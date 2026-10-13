"""Blender: isolate the main Cat from the Tripo image-to-3D export and save it in figure space.

blender -b --factory-startup --python prep_tripo.py -- <tripo.glb>
The Tripo export also modelled the sheet's small turnaround views and props; only the largest
connected island (the hero figure) is kept. Writes cat_tripo.glb (studs, faces -Y, grounded
centred), cat_tripo_basecolor.png (1024 px; Roblox's texture cap) and cat_tripo.json (eye anchor).
"""
import json
import os
import sys

import bmesh
import bpy

HEIGHT = 3.4  # studs, the previous Cat's height
TRIS = 18500  # under the 20,000 per-part limit; build.py then keeps the mesh as is
OUT = os.path.dirname(os.path.abspath(__file__))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[sys.argv.index("--") + 1])
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
obj.data.transform(obj.matrix_world)
obj.matrix_world.identity()

bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
seen, islands = set(), []
for f in bm.faces:
    if f in seen:
        continue
    stack, faces = [f], []
    seen.add(f)
    while stack:
        g = stack.pop()
        faces.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h not in seen:
                    seen.add(h)
                    stack.append(h)
    islands.append(faces)
keep = set(max(islands, key=len))
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")

zs = [v.co.z for v in bm.verts]
lo, hi = min(zs), max(zs)
s = HEIGHT / (hi - lo)
cx = (min(v.co.x for v in bm.verts) + max(v.co.x for v in bm.verts)) / 2
cy = (min(v.co.y for v in bm.verts) + max(v.co.y for v in bm.verts)) / 2
for v in bm.verts:
    v.co.x, v.co.y, v.co.z = (v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - lo) * s
bm.to_mesh(obj.data)
bm.free()

# Decimate here, not in build.py, so collapse damage (a few non-manifold fins) can be repaired:
# drop faces on bad edges, fill the holes, and borrow each filled corner's UV from its vertex.
mod = obj.modifiers.new("Decimate", "DECIMATE")
mod.ratio = TRIS / len(obj.data.polygons)
mod.use_collapse_triangulate = True
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = obj
bpy.ops.object.modifier_apply(modifier=mod.name)
bm = bmesh.new()
bm.from_mesh(obj.data)
uv = bm.loops.layers.uv.active
for _ in range(10):
    bad = [e for e in bm.edges if not e.is_manifold or not e.link_faces]
    if not bad:
        break
    bmesh.ops.delete(bm, geom=list({f for e in bad for f in e.link_faces}), context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    filled = bmesh.ops.holes_fill(bm, edges=bm.edges, sides=0)["faces"]
    tri = bmesh.ops.triangulate(bm, faces=filled)["faces"]
    for f in tri:
        for l in f.loops:
            other = next((o for o in l.vert.link_loops if o.face not in tri), None)
            if other is not None:
                l[uv].uv = other[uv].uv
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bad = sum(1 for e in bm.edges if not e.is_manifold)
bm.to_mesh(obj.data)
bm.free()
if bad:
    raise SystemExit(f"{bad} non-manifold edges remain after repair")
obj.name = obj.data.name = "CatTripo"

# Eye anchor: front-most face point on the centreline at eye height (about 57% of head-to-toe
# in the hero render), pushed inside the head so the hidden facing marker never shows.
eye_z = 0.58 * HEIGHT
near = [v.co for v in obj.data.vertices if abs(v.co.x) < 0.08 and abs(v.co.z - eye_z) < 0.08]
front = min(c.y for c in near)
json.dump(dict(eye=[0.0, front + 0.6, eye_z], scale=s, islands_dropped=len(islands) - 1,
               tris=len(obj.data.polygons)), open(os.path.join(OUT, "cat_tripo.json"), "w"), indent=1)

mat = obj.data.materials[0]
img = next(n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and "basecolor" in n.image.name)
img.scale(1024, 1024)
img.filepath_raw = os.path.join(OUT, "cat_tripo_basecolor.png")
img.file_format = "PNG"
img.save()

bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "cat_tripo.glb"), use_selection=True,
                          export_materials="NONE")
print("PREP", len(keep), "tris kept,", len(islands) - 1, "islands dropped", flush=True)
