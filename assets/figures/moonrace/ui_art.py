"""Render the Moonrace collection UI artwork from the production figure models.

  blender -b --factory-startup --python assets/figures/moonrace/ui_art.py

Writes transparent 1254x1254 PNGs matching the existing collection artwork contract:
  assets/ui/collection/moonrace/moonrace_emblem.png
  assets/ui/collection/moonrace/moonrace_corner_{top_left,top_right,bottom_left,bottom_right}.png
  assets/ui/shop/moonrace/moonrace_shop_pattern.png (seamlessly tileable)

Requires the figures' final builds (model/<figure>_production.blend). The motif is a gold moon hoop
with a lacquer-red face, cream puff clouds, gold coins with square holes and small red lanterns, in
the collection's shop palette. Copied from the We Are All Stars script (same Stage helpers and layout
rules). The Mythical Cat is the secret chase figure, so it never appears in this artwork.
"""

import math
import os
import random
import sys

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, "tools", "figures"))
import build  # noqa: E402  (render garnish helper only)

SIZE = 1254
RED = "#C8372D"
GOLD = "#E4B24C"
CREAM = "#FBF0E2"
FIGURES = ("rat", "ox", "rabbit", "snake", "horse", "goat", "monkey", "rooster", "dog", "pig", "tiger", "dragon")


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
        path = os.path.join(HERE, slug, "model", f"{slug.replace('-', '_')}_production.blend")
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

    def _add(self, obj, mat):
        self.objects.append(obj)
        obj.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
        return obj

    def cloud(self, x, z, r, mat, y=-1.4):
        """Puffy cream cloud: three overlapping balls on a flat-bottomed puff."""
        for dx, dz, s in ((0.0, 0.1, 1.0), (-0.75, -0.08, 0.72), (0.75, -0.1, 0.68), (-0.35, -0.2, 0.7), (0.4, -0.22, 0.66)):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=r * s, location=(x + dx * r, y, z + dz * r), segments=32,
                                                 ring_count=16)
            self._add(bpy.context.active_object, mat)

    def coin(self, x, z, r, mat, y=-1.4, spin=0.0):
        """Gold coin facing the camera with a raised rim and a square hole (boolean)."""
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=r * 0.2, location=(x, y, z),
                                            rotation=(math.radians(90), 0, 0), vertices=64)
        disc = self._add(bpy.context.active_object, mat)
        bpy.ops.mesh.primitive_cube_add(size=r * 0.45, location=(x, y, z), rotation=(0, math.radians(45 + spin), 0))
        hole = bpy.context.active_object
        hole.scale.y = 3.0
        hole.hide_render = True
        self.objects.append(hole)
        mod = disc.modifiers.new("Hole", "BOOLEAN")
        mod.operation, mod.object = "DIFFERENCE", hole
        bev = disc.modifiers.new("Bevel", "BEVEL")
        bev.width, bev.segments = r * 0.04, 2
        bpy.ops.mesh.primitive_torus_add(major_radius=r * 0.9, minor_radius=r * 0.08, location=(x, y - r * 0.08, z),
                                         rotation=(math.radians(90), 0, 0))
        self._add(bpy.context.active_object, mat)
        return disc

    def lantern(self, x, z, r, red, gold, y=-1.4):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z), segments=32, ring_count=16)
        body = self._add(bpy.context.active_object, red)
        body.scale = (1.0, 1.0, 0.86)
        for dz in (r * 0.86, -r * 0.86):
            bpy.ops.mesh.primitive_cylinder_add(radius=r * 0.45, depth=r * 0.22, location=(x, y, z + dz), vertices=32)
            self._add(bpy.context.active_object, gold)
        bpy.ops.mesh.primitive_cone_add(radius1=r * 0.12, radius2=r * 0.3, depth=r * 0.9,
                                        location=(x, y, z - r * 1.45), vertices=24)
        self._add(bpy.context.active_object, red)

    def hoop(self, major, minor, mat, inner_mat, z=0.0):
        """Gold full-moon ring facing the camera, with a lacquer-red face behind."""
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=160,
                                         minor_segments=24, location=(0, 0.3, z), rotation=(math.radians(90), 0, 0))
        self._add(bpy.context.active_object, mat)
        bpy.ops.mesh.primitive_cylinder_add(radius=major, depth=0.04, location=(0, 0.45, z),
                                            rotation=(math.radians(90), 0, 0), vertices=160)
        self.objects.append(bpy.context.active_object)
        bpy.context.active_object.data.materials.append(inner_mat)

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
    gold = material("Gold", GOLD, metal=0.45, rough=0.3, coat=0.3)
    red = material("Lacquer", RED, rough=0.4, coat=0.5)
    cream = material("Cloud", CREAM, rough=0.7)
    stage = Stage(roots)
    ui = os.path.join(REPO, "assets", "ui")
    cam = setup(5.0)
    if os.environ.get("UI_ART_SKIP_EMBLEM") != "1":
        emblem(stage, gold, red, cream, ui)
    stage.clear()
    corners_and_pattern(stage, cam, gold, red, cream, ui)


def emblem(stage, gold, red, cream, ui):
    # Emblem: the Rabbit before a gold full moon, on a cloud, with a coin and a lantern.
    stage.hoop(2.0, 0.14, gold, red, z=0.1)
    stage.cloud(0.0, -1.72, 0.55, cream)
    stage.figure("rabbit", 0.0, -1.78, 0.98, turn=-12)
    stage.coin(-1.55, 1.25, 0.3, gold, spin=8)
    stage.lantern(1.62, 1.2, 0.26, red, gold)
    stage.cloud(1.55, -1.0, 0.24, cream)
    render(os.path.join(ui, "collection", "moonrace", "moonrace_emblem.png"))


def corners_and_pattern(stage, cam, gold, red, cream, ui):
    # Corners: authored for the top-left, then mirrored per corner with upright figures.
    cam.data.ortho_scale = 6.0
    layout = [  # slug, x, base z, scale, turn
        ("tiger", -2.0, 0.45, 0.5, 14),
        ("rat", -0.45, 1.4, 0.44, -8),
        ("pig", -2.5, -1.2, 0.42, 16),
        ("rooster", 0.95, 1.95, 0.32, -10),
    ]
    for name, sx, sz in (("top_left", 1, 1), ("top_right", -1, 1), ("bottom_left", 1, -1), ("bottom_right", -1, -1)):
        for slug, x, z, s, turn in layout:
            fz = z if sz > 0 else -z - 3.2 * s  # keep the figure's footprint in the same corner area
            stage.figure(slug, sx * x, fz, s, turn=sx * turn)
        for x, z, r in ((0.35, 2.7, 0.2), (-2.7, -2.15, 0.17), (2.3, 2.3, 0.14)):
            stage.coin(sx * x, sz * z, r, gold, spin=sx * 10)
        for x, z, r in ((-1.0, 0.5, 0.2), (-2.75, 0.3, 0.16)):
            stage.cloud(sx * x, sz * z, r, cream)
        stage.lantern(sx * 1.75, sz * 2.7, 0.15, red, gold)
        render(os.path.join(ui, "collection", "moonrace", f"moonrace_corner_{name}.png"))
        stage.clear()

    if os.environ.get("UI_ART_SKIP_PATTERN") == "1":
        return
    # Shop pattern: a jittered, seamlessly wrapping scatter of small figures, coins and clouds.
    W = 8.0
    cam.data.ortho_scale = W
    rng = random.Random(13)
    items = []
    n = 4
    pool = list(FIGURES)
    for row in range(n):
        for col in range(n):
            x = -W / 2 + (col + 0.5 + (0.5 if row % 2 else 0.0)) * W / n + rng.uniform(-0.2, 0.2)
            z = -W / 2 + (row + 0.5) * W / n + rng.uniform(-0.15, 0.15)
            items.append(("figure", pool[(row * 5 + col) % len(pool)], x, z, rng.uniform(0.27, 0.31), rng.uniform(-20, 20)))
            items.append(("coin" if (row + col) % 2 else "lantern", None, x + W / n * 0.5, z + W / n * 0.42,
                          rng.uniform(0.11, 0.15), rng.uniform(0, 30)))
            items.append(("cloud", None, x - W / n * 0.4, z + W / n * 0.38, 0.1, 0))
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
                elif kind == "coin":
                    stage.coin(px, pz, s, gold, spin=extra)
                elif kind == "lantern":
                    stage.lantern(px, pz, s * 0.8, red, gold)
                else:
                    stage.cloud(px, pz, s, cream)
    render(os.path.join(ui, "shop", "moonrace", "moonrace_shop_pattern.png"))
    stage.clear()


main()
