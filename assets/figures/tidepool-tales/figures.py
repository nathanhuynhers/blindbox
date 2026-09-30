"""Tidepool Tales figure definitions, reconstructed from the approved character sheets.

Units are studs. +Z is up, every figure faces -Y, the character's left is +X,
and the lowest point of each figure rests on Z = 0 after grounding.
"""

import math

import numpy as np

from sdf import (
    arc2, catmull, cylinder, ellipse2, ellipsoid, fan_angle, frame, front_decal, overlay,
    ribs, rot, round_box, round_cone, smax, smin, sphere, torus, tube, union,
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


def surface_point(fn, origin, direction, tmax=3.0, steps=600):
    """March from an interior point outward and return the surface crossing."""
    o = np.asarray(origin, float)
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
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


def sample_surface(fn, lo, hi, spacing, count, seed, keep=None, step=0.02):
    """Well-spaced points on an SDF surface, optionally filtered."""
    axes = [np.arange(lo[i], hi[i], step) for i in range(3)]
    g = np.meshgrid(*axes, indexing="ij")
    d = fn((g[0], g[1], g[2]))
    mask = np.abs(d) < step * 0.55
    pts = np.stack([g[0][mask], g[1][mask], g[2][mask]], axis=1)
    if keep is not None:
        pts = pts[keep(pts[:, 0], pts[:, 1], pts[:, 2])]
    rng = np.random.default_rng(seed)
    rng.shuffle(pts)
    chosen = []
    for q in pts:
        if all(np.linalg.norm(q - c) > spacing for c in chosen):
            chosen.append(q)
            if len(chosen) >= count:
                break
    return chosen


def spheres_region(p, centers, radii):
    d = None
    for c, r in zip(centers, radii):
        s = sphere(p, c, r)
        d = s if d is None else np.minimum(d, s)
    return d


def face(prefix, base, ylim, eye_dx, eye_z, eye_r, mouth, cheek_dx, cheek_z, cheek_r, mats,
         eye_cx=0.0, open_mouth=None):
    """Eyes, highlights, mouth and cheeks as thin skins conforming to `base`."""
    ru, rv = eye_r

    def eye_dome(p):
        dome = np.zeros_like(p[0])
        regs = []
        for sx in (-1.0, 1.0):
            u = p[0] - (eye_cx + sx * eye_dx)
            v = p[2] - eye_z
            regs.append(ellipse2(u, v, ru, rv))
            q = (u / ru) ** 2 + (v / rv) ** 2
            dome = np.maximum(dome, 0.028 * np.clip(1.0 - q, 0.0, 1.0))
        return np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim), 0.012 + dome

    def eyes(p):
        region, out = eye_dome(p)
        return overlay(base(p), region, out, depth=0.05, k=0.004)

    def shine(p):
        _, out = eye_dome(p)
        eye_surface = base(p) - out
        regs = []
        for sx in (-1.0, 1.0):
            u = p[0] - (eye_cx + sx * eye_dx - 0.3 * ru)
            v = p[2] - (eye_z + 0.38 * rv)
            regs.append(ellipse2(u, v, 0.3 * ru, 0.26 * rv))
        region = np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim)
        return overlay(eye_surface, region, 0.007, depth=0.02, k=0.002)

    def cheeks(p):
        regs = [
            ellipse2(p[0] - sx * cheek_dx, p[2] - cheek_z, cheek_r[0], cheek_r[1]) for sx in (-1.0, 1.0)
        ]
        region = np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim)
        return overlay(base(p), region, 0.008, depth=0.04, k=0.004)

    comps = [
        Comp(f"{prefix}_Eyes", eyes, mats["eyes"], voxel=0.005, tris=1400),
        Comp(f"{prefix}_EyeShine", shine, mats["shine"], voxel=0.004, tris=400),
        Comp(f"{prefix}_Cheeks", cheeks, mats["cheeks"], voxel=0.005, tris=900),
    ]

    if open_mouth is None:
        mx, mz, radius, aperture, thick = mouth

        def mouth_fn(p):
            region = np.maximum(arc2(p[0] - mx, p[2] - (mz + radius), radius, aperture, thick), p[1] - ylim)
            return overlay(base(p), region, 0.01, depth=0.04, k=0.002)

        comps.append(Comp(f"{prefix}_Mouth", mouth_fn, mats["mouth"], voxel=0.004, tris=500))
    else:
        mx, mz, rx, ry = open_mouth

        def mouth_region(p):
            u, v = p[0] - mx, p[2] - mz
            return np.maximum(smax(ellipse2(u, v, rx, ry), v - 0.25 * ry, 0.012), p[1] - ylim)

        def mouth_fn(p):
            return overlay(base(p), mouth_region(p), 0.01, depth=0.04, k=0.003)

        def tongue_fn(p):
            u, v = p[0] - mx, p[2] - (mz - 0.62 * ry)
            region = np.maximum(np.maximum(ellipse2(u, v, 0.62 * rx, 0.42 * ry), mouth_region(p) + 0.006), p[1] - ylim)
            return overlay(base(p) - 0.01, region, 0.005, depth=0.02, k=0.002)

        comps.append(Comp(f"{prefix}_Mouth", mouth_fn, mats["mouth"], voxel=0.004, tris=600))
        comps.append(Comp(f"{prefix}_Tongue", tongue_fn, mats["tongue"], voxel=0.004, tris=400))
    return comps


def face_mats(prefix):
    return {
        "eyes": (f"{prefix}_EyeGloss", Mat("#2A1D18", rough=0.18, coat=0.6)),
        "shine": (f"{prefix}_EyeShine", Mat("#FFFFFF", rough=0.3)),
        "cheeks": (f"{prefix}_Blush", Mat("#F4A3A0", rough=0.6)),
        "mouth": (f"{prefix}_Mouth", Mat("#3A2420", rough=0.4)),
        "tongue": (f"{prefix}_Tongue", Mat("#EE8C96", rough=0.45)),
    }


def assemble(name, title, rarity, comps, mats, bounds, **info):
    """Resolve material tuples into a flat figure description."""
    materials = {}
    for c in comps:
        mname, m = c.mat
        materials[mname] = m
        c.mat = mname
    return dict(name=name, title=title, rarity=rarity, comps=comps, mats=materials, bounds=bounds, **info)


# ---------------------------------------------------------------- 1. Bubble Bean

def bubble_bean():
    N = "BubbleBean"
    fm = face_mats(N)
    aqua = (f"{N}_Aqua", Mat("#6CC7C1", rough=0.48, coat=0.25))
    cream = (f"{N}_Cream", Mat("#F3EDD8", rough=0.5, coat=0.2))
    spot = (f"{N}_Spots", Mat("#C4EBE5", rough=0.5, coat=0.2))
    bubble = (f"{N}_Bubble", Mat("#E4F4F8", rough=0.04, alpha=0.38, transmission=1.0, thin_film=420.0))

    def torso(p):
        head = ellipsoid(p, (0, 0, 1.42), (0.97, 0.86, 0.9))
        lower = ellipsoid(p, (0, -0.03, 0.8), (0.84, 0.76, 0.74))
        return smin(head, lower, 0.35)

    def body(p):
        d = torso(p)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.36, -0.3, 0.15), (0.21, 0.25, 0.155)), 0.07)
        return smin(d, sphere(p, (0, 0.72, 0.4), 0.12), 0.06)

    def fin(sx):
        a = np.array([0.52 * sx, -0.12, -0.84])
        n = np.array([0.8 * sx, -0.55, 0.25])
        a /= np.linalg.norm(a)
        n = n - np.dot(n, a) * a
        n /= np.linalg.norm(n)
        R = np.stack([a, np.cross(n, a), n], axis=1)
        return lambda p: ellipsoid(p, (sx * 0.9, -0.1, 0.86), (0.34, 0.2, 0.1), R)

    def belly(p):
        region = front_decal(p, 0.0, 0.58, lambda u, v: ellipse2(u, v, 0.47, 0.37), y_limit=-0.2)
        return overlay(torso(p), region, 0.012, depth=0.05)

    spot_dirs = [(0, 32, 0.1), (-32, 20, 0.08), (30, 24, 0.09), (-58, 44, 0.08), (56, 40, 0.085),
                 (-14, 60, 0.075), (22, 58, 0.08), (-78, 16, 0.07), (76, 20, 0.075), (8, 8, 0.07),
                 (-118, 50, 0.065), (122, 48, 0.07), (-44, 70, 0.06), (150, 64, 0.055)]
    spot_pts = [surface_point(torso, (0, 0, 1.4), sph_dir(az, el)) for az, el, _ in spot_dirs]
    spot_r = [r for _, _, r in spot_dirs]

    def spots(p):
        return overlay(torso(p), spheres_region(p, spot_pts, spot_r), 0.01, depth=0.04)

    big = ((0.0, 0.1, 2.5), 0.58)
    small = [((-0.68, -0.04, 2.2), 0.16), ((0.69, 0.02, 2.18), 0.155), ((0.5, 0.24, 2.9), 0.1)]

    def bubbles(p):
        d = sphere(p, *big)
        for c, r in small:
            d = smin(d, sphere(p, c, r), 0.03)
        return d

    head_face = lambda p: ellipsoid(p, (0, 0, 1.42), (0.97, 0.86, 0.9))
    comps = [
        Comp(f"{N}_Body", body, aqua, voxel=0.011, tris=12000),
        Comp(f"{N}_Belly", belly, cream, voxel=0.006, tris=2400),
        Comp(f"{N}_Spots", spots, spot, voxel=0.005, tris=2600),
        Comp(f"{N}_LeftFin", fin(1), aqua, voxel=0.008, tris=1400),
        Comp(f"{N}_RightFin", fin(-1), aqua, voxel=0.008, tris=1400),
        Comp(f"{N}_BubbleCap", bubbles, bubble, voxel=0.01, tris=5000),
    ]
    comps += face(N, torso, -0.3, 0.33, 1.3, (0.1, 0.132), (0.0, 1.14, 0.075, 58, 0.015),
                  0.49, 1.12, (0.115, 0.075), fm)
    return assemble(N, "Bubble Bean", "Common", comps, {}, ((-1.6, -1.4, -0.3), (1.6, 1.4, 3.4)), catalog="tide.bubble")


# ---------------------------------------------------------------- 2. Coral Cuddle

def coral_cuddle():
    N = "CoralCuddle"
    fm = face_mats(N)
    coral = (f"{N}_Coral", Mat("#F27E70", rough=0.62, coat=0.1))
    cream = (f"{N}_Cream", Mat("#F6D2B6", rough=0.55, coat=0.1))
    dots = (f"{N}_CoralDots", Mat("#F9C2B6", rough=0.6))
    star = (f"{N}_Starfish", Mat("#EFC04A", rough=0.55, coat=0.15))
    star_dots = (f"{N}_StarfishDots", Mat("#FBE7A6", rough=0.55))

    C = (0.0, 0.0, 1.8)
    head_r = (0.76, 0.72, 0.72)
    face_cut = ((0.0, -0.6, 1.5), (0.56, 0.34, 0.47))

    def head(p):
        return ellipsoid(p, C, head_r)

    branches = [
        # (base, mid, tips)
        ((-0.26, 0.0, 2.3), (-0.4, 0.0, 2.56), [(-0.64, 0.0, 2.7), (-0.4, -0.02, 2.86), (-0.2, 0.02, 2.74)]),
        ((0.27, 0.02, 2.3), (0.42, 0.0, 2.58), [(0.34, 0.0, 2.88), (0.64, 0.02, 2.76)]),
        ((0.0, 0.32, 2.3), (0.02, 0.4, 2.56), [(-0.16, 0.46, 2.76), (0.2, 0.46, 2.72)]),
        ((-0.58, 0.0, 2.06), (-0.84, 0.0, 2.18), [(-0.98, 0.0, 2.4), (-1.04, 0.02, 2.06)]),
        ((0.58, 0.0, 2.06), (0.86, 0.0, 2.2), [(0.96, 0.0, 2.42), (1.05, -0.02, 2.1)]),
        ((-0.66, 0.06, 1.62), (-0.9, 0.06, 1.6), [(-1.02, 0.06, 1.76), (-0.96, 0.08, 1.42)]),
        ((0.66, 0.06, 1.62), (0.9, 0.06, 1.62), [(1.0, 0.06, 1.78), (0.98, 0.08, 1.44)]),
        ((0.0, 0.62, 1.8), (0.0, 0.88, 1.9), [(-0.18, 0.98, 2.02), (0.18, 0.98, 2.0)]),
        ((-0.38, 0.52, 2.06), (-0.5, 0.74, 2.24), [(-0.58, 0.86, 2.38)]),
        ((0.38, 0.52, 2.06), (0.52, 0.72, 2.22), [(0.62, 0.82, 2.36)]),
        ((-0.46, 0.5, 1.48), (-0.62, 0.74, 1.4), [(-0.7, 0.86, 1.3)]),
        ((0.46, 0.5, 1.48), (0.62, 0.74, 1.42), [(0.7, 0.84, 1.34)]),
    ]

    def branches_sdf(p):
        d = None
        for base, mid, tips in branches:
            t = round_cone(p, base, mid, 0.165, 0.14)
            for tip in tips:
                t = smin(t, round_cone(p, mid, tip, 0.13, 0.12), 0.06)
                t = smin(t, sphere(p, tip, 0.135), 0.03)
            d = t if d is None else np.minimum(d, t)
        return d

    knob_pts = [surface_point(head, C, sph_dir(az, el)) for az, el in
                [(-20, 20), (25, 10), (0, -10), (-50, 0), (50, -5), (-70, 40), (70, 38), (10, 45)]]

    def crown(p):
        d = smax(head(p), -ellipsoid(p, *face_cut), 0.06)
        d = smin(d, branches_sdf(p), 0.09)
        for q in knob_pts:
            d = smin(d, sphere(p, q, 0.075), 0.04)
        return d

    def face_surface(p):
        return head(p) + 0.075

    def face_fn(p):
        region = ellipsoid(p, face_cut[0], tuple(r + 0.02 for r in face_cut[1]))
        return overlay(face_surface(p), region, 0.0, depth=0.1, k=0.01)

    def torso(p):
        return ellipsoid(p, (0, 0, 0.64), (0.52, 0.46, 0.46))

    def body(p):
        d = torso(p)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.24, -0.06, 0.15), (0.17, 0.2, 0.16)), 0.06)
            d = smin(d, tube(p, [(sx * 0.4, -0.05, 0.92), (sx * 0.44, -0.34, 0.8), (sx * 0.2, -0.56, 0.74)],
                             [0.13, 0.125, 0.12], k=0.02), 0.05)
        d = smin(d, sphere(p, (0, 0.46, 0.42), 0.1), 0.05)
        return smin(d, ellipsoid(p, (0, 0, 1.12), (0.4, 0.38, 0.3)), 0.12)

    def belly(p):
        region = front_decal(p, 0.0, 0.52, lambda u, v: ellipse2(u, v, 0.34, 0.3), y_limit=-0.1)
        return overlay(torso(p), region, 0.01, depth=0.05)

    S = np.array([0.02, -0.6, 0.8])
    nrm = np.array([0.0, -0.96, 0.28])
    Rs = frame(nrm, (0, 0, 1))
    tips = []
    for i in range(5):
        a = math.radians(90 + 72 * i - 12)
        tips.append(S + Rs @ np.array([math.cos(a) * 0.36, math.sin(a) * 0.36, 0.0]))

    def starfish(p):
        # flatten along the star's normal so arms read as puffy, not tubular
        q = (p[0] - S[0], p[1] - S[1], p[2] - S[2])
        dn = q[0] * nrm[0] + q[1] * nrm[1] + q[2] * nrm[2]
        s = 1.45
        pf = (p[0] + nrm[0] * dn * (s - 1), p[1] + nrm[1] * dn * (s - 1), p[2] + nrm[2] * dn * (s - 1))
        d = sphere(pf, S, 0.15)
        for t in tips:
            d = smin(d, round_cone(pf, S, t, 0.14, 0.088), 0.05)
        return d / s

    dot_pts = []
    for t in tips:
        for f in (0.35, 0.62, 0.86):
            dot_pts.append(surface_point(starfish, S + (t - S) * f, -nrm, tmax=0.4))
    dot_pts.append(surface_point(starfish, S, -nrm, tmax=0.4))

    def star_dots_fn(p):
        return overlay(starfish(p), spheres_region(p, dot_pts, [0.028] * len(dot_pts)), 0.008, depth=0.03)

    crown_dot_pts = sample_surface(crown, (-1.35, -0.5, 1.0), (1.35, 1.2, 3.2), 0.2, 34, 7,
                                   keep=lambda x, y, z: ~((y < -0.25) & (z < 2.25) & (np.abs(x) < 0.62)))

    def crown_dots(p):
        return overlay(crown(p), spheres_region(p, crown_dot_pts, [0.046] * len(crown_dot_pts)), 0.009, depth=0.03)

    comps = [
        Comp(f"{N}_CoralCrown", crown, coral, voxel=0.011, tris=16000),
        Comp(f"{N}_CoralDots", crown_dots, dots, voxel=0.005, tris=3500),
        Comp(f"{N}_Face", face_fn, cream, voxel=0.006, tris=2400),
        Comp(f"{N}_Body", body, coral, voxel=0.01, tris=9000),
        Comp(f"{N}_Belly", belly, cream, voxel=0.006, tris=1400),
        Comp(f"{N}_Starfish", starfish, star, voxel=0.007, tris=4000),
        Comp(f"{N}_StarfishDots", star_dots_fn, star_dots, voxel=0.004, tris=1800),
    ]
    comps += face(N, face_surface, -0.3, 0.25, 1.55, (0.085, 0.112), (0.0, 1.41, 0.06, 58, 0.013),
                  0.39, 1.39, (0.095, 0.064), fm)
    return assemble(N, "Coral Cuddle", "Common", comps, {}, ((-1.5, -1.2, -0.3), (1.5, 1.4, 3.4)), catalog="tide.coral")


# ---------------------------------------------------------------- 3. Shell Scribe

def shell_scribe():
    N = "ShellScribe"
    fm = face_mats(N)
    shell_m = (f"{N}_Shell", Mat(["#E2D2EE", "#BFA5E0", "#9C80CC"], rough=0.55, coat=0.2))
    head_m = (f"{N}_Face", Mat("#F3E7EF", rough=0.55, coat=0.1))
    body_m = (f"{N}_Lavender", Mat("#DACAE9", rough=0.55, coat=0.1))
    cover = (f"{N}_BookCover", Mat("#9B6A44", rough=0.6))
    pages = (f"{N}_BookPages", Mat("#F7EFDD", rough=0.7))
    emblem = (f"{N}_BookEmblem", Mat("#DDB172", rough=0.45))
    pencil = (f"{N}_PencilBody", Mat("#F2C24F", rough=0.5))
    eraser = (f"{N}_PencilEraser", Mat("#F2A2A4", rough=0.6))
    ferrule = (f"{N}_PencilFerrule", Mat("#C9B48C", rough=0.35, metal=0.6))
    wood = (f"{N}_PencilWood", Mat("#EACB9C", rough=0.7))
    lead = (f"{N}_PencilLead", Mat("#4A4242", rough=0.5))

    HC = (0.0, -0.05, 1.72)

    def head(p):
        return ellipsoid(p, HC, (0.72, 0.64, 0.66))

    SC = (0.0, 0.1, 1.84)
    SR = np.array([1.02, 0.94, 1.0])
    hinge = (0.0, 0.8, 1.02)

    def shell(p):
        ang, dist = fan_angle(p, hinge)
        rib = ribs(ang, 28.0) * np.clip((dist - 0.25) / 0.6, 0.0, 1.0)
        outer = ellipsoid(p, SC, SR) - 0.11 * rib
        inner = ellipsoid(p, (SC[0], SC[1] - 0.02, SC[2] - 0.04), SR - 0.21)
        d = smax(outer, -inner, 0.02)
        # front opening: tilted plane; ribs push the rim forward into lobes
        n = np.array([0.0, -1.0, -0.28])
        n /= np.linalg.norm(n)
        front = (p[0] * n[0] + (p[1] + 0.52) * n[1] + (p[2] - 1.9) * n[2]) - 0.1 * rib
        d = smax(d, front, 0.05)
        bottom = (1.02 + 0.34 * np.clip(-p[1] / 0.6, 0, 1)) - p[2] - 0.08 * rib
        return smax(d, bottom, 0.05)

    def torso(p):
        return ellipsoid(p, (0, 0.0, 0.72), (0.5, 0.44, 0.5))

    def body(p):
        d = torso(p)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.21, -0.08, 0.15), (0.16, 0.2, 0.155)), 0.06)
            d = smin(d, tube(p, [(sx * 0.36, -0.06, 0.98), (sx * 0.46, -0.3, 0.92), (sx * 0.4, -0.5, 0.96)],
                             [0.12, 0.115, 0.11], k=0.02), 0.05)
            d = smin(d, sphere(p, (sx * 0.39, -0.54, 0.97), 0.115), 0.03)
        return smin(d, sphere(p, (0, 0.44, 0.4), 0.1), 0.05)

    B = np.array([0.0, -0.64, 0.98])
    halves = []
    for sx in (-1, 1):
        R = rot(0, 0, sx * 24)
        halves.append((sx, R))

    def cover_fn(p):
        d = None
        for sx, R in halves:
            c = B + R @ np.array([sx * 0.19, 0.0, 0.0])
            b = round_box(p, c, (0.19, 0.028, 0.25), 0.022, R)
            d = b if d is None else np.minimum(d, b)
        spine = cylinder(p, B + np.array([0, 0.02, 0]), 0.035, 0.25, 0.02)
        return smin(d, spine, 0.01)

    def pages_fn(p):
        d = None
        for sx, R in halves:
            c = B + R @ np.array([sx * 0.18, 0.07, 0.0])
            b = round_box(p, c, (0.17, 0.05, 0.225), 0.02, R)
            d = b if d is None else np.minimum(d, b)
        return d

    Rr = halves[1][1]
    Ec = B + Rr @ np.array([0.2, 0.0, 0.01])

    def emblem_fn(p):
        # small scallop: a fan of five rounded ribs on the right cover
        u = p[0] - Ec[0]
        v = p[2] - Ec[2]
        fan = smax(ellipse2(u, v - 0.02, 0.095, 0.085), -(v + 0.045), 0.01)
        a = np.arctan2(u, v + 0.06)
        groove = np.abs(np.sin(a * 5.0)) * np.sqrt(u * u + (v + 0.06) ** 2) - 0.006
        base_hinge = ellipse2(u, v + 0.055, 0.03, 0.02)
        region = np.maximum(np.minimum(smax(fan, -groove, 0.004), base_hinge), p[1] - (B[1] + 0.05))
        return overlay(cover_fn(p), region, 0.012, depth=0.03, k=0.003)

    pa = np.array([0.46, -0.66, 0.74])
    pb = np.array([0.58, -0.6, 1.44])
    axis = (pb - pa) / np.linalg.norm(pb - pa)

    def along(t):
        return pa + axis * t

    L = np.linalg.norm(pb - pa)
    Rp = frame(axis, (0, -1, 0))

    def pencil_body(p):
        mid = along(0.09 + (L - 0.2) * 0.5)
        return cylinder(p, mid, 0.058, (L - 0.2) * 0.5, 0.012, Rp)

    def pencil_ferrule(p):
        return cylinder(p, along(L - 0.085), 0.062, 0.028, 0.01, Rp)

    def pencil_eraser(p):
        return cylinder(p, along(L - 0.035), 0.058, 0.035, 0.03, Rp)

    def pencil_wood(p):
        return round_cone(p, along(0.1), along(0.015), 0.056, 0.022)

    def pencil_lead(p):
        return sphere(p, along(0.012), 0.024)

    comps = [
        Comp(f"{N}_ShellHood", shell, shell_m, voxel=0.01, tris=18000, ramp=lambda x, y, z: np.clip((z - 1.05) / 1.75, 0, 1)),
        Comp(f"{N}_Head", head, head_m, voxel=0.01, tris=7000),
        Comp(f"{N}_Body", body, body_m, voxel=0.009, tris=8000),
        Comp(f"{N}_BookCover", cover_fn, cover, voxel=0.006, tris=3000),
        Comp(f"{N}_BookPages", pages_fn, pages, voxel=0.006, tris=2000),
        Comp(f"{N}_BookEmblem", emblem_fn, emblem, voxel=0.003, tris=1200),
        Comp(f"{N}_Pencil", pencil_body, pencil, voxel=0.005, tris=1400),
        Comp(f"{N}_PencilFerrule", pencil_ferrule, ferrule, voxel=0.004, tris=600),
        Comp(f"{N}_PencilEraser", pencil_eraser, eraser, voxel=0.004, tris=600),
        Comp(f"{N}_PencilWood", pencil_wood, wood, voxel=0.004, tris=500),
        Comp(f"{N}_PencilLead", pencil_lead, lead, voxel=0.004, tris=200),
    ]
    comps += face(N, head, -0.35, 0.235, 1.66, (0.07, 0.095), (0.0, 1.53, 0.055, 58, 0.012),
                  0.4, 1.52, (0.09, 0.06), fm)
    return assemble(N, "Shell Scribe", "Common", comps, {}, ((-1.4, -1.2, -0.3), (1.4, 1.4, 3.3)), catalog="tide.shell")


# ---------------------------------------------------------------- 4. Jelly Jive

def jelly_jive():
    N = "JellyJive"
    fm = face_mats(N)
    fm["mouth"] = (f"{N}_Mouth", Mat("#4A2226", rough=0.4))
    bell_m = (f"{N}_Bell", Mat(["#BCCDF6", "#9BB2EF", "#7E98E4"], rough=0.3, coat=0.5, subsurface=0.25, thin_film=300.0))
    tent_m = (f"{N}_Tentacle", Mat("#A5BCF1", rough=0.32, coat=0.4, subsurface=0.25))
    spot_m = (f"{N}_Spots", Mat("#E4EAFB", rough=0.35, coat=0.3))

    C = np.array([0.0, 0.0, 1.36])
    lobes = []
    for i in range(10):
        a = 2 * math.pi * i / 10 + math.pi / 10
        lobes.append((0.83 * math.sin(a), -0.79 * math.cos(a), 0.76))

    def dome(p):
        d = ellipsoid(p, C, (0.95, 0.9, 0.86))
        return smax(d, 0.74 - p[2], 0.14)

    def bell(p):
        d = dome(p)
        for q in lobes:
            d = smin(d, ellipsoid(p, q, (0.24, 0.24, 0.19)), 0.12)
        return smax(d, -ellipsoid(p, (0, 0, 0.54), (0.62, 0.58, 0.3)), 0.08)

    tentacles = [
        ([(-0.55, -0.05, 0.8), (-0.88, -0.12, 0.62), (-1.08, -0.16, 0.66), (-1.14, -0.22, 0.84)], [0.18, 0.17, 0.155, 0.145]),
        ([(0.55, -0.1, 0.8), (0.86, -0.24, 0.86), (1.02, -0.36, 1.02), (1.0, -0.44, 1.2)], [0.18, 0.17, 0.155, 0.145]),
        ([(-0.26, -0.06, 0.74), (-0.32, -0.14, 0.42), (-0.3, -0.24, 0.18)], [0.19, 0.18, 0.18]),
        ([(0.26, 0.02, 0.74), (0.36, 0.08, 0.44), (0.44, 0.16, 0.18)], [0.19, 0.18, 0.18]),
        ([(0.0, 0.34, 0.74), (0.02, 0.56, 0.46), (-0.04, 0.56, 0.18)], [0.19, 0.18, 0.18]),
    ]

    def tent(p):
        d = None
        for pts, rs in tentacles:
            t = tube(p, pts, rs, k=0.03)
            d = t if d is None else smin(d, t, 0.06)
        return d

    spot_pts = sample_surface(dome, (-1.0, -1.0, 1.1), (1.0, 1.0, 2.3), 0.26, 16, 3,
                              keep=lambda x, y, z: (z > 1.6) | ((y > -0.2) & (z > 1.25)))

    def spots(p):
        rs = [0.07 if i % 3 else 0.05 for i in range(len(spot_pts))]
        return overlay(bell(p), spheres_region(p, spot_pts, rs), 0.01, depth=0.04)

    comps = [
        Comp(f"{N}_Bell", bell, bell_m, voxel=0.01, tris=14000, ramp=lambda x, y, z: np.clip((z - 0.64) / 1.6, 0, 1)),
        Comp(f"{N}_Spots", spots, spot_m, voxel=0.005, tris=2200),
        Comp(f"{N}_Tentacles", tent, tent_m, voxel=0.009, tris=9000),
    ]
    comps += face(N, bell, -0.4, 0.3, 1.18, (0.09, 0.118), None, 0.49, 1.04, (0.11, 0.072), fm,
                  open_mouth=(0.0, 1.03, 0.1, 0.085))
    return assemble(N, "Jelly Jive", "Uncommon", comps, {}, ((-1.5, -1.2, -0.3), (1.5, 1.2, 2.6)), catalog="tide.jelly")


# ---------------------------------------------------------------- 5. Ripple Ray

def ripple_ray():
    N = "RippleRay"
    fm = face_mats(N)
    mint = (f"{N}_Seafoam", Mat("#8FD6C8", rough=0.45, coat=0.3))
    cream = (f"{N}_Cream", Mat("#F2F0DC", rough=0.5, coat=0.2))
    spot_m = (f"{N}_Spots", Mat("#D5F1EA", rough=0.45, coat=0.2))

    B = (0.0, 0.0, 0.7)

    def torso(p):
        return ellipsoid(p, B, (0.8, 0.74, 0.6))

    def body(p):
        d = torso(p)
        for sx in (-1, 1):
            for fy in (-0.34, 0.3):
                d = smin(d, ellipsoid(p, (sx * 0.32, fy, 0.12), (0.13, 0.15, 0.12)), 0.06)
        return d

    def wing_sections(sx, shift, shrink):
        spine = [(0.34, 0.0, 0.8), (0.92, 0.06, 0.92), (1.38, 0.16, 1.22), (1.68, 0.3, 1.56), (1.8, 0.42, 1.86)]
        pts = catmull(spine, 8)
        n = len(pts)
        secs = []
        for i in range(n - 1):
            a, b = np.array(pts[i]), np.array(pts[i + 1])
            t = (b - a) / np.linalg.norm(b - a)
            f = i / (n - 2)
            chord = np.array([0.0, 0.95, -0.3])
            chord = chord - np.dot(chord, t) * t
            chord /= np.linalg.norm(chord)
            nrm = np.cross(t, chord)
            if nrm[2] < 0:
                nrm = -nrm
            c = 0.5 * (a + b)
            half_len = np.linalg.norm(b - a) * 1.2 + 0.06
            half_chord = 0.16 + 0.58 * (1.0 - f) ** 1.3
            half_thick = 0.16 + 0.16 * (1.0 - f) ** 1.2
            c = c + nrm * shift
            mirror = np.array([sx, 1.0, 1.0])
            R = np.stack([t * mirror, chord * mirror, nrm * mirror], axis=1)
            secs.append((c * mirror, (half_len - shrink, half_chord - shrink, half_thick - shrink * 0.6), R))
        return secs

    def wing(sx, shift=0.03, shrink=0.0, k=0.06):
        secs = wing_sections(sx, shift, shrink)

        def fn(p):
            d = None
            for c, r, R in secs:
                e = ellipsoid(p, c, r, R)
                d = e if d is None else smin(d, e, k)
            return d
        return fn

    wingL, wingR = wing(1), wing(-1)
    regionL, regionR = wing(1, -0.14, 0.0, 0.14), wing(-1, -0.14, 0.0, 0.14)

    def underL(p):
        return overlay(wingL(p), regionL(p), 0.012, depth=0.05, k=0.02)

    def underR(p):
        return overlay(wingR(p), regionR(p), 0.012, depth=0.05, k=0.02)

    def belly(p):
        region = np.minimum(
            front_decal(p, 0.0, 0.5, lambda u, v: ellipse2(u, v, 0.74, 0.44), y_limit=-0.15),
            p[2] - 0.32,
        )
        return overlay(torso(p), region, 0.012, depth=0.05)

    def tail(p):
        d = tube(p, [(0.0, 0.6, 0.48), (0.02, 0.92, 0.24), (0.08, 1.18, 0.14), (0.18, 1.34, 0.15)], [0.11, 0.09, 0.08, 0.08], k=0.03)
        return smin(d, sphere(p, (0.2, 1.36, 0.14), 0.1), 0.04)

    def wing_spots_for(sx, fn):
        pts, rs = [], []
        secs = wing_sections(sx, 0.03, 0.0)
        picks = [(0.24, -0.2, 0.07), (0.36, 0.05, 0.08), (0.5, -0.24, 0.075), (0.6, 0.02, 0.09),
                 (0.72, -0.2, 0.075), (0.84, 0.0, 0.07), (0.93, -0.18, 0.06), (0.46, 0.26, 0.06), (0.7, 0.24, 0.055)]
        for f, off, r in picks:
            c, rad, R = secs[min(int(f * (len(secs) - 1)), len(secs) - 1)]
            origin = c + R[:, 1] * off * rad[1] * 2.0
            pts.append(surface_point(fn, origin, R[:, 2], tmax=0.5))
            rs.append(r)
        return pts, rs

    lp, lr = wing_spots_for(1, wingL)
    rp, rr = wing_spots_for(-1, wingR)
    top_pts = [surface_point(torso, B, sph_dir(az, el)) for az, el in [(0, 62), (-40, 50), (40, 50)]]

    def spots(p):
        d1 = overlay(wingL(p), spheres_region(p, lp, lr), 0.01, depth=0.04)
        d2 = overlay(wingR(p), spheres_region(p, rp, rr), 0.01, depth=0.04)
        d3 = overlay(torso(p), spheres_region(p, top_pts, [0.07, 0.06, 0.06]), 0.01, depth=0.04)
        return np.minimum(np.minimum(d1, d2), d3)

    comps = [
        Comp(f"{N}_Body", body, mint, voxel=0.01, tris=9000),
        Comp(f"{N}_Belly", belly, cream, voxel=0.006, tris=2600),
        Comp(f"{N}_LeftWing", wingL, mint, voxel=0.01, tris=9000),
        Comp(f"{N}_RightWing", wingR, mint, voxel=0.01, tris=9000),
        Comp(f"{N}_LeftWingUnderside", underL, cream, voxel=0.006, tris=6000),
        Comp(f"{N}_RightWingUnderside", underR, cream, voxel=0.006, tris=6000),
        Comp(f"{N}_Tail", tail, mint, voxel=0.007, tris=2000),
        Comp(f"{N}_Spots", spots, spot_m, voxel=0.005, tris=3500),
    ]
    comps += face(N, lambda p: torso(p) - 0.012, -0.3, 0.29, 0.78, (0.095, 0.122), (0.0, 0.63, 0.065, 58, 0.014),
                  0.48, 0.62, (0.105, 0.07), fm)
    return assemble(N, "Ripple Ray", "Uncommon", comps, {}, ((-2.3, -1.2, -0.3), (2.3, 1.7, 2.4)), catalog="tide.ray")


# ---------------------------------------------------------------- 6. Pearl Regent

def pearl_regent():
    N = "PearlRegent"
    fm = face_mats(N)
    pearl = (f"{N}_Pearl", Mat("#F4ECDF", rough=0.3, coat=0.6, thin_film=520.0))
    shell_m = (f"{N}_ShellPink", Mat(["#EDBBAD", "#F1CBBE", "#F5DCD1"], rough=0.35, coat=0.5, thin_film=460.0))
    gold = (f"{N}_Gold", Mat("#D6A94F", rough=0.32, metal=0.85))

    hinge = (0.0, 0.62, 0.3)
    VC = np.array([0.0, -0.3, 1.58])
    VR = np.array([1.55, 1.02, 1.72])

    def rib_at(p, cpr):
        ang, dist = fan_angle(p, hinge)
        return ribs(ang, cpr) * np.clip((dist - 0.2) / 0.5, 0.0, 1.0)

    def valve_parts(p):
        rib = rib_at(p, 36.0)
        outer = ellipsoid(p, VC, VR) - 0.07 * rib
        inner = ellipsoid(p, VC - np.array([0, 0.03, 0]), VR - 0.18) - 0.07 * rib
        cut = (-0.1 - p[1]) - 0.06 * rib  # keep y > -0.1 (behind the figure)
        return outer, inner, cut

    DC = np.array([0.0, -0.42, 0.44])
    DR = np.array([1.45, 1.12, 0.5])

    def dish_parts(p):
        rib = rib_at(p, 30.0)
        outer = ellipsoid(p, DC, DR) - 0.05 * rib
        inner = ellipsoid(p, DC + np.array([0, 0, 0.3]), DR - np.array([0.2, 0.2, 0.08])) - 0.03 * rib
        return outer, inner

    def throne(p):
        outer, inner, cut = valve_parts(p)
        valve = smax(smax(outer, -inner, 0.02), cut, 0.03)
        valve = smax(valve, 0.25 - p[2], 0.02)
        do, di = dish_parts(p)
        dish = smax(smax(do, -di, 0.03), -p[2], 0.02)
        return smin(valve, dish, 0.06)

    def trim(p):
        outer, inner, cut = valve_parts(p)
        vt = np.maximum(np.maximum(outer - 0.02, -inner - 0.02), np.abs(cut) - 0.032)
        vt = np.maximum(vt, 0.5 - p[2])
        do, di = dish_parts(p)
        dt = np.maximum(np.maximum(do - 0.018, -di - 0.018), np.maximum(np.abs(di), np.abs(do)) - 0.05)
        dt = np.maximum(dt, 0.3 - p[2])
        return np.minimum(vt, dt)

    HC = (0.0, -0.46, 1.94)

    def head(p):
        return ellipsoid(p, HC, (0.74, 0.6, 0.6))

    def body(p):
        d = ellipsoid(p, (0, -0.42, 1.08), (0.52, 0.44, 0.48))
        d = smin(d, head(p), 0.1)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.27, -0.8, 0.78), (0.19, 0.25, 0.17), rot(12, 0, 0)), 0.07)
        d = smin(d, ellipsoid(p, (-0.5, -0.62, 1.08), (0.17, 0.22, 0.15), rot(0, 20, -20)), 0.06)
        d = smin(d, ellipsoid(p, (0.5, -0.66, 1.12), (0.17, 0.2, 0.16), rot(0, -25, 20)), 0.06)
        return d

    s0 = np.array([0.64, -0.8, 0.76])
    s1 = np.array([0.8, -0.8, 1.72])

    def scepter(p):
        d = round_cone(p, s0, s1, 0.05, 0.055)
        d = smin(d, sphere(p, s0, 0.075), 0.02)
        d = smin(d, torus(p, s1 + np.array([0, 0, -0.02]), 0.075, 0.035), 0.03)
        cup = ellipsoid(p, s1 + np.array([0.01, 0, 0.06]), (0.12, 0.12, 0.08))
        cup = smax(cup, -sphere(p, s1 + np.array([0.02, 0, 0.2]), 0.15), 0.02)
        return smin(d, cup, 0.03)

    orb_c = s1 + np.array([0.02, 0.0, 0.2])
    crown_c = np.array([0.0, -0.5, 2.48])
    Rc = rot(-8, 0, 0)
    points = []
    for i in range(5):
        a = math.radians(-90 + (i - 2) * 48)
        dirv = Rc @ np.array([math.cos(a) * 0.31, math.sin(a) * 0.31, 0.0])
        points.append(crown_c + dirv)

    def crown(p):
        band = cylinder(p, crown_c, 0.33, 0.085, 0.03, Rc)
        band = smax(band, -cylinder(p, crown_c + Rc @ np.array([0, 0, 0.05]), 0.25, 0.14, 0.02, Rc), 0.02)
        d = band
        for q in points:
            top = q + Rc @ np.array([0, 0, 0.26]) + (q - crown_c) * 0.12
            d = smin(d, round_cone(p, q + Rc @ np.array([0, 0, 0.02]), top, 0.085, 0.035), 0.04)
            d = smin(d, sphere(p, top + Rc @ np.array([0, 0, 0.04]), 0.065), 0.02)
        return d

    front_pt = crown_c + Rc @ np.array([0.0, -0.33, 0.0])

    def pearls(p):
        return np.minimum(sphere(p, orb_c, 0.16), sphere(p, front_pt + np.array([0, -0.04, 0.0]), 0.085))

    comps = [
        Comp(f"{N}_ShellThrone", throne, shell_m, voxel=0.012, tris=19000,
             ramp=lambda x, y, z: np.clip((np.sqrt((x - hinge[0]) ** 2 + (y - hinge[1]) ** 2 + (z - hinge[2]) ** 2) - 0.3) / 2.6, 0, 1)),
        Comp(f"{N}_ShellTrim", trim, gold, voxel=0.007, tris=9000),
        Comp(f"{N}_Body", body, pearl, voxel=0.009, tris=12000),
        Comp(f"{N}_Crown", crown, gold, voxel=0.006, tris=5000),
        Comp(f"{N}_Scepter", scepter, gold, voxel=0.005, tris=3000),
        Comp(f"{N}_Pearls", pearls, pearl, voxel=0.005, tris=2400),
    ]
    comps += face(N, head, -0.7, 0.245, 1.9, (0.075, 0.1), (0.0, 1.77, 0.058, 58, 0.013),
                  0.42, 1.75, (0.1, 0.066), fm)
    return assemble(N, "Pearl Regent", "Rare", comps, {}, ((-1.8, -1.6, -0.3), (1.8, 1.4, 3.6)), catalog="tide.pearl")


FIGURES = {
    "bubble-bean": bubble_bean,
    "coral-cuddle": coral_cuddle,
    "shell-scribe": shell_scribe,
    "jelly-jive": jelly_jive,
    "ripple-ray": ripple_ray,
    "pearl-regent": pearl_regent,
}
