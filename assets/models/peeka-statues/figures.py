"""Peeka statues: the Blindbox Town mascot in four poses, pastel marble with gold trim.

Town decoration only (not a catalog figure). Built with tools/figures/build.py:
  FIG_ASSETS=models blender -b --factory-startup --python tools/figures/build.py -- peeka-statues <slug> final
Units are studs at model scale. +Z is up, the statue faces -Y, the character's left is +X.
The town scales each statue so the pedestal is 12 studs across.
"""

import math
import os

import numpy as np

from sdf import (
    arc2, cylinder, ellipse2, ellipsoid, frame, overlay, rot, round_box, round_cone, smax, smin,
    sphere, tube,
)

RENDER_VIEW = "Khronos PBR Neutral|None|-1.1"


class Mat:
    def __init__(self, color, rough=0.5, metal=0.0, alpha=1.0, **render):
        self.color = color
        self.rough = rough
        self.metal = metal
        self.alpha = alpha
        self.render = render


class Comp:
    def __init__(self, name, fn, mat, voxel=0.012, tris=6000, ramp=None, min_faces=24):
        self.name = name
        self.fn = fn
        self.mat = mat
        self.voxel = voxel
        self.tris = tris
        self.ramp = ramp
        self.min_faces = min_faces


SCALE = 1.22  # authored at box size, scaled to the collection's ~3-stud figure height


def scaled(fn, s=SCALE):
    return lambda p: fn((p[0] / s, p[1] / s, p[2] / s)) * s


def assemble(name, title, rarity, comps, bounds, **info):
    materials = {}
    bounds = tuple(tuple(v * SCALE for v in corner) for corner in bounds)
    for c in comps:
        c.fn = scaled(c.fn)
        mname, m = c.mat
        materials[mname] = m
        c.mat = mname
    return dict(name=name, title=title, rarity=rarity, comps=comps, mats=materials, bounds=bounds, **info)


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


# ------------------------------------------------------------------ palette

MARBLE = {
    "mint": ("#DDF0E3", "#B7DCC3", "#7FA88C"),
    "sky": ("#DCEBF5", "#B3D2E6", "#7698B0"),
    "lilac": ("#E9E2F6", "#CDBFEA", "#8F80B8"),
    "butter": ("#F7EDD2", "#EAD49A", "#A88C4C"),
}


def palette(prefix, finish="color", tint="lilac"):
    if finish == "marble":
        light, mid, carve = MARBLE[tint]
        stone = dict(rough=0.32, coat=0.35)
        gold = Mat("#E2B45E", rough=0.28, metal=0.85)
        return {
            "fur": (f"{prefix}_Marble", Mat(light, **stone)),
            "ear": (f"{prefix}_MarbleShade", Mat(mid, **stone)),
            "box": (f"{prefix}_MarbleBox", Mat(mid, **stone)),
            "lid": (f"{prefix}_MarbleLid", Mat(mid, **stone)),
            "gold": (f"{prefix}_Gold", gold),
            "mark": (f"{prefix}_GoldMark", gold),
            "eyes": (f"{prefix}_Carve", Mat(carve, rough=0.5)),
            "shine": (f"{prefix}_CarveShine", Mat(light, rough=0.4)),
            "cheeks": (f"{prefix}_CarveCheek", Mat(mid, rough=0.4)),
            "mouth": (f"{prefix}_CarveMouth", Mat(carve, rough=0.5)),
            "nose": (f"{prefix}_CarveNose", Mat(carve, rough=0.5)),
            "pad": (f"{prefix}_CarvePad", Mat(mid, rough=0.4)),
            "dots": (f"{prefix}_GoldDots", gold),
        }
    return {
        "fur": (f"{prefix}_Fur", Mat("#FFF3E4", rough=0.62, coat=0.12, sheen=0.4)),
        "ear": (f"{prefix}_InnerEar", Mat("#F7B9CC", rough=0.55, coat=0.1)),
        "box": (f"{prefix}_Box", Mat("#EF8DB4", rough=0.42, coat=0.35)),
        "lid": (f"{prefix}_Lid", Mat("#DC6A9A", rough=0.42, coat=0.35)),
        "gold": (f"{prefix}_Ribbon", Mat("#F5C866", rough=0.32, coat=0.4)),
        "mark": (f"{prefix}_QuestionMark", Mat("#FFFDF8", rough=0.4, coat=0.3)),
        "eyes": (f"{prefix}_EyeGloss", Mat("#2A1D22", rough=0.15, coat=0.7)),
        "shine": (f"{prefix}_EyeShine", Mat("#FFFFFF", rough=0.3)),
        "cheeks": (f"{prefix}_Blush", Mat("#F6A3B4", rough=0.6)),
        "mouth": (f"{prefix}_Mouth", Mat("#4A2A30", rough=0.4)),
        "nose": (f"{prefix}_Nose", Mat("#E77D9C", rough=0.35, coat=0.4)),
        "pad": (f"{prefix}_PawPad", Mat("#F7B9CC", rough=0.55)),
        "dots": (f"{prefix}_BoxDots", Mat("#FAD0E1", rough=0.42, coat=0.35)),
    }


# ------------------------------------------------------------------ shared parts

HEAD_C = np.array([0.0, -0.02, 1.5])
HEAD_R = (0.68, 0.58, 0.6)
BOX_HALF = 0.64
BOX_TOP = 1.16


def head_sdf(p, c=HEAD_C):
    skull = ellipsoid(p, c, HEAD_R)
    # Soft fluffy cheeks widen the lower face a little.
    for sx in (-1, 1):
        skull = smin(skull, ellipsoid(p, c + np.array([sx * 0.3, -0.16, -0.2]), (0.32, 0.3, 0.27)), 0.12)
    return skull


def fluff(p, c=HEAD_C):
    """Three soft forehead tufts under the lid brim."""
    d = None
    for x, lean in ((-0.13, -18), (0.04, 6), (0.2, 24)):
        tip = c + np.array([x + 0.08 * math.sin(math.radians(lean)), -0.48, 0.5])
        base = c + np.array([x, -0.36, 0.38])
        t = round_cone(p, base, tip, 0.09, 0.025)
        d = t if d is None else smin(d, t, 0.03)
    return d


def ear_up(p, root, lean=14, length=0.86):
    d = unit((math.sin(math.radians(lean)), 0.04, math.cos(math.radians(lean))))
    R = frame(d)
    c1 = root + d * (0.24 * length)
    c2 = root + d * (0.6 * length)
    a = ellipsoid(p, c1, (0.085, 0.17, 0.3 * length), R)
    b = ellipsoid(p, c2, (0.075, 0.155, 0.36 * length), R)
    # The tip curls gently forward.
    tip_dir = unit(d + np.array([0.0, -0.9, -0.2]))
    tip = ellipsoid(p, root + d * (0.9 * length) + tip_dir * 0.07, (0.065, 0.13, 0.12), frame(tip_dir))
    return smin(smin(a, b, 0.08), tip, 0.06), (c2, R)


def ear_flop(p, root, side=-1):
    """Rises out of the head, then folds over and hangs to the side."""
    dA = unit((0.55 * side, 0.03, 0.83))
    dB = unit((0.42 * side, -0.06, -0.9))
    RA, RB = frame(dA), frame(dB)
    cA = root + dA * 0.17
    bend = root + dA * 0.33
    cB = bend + dB * 0.33
    a = ellipsoid(p, cA, (0.085, 0.17, 0.26), RA)
    b = ellipsoid(p, cB, (0.075, 0.155, 0.36), RB)
    knee = sphere(p, bend, 0.12)
    return smin(smin(a, knee, 0.1), b, 0.1), (cB, RB)


def inner_ear(base_fn, center, R, scale=1.0):
    def region(p):
        inside = ellipsoid(p, center, (0.2, 0.1 * scale, 0.29 * scale), R)
        return np.maximum(inside, p[1] - (center[1] - 0.025))
    return lambda p: overlay(base_fn(p), region(p), 0.006, depth=0.03, k=0.004)


def question_2d(u, v, s=1.0):
    """A chunky '?' glyph centred near the origin, size about 0.6 * s tall."""
    u, v = u / s, v / s
    cx, cz, R, t = 0.0, 0.11, 0.13, 0.055
    ang = np.arctan2(v - cz, u - cx)
    ring = np.abs(np.sqrt((u - cx) ** 2 + (v - cz) ** 2) - R) - t
    # Remove the lower-left quarter of the ring to open the hook.
    ring = np.where((ang < -math.pi / 2 + 0.25) & (ang > -math.pi), 1.0, ring)
    stem = np.maximum(np.abs(u) - t, np.abs(v + 0.035) - 0.075)
    hook_end = np.sqrt(u**2 + (v + 0.0) ** 2) - t
    dot = np.sqrt(u**2 + (v + 0.24) ** 2) - 0.07
    return np.minimum(np.minimum(np.minimum(ring, stem), hook_end), dot) * s


def box_sdf(p, center=(0.0, 0.0, 0.0), half=BOX_HALF, top=BOX_TOP, recess=True):
    cx, cy, cz = center
    h = top / 2
    d = round_box(p, (cx, cy, cz + h), (half, half, h), 0.07)
    lip = round_box(p, (cx, cy, cz + top - 0.04), (half + 0.035, half + 0.035, 0.05), 0.035)
    d = smin(d, lip, 0.01)
    if recess:
        d = smax(d, -round_box(p, (cx, cy, cz + top + 0.02), (half - 0.07, half - 0.07, 0.24), 0.05), 0.02)
    return d


def box_marks(box_fn, center=(0.0, 0.0, 0.0), half=BOX_HALF, z=0.48, size=1.0):
    cx, cy, cz = center

    def fn(p):
        x, y, zz = p[0] - cx, p[1] - cy, p[2] - (cz + z)
        regions = [
            np.maximum(question_2d(x, zz, size), y + half - 0.12),  # front (-Y)
            np.maximum(question_2d(-x, zz, size), -y + half - 0.12),  # back (+Y)
            np.maximum(question_2d(-y, zz, size), x + half - 0.12),  # character's right (-X)
            np.maximum(question_2d(y, zz, size), -x + half - 0.12),  # character's left (+X)
        ]
        region = np.minimum(np.minimum(regions[0], regions[1]), np.minimum(regions[2], regions[3]))
        return overlay(box_fn(p), region, 0.012, depth=0.05, k=0.004)

    return fn


def box_dots(box_fn, center=(0.0, 0.0, 0.0), half=BOX_HALF, top=BOX_TOP):
    cx, cy, cz = center
    su, sz = half / BOX_HALF, top / BOX_TOP
    spots = [(-0.46, 0.2, 0.055), (0.47, 0.26, 0.045), (-0.44, 0.74, 0.045), (0.45, 0.7, 0.055),
             (-0.27, 0.08, 0.035), (0.28, 0.86, 0.035)]
    pts = []
    for u, z, r in spots:
        u, z = u * su, z * sz
        for face_pt in ((u, -half, z), (-u, half, z), (-half, -u, z), (half, u, z)):
            pts.append(((cx + face_pt[0], cy + face_pt[1], cz + face_pt[2]), r))

    def fn(p):
        region = None
        for c, r in pts:
            d = sphere(p, c, r + 0.02)
            region = d if region is None else np.minimum(region, d)
        return overlay(box_fn(p), region, 0.01, depth=0.04, k=0.003)

    return fn


def box_ribbon(box_fn, center=(0.0, 0.0, 0.0), z=0.98, width=0.075):
    cz = center[2]

    def fn(p):
        region = np.abs(p[2] - (cz + z)) - width
        return overlay(box_fn(p), region, 0.014, depth=0.05, k=0.004)

    return fn


def lid_parts(center, R, half=0.4):
    c = np.asarray(center, float)

    def lid(p):
        slab = round_box(p, c, (half, half, 0.075), 0.045, R)
        lip = round_box(p, c + R @ np.array([0, 0, -0.06]), (half + 0.03, half + 0.03, 0.04), 0.03, R)
        return smin(slab, lip, 0.01)

    def ribbon(p):
        x, y, _ = (R.T @ np.stack([p[0] - c[0], p[1] - c[1], p[2] - c[2]]).reshape(3, -1)).reshape((3,) + np.shape(p[0]))
        region = np.minimum(np.abs(x) - 0.06, np.abs(y) - 0.06)
        return overlay(lid(p), region, 0.012, depth=0.05, k=0.004)

    top = c + R @ np.array([0, 0, 0.1])

    def bow(p):
        knot = ellipsoid(p, top + R @ np.array([0, 0, 0.02]), (0.08, 0.07, 0.065), R)
        d = knot
        for sx in (-1, 1):
            Rl = R @ rot(ry=sx * 28)
            loop = ellipsoid(p, top + R @ np.array([sx * 0.15, 0.0, 0.07]), (0.15, 0.07, 0.085), Rl)
            hole = ellipsoid(p, top + R @ np.array([sx * 0.16, -0.06, 0.075]), (0.07, 0.06, 0.035), Rl)
            d = smin(d, smax(loop, -hole, 0.01), 0.03)
            tail = tube(p, [top + R @ np.array([sx * 0.04, -0.02, 0.0]),
                            top + R @ np.array([sx * 0.13, -0.12, -0.05]),
                            top + R @ np.array([sx * 0.2, -0.2, -0.13])], [0.035, 0.03, 0.028])
            d = smin(d, tail, 0.02)
        return d

    return lid, ribbon, bow


def face(prefix, base, mats, cx=0.0, eye_z=1.45, eye_dx=0.225, ylim=-0.25, closed=False, open_mouth=False):
    eye_r = (0.078, 0.102)
    ru, rv = eye_r

    def eye_region(p, ox=0.0, oz=0.0, su=1.0, sv=1.0):
        regs = [ellipse2(p[0] - (cx + sx * eye_dx + ox), p[2] - (eye_z + oz), ru * su, rv * sv) for sx in (-1, 1)]
        return np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim)

    comps = []
    if closed:
        def eyes(p):
            regs = [arc2(p[0] - (cx + sx * eye_dx), -(p[2] - eye_z) + 0.05, 0.06, 62, 0.017) for sx in (-1, 1)]
            region = np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim)
            return overlay(base(p), region, 0.01, depth=0.04, k=0.002)
        comps.append(Comp(f"{prefix}_Eyes", eyes, mats["eyes"], voxel=0.004, tris=900))
    else:
        def dome(p):
            out = np.zeros_like(p[0])
            for sx in (-1, 1):
                q = ((p[0] - (cx + sx * eye_dx)) / ru) ** 2 + ((p[2] - eye_z) / rv) ** 2
                out = np.maximum(out, 0.026 * np.clip(1 - q, 0, 1))
            return 0.012 + out

        def eyes(p):
            return overlay(base(p), eye_region(p), dome(p), depth=0.05, k=0.004)

        def shine(p):
            big = eye_region(p, ox=-0.3 * ru, oz=0.36 * rv, su=0.34, sv=0.3)
            small = eye_region(p, ox=0.32 * ru, oz=-0.38 * rv, su=0.15, sv=0.14)
            return overlay(base(p) - dome(p), np.minimum(big, small), 0.007, depth=0.02, k=0.002)

        comps.append(Comp(f"{prefix}_Eyes", eyes, mats["eyes"], voxel=0.0045, tris=1400))
        comps.append(Comp(f"{prefix}_EyeShine", shine, mats["shine"], voxel=0.0035, tris=500))

    def cheeks(p):
        regs = [ellipse2(p[0] - (cx + sx * 0.37), p[2] - (eye_z - 0.13), 0.085, 0.052) for sx in (-1, 1)]
        return overlay(base(p), np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim), 0.007, depth=0.04, k=0.004)

    def nose(p):
        region = np.maximum(ellipse2(p[0] - cx, p[2] - (eye_z - 0.1), 0.032, 0.022), p[1] - ylim)
        return overlay(base(p), region, 0.012, depth=0.04, k=0.003)

    def mouth(p):
        if open_mouth:
            u, v = p[0] - cx, p[2] - (eye_z - 0.2)
            region = smax(ellipse2(u, v, 0.075, 0.06), v - 0.012, 0.01)
            return overlay(base(p), np.maximum(region, p[1] - ylim), 0.009, depth=0.04, k=0.002)
        regs = [arc2(p[0] - (cx + sx * 0.034), p[2] - (eye_z - 0.17 + 0.034), 0.034, 70, 0.0095) for sx in (-1, 1)]
        return overlay(base(p), np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim), 0.009, depth=0.04, k=0.002)

    comps += [
        Comp(f"{prefix}_Cheeks", cheeks, mats["cheeks"], voxel=0.0045, tris=900),
        Comp(f"{prefix}_Nose", nose, mats["nose"], voxel=0.0035, tris=300),
        Comp(f"{prefix}_Mouth", mouth, mats["mouth"], voxel=0.0035, tris=500),
    ]
    return comps


def paw(center, toes=True):
    c = np.asarray(center, float)

    def fn(p):
        d = ellipsoid(p, c, (0.17, 0.15, 0.11))
        if toes:
            for dx in (-0.055, 0.055):
                groove = round_cone(p, c + np.array([dx, -0.16, 0.06]), c + np.array([dx, -0.1, 0.1]), 0.011, 0.011)
                d = smax(d, -groove, 0.012)
        return d

    return fn


# ------------------------------------------------------------------ pedestal (statues only)

def pedestal_parts(mats):
    base = lambda p: cylinder(p, (0, 0, -0.32), 1.25, 0.12, r=0.05)
    step = lambda p: cylinder(p, (0, 0, -0.17), 1.12, 0.05, r=0.03)
    drum = lambda p: cylinder(p, (0, 0, -0.08), 0.95, 0.06, r=0.03)

    def stone(p):
        return np.minimum(np.minimum(base(p), step(p)), drum(p))

    def band(p):
        return overlay(drum(p), np.abs(p[2] + 0.08) - 0.035, 0.01, depth=0.04, k=0.003)

    cream = ("Pedestal_Cream", Mat("#F4EEE4", rough=0.3, coat=0.4))
    return [
        Comp("Pedestal_Stone", stone, cream, voxel=0.014, tris=5000),
        Comp("Pedestal_Band", band, mats["gold"], voxel=0.006, tris=1600),
    ]


# ------------------------------------------------------------------ Peekaboo (signature pose)

def peekaboo(finish="color", tint="lilac", name="Peeka"):
    N = name
    m = palette(N, finish, tint)
    lid_c = HEAD_C + np.array([0.02, 0.02, 0.6])
    lid_R = rot(rx=9, ry=-13, rz=8)
    lid, lid_ribbon, lid_bow = lid_parts(lid_c, lid_R, half=0.27)

    ear_l_root = HEAD_C + np.array([0.4, 0.05, 0.4])
    ear_r_root = HEAD_C + np.array([-0.42, 0.05, 0.38])

    def ears(p):
        a, _ = ear_up(p, ear_l_root, lean=17, length=0.92)
        b, _ = ear_flop(p, ear_r_root, side=-1)
        return np.minimum(a, b)

    def head(p):
        return smin(smin(head_sdf(p), ears(p), 0.07), fluff(p), 0.05)

    probe = (np.zeros(1), np.zeros(1), np.zeros(1))
    _, (cl, Rl) = ear_up(probe, ear_l_root, lean=17, length=0.92)
    _, (cr, Rr) = ear_flop(probe, ear_r_root, side=-1)
    ear_up_fn = lambda p: ear_up(p, ear_l_root, lean=17, length=0.92)[0]
    ear_flop_fn = lambda p: ear_flop(p, ear_r_root, side=-1)[0]

    def inner_ears(p):
        a = inner_ear(ear_up_fn, cl, Rl, 1.05)(p)
        b = inner_ear(ear_flop_fn, cr, Rr, 0.95)(p)
        return np.minimum(a, b)

    paws = [paw((sx * 0.31, -0.6, BOX_TOP + 0.05)) for sx in (-1, 1)]

    def paws_fn(p):
        return np.minimum(paws[0](p), paws[1](p))

    box = lambda p: box_sdf(p)
    comps = [
        Comp(f"{N}_Head", head, m["fur"], voxel=0.009, tris=16000),
        Comp(f"{N}_InnerEars", inner_ears, m["ear"], voxel=0.005, tris=2400),
        Comp(f"{N}_Paws", paws_fn, m["fur"], voxel=0.006, tris=3000),
        Comp(f"{N}_Box", box, m["box"], voxel=0.011, tris=9000),
        Comp(f"{N}_BoxRibbon", box_ribbon(box), m["gold"], voxel=0.006, tris=3000),
        Comp(f"{N}_BoxMarks", box_marks(box), m["mark"], voxel=0.005, tris=4000),
        Comp(f"{N}_BoxDots", box_dots(box), m["dots"], voxel=0.005, tris=3000),
        Comp(f"{N}_Lid", lid, m["lid"], voxel=0.008, tris=5000),
        Comp(f"{N}_LidRibbon", lid_ribbon, m["gold"], voxel=0.005, tris=2600),
        Comp(f"{N}_Bow", lid_bow, m["gold"], voxel=0.005, tris=4000),
    ]
    comps += face(N, head_sdf, m)
    bounds = ((-1.35, -1.1, -0.1), (1.35, 1.1, 3.0))
    if finish == "marble":
        comps += pedestal_parts(m)
        bounds = ((-1.4, -1.4, -0.5), (1.4, 1.4, 3.0))
    return assemble(N, "Peeka", "Mascot", comps, bounds, catalog=None)


# ------------------------------------------------------------------ poses with a body

def axes(forward, thick):
    """Rotation with local Z along `forward` and local X (ear thickness) along `thick`."""
    f = unit(forward)
    n = np.asarray(thick, float)
    n = unit(n - np.dot(n, f) * f)
    return np.stack([n, np.cross(f, n), f], axis=1)


def ear_flop2(p, root, side):
    """Relaxed ear for the nap pose: falls sideways and back along the head."""
    dA = unit((0.5 * side, 0.15, 0.85))
    dB = unit((0.35 * side, 0.45, -0.82))
    cA = root + dA * 0.17
    bend = root + dA * 0.33
    cB = bend + dB * 0.33
    a = ellipsoid(p, cA, (0.085, 0.17, 0.26), frame(dA))
    b = ellipsoid(p, cB, (0.075, 0.155, 0.36), axes(dB, (side, 0, 0)))
    return smin(smin(a, sphere(p, bend, 0.12), 0.1), b, 0.1)


def head_parts(N, m, c, ears="signature", lid=True, closed=False, open_mouth=False):
    c = np.asarray(c, float)
    probe = (np.zeros(1), np.zeros(1), np.zeros(1))
    inner = []
    if ears == "signature":
        l_root, r_root = c + np.array([0.4, 0.05, 0.4]), c + np.array([-0.42, 0.05, 0.38])
        up = lambda p: ear_up(p, l_root, lean=17, length=0.92)[0]
        flop = lambda p: ear_flop(p, r_root, side=-1)[0]
        ear_fns = [up, flop]
        inner = [(up, ear_up(probe, l_root, lean=17, length=0.92)[1], 1.05),
                 (flop, ear_flop(probe, r_root, side=-1)[1], 0.95)]
    elif ears == "splay":
        roots = [c + np.array([0.42, 0.05, 0.38]), c + np.array([-0.42, 0.05, 0.38])]
        ear_fns = [lambda p, r=roots[0]: ear_up(p, r, lean=40, length=0.82)[0],
                   lambda p, r=roots[1]: ear_up(p, r, lean=-40, length=0.82)[0]]
        inner = [(ear_fns[0], ear_up(probe, roots[0], lean=40, length=0.82)[1], 1.0),
                 (ear_fns[1], ear_up(probe, roots[1], lean=-40, length=0.82)[1], 1.0)]
    else:  # "relaxed": both ears fall sideways for the nap
        roots = [c + np.array([0.4, 0.08, 0.38]), c + np.array([-0.4, 0.08, 0.38])]
        ear_fns = [lambda p, r=roots[0]: ear_flop2(p, r, 1), lambda p, r=roots[1]: ear_flop2(p, r, -1)]

    def head(p):
        d = head_sdf(p, c)
        for e in ear_fns:
            d = smin(d, e(p), 0.07)
        return smin(d, fluff(p, c), 0.05)

    comps = [Comp(f"{N}_Head", head, m["fur"], voxel=0.009, tris=16000)]
    if inner:
        def inner_ears(p):
            d = None
            for fn, (ic, iR), sc in inner:
                e = inner_ear(fn, ic, iR, sc)(p)
                d = e if d is None else np.minimum(d, e)
            return d
        comps.append(Comp(f"{N}_InnerEars", inner_ears, m["ear"], voxel=0.005, tris=2400))
    if lid:
        lid_fn, lid_ribbon, lid_bow = lid_parts(c + np.array([0.02, 0.02, 0.6]), rot(rx=9, ry=-13, rz=8), half=0.27)
        comps += [
            Comp(f"{N}_Lid", lid_fn, m["lid"], voxel=0.008, tris=5000),
            Comp(f"{N}_LidRibbon", lid_ribbon, m["gold"], voxel=0.005, tris=2600),
            Comp(f"{N}_Bow", lid_bow, m["gold"], voxel=0.005, tris=4000),
        ]
    comps += face(N, lambda p: head_sdf(p, c), m, cx=c[0], eye_z=c[2] - 0.05, ylim=c[1] - 0.23,
                  closed=closed, open_mouth=open_mouth)
    return comps


def gift_parts(N, m, center, half, top, z_band, mark_z, mark_size, dots=True, recess=True):
    box = lambda p: box_sdf(p, center, half, top, recess)
    comps = [
        Comp(f"{N}_Box", box, m["box"], voxel=0.011, tris=9000),
        Comp(f"{N}_BoxRibbon", box_ribbon(box, center, z=z_band, width=0.07 * half / BOX_HALF + 0.01), m["gold"], voxel=0.006, tris=3000),
        Comp(f"{N}_BoxMarks", box_marks(box, center, half, z=mark_z, size=mark_size), m["mark"], voxel=0.005, tris=4000),
    ]
    if dots:
        comps.append(Comp(f"{N}_BoxDots", box_dots(box, center, half, top), m["dots"], voxel=0.005, tris=3000))
    return comps


def z_glyph(p, c, size):
    c = np.asarray(c, float)
    w, h, t = 0.7 * size, size, 0.12 * size
    tl, tr = c + np.array([-w / 2, 0, h / 2]), c + np.array([w / 2, 0, h / 2])
    bl, br = c + np.array([-w / 2, 0, -h / 2]), c + np.array([w / 2, 0, -h / 2])
    d = round_cone(p, tl, tr, t, t)
    d = np.minimum(d, round_cone(p, tr, bl, t, t))
    return np.minimum(d, round_cone(p, bl, br, t, t))


def tada(finish="color", tint="sky"):
    N = "PeekaTada"
    m = palette(N, finish, tint)
    body_c = np.array([0.0, 0.0, 0.98])
    head_c = np.array([0.0, -0.03, 1.8])
    arms = []
    hands = []
    for sx in (1, -1):
        shoulder = np.array([sx * 0.36, -0.08, 1.22])
        hand = np.array([sx * 0.84, -0.16, 2.56])
        arms.append(([shoulder, np.array([sx * 0.7, -0.14, 1.78]), hand], [0.15, 0.135, 0.12]))
        hands.append(hand)

    def body(p):
        d = ellipsoid(p, body_c, (0.5, 0.44, 0.52))
        for pts, rs in arms:
            d = smin(d, tube(p, pts, rs), 0.08)
        for h in hands:
            d = smin(d, sphere(p, h, 0.14), 0.04)
        return d

    lid_fn, lid_ribbon, lid_bow = lid_parts((0.0, -0.12, 2.76), rot(rx=-6, ry=4), half=0.76)
    comps = [
        Comp(f"{N}_Body", body, m["fur"], voxel=0.009, tris=12000),
        Comp(f"{N}_HeldLid", lid_fn, m["lid"], voxel=0.009, tris=6000),
        Comp(f"{N}_HeldLidRibbon", lid_ribbon, m["gold"], voxel=0.006, tris=3000),
        Comp(f"{N}_HeldBow", lid_bow, m["gold"], voxel=0.005, tris=4000),
    ]
    comps += gift_parts(N, m, (0.0, 0.0, 0.0), 0.6, 0.86, z_band=0.7, mark_z=0.36, mark_size=0.78)
    comps += head_parts(N, m, head_c, ears="splay", lid=False, open_mouth=True)
    bounds = ((-1.5, -1.2, -0.1), (1.5, 1.2, 3.2))
    if finish == "marble":
        comps += pedestal_parts(m)
        bounds = ((-1.5, -1.45, -0.5), (1.5, 1.45, 3.2))
    return assemble(N, "Peeka: Ta-da!", "Mascot", comps, bounds, catalog=None)


def big_hug(finish="color", tint="lilac"):
    N = "PeekaHug"
    m = palette(N, finish, tint)
    body_c = np.array([0.0, 0.06, 0.62])
    head_c = np.array([0.0, -0.06, 1.52])
    feet = [(np.array([sx * 0.33, -0.44, 0.16]), (0.19, 0.25, 0.15)) for sx in (1, -1)]
    tail = (np.array([0.0, 0.6, 0.38]), 0.17)
    arms = []
    for sx in (1, -1):
        arms.append(([np.array([sx * 0.46, -0.08, 0.98]), np.array([sx * 0.5, -0.48, 0.82]),
                      np.array([sx * 0.27, -0.86, 0.76])], [0.15, 0.135, 0.12]))

    def body(p):
        d = ellipsoid(p, body_c, (0.6, 0.52, 0.56))
        for c, r in feet:
            d = smin(d, ellipsoid(p, c, r), 0.06)
        for pts, rs in arms:
            d = smin(d, tube(p, pts, rs), 0.07)
            d = smin(d, sphere(p, pts[-1], 0.13), 0.04)
        return smin(d, sphere(p, *tail), 0.05)

    def pads(p):
        region = None
        for c, _ in feet:
            r = sphere(p, c + np.array([0.0, -0.24, 0.0]), 0.12)
            region = r if region is None else np.minimum(region, r)
        return overlay(body(p), np.maximum(region, p[1] + 0.55), 0.008, depth=0.03, k=0.003)

    gift_c = (0.0, -0.56, 0.34)
    _, _, gift_bow = lid_parts((0.0, -0.56, 0.34 + 0.62 - 0.1), np.eye(3), half=0.28)
    comps = [
        Comp(f"{N}_Body", body, m["fur"], voxel=0.009, tris=14000),
        Comp(f"{N}_FootPads", pads, m["pad"], voxel=0.005, tris=1200),
        Comp(f"{N}_GiftBow", gift_bow, m["gold"], voxel=0.005, tris=4000),
    ]
    comps += gift_parts(N, m, gift_c, 0.3, 0.62, z_band=0.31, mark_z=0.18, mark_size=0.42, dots=False, recess=False)
    comps += head_parts(N, m, head_c, ears="signature", lid=True)
    bounds = ((-1.4, -1.3, -0.1), (1.4, 1.2, 3.0))
    if finish == "marble":
        comps += pedestal_parts(m)
        bounds = ((-1.45, -1.45, -0.5), (1.45, 1.45, 3.0))
    return assemble(N, "Peeka: Big Hug", "Mascot", comps, bounds, catalog=None)


def nap(finish="color", tint="butter"):
    N = "PeekaNap"
    m = palette(N, finish, tint)
    head_c = np.array([-0.4, -0.1, 1.62])
    body_c = np.array([0.2, 0.06, 1.3])
    tail = (np.array([0.84, 0.3, 1.42]), 0.16)
    paws_at = [np.array([-0.62, -0.6, 1.13]), np.array([-0.2, -0.62, 1.13])]
    foot = (np.array([0.74, -0.3, 1.12]), (0.17, 0.22, 0.12))

    def body(p):
        d = ellipsoid(p, body_c, (0.62, 0.46, 0.32))
        for c in paws_at:
            d = smin(d, ellipsoid(p, c, (0.17, 0.16, 0.1)), 0.05)
        d = smin(d, ellipsoid(p, *foot), 0.06)
        return smin(d, sphere(p, *tail), 0.05)

    box_top = 0.92
    lid_fn, lid_ribbon, _ = lid_parts((0.0, 0.0, box_top + 0.06), np.eye(3), half=0.69)

    def zs(p):
        d = z_glyph(p, (0.24, -0.2, 2.42), 0.18)
        d = np.minimum(d, z_glyph(p, (0.52, -0.16, 2.72), 0.24))
        return np.minimum(d, z_glyph(p, (0.86, -0.12, 3.08), 0.3))

    comps = [
        Comp(f"{N}_Body", body, m["fur"], voxel=0.009, tris=12000),
        Comp(f"{N}_Lid", lid_fn, m["lid"], voxel=0.009, tris=6000),
        Comp(f"{N}_LidRibbon", lid_ribbon, m["gold"], voxel=0.006, tris=3000),
        Comp(f"{N}_Snores", zs, m["gold"], voxel=0.006, tris=3000),
    ]
    comps += gift_parts(N, m, (0.0, 0.0, 0.0), 0.64, box_top, z_band=0.66, mark_z=0.36, mark_size=0.8, recess=False)
    comps += head_parts(N, m, head_c, ears="relaxed", lid=False, closed=True)
    bounds = ((-1.4, -1.3, -0.1), (1.4, 1.2, 3.4))
    if finish == "marble":
        comps += pedestal_parts(m)
        bounds = ((-1.45, -1.45, -0.5), (1.45, 1.45, 3.4))
    return assemble(N, "Peeka: Nap Time", "Mascot", comps, bounds, catalog=None)


FIGURES = {
    "peekaboo": lambda: peekaboo("marble", "mint", "PeekaPeekaboo"),
    "tada": lambda: tada("marble", "sky"),
    "hug": lambda: big_hug("marble", "lilac"),
    "nap": lambda: nap("marble", "butter"),
}
