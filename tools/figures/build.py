"""Build, validate, export and render collectible figures inside Blender.

Each collection defines its figures in assets/figures/<collection>/figures.py (a FIGURES dict of
figure slug -> builder, using sdf.py from this folder). See docs/FIGURE_COLLECTION_RUNBOOK.md.

Usage (from the repository root):
  blender -b --factory-startup --python tools/figures/build.py -- <collection> <figure> [mode]
  blender -b --factory-startup --python tools/figures/build.py -- <collection> lineup

mode: preview (beauty contact sheet), final (GLB + reimport fidelity and beauty), or fidelity
      (render an existing exported GLB without rebuilding). lineup renders every figure in the collection
      side by side from their production .blend files.

FIG_ASSETS=<folder under assets/> builds models kept elsewhere, e.g. FIG_ASSETS=models for the
town props in assets/models/<collection>/figures.py. The default is figures.
"""

import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
import openvdb as vdb

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from glb import summary as glb_summary
from modeling import MeshData


ROOT = ""  # assets/figures/<collection>, set by main()
PREVIEW = ""  # build/figures/<collection>/preview (ignored scratch)
# "view transform|look|exposure"; FIG_VIEW overrides, else the collection's RENDER_VIEW, else this.
RENDER_VIEW = "AgX|AgX - Punchy|-0.35"
BLOCK = 8

VIEWS = {  # azimuth measured from the front (-Y) toward the character's left (+X)
    "front": (0.0, 6.0),
    "three_quarter": (-35.0, 8.0),
    "side": (90.0, 6.0),
    "back": (180.0, 6.0),
}
CAM_TARGET = (0.0, 0.0, 1.55)
CAM_DIST = 12.4
FOCAL = 85.0


# --------------------------------------------------------------- SDF -> mesh

def evaluate(fn, lo, hi, v):
    """Dense SDF samples, evaluating exactly only in blocks near the surface."""
    n = [int(math.ceil((hi[i] - lo[i]) / v / BLOCK)) * BLOCK + 1 for i in range(3)]
    if math.prod(n) > int(os.environ.get("FIG_MAX_GRID_CELLS", "64000000")):
        raise ValueError(f"SDF grid {n} exceeds memory guard; use tight per-component bounds or split the part")
    nb = [(n[i] - 1) // BLOCK for i in range(3)]
    centers = [lo[i] + (np.arange(nb[i]) + 0.5) * BLOCK * v for i in range(3)]
    cg = np.meshgrid(*centers, indexing="ij")
    dc = fn((cg[0], cg[1], cg[2]))
    if not np.isfinite(dc).all():
        raise ValueError("non-finite SDF samples")
    half_diag = BLOCK * v * math.sqrt(3) / 2
    active = np.abs(dc) < half_diag * 2.0 + v * 2
    arr = np.empty(n, dtype=np.float32)
    # coarse fill: nearest block centre value (sign-correct away from the surface)
    idx = [np.minimum(np.arange(n[i]) // BLOCK, nb[i] - 1) for i in range(3)]
    arr[:] = dc[np.ix_(idx[0], idx[1], idx[2])]
    ab = np.argwhere(active)
    off = np.arange(BLOCK + 1)
    ox, oy, oz = np.meshgrid(off, off, off, indexing="ij")
    ox, oy, oz = ox.ravel(), oy.ravel(), oz.ravel()
    chunk = max(1, 1_500_000 // ox.size)
    for s in range(0, len(ab), chunk):
        blocks = ab[s:s + chunk]
        ix = (blocks[:, 0:1] * BLOCK + ox[None, :]).ravel()
        iy = (blocks[:, 1:2] * BLOCK + oy[None, :]).ravel()
        iz = (blocks[:, 2:3] * BLOCK + oz[None, :]).ravel()
        vals = fn((lo[0] + ix * v, lo[1] + iy * v, lo[2] + iz * v))
        if not np.isfinite(vals).all():
            raise ValueError("non-finite SDF surface samples")
        arr[ix, iy, iz] = vals
    return arr, int(active.sum()), int(active.size)


def find_bounds(fn, lo, hi, step=0.04):
    axes = [np.arange(lo[i], hi[i] + step, step) for i in range(3)]
    g = np.meshgrid(*axes, indexing="ij")
    d = fn((g[0], g[1], g[2]))
    mask = d < step * 1.2
    if not mask.any():
        return None
    pts = np.stack([g[0][mask], g[1][mask], g[2][mask]], axis=1)
    return pts.min(0) - step * 2, pts.max(0) + step * 2


def sdf_to_mesh(comp, bounds):
    b = getattr(comp, "bounds", None)
    if b is None:
        b = find_bounds(comp.fn, *bounds)
    if b is None:
        raise RuntimeError(f"{comp.name}: empty SDF inside figure bounds")
    lo, hi = np.asarray(b[0], float), np.asarray(b[1], float)
    if lo.shape != (3,) or hi.shape != (3,) or not np.isfinite([lo, hi]).all() or np.any(hi <= lo):
        raise ValueError(f"{comp.name}: invalid sampling bounds")
    arr, act, tot = evaluate(comp.fn, lo, hi, comp.voxel)
    # Explicit tight bounds must still enclose the whole surface.
    if any(np.any(face <= 0) for face in (arr[0], arr[-1], arr[:, 0], arr[:, -1], arr[:, :, 0], arr[:, :, -1])):
        raise ValueError(f"{comp.name}: SDF touches sampling bounds; add margin")
    g = vdb.FloatGrid()
    g.background = float(arr.max())
    g.copyFromArray(arr)
    pts, quads = g.convertToQuads(isovalue=0.0)
    verts = lo[None, :] + pts.astype(np.float64) * comp.voxel
    return verts, quads, dict(active_blocks=act, blocks=tot, grid=list(arr.shape))


def build_object(comp, bounds, collection):
    t0 = time.time()
    factory = getattr(comp, "mesh", None)
    if factory is None:
        verts, faces, info = sdf_to_mesh(comp, bounds)
        me = bpy.data.meshes.new(comp.name)
        me.from_pydata(verts.tolist(), [], faces.tolist())
    else:
        source = factory() if callable(factory) else factory
        info = dict(source="mesh")
        if isinstance(source, MeshData):
            me = bpy.data.meshes.new(comp.name)
            me.from_pydata(np.asarray(source.vertices).tolist(), [], source.faces)
            if source.uvs is not None:
                uv = me.uv_layers.new(name="UVMap")
                coords = [xy for face in source.uvs for xy in face]
                if len(coords) != len(me.loops):
                    raise ValueError(f"{comp.name}: UV corner count does not match mesh")
                uv.data.foreach_set("uv", np.asarray(coords, np.float32).ravel())
        elif isinstance(source, bpy.types.Object) and source.type == "MESH":
            me = bpy.data.meshes.new_from_object(source.evaluated_get(bpy.context.evaluated_depsgraph_get()), preserve_all_data_layers=True, depsgraph=bpy.context.evaluated_depsgraph_get())
            me.transform(source.matrix_world)
            # Factory objects are construction helpers, never exported.
            bpy.data.objects.remove(source, do_unlink=True)
            # Roblox names MeshParts after the glTF mesh, so the source's mesh name must not leak.
            me.name = comp.name
        else:
            raise TypeError(f"{comp.name}: mesh factory must return MeshData or a Blender mesh object")
    if me.validate():
        raise ValueError(f"{comp.name}: invalid source mesh required repairs")
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(comp.name, me)
    collection.objects.link(obj)
    raw_tris = len(me.polygons)
    reference = me.copy()
    if raw_tris > comp.tris:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = comp.tris / raw_tris
        mod.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
        new = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
        obj.modifiers.clear()
        old = obj.data
        obj.data = new
        bpy.data.meshes.remove(old)
        new.name = comp.name
    else:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
    removed = drop_specks(obj.data, comp.min_faces)
    obj.data.polygons.foreach_set("use_smooth", [getattr(comp, "smooth", True)] * len(obj.data.polygons))
    error = surface_error(reference, obj.data)
    bpy.data.meshes.remove(reference)
    info.update(surface_error=error, retained_ratio=len(obj.data.polygons) / max(1, raw_tris))
    limit = getattr(comp, "max_surface_error", None)
    if limit is not None and error > limit:
        raise ValueError(f"{comp.name}: optimization moved surface {error:.6f} studs (limit {limit}); increase budget or split detail")
    info.update(raw_tris=raw_tris, removed_faces=removed, seconds=round(time.time() - t0, 1))
    return obj, info


def surface_error(before, after):
    """Symmetric sampled surface distance (vertices + face centers), not a proof of similarity."""
    from mathutils.bvhtree import BVHTree
    def tree(me):
        return BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])
    result = 0.0
    for source, target in ((before, after), (after, before)):
        bvh = tree(target)
        for point in [v.co for v in source.vertices] + [p.center for p in source.polygons]:
            hit = bvh.find_nearest(point)
            if hit is None or hit[3] is None:
                return float("inf")
            result = max(result, hit[3])
    return result


def face_set(me, places=6):
    """Triangles as sorted rounded corner positions: index order and UV/normal seam splits ignored."""
    co = [tuple(round(c, places) for c in v.co) for v in me.vertices]
    return sorted(tuple(sorted(co[i] for i in p.vertices)) for p in me.polygons)


def drop_specks(me, min_faces):
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    seen = set()
    doomed = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, island = [f], []
        seen.add(f.index)
        while stack:
            cur = stack.pop()
            island.append(cur)
            for e in cur.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        if len(island) < min_faces:
            doomed.extend(island)
    if doomed:
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.dissolve_degenerate(bm, dist=2e-5, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(me)
    bm.free()
    return len(doomed)


# --------------------------------------------------------------- materials

def srgb(hexstr):
    h = hexstr.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


def make_image(name, colors, alpha):
    w = 64 if len(colors) > 1 else 16
    img = bpy.data.images.new(name, w, 4, alpha=alpha < 1.0)
    stops = np.array([srgb(c) for c in colors])
    # Store encoded sRGB texels; the shader decodes through the image color space.
    # Converting these values to linear here would encode a darker albedo in GLB.
    img.colorspace_settings.name = "sRGB"
    if len(colors) > 1:
        t = np.linspace(0, 1, w)
        xs = np.linspace(0, 1, len(colors))
        row = np.stack([np.interp(t, xs, stops[:, k]) for k in range(3)], axis=1)
    else:
        row = np.repeat(stops, w, axis=0)
    rgba = np.concatenate([row, np.full((w, 1), alpha)], axis=1)
    px = np.tile(rgba[None, :, :], (4, 1, 1)).ravel()
    img.pixels.foreach_set(px.astype(np.float32))
    img.file_format = "PNG"
    img.pack()
    return img


def make_material(name, m):
    colors = m.color if isinstance(m.color, list) else [m.color]
    mat = bpy.data.materials.new(name)
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = load_map(m.color_map, "sRGB") if getattr(m, "color_map", None) else make_image(name, colors, m.alpha)
    tex.interpolation = "Linear"
    tex.extension = "EXTEND"
    tex.location = (-400, 200)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if m.alpha < 1.0:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.surface_render_method = "BLENDED"
    bsdf.inputs["Roughness"].default_value = m.rough
    bsdf.inputs["Metallic"].default_value = m.metal
    if getattr(m, "pbr", False):
        # glTF core uses packed G=roughness, B=metalness. Named Separate Color
        # connections are recognized by Blender's exporter, avoiding extensions.
        rough = load_map(m.roughness_map, "Non-Color") if m.roughness_map else None
        metal = load_map(m.metalness_map, "Non-Color") if m.metalness_map else None
        packed = packed_pbr(name, rough, metal, m.rough, m.metal)
        ptex = nt.nodes.new("ShaderNodeTexImage")
        ptex.image = packed
        split = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(ptex.outputs["Color"], split.inputs["Color"])
        nt.links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(split.outputs["Blue"], bsdf.inputs["Metallic"])
        if m.normal_map:
            ntex = nt.nodes.new("ShaderNodeTexImage")
            ntex.image = load_map(m.normal_map, "Non-Color")
            normal = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(ntex.outputs["Color"], normal.inputs["Color"])
            nt.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    mat["render_garnish"] = json.dumps(m.render)
    return mat


def load_map(path, color_space):
    # Separate images for data/color interpretations of a shared source file.
    img = bpy.data.images.load(os.path.abspath(path), check_existing=False)
    if max(img.size) > 2048:
        raise ValueError(f"{path}: texture exceeds pipeline 2048px budget; downsample deliberately")
    img.colorspace_settings.name = color_space
    img.pack()
    return img


def packed_pbr(name, rough, metal, rough_value, metal_value):
    sizes = [tuple(i.size) for i in (rough, metal) if i is not None]
    if len(set(sizes)) > 1:
        raise ValueError("roughness and metalness maps must have identical sizes")
    w, h = sizes[0] if sizes else (4, 4)
    px = np.ones((w * h, 4), dtype=np.float32)
    for channel, image, value in ((1, rough, rough_value), (2, metal, metal_value)):
        if image is None:
            px[:, channel] = value
        else:
            data = np.empty(w * h * 4, np.float32)
            image.pixels.foreach_get(data)
            px[:, channel] = data.reshape(-1, 4)[:, 0]
    img = bpy.data.images.new(f"{name}_MetallicRoughness", w, h, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(px.ravel())
    img.file_format = "PNG"
    img.pack()
    return img


def apply_render_garnish(mat):
    """Beauty-only extras. These do not predict Studio shading."""
    extras = json.loads(mat.get("render_garnish", "{}"))
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    if "coat" in extras:
        bsdf.inputs["Coat Weight"].default_value = extras["coat"]
        bsdf.inputs["Coat Roughness"].default_value = 0.25
    if "thin_film" in extras:
        bsdf.inputs["Thin Film Thickness"].default_value = extras["thin_film"]
        bsdf.inputs["Thin Film IOR"].default_value = 1.45
    if "subsurface" in extras:
        bsdf.inputs["Subsurface Weight"].default_value = extras["subsurface"]
        bsdf.inputs["Subsurface Radius"].default_value = (0.4, 0.5, 0.8)
        bsdf.inputs["Subsurface Scale"].default_value = 0.15
    if "transmission" in extras:
        # soap-film preview: mostly transparent surface with iridescent gloss
        for link in list(mat.node_tree.links):
            if link.to_socket == bsdf.inputs["Alpha"]:
                mat.node_tree.links.remove(link)
        bsdf.inputs["Alpha"].default_value = 0.16
        bsdf.inputs["Roughness"].default_value = 0.02
        bsdf.inputs["Specular IOR Level"].default_value = 1.0


def set_uvs(obj, ramp, mode="legacy"):
    me = obj.data
    if ramp is not None:
        # A ramp replaces authored UVs; do not leave a different active render layer.
        for layer in list(me.uv_layers):
            me.uv_layers.remove(layer)
    if ramp is None and me.uv_layers:
        return
    if ramp is None and mode == "auto":
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(island_margin=0.03)
        bpy.ops.object.mode_set(mode="OBJECT")
        return
    uv = me.uv_layers.new(name="UVMap")
    nloops = len(me.loops)
    if ramp is None:
        coords = np.full(nloops * 2, 0.5, dtype=np.float32)
    else:
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        vi = np.empty(nloops, dtype=np.int64)
        me.loops.foreach_get("vertex_index", vi)
        t = np.clip(ramp(co[:, 0], co[:, 1], co[:, 2]), 0.0, 1.0)
        u = 0.5 / 64 + t * (1 - 1 / 64)
        coords = np.stack([u[vi], np.full(nloops, 0.5)], axis=1).ravel().astype(np.float32)
    uv.data.foreach_set("uv", coords)


# --------------------------------------------------------------- audit

def audit(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # glTF splits UV/normal seams. Audit a welded copy, never change the asset.
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bm.verts.index_update()
    non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    zero = sum(1 for f in bm.faces if f.calc_area() < 1e-10)
    vol = bm.calc_volume(signed=True)
    tris = len(bm.faces)
    remaining = set(bm.faces)
    islands, negative = [], 0
    while remaining:
        seed = remaining.pop()
        stack, island = [seed], [seed]
        while stack:
            f = stack.pop()
            for e in f.edges:
                for other in e.link_faces:
                    if other in remaining:
                        remaining.remove(other)
                        stack.append(other)
                        island.append(other)
        ivol = sum(f.verts[0].co.dot(f.verts[1].co.cross(f.verts[2].co)) / 6 for f in island)
        negative += int(ivol <= 0)
        islands.append(len(island))
    duplicate = len(bm.faces) - len({tuple(sorted(v.index for v in f.verts)) for f in bm.faces})
    bm.free()
    coords = np.asarray([v.co[:] for v in obj.data.vertices])
    uv = obj.data.uv_layers.active
    uvcoords = np.asarray([u.uv[:] for u in uv.data]) if uv else np.empty((0, 2))
    uv_zero = 0
    if uv:
        for p in obj.data.polygons:
            a, b, c = [np.asarray(uv.data[i].uv) for i in p.loop_indices]
            uv_zero += int(abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) < 1e-12)
    return dict(tris=tris, verts=len(obj.data.vertices), non_manifold_edges=non_manifold,
                boundary_edges=boundary, zero_area_faces=zero, signed_volume=vol,
                islands=len(islands), island_faces=sorted(islands), non_positive_islands=negative,
                duplicate_faces=duplicate, finite_vertices=bool(np.isfinite(coords).all()),
                finite_uvs=bool(len(uvcoords) and np.isfinite(uvcoords).all()), uv_zero_area_faces=uv_zero,
                bounds=[coords.min(0).tolist(), coords.max(0).tolist()], materials=len(obj.data.materials))


# --------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def build_figure(spec, collection):
    mats = {name: make_material(name, m) for name, m in spec["mats"].items()}
    objs, report = [], {}
    names = [c.name for c in spec["comps"]]
    if len(names) != len(set(names)) or any("." in n for n in names):
        raise ValueError("component names must be unique and contain no periods")
    for comp in spec["comps"]:
        obj, info = build_object(comp, spec["bounds"], collection)
        set_uvs(obj, comp.ramp, getattr(comp, "uv", "legacy"))
        obj.data.materials.clear()
        obj.data.materials.append(mats[comp.mat])
        objs.append(obj)
        report[comp.name] = info
        check = audit(obj)
        expected = getattr(comp, "expected_islands", None)
        if expected is not None and check["islands"] != expected:
            raise ValueError(f"{comp.name}: expected {expected} solid islands, got {check['islands']}")
        m = spec["mats"][comp.mat]
        spatial_maps = any(getattr(m, k, None) for k in ("color_map", "roughness_map", "metalness_map", "normal_map"))
        if spatial_maps and check["uv_zero_area_faces"]:
            raise ValueError(f"{comp.name}: spatial maps require nondegenerate UVs, including caps")
        print(f"  {comp.name}: {len(obj.data.polygons)} tris ({info['seconds']}s)", flush=True)
    # ground pivot: lowest point to Z = 0, centreline kept
    zmin = min(min(v.co.z for v in o.data.vertices) for o in objs)
    for o in objs:
        o.data.transform(__import__("mathutils").Matrix.Translation((0, 0, -zmin)))
    root = bpy.data.objects.new(spec["name"], None)
    collection.objects.link(root)
    for o in objs:
        o.parent = root
    return root, objs, report, mats


def setup_render(scene, res, samples, fidelity=False):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 8
    scene.cycles.transmission_bounces = 8
    scene.render.resolution_x = res
    scene.render.resolution_y = res
    scene.render.film_transparent = True
    scene.cycles.film_transparent_glass = True
    vt, look, expo = ("Khronos PBR Neutral|None|-0.35" if fidelity else os.environ.get("FIG_VIEW", RENDER_VIEW)).split("|")
    scene.view_settings.view_transform = vt
    scene.view_settings.look = look
    scene.view_settings.exposure = float(expo)
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.9, 0.88, 0.85, 1)
    bg.inputs["Strength"].default_value = 0.55
    scene.world = world

    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.name = "StudioFloor"
    floor.is_shadow_catcher = True

    def area(name, loc, energy, size, color=(1, 1, 1)):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.size = size
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        scene.collection.objects.link(lo)
        lo.location = loc
        d = -np.array(loc) + np.array([0, 0, 1.4])
        lo.rotation_euler = __import__("mathutils").Vector(d).to_track_quat("-Z", "Y").to_euler()
        return lo

    area("Key", (-5.0, -7.0, 7.5), 2300, 5.0)
    area("Fill", (7.0, -5.0, 3.5), 900, 6.0)
    area("Rim", (2.0, 8.0, 7.0), 1600, 4.0)
    area("Back", (-6.0, 6.0, 3.0), 800, 5.0)

    cd = bpy.data.cameras.new("Cam")
    cd.lens = FOCAL
    cam = bpy.data.objects.new("Cam", cd)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def aim(cam, az, el, dist=CAM_DIST, target=CAM_TARGET):
    import mathutils
    a, e = math.radians(az), math.radians(el)
    pos = mathutils.Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    pos += mathutils.Vector(target)
    cam.location = pos
    cam.rotation_euler = (mathutils.Vector(target) - pos).to_track_quat("-Z", "Y").to_euler()


def render_to(path, webp=None):
    bpy.ops.render.render(write_still=False)
    img = bpy.data.images["Render Result"]
    img.save_render(path)
    if webp:
        s = bpy.context.scene.render.image_settings
        s.file_format = "WEBP"
        s.quality = 90
        img.save_render(webp)
        s.file_format = "PNG"


def contact_sheet(paths, out, bg=(0.97, 0.94, 0.89)):
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size
    sheet = np.zeros((h, w * len(imgs), 4), dtype=np.float32)
    for i, im in enumerate(imgs):
        px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        a = px[:, :, 3:4]
        rgb = px[:, :, :3] * a + np.array(bg) * (1 - a)
        sheet[:, i * w:(i + 1) * w, :3] = rgb
        sheet[:, i * w:(i + 1) * w, 3] = 1
    out_img = bpy.data.images.new("sheet", w * len(imgs), h, alpha=True)
    out_img.pixels.foreach_set(sheet.ravel())
    out_img.filepath_raw = out
    out_img.file_format = "PNG"
    out_img.save()


# --------------------------------------------------------------- export

def export_glb(root, objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    kwargs = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                  export_apply=True, export_texcoords=True, export_normals=True,
                  export_materials="EXPORT", export_image_format="AUTO", export_cameras=False,
                  export_lights=False, export_animations=False, export_extras=False)
    supported = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    missing = set(kwargs) - set(supported)
    if missing:
        raise RuntimeError(f"Blender exporter lacks required options: {sorted(missing)}")
    if "export_tangents" in supported:
        kwargs["export_tangents"] = True
    bpy.ops.export_scene.gltf(**kwargs)


def reimport_check(path, expected, snapshots=None):
    reset()
    bpy.ops.import_scene.gltf(filepath=path)
    imported = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
    got = {name: len(o.data.polygons) for name, o in imported.items()}
    mism = {k: (v, got.get(k)) for k, v in expected.items() if got.get(k) != v}
    changes = {}
    for name, before in (snapshots or {}).items():
        if name not in imported:
            changes[name] = ["missing part"]
            continue
        obj = imported[name]
        me = obj.data.copy()
        me.transform(obj.matrix_world)
        temp = bpy.data.objects.new("AuditCopy", me)
        after = audit(temp)
        bpy.data.objects.remove(temp)
        bpy.data.meshes.remove(me)
        errors = []
        if not np.allclose(before["bounds"], after["bounds"], atol=2e-5, rtol=0):
            errors.append("bounds changed")
        if not math.isclose(before["signed_volume"], after["signed_volume"], abs_tol=1e-7, rel_tol=1e-4):
            errors.append("volume changed")
        for k in ("islands", "non_positive_islands", "non_manifold_edges", "zero_area_faces", "materials", "finite_uvs"):
            if before[k] != after[k]:
                errors.append(f"{k} changed")
        if corner_changes(before, obj):
            errors.append("UVs or shading normals changed")
        # Compare actual surface, not only counts/bounds. Snapshots are plain data
        # because reset destroys Blender datablocks.
        original = bpy.data.meshes.new("Original")
        original.from_pydata(before["positions"], [], before["faces"])
        current = obj.data.copy()
        current.transform(obj.matrix_world)
        # BVH nearest-point sampling is inexact on long obtuse slivers (it reports ~5e-5 for a mesh
        # against itself), so identical triangles are accepted first; sampling judges real changes.
        if face_set(original) != face_set(current) and surface_error(original, current) > 2e-5:
            errors.append("surface changed")
        bpy.data.meshes.remove(original)
        bpy.data.meshes.remove(current)
        if errors:
            changes[name] = errors
    return dict(meshes=len(got), triangle_mismatches=mism, unexpected_parts=sorted(set(got) - set(expected)), geometry_mismatches=changes)


def snapshots_for(objs):
    result = {}
    for o in objs:
        data = audit(o)
        data["positions"] = [(o.matrix_world @ v.co)[:] for v in o.data.vertices]
        data["faces"] = [p.vertices[:] for p in o.data.polygons]
        data["corners"] = [(o.data.vertices[loop.vertex_index].co[:], o.data.uv_layers.active.data[loop.index].uv[:], o.data.corner_normals[loop.index].vector[:]) for loop in o.data.loops]
        result[o.name] = data
    return result


def corner_changes(before, obj):
    """UV/normal seams may split vertices on import; compare corner attributes spatially."""
    from mathutils.kdtree import KDTree
    from mathutils import Vector
    corners = before["corners"]
    kd = KDTree(len(corners))
    for i, (pos, uv, normal) in enumerate(corners):
        kd.insert(pos, i)
    kd.balance()
    if not obj.data.uv_layers.active:
        return True
    for loop in obj.data.loops:
        pos = obj.matrix_world @ obj.data.vertices[loop.vertex_index].co
        uv = obj.data.uv_layers.active.data[loop.index].uv
        normal = obj.matrix_world.to_3x3() @ obj.data.corner_normals[loop.index].vector
        found = False
        for _, i, _ in kd.find_range(pos, 2e-5):
            _, old_uv, old_normal = corners[i]
            if (uv - Vector(old_uv)).length < 2e-5 and normal.dot(Vector(old_normal)) > 0.9999:
                found = True
                break
        if not found:
            return True
    return False


def render_views(objs, out_dir, snake, mode, res=1000, samples=96):
    """Both modes use matching measured framing; fidelity uses the reimported GLB."""
    scene = bpy.context.scene
    allv = np.asarray([(o.matrix_world @ v.co)[:] for o in objs for v in o.data.vertices])
    center = (allv.min(0) + allv.max(0)) / 2
    radius = max(np.linalg.norm(allv - center, axis=1).max(), 0.01)
    if mode == "beauty":
        for m in bpy.data.materials:
            if "render_garnish" in m:
                apply_render_garnish(m)
    cam = setup_render(scene, res, samples, fidelity=mode == "fidelity")
    distance = radius * 1.12 / math.sin(min(cam.data.angle_x, cam.data.angle_y) / 2)
    # Keep lighting relative to authored size for different silhouettes/heights.
    scale = radius / 1.7
    for obj in scene.objects:
        if obj.type == "LIGHT":
            obj.location *= scale
            obj.data.energy *= scale * scale
            obj.data.size *= scale
    paths = []
    for view in os.environ.get("FIG_VIEWS", ",".join(VIEWS)).split(","):
        az, el = VIEWS[view]
        aim(cam, az, el, dist=distance, target=center)
        p = os.path.join(out_dir, f"{snake}_{mode}_{view}.png")
        render_to(p, p.replace(".png", ".webp"))
        paths.append(p)
    return paths


# --------------------------------------------------------------- main

def main():
    global ROOT, PREVIEW, RENDER_VIEW
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        raise SystemExit("usage: build.py -- <collection|--fixture> <figure|lineup> [preview|final|fidelity]")
    collection, slug = argv[0], argv[1]
    mode = argv[2] if len(argv) > 2 else "preview"
    if mode not in ("preview", "final", "fidelity"):
        raise SystemExit("mode must be preview, final or fidelity")
    ROOT = os.path.join(REPO, "assets", os.environ.get("FIG_ASSETS", "figures"), collection)
    PREVIEW = os.path.join(REPO, "build", "figures", collection, "preview")
    os.makedirs(PREVIEW, exist_ok=True)
    sys.path.insert(0, ROOT)
    if collection == "--fixture":
        import importlib.util
        path = os.path.join(REPO, "tests", "fixtures", "figure_pipeline.py")
        loader = importlib.util.spec_from_file_location("figure_fixture", path)
        figures = importlib.util.module_from_spec(loader)
        loader.loader.exec_module(figures)
    else:
        import figures
    FIGURES = figures.FIGURES
    RENDER_VIEW = getattr(figures, "RENDER_VIEW", RENDER_VIEW)

    if slug == "lineup":
        return lineup(collection, list(FIGURES))
    base = os.path.join(REPO, "build", "figures", "pipeline-fixture", slug) if collection == "--fixture" else os.path.join(ROOT, slug)
    snake = slug.replace("-", "_")
    for sub in ("model", "renders", "validation"):
        os.makedirs(os.path.join(base, sub), exist_ok=True)

    reset()
    if mode == "fidelity":
        bpy.ops.import_scene.gltf(filepath=os.path.join(base, "model", f"{snake}_roblox.glb"))
        objs = [o for o in bpy.data.objects if o.type == "MESH"]
        render_views(objs, os.path.join(base, "renders"), snake, "fidelity")
        return

    # Definitions may prepare/bake native objects; do not reset after constructing them.
    spec = FIGURES[slug]()
    scene = bpy.context.scene
    col = bpy.data.collections.new(f"{spec['name']}_Production")
    scene.collection.children.link(col)
    t0 = time.time()
    root, objs, report, mats = build_figure(spec, col)
    print(f"built {spec['name']} in {time.time() - t0:.1f}s", flush=True)

    snapshots = snapshots_for(objs)
    if mode == "final":
        audits = {o.name: audit(o) for o in objs}
        allv = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in objs])
        size = (allv.max(0) - allv.min(0)).round(4).tolist()
        blend = os.path.join(base, "model", f"{snake}_production.blend")
        glb = os.path.join(base, "model", f"{snake}_roblox.glb")
        export_glb(root, objs, glb)
        bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
        expected = {o.name: len(o.data.polygons) for o in objs}
        summary = dict(
            schema_version=2,
            figure=spec["name"], title=spec["title"], rarity=spec["rarity"],
            size_xyz_studs=size, meshes=len(objs), triangles=sum(expected.values()),
            materials=sorted(mats.keys()), components=audits, build=report, glb=glb_summary(glb),
            # Runtime wiring data consumed by tools/figures/publish.py.
            catalog=spec.get("catalog"), root=spec["name"], face=f"{spec['name']}_Eyes",
            glass=[c.name for c in spec["comps"] if spec["mats"][c.mat].alpha < 1.0],
            constraints={c.name: dict(expected_islands=getattr(c, "expected_islands", None),
                         max_surface_error=getattr(c, "max_surface_error", None),
                         min_feature=getattr(c, "min_feature", None), voxel=c.voxel) for c in spec["comps"]},
        )
        summary["reimport"] = reimport_check(glb, expected, snapshots)
        print(json.dumps({k: summary[k] for k in ("size_xyz_studs", "meshes", "triangles", "reimport")}), flush=True)
        # Currently in the clean reimported scene; never garnish fidelity renders.
        res = int(os.environ.get("FIG_RENDER_RES", "1000"))
        samples = int(os.environ.get("FIG_RENDER_SAMPLES", "96"))
        paths = render_views([o for o in bpy.data.objects if o.type == "MESH"], os.path.join(base, "renders"), snake, "fidelity", res, samples)
        contact_sheet(paths, os.path.join(base, "renders", f"{snake}_fidelity_sheet.png"))
        summary["previews"] = dict(fidelity_source="exported_reimported_glb", fidelity_sha256=summary["glb"]["sha256"],
                                   fidelity_views=[os.path.basename(p) for p in paths], resolution=res,
                                   view_names=os.environ.get("FIG_VIEWS", ",".join(VIEWS)).split(","),
                                   disclaimer="Blender production fidelity preview; not a Roblox screenshot")
        bpy.ops.wm.open_mainfile(filepath=blend)
        objs = [o for o in bpy.data.objects if o.type == "MESH"]
        paths = render_views(objs, os.path.join(base, "renders"), snake, "beauty", res, samples)
        contact_sheet(paths, os.path.join(base, "renders", f"{snake}_beauty_sheet.png"))
        summary["previews"]["beauty_views"] = [os.path.basename(p) for p in paths]
        with open(os.path.join(base, "validation", f"{snake}_validation.json"), "w") as fh:
            json.dump(summary, fh, indent=2, allow_nan=False)
    else:
        paths = render_views(objs, PREVIEW, snake, "beauty", 420, 14)
        contact_sheet(paths, os.path.join(PREVIEW, f"{snake}_beauty_sheet{os.environ.get('FIG_TAG', '')}.png"))
    print("done", time.time() - t0, flush=True)


def lineup(collection, order, gap=0.9):
    """Every figure in catalogue order, at true relative scale, spaced by measured width."""
    reset()
    widths = []
    for slug in order:
        snake = slug.replace("-", "_")
        with open(os.path.join(ROOT, slug, "validation", f"{snake}_validation.json")) as fh:
            widths.append(json.load(fh)["size_xyz_studs"][0])
    total = sum(widths) + gap * (len(widths) - 1)
    xs, cursor = [], -total / 2
    for w in widths:
        xs.append(cursor + w / 2)
        cursor += w + gap
    scene = bpy.context.scene
    for slug, x in zip(order, xs):
        snake = slug.replace("-", "_")
        path = os.path.join(ROOT, slug, "model", f"{snake}_production.blend")
        with bpy.data.libraries.load(path) as (src, dst):
            dst.objects = list(src.objects)
        for o in dst.objects:
            if o is None:
                continue
            if o.type in ("MESH", "EMPTY") and o.name not in scene.objects:
                scene.collection.objects.link(o)
                if o.parent is None:
                    o.location.x += x
    for m in bpy.data.materials:
        if "render_garnish" in m:
            apply_render_garnish(m)
    cam = setup_render(scene, 1000, 96)
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 900
    cam.data.lens = 50
    aim(cam, -6.0, 7.0, dist=max(20.0, total * 1.55), target=(0.0, 0.0, 1.7))
    out = os.path.join(ROOT, f"{collection.replace('-', '_')}_lineup.png")
    render_to(out, out.replace(".png", ".webp"))


if __name__ == "__main__":
    main()
