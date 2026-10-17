"""Render the "Unlock 5th Display" / "Unlock 6th Display" gamepass icons.

  blender -b --factory-startup --python assets/ui/gamepasses/display_pass_icons.py

Writes 512x512 opaque PNGs next to this file ("Unlock 5th Display.png", "Unlock 6th Display.png"):
a violet sunburst like the other pass icons, the glossy Display navigation icon, and a big gold
slot number. Roblox crops pass icons to a circle, so every element stays inside a centred
circle of radius 0.46 (no edge text to clip).
"""

import math
import os

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
SIZE = 512
FONT = "C:/Windows/Fonts/seguibl.ttf"
PLUM = (0x2D, 0x1A, 0x4C)


def linear(rgb):
    return tuple((c / 255) ** 2.2 for c in rgb)


def sunburst():
    """Display-space RGBA background: radial violet gradient, soft rays and sparkles."""
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    cx = cy = (SIZE - 1) / 2
    dx, dy = (x - cx) / SIZE, (y - cy) / SIZE
    r = np.sqrt(dx * dx + dy * dy) / 0.71
    inner, outer = np.array([0xC9, 0x9C, 0xFF]) / 255, np.array([0x5E, 0x2E, 0xD6]) / 255
    t = np.clip(r, 0, 1)[..., None] ** 0.9
    rgb = inner * (1 - t) + outer * t
    angle = np.arctan2(dy, dx)
    rays = (np.cos(angle * 16) > 0.35).astype(np.float32) * np.clip(1 - r * 0.9, 0, 1) * 0.13
    rgb = rgb + rays[..., None]
    for sx, sy, s in ((0.2, 0.25, 0.05), (0.8, 0.22, 0.04), (0.18, 0.7, 0.035), (0.84, 0.62, 0.03)):
        px, py = (x / SIZE - sx) / s, (y / SIZE - sy) / s
        star = np.clip(1 - (np.abs(px) ** 0.5 + np.abs(py) ** 0.5), 0, 1)
        rgb = rgb + star[..., None] * 1.4
    out = np.ones((SIZE, SIZE, 4), dtype=np.float32)
    out[..., :3] = np.clip(rgb, 0, 1)
    return out


def load_rgba(path, size):
    img = bpy.data.images.load(path, check_existing=False)
    img.scale(size, size)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)
    return px[::-1]  # Blender rows run bottom-up


def over(base, layer, x0, y0):
    h, w = layer.shape[:2]
    region = base[y0:y0 + h, x0:x0 + w]
    a = layer[..., 3:4]
    region[..., :3] = layer[..., :3] * a + region[..., :3] * (1 - a)
    region[..., 3:4] = a + region[..., 3:4] * (1 - a)


def render_number(number, path):
    """The slot number alone: flat white chunky glyph on transparency (outlined in 2D later)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.render.resolution_x = scene.render.resolution_y = 400
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    bpy.ops.object.text_add(rotation=(math.pi / 2, 0, 0))
    text = bpy.context.active_object
    text.data.body = str(number)
    text.data.font = bpy.data.fonts.load(FONT)
    text.data.align_x, text.data.align_y = "CENTER", "CENTER"
    text.data.size = 1.0
    ink = bpy.data.materials.new("Ink")
    ink.use_nodes = True
    nodes = ink.node_tree.nodes
    nodes.clear()
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (1, 1, 1, 1)
    out = nodes.new("ShaderNodeOutputMaterial")
    ink.node_tree.links.new(emit.outputs[0], out.inputs["Surface"])
    text.data.materials.append(ink)
    cam = bpy.data.cameras.new("C")
    cam.type, cam.ortho_scale = "ORTHO", 1.25
    cam_obj = bpy.data.objects.new("C", cam)
    scene.collection.objects.link(cam_obj)
    cam_obj.location, cam_obj.rotation_euler = (0, -6, 0.04), (math.pi / 2, 0, 0)
    scene.camera = cam_obj
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def coin(size):
    """Glossy gold disc: radial gold gradient, cream inner ring, top highlight (display RGBA)."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    r = np.sqrt((x - c) ** 2 + (y - c) ** 2) / (size / 2)
    light, deep = np.array([0xFF, 0xE2, 0x6E]) / 255, np.array([0xF5, 0xA8, 0x1C]) / 255
    shade = np.clip((y / size) * 0.8 + r * 0.35, 0, 1)[..., None]
    rgb = light * (1 - shade) + deep * shade
    ring = (np.abs(r - 0.8) < 0.035)[..., None]
    rgb = np.where(ring, np.array([0xFF, 0xF4, 0xC8]) / 255, rgb)
    gloss = np.clip(1 - np.sqrt(((x - c) / (size * 0.32)) ** 2 + ((y - size * 0.28) / (size * 0.12)) ** 2), 0, 1)
    rgb = rgb + gloss[..., None] * 0.35
    out = np.zeros((size, size, 4), dtype=np.float32)
    out[..., :3] = np.clip(rgb, 0, 1)
    out[..., 3] = np.clip((1 - r) * size / 2, 0, 1)  # anti-aliased edge
    return out


def outline(layer, px):
    """Grow a plum silhouette around a transparent layer, like the navigation icons."""
    alpha = layer[..., 3]
    grown = alpha.copy()
    for dy in range(-px, px + 1):
        for dx in range(-px, px + 1):
            if dx * dx + dy * dy <= px * px:
                grown = np.maximum(grown, np.roll(np.roll(alpha, dy, 0), dx, 1))
    plum = np.array(PLUM, dtype=np.float32) / 255
    out = np.empty_like(layer)
    a, g = alpha[..., None], grown[..., None]
    out[..., :3] = (layer[..., :3] * a + plum * (g - a)) / np.maximum(g, 1e-4)
    out[..., 3] = grown
    return out


def save(rgba, path):
    img = bpy.data.images.new("out", SIZE, SIZE, alpha=True)
    img.pixels[:] = rgba[::-1].ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def main():
    scratch = os.path.join(REPO, "build", "display_pass_icons")
    os.makedirs(scratch, exist_ok=True)
    for number, label in ((5, "5th"), (6, "6th")):
        number_path = os.path.join(scratch, f"number_{number}.png")
        render_number(number, number_path)
        base = sunburst()
        icon = load_rgba(os.path.join(REPO, "assets", "ui", "navigation", "display_navigation_icon.png"), 330)
        over(base, icon, 70, 62)
        badge = coin(170)
        glyph = outline(load_rgba(number_path, 130), 7)
        over(badge, glyph, 20, 20)
        over(base, outline(np.pad(badge, ((8, 8), (8, 8), (0, 0))), 6), 266, 254)
        save(base, os.path.join(HERE, f"Unlock {label} Display.png"))
        print("WROTE", label)


main()
