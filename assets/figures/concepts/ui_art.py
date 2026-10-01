"""Render the Concepts collection UI artwork from the production figure models.

  blender -b --factory-startup --python assets/figures/concepts/ui_art.py

Writes transparent 1254x1254 PNGs matching the existing collection artwork contract:
  assets/ui/collection/concepts/concepts_emblem.png
  assets/ui/collection/concepts/concepts_corner_{top_left,top_right,bottom_left,bottom_right}.png
  assets/ui/shop/concepts/concepts_shop_pattern.png (seamlessly tileable)

Requires the four sphere figures' final builds (model/<figure>_production.blend). Each corner is
laid out in its own corner with upright faces, as the Pocket Grove and Tidepool corners are.
"""

import math
import os
import random
import sys

import bmesh
import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, "tools", "figures"))
import build  # noqa: E402  (render garnish helper only)

SIZE = 1254
GOLD = "#D4A520"
PALE_GOLD = "#F1D98A"
SPHERES = ("verity", "falsity", "cruelty", "lovity")
CENTRE_Z = 1.05  # sphere centre above each figure's root (ground) after grounding


def srgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4)) + (1.0,)


def material(name, hexstr, metal=0.0, rough=0.3, emit=0.0):
    mat = bpy.data.materials.new(name)
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = srgb(hexstr)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = 0.4
    if emit:
        bsdf.inputs["Emission Color"].default_value = srgb(hexstr)
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def load_figures():
    roots = {}
    for slug in SPHERES:
        path = os.path.join(HERE, slug, "model", f"{slug}_production.blend")
        with bpy.data.libraries.load(path) as (src, dst):
            dst.objects = list(src.objects)
        for o in dst.objects:
            if o is not None and o.parent is None and o.type == "EMPTY":
                roots[slug] = o
    for m in bpy.data.materials:
        if "render_garnish" in m:
            build.apply_render_garnish(m)
    return roots


class Stage:
    """Objects for one render; cleared before the next composition."""

    def __init__(self, roots):
        self.roots = roots
        self.objects = []

    def link(self, obj):
        bpy.context.scene.collection.objects.link(obj)
        self.objects.append(obj)
        return obj

    def sphere(self, slug, x, z, scale, turn=0.0, tilt=0.0):
        """A linked copy of a sphere figure with its centre at (x, z) in the picture plane."""
        src = self.roots[slug]
        root = self.link(src.copy())
        root.hide_render = False  # the originals are hidden; copies inherit the flag
        for child in src.children:
            c = self.link(child.copy())
            c.parent = root
            c.hide_render = False
        root.scale = (scale,) * 3
        root.rotation_euler = (math.radians(tilt), 0.0, math.radians(turn))
        offset = mathutils.Matrix.Rotation(math.radians(tilt), 3, "X") @ mathutils.Vector((0, 0, CENTRE_Z * scale))
        root.location = (x - offset.x, -offset.y, z - offset.z)
        return root

    def star(self, x, z, r, mat, y=-1.2, spin=0.0):
        """Four-point faceted sparkle facing the camera."""
        me = bpy.data.meshes.new("Sparkle")
        bm = bmesh.new()
        rim = []
        for i in range(8):
            a = math.radians(spin + i * 45.0)
            rr = r if i % 2 == 0 else r * 0.3
            rim.append(bm.verts.new((math.sin(a) * rr, 0.0, math.cos(a) * rr)))
        front, back = bm.verts.new((0, -r * 0.3, 0)), bm.verts.new((0, r * 0.12, 0))
        for i in range(8):
            a, b = rim[i], rim[(i + 1) % 8]
            bm.faces.new((front, a, b))
            bm.faces.new((back, b, a))
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        obj = self.link(bpy.data.objects.new("Sparkle", me))
        obj.location = (x, y, z)
        return obj

    def dot(self, x, z, r, mat, y=-1.2):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z), segments=24, ring_count=12)
        obj = bpy.context.active_object
        self.objects.append(obj)
        obj.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
        return obj

    def ribbon(self, points, radius, mat, y=0.6):
        """Smooth gold swoosh through picture-plane (x, z) points, behind the figures."""
        cu = bpy.data.curves.new("Ribbon", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = radius
        cu.bevel_resolution = 6
        cu.use_fill_caps = True
        sp = cu.splines.new("NURBS")
        sp.points.add(len(points) - 1)
        for pt, (x, z) in zip(sp.points, points):
            pt.co = (x, y, z, 1.0)
        sp.use_endpoint_u = True
        sp.order_u = 4
        sp.resolution_u = 24
        cu.materials.append(mat)
        return self.link(bpy.data.objects.new("Ribbon", cu))

    def ring(self, major, minor, tilt, mat, z=0.0):
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=128,
                                         minor_segments=24, location=(0, 0, z),
                                         rotation=(math.radians(tilt), 0, 0))
        obj = bpy.context.active_object
        self.objects.append(obj)
        obj.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
        return obj

    def clear(self):
        for o in reversed(self.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        self.objects = []


def setup(scale):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Khronos PBR Neutral"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = -0.8
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.95, 0.92, 0.85, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    scene.world = world

    def area(name, loc, energy, size):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy, ld.size = energy, size
        lo = bpy.data.objects.new(name, ld)
        scene.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = (-mathutils.Vector(loc)).to_track_quat("-Z", "Y").to_euler()

    area("Key", (-6.0, -9.0, 8.0), 3200, 6.0)
    area("Fill", (8.0, -7.0, 2.0), 1200, 8.0)
    area("Rim", (3.0, 8.0, 7.0), 1400, 5.0)
    cd = bpy.data.cameras.new("Cam")
    cd.type = "ORTHO"
    cd.ortho_scale = scale
    cam = bpy.data.objects.new("Cam", cd)
    scene.collection.objects.link(cam)
    cam.location = (0, -30, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam
    return cam


def render(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("wrote", path, flush=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    roots = load_figures()
    for root in roots.values():  # hide the originals; compositions use linked copies
        for o in [root, *root.children]:
            o.hide_render = True
    gold = material("Gold", GOLD, metal=1.0, rough=0.22)
    pale = material("PaleGold", PALE_GOLD, metal=0.6, rough=0.25, emit=0.4)
    stage = Stage(roots)
    ui = os.path.join(REPO, "assets", "ui")
    cam = setup(6.0)

    # Emblem: Verity inside a tilted gold orbit carrying the other three concepts.
    cam.data.ortho_scale = 5.4
    tilt, radius = math.radians(22.0), 2.1
    stage.ring(radius, 0.12, 22.0, gold, z=-0.1)
    stage.sphere("verity", 0.0, 0.0, 0.92, turn=-8)
    for slug, ang in (("falsity", 160.0), ("cruelty", 340.0), ("lovity", 215.0)):
        a = math.radians(ang)  # ring point (R cos a, R sin a, 0) tilted about X: back rises
        x, depth = radius * math.cos(a), radius * math.sin(a) * math.cos(tilt)
        orb = stage.sphere(slug, x, -0.1 + radius * math.sin(a) * math.sin(tilt), 0.34, turn=-x * 12)
        orb.location.y += depth - 0.5  # sit just in front of the ring so it never crosses a face
    stage.star(1.55, 1.55, 0.34, pale)
    stage.star(-1.75, 1.2, 0.2, pale, spin=20)
    render(os.path.join(ui, "collection", "concepts", "concepts_emblem.png"))
    stage.clear()

    # Corners: authored for the top-left, then laid out mirrored per corner with upright faces.
    cam.data.ortho_scale = 6.0
    layout = [
        ("verity", -1.95, 1.95, 0.72, 10),
        ("falsity", -0.25, 2.3, 0.42, -6),
        ("lovity", -2.3, 0.2, 0.4, 14),
        ("cruelty", 1.05, 2.55, 0.26, -10),
    ]
    swoosh = [(2.9, 2.75), (1.6, 2.15), (0.4, 1.5), (-0.9, 1.0), (-1.5, -0.1), (-2.0, -1.5), (-2.7, -2.9)]
    for name, sx, sz in (("top_left", 1, 1), ("top_right", -1, 1), ("bottom_left", 1, -1), ("bottom_right", -1, -1)):
        stage.ribbon([(sx * x, sz * z) for x, z in swoosh], 0.07, gold)
        for slug, x, z, s, turn in layout:
            stage.sphere(slug, sx * x, sz * z, s, turn=sx * turn)
        for x, z, r in ((0.6, 2.75, 0.2), (-2.75, -0.95, 0.17), (-0.95, 0.55, 0.24), (2.2, 2.2, 0.12)):
            stage.star(sx * x, sz * z, r, pale)
        for x, z, r in ((1.95, 2.55, 0.06), (-2.5, -1.85, 0.05), (-1.45, 0.95, 0.05)):
            stage.dot(sx * x, sz * z, r, gold)
        render(os.path.join(ui, "collection", "concepts", f"concepts_corner_{name}.png"))
        stage.clear()

    # Shop pattern: a jittered, seamlessly wrapping scatter of small concepts and sparkles.
    W = 8.0
    cam.data.ortho_scale = W
    rng = random.Random(7)
    items = []
    n = 4
    for row in range(n):
        for col in range(n):
            x = -W / 2 + (col + 0.5 + (0.5 if row % 2 else 0.0)) * W / n + rng.uniform(-0.25, 0.25)
            z = -W / 2 + (row + 0.5) * W / n + rng.uniform(-0.2, 0.2)
            items.append(("sphere", SPHERES[(row * 3 + col) % 4], x, z, rng.uniform(0.3, 0.38), rng.uniform(-25, 25)))
            items.append(("star", None, x + W / n * 0.5, z + W / n * 0.42, rng.uniform(0.13, 0.2), rng.uniform(0, 30)))
            items.append(("dot", None, x - W / n * 0.38, z + W / n * 0.4, 0.06, 0))
    for kind, slug, x, z, s, extra in items:
        x = (x + W / 2) % W - W / 2
        z = (z + W / 2) % W - W / 2
        for ox in (-W, 0.0, W):
            for oz in (-W, 0.0, W):
                px, pz = x + ox, z + oz
                if abs(px) > W / 2 + 0.6 or abs(pz) > W / 2 + 0.6:
                    continue
                if kind == "sphere":
                    stage.sphere(slug, px, pz, s, turn=extra)
                elif kind == "star":
                    stage.star(px, pz, s, pale, spin=extra)
                else:
                    stage.dot(px, pz, s, gold)
    render(os.path.join(ui, "shop", "concepts", "concepts_shop_pattern.png"))
    stage.clear()


main()
