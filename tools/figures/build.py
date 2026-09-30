"""Build, validate, export and render collectible figures inside Blender.

Each collection defines its figures in assets/figures/<collection>/figures.py (a FIGURES dict of
figure slug -> builder, using sdf.py from this folder). See docs/FIGURE_COLLECTION_RUNBOOK.md.

Usage (from the repository root):
  blender -b --factory-startup --python tools/figures/build.py -- <collection> <figure> [mode]
  blender -b --factory-startup --python tools/figures/build.py -- <collection> lineup

mode: preview (default, fast contact sheet in build/figures/<collection>/preview/) or final
      (meshes, .blend, GLB, validation, renders). lineup renders every figure in the collection
      side by side from their production .blend files.
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


ROOT = ""  # assets/figures/<collection>, set by main()
PREVIEW = ""  # build/figures/<collection>/preview (ignored scratch)
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
    nb = [(n[i] - 1) // BLOCK for i in range(3)]
    centers = [lo[i] + (np.arange(nb[i]) + 0.5) * BLOCK * v for i in range(3)]
    cg = np.meshgrid(*centers, indexing="ij")
    dc = fn((cg[0], cg[1], cg[2]))
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
    b = find_bounds(comp.fn, *bounds)
    if b is None:
        raise RuntimeError(f"{comp.name}: empty SDF inside figure bounds")
    lo, hi = b
    arr, act, tot = evaluate(comp.fn, lo, hi, comp.voxel)
    g = vdb.FloatGrid()
    g.background = float(arr.max())
    g.copyFromArray(arr)
    pts, quads = g.convertToQuads(isovalue=0.0)
    verts = lo[None, :] + pts.astype(np.float64) * comp.voxel
    return verts, quads, dict(active_blocks=act, blocks=tot, grid=list(arr.shape))


def build_object(comp, bounds, collection):
    t0 = time.time()
    verts, quads, info = sdf_to_mesh(comp, bounds)
    me = bpy.data.meshes.new(comp.name)
    me.from_pydata(verts.tolist(), [], quads.tolist())
    me.validate()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(comp.name, me)
    collection.objects.link(obj)
    raw_tris = len(me.polygons) * 2
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
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    info.update(raw_tris=raw_tris, removed_faces=removed, seconds=round(time.time() - t0, 1))
    return obj, info


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
    tex.image = make_image(name, colors, m.alpha)
    tex.interpolation = "Linear"
    tex.extension = "EXTEND"
    tex.location = (-400, 200)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if m.alpha < 1.0:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.surface_render_method = "BLENDED"
    bsdf.inputs["Roughness"].default_value = m.rough
    bsdf.inputs["Metallic"].default_value = m.metal
    mat["render_garnish"] = json.dumps(m.render)
    return mat


def apply_render_garnish(mat):
    """Render-only extras that preview what Studio will show via gloss/transparency."""
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


def set_uvs(obj, ramp):
    me = obj.data
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
    non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    zero = sum(1 for f in bm.faces if f.calc_area() < 1e-10)
    vol = bm.calc_volume(signed=True)
    tris = len(bm.faces)
    bm.free()
    return dict(tris=tris, verts=len(obj.data.vertices), non_manifold_edges=non_manifold,
                boundary_edges=boundary, zero_area_faces=zero, signed_volume=round(vol, 5))


# --------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def build_figure(spec, collection):
    mats = {name: make_material(name, m) for name, m in spec["mats"].items()}
    objs, report = [], {}
    for comp in spec["comps"]:
        obj, info = build_object(comp, spec["bounds"], collection)
        set_uvs(obj, comp.ramp)
        obj.data.materials.append(mats[comp.mat])
        objs.append(obj)
        report[comp.name] = info
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


def setup_render(scene, res, samples):
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
    vt, look, expo = os.environ.get("FIG_VIEW", "AgX|AgX - Punchy|-0.35").split("|")
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
    while True:
        try:
            bpy.ops.export_scene.gltf(**kwargs)
            return
        except TypeError as exc:
            bad = [k for k in kwargs if f'"{k}"' in str(exc)]
            if not bad:
                raise
            kwargs.pop(bad[0])


def glb_summary(path):
    import struct
    with open(path, "rb") as fh:
        data = fh.read()
    jlen = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + jlen])
    mats = doc.get("materials", [])
    return dict(
        bytes=len(data),
        nodes=[n.get("name") for n in doc.get("nodes", [])],
        meshes=len(doc.get("meshes", [])),
        materials=len(mats),
        images=len(doc.get("images", [])),
        textures=len(doc.get("textures", [])),
        all_materials_textured=all("baseColorTexture" in m.get("pbrMetallicRoughness", {}) for m in mats),
        extensions_required=doc.get("extensionsRequired", []),
        extensions_used=doc.get("extensionsUsed", []),
    )


def reimport_check(path, expected):
    reset()
    bpy.ops.import_scene.gltf(filepath=path)
    got = {o.name.split(".")[0]: len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH"}
    mism = {k: (v, got.get(k)) for k, v in expected.items() if got.get(k) != v}
    return dict(meshes=len(got), triangle_mismatches=mism)


# --------------------------------------------------------------- main

def main():
    global ROOT, PREVIEW
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        raise SystemExit("usage: build.py -- <collection> <figure|lineup> [preview|final]")
    collection, slug = argv[0], argv[1]
    mode = argv[2] if len(argv) > 2 else "preview"
    ROOT = os.path.join(REPO, "assets", "figures", collection)
    PREVIEW = os.path.join(REPO, "build", "figures", collection, "preview")
    os.makedirs(PREVIEW, exist_ok=True)
    sys.path.insert(0, ROOT)
    from figures import FIGURES

    if slug == "lineup":
        return lineup(collection, list(FIGURES))
    spec = FIGURES[slug]()
    base = os.path.join(ROOT, slug)
    snake = slug.replace("-", "_")
    for sub in ("model", "renders", "validation"):
        os.makedirs(os.path.join(base, sub), exist_ok=True)

    reset()
    scene = bpy.context.scene
    col = bpy.data.collections.new(f"{spec['name']}_Production")
    scene.collection.children.link(col)
    t0 = time.time()
    root, objs, report, mats = build_figure(spec, col)
    print(f"built {spec['name']} in {time.time() - t0:.1f}s", flush=True)

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
            figure=spec["name"], title=spec["title"], rarity=spec["rarity"],
            size_xyz_studs=size, meshes=len(objs), triangles=sum(expected.values()),
            materials=sorted(mats.keys()), components=audits, build=report, glb=glb_summary(glb),
            # Runtime wiring data consumed by tools/figures/publish.py.
            catalog=spec.get("catalog"), root=spec["name"], face=f"{spec['name']}_Eyes",
            glass=[c.name for c in spec["comps"] if spec["mats"][c.mat].alpha < 1.0],
        )
        summary["reimport"] = reimport_check(glb, expected)
        with open(os.path.join(base, "validation", f"{snake}_validation.json"), "w") as fh:
            json.dump(summary, fh, indent=2)
        print(json.dumps({k: summary[k] for k in ("size_xyz_studs", "meshes", "triangles", "reimport")}), flush=True)
        bpy.ops.wm.open_mainfile(filepath=blend)
        scene = bpy.context.scene
        res, samples = 1000, 96
    else:
        res, samples = 420, 14

    for m in bpy.data.materials:
        if "render_garnish" in m:
            apply_render_garnish(m)
    cam = setup_render(scene, res, samples)
    out_dir = os.path.join(base, "renders") if mode == "final" else PREVIEW
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    views = {k: VIEWS[k] for k in os.environ.get("FIG_VIEWS", ",".join(VIEWS)).split(",")}
    for view, (az, el) in views.items():
        aim(cam, az, el)
        p = os.path.join(out_dir, f"{snake}_{view}.png")
        render_to(p, p.replace(".png", ".webp") if mode == "final" else None)
        paths.append(p)
    if mode == "final":
        aim(cam, -30.0, 11.0, dist=10.2, target=(0.0, 0.0, 1.45))
        p = os.path.join(out_dir, f"{snake}_beauty.png")
        render_to(p, p.replace(".png", ".webp"))
    contact_sheet(paths, os.path.join(PREVIEW, f"{snake}_sheet{os.environ.get('FIG_TAG', '')}.png"))
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
