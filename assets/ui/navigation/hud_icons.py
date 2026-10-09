"""Render the HUD Daily and Home icons to match the glossy navigation icon set.

  blender -b --factory-startup --python assets/ui/navigation/hud_icons.py -- [daily|home|all] [preview|final]

final writes transparent 1254x1254 PNGs next to this file (daily_navigation_icon.png,
home_navigation_icon.png), the same framing as the five dock icons. preview renders at 400px and
writes phone-size checks (32 and 44px) into build/hud_icons/ (ignored scratch).

Look: chunky bevelled toy shapes, glossy coat, lavender/violet and white with warm wood and gold
accents, a dark plum inverted-hull outline on every part plus one thick plum outline around the
whole silhouette, and a few outlined sparkles. Bold silhouettes only: they must read at 28-32px.
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
SIZE = 1254

PLUM = "#2D1A4C"
LAVENDER = "#BCA2FB"
LILAC = "#E6DCFF"
VIOLET = "#8A64EC"
DEEP = "#6A45D8"
WHITE = "#FBF8FF"
WOOD = "#D7A06A"
WOOD_DARK = "#A86E3E"
GOLD = "#FFCF4D"
PINK = "#FF9CC6"


def srgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4)) + (1.0,)


MATS = {}


def mat(hexstr, rough=0.28, coat=0.7, emit=0.0):
    key = (hexstr, rough, coat, emit)
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(hexstr)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = srgb(hexstr)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = 0.08
    if emit:
        bsdf.inputs["Emission Color"].default_value = srgb(hexstr)
        bsdf.inputs["Emission Strength"].default_value = emit
    MATS[key] = m
    return m


def outline_material():
    """Plum hull whose camera-facing (flipped) faces are clear: the classic inverted hull."""
    m = bpy.data.materials.new("Outline")
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    geo = nodes.new("ShaderNodeNewGeometry")
    mix = nodes.new("ShaderNodeMixShader")
    clear = nodes.new("ShaderNodeBsdfTransparent")
    ink = nodes.new("ShaderNodeEmission")
    ink.inputs["Color"].default_value = srgb(PLUM)
    links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    links.new(ink.outputs[0], mix.inputs[1])
    links.new(clear.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])
    return m


OUTLINE = None
PARTS = []
# Inverted hulls occlude Freestyle's visibility tests (dashed lines), so Freestyle draws the
# part lines and a dilated silhouette draws the outer outline. Kept as a switch for comparison.
HULL = False


def finish(obj, material, outline=0.055, soft=True):
    obj.data.materials.append(material)
    obj.data.materials.append(OUTLINE)
    if soft:
        obj.modifiers.new("Soft", "SUBSURF").levels = 2
        obj.modifiers["Soft"].render_levels = 2
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if outline and HULL:
        hull = obj.modifiers.new("Outline", "SOLIDIFY")
        hull.thickness = outline
        hull.offset = 1.0
        hull.use_rim = False
        hull.material_offset = 1
    PARTS.append(obj)
    return obj


def link(name, me):
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def rbox(name, size, loc, material, bevel=0.12, rot=(0, 0, 0), outline=0.055):
    """Rounded box: bevelled cube softened by subdivision."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES", profile=0.5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(name, me)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    return finish(obj, material, outline)


def slab(name, outline2d, depth, loc, material, bevel=0.05, rot=(0, 0, 0), outline=0.055):
    """A 2D outline in the XZ plane (facing the camera) extruded along Y, edges rounded."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in outline2d]
    face = bm.faces.new(front)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.y += depth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    side = [e for e in bm.edges if abs(e.verts[0].co.y - e.verts[1].co.y) < 1e-6]
    bmesh.ops.bevel(bm, geom=side, offset=bevel, segments=4, affect="EDGES", profile=0.5, clamp_overlap=True)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(name, me)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    return finish(obj, material, outline, soft=False)


def ball(name, radius, loc, material, scale=(1, 1, 1), rot=(0, 0, 0), outline=0.055):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=radius)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(name, me)
    obj.location, obj.scale = loc, scale
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    return finish(obj, material, outline, soft=False)


def ring(name, big, small, loc, material, scale=(1, 1, 1), rot=(0, 0, 0), outline=0.055):
    bpy.ops.mesh.primitive_torus_add(major_radius=big, minor_radius=small, major_segments=40, minor_segments=16)
    obj = bpy.context.active_object
    obj.name = name
    obj.location, obj.scale = loc, scale
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    return finish(obj, material, outline, soft=False)


def cylinder(name, radius, depth, loc, material, rot=(90, 0, 0), bevel=0.04, outline=0.055):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=40, radius1=radius, radius2=radius, depth=depth)
    rim = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6]
    bmesh.ops.bevel(bm, geom=rim, offset=bevel, segments=4, affect="EDGES", profile=0.5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(name, me)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    return finish(obj, material, outline, soft=False)


def star_points(r, inner=0.48, points=5, spin=0.0):
    out = []
    for i in range(points * 2):
        a = math.radians(spin + 90 + i * 180 / points)
        rr = r if i % 2 == 0 else r * inner
        out.append((math.cos(a) * rr, math.sin(a) * rr))
    return out


def heart_points(r, n=26):
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        out.append((x * r / 16, z * r / 16))
    return out[::-1]


def sparkle(name, r, loc, material):
    return slab(name, star_points(r, inner=0.44, points=4), r * 0.35, loc, material, bevel=r * 0.12, outline=0.03)


def wedge(name, loc, angle, length, material):
    """Rounded 'emphasis' tick radiating from a point, like the Shop and Goals bursts."""
    w = length * 0.42
    pts = [(-w / 2, 0), (w / 2, 0), (w * 0.22, -length), (-w * 0.22, -length)]
    return slab(name, pts, 0.12, loc, material, bevel=w * 0.24, rot=(0, -angle, 0), outline=0.03)


# ------------------------------------------------------------------ icons

def build_daily():
    """A gift box with a big bow and a calendar page clipped to its front."""
    body = mat(VIOLET)
    lid = mat(LAVENDER)
    ribbon = mat(WHITE)
    rbox("Body", (1.72, 1.5, 1.22), (0, 0, 0.62), body, bevel=0.14)
    rbox("Lid", (1.96, 1.72, 0.42), (0, 0, 1.36), lid, bevel=0.14)
    rbox("RibbonFront", (0.38, 1.56, 1.3), (0, 0, 0.62), ribbon, bevel=0.08, outline=0.025)
    rbox("RibbonLid", (0.42, 1.78, 0.48), (0, 0, 1.36), ribbon, bevel=0.08, outline=0.025)
    # Bow: two open loops (the holes make it read as a bow, not a cloud) and a knot.
    bow = mat(DEEP)
    for side in (-1, 1):
        ring(f"Loop{side}", 0.36, 0.13, (side * 0.4, 0, 1.86), bow, scale=(1.2, 1, 0.85), rot=(90, side * -30, 0))
    ball("Knot", 0.2, (0, -0.02, 1.74), bow, scale=(1, 0.9, 0.95))
    # Calendar page clipped to the front, tilted for life.
    page = rbox("Page", (1.05, 0.14, 1.0), (0.38, -0.86, 0.6), mat(WHITE), bevel=0.1, rot=(0, -8, 0))
    header = rbox("PageHeader", (1.07, 0.18, 0.3), (0.42, -0.9, 0.98), mat(DEEP), bevel=0.08, rot=(0, -8, 0))
    for x in (0.16, 0.66):
        cylinder("Ring", 0.07, 0.24, (x + 0.04, -0.93, 1.16), mat(PLUM, rough=0.4), rot=(0, -8, 0), bevel=0.02, outline=0.0)
    slab("Day", star_points(0.25), 0.1, (0.37, -1.02, 0.52), mat(GOLD), bevel=0.04, rot=(0, -8, 0), outline=0.028)
    del page, header
    sparkle("Sparkle1", 0.36, (1.5, -0.2, 2.05), mat(LILAC, rough=0.2))
    sparkle("Sparkle2", 0.26, (-1.45, -0.2, 1.9), mat(LILAC, rough=0.2))


def build_home():
    """A cozy cottage on a wooden plinth: pitched roof, heart gable, round door, striped awning."""
    walls = mat(WHITE)
    roof = mat(VIOLET)
    # Plinth like the Shop icon's: wood on a deep plum-violet base.
    rbox("Base", (2.5, 1.75, 0.22), (0, 0, -0.04), mat(DEEP), bevel=0.1)
    rbox("Deck", (2.36, 1.62, 0.2), (0, 0, 0.13), mat(WOOD), bevel=0.08)
    # House: a pentagon prism so the gable is part of the white wall.
    w, h, peak = 1.62, 1.08, 1.86
    house = [(-w / 2, 0), (w / 2, 0), (w / 2, h), (0, peak), (-w / 2, h)]
    slab("House", house, 1.25, (0, 0, 0.22), walls, bevel=0.1)
    # Roof: two chunky slabs meeting at the ridge, with eaves.
    pitch = math.degrees(math.atan2(peak - h, w / 2))
    run = math.hypot(w / 2, peak - h) + 0.36
    for side in (-1, 1):
        rbox(
            f"Roof{side}",
            (run, 1.55, 0.26),
            (side * (w / 4 + 0.1), 0, 0.22 + (h + peak) / 2 + 0.14),
            roof,
            bevel=0.11,
            rot=(0, side * pitch, 0),
        )
    rbox("Chimney", (0.3, 0.3, 0.5), (0.52, 0.15, 0.22 + peak - 0.05), mat(WOOD_DARK), bevel=0.06)
    # Heart on the gable.
    slab("Heart", heart_points(0.27), 0.14, (0, -0.68, 0.22 + h + 0.3), mat(PINK), bevel=0.025, outline=0.028)
    # Round-top wooden door with a gold knob.
    door = [(-0.27, 0), (0.27, 0)] + [(math.cos(a) * 0.27, 0.36 + math.sin(a) * 0.27) for a in np.linspace(0, math.pi, 14)]
    slab("Door", door, 0.12, (0, -0.64, 0.24), mat(WOOD), bevel=0.04, outline=0.028)
    ball("Knob", 0.07, (0.15, -0.72, 0.56), mat(GOLD), outline=0.0)
    # Striped awning over the door: alternating violet / white stripes, scalloped hem.
    count, span = 5, 1.5
    stripe = span / count
    drop = math.degrees(math.atan2(0.26, 0.42))
    for i in range(count):
        x = -span / 2 + stripe * (i + 0.5)
        m = mat(VIOLET if i % 2 == 0 else WHITE)
        rbox(f"Stripe{i}", (stripe, 0.5, 0.08), (x, -0.86, 1.13), m, bevel=0.035, rot=(drop, 0, 0))
        ball(f"Scallop{i}", stripe * 0.5, (x, -1.07, 0.99), m, scale=(1, 0.4, 0.75))
    sparkle("Sparkle1", 0.34, (1.45, -0.2, 2.15), mat(LILAC, rough=0.2))
    sparkle("Sparkle2", 0.25, (-1.42, -0.2, 2.0), mat(LILAC, rough=0.2))


ICONS = {"daily": build_daily, "home": build_home}


# ------------------------------------------------------------------ render

def stage(size):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64 if size > 600 else 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    # Freestyle draws the plum lines between parts that an inverted hull cannot show.
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = size / 1254 * 7.5
    lineset = scene.view_layers[0].freestyle_settings.linesets[0]
    lineset.select_by_visibility = True
    lineset.select_silhouette = True
    lineset.select_border = True
    lineset.select_crease = False
    lineset.select_material_boundary = True
    if lineset.linestyle is None:
        lineset.linestyle = bpy.data.linestyles.new("Plum")
    lineset.linestyle.color = srgb(PLUM)[:3]
    lineset.linestyle.caps = "ROUND"
    scene.view_layers[0].freestyle_settings.use_smoothness = True
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = srgb("#EFE8FF")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.85
    scene.world = world
    for name, loc, energy, size_ in (
        ("Key", (-4, -6, 7), 900, 5),
        ("Fill", (6, -5, 2), 260, 6),
        ("Rim", (2, 6, 6), 500, 4),
    ):
        light = bpy.data.lights.new(name, "AREA")
        light.energy, light.size = energy, size_
        obj = link(name, light)
        obj.location = loc
        obj.rotation_euler = (Vector((0, 0, 0.9)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.cameras.new("Camera")
    cam.lens = 70
    cam_obj = link("Camera", cam)
    scene.camera = cam_obj
    return scene, cam_obj


def frame(cam_obj, scene):
    """Aim a 3/4 high camera and fit every part's bounds to ~86% of the square."""
    bpy.context.view_layer.update()
    pts = []
    for obj in PARTS:
        pts += [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    centre = (lo + hi) / 2
    direction = Vector((0.42, -1.0, 0.36)).normalized()
    radius = (hi - lo).length / 2
    distance = radius / math.tan(math.atan(18 / cam_obj.data.lens) * 0.86)
    cam_obj.location = centre + direction * distance
    cam_obj.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    # Recentre on the projected silhouette so the art sits in the middle like the dock icons.
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()
    xs, ys = [], []
    for p in pts:
        v = world_to_camera_view(scene, cam_obj, p)
        xs.append(v.x)
        ys.append(v.y)
    zoom = 0.84 / max(max(xs) - min(xs), max(ys) - min(ys))
    cam_obj.data.lens *= zoom
    cam_obj.data.shift_x = ((min(xs) + max(xs)) / 2 - 0.5) * zoom
    cam_obj.data.shift_y = ((min(ys) + max(ys)) / 2 - 0.5) * zoom


def silhouette_outline(path, px):
    """Thick plum outline around the whole silhouette, like the reference set."""
    img = bpy.data.images.load(path)
    w, h = img.size
    rgba = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    alpha = rgba[..., 3]
    grown = alpha.copy()
    r = int(px)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                grown = np.maximum(grown, np.roll(np.roll(alpha, dy, 0), dx, 1))
    plum = np.array(srgb(PLUM)[:3], dtype=np.float32)
    plum = plum ** (1 / 2.2)  # pixels of a loaded PNG are display (sRGB) values
    a = alpha[..., None]
    out = np.empty_like(rgba)
    g = grown[..., None]
    out[..., :3] = (rgba[..., :3] * a + plum * (g - a)) / np.maximum(g, 1e-4)
    out[..., 3] = grown
    img.pixels[:] = out.ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def shrink(img, path, size):
    small = img.copy()
    small.scale(size, size)
    small.filepath_raw = path
    small.file_format = "PNG"
    small.save()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    which = argv[0] if argv else "all"
    mode = argv[1] if len(argv) > 1 else "preview"
    names = list(ICONS) if which == "all" else [which]
    scratch = os.path.join(REPO, "build", "hud_icons")
    os.makedirs(scratch, exist_ok=True)
    for name in names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        global OUTLINE
        MATS.clear()
        PARTS.clear()
        OUTLINE = outline_material()
        size = SIZE if mode == "final" else 400
        scene, cam = stage(size)
        ICONS[name]()
        frame(cam, scene)
        path = (
            os.path.join(HERE, f"{name}_navigation_icon.png")
            if mode == "final"
            else os.path.join(scratch, f"{name}_preview.png")
        )
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        img = silhouette_outline(path, size * 0.01)
        for px in (32, 44):
            shrink(bpy.data.images.load(path, check_existing=False), os.path.join(scratch, f"{name}_{px}.png"), px)
        print("WROTE", path)


main()
