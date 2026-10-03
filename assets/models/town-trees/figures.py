"""Blindbox Town trees: the bonsai-style sakura and three green trees from the approved mockup.

Town decoration only (not catalog figures). Built with tools/figures/build.py:
  FIG_ASSETS=models blender -b --factory-startup --python tools/figures/build.py -- town-trees <slug> final
Units are studs at model scale (about 3.5 tall); the town scales each placement.
+Z is up. Crowns are made of blossom/leaf clusters so the families read as one set.
"""

import math

import numpy as np

from sdf import ellipsoid, overlay, round_cone, smax, smin, sphere, tube  # noqa: F401

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


def assemble(name, title, rarity, comps, bounds, **info):
    materials = {}
    for c in comps:
        mname, m = c.mat
        materials[mname] = m
        c.mat = mname
    return dict(name=name, title=title, rarity=rarity, comps=comps, mats=materials, bounds=bounds, **info)


# ------------------------------------------------------------------ value noise

def _hash(ix, iy, iz, seed):
    h = np.sin(ix * 127.1 + iy * 311.7 + iz * 74.7 + seed * 19.19) * 43758.5453
    return h - np.floor(h)


def noise(p, freq, seed=0.0):
    """Smooth 3D value noise in [0, 1]."""
    x, y, z = p[0] * freq, p[1] * freq, p[2] * freq
    ix, iy, iz = np.floor(x), np.floor(y), np.floor(z)
    fx, fy, fz = x - ix, y - iy, z - iz
    ux, uy, uz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    out = 0.0
    for dx in (0, 1):
        wx = ux if dx else 1 - ux
        for dy in (0, 1):
            wy = uy if dy else 1 - uy
            for dz in (0, 1):
                wz = uz if dz else 1 - uz
                out = out + wx * wy * wz * _hash(ix + dx, iy + dy, iz + dz, seed)
    return out


def fbm(p, freq, octaves=3, seed=0.0):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + amp * noise(p, freq * (2.05**o), seed + o * 7.3)
        norm += amp
        amp *= 0.5
    return total / norm


def worley(p, cell, seed=0.0):
    """Distance to the nearest jittered feature point on a lattice of size `cell`."""
    x, y, z = p[0] / cell, p[1] / cell, p[2] / cell
    ix, iy, iz = np.floor(x), np.floor(y), np.floor(z)
    best = np.full(np.shape(x), 9.0)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                cx, cy, cz = ix + dx, iy + dy, iz + dz
                jx = _hash(cx, cy, cz, seed)
                jy = _hash(cx, cy, cz, seed + 1.7)
                jz = _hash(cx, cy, cz, seed + 3.1)
                d2 = (cx + jx - x) ** 2 + (cy + jy - y) ** 2 + (cz + jz - z) ** 2
                best = np.minimum(best, d2)
    return np.sqrt(best) * cell


# ------------------------------------------------------------------ structure

TRUNK = [(0.0, 0.0, -0.02), (0.12, 0.02, 0.42), (-0.08, 0.0, 0.82), (-0.2, -0.02, 1.16),
         (-0.06, 0.02, 1.5), (0.16, 0.0, 1.78)]
TRUNK_R = [0.24, 0.19, 0.155, 0.135, 0.12, 0.1]

# (control points, radii): gnarled limbs that carry the blossom pads.
BRANCHES = [
    ([(-0.06, 0.02, 1.5), (-0.45, 0.06, 1.78), (-0.95, 0.04, 2.0), (-1.42, 0.08, 2.08)], [0.1, 0.075, 0.055, 0.04]),
    ([(0.16, 0.0, 1.78), (0.5, -0.06, 1.92), (0.95, -0.04, 1.86), (1.32, -0.08, 1.72)], [0.095, 0.07, 0.05, 0.038]),
    ([(0.16, 0.0, 1.78), (0.12, 0.18, 2.12), (0.02, 0.3, 2.42)], [0.085, 0.06, 0.04]),
    ([(0.16, 0.0, 1.78), (0.36, -0.2, 2.06), (0.5, -0.3, 2.3)], [0.075, 0.055, 0.038]),
    ([(-0.08, 0.0, 0.82), (0.25, -0.08, 0.92), (0.62, -0.16, 0.96), (0.86, -0.2, 0.9)], [0.08, 0.06, 0.045, 0.034]),
    ([(-0.2, -0.02, 1.16), (-0.48, 0.02, 1.2), (-0.72, 0.06, 1.12)], [0.07, 0.05, 0.036]),
]

# Blossom pads: (center, radii, droop) – wide, flattish cushions, heavier toward the left.
PADS = [
    ((-1.2, 0.05, 2.14), (0.78, 0.68, 0.4), 0.7),
    ((-1.72, 0.0, 1.95), (0.42, 0.42, 0.34), 0.9),
    ((-0.5, 0.02, 2.4), (0.66, 0.66, 0.44), 0.35),
    ((0.24, 0.12, 2.52), (0.72, 0.7, 0.48), 0.3),
    ((-0.06, 0.18, 2.86), (0.42, 0.42, 0.3), 0.2),
    ((1.04, -0.06, 2.02), (0.66, 0.58, 0.38), 0.6),
    ((1.48, -0.08, 1.82), (0.36, 0.36, 0.3), 0.9),
    ((0.12, 0.46, 2.24), (0.58, 0.42, 0.38), 0.35),
    ((-0.62, -0.32, 2.18), (0.42, 0.34, 0.32), 0.5),
    ((0.62, -0.36, 2.28), (0.42, 0.34, 0.34), 0.5),
    ((0.56, -0.14, 0.98), (0.26, 0.24, 0.17), 1.2),
    ((0.84, -0.2, 0.94), (0.34, 0.3, 0.2), 1.4),
    ((1.08, -0.24, 0.78), (0.22, 0.22, 0.24), 1.6),
    ((-0.56, 0.04, 1.18), (0.24, 0.24, 0.16), 1.2),
    ((-0.78, 0.06, 1.08), (0.28, 0.26, 0.19), 1.4),
    ((-0.96, 0.06, 0.92), (0.17, 0.18, 0.2), 1.6),
]


def trunk_sdf(p):
    d = tube(p, TRUNK, TRUNK_R, k=0.05, samples=8)
    for pts, rs in BRANCHES:
        d = smin(d, tube(p, pts, rs, k=0.03, samples=6), 0.07)
    # Root flare: four roots splaying into a low, soil-like mound.
    for ang in (20, 115, 205, 300):
        a = math.radians(ang)
        tip = (0.46 * math.cos(a), 0.46 * math.sin(a), 0.0)
        mid = (0.22 * math.cos(a), 0.22 * math.sin(a), 0.1)
        d = smin(d, tube(p, [(0, 0, 0.2), mid, tip], [0.12, 0.08, 0.045], k=0.02, samples=4), 0.08)
    mound = ellipsoid(p, (0.0, 0.0, -0.02), (0.56, 0.5, 0.1))
    d = smin(d, mound, 0.06)
    # Bark: shallow vertical grooves that wander with the trunk.
    groove = np.sin(np.arctan2(p[1], p[0] - 0.02 * p[2]) * 9.0 + p[2] * 2.5)
    return d + 0.012 * groove * np.clip(1.9 - p[2], 0.0, 1.0)


def canopy_sdf(p, pads):
    d = None
    for c, r, droop in pads:
        e = ellipsoid(p, c, r)
        # Pull the underside down into hanging blossom clumps.
        below = np.clip(c[2] - p[2], 0.0, None)
        hang = droop * 0.26 * (noise((p[0], p[1], p[2] * 0.45), 6.0, 3.1) - 0.42) * np.clip(below / r[2], 0.0, 1.0)
        e = e - hang
        d = e if d is None else smin(d, e, 0.12)
    # Big soft clumps, then a skin made of small round blossom clusters for a frayed edge.
    clumps = fbm(p, 3.4, 2, 1.7) - 0.5
    body = d + 0.2 * clumps
    shell = np.abs(body + 0.05) < 0.16
    blossoms = np.where(shell, worley(p, 0.15, 2.3) - 0.085 + 0.25 * np.maximum(body + 0.05, 0.0), 9.0)
    return smin(body + 0.07, blossoms, 0.035)


def speckle_region(p):
    """Patches of deeper coral blossom, like the reference's red flecks."""
    n = noise(p, 34.0, 21.0)
    m = noise(p, 2.6, 5.0)
    return (0.76 - 0.14 * m) - n


def sakura():
    N = "Sakura"
    bark = (f"{N}_Bark", Mat("#3E2C28", rough=0.85, coat=0.0))
    blossom = (f"{N}_Blossom", Mat(["#F1C2D1", "#FADFE8", "#FFFAFC"], rough=0.78, sheen=0.7, subsurface=0.2))
    coral = (f"{N}_Coral", Mat("#EF8A9B", rough=0.65))
    soil = (f"{N}_Moss", Mat("#5E4A3E", rough=0.9))

    upper = PADS[:10]
    lower = PADS[10:]

    def upper_fn(p):
        return canopy_sdf(p, upper)

    def lower_fn(p):
        return canopy_sdf(p, lower)

    def group(*idx):
        pads = [PADS[i] for i in idx]
        return lambda p: canopy_sdf(p, pads)

    def speck(fn):
        return lambda p: overlay(fn(p), speckle_region(p), 0.012, depth=0.05, k=0.006)

    def moss(p):
        region = np.maximum(-(0.1 - p[2]), np.sqrt(p[0] ** 2 + p[1] ** 2) - 0.6)
        return overlay(trunk_sdf(p), region, 0.008, depth=0.04, k=0.01)

    zr = lambda x, y, z: np.clip((z - 1.6) / 1.4, 0.0, 1.0)
    comps = [
        Comp(f"{N}_Trunk", trunk_sdf, bark, voxel=0.01, tris=6000),
        Comp(f"{N}_CanopyWest", group(0, 1, 8), blossom, voxel=0.01, tris=10000, ramp=zr),
        Comp(f"{N}_CanopyCrown", group(2, 3, 4), blossom, voxel=0.01, tris=10000, ramp=zr),
        Comp(f"{N}_CanopyEast", group(5, 6, 9), blossom, voxel=0.01, tris=10000, ramp=zr),
        Comp(f"{N}_CanopyBack", group(7), blossom, voxel=0.01, tris=6000, ramp=zr),
        Comp(f"{N}_CanopyLow", lower_fn, blossom, voxel=0.01, tris=6000, ramp=lambda x, y, z: np.clip((z - 0.7) / 0.8, 0, 1)),
        Comp(f"{N}_SpecklesHigh", speck(upper_fn), coral, voxel=0.005, tris=9000),
        Comp(f"{N}_SpecklesLow", speck(lower_fn), coral, voxel=0.006, tris=3000),
        Comp(f"{N}_RootMound", moss, soil, voxel=0.008, tris=2000),
    ]
    return assemble(N, "Sakura", "Decor", comps, ((-2.6, -1.6, -0.2), (2.4, 1.6, 3.5)), catalog=None)


# ------------------------------------------------------------------ green trees

LEAF = ["#5C9C4E", "#86C46E", "#B6E08F"]  # shade -> body -> sun, matching the mockup palette
BARK_GREEN = "#7A5640"


def leafy(d, cell=0.2, size=0.11, clump=0.13, seed=0.0):
    """Turn a soft crown SDF into a surface of rounded leaf clusters."""
    def fn(p):
        base = d(p) + clump * (fbm(p, 2.8, 2, seed + 1.3) - 0.5)
        shell = np.abs(base + 0.05) < 0.2
        bumps = np.where(shell, worley(p, cell, seed + 2.7) - size + 0.25 * np.maximum(base + 0.05, 0.0), 9.0)
        return smin(base + 0.08, bumps, 0.04)

    return fn


def flared_trunk(p, top, r0, r1, lean=(0.0, 0.0), roots=4, root_len=0.42):
    lx, ly = lean
    d = tube(p, [(0.0, 0.0, -0.02), (lx * 0.4, ly * 0.4, top * 0.45), (lx, ly, top)], [r0, (r0 + r1) / 2, r1], k=0.04, samples=6)
    for i in range(roots):
        a = math.radians(30 + i * 360 / roots)
        tip = (root_len * math.cos(a), root_len * math.sin(a), 0.0)
        mid = (0.5 * root_len * math.cos(a), 0.5 * root_len * math.sin(a), 0.08)
        d = smin(d, tube(p, [(0, 0, 0.22), mid, tip], [r0 * 0.6, r0 * 0.4, r0 * 0.2], k=0.02, samples=4), 0.07)
    groove = np.sin(np.arctan2(p[1], p[0]) * 8.0 + p[2] * 1.5)
    return d + 0.01 * groove * np.clip(top + 0.2 - p[2], 0.0, 1.0)


def puffball():
    """G1 Puffball: a chunky broadleaf with a flared root base and a big round crown."""
    N = "Puffball"
    bark = (f"{N}_Bark", Mat(BARK_GREEN, rough=0.85))
    leaves = (f"{N}_Leaves", Mat(LEAF, rough=0.75, sheen=0.4))
    puffs = [
        ((0.0, 0.0, 2.2), (0.95, 0.9, 0.82)),
        ((0.78, 0.04, 1.86), (0.6, 0.58, 0.52)),
        ((-0.8, -0.02, 1.84), (0.6, 0.58, 0.52)),
        ((0.06, -0.7, 1.9), (0.6, 0.5, 0.52)),
        ((-0.04, 0.72, 1.92), (0.6, 0.5, 0.52)),
        ((0.3, -0.12, 2.78), (0.52, 0.5, 0.42)),
        ((-0.34, 0.18, 2.72), (0.48, 0.46, 0.4)),
    ]

    def crown_base(sel):
        def fn(p):
            d = None
            for i in sel:
                c, r = puffs[i]
                e = ellipsoid(p, c, r)
                d = e if d is None else smin(d, e, 0.2)
            return d
        return fn

    def trunk(p):
        d = flared_trunk(p, 1.5, 0.24, 0.16, lean=(0.05, 0.0), root_len=0.32)
        for tip in ((0.5, 0.0, 1.85), (-0.48, 0.08, 1.8), (0.0, 0.2, 2.1)):
            d = smin(d, tube(p, [(0.05, 0.0, 1.3), tip], [0.11, 0.06], k=0.02, samples=4), 0.05)
        return d

    zr = lambda x, y, z: np.clip((z - 1.25) / 1.75, 0.0, 1.0)
    comps = [
        Comp(f"{N}_Trunk", trunk, bark, voxel=0.01, tris=4000),
        Comp(f"{N}_CrownCore", leafy(crown_base([0, 5, 6]), seed=3.0), leaves, voxel=0.011, tris=10000, ramp=zr),
        Comp(f"{N}_CrownSides", leafy(crown_base([1, 2, 3, 4]), seed=3.0), leaves, voxel=0.011, tris=10000, ramp=zr),
    ]
    return assemble(N, "Puffball", "Decor", comps, ((-2.0, -2.0, -0.2), (2.0, 2.0, 3.6)), catalog=None)


def poplar():
    """G2 Poplar: a tall, narrow column of stacked leaf puffs on a short trunk."""
    N = "Poplar"
    bark = (f"{N}_Bark", Mat(BARK_GREEN, rough=0.85))
    leaves = (f"{N}_Leaves", Mat(LEAF, rough=0.75, sheen=0.4))
    tiers = [(0.95, 0.5), (1.38, 0.55), (1.82, 0.53), (2.24, 0.48), (2.62, 0.42), (2.96, 0.34), (3.24, 0.24)]

    def column(p):
        d = None
        for i, (z, r) in enumerate(tiers):
            off = 0.06 * (1 if i % 2 else -1)
            e = ellipsoid(p, (off, -off * 0.5, z), (r, r * 0.92, 0.36))
            d = e if d is None else smin(d, e, 0.16)
        return d

    def trunk(p):
        return flared_trunk(p, 1.0, 0.16, 0.11, roots=3, root_len=0.3)

    zr = lambda x, y, z: np.clip((z - 0.7) / 2.7, 0.0, 1.0)
    comps = [
        Comp(f"{N}_Trunk", trunk, bark, voxel=0.009, tris=2500),
        Comp(f"{N}_Column", leafy(column, cell=0.17, size=0.095, clump=0.1, seed=6.0), leaves, voxel=0.01, tris=14000, ramp=zr),
    ]
    return assemble(N, "Poplar", "Decor", comps, ((-1.0, -1.0, -0.2), (1.0, 1.0, 3.7)), catalog=None)


def topiary():
    """G3 Topiary Ball: a clipped ball on a straight stem, dotted with pastel flowers."""
    N = "Topiary"
    bark = (f"{N}_Stem", Mat(BARK_GREEN, rough=0.85))
    leaves = (f"{N}_Leaves", Mat(LEAF, rough=0.7, sheen=0.4))
    pink = (f"{N}_FlowerPink", Mat("#F4A9C4", rough=0.5, coat=0.2))
    yellow = (f"{N}_FlowerYellow", Mat("#F7D07E", rough=0.5, coat=0.2))
    centre, radius = (0.0, 0.0, 2.15), 0.95

    def ball_base(p):
        d = sphere(p, centre, radius)
        # Faint clipping bands give it a tended look.
        return d + 0.012 * np.sin((p[2] - centre[2]) * 14.0)

    ball = leafy(ball_base, cell=0.12, size=0.06, clump=0.03, seed=9.0)

    def stem(p):
        d = round_cone(p, (0, 0, 0.0), (0, 0, 1.4), 0.085, 0.07)
        return smin(d, ellipsoid(p, (0, 0, 0.02), (0.18, 0.18, 0.06)), 0.04)

    flowers = []
    for i, (az, el) in enumerate([(-30, 30), (35, 10), (-75, -5), (120, 35), (200, 15), (10, 60), (260, -10), (80, 50)]):
        a, e = math.radians(az), math.radians(el)
        c = np.array(centre) + (radius + 0.03) * np.array([math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)])
        flowers.append((c, i % 2))

    def flower_fn(kind):
        def fn(p):
            d = None
            for c, k in flowers:
                if k != kind:
                    continue
                s = sphere(p, c, 0.075)
                d = s if d is None else np.minimum(d, s)
            return d
        return fn

    zr = lambda x, y, z: np.clip((z - 1.3) / 1.8, 0.0, 1.0)
    comps = [
        Comp(f"{N}_Stem", stem, bark, voxel=0.008, tris=1500),
        Comp(f"{N}_Ball", ball, leaves, voxel=0.01, tris=12000, ramp=zr),
        Comp(f"{N}_FlowersPink", flower_fn(0), pink, voxel=0.005, tris=1200),
        Comp(f"{N}_FlowersYellow", flower_fn(1), yellow, voxel=0.005, tris=1200),
    ]
    return assemble(N, "Topiary Ball", "Decor", comps, ((-1.3, -1.3, -0.2), (1.3, 1.3, 3.3)), catalog=None)

FIGURES = {
    "sakura": sakura,
    "puffball": puffball,
    "poplar": poplar,
    "topiary": topiary,
}
