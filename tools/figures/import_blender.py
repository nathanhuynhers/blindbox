"""Isolated Blender worker for external.py. Never constructs character geometry."""
from __future__ import annotations

import json
import math
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

import build
from baking import bake_maps
from external import digest, gate, write_json, VIEWS
from external_glb import inspect, material_signatures, MAX_TRIS
from partition import partition


def protected_object(name, entry):
    return name == entry['eyes']['object'] or name in entry['protected_objects'] or any(word in name.lower() for word in ('face', 'eye', 'hair', 'accessor', 'cloth'))


def subset(obj, indices, name, material_index):
    """Copy source triangle corners, UVs, colors and split normals without welding."""
    src = obj.data
    polygons = [src.polygons[i] for i in sorted(indices)]
    vertices = sorted({v for p in polygons for v in p.vertices})
    remap = {old: new for new, old in enumerate(vertices)}
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([src.vertices[v].co[:] for v in vertices], [],
                     [[remap[v] for v in p.vertices] for p in polygons])
    mesh.materials.append(src.materials[material_index])
    for p, original in zip(mesh.polygons, polygons):
        p.use_smooth = original.use_smooth
    corners = [i for p in polygons for i in p.loop_indices]
    uv = mesh.uv_layers.new(name=src.uv_layers.active.name)
    for i, old in enumerate(corners):
        uv.data[i].uv = src.uv_layers.active.data[old].uv
    for color in src.color_attributes:
        if color.domain not in ('POINT', 'CORNER'):
            raise ValueError('unsupported color attribute domain')
        new = mesh.color_attributes.new(name=color.name, type=color.data_type, domain=color.domain)
        for i, old in enumerate(vertices if color.domain == 'POINT' else corners):
            new.data[i].color = color.data[old].color
    mesh.update()
    mesh.normals_split_custom_set([src.corner_normals[i].vector[:] for i in corners])
    result = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(result)
    return result


def geometry_check(obj):
    stats = build.audit(obj)
    # Cuts intentionally produce boundaries; closed-solid volume is not appropriate here.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    stats['branch_edges'] = sum(len(e.link_faces) > 2 for e in bm.edges)
    bm.free()
    if not stats['finite_vertices'] or not stats['finite_uvs'] or any(stats[k] for k in ('zero_area_faces', 'duplicate_faces', 'uv_zero_area_faces', 'branch_edges')):
        raise ValueError(f'{obj.name}: invalid geometry/UVs: {stats}')
    return stats


def normalize(objects, entry):
    rotation = Euler([math.radians(x) for x in entry['rotation_degrees']], 'XYZ').to_matrix().to_4x4()
    for obj in objects:
        mesh = obj.data.copy()
        transform = rotation @ obj.matrix_world
        normals = [(transform.to_3x3().inverted().transposed() @ n.vector).normalized()[:] for n in obj.data.corner_normals]
        mesh.transform(transform)
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
        old, obj.data = obj.data, mesh
        mesh.normals_split_custom_set(normals)
        # Roblox names MeshParts after the glTF mesh; the copy must not become "<name>.001".
        name = old.name
        if not old.users:
            bpy.data.meshes.remove(old)
        mesh.name = name
    coords = np.asarray([v.co[:] for o in objects for v in o.data.vertices])
    low, high = coords.min(0), coords.max(0)
    if not np.isfinite(coords).all() or min(high - low) <= 1e-8:
        raise ValueError('source has invalid/flat bounds')
    scale = entry['height_studs'] / (high[2] - low[2])
    transform = Matrix.Scale(float(scale), 4) @ Matrix.Translation(Vector((-(low[0] + high[0]) / 2, -(low[1] + high[1]) / 2, -low[2])))
    for obj in objects:
        obj.data.transform(transform)
    return coords, scale


def spread_degenerate_uvs(mesh, eps=1e-5):
    """Give zero-UV-area triangles (collinear/coincident UVs) a sub-texel area so tangents exist.

    Tripo exports and collapse decimation both produce some; they sample one texel either way, and
    eps (0.04 texel at 4096 px) moves no visible texture. Returns how many triangles changed.
    """
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.active
    changed = 0
    for f in bm.faces:
        a, b, c = (l[uv].uv for l in f.loops)
        if abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) >= 1e-12:
            continue
        ab = b - a
        if ab.length < 1e-4:
            f.loops[1][uv].uv = (a.x + eps, a.y)
            f.loops[2][uv].uv = (a.x, a.y + eps)
        else:
            n = ab.normalized()
            f.loops[2][uv].uv = (c.x - n.y * eps, c.y + n.x * eps)
        changed += 1
    bm.to_mesh(mesh)
    bm.free()
    return changed


def optimize(obj, policy, output, texture_limit=4096):
    """Only explicitly budgeted non-protected objects can lose geometry."""
    if not policy or len(obj.data.polygons) <= policy['target_triangles']:
        return {'mode': 'lossless', 'surface_error': 0.0}
    if obj.data.color_attributes:
        raise ValueError('decimation of vertex-painted objects needs a color bake; use lossless partitioning')
    source = obj.copy()
    source.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(source)
    before = source.data
    bpy.context.view_layer.objects.active = obj
    # glTF import splits vertices along UV seams; decimating unwelded seams collapses each side
    # independently and tears the surface. Weld positions first (UVs stay per corner).
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bm.to_mesh(obj.data)
    bm.free()
    mod = obj.modifiers.new('ExplicitQualityBudget', 'DECIMATE')
    mod.ratio = policy['target_triangles'] / len(before.polygons)
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    uv_spread = spread_degenerate_uvs(obj.data)
    error = build.surface_error(before, obj.data)
    if not math.isfinite(error) or error > policy['max_surface_error']:
        raise ValueError(f'{obj.name}: decimation surface error {error} exceeds {policy["max_surface_error"]}; split instead')
    bake = None
    original_material = baked_material = None
    if policy.get('bake_normals'):
        if len(obj.data.materials) != 1:
            raise ValueError('normal baking requires a single source material object')
        # Existing imported normal detail is not silently replaced by a new bake.
        mat = obj.data.materials[0]
        shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        if shader.inputs['Alpha'].is_linked or shader.inputs['Alpha'].default_value < 1:
            raise ValueError('normal baking requires opaque material; keep transparent geometry lossless')
        if shader.inputs['Normal'].is_linked:
            raise ValueError('source already has a normal map; retain it with lossless partitioning')
        original_material = mat.name
        mat = mat.copy()
        baked_material = mat.name
        obj.data.materials[0] = mat
        source.hide_render = False
        paths = bake_maps(obj, output / 'maps', resolution=policy.get('bake_resolution', min(2048, texture_limit)), channels=('normal',), high=source, cage=policy['max_surface_error'] * 2)
        bake = paths['normal_map']
        shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        image = bpy.data.images.load(bake)
        image.colorspace_settings.name = 'Non-Color'
        image.pack()
        node = mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = image
        normal = mat.node_tree.nodes.new('ShaderNodeNormalMap')
        mat.node_tree.links.new(node.outputs['Color'], normal.inputs['Color'])
        mat.node_tree.links.new(normal.outputs['Normal'], shader.inputs['Normal'])
    before_count = len(before.polygons)
    bpy.data.objects.remove(source, do_unlink=True)
    return {'mode': 'explicit_decimation', 'surface_error': error, 'normal_bake': Path(bake).name if bake else None,
            'original_material': original_material, 'baked_material': baked_material,
            'before_triangles': before_count, 'after_triangles': len(obj.data.polygons), 'uv_spread': uv_spread}


def render(objects, output, slug, kind, framing, resolution, samples):
    center, radius = framing
    camera = build.setup_render(bpy.context.scene, resolution, samples, fidelity=True)
    distance = radius * 1.12 / math.sin(min(camera.data.angle_x, camera.data.angle_y) / 2)
    scale = radius / 1.7
    for obj in bpy.context.scene.objects:
        if obj.type == 'LIGHT':
            obj.location *= scale
            obj.data.energy *= scale * scale
            obj.data.size *= scale
    paths = []
    for view in VIEWS:
        az, el = build.VIEWS[view]
        build.aim(camera, az, el, dist=distance, target=center)
        file = output / f'{slug}_{kind}_{view}.png'
        bpy.context.scene.render.filepath = str(file)
        bpy.ops.render.render(write_still=True)
        paths.append(file.name)
    return paths


def compare(output, source, fidelity):
    result = {}
    for view, a, b in zip(VIEWS, source, fidelity):
        images = [bpy.data.images.load(str(output / p), check_existing=False) for p in (a, b)]
        pixels = [np.asarray(i.pixels[:], dtype=np.float32).reshape(-1, 4) for i in images]
        masks = [p[:, 3] > .5 for p in pixels]
        union, common = masks[0] | masks[1], masks[0] & masks[1]
        iou = float(common.sum() / max(1, union.sum()))
        difference = float(np.abs(pixels[0][union, :3] - pixels[1][union, :3]).mean()) if union.any() else 1.0
        result[view] = {'silhouette_iou': iou, 'foreground_rgb_mae': difference,
                        'pass': iou >= .97 and difference <= .05,
                        'limits': {'silhouette_iou_min': .97, 'foreground_rgb_mae_max': .05}}
        for image in images:
            bpy.data.images.remove(image)
    return result


def convert(job):
    e, output = job['entry'], Path(job['output'])
    slug = e['figure_slug'].replace('-', '_')
    validation = output / 'validation' / f'{slug}_validation.json'
    validation.unlink(missing_ok=True)  # Failed workers must not leave an old passing receipt.
    for folder in ('source', 'model', 'renders', 'validation'):
        (output / folder).mkdir(parents=True, exist_ok=True)
    shutil.copyfile(job['source'], output / 'source/original.glb')
    if digest(output / 'source/original.glb') != job['source_sha256']:
        raise ValueError('source changed while copying; rerun with a stable download')
    source_stats = inspect(output / 'source/original.glb', texture_limit=16384 if e.get('resize_textures') else e['texture_limit'])
    build.reset()
    bpy.ops.import_scene.gltf(filepath=str(output / 'source/original.glb'))
    objects = sorted((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: o.name)
    names = {o.name for o in objects}
    selectors = {e['eyes']['object'], *e['protected_objects'], *e.get('optimization', {})}
    if not selectors <= names:
        raise ValueError(f'source selectors missing: {sorted(selectors - names)}; available: {sorted(names)}')
    normalize(objects, e)
    for obj in objects:
        geometry_check(obj)
    coords = np.asarray([v.co[:] for o in objects for v in o.data.vertices])
    low, high = coords.min(0), coords.max(0)
    center = (low + high) / 2
    radius = float(np.linalg.norm(coords - center, axis=1).max())
    framing = center.tolist(), radius
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'source/source.blend'))
    source_views = render(objects, output / 'renders', slug, 'source', framing, job['resolution'], job['samples'])
    # Restore the canonical full-resolution scene, with no render props/lights in production.
    bpy.ops.wm.open_mainfile(filepath=str(output / 'source/source.blend'))
    objects = sorted((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: o.name)
    texture_changes = []
    for image in bpy.data.images:
        if image.type != 'IMAGE' or max(image.size) <= e['texture_limit']:
            continue
        if not e.get('resize_textures'):
            raise ValueError('texture exceeds limit without explicit resize opt-in')
        previous = list(image.size)
        ratio = e['texture_limit'] / max(previous)
        image.scale(max(1, round(previous[0] * ratio)), max(1, round(previous[1] * ratio)))
        image.pack()
        texture_changes.append({'image': image.name, 'before': previous, 'after': list(image.size)})
    parts, information = [], {}
    eyes_count = 0
    for obj in objects:
        protected = protected_object(obj.name, e)
        policy = e.get('optimization', {}).get(obj.name)
        if protected and policy and len(obj.data.polygons) > policy['target_triangles']:
            raise ValueError(f'{obj.name}: protected detail cannot be decimated; use lossless partitioning')
        information[obj.name] = optimize(obj, policy, output, e['texture_limit'])
        geometry_check(obj)
        groups = {}
        for face in obj.data.polygons:
            eyes = obj.name == e['eyes']['object']
            if eyes and 'region' in e['eyes']:
                position = (np.asarray(face.center[:]) - low) / (high - low)
                lo, hi = e['eyes']['region']
                eyes = bool(np.all(position >= lo) and np.all(position <= hi))
            groups.setdefault((eyes, face.material_index), []).append(face.index)
        for (eyes, material), indices in sorted(groups.items(), reverse=True):
            selected_faces = [obj.data.polygons[i].vertices[:] for i in indices]
            groups_of_indices = partition(selected_faces, [v.co[:] for v in obj.data.vertices], MAX_TRIS)
            if eyes and (len(groups_of_indices) != 1 or eyes_count):
                raise ValueError('eyes selector must yield one material and <=19999 triangles; tighten region')
            for group in groups_of_indices:
                if eyes:
                    name = e['root'] + '_Eyes'
                    eyes_count += 1
                else:
                    name = e['root'] + f'_Part{len(parts) + 1:03d}'
                part = subset(obj, [indices[i] for i in group], name, material)
                parts.append(part)
                if len(parts) > e['max_parts']:
                    raise ValueError('MeshPart safety cap exceeded; specify selective optimization or review max_parts')
        bpy.data.objects.remove(obj, do_unlink=True)
    if not eyes_count:
        raise ValueError('eyes region selected no source triangles')
    for obj in list(bpy.context.scene.objects):
        if obj not in parts:
            bpy.data.objects.remove(obj, do_unlink=True)
    if any(info.get('mode') == 'explicit_decimation' for info in information.values()):
        # Decimation can move the extreme vertices; restore the requested height and grounding.
        normalize(parts, dict(e, rotation_degrees=[0, 0, 0]))
    root = bpy.data.objects.new(e['root'], None)
    bpy.context.scene.collection.objects.link(root)
    for obj in parts:
        obj.parent = root
    stats = {o.name: geometry_check(o) for o in parts}
    coordinates = np.asarray([v.co[:] for o in parts for v in o.data.vertices])
    minv, maxv = coordinates.min(0), coordinates.max(0)
    eye = next(o for o in parts if o.name.endswith('_Eyes'))
    eye_coords = np.asarray([v.co[:] for v in eye.data.vertices])
    delta = (eye_coords.min(0) + eye_coords.max(0) - minv - maxv) / 2
    facing_valid = bool(delta[1] < -.001 and abs(delta[0]) <= -delta[1] * .15)
    if not facing_valid:
        raise ValueError('eyes bounding center must lie on the front (-Y), near the centerline; adjust rotation/region')
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'model' / f'{slug}_production.blend'))
    model = output / 'model' / f'{slug}_roblox.glb'
    snapshots = build.snapshots_for(parts)
    expected = {o.name: len(o.data.polygons) for o in parts}
    build.export_glb(root, parts, str(model))
    glb = inspect(model, production=True, texture_limit=e['texture_limit'])
    original_materials = material_signatures(output / 'source/original.glb')
    final_materials = material_signatures(model)
    material_mismatches = []
    baked_aliases = {v['baked_material']: v['original_material'] for v in information.values() if v.get('baked_material')}
    for baked_name, original_name in baked_aliases.items():
        if original_name not in final_materials and baked_name in final_materials:
            final_materials[original_name] = final_materials[baked_name]
    for name, original in original_materials.items():
        actual = final_materials.get(name)
        if actual is None:
            material_mismatches.append(f'{name}: original material missing')
            continue
        for field in original:
            if field == 'maps':
                for slot, details in original[field].items():
                    target = actual[field].get(slot)
                    for key, value in details.items():
                        if key == 'dimensions' and e.get('resize_textures'):
                            continue
                        if target is None or target.get(key) != value:
                            material_mismatches.append(f'{name}: {slot} {key} changed')
                allowed_maps = set(original[field]) | ({'normal'} if name in baked_aliases.values() else set())
                if not set(actual[field]) <= allowed_maps:
                    material_mismatches.append(f'{name}: material map channels changed')
            elif isinstance(original[field], (int, float, list)):
                if not np.allclose(original[field], actual[field], atol=1e-5, rtol=0):
                    material_mismatches.append(f'{name}: {field} changed')
            elif original[field] != actual[field]:
                material_mismatches.append(f'{name}: {field} changed')
    ri = build.reimport_check(str(model), expected, snapshots)
    imported = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    fidelity = render(imported, output / 'renders', slug, 'fidelity', framing, job['resolution'], job['samples'])
    comparison = compare(output / 'renders', source_views, fidelity)
    report = {'schema_version': 3, 'pipeline': 'external_glb', 'fingerprint': job['fingerprint'],
              'source_filename': e['source'], 'source_sha256': job['source_sha256'], 'import_entry': e,
              'catalog': e['figure_id'], 'collection_id': e['collection_id'], 'rarity': e['rarity'],
              'root': e['root'], 'figure': e['root'], 'title': e['title'], 'face': e['root'] + '_Eyes',
              'glass': [], 'meshes': len(parts), 'triangles': sum(expected.values()),
              'source_triangles': source_stats['triangles'], 'source': source_stats,
              'size_xyz_studs': (maxv - minv).tolist(), 'grounded': bool(abs(minv[2]) <= 2e-5),
              'facing_valid': facing_valid, 'components': stats, 'optimization': information,
              'texture_changes': texture_changes, 'glb': glb, 'reimport': ri,
              'material_mismatches': material_mismatches, 'source_materials': original_materials, 'production_materials': final_materials,
              'visual_comparison': comparison, 'previews': {'view_names': VIEWS, 'source_views': source_views,
              'fidelity_views': fidelity, 'fidelity_sha256': glb['sha256'], 'fidelity_source': 'exported_reimported_glb'},
              'errors': [], 'notes': ['Open boundaries from partitioning are intentional; no caps added.',
              'Image metrics flag large losses, not likeness, seams or Roblox PBR fidelity.',
              'Original source GLB is byte-preserved. Orientation/scale are explicit manifest choices.']}
    report['artifacts'] = {p.relative_to(output).as_posix(): digest(p) for directory in ('source', 'model', 'renders', 'maps')
                           for p in sorted((output / directory).rglob('*')) if p.is_file() and not p.name.endswith('.blend1')}
    report['errors'] = gate(report, e)
    write_json(validation, report)
    if report['errors']:
        raise ValueError('; '.join(report['errors']))
    print(f'Converted {e["figure_id"]}: {report["triangles"]} triangles / {report["meshes"]} MeshParts', flush=True)


if __name__ == '__main__':
    file = Path(sys.argv[sys.argv.index('--') + 1])
    convert(json.loads(file.read_text(encoding='utf-8')))
