"""Pocket Grove figure definitions, reconstructed from the approved character sheets.

Units are studs. +Z is up, every figure faces -Y, the character's left is +X,
and the lowest point of each figure rests on Z = 0 after grounding.
Helpers are copied from the Tidepool Tales definitions (see the figure collection runbook);
`face` adds closed-eye variants and `Leaf` builds the leaves, petals, ears and antennae.
"""

import math

import numpy as np

from sdf import (
    arc2, catmull, cylinder, ellipse2, ellipsoid, frame, front_decal, local, overlay, rot,
    round_box, round_cone, smax, smin, sphere, torus, tube,
)


class Mat:
    def __init__(self, color, rough=0.5, metal=0.0, alpha=1.0, **render):
        self.color = color  # hex string, or list of hex strings for a vertical ramp
        self.rough = rough
        self.metal = metal
        self.alpha = alpha
        self.render = render  # render-only garnish: coat, thin_film, transmission, subsurface, sheen


class Comp:
    def __init__(self, name, fn, mat, voxel=0.012, tris=6000, ramp=None, min_faces=24):
        self.name = name
        self.fn = fn
        self.mat = mat
        self.voxel = voxel
        self.tris = tris
        self.ramp = ramp  # fn(x, y, z) -> t in [0, 1] for ramp materials
        self.min_faces = min_faces


# ------------------------------------------------------------------ helpers

def P(pts):
    return (pts[:, 0], pts[:, 1], pts[:, 2])


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def surface_point(fn, origin, direction, tmax=3.0, steps=600):
    """March from an interior point outward and return the surface crossing."""
    o = np.asarray(origin, float)
    d = unit(direction)
    ts = np.linspace(0.0, tmax, steps)
    pts = o[None, :] + ts[:, None] * d[None, :]
    v = fn(P(pts))
    idx = int(np.argmax(v >= 0.0))
    lo, hi = ts[max(idx - 1, 0)], ts[idx]
    for _ in range(30):
        mid = 0.5 * (lo + hi)
        if fn(P((o + mid * d)[None, :]))[0] < 0:
            lo = mid
        else:
            hi = mid
    return o + 0.5 * (lo + hi) * d


def sph_dir(az_deg, el_deg):
    """Direction by azimuth (0 = back/+Y, 90 = character's left/+X) and elevation."""
    a, e = math.radians(az_deg), math.radians(el_deg)
    return np.array([math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)])


def spheres_region(p, centers, radii):
    d = None
    for c, r in zip(centers, radii):
        s = sphere(p, c, r)
        d = s if d is None else np.minimum(d, s)
    return d


def seg2(u, v, a, b, th):
    """2D capsule from a to b with half-thickness th."""
    bx, by = b[0] - a[0], b[1] - a[1]
    px, py = u - a[0], v - a[1]
    h = np.clip((px * bx + py * by) / (bx * bx + by * by), 0.0, 1.0)
    return np.sqrt((px - bx * h) ** 2 + (py - by * h) ** 2) - th


def flat_base(d, p):
    """Flat sole at Z = 0 so the figure stands squarely on its surface."""
    return smax(d, -p[2], 0.015)


class Leaf:
    """A pillowy blade from base to tip: leaves, petals, lop ears and feathered antennae.

    `up` is the blade's broad-face normal. Edges are fully rounded (radius = half thickness),
    so tips and rims are never paper-thin. `bend` curls the tip toward +up (studs at the tip),
    `cup` raises the side edges, `crease` presses a midrib, `serrate` scallops the outline.
    """

    def __init__(self, base, tip, width, thick, up, mid=0.45, r_base=None, r_tip=None,
                 bend=0.0, cup=0.0, crease=0.0, pillow=0.35, serrate=None):
        self.b = np.asarray(base, float)
        v = np.asarray(tip, float) - self.b
        self.L = float(np.linalg.norm(v))
        self.t = v / self.L
        n = np.asarray(up, float)
        n = n - np.dot(n, self.t) * self.t
        self.n = n / np.linalg.norm(n)
        self.c = np.cross(self.n, self.t)
        self.w = width
        self.h = thick
        self.m = mid * self.L
        self.rb = width * 0.3 if r_base is None else r_base
        self.rt = width * 0.12 if r_tip is None else r_tip
        self.bend, self.cup, self.crease, self.pillow, self.serrate = bend, cup, crease, pillow, serrate

    def coords(self, p):
        q = (p[0] - self.b[0], p[1] - self.b[1], p[2] - self.b[2])
        a = q[0] * self.t[0] + q[1] * self.t[1] + q[2] * self.t[2]
        s = q[0] * self.c[0] + q[1] * self.c[1] + q[2] * self.c[2]
        n = q[0] * self.n[0] + q[1] * self.n[1] + q[2] * self.n[2]
        f = np.clip(a / self.L, 0.0, 1.2)
        n = n - self.bend * f * f - self.cup * (s / self.w) ** 2
        return a, s, n

    def outline(self, a, s):
        z = np.zeros_like(a)
        q = (a, s, z)
        d = smin(round_cone(q, (0, 0, 0), (self.m, 0, 0), self.rb, self.w),
                 round_cone(q, (self.m, 0, 0), (self.L, 0, 0), self.w, self.rt), 0.02)
        if self.serrate:
            amp, period = self.serrate
            d = d + amp * (0.5 + 0.5 * np.cos(2 * math.pi * (a + 0.9 * np.abs(s)) / period))
        return d

    def parts(self, p):
        a, s, n = self.coords(p)
        d2 = self.outline(a, s)
        inner = d2 + self.h
        bulge = self.h * self.pillow * np.clip(-inner / self.w, 0.0, 1.0)
        d = np.sqrt(np.maximum(inner, 0.0) ** 2 + n * n) - self.h - bulge
        if self.crease:
            env = np.clip(a / self.L * 5, 0, 1) * np.clip((self.L - a) / self.L * 5, 0, 1)
            d = d + self.crease * env * np.exp(-(s / (0.1 * self.w)) ** 2)
        return d, a, s, n, d2

    def __call__(self, p):
        return self.parts(p)[0]


def face(prefix, base, ylim, eyes, mouth, cheeks, mats, eye_cx=0.0):
    """Eyes, mouth and cheeks as thin skins conforming to `base`.

    eyes: {"kind": "open", "dx", "z", "r": (ru, rv)} domed ovals with a highlight, or
          {"kind": "sleepy" | "happy", "dx", "z", "w", "th"} closed-eye arcs with a lash flick.
    mouth: (mx, mz, radius, aperture_deg, thickness); cheeks: (dx, z, (ru, rv)).
    """
    kind, dx, ez = eyes["kind"], eyes["dx"], eyes["z"]
    comps = []
    if kind == "open":
        ru, rv = eyes["r"]

        def eye_dome(p):
            dome = np.zeros_like(p[0])
            regs = []
            for sx in (-1.0, 1.0):
                u = p[0] - (eye_cx + sx * dx)
                v = p[2] - ez
                regs.append(ellipse2(u, v, ru, rv))
                q = (u / ru) ** 2 + (v / rv) ** 2
                dome = np.maximum(dome, 0.028 * np.clip(1.0 - q, 0.0, 1.0))
            return np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim), 0.012 + dome

        def eyes_fn(p):
            region, out = eye_dome(p)
            return overlay(base(p), region, out, depth=0.05, k=0.004)

        def shine(p):
            _, out = eye_dome(p)
            eye_surface = base(p) - out
            regs = []
            for sx in (-1.0, 1.0):
                u = p[0] - (eye_cx + sx * dx - 0.3 * ru)
                v = p[2] - (ez + 0.38 * rv)
                regs.append(ellipse2(u, v, 0.3 * ru, 0.26 * rv))
            region = np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim)
            return overlay(eye_surface, region, 0.007, depth=0.02, k=0.002)

        comps.append(Comp(f"{prefix}_Eyes", eyes_fn, mats["eyes"], voxel=0.005, tris=1400))
        comps.append(Comp(f"{prefix}_EyeShine", shine, mats["shine"], voxel=0.004, tris=400))
    else:
        w, th = eyes["w"], eyes["th"]
        ap = 58.0
        R = w / math.sin(math.radians(ap))
        rise = R - R * math.cos(math.radians(ap))

        def lids(p):
            regs = []
            for sx in (-1.0, 1.0):
                u = p[0] - (eye_cx + sx * dx)
                v = p[2] - ez
                if kind == "sleepy":  # relaxed closed eye, lowest in the middle
                    arc = arc2(u, v - R, R, ap, th)
                    end = (sx * w, rise)
                    flick = seg2(u, v, end, (sx * (w + 0.045), rise - 0.012), th * 0.8)
                else:  # happy closed eye, highest in the middle
                    arc = arc2(u, -(v + R), R, ap, th)
                    end = (sx * w, -rise)
                    flick = seg2(u, v, end, (sx * (w + 0.045), -rise + 0.028), th * 0.8)
                regs.append(np.minimum(arc, flick))
            region = np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim)
            return overlay(base(p), region, 0.012, depth=0.05, k=0.003)

        comps.append(Comp(f"{prefix}_Eyes", lids, mats["eyes"], voxel=0.004, tris=1200))

    cdx, cz, cr = cheeks

    def cheeks_fn(p):
        regs = [ellipse2(p[0] - (eye_cx + sx * cdx), p[2] - cz, cr[0], cr[1]) for sx in (-1.0, 1.0)]
        region = np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim)
        return overlay(base(p), region, 0.008, depth=0.04, k=0.004)

    comps.append(Comp(f"{prefix}_Cheeks", cheeks_fn, mats["cheeks"], voxel=0.005, tris=900))

    mx, mz, radius, aperture, thick = mouth

    def mouth_fn(p):
        region = np.maximum(arc2(p[0] - mx, p[2] - (mz + radius), radius, aperture, thick), p[1] - ylim)
        return overlay(base(p), region, 0.01, depth=0.04, k=0.002)

    comps.append(Comp(f"{prefix}_Mouth", mouth_fn, mats["mouth"], voxel=0.004, tris=500))
    return comps


def face_mats(prefix):
    return {
        "eyes": (f"{prefix}_EyeGloss", Mat("#35251F", rough=0.18, coat=0.6)),
        "shine": (f"{prefix}_EyeShine", Mat("#FFFFFF", rough=0.3)),
        "cheeks": (f"{prefix}_Blush", Mat("#F4A7A0", rough=0.6)),
        "mouth": (f"{prefix}_Mouth", Mat("#4A2E26", rough=0.4)),
    }


def assemble(name, title, rarity, comps, mats, bounds, **info):
    """Resolve material tuples into a flat figure description."""
    materials = {}
    for c in comps:
        mname, m = c.mat
        materials[mname] = m
        c.mat = mname
    return dict(name=name, title=title, rarity=rarity, comps=comps, mats=materials, bounds=bounds, **info)


# Pocket Grove's pastel palette washes toward white under AgX, so its renders use the
# color-faithful Khronos PBR Neutral transform. The GLB albedo is unaffected.
RENDER_VIEW = "Khronos PBR Neutral|None|-1.1"


# ---------------------------------------------------------------- 1. Pebble Pip

def pebble_pip():
    N = "PebblePip"
    fm = face_mats(N)
    stone = (f"{N}_Stone", Mat("#CFBFAF", rough=0.72, coat=0.05))
    leaf_m = (f"{N}_CloverLeaf", Mat("#96B64E", rough=0.5, coat=0.15))
    stem_m = (f"{N}_CloverStem", Mat("#76934C", rough=0.55))

    def head(p):
        dome = ellipsoid(p, (0, 0, 1.12), (1.06, 1.0, 1.0))
        crown = ellipsoid(p, (0, 0, 1.36), (0.94, 0.9, 0.78))
        return smax(smin(dome, crown, 0.2), 0.72 - p[2], 0.3)

    def body(p):
        d = ellipsoid(p, (0, 0, 0.46), (0.39, 0.35, 0.42))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.18, -0.06, 0.09), (0.15, 0.19, 0.12)), 0.06)
            d = smin(d, round_cone(p, (sx * 0.32, 0.0, 0.62), (sx * 0.52, -0.05, 0.36), 0.105, 0.095), 0.05)
        return flat_base(d, p)

    # Trefoil of heart-shaped leaflets facing the viewer and tipped up, as in the hero and
    # front views (upper-left, upper-right and lower-right leaflets around the stem tip).
    C = np.array([0.06, -0.1, 2.74])
    nrm = unit((0.3, -0.68, 0.66))
    e1 = unit(np.array([1.0, 0.0, 0.0]) - nrm[0] * nrm)
    e2 = np.cross(nrm, e1)
    lobes = []
    for ang in (148.0, 32.0, -80.0):
        a0 = math.radians(ang)
        d0 = math.cos(a0) * e1 + math.sin(a0) * e2
        side = np.cross(nrm, d0)
        for off in (-1.0, 1.0):
            d = unit(d0 + side * off * 0.42)
            lobes.append(Leaf(C + d0 * 0.03, C + d * 0.46, 0.17, 0.05, nrm, mid=0.64,
                              r_base=0.03, r_tip=0.165, bend=0.05))

    def clover(p):
        d = None
        for lf in lobes:
            v = lf(p)
            d = v if d is None else smin(d, v, 0.02)
        return d

    def stem(p):
        return tube(p, [(0.0, 0.02, 2.05), (-0.08, 0.0, 2.3), (-0.06, -0.05, 2.52), tuple(C)],
                    [0.064, 0.058, 0.052, 0.046], k=0.02)

    comps = [
        Comp(f"{N}_Head", head, stone, voxel=0.011, tris=11000),
        Comp(f"{N}_Body", body, stone, voxel=0.008, tris=7000),
        Comp(f"{N}_Clover", clover, leaf_m, voxel=0.005, tris=6000),
        Comp(f"{N}_CloverStem", stem, stem_m, voxel=0.005, tris=1600),
    ]
    comps += face(N, head, -0.35, dict(kind="open", dx=0.44, z=1.22, r=(0.09, 0.125)),
                  (0.0, 1.1, 0.075, 55, 0.015), (0.64, 1.03, (0.145, 0.095)), fm)
    return assemble(N, "Pebble Pip", "Common", comps, {}, ((-1.5, -1.4, -0.2), (1.5, 1.4, 3.5)),
                    catalog="grove.pebble")


# ---------------------------------------------------------------- 2. Sprout Scout

def sprout_scout():
    N = "SproutScout"
    fm = face_mats(N)
    sage = (f"{N}_Sage", Mat("#A5B06C", rough=0.62, coat=0.1))
    leaf_m = (f"{N}_Leaf", Mat("#A9B54A", rough=0.5, coat=0.2))
    scarf_m = (f"{N}_Scarf", Mat("#F4DDBD", rough=0.8))
    leather = (f"{N}_Leather", Mat("#A56E43", rough=0.62))
    flap_m = (f"{N}_BagFlap", Mat("#93603A", rough=0.6))
    brass = (f"{N}_Buckle", Mat("#D8B46A", rough=0.35, metal=0.6))
    wood = (f"{N}_Staff", Mat("#7A5030", rough=0.7))

    def head(p):
        return smax(ellipsoid(p, (0, 0, 1.36), (1.0, 0.94, 0.97)), 0.92 - p[2], 0.34)

    def torso(p):
        return ellipsoid(p, (0, 0, 0.52), (0.53, 0.46, 0.5))

    def body(p):
        d = torso(p)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.22, -0.08, 0.09), (0.17, 0.21, 0.12)), 0.06)
        d = smin(d, round_cone(p, (-0.44, 0.0, 0.72), (-0.62, -0.14, 0.5), 0.12, 0.11), 0.05)
        d = smin(d, round_cone(p, (0.44, -0.05, 0.72), (0.84, -0.3, 0.68), 0.12, 0.11), 0.05)
        d = smin(d, sphere(p, (0.9, -0.32, 0.68), 0.12), 0.03)
        return flat_base(d, p)

    def sprout_stem(p):
        return tube(p, [(0.0, 0.0, 2.2), (0.0, -0.02, 2.38), (0.0, -0.03, 2.48)], [0.1, 0.085, 0.075], k=0.02)

    left = Leaf((-0.06, -0.03, 2.46), (-1.12, -0.2, 2.98), 0.44, 0.07, (-0.35, -0.35, 0.87),
                mid=0.5, r_base=0.06, r_tip=0.19, bend=-0.2, cup=0.1, crease=0.022)
    right = Leaf((0.06, -0.03, 2.46), (1.02, 0.14, 3.2), 0.48, 0.07, (0.5, -0.25, 0.83),
                 mid=0.5, r_base=0.06, r_tip=0.2, bend=-0.18, cup=0.1, crease=0.022)

    def leaves(p):
        return smin(smin(left(p), right(p), 0.04), sprout_stem(p), 0.05)

    def scarf(p):
        band = torus(p, (0, -0.02, 0.88), 0.46, 0.14)
        knot = sphere(p, (0.22, -0.52, 0.86), 0.14)
        tail = round_box(p, (0.28, -0.56, 0.6), (0.14, 0.06, 0.23), 0.05, rot(-8, 0, 10))
        return smin(smin(band, knot, 0.05), tail, 0.04)

    sn = unit((0.5, 0.0, -0.85))
    sc = np.array([0.0, 0.0, 0.64])

    def strap(p):
        band = np.abs((p[0] - sc[0]) * sn[0] + (p[2] - sc[2]) * sn[2]) - 0.06
        return overlay(torso(p), band, 0.035, depth=0.05, k=0.01)

    BC = np.array([-0.56, -0.3, 0.38])
    RB = rot(0, 0, -32)

    def bag(p):
        return round_box(p, BC, (0.27, 0.1, 0.21), 0.07, RB)

    def flap(p):
        x, y, z = local(p, BC, RB)
        region = np.maximum(np.maximum(-0.04 - z, y - 0.05), np.abs(x) - 0.26)
        return overlay(bag(p), region, 0.014, depth=0.04, k=0.01)

    btn = BC + RB @ np.array([0.0, -0.12, -0.05])

    def buckle(p):
        return sphere(p, btn, 0.05)

    s0, s1 = np.array([0.92, -0.32, 0.0]), np.array([0.98, -0.35, 1.28])

    def staff(p):
        d = round_cone(p, s0, s1, 0.085, 0.072)
        d = smin(d, round_cone(p, (0.97, -0.35, 1.1), (1.13, -0.34, 1.32), 0.05, 0.042), 0.03)
        d = smin(d, sphere(p, (0.95, -0.33, 0.97), 0.095), 0.03)
        return flat_base(d, p)

    staff_leaf = Leaf((1.12, -0.34, 1.3), (1.36, -0.4, 1.6), 0.15, 0.045, (0.5, -0.8, -0.2),
                      mid=0.45, r_base=0.035, r_tip=0.05, bend=0.03, crease=0.012)

    comps = [
        Comp(f"{N}_Head", head, sage, voxel=0.011, tris=11000),
        Comp(f"{N}_Body", body, sage, voxel=0.008, tris=9000),
        Comp(f"{N}_Sprout", leaves, leaf_m, voxel=0.007, tris=8000),
        Comp(f"{N}_Scarf", scarf, scarf_m, voxel=0.006, tris=5000),
        Comp(f"{N}_Strap", strap, leather, voxel=0.005, tris=3000),
        Comp(f"{N}_Bag", bag, leather, voxel=0.006, tris=2500),
        Comp(f"{N}_BagFlap", flap, flap_m, voxel=0.004, tris=2000),
        Comp(f"{N}_Buckle", buckle, brass, voxel=0.004, tris=400),
        Comp(f"{N}_Staff", staff, wood, voxel=0.005, tris=2500),
        Comp(f"{N}_StaffLeaf", staff_leaf, leaf_m, voxel=0.004, tris=1000),
    ]
    comps += face(N, head, -0.35, dict(kind="open", dx=0.45, z=1.42, r=(0.09, 0.125)),
                  (0.0, 1.3, 0.075, 55, 0.015), (0.65, 1.23, (0.145, 0.095)), fm)
    return assemble(N, "Sprout Scout", "Common", comps, {}, ((-1.6, -1.4, -0.2), (1.7, 1.4, 3.7)),
                    catalog="grove.sprout")


# ---------------------------------------------------------------- 3. Acorn Dot

def acorn_dot():
    N = "AcornDot"
    fm = face_mats(N)
    skin = (f"{N}_Skin", Mat("#DDB07E", rough=0.62, coat=0.1))
    cap_m = (f"{N}_Cap", Mat("#8E5E40", rough=0.7))
    nut_m = (f"{N}_Nut", Mat("#C98A57", rough=0.5, coat=0.2))
    leaf_m = (f"{N}_Leaf", Mat("#B5A64C", rough=0.55))

    CC = np.array([0.0, 0.04, 1.4])
    CR = (1.17, 1.08, 1.06)

    def scales(p, center, rows, per_row, amp, phi0):
        x, y, z = p[0] - center[0], p[1] - center[1], p[2] - center[2]
        r = np.sqrt(x * x + y * y + z * z) + 1e-9
        phi = np.arccos(np.clip(z / r, -1, 1))
        theta = np.arctan2(x, -y)
        v = phi / (math.pi / 2) * rows
        row = np.floor(v)
        fv = v - row - 0.5
        u = theta / (2 * math.pi) * per_row + 0.5 * np.mod(row, 2)
        fu = u - np.floor(u) - 0.5
        s = np.abs(2 * fu) + np.abs(2 * fv)
        t = np.clip((1.0 - s) / 0.35, 0.0, 1.0)  # flat-topped plates with rounded grooves
        return amp * t * t * (3 - 2 * t) * np.clip((phi - phi0) / 0.3, 0, 1)

    def cap_shell(p):
        tilt = 1.45 + 0.12 * (-p[1])
        d = smax(ellipsoid(p, CC, CR), tilt - p[2], 0.12)
        return smax(d, -ellipsoid(p, (0, 0.04, 1.3), (0.98, 0.9, 0.66)), 0.05)

    def cap(p):
        d = cap_shell(p) - scales(p, (0, 0.04, 1.4), 5.0, 14.0, 0.055, 0.22)
        stem = round_cone(p, (0.0, 0.04, 2.34), (0.08, 0.05, 2.8), 0.12, 0.095)
        return smin(d, stem, 0.06)

    cap_leaf = Leaf((-0.06, 0.03, 2.5), (-0.36, -0.02, 2.74), 0.1, 0.035, (-0.35, -0.6, 0.7),
                    mid=0.45, r_base=0.03, r_tip=0.025, crease=0.008)

    def head(p):
        q = (p[0], p[1] / 0.9, p[2])
        d = cylinder(q, (0, 0, 1.38), 1.0, 0.52, 0.42) * 0.9
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.96, 0.08, 1.12), (0.09, 0.15, 0.2)), 0.05)
        return d

    def body(p):
        d = ellipsoid(p, (0, 0, 0.46), (0.47, 0.41, 0.46))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.2, -0.07, 0.09), (0.16, 0.2, 0.12)), 0.06)
            d = smin(d, round_cone(p, (sx * 0.4, -0.05, 0.62), (sx * 0.3, -0.5, 0.46), 0.12, 0.11), 0.05)
            d = smin(d, sphere(p, (sx * 0.29, -0.55, 0.45), 0.11), 0.03)
        d = smin(d, sphere(p, (0.0, 0.41, 0.22), 0.13), 0.05)
        return flat_base(d, p)

    AN = np.array([0.0, -0.6, 0.42])

    def nut(p):
        d = ellipsoid(p, AN, (0.28, 0.26, 0.28))
        return smin(d, round_cone(p, AN, AN + (0, -0.02, -0.32), 0.14, 0.04), 0.1)

    def acorn_cap(p):
        c = AN + np.array([0.0, 0.0, 0.22])
        d = smax(ellipsoid(p, c, (0.32, 0.3, 0.18)), c[2] - 0.02 - p[2], 0.03)
        d = d - scales(p, c - (0, 0, 0.05), 3.0, 10.0, 0.018, 0.25)
        return smin(d, round_cone(p, c + (0, 0, 0.12), c + (0.02, 0.0, 0.28), 0.055, 0.045), 0.03)

    comps = [
        Comp(f"{N}_Cap", cap, cap_m, voxel=0.009, tris=16000),
        Comp(f"{N}_CapLeaf", cap_leaf, leaf_m, voxel=0.004, tris=800),
        Comp(f"{N}_Head", head, skin, voxel=0.01, tris=10000),
        Comp(f"{N}_Body", body, skin, voxel=0.008, tris=8000),
        Comp(f"{N}_Acorn", nut, nut_m, voxel=0.006, tris=2500),
        Comp(f"{N}_AcornCap", acorn_cap, cap_m, voxel=0.005, tris=3000),
    ]
    comps += face(N, head, -0.35, dict(kind="open", dx=0.42, z=1.33, r=(0.09, 0.125)),
                  (0.0, 1.21, 0.075, 55, 0.015), (0.64, 1.14, (0.145, 0.095)), fm)
    return assemble(N, "Acorn Dot", "Common", comps, {}, ((-1.5, -1.4, -0.2), (1.5, 1.4, 3.3)),
                    catalog="grove.acorn")


# ---------------------------------------------------------------- 4. Mallow Cap

def mallow_cap():
    N = "MallowCap"
    fm = face_mats(N)
    skin = (f"{N}_Skin", Mat("#EFD0B4", rough=0.62, coat=0.1))
    cap_m = (f"{N}_Cap", Mat("#DE8183", rough=0.55, coat=0.2))
    gill_m = (f"{N}_Gills", Mat("#E7B7A8", rough=0.65))
    spot_m = (f"{N}_Spots", Mat("#FAEEE1", rough=0.5, coat=0.2))

    CO = np.array([0.0, 0.1, 1.32])
    RT = rot(-21, 0, 0)  # tip the cap back so the gills show at the front

    def cap_local(p):
        return local(p, CO, RT)

    def cap_outer(p):
        q = cap_local(p)
        d = ellipsoid(q, (0, 0, -1.2), (1.86, 1.8, 2.8))
        d = smax(d, -q[2], 0.1)
        return smin(d, torus(q, (0, 0, 0.06), 1.56, 0.1), 0.08)

    def hollow(q):
        return ellipsoid(q, (0, 0, -0.06), (1.45, 1.42, 0.56))

    def cap(p):
        return smax(cap_outer(p), -hollow(cap_local(p)), 0.08)

    def gills(p):
        q = cap_local(p)
        ang = np.arctan2(q[0], q[1])
        rib = np.abs(np.cos(ang * 24.0)) ** 0.6
        region = np.minimum(hollow(q) - 0.03, q[2] - 0.03)
        return overlay(cap(p) - 0.012 * rib, region, 0.012, depth=0.05, k=0.01)

    spot_dirs = [(180, 40, 0.34), (-140, 28, 0.3), (142, 30, 0.28), (-150, 64, 0.24), (156, 66, 0.22),
                 (-100, 30, 0.28), (104, 44, 0.24), (-70, 58, 0.18), (60, 20, 0.2), (0, 76, 0.14)]
    origin = CO + RT @ np.array([0.0, 0.0, 0.2])
    spot_pts = [surface_point(cap_outer, origin, RT @ sph_dir(az, el)) for az, el, _ in spot_dirs]
    spot_r = [r for _, _, r in spot_dirs]

    def spots(p):
        return overlay(cap(p), spheres_region(p, spot_pts, spot_r), 0.012, depth=0.05, k=0.01)

    HC = (0.0, -0.05, 1.38)

    def head(p):
        return ellipsoid(p, HC, (0.8, 0.7, 0.6))

    ears = [Leaf((sx * 0.6, -0.08, 1.64), (sx * 0.88, -0.2, 0.92), 0.21, 0.08, (sx * 1.0, -0.35, 0.0),
                 mid=0.58, r_base=0.09, r_tip=0.15, bend=0.04) for sx in (-1, 1)]

    def body(p):
        d = ellipsoid(p, (0, 0, 0.5), (0.5, 0.44, 0.48))
        d = smin(d, head(p), 0.12)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.26, -0.28, 0.17), (0.18, 0.28, 0.16)), 0.08)
            d = smin(d, ellipsoid(p, (sx * 0.42, -0.52, 0.14), (0.15, 0.13, 0.14), rot(0, 0, sx * 30)), 0.06)
            d = smin(d, round_cone(p, (sx * 0.42, -0.05, 0.74), (sx * 0.3, -0.4, 0.44), 0.12, 0.11), 0.05)
            d = smin(d, ears[0 if sx < 0 else 1](p), 0.06)
        return flat_base(d, p)

    comps = [
        Comp(f"{N}_Cap", cap, cap_m, voxel=0.011, tris=14000),
        Comp(f"{N}_Gills", gills, gill_m, voxel=0.006, tris=12000),
        Comp(f"{N}_Spots", spots, spot_m, voxel=0.006, tris=4000),
        Comp(f"{N}_Body", body, skin, voxel=0.009, tris=14000),
    ]
    comps += face(N, head, -0.35, dict(kind="sleepy", dx=0.34, z=1.24, w=0.11, th=0.02),
                  (0.0, 1.13, 0.06, 55, 0.013), (0.52, 1.12, (0.12, 0.08)), fm)
    return assemble(N, "Mallow Cap", "Uncommon", comps, {}, ((-2.0, -2.0, -0.2), (2.0, 2.0, 3.3)),
                    catalog="grove.mushroom")


# ---------------------------------------------------------------- 5. Moon Moth

def moon_moth():
    N = "MoonMoth"
    fm = face_mats(N)
    lavender = (f"{N}_Lavender", Mat("#C6B0D6", rough=0.6, coat=0.15))
    face_m = (f"{N}_Face", Mat("#F3E4E6", rough=0.6, coat=0.1))
    wing_m = (f"{N}_Wing", Mat(["#B38FC7", "#C2A7D2", "#CBB6D8"], rough=0.55, coat=0.2))
    wing_in = (f"{N}_WingInner", Mat("#E4C8E0", rough=0.6))
    ear_in = (f"{N}_EarInner", Mat("#F4B3C0", rough=0.6))
    moon_m = (f"{N}_Moon", Mat("#FDDFA0", rough=0.4, coat=0.3))

    HC = (0.0, 0.0, 2.0)

    def head(p):
        return ellipsoid(p, HC, (0.84, 0.74, 0.68))

    def face_fn(p):
        region = front_decal(p, 0.0, 1.8, lambda u, v: ellipse2(u, v, 0.62, 0.5), y_limit=-0.2)
        return overlay(head(p), region, 0.01, depth=0.05, k=0.01)

    ears = [Leaf((sx * 0.55, 0.0, 2.22), (sx * 1.42, -0.06, 2.1), 0.2, 0.08, (0.0, -1.0, 0.25),
                 mid=0.55, r_base=0.08, r_tip=0.15, cup=0.03) for sx in (-1, 1)]

    def ear_fn(p):
        return np.minimum(ears[0](p), ears[1](p))

    def ear_inner(p):
        d = None
        for e in ears:
            full, a, s, n, d2 = e.parts(p)
            region = np.maximum(d2 + 0.07, -n)
            v = overlay(full, region, 0.01, depth=0.04, k=0.01)
            d = v if d is None else np.minimum(d, v)
        return d

    antennae = [Leaf((sx * 0.36, -0.02, 2.76), (sx * 0.6, -0.05, 3.34), 0.25, 0.055, (0.0, -1.0, 0.1),
                     mid=0.48, r_base=0.06, r_tip=0.09, crease=0.015, serrate=(0.022, 0.085)) for sx in (-1, 1)]

    def antenna_fn(p):
        d = np.minimum(antennae[0](p), antennae[1](p))
        for sx in (-1, 1):
            d = smin(d, round_cone(p, (sx * 0.2, 0.0, 2.55), (sx * 0.38, -0.02, 2.82), 0.06, 0.05), 0.03)
        return d

    # Each wing is a broad cupped lobe hanging from the upper back, flaring out and down
    # like a sleeve; the cup wraps it around the body so it reads from side and back.
    wing_leaves = {sx: Leaf((sx * 0.3, 0.6, 2.3), (sx * 1.26, 0.12, 0.6), 0.8, 0.09,
                            (sx * 0.72, 0.69, 0.1), mid=0.66, r_base=0.26, r_tip=0.48,
                            cup=-0.4, bend=-0.05) for sx in (-1, 1)}

    def wings(p):
        return np.minimum(wing_leaves[1](p), wing_leaves[-1](p))

    def wing_inner_fn(p):
        d = None
        for lf in wing_leaves.values():
            full, a, s, n, d2 = lf.parts(p)
            v = overlay(full, np.maximum(n, d2 + 0.05), 0.01, depth=0.05, k=0.01)
            d = v if d is None else np.minimum(d, v)
        return d

    def crescent2(u, v, r):
        return smax(ellipse2(u, v, r, r), -ellipse2(u + 0.42 * r, v - 0.2 * r, 0.82 * r, 0.82 * r), 0.01)

    dots = [(0.35, 0.2), (0.45, -0.35), (0.58, 0.42), (0.8, -0.1), (0.9, 0.4), (0.3, -0.25)]

    def markings(p):
        d = None
        for sx, lf in wing_leaves.items():
            full, a, s, n, d2 = lf.parts(p)
            L, w = lf.L, lf.w
            moon = crescent2(s * sx + 0.05, a - 0.66 * L, 0.26)
            spots = None
            for fa, fs in dots:
                e = ellipse2(a - fa * L, s - fs * w, 0.045, 0.045)
                spots = e if spots is None else np.minimum(spots, e)
            region = np.maximum(np.minimum(moon, spots), -n)
            m = overlay(full, region, 0.012, depth=0.05, k=0.008)
            d = m if d is None else np.minimum(d, m)
        return d

    def body(p):
        d = ellipsoid(p, (0, 0, 0.78), (0.45, 0.4, 0.58))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.18, -0.05, 0.09), (0.15, 0.19, 0.12)), 0.06)
            d = smin(d, round_cone(p, (sx * 0.4, -0.05, 1.08), (sx * 0.2, -0.38, 0.84), 0.11, 0.1), 0.05)
        return flat_base(d, p)

    comps = [
        Comp(f"{N}_Head", head, lavender, voxel=0.01, tris=9000),
        Comp(f"{N}_Face", face_fn, face_m, voxel=0.006, tris=4000),
        Comp(f"{N}_Ears", ear_fn, lavender, voxel=0.007, tris=4000),
        Comp(f"{N}_EarInner", ear_inner, ear_in, voxel=0.005, tris=2400),
        Comp(f"{N}_Antennae", antenna_fn, lavender, voxel=0.005, tris=6000),
        Comp(f"{N}_Wings", wings, wing_m, voxel=0.009, tris=14000, ramp=lambda x, y, z: np.clip((z - 0.3) / 2.0, 0, 1)),
        Comp(f"{N}_WingInner", wing_inner_fn, wing_in, voxel=0.007, tris=10000),
        Comp(f"{N}_WingMarks", markings, moon_m, voxel=0.006, tris=4000),
        Comp(f"{N}_Body", body, lavender, voxel=0.008, tris=8000),
    ]
    comps += face(N, lambda p: head(p) - 0.01, -0.3, dict(kind="sleepy", dx=0.36, z=1.72, w=0.11, th=0.02),
                  (0.0, 1.62, 0.06, 55, 0.013), (0.54, 1.6, (0.12, 0.08)), fm)
    return assemble(N, "Moon Moth", "Uncommon", comps, {}, ((-2.0, -1.4, -0.2), (2.0, 1.6, 3.7)),
                    catalog="grove.moth")


# ---------------------------------------------------------------- 6. Sunbeam Sprite

def sunbeam_sprite():
    N = "SunbeamSprite"
    fm = face_mats(N)
    skin = (f"{N}_Skin", Mat("#F3D6B2", rough=0.6, coat=0.12))
    petal_m = (f"{N}_Petals", Mat(["#F4A83A", "#F8BA40", "#F9C654"], rough=0.5, coat=0.25))
    braid_m = (f"{N}_Braid", Mat("#F8BA40", rough=0.5, coat=0.2))
    gold = (f"{N}_Gold", Mat("#F0B544", rough=0.3, metal=0.7))
    orb_m = (f"{N}_Orb", Mat("#FCE7A8", rough=0.35, coat=0.4))
    sun_m = (f"{N}_OrbSun", Mat("#F8C455", rough=0.35, coat=0.3))

    HC = (0.0, 0.0, 1.85)

    def head(p):
        return ellipsoid(p, HC, (1.02, 0.85, 0.84))

    O = np.array([0.0, 0.3, 1.9])

    def ring(count, phase, y, reach, width, lean):
        out = []
        for i in range(count):
            a = math.radians(90 + phase + i * 360.0 / count)
            ca, sa = math.cos(a), math.sin(a)
            rx = reach[0]
            rz = reach[1] if sa > 0 else reach[2]
            d = np.array([ca, 0.0, sa])
            base = O + np.array([ca * 0.5, y - O[1], sa * 0.5])
            tip = O + np.array([ca * rx, y - O[1] + lean, sa * rz])
            out.append(Leaf(base, tip, width, 0.075, (0.0, -1.0, 0.0) - 0.3 * d, mid=0.5,
                            r_base=0.1, r_tip=0.15, bend=-0.1, cup=0.06, crease=0.025))
        return out

    petals = (ring(12, 0.0, 0.3, (1.68, 1.36, 1.2), 0.4, 0.14)
              + ring(11, 16.0, 0.48, (1.46, 1.2, 1.06), 0.36, 0.34)
              + ring(8, 8.0, 0.72, (1.05, 0.95, 0.9), 0.34, 0.2))  # back rosette

    def petal_fn(p):
        d = None
        for lf in petals:
            v = lf(p)
            d = v if d is None else np.minimum(d, v)
        return d

    braid_path = catmull([(0.0, 0.95, 2.5), (0.0, 1.3, 1.85), (0.0, 1.26, 1.2), (0.0, 0.6, 0.6)], 3)

    def braid(p):
        d = None
        for i, c in enumerate(braid_path):
            sx = 1 if i % 2 else -1
            e = ellipsoid(p, c + np.array([sx * 0.09, 0.0, 0.0]), (0.23, 0.17, 0.26), rot(0, sx * 32, 0))
            d = e if d is None else smin(d, e, 0.04)
        return d

    ears = [Leaf((sx * 0.68, -0.12, 2.3), (sx * 0.88, -0.34, 1.12), 0.26, 0.1, (sx * 0.9, -0.45, 0.0),
                 mid=0.58, r_base=0.12, r_tip=0.17, bend=0.05) for sx in (-1, 1)]

    def body(p):
        d = ellipsoid(p, (0, 0, 0.56), (0.48, 0.42, 0.52))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.2, -0.07, 0.09), (0.16, 0.2, 0.12)), 0.06)
            d = smin(d, round_cone(p, (sx * 0.4, -0.05, 0.82), (sx * 0.3, -0.6, 0.82), 0.115, 0.105), 0.05)
            d = smin(d, sphere(p, (sx * 0.3, -0.64, 0.84), 0.105), 0.03)
        return flat_base(d, p)

    def ears_fn(p):
        return np.minimum(ears[0](p), ears[1](p))

    CR = rot(-10, 0, 0)
    crown_c = np.array([0.0, -0.06, 2.72])
    tips = []
    for i in range(6):
        a = math.radians(-90 + i * 60)
        tall = 0.3 if i == 0 else (0.24 if i in (1, 5) else 0.2)
        base = crown_c + CR @ np.array([math.cos(a) * 0.3, math.sin(a) * 0.3, 0.05])
        tips.append((base, crown_c + CR @ np.array([math.cos(a) * 0.36, math.sin(a) * 0.36, 0.05 + tall])))

    def crown(p):
        band = cylinder(p, crown_c, 0.34, 0.09, 0.03, CR)
        band = smax(band, -cylinder(p, crown_c + CR @ np.array([0, 0, 0.06]), 0.26, 0.14, 0.02, CR), 0.02)
        d = band
        for b, t in tips:
            d = smin(d, round_cone(p, b, t, 0.08, 0.035), 0.04)
            d = smin(d, sphere(p, t + CR @ np.array([0, 0, 0.045]), 0.065), 0.02)
        return d

    OC = np.array([0.0, -0.74, 0.86])
    RO = frame((0.0, -1.0, 0.18))

    def orb(p):
        return cylinder(p, OC, 0.38, 0.08, 0.05, RO)

    def orb_sun(p):
        x, y, z = local(p, OC, RO)
        r = np.sqrt(x * x + y * y)
        ang = np.arctan2(y, x)
        rays = np.maximum(np.abs(r - 0.265) - 0.07, (np.abs(np.sin(ang * 4.0)) - 0.3) * r)
        region = np.minimum(r - 0.14, rays)
        region = np.maximum(region, -z)
        return overlay(orb(p), region, 0.012, depth=0.04, k=0.006)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.011, tris=11000),
        Comp(f"{N}_Ears", ears_fn, skin, voxel=0.007, tris=4000),
        Comp(f"{N}_Petals", petal_fn, petal_m, voxel=0.009, tris=18000,
             ramp=lambda x, y, z: np.clip((np.sqrt(x * x + (z - 1.9) ** 2) - 0.8) / 0.9, 0, 1)),
        Comp(f"{N}_Braid", braid, braid_m, voxel=0.007, tris=5000),
        Comp(f"{N}_Crown", crown, gold, voxel=0.005, tris=5000),
        Comp(f"{N}_Orb", orb, orb_m, voxel=0.006, tris=3000),
        Comp(f"{N}_OrbSun", orb_sun, sun_m, voxel=0.004, tris=2500),
        Comp(f"{N}_Body", body, skin, voxel=0.008, tris=9000),
    ]
    comps += face(N, head, -0.35, dict(kind="happy", dx=0.4, z=1.64, w=0.115, th=0.021),
                  (0.0, 1.5, 0.065, 55, 0.014), (0.62, 1.48, (0.13, 0.085)), fm)
    return assemble(N, "Sunbeam Sprite", "Rare", comps, {}, ((-2.1, -1.4, -0.2), (2.1, 1.6, 3.8)),
                    catalog="grove.star")


FIGURES = {
    "pebble-pip": pebble_pip,
    "sprout-scout": sprout_scout,
    "acorn-dot": acorn_dot,
    "mallow-cap": mallow_cap,
    "moon-moth": moon_moth,
    "sunbeam-sprite": sunbeam_sprite,
}
