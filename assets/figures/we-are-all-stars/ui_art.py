"""Render the We Are All Stars collection UI artwork from the production figure models.

  blender -b --factory-startup --python assets/figures/we-are-all-stars/ui_art.py

Writes transparent 1254x1254 PNGs matching the existing collection artwork contract:
  assets/ui/collection/we-are-all-stars/we_are_all_stars_emblem.png
  assets/ui/collection/we-are-all-stars/we_are_all_stars_corner_{top_left,top_right,bottom_left,bottom_right}.png
  assets/ui/shop/we-are-all-stars/we_are_all_stars_shop_pattern.png (seamlessly tileable)

Requires the figures' final builds (model/<figure>_production.blend). The motif is a night-sky
ring, puffy yellow and blush stars, round twinkle dots and a dotted shooting-star trail, in the
collection's shop palette. Copied from the Tender Echoes script (same Stage helpers and layout
rules); each corner is laid out in its own corner with upright figures.
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
BLUE = "#8FA7CF"
BLUSH = "#E8A9AE"
YELLOW = "#F2CF6B"
CREAM = "#F7F2E8"
FIGURES = ("mirrorlight", "wishing", "page-turner", "lamplight", "sanctuary", "echo", "garden", "reminiscence",
           "nightlight", "cloud-rest")


def srgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4)) + (1.0,)


def material(name, hexstr, metal=0.0, rough=0.6, coat=0.0):
    mat = bpy.data.materials.new(name)
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = srgb(hexstr)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = coat
    return mat


def load_figures():
    roots = {}
    for slug in FIGURES:
        snake = slug.replace("-", "_")
        path = os.path.join(HERE, slug, "model", f"{snake}_production.blend")
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

    def figure(self, slug, x, z, scale, turn=0.0, y=0.0):
        """A linked copy of a figure standing with its base at (x, z) in the picture plane."""
        src = self.roots[slug]
        root = self.link(src.copy())
        root.hide_render = False  # the originals are hidden; copies inherit the flag
        for child in src.children:
            c = self.link(child.copy())
            c.parent = root
            c.hide_render = False
        root.scale = (scale,) * 3
        root.rotation_euler = (0.0, 0.0, math.radians(turn))
        root.location = (x, y, z)
        return root

    def mesh(self, name, bm, mat, loc, rot=(0, 0, 0)):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        for poly in me.polygons:
            poly.use_smooth = True
        obj = self.link(bpy.data.objects.new(name, me))
        obj.location = loc
        obj.rotation_euler = tuple(math.radians(a) for a in rot)
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = 0.02
        mod.segments = 3
        return obj

    def puffy_star(self, x, z, r, mat, y=-1.4, spin=0.0):
        """Puffy five-point star facing the camera."""
        bm = bmesh.new()
        rim = []
        for i in range(10):
            a = math.radians(spin + i * 36.0)
            rr = r if i % 2 == 0 else r * 0.48
            rim.append((math.sin(a) * rr, math.cos(a) * rr))
        top = [bm.verts.new((u, -r * 0.12, v)) for u, v in rim]
        bot = [bm.verts.new((u, r * 0.12, v)) for u, v in rim]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for i in range(10):
            j = (i + 1) % 10
            bm.faces.new((top[i], bot[i], bot[j], top[j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self.mesh("PuffyStar", bm, mat, (x, y, z))

    def cross(self, x, z, s, mat, y=-1.4, spin=0.0):
        """A round twinkle dot (the role the cross-stitch plays in the Tender Echoes art)."""
        bpy.ops.mesh.primitive_uv_sphere_add(radius=s * 0.55, location=(x, y, z), segments=32, ring_count=16)
        obj = bpy.context.active_object
        self.objects.append(obj)
        obj.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
        return [obj]

    def thread(self, points, radius, mat, y=0.4, dash=0.07, gap=0.12):
        """Dotted shooting-star trail through picture-plane (x, z) points, behind the figures."""
        pts = [mathutils.Vector((x, y, z)) for x, z in points]
        samples = []
        for i in range(len(pts) - 1):
            p0 = pts[max(i - 1, 0)]
            p1, p2 = pts[i], pts[i + 1]
            p3 = pts[min(i + 2, len(pts) - 1)]
            for k in range(24):
                t = k / 24
                samples.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                      + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
        samples.append(pts[-1])
        travelled, on, start = 0.0, True, samples[0]
        for a, b in zip(samples[:-1], samples[1:]):
            travelled += (b - a).length
            if on and travelled >= dash:
                self._capsule(start, b, radius, mat)
                on, travelled = False, 0.0
            elif not on and travelled >= gap:
                on, travelled, start = True, 0.0, b

    def _capsule(self, a, b, radius, mat):
        mid = (a + b) / 2
        d = b - a
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=d.length, location=mid, vertices=12)
        obj = bpy.context.active_object
        obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        self.objects.append(obj)
        obj.data.materials.append(mat)
        bpy.ops.object.shade_smooth()

    def hoop(self, major, minor, mat, inner_mat, z=0.0):
        """Soft night-sky ring facing the camera, with a cream disc behind."""
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=160,
                                         minor_segments=24, location=(0, 0.3, z), rotation=(math.radians(90), 0, 0))
        ring = bpy.context.active_object
        self.objects.append(ring)
        ring.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
        bpy.ops.mesh.primitive_cylinder_add(radius=major, depth=0.04, location=(0, 0.45, z),
                                            rotation=(math.radians(90), 0, 0), vertices=160)
        cloth = bpy.context.active_object
        self.objects.append(cloth)
        cloth.data.materials.append(inner_mat)

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
    scene.view_settings.exposure = -0.9
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.95, 0.92, 0.86, 1)
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
    yellow = material("StarYellow", YELLOW, rough=0.4, coat=0.4)
    blush = material("Blush", BLUSH, rough=0.45, coat=0.3)
    ring = material("SkyRing", BLUE, rough=0.4, coat=0.3)
    cream = material("Cream", CREAM, rough=0.95)
    thread = material("Trail", BLUE, rough=0.5)
    stage = Stage(roots)
    ui = os.path.join(REPO, "assets", "ui")
    cam = setup(6.0)

    # Emblem: Wishing Star on her star seat inside a night-sky ring, with puffy stars and dots.
    cam.data.ortho_scale = 5.0
    only_corners = os.environ.get("UI_ART_SKIP_EMBLEM") == "1"
    if not only_corners:
        emblem(stage, yellow, blush, ring, cream, thread, ui)
    stage.clear()
    corners_and_pattern(stage, cam, yellow, blush, thread, ui)


def emblem(stage, yellow, blush, ring, cream, thread, ui):
    stage.hoop(2.05, 0.13, ring, cream, z=0.0)
    stage.figure("wishing", 0.0, -1.62, 0.9, turn=-10)
    stage.puffy_star(1.5, 1.45, 0.3, blush, spin=12)
    stage.puffy_star(-1.62, 1.05, 0.22, yellow, spin=-8)
    stage.puffy_star(1.72, -0.55, 0.18, yellow, spin=20)
    stage.cross(-1.5, -0.9, 0.13, thread)
    stage.cross(-0.95, 1.6, 0.1, thread, spin=10)
    render(os.path.join(ui, "collection", "we-are-all-stars", "we_are_all_stars_emblem.png"))


def corners_and_pattern(stage, cam, yellow, blush, thread, ui):
    # Corners: authored for the top-left, then mirrored per corner with upright figures.
    cam.data.ortho_scale = 6.0
    layout = [  # slug, x, base z, scale, turn
        ("sanctuary", -2.1, 0.5, 0.6, 12),
        ("page-turner", -0.45, 1.35, 0.44, -8),
        ("echo", -2.45, -1.15, 0.42, 16),
        ("lamplight", 1.0, 1.9, 0.3, -10),
    ]
    swoosh = [(2.9, 2.6), (1.7, 1.9), (0.5, 1.35), (-0.8, 0.7), (-1.4, -0.4), (-1.9, -1.8), (-2.7, -2.9)]
    for name, sx, sz in (("top_left", 1, 1), ("top_right", -1, 1), ("bottom_left", 1, -1), ("bottom_right", -1, -1)):
        stage.thread([(sx * x, sz * z) for x, z in swoosh], 0.035, thread)
        for slug, x, z, s, turn in layout:
            fz = z if sz > 0 else -z - 3.2 * s  # keep the figure's footprint in the same corner area
            stage.figure(slug, sx * x, fz, s, turn=sx * turn)
        for x, z, r, mat in ((0.35, 2.75, 0.2, blush), (-2.75, -2.1, 0.17, yellow), (-0.95, 0.5, 0.2, yellow),
                             (2.25, 2.25, 0.13, blush)):
            stage.puffy_star(sx * x, sz * z, r, mat, spin=sx * 10)
        for x, z in ((1.75, 2.75), (-2.75, 0.2), (-1.45, 1.05)):
            stage.cross(sx * x, sz * z, 0.09, thread)
        render(os.path.join(ui, "collection", "we-are-all-stars", f"we_are_all_stars_corner_{name}.png"))
        stage.clear()

    if os.environ.get("UI_ART_SKIP_PATTERN") == "1":
        return
    # Shop pattern: a jittered, seamlessly wrapping scatter of small figures, puffy stars and dots.
    W = 8.0
    cam.data.ortho_scale = W
    rng = random.Random(11)
    items = []
    n = 4
    pool = list(FIGURES)
    for row in range(n):
        for col in range(n):
            x = -W / 2 + (col + 0.5 + (0.5 if row % 2 else 0.0)) * W / n + rng.uniform(-0.2, 0.2)
            z = -W / 2 + (row + 0.5) * W / n + rng.uniform(-0.15, 0.15)
            items.append(("figure", pool[(row * 3 + col) % len(pool)], x, z, rng.uniform(0.28, 0.32), rng.uniform(-20, 20)))
            items.append(("star", yellow if (row + col) % 2 else blush, x + W / n * 0.5, z + W / n * 0.42,
                          rng.uniform(0.12, 0.17), rng.uniform(0, 30)))
            items.append(("cross", thread, x - W / n * 0.4, z + W / n * 0.38, 0.07, 0))
    for kind, what, x, z, s, extra in items:
        x = (x + W / 2) % W - W / 2
        z = (z + W / 2) % W - W / 2
        for ox in (-W, 0.0, W):
            for oz in (-W, 0.0, W):
                px, pz = x + ox, z + oz
                if abs(px) > W / 2 + 0.7 or abs(pz) > W / 2 + 0.7:
                    continue
                if kind == "figure":
                    stage.figure(what, px, pz - 1.6 * s, s, turn=extra)  # centred on (px, pz)
                elif kind == "star":
                    stage.puffy_star(px, pz, s, what, spin=extra)
                else:
                    stage.cross(px, pz, s, what)
    render(os.path.join(ui, "shop", "we-are-all-stars", "we_are_all_stars_shop_pattern.png"))
    stage.clear()


main()
