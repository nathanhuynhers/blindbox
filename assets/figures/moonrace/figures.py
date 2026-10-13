"""Moonrace figure definitions, reconstructed from the approved character sheets.

Units are studs. +Z is up, every figure faces -Y, the character's left is +X, and the lowest
point rests on Z = 0 after grounding.

Hybrid construction (docs/FIGURE_COLLECTION_RUNBOOK.md, "Hybrid modeling"): SDFs for heads,
bodies, muzzles and fur masses; native sweeps (`modeling.sweep`) for tails, horns, whiskers,
cords, ribbons and trims; separate thin surface skins for every facial feature, belly patch,
stripe and trim. Colors are flat embedded albedo (shared presets from `materials.py`); gold is
painted resin with a little metal. No PBR maps: uniform materials gain nothing from them in
Roblox and they would add an unverified SurfaceAppearance import.

Collection-wide visual language from the sheets: chibi heads about 45% of the height, large
glossy amber eyes with a dark lash line and two highlights, blush, red/gold Lunar New Year
accessories with tassels, coins and knots.

MOON_FAST=<factor> coarsens SDF voxels (and their error limits) for quick preview iteration only;
never set it for final builds.
"""

import math
import os

import numpy as np

from materials import Mat, preset
from modeling import Comp, join_meshes, sweep
from sdf import (
    arc2, cylinder, ellipse2, ellipsoid, frame, local, overlay, rot, round_box, round_cone,
    smax, smin, sphere, surface_normal, surface_point, torus, tube,
)

RENDER_VIEW = "Khronos PBR Neutral|None|-0.8"
FAST = float(os.environ.get("MOON_FAST", "1"))
TRI_SCALE = 0.5
BOUNDS = ((-2.4, -2.4, -0.3), (2.4, 2.4, 3.9))

GOLD = "#E4B24C"
GOLD_DEEP = "#C98F2E"
RED = "#D8352E"
RED_DEEP = "#A82424"
CREAM = "#FBEBDD"
INK = "#2A1810"


# ------------------------------------------------------------------ materials and parts

def m_vinyl(color):
    return preset("satin_vinyl", color)


def m_matte(color):
    return preset("matte_plastic", color)


def m_gloss(color):
    return preset("glossy_vinyl", color)


def m_gold(color=GOLD):
    return Mat(color, rough=0.3, metal=0.45)


def m_fabric(color):
    return preset("soft_fabric", color, rough=0.78)


def C(name, fn, mat, *, voxel=0.008, tris=8000, err=None, islands=1, ramp=None, mesh=None, smooth=True,
      bounds=None):
    """One MeshPart. `mat` is a (material name, Mat) tuple; err defaults to 2.5 voxels."""
    if mesh is not None:
        comp = Comp(name, None, mat[0], mesh=mesh, tris=tris, max_surface_error=err or 0.006,
                    expected_islands=islands, ramp=ramp, smooth=smooth)
    else:
        v = voxel * FAST
        # min_faces drops Decimate debris (lone or twin flattened triangles in thin skins), which fail the
        # orientation/duplicate gates; every authored feature here meshes to hundreds of faces.
        comp = Comp(name, fn, mat[0], voxel=v, tris=tris, max_surface_error=(err or max(2.5 * voxel, 0.01)) * FAST,
                    expected_islands=islands, ramp=ramp, smooth=smooth, bounds=bounds, min_faces=12,
                    uv="auto" if ramp is not None else "legacy")
    comp.material = mat
    return comp


def S(name, meshes, mat, *, tris=8000, err=0.006, ramp=None):
    """A native sweep part from one or more MeshData sweeps (one island each)."""
    meshes = meshes if isinstance(meshes, list) else [meshes]
    data = meshes[0] if len(meshes) == 1 else join_meshes(meshes)
    return C(name, None, mat, mesh=data, tris=tris, err=err, islands=len(meshes), ramp=ramp)


def assemble(name, title, rarity, comps, catalog, bounds=BOUNDS, tri_scale=TRI_SCALE):
    mats = {}
    for c in comps:
        c.tris = max(300, min(19000, int(c.tris * tri_scale)))
        mats[c.material[0]] = c.material[1]
    return dict(name=name, title=title, rarity=rarity, comps=comps, mats=mats, bounds=bounds, catalog=catalog)


# ------------------------------------------------------------------ geometry helpers

def V(*a):
    return np.asarray(a if len(a) > 1 else a[0], float)


def U(fns, k=0.0):
    def fn(p):
        d = fns[0](p)
        for f in fns[1:]:
            d = smin(d, f(p), k) if k else np.minimum(d, f(p))
        return d
    return fn


def flat(fn, z0=0.0, k=0.02):
    return lambda p: smax(fn(p), z0 - p[2], k)


def taper(points, r0, r1, flat_ratio=1.0, power=1.0):
    n = len(points)
    t = np.linspace(0, 1, n) ** power
    r = r0 + (r1 - r0) * t
    return np.column_stack((r, r * flat_ratio))


def tail(points, r0, r1, flat_ratio=1.0, power=1.0, samples=8, sides=18):
    return sweep(points, taper(points, r0, r1, flat_ratio, power), samples=samples, sides=sides)


def rope(points, r, samples=8, sides=12):
    return sweep(points, r, samples=samples, sides=sides)


def anchor(fn, origin, direction, lift=0.0):
    """Surface point and outward normal where a ray from inside `fn` exits."""
    pt = surface_point(fn, origin, direction)
    n = surface_normal(fn, pt)
    return pt + n * lift, n


def rot2(u, v, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return u * c + v * s, -u * s + v * c


def seg2(u, v, a, b, th):
    pa = np.stack([u - a[0], v - a[1]])
    ba = np.array([b[0] - a[0], b[1] - a[1]])
    h = np.clip((pa[0] * ba[0] + pa[1] * ba[1]) / (ba @ ba), 0, 1)
    return np.sqrt((pa[0] - ba[0] * h) ** 2 + (pa[1] - ba[1] * h) ** 2) - th


class Decal:
    """2D shapes on a base surface: each item is (centre, normal, shape(u, v)).

    u runs toward the character's left (+X) and v upward for front-facing normals.
    """

    def __init__(self, base, items, out, depth=0.05, k=0.003, slab=0.25, up=(0, 0, 1)):
        self.base, self.out, self.depth, self.k, self.slab = base, out, depth, k, slab
        self.items = [(V(c), frame(n, up), shape) for c, n, shape in items]

    def region(self, p):
        d = None
        for c, R, shape in self.items:
            u, v, w = local(p, c, R)
            r = np.maximum(shape(u, v), np.abs(w) - self.slab)
            d = r if d is None else np.minimum(d, r)
        return d

    def __call__(self, p):
        return overlay(self.base(p), self.region(p), self.out, self.depth, self.k)


def decal(base, items, out, **kw):
    return Decal(base, items, out, **kw)


def front(base, x, z, y0=0.0, lift=0.0):
    """Anchor on the front of `base` at (x, z), searching from y0 toward -Y."""
    return anchor(base, (x, y0, z), (0, -1, 0), lift)


# ------------------------------------------------------------------ face kit

AMBER = ["#FBD27A", "#E59A35", "#A55A1E", "#4A2412"]  # bottom (bright) to top (dark)


def eyes(N, base, spots, ru, rv, *, tilt=8.0, iris=AMBER, closed=False, y0=0.0, shine=True, lid=None,
         brows=None, rim="#2B160C", pupil="#1E0F08", star_shine=False, brow_color="#6B4A3A"):
    """Large glossy chibi eyes on `base`. `spots` = [(x, z), ...]; first part is `<N>_Eyes`.

    Layers (separate parts so Roblox shows them as real geometry): dark eye body, iris ramp,
    pupil, highlights and the upper lash line with an outer flick. `tilt` lifts outer corners;
    `lid` flattens the top at lid*rv (relaxed/heavy lids); `brows` = (height, half-length,
    half-height, tilt) above each eye.
    """
    items = []
    for x, z in spots:
        c, n = front(base, x, z, y0)
        items.append((c, n, math.copysign(1.0, x) if x else 1.0))
    mats = {
        "eye": (f"{N}_EyeDark", m_gloss(rim)),
        "iris": (f"{N}_Iris", m_gloss(list(iris))),
        "pupil": (f"{N}_Pupil", m_gloss(pupil)),
        "shine": (f"{N}_EyeShine", m_gloss("#FFFFFF")),
        "lash": (f"{N}_Lash", m_matte("#2A1611")),
    }

    def shape_of(f, sx):
        return lambda u, v: f(*rot2(u, v, sx * tilt), sx)

    def make(f, out, **kw):
        return decal(base, [(c, n, shape_of(f, sx)) for c, n, sx in items], out, **kw)

    comps = []
    th = 0.024 * ru / 0.16
    if closed:
        def happy(u, v, sx):  # a bowed squint line
            R = ru * 1.1
            return arc2(u, -(v + R * 0.35), R, 58.0, th * 0.9)
        comps.append(C(f"{N}_Eyes", make(happy, 0.012), mats["lash"], voxel=0.0035, tris=1600, islands=len(items)))
    else:
        top = rv * (lid if lid is not None else 2.0)

        def body(u, v, sx):
            return np.maximum(ellipse2(u, v, ru, rv), v - top)

        def iris_s(u, v, sx):
            return np.maximum(ellipse2(u, v + 0.04 * rv, ru * 0.84, rv * 0.84), body(u, v, sx) + 0.004)

        def pupil_s(u, v, sx):
            return np.maximum(ellipse2(u, v - 0.02 * rv, ru * 0.4, rv * 0.44), body(u, v, sx) + 0.01)

        def shine_s(u, v, sx):
            cv = min(0.34 * rv, top - 0.3 * rv)
            if star_shine:
                q, w = np.abs(u + 0.28 * ru), np.abs(v - cv)
                big = np.maximum(q + w * 0.45 - 0.26 * ru, q * 0.45 + w - 0.26 * ru)
            else:
                big = ellipse2(u + 0.3 * ru, v - cv, 0.27 * ru, 0.25 * rv)
            small = ellipse2(u - 0.34 * ru, v + 0.42 * rv, 0.12 * ru, 0.11 * rv)
            return np.minimum(big, small)

        def lash_s(u, v, sx):
            low = min(0.08 * rv, top - 0.3 * rv)
            band = np.maximum(np.abs(body(u, v, sx) - 0.008) - th, low - v)
            fv = min(0.5 * rv, top)
            flick = seg2(u, v, (sx * 0.86 * ru, fv), (sx * 1.24 * ru, fv + 0.28 * rv), th * 0.7)
            return np.minimum(band, flick)

        ez = float(np.mean([z for _, z in spots]))

        def iris_t(x, y, z):
            return np.clip((z - (ez - rv * 0.8)) / (rv * 1.6), 0, 1)

        comps.append(C(f"{N}_Eyes", make(body, 0.010), mats["eye"], voxel=0.004, tris=2400, islands=len(items)))
        comps.append(C(f"{N}_Iris", make(iris_s, 0.016), mats["iris"], voxel=0.004, tris=2400, islands=len(items),
                       ramp=iris_t))
        comps.append(C(f"{N}_Pupil", make(pupil_s, 0.021), mats["pupil"], voxel=0.0035, tris=1200,
                       islands=len(items)))
        if shine:
            comps.append(C(f"{N}_EyeShine", make(shine_s, 0.026, k=0.002), mats["shine"], voxel=0.003, tris=1400,
                           islands=2 * len(items)))
        comps.append(C(f"{N}_Lash", make(lash_s, 0.026, k=0.002), mats["lash"], voxel=0.003, tris=2400,
                       islands=len(items)))
    if brows:
        bz, bl, bh, bt = brows

        def brow_s(u, v, sx):
            return ellipse2(*rot2(u - sx * 0.1 * ru, v - bz, sx * bt), bl, bh)
        comps.append(C(f"{N}_Brow", make(brow_s, 0.008, k=0.004), (f"{N}_BrowMat", m_matte(brow_color)),
                       voxel=0.004, tris=1000, islands=len(items)))
    return comps


def mouth_w(r, th=0.012, philtrum=0.0):
    """Cat-like double-arc mouth; optional short line up to the nose."""
    def shape(u, v):
        d = np.minimum(arc2(u - r, v, r, 75.0, th), arc2(u + r, v, r, 75.0, th))
        if philtrum:
            d = np.minimum(d, seg2(u, v, (0, 0), (0, philtrum), th))
        return d
    return shape


def mouth_smile(r, aperture=60.0, th=0.013):
    return lambda u, v: arc2(u, v - r, r, aperture, th)


def blob(ru, rv, du=0.0, dv=0.0, tilt=0.0):
    return lambda u, v: ellipse2(*rot2(u - du, v - dv, tilt), ru, rv)


def blush(N, base, spots, ru, rv, color="#F4A3A0", y0=0.0, out=0.005):
    items = [(*front(base, x, z, y0), blob(ru, rv)) for x, z in spots]
    return C(f"{N}_Blush", decal(base, items, out, k=0.012), (f"{N}_Blush", m_matte(color)), voxel=0.005,
             tris=1600, islands=len(items))


def path_param(points, samples=12):
    """t(x, y, z) in [0, 1]: normalized arc length of the nearest point on a Catmull-Rom path."""
    from sdf import catmull
    path = np.asarray(catmull([V(q) for q in points], samples))
    seg = np.linalg.norm(np.diff(path, axis=0), axis=1)
    arc = np.concatenate([[0], np.cumsum(seg)]) / seg.sum()

    def t(x, y, z):
        q = np.stack([np.ravel(x), np.ravel(y), np.ravel(z)], axis=1)
        out = np.empty(len(q))
        for i in range(0, len(q), 4096):
            d = np.linalg.norm(q[i:i + 4096, None, :] - path[None, :, :], axis=2)
            out[i:i + 4096] = arc[np.argmin(d, axis=1)]
        return out.reshape(np.shape(x))
    return t


def path_centre(points, samples=12, sigma=0.12):
    """Smoothly weighted z of nearby Catmull-Rom path samples (splits a tube into top and underside).

    A hard nearest-point lookup jumps between neighbouring turns and pinches the skins it drives.
    """
    from sdf import catmull
    path = np.asarray(catmull([V(q) for q in points], samples))

    def zc(p):
        q = np.stack([np.ravel(p[0]), np.ravel(p[1]), np.ravel(p[2])], axis=1)
        out = np.empty(len(q))
        for i in range(0, len(q), 8192):
            d = ((q[i:i + 8192, None, :] - path[None, :, :]) ** 2).sum(axis=2)
            w = np.exp(-(d - d.min(axis=1, keepdims=True)) / (2 * sigma * sigma))
            out[i:i + 8192] = (w * path[None, :, 2]).sum(axis=1) / w.sum(axis=1)
        return out.reshape(np.shape(p[0]))
    return zc


def bands(colors, period_stops):
    """Ramp stops that hold each color for `period_stops` entries (crisp bands on a 64px ramp)."""
    out = []
    for c in colors:
        out += [c] * period_stops
    return out


def mouth_open(w, h, tongue=False):
    """Open smile: a half-ellipse below v = 0; the tongue variant is its lower part."""
    if tongue:
        return lambda u, v: np.maximum(ellipse2(u, v + h * 0.72, w * 0.62, h * 0.42), ellipse2(u, v, w, h))
    return lambda u, v: np.maximum(ellipse2(u, v, w, h), v)


class Mantle:
    """Cape/cloak shell: an ellipsoid dome over the back whose sections flare toward the hem.

    Below `flare_z` the section scales by up to 1 + flare. The front opening keeps y > y_open,
    interpolated from `y_top` at the dome top to `y_bot` at the hem; the hem waves with `waves`
    lobes. `trim(width)` is a thicker border band along the hem and front edges.
    """

    def __init__(self, c, r, *, flare=0.5, flare_z=None, th=0.05, hem=0.02, waves=6, wave=0.06, y_top=-0.25,
                 y_bot=-0.1, power=1.6, folds=0, fold=0.0, layer=None, hem_front=0.0):
        self.c, self.r = V(c), V(r)
        self.folds, self.fold, self.hem_front = folds, fold, hem_front
        self.layer = layer  # (inner, outer) offsets from the surface; default centred on it
        self.flare, self.flare_z = flare, self.c[2] if flare_z is None else flare_z
        self.th, self.hem, self.waves, self.wave, self.y_top, self.y_bot, self.power = th, hem, waves, wave, y_top, y_bot, power

    def _parts(self, p):
        x, y, z = p[0] - self.c[0], p[1] - self.c[1], p[2]
        s = 1 + self.flare * np.clip((self.flare_z - z) / max(self.flare_z, 1e-6), 0, 1) ** self.power
        d = ellipsoid((x / s, y / s, np.maximum(z, self.c[2])), (0, 0, self.c[2]), self.r) * s  # hangs straight below the centre
        theta = np.arctan2(x, y)
        if self.folds:
            d = d - self.fold * np.sin(theta * self.folds) * np.clip((self.flare_z - z) / max(self.flare_z, 1e-6), 0, 1)
        front_rise = self.hem_front * np.clip(-y / self.r[1], 0, 1) ** 1.5
        hem = z - (self.hem + front_rise + self.wave * 0.5 * (1 + np.cos(theta * self.waves)))
        top = self.c[2] + self.r[2]
        t = np.clip((top - z) / (top - self.hem), 0, 1)
        opening = p[1] - (self.y_top + (self.y_bot - self.y_top) * t)
        return d, np.maximum(-hem, -opening), hem, opening

    def _shell(self, d, extra=0.0):
        if self.layer:
            return np.maximum(d - self.layer[1] - extra, self.layer[0] - extra - d)
        return np.abs(d) - self.th / 2 - extra

    def surface(self, p):
        return self._parts(p)[0]

    def __call__(self, p):
        d, region, _, _ = self._parts(p)
        return np.maximum(self._shell(d), region)

    def trim(self, width=0.07, extra=0.012):
        def fn(p):
            d, region, hem, opening = self._parts(p)
            return np.maximum(np.maximum(self._shell(d, extra), region), np.minimum(hem, opening) - width)
        return fn


def spikes(p, roots, tips, r0, r1=0.012, k=0.05):
    d = None
    for a, b in zip(roots, tips):
        e = round_cone(p, a, b, r0, r1)
        d = e if d is None else smin(d, e, k)
    return d


# ------------------------------------------------------------------ accessory kit

def tassel(p, top, length, r, grooves=10, R=None):
    """Knot bead, binding cap and a flared skirt with cord grooves, hanging down from `top`."""
    top = V(top)
    x, y, z = local(p, top, R)
    knot = sphere((x, y, z), (0, 0, -r * 0.7), r * 0.75)
    cap = cylinder((x, y, z), (0, 0, -r * 1.7), r * 0.62, r * 0.35, r=r * 0.2)
    zz = np.clip(-z - r * 1.9, 0, None) / length
    rad = r * (0.55 + 0.6 * np.clip(zz, 0, 1) ** 0.6)
    theta = np.arctan2(y, x)
    skirt = np.maximum(np.sqrt(x * x + y * y) - rad + 0.006 * np.abs(np.sin(theta * grooves / 2)),
                       np.maximum(z + r * 1.8, -z - r * 1.9 - length))
    return smin(smin(knot, cap, 0.01), skirt, 0.012)


def coin(p, c, n, r, th, hole=0.0, rim=True):
    R = frame(n)
    x, y, z = local(p, c, R)
    d = cylinder((x, y, z), (0, 0, 0), r, th / 2, r=th * 0.35)
    if rim:
        d = smin(d, torus((x, y, z), (0, 0, 0), r * 0.9, th * 0.42), 0.006)
    if hole:
        d = smax(d, -round_box((x, y, z), (0, 0, 0), (hole, hole, th * 2), hole * 0.25), 0.006)
    return d


def bell(p, c, r, R=None):
    x, y, z = local(p, c, R)
    dome = smax(ellipsoid((x, y, z), (0, 0, 0), (r, r, r * 1.05)), -z - r * 0.1, 0.02)
    lip = torus((x, y, z), (0, 0, -r * 0.12), r * 0.9, r * 0.14)
    loop = torus((y, z, x), (0, r * 1.05, 0), r * 0.22, r * 0.07)
    d = smin(smin(dome, lip, 0.03), loop, 0.02)
    slot = round_box((x, y, z), (0, -r * 0.9, -r * 0.15), (r * 0.12, r * 0.4, r * 0.32), r * 0.1)
    return smax(d, -slot, 0.01)


def flower(p, c, n, r, petals=5, spin=0.0, cup=0.25, th=None, petal_w=0.55):
    """Flat five-petal blossom facing `n` (petals only; add a centre separately)."""
    R = frame(n)
    x, y, z = local(p, c, R)
    th = th or r * 0.22
    d = None
    for i in range(petals):
        a = math.radians(spin + 360.0 * i / petals)
        ca, sa = math.cos(a), math.sin(a)
        u, v = x * ca + y * sa, -x * sa + y * ca
        e = ellipsoid((u, v, z), (r * 0.55, 0, -cup * r * 0.3 + cup * 0.0), (r * 0.5, r * petal_w * 0.62, th))
        d = e if d is None else smin(d, e, r * 0.08)
    return d


def knot_button(p, c, r):
    return sphere(p, c, r)


# ------------------------------------------------------------------ figures

def rat():
    N = "MoonRat"
    grey, ear_c, pink, cream, jacket = "#7A6D6E", "#8A7471", "#F3A9A3", "#F9E7D6", "#3E3A3F"
    hc = V(0, -0.02, 2.0)

    def head(p):
        d = ellipsoid(p, hc, (0.76, 0.66, 0.62))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.46, -0.2, 1.74), (0.36, 0.34, 0.3)), 0.16)
            # fur tufts on the cheek sides
            for dz, ang in ((0.05, -10), (-0.12, -30)):
                d = smin(d, round_cone(p, (sx * 0.62, -0.05, 1.8 + dz), (sx * 0.98, -0.05, 1.78 + dz + ang * -0.004),
                                       0.12, 0.012), 0.08)
        d = smin(d, ellipsoid(p, (0, -0.5, 1.78), (0.3, 0.22, 0.2)), 0.12)
        # forehead fur flick
        d = smin(d, round_cone(p, (0.05, -0.35, 2.48), (0.18, -0.42, 2.66), 0.1, 0.015), 0.07)
        return d

    face_c, face_n = front(head, 0, 1.78)

    def face_mask(u, v):
        return np.maximum(ellipse2(u, v + 0.05, 0.66, 0.36), -ellipse2(u, v - 0.42, 0.22, 0.22))

    ear_R = {sx: rot(-8, sx * 18, sx * 14) for sx in (-1, 1)}
    ear_c_ = {sx: V(sx * 0.86, 0.12, 2.62) for sx in (-1, 1)}

    def ears(p):
        d = None
        for sx in (-1, 1):
            R, c = ear_R[sx], ear_c_[sx]
            e = ellipsoid(p, c, (0.5, 0.13, 0.5), R)
            cut = ellipsoid(p, c + R @ V(0, -0.14, 0.0), (0.4, 0.1, 0.4), R)
            e = smax(e, -cut, 0.03)
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            R, c = ear_R[sx], ear_c_[sx]
            e = ellipsoid(p, c + R @ V(0, -0.03, 0.0), (0.39, 0.035, 0.39), R)
            d = e if d is None else np.minimum(d, e)
        return d

    # body: jacket torso, belly and trousers
    def torso(p):
        d = ellipsoid(p, (0, 0.02, 0.92), (0.6, 0.5, 0.62))
        d = smin(d, ellipsoid(p, (0, 0.04, 0.48), (0.62, 0.52, 0.42)), 0.2)
        for sx in (-1, 1):
            d = smin(d, round_cone(p, (sx * 0.28, -0.02, 0.4), (sx * 0.3, -0.12, 0.1), 0.22, 0.17), 0.08)
        return smax(d, 0.04 - p[2], 0.02)

    def feet(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, (sx * 0.31, -0.24, 0.07), (0.17, 0.25, 0.1))
            for t in (-1, 0, 1):
                e = smin(e, sphere(p, (sx * 0.31 + t * 0.08, -0.46, 0.06), 0.055), 0.03)
            d = e if d is None else np.minimum(d, e)
        return smax(d, -p[2], 0.01)

    belly = decal(torso, [(*front(torso, 0, 0.72), blob(0.32, 0.4))], 0.008, k=0.02)

    # arms: right arm bent to the chest holding the coin cord, left arm out holding the lantern pole
    arm_r = [(-0.5, -0.02, 1.26), (-0.62, -0.25, 1.02), (-0.32, -0.52, 0.98)]
    arm_l = [(0.5, -0.02, 1.26), (0.7, -0.22, 1.08), (0.82, -0.4, 1.02)]

    def sleeves(p):
        return np.minimum(tube(p, arm_r, [0.17, 0.155, 0.14], k=0.04), tube(p, arm_l, [0.17, 0.155, 0.14], k=0.04))

    def cuffs(p):
        d = None
        for a, b in ((arm_r[1], arm_r[2]), (arm_l[1], arm_l[2])):
            a, b = V(a), V(b)
            c = a + (b - a) * 0.78
            e = torus(p, c, 0.135, 0.032, frame(b - a))
            d = e if d is None else np.minimum(d, e)
        return d

    def hands(p):
        return np.minimum(ellipsoid(p, (-0.26, -0.58, 0.97), (0.13, 0.12, 0.12)),
                          ellipsoid(p, (0.88, -0.45, 1.02), (0.12, 0.12, 0.13)))

    # jacket trims: neckline and hem bands
    def trims(p):
        hem = torus(p, (0, 0.03, 0.58), 0.6, 0.03)
        hem = smax(hem, -p[1] - 0.6, 0.01)
        return hem

    def scarf(p):
        d = torus(p, (0, 0.0, 1.38), 0.4, 0.13)
        d = smin(d, ellipsoid(p, (0, 0.34, 1.32), (0.48, 0.22, 0.3)), 0.1)  # hood folded behind
        d = smin(d, ellipsoid(p, (0.08, -0.4, 1.3), (0.14, 0.1, 0.12)), 0.05)  # knot
        return d

    # crown band over the head, flowers at the ear roots
    band_pts = []
    for a in np.linspace(-62, 62, 9):
        q, n = anchor(head, hc, (math.sin(math.radians(a)), -0.42, math.cos(math.radians(a)) * 0.9 + 0.1), 0.012)
        band_pts.append(q)
    crown_c = V(0.0, -0.28, 2.62)

    def crown(p):
        d = ellipsoid(p, crown_c, (0.2, 0.14, 0.12), rot(-30, 0, 0))
        d = smin(d, ellipsoid(p, crown_c + V(0, -0.02, 0.1), (0.1, 0.08, 0.08)), 0.03)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, crown_c + V(sx * 0.18, 0.02, -0.03), (0.09, 0.07, 0.06)), 0.03)
        d = np.minimum(d, flower(p, V(-0.66, -0.18, 2.38), V(-0.55, -0.8, 0.2), 0.11))
        return d

    def flowers(p):
        return np.minimum(flower(p, V(0.66, -0.2, 2.36), V(0.55, -0.8, 0.2), 0.13, spin=12),
                          flower(p, V(-0.6, -0.3, 2.22), V(-0.45, -0.85, 0.2), 0.1, spin=30))

    def pearl(p):
        return sphere(p, crown_c + V(-0.22, 0.12, 0.08), 0.06)

    loop_c = crown_c + V(0.16, 0.18, 0.2)

    def loop(p):
        return torus(p, loop_c, 0.08, 0.028, rot(70, 0, 20))

    # coins and tassels on the chest cord, satchel with strap, lantern on a pole
    coin_a = V(0.05, -0.62, 0.92)
    coin_b = V(-0.24, -0.58, 0.74)

    def coins(p):
        d = coin(p, coin_a, V(0, -1, 0.15), 0.13, 0.05, hole=0.028)
        d = np.minimum(d, coin(p, coin_b, V(-0.2, -1, 0.1), 0.085, 0.04, hole=0.02))
        d = np.minimum(d, sphere(p, (0.04, -0.6, 1.14), 0.06))  # knot bead
        d = np.minimum(d, coin(p, V(-0.82, -0.12, 0.42), V(-1, -0.3, 0), 0.08, 0.035, hole=0.018))  # satchel charm
        return d

    def tassels(p):
        d = tassel(p, coin_a + V(0, 0, -0.13), 0.2, 0.05)
        d = np.minimum(d, tassel(p, coin_b + V(0, 0, -0.08), 0.15, 0.04))
        d = np.minimum(d, tassel(p, lan_c - V(0, 0, 0.3), 0.16, 0.05))  # lantern tassel
        return d

    bag_c = V(-0.74, -0.04, 0.72)
    bag_R = rot(0, 0, -18)

    def satchel(p):
        d = round_box(p, bag_c, (0.17, 0.25, 0.2), 0.08, bag_R)
        flap = round_box(p, bag_c + bag_R @ V(-0.06, 0, 0.1), (0.13, 0.26, 0.14), 0.06, bag_R @ rot(0, 10, 0))
        return smin(d, flap, 0.02)

    def bag_flower(p):
        return flower(p, bag_c + bag_R @ V(-0.2, -0.0, 0.06), bag_R @ V(-1, 0, 0), 0.075)

    strap = [(0.42, -0.36, 1.32), (0.1, -0.5, 1.15), (-0.35, -0.48, 0.92), (-0.62, -0.28, 0.85)]
    pole = [(0.86, -0.4, 0.96), (0.92, -0.42, 1.22), (1.02, -0.42, 1.36), (1.12, -0.42, 1.3), (1.14, -0.42, 1.18)]
    lan_c = V(1.14, -0.42, 0.68)

    def lantern(p):
        x, y, z = local(p, lan_c)
        r = np.sqrt(x * x + y * y)
        theta = np.arctan2(y, x)
        d = ellipsoid(p, lan_c, (0.25, 0.25, 0.26))
        return d + 0.008 * np.abs(np.sin(theta * 4)) ** 4 * (r > 0)

    def lantern_ribs(p):
        x, y, z = local(p, lan_c)
        theta = np.arctan2(y, x)
        ring = np.abs(np.sin(theta * 4)) - 0.12  # eight vertical ribs
        base = ellipsoid(p, lan_c, (0.25, 0.25, 0.26))
        rib = overlay(base, ring * 0.25, 0.012, 0.03, 0.004)
        caps = np.minimum(cylinder(p, lan_c + V(0, 0, 0.26), 0.12, 0.035, r=0.015),
                          cylinder(p, lan_c - V(0, 0, 0.26), 0.13, 0.035, r=0.015))
        return np.minimum(rib, caps)

    cord_l = [(1.14, -0.42, 1.18), (1.14, -0.42, 0.95)]

    def tail_mesh():
        pts = [(-0.3, 0.42, 0.42), (-0.7, 0.55, 0.32), (-1.08, 0.38, 0.5), (-1.22, 0.18, 0.88), (-1.1, 0.1, 1.2),
               (-0.86, 0.12, 1.26), (-0.76, 0.2, 1.06), (-0.88, 0.26, 0.96)]
        return tail(pts, 0.085, 0.032, power=0.8, samples=10)

    hm = ("MoonRat_Fur", m_vinyl(grey))
    comps = [
        C(f"{N}_Head", flat(head, 0.3), hm, voxel=0.008, tris=12000, err=0.02),
        C(f"{N}_Face", decal(head, [(face_c, face_n, face_mask)], 0.008, k=0.02, slab=0.6),
          (f"{N}_Cream", m_vinyl(cream)), voxel=0.005, tris=6000),
        C(f"{N}_Ears", ears, (f"{N}_EarOuter", m_vinyl(ear_c)), voxel=0.007, tris=6000, islands=2, err=0.015),
        C(f"{N}_EarInner", ear_in, (f"{N}_EarPink", m_vinyl(pink)), voxel=0.006, tris=3000, islands=2),
        *eyes(N, head, [(-0.3, 2.0), (0.3, 2.0)], 0.18, 0.21, tilt=6, brows=(0.3, 0.07, 0.025, -12)),
        blush(N, head, [(-0.48, 1.8), (0.48, 1.8)], 0.13, 0.08),
        C(f"{N}_Nose", lambda p: ellipsoid(p, front(head, 0, 1.86)[0] + V(0, 0.01, 0), (0.07, 0.05, 0.05)),
          (f"{N}_NosePink", m_gloss("#F08C8C")), voxel=0.004, tris=800),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.73), mouth_w(0.045, 0.011, 0.07))], 0.008),
          (f"{N}_MouthInk", m_matte("#6B3A33")), voxel=0.003, tris=1200),
        C(f"{N}_Torso", torso, (f"{N}_Jacket", m_fabric(jacket)), voxel=0.008, tris=10000, err=0.02),
        C(f"{N}_Belly", belly, (f"{N}_BellyCream", m_vinyl(cream)), voxel=0.005, tris=3000),
        C(f"{N}_Sleeves", sleeves, (f"{N}_Jacket", m_fabric(jacket)), voxel=0.007, tris=5000, islands=2),
        C(f"{N}_Hands", hands, (f"{N}_Paws", m_vinyl("#F4C4BA")), voxel=0.006, tris=2400, islands=2),
        C(f"{N}_Feet", feet, (f"{N}_Paws", m_vinyl("#F4C4BA")), voxel=0.006, tris=3000, islands=2),
        C(f"{N}_Scarf", scarf, (f"{N}_Red", m_fabric(RED)), voxel=0.007, tris=6000, err=0.016),
        C(f"{N}_Gold", lambda p: np.minimum(np.minimum(cuffs(p), trims(p)), np.minimum(crown(p), coins(p))),
          (f"{N}_GoldMat", m_gold()), voxel=0.0055, tris=14000, islands=None),
        S(f"{N}_Band", [tail(band_pts, 0.04, 0.04, flat_ratio=0.6)], (f"{N}_GoldMat", m_gold())),
        C(f"{N}_Flowers", lambda p: np.minimum(flowers(p), bag_flower(p)), (f"{N}_Petal", m_vinyl("#FBE3C8")),
          voxel=0.004, tris=4000, islands=3),
        C(f"{N}_Pearl", pearl, (f"{N}_PearlMat", preset("pearlescent", "#F4EEE6")), voxel=0.004, tris=600),
        C(f"{N}_Tassels", lambda p: np.minimum(tassels(p), loop(p)), (f"{N}_Red", m_fabric(RED)),
          voxel=0.005, tris=6000, islands=4),
        C(f"{N}_Satchel", satchel, (f"{N}_BagRed", m_vinyl("#D23A32")), voxel=0.006, tris=4000),
        S(f"{N}_Strap", [rope(strap, 0.04)], (f"{N}_Red", m_fabric(RED))),
        S(f"{N}_Pole", [tail(pole, 0.035, 0.03)], (f"{N}_Wood", m_vinyl("#5A3424"))),
        S(f"{N}_Cord", [rope(cord_l, 0.016)], (f"{N}_Red", m_fabric(RED))),
        C(f"{N}_Lantern", lantern, (f"{N}_Glow", m_gloss(["#FFE6A6", "#FFB648", "#F27A2E"])), voxel=0.006, tris=4000,
          ramp=lambda x, y, z: np.clip(np.sqrt((x - lan_c[0]) ** 2 + (z - lan_c[2]) ** 2 * 1.2) / 0.27, 0, 1)),
        C(f"{N}_LanternRibs", lantern_ribs, (f"{N}_Red", m_fabric(RED)), voxel=0.004, tris=6000, islands=None),
        S(f"{N}_Tail", [tail_mesh()], (f"{N}_TailPink", m_vinyl("#EDA9A3"))),
    ]
    return assemble(N, "Rat", "Common", comps, "moon.rat")


def ox():
    N = "MoonOx"
    brown, cream, teal, leather = "#5C3B2E", "#F6E8D8", "#3F8C78", "#7A4A2E"
    hc = V(0, -0.8, 2.08)

    def head(p):
        d = ellipsoid(p, hc, (0.7, 0.6, 0.58))
        d = smin(d, ellipsoid(p, (0, -1.12, 1.84), (0.56, 0.36, 0.38)), 0.22)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.44, -0.92, 1.86), (0.32, 0.3, 0.3)), 0.16)
        return d

    face = decal(head, [(*front(head, 0, 1.86, -0.8), lambda u, v: np.maximum(
        ellipse2(u, v + 0.06, 0.72, 0.38), -ellipse2(u, v - 0.5, 0.18, 0.3)))], 0.008, k=0.02, slab=0.6)

    ear_R = {sx: rot(0, sx * 12, sx * -8) for sx in (-1, 1)}

    def ears(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, V(sx * 0.9, -0.66, 2.0), (0.36, 0.11, 0.17), ear_R[sx])
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, V(sx * 0.92, -0.73, 1.99), (0.29, 0.05, 0.12), ear_R[sx])
            d = e if d is None else np.minimum(d, e)
        return d

    horns = [tail([(sx * 0.42, -0.72, 2.44), (sx * 0.72, -0.74, 2.56), (sx * 1.02, -0.74, 2.72),
                   (sx * 1.17, -0.72, 2.98), (sx * 1.1, -0.7, 3.22)], 0.17, 0.045, power=1.2, samples=10)
             for sx in (-1, 1)]

    def horn_t(x, y, z):
        return np.clip((np.abs(x) - 0.45) / 0.85, 0, 1) * 0.6 + np.clip((z - 2.7) / 0.6, 0, 1) * 0.4

    legs = [(sx * 0.56, ly) for sx in (-1, 1) for ly in (-0.48, 0.72)]

    def body(p):
        d = ellipsoid(p, (0, 0.18, 1.0), (0.84, 1.05, 0.66))
        d = smin(d, ellipsoid(p, (0, -0.42, 1.12), (0.76, 0.55, 0.64)), 0.25)
        for x, y in legs:
            d = smin(d, round_cone(p, (x * 0.96, y, 0.9), (x, y, 0.3), 0.27, 0.25), 0.12)
        d = smin(d, round_cone(p, (0, -0.55, 1.45), (0, -0.72, 1.75), 0.45, 0.4), 0.15)  # neck
        return smax(d, 0.22 - p[2], 0.03)

    def hooves(p):
        d = None
        for x, y in legs:
            e = cylinder(p, (x, y, 0.13), 0.27, 0.13, r=0.06)
            e = smax(e, -round_box(p, (x, y - 0.27, 0.1), (0.018, 0.08, 0.2), 0.01), 0.01)  # cloven split
            d = e if d is None else np.minimum(d, e)
        return d

    centre = (0, 0.2, 1.0)
    patches = decal(body, [
        (*anchor(body, centre, (1, 0.3, 0.2)), blob(0.3, 0.22, tilt=20)),
        (*anchor(body, centre, (-1, 0.5, -0.1)), blob(0.28, 0.2, tilt=-30)),
        (*anchor(body, centre, (0.9, 1.0, -0.3)), blob(0.22, 0.17)),
        (*anchor(body, centre, (-0.7, -0.3, -0.7)), blob(0.18, 0.14)),
        (*anchor(body, centre, (0.2, 1.0, 0.0)), blob(0.2, 0.16)),
        (*anchor(body, (0.54, -0.48, 0.55), (1, -0.3, 0)), blob(0.14, 0.12)),
        (*anchor(body, (-0.54, 0.72, 0.55), (-1, 0.3, 0)), blob(0.16, 0.13)),
    ], 0.007, k=0.015, slab=0.2)

    bib = decal(body, [(*front(body, 0, 1.05, -0.4), lambda u, v: np.maximum(ellipse2(u, v + 0.1, 0.42, 0.5),
                                                                          v - 0.32))], 0.03, k=0.03, slab=0.4)

    collar_R = rot(-28, 0, 0)

    def collar(p):
        return torus(p, (0, -0.68, 1.56), 0.48, 0.07, collar_R)

    def gold(p):
        d = bell(p, V(0, -1.12, 1.2), 0.22)
        for i in range(9):
            a = math.radians(-80 + 20 * i)
            q = V(0, -0.68, 1.56) + collar_R @ V(0.48 * math.sin(a), -0.48 * math.cos(a), 0)
            d = np.minimum(d, sphere(p, q + V(0, -0.05, 0.02), 0.045))
        crown_c = V(0, -1.0, 2.5)
        cr = ellipsoid(p, crown_c, (0.24, 0.1, 0.15), rot(-35, 0, 0))
        cr = smin(cr, flower(p, crown_c + V(0, 0.06, 0.16), V(0, -0.5, 1), 0.13, petals=6), 0.02)
        for sx in (-1, 1):
            cr = smin(cr, ellipsoid(p, crown_c + V(sx * 0.2, 0.05, 0.05), (0.09, 0.06, 0.08)), 0.03)
            d = np.minimum(d, torus(p, V(sx * 0.6, -0.74, 2.53), 0.14, 0.045, frame(V(sx * 1, 0, 0.35))))
        d = np.minimum(d, cr)
        for x, y in legs:
            c, n = anchor(hooves, (x, y, 0.13), (0, -1, 0))
            d = np.minimum(d, flower(p, c, n, 0.07, petals=3, spin=90, petal_w=0.8))
        d = np.minimum(d, coin(p, V(0, 1.2, 1.5), V(0, 1, 0.1), 0.11, 0.05))
        return d

    def cloth_region(p):
        return np.maximum(0.66 - p[2], np.abs(p[1] - 0.12) - 0.86)

    def cloth(p):
        return np.maximum(np.abs(body(p) - 0.06) - 0.035, cloth_region(p))

    def cloth_trim(p):
        r = cloth_region(p)
        return np.maximum(np.abs(body(p) - 0.06) - 0.05, np.maximum(r, -r - 0.07))

    def bundles(p):
        d = None
        for sx in (-1, 1):
            c = V(sx * 0.9, -0.38, 1.42)
            e = ellipsoid(p, c, (0.18, 0.2, 0.17))
            for sy in (-1, 1):
                e = smin(e, ellipsoid(p, c + V(sx * 0.05, sy * 0.2, 0.06), (0.12, 0.16, 0.11), rot(sy * 30, 0, 0)), 0.04)
            d = e if d is None else np.minimum(d, e)
        bow = ellipsoid(p, (0, 1.12, 1.58), (0.14, 0.1, 0.12))
        for sx in (-1, 1):
            bow = smin(bow, ellipsoid(p, (sx * 0.24, 1.1, 1.62), (0.2, 0.08, 0.13), rot(0, sx * -15, 0)), 0.04)
        return np.minimum(d, bow)

    def tassels(p):
        return np.minimum(tassel(p, V(-0.98, -0.42, 1.25), 0.32, 0.06), tassel(p, V(0.98, -0.42, 1.25), 0.32, 0.06))

    tail_pts = [(0, 1.18, 1.25), (0, 1.32, 1.0), (0.02, 1.32, 0.72), (0.04, 1.26, 0.55)]

    def tuft(p):
        return spikes(p, [V(0.04, 1.26, 0.6)] * 4, [V(0.0, 1.3, 0.32), V(0.14, 1.28, 0.36), V(-0.1, 1.28, 0.38),
                                                    V(0.06, 1.38, 0.36)], 0.09, 0.03, 0.06)

    brown_m = (f"{N}_Brown", m_vinyl(brown))
    gold_m = (f"{N}_GoldMat", m_gold())
    comps = [
        C(f"{N}_Head", head, brown_m, voxel=0.008, tris=12000, err=0.02),
        C(f"{N}_Muzzle", face, (f"{N}_MuzzleCream", m_vinyl("#F7E2D6")), voxel=0.005, tris=6000),
        C(f"{N}_Ears", ears, brown_m, voxel=0.006, tris=3000, islands=2),
        C(f"{N}_EarInner", ear_in, (f"{N}_EarPink", m_vinyl("#E8A08C")), voxel=0.005, tris=2000, islands=2),
        S(f"{N}_Horns", horns, (f"{N}_Horn", m_vinyl(["#F8EEDF", "#EEDCC3", "#D9BE9A"])), ramp=horn_t),
        *eyes(N, head, [(-0.33, 2.15), (0.33, 2.15)], 0.135, 0.155, tilt=2, lid=0.74, y0=-0.8,
              brows=(0.28, 0.06, 0.016, 12), brow_color="#3A2318"),
        blush(N, head, [(-0.5, 1.92), (0.5, 1.92)], 0.14, 0.09, y0=-0.8),
        C(f"{N}_Nose", decal(head, [(*front(head, 0, 1.9, -0.8), blob(0.22, 0.11))], 0.02, k=0.01),
          (f"{N}_NosePink", m_gloss("#F2A8A0")), voxel=0.004, tris=1600),
        C(f"{N}_Nostrils", decal(head, [(*front(head, sx * 0.1, 1.91, -0.8), blob(0.04, 0.03, tilt=sx * 20))
                                        for sx in (-1, 1)], 0.028, k=0.004),
          (f"{N}_NostrilMat", m_matte("#B8605A")), voxel=0.003, tris=800, islands=2),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.66, -0.8), mouth_smile(0.2, 42.0, 0.012))], 0.008),
          (f"{N}_MouthInk", m_matte("#5E3328")), voxel=0.003, tris=1200),
        C(f"{N}_Body", body, (f"{N}_Hide", m_vinyl(cream)), voxel=0.009, tris=14000, err=0.022),
        C(f"{N}_Patches", patches, brown_m, voxel=0.006, tris=6000, islands=None),
        C(f"{N}_Bib", bib, (f"{N}_Leather", m_vinyl(leather)), voxel=0.006, tris=4000),
        C(f"{N}_Hooves", hooves, (f"{N}_Hoof", m_vinyl("#4A2E22")), voxel=0.006, tris=6000, islands=4),
        C(f"{N}_Collar", collar, (f"{N}_Red", m_fabric(RED)), voxel=0.006, tris=3000),
        C(f"{N}_Gold", gold, gold_m, voxel=0.006, tris=16000, islands=None),
        C(f"{N}_Cloth", cloth, (f"{N}_Sage", m_fabric(teal)), voxel=0.007, tris=10000, err=0.02),
        C(f"{N}_ClothTrim", cloth_trim, gold_m, voxel=0.006, tris=6000),
        C(f"{N}_Bundles", bundles, (f"{N}_Sage", m_fabric(teal)), voxel=0.006, tris=4000, islands=3),
        C(f"{N}_Tassels", tassels, (f"{N}_Orange", m_fabric("#E8783A")), voxel=0.005, tris=3000, islands=2),
        S(f"{N}_Tail", [tail(tail_pts, 0.05, 0.035)], brown_m),
        C(f"{N}_Tuft", tuft, brown_m, voxel=0.005, tris=2000),
    ]
    return assemble(N, "Ox", "Common", comps, "moon.ox")


def tiger():
    N = "MoonTiger"
    orange, white, black, pink = "#EE8B2F", "#FCF1E6", "#2A211E", "#F2A49A"
    hc = V(0, -0.55, 2.18)

    def head(p):
        d = ellipsoid(p, hc, (0.86, 0.72, 0.7))
        d = smin(d, ellipsoid(p, (0, -1.1, 1.94), (0.34, 0.22, 0.22)), 0.16)
        d = smin(d, ellipsoid(p, (0, -1.0, 1.74), (0.22, 0.15, 0.13)), 0.1)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.48, -0.78, 1.92), (0.36, 0.34, 0.3)), 0.15)
        return d

    def cheek_fluff(p):
        roots, tips = [], []
        for sx in (-1, 1):
            for dz, out, drop in ((0.2, 1.08, 0.04), (0.04, 1.16, -0.06), (-0.12, 1.12, -0.16), (-0.28, 1.0, -0.26),
                                  (-0.4, 0.78, -0.3)):
                roots.append(V(sx * 0.6, -0.72, 1.95 + dz))
                tips.append(V(sx * out, -0.62, 1.93 + dz + drop))
        d = spikes(p, roots, tips, 0.21, 0.06, 0.1)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.66, -0.74, 1.88), (0.28, 0.25, 0.32)), 0.1)
        return d

    def ruff(p):
        d = ellipsoid(p, (0, -0.62, 1.48), (0.62, 0.5, 0.26))
        for i in range(14):
            a = math.radians(-150 + 300 * i / 13)
            root = V(0.5 * math.sin(a), -0.62 - 0.42 * math.cos(a), 1.5)
            tip = V(0.82 * math.sin(a), -0.62 - 0.72 * math.cos(a), 1.28 - 0.08 * abs(math.cos(a)))
            d = smin(d, round_cone(p, root, tip, 0.14, 0.05), 0.07)
        return d

    mask = decal(head, [(*front(head, 0, 1.9, -0.55), lambda u, v: np.minimum(
        ellipse2(u, v + 0.16, 0.56, 0.32), np.minimum(ellipse2(u - 0.3, v - 0.42, 0.14, 0.08),
                                                     ellipse2(u + 0.3, v - 0.42, 0.14, 0.08))))],
        0.008, k=0.015, slab=0.6)

    def stripe_shapes(u, v):
        d = seg2(u, v, (0, 0.62), (0, 0.42), 0.03)
        for sx in (-1, 1):
            d = np.minimum(d, seg2(u, v, (sx * 0.12, 0.66), (sx * 0.1, 0.5), 0.025))
            d = np.minimum(d, seg2(u, v, (sx * 0.24, 0.74), (sx * 0.4, 0.66), 0.03))
            for k, vv in enumerate((0.12, -0.02, -0.16)):
                d = np.minimum(d, seg2(u, v, (sx * 0.86, vv + 0.04), (sx * (0.6 + 0.04 * k), vv - 0.02), 0.03))
        return d

    head_stripes = decal(head, [(*front(head, 0, 1.92, -0.55), stripe_shapes)], 0.012, k=0.006, slab=0.8)

    ear_c = {sx: V(sx * 0.56, -0.38, 2.74) for sx in (-1, 1)}
    ear_R = {sx: rot(-10, sx * 20, sx * -10) for sx in (-1, 1)}

    def ears(p):
        d = None
        for sx in (-1, 1):
            e = smin(ellipsoid(p, ear_c[sx], (0.24, 0.12, 0.22), ear_R[sx]),
                     round_cone(p, ear_c[sx], ear_c[sx] + V(sx * 0.06, 0.02, 0.2), 0.14, 0.04), 0.08)
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, ear_c[sx] + V(0, -0.08, -0.01), (0.15, 0.05, 0.15), ear_R[sx])
            d = e if d is None else np.minimum(d, e)
        return d

    paws = [(sx * 0.38, -0.66) for sx in (-1, 1)] + [(sx * 0.46, 0.72) for sx in (-1, 1)]

    def body(p):
        d = ellipsoid(p, (0, 0.25, 0.88), (0.6, 0.92, 0.52))
        d = smin(d, ellipsoid(p, (0, -0.42, 1.1), (0.64, 0.55, 0.62)), 0.25)
        for sx in (-1, 1):
            d = smin(d, round_cone(p, (sx * 0.38, -0.5, 0.85), (sx * 0.38, -0.62, 0.2), 0.24, 0.22), 0.1)
            d = smin(d, ellipsoid(p, (sx * 0.44, 0.62, 0.6), (0.3, 0.42, 0.44)), 0.12)
            d = smin(d, round_cone(p, (sx * 0.46, 0.68, 0.5), (sx * 0.46, 0.7, 0.2), 0.22, 0.21), 0.08)
        return smax(d, 0.18 - p[2], 0.03)

    def paw_fn(p):
        d = None
        for x, y in paws:
            e = ellipsoid(p, (x, y - 0.06, 0.13), (0.25, 0.3, 0.16))
            d = e if d is None else np.minimum(d, e)
        return smax(d, -p[2], 0.01)

    toe_items = []
    for x, y in paws:
        c, n = anchor(paw_fn, (x, y - 0.06, 0.13), (0, -1, 0.25))
        toe_items.append((c, n, lambda u, v: np.minimum(seg2(u, v, (-0.07, 0.05), (-0.07, -0.06), 0.014),
                                                        seg2(u, v, (0.07, 0.05), (0.07, -0.06), 0.014))))
    toes = decal(paw_fn, toe_items, 0.01, k=0.004, slab=0.15)

    belly = decal(body, [(*front(body, 0, 0.95, -0.4), blob(0.36, 0.45))], 0.008, k=0.02, slab=0.4)

    def body_stripes(p, side):
        x, y, z = p[0], p[1], p[2]
        theta = np.arctan2(x, z - 0.6)
        d = None
        for i, y0 in enumerate((-0.15, 0.12, 0.38, 0.62, 0.88, 1.08)):
            w = 0.02 + 0.03 * np.clip(1.0 - np.abs(theta) / 1.5, 0, 1)
            e = smax(np.abs(y - y0 - 0.07 * np.sin(2.2 * theta + i)) - w, 0.08 - np.abs(theta), 0.01)
            e = smax(e, np.abs(theta) - (1.25 + 0.15 * math.sin(i * 1.7)), 0.03)
            d = e if d is None else smin(d, e, 0.005)
        for sx in (-1, 1):  # bands on the front legs, outer faces only
            for z0 in (0.4, 0.62):
                e = smax(np.abs(z - z0 - 0.03 * sx * y) - 0.028, -(x * sx - 0.3), 0.01)
                d = smin(d, smax(e, np.abs(y + 0.55) - 0.3, 0.02), 0.005)
        return overlay(body(p), smax(d, -side * p[0], 0.01), 0.01, 0.022, 0.006)

    cape = Mantle((0, 0.32, 0.86), (0.8, 1.02, 0.58), flare=0.6, th=0.045, waves=8, wave=0.06, y_top=-0.3,
                  y_bot=-0.02, folds=6, fold=0.045, hem_front=0.42)
    swirl_items = [(*anchor(cape.surface, V(0, 0.32, 0.8), d, 0.03), (lambda r: lambda u, v: spiral2(u, v, r, 1.7, 0.014))(r))
                   for d, r in (((1, 0.2, -0.25), 0.05), ((-1, 0.2, -0.25), 0.05), ((1, 0.9, -0.5), 0.045),
                                ((-1, 0.9, -0.5), 0.045), ((0.3, 1, 0.2), 0.04), ((-0.3, 1, 0.2), 0.04))]
    embroidery = decal(cape, swirl_items, 0.008, k=0.002, slab=0.08)

    def pauldrons(p):
        d = None
        for sx in (-1, 1):
            c, R = V(sx * 0.64, -0.32, 1.38), rot(0, sx * 32, 0)
            e = smax(ellipsoid(p, c, (0.3, 0.34, 0.2), R), -ellipsoid(p, c + V(-sx * 0.06, 0, -0.08), (0.26, 0.3, 0.16), R),
                     0.02)
            e = smin(e, torus(p, c + V(sx * 0.1, -0.1, 0.06), 0.09, 0.028, frame(V(sx, -0.4, 0.6))), 0.01)
            d = e if d is None else np.minimum(d, e)
        return d

    def scarf(p):
        d = torus(p, (0, -0.6, 1.4), 0.52, 0.09, rot(-18, 0, 0))
        d = smin(d, ellipsoid(p, (0, -1.08, 1.36), (0.2, 0.11, 0.14)), 0.05)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.24, -1.04, 1.34), (0.2, 0.08, 0.13), rot(0, sx * -20, 0)), 0.04)
        return d

    med_c = V(0, -1.2, 1.32)

    def medallion(p):
        heart = smin(sphere(p, med_c + V(-0.08, 0, 0.06), 0.13), sphere(p, med_c + V(0.08, 0, 0.06), 0.13), 0.06)
        heart = smin(heart, sphere(p, med_c + V(0, 0, -0.08), 0.09), 0.1)
        heart = smax(heart, np.abs(p[1] - med_c[1]) - 0.05, 0.02)
        R = rot(0, 45, 0)
        knot = round_box(p, med_c + V(0, 0.0, -0.32), (0.09, 0.03, 0.09), 0.03, R)
        knot = smax(knot, -round_box(p, med_c + V(0, 0, -0.32), (0.035, 0.06, 0.035), 0.01, R), 0.01)
        cord = round_cone(p, med_c + V(0, 0, -0.08), med_c + V(0, 0, -0.22), 0.025, 0.025)
        return np.minimum(np.minimum(heart, knot), cord)

    tail_pts = [(0.08, 1.08, 0.92), (0.22, 1.36, 1.2), (0.34, 1.44, 1.66), (0.3, 1.3, 2.1), (0.12, 1.08, 2.3),
                (-0.04, 0.95, 2.16)]

    white_m, black_m, gold_m = (f"{N}_White", m_vinyl(white)), (f"{N}_Black", m_vinyl(black)), (f"{N}_GoldMat", m_gold())
    orange_m, red_m = (f"{N}_Orange", m_vinyl(orange)), (f"{N}_CapeRed", m_fabric(RED))
    comps = [
        C(f"{N}_Head", head, orange_m, voxel=0.008, tris=12000, err=0.02),
        C(f"{N}_Mask", mask, white_m, voxel=0.005, tris=6000, islands=None),
        C(f"{N}_HeadStripes", head_stripes, black_m, voxel=0.004, tris=6000, islands=None),
        C(f"{N}_CheekFluff", cheek_fluff, white_m, voxel=0.006, tris=6000, islands=2),
        C(f"{N}_Ruff", ruff, white_m, voxel=0.007, tris=8000, err=0.018),
        C(f"{N}_Ears", ears, black_m, voxel=0.006, tris=3000, islands=2),
        C(f"{N}_EarInner", ear_in, (f"{N}_EarPink", m_vinyl(pink)), voxel=0.005, tris=2000, islands=2),
        *eyes(N, head, [(-0.32, 2.2), (0.32, 2.2)], 0.17, 0.17, tilt=6, y0=-0.55, lid=0.9,
              iris=["#FFE08A", "#F2B23A", "#B8691E", "#5A2C10"]),
        C(f"{N}_Nose", lambda p: ellipsoid(p, front(head, 0, 2.0, -0.55)[0] + V(0, 0.025, -0.01), (0.14, 0.07, 0.08)),
          (f"{N}_NoseMat", m_gloss("#D9584C")), voxel=0.004, tris=1000),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.84, -0.55), mouth_open(0.11, 0.08))], 0.01),
          (f"{N}_MouthMat", m_matte("#8E2E2A")), voxel=0.003, tris=1200),
        C(f"{N}_Tongue", decal(head, [(*front(head, 0, 1.84, -0.55), mouth_open(0.11, 0.08, tongue=True))], 0.014),
          (f"{N}_TongueMat", m_gloss("#F07F7A")), voxel=0.003, tris=800),
        C(f"{N}_Body", body, orange_m, voxel=0.009, tris=14000, err=0.022),
        C(f"{N}_StripesLeft", lambda p: body_stripes(p, 1), black_m, voxel=0.005, tris=18000, islands=None, err=0.016),
        C(f"{N}_StripesRight", lambda p: body_stripes(p, -1), black_m, voxel=0.005, tris=18000, islands=None, err=0.016),
        C(f"{N}_Belly", belly, white_m, voxel=0.006, tris=3000),
        C(f"{N}_Paws", paw_fn, white_m, voxel=0.006, tris=5000, islands=4),
        C(f"{N}_Toes", toes, black_m, voxel=0.003, tris=2400, islands=8),
        C(f"{N}_Cape", cape, red_m, voxel=0.007, tris=14000, err=0.02, islands=None),
        C(f"{N}_CapeTrim", cape.trim(0.08), gold_m, voxel=0.006, tris=10000, islands=None),
        C(f"{N}_Embroidery", embroidery, gold_m, voxel=0.004, tris=5000, islands=None),
        C(f"{N}_HeadTuft", lambda p: spikes(p, [V(0, -0.45, 2.7)] * 3, [V(-0.12, -0.5, 2.95), V(0.02, -0.4, 3.0),
                                                                     V(0.14, -0.5, 2.92)], 0.07, 0.015, 0.03),
          black_m, voxel=0.005, tris=1600),
        C(f"{N}_Pauldrons", pauldrons, gold_m, voxel=0.005, tris=6000, islands=2),
        C(f"{N}_Scarf", scarf, (f"{N}_ScarfRed", m_fabric(RED_DEEP)), voxel=0.006, tris=5000),
        C(f"{N}_Medallion", medallion, gold_m, voxel=0.004, tris=5000, islands=None),
        C(f"{N}_Tassel", lambda p: tassel(p, med_c + V(0, 0, -0.44), 0.26, 0.055), red_m, voxel=0.004, tris=2400),
        C(f"{N}_EarOrnament", lambda p: flower(p, V(-0.48, -0.62, 2.62), V(-0.4, -0.8, 0.5), 0.12, petals=4, spin=45),
          gold_m, voxel=0.004, tris=1600),
        S(f"{N}_Tail", [tail(tail_pts, 0.15, 0.12, samples=12, sides=20)],
          (f"{N}_TailBands", m_vinyl(bands([orange, orange, black, orange, orange, black, orange, orange, black,
                                            orange, black, black], 3))), ramp=path_param(tail_pts)),
    ]
    return assemble(N, "Tiger", "Legendary", comps, "moon.tiger", tri_scale=0.6)


def rabbit():
    N = "MoonRabbit"
    white, pink, rose, ribbon = "#FBF1EA", "#F3A49E", "#F08B8E", "#F59A96"
    hc = V(0, -0.05, 1.6)

    def head(p):
        d = ellipsoid(p, hc, (0.64, 0.58, 0.56))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.36, -0.24, 1.38), (0.3, 0.28, 0.24)), 0.14)
        return d

    ear_c = {sx: V(sx * 0.4, 0.02, 2.62) for sx in (-1, 1)}
    ear_R = {sx: rot(-6, sx * 16, sx * 10) for sx in (-1, 1)}

    def ears(p):
        d = None
        for sx in (-1, 1):
            R = ear_R[sx]
            e = ellipsoid(p, ear_c[sx], (0.21, 0.1, 0.66), R)
            e = smax(e, -ellipsoid(p, ear_c[sx] + R @ V(0, -0.11, -0.02), (0.15, 0.08, 0.56), R), 0.02)
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            R = ear_R[sx]
            e = ellipsoid(p, ear_c[sx] + R @ V(0, -0.025, -0.02), (0.15, 0.03, 0.55), R)
            d = e if d is None else np.minimum(d, e)
        return d

    def body(p):
        d = ellipsoid(p, (0, 0.05, 0.64), (0.58, 0.52, 0.6))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.44, 0.12, 0.34), (0.32, 0.46, 0.32)), 0.15)
        d = smin(d, ellipsoid(p, (0, 0.0, 1.12), (0.36, 0.34, 0.2)), 0.15)
        return smax(d, 0.03 - p[2], 0.02)

    arm = {sx: [(sx * 0.45, -0.08, 1.0), (sx * 0.48, -0.36, 0.82), (sx * 0.3, -0.62, 0.74)] for sx in (-1, 1)}

    def arms(p):
        d = None
        for sx in (-1, 1):
            e = tube(p, arm[sx], [0.15, 0.14, 0.13], k=0.04)
            e = smin(e, ellipsoid(p, (sx * 0.27, -0.66, 0.74), (0.13, 0.12, 0.13)), 0.05)
            d = e if d is None else np.minimum(d, e)
        return d

    def feet(p):
        d = np.minimum(ellipsoid(p, (-0.32, -0.42, 0.08), (0.16, 0.24, 0.1)),
                       ellipsoid(p, (0.32, -0.42, 0.08), (0.16, 0.24, 0.1)))
        return smax(d, -p[2], 0.01)

    toes = decal(feet, [(*anchor(feet, (sx * 0.32 + t * 0.07, -0.42, 0.08), (0, -1, 0.3)), blob(0.03, 0.025))
                        for sx in (-1, 1) for t in (-1, 0, 1)], 0.008, k=0.004, slab=0.1)

    charm_c, charm_n = V(0, -0.82, 0.72), V(0, -1, 0.1)
    charm_R = frame(charm_n)

    def charm_disc(p):
        return cylinder(p, charm_c + V(0, 0.01, 0), 0.22, 0.025, r=0.01, R=charm_R)

    def crescent(u, v):
        return np.maximum(ellipse2(u, v, 0.15, 0.15), -ellipse2(u - 0.06, v - 0.05, 0.13, 0.13))

    moon = decal(charm_disc, [(charm_c + V(0, -0.03, 0), charm_n, crescent)], 0.008, k=0.004, slab=0.08)

    brooch_c, brooch_n = front(head, 0, 1.98, -0.05)

    def brooch(p):
        return coin(p, brooch_c, brooch_n, 0.13, 0.045)

    def gold(p):
        d = smin(torus(p, charm_c, 0.24, 0.05, charm_R), sphere(p, charm_c + V(0, 0, 0.3), 0.05), 0.02)
        d = np.minimum(d, torus(p, V(-0.6, -0.3, 0.42), 0.3, 0.055, rot(70, 0, 25)))  # hoop at the side (balanced for facing)
        d = np.minimum(d, brooch(p))
        d = np.minimum(d, sphere(p, brooch_c + V(0, -0.02, -0.19), 0.045))
        d = np.minimum(d, round_cone(p, brooch_c + V(0, 0, -0.12), brooch_c + V(0, -0.01, -0.16), 0.015, 0.015))
        top = V(0, -0.24, 2.12)
        d = np.minimum(d, smin(ellipsoid(p, top, (0.11, 0.06, 0.06)), sphere(p, top + V(0, 0, 0.07), 0.04), 0.02))
        for sx in (-1, 1):
            d = np.minimum(d, sphere(p, V(sx * 0.53, -0.36, 1.86), 0.05))  # flower centres
        c = V(0, 0.68, 1.08)  # crescent on the back bow
        moon_b = smax(cylinder(p, c, 0.08, 0.02, r=0.008, R=frame(V(0, 1, 0))),
                      -cylinder(p, c + V(0.03, 0, 0.02), 0.065, 0.05, R=frame(V(0, 1, 0))), 0.005)
        return np.minimum(d, moon_b)

    swirl = decal(brooch, [(brooch_c, brooch_n, lambda u, v: np.minimum(arc2(u, v - 0.02, 0.05, 140, 0.012),
                                                                       seg2(u, v, (0, -0.03), (0, -0.07), 0.012)))],
                  0.008, k=0.003, slab=0.05)

    def flowers(p):
        return np.minimum(flower(p, V(-0.53, -0.32, 1.86), V(-0.5, -0.8, 0.2), 0.16, spin=10, petal_w=0.7),
                          flower(p, V(0.53, -0.32, 1.86), V(0.5, -0.8, 0.2), 0.16, spin=30, petal_w=0.7))

    ribbons = []
    for sx in (-1, 1):
        for off, ln in ((0.0, 0.62), (0.08, 0.5)):
            ribbons.append(sweep([(sx * 0.6, -0.2 + off, 1.8), (sx * (0.78 + off), -0.25, 1.55),
                                  (sx * (0.8 + off), -0.22, 1.3), (sx * (0.76 + off), -0.25, 1.57 - ln)],
                                 np.array([[0.07, 0.022]] * 4), samples=8, sides=12))
        ribbons.append(sweep([(sx * 0.52, -0.18, 1.86), (sx * 0.7, -0.12, 2.0), (sx * 0.78, -0.2, 1.86),
                              (sx * 0.62, -0.26, 1.8)], np.array([[0.05, 0.02]] * 4), samples=8, sides=12))

    def collar(p):
        d = torus(p, (0, -0.02, 1.08), 0.42, 0.08, rot(-8, 0, 0))
        return smin(d, ellipsoid(p, (0, -0.42, 1.04), (0.2, 0.08, 0.1)), 0.05)

    def bow(p):
        c = V(0, 0.58, 1.06)
        d = ellipsoid(p, c, (0.12, 0.08, 0.1))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, c + V(sx * 0.2, 0.0, 0.05), (0.2, 0.07, 0.14), rot(0, sx * -20, 0)), 0.04)
            d = smin(d, round_cone(p, c + V(sx * 0.06, 0.02, -0.04), c + V(sx * 0.2, 0.05, -0.4), 0.06, 0.04), 0.02)
        return d

    body_flowers = decal(body, [(*anchor(body, (0, 0.05, 0.6), d), lambda u, v: flower(
        (u, v, np.zeros_like(u)), V(0, 0, 0), V(0, 0, 1), 0.07, petal_w=0.7)) for d in
                                ((0.9, 0.2, -0.3), (-0.9, 0.3, -0.2), (0.7, 0.6, 0.1), (-0.6, 0.7, 0.3))],
                         0.006, k=0.004, slab=0.1)

    white_m, pink_m, rose_m = (f"{N}_White", m_vinyl(white)), (f"{N}_EarPink", m_vinyl(pink)), (f"{N}_Rose", m_vinyl(rose))
    gold_m, ribbon_m = (f"{N}_GoldMat", m_gold()), (f"{N}_Ribbon", m_fabric(ribbon))
    comps = [
        C(f"{N}_Head", head, white_m, voxel=0.008, tris=12000, err=0.02),
        C(f"{N}_Ears", ears, white_m, voxel=0.006, tris=6000, islands=2, err=0.015),
        C(f"{N}_EarInner", ear_in, pink_m, voxel=0.005, tris=3000, islands=2),
        *eyes(N, head, [(-0.27, 1.62), (0.27, 1.62)], 0.16, 0.19, tilt=4, y0=-0.05,
              brows=(0.3, 0.05, 0.02, -15), brow_color="#F2A08E"),
        blush(N, head, [(-0.4, 1.43), (0.4, 1.43)], 0.11, 0.07, y0=-0.05),
        C(f"{N}_Nose", lambda p: ellipsoid(p, front(head, 0, 1.47, -0.05)[0] + V(0, 0.01, 0), (0.05, 0.035, 0.035)),
          (f"{N}_NosePink", m_gloss("#F49A9A")), voxel=0.004, tris=600),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.38, -0.05), mouth_w(0.04, 0.01, 0.06))], 0.008),
          (f"{N}_MouthInk", m_matte("#8E4A44")), voxel=0.003, tris=1000),
        C(f"{N}_Body", body, white_m, voxel=0.008, tris=10000, err=0.02),
        C(f"{N}_Arms", arms, white_m, voxel=0.006, tris=4000, islands=2),
        C(f"{N}_Feet", feet, white_m, voxel=0.006, tris=2000, islands=2),
        C(f"{N}_Toes", toes, pink_m, voxel=0.003, tris=1200, islands=None),
        C(f"{N}_BodyFlowers", body_flowers, rose_m, voxel=0.003, tris=2400, islands=None),
        C(f"{N}_Gold", gold, gold_m, voxel=0.0055, tris=12000, islands=None),
        C(f"{N}_Swirl", swirl, (f"{N}_GoldDeep", m_gold(GOLD_DEEP)), voxel=0.003, tris=800, islands=None),
        C(f"{N}_CharmDisc", charm_disc, (f"{N}_CharmRed", m_gloss("#B8303A")), voxel=0.004, tris=1600),
        C(f"{N}_Moon", moon, gold_m, voxel=0.003, tris=1000),
        C(f"{N}_Flowers", flowers, rose_m, voxel=0.004, tris=4000, islands=2),
        S(f"{N}_Ribbons", ribbons, ribbon_m),
        C(f"{N}_Collar", collar, ribbon_m, voxel=0.006, tris=3000),
        C(f"{N}_Bow", bow, ribbon_m, voxel=0.005, tris=3000),
        C(f"{N}_Tassel", lambda p: tassel(p, V(0, 0.66, 0.86), 0.18, 0.04), rose_m, voxel=0.004, tris=1600),
        C(f"{N}_Cotton", lambda p: sphere(p, (0, 0.6, 0.3), 0.2), (f"{N}_CottonCream", m_matte("#F7EADD")),
          voxel=0.006, tris=2000),
    ]
    return assemble(N, "Rabbit", "Common", comps, "moon.rabbit")


def spiral2(u, v, pitch, turns, th):
    """Archimedean spiral band (cloud swirls): r = pitch * angle / 2pi, for `turns` turns."""
    r = np.sqrt(u * u + v * v)
    a = (np.arctan2(v, u) + 2 * math.pi) % (2 * math.pi)
    d = None
    for k in range(int(math.ceil(turns)) + 1):
        rr = pitch * (a / (2 * math.pi) + k)
        e = np.abs(r - rr)
        e = np.where(rr > pitch * turns, 1.0, e)
        d = e if d is None else np.minimum(d, e)
    return d - th


def star4(u, v, r, waist=0.3):
    """Four-point sparkle star of radius r; `waist` sets the arm width."""
    a, b = np.abs(u), np.abs(v)
    k = math.hypot(1 / waist, 1)
    return np.minimum((a / waist + b - r) / k, (b / waist + a - r) / k)


def dragon():
    N = "MoonDragon"
    cream, teal, aqua, green = "#F7F0E4", "#2F8789", "#A8DCD6", "#7DBB9C"

    clouds = [((0, -0.35, 0.34), 0.42), ((-0.62, -0.42, 0.3), 0.36), ((0.62, -0.42, 0.3), 0.36),
              ((-0.95, 0.05, 0.3), 0.36), ((0.95, 0.05, 0.3), 0.38), ((-0.55, 0.5, 0.32), 0.4),
              ((0.5, 0.55, 0.32), 0.4), ((0, 0.62, 0.3), 0.36), ((-1.15, -0.4, 0.2), 0.24), ((1.2, -0.35, 0.2), 0.25),
              ((0.25, -0.75, 0.22), 0.25), ((-0.3, -0.78, 0.2), 0.22)]

    def cloud(p):
        d = None
        for c, r in clouds:
            e = ellipsoid(p, c, (r, r * 0.9, r * 0.82))
            d = e if d is None else smin(d, e, 0.06)
        return smax(d, -p[2], 0.02)

    swirl_items = []
    for c, r in clouds:
        if c[1] < 0.1 or abs(c[0]) > 0.9:
            q, n = anchor(cloud, c, (np.sign(c[0]) * 0.35 if abs(c[0]) > 0.5 else 0, -1, 0.3))
            swirl_items.append((q, n, (lambda rr: lambda u, v: spiral2(u, v, rr * 0.22, 2.0, 0.018))(r)))
    swirls = decal(cloud, swirl_items, 0.012, k=0.004, slab=0.12)

    coil = [(0.05, -0.05, 0.72), (-0.5, -0.42, 0.66), (0.1, -0.72, 0.6), (0.72, -0.42, 0.64), (0.86, 0.18, 0.7),
            (0.45, 0.62, 0.76), (-0.25, 0.7, 0.86), (-0.72, 0.4, 1.02), (-0.86, 0.06, 1.3), (-0.76, -0.08, 1.52)]

    def body(p):
        d = tube(p, coil, [0.34, 0.3, 0.27, 0.26, 0.24, 0.22, 0.19, 0.15, 0.1, 0.065], k=0.06)
        d = smin(d, round_cone(p, (0, -0.1, 0.8), (0, -0.32, 1.72), 0.46, 0.31), 0.12)
        for sx in (-1, 1):  # little forelegs
            d = smin(d, tube(p, [(sx * 0.3, -0.42, 1.32), (sx * 0.4, -0.66, 1.18), (sx * 0.26, -0.78, 1.1)],
                             [0.09, 0.08, 0.075]), 0.05)
        return d

    coil_z = path_centre(coil[1:])

    def off_torso(p):
        return 0.5 - np.sqrt(p[0] ** 2 + (p[1] + 0.15) ** 2) - np.clip(p[2] - 0.9, 0, None)

    def underside(p):
        return overlay(body(p), smax(p[2] - coil_z(p) + 0.04, off_torso(p), 0.03), 0.008, 0.05, 0.02)

    def edge(p):
        return overlay(body(p), smax(np.abs(p[2] - coil_z(p) + 0.04) - 0.022, off_torso(p), 0.02), 0.013, 0.05, 0.004)

    belly = decal(body, [(*front(body, 0, 1.25, -0.2), lambda u, v: np.maximum(
        ellipse2(u, v, 0.27, 0.62), -(np.abs(np.sin(v * 22)) - 0.12)))], 0.012, k=0.004, slab=0.4)
    belly_plate = decal(body, [(*front(body, 0, 1.25, -0.2), blob(0.29, 0.64))], 0.006, k=0.01, slab=0.4)

    hc = V(0, -0.42, 2.18)

    def head(p):
        d = ellipsoid(p, hc, (0.56, 0.5, 0.48))
        d = smin(d, ellipsoid(p, (0, -0.86, 2.04), (0.27, 0.3, 0.2)), 0.16)
        d = smin(d, round_cone(p, (0, -0.3, 1.86), (0, -0.2, 1.62), 0.3, 0.27), 0.12)  # neck
        return d

    def cheek_fins(p):
        roots, tips = [], []
        for sx in (-1, 1):
            for dz, out, up, back in ((0.14, 0.86, 0.2, 0.12), (-0.02, 0.94, 0.02, 0.18), (-0.18, 0.84, -0.16, 0.16)):
                roots.append(V(sx * 0.4, -0.42, 2.14 + dz))
                tips.append(V(sx * out, -0.28 + back, 2.14 + dz + up))
        return spikes(p, roots, tips, 0.16, 0.05, 0.08)

    def mane(p):
        d = None
        for i, (y, z, h, lean) in enumerate(((-0.66, 2.5, 0.34, 18), (-0.5, 2.58, 0.44, 10), (-0.32, 2.6, 0.5, 2),
                                             (-0.12, 2.54, 0.46, -6), (0.06, 2.42, 0.4, -14))):
            for sx in ((0,) if i % 2 == 0 else (-1, 1)):
                c = V(sx * 0.13, y, z + h * 0.45)
                leaf = ellipsoid(p, c, (0.11, 0.05, h * 0.55), rot(-25 - lean, sx * 18, 0))
                d = leaf if d is None else smin(d, leaf, 0.04)
        for i, (y, z, h) in enumerate(((-0.62, 2.55, 0.32), (-0.42, 2.62, 0.42), (-0.2, 2.6, 0.44), (0.02, 2.5, 0.42),
                                       (0.18, 2.32, 0.36), (0.26, 2.1, 0.3))):
            for sx in ((0,) if i % 2 == 0 else (-0.14, 0.14)):
                e = round_cone(p, (sx, y, z - 0.12), (sx * 1.6, y + 0.22, z + h * 0.7), 0.12, 0.02)
                d = e if d is None else smin(d, e, 0.05)
        return smin(d, ellipsoid(p, (0, -0.2, 2.42), (0.22, 0.52, 0.22), rot(-35, 0, 0)), 0.06)

    forehead_c, forehead_n = front(head, 0, 2.44, -0.42)
    diamond = decal(head, [(forehead_c, forehead_n, lambda u, v: (np.abs(u) * 1.6 + np.abs(v) - 0.09))], 0.012, k=0.004)

    antlers = []
    for sx in (-1, 1):
        antlers.append(tail([(sx * 0.22, -0.42, 2.55), (sx * 0.3, -0.36, 2.85), (sx * 0.38, -0.18, 3.12),
                             (sx * 0.4, 0.05, 3.3)], 0.11, 0.04, samples=10))
        antlers.append(tail([(sx * 0.32, -0.36, 2.85), (sx * 0.52, -0.3, 2.98), (sx * 0.66, -0.16, 3.14)],
                            0.075, 0.03, samples=8))
        antlers.append(tail([(sx * 0.3, -0.25, 2.5), (sx * 0.48, -0.12, 2.62), (sx * 0.6, 0.06, 2.84)],
                            0.08, 0.03, samples=8))

    whisk_gold = [tail([(-0.24, -0.98, 2.04), (-0.6, -0.9, 2.14), (-0.88, -0.62, 2.36), (-0.92, -0.4, 2.6),
                        (-0.78, -0.36, 2.74)], 0.04, 0.03, samples=10),
                  tail([(0.24, -0.98, 2.04), (0.62, -0.88, 2.0), (0.88, -0.6, 1.82), (0.98, -0.42, 1.56),
                        (0.92, -0.3, 1.34)], 0.04, 0.025, samples=10)]
    whisk_green = [tail([(-0.24, -0.96, 1.98), (-0.62, -0.78, 1.82), (-0.9, -0.56, 1.66), (-1.0, -0.5, 1.4)],
                        0.035, 0.02, flat_ratio=0.6, samples=10),
                   tail([(0.24, -0.96, 2.08), (0.55, -0.82, 2.3), (0.8, -0.56, 2.42), (0.9, -0.3, 2.3)],
                        0.035, 0.02, flat_ratio=0.6, samples=10)]
    star_c = V(-0.74, -0.36, 2.86)
    pend_c = V(-1.0, -0.5, 1.22)

    def star(p):
        R = frame(V(0, -1, 0))
        x, y, z = local(p, star_c, R)
        flat2 = star4(x, y, 0.2, 0.3)
        return smax(flat2, np.abs(z) - 0.035, 0.02)

    def gold(p):
        d = star(p)
        d = np.minimum(d, coin(p, pend_c, V(0, -1, 0), 0.1, 0.04))
        d = np.minimum(d, torus(p, (0, -0.32, 1.7), 0.32, 0.025, rot(-20, 0, 0)))  # necklace chain
        d = np.minimum(d, coin(p, V(0, -0.74, 1.5), V(0, -1, 0.2), 0.09, 0.04))  # pendant boss
        d = np.minimum(d, round_cone(p, (0, -0.66, 1.44), (0, -0.67, 1.3), 0.03, 0.022))
        for sx in (-1, 1):
            for t in (-1, 0, 1):
                d = np.minimum(d, round_cone(p, (sx * 0.26 + t * 0.04, -0.84, 1.1), (sx * 0.26 + t * 0.05, -0.9, 1.04),
                                             0.022, 0.008))  # claws
        d = np.minimum(d, spikes(p, [V(-0.76, -0.08, 1.52)] * 3,
                                 [V(-0.95, -0.05, 1.72), V(-0.7, 0.02, 1.78), V(-0.58, -0.12, 1.66)], 0.06, 0.015))
        return d

    def pearl(p):
        return sphere(p, pend_c + V(0, -0.04, 0), 0.055)

    eyes_ = eyes(N, head, [(-0.24, 2.22), (0.24, 2.22)], 0.125, 0.145, tilt=8, y0=-0.42, lid=0.82,
                 iris=["#CDEFD8", "#5DBB93", "#1F7258", "#0E3A2E"])
    cream_m, teal_m, gold_m = (f"{N}_Cream", m_gloss(cream)), (f"{N}_Teal", m_gloss(teal)), (f"{N}_GoldMat", m_gold())
    comps = [
        C(f"{N}_Cloud", cloud, (f"{N}_CloudCream", m_gloss("#FBF6EE")), voxel=0.009, tris=14000, err=0.022),
        C(f"{N}_CloudSwirls", swirls, (f"{N}_Aqua", m_gloss(aqua)), voxel=0.004, tris=8000, islands=None),
        C(f"{N}_Body", body, teal_m, voxel=0.008, tris=16000, err=0.022),
        C(f"{N}_BellyPlate", belly_plate, cream_m, voxel=0.005, tris=4000, islands=None),
        C(f"{N}_CoilBelly", underside, cream_m, voxel=0.006, tris=8000, islands=None),
        C(f"{N}_CoilEdge", edge, gold_m, voxel=0.005, tris=6000, islands=None),
        C(f"{N}_BellyRidges", belly, cream_m, voxel=0.004, tris=6000, islands=None),
        C(f"{N}_Head", head, cream_m, voxel=0.007, tris=12000, err=0.018),
        C(f"{N}_CheekFins", cheek_fins, cream_m, voxel=0.005, tris=5000, islands=2),
        C(f"{N}_Mane", mane, teal_m, voxel=0.006, tris=8000, err=0.015),
        C(f"{N}_Diamond", diamond, teal_m, voxel=0.003, tris=600),
        *eyes_,
        blush(N, head, [(-0.3, 2.04), (0.3, 2.04)], 0.08, 0.05, y0=-0.42),
        C(f"{N}_Nose", lambda p: ellipsoid(p, front(head, 0, 2.08, -0.6)[0] + V(0, 0.012, 0), (0.06, 0.03, 0.035)),
          (f"{N}_NosePink", m_gloss("#F2A39A")), voxel=0.004, tris=600),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.97, -0.6), mouth_smile(0.08, 55.0, 0.01))], 0.008),
          (f"{N}_MouthInk", m_matte("#6A3B33")), voxel=0.003, tris=800),
        S(f"{N}_Antlers", antlers, gold_m),
        S(f"{N}_WhiskersGold", whisk_gold, gold_m),
        S(f"{N}_WhiskersGreen", whisk_green, (f"{N}_Jade", m_gloss(green))),
        C(f"{N}_Gold", gold, gold_m, voxel=0.0045, tris=10000, islands=None),
        C(f"{N}_Pearl", pearl, (f"{N}_PearlMat", preset("pearlescent", "#F6F0E8")), voxel=0.003, tris=600),
        C(f"{N}_Tassel", lambda p: tassel(p, pend_c + V(0, 0, -0.1), 0.24, 0.05), (f"{N}_TasselCream", m_fabric("#F3DFC6")),
          voxel=0.004, tris=2400),
    ]
    return assemble(N, "Dragon", "Legendary", comps, "moon.dragon", tri_scale=0.6)


def snake():
    N = "MoonSnake"
    teal, cream, tan, sage = "#33807B", "#F6ECDD", "#E9C9A0", "#8FAE8C"
    turns, z0, pitch = 1.6, 0.3, 0.36

    def spiral_pt(t):  # t in [0, 1] along the coil, outer bottom (back) to inner top (front)
        a = math.pi / 2 + t * turns * 2 * math.pi
        r = 0.86 - 0.36 * t
        return V(r * math.cos(a), r * math.sin(a) + 0.1, z0 + pitch * turns * t)

    coil = [spiral_pt(t) for t in np.linspace(0, 1, 14)]
    neck = [coil[-1], V(0.05, -0.32, 1.02), V(0.0, -0.3, 1.32), V(0, -0.24, 1.58)]
    tail_pts = [coil[0], V(-0.42, 0.9, 0.27), V(-0.78, 0.66, 0.22), V(-0.96, 0.3, 0.17), V(-0.98, -0.05, 0.13)]

    def body(p):
        d = tube(p, coil, np.linspace(0.31, 0.26, len(coil)), k=0.05)
        d = smin(d, tube(p, neck, [0.28, 0.29, 0.3, 0.32], k=0.05), 0.08)
        return smax(d, 0.0 - p[2], 0.02)

    def top_region(p):
        x, y, z = p[0], p[1] - 0.1, p[2]
        a = (np.arctan2(y, x) + math.pi / 2) % (2 * math.pi)
        best = None
        for k in range(2):
            zc = z0 + pitch * (a / (2 * math.pi) + k)
            e = np.abs(z - zc)
            best = e if best is None else np.minimum(best, e)
            if k == 0:
                zc0 = zc
        return best

    spiral_z = path_centre(list(reversed(tail_pts)) + coil[1:], sigma=0.07)

    def back_region(p):
        # teal over the top half of the coil and tail (continuous split); the neck is teal behind
        coil_part = smax((spiral_z(p) - 0.03) - p[2], p[2] - 1.15, 0.03)
        neck_back = np.maximum(-(p[1] + 0.22) * 4, 0.95 - p[2])
        return smin(coil_part, neck_back, 0.02)

    teal_skin = lambda p: overlay(body(p), back_region(p), 0.008, 0.05, 0.02)
    seam = lambda p: overlay(body(p), smax(np.abs(spiral_z(p) - 0.03 - p[2]) - 0.02, p[2] - 1.0, 0.02), 0.014, 0.05, 0.004)

    hc = V(0, -0.2, 2.0)

    def head(p):
        d = ellipsoid(p, hc, (0.64, 0.58, 0.55))
        d = smin(d, ellipsoid(p, (0, -0.58, 1.82), (0.44, 0.3, 0.3)), 0.2)
        return d

    def cap_region(p):
        x, y, z = p[0] - hc[0], p[1] - hc[1], p[2] - hc[2]
        az = np.abs(np.arctan2(x, -y))  # 0 front, pi back
        line = np.interp(az, [0, 0.35, 0.9, 1.6, 3.2], [0.2, 0.22, 0.1, -0.12, -0.42])
        line = line - 0.06 * np.exp(-(x / 0.06) ** 2) * (az < 0.6)
        return line - z

    cap = lambda p: overlay(head(p), cap_region(p), 0.012, 0.05, 0.02)

    loops = {sx: V(sx * 0.64, -0.05, 2.08) for sx in (-1, 1)}

    def ear_loops(p):
        d = None
        for sx in (-1, 1):
            e = torus(p, loops[sx], 0.14, 0.05, rot(0, 0, 90) @ rot(0, 15 * sx, 0))
            d = e if d is None else np.minimum(d, e)
        return d

    fl_c, fl_n = anchor(head, hc, (0.35, -0.3, 0.9), 0.02)

    def gold(p):
        d = None
        for sx in (-1, 1):
            e = torus(p, loops[sx] + V(0, 0, -0.12), 0.06, 0.022, frame(V(1, 0, 0)))
            e = np.minimum(e, round_cone(p, loops[sx] + V(0, -0.02, -0.18), loops[sx] + V(sx * 0.02, -0.02, -0.42),
                                         0.015, 0.015))
            leaf = ellipsoid(p, loops[sx] + V(sx * 0.02, -0.03, -0.5), (0.05, 0.025, 0.09))
            e = np.minimum(e, leaf)
            d = e if d is None else np.minimum(d, e)
        d = np.minimum(d, sphere(p, fl_c + V(0.02, -0.03, 0.05), 0.08))
        dc, dn = front(head, 0, 2.3, -0.2)
        d = np.minimum(d, ellipsoid(p, dc + V(0, 0.0, -0.04), (0.03, 0.02, 0.06)))  # forehead drop
        d = np.minimum(d, torus(p, (0, -0.28, 1.22), 0.31, 0.04, rot(-12, 0, 0)))  # collar trim
        d = np.minimum(d, torus(p, (0, -0.25, 1.32), 0.3, 0.03, rot(-12, 0, 0)))
        d = np.minimum(d, torus(p, med_c, 0.13, 0.03, frame(V(0, -1, 0.25))))  # medallion rim
        return d

    med_c = V(0, -0.64, 1.12)

    def collar(p):
        return torus(p, (0, -0.27, 1.27), 0.3, 0.06, rot(-12, 0, 0))

    def jade(p):
        return cylinder(p, med_c, 0.12, 0.03, r=0.012, R=frame(V(0, -1, 0.25)))

    def petals(p):
        c = fl_c + V(0, 0, 0.02)
        return flower(p, c, V(0.3, -0.4, 1), 0.24, spin=8, petal_w=0.8)

    def leaves(p):
        return np.minimum(ellipsoid(p, fl_c + V(-0.18, 0.05, -0.02), (0.15, 0.06, 0.03), rot(20, 0, 25)),
                          ellipsoid(p, fl_c + V(0.12, 0.12, -0.04), (0.12, 0.05, 0.03), rot(-15, 0, -30)))

    gold_decor = decal(teal_skin, [(*anchor(body, coil[k], (coil[k][0], coil[k][1] - 0.1, 0.7)), lambda u, v: flower(
        (u, v, np.zeros_like(u)), V(0, 0, 0), V(0, 0, 1), 0.08, petal_w=0.7)) for k in (3, 5, 7, 9)],
                       0.006, k=0.003, slab=0.12)

    comps = [
        C(f"{N}_Body", body, (f"{N}_Cream", m_gloss(cream)), voxel=0.008, tris=14000, err=0.02),
        C(f"{N}_Seam", seam, (f"{N}_GoldMat", m_gold()), voxel=0.006, tris=8000, islands=None,
          bounds=((-1.3, -1.3, -0.1), (1.3, 1.5, 1.3))),
        C(f"{N}_Scales", teal_skin, (f"{N}_Teal", m_gloss(teal)), voxel=0.006, tris=14000, err=0.016, islands=None),
        S(f"{N}_TailTip", [tail(tail_pts, 0.3, 0.06, power=0.8)], (f"{N}_TailTwoTone", m_gloss([cream, cream, teal, teal])),
          ramp=lambda x, y, z: np.clip((z - spiral_z((x, y, z)) + 0.03) / 0.06 + 0.5, 0, 1)),
        C(f"{N}_Head", head, (f"{N}_Cream", m_gloss(cream)), voxel=0.007, tris=12000, err=0.018),
        C(f"{N}_Cap", cap, (f"{N}_Teal", m_gloss(teal)), voxel=0.005, tris=8000),
        C(f"{N}_EarLoops", ear_loops, (f"{N}_Teal", m_gloss(teal)), voxel=0.005, tris=3000, islands=2),
        *eyes(N, head, [(-0.28, 1.98), (0.28, 1.98)], 0.17, 0.19, tilt=6, y0=-0.2, brows=(0.28, 0.06, 0.018, -10),
              brow_color="#B98A6A"),
        blush(N, head, [(-0.44, 1.8), (0.44, 1.8)], 0.11, 0.07, y0=-0.2),
        C(f"{N}_Nostrils", decal(head, [(*front(head, sx * 0.07, 1.76, -0.3), blob(0.025, 0.018)) for sx in (-1, 1)],
                                 0.008, k=0.003), (f"{N}_NostrilMat", m_matte("#C98A84")), voxel=0.003, tris=600,
          islands=2),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.66, -0.3), mouth_smile(0.16, 48.0, 0.012))], 0.008),
          (f"{N}_MouthInk", m_matte("#7A4438")), voxel=0.003, tris=1000),
        C(f"{N}_Collar", collar, (f"{N}_Red", m_fabric(RED)), voxel=0.005, tris=4000),
        C(f"{N}_Gold", gold, (f"{N}_GoldMat", m_gold()), voxel=0.004, tris=10000, islands=None),
        C(f"{N}_GoldMotifs", gold_decor, (f"{N}_GoldMat", m_gold()), voxel=0.004, tris=3000, islands=None),
        C(f"{N}_Jade", jade, (f"{N}_JadeMat", m_gloss("#4E9A73")), voxel=0.004, tris=1600),
        C(f"{N}_Flower", petals, (f"{N}_Petal", m_vinyl("#F7C2BC")), voxel=0.004, tris=3000),
        C(f"{N}_Leaves", leaves, (f"{N}_Leaf", m_vinyl(sage)), voxel=0.004, tris=1600, islands=2),
        C(f"{N}_Tassels", lambda p: np.minimum(tassel(p, med_c + V(0, 0, -0.16), 0.24, 0.05),
                                               tassel(p, loops[-1] + V(-0.06, -0.02, -0.36), 0.18, 0.04)),
          (f"{N}_Blue", m_fabric("#3E54A8")), voxel=0.004, tris=4000, islands=2),
        C(f"{N}_Beads", lambda p: np.minimum(sphere(p, loops[-1] + V(-0.06, -0.02, -0.28), 0.05),
                                             sphere(p, med_c + V(0.14, 0, -0.08), 0.04)),
          (f"{N}_Red", m_fabric(RED)), voxel=0.004, tris=1200, islands=2),
    ]
    return assemble(N, "Snake", "Uncommon", comps, "moon.snake")


def horse():
    N = "MoonHorse"
    cream, brown, chestnut, blue = "#FBF0E3", "#5B3424", "#8C5434", "#3B6FB0"
    legs = [(sx * 0.3, ly) for sx in (-1, 1) for ly in (-0.5, 0.62)]

    def body(p):
        d = ellipsoid(p, (0, 0.1, 1.08), (0.52, 0.84, 0.48))
        d = smin(d, ellipsoid(p, (0, -0.42, 1.18), (0.5, 0.46, 0.48)), 0.2)
        for x, y in legs:
            d = smin(d, round_cone(p, (x, y, 0.95), (x, y, 0.24), 0.21, 0.17), 0.1)
        d = smin(d, round_cone(p, (0, -0.42, 1.4), (0, -0.62, 1.86), 0.36, 0.3), 0.14)
        return d

    def hooves(p):
        d = None
        for x, y in legs:
            e = cylinder(p, (x, y - 0.02, 0.1), 0.2, 0.1, r=0.04)
            fet = torus(p, (x, y - 0.02, 0.22), 0.18, 0.05)
            for k in range(5):  # wavy feathered cuff
                a = k * 2 * math.pi / 5
                fet = smin(fet, sphere(p, (x + 0.16 * math.cos(a), y - 0.02 + 0.16 * math.sin(a), 0.2), 0.05), 0.03)
            e = np.minimum(e, fet)
            d = e if d is None else np.minimum(d, e)
        return d

    hc = V(0, -0.66, 2.2)

    def head(p):
        d = ellipsoid(p, hc, (0.54, 0.5, 0.5))
        d = smin(d, ellipsoid(p, (0, -1.08, 1.94), (0.34, 0.32, 0.28)), 0.2)
        return d

    patch = decal(head, [(*front(head, -0.3, 2.22, -0.66), blob(0.24, 0.26, du=-0.02, tilt=15))], 0.008, k=0.012)

    ears = {sx: V(sx * 0.3, -0.52, 2.72) for sx in (-1, 1)}

    def ear_fn(p):
        d = None
        for sx in (-1, 1):
            e = round_cone(p, ears[sx] - V(0, 0, 0.12), ears[sx] + V(sx * 0.04, 0.02, 0.18), 0.13, 0.03)
            e = smax(e, -ellipsoid(p, ears[sx] + V(0, -0.1, 0.0), (0.07, 0.06, 0.16)), 0.02)
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, ears[sx] + V(0, -0.05, 0.0), (0.07, 0.03, 0.15))
            d = e if d is None else np.minimum(d, e)
        return d

    def mane_cap(p):
        d = ellipsoid(p, hc + V(0, 0.08, 0.14), (0.6, 0.52, 0.48))
        for sx in (-1, 1):
            side = tube(p, [(sx * 0.32, -0.5, 2.58), (sx * 0.58, -0.5, 2.26), (sx * 0.6, -0.42, 1.86),
                            (sx * 0.66, -0.4, 1.52), (sx * 0.78, -0.48, 1.36)], [0.24, 0.24, 0.2, 0.16, 0.1], k=0.04)
            side = side + 0.012 * np.abs(np.sin(np.arctan2(p[1] + 0.45, p[0] - sx * 0.6) * 5)) ** 0.5
            d = smin(d, side, 0.08)
        d = smax(d, -(p[2] - (hc[2] + 0.12 - 0.2 * np.clip(p[1] - hc[1] + 0.2, 0, 1))), 0.06)
        d = smin(d, round_cone(p, hc + V(0, 0.3, 0.0), (0, -0.2, 1.45), 0.28, 0.16), 0.1)  # crest down the neck
        return d

    locks_dark, locks_light = [], []
    for sx in (-1, 1):
        locks_dark.append(sweep([(sx * 0.28, -0.88, 2.66), (sx * 0.5, -0.96, 2.5), (sx * 0.56, -0.9, 2.3),
                                 (sx * 0.48, -0.86, 2.16)], taper([0] * 4, 0.14, 0.05)[:, ::-1] * V(1, 0.5),
                                samples=8, sides=14))
        locks_dark.append(sweep([(sx * 0.5, -0.5, 2.5), (sx * 0.68, -0.58, 2.1), (sx * 0.66, -0.52, 1.7),
                                 (sx * 0.74, -0.6, 1.42), (sx * 0.86, -0.66, 1.36)],
                                taper([0] * 5, 0.17, 0.05) * V(1, 0.55), samples=8, sides=14))
        locks_light.append(sweep([(sx * 0.42, -0.3, 2.45), (sx * 0.58, -0.25, 2.0), (sx * 0.55, -0.2, 1.6),
                                  (sx * 0.62, -0.18, 1.3), (sx * 0.74, -0.22, 1.22)],
                                 taper([0] * 5, 0.16, 0.05) * V(1, 0.55), samples=8, sides=14))
        locks_dark.append(sweep([(sx * 0.2, -0.2, 2.62), (sx * 0.42, 0.0, 2.3), (sx * 0.4, 0.05, 1.9),
                                 (sx * 0.5, 0.0, 1.55), (sx * 0.66, -0.08, 1.4)],
                                taper([0] * 5, 0.2, 0.06) * V(1, 0.6), samples=8, sides=14))
        locks_light.append(sweep([(sx * 0.56, -0.7, 2.52), (sx * 0.72, -0.78, 2.2), (sx * 0.7, -0.72, 1.86),
                                  (sx * 0.8, -0.8, 1.66), (sx * 0.94, -0.78, 1.62)],
                                 taper([0] * 5, 0.14, 0.04) * V(1, 0.6), samples=8, sides=14))
    for k, x in enumerate((-0.17, 0.0, 0.17)):  # cascade down the back of the neck to the withers
        (locks_dark if k != 1 else locks_light).append(sweep(
            [(x, -0.36, 2.62), (x * 1.1, -0.18, 2.3), (x * 1.3 + 0.03, -0.24, 1.95), (x * 1.4 - 0.03, -0.14, 1.62),
             (x * 1.6, -0.02, 1.4)], taper([0] * 5, 0.17, 0.07) * V(1, 0.6), samples=8, sides=14))
    locks_dark.append(sweep([(0.0, -0.98, 2.7), (-0.16, -1.14, 2.58), (-0.2, -1.18, 2.4), (-0.08, -1.14, 2.3)],
                            taper([0] * 4, 0.15, 0.05) * V(1, 0.6), samples=8, sides=14))
    locks_light.append(sweep([(0.1, -0.9, 2.74), (0.3, -1.04, 2.66), (0.42, -1.02, 2.52)],
                             taper([0] * 3, 0.1, 0.04) * V(1, 0.6), samples=8, sides=14))
    tail_locks = [sweep([(sx * 0.08, 0.86, 1.3), (sx * 0.24, 1.2, 1.12), (sx * 0.3, 1.38, 0.72), (sx * 0.24, 1.3, 0.38),
                         (sx * 0.06, 1.1, 0.3)], taper([0] * 5, 0.2, 0.05) * V(1, 0.7), samples=8, sides=14)
                  for sx in (-1, 1)]
    tail_locks.append(sweep([(0, 0.88, 1.32), (0, 1.26, 1.24), (0.02, 1.5, 0.9), (0.06, 1.48, 0.5), (0.16, 1.32, 0.3)],
                            taper([0] * 5, 0.22, 0.06) * V(0.8, 1.0), samples=8, sides=14))

    def blanket_region(p):
        return np.maximum(0.88 - p[2], np.abs(p[1] - 0.05) - 0.62)

    def blanket(p):
        return np.maximum(np.abs(body(p) - 0.05) - 0.03, blanket_region(p))

    def blanket_trim(p):
        r = blanket_region(p)
        return np.maximum(np.abs(body(p) - 0.05) - 0.044, np.maximum(r, -r - 0.06))

    def underlay(p):
        r = np.maximum(0.82 - p[2], np.abs(p[1] - 0.1) - 0.66)
        return np.maximum(np.abs(body(p) - 0.03) - 0.025, r)

    def strap(p):
        return torus(p, (0, -0.5, 1.32), 0.5, 0.06, rot(-30, 0, 0))

    meds = [V(0, -0.98, 1.26), V(-0.48, -0.66, 1.28), V(0.48, -0.66, 1.28)]

    def gold(p):
        d = None
        for c in meds:
            n = c - V(0, -0.4, 1.3)
            e = coin(p, c, n, 0.13, 0.05)
            e = smin(e, flower(p, c + n / np.linalg.norm(n) * 0.03, n, 0.08, petals=8), 0.01)
            d = e if d is None else np.minimum(d, e)
        crown = front(head, 0, 2.5, -0.66)[0]
        cr = ellipsoid(p, crown + V(0, 0.02, 0.06), (0.24, 0.09, 0.16), rot(-30, 0, 0))
        cr = smin(cr, torus(p, crown + V(0.04, 0.06, 0.24), 0.09, 0.025, frame(V(0, -1, 0.2))), 0.01)
        d = np.minimum(d, cr)
        d = np.minimum(d, torus(p, (0, -1.06, 2.0), 0.3, 0.03, rot(-75, 0, 0)))  # noseband
        for sx in (-1, 1):
            d = np.minimum(d, ellipsoid(p, (sx * 0.56, -0.66, 2.42), (0.1, 0.05, 0.06), rot(0, sx * 30, 0)))  # pins
        for sx in (-1, 1):
            d = np.minimum(d, cylinder(p, (sx * 0.22, 1.25, 0.74), 0.06, 0.05, r=0.02))  # tail ornament caps
        return d

    def gem(p):
        return ellipsoid(p, front(head, 0, 2.52, -0.66)[0] + V(0, -0.08, 0.06), (0.07, 0.035, 0.08))

    def tassels_blue(p):
        d = tassel(p, meds[0] + V(0, 0, -0.14), 0.22, 0.05)
        for c in meds[1:]:
            d = np.minimum(d, tassel(p, c + V(0, 0, -0.14), 0.26, 0.05))
        for sx in (-1, 1):
            d = np.minimum(d, tassel(p, V(sx * 0.6, -0.68, 2.36), 0.18, 0.04))
            d = np.minimum(d, tassel(p, V(sx * 0.22, 1.25, 0.66), 0.16, 0.04))
        return d

    cream_m, dark_m, light_m = (f"{N}_Cream", m_vinyl(cream)), (f"{N}_ManeDark", m_gloss(brown)), (f"{N}_ManeLight", m_gloss(chestnut))
    gold_m, blue_m = (f"{N}_GoldMat", m_gold()), (f"{N}_Blue", m_fabric(blue))
    comps = [
        C(f"{N}_Body", body, cream_m, voxel=0.008, tris=14000, err=0.02),
        C(f"{N}_Hooves", hooves, (f"{N}_Hoof", m_vinyl("#4E2E22")), voxel=0.005, tris=8000, islands=4),
        C(f"{N}_Head", head, cream_m, voxel=0.007, tris=12000, err=0.018),
        C(f"{N}_Patch", patch, (f"{N}_PatchBrown", m_vinyl("#B9784C")), voxel=0.005, tris=3000),
        C(f"{N}_Ears", ear_fn, cream_m, voxel=0.005, tris=3000, islands=2),
        C(f"{N}_EarInner", ear_in, (f"{N}_EarPink", m_vinyl("#F2A6A0")), voxel=0.004, tris=1600, islands=2),
        C(f"{N}_ManeCap", mane_cap, dark_m, voxel=0.007, tris=8000, err=0.018),
        S(f"{N}_ManeLocks", locks_dark, dark_m, tris=10000),
        S(f"{N}_ManeHighlights", locks_light + tail_locks[:2], light_m, tris=10000),
        *eyes(N, head, [(-0.27, 2.22), (0.27, 2.22)], 0.14, 0.17, tilt=6, y0=-0.66, brows=(0.26, 0.05, 0.016, -10),
              brow_color="#5B3424", iris=["#E9B276", "#B56A35", "#6B3618", "#2E160A"]),
        blush(N, head, [(-0.36, 2.0), (0.36, 2.0)], 0.1, 0.06, y0=-0.66),
        C(f"{N}_Nostrils", decal(head, [(*front(head, sx * 0.12, 1.98, -0.9), blob(0.035, 0.05, tilt=sx * 25))
                                        for sx in (-1, 1)], 0.008, k=0.003), (f"{N}_NostrilMat", m_matte("#8E5A4A")),
          voxel=0.003, tris=800, islands=2),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.82, -0.9), mouth_smile(0.12, 45.0, 0.011))], 0.008),
          (f"{N}_MouthInk", m_matte("#6A3A2E")), voxel=0.003, tris=800),
        C(f"{N}_Blanket", blanket, blue_m, voxel=0.006, tris=10000, err=0.016),
        C(f"{N}_BlanketTrim", blanket_trim, gold_m, voxel=0.005, tris=6000),
        C(f"{N}_Underlay", underlay, (f"{N}_Red", m_fabric(RED)), voxel=0.006, tris=6000),
        C(f"{N}_Strap", strap, blue_m, voxel=0.005, tris=4000),
        C(f"{N}_Gold", gold, gold_m, voxel=0.006, tris=14000, islands=None),
        C(f"{N}_Gem", gem, (f"{N}_GemBlue", m_gloss("#2D4E9A")), voxel=0.003, tris=600),
        C(f"{N}_Tassels", tassels_blue, blue_m, voxel=0.0055, tris=8000, islands=7),
        S(f"{N}_Tail", tail_locks[2:], dark_m),
    ]
    return assemble(N, "Horse", "Uncommon", comps, "moon.horse")


def ridged(points, r0, r1, ridges, depth, sides=20):
    """Tapered sweep with annular ridges (ram horns): radius modulated along a dense path."""
    from sdf import catmull
    path = np.asarray(catmull([V(q) for q in points], 16))
    t = np.linspace(0, 1, len(path))
    r = (r0 + (r1 - r0) * t) * (1 + depth * np.abs(np.sin(t * ridges * math.pi)) ** 0.5)
    return sweep(path, np.column_stack((r, r)), samples=1, sides=sides)


def puff_points(c, r, count, zmin, seed=0.0):
    """Fibonacci points on an ellipsoid surface above zmin: wool and cloud lumps."""
    c, r = V(c), V(r)
    out = []
    for i in range(count):
        z = 1 - 2 * (i + 0.5) / count
        a = i * math.pi * (3 - math.sqrt(5)) + seed
        q = c + r * V(math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z)
        if q[2] >= zmin:
            out.append(q)
    return out


def goat():
    N = "MoonGoat"
    cream, wool, horn, green = "#FBEFE2", "#FFF8F0", "#9A6232", "#5E9B66"
    hc = V(0, -0.58, 1.9)

    def head(p):
        d = ellipsoid(p, hc, (0.62, 0.54, 0.55))
        d = smin(d, ellipsoid(p, (0, -0.94, 1.7), (0.3, 0.24, 0.22)), 0.16)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.34, -0.72, 1.68), (0.26, 0.24, 0.22)), 0.12)
        return d

    tuft_pts = [V(0, -0.62, 2.3), V(-0.2, -0.5, 2.3), V(0.2, -0.5, 2.3), V(-0.1, -0.78, 2.22), V(0.12, -0.8, 2.22),
                V(0, -0.36, 2.34), V(-0.3, -0.7, 2.14), V(0.3, -0.7, 2.14)]

    def tuft(p):
        d = None
        for i, q in enumerate(tuft_pts):
            e = sphere(p, q, 0.15 if i < 3 else 0.12)
            d = e if d is None else smin(d, e, 0.04)
        return d

    ear_R = {sx: rot(-10, sx * -25, sx * 10) for sx in (-1, 1)}

    def ears(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, V(sx * 0.72, -0.5, 1.74), (0.3, 0.1, 0.13), ear_R[sx])
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, V(sx * 0.74, -0.57, 1.73), (0.23, 0.04, 0.08), ear_R[sx])
            d = e if d is None else np.minimum(d, e)
        return d

    horns = [ridged([(sx * 0.3, -0.42, 2.12), (sx * 0.52, -0.3, 2.48), (sx * 0.88, -0.2, 2.56), (sx * 1.12, -0.34, 2.32),
                     (sx * 1.1, -0.56, 2.04), (sx * 0.95, -0.6, 1.92), (sx * 0.88, -0.48, 2.04)],
                    0.16, 0.06, 12, 0.12) for sx in (-1, 1)]

    body_c, body_r = V(0, 0.12, 0.78), V(0.62, 0.76, 0.48)
    puffs = puff_points(body_c, body_r * 1.0, 46, 0.42) + [V(0, 0.98, 1.0), V(0.1, 1.08, 1.18), V(-0.08, 1.05, 0.86)]

    def body(p):
        d = ellipsoid(p, body_c, body_r)
        for i, q in enumerate(puffs):
            d = smin(d, sphere(p, q, 0.24 if i < len(puffs) - 3 else 0.2), 0.05)
        d = smin(d, round_cone(p, (0, -0.42, 1.0), (0, -0.55, 1.45), 0.36, 0.3), 0.12)  # neck
        return d

    legs = [(sx * 0.34, ly) for sx in (-1, 1) for ly in (-0.36, 0.6)]

    def leg_fn(p):
        d = None
        for x, y in legs:
            e = round_cone(p, (x, y, 0.5), (x, y, 0.2), 0.17, 0.16)
            for k in range(6):
                a = k * math.pi / 3
                e = smin(e, sphere(p, (x + 0.15 * math.cos(a), y + 0.15 * math.sin(a), 0.28), 0.08), 0.04)
            d = e if d is None else np.minimum(d, e)
        return d

    def hooves(p):
        d = None
        for x, y in legs:
            e = cylinder(p, (x, y - 0.02, 0.09), 0.16, 0.09, r=0.04)
            e = smax(e, -round_box(p, (x, y - 0.18, 0.08), (0.015, 0.06, 0.2), 0.008), 0.008)
            d = e if d is None else np.minimum(d, e)
        return d

    collar_R = rot(-26, 0, 0)

    def collar(p):
        return smax(torus(p, (0, -0.52, 1.28), 0.42, 0.07, collar_R), -torus(p, (0, -0.52, 1.28), 0.42, 0.035, collar_R) - 0.0, 0)

    def collar_pt(a, out=0.06):
        a = math.radians(a)
        return V(0, -0.52, 1.28) + collar_R @ V(0.42 * math.sin(a), -0.42 * math.cos(a) - out, 0)

    def gold(p):
        d = bell(p, collar_pt(0) + V(0, -0.02, -0.22), 0.13)
        for a in range(-80, 81, 20):
            d = np.minimum(d, sphere(p, collar_pt(a, 0.05), 0.035))
        d = np.minimum(d, flower(p, collar_pt(-38, 0.08), V(-0.4, -1, 0.3), 0.14, petal_w=0.8))
        d = np.minimum(d, sphere(p, collar_pt(28, 0.12), 0.045))
        d = np.minimum(d, sphere(p, V(0.86, -0.42, 1.08), 0.06))
        horn_marks = [anchor(lambda q: horn_sdf(q), V(sx * 0.62, -0.26, 2.54), (0, -1, 0.3)) for sx in (-1, 1)]
        for c, n in horn_marks:
            d = np.minimum(d, flower(p, c, n, 0.07, petal_w=0.7))
        return d

    def horn_sdf(q):
        return np.minimum(tube(q, [(0.52, -0.3, 2.48), (0.88, -0.2, 2.56)], [0.16, 0.14]),
                          tube(q, [(-0.52, -0.3, 2.48), (-0.88, -0.2, 2.56)], [0.16, 0.14]))

    def blossom(p):
        d = flower(p, collar_pt(28, 0.12), V(0.2, -1, 0.3), 0.18, petal_w=0.8)
        return d

    def side_flower(p):
        c = V(0.84, -0.4, 1.08)
        d = None
        for i in range(6):
            a = math.radians(60 * i)
            e = ellipsoid(p, c + V(0.02, 0.17 * math.cos(a), 0.17 * math.sin(a)), (0.06, 0.13, 0.08),
                          rot(math.degrees(a), 0, 0))
            d = e if d is None else smin(d, e, 0.02)
        return d

    def leaves(p):
        d = None
        for a, s_ in ((-60, 1.0), (-20, 0.8), (40, 0.9), (75, 0.8)):
            c = collar_pt(a, 0.07)
            e = ellipsoid(p, c, (0.1 * s_, 0.035, 0.06 * s_), rot(0, a * 0.8, 0) @ rot(0, 0, 20))
            d = e if d is None else np.minimum(d, e)
        d = np.minimum(d, ellipsoid(p, V(0.78, -0.3, 1.2), (0.03, 0.12, 0.06), rot(-30, 0, 0)))
        return d

    cream_m, wool_m, gold_m = (f"{N}_Cream", m_vinyl(cream)), (f"{N}_Wool", m_matte(wool)), (f"{N}_GoldMat", m_gold())
    comps = [
        C(f"{N}_Head", head, cream_m, voxel=0.007, tris=12000, err=0.018),
        C(f"{N}_Tuft", tuft, wool_m, voxel=0.006, tris=5000),
        C(f"{N}_Ears", ears, cream_m, voxel=0.005, tris=3000, islands=2),
        C(f"{N}_EarInner", ear_in, (f"{N}_EarPink", m_vinyl("#F2A9A0")), voxel=0.004, tris=1600, islands=2),
        S(f"{N}_Horns", horns, (f"{N}_Horn", m_gloss(horn)), tris=10000),
        *eyes(N, head, [(-0.26, 1.92), (0.26, 1.92)], 0.15, 0.18, tilt=4, y0=-0.58, brows=(0.27, 0.05, 0.016, -10),
              brow_color="#D9A27E"),
        blush(N, head, [(-0.4, 1.72), (0.4, 1.72)], 0.1, 0.06, y0=-0.58),
        C(f"{N}_Nose", lambda p: ellipsoid(p, front(head, 0, 1.74, -0.7)[0] + V(0, 0.01, 0), (0.05, 0.03, 0.035)),
          (f"{N}_NosePink", m_gloss("#F2A3A0")), voxel=0.004, tris=600),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.64, -0.7), mouth_w(0.04, 0.01, 0.06))], 0.008),
          (f"{N}_MouthInk", m_matte("#8A4E44")), voxel=0.003, tris=1000),
        C(f"{N}_Body", body, wool_m, voxel=0.008, tris=16000, err=0.022),
        C(f"{N}_Legs", leg_fn, wool_m, voxel=0.006, tris=6000, islands=4),
        C(f"{N}_Hooves", hooves, (f"{N}_Hoof", m_gloss("#A9733E")), voxel=0.005, tris=4000, islands=4),
        C(f"{N}_Collar", lambda p: torus(p, (0, -0.52, 1.28), 0.42, 0.075, collar_R), (f"{N}_Green", m_fabric(green)),
          voxel=0.005, tris=4000),
        C(f"{N}_Gold", gold, gold_m, voxel=0.004, tris=10000, islands=None),
        C(f"{N}_Blossom", blossom, (f"{N}_Petal", m_vinyl("#FBE0D2")), voxel=0.004, tris=2400),
        C(f"{N}_SideFlower", side_flower, (f"{N}_Coral", m_gloss("#F58E72")), voxel=0.004, tris=3000),
        C(f"{N}_Leaves", leaves, (f"{N}_Leaf", m_vinyl("#5E8F4E")), voxel=0.004, tris=3000, islands=None),
    ]
    return assemble(N, "Goat", "Common", comps, "moon.goat")


def monkey():
    N = "MoonMonkey"
    fur, face_c, pink = "#7A4A2D", "#F8E2CF", "#F3B3A6"
    hc = V(0, -0.05, 2.04)

    def head(p):
        d = ellipsoid(p, hc, (0.6, 0.54, 0.55))
        d = smin(d, ellipsoid(p, (0, -0.5, 1.84), (0.3, 0.16, 0.18)), 0.12)
        d = smin(d, spikes(p, [V(0, -0.1, 2.5)] * 3, [V(-0.1, -0.12, 2.82), V(0.06, -0.04, 2.86), V(0.16, -0.16, 2.74)],
                           0.12, 0.02, 0.05), 0.08)
        for sx in (-1, 1):
            d = smin(d, round_cone(p, (sx * 0.5, -0.1, 2.1), (sx * 0.72, -0.12, 2.2), 0.08, 0.015), 0.05)
        return d

    mask = decal(head, [(*front(head, 0, 1.98, -0.05), lambda u, v: np.minimum(
        np.minimum(ellipse2(u - 0.2, v - 0.06, 0.24, 0.26), ellipse2(u + 0.2, v - 0.06, 0.24, 0.26)),
        ellipse2(u, v + 0.2, 0.36, 0.26)))], 0.008, k=0.02, slab=0.6)

    ear_c = {sx: V(sx * 0.62, 0.0, 2.04) for sx in (-1, 1)}

    def ears(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, ear_c[sx], (0.12, 0.22, 0.24), rot(0, 0, sx * 25))
            e = smax(e, -ellipsoid(p, ear_c[sx] + V(sx * 0.06, -0.06, 0), (0.06, 0.16, 0.18), rot(0, 0, sx * 25)), 0.02)
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, ear_c[sx] + V(sx * 0.02, -0.03, 0), (0.03, 0.16, 0.18), rot(0, 0, sx * 25))
            d = e if d is None else np.minimum(d, e)
        return d

    def body(p):
        d = ellipsoid(p, (0, 0.02, 0.9), (0.46, 0.4, 0.5))
        for sx in (-1, 1):
            d = smin(d, round_cone(p, (sx * 0.22, 0.0, 0.5), (sx * 0.28, -0.06, 0.14), 0.19, 0.16), 0.08)
        return smax(d, 0.05 - p[2], 0.02)

    belly = decal(body, [(*front(body, 0, 0.72, 0), blob(0.26, 0.3))], 0.008, k=0.02)

    def feet(p):
        d = np.minimum(ellipsoid(p, (-0.29, -0.16, 0.08), (0.16, 0.24, 0.09)),
                       ellipsoid(p, (0.29, -0.16, 0.08), (0.16, 0.24, 0.09)))
        return smax(d, -p[2], 0.01)

    arm = {sx: [(sx * 0.42, -0.04, 1.28), (sx * 0.5, -0.32, 1.12), (sx * 0.3, -0.62, 1.0)] for sx in (-1, 1)}

    def arms(p):
        d = None
        for sx in (-1, 1):
            e = tube(p, arm[sx], [0.13, 0.12, 0.11], k=0.04)
            e = smin(e, ellipsoid(p, (sx * 0.24, -0.72, 0.96), (0.11, 0.12, 0.09)), 0.04)
            d = e if d is None else np.minimum(d, e)
        return d

    vest = Mantle((0, 0.0, 0.92), (0.54, 0.47, 0.5), flare=0.35, flare_z=1.0, th=0.04, hem=0.66, waves=5, wave=0.05,
                  y_top=-0.36, y_bot=-0.3)

    def gold(p):
        d = vest.trim(0.05)(p)
        for sx in (-1, 1):
            a, b = V(arm[sx][1]), V(arm[sx][2])
            d = np.minimum(d, torus(p, a + (b - a) * 0.8, 0.12, 0.03, frame(b - a)))
            c, R = V(sx * 0.42, -0.04, 1.36), rot(0, sx * 35, 0)
            d = np.minimum(d, smax(ellipsoid(p, c, (0.22, 0.24, 0.12), R),
                                   -ellipsoid(p, c + V(0, 0, -0.06), (0.19, 0.21, 0.1), R), 0.02))
        mark_c, mark_n = front(head, 0, 2.36, -0.05)
        d = np.minimum(d, flower(p, mark_c, mark_n, 0.08, petals=3, spin=90, petal_w=0.6))
        d = np.minimum(d, flower(p, V(0, -0.5, 1.32), V(0, -1, 0.2), 0.1, petals=8))
        d = np.minimum(d, sphere(p, V(0.0, 0.48, 1.12), 0.05))
        return d

    peach_c = V(0, -0.82, 1.06)

    def peach(p):
        d = sphere(p, peach_c, 0.26)
        d = smin(d, sphere(p, peach_c + V(0, -0.06, 0.2), 0.12), 0.12)
        crease = np.abs(p[0] - peach_c[0] + 0.03 * (p[2] - peach_c[2])) - 0.006
        return smax(d, -np.maximum(crease, -(p[1] - peach_c[1] + 0.1)), 0.03)

    def peach_leaves(p):
        return np.minimum(ellipsoid(p, peach_c + V(-0.22, -0.08, -0.12), (0.14, 0.05, 0.08), rot(10, 30, -30)),
                          ellipsoid(p, peach_c + V(0.24, -0.04, -0.14), (0.12, 0.05, 0.07), rot(-10, -30, 30)))

    def bow(p):
        c = V(0, 0.5, 1.2)
        d = ellipsoid(p, c, (0.1, 0.08, 0.09))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, c + V(sx * 0.2, 0.02, 0.06), (0.2, 0.07, 0.14), rot(0, sx * -20, 0)), 0.04)
            d = smin(d, round_cone(p, c + V(sx * 0.05, 0, -0.05), c + V(sx * 0.18, 0.04, -0.36), 0.05, 0.03), 0.02)
        return d

    # The curl stays within the ears' width: runtime facing aims from the bounding-box centre to _Eyes.
    tail_pts = [(0.12, 0.38, 0.58), (0.36, 0.66, 0.62), (0.5, 0.78, 1.0), (0.52, 0.74, 1.58), (0.48, 0.64, 2.08),
                (0.44, 0.58, 2.42), (0.64, 0.58, 2.42), (0.68, 0.58, 2.22), (0.54, 0.58, 2.12), (0.5, 0.58, 2.28)]

    fur_m, face_m, gold_m = (f"{N}_Fur", m_vinyl(fur)), (f"{N}_Face", m_vinyl(face_c)), (f"{N}_GoldMat", m_gold())
    red_m = (f"{N}_Red", m_fabric(RED))
    comps = [
        C(f"{N}_Head", head, fur_m, voxel=0.007, tris=12000, err=0.018),
        C(f"{N}_Mask", mask, face_m, voxel=0.005, tris=6000, islands=None),
        C(f"{N}_Ears", ears, fur_m, voxel=0.005, tris=3000, islands=2),
        C(f"{N}_EarInner", ear_in, (f"{N}_EarPink", m_vinyl(pink)), voxel=0.004, tris=1600, islands=2),
        *eyes(N, head, [(-0.21, 2.04), (0.21, 2.04)], 0.13, 0.16, tilt=4, y0=-0.05, brows=(0.25, 0.05, 0.018, -12),
              brow_color="#9A5E3A", iris=["#E9A866", "#B5642A", "#6A3216", "#2E140A"]),
        blush(N, head, [(-0.36, 1.86), (0.36, 1.86)], 0.1, 0.06, y0=-0.05),
        C(f"{N}_Nose", lambda p: ellipsoid(p, front(head, 0, 1.9, -0.05)[0] + V(0, 0.01, 0), (0.05, 0.03, 0.03)),
          (f"{N}_NosePink", m_gloss("#F09A8E")), voxel=0.004, tris=600),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.79, -0.05), mouth_w(0.045, 0.011, 0.04))], 0.008),
          (f"{N}_MouthInk", m_matte("#7A3E32")), voxel=0.003, tris=1000),
        C(f"{N}_Body", body, fur_m, voxel=0.007, tris=10000, err=0.018),
        C(f"{N}_Belly", belly, face_m, voxel=0.005, tris=3000),
        C(f"{N}_Feet", feet, face_m, voxel=0.005, tris=2400, islands=2),
        C(f"{N}_Arms", arms, fur_m, voxel=0.006, tris=4000, islands=2),
        C(f"{N}_Vest", vest, red_m, voxel=0.006, tris=10000, err=0.016, islands=None),
        C(f"{N}_Gold", gold, gold_m, voxel=0.0055, tris=12000, islands=None),
        C(f"{N}_Peach", peach, (f"{N}_PeachSkin", m_vinyl(["#FBE0C8", "#F7A79C", "#EE7F7F"])), voxel=0.005, tris=4000,
          ramp=lambda x, y, z: np.clip((z - peach_c[2] + 0.26) / 0.55, 0, 1)),
        C(f"{N}_PeachLeaves", peach_leaves, (f"{N}_Leaf", m_vinyl("#5E8F4E")), voxel=0.004, tris=1600, islands=2),
        C(f"{N}_Bow", bow, (f"{N}_Silk", m_gloss("#F2C661")), voxel=0.005, tris=3000),
        C(f"{N}_Tassel", lambda p: tassel(p, V(0.0, -0.53, 1.22), 0.2, 0.04), red_m, voxel=0.004, tris=1600),
        S(f"{N}_Tail", [tail(tail_pts, 0.095, 0.055, samples=10)], fur_m),
    ]
    return assemble(N, "Monkey", "Uncommon", comps, "moon.monkey")


def rooster():
    N = "MoonRooster"
    white, brown, red, cream, dark = "#FFF7EE", "#5E2A22", "#D8322E", "#F7DDB0", "#3B2E2E"
    hc = V(0, -0.22, 2.16)

    def body(p):
        d = ellipsoid(p, (0, 0.05, 1.12), (0.66, 0.62, 0.66))
        d = smin(d, ellipsoid(p, hc, (0.4, 0.4, 0.42)), 0.3)
        d = smin(d, ellipsoid(p, (0, -0.25, 1.35), (0.56, 0.48, 0.5)), 0.2)
        return d

    lower = lambda p: overlay(body(p), p[2] - 0.9 - 0.1 * np.clip(-p[1], 0, 1), 0.008, 0.05, 0.03)

    def comb(p):
        d = None
        for c, r, R in (((0, -0.32, 2.62), (0.09, 0.15, 0.2), rot(-30, 0, 0)), ((0, -0.12, 2.72), (0.1, 0.17, 0.24), rot(-10, 0, 0)),
                        ((0, 0.08, 2.66), (0.09, 0.16, 0.22), rot(15, 0, 0)), ((0, 0.22, 2.5), (0.08, 0.13, 0.17), rot(35, 0, 0)),
                        ((0.08, -0.2, 2.56), (0.07, 0.14, 0.18), rot(-20, 15, 0)), ((-0.08, 0.0, 2.6), (0.07, 0.15, 0.2), rot(0, -15, 0))):
            e = ellipsoid(p, c, r, R)
            d = e if d is None else smin(d, e, 0.04)
        return smin(d, ellipsoid(p, (0, -0.1, 2.48), (0.12, 0.25, 0.1)), 0.05)

    beak_c = front(body, 0, 2.1, -0.2)[0]

    def beak(p):
        top = round_cone(p, beak_c + V(0, 0.06, 0.02), beak_c + V(0, -0.2, -0.02), 0.11, 0.025)
        low = round_cone(p, beak_c + V(0, 0.04, -0.06), beak_c + V(0, -0.12, -0.08), 0.07, 0.02)
        return smin(top, low, 0.02)

    def wattle(p):
        return smin(ellipsoid(p, beak_c + V(-0.05, -0.02, -0.2), (0.06, 0.05, 0.1)),
                    ellipsoid(p, beak_c + V(0.05, -0.02, -0.21), (0.06, 0.05, 0.1)), 0.03)

    def wing_feathers(p, dark_only=False):
        d = None
        for sx in (-1, 1):
            base = V(sx * 0.6, -0.08, 1.28)
            for row, (dz, n, ln) in enumerate(((0.0, 4, 0.34), (-0.18, 4, 0.36), (-0.36, 3, 0.32))):
                for k in range(n):
                    if dark_only != (row == 2 and k in (0, 1)):
                        continue
                    y = -0.36 + 0.2 * k + 0.05 * row
                    c = base + V(sx * (0.06 + 0.03 * row), y, dz)
                    e = ellipsoid(p, c, (0.07, 0.11, ln * 0.5), rot(-20 + 12 * k, sx * -12, 0))
                    d = e if d is None else smin(d, e, 0.015)
        return d

    vest_R = rot(-8, 0, 0)

    def vest(p):
        band = smax(torus(p, (0, -0.02, 1.1), 0.64, 0.12, vest_R), -(p[1] + 0.2), 0.02)
        return smin(band, decal(body, [(*front(body, 0, 0.98, 0), blob(0.42, 0.24))], 0.035, k=0.02)(p), 0.02)

    med_c = front(body, 0.18, 1.12, 0)[0] + V(0, -0.1, 0)

    def gold(p):
        d = torus(p, med_c, 0.15, 0.03, frame(V(0.2, -1, 0)))
        d = np.minimum(d, bell(p, med_c + V(0.02, -0.04, -0.42), 0.08))
        d = np.minimum(d, torus(p, (0, -0.02, 1.2), 0.6, 0.025, vest_R))
        d = np.minimum(d, round_cone(p, med_c + V(0, -0.02, -0.15), med_c + V(0.02, -0.04, -0.32), 0.02, 0.02))
        return d

    def legs(p):
        d = None
        for sx in (-1, 1):
            hip = V(sx * 0.26, 0.05, 0.6)
            e = round_cone(p, hip, hip * V(1, 1, 0) + V(0, 0, 0.06), 0.06, 0.05)
            for a in (-35, 0, 35):
                toe = hip * V(1, 1, 0) + V(math.sin(math.radians(a + sx * 8)) * 0.24, -math.cos(math.radians(a)) * 0.24, 0.035)
                e = smin(e, round_cone(p, hip * V(1, 1, 0) + V(0, 0, 0.05), toe, 0.045, 0.025), 0.02)
            e = smin(e, round_cone(p, hip * V(1, 1, 0) + V(0, 0, 0.05), hip * V(1, 1, 0) + V(0, 0.16, 0.03), 0.04, 0.02), 0.02)
            d = e if d is None else np.minimum(d, e)
        return smax(d, -p[2], 0.005)

    def thighs(p):
        return np.minimum(ellipsoid(p, (-0.26, 0.02, 0.64), (0.2, 0.22, 0.2)), ellipsoid(p, (0.26, 0.02, 0.64), (0.2, 0.22, 0.2)))

    feathers = {"red": [], "cream": [], "brown": []}
    fan = [(-80, 0.9, "brown"), (-62, 1.15, "red"), (-46, 1.25, "cream"), (-30, 1.35, "red"), (-15, 1.3, "brown"),
           (0, 1.4, "red"), (15, 1.3, "cream"), (30, 1.35, "red"), (46, 1.25, "brown"), (62, 1.15, "cream"),
           (80, 0.9, "red"), (-25, 0.95, "cream"), (25, 0.95, "cream"), (0, 1.0, "brown")]
    root = V(0, 0.45, 1.2)
    for i, (a, ln, col) in enumerate(fan):
        ar = math.radians(a)
        back = 0.35 if i < 11 else 0.2
        tip = root + V(math.sin(ar) * ln, back + 0.3 * math.cos(ar) * 0.5, math.cos(ar) * ln * 0.85)
        mid = (root + tip) / 2 + V(math.sin(ar) * 0.12, 0.3 + 0.1 * (i >= 11), 0.1)
        end = tip + V(math.sin(ar) * 0.12, 0.12, -0.18)
        w = 0.26 if i < 11 else 0.2
        feathers[col].append(sweep([root, mid, tip, end], np.array([[w * 0.5, 0.05], [w, 0.055], [w * 0.85, 0.045],
                                                                     [w * 0.3, 0.03]]), samples=8, sides=16))

    white_m, gold_m = (f"{N}_White", m_vinyl(white)), (f"{N}_GoldMat", m_gold())
    comps = [
        C(f"{N}_Body", body, white_m, voxel=0.008, tris=14000, err=0.02),
        C(f"{N}_Lower", lower, (f"{N}_Brown", m_vinyl(brown)), voxel=0.006, tris=6000),
        C(f"{N}_Thighs", thighs, (f"{N}_Brown", m_vinyl(brown)), voxel=0.006, tris=3000, islands=2),
        C(f"{N}_Comb", comb, (f"{N}_CombRed", m_gloss(red)), voxel=0.005, tris=6000),
        C(f"{N}_Beak", beak, (f"{N}_BeakGold", m_gloss("#E8A93C")), voxel=0.004, tris=2000),
        C(f"{N}_Wattle", wattle, (f"{N}_CombRed", m_gloss(red)), voxel=0.004, tris=1600),
        *eyes(N, body, [(-0.2, 2.24), (0.2, 2.24)], 0.09, 0.11, tilt=4, y0=-0.22, brows=(0.17, 0.06, 0.016, 14),
              brow_color="#4A2A22", iris=["#C98A52", "#8A4E26", "#4A2412", "#1E0F08"]),
        blush(N, body, [(-0.3, 2.06), (0.3, 2.06)], 0.08, 0.05, y0=-0.22),
        C(f"{N}_Wings", lambda p: wing_feathers(p), (f"{N}_Cream", m_vinyl(cream)), voxel=0.005, tris=10000, islands=None),
        C(f"{N}_WingTips", lambda p: wing_feathers(p, True), (f"{N}_Dark", m_vinyl(dark)), voxel=0.005, tris=3000,
          islands=None),
        C(f"{N}_Vest", vest, (f"{N}_VestRed", m_fabric(RED_DEEP)), voxel=0.006, tris=8000, islands=None),
        C(f"{N}_Medallion", lambda p: cylinder(p, med_c, 0.14, 0.03, r=0.01, R=frame(V(0.2, -1, 0))),
          (f"{N}_CombRed", m_gloss(red)), voxel=0.004, tris=1600),
        C(f"{N}_Gold", gold, gold_m, voxel=0.004, tris=8000, islands=None),
        C(f"{N}_Tassels", lambda p: np.minimum(tassel(p, med_c + V(-0.06, -0.02, -0.34), 0.22, 0.05),
                                               tassel(p, med_c + V(0.1, -0.02, -0.34), 0.22, 0.05)),
          (f"{N}_Coral", m_fabric("#F27B6B")), voxel=0.004, tris=3000, islands=2),
        C(f"{N}_Legs", legs, gold_m, voxel=0.004, tris=5000, islands=2),
        S(f"{N}_TailRed", feathers["red"], (f"{N}_FeatherRed", m_gloss(red)), tris=16000),
        S(f"{N}_TailCream", feathers["cream"], (f"{N}_FeatherCream", m_gloss("#F3D49A")), tris=14000),
        S(f"{N}_TailBrown", feathers["brown"], (f"{N}_FeatherBrown", m_gloss("#6A2E24")), tris=10000),
    ]
    return assemble(N, "Rooster", "Uncommon", comps, "moon.rooster")


def dog():
    N = "MoonDog"
    tan, white, navy, blue = "#E49A58", "#FFF6EC", "#2F3F7A", "#4B63A8"
    hc = V(0, -0.5, 1.98)

    def head(p):
        d = ellipsoid(p, hc, (0.68, 0.58, 0.56))
        d = smin(d, ellipsoid(p, (0, -1.0, 1.78), (0.3, 0.26, 0.22)), 0.16)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.46, -0.7, 1.76), (0.36, 0.32, 0.3)), 0.14)
            d = smin(d, spikes(p, [V(sx * 0.6, -0.58, 1.78)] * 3, [V(sx * 0.86, -0.56, 1.86), V(sx * 0.88, -0.56, 1.7),
                                                                   V(sx * 0.78, -0.58, 1.54)], 0.15, 0.03, 0.06), 0.08)
        return d

    def face_white(u, v):
        muzzle = ellipse2(u, v + 0.2, 0.6, 0.3)
        blaze = np.maximum(np.abs(u) - 0.07 - 0.1 * np.clip(-v + 0.2, 0, 1), v - 0.6)
        return np.minimum(muzzle, blaze)

    mask = decal(head, [(*front(head, 0, 1.92, -0.5), face_white)], 0.008, k=0.02, slab=0.7)

    ear_c = {sx: V(sx * 0.44, -0.36, 2.56) for sx in (-1, 1)}

    def ears(p):
        d = None
        for sx in (-1, 1):
            e = round_cone(p, ear_c[sx] - V(sx * 0.02, 0, 0.18), ear_c[sx] + V(sx * 0.12, 0.02, 0.28), 0.22, 0.04)
            e = smax(e, np.abs(p[1] - ear_c[sx][1] - 0.02 + 0.0 * p[0]) - 0.1, 0.03)
            e = smax(e, -ellipsoid(p, ear_c[sx] + V(sx * 0.03, -0.1, 0.02), (0.12, 0.06, 0.22), rot(0, sx * -16, 0)), 0.02)
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, ear_c[sx] + V(sx * 0.03, -0.06, 0.0), (0.11, 0.03, 0.2), rot(0, sx * -16, 0))
            d = e if d is None else np.minimum(d, e)
        return d

    legs = [(sx * 0.32, ly) for sx in (-1, 1) for ly in (-0.4, 0.62)]

    def body(p):
        d = ellipsoid(p, (0, 0.16, 0.78), (0.54, 0.78, 0.48))
        d = smin(d, ellipsoid(p, (0, -0.36, 0.98), (0.52, 0.46, 0.5)), 0.2)
        for x, y in legs:
            d = smin(d, round_cone(p, (x, y, 0.62), (x, y - 0.04, 0.16), 0.2, 0.17), 0.1)
        return smax(d, 0.1 - p[2], 0.02)

    def paws(p):
        d = None
        for x, y in legs:
            e = ellipsoid(p, (x, y - 0.1, 0.11), (0.2, 0.25, 0.13))
            d = e if d is None else np.minimum(d, e)
        return smax(d, -p[2], 0.01)

    chest = decal(body, [(*front(body, 0, 0.92, -0.3), blob(0.34, 0.42, dv=-0.05)),
                         (*anchor(body, (0, 0.2, 0.8), (1, 0.4, 0.1)), blob(0.08, 0.06)),
                         (*anchor(body, (0, 0.3, 0.8), (-1, 0.6, 0.2)), blob(0.07, 0.05))], 0.008, k=0.02, slab=0.3)

    def scarf(p):
        d = torus(p, (0, -0.42, 1.42), 0.5, 0.11, rot(-22, 0, 0))
        c = V(0, -0.96, 1.24)
        d = smin(d, ellipsoid(p, c, (0.48, 0.15, 0.24)), 0.1)
        d = smin(d, ellipsoid(p, (0.52, -0.82, 1.3), (0.12, 0.1, 0.12)), 0.06)  # knot on the side
        return d

    scarf_tails = [sweep([(0.56, -0.86, 1.28), (0.76, -0.92, 1.12), (0.86, -0.9, 0.9), (0.94, -0.84, 0.74)],
                         np.array([[0.12, 0.03], [0.14, 0.03], [0.12, 0.028], [0.08, 0.025]]), samples=8, sides=12),
                   sweep([(0.56, -0.84, 1.3), (0.8, -0.78, 1.36), (0.96, -0.68, 1.3)],
                         np.array([[0.1, 0.03], [0.12, 0.03], [0.07, 0.025]]), samples=8, sides=12)]

    pattern = decal(scarf, [(*front(scarf, sx * 0.24, 1.26, -0.9), lambda u, v: spiral2(u, v, 0.04, 1.6, 0.01))
                            for sx in (-1, 1)], 0.008, k=0.003, slab=0.12)

    med_c = V(0, -1.12, 1.18)

    def gold(p):
        d = coin(p, med_c, V(0, -1, 0.05), 0.15, 0.06)
        for sx in (-1, 1):
            d = np.minimum(d, sphere(p, med_c + V(sx * 0.1, -0.02, -0.24), 0.08))  # bells
            d = np.minimum(d, flower(p, V(sx * 0.4, -0.78, 1.42), V(sx * 0.5, -1, 0.3), 0.08, petals=5))
        return d

    paw_print = decal(lambda p: coin(p, med_c, V(0, -1, 0.05), 0.15, 0.06),
                      [(med_c + V(0, -0.03, 0), V(0, -1, 0.05), lambda u, v: np.minimum(
                          ellipse2(u, v + 0.02, 0.05, 0.04),
                          np.minimum.reduce([ellipse2(u - a, v - b, 0.018, 0.022) for a, b in
                                             ((-0.05, 0.04), (-0.018, 0.065), (0.018, 0.065), (0.05, 0.04))])))],
                      0.008, k=0.002, slab=0.05)

    tail_pts = [(0, 0.86, 0.95), (0.05, 1.08, 1.3), (0.02, 0.98, 1.58), (-0.1, 0.72, 1.6), (-0.12, 0.6, 1.42)]

    def tail_fluff(p):
        d = tube(p, tail_pts, [0.2, 0.26, 0.26, 0.22, 0.14], k=0.05)
        for i, q in enumerate(catmull_pts(tail_pts, 3)):
            d = smin(d, sphere(p, q + V(0.14 * math.sin(i * 2.1), 0.0, 0.14 * math.cos(i * 2.1)), 0.13), 0.05)
        return d

    tail_t = path_param(tail_pts)

    tan_m, white_m, gold_m = (f"{N}_Tan", m_vinyl(tan)), (f"{N}_White", m_vinyl(white)), (f"{N}_GoldMat", m_gold())
    comps = [
        C(f"{N}_Head", head, tan_m, voxel=0.008, tris=12000, err=0.02),
        C(f"{N}_Mask", mask, white_m, voxel=0.005, tris=6000, islands=None),
        C(f"{N}_Ears", ears, tan_m, voxel=0.006, tris=4000, islands=2),
        C(f"{N}_EarInner", ear_in, (f"{N}_EarPink", m_vinyl("#F2A6A0")), voxel=0.004, tris=2000, islands=2),
        *eyes(N, head, [(-0.27, 2.04), (0.27, 2.04)], 0.13, 0.15, tilt=2, y0=-0.5,
              iris=["#B9876A", "#7A4A30", "#3E2216", "#1A0D08"], brows=(0.25, 0.05, 0.04, 0), brow_color="#7A4A30"),
        C(f"{N}_Nose", lambda p: ellipsoid(p, front(head, 0, 1.86, -0.9)[0] + V(0, 0.02, 0), (0.11, 0.07, 0.075)),
          (f"{N}_NoseBlack", m_gloss("#1E1A1A")), voxel=0.004, tris=1600),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.66, -0.9), mouth_open(0.16, 0.13))], 0.012),
          (f"{N}_MouthMat", m_matte("#7E2E2C")), voxel=0.003, tris=1600),
        C(f"{N}_Tongue", decal(head, [(*front(head, 0, 1.66, -0.9), mouth_open(0.16, 0.13, tongue=True))], 0.016),
          (f"{N}_TongueMat", m_gloss("#F0857F")), voxel=0.003, tris=1000),
        blush(N, head, [(-0.44, 1.84), (0.44, 1.84)], 0.1, 0.06, y0=-0.5),
        C(f"{N}_Body", body, tan_m, voxel=0.008, tris=14000, err=0.02),
        C(f"{N}_Chest", chest, white_m, voxel=0.005, tris=5000, islands=None),
        C(f"{N}_Paws", paws, white_m, voxel=0.005, tris=5000, islands=4),
        C(f"{N}_Scarf", scarf, (f"{N}_Navy", m_fabric(navy)), voxel=0.006, tris=8000, err=0.016),
        S(f"{N}_ScarfTails", scarf_tails, (f"{N}_Navy", m_fabric(navy))),
        C(f"{N}_ScarfPattern", pattern, gold_m, voxel=0.003, tris=2000, islands=None),
        C(f"{N}_Gold", gold, gold_m, voxel=0.004, tris=8000, islands=None),
        C(f"{N}_PawPrint", paw_print, (f"{N}_GoldDeep", m_gold(GOLD_DEEP)), voxel=0.003, tris=1200, islands=None),
        C(f"{N}_Tassel", lambda p: tassel(p, med_c + V(0, -0.02, -0.34), 0.2, 0.045), (f"{N}_Blue", m_fabric(blue)),
          voxel=0.004, tris=2000),
        C(f"{N}_Tail", tail_fluff, (f"{N}_TailMix", m_vinyl([tan, tan, white, white])), voxel=0.006, tris=8000,
          ramp=tail_t, err=0.016),
    ]
    return assemble(N, "Dog", "Rare", comps, "moon.dog")


def catmull_pts(points, samples):
    from sdf import catmull
    return [V(q) for q in catmull([V(q) for q in points], samples)]


def pig():
    N = "MoonPig"
    pink, snout, red = "#F8C9BE", "#F4A3A0", "#D33A33"

    def body(p):
        d = ellipsoid(p, (0, 0.04, 0.95), (0.8, 0.72, 0.78))
        d = smin(d, ellipsoid(p, (0, -0.12, 1.95), (0.7, 0.6, 0.56)), 0.3)
        for sx in (-1, 1):
            d = smin(d, round_cone(p, (sx * 0.4, -0.1, 0.35), (sx * 0.42, -0.22, 0.08), 0.2, 0.15), 0.12)
        return smax(d, -p[2], 0.01)

    sn_c = front(body, 0, 1.92, -0.2)[0]

    def snout_fn(p):
        return smin(cylinder(p, sn_c + V(0, -0.06, 0), 0.24, 0.1, r=0.07, R=frame(V(0, -1, 0.05))),
                    ellipsoid(p, sn_c + V(0, 0.04, 0), (0.24, 0.1, 0.17)), 0.04)

    nostrils = decal(snout_fn, [(sn_c + V(sx * 0.08, -0.16, 0.0), V(0, -1, 0.05), blob(0.04, 0.07)) for sx in (-1, 1)],
                     0.006, k=0.003, slab=0.06)

    ear_R = {sx: rot(20, sx * -30, sx * 25) for sx in (-1, 1)}

    def ears(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, V(sx * 0.62, -0.18, 2.42), (0.3, 0.1, 0.22), ear_R[sx])
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, V(sx * 0.63, -0.26, 2.41), (0.22, 0.04, 0.15), ear_R[sx])
            d = e if d is None else np.minimum(d, e)
        return d

    arm = {sx: [(sx * 0.62, -0.3, 1.45), (sx * 0.6, -0.62, 1.32), (sx * 0.36, -0.84, 1.3)] for sx in (-1, 1)}

    def arms(p):
        d = None
        for sx in (-1, 1):
            e = tube(p, arm[sx], [0.19, 0.18, 0.16], k=0.05)
            d = e if d is None else np.minimum(d, e)
        return d

    def trotters(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, (sx * 0.34, -0.9, 1.3), (0.13, 0.12, 0.13))
            e2 = smax(ellipsoid(p, (sx * 0.42, -0.24, 0.08), (0.15, 0.18, 0.09)), -p[2], 0.01)
            d = np.minimum(e, e2) if d is None else np.minimum(d, np.minimum(e, e2))
        return d

    ingot_c = V(0, -1.02, 1.38)

    def ingot(p):
        x, y, z = local(p, ingot_c)
        boat = ellipsoid(p, ingot_c, (0.42, 0.24, 0.16))
        rim = ellipsoid(p, ingot_c + V(0, 0, 0.1), (0.36, 0.18, 0.12))
        boat = smax(boat, -rim, 0.03)
        for sx in (-1, 1):
            boat = smin(boat, ellipsoid(p, ingot_c + V(sx * 0.32, 0, 0.1), (0.14, 0.2, 0.1), rot(0, sx * 25, 0)), 0.06)
        dome = sphere(p, ingot_c + V(0, 0, 0.12), 0.17)
        return np.minimum(boat, dome)

    def rope(p):
        x, y, z = p
        theta = np.arctan2(x, -(y + 0.12))
        d = torus(p, (0, -0.12, 1.5), 0.7, 0.07, rot(-12, 0, 0))
        return d - 0.012 * np.abs(np.sin(theta * 34 + (z - 1.5) * 40))

    def gold(p):
        d = ingot(p)
        for sx in (-1, 1):
            d = np.minimum(d, coin(p, V(sx * 0.86, -0.08, 0.98), V(sx, -0.2, 0), 0.22, 0.06))
        crown_c = front(body, 0, 2.48, -0.12)[0]
        cr = ellipsoid(p, crown_c + V(0, 0.04, 0.02), (0.22, 0.08, 0.1), rot(-40, 0, 0))
        cr = smin(cr, ellipsoid(p, crown_c + V(0, 0.02, 0.1), (0.1, 0.06, 0.08)), 0.03)
        d = np.minimum(d, cr)
        for a in (-55, 0, 55):
            ar = math.radians(a)
            c = V(0, -0.12, 1.5) + rot(-12, 0, 0) @ V(0.7 * math.sin(ar), -0.7 * math.cos(ar), 0) + V(0, -0.08, 0)
            d = np.minimum(d, flower(p, c, c - V(0, -0.12, 1.4), 0.11, petals=5))
        for sx in (-1, 1):
            c, n = anchor(trotters, (sx * 0.34, -0.9, 1.3), (0, -1, 0.2))
            d = np.minimum(d, flower(p, c, n, 0.05, petals=3, spin=90, petal_w=0.8))
        return d

    coin_mark = decal(lambda p: np.minimum(*[coin(p, V(sx * 0.86, -0.08, 0.98), V(sx, -0.2, 0), 0.22, 0.06)
                                             for sx in (-1, 1)]),
                      [(V(sx * 0.9, -0.09, 0.98), V(sx, -0.2, 0), lambda u, v: np.minimum.reduce(
                          [ellipse2(u - a, v - b, 0.035, 0.05) for a, b in ((-0.07, 0.05), (0.06, 0.07), (0.0, -0.02),
                                                                           (-0.06, -0.09), (0.08, -0.06))]))
                       for sx in (-1, 1)], 0.008, k=0.002, slab=0.05)

    back_cloud = decal(body, [(*anchor(body, (0, 0.0, 1.1), (0, 1, 0.1)), lambda u, v: np.minimum(
        spiral2(u + 0.08, v, 0.035, 1.5, 0.016), spiral2(u - 0.08, v + 0.02, 0.035, 1.5, 0.016)))],
                       0.008, k=0.003, slab=0.2)

    tail_pts = [(0, 0.74, 0.95), (0.08, 0.86, 1.0), (0.12, 0.88, 1.12), (0.02, 0.86, 1.16), (0.0, 0.84, 1.06)]

    pink_m, gold_m = (f"{N}_Pink", m_vinyl(pink)), (f"{N}_GoldMat", m_gold())
    comps = [
        C(f"{N}_Body", body, pink_m, voxel=0.009, tris=16000, err=0.022),
        C(f"{N}_Snout", snout_fn, (f"{N}_SnoutPink", m_gloss(snout)), voxel=0.005, tris=4000),
        C(f"{N}_Nostrils", nostrils, (f"{N}_NostrilMat", m_matte("#C76A6E")), voxel=0.003, tris=1200, islands=2),
        *eyes(N, body, [(-0.33, 2.14), (0.33, 2.14)], 0.13, 0.12, closed=True, y0=-0.12),
        C(f"{N}_Mouth", decal(body, [(*front(body, 0, 1.68, -0.12), mouth_open(0.15, 0.12))], 0.01),
          (f"{N}_MouthMat", m_matte("#9A3B3C")), voxel=0.003, tris=1600),
        C(f"{N}_Tongue", decal(body, [(*front(body, 0, 1.68, -0.12), mouth_open(0.15, 0.12, tongue=True))], 0.014),
          (f"{N}_TongueMat", m_gloss("#F07D84")), voxel=0.003, tris=1000),
        blush(N, body, [(-0.46, 1.94), (0.46, 1.94)], 0.14, 0.09, y0=-0.12, color="#F59A9A"),
        C(f"{N}_Brows", decal(body, [(*front(body, sx * 0.36, 2.36, -0.12), lambda u, v: arc2(u, -v, 0.08, 50, 0.014))
                                     for sx in (-1, 1)], 0.008, k=0.003), (f"{N}_BrowMat", m_matte("#7A4A3A")),
          voxel=0.003, tris=800, islands=2),
        C(f"{N}_Ears", ears, pink_m, voxel=0.006, tris=4000, islands=2),
        C(f"{N}_EarInner", ear_in, (f"{N}_EarPink", m_vinyl("#F4A7A4")), voxel=0.004, tris=2000, islands=2),
        C(f"{N}_Arms", arms, pink_m, voxel=0.006, tris=5000, islands=2),
        C(f"{N}_Trotters", trotters, (f"{N}_Hoof", m_gloss("#5A3426")), voxel=0.005, tris=4000, islands=4),
        C(f"{N}_Rope", rope, (f"{N}_Red", m_fabric(red)), voxel=0.004, tris=10000, err=0.014),
        C(f"{N}_Gold", gold, gold_m, voxel=0.006, tris=16000, islands=None),
        C(f"{N}_CoinMarks", coin_mark, (f"{N}_Ink", m_matte("#2A1D18")), voxel=0.003, tris=2400, islands=None),
        C(f"{N}_BackEmblem", back_cloud, gold_m, voxel=0.003, tris=2000, islands=None),
        C(f"{N}_Tassels", lambda p: np.minimum(tassel(p, V(-0.86, -0.3, 1.5), 0.24, 0.05),
                                               tassel(p, V(0, -0.86, 1.06), 0.2, 0.045)),
          (f"{N}_Red", m_fabric(red)), voxel=0.004, tris=3000, islands=2),
        S(f"{N}_Tail", [tail(tail_pts, 0.05, 0.035, samples=8)], pink_m),
    ]
    return assemble(N, "Pig", "Rare", comps, "moon.pig")


def cat():
    N = "MoonCat"
    navy, cream, lav, blue, pink = "#2B2D4D", "#FCF2E6", "#9C93D3", "#4F68B5", "#F1A5A0"
    hc = V(0, -0.12, 1.94)

    def head(p):
        d = ellipsoid(p, hc, (0.66, 0.58, 0.55))
        d = smin(d, ellipsoid(p, (0, -0.56, 1.76), (0.24, 0.16, 0.16)), 0.12)
        for sx in (-1, 1):
            d = smin(d, spikes(p, [V(sx * 0.5, -0.3, 1.8)] * 3, [V(sx * 0.88, -0.3, 1.86), V(sx * 0.86, -0.28, 1.68),
                                                                  V(sx * 0.72, -0.3, 1.54)], 0.13, 0.02, 0.05), 0.06)
        return d

    def face_cream(u, v):
        lower = ellipse2(u, v + 0.18, 0.62, 0.34)
        bridge = np.maximum(np.abs(u) - 0.06 - 0.22 * np.clip(0.25 - v, 0, 1), v - 0.42)
        return np.minimum(lower, bridge)

    mask = decal(head, [(*front(head, 0, 1.86, -0.12), face_cream)], 0.008, k=0.02, slab=0.7)

    def gold_marks(u, v):
        d = np.minimum(ellipse2(u - 0.21, v - 0.47, 0.06, 0.045), ellipse2(u + 0.21, v - 0.47, 0.06, 0.045))
        d = np.minimum(d, seg2(u, v, (0, 0.5), (0, 0.38), 0.018))
        for sx in (-1, 1):
            for k, vv in enumerate((0.02, -0.08)):
                d = np.minimum(d, seg2(u, v, (sx * 0.5, vv), (sx * 0.7, vv + 0.04 - 0.05 * k), 0.012))
        return d

    marks = decal(head, [(*front(head, 0, 1.86, -0.12), gold_marks)], 0.014, k=0.003, slab=0.8)

    ear_c = {sx: V(sx * 0.42, -0.04, 2.48) for sx in (-1, 1)}

    def ears(p):
        d = None
        for sx in (-1, 1):
            e = round_cone(p, ear_c[sx] - V(sx * 0.04, 0, 0.12), ear_c[sx] + V(sx * 0.1, 0.02, 0.3), 0.22, 0.03)
            e = smax(e, np.abs(p[1] - ear_c[sx][1]) - 0.1, 0.03)
            e = smax(e, -ellipsoid(p, ear_c[sx] + V(sx * 0.02, -0.1, 0.04), (0.12, 0.06, 0.2), rot(0, sx * -14, 0)), 0.02)
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_in(p):
        d = None
        for sx in (-1, 1):
            e = ellipsoid(p, ear_c[sx] + V(sx * 0.02, -0.06, 0.02), (0.11, 0.03, 0.18), rot(0, sx * -14, 0))
            d = e if d is None else np.minimum(d, e)
        return d

    def ear_tufts(p):
        return spikes(p, [ear_c[sx] + V(-sx * 0.06, -0.08, -0.06) for sx in (-1, 1)],
                      [ear_c[sx] + V(sx * 0.05, -0.12, 0.14) for sx in (-1, 1)], 0.06, 0.012, 0.0)

    def body(p):
        d = ellipsoid(p, (0, 0.12, 0.78), (0.52, 0.5, 0.6))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, (sx * 0.36, 0.2, 0.36), (0.26, 0.4, 0.3)), 0.12)
            d = smin(d, round_cone(p, (sx * 0.2, -0.24, 0.8), (sx * 0.22, -0.36, 0.14), 0.13, 0.12), 0.08)
        return smax(d, 0.06 - p[2], 0.02)

    chest = decal(body, [(*front(body, 0, 0.86, 0), blob(0.3, 0.46))], 0.008, k=0.02, slab=0.3)

    def paws(p):
        d = None
        for x, y in ((-0.22, -0.42), (0.22, -0.42), (-0.4, -0.06), (0.4, -0.06)):
            e = ellipsoid(p, (x, y, 0.08), (0.14, 0.18, 0.09))
            d = e if d is None else np.minimum(d, e)
        return smax(d, -p[2], 0.01)

    cloak_args = dict(flare=0.55, flare_z=1.0, waves=7, wave=0.08, y_top=-0.36, y_bot=-0.28, folds=7, fold=0.05,
                      hem_front=0.25)
    cloak = Mantle((0, 0.2, 0.86), (0.74, 0.7, 0.68), layer=(0.0, 0.035), **cloak_args)
    lining = Mantle((0, 0.2, 0.86), (0.74, 0.7, 0.68), layer=(-0.03, 0.0), **cloak_args)

    stars = decal(cloak, [(*anchor(cloak.surface, V(0, 0.2, 0.6), d, 0.035), (lambda r: lambda u, v: star4(u, v, r, 0.32))(r))
                          for d, r in (((1, 0.3, 0.1), 0.07), ((-1, 0.4, -0.2), 0.06), ((0.4, 1, 0.3), 0.08),
                                       ((-0.5, 1, -0.3), 0.06), ((0.8, 0.7, -0.4), 0.05), ((-0.9, 0.2, 0.4), 0.05),
                                       ((0.1, 1, -0.5), 0.05))], 0.008, k=0.002, slab=0.08)

    ribbons = [
        sweep([(0.46, 0.0, 1.3), (0.9, -0.05, 1.22), (1.16, 0.12, 0.9), (1.02, 0.42, 0.55), (1.22, 0.36, 0.24)],
              np.array([[0.2, 0.022]] * 5), samples=10, sides=14),
        sweep([(-0.46, 0.0, 1.3), (-0.9, -0.08, 1.12), (-1.12, 0.05, 0.72), (-0.95, -0.18, 0.4), (-1.18, -0.22, 0.2)],
              np.array([[0.2, 0.022]] * 5), samples=10, sides=14),
    ]
    ribbons_lav = [
        sweep([(0.4, 0.4, 1.2), (0.85, 0.65, 1.0), (1.05, 0.7, 0.55), (0.85, 0.9, 0.3)],
              np.array([[0.11, 0.022]] * 4), samples=10, sides=14),
        sweep([(-0.4, 0.4, 1.2), (-0.85, 0.65, 0.95), (-1.0, 0.8, 0.6), (-0.8, 0.95, 0.35)],
              np.array([[0.11, 0.022]] * 4), samples=10, sides=14),
    ]

    bow_c = V(0, -0.5, 1.3)

    def bow(p):
        d = ellipsoid(p, bow_c, (0.12, 0.09, 0.1))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, bow_c + V(sx * 0.26, 0.04, 0.04), (0.26, 0.08, 0.13), rot(0, sx * -12, 0)), 0.04)
        d = smin(d, round_box(p, bow_c + V(0, -0.02, -0.3), (0.08, 0.025, 0.2), 0.02, rot(0, 0, 0)), 0.03)
        return d

    med_c = bow_c + V(0, -0.1, 0.0)

    crown_c = V(0.04, -0.02, 2.78)
    crown_R = frame(V(0, -1, 0.1))

    def crown(p):
        x, y, z = local(p, crown_c, crown_R)
        ring = torus((x, y, z), (0, 0, 0), 0.4, 0.055)
        inner = torus((x, y, z), (0, 0, 0), 0.31, 0.03)
        cut = sphere((x, y, z), (0.32, 0.42, 0), 0.36)  # crescent opening
        ring = smax(ring, -cut, 0.02)
        d = np.minimum(ring, smax(inner, -cut, 0.02))
        d = np.minimum(d, round_cone((x, y, z), (0.02, 0.4, 0), (0.12, 0.62, 0), 0.04, 0.015))  # top spire
        d = np.minimum(d, round_cone((x, y, z), (-0.36, 0.0, 0), (-0.5, -0.12, 0), 0.03, 0.01))
        d = np.minimum(d, round_cone(p, crown_c + V(0, 0.02, -0.38), crown_c + V(0, 0.0, -0.58), 0.035, 0.035))
        d = np.minimum(d, coin(p, med_c, V(0, -1, 0.1), 0.13, 0.05))
        for sx in (-1, 1):  # earring chains
            top = ear_c[sx] + V(sx * 0.16, -0.02, -0.12)
            d = np.minimum(d, round_cone(p, top, top + V(0, 0, -0.28), 0.014, 0.014))
        d = np.minimum(d, round_cone(p, V(0.86, 0.66, 2.0), V(0.9, 0.62, 1.82), 0.014, 0.014))  # tail charm chain
        return d

    def blue_parts(p):
        x, y, z = local(p, crown_c, crown_R)
        s = smax(star4(x, y, 0.2, 0.34), np.abs(z) - 0.04, 0.015)
        dome = smax(ellipsoid(p, V(0, -0.24, 2.42), (0.2, 0.14, 0.14)), V(0, 0, 0)[2] + 2.36 - p[2], 0.01)
        d = np.minimum(s, dome)
        for sx in (-1, 1):
            c = ear_c[sx] + V(sx * 0.16, -0.02, -0.48)
            xx, yy, zz = local(p, c, frame(V(0, -1, 0)))
            d = np.minimum(d, smax(star4(xx, yy, 0.09, 0.36), np.abs(zz) - 0.025, 0.01))
        xx, yy, zz = local(p, V(0.9, 0.62, 1.72), frame(V(0.3, -1, 0)))
        d = np.minimum(d, smax(star4(xx, yy, 0.12, 0.36), np.abs(zz) - 0.03, 0.01))
        return d

    medal_face = decal(lambda p: coin(p, med_c, V(0, -1, 0.1), 0.13, 0.05),
                       [(med_c + V(0, -0.03, 0), V(0, -1, 0.1), lambda u, v: star4(u, v, 0.09, 0.32))],
                       0.008, k=0.002, slab=0.05)

    tail_pts = [(0.3, 0.55, 0.5), (0.62, 0.78, 0.82), (0.78, 0.8, 1.32), (0.68, 0.72, 1.8), (0.48, 0.66, 2.06),
                (0.4, 0.62, 2.28), (0.56, 0.62, 2.36), (0.76, 0.62, 2.18)]

    navy_m, cream_m, gold_m = (f"{N}_Navy", m_vinyl(navy)), (f"{N}_Cream", m_vinyl(cream)), (f"{N}_GoldMat", m_gold())
    blue_m, lav_m = (f"{N}_Blue", m_gloss(blue)), (f"{N}_Lavender", m_fabric(lav))
    comps = [
        C(f"{N}_Head", head, navy_m, voxel=0.007, tris=14000, err=0.018),
        C(f"{N}_Mask", mask, cream_m, voxel=0.005, tris=6000, islands=None),
        C(f"{N}_Marks", marks, gold_m, voxel=0.003, tris=4000, islands=None),
        C(f"{N}_Ears", ears, navy_m, voxel=0.005, tris=4000, islands=2),
        C(f"{N}_EarInner", ear_in, (f"{N}_EarPink", m_vinyl(pink)), voxel=0.004, tris=2000, islands=2),
        C(f"{N}_EarTufts", ear_tufts, cream_m, voxel=0.004, tris=1600, islands=2),
        *eyes(N, head, [(-0.25, 1.92), (0.25, 1.92)], 0.15, 0.18, tilt=6, y0=-0.12, star_shine=True,
              iris=["#C8DAF6", "#7193D6", "#30498F", "#141E46"], rim="#151A33", pupil="#0E1230"),
        blush(N, head, [(-0.4, 1.74), (0.4, 1.74)], 0.1, 0.06, y0=-0.12),
        C(f"{N}_Nose", lambda p: ellipsoid(p, front(head, 0, 1.8, -0.4)[0] + V(0, 0.01, 0), (0.05, 0.03, 0.03)),
          (f"{N}_NosePink", m_gloss("#F2A0A0")), voxel=0.004, tris=600),
        C(f"{N}_Mouth", decal(head, [(*front(head, 0, 1.7, -0.4), mouth_w(0.045, 0.011, 0.06))], 0.008),
          (f"{N}_MouthInk", m_matte("#5A3438")), voxel=0.003, tris=1000),
        C(f"{N}_Body", body, navy_m, voxel=0.008, tris=12000, err=0.02),
        C(f"{N}_Chest", chest, cream_m, voxel=0.005, tris=4000),
        C(f"{N}_Paws", paws, cream_m, voxel=0.005, tris=3000, islands=4),
        C(f"{N}_Cloak", cloak, (f"{N}_CloakNavy", m_fabric("#262A4C")), voxel=0.006, tris=16000, err=0.016, islands=None),
        C(f"{N}_Lining", lining, lav_m, voxel=0.006, tris=12000, err=0.016, islands=None),
        C(f"{N}_CloakTrim", cloak.trim(0.07, 0.03), gold_m, voxel=0.006, tris=12000, islands=None),
        C(f"{N}_Stars", stars, gold_m, voxel=0.004, tris=4000, islands=None),
        S(f"{N}_Ribbons", ribbons, (f"{N}_RibbonCream", m_gloss("#F7EBD6")), tris=6000),
        S(f"{N}_RibbonsLav", ribbons_lav, lav_m, tris=6000),
        C(f"{N}_Bow", bow, blue_m, voxel=0.005, tris=5000),
        C(f"{N}_Gold", crown, gold_m, voxel=0.005, tris=14000, islands=None),
        C(f"{N}_BlueGems", blue_parts, blue_m, voxel=0.005, tris=5000, islands=None),
        C(f"{N}_MedalFace", medal_face, (f"{N}_Ivory", m_gloss("#F6F0E4")), voxel=0.003, tris=1000),
        C(f"{N}_Tassel", lambda p: tassel(p, bow_c + V(0, -0.04, -0.52), 0.2, 0.045), gold_m, voxel=0.004, tris=2000),
        S(f"{N}_Tail", [tail(tail_pts, 0.17, 0.08, power=0.9, samples=10, sides=20)],
          (f"{N}_TailGrad", m_gloss(["#FCF2E6", "#E6DDF3", "#B3A8E2", "#8C83CC"])), ramp=path_param(tail_pts)),
    ]
    return assemble(N, "Cat", "Mythical", comps, "moon.cat", tri_scale=0.65)


def cat_tripo():
    """The Cat from a Tripo image-to-3D model of the approved sheet (see cat/source/prep_tripo.py).

    One textured body part decimated to the part limit, plus a hidden marker inside the head that
    gives the runtime its facing (`_Eyes`); the marker sits on the bounding-box centreline.
    """
    import json
    N = "MoonCat"
    src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cat", "source")
    eye = json.load(open(os.path.join(src, "cat_tripo.json")))["eye"]

    def body():
        import bpy
        bpy.ops.import_scene.gltf(filepath=os.path.join(src, "cat_tripo.glb"))
        return bpy.context.selected_objects[0]

    tex = ("MoonCat_Texture", Mat("#FFFFFF", rough=0.6, color_map=os.path.join(src, "cat_tripo_basecolor.png")))
    comps = [
        C(f"{N}_Body", None, tex, mesh=body, tris=19000),
        C(f"{N}_Eyes", lambda p: sphere(p, V(eye), 0.08), ("MoonCat_Marker", m_matte(INK)), voxel=0.01),
    ]
    return assemble(N, "Cat", "Mythical", comps, "moon.cat", tri_scale=1.0)


FIGURES = {
    "rat": rat,
    "ox": ox,
    "tiger": tiger,
    "rabbit": rabbit,
    "dragon": dragon,
    "snake": snake,
    "horse": horse,
    "goat": goat,
    "monkey": monkey,
    "rooster": rooster,
    "dog": dog,
    "pig": pig,
    "cat": cat_tripo,
}
