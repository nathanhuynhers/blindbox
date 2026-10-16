"""Blender: facing and eyes.region for a single-mesh GLB from one marked pixel between the eyes.

The runtime aims each figure from its bounding-box centre to `<Root>_Eyes`, so the import rotation
must make that vector point to -Y. Given the reference_paint.py hero camera (az, el) and the pixel
between the eyes in its 768 px `paint_hero.png`, this ray-casts the face point, then iterates the yaw
so the bounding centre of the selected face patch is straight in front. Prints a JSON line with
`rotation_degrees` and `eyes.region` for the external batch manifest; it changes no files.

  blender -b --factory-startup --python tools/figures/face_patch.py -- <in.glb> <az> <el> <px> <py>
"""
import bpy, sys, math, json, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

glb, az, el, px, py = sys.argv[sys.argv.index("--") + 1:]
az, el, px, py = float(az), float(el), float(px), float(py)
RES, HALF = 768, (0.08, 0.07)  # paint_hero.png size; patch half-width (x) and half-height (z), normalized

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
o = next(x for x in bpy.context.scene.objects if x.type == "MESH")
co = np.array([o.matrix_world @ v.co for v in o.data.vertices])
tris = np.array([p.vertices[:] for p in o.data.polygons])
lo, hi = co.min(0), co.max(0); centre = Vector((lo + hi) / 2); size = float((hi - lo).max())

# Same orthographic camera as reference_paint.py: centred on the bounds, ortho_scale size * 1.8.
a, e = math.radians(az), math.radians(el)
d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
q = (-d).to_track_quat("-Z", "Y")
right, up = q @ Vector((1, 0, 0)), q @ Vector((0, 1, 0))
origin = centre + d * size * 5 + right * (px / RES - 0.5) * size * 1.8 + up * (0.5 - py / RES) * size * 1.8
bvh = BVHTree.FromPolygons([Vector(c) for c in co], tris.tolist())
hit = bvh.ray_cast(origin, -d)[0]
assert hit is not None, "marked pixel does not hit the mesh"
E = np.array(hit)


def rot(p, t):
    c, s = math.cos(math.radians(t)), math.sin(math.radians(t))
    return np.stack([p[..., 0] * c - p[..., 1] * s, p[..., 0] * s + p[..., 1] * c, p[..., 2]], -1)


centres = co[tris].mean(1)
theta = 0.0
for _ in range(12):
    r = rot(co, theta); rlo, rhi = r.min(0), r.max(0); ext = rhi - rlo
    en = (rot(E, theta) - rlo) / ext
    region = [[max(0.0, en[0] - HALF[0]), 0.0, max(0.0, en[2] - HALF[1])], [min(1.0, en[0] + HALF[0]), min(1.0, en[1] + 0.06), min(1.0, en[2] + HALF[1])]]
    pos = (rot(centres, theta) - rlo) / ext
    sel = np.all((pos >= region[0]) & (pos <= region[1]), 1)
    pv = r[np.unique(tris[sel])]
    delta = (pv.min(0) + pv.max(0) - rlo - rhi) / 2
    yaw = math.degrees(math.atan2(delta[0], -delta[1]))
    theta -= yaw
    if abs(yaw) < 0.05: break
theta = (theta + 180) % 360 - 180
ok = bool(delta[1] < -0.001 and abs(delta[0]) <= -delta[1] * 0.15)
print("FACE", json.dumps(dict(rotation_degrees=[0, 0, round(float(theta), 2)], region=[[round(float(v), 4) for v in region[0]], [round(float(v), 4) for v in region[1]]],
                              patch_triangles=int(sel.sum()), residual_yaw=round(float(yaw), 3), facing_valid=ok)), flush=True)
