"""Blender: prepare the Tripo Cat download as named source parts for tools/figures/external.py.

blender -b --factory-startup --python prep_tripo_source.py -- <tripo.glb> <out.glb>

Tripo was given the whole reference sheet, so the export also contains the sheet's small turnaround
copies and a prop. Keep only the largest connected island (the hero cat), then split it, without
changing any triangle's shape, into `Face` (eyes and nose patch: the importer's protected eyes object) and
`Body` (everything else, which the importer may optimize), with two importer-gate repairs below.
Prints the Z rotation that puts the Face
bounding centre in front of the figure's bounding centre, for the batch manifest.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 5, "tools", "figures"))
from import_blender import spread_degenerate_uvs  # noqa: E402

# Source units (Tripo export, before the importer's scaling), measured from front/side renders.
FACE_BOX = ((-0.02, -1.0, 0.705), (0.14, -0.08, 0.785))

src, dst = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
obj.data.transform(obj.matrix_world)
obj.matrix_world.identity()

bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)  # weld coincident seam vertices; UVs stay per corner
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
lo, hi = np.array(FACE_BOX[0]), np.array(FACE_BOX[1])
for f in bm.faces:
    c = np.array(f.calc_center_median())
    f.select = bool(np.all(c >= lo) and np.all(c <= hi))
bm.select_mode = {"FACE"}
bm.select_flush_mode()
bm.to_mesh(obj.data)
bm.free()

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.context.tool_settings.mesh_select_mode = (False, False, True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
face = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o is not obj)
obj.name, obj.data.name, face.name, face.data.name = "Body", "Body", "Face", "Face"
repairs = {}
for o in (obj, face):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    # A fin: an edge shared by 3+ faces (the importer's branch-edge gate). Drop the smallest extras.
    fins = set()
    for e in bm.edges:
        if len(e.link_faces) > 2:
            fins.update(sorted(e.link_faces, key=lambda f: f.calc_area())[:len(e.link_faces) - 2])
    bmesh.ops.delete(bm, geom=list(fins), context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    # Tripo exports some zero-UV-area triangles, which the importer's UV gate rejects.
    repairs[o.name] = dict(fins=len(fins), uv_spread=spread_degenerate_uvs(o.data))

body_v = np.array([v.co[:] for v in obj.data.vertices])
face_v = np.array([v.co[:] for v in face.data.vertices])
best = None
for tenth in range(-450, 451):
    a = math.radians(tenth / 10)
    rot = np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])
    allv, fv = np.vstack([body_v, face_v]) @ rot.T, face_v @ rot.T
    d = (fv.min(0) + fv.max(0) - allv.min(0) - allv.max(0)) / 2
    if d[1] < 0 and (best is None or abs(d[0]) / -d[1] < best[0]):
        best = (abs(d[0]) / -d[1], tenth / 10)
print(f"PREP kept {len(keep)} of {sum(map(len, islands))} triangles; Face {len(face.data.polygons)}, "
      f"Body {len(obj.data.polygons)}; repairs {repairs}; rotate Z {best[1]} deg (ratio {best[0]:.3f})", flush=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=dst, use_selection=True, export_format="GLB")
