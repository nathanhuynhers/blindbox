"""Tender Echoes figure definitions, reconstructed from the approved character sheets.

Units are studs. +Z is up, every figure faces -Y, the character's left is +X,
and the lowest point of each figure rests on Z = 0 after grounding.

Unlike the earlier mascot collections these are chibi children: an oversized head with a
porcelain face, heavy-lidded eyes glancing toward the viewer's right, sculpted hair locks and a
handmade costume. The shared kit below (head, face, hair, limbs, shoes, knit and patch helpers)
is measured from the standing sheets: about 3.3 studs tall, eyes at Z 1.95, chin at Z 1.55.
`Mat`, `Comp`, `Leaf`, `surface_point` and `assemble` are copied from the Pocket Grove definitions.
"""

import math

import numpy as np

from sdf import (
    arc2, catmull, cylinder, ellipse2, ellipsoid, frame, local, overlay, rot,
    round_box, round_cone, smax, smin, sphere, torus, tube,
)


class Mat:
    def __init__(self, color, rough=0.5, metal=0.0, alpha=1.0, **render):
        self.color = color  # hex string, or list of hex strings for a ramp
        self.rough = rough
        self.metal = metal
        self.alpha = alpha
        self.render = render  # render-only garnish: coat, thin_film, transmission, subsurface


class Comp:
    def __init__(self, name, fn, mat, voxel=0.012, tris=6000, ramp=None, min_faces=24):
        self.name = name
        self.fn = fn
        self.mat = mat
        self.voxel = voxel
        self.tris = tris
        self.ramp = ramp  # fn(x, y, z) -> t in [0, 1] for ramp materials
        self.min_faces = min_faces


# The sheets' soft pastels wash toward white under AgX, as Pocket Grove's did; renders only.
RENDER_VIEW = "Khronos PBR Neutral|None|-1.1"

SKIN = "#F6DCCB"


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
    idx = int(np.argmax(v[1:] >= 0.0)) + 1  # an ellipsoid centre evaluates to exactly 0
    lo, hi = ts[max(idx - 1, 0)], ts[idx]
    for _ in range(30):
        mid = 0.5 * (lo + hi)
        if fn(P((o + mid * d)[None, :]))[0] < 0:
            lo = mid
        else:
            hi = mid
    return o + 0.5 * (lo + hi) * d


def normal_at(fn, q, e=1e-3):
    q = np.asarray(q, float)
    g = []
    for i in range(3):
        a, b = q.copy(), q.copy()
        a[i] += e
        b[i] -= e
        g.append(fn(P(a[None, :]))[0] - fn(P(b[None, :]))[0])
    return unit(g)


def sph_dir(az_deg, el_deg):
    """Direction by azimuth (0 = front/-Y, 90 = character's left/+X) and elevation."""
    a, e = math.radians(az_deg), math.radians(el_deg)
    return np.array([math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)])


def seg2(u, v, a, b, th):
    """2D capsule from a to b with half-thickness th."""
    bx, by = b[0] - a[0], b[1] - a[1]
    px, py = u - a[0], v - a[1]
    h = np.clip((px * bx + py * by) / (bx * bx + by * by), 0.0, 1.0)
    return np.sqrt((px - bx * h) ** 2 + (py - by * h) ** 2) - th


def rect2(u, v, hw, hh, r):
    qx, qy = np.abs(u) - hw + r, np.abs(v) - hh + r
    return np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0) - r


def cross2(u, v, s, th):
    """An X stitch of half-size s."""
    return np.minimum(seg2(u, v, (-s, -s), (s, s), th), seg2(u, v, (-s, s), (s, -s), th))


def star2(u, v, r, rf=0.45):
    """Five-point star pointing up (+v) with outer radius r (Inigo Quilez's sdStar5)."""
    k1x, k1y = 0.809016994375, -0.587785252292
    px, py = np.abs(u), v.copy() if hasattr(v, "copy") else v
    for kx, ky in ((k1x, k1y), (-k1x, k1y)):
        dot = np.maximum(kx * px + ky * py, 0.0)
        px, py = px - 2 * dot * kx, py - 2 * dot * ky
    px = np.abs(px)
    py = py - r
    bax, bay = rf * -k1y - 0.0, rf * k1x - 1.0
    h = np.clip((px * bax + py * bay) / (bax * bax + bay * bay), 0.0, r)
    return np.sqrt((px - bax * h) ** 2 + (py - bay * h) ** 2) * np.sign(py * bax - px * bay)


def bands(t, period, duty=0.5):
    """Signed distance to repeating stripes along t (negative inside a stripe)."""
    f = t / period - np.floor(t / period)
    return (np.abs(f - 0.5) - 0.5 * duty) * period


def splotch(u, v, r, seed):
    """Irregular paint blob of rough radius r."""
    rng = np.random.default_rng(seed)
    a = np.arctan2(v, u)
    wob = sum(rng.uniform(0.05, 0.16) * np.cos(k * a + rng.uniform(0, 6.3)) for k in (2, 3, 5))
    return np.sqrt(u * u + v * v) - r * (1 + wob)


def union_all(ds, k=0.0):
    d = None
    for v in ds:
        d = v if d is None else (smin(d, v, k) if k else np.minimum(d, v))
    return d


def flat_base(d, p, z=0.0):
    """Flat sole at Z = z so the figure stands squarely on its surface."""
    return smax(d, z - p[2], 0.012)


def fold(f):
    """Mirror a function of p across X = 0 (symmetric pairs as one field)."""
    return lambda p: f((np.abs(p[0]), p[1], p[2]))


def tilt_frame(n):
    """Rotation taking +Z to `n` by the shortest arc, so local X stays near world X."""
    n = unit(n)
    z = np.array([0.0, 0.0, 1.0])
    axis = np.cross(z, n)
    s_, c_ = np.linalg.norm(axis), float(np.dot(z, n))
    if s_ < 1e-9:
        return np.eye(3)
    k = axis / s_
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + s_ * K + (1 - c_) * (K @ K)


class Tangent:
    """A local frame on a surface: u across, v up, w along the outward normal."""

    def __init__(self, base, origin, direction, spin=0.0):
        self.c = surface_point(base, origin, direction)
        n = normal_at(base, self.c)
        self.R = frame(n) @ rot(0, 0, spin)

    def uvw(self, p, lift=0.0):
        return local(p, self.c + self.R[:, 2] * lift, self.R)

    def region(self, p, shape, reach=0.3):
        u, v, w = self.uvw(p)
        return np.maximum(shape(u, v), np.abs(w) - reach)

    def point(self, u, v, w=0.0):
        return self.c + self.R @ np.array([u, v, w])


def waves(p, freq, seed, n=7):
    """Cheap smooth pseudo-noise in about [-1, 1] from random plane waves."""
    rng = np.random.default_rng(seed)
    acc = 0.0
    for _ in range(n):
        d = unit(rng.normal(size=3))
        f = freq * (0.7 + 0.6 * rng.random())
        acc = acc + np.sin((p[0] * d[0] + p[1] * d[1] + p[2] * d[2]) * f + rng.random() * 6.283)
    return acc / math.sqrt(n * 0.5)


def knit(p, c, cols, rows, amp, el0=-1.2):
    """Chunky stockinette: columns of V-shaped stitch pairs wrapped round a centre.

    Returns a displacement (positive = outward) to subtract from a distance field.
    Columns follow the azimuth around Z; stitch rows follow elevation from `el0`.
    """
    x, y, z = p[0] - c[0], p[1] - c[1], p[2] - c[2]
    r = np.sqrt(x * x + y * y + z * z) + 1e-9
    az = np.arctan2(x, -y)
    el = np.arcsin(np.clip(z / r, -1, 1))
    u = az / (2 * math.pi) * cols
    fu = u - np.floor(u) - 0.5
    h = np.abs(fu) * 2.0  # 0 at the column's centre seam, 1 between columns
    v = (el - el0) / (math.pi / 2) * rows + 0.55 * h
    fv = v - np.floor(v) - 0.5
    across = np.clip(1.0 - ((h - 0.5) / 0.5) ** 2, 0.0, 1.0)
    along = np.clip(1.0 - (2.0 * fv) ** 2, 0.0, 1.0)
    pole = np.clip((1.45 - el) / 0.35, 0.0, 1.0)  # stitches shrink away near the crown
    return amp * np.sqrt(across * along) * pole


def rib(p, c, count, amp):
    """Vertical ribbing round a centre axis (cuffs, socks, brims)."""
    az = np.arctan2(p[0] - c[0], -(p[1] - c[1]))
    return amp * np.abs(np.cos(az * count * 0.5)) ** 0.6


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


# ------------------------------------------------------------------ kit: head and face

class Head:
    """Porcelain chibi head: broad round skull, full low cheeks, small chin, neck stub."""

    def __init__(self, c=(0.0, -0.07, 2.1), r=(0.62, 0.62, 0.6), ears=True):
        self.c = np.asarray(c, float)
        self.r = r
        self.ears = ears

    def __call__(self, p):
        c, (rx, ry, rz) = self.c, self.r
        d = ellipsoid(p, c, (rx, ry, rz))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, c + (sx * 0.3 * rx / 0.62, -0.27, -0.27), (0.28, 0.3, 0.26)), 0.14)
            if self.ears:
                d = smin(d, ellipsoid(p, c + (sx * rx * 0.97, 0.04, -0.12), (0.08, 0.12, 0.15)), 0.04)
        d = smin(d, ellipsoid(p, c + (0, -0.24, -0.4), (0.3, 0.3, 0.2)), 0.12)
        d = smin(d, round_cone(p, c + (0, 0.06, -0.42), c + (0, 0.06, -0.8), 0.17, 0.18), 0.08)
        return d


def face_mats(N, iris=("#1F1A12", "#2A2619", "#4A4A31", "#5C5C3D", "#2C2A1D"), brow="#C9A587"):
    return {
        "white": (f"{N}_EyeWhite", Mat("#F1E8DD", rough=0.35)),
        "iris": (f"{N}_Iris", Mat(list(iris), rough=0.15, coat=0.7)),
        "shine": (f"{N}_EyeShine", Mat("#FFFFFF", rough=0.25)),
        "lash": (f"{N}_Lash", Mat("#3A2A22", rough=0.5)),
        "brow": (f"{N}_Brow", Mat(brow, rough=0.6)),
        "nose": (f"{N}_Nose", Mat("#F0A493", rough=0.45, coat=0.2)),
        "mouth": (f"{N}_Mouth", Mat("#B66F62", rough=0.45)),
        "cheeks": (f"{N}_Blush", Mat("#F6CBBA", rough=0.6)),
    }


def kid_face(N, base, mats, z=1.95, dx=0.29, ru=0.15, rv=0.17, look=0.3, lid=0.62, droop=0.0,
             brows=(0.19, 0.07, 0.026, 10.0), nose_z=1.81, mouth_z=1.72, mouth_w=0.04,
             cheeks=(0.4, 1.75, (0.12, 0.075)), cx=0.0, ylim=-0.25, closed=False):
    """Heavy-lidded eyes glancing toward +X, small brows, nose nub, pout and blush.

    Every feature is a thin skin conforming to `base`. `look` shifts the iris toward the
    character's left (viewer's right) as a fraction of the eye width; `lid` is how far above the
    eye centre the upper lid line sits (fraction of rv); `droop` lowers its outer corner.
    `brows` = (height above eye centre, half-length, half-height, worried tilt) or None.
    `closed` draws sleeping eyes: a downward lash arc only.
    """
    def eye_uv(p, sx):
        return p[0] - (cx + sx * dx), p[2] - z

    def lid_v(u, sx):
        t = u * sx / ru
        return rv * (lid - droop * t - 0.22 * t * t)

    def dome(p):
        out = np.zeros_like(p[0])
        for sx in (-1.0, 1.0):
            u, v = eye_uv(p, sx)
            q = (u / ru) ** 2 + (v / rv) ** 2
            out = np.maximum(out, 0.03 * np.clip(1.0 - q, 0.0, 1.0))
        return out

    def eye_region(p, grow=1.0):
        regs = []
        for sx in (-1.0, 1.0):
            u, v = eye_uv(p, sx)
            regs.append(np.maximum(ellipse2(u, v, ru * grow, rv * grow), v - lid_v(u, sx)))
        return np.maximum(np.minimum(*regs), p[1] - ylim)

    iu, iv = look * ru, -0.06 * rv
    ri = (0.84 * ru, 0.84 * rv)

    def iris_region(p):
        regs = []
        for sx in (-1.0, 1.0):
            u, v = eye_uv(p, sx)
            regs.append(ellipse2(u - iu, v - iv, *ri))
        return np.maximum(np.minimum(*regs), eye_region(p))

    def skin(p, region, out, depth=0.05, k=0.003):
        return overlay(base(p), region, out + dome(p), depth=depth, k=k)

    comps = []
    if not closed:
        # The symmetric eye whites are the runtime facing part (`_Eyes`); the irises glance sideways.
        comps.append(Comp(f"{N}_Eyes", lambda p: skin(p, eye_region(p), 0.008), mats["white"],
                          voxel=0.004, tris=1600))

        def iris(p):
            return skin(p, iris_region(p), 0.014)

        def iris_t(x, y, zz):
            t = None
            for sx in (-1.0, 1.0):
                u, v = x - (cx + sx * dx) - iu, zz - z - iv
                e = np.sqrt((u / ri[0]) ** 2 + (v / ri[1]) ** 2)
                t = e if t is None else np.minimum(t, e)
            return np.clip(t, 0, 1)

        comps.append(Comp(f"{N}_Iris", iris, mats["iris"], voxel=0.004, tris=2400, ramp=iris_t))

        def shine(p):
            regs = []
            for sx in (-1.0, 1.0):
                u, v = eye_uv(p, sx)
                regs.append(ellipse2(u - iu + 0.42 * ri[0], v - iv - 0.18 * rv, 0.2 * ri[0], 0.2 * rv))
                regs.append(ellipse2(u - iu - 0.38 * ri[0], v - iv + 0.42 * rv, 0.08 * ri[0], 0.08 * rv))
            region = np.maximum(np.minimum.reduce(regs), eye_region(p))
            return skin(p, region, 0.019, k=0.002)

        comps.append(Comp(f"{N}_EyeShine", shine, mats["shine"], voxel=0.0035, tris=600))

        def lash(p):
            regs = []
            for sx in (-1.0, 1.0):
                u, v = eye_uv(p, sx)
                top = np.minimum(lid_v(u, sx), rv * np.sqrt(np.clip(1 - (u / ru) ** 2, 0, 1)))
                th = 0.009 + 0.008 * np.clip(u * sx / ru, 0, 1)  # thicker toward the outer corner
                band = np.maximum(np.abs(v - top - 0.004) - th, np.abs(u) - ru * 0.98)
                ou = sx * ru * 0.9
                tip = (ou, min(lid_v(ou, sx), rv * math.sqrt(1 - 0.81)))
                flick = seg2(u, v, tip, (sx * ru * 1.12, tip[1] + 0.02), 0.01)
                regs.append(np.minimum(band, flick))
            return skin(p, np.maximum(np.minimum(*regs), p[1] - ylim), 0.02, k=0.002)

        comps.append(Comp(f"{N}_Lash", lash, mats["lash"], voxel=0.0035, tris=900))
    else:
        def lids(p):
            regs = []
            for sx in (-1.0, 1.0):
                u, v = eye_uv(p, sx)
                R = ru / math.sin(math.radians(60))
                arc = arc2(u, v - R * 0.62, R, 60.0, 0.014)
                tip = (sx * ru, R * 0.62 - R * math.cos(math.radians(60)))
                regs.append(np.minimum(arc, seg2(u, v, tip, (sx * (ru + 0.04), tip[1] + 0.01), 0.01)))
            return overlay(base(p), np.maximum(np.minimum(*regs), p[1] - ylim), 0.012, depth=0.05, k=0.003)

        comps.append(Comp(f"{N}_Eyes", lids, mats["lash"], voxel=0.0035, tris=1200))

    if brows:
        bz, bl, bh, tilt = brows

        def brow(p):
            regs = []
            for sx in (-1.0, 1.0):
                u, v = p[0] - (cx + sx * (dx - 0.02)), p[2] - (z + bz)
                a = math.radians(-sx * tilt)
                uu, vv = u * math.cos(a) + v * math.sin(a), -u * math.sin(a) + v * math.cos(a)
                regs.append(ellipse2(uu, vv, bl, bh))
            return overlay(base(p), np.maximum(np.minimum(*regs), p[1] - ylim), 0.008, depth=0.04, k=0.004)

        comps.append(Comp(f"{N}_Brow", brow, mats["brow"], voxel=0.004, tris=700))

    nose_c = surface_point(base, (cx, -0.1, nose_z), (0, -1, 0)) + np.array([0, 0.012, 0])

    def nose(p):
        return ellipsoid(p, nose_c, (0.048, 0.032, 0.036))

    comps.append(Comp(f"{N}_Nose", nose, mats["nose"], voxel=0.004, tris=500))

    def mouth(p):
        R = mouth_w / math.sin(math.radians(48))
        u, v = p[0] - cx, p[2] - (mouth_z - R)
        region = np.maximum(arc2(u, -v, R, 48.0, 0.011), p[1] - ylim)
        return overlay(base(p), region, 0.008, depth=0.04, k=0.002)

    comps.append(Comp(f"{N}_Mouth", mouth, mats["mouth"], voxel=0.0035, tris=400))

    cdx, cz, cr = cheeks

    def blush(p):
        regs = [ellipse2(p[0] - (cx + sx * cdx), p[2] - cz, cr[0], cr[1]) for sx in (-1.0, 1.0)]
        return overlay(base(p), np.maximum(np.minimum(*regs), p[1] - ylim), 0.005, depth=0.04, k=0.012)

    comps.append(Comp(f"{N}_Blush", blush, mats["cheeks"], voxel=0.005, tris=900))
    return comps


# ------------------------------------------------------------------ kit: hair

class Hair:
    """Sculpted vinyl hair: an ellipsoid cap cut by a lock-tipped hem, with grooved locks.

    `hem` maps |azimuth| in degrees (0 = front, 180 = back) to the hem height at a lock seam;
    each lock hangs `tip` lower at its centre. `swing` rotates the lock pattern (side parting),
    `skew` shifts the hem with the signed azimuth for asymmetric bangs.
    """

    def __init__(self, c, r, hem, locks=16, tip=0.09, groove=0.028, puff=0.02, swing=0.0, skew=None, k=0.05,
                 opening=None):
        self.opening = opening  # (centre z, half-width, half-height, y limit): face cut-out in front
        self.c = np.asarray(c, float)
        self.r = r
        self.az_pts, self.z_pts = zip(*hem)
        self.locks, self.tip, self.groove, self.puff = locks, tip, groove, puff
        self.swing, self.skew, self.k = swing, skew, k

    def lock_phase(self, p):
        x, y = p[0] - self.c[0], p[1] - self.c[1]
        az = np.degrees(np.arctan2(x, -y))
        f = (az + self.swing) / 360.0 * self.locks
        f = f - np.floor(f)
        return az, f

    def __call__(self, p):
        c = self.c
        az, f = self.lock_phase(p)
        tri = 1.0 - np.abs(2.0 * f - 1.0)  # 0 at seams, 1 at lock centres
        hem = np.interp(np.abs(az), self.az_pts, self.z_pts)
        if self.skew is not None:
            hem = hem + np.interp(az, *self.skew)
        hem = hem - self.tip * tri ** 0.8
        d = ellipsoid(p, c, self.r)
        drop = np.clip((c[2] + self.r[2] * 0.55 - p[2]) / (self.r[2] * 0.9), 0.0, 1.0)
        seam = np.minimum(f, 1.0 - f)
        strands = 0.01 * np.abs(np.sin(f * math.pi * 4.0)) ** 0.5
        d = d + self.groove * np.exp(-(seam / 0.06) ** 2) * drop - self.puff * tri * drop + strands * drop
        d = smax(d, hem - p[2], self.k)
        if self.opening:
            oz, ow, oh, oy = self.opening
            d = smax(d, -np.maximum(ellipse2(p[0], p[2] - oz, ow, oh), p[1] - oy), 0.05)
        return d


def fringe(c, r, specs, thick=0.06, lift=0.055, bend=0.03, crease=0.022):
    """Individual bang locks laid over an ellipsoid hair shell.

    Each spec is (azimuth deg, root z, tip z, width[, swing deg]): the lock runs over the shell
    surface from the root to the tip, swinging `swing` degrees in azimuth on the way down.
    """
    c = np.asarray(c, float)

    def on_shell(az, z, extra):
        zz = np.clip((z - c[2]) / r[2], -0.98, 0.98)
        k = math.sqrt(1 - zz * zz)
        a = math.radians(az)
        return c + np.array([math.sin(a) * r[0] * k * (1 + extra), -math.cos(a) * r[1] * k * (1 + extra), zz * r[2]])

    leaves = []
    for spec in specs:
        az, z0, z1, w = spec[:4]
        swing = spec[4] if len(spec) > 4 else 0.0
        base = on_shell(az, z0, lift / max(r))
        tip = on_shell(az + swing, z1, (lift + 0.02) / max(r))
        nrm = unit(0.5 * (base + tip) - c)
        leaves.append(Leaf(base, tip, w, thick, nrm, mid=0.35, r_base=w * 0.7, r_tip=w * 0.2,
                           bend=bend, crease=crease))
    return lambda p: union_all([lf(p) for lf in leaves], 0.02)


def lock_mop(c, r, rows, seed=0, width=0.17, thick=0.06, length=0.42, flare=0.1, swing=18.0,
             skip=None, bend=0.06, round_tip=0.18):
    """Messy sculpted hair: broad pillowy locks seeded over an ellipsoid scalp.

    rows: [(elevation deg, count, azimuth phase deg)], each lock rooted on the scalp and hanging
    toward lower elevation, flaring `flare` outward with a random swing. `skip(az, el)` returns
    True for roots to omit (keeps the face clear). Returns a list of Leaf locks.
    """
    rng = np.random.default_rng(seed)
    c = np.asarray(c, float)

    def at(az, el, grow):
        d = sph_dir(az, el)
        return c + d * np.array(r) * (1 + grow)

    leaves = []
    for el, count, phase in rows:
        for i in range(count):
            az = phase + i * 360.0 / count + rng.uniform(-6, 6)
            az = (az + 180.0) % 360.0 - 180.0
            if skip and skip(az, el):
                continue
            L = length * rng.uniform(0.85, 1.15)
            drop = math.degrees(L / max(r))
            sw = rng.uniform(-swing, swing)
            base = at(az, el, 0.0)
            tip = at(az + sw, el - drop, flare / max(r) * rng.uniform(0.6, 1.3))
            nrm = unit(0.5 * (base + tip) - c)
            w = width * rng.uniform(0.85, 1.15)
            leaves.append(Leaf(base, tip, w, thick, nrm, mid=0.3, r_base=w * 0.75, r_tip=w * round_tip,
                               bend=bend * rng.uniform(0.5, 1.5), crease=0.02))
    return leaves


def curl(p, root, tip, r0, r1, bend=(0, 0, 0)):
    """A tapered hair curl from root to tip bowing through `bend`."""
    root, tip = np.asarray(root, float), np.asarray(tip, float)
    mid = 0.5 * (root + tip) + np.asarray(bend, float)
    return tube(p, [root, mid, tip], [r0, 0.5 * (r0 + r1) + 0.01, r1], k=0.02, samples=5)


# ------------------------------------------------------------------ kit: limbs, shoes, socks

def mitten(p, c, down, r=(0.1, 0.08, 0.12), thumb=(0.0, -1.0, 0.0)):
    """Chubby closed hand along `down`, with a thumb toward `thumb`."""
    c = np.asarray(c, float)
    R = frame(down, up_hint=thumb)
    d = ellipsoid(p, c, r, R)
    t = c + 0.6 * r[0] * unit(thumb) - 0.25 * r[2] * unit(down)
    return smin(d, ellipsoid(p, t, (0.045, 0.045, 0.06), R), 0.03)


def shoe(p, c, length=0.5, width=0.4, height=0.3, yaw=0.0, R=None):
    """Rounded clog with a bulbous toe; `c` is the heel-centre on the sole plane.

    `R` (rotation) overrides `yaw`, e.g. to tip a seated figure's shoe back onto its heel.
    """
    x, y, z = local(p, c, rot(0, 0, yaw) if R is None else R)
    q = (x, y, z)
    toe = ellipsoid(q, (0, -length * 0.22, height * 0.42), (width / 2, length * 0.32, height * 0.48))
    heel = ellipsoid(q, (0, length * 0.15, height * 0.48), (width * 0.46, length * 0.3, height * 0.55))
    d = smin(toe, heel, 0.12)
    return smax(d, -z, 0.02)


def sole(p, c, shoe_fn, h=0.055):
    """Darker outsole band at the bottom of a shoe."""
    return overlay(shoe_fn(p), p[2] - (c[2] + h), 0.012, depth=0.04, k=0.006)


def sock(p, c, r=0.15, h=0.1, ribs=14):
    """Slouchy ribbed sock cuff around the ankle."""
    d = cylinder(p, c, r, h, 0.07)
    d = smin(d, torus(p, (c[0], c[1], c[2] + h * 0.55), r * 0.9, 0.06), 0.04)
    return d - rib(p, c, ribs, 0.012)


def arm_parts(pts, sleeve_r, hand_c, down, thumb=(0, -1, 0), hand_r=(0.1, 0.08, 0.12), wrist=0.07):
    """A sleeved arm through `pts` (shoulder ... wrist) and a mitten hand; returns (sleeve, hand)."""
    pts = [np.asarray(q, float) for q in pts]
    hand_c = np.asarray(hand_c, float)

    def sleeve(p):
        return tube(p, pts, sleeve_r, k=0.03)

    def hand(p):
        d = mitten(p, hand_c, down, hand_r, thumb)
        return smin(d, round_cone(p, pts[-1], hand_c, wrist, wrist), 0.03)

    return sleeve, hand


def coil(p, path, ring=0.038, wire=0.022, pitch=0.05, samples=8):
    """Coiled telephone cord: torus rings stacked along a Catmull-Rom path."""
    pts = catmull(path, samples)
    lengths = np.cumsum([0.0] + [np.linalg.norm(b - a) for a, b in zip(pts[:-1], pts[1:])])
    d = None
    for s_ in np.arange(0.0, lengths[-1], pitch):
        i = min(max(int(np.searchsorted(lengths, s_)), 1), len(pts) - 1)
        a, b = pts[i - 1], pts[i]
        c = a + (b - a) * ((s_ - lengths[i - 1]) / max(lengths[i] - lengths[i - 1], 1e-9))
        e = torus(p, c, ring, wire, frame(b - a))
        d = e if d is None else np.minimum(d, e)
    return d


class SeatedLegs:
    """Legs stretched forward from a seated figure, shoes tipped back on their heels.

    hip, knee and heel are given for the character's left leg (+X) and mirrored.
    `pitch` tips the shoe toe-up (degrees), `splay` turns the toes outward.
    """

    def __init__(self, hip=(0.22, 0.05, 0.3), knee=(0.36, -0.5, 0.36), ankle=(0.44, -0.86, 0.3),
                 heel=(0.46, -0.9, 0.04), pitch=-62.0, splay=12.0, size=(0.5, 0.4, 0.3)):
        self.hip, self.knee, self.ankle = (np.asarray(v, float) for v in (hip, knee, ankle))
        self.heel = np.asarray(heel, float)
        self.R = rot(pitch, 0, splay)
        self.size = size

    def m(self, p):
        return (np.abs(p[0]), p[1], p[2])

    def thigh(self, p, r=(0.18, 0.16)):
        return round_cone(self.m(p), self.hip, self.knee, r[0], r[1])

    def shin(self, p, r=(0.12, 0.11)):
        return round_cone(self.m(p), self.knee, self.ankle, r[0], r[1])

    def shoe(self, p):
        L, W, H = self.size
        return shoe(self.m(p), self.heel, L, W, H, R=self.R)

    def sole(self, p):
        x, y, z = local(self.m(p), self.heel, self.R)
        return overlay(self.shoe(p), z - 0.055, 0.012, depth=0.04, k=0.006)

    def sock(self, p, r=0.14, h=0.12):
        c = self.ankle + 0.35 * (self.knee - self.ankle)
        R = frame(self.knee - self.ankle)
        d = cylinder(self.m(p), c, r, h, 0.06, R)
        return d - 0.01 * np.abs(np.cos(np.arctan2(*local(self.m(p), c, R)[:2]) * 7)) ** 0.6

    def toe_mark(self, p, shape, lift=0.0):
        """A 2D mark centred on the sole/toe face, in the shoe's sole plane."""
        L, W, H = self.size
        x, y, z = local(self.m(p), self.heel, self.R)
        return np.maximum(shape(x, y + L * 0.18), z - 0.08 - lift)


def standing_feet(N, skin, sock_m, shoe_m, sole_m, x=0.23, length=0.56, width=0.42, height=0.32,
                  leg_top=0.75, sock_z=0.38, stitch=None):
    """Legs, slouchy socks and clogs for a figure standing with its feet apart.

    `stitch` = material for a cream cross-stitch on each toe, or None.
    """
    foot = [np.array([sx * x, -0.02, 0.0]) for sx in (-1, 1)]

    def legs(p):
        q = (np.abs(p[0]), p[1], p[2])
        return round_cone(q, (x - 0.03, -0.02, leg_top), (x - 0.02, -0.03, sock_z - 0.05), 0.12, 0.11)

    def shoes(p):
        return union_all([shoe(p, c, length, width, height) for c in foot])

    def soles(p):
        return overlay(shoes(p), p[2] - 0.055, 0.012, depth=0.04, k=0.006)

    def socks(p):
        return union_all([sock(p, c + np.array([0, 0.04, sock_z]), 0.15, 0.1) for c in foot])

    comps = [
        Comp(f"{N}_Legs", legs, skin, voxel=0.007, tris=2500),
        Comp(f"{N}_Socks", socks, sock_m, voxel=0.006, tris=4000),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.007, tris=5000),
        Comp(f"{N}_Soles", soles, sole_m, voxel=0.005, tris=3000),
    ]
    if stitch:
        marks = [Tangent(shoes, c + np.array([0, 0.0, 0.12]), (0.25 * np.sign(c[0]), -1, 0.9)) for c in foot]

        def toe_x(p):
            region = union_all([t.region(p, lambda u, v: cross2(u, v, 0.045, 0.012)) for t in marks])
            return overlay(shoes(p), region, 0.012, depth=0.03, k=0.003)

        comps.append(Comp(f"{N}_ShoeStitch", toe_x, stitch, voxel=0.0035, tris=900))
    return comps


# ------------------------------------------------------------------ assemble

# Per-part triangle budgets above are authored generously; every part is decimated to this share
# so each figure lands near the earlier collections' 28k-53k total (shelves show many at once).
TRI_SCALE = 0.5


def assemble(name, title, rarity, comps, mats, bounds, **info):
    """Resolve material tuples into a flat figure description."""
    materials = {}
    for c in comps:
        c.tris = max(300, int(c.tris * TRI_SCALE))
        mname, m = c.mat
        materials[mname] = m
        c.mat = mname
    return dict(name=name, title=title, rarity=rarity, comps=comps, mats=materials, bounds=bounds, **info)


# ---------------------------------------------------------------- Wander Knit

def wander_knit():
    N = "WanderKnit"
    fm = face_mats(N)
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    knit_m = (f"{N}_Knit", Mat("#7D7F60", rough=0.9))
    hair_m = (f"{N}_Hair", Mat("#EADFC9", rough=0.45, coat=0.15))
    dress_m = (f"{N}_Dress", Mat("#9E9C80", rough=0.85))
    patch_m = (f"{N}_Patch", Mat("#DCCDB0", rough=0.8))
    stitch_m = (f"{N}_Stitch", Mat("#B97E6E", rough=0.6))
    leather = (f"{N}_Leather", Mat("#8E5E44", rough=0.55, coat=0.15))
    cream = (f"{N}_Cream", Mat("#E8DCC4", rough=0.7))
    button_m = (f"{N}_Button", Mat("#B8A27A", rough=0.35, metal=0.3))
    sock_m = (f"{N}_Socks", Mat("#EADFC8", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#94694C", rough=0.45, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#6E4A35", rough=0.6))

    head = Head()
    BC = np.array([0.0, 0.14, 2.22])
    BR = (0.97, 0.8, 0.93)

    def face_hole(p):
        return np.maximum(ellipse2(p[0], p[2] - 1.88, 0.78, 0.55), p[1] + 0.05)

    def beanie_shape(p):
        d = ellipsoid(p, BC, BR)
        d = smax(d, 1.36 - p[2], 0.08)  # open underneath, round the neck
        return smax(d, -face_hole(p), 0.07)

    def beanie(p):
        brim = 0.05 * np.exp(-(face_hole(p) / 0.08) ** 2) * np.clip((p[2] - 1.62) / 0.12, 0, 1)
        return beanie_shape(p) - brim - knit(p, BC, 24, 6, 0.05, el0=-1.3)

    ear_c = [np.array([sx * 0.6, 0.12, 3.02]) for sx in (-1, 1)]

    def ears(p):
        d = union_all([sphere(p, c, 0.21) for c in ear_c])
        wind = np.abs(np.sin((p[0] * 0.5 + p[1] * 0.3 + p[2] * 0.81) * 70.0))  # wound yarn
        return d - 0.016 * wind ** 0.5 - 0.008 * waves(p, 30.0, 3)

    def braids(p):
        d = None
        for sx in (-1, 1):
            path = catmull([(sx * 0.66, -0.02, 1.62), (sx * 0.68, -0.08, 1.38), (sx * 0.66, -0.12, 1.2)], 4)
            for i, q in enumerate(path):
                tw = 1 if i % 2 else -1
                e = ellipsoid(p, q + np.array([tw * 0.025, 0, 0]), (0.06, 0.055, 0.075), rot(0, tw * 30, 0))
                d = e if d is None else smin(d, e, 0.02)
            d = smin(d, sphere(p, (sx * 0.66, -0.13, 1.06), 0.115) - 0.01 * waves(p, 50.0, 5 + sx), 0.03)
        return d

    hair = Hair((0.0, -0.03, 2.12), (0.8, 0.74, 0.68),
                hem=[(0, 2.22), (22, 2.2), (45, 2.0), (70, 1.66), (180, 1.5)],
                locks=16, tip=0.12, groove=0.045, puff=0.03, swing=12.0)
    bangs = fringe((0.0, -0.03, 2.12), (0.8, 0.74, 0.68), [
        (-40, 2.5, 2.12, 0.1, -6), (-22, 2.52, 2.06, 0.11, -4), (-4, 2.54, 2.1, 0.11, 6),
        (14, 2.53, 2.04, 0.11, 8), (32, 2.5, 2.1, 0.1, 8), (48, 2.42, 2.0, 0.09, 6)])

    side = []
    for sx in (-1, 1):  # locks framing the face in front of the cheeks
        side.append(Leaf((sx * 0.6, -0.44, 2.32), (sx * 0.62, -0.5, 1.64), 0.11, 0.05, (sx * 0.6, -0.8, 0.0),
                         mid=0.4, r_base=0.08, r_tip=0.03, bend=0.06))
        side.append(Leaf((sx * 0.5, -0.56, 2.32), (sx * 0.5, -0.6, 1.9), 0.09, 0.045, (sx * 0.4, -0.9, 0.0),
                         mid=0.35, r_base=0.07, r_tip=0.025, bend=0.05))

    def hair_fn(p):
        d = smin(smin(hair(p), union_all([lf(p) for lf in side]), 0.04), bangs(p), 0.03)
        d = smax(d, ellipsoid(p, BC, (BR[0] - 0.02, BR[1] - 0.02, BR[2] - 0.02)), 0.02)  # stay under the beanie
        return d

    hat_patch = Tangent(beanie_shape, (0.0, 0.2, 2.62), sph_dir(-40, 18), spin=-14)

    def patch(p):
        return overlay(beanie_shape(p), hat_patch.region(p, lambda u, v: rect2(u, v, 0.2, 0.13, 0.03)),
                       0.07, depth=0.05, k=0.008)

    def patch_stitch(p):
        u, v, w = hat_patch.uvw(p)
        x = cross2(u, v, 0.055, 0.013)
        edge = np.abs(rect2(u, v, 0.165, 0.1, 0.02)) - 0.009
        dash = np.cos((u + v) * 70.0) - 0.1
        region = np.maximum(np.minimum(x, np.maximum(edge, dash)), np.abs(w) - 0.3)
        return overlay(patch(p) - 0.0, region, 0.008, depth=0.03, k=0.002)

    side_stitch = Tangent(beanie_shape, (0.0, 0.2, 2.62), sph_dir(55, 10), spin=10)

    def back_seam(p):  # the darned seam up the back and a cross-stitch on the right
        x, y, z = p[0] - BC[0], p[1] - BC[1], p[2] - BC[2]
        seam = np.maximum(np.abs(x) - 0.012 - 0.008 * (np.cos(z * 60) > 0.3), -y)
        seam = np.maximum(np.maximum(seam, -(z + 0.3)), np.maximum(z - 0.62, 0.15 - y))
        sx = side_stitch.region(p, lambda u, v: np.minimum(cross2(u, v, 0.05, 0.012),
                                                           cross2(u - 0.12, v + 0.08, 0.04, 0.012)))
        return overlay(beanie_shape(p), np.minimum(seam, sx), 0.058, depth=0.05, k=0.004)

    def dress(p):
        q = (p[0], p[1] / 0.82, p[2])
        d = round_cone(q, (0, 0, 1.4), (0, 0, 0.72), 0.34, 0.52)
        d = smax(d, 0.6 - p[2], 0.05)
        d = smax(d, p[2] - 1.5, 0.05)
        return d - 0.006 * waves(p, 9.0, 11)

    def arms(p):
        q = (np.abs(p[0]), p[1], p[2])
        d = tube(q, [(0.3, 0.0, 1.36), (0.42, 0.0, 1.12), (0.5, -0.02, 0.9)], [0.095, 0.085, 0.08], k=0.02)
        return smin(d, mitten(q, (0.52, -0.03, 0.8), (0.1, 0.0, -1.0), thumb=(-0.2, -1.0, 0.0)), 0.04)

    dress_patch = Tangent(dress, (0, 0, 0.75), (-0.5, -1, 0), spin=8)

    def dpatch(p):
        return overlay(dress(p), dress_patch.region(p, lambda u, v: rect2(u, v, 0.075, 0.065, 0.02)), 0.014,
                       depth=0.04, k=0.006)

    def dpatch_stitch(p):
        u, v, w = dress_patch.uvw(p)
        region = np.maximum(np.minimum(cross2(u, v, 0.03, 0.008), np.abs(rect2(u, v, 0.06, 0.05, 0.015)) - 0.006),
                            np.abs(w) - 0.3)
        return overlay(dress(p), region, 0.02, depth=0.03, k=0.002)

    # Satchel on the character's left hip, strap from the right shoulder.
    SC = np.array([0.4, -0.3, 0.86])
    RS = rot(0, 0, -28)

    def bag(p):
        return round_box(p, SC, (0.24, 0.1, 0.2), 0.08, RS)

    def flap(p):
        x, y, z = local(p, SC, RS)
        region = np.maximum(np.maximum(-0.02 - z, y - 0.02), np.abs(x) - 0.25)
        return overlay(bag(p), region, 0.02, depth=0.04, k=0.01)

    def flap_stitch(p):
        x, y, z = local(p, SC, RS)
        edge = np.maximum(np.abs(np.maximum(np.abs(x) - 0.18, -0.03 - z + 0.0)) - 0.008, z - 0.17)
        dash = np.cos((x + z) * 80.0) - 0.2
        region = np.maximum(np.maximum(edge, dash), y)
        return overlay(flap(p), region, 0.006, depth=0.02, k=0.002)

    def strap(p):
        a, b = np.array([-0.3, -0.22, 1.48]), SC + RS @ np.array([-0.12, 0.0, 0.18])
        mid = 0.5 * (a + b) + np.array([0.0, -0.17, 0.0])
        front = tube(p, [a, mid, b], [0.035, 0.035, 0.035], k=0.01)
        back = tube(p, [(-0.3, 0.12, 1.5), (0.0, 0.36, 1.22), (0.36, 0.2, 1.0), SC + RS @ np.array([0.12, 0.06, 0.18])],
                    [0.035] * 4, k=0.01)
        over = tube(p, [a, (-0.31, -0.05, 1.56), (-0.3, 0.12, 1.5)], [0.035] * 3, k=0.01)
        return union_all([front, back, over], 0.01)

    bunny_c = SC + RS @ np.array([0.0, -0.13, 0.04])

    def bunny(p):
        d = ellipsoid(p, bunny_c, (0.06, 0.03, 0.055))
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, bunny_c + RS @ np.array([sx * 0.03, 0.0, 0.08]), (0.02, 0.018, 0.05)), 0.015)
        return d

    def bag_button(p):
        return ellipsoid(p, SC + RS @ np.array([0.0, -0.13, -0.08]), (0.035, 0.02, 0.035))

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair_fn, hair_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Beanie", beanie, knit_m, voxel=0.0075, tris=19500),
        Comp(f"{N}_BeanieEars", ears, knit_m, voxel=0.007, tris=4000),
        Comp(f"{N}_Braids", braids, knit_m, voxel=0.006, tris=6000),
        Comp(f"{N}_HatPatch", patch, patch_m, voxel=0.005, tris=2000),
        Comp(f"{N}_HatStitch", patch_stitch, stitch_m, voxel=0.004, tris=2500),
        Comp(f"{N}_Darning", back_seam, stitch_m, voxel=0.005, tris=2500),
        Comp(f"{N}_Dress", dress, dress_m, voxel=0.008, tris=9000),
        Comp(f"{N}_DressPatch", dpatch, patch_m, voxel=0.004, tris=800),
        Comp(f"{N}_DressStitch", dpatch_stitch, stitch_m, voxel=0.0035, tris=1000),
        Comp(f"{N}_Arms", arms, skin, voxel=0.006, tris=5000),
        Comp(f"{N}_Bag", bag, leather, voxel=0.006, tris=3000),
        Comp(f"{N}_BagFlap", flap, leather, voxel=0.005, tris=2500),
        Comp(f"{N}_BagStitch", flap_stitch, cream, voxel=0.0035, tris=1500),
        Comp(f"{N}_Strap", strap, leather, voxel=0.005, tris=2000),
        Comp(f"{N}_Bunny", bunny, cream, voxel=0.004, tris=1000),
        Comp(f"{N}_BagButton", bag_button, button_m, voxel=0.004, tris=400),
    ]
    comps += standing_feet(N, skin, sock_m, shoe_m, sole_m)
    comps += kid_face(N, head, fm)
    return assemble(N, "Wander Knit", "Common", comps, {}, ((-1.3, -1.2, -0.2), (1.3, 1.2, 3.4)),
                    catalog="echo.wander-knit")


# ---------------------------------------------------------------- Echo Line

def echo_line():
    N = "EchoLine"
    fm = face_mats(N, iris=("#1C140D", "#24180F", "#4A3322", "#5E412B", "#2A1C12"), brow="#9C6E52")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#87593F", rough=0.6, coat=0.08))
    clip_m = (f"{N}_Clip", Mat("#EAD3A0", rough=0.4, coat=0.2))
    sweater = (f"{N}_Sweater", Mat("#EDE4D3", rough=0.85))
    overall_m = (f"{N}_Overalls", Mat("#C99A45", rough=0.75))
    patch_m = (f"{N}_Patch", Mat("#E3C68A", rough=0.75))
    stitch_m = (f"{N}_Stitch", Mat("#8C6440", rough=0.6))
    leather = (f"{N}_Strap", Mat("#8A5A3E", rough=0.5, coat=0.15))
    navy = (f"{N}_Phone", Mat("#454C5E", rough=0.35, coat=0.3))
    cream = (f"{N}_Cream", Mat("#EBDDBF", rough=0.5, coat=0.1))
    sock_m = (f"{N}_Socks", Mat("#EADFC8", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#8F6447", rough=0.45, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#5F3F2C", rough=0.6))

    head = Head()
    HC = np.array([0.0, 0.1, 2.42])
    HR = (0.9, 0.8, 0.8)
    hair_shell = Hair(HC, HR, hem=[(0, 2.4), (25, 2.32), (50, 2.05), (80, 1.9), (180, 1.84)],
                      locks=15, tip=0.12, groove=0.03, puff=0.03, swing=5.0)
    bangs = fringe(HC, HR, [
        (-38, 2.72, 2.04, 0.17, -12), (-18, 2.8, 2.08, 0.16, 10), (2, 2.82, 2.18, 0.16, 16),
        (20, 2.78, 2.1, 0.16, 14), (40, 2.66, 1.98, 0.16, 10), (-55, 2.55, 1.92, 0.15, -8)],
        thick=0.07, lift=0.07)
    mop = lock_mop(HC, HR, [(78, 5, 0), (58, 9, 20), (38, 12, 5), (18, 14, 14), (-2, 15, 3), (-20, 13, 10)],
                   seed=4, width=0.25, thick=0.075, length=0.5, flare=0.07, swing=28, round_tip=0.3,
                   skip=lambda az, el: abs(az) < 62 and el < 30)
    curls = [  # the cowlick on top
        ((-0.1, 0.1, 3.12), (0.22, 0.02, 3.42), (-0.12, -0.04, 0.1)),
        ((0.1, 0.18, 3.14), (-0.16, 0.24, 3.34), (0.06, 0.0, 0.1)),
    ]

    def hair(p):
        d = smin(hair_shell(p), union_all([lf(p) for lf in mop]), 0.03)
        d = smin(d, bangs(p), 0.03)
        for a, b, bend in curls:
            d = smin(d, curl(p, a, b, 0.07, 0.025, bend), 0.04)
        return d

    clip_c = surface_point(lambda p: ellipsoid(p, HC, HR), HC + (0, 0, 0.1), sph_dir(46, 0)) + sph_dir(46, 0) * 0.13
    RC = frame(unit(clip_c - HC)) @ rot(0, 0, 20)

    def clip(p):
        u, v, w = local(p, clip_c, RC)
        d2 = cross2(u, v, 0.08, 0.045)
        inside = np.minimum(np.maximum(d2, np.abs(w) - 0.02), 0)
        return np.sqrt(np.maximum(d2, 0) ** 2 + np.maximum(np.abs(w) - 0.02, 0) ** 2) + inside - 0.015

    def torso(p):
        return ellipsoid(p, (0, 0.02, 1.15), (0.37, 0.31, 0.38))

    def sweater_fn(p):
        return smax(torso(p), p[2] - 1.5, 0.05)

    # Right arm (character's right, -X) bent up to hold the receiver at the ear.
    r_sleeve, r_hand = arm_parts([(-0.32, 0.0, 1.38), (-0.6, -0.1, 1.24), (-0.66, -0.36, 1.46), (-0.64, -0.48, 1.58)],
                                 [0.13, 0.14, 0.13, 0.12], (-0.62, -0.6, 1.7), (0.05, -0.3, 1.0), thumb=(1, -0.4, 0.2))
    l_sleeve, l_hand = arm_parts([(0.32, 0.0, 1.38), (0.48, -0.02, 1.12), (0.54, -0.08, 0.96)],
                                 [0.13, 0.13, 0.12], (0.57, -0.13, 0.84), (0.2, -0.2, -1.0), thumb=(-0.3, -1, 0))

    def sleeves(p):
        return np.minimum(r_sleeve(p), l_sleeve(p))

    def hands(p):
        return np.minimum(r_hand(p), l_hand(p))

    def overalls(p):
        low = smax(ellipsoid(p, (0, 0.02, 1.0), (0.4, 0.33, 0.34)), p[2] - 1.08, 0.04)
        legs = fold(lambda q: round_cone(q, (0.18, 0.0, 0.9), (0.21, -0.02, 0.5), 0.21, 0.2))(p)
        d = smin(low, legs, 0.08)
        d = smax(d, 0.48 - p[2], 0.03)
        cuffs = fold(lambda q: torus(q, (0.21, -0.02, 0.53), 0.19, 0.045))(p)
        d = smin(d, cuffs, 0.02)
        bib_region = np.maximum(np.maximum(np.abs(p[0]) - 0.24, p[1] + 0.05), p[2] - 1.47)
        bib = overlay(torso(p), bib_region, 0.025, depth=0.05, k=0.02)
        return smin(d, bib, 0.02)

    def straps(p):
        q = (np.abs(p[0]), p[1], p[2])
        return tube(q, [(0.2, -0.24, 1.44), (0.22, -0.16, 1.56), (0.2, 0.08, 1.58), (0.08, 0.3, 1.25)],
                    [0.035] * 4, k=0.01)

    def strap_buttons(p):
        return fold(lambda q: cylinder(q, (0.2, -0.3, 1.43), 0.04, 0.015, 0.008, rot(90, 0, 0)))(p)

    patches = [Tangent(overalls, (0, 0, 0.75), (-1, -1.3, 0.1), spin=12),
               Tangent(overalls, (0, 0, 0.7), (1, -0.6, 0.0), spin=-8)]

    def patch(p):
        reg = union_all([t.region(p, lambda u, v: rect2(u, v, 0.08, 0.07, 0.025)) for t in patches])
        return overlay(overalls(p), reg, 0.014, depth=0.04, k=0.006)

    def patch_stitch(p):
        def mark(u, v):
            return np.maximum(np.abs(rect2(u, v, 0.065, 0.055, 0.02)) - 0.006, np.cos((u + v) * 90.0) - 0.1)
        reg = union_all([t.region(p, mark) for t in patches])
        return overlay(overalls(p), reg, 0.02, depth=0.03, k=0.002)

    # Receiver: earpiece cup at the right ear, handle down to the mouthpiece at the chin.
    E = np.array([-0.76, -0.36, 1.98])
    M = np.array([-0.4, -0.64, 1.56])
    RE = frame(unit((-0.75, -0.65, 0.15)))
    RM = frame(unit((-0.3, -0.9, 0.3)))

    def receiver(p):
        ear = cylinder(p, E, 0.2, 0.09, 0.07, RE)
        mouth = cylinder(p, M, 0.17, 0.085, 0.06, RM)
        handle = tube(p, [E + RE @ np.array([0, -0.05, 0.03]), (-0.68, -0.6, 1.8), M + RM @ np.array([0, 0.04, 0.03])],
                      [0.1, 0.105, 0.1], k=0.04)
        return smin(smin(ear, mouth, 0.05), handle, 0.05)

    def receiver_plates(p):
        reg = []
        for c, R, r in ((E, RE, 0.13), (M, RM, 0.12)):
            u, v, w = local(p, c, R)
            reg.append(np.maximum(np.sqrt(u * u + v * v) - r, -w))
        u, v, w = local(p, E, RE)
        plus = np.minimum(rect2(u, v, 0.03, 0.085, 0.02), rect2(u, v, 0.085, 0.03, 0.02))
        reg.append(np.maximum(plus, w))  # cross on the back of the earpiece
        return overlay(receiver(p), union_all(reg), 0.012, depth=0.04, k=0.004)

    def receiver_holes(p):
        reg = []
        for c, R in ((E, RE), (M, RM)):
            u, v, w = local(p, c, R)
            dots = None
            for hu, hv in ((0, 0), (0.045, 0), (-0.045, 0), (0, 0.045), (0, -0.045), (0.032, 0.032),
                           (-0.032, -0.032), (0.032, -0.032), (-0.032, 0.032)):
                e = np.sqrt((u - hu) ** 2 + (v - hv) ** 2) - 0.012
                dots = e if dots is None else np.minimum(dots, e)
            reg.append(np.maximum(dots, -w))
        return overlay(receiver_plates(p), union_all(reg), 0.006, depth=0.02, k=0.002)

    BAG = np.array([0.43, -0.3, 0.88])
    RB = frame(unit((0.25, -1.0, 0.0)))

    def bag(p):
        d = cylinder(p, BAG, 0.21, 0.08, 0.06, RB)
        for sx in (-1, 1):
            d = smin(d, sphere(p, BAG + RB @ np.array([sx * 0.14, 0.15, 0.0]), 0.065), 0.03)
        return d

    def bag_face(p):
        u, v, w = local(p, BAG, RB)
        disc = np.maximum(np.sqrt(u * u + v * v) - 0.14, -w)
        return overlay(bag(p), disc, 0.012, depth=0.04, k=0.004)

    def bag_x(p):
        u, v, w = local(p, BAG, RB)
        eyes = np.minimum(np.sqrt((u - 0.06) ** 2 + (v - 0.06) ** 2), np.sqrt((u + 0.06) ** 2 + (v - 0.06) ** 2)) - 0.016
        mark = np.minimum(cross2(u, v + 0.02, 0.045, 0.011), eyes)
        return overlay(bag_face(p), np.maximum(mark, -w), 0.008, depth=0.02, k=0.002)

    def cord(p):
        a = M + RM @ np.array([0.02, -0.1, -0.02])
        front = coil(p, [a, (-0.24, -0.52, 1.36), (-0.02, -0.42, 1.22), (0.22, -0.4, 1.06),
                         BAG + RB @ np.array([-0.12, 0.14, 0.02])])
        back = coil(p, [BAG + RB @ np.array([0.1, 0.16, 0.08]), (0.44, 0.1, 1.15), (0.2, 0.38, 1.36),
                        (-0.2, 0.3, 1.52), (-0.32, -0.08, 1.56), (-0.26, -0.26, 1.42)])
        return np.minimum(front, back)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Clip", clip, clip_m, voxel=0.004, tris=1200),
        Comp(f"{N}_Sweater", sweater_fn, sweater, voxel=0.008, tris=5000),
        Comp(f"{N}_Sleeves", sleeves, sweater, voxel=0.007, tris=7000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Overalls", overalls, overall_m, voxel=0.007, tris=11000),
        Comp(f"{N}_Patches", patch, patch_m, voxel=0.004, tris=1600),
        Comp(f"{N}_PatchStitch", patch_stitch, stitch_m, voxel=0.0035, tris=1600),
        Comp(f"{N}_Straps", straps, leather, voxel=0.005, tris=2500),
        Comp(f"{N}_StrapButtons", strap_buttons, leather, voxel=0.004, tris=800),
        Comp(f"{N}_Receiver", receiver, navy, voxel=0.006, tris=6000),
        Comp(f"{N}_ReceiverPlates", receiver_plates, cream, voxel=0.004, tris=2500),
        Comp(f"{N}_ReceiverHoles", receiver_holes, navy, voxel=0.0035, tris=2000),
        Comp(f"{N}_Cord", cord, cream, voxel=0.0045, tris=16000),
        Comp(f"{N}_PhoneBag", bag, navy, voxel=0.006, tris=4000),
        Comp(f"{N}_BagFace", bag_face, cream, voxel=0.004, tris=1500),
        Comp(f"{N}_BagMark", bag_x, navy, voxel=0.0035, tris=1000),
    ]
    comps += standing_feet(N, skin, sock_m, shoe_m, sole_m, stitch=cream)
    comps += kid_face(N, head, fm, brows=(0.2, 0.08, 0.026, 18.0), look=0.28)
    return assemble(N, "Echo Line", "Uncommon", comps, {}, ((-1.4, -1.2, -0.2), (1.4, 1.3, 3.7)),
                    catalog="echo.echo-line")


# ---------------------------------------------------------------- Crate Spark

def crate_spark():
    N = "CrateSpark"
    fm = face_mats(N, iris=("#1C140D", "#24180F", "#47331F", "#5A422A", "#2A1C12"), brow="#C97B4E")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#E07A3E", rough=0.6, coat=0.08))
    cream = (f"{N}_Cream", Mat("#EEE2CC", rough=0.8))
    red = (f"{N}_Red", Mat("#BE4A3C", rough=0.7))
    pom_m = (f"{N}_Pompom", Mat("#E58A48", rough=0.95))
    wood = (f"{N}_Wood", Mat("#B98A5A", rough=0.75))
    dark_wood = (f"{N}_WoodPost", Mat("#9A6E45", rough=0.75))
    nail_m = (f"{N}_Nails", Mat("#5E4634", rough=0.4, metal=0.3))
    paint_red = (f"{N}_StarPaint", Mat("#C24A38", rough=0.6))
    paint_yel = (f"{N}_Splotch", Mat("#E3B54C", rough=0.6))
    leather = (f"{N}_Strap", Mat("#7A5038", rough=0.55))
    sock_m = (f"{N}_Socks", Mat("#EEE4D0", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#A4483A", rough=0.45, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#EEE0C4", rough=0.6))

    head = Head(c=(0.0, -0.07, 2.0))
    HC = np.array([0.0, 0.08, 2.22])
    HR = (0.86, 0.8, 0.72)
    hair_shell = Hair(HC, HR, hem=[(0, 2.26), (25, 2.2), (50, 1.92), (80, 1.72), (180, 1.66)],
                      locks=15, tip=0.12, groove=0.03, puff=0.03, swing=5.0)
    bangs = fringe(HC, HR, [
        (-40, 2.54, 1.92, 0.17, -14), (-20, 2.6, 1.98, 0.16, 14), (0, 2.62, 2.06, 0.16, 18),
        (20, 2.6, 1.96, 0.16, 16), (40, 2.5, 1.88, 0.16, 12), (-58, 2.4, 1.78, 0.15, -8),
        (58, 2.4, 1.8, 0.15, 10)], thick=0.07, lift=0.07)
    mop = lock_mop(HC, HR, [(52, 10, 0), (30, 13, 12), (8, 15, 3), (-12, 15, 9)],
                   seed=9, width=0.24, thick=0.075, length=0.48, flare=0.1, swing=34, round_tip=0.36,
                   bend=0.1, skip=lambda az, el: abs(az) < 64 and el < 30)
    curls = [((0.18, 0.0, 2.84), (0.48, -0.1, 3.0), (0.0, -0.05, 0.12)),
             ((0.4, 0.0, 2.78), (0.6, -0.08, 2.9), (0.06, 0.0, 0.08))]

    def hair(p):
        d = smin(hair_shell(p), union_all([lf(p) for lf in mop]), 0.03)
        d = smin(d, bangs(p), 0.03)
        for a, b, bend in curls:
            d = smin(d, curl(p, a, b, 0.06, 0.022, bend), 0.04)
        return smax(d, -(hat(p) - 0.01), 0.02)  # tucked under the hat

    # Party hat perched on the character's right, tipped outward.
    HB = np.array([-0.38, 0.06, 2.76])
    RH = tilt_frame((-0.5, 0.06, 1.0))
    cone_h = 0.62

    def hat(p):
        x, y, z = local(p, HB, RH)
        q = (x, y, z)
        return round_cone(q, (0, 0, 0.0), (0, 0, cone_h), 0.32, 0.03)

    def hat_stripes(p):
        x, y, z = local(p, HB, RH)
        ang = np.arctan2(y, x)
        region = bands(z * 1.0 + ang / (2 * math.pi) * 0.1, 0.16, 0.42)
        region = np.maximum(region, -z + 0.02)
        rim = np.abs(z - 0.04) - 0.05
        return overlay(hat(p), np.minimum(region, rim), 0.012, depth=0.04, k=0.004)

    pom_c = HB + RH @ np.array([0, 0, cone_h + 0.08])

    def pompom(p):
        return sphere(p, pom_c, 0.14) - 0.012 * waves(p, 60.0, 31) - 0.008 * waves(p, 120.0, 32)

    def torso(p):
        return ellipsoid(p, (0, 0.02, 1.0), (0.36, 0.3, 0.38))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.32, 0.0, 1.25), (sx * 0.44, -0.1, 1.02), (sx * 0.24, -0.36, 1.12),
                             (sx * 0.16, -0.42, 1.2)], [0.13, 0.13, 0.12, 0.11], (sx * 0.1, -0.46, 1.3),
                            (0.0, -0.3, 1.0), thumb=(-sx, -0.3, 0.3), hand_r=(0.1, 0.085, 0.11)))

    def shirt(p):
        d = smax(torso(p), p[2] - 1.36, 0.06)
        return smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.04)

    def shirt_stripes(p):
        return overlay(shirt(p), bands(p[2] - 0.02, 0.13, 0.5), 0.008, depth=0.04, k=0.004)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    CC = np.array([0.0, -0.06, 0.78])
    CH = (0.66, 0.5, 0.3)

    def crate(p):
        outer = round_box(p, CC, CH, 0.04)
        inner = round_box(p, CC + (0, 0, 0.12), (CH[0] - 0.07, CH[1] - 0.07, CH[2]), 0.02)
        d = smax(outer, -inner, 0.01)
        z = p[2] - (CC[2] - CH[2])
        groove = np.exp(-((bands(z, 2 * CH[2] / 3, 0.0) + 0.0) / 0.012) ** 2)
        grain = 0.004 * np.sin(p[0] * 40 + 3 * np.sin(p[2] * 25)) + 0.004 * np.sin(p[1] * 40 + 3 * np.sin(p[2] * 21))
        return d + 0.014 * groove - grain

    def posts(p):
        q = (np.abs(p[0] - CC[0]), np.abs(p[1] - CC[1]), p[2])
        d = round_box(q, (CH[0] - 0.035, CH[1] - 0.035, CC[2]), (0.07, 0.07, CH[2] + 0.015), 0.025)
        top = smax(smax(round_box(p, CC + (0, 0, CH[2] - 0.03), (CH[0] + 0.01, CH[1] + 0.01, 0.045), 0.02),
                        -round_box(p, CC + (0, 0, CH[2]), (CH[0] - 0.09, CH[1] - 0.09, 0.2), 0.02), 0.01),
                   -0.0, 0.0)
        return np.minimum(d, top)

    nail_pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (-0.18, 0.0, 0.18):
                nail_pts.append(CC + np.array([sx * (CH[0] - 0.035), sy * (CH[1] + 0.04), z]))
                nail_pts.append(CC + np.array([sx * (CH[0] + 0.04), sy * (CH[1] - 0.035), z]))

    def nails(p):
        return union_all([sphere(p, c, 0.022) for c in nail_pts])

    def star_paint(p):
        u, v = p[0] - CC[0], p[2] - (CC[2] - 0.04)
        region = np.maximum(star2(u, v, 0.15, 0.48), p[1] - (CC[1] - CH[1] + 0.1))
        side = np.maximum(star2(p[1] - CC[1] - 0.05, p[2] - CC[2], 0.1, 0.48), -(p[0] - CC[0] - CH[0] + 0.1))
        return overlay(crate(p), np.minimum(region, side), 0.008, depth=0.03, k=0.003)

    def splotches(p):
        fy = CC[1] - CH[1] + 0.1
        regs = [np.maximum(splotch(p[0] - 0.42, p[2] - 0.92, 0.08, 1), p[1] - fy),
                np.maximum(splotch(p[0] + 0.52, p[2] - 0.6, 0.07, 2), p[1] - fy),
                np.maximum(splotch(p[0] - 0.25, p[2] - 0.6, 0.05, 3), p[1] - fy),
                np.maximum(splotch(p[0] - 0.4, p[2] - 0.95, 0.07, 4), -(p[1] - CC[1] - CH[1] + 0.1))]
        return overlay(crate(p), union_all(regs), 0.008, depth=0.03, k=0.003)

    def straps(p):
        q = (np.abs(p[0]), p[1], p[2])
        return tube(q, [(0.22, -0.42, 1.04), (0.22, -0.26, 1.34), (0.22, 0.05, 1.42), (0.22, 0.34, 1.2),
                        (0.22, 0.4, 1.04)], [0.035] * 5, k=0.01)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Hat", hat, cream, voxel=0.006, tris=6000),
        Comp(f"{N}_HatStripes", hat_stripes, red, voxel=0.0045, tris=6000),
        Comp(f"{N}_Pompom", pompom, pom_m, voxel=0.005, tris=5000),
        Comp(f"{N}_Shirt", shirt, cream, voxel=0.007, tris=9000),
        Comp(f"{N}_ShirtStripes", shirt_stripes, red, voxel=0.005, tris=12000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Crate", crate, wood, voxel=0.006, tris=14000),
        Comp(f"{N}_CratePosts", posts, dark_wood, voxel=0.006, tris=6000),
        Comp(f"{N}_Nails", nails, nail_m, voxel=0.004, tris=3000),
        Comp(f"{N}_StarPaint", star_paint, paint_red, voxel=0.004, tris=2000),
        Comp(f"{N}_Splotches", splotches, paint_yel, voxel=0.004, tris=2000),
        Comp(f"{N}_Straps", straps, leather, voxel=0.005, tris=3000),
    ]
    comps += standing_feet(N, skin, sock_m, shoe_m, sole_m, stitch=cream, sock_z=0.36)
    comps += kid_face(N, head, fm, z=1.85, nose_z=1.71, mouth_z=1.62, cheeks=(0.4, 1.65, (0.12, 0.075)),
                      brows=(0.2, 0.08, 0.026, 20.0), look=0.3)
    return assemble(N, "Crate Spark", "Rare", comps, {}, ((-1.4, -1.2, -0.2), (1.4, 1.2, 3.9)),
                    catalog="echo.crate-spark")


def posed(fn, pivot, R):
    """Evaluate `fn` in a frame rotated by R about `pivot` (tilting a head group)."""
    pivot = np.asarray(pivot, float)
    return lambda p: fn(_rotate(p, pivot, R))


def _rotate(p, pivot, R):
    # Inverse-rotate world points into the unposed frame: q = R^T (p - pivot) + pivot.
    x, y, z = local(p, pivot, R)
    return x + pivot[0], y + pivot[1], z + pivot[2]


def pose_comps(comps, pivot, R):
    """Rotate already-built components (including ramp lookups) as one rigid group."""
    for c in comps:
        c.fn = posed(c.fn, pivot, R)
        if c.ramp is not None:
            ramp = c.ramp
            c.ramp = (lambda r: lambda x, y, z: r(*_rotate((x, y, z), pivot, R)))(ramp)
    return comps


def dino_toy(p, c, yaw=0.0, s=1.0):
    """Little seated dinosaur plush: returns (body, spikes, belly region, eye/blush anchors)."""
    R = rot(0, 0, yaw)
    c = np.asarray(c, float)

    def at(v):
        return c + R @ (np.asarray(v, float) * s)

    body = ellipsoid(p, at((0, 0.02, 0.22)), (0.21 * s, 0.24 * s, 0.23 * s), R)
    head = ellipsoid(p, at((0, -0.08, 0.54)), (0.17 * s, 0.2 * s, 0.16 * s), R)
    snout = ellipsoid(p, at((0, -0.2, 0.51)), (0.13 * s, 0.12 * s, 0.1 * s), R)
    neck = round_cone(p, at((0, 0.0, 0.3)), at((0, -0.06, 0.5)), 0.15 * s, 0.13 * s)
    d = smin(smin(smin(body, head, 0.06 * s), snout, 0.05 * s), neck, 0.06 * s)
    tail = tube(p, [at((0, 0.2, 0.12)), at((0.1, 0.36, 0.06)), at((0.24, 0.36, 0.04))], [0.09 * s, 0.06 * s, 0.03 * s])
    d = smin(d, tail, 0.04 * s)
    for sx in (-1, 1):
        d = smin(d, ellipsoid(p, at((sx * 0.12, -0.14, 0.07)), (0.07 * s, 0.09 * s, 0.07 * s), R), 0.03 * s)
        d = smin(d, ellipsoid(p, at((sx * 0.15, -0.14, 0.3)), (0.05 * s, 0.07 * s, 0.05 * s), R), 0.03 * s)
    d = smax(d, c[2] - p[2], 0.01)
    spikes = None
    for t, h in ((0.66, 0.06), (0.58, 0.07), (0.44, 0.075), (0.3, 0.075), (0.18, 0.065), (0.1, 0.05)):
        base = at((0, 0.08 + 0.24 * (0.66 - t), t)) if t > 0.4 else at((0, 0.26 - 0.3 * t, t + 0.04))
        e = sphere(p, base, h * s)
        spikes = e if spikes is None else np.minimum(spikes, e)
    return d, spikes, at


def face_z(H):
    """Face feature heights for a Head centred at height H (measured on the standing sheets)."""
    return dict(z=H - 0.15, nose_z=H - 0.29, mouth_z=H - 0.38, cheeks=(0.4, H - 0.35, (0.12, 0.075)))


# ---------------------------------------------------------------- Paper Crown

def paper_crown():
    N = "PaperCrown"
    fm = face_mats(N, iris=("#1C140D", "#241A10", "#463525", "#5A4530", "#2A1D13"), brow="#C98466")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#D37560", rough=0.6, coat=0.08))
    paper = (f"{N}_Paper", Mat("#DFC9A2", rough=0.85))
    red_ink = (f"{N}_RedInk", Mat("#C65A4C", rough=0.7))
    blue_ink = (f"{N}_BlueInk", Mat("#6F86A0", rough=0.7))
    gold = (f"{N}_Gold", Mat("#E0B24E", rough=0.5, coat=0.15))
    sweater = (f"{N}_Sweater", Mat("#EEE3CF", rough=0.85))
    denim = (f"{N}_Denim", Mat("#62799A", rough=0.8))
    denim_lt = (f"{N}_DenimCuff", Mat("#8FA0B6", rough=0.8))
    stitch_m = (f"{N}_Stitch", Mat("#D9B77A", rough=0.6))
    sash_m = (f"{N}_Sash", Mat("#C26E66", rough=0.8))
    button_m = (f"{N}_Button", Mat("#9A6A45", rough=0.4, coat=0.2))
    pouch_m = (f"{N}_Pouch", Mat("#EBDDC2", rough=0.7))
    sock_m = (f"{N}_Socks", Mat("#EEE4D0", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#83563C", rough=0.45, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#6A432E", rough=0.6))
    dark = (f"{N}_Dark", Mat("#4A3428", rough=0.5))

    H = 1.87
    head = Head(c=(0.0, -0.07, H))
    HC = np.array([0.0, 0.04, 1.76])
    HR = (0.96, 0.86, 0.9)
    hair_shell = Hair(HC, HR, hem=[(0, 2.02), (25, 1.96), (45, 1.6), (70, 1.36), (180, 1.3)],
                      locks=22, tip=0.1, groove=0.04, puff=0.03, swing=8.0, opening=(1.5, 0.56, 0.52, -0.1))
    bangs = fringe(HC, HR, [
        (-44, 2.4, 1.72, 0.17, 10), (-26, 2.48, 1.88, 0.17, 16), (-8, 2.52, 1.92, 0.17, 20),
        (10, 2.5, 1.9, 0.17, 20), (28, 2.42, 1.8, 0.16, 16), (46, 2.3, 1.62, 0.16, 12),
        (-62, 2.3, 1.45, 0.15, 6), (62, 2.2, 1.45, 0.15, 6)], thick=0.07, lift=0.07)
    mop = lock_mop(HC, HR, [(52, 11, 0), (14, 19, 8)],
                   seed=12, width=0.26, thick=0.06, length=0.8, flare=0.03, swing=5, round_tip=0.3,
                   bend=-0.035, skip=lambda az, el: abs(az) < 66 and el < 55)

    def hair(p):
        d = smin(hair_shell(p), union_all([lf(p) for lf in mop]), 0.03)
        return smin(d, bangs(p), 0.03)

    # Paper crown, tipped down toward the character's left.
    CC = np.array([0.12, -0.04, 2.36])
    RCR = tilt_frame((0.22, 0.04, 1.0))

    def crown_coords(p):
        x, y, z = local(p, CC, RCR)
        ang = np.arctan2(x, -y)
        return x, y, z, ang, np.sqrt(x * x + y * y)

    def crown(p):
        x, y, z, ang, r = crown_coords(p)
        R = 0.82 + 0.16 * np.clip(z, 0, 0.6)
        f = ang / (2 * math.pi) * 7 + 0.5
        f = f - np.floor(f)
        top = 0.2 + 0.3 * (1 - np.abs(2 * f - 1)) ** 1.1
        d = np.abs(r - R) - 0.025
        d = smax(d, -z, 0.02)
        return smax(d, z - top, 0.03)

    def crown_ink(p, marks):
        x, y, z, ang, r = crown_coords(p)
        R = 0.82 + 0.16 * np.clip(z, 0, 0.6)
        reg = None
        for a0, v0, shape in marks:
            u = (ang - math.radians(a0)) * R
            e = shape(u, z - v0)
            reg = e if reg is None else np.minimum(reg, e)
        reg = np.maximum(reg, R - r)  # outside face only
        return overlay(crown(p), reg, 0.008, depth=0.03, k=0.002)

    def crown_red(p):
        return crown_ink(p, [(-28, 0.24, lambda u, v: star2(u, v, 0.11, 0.5)),
                             (150, 0.2, lambda u, v: star2(u, v, 0.08, 0.5))])

    def crown_doodle(u, v):
        pts = [(-0.08, -0.05), (-0.08, 0.05), (-0.04, 0.0), (0.0, 0.06), (0.04, 0.0), (0.08, 0.05), (0.08, -0.05),
               (-0.08, -0.05)]
        return union_all([seg2(u, v, a, b, 0.009) for a, b in zip(pts[:-1], pts[1:])])

    def sprig(u, v):
        d = seg2(u, v, (0, -0.08), (0, 0.1), 0.008)
        for k, s in ((-0.03, 1), (0.01, -1), (0.05, 1)):
            d = np.minimum(d, ellipse2(u - s * 0.03, v - k, 0.028, 0.014))
        return d

    def stitches(u, v):
        return np.minimum(seg2(u, v, (0, -0.05), (0, 0.05), 0.008), seg2(u, v, (-0.025, 0.0), (0.025, 0.0), 0.008))

    def crown_blue(p):
        marks = [(52, 0.2, sprig), (-70, 0.3, stitches), (-5, 0.36, stitches), (98, 0.26, stitches),
                 (200, 0.3, stitches), (-130, 0.26, sprig)]
        return crown_ink(p, marks)

    def crown_gold(p):
        return crown_ink(p, [(22, 0.2, crown_doodle), (-100, 0.18, crown_doodle)])

    legs = SeatedLegs()

    def torso(p):
        return ellipsoid(p, (0, 0.05, 0.86), (0.38, 0.32, 0.44))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.33, 0.02, 1.12), (sx * 0.43, -0.1, 0.78), (sx * 0.3, -0.36, 0.48),
                             (sx * 0.17, -0.48, 0.38)], [0.13, 0.13, 0.12, 0.11], (sx * 0.1, -0.56, 0.33),
                            (-sx * 0.3, -0.6, -0.6), thumb=(0, 0.3, 1), hand_r=(0.1, 0.075, 0.12)))

    def sweater_fn(p):
        d = smax(torso(p), p[2] - 1.22, 0.06)
        return smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.04)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    def overalls(p):
        seat = smax(ellipsoid(p, (0, 0.03, 0.32), (0.46, 0.36, 0.33)), -p[2], 0.02)
        d = smin(seat, legs.thigh(p, (0.19, 0.17)), 0.08)
        d = smax(d, p[2] - 0.66, 0.05)
        bib_region = np.maximum(np.maximum(np.abs(p[0]) - 0.26, p[1] + 0.08), p[2] - 1.08)
        bib = overlay(torso(p), bib_region, 0.03, depth=0.06, k=0.02)
        back_region = np.maximum(np.maximum(np.abs(p[0]) - 0.3, -p[1] + 0.1), p[2] - 0.9)
        back = overlay(torso(p), back_region, 0.03, depth=0.06, k=0.02)
        return smin(smin(d, bib, 0.03), back, 0.03)

    def cuffs(p):
        c = legs.knee + 0.08 * unit(legs.hip - legs.knee)
        return torus(legs.m(p), c, 0.17, 0.05, frame(legs.knee - legs.hip))

    pocket_t = Tangent(overalls, (0, 0, 0.92), (0, -1, 0))

    def pocket(p):
        return overlay(overalls(p), pocket_t.region(p, lambda u, v: rect2(u, v, 0.13, 0.11, 0.03)), 0.014,
                       depth=0.04, k=0.006)

    def pocket_gold(p):
        u, v, w = pocket_t.uvw(p)
        edge = np.abs(rect2(u, v, 0.11, 0.09, 0.025)) - 0.006
        dash = np.cos((u + v) * 110) - 0.2
        reg = np.minimum(np.maximum(edge, dash), crown_doodle(u, v * 1.2))
        return overlay(pocket(p), np.maximum(reg, np.abs(w) - 0.2), 0.008, depth=0.02, k=0.002)

    def straps(p):
        q = (np.abs(p[0]), p[1], p[2])
        return tube(q, [(0.22, -0.3, 1.04), (0.24, -0.2, 1.22), (0.24, 0.1, 1.26), (0.2, 0.36, 0.95)],
                    [0.04] * 4, k=0.01)

    def buttons(p):
        return fold(lambda q: cylinder(q, (0.22, -0.36, 1.04), 0.045, 0.018, 0.01, rot(90, 0, 0)))(p)

    def sash(p):
        back = np.minimum(
            tube(p, [(-0.3, 0.05, 1.24), (-0.1, 0.36, 0.95), (0.3, 0.34, 0.6), (0.48, 0.2, 0.45)], [0.05] * 4),
            tube(p, [(0.3, 0.05, 1.24), (0.1, 0.36, 0.95), (-0.3, 0.34, 0.6), (-0.48, 0.2, 0.45)], [0.05] * 4))
        front = tube(p, [(-0.3, 0.05, 1.24), (-0.36, -0.2, 1.1), (-0.42, -0.2, 0.75), (-0.5, 0.0, 0.5)], [0.05] * 4)
        ruffles = None
        for sx in (-1, 1):
            c = np.array([sx * 0.52, 0.12, 0.45])
            for i, (dz, a) in enumerate(((0.06, -30), (-0.04, 10), (-0.14, 40), (0.12, -60))):
                R = rot(0, 0, sx * a) @ rot(0, sx * 25, 0)
                e = ellipsoid(p, c + np.array([sx * 0.04 * i, 0.03 * i, dz]), (0.07, 0.17, 0.08), R)
                ruffles = e if ruffles is None else smin(ruffles, e, 0.02)
        d = smin(np.minimum(back, front), ruffles, 0.03)
        return d - 0.008 * np.abs(np.sin(p[1] * 60 + p[2] * 30))

    PC = np.array([0.52, -0.12, 0.44])

    def pouch(p):
        d = ellipsoid(p, PC, (0.12, 0.07, 0.11))
        for sx in (-1, 1):
            d = smin(d, sphere(p, PC + (sx * 0.08, 0.0, 0.1), 0.035), 0.02)
        return d

    def pouch_face(p):
        u, v = p[0] - PC[0], p[2] - PC[2]
        eyes = np.minimum(ellipse2(u - 0.035, v - 0.01, 0.012, 0.012), ellipse2(u + 0.035, v - 0.01, 0.012, 0.012))
        mouth = arc2(u, v + 0.0, 0.02, 60, 0.006)
        return overlay(pouch(p), np.maximum(np.minimum(eyes, mouth), p[1] - PC[1]), 0.006, depth=0.02, k=0.002)

    def shoes(p):
        return legs.shoe(p)

    def sole_marks(p):
        reg = legs.toe_mark(p, lambda u, v: np.minimum(cross2(u, v - 0.06, 0.035, 0.009),
                                                       np.abs(rect2(u, v, 0.14, 0.22, 0.1)) - 0.006))
        return overlay(legs.sole(p), reg, 0.008, depth=0.02, k=0.002)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Crown", crown, paper, voxel=0.005, tris=12000),
        Comp(f"{N}_CrownStar", crown_red, red_ink, voxel=0.0035, tris=2000),
        Comp(f"{N}_CrownSprig", crown_blue, blue_ink, voxel=0.0035, tris=3000),
        Comp(f"{N}_CrownDoodle", crown_gold, gold, voxel=0.0035, tris=2000),
        Comp(f"{N}_Sweater", sweater_fn, sweater, voxel=0.007, tris=9000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Overalls", overalls, denim, voxel=0.007, tris=12000),
        Comp(f"{N}_Cuffs", cuffs, denim_lt, voxel=0.006, tris=4000),
        Comp(f"{N}_Pocket", pocket, denim, voxel=0.004, tris=2000),
        Comp(f"{N}_PocketCrown", pocket_gold, gold, voxel=0.0035, tris=2000),
        Comp(f"{N}_Straps", straps, denim, voxel=0.005, tris=3000),
        Comp(f"{N}_Buttons", buttons, button_m, voxel=0.004, tris=800),
        Comp(f"{N}_Sash", sash, sash_m, voxel=0.006, tris=12000),
        Comp(f"{N}_Pouch", pouch, pouch_m, voxel=0.004, tris=2000),
        Comp(f"{N}_PouchFace", pouch_face, dark, voxel=0.003, tris=600),
        Comp(f"{N}_Legs", lambda p: legs.shin(p), skin, voxel=0.006, tris=2500),
        Comp(f"{N}_Socks", lambda p: legs.sock(p), sock_m, voxel=0.006, tris=4000),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.006, tris=5000),
        Comp(f"{N}_Soles", lambda p: legs.sole(p), sole_m, voxel=0.005, tris=3000),
        Comp(f"{N}_SoleStitch", sole_marks, stitch_m, voxel=0.0035, tris=1500),
    ]
    comps += kid_face(N, head, fm, **face_z(H), brows=(0.21, 0.07, 0.024, 16.0), look=0.32, lid=0.48)
    return assemble(N, "Paper Crown", "Uncommon", comps, {}, ((-1.4, -1.4, -0.2), (1.4, 1.2, 3.3)),
                    catalog="echo.paper-crown")


# ---------------------------------------------------------------- Thread Parade

def bow(p, c, R, size=0.12):
    """A puffy ribbon bow (two loops and a knot) in the frame R, facing local -Y."""
    c = np.asarray(c, float)
    d = ellipsoid(p, c, (size * 0.38, size * 0.32, size * 0.36), R)
    for sx in (-1, 1):
        lobe = ellipsoid(p, c + R @ np.array([sx * size * 0.75, 0.0, 0.0]), (size * 0.7, size * 0.3, size * 0.5),
                         R @ rot(0, sx * 12, 0))
        d = smin(d, lobe, size * 0.25)
    return d


def thread_parade():
    N = "ThreadParade"
    fm = face_mats(N, iris=("#1E1A12", "#29251A", "#535236", "#68674A", "#2E2C1E"), brow="#C9A37E")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#E7DCC8", rough=0.55, coat=0.08))
    straw = (f"{N}_Straw", Mat("#D9AE68", rough=0.8))
    band_m = (f"{N}_Band", Mat("#7D8FAE", rough=0.75))
    stitch_m = (f"{N}_Stitch", Mat("#EBD6A8", rough=0.6))
    red = (f"{N}_Bow", Mat("#B5493E", rough=0.7))
    flower_m = (f"{N}_Flower", Mat("#EEDFC3", rough=0.6))
    flower_x = (f"{N}_FlowerStitch", Mat("#B07A50", rough=0.6))
    blouse = (f"{N}_Blouse", Mat("#EFE4CF", rough=0.85))
    denim = (f"{N}_Denim", Mat("#7F95B4", rough=0.8))
    cuff_m = (f"{N}_Cuff", Mat("#A6ABAE", rough=0.8))
    patch_m = (f"{N}_Patch", Mat("#E1CBA3", rough=0.75))
    wood = (f"{N}_Wood", Mat("#A87A4F", rough=0.55, coat=0.15))
    thread_m = (f"{N}_Thread", Mat("#E9DCC0", rough=0.8))
    ring_m = (f"{N}_Ring", Mat("#AE4B40", rough=0.45, coat=0.2))
    sock_m = (f"{N}_Socks", Mat("#EEE4D0", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#80563C", rough=0.45, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#5F3F2C", rough=0.6))

    H = 2.12
    head = Head(c=(0.0, -0.07, H))
    HC = np.array([0.0, 0.04, 2.2])
    HR = (0.92, 0.82, 0.74)
    hair_shell = Hair(HC, HR, hem=[(0, 2.3), (25, 2.24), (45, 1.95), (70, 1.72), (180, 1.66)],
                      locks=16, tip=0.08, groove=0.03, puff=0.03, swing=8.0, opening=(1.86, 0.54, 0.46, -0.1))
    bangs = fringe(HC, HR, [
        (-36, 2.44, 2.1, 0.17, -14), (-16, 2.46, 2.14, 0.16, 12), (4, 2.46, 2.2, 0.16, 16),
        (24, 2.42, 2.1, 0.16, 14), (-56, 2.36, 1.86, 0.15, -6), (52, 2.32, 1.86, 0.15, 8)], thick=0.07, lift=0.07)
    mop = lock_mop(HC, HR, [(-6, 18, 0), (-22, 18, 10)],
                   seed=17, width=0.2, thick=0.1, length=0.26, flare=0.03, swing=20, round_tip=0.8,
                   bend=0.12, skip=lambda az, el: abs(az) < 60)

    def hair(p):
        d = smin(hair_shell(p) - 0.05 * waves(p, 12.0, 41), union_all([lf(p) for lf in mop]), 0.03)
        d = smin(d, bangs(p), 0.03)
        d = smax(d, -(hat_shape(p) - 0.005), 0.02)  # tucked under the hat
        return smax(d, hat_local(p)[2] + 0.06, 0.02)  # and never above the brim

    # Straw hat: dome crown and a wide brim tipped down toward the character's left.
    HB = np.array([0.02, 0.1, 2.52])
    RT = tilt_frame((0.3, -0.22, 1.0))

    def hat_local(p):
        return local(p, HB, RT)

    def hat_shape(p):
        x, y, z = hat_local(p)
        q = (x, y, z)
        crown = smax(ellipsoid(q, (0, 0, 0.0), (0.84, 0.8, 0.66)), -z - 0.02, 0.05)
        brim = cylinder(q, (0, 0, 0.0), 1.08, 0.05, 0.05)
        return smin(crown, brim, 0.08)

    def straw_fn(p):
        x, y, z = hat_local(p)
        r = np.sqrt(x * x + y * y + (z * 1.2) ** 2)
        ang = np.arctan2(x, -y)
        coil_ = np.abs(np.sin(r * math.pi / 0.09))  # coiled rows of plaited straw
        braid_ = np.abs(np.sin(ang * 34 + r * 40))
        return hat_shape(p) - 0.034 * coil_ ** 0.5 * (0.45 + 0.55 * braid_)

    def band(p):
        x, y, z = hat_local(p)
        crown = ellipsoid((x, y, z), (0, 0, 0.0), (0.84, 0.8, 0.66))
        region = np.maximum(np.abs(z - 0.16) - 0.11, -0.0 - (np.sqrt(x * x + y * y) - 0.3))
        return overlay(crown, region, 0.04, depth=0.05, k=0.01)

    def band_stitch(p):
        x, y, z = hat_local(p)
        ang = np.arctan2(x, -y)
        crown = ellipsoid((x, y, z), (0, 0, 0.0), (0.84, 0.8, 0.66))
        region = np.maximum(np.abs(z - 0.16) - 0.012, np.cos(ang * 40) - 0.2)
        return overlay(crown, region, 0.05, depth=0.03, k=0.002)

    fl_c = surface_point(hat_shape, HB + RT @ np.array([0, 0, 0.16]), RT @ sph_dir(28, 0)) + RT @ (sph_dir(28, 0) * 0.04)
    RF = frame(unit(fl_c - (HB + RT @ np.array([0, 0, 0.16]))))

    def flower(p):
        u, v, w = local(p, fl_c, RF)
        a = np.arctan2(v, u)
        r2 = np.sqrt(u * u + v * v) - 0.1 * (0.78 + 0.22 * np.cos(4 * a))
        return np.sqrt(np.maximum(r2, 0) ** 2 + np.maximum(np.abs(w) - 0.025, 0) ** 2) + np.minimum(
            np.maximum(r2, np.abs(w) - 0.025), 0) - 0.012

    def flower_stitch(p):
        u, v, w = local(p, fl_c, RF)
        return overlay(flower(p), np.maximum(cross2(u, v, 0.035, 0.008), -w), 0.006, depth=0.02, k=0.002)

    bow_c = surface_point(hat_shape, HB + RT @ np.array([0, 0, 0.16]), RT @ sph_dir(70, 0)) + RT @ (sph_dir(70, 0) * 0.06)
    RBW = frame(unit(bow_c - (HB + RT @ np.array([0, 0, 0.16])))) @ rot(0, 0, 10)

    def bow_fn(p):
        b = bow(p, bow_c, RBW @ rot(90, 0, 0), 0.14)
        tails = np.minimum(
            Leaf(bow_c, bow_c + np.array([0.08, -0.05, -0.62]), 0.06, 0.02, (1, -0.4, 0), mid=0.3,
                 r_base=0.05, r_tip=0.055)(p),
            Leaf(bow_c, bow_c + np.array([0.16, 0.12, -0.45]), 0.06, 0.02, (1, 0.3, 0), mid=0.3,
                 r_base=0.05, r_tip=0.055)(p))
        return b, tails

    def red_bow(p):
        return bow_fn(p)[0]

    def ribbon_tails(p):
        return bow_fn(p)[1]

    def torso(p):
        return ellipsoid(p, (0, 0.02, 1.15), (0.37, 0.31, 0.38))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.33, 0.0, 1.38), (sx * 0.44, 0.0, 1.14), (sx * 0.5, -0.03, 0.9)],
                            [0.17, 0.16, 0.08], (sx * 0.52, -0.05, 0.8), (sx * 0.1, 0.0, -1.0),
                            thumb=(-sx * 0.2, -1, 0)))

    def blouse_fn(p):
        d = smax(torso(p), p[2] - 1.5, 0.05)
        puffs = fold(lambda q: tube(q, [(0.33, 0.0, 1.38), (0.44, 0.0, 1.14)], [0.17, 0.16], k=0.02))(p)
        return smin(d, puffs, 0.04) - 0.006 * np.abs(np.sin(np.arctan2(p[1], p[0]) * 14))

    def arms(p):
        q = (np.abs(p[0]), p[1], p[2])
        fore = round_cone(q, (0.45, 0.0, 1.1), (0.5, -0.03, 0.9), 0.08, 0.075)
        return smin(fore, sl[1][1](q), 0.03)

    def bowtie(p):
        return bow(p, np.array([0.0, -0.33, 1.47]), rot(0, 0, 0), 0.1)

    def overalls(p):
        low = smax(ellipsoid(p, (0, 0.02, 1.0), (0.4, 0.33, 0.34)), p[2] - 1.08, 0.04)
        legs = fold(lambda q: round_cone(q, (0.18, 0.0, 0.9), (0.21, -0.02, 0.48), 0.21, 0.2))(p)
        d = smax(smin(low, legs, 0.08), 0.44 - p[2], 0.03)
        bib_region = np.maximum(np.maximum(np.abs(p[0]) - 0.25, p[1] + 0.05), p[2] - 1.36)
        bib = overlay(torso(p), bib_region, 0.025, depth=0.05, k=0.02)
        return smin(d, bib, 0.02)

    def cuffs(p):
        return fold(lambda q: torus(q, (0.21, -0.02, 0.48), 0.2, 0.055))(p)

    def straps(p):
        q = (np.abs(p[0]), p[1], p[2])
        return tube(q, [(0.2, -0.3, 1.3), (0.22, -0.18, 1.5), (0.2, 0.08, 1.56), (0.1, 0.3, 1.22)], [0.045] * 4, k=0.01)

    BT = [np.array([sx * 0.2, -0.36, 1.3]) for sx in (-1, 1)]

    def buttons(p):
        return union_all([cylinder(p, c, 0.075, 0.025, 0.015, rot(90, 0, 0)) for c in BT])

    def button_x(p):
        reg = union_all([np.maximum(cross2(p[0] - c[0], p[2] - c[2], 0.03, 0.008), p[1] - c[1]) for c in BT])
        return overlay(buttons(p), reg, 0.006, depth=0.02, k=0.002)

    patch_t = Tangent(overalls, (0.2, 0, 0.66), (0.3, -1, 0), spin=-6)

    def patch(p):
        return overlay(overalls(p), patch_t.region(p, lambda u, v: rect2(u, v, 0.09, 0.08, 0.02)), 0.014, depth=0.04,
                       k=0.006)

    def patch_stitch(p):
        def mark(u, v):
            edge = np.maximum(np.abs(rect2(u, v, 0.075, 0.065, 0.015)) - 0.006, np.cos((u + v) * 90) - 0.1)
            return np.minimum(edge, cross2(u, v, 0.03, 0.008))
        return overlay(patch(p), patch_t.region(p, mark), 0.006, depth=0.02, k=0.002)

    # Wooden spool on the back, axis along X; a cord drops from its right end to a red ring.
    SP = np.array([0.0, 0.5, 1.14])
    RX = rot(0, 90, 0)

    def spool(p):
        d = cylinder(p, SP, 0.12, 0.42, 0.02, RX)
        for sx in (-1, 1):
            d = smin(d, cylinder(p, SP + (sx * 0.36, 0, 0), 0.26, 0.06, 0.03, RX), 0.02)
        hole = cylinder(p, SP, 0.06, 0.6, 0.0, RX)
        return smax(d, -hole, 0.01)

    def thread_fn(p):
        d = cylinder(p, SP, 0.2, 0.3, 0.04, RX)
        return d - 0.008 * np.abs(np.sin((p[1] - SP[1]) * 70 + (p[2] - SP[2]) * 70 + p[0] * 8))

    RC = np.array([-0.7, 0.02, 0.8])

    def cord(p):
        return tube(p, [(-0.42, 0.42, 1.0), (-0.6, 0.3, 0.98), (-0.7, 0.12, 0.94), RC + (0, 0, 0.12)],
                    [0.035] * 4, k=0.01)

    def ring(p):
        return torus(p, RC, 0.12, 0.045, rot(90, 0, 10))

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Hat", straw_fn, straw, voxel=0.006, tris=19500),
        Comp(f"{N}_HatBand", band, band_m, voxel=0.005, tris=6000),
        Comp(f"{N}_BandStitch", band_stitch, stitch_m, voxel=0.004, tris=2500),
        Comp(f"{N}_HatFlower", flower, flower_m, voxel=0.004, tris=2000),
        Comp(f"{N}_HatFlowerStitch", flower_stitch, flower_x, voxel=0.003, tris=600),
        Comp(f"{N}_HatBow", red_bow, red, voxel=0.005, tris=4000),
        Comp(f"{N}_RibbonTails", ribbon_tails, band_m, voxel=0.004, tris=3000),
        Comp(f"{N}_Blouse", blouse_fn, blouse, voxel=0.007, tris=9000),
        Comp(f"{N}_Arms", arms, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Bowtie", bowtie, red, voxel=0.004, tris=2500),
        Comp(f"{N}_Overalls", overalls, denim, voxel=0.007, tris=11000),
        Comp(f"{N}_Cuffs", cuffs, cuff_m, voxel=0.006, tris=4000),
        Comp(f"{N}_Straps", straps, denim, voxel=0.005, tris=3000),
        Comp(f"{N}_Buttons", buttons, wood, voxel=0.004, tris=1500),
        Comp(f"{N}_ButtonStitch", button_x, red, voxel=0.003, tris=600),
        Comp(f"{N}_Patch", patch, patch_m, voxel=0.004, tris=1200),
        Comp(f"{N}_PatchStitch", patch_stitch, red, voxel=0.003, tris=1200),
        Comp(f"{N}_Spool", spool, wood, voxel=0.006, tris=6000),
        Comp(f"{N}_SpoolThread", thread_fn, thread_m, voxel=0.005, tris=6000),
        Comp(f"{N}_Cord", cord, thread_m, voxel=0.004, tris=2000),
        Comp(f"{N}_Ring", ring, ring_m, voxel=0.004, tris=3000),
    ]
    comps += standing_feet(N, skin, sock_m, shoe_m, sole_m, stitch=stitch_m, sock_z=0.34, height=0.28)
    comps += kid_face(N, head, fm, **face_z(H), brows=(0.21, 0.065, 0.028, 4.0), look=0.3)
    return assemble(N, "Thread Parade", "Common", comps, {}, ((-1.4, -1.3, -0.2), (1.4, 1.3, 3.6)),
                    catalog="echo.thread-parade")


# ---------------------------------------------------------------- Still Pebble

def still_pebble():
    N = "StillPebble"
    fm = face_mats(N, iris=("#1E1A12", "#29251A", "#4C4C33", "#626144", "#2E2C1E"), brow="#D59A7E")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#DE7C5C", rough=0.6, coat=0.08))
    knit_m = (f"{N}_Beanie", Mat("#E4D8C2", rough=0.9))
    patch_m = (f"{N}_Patch", Mat("#EADFC6", rough=0.8))
    leaf_m = (f"{N}_Leaf", Mat("#7F9466", rough=0.6))
    stitch_m = (f"{N}_Stitch", Mat("#B8665A", rough=0.6))
    scarf_m = (f"{N}_Scarf", Mat("#B0605A", rough=0.9))
    sweater = (f"{N}_Sweater", Mat("#EDE3CF", rough=0.9))
    denim = (f"{N}_Denim", Mat("#7A90AE", rough=0.8))
    sock_m = (f"{N}_Socks", Mat("#EEE4D0", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#83563C", rough=0.45, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#5F3F2C", rough=0.6))
    cream = (f"{N}_Cream", Mat("#EADBBE", rough=0.6))
    dino_m = (f"{N}_Dino", Mat("#8F9E72", rough=0.55, coat=0.15))
    spike_m = (f"{N}_DinoSpikes", Mat("#6F7F57", rough=0.55))
    belly_m = (f"{N}_DinoBelly", Mat("#E6DDC2", rough=0.6))
    dot_m = (f"{N}_DinoEyes", Mat("#3A3226", rough=0.3, coat=0.4))
    blush_m = (f"{N}_DinoBlush", Mat("#E7A79A", rough=0.6))

    # Head group, modelled upright and then tilted toward the character's left about the neck.
    H = 1.56
    pivot = np.array([0.0, -0.02, 1.02])
    tilt = rot(0, 17, 0)
    head = Head(c=(0.0, -0.07, H))
    BC = np.array([0.0, 0.06, 1.86])
    BR = (0.86, 0.82, 0.8)

    def beanie_shape(p):
        d = ellipsoid(p, BC, BR)
        return smax(d, 1.7 - p[2] + 0.12 * np.clip(p[1], 0, 1), 0.05)

    def beanie(p):
        cuff_band = np.clip(1.0 - np.abs(p[2] - 1.86) / 0.15, 0, 1)
        d = beanie_shape(p) - 0.04 * cuff_band
        knit_ = knit(p, BC, 26, 6, 0.045, el0=-0.3)
        ribs = rib(p, BC, 44, 0.03)
        return d - np.where(p[2] < 2.0, ribs, knit_)

    def pompom(p):
        return sphere(p, BC + (0, 0, 0.84), 0.21) - 0.025 * np.abs(waves(p, 30.0, 51)) - 0.01 * waves(p, 70.0, 52)

    cuff_t = Tangent(beanie_shape, BC, sph_dir(-32, 0), spin=0)

    def patch(p):
        return overlay(beanie_shape(p) - 0.04,
                       cuff_t.region(p, lambda u, v: rect2(u, v + 0.0, 0.17, 0.11, 0.03)), 0.05, depth=0.05, k=0.008)

    def sprig(u, v):
        d = seg2(u, v, (0.0, -0.08), (0.02, 0.07), 0.01)
        for k, sx in ((-0.03, 1), (0.0, -1), (0.035, 1), (0.05, -1)):
            a = math.radians(35 * sx)
            uu, vv = u - sx * 0.035, v - k
            d = np.minimum(d, ellipse2(uu * math.cos(a) + vv * math.sin(a), -uu * math.sin(a) + vv * math.cos(a), 0.035, 0.016))
        return d

    def leaf(p):
        return overlay(patch(p), cuff_t.region(p, sprig), 0.008, depth=0.02, k=0.002)

    def stitches(p):
        u, v, w = cuff_t.uvw(p)
        edge = np.maximum(np.abs(rect2(u, v, 0.15, 0.09, 0.02)) - 0.007, np.cos(u * 70 + v * 70) - 0.2)
        crosses = Tangent(beanie_shape, BC, sph_dir(36, 30))
        cx = crosses.region(p, lambda a, b: np.minimum(cross2(a, b, 0.04, 0.01), cross2(a - 0.12, b - 0.1, 0.035, 0.01)))
        on_patch = overlay(patch(p), np.maximum(edge, np.abs(w) - 0.3), 0.008, depth=0.02, k=0.002)
        on_hat = overlay(beanie_shape(p), cx, 0.06, depth=0.04, k=0.003)
        return np.minimum(on_patch, on_hat)

    HC = np.array([0.0, 0.04, 1.6])
    HR = (0.82, 0.76, 0.68)
    hair_shell = Hair(HC, HR, hem=[(0, 1.72), (25, 1.66), (50, 1.4), (80, 1.28), (180, 1.34)],
                      locks=17, tip=0.12, groove=0.04, puff=0.03, swing=6.0, opening=(1.4, 0.5, 0.38, -0.1))
    bangs = fringe(HC, HR, [(-40, 1.84, 1.5, 0.16, -10), (-20, 1.86, 1.56, 0.15, 14), (0, 1.86, 1.6, 0.15, 18),
                            (20, 1.84, 1.54, 0.15, 14), (40, 1.8, 1.46, 0.15, 10)], thick=0.07, lift=0.06)
    mop = lock_mop(HC, HR, [(4, 16, 0), (-14, 18, 10)], seed=22, width=0.22, thick=0.07, length=0.26,
                   flare=0.08, swing=30, round_tip=0.35, bend=0.1, skip=lambda az, el: abs(az) < 58)

    def hair(p):
        d = smin(hair_shell(p), union_all([lf(p) for lf in mop]), 0.03)
        d = smin(d, bangs(p), 0.03)
        return smax(d, -(beanie_shape(p) - 0.01), 0.02)

    head_group = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=16000),
        Comp(f"{N}_Beanie", beanie, knit_m, voxel=0.0075, tris=19500),
        Comp(f"{N}_Pompom", pompom, knit_m, voxel=0.006, tris=6000),
        Comp(f"{N}_Patch", patch, patch_m, voxel=0.005, tris=2500),
        Comp(f"{N}_PatchLeaf", leaf, leaf_m, voxel=0.0035, tris=1200),
        Comp(f"{N}_Stitches", stitches, stitch_m, voxel=0.0035, tris=2500),
    ]
    head_group += kid_face(N, head, fm, **face_z(H), brows=(0.2, 0.065, 0.026, 6.0), look=0.34, lid=0.5)
    pose_comps(head_group, pivot, tilt)

    def torso(p):
        return ellipsoid(p, (0, 0.06, 0.72), (0.4, 0.34, 0.4))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.34, 0.02, 0.98), (sx * 0.44, -0.2, 0.74), (sx * 0.28, -0.46, 0.66),
                             (sx * 0.16, -0.52, 0.68)], [0.14, 0.14, 0.13, 0.12], (sx * 0.09, -0.56, 0.72),
                            (-sx, -0.2, -0.1), thumb=(0, -0.3, 1), hand_r=(0.1, 0.08, 0.11)))

    def sweater_fn(p):
        d = smax(torso(p), p[2] - 1.08, 0.06)
        d = smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.04)
        return d - 0.012 * np.abs(np.sin(np.arctan2(p[0], -(p[1] - 0.06)) * 18)) ** 0.5

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def shorts(p):
        seat = smax(ellipsoid(p, (0, 0.04, 0.2), (0.38, 0.28, 0.2)), -p[2], 0.02)
        thigh = round_cone(m(p), (0.2, 0.08, 0.26), (0.21, -0.36, 0.56), 0.19, 0.17)
        return smin(seat, thigh, 0.08)

    def shins(p):
        return round_cone(m(p), (0.21, -0.38, 0.54), (0.24, -0.62, 0.22), 0.12, 0.11)

    def socks(p):
        q = m(p)
        d = round_cone(q, (0.22, -0.45, 0.44), (0.24, -0.62, 0.2), 0.14, 0.135)
        return d - 0.01 * np.abs(np.cos(np.arctan2(q[0] - 0.23, q[1] + 0.5) * 7)) ** 0.6

    heel = np.array([0.25, -0.56, 0.0])

    def shoes(p):
        return shoe(m(p), heel, 0.5, 0.4, 0.28, yaw=-6)

    def soles(p):
        return overlay(shoes(p), p[2] - 0.055, 0.012, depth=0.04, k=0.006)

    def toe_x(p):
        q = m(p)
        reg = np.maximum(cross2(q[0] - 0.25, q[1] + 0.82, 0.05, 0.013), -(q[2] - 0.15))
        return overlay(shoes(p), reg, 0.012, depth=0.03, k=0.003)

    def scarf(p):
        wrap = torus(p, (0, 0.0, 1.02), 0.42, 0.16, rot(-10, 0, 0))
        knot = ellipsoid(p, (0.2, -0.44, 0.96), (0.18, 0.12, 0.15))
        front = Leaf((0.3, -0.42, 0.94), (0.66, -0.36, 0.16), 0.22, 0.042, (0.3, -1, 0.1), mid=0.5, r_base=0.15,
                     r_tip=0.2, bend=0.08, cup=0.04)(p)
        back = Leaf((0.0, 0.46, 1.0), (0.06, 0.6, 0.12), 0.22, 0.042, (0, 1, 0.1), mid=0.5, r_base=0.18, r_tip=0.22,
                    bend=0.08, cup=0.04)(p)
        d = union_all([wrap, knot, front, back], 0.04)
        return d - 0.01 * np.abs(np.sin(p[2] * 50 + p[0] * 12)) ** 0.5

    def fringe_fn(p):
        d = None
        for base, n in (((0.66, -0.36, 0.16), (0.3, -1, 0.1)), ((0.06, 0.6, 0.12), (0, 1, 0.1))):
            b = np.asarray(base, float)
            side = unit(np.cross(n, (0, 0, 1)))
            for k in np.linspace(-0.17, 0.17, 9):
                e = round_cone(p, b + side * k, b + side * k * 1.1 + np.array([0, 0, -0.1]), 0.022, 0.018)
                d = e if d is None else np.minimum(d, e)
        return smax(d, -p[2], 0.01)

    scarf_t = Tangent(scarf, (0.3, -0.2, 0.5), (0.4, -1, 0), spin=10)

    def scarf_x(p):
        return overlay(scarf(p), scarf_t.region(p, lambda u, v: cross2(u, v, 0.045, 0.012)), 0.012, depth=0.03, k=0.003)

    DC = np.array([-0.72, -0.28, 0.0])

    def dino(p):
        return dino_toy(p, DC, yaw=-18)[0]

    def dino_spikes(p):
        body, spikes, at = dino_toy(p, DC, yaw=-18)
        return smax(spikes, -(body + 0.02), 0.01)

    _, _, at = dino_toy((np.zeros(1), np.zeros(1), np.zeros(1)), DC, yaw=-18)

    def dino_belly(p):
        reg = ellipsoid(p, at((0, -0.2, 0.22)), (0.14, 0.12, 0.18))
        return overlay(dino(p), reg, 0.008, depth=0.03, k=0.01)

    def dino_eyes(p):
        return union_all([sphere(p, at((sx * 0.1, -0.19, 0.6)), 0.026) for sx in (-1, 1)])

    def dino_blush(p):
        reg = union_all([sphere(p, at((sx * 0.13, -0.17, 0.52)), 0.04) for sx in (-1, 1)])
        return overlay(dino(p), reg, 0.006, depth=0.02, k=0.008)

    comps = head_group + [
        Comp(f"{N}_Sweater", sweater_fn, sweater, voxel=0.007, tris=11000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Shorts", shorts, denim, voxel=0.007, tris=8000),
        Comp(f"{N}_Legs", shins, skin, voxel=0.006, tris=2000),
        Comp(f"{N}_Socks", socks, sock_m, voxel=0.006, tris=4000),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.006, tris=5000),
        Comp(f"{N}_Soles", soles, sole_m, voxel=0.005, tris=3000),
        Comp(f"{N}_ShoeStitch", toe_x, cream, voxel=0.0035, tris=900),
        Comp(f"{N}_Scarf", scarf, scarf_m, voxel=0.006, tris=12000),
        Comp(f"{N}_ScarfFringe", fringe_fn, scarf_m, voxel=0.004, tris=4000),
        Comp(f"{N}_ScarfStitch", scarf_x, cream, voxel=0.0035, tris=800),
        Comp(f"{N}_Dino", dino, dino_m, voxel=0.005, tris=9000),
        Comp(f"{N}_DinoSpikes", dino_spikes, spike_m, voxel=0.004, tris=3000),
        Comp(f"{N}_DinoBelly", dino_belly, belly_m, voxel=0.004, tris=2000),
        Comp(f"{N}_DinoEyes", dino_eyes, dot_m, voxel=0.003, tris=400),
        Comp(f"{N}_DinoBlush", dino_blush, blush_m, voxel=0.0035, tris=500),
    ]
    return assemble(N, "Still Pebble", "Common", comps, {}, ((-1.3, -1.3, -0.2), (1.3, 1.2, 3.1)),
                    catalog="echo.still-pebble")


# ---------------------------------------------------------------- Hearth Helm

def shingles(p, c, rows, per_row, amp, el0):
    """Overlapping roof tiles: rows by elevation from el0 up, staggered, each thickest at its lower edge."""
    x, y, z = p[0] - c[0], p[1] - c[1], p[2] - c[2]
    r = np.sqrt(x * x + y * y + z * z) + 1e-9
    el = np.arcsin(np.clip(z / r, -1, 1))
    az = np.arctan2(x, -y)
    v = (el - el0) / (math.pi / 2 - el0) * rows
    row = np.floor(v)
    fv = v - row
    n = np.maximum(per_row * np.cos(el) ** 0.8, 3.0)
    u = az / (2 * math.pi) * np.round(n) + 0.5 * np.mod(row, 2)
    fu = u - np.floor(u) - 0.5
    step = amp * (1.0 - fv) ** 0.6
    gap = np.exp(-((0.5 - np.abs(fu)) / 0.06) ** 2) * amp * 0.7
    corner = np.clip(np.abs(fu) * 2 - 0.6, 0, 1) ** 2 * np.clip(0.35 - fv, 0, 1) * amp * 2.5  # rounded tile corners
    return step - gap - corner


def hearth_helm():
    N = "HearthHelm"
    fm = face_mats(N, iris=("#1E1A12", "#29251A", "#4F4E35", "#656448", "#2E2C1E"), brow="#C08B6C")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#A96B4C", rough=0.6, coat=0.08))
    stone = (f"{N}_Stone", Mat("#E6D8BE", rough=0.9))
    brick_m = (f"{N}_Bricks", Mat("#CDB596", rough=0.85))
    tile = (f"{N}_Roof", Mat("#C06F5B", rough=0.7))
    frame_m = (f"{N}_Window", Mat("#80553A", rough=0.5, coat=0.15))
    glass_m = (f"{N}_Pane", Mat("#4A3A30", rough=0.25, coat=0.4))
    shutter_m = (f"{N}_Shutters", Mat("#7E9C98", rough=0.6))
    stitch_m = (f"{N}_Stitch", Mat("#8E6248", rough=0.6))
    tunic_m = (f"{N}_Tunic", Mat("#E6D9BF", rough=0.85))
    toggle_m = (f"{N}_Toggle", Mat("#8C5E40", rough=0.5))
    stripe_a = (f"{N}_Shorts", Mat("#EBE2CF", rough=0.8))
    stripe_b = (f"{N}_ShortStripes", Mat("#7F9C99", rough=0.8))
    sock_m = (f"{N}_Socks", Mat("#EEE4D0", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#83563C", rough=0.45, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#5F3F2C", rough=0.6))

    H = 2.06
    head = Head(c=(0.0, -0.07, H))
    HC = np.array([0.0, 0.14, 2.28])
    HR = (0.98, 0.94, 0.86)

    def face_hole(p):
        return np.maximum(ellipse2(p[0], p[2] - 1.88, 0.62, 0.6), p[1] + 0.02)

    def helmet_shape(p):
        d = ellipsoid(p, HC, HR)
        d = smax(d, 1.44 - p[2], 0.08)
        return smax(d, -face_hole(p), 0.07)

    def helmet(p):
        rim = 0.05 * np.exp(-(face_hole(p) / 0.08) ** 2) * np.clip((p[2] - 1.55) / 0.1, 0, 1)
        lumps = 0.008 * waves(p, 22.0, 61)
        return helmet_shape(p) - rim - lumps

    def eave(p):
        az = np.degrees(np.abs(np.arctan2(p[0], -(p[1] - HC[1]))))
        return np.interp(az, [0, 30, 62, 95, 125, 180], [2.74, 2.72, 2.7, 2.3, 2.0, 1.96])

    def roof(p):
        shell = ellipsoid(p, HC + (0, 0, 0.02), (HR[0] + 0.09, HR[1] + 0.09, HR[2] + 0.09))
        d = smax(shell, eave(p) - p[2], 0.03)
        d = smax(d, -(ellipsoid(p, HC, (HR[0] - 0.05, HR[1] - 0.05, HR[2] - 0.05))), 0.02)
        return d - shingles(p, HC, 6, 22, 0.045, math.radians(-14))

    CH = np.array([0.42, 0.26, 3.14])

    def chimney(p):
        stack = round_box(p, CH, (0.13, 0.13, 0.3), 0.03)
        stack = smax(stack, 2.6 - p[2], 0.01)
        return stack - 0.006 * waves(p, 40.0, 63)

    def chimney_cap(p):
        return round_box(p, CH + (0, 0, 0.31), (0.17, 0.17, 0.05), 0.025)

    behind = np.array([0.0, 0.34, 2.42])  # march from behind the face opening, never through it
    win = Tangent(helmet_shape, behind, sph_dir(60, -8))  # on the wall, below the eave

    def window(p):
        u, v, w = win.uvw(p)
        arch = np.where(v > 0.0, np.sqrt(u * u + v * v) - 0.16, np.abs(u) - 0.16)
        arch = np.maximum(arch, -0.2 - v)
        frame_ = np.abs(arch) - 0.025
        mull = np.maximum(np.minimum(np.abs(u) - 0.016, np.abs(v + 0.02) - 0.016), arch)
        region = np.minimum(frame_, mull)
        return np.maximum(region, np.abs(w) - 0.3) , arch

    def window_frame(p):
        region, _ = window(p)
        return overlay(helmet_shape(p), region, 0.045, depth=0.05, k=0.004)

    def window_pane(p):
        _, arch = window(p)
        u, v, w = win.uvw(p)
        return overlay(helmet_shape(p), np.maximum(arch, np.abs(w) - 0.3), 0.012, depth=0.05, k=0.004)

    def shutters(p):
        reg = win.region(p, lambda u, v: np.minimum(rect2(u - 0.26, v + 0.02, 0.065, 0.16, 0.02),
                                                     rect2(u + 0.26, v + 0.02, 0.065, 0.16, 0.02)))
        return overlay(helmet_shape(p), reg, 0.035, depth=0.05, k=0.005)

    brick_spots = [(-62, 12, 0), (-44, 22, 1), (-90, -4, 0), (-140, -30, 1), (-170, -24, 0), (160, -32, 1),
                   (130, -26, 0), (108, -14, 1), (178, -38, 0), (-118, -18, 1), (88, -22, 0), (40, 24, 1)]
    brick_t = [Tangent(helmet_shape, behind, sph_dir(a, e), spin=0) for a, e, _ in brick_spots]

    def bricks(p):
        regs = []
        for t, (_, _, two) in zip(brick_t, brick_spots):
            def shape(u, v, two=two):
                d = rect2(u, v, 0.06, 0.035, 0.012)
                return np.minimum(d, rect2(u - 0.1, v - 0.06, 0.05, 0.03, 0.012)) if two else d
            regs.append(t.region(p, shape))
        return overlay(helmet_shape(p), union_all(regs), 0.03, depth=0.04, k=0.004)

    xt = Tangent(helmet_shape, behind + (0, 0, -0.3), sph_dir(-76, -8), spin=10)

    def x_stitch(p):
        reg = xt.region(p, lambda u, v: np.minimum(cross2(u, v + 0.06, 0.05, 0.013), rect2(u - 0.02, v + 0.2, 0.05, 0.035, 0.012)))
        return overlay(helmet_shape(p), reg, 0.065, depth=0.05, k=0.003)

    hair_c = np.array([0.0, 0.04, 2.14])
    hair_r = (0.8, 0.78, 0.7)
    hair_shell = Hair(hair_c, hair_r, hem=[(0, 2.2), (25, 2.14), (50, 1.8), (80, 1.55), (180, 1.38)],
                      locks=18, tip=0.12, groove=0.04, puff=0.03, swing=6.0, opening=(1.82, 0.5, 0.4, -0.1))
    bangs = fringe(hair_c, hair_r, [(-38, 2.44, 2.02, 0.16, -12), (-18, 2.48, 2.1, 0.15, 12), (2, 2.48, 2.14, 0.15, 16),
                                    (22, 2.44, 2.06, 0.15, 14), (42, 2.38, 1.96, 0.15, 10)], thick=0.07, lift=0.06)

    def hair(p):
        d = smin(hair_shell(p) - 0.02 * waves(p, 12.0, 64), bangs(p), 0.03)
        return smax(d, -(helmet_shape(p) - 0.01), 0.02)

    def torso(p):
        return ellipsoid(p, (0, 0.02, 1.15), (0.36, 0.3, 0.38))

    def tunic(p):
        q = (p[0], p[1] / 0.85, p[2])
        d = round_cone(q, (0, 0, 1.4), (0, 0, 0.9), 0.34, 0.46)
        d = smax(smax(d, 0.8 - p[2], 0.04), p[2] - 1.5, 0.05)
        collar = torus(p, (0, -0.05, 1.46), 0.2, 0.04, rot(-15, 0, 0))
        return smin(d, collar, 0.02) - 0.005 * waves(p, 10.0, 65)

    def toggle(p):
        return round_box(p, (0.0, -0.34, 1.32), (0.02, 0.02, 0.06), 0.015)

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.32, 0.0, 1.38), (sx * 0.42, -0.12, 1.12), (sx * 0.2, -0.38, 1.22),
                             (sx * 0.1, -0.42, 1.28)], [0.085, 0.08, 0.075, 0.07], (sx * 0.06, -0.46, 1.34),
                            (0.0, -0.2, 1.0), thumb=(-sx, -0.3, 0.3), hand_r=(0.09, 0.08, 0.11)))

    def arms(p):
        return union_all([sl[0][0](p), sl[1][0](p), sl[0][1](p), sl[1][1](p)], 0.03)

    def shorts_shape(p):
        low = smax(ellipsoid(p, (0, 0.02, 0.86), (0.38, 0.32, 0.22)), p[2] - 0.98, 0.04)
        legs = fold(lambda q: round_cone(q, (0.18, 0.0, 0.82), (0.21, -0.02, 0.56), 0.22, 0.21))(p)
        return smax(smin(low, legs, 0.08), 0.52 - p[2], 0.04)

    def shorts(p):
        return shorts_shape(p) - 0.006 * np.abs(np.sin(p[2] * 40))

    def shorts_stripes(p):
        az = np.arctan2(p[0], -p[1])
        return overlay(shorts_shape(p), bands(az, 2 * math.pi / 26, 0.45) * 0.4, 0.008, depth=0.03, k=0.002)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Helmet", helmet, stone, voxel=0.0075, tris=16000),
        Comp(f"{N}_Roof", roof, tile, voxel=0.007, tris=19500),
        Comp(f"{N}_Chimney", chimney, stone, voxel=0.005, tris=3000),
        Comp(f"{N}_ChimneyCap", chimney_cap, tile, voxel=0.005, tris=1500),
        Comp(f"{N}_WindowFrame", window_frame, frame_m, voxel=0.004, tris=2500),
        Comp(f"{N}_WindowPane", window_pane, glass_m, voxel=0.004, tris=1500),
        Comp(f"{N}_Shutters", shutters, shutter_m, voxel=0.004, tris=2000),
        Comp(f"{N}_Bricks", bricks, brick_m, voxel=0.004, tris=5000),
        Comp(f"{N}_Stitches", x_stitch, stitch_m, voxel=0.0035, tris=1500),
        Comp(f"{N}_Tunic", tunic, tunic_m, voxel=0.007, tris=9000),
        Comp(f"{N}_Toggle", toggle, toggle_m, voxel=0.003, tris=500),
        Comp(f"{N}_Arms", arms, skin, voxel=0.005, tris=6000),
        Comp(f"{N}_Shorts", shorts, stripe_a, voxel=0.006, tris=8000),
        Comp(f"{N}_ShortStripes", shorts_stripes, stripe_b, voxel=0.004, tris=9000),
    ]
    comps += standing_feet(N, skin, sock_m, shoe_m, sole_m, stitch=stitch_m, sock_z=0.36)
    comps += kid_face(N, head, fm, **face_z(H), brows=(0.21, 0.06, 0.026, 4.0), look=0.3, lid=0.5)
    return assemble(N, "Hearth Helm", "Uncommon", comps, {}, ((-1.4, -1.3, -0.2), (1.4, 1.3, 3.6)),
                    catalog="echo.hearth-helm")


# ---------------------------------------------------------------- Dino Drift

def footprint2(u, v, s=1.0):
    """Three-toed dinosaur footprint, toes up."""
    pad = ellipse2(u, v + 0.03 * s, 0.045 * s, 0.035 * s)
    toes = [ellipse2(u - dx * s, v - dy * s, 0.022 * s, 0.045 * s) for dx, dy in ((-0.045, 0.03), (0.0, 0.05), (0.045, 0.03))]
    return union_all([pad] + toes, 0.01 * s)


def dino_drift():
    N = "DinoDrift"
    fm = face_mats(N, iris=("#1E1A12", "#29251A", "#4C4C33", "#626144", "#2E2C1E"), brow="#C9A587")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#E6DCC8", rough=0.55, coat=0.08))
    fleece = (f"{N}_Fleece", Mat("#9AA088", rough=0.95))
    spike_m = (f"{N}_Spikes", Mat("#6F7A60", rough=0.95))
    lining = (f"{N}_Lining", Mat("#E4DAC3", rough=0.9))
    dot_m = (f"{N}_Dots", Mat("#3B342B", rough=0.4, coat=0.3))
    wood = (f"{N}_Toggles", Mat("#8C5C3C", rough=0.5, coat=0.15))
    cord_m = (f"{N}_Cords", Mat("#E8DECA", rough=0.8))
    boot_m = (f"{N}_Boots", Mat("#C05A4B", rough=0.35, coat=0.35))
    sock_m = (f"{N}_Socks", Mat("#EEE4D0", rough=0.85))
    emblem_m = (f"{N}_Emblem", Mat("#EADFC6", rough=0.5))
    print_m = (f"{N}_Footprint", Mat("#7C8B66", rough=0.8))

    H = 2.06
    head = Head(c=(0.0, -0.07, H))
    HC = np.array([0.0, 0.12, 2.28])
    HR = (0.92, 0.9, 0.94)
    SN = np.array([0.0, -0.5, 2.66])

    def face_hole(p):
        return np.maximum(ellipse2(p[0], p[2] - 1.92, 0.62, 0.56), p[1] + 0.0)

    def hood_shape(p):
        d = ellipsoid(p, HC, HR)
        d = smin(d, ellipsoid(p, SN, (0.62, 0.48, 0.27)), 0.2)
        d = smax(d, 1.4 - p[2], 0.08)
        return smax(d, -face_hole(p), 0.07)

    def hood(p):
        rim = 0.05 * np.exp(-(face_hole(p) / 0.08) ** 2) * np.clip((p[2] - 1.52) / 0.1, 0, 1)
        return hood_shape(p) - rim - 0.0025 * waves(p, 40.0, 71)

    def lining_fn(p):
        snout_front = np.maximum(np.maximum(p[1] + 0.84, 2.45 - p[2]), p[2] - 2.8)
        rim = np.abs(face_hole(p) + 0.0) - 0.07
        return overlay(hood(p), np.minimum(snout_front, rim), 0.01, depth=0.05, k=0.02)

    def dots(p):
        eyes = [sphere(p, surface_point(hood_shape, (sx * 0.3, 0.0, 2.95), (sx * 0.1, -1, 0.2)), 0.055) for sx in (-1, 1)]
        nostrils = [ellipsoid(p, (sx * 0.13, -0.97, 2.72), (0.03, 0.02, 0.024)) for sx in (-1, 1)]
        return union_all(eyes + nostrils)

    def horns(p):
        return union_all([ellipsoid(p, (sx * 0.2, -0.08, 3.2), (0.09, 0.08, 0.12)) for sx in (-1, 1)], 0.0)

    # Spikes: rounded plates down the midline of the hood, back, and tail.
    tail_path = [(0.0, 0.42, 0.78), (-0.05, 0.72, 0.42), (-0.2, 0.96, 0.16), (-0.42, 1.06, 0.08)]

    def tail(p):
        return tube(p, tail_path, [0.24, 0.18, 0.11, 0.04], k=0.06)

    spike_pts = []
    for el in (66, 46, 26, 6, -16):
        q = surface_point(lambda p: ellipsoid(p, HC, HR), HC, sph_dir(180, el))
        n = unit(q - HC)
        spike_pts.append((q + n * 0.06, n, 0.21 - 0.004 * (66 - el) / 4))
    for z in (1.3, 1.06):
        spike_pts.append((np.array([0.0, 0.5 + 0.06 * (1.3 - z), z]), np.array([0, 1.0, 0.1]), 0.15))
    for t, r in zip(catmull(tail_path, 2)[1:-1], (0.13, 0.11, 0.09, 0.07)):
        spike_pts.append((np.asarray(t) + np.array([0, 0, 0.14]), np.array([0, 0.3, 1.0]), r))

    def spikes(p):
        d = None
        for c, n, r in spike_pts:
            R = frame(n, up_hint=(1, 0, 0))
            e = ellipsoid(p, c, (r * 0.8, 0.075, r), R)
            d = e if d is None else np.minimum(d, e)
        return d

    hair_c = np.array([0.0, 0.03, 2.14])
    hair_r = (0.8, 0.76, 0.7)
    hair_shell = Hair(hair_c, hair_r, hem=[(0, 2.2), (25, 2.14), (50, 1.8), (80, 1.55), (180, 1.4)],
                      locks=18, tip=0.12, groove=0.04, puff=0.03, swing=6.0, opening=(1.84, 0.5, 0.4, -0.1))
    bangs = fringe(hair_c, hair_r, [(-38, 2.44, 2.04, 0.16, -12), (-18, 2.48, 2.1, 0.15, 12), (2, 2.48, 2.16, 0.15, 16),
                                    (22, 2.44, 2.06, 0.15, 14), (42, 2.38, 1.96, 0.15, 10)], thick=0.07, lift=0.06)

    def hair(p):
        d = smin(hair_shell(p) - 0.02 * waves(p, 12.0, 72), bangs(p), 0.03)
        return smax(d, -(hood_shape(p) - 0.01), 0.02)

    def coat_body(p):
        q = (p[0], p[1] / 0.86, p[2])
        d = round_cone(q, (0, 0.0, 1.38), (0, 0.0, 0.66), 0.38, 0.6)
        d = smax(d, 0.56 - p[2] + 0.03 * np.cos(np.arctan2(p[0], -p[1]) * 6), 0.04)
        return smax(d, p[2] - 1.56, 0.06)

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.36, 0.0, 1.36), (sx * 0.56, -0.05, 1.12), (sx * 0.52, -0.2, 0.98)],
                            [0.17, 0.19, 0.17], (sx * 0.47, -0.27, 0.9), (-sx * 0.4, -0.4, -1.0),
                            thumb=(-sx, -0.2, 0), hand_r=(0.09, 0.075, 0.1)))

    def coat(p):
        d = smin(coat_body(p), np.minimum(sl[0][0](p), sl[1][0](p)), 0.05)
        cuffs = fold(lambda q: torus(q, (0.53, -0.18, 1.0), 0.15, 0.045, frame((0.0, -0.4, -1.0))))(p)
        d = smin(d, cuffs, 0.02)
        d = smin(d, tail(p), 0.08)
        return d - 0.0025 * waves(p, 40.0, 73)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    pocket_t = Tangent(coat_body, (0, 0, 0.92), (0, -1, 0))

    def pocket(p):
        reg = pocket_t.region(p, lambda u, v: rect2(u, v, 0.28, 0.2, 0.08))
        return overlay(coat_body(p) - 0.005, reg, 0.03, depth=0.05, k=0.01)

    def pocket_print(p):
        return overlay(pocket(p), pocket_t.region(p, lambda u, v: footprint2(u, v + 0.05, 1.3)), 0.008, depth=0.02,
                       k=0.002)

    def toggles(p):
        d = None
        for z, x in ((1.4, 0.04), (1.2, -0.02)):
            c = np.array([x, -0.42 + 0.02 * (1.4 - z), z])
            t = round_cone(p, c - (0.07, 0, 0), c + (0.07, 0, 0), 0.032, 0.032)
            d = t if d is None else np.minimum(d, t)
        return d

    def cords(p):
        d = None
        for sx in (-1, 1):
            c = tube(p, [(sx * 0.18, -0.36, 1.52), (sx * 0.2, -0.43, 1.4), (sx * 0.22, -0.45, 1.24)], [0.018] * 3)
            c = smin(c, sphere(p, (sx * 0.22, -0.46, 1.2), 0.055), 0.01)
            d = c if d is None else np.minimum(d, c)
        return d

    foot = [np.array([sx * 0.22, -0.02, 0.0]) for sx in (-1, 1)]

    def boots(p):
        d = None
        for c in foot:
            b = smin(shoe(p, c, 0.52, 0.38, 0.28), cylinder(p, c + (0, 0.03, 0.24), 0.165, 0.16, 0.05), 0.06)
            d = b if d is None else np.minimum(d, b)
        return smax(d, -p[2], 0.01)

    def boot_emblem(p):
        regs = []
        for c in foot:
            sx = np.sign(c[0])
            u, v = (p[1] - c[1] - 0.0) * -sx, p[2] - 0.22
            regs.append(np.maximum(footprint2(u, v, 1.1), -(p[0] - c[0]) * sx))
        return overlay(boots(p), union_all(regs), 0.01, depth=0.03, k=0.003)

    def socks(p):
        return union_all([sock(p, c + np.array([0, 0.03, 0.44]), 0.14, 0.06) for c in foot])

    def legs(p):
        q = (np.abs(p[0]), p[1], p[2])
        return round_cone(q, (0.2, -0.01, 0.7), (0.21, 0.0, 0.42), 0.11, 0.1)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Hood", hood, fleece, voxel=0.0075, tris=16000),
        Comp(f"{N}_Lining", lining_fn, lining, voxel=0.005, tris=6000),
        Comp(f"{N}_HoodDots", dots, dot_m, voxel=0.004, tris=1200),
        Comp(f"{N}_Horns", horns, fleece, voxel=0.005, tris=1500),
        Comp(f"{N}_Spikes", spikes, spike_m, voxel=0.005, tris=8000),
        Comp(f"{N}_Coat", coat, fleece, voxel=0.0075, tris=18000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=3000),
        Comp(f"{N}_Pocket", pocket, lining, voxel=0.005, tris=4000),
        Comp(f"{N}_PocketPrint", pocket_print, print_m, voxel=0.0035, tris=1200),
        Comp(f"{N}_Toggles", toggles, wood, voxel=0.004, tris=1500),
        Comp(f"{N}_Cords", cords, cord_m, voxel=0.004, tris=2500),
        Comp(f"{N}_Legs", legs, skin, voxel=0.006, tris=2000),
        Comp(f"{N}_Socks", socks, sock_m, voxel=0.005, tris=3000),
        Comp(f"{N}_Boots", boots, boot_m, voxel=0.006, tris=7000),
        Comp(f"{N}_BootEmblem", boot_emblem, emblem_m, voxel=0.0035, tris=1200),
    ]
    comps += kid_face(N, head, fm, **face_z(H), brows=(0.21, 0.06, 0.026, 4.0), look=0.12, lid=0.4)
    return assemble(N, "Dino Drift", "Common", comps, {}, ((-1.4, -1.4, -0.2), (1.4, 1.5, 3.6)),
                    catalog="echo.dino-drift")


# ---------------------------------------------------------------- Mask Nuzzle

def mask_nuzzle():
    N = "MaskNuzzle"
    fm = face_mats(N, iris=("#1E1A12", "#29251A", "#4C4A33", "#625F44", "#2E2C1E"), brow="#C9A587")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#DBC7A6", rough=0.55, coat=0.08))
    fur = (f"{N}_Fur", Mat("#C8704A", rough=0.95))
    trim_m = (f"{N}_Trim", Mat("#EEE3CD", rough=0.95))
    tip_m = (f"{N}_EarTips", Mat("#6E4632", rough=0.9))
    stitch_m = (f"{N}_Stitch", Mat("#EEDFC0", rough=0.7))
    scarf_m = (f"{N}_Scarf", Mat("#7F95A8", rough=0.9))
    jacket = (f"{N}_Jacket", Mat("#EEE4D1", rough=0.9))
    leather = (f"{N}_Satchel", Mat("#7D5139", rough=0.55, coat=0.12))
    mask_m = (f"{N}_Mask", Mat("#F3EDE2", rough=0.35, coat=0.3))
    mask_red = (f"{N}_MaskPaint", Mat("#D06A4E", rough=0.5))
    mask_dark = (f"{N}_MaskEyes", Mat("#3D2E28", rough=0.4))
    bell_m = (f"{N}_Bell", Mat("#C9A15A", rough=0.3, metal=0.7))
    sock_m = (f"{N}_Socks", Mat("#EDE3CE", rough=0.95))
    shoe_m = (f"{N}_Shoes", Mat("#7D533A", rough=0.45, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#E8DCC2", rough=0.7))

    H = 1.98
    head = Head(c=(0.0, -0.07, H))
    HC = np.array([0.0, 0.16, 2.2])
    HR = (1.0, 0.96, 0.84)

    def face_hole(p):
        return np.maximum(ellipse2(p[0], p[2] - 1.86, 0.64, 0.58), p[1] + 0.0)

    def hood_shape(p):
        d = ellipsoid(p, HC, HR)
        d = smax(d, 1.4 - p[2], 0.08)
        return smax(d, -face_hole(p), 0.07)

    def fuzz(p, seed, amp=0.004):
        return amp * waves(p, 45.0, seed) + amp * 0.6 * waves(p, 90.0, seed + 1)

    def hood(p):
        return hood_shape(p) - fuzz(p, 81)

    def trim(p):
        band = np.abs(face_hole(p) + 0.02) - 0.075
        rim = overlay(hood_shape(p), band, 0.05, depth=0.06, k=0.03)
        return rim - fuzz(p, 83, 0.008)

    ears = [Leaf((sx * 0.5, 0.18, 2.86), (sx * 0.66, 0.12, 3.32), 0.24, 0.09, (sx * 0.15, -1, 0.1), mid=0.3,
                 r_base=0.22, r_tip=0.03) for sx in (-1, 1)]

    def ear_fn(p):
        return np.minimum(ears[0](p), ears[1](p)) - fuzz(p, 85)

    def ear_inner(p):
        d = None
        for e in ears:
            full, a, s_, n, d2 = e.parts(p)
            v = overlay(full, np.maximum(np.maximum(d2 + 0.07, -n), a - e.L * 0.7), 0.012, depth=0.04, k=0.01)
            d = v if d is None else np.minimum(d, v)
        return d

    def ear_tips(p):
        d = None
        for e in ears:
            full, a, s_, n, d2 = e.parts(p)
            v = overlay(full, e.L * 0.62 - a, 0.008, depth=0.05, k=0.01)
            d = v if d is None else np.minimum(d, v)
        return d

    seam_pts = [sph_dir(180, el) for el in (60, 40, 20, 0, -20)] + [sph_dir(a, e) for a, e in ((-110, 15), (-120, -5), (110, 12))]
    seam_t = [Tangent(hood_shape, HC, d) for d in seam_pts]

    def stitches(p):
        reg = union_all([t.region(p, lambda u, v: np.minimum(rect2(u, v, 0.012, 0.055, 0.01), rect2(u, v, 0.055, 0.012, 0.01)))
                         for t in seam_t])
        return overlay(hood_shape(p), reg, 0.02, depth=0.04, k=0.003)

    hair_c = np.array([0.0, 0.03, 2.06])
    hair_r = (0.8, 0.76, 0.7)
    hair_shell = Hair(hair_c, hair_r, hem=[(0, 2.14), (25, 2.08), (50, 1.74), (80, 1.5), (180, 1.36)],
                      locks=18, tip=0.12, groove=0.04, puff=0.03, swing=6.0, opening=(1.76, 0.5, 0.4, -0.1))
    bangs = fringe(hair_c, hair_r, [(-38, 2.36, 1.96, 0.16, -12), (-18, 2.4, 2.02, 0.15, 12), (2, 2.4, 2.08, 0.15, 16),
                                    (22, 2.36, 1.98, 0.15, 14), (42, 2.3, 1.88, 0.15, 10)], thick=0.07, lift=0.06)

    def hair(p):
        d = smin(hair_shell(p) - 0.02 * waves(p, 12.0, 84), bangs(p), 0.03)
        return smax(d, -(hood_shape(p) - 0.01), 0.02)

    # Kitsune mask on the character's left temple, facing front-left, with cord, bell and tassel.
    MC = np.array([0.7, -0.46, 2.52])
    MS = 1.6
    RM = frame(unit((0.55, -0.85, 0.05)), up_hint=(0, 0, 1)) @ rot(0, 0, 0)

    def mask(p):
        x, y, z = (v / MS for v in local(p, MC, RM))
        q = (x, y, z)
        d = ellipsoid(q, (0, 0, 0), (0.17, 0.2, 0.1))
        d = smin(d, ellipsoid(q, (0, -0.1, 0.07), (0.07, 0.1, 0.07)), 0.05)
        for sx in (-1, 1):
            d = smin(d, round_cone(q, (sx * 0.09, 0.12, 0.0), (sx * 0.14, 0.27, 0.0), 0.06, 0.015), 0.03)
        return d * MS

    def mask_paint(p):
        x, y, z = (v / MS for v in local(p, MC, RM))
        reg = np.minimum(ellipse2(x - 0.09, y - 0.04, 0.04, 0.02), ellipse2(x + 0.09, y - 0.04, 0.04, 0.02))
        reg = np.minimum(reg, ellipse2(x, y - 0.13, 0.02, 0.04))
        ears_ = np.minimum(ellipse2(np.abs(x) - 0.12, y - 0.2, 0.025, 0.05), ellipse2(x, y + 0.17, 0.03, 0.015))
        reg = np.maximum(np.minimum(reg, ears_), -z)
        return overlay(mask(p), reg * MS, 0.008, depth=0.03, k=0.002)

    def mask_eyes(p):
        x, y, z = (v / MS for v in local(p, MC, RM))
        reg = np.minimum(seg2(x, y, (0.04, 0.0), (0.12, 0.03), 0.012), seg2(x, y, (-0.04, 0.0), (-0.12, 0.03), 0.012))
        reg = np.minimum(reg, ellipse2(x, y + 0.19, 0.015, 0.012))
        return overlay(mask(p), np.maximum(reg, -z) * MS, 0.01, depth=0.03, k=0.002)

    BL = np.array([0.9, -0.36, 2.12])

    def cord(p):
        d = tube(p, [MC + RM @ np.array([0.18, -0.08, -0.06]), (0.88, -0.32, 2.36), BL + (0, 0, 0.06)], [0.024] * 3)
        return smin(d, torus(p, (0.86, -0.32, 2.38), 0.055, 0.022, frame((1, -0.4, 0))), 0.01)

    def bell(p):
        return sphere(p, BL, 0.075)

    def bell_x(p):
        reg = np.maximum(cross2(p[0] - BL[0], p[2] - BL[2], 0.035, 0.008), p[1] - BL[1])
        return overlay(bell(p), reg, 0.006, depth=0.02, k=0.002)

    def tassel(p):
        d = round_cone(p, BL + (0, 0, -0.07), BL + (0.02, 0, -0.34), 0.03, 0.06)
        return d - 0.008 * np.abs(np.sin(np.arctan2(p[0] - BL[0], p[1] - BL[1]) * 10))

    def scarf_tassels(p):
        d = tassel(p)
        for c in (np.array([-0.16, -0.5, 1.12]), np.array([0.02, -0.52, 1.1])):
            t = round_cone(p, c, c + (0, -0.01, -0.22), 0.028, 0.05)
            d = np.minimum(d, t - 0.008 * np.abs(np.sin(np.arctan2(p[0] - c[0], p[1] - c[1]) * 10)))
        return d

    def capelet_shape(p):
        q = (p[0], p[1] / 0.9, p[2])
        d = round_cone(q, (0, 0.04, 1.5), (0, 0.04, 1.02), 0.4, 0.66)
        d = smax(d, 0.96 - p[2] + 0.04 * np.cos(np.arctan2(p[0], -p[1]) * 5), 0.04)
        return smax(d, p[2] - 1.6, 0.05)

    def capelet(p):
        return capelet_shape(p) - fuzz(p, 86)

    def cape_trim(p):
        return overlay(capelet_shape(p), p[2] - 1.04 - 0.04 * np.cos(np.arctan2(p[0], -p[1]) * 5), 0.03, depth=0.05,
                       k=0.02) - fuzz(p, 87, 0.007)

    def pompoms(p):
        d = union_all([sphere(p, (sx * 0.74, -0.12, 1.16), 0.14) for sx in (-1, 1)])
        cords = union_all([tube(p, [(sx * 0.62, -0.1, 1.6), (sx * 0.72, -0.14, 1.36), (sx * 0.74, -0.12, 1.28)],
                                [0.02] * 3) for sx in (-1, 1)])
        return smin(d - fuzz(p, 88, 0.01), cords, 0.02)

    def scarf(p):
        wrap = torus(p, (0, -0.04, 1.46), 0.36, 0.1, rot(-12, 0, 0))
        knot = ellipsoid(p, (-0.08, -0.44, 1.36), (0.12, 0.08, 0.1))
        tails = np.minimum(tube(p, [(-0.08, -0.44, 1.36), (-0.14, -0.5, 1.22), (-0.16, -0.5, 1.13)], [0.05, 0.05, 0.045]),
                           tube(p, [(-0.06, -0.44, 1.36), (0.0, -0.52, 1.22), (0.02, -0.52, 1.12)], [0.05, 0.05, 0.045]))
        return union_all([wrap, knot, tails], 0.03) - 0.006 * np.abs(np.sin(p[2] * 60))

    def torso(p):
        return ellipsoid(p, (0, 0.02, 1.08), (0.38, 0.32, 0.38))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.34, 0.0, 1.34), (sx * 0.46, -0.02, 1.08), (sx * 0.48, -0.06, 0.9)],
                            [0.16, 0.16, 0.15], (sx * 0.5, -0.08, 0.8), (sx * 0.1, 0, -1.0), thumb=(-sx * 0.2, -1, 0)))

    def jacket_fn(p):
        d = smax(torso(p), p[2] - 1.42, 0.05)
        d = smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.04)
        return d - fuzz(p, 89, 0.006)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    def pants(p):
        low = smax(ellipsoid(p, (0, 0.02, 0.9), (0.4, 0.33, 0.28)), p[2] - 1.0, 0.04)
        legs_ = fold(lambda q: round_cone(q, (0.18, 0.0, 0.84), (0.22, -0.02, 0.36), 0.22, 0.19))(p)
        return smax(smin(low, legs_, 0.08), 0.3 - p[2], 0.03) - 0.006 * np.abs(np.sin(p[2] * 30 + p[0] * 5))

    tail_path = [(0.0, 0.36, 0.86), (-0.34, 0.68, 0.6), (-0.72, 0.54, 0.42), (-0.9, 0.16, 0.5)]

    def tail_shape(p):
        return tube(p, tail_path, [0.12, 0.27, 0.26, 0.06], k=0.08)

    def tail(p):
        return tail_shape(p) - fuzz(p, 90, 0.008)

    def tail_tip(p):
        return overlay(tail_shape(p), -(-p[0] - 0.7), 0.035, depth=0.06, k=0.04) - fuzz(p, 91, 0.006)

    SC = np.array([0.46, -0.3, 0.92])
    RS = rot(0, 0, -30)

    def satchel(p):
        bag = round_box(p, SC, (0.18, 0.08, 0.15), 0.06, RS)
        strap = tube(p, [(-0.3, -0.25, 1.5), (0.0, -0.44, 1.28), (0.3, -0.38, 1.06), SC + RS @ np.array([-0.1, 0, 0.14])],
                     [0.03] * 4, k=0.01)
        return np.minimum(bag, strap)

    def satchel_flap(p):
        x, y, z = local(p, SC, RS)
        region = np.maximum(np.maximum(-0.0 - z, y), np.abs(x) - 0.19)
        bag = round_box(p, SC, (0.18, 0.08, 0.15), 0.06, RS)
        return overlay(bag, region, 0.018, depth=0.04, k=0.01)

    def satchel_button(p):
        return ellipsoid(p, SC + RS @ np.array([0.0, -0.11, -0.02]), (0.04, 0.02, 0.04))

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Hood", hood, fur, voxel=0.0075, tris=16000),
        Comp(f"{N}_HoodTrim", trim, trim_m, voxel=0.006, tris=9000),
        Comp(f"{N}_Ears", ear_fn, fur, voxel=0.006, tris=4000),
        Comp(f"{N}_EarInner", ear_inner, trim_m, voxel=0.005, tris=2500),
        Comp(f"{N}_EarTips", ear_tips, tip_m, voxel=0.005, tris=2500),
        Comp(f"{N}_Stitches", stitches, stitch_m, voxel=0.004, tris=3000),
        Comp(f"{N}_Mask", mask, mask_m, voxel=0.004, tris=5000),
        Comp(f"{N}_MaskPaint", mask_paint, mask_red, voxel=0.003, tris=2000),
        Comp(f"{N}_MaskEyes", mask_eyes, mask_dark, voxel=0.003, tris=1200),
        Comp(f"{N}_Cord", cord, scarf_m, voxel=0.004, tris=2000),
        Comp(f"{N}_Bell", bell, bell_m, voxel=0.004, tris=1500),
        Comp(f"{N}_BellMark", bell_x, mask_dark, voxel=0.003, tris=500),
        Comp(f"{N}_Tassels", scarf_tassels, scarf_m, voxel=0.004, tris=4000),
        Comp(f"{N}_Capelet", capelet, fur, voxel=0.007, tris=10000),
        Comp(f"{N}_CapeTrim", cape_trim, trim_m, voxel=0.006, tris=7000),
        Comp(f"{N}_Pompoms", pompoms, trim_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Scarf", scarf, scarf_m, voxel=0.006, tris=7000),
        Comp(f"{N}_Jacket", jacket_fn, jacket, voxel=0.007, tris=9000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=3000),
        Comp(f"{N}_Pants", pants, jacket, voxel=0.007, tris=8000),
        Comp(f"{N}_Tail", tail, fur, voxel=0.007, tris=8000),
        Comp(f"{N}_TailTip", tail_tip, trim_m, voxel=0.006, tris=5000),
        Comp(f"{N}_Satchel", satchel, leather, voxel=0.005, tris=4000),
        Comp(f"{N}_SatchelFlap", satchel_flap, leather, voxel=0.004, tris=2000),
        Comp(f"{N}_SatchelButton", satchel_button, trim_m, voxel=0.003, tris=500),
    ]
    comps += standing_feet(N, skin, sock_m, shoe_m, sole_m, stitch=stitch_m, sock_z=0.36)
    comps += kid_face(N, head, fm, **face_z(H), brows=(0.21, 0.06, 0.026, 4.0), look=0.3, lid=0.5)
    return assemble(N, "Mask Nuzzle", "Rare", comps, {}, ((-1.5, -1.3, -0.2), (1.4, 1.4, 3.6)),
                    catalog="echo.mask-nuzzle")


# ---------------------------------------------------------------- Mumble Beast

def boucle(p, seed, amp=0.012):
    """Looped boucle yarn surface (positive = outward)."""
    return amp * np.abs(waves(p, 34.0, seed)) + amp * 0.5 * waves(p, 80.0, seed + 1)


def mumble_beast():
    N = "MumbleBeast"
    fm = face_mats(N, iris=("#1E1A12", "#29251A", "#4C4A33", "#625F44", "#2E2C1E"), brow="#C9A587")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#DED2BD", rough=0.55, coat=0.08))
    fluff = (f"{N}_Boucle", Mat("#8A6853", rough=0.95))
    cream = (f"{N}_Cream", Mat("#EBDDC4", rough=0.75))
    horn_m = (f"{N}_Horns", Mat("#E8DAC0", rough=0.5, coat=0.2))
    x_m = (f"{N}_Stitches", Mat("#D08A67", rough=0.7))
    seam_m = (f"{N}_Seam", Mat("#D9BA94", rough=0.7))
    dot_m = (f"{N}_Dots", Mat("#3B302A", rough=0.4, coat=0.3))
    pom_m = (f"{N}_Pompoms", Mat("#A55A48", rough=0.95))
    cord_m = (f"{N}_Cords", Mat("#B07D5C", rough=0.7))

    H = 1.93
    head = Head(c=(0.0, -0.07, H))
    HC = np.array([0.0, 0.12, 2.2])
    HR = (0.98, 0.92, 0.86)

    def edge_z(x):
        return 1.82 + 0.56 * np.sqrt(np.clip(1 - (x / 0.6) ** 2, 0, 1))

    def face_hole(p):
        return np.maximum(ellipse2(p[0], p[2] - 1.82, 0.6, 0.56), p[1] + 0.0)

    def hood_shape(p):
        d = ellipsoid(p, HC, HR)
        d = smax(d, 1.4 - p[2], 0.08)
        return smax(d, -face_hole(p), 0.07)

    def hood(p):
        rim = 0.05 * np.exp(-(face_hole(p) / 0.08) ** 2) * np.clip((p[2] - 1.48) / 0.1, 0, 1)
        return hood_shape(p) - rim - boucle(p, 101)

    def teeth(p):
        x, z = p[0], p[2]
        w = 0.15
        fu = x / w - np.floor(x / w) - 0.5
        rel = z - edge_z(x) + 0.03
        region = np.maximum(np.maximum(0.13 * np.abs(2 * fu) - rel, rel - 0.13), np.abs(x) - 0.56)
        region = np.maximum(region, p[1] + 0.2)
        return overlay(hood_shape(p) - 0.04, region, 0.05, depth=0.06, k=0.008)

    ear_c = [np.array([sx * 0.94, 0.04, 2.62]) for sx in (-1, 1)]

    def ears(p):
        d = union_all([ellipsoid(p, c, (0.15, 0.25, 0.26), rot(0, 0, -np.sign(c[0]) * 25)) for c in ear_c])
        return d - boucle(p, 103)

    ear_t = [Tangent(lambda p: union_all([ellipsoid(p, c, (0.15, 0.25, 0.26), rot(0, 0, -np.sign(c[0]) * 25))
                                          for c in ear_c]), c - np.array([np.sign(c[0]) * 0.02, -0.0, 0]),
                     (np.sign(c[0]) * 0.4, -1, 0.05)) for c in ear_c]

    def x_marks(p):
        reg = union_all([t.region(p, lambda u, v: cross2(u, v, 0.075, 0.02)) for t in ear_t])
        ear_x = overlay(ears(p) + 0.012, reg, 0.03, depth=0.04, k=0.004)
        return ear_x

    def horns(p):
        return union_all([tube(p, [(sx * 0.42, 0.06, 2.92), (sx * 0.56, 0.02, 3.12), (sx * 0.52, -0.06, 3.3)],
                               [0.12, 0.08, 0.025], k=0.02) for sx in (-1, 1)])

    def dots(p):
        return union_all([sphere(p, surface_point(hood_shape, (sx * 0.22, 0.0, 2.8), (sx * 0.15, -1, 0.35)), 0.05)
                          for sx in (-1, 1)])

    def seam(p):
        reg = np.maximum(np.abs(p[0]) - 0.008, 0.25 - p[1])
        dash = np.maximum(np.maximum(np.abs(p[0]) - 0.04, np.cos(p[2] * 40) - 0.85), 0.25 - p[1])
        reg = np.minimum(reg, dash)
        reg = np.maximum(reg, np.maximum(0.5 - p[2], p[2] - 3.0))
        base = np.minimum(hood_shape(p), ellipsoid(p, (0, 0.02, 1.0), (0.44, 0.36, 0.5)))
        return overlay(base, reg, 0.03, depth=0.05, k=0.003)

    hair_c = np.array([0.0, 0.03, 2.02])
    hair_r = (0.8, 0.76, 0.7)
    hair_shell = Hair(hair_c, hair_r, hem=[(0, 2.1), (25, 2.04), (50, 1.7), (80, 1.46), (180, 1.32)],
                      locks=18, tip=0.12, groove=0.04, puff=0.03, swing=6.0, opening=(1.72, 0.5, 0.4, -0.1))
    bangs = fringe(hair_c, hair_r, [(-38, 2.32, 1.92, 0.16, -12), (-18, 2.36, 1.98, 0.15, 12), (2, 2.36, 2.04, 0.15, 16),
                                    (22, 2.32, 1.94, 0.15, 14), (42, 2.26, 1.84, 0.15, 10)], thick=0.07, lift=0.06)

    def hair(p):
        d = smin(hair_shell(p) - 0.02 * waves(p, 12.0, 104), bangs(p), 0.03)
        return smax(d, -(hood_shape(p) - 0.01), 0.02)

    def torso(p):
        return ellipsoid(p, (0, 0.02, 1.0), (0.44, 0.36, 0.5))

    # Character's right arm hangs; the left paw is raised to the mouth.
    arm_r = ([(-0.38, 0.0, 1.32), (-0.52, -0.05, 1.04), (-0.54, -0.1, 0.86)], [0.16, 0.15, 0.14])
    arm_l = ([(0.38, 0.0, 1.32), (0.46, -0.3, 1.1), (0.2, -0.56, 1.38), (0.08, -0.62, 1.48)], [0.16, 0.15, 0.14, 0.13])
    paws = [(np.array([-0.55, -0.12, 0.76]), np.array([0, -0.2, -1.0])), (np.array([0.04, -0.68, 1.56]), np.array([-0.3, -0.4, 1.0]))]

    def suit_shape(p):
        d = smax(torso(p), p[2] - 1.44, 0.06)
        for pts, rs in (arm_r, arm_l):
            d = smin(d, tube(p, pts, rs, k=0.03), 0.05)
        for c, down in paws:
            d = smin(d, ellipsoid(p, c, (0.13, 0.12, 0.15), frame(down)), 0.04)
        legs_ = fold(lambda q: round_cone(q, (0.2, 0.0, 0.78), (0.24, -0.02, 0.3), 0.23, 0.21))(p)
        d = smin(d, legs_, 0.08)
        feet = fold(lambda q: ellipsoid(q, (0.25, -0.12, 0.16), (0.21, 0.3, 0.17)))(p)
        d = smin(d, feet, 0.08)
        d = smin(d, sphere(p, (0.0, 0.44, 0.66), 0.16), 0.04)
        return smax(d, -p[2], 0.01)

    def suit(p):
        return suit_shape(p) - boucle(p, 105)

    claw_pts = []
    for sx in (-1, 1):
        for k in (-1, 0, 1):
            claw_pts.append((np.array([sx * 0.25 + k * 0.1, -0.4 + 0.02 * abs(k), 0.08]), 0.055))
    for c, down in paws:
        R = frame(down)
        for k in (-1, 0, 1):
            claw_pts.append((c + R @ np.array([k * 0.07, -0.08, 0.12]), 0.035))

    def claws(p):
        return union_all([ellipsoid(p, c, (r, r * 1.1, r)) for c, r in claw_pts])

    belly_t = Tangent(torso, (0, 0.0, 0.94), (0, -1, 0))

    def belly(p):
        return overlay(suit_shape(p) - 0.012, belly_t.region(p, lambda u, v: ellipse2(u, v, 0.24, 0.32)), 0.02, depth=0.05,
                       k=0.01) - 0.004 * waves(p, 50.0, 106)

    def belly_marks(p):
        def mark(u, v):
            edge = np.maximum(np.abs(ellipse2(u, v, 0.2, 0.28)) - 0.008, np.cos(np.arctan2(v, u) * 22) - 0.1)
            return np.minimum(edge, cross2(u - 0.1, v + 0.12, 0.05, 0.013))
        return overlay(belly(p), belly_t.region(p, mark), 0.008, depth=0.02, k=0.002)

    knee_t = [Tangent(suit_shape, (sx * 0.24, 0.0, 0.42), (sx * 0.3, -1, 0)) for sx in (-1, 1)]

    def knee_patches(p):
        reg = union_all([t.region(p, lambda u, v: rect2(u, v, 0.09, 0.08, 0.02)) for t in knee_t])
        return overlay(suit_shape(p), reg, 0.026, depth=0.05, k=0.006)

    def knee_x(p):
        reg = union_all([t.region(p, lambda u, v: cross2(u, v, 0.05, 0.013)) for t in knee_t])
        tail_t = np.maximum(cross2(p[0], p[2] - 0.66, 0.06, 0.015), 0.5 - p[1])
        return np.minimum(overlay(knee_patches(p), reg, 0.008, depth=0.02, k=0.002),
                          overlay(suit_shape(p), tail_t, 0.035, depth=0.05, k=0.003))

    def pompoms(p):
        d = None
        for c, r, top in (((-0.66, -0.28, 1.16), 0.12, (-0.5, -0.36, 1.56)), ((0.62, -0.3, 1.2), 0.11, (0.48, -0.38, 1.56)),
                          ((-0.3, -0.5, 1.04), 0.08, (-0.3, -0.48, 1.44))):
            e = sphere(p, c, r)
            d = e if d is None else np.minimum(d, e)
        return d - boucle(p, 107, 0.01)

    def cords(p):
        return union_all([tube(p, [top, (np.array(c) + np.array(top)) / 2 + np.array([0, -0.03, 0]), c], [0.02] * 3)
                          for c, top in (((-0.66, -0.28, 1.24), (-0.5, -0.36, 1.56)), ((0.62, -0.3, 1.28), (0.48, -0.38, 1.56)),
                                         ((-0.3, -0.5, 1.1), (-0.3, -0.48, 1.44)))])

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Hood", hood, fluff, voxel=0.0075, tris=19000),
        Comp(f"{N}_Teeth", teeth, cream, voxel=0.004, tris=3000),
        Comp(f"{N}_Ears", ears, fluff, voxel=0.006, tris=5000),
        Comp(f"{N}_EarStitch", x_marks, x_m, voxel=0.004, tris=1500),
        Comp(f"{N}_Horns", horns, horn_m, voxel=0.005, tris=3000),
        Comp(f"{N}_HoodEyes", dots, dot_m, voxel=0.004, tris=800),
        Comp(f"{N}_Seam", seam, seam_m, voxel=0.004, tris=3000),
        Comp(f"{N}_Suit", suit, fluff, voxel=0.0075, tris=19500),
        Comp(f"{N}_Claws", claws, cream, voxel=0.004, tris=3000),
        Comp(f"{N}_Belly", belly, cream, voxel=0.005, tris=5000),
        Comp(f"{N}_BellyStitch", belly_marks, x_m, voxel=0.0035, tris=2500),
        Comp(f"{N}_KneePatches", knee_patches, x_m, voxel=0.004, tris=1500),
        Comp(f"{N}_KneeStitch", knee_x, seam_m, voxel=0.0035, tris=1500),
        Comp(f"{N}_Pompoms", pompoms, pom_m, voxel=0.004, tris=7000),
        Comp(f"{N}_Cords", cords, cord_m, voxel=0.004, tris=2000),
    ]
    comps += kid_face(N, head, fm, **face_z(H), brows=(0.21, 0.06, 0.026, 4.0), look=0.3, lid=0.5)
    return assemble(N, "Mumble Beast", "Legendary", comps, {}, ((-1.4, -1.3, -0.2), (1.4, 1.3, 3.6)),
                    catalog="echo.mumble-beast")


# ---------------------------------------------------------------- Feather Hush

def feather_hush():
    N = "FeatherHush"
    fm = face_mats(N, iris=("#1E1A12", "#29251A", "#4A4836", "#5E5B46", "#2E2C1E"), brow="#C07F62")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#B25F43", rough=0.6, coat=0.08))
    hood_m = (f"{N}_Hood", Mat("#3A3634", rough=0.85))
    feather_m = (f"{N}_Feathers", Mat("#45413E", rough=0.8))
    beak_m = (f"{N}_Beak", Mat("#69635D", rough=0.6, coat=0.1))
    button_m = (f"{N}_Button", Mat("#B89470", rough=0.5, coat=0.15))
    dark = (f"{N}_ButtonHoles", Mat("#3A2E28", rough=0.5))
    gold = (f"{N}_Gold", Mat("#C9A25B", rough=0.3, metal=0.75))
    berry_m = (f"{N}_Berry", Mat("#B5382F", rough=0.3, coat=0.4))
    leaf_m = (f"{N}_Leaf", Mat("#6E7A55", rough=0.6))
    stitch_m = (f"{N}_Stitch", Mat("#B89874", rough=0.7))
    tunic_m = (f"{N}_Tunic", Mat("#8D8473", rough=0.85))
    leather = (f"{N}_Satchel", Mat("#6B4A36", rough=0.55, coat=0.12))
    sock_m = (f"{N}_Socks", Mat("#E6DBC6", rough=0.85))
    shoe_m = (f"{N}_Boots", Mat("#4A3A32", rough=0.45, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#2F2520", rough=0.6))

    H = 2.08
    head = Head(c=(0.0, -0.07, H))
    HC = np.array([0.0, 0.14, 2.3])
    HR = (0.94, 0.92, 0.86)

    def face_hole(p):
        return np.maximum(ellipse2(p[0], p[2] - 1.9, 0.6, 0.52), p[1] + 0.0)

    def hood_shape(p):
        d = ellipsoid(p, HC, HR)
        d = smax(d, 1.42 - p[2], 0.08)
        return smax(d, -face_hole(p), 0.07)

    beak = Leaf((0.0, -0.3, 2.9), (0.0, -1.12, 2.34), 0.44, 0.11, (0, -0.45, 1.0), mid=0.22, r_base=0.42,
                r_tip=0.03, bend=-0.08, crease=0.0)

    def hood(p):
        return hood_shape(p)

    hood_feathers = []
    rng = np.random.default_rng(5)
    for el, count, phase in ((58, 9, 0), (36, 13, 12), (14, 15, 5), (-8, 16, 15), (-28, 16, 0)):
        for i in range(count):
            az = (phase + i * 360.0 / count + rng.uniform(-5, 5) + 180) % 360 - 180
            if abs(az) < 58 and el < 40:
                continue
            base = HC + sph_dir(az, el) * np.array(HR) * 1.0
            tip = HC + sph_dir(az + rng.uniform(-6, 6), el - 30) * np.array(HR) * 1.1
            nrm = unit(0.5 * (base + tip) - HC)
            hood_feathers.append(Leaf(base, tip, 0.15, 0.045, nrm, mid=0.45, r_base=0.08, r_tip=0.04, bend=0.04,
                                      crease=0.015))

    cloak_c = np.array([0.0, 0.06, 0.0])

    def cloak_shape(p):
        q = (p[0], (p[1] - 0.06) / 0.9, p[2])
        d = round_cone(q, (0, 0, 1.5), (0, 0, 0.4), 0.42, 0.82)
        d = smax(d, 0.32 - p[2], 0.04)
        d = smax(d, p[2] - 1.62, 0.05)
        az = np.degrees(np.abs(np.arctan2(p[0], -(p[1] - 0.06))))
        opening = np.maximum((az - 30) * 0.0105, p[2] - 1.42)  # open down the front
        return smax(d, -opening, 0.02)

    cloak_feathers = []
    for z, count, phase, L in ((1.5, 12, 0, 0.36), (1.26, 15, 10, 0.4), (1.0, 17, 4, 0.42), (0.76, 19, 14, 0.42),
                               (0.54, 20, 6, 0.4)):
        for i in range(count):
            az = (phase + i * 360.0 / count + rng.uniform(-4, 4) + 180) % 360 - 180
            if abs(az) < 34 and z < 1.45:
                continue
            r_at = 0.42 + (0.82 - 0.42) * (1.5 - z) / 1.1
            a = math.radians(az)
            base = np.array([math.sin(a) * r_at, 0.06 - math.cos(a) * r_at * 0.9, z]) * np.array([1.06, 1.06, 1.0])
            r_tip = 0.42 + (0.82 - 0.42) * (1.5 - (z - L)) / 1.1
            tip = np.array([math.sin(a) * r_tip * 1.12, 0.06 - math.cos(a) * r_tip * 1.0, z - L])
            nrm = unit(np.array([math.sin(a), -math.cos(a), 0.25]))
            cloak_feathers.append(Leaf(base, tip, 0.13, 0.045, nrm, mid=0.45, r_base=0.07, r_tip=0.035, bend=0.04,
                                       crease=0.015))

    def feathers_hood(p):
        d = union_all([lf(p) for lf in hood_feathers])
        return smax(d, -(face_hole(p) + 0.04), 0.02)

    def feathers_cloak(p):
        return union_all([lf(p) for lf in cloak_feathers])

    BT = surface_point(hood_shape, HC + (0, 0, 0.3), sph_dir(-42, 22)) + sph_dir(-42, 22) * 0.07
    RBT = frame(unit(BT - HC))

    def button(p):
        u, v, w = local(p, BT, RBT)
        d = cylinder((u, v, w), (0, 0, 0), 0.15, 0.035, 0.025)
        return smin(d, torus((u, v, w), (0, 0, 0.03), 0.12, 0.02), 0.01)

    def button_holes(p):
        u, v, w = local(p, BT, RBT)
        holes = union_all([np.sqrt((u - a) ** 2 + (v - b) ** 2) - 0.024 for a, b in ((0.04, 0.04), (-0.04, -0.04),
                                                                                      (0.04, -0.04), (-0.04, 0.04))])
        thread = cross2(u, v, 0.045, 0.011)
        return overlay(button(p), np.maximum(np.minimum(holes, thread), -w), 0.008, depth=0.02, k=0.002)

    CH = [BT + np.array([-0.06, -0.1, -0.2]), np.array([-0.62, -0.6, 2.36]), np.array([-0.64, -0.64, 2.2])]

    def charm_chain(p):
        d = tube(p, [BT + np.array([0, -0.02, -0.1])] + CH[:2], [0.018] * 3)
        d = np.minimum(d, torus(p, CH[1] + (0, 0, -0.06), 0.06, 0.016, frame((0.3, -1, 0))))
        return d

    def berry(p):
        return sphere(p, CH[2] + (0, 0, -0.08), 0.09)

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.32, 0.0, 1.4), (sx * 0.42, -0.12, 1.14), (sx * 0.24, -0.38, 1.16),
                             (sx * 0.15, -0.44, 1.2)], [0.12, 0.12, 0.11, 0.1], (sx * 0.1, -0.5, 1.24),
                            (-sx, -0.3, 0.2), thumb=(0, -0.3, 1), hand_r=(0.09, 0.075, 0.1)))

    def tunic(p):
        q = (p[0], p[1] / 0.85, p[2])
        d = round_cone(q, (0, 0, 1.42), (0, 0, 0.66), 0.34, 0.46)
        d = smax(smax(d, 0.56 - p[2], 0.04), p[2] - 1.52, 0.05)
        return smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.04) - 0.004 * waves(p, 15.0, 111)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    AP = np.array([0.0, -0.6, 1.28])

    def apple(p):
        d = sphere(p, AP, 0.13)
        return smax(d, -sphere(p, AP + (0, 0, 0.15), 0.05), 0.04)

    def apple_leaf(p):
        stem = round_cone(p, AP + (0, 0, 0.09), AP + (0.02, 0, 0.18), 0.012, 0.01)
        lf = Leaf(AP + (0.02, 0, 0.15), AP + (0.13, -0.04, 0.22), 0.04, 0.012, (0, -0.4, 1), mid=0.45, r_base=0.01,
                  r_tip=0.01)(p)
        lf2 = Leaf(AP + (-0.01, 0, 0.15), AP + (-0.1, -0.06, 0.2), 0.035, 0.012, (0, -0.4, 1), mid=0.45, r_base=0.01,
                   r_tip=0.01)(p)
        return union_all([stem, lf, lf2])

    SC = np.array([-0.24, -0.36, 0.7])
    RS = rot(0, 0, 18)

    def satchel(p):
        bag = round_box(p, SC, (0.2, 0.08, 0.16), 0.06, RS)
        strap = tube(p, [(0.3, -0.26, 1.48), (0.16, -0.42, 1.2), (-0.08, -0.44, 0.96), SC + RS @ np.array([0.1, 0, 0.15])],
                     [0.028] * 4, k=0.01)
        back = tube(p, [(0.3, 0.1, 1.5), (0.0, 0.42, 1.2), (-0.36, 0.3, 0.9), SC + RS @ np.array([-0.15, 0.04, 0.14])],
                    [0.028] * 4, k=0.01)
        return union_all([bag, strap, back])

    def satchel_rings(p):
        rings = [torus(p, SC + RS @ np.array([sx * 0.09, -0.1, -0.03]), 0.04, 0.012, RS @ rot(90, 0, 0)) for sx in (-1, 1)]
        return union_all(rings)

    def satchel_flower(p):
        u, v = p[0] - SC[0] + 0.05, p[2] - SC[2] + 0.06
        petals = union_all([ellipse2(u - 0.025 * math.cos(a), v - 0.025 * math.sin(a), 0.02, 0.02)
                            for a in (0.8, 2.4, 3.9, 5.5)])
        bag = round_box(p, SC, (0.2, 0.08, 0.16), 0.06, RS)
        return overlay(bag, np.maximum(petals, p[1] - SC[1]), 0.008, depth=0.02, k=0.002)

    x_spots = [(-30, 52), (28, 50), (-100, 30), (130, 36), (165, 10), (-150, 20)]
    x_t = [Tangent(hood_shape, HC, sph_dir(a, e)) for a, e in x_spots]
    cx_t = [(np.array([sx * 0.62, -0.32, z]), np.array([sx * 0.5, -1, 0.2])) for sx, z in ((-1, 1.18), (1, 0.62), (-1, 0.5))]

    def x_stitches(p):
        reg = union_all([t.region(p, lambda u, v: cross2(u, v, 0.05, 0.012)) for t in x_t])
        hood_x = overlay(hood_shape(p), reg, 0.07, depth=0.06, k=0.003)
        cl = []
        for c, n in cx_t:
            R = frame(unit(n))
            u, v, w = local(p, c, R)
            cl.append(np.maximum(cross2(u, v, 0.045, 0.011), np.abs(w) - 0.12))
        cloak_x = overlay(feathers_cloak(p), union_all(cl), 0.012, depth=0.03, k=0.003)
        return np.minimum(hood_x, cloak_x)

    hair_c = np.array([0.0, 0.03, 2.14])
    hair_r = (0.8, 0.76, 0.7)
    hair_shell = Hair(hair_c, hair_r, hem=[(0, 2.2), (25, 2.14), (50, 1.8), (80, 1.55), (180, 1.4)],
                      locks=18, tip=0.12, groove=0.04, puff=0.03, swing=6.0, opening=(1.84, 0.5, 0.4, -0.1))
    bangs = fringe(hair_c, hair_r, [(-38, 2.4, 2.02, 0.16, -12), (-18, 2.42, 2.08, 0.15, 12), (2, 2.42, 2.12, 0.15, 16),
                                    (22, 2.4, 2.04, 0.15, 14), (42, 2.34, 1.94, 0.15, 10),
                                    (-54, 2.2, 1.66, 0.14, -4), (54, 2.2, 1.66, 0.14, 6)], thick=0.07, lift=0.06)

    def hair(p):
        d = smin(hair_shell(p) - 0.02 * waves(p, 12.0, 112), bangs(p), 0.03)
        return smax(d, -(hood_shape(p) - 0.01), 0.02)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Hood", hood, hood_m, voxel=0.0075, tris=12000),
        Comp(f"{N}_Beak", beak, beak_m, voxel=0.006, tris=4000),
        Comp(f"{N}_HoodFeathers", feathers_hood, feather_m, voxel=0.0065, tris=19500),
        Comp(f"{N}_Cloak", cloak_shape, hood_m, voxel=0.0075, tris=8000),
        Comp(f"{N}_CloakFeathers", feathers_cloak, feather_m, voxel=0.0065, tris=19500),
        Comp(f"{N}_Button", button, button_m, voxel=0.004, tris=3000),
        Comp(f"{N}_ButtonThread", button_holes, dark, voxel=0.003, tris=1200),
        Comp(f"{N}_Chain", charm_chain, gold, voxel=0.0035, tris=2500),
        Comp(f"{N}_Berry", berry, berry_m, voxel=0.004, tris=1500),
        Comp(f"{N}_Stitches", x_stitches, stitch_m, voxel=0.0035, tris=3000),
        Comp(f"{N}_Tunic", tunic, tunic_m, voxel=0.007, tris=9000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=3500),
        Comp(f"{N}_Apple", apple, berry_m, voxel=0.004, tris=3000),
        Comp(f"{N}_AppleLeaf", apple_leaf, leaf_m, voxel=0.003, tris=1500),
        Comp(f"{N}_Satchel", satchel, leather, voxel=0.005, tris=5000),
        Comp(f"{N}_SatchelRings", satchel_rings, gold, voxel=0.003, tris=1500),
        Comp(f"{N}_SatchelFlower", satchel_flower, stitch_m, voxel=0.003, tris=600),
    ]
    comps += standing_feet(N, skin, sock_m, shoe_m, sole_m, stitch=stitch_m, sock_z=0.34)
    comps += kid_face(N, head, fm, **face_z(H), brows=(0.21, 0.06, 0.026, 4.0), look=0.3, lid=0.5)
    return assemble(N, "Feather Hush", "Legendary", comps, {}, ((-1.5, -1.4, -0.2), (1.5, 1.4, 3.6)),
                    catalog="echo.feather-hush")


# ---------------------------------------------------------------- Hush Veil

def plus2(u, v, s, th):
    return np.minimum(rect2(u, v, th, s, th), rect2(u, v, s, th, th))


def hush_veil():
    N = "HushVeil"
    fm = face_mats(N, iris=("#1E1A12", "#29251A", "#4A4836", "#5E5B46", "#2E2C1E"), brow="#B9AF95")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#B7CBB6", rough=0.55, coat=0.08))
    blanket_m = (f"{N}_Blanket", Mat("#ECE4D4", rough=0.95))
    star_m = (f"{N}_FeltStars", Mat("#B3C6B1", rough=0.9))
    stitch_m = (f"{N}_Stitch", Mat("#C8B394", rough=0.7))
    mint_x = (f"{N}_MintStitch", Mat("#9DB59B", rough=0.7))
    clasp_m = (f"{N}_Clasp", Mat("#E0CFAE", rough=0.75))
    button_m = (f"{N}_Button", Mat("#BCA684", rough=0.5, coat=0.15))
    leaf_m = (f"{N}_Leaves", Mat("#A6BA9C", rough=0.8))
    inner_m = (f"{N}_Tunic", Mat("#E7DECB", rough=0.9))
    sock_m = (f"{N}_Socks", Mat("#EDE4D1", rough=0.9))
    boot_m = (f"{N}_Boots", Mat("#8E867B", rough=0.6, coat=0.1))
    sole_m = (f"{N}_Sole", Mat("#6E675E", rough=0.6))

    H = 1.81
    head = Head(c=(0.0, -0.07, H))
    HC = np.array([0.0, 0.12, 2.1])
    HR = (0.86, 0.9, 0.9)

    def face_hole(p):
        return np.maximum(ellipse2(p[0], p[2] - 1.74, 0.6, 0.6), p[1] + 0.0)

    def front_gap(p):
        az = np.degrees(np.abs(np.arctan2(p[0], -(p[1] - 0.15))))
        widen = 18.0 * np.clip((1.32 - p[2]) / 1.32, 0, 1)
        return np.maximum((az - 24 - widen) * 0.012, p[2] - 1.3)

    def blanket_shape(p):
        az = np.arctan2(p[0], -(p[1] - 0.15))
        hood = ellipsoid(p, HC, HR)
        drop = np.clip((1.8 - p[2]) / 1.6, 0, 1)
        q = (p[0], (p[1] - 0.15) / 0.86 + 0.15, p[2])
        bell = round_cone(q, (0, 0.15, 1.85), (0, 0.15, 0.22), 0.72, 1.12)
        d = smin(hood, bell, 0.25)
        d = d - 0.13 * drop ** 1.3 * np.cos(az * 6 + 0.6) ** 2 - 0.04 * drop * np.cos(az * 13 + 1.7)  # draped folds
        d = smax(d, -p[2], 0.02)
        d = smax(d, -face_hole(p), 0.07)
        return smax(d, -front_gap(p), 0.06)

    def blanket(p):
        rim = 0.05 * np.exp(-(face_hole(p) / 0.08) ** 2) * np.clip((p[2] - 1.3) / 0.1, 0, 1)
        edge = 0.04 * np.exp(-(front_gap(p) / 0.07) ** 2) + 0.04 * np.exp(-(p[2] / 0.08) ** 2)
        return blanket_shape(p) - rim - edge - 0.003 * waves(p, 50.0, 121)

    def dashes(p):
        az = np.arctan2(p[0], -(p[1] - 0.15))
        band_face = np.abs(face_hole(p) + 0.1) - 0.017
        band_gap = np.abs(front_gap(p) + 0.1) - 0.017
        band_hem = np.abs(p[2] - 0.13) - 0.017
        band_back = np.maximum(np.abs(p[0]) - 0.017, 0.3 - p[1])
        band = np.minimum(np.minimum(np.minimum(band_face, band_gap), band_hem), band_back)
        dash = (np.cos(az * 48 + p[2] * 48) - 0.2) * 0.03  # soft-ended dashes, roughly distance-scaled
        return overlay(blanket_shape(p) - 0.03, smax(band, dash, 0.008), 0.05, depth=0.05, k=0.006)

    star_t = [Tangent(blanket_shape, HC, sph_dir(-48, 32), spin=-10), Tangent(blanket_shape, HC, sph_dir(130, 10), spin=8),
              Tangent(blanket_shape, (0, 0.15, 0.8), (-1.0, -0.4, -0.1), spin=5)]

    def stars(p):
        reg = union_all([t.region(p, lambda u, v: star2(u, v, 0.15, 0.5)) for t in star_t])
        return overlay(blanket_shape(p) - 0.03, reg, 0.07, depth=0.05, k=0.02)

    plus_spots = [(-70, 10), (-64, 34), (62, 26), (70, -5), (-110, 30), (150, -10), (100, 40), (-160, 20), (0, 70)]
    plus_t = [Tangent(blanket_shape, HC, sph_dir(a, e)) for a, e in plus_spots]
    plus_low = [Tangent(blanket_shape, (0, 0.15, z), (math.sin(math.radians(a)), -math.cos(math.radians(a)), 0))
                for a, z in ((-50, 0.5), (60, 0.62), (120, 0.4), (-130, 0.7), (170, 0.35))]

    def plus_marks(p):
        reg = union_all([t.region(p, lambda u, v: plus2(u, v, 0.05, 0.012)) for t in plus_t + plus_low])
        return overlay(blanket_shape(p) - 0.03, reg, 0.042, depth=0.05, k=0.003)

    CL = np.array([0.0, -0.62, 1.1])

    def clasp(p):
        u, v = p[0] - CL[0], p[2] - CL[2]
        d2 = star2(u, v, 0.17, 0.55)
        w = p[1] - CL[1]
        return np.sqrt(np.maximum(d2, 0) ** 2 + np.maximum(np.abs(w) - 0.035, 0) ** 2) + \
            np.minimum(np.maximum(d2, np.abs(w) - 0.035), 0) - 0.02

    def clasp_stitch(p):
        u, v = p[0] - CL[0], p[2] - CL[2]
        band = np.maximum(np.abs(star2(u, v, 0.13, 0.55)) - 0.007, np.cos(np.arctan2(v, u) * 30) - 0.2)
        return overlay(clasp(p), np.maximum(band, p[1] - CL[1]), 0.008, depth=0.02, k=0.002)

    def clasp_button(p):
        return cylinder(p, CL + (0, -0.06, 0.0), 0.05, 0.02, 0.012, rot(90, 0, 0))

    leaves = [Leaf(CL + (-0.03, -0.02, -0.1), CL + (-0.16, -0.06, -0.38), 0.07, 0.025, (0, -1, 0), mid=0.45,
                   r_base=0.02, r_tip=0.02, crease=0.01),
              Leaf(CL + (0.03, -0.02, -0.1), CL + (0.12, -0.08, -0.36), 0.07, 0.025, (0, -1, 0), mid=0.45,
                   r_base=0.02, r_tip=0.02, crease=0.01)]

    def leaf_fn(p):
        return np.minimum(leaves[0](p), leaves[1](p))

    hair_c = np.array([0.0, 0.03, 1.88])
    hair_r = (0.78, 0.76, 0.7)
    hair_shell = Hair(hair_c, hair_r, hem=[(0, 1.98), (25, 1.92), (50, 1.56), (80, 1.3), (180, 1.2)],
                      locks=18, tip=0.14, groove=0.04, puff=0.03, swing=6.0, opening=(1.6, 0.5, 0.42, -0.1))
    bangs = fringe(hair_c, hair_r, [(-38, 2.2, 1.8, 0.16, -12), (-18, 2.22, 1.86, 0.15, 12), (2, 2.22, 1.9, 0.15, 16),
                                    (22, 2.2, 1.82, 0.15, 14), (42, 2.14, 1.72, 0.15, 10)], thick=0.07, lift=0.06)
    long_locks = [Leaf((sx * 0.5, -0.36, 1.62), (sx * 0.5, -0.44, 1.16), 0.09, 0.045, (sx * 0.4, -0.9, 0), mid=0.4,
                       r_base=0.07, r_tip=0.02, bend=0.03) for sx in (-1, 1)]

    def hair(p):
        d = smin(hair_shell(p) - 0.02 * waves(p, 12.0, 122), bangs(p), 0.03)
        d = smin(d, union_all([lf(p) for lf in long_locks]), 0.03)
        return smax(d, -(blanket_shape(p) - 0.01), 0.02)

    def tunic(p):
        return smax(ellipsoid(p, (0, 0.05, 0.92), (0.4, 0.34, 0.5)), p[2] - 1.36, 0.06)

    def knees(p):
        q = (np.abs(p[0]), p[1], p[2])
        thigh = round_cone(q, (0.18, 0.05, 0.42), (0.16, -0.36, 0.64), 0.15, 0.13)
        shin = round_cone(q, (0.16, -0.38, 0.62), (0.2, -0.46, 0.32), 0.12, 0.11)
        return smin(thigh, shin, 0.05)

    foot = [np.array([sx * 0.22, -0.4, 0.0]) for sx in (-1, 1)]

    def boots(p):
        d = union_all([smin(shoe(p, c, 0.5, 0.4, 0.3), cylinder(p, c + (0, 0.04, 0.22), 0.15, 0.1, 0.05), 0.05) for c in foot])
        return smax(d, -p[2], 0.01)

    def boot_soles(p):
        return overlay(boots(p), p[2] - 0.05, 0.012, depth=0.04, k=0.006)

    def boot_x(p):
        reg = union_all([np.maximum(cross2(p[0] - c[0], p[1] - c[1] + 0.14, 0.04, 0.011), 0.16 - p[2]) for c in foot])
        return overlay(boots(p), reg, 0.01, depth=0.03, k=0.003)

    def socks(p):
        return union_all([sock(p, c + np.array([0, 0.03, 0.38]), 0.14, 0.07) for c in foot])

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Blanket", blanket, blanket_m, voxel=0.008, tris=19500),
        Comp(f"{N}_EdgeStitch", dashes, stitch_m, voxel=0.0045, tris=14000),
        Comp(f"{N}_FeltStars", stars, star_m, voxel=0.005, tris=4000),
        Comp(f"{N}_CrossStitch", plus_marks, mint_x, voxel=0.004, tris=4000),
        Comp(f"{N}_Clasp", clasp, clasp_m, voxel=0.004, tris=3000),
        Comp(f"{N}_ClaspStitch", clasp_stitch, stitch_m, voxel=0.003, tris=1500),
        Comp(f"{N}_ClaspButton", clasp_button, button_m, voxel=0.003, tris=800),
        Comp(f"{N}_ClaspLeaves", leaf_fn, leaf_m, voxel=0.004, tris=1500),
        Comp(f"{N}_Tunic", tunic, inner_m, voxel=0.008, tris=5000),
        Comp(f"{N}_Legs", knees, skin, voxel=0.006, tris=4000),
        Comp(f"{N}_Socks", socks, sock_m, voxel=0.005, tris=3000),
        Comp(f"{N}_Boots", boots, boot_m, voxel=0.006, tris=6000),
        Comp(f"{N}_Soles", boot_soles, sole_m, voxel=0.005, tris=3000),
        Comp(f"{N}_BootStitch", boot_x, stitch_m, voxel=0.0035, tris=800),
    ]
    comps += kid_face(N, head, fm, **face_z(H), brows=(0.21, 0.06, 0.026, 4.0), look=0.3, lid=0.48)
    return assemble(N, "Hush Veil", "Rare", comps, {}, ((-1.5, -1.4, -0.2), (1.5, 1.5, 3.3)),
                    catalog="echo.hush-veil")


# ---------------------------------------------------------------- Moon Doze

def moon_doze():
    N = "MoonDoze"
    fm = face_mats(N, brow="#B9BFCB")
    fm["lash"] = (f"{N}_Lash", Mat("#6E4E46", rough=0.5))
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#BFCADA", rough=0.55, coat=0.08))
    cap_m = (f"{N}_Cap", Mat("#8E9DC6", rough=0.95))
    trim_m = (f"{N}_Trim", Mat("#EEE6D6", rough=0.95))
    star_w = (f"{N}_CapStars", Mat("#F2EBDC", rough=0.7))
    gold = (f"{N}_Moon", Mat("#EBCB7E", rough=0.45, coat=0.2))
    plush_m = (f"{N}_StarPlush", Mat("#F1D68C", rough=0.85))
    plush_face = (f"{N}_PlushFace", Mat("#7A5E3E", rough=0.5))
    pj_m = (f"{N}_Pajamas", Mat("#B5BEDA", rough=0.9))
    pj_cream = (f"{N}_PajamaCream", Mat("#EEE6D6", rough=0.9))
    lav = (f"{N}_Lavender", Mat("#AE9FCF", rough=0.85))
    cloud_m = (f"{N}_Cloud", Mat("#F0E9DA", rough=0.95))
    felt = (f"{N}_FeltStars", Mat("#A99BCB", rough=0.9))
    bead_m = (f"{N}_Beads", Mat("#9FB3D0", rough=0.4, coat=0.3))
    stitch_m = (f"{N}_Stitch", Mat("#F2EBDC", rough=0.7))

    H = 1.81
    head = Head(c=(0.0, -0.07, H))

    # Cloud base: puffs round a ring, flat underneath.
    puffs = [(0.0, 0.05, 0.36, 0.52)]
    for i in range(12):
        a = math.radians(i * 30 + 8)
        r = 0.36 + 0.05 * math.sin(i * 2.3)
        puffs.append((0.86 * math.sin(a), 0.05 - 0.7 * math.cos(a), 0.3 + 0.06 * math.cos(i * 1.7), r))
    for i in range(6):
        a = math.radians(i * 60 + 30)
        puffs.append((0.45 * math.sin(a), 0.05 - 0.38 * math.cos(a), 0.56, 0.3))

    def cloud_shape(p):
        d = union_all([sphere(p, (x, y, z), r) for x, y, z, r in puffs], 0.035)
        return smax(d, -p[2], 0.03)

    def cloud(p):
        dimples = 0.006 * np.abs(waves(p, 30.0, 131)) + 0.004 * waves(p, 70.0, 132)
        return cloud_shape(p) - dimples

    cloud_stars = [Tangent(cloud_shape, (0, 0.05, 0.3), (math.sin(math.radians(a)), -math.cos(math.radians(a)), dz), spin=s)
                   for a, dz, s in ((-40, -0.1, 10), (70, 0.0, -12), (150, 0.1, 5), (-120, -0.1, 20))]

    def felt_stars(p):
        reg = union_all([t.region(p, lambda u, v: star2(u, v, 0.13, 0.5)) for t in cloud_stars])
        return overlay(cloud_shape(p), reg, 0.025, depth=0.05, k=0.02)

    bead_dirs = [(-15, 0.2), (25, -0.1), (100, 0.15), (-80, 0.2), (190, 0.0), (-160, 0.25), (55, 0.3), (-5, -0.15)]
    bead_pts = [surface_point(cloud_shape, (0, 0.05, 0.35), (math.sin(math.radians(a)), -math.cos(math.radians(a)), dz))
                for a, dz in bead_dirs]

    def beads(p):
        return union_all([sphere(p, c, 0.035) for c in bead_pts])

    # Nightcap: a quilted cap on the head flopping to the character's right into a pompom.
    CB = np.array([0.0, 0.1, 2.2])
    cap_path = [(0.0, 0.08, 2.4), (-0.22, 0.1, 2.6), (-0.64, 0.05, 2.56), (-0.92, -0.02, 2.2), (-0.99, -0.04, 1.88)]

    def cap_shape(p):
        dome = ellipsoid(p, CB, (0.86, 0.84, 0.66))
        dome = smax(dome, 2.04 - p[2] - 0.12 * np.clip(p[1], 0, 1), 0.04)
        tail = tube(p, cap_path, [0.52, 0.4, 0.27, 0.17, 0.09], k=0.1)
        return smin(dome, smax(tail, 2.3 - p[2] - 2.0 * np.clip(-p[0] - 0.55, 0, 1), 0.04), 0.12)

    def cap(p):
        return cap_shape(p) - 0.004 * waves(p, 45.0, 133)

    def cap_trim(p):
        band = torus(p, CB + (0, 0.0, -0.12), 0.83, 0.1, rot(-6, 0, 0))
        quilt = 0.012 * np.abs(np.cos(np.arctan2(p[0], -p[1]) * 18))
        return band - quilt

    def cap_seam(p):
        reg = np.maximum(np.abs(p[2] - (CB[2] + 0.02) + 0.06 * p[1]) - 0.01, np.cos(np.arctan2(p[0], -p[1]) * 50) - 0.2)
        return overlay(cap_shape(p), reg, 0.012, depth=0.03, k=0.002)

    cap_star_dirs = [(-20, 30), (30, 34), (70, 18), (110, 26), (160, 30), (-150, 20), (-110, 38), (200, 55), (0, 58)]
    cap_star_t = [Tangent(cap_shape, CB, sph_dir(a, e), spin=a * 0.3) for a, e in cap_star_dirs]
    tail_star_t = [Tangent(cap_shape, (-0.64, 0.05, 2.56), (0.1, -1, 0.4)), Tangent(cap_shape, (-0.86, 0.0, 2.3), (0.2, 1, 0.1)),
                   Tangent(cap_shape, (-0.64, 0.05, 2.56), (0.0, 0.6, 1.0))]

    def cap_stars(p):
        reg = union_all([t.region(p, lambda u, v: star2(u, v, 0.075, 0.5)) for t in cap_star_t + tail_star_t])
        return overlay(cap_shape(p), reg, 0.018, depth=0.04, k=0.004)

    moon_c = surface_point(cap_shape, CB, sph_dir(-42, 8)) + sph_dir(-42, 8) * 0.04
    RMN = frame(sph_dir(-42, 8))

    def moon(p):
        u, v, w = local(p, moon_c, RMN)
        d2 = smax(ellipse2(u, v, 0.15, 0.15), -ellipse2(u + 0.08, v - 0.05, 0.13, 0.13), 0.01)
        return np.sqrt(np.maximum(d2, 0) ** 2 + np.maximum(np.abs(w) - 0.03, 0) ** 2) + \
            np.minimum(np.maximum(d2, np.abs(w) - 0.03), 0) - 0.015

    PP = np.array([-1.0, -0.05, 1.68])

    def pompom(p):
        return sphere(p, PP, 0.22) - 0.02 * np.abs(waves(p, 28.0, 134)) - 0.008 * waves(p, 70.0, 135)

    def charm(p):
        cord = round_cone(p, PP + (0, 0, -0.2), PP + (0, 0, -0.38), 0.012, 0.012)
        u, v = p[0] - PP[0], p[2] - (PP[2] - 0.5)
        d2 = star2(u, v, 0.1, 0.5)
        w = p[1] - PP[1]
        st = np.sqrt(np.maximum(d2, 0) ** 2 + np.maximum(np.abs(w) - 0.025, 0) ** 2) + \
            np.minimum(np.maximum(d2, np.abs(w) - 0.025), 0) - 0.015
        return np.minimum(cord, st)

    hair_c = np.array([0.0, 0.03, 1.9])
    hair_r = (0.84, 0.8, 0.72)
    hair_shell = Hair(hair_c, hair_r, hem=[(0, 1.98), (25, 1.92), (50, 1.5), (80, 1.24), (180, 1.18)],
                      locks=20, tip=0.14, groove=0.04, puff=0.03, swing=6.0, opening=(1.6, 0.5, 0.42, -0.1))
    bangs = fringe(hair_c, hair_r, [(-40, 2.16, 1.78, 0.17, -12), (-20, 2.2, 1.84, 0.16, 12), (0, 2.2, 1.88, 0.16, 16),
                                    (20, 2.18, 1.8, 0.16, 14), (40, 2.12, 1.7, 0.16, 10),
                                    (58, 2.06, 1.48, 0.15, 6), (-58, 2.06, 1.48, 0.15, -6)], thick=0.07, lift=0.06)
    mop = lock_mop(hair_c, hair_r, [(10, 16, 0), (-10, 18, 8)], seed=31, width=0.22, thick=0.065, length=0.4,
                   flare=0.06, swing=18, round_tip=0.3, bend=0.06, skip=lambda az, el: abs(az) < 62)

    def hair(p):
        d = smin(hair_shell(p) - 0.02 * waves(p, 12.0, 136), bangs(p), 0.03)
        return smax(d, -(cap_shape(p) - 0.01), 0.02)

    def torso(p):
        return ellipsoid(p, (0, 0.05, 1.02), (0.42, 0.36, 0.42))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.34, 0.02, 1.26), (sx * 0.46, -0.16, 1.02), (sx * 0.26, -0.44, 1.04),
                             (sx * 0.16, -0.5, 1.08)], [0.15, 0.15, 0.14, 0.13], (sx * 0.12, -0.58, 1.1),
                            (-sx, -0.3, 0.2), thumb=(0, -0.3, 1), hand_r=(0.09, 0.075, 0.1)))

    def pajamas(p):
        d = smax(torso(p), p[2] - 1.36, 0.06)
        d = smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.04)
        legs_ = fold(lambda q: round_cone(q, (0.2, 0.05, 0.68), (0.32, -0.4, 0.66), 0.2, 0.17))(p)
        d = smin(d, legs_, 0.08)
        quilt = 0.02 * np.abs(np.sin((p[0] + p[2]) * 18)) ** 0.4 * np.abs(np.sin((p[0] - p[2]) * 18)) ** 0.4
        return d - quilt

    def collar(p):
        return torus(p, (0, -0.02, 1.34), 0.3, 0.07, rot(-14, 0, 0)) - 0.01 * np.abs(np.cos(np.arctan2(p[0], -p[1]) * 12))

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    def slippers(p):
        return fold(lambda q: ellipsoid(q, (0.36, -0.58, 0.66), (0.16, 0.2, 0.15)))(p)

    SP = np.array([0.04, -0.66, 1.08])
    RSP = rot(0, -14, 0)

    def plush(p):
        u, v, w = local(p, SP, RSP)
        d2 = star2(u, w, 0.32, 0.6)
        return np.sqrt(np.maximum(d2, 0) ** 2 + np.maximum(np.abs(v) - 0.07, 0) ** 2) + \
            np.minimum(np.maximum(d2, np.abs(v) - 0.07), 0) - 0.05

    def plush_face_fn(p):
        u, v, w = local(p, SP, RSP)
        eyes = np.minimum(arc2(u - 0.07, w - 0.02 - 0.04, 0.04, 55, 0.008), arc2(u + 0.07, w - 0.02 - 0.04, 0.04, 55, 0.008))
        return overlay(plush(p), np.maximum(eyes, v), 0.008, depth=0.02, k=0.002)

    def bow_back(p):
        return bow(p, np.array([0.0, 0.5, 0.92]), rot(0, 0, 180), 0.28)

    def bow_tails(p):
        return union_all([Leaf((sx * 0.04, 0.52, 0.82), (sx * 0.18, 0.58, 0.58), 0.06, 0.025, (0, 1, 0), mid=0.4,
                               r_base=0.05, r_tip=0.06)(p) for sx in (-1, 1)])

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=16000),
        Comp(f"{N}_Cap", cap, cap_m, voxel=0.0075, tris=14000),
        Comp(f"{N}_CapTrim", cap_trim, trim_m, voxel=0.006, tris=7000),
        Comp(f"{N}_CapSeam", cap_seam, stitch_m, voxel=0.004, tris=2500),
        Comp(f"{N}_CapStars", cap_stars, star_w, voxel=0.004, tris=5000),
        Comp(f"{N}_Moon", moon, gold, voxel=0.004, tris=2500),
        Comp(f"{N}_Pompom", pompom, trim_m, voxel=0.005, tris=7000),
        Comp(f"{N}_Charm", charm, gold, voxel=0.0035, tris=1500),
        Comp(f"{N}_Pajamas", pajamas, pj_m, voxel=0.007, tris=12000),
        Comp(f"{N}_Collar", collar, pj_cream, voxel=0.005, tris=4000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=3000),
        Comp(f"{N}_Slippers", slippers, lav, voxel=0.006, tris=4000),
        Comp(f"{N}_StarPlush", plush, plush_m, voxel=0.005, tris=6000),
        Comp(f"{N}_PlushFace", plush_face_fn, plush_face, voxel=0.003, tris=800),
        Comp(f"{N}_Bow", bow_back, lav, voxel=0.005, tris=5000),
        Comp(f"{N}_BowTails", bow_tails, lav, voxel=0.004, tris=2500),
        Comp(f"{N}_Cloud", cloud, cloud_m, voxel=0.008, tris=19500),
        Comp(f"{N}_CloudStars", felt_stars, felt, voxel=0.004, tris=4000),
        Comp(f"{N}_CloudBeads", beads, bead_m, voxel=0.004, tris=2000),
    ]
    comps += kid_face(N, head, fm, **face_z(H), brows=None, closed=True)
    return assemble(N, "Moon Doze", "Mythical", comps, {}, ((-1.5, -1.4, -0.2), (1.5, 1.4, 3.2)),
                    catalog="echo.moon-doze")


FIGURES = {  # catalog order
    "thread-parade": thread_parade,
    "wander-knit": wander_knit,
    "dino-drift": dino_drift,
    "still-pebble": still_pebble,
    "hearth-helm": hearth_helm,
    "echo-line": echo_line,
    "paper-crown": paper_crown,
    "mask-nuzzle": mask_nuzzle,
    "hush-veil": hush_veil,
    "crate-spark": crate_spark,
    "feather-hush": feather_hush,
    "mumble-beast": mumble_beast,
    "moon-doze": moon_doze,
}
