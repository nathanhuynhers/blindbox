"""We Are All Stars figure definitions, reconstructed from the approved character sheets.

Units are studs. +Z is up, every figure faces -Y, the character's left is +X,
and the lowest point of each figure rests on Z = 0 after grounding.

The same chibi girl construction as Tender Echoes (porcelain head, sculpted vinyl hair, mitten
hands, clogs), with this series' face: large round dark eyes glancing slightly toward the viewer's
right, lashes with a flick, faint brows, a tiny nose, a small smile and blush. The shared kit
(`Mat`, `Comp`, `Leaf`, `Head`, `kid_face`, `Hair`, `fringe`, `lock_mop`, limbs and `assemble`) is
copied from the Tender Echoes definitions; the series kit below it adds the round-eyed face
settings, flared bob hair, puffy stars, clouds and the little white cat that recurs on the sheets.
Glowing stars are albedo only (emission never reaches the GLB): a pale warm yellow ramp.
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
             cheeks=(0.4, 1.75, (0.12, 0.075)), cx=0.0, ylim=-0.25, closed=False, iris=0.84,
             smile=False):
    """Heavy-lidded eyes glancing toward +X, small brows, nose nub, pout and blush.

    Every feature is a thin skin conforming to `base`. `look` shifts the iris toward the
    character's left (viewer's right) as a fraction of the eye width; `lid` is how far above the
    eye centre the upper lid line sits (fraction of rv); `droop` lowers its outer corner.
    `brows` = (height above eye centre, half-length, half-height, worried tilt) or None.
    `closed` draws sleeping eyes: a downward lash arc only. `iris` is the iris size as a fraction of
    the eye; `smile` turns the mouth arc up instead of the default pout.
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
    ri = (iris * ru, iris * rv)

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
        if smile:
            u, v = p[0] - cx, p[2] - (mouth_z + R)
            region = np.maximum(arc2(u, v, R, 48.0, 0.011), p[1] - ylim)
        else:
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


def posed(fn, pivot, R):
    """Evaluate `fn` in a frame rotated by R about `pivot` (tilting a group)."""
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


def bow(p, c, R, size=0.12):
    """A puffy ribbon bow (two loops and a knot) in the frame R, facing local -Y."""
    c = np.asarray(c, float)
    d = ellipsoid(p, c, (size * 0.38, size * 0.32, size * 0.36), R)
    for sx in (-1, 1):
        lobe = ellipsoid(p, c + R @ np.array([sx * size * 0.75, 0.0, 0.0]), (size * 0.7, size * 0.3, size * 0.5),
                         R @ rot(0, sx * 12, 0))
        d = smin(d, lobe, size * 0.25)
    return d


# ------------------------------------------------------------------ series kit: head, face, hair

HAIR = "#8A5A45"
GLOW = ["#FFF6CF", "#FFE89A", "#F9D774"]  # glowing star albedo, bright centre to warm rim


def star_head(H, x=0.0, y=-0.05):
    """The series head: a little broader than Tender Echoes', chin at H - 0.6."""
    return Head(c=(x, y, H), r=(0.66, 0.62, 0.6))


def star_face(N, head, fm, H, look=0.14, closed=False, cx=0.0, **kw):
    """Round dark eyes low on the face (measured on the Mirrorlight FRONT view), small smile."""
    args = dict(z=H - 0.25, dx=0.31, ru=0.165, rv=0.18, look=look, lid=1.15, iris=0.9,
                brows=(0.31, 0.065, 0.016, -4.0), nose_z=H - 0.4, mouth_z=H - 0.49, mouth_w=0.034,
                cheeks=(0.43, H - 0.42, (0.13, 0.08)), smile=True, cx=cx, closed=closed)
    args.update(kw)
    return kid_face(N, head, fm, **args)


class Bob(Hair):
    """Hair whose sides hang straight past the cap and flip outward at the hem.

    `bell` = (top z, bottom z, flare): below `top` the shell continues as a vertical skirt that
    widens by `flare` (fraction of the radius) toward `bottom`.
    """

    def __init__(self, c, r, hem, bell, wave=None, roll=0.0, roll_from=50.0, **kw):
        super().__init__(c, r, hem, **kw)
        self.bell = bell
        self.wave = wave  # (amplitude, frequency): soft horizontal waves down the long hair
        self.roll = roll  # radius of the outward-curled roll along the side and back hem
        self.roll_from = roll_from  # |azimuth| where the roll starts (clear of the bangs)

    def __call__(self, p):
        c = self.c
        az, f = self.lock_phase(p)
        tri = 1.0 - np.abs(2.0 * f - 1.0)
        hem = np.interp(np.abs(az), self.az_pts, self.z_pts)
        if self.skew is not None:
            hem = hem + np.interp(az, *self.skew)
        hem = hem - self.tip * tri ** 0.8
        top, bottom, flare = self.bell
        rx, ry = self.r[0], self.r[1]
        t = np.clip((top - p[2]) / (top - bottom), 0.0, 1.0)
        rho = np.sqrt(((p[0] - c[0]) / rx) ** 2 + ((p[1] - c[1]) / ry) ** 2)
        skirt = smax((rho - (1.0 + flare * t ** 2.5)) * min(rx, ry), p[2] - top, 0.05)
        if self.wave:
            amp, freq = self.wave
            skirt = skirt - amp * np.sin(p[2] * freq + 0.6 * np.sin(az * 0.05)) * t
        d = smin(ellipsoid(p, c, self.r), skirt, 0.12)
        if self.roll:
            base_hem = np.interp(np.abs(az), self.az_pts, self.z_pts)
            w = np.clip((np.abs(az) - self.roll_from) / 12.0, 0.0, 1.0)
            ring_r = (1.0 + flare) * min(rx, ry) - 0.2 * self.roll
            rho_s = rho * min(rx, ry)
            ring = np.sqrt((rho_s - ring_r) ** 2 + (p[2] - base_hem - 0.85 * self.roll) ** 2) - self.roll * w
            d = smin(d, ring, 0.06)
        drop = np.clip((c[2] + self.r[2] * 0.55 - p[2]) / (self.r[2] * 0.9), 0.0, 1.0)
        seam = np.minimum(f, 1.0 - f)
        strands = 0.008 * np.abs(np.sin(f * math.pi * 4.0)) ** 0.5
        d = d + self.groove * np.exp(-(seam / 0.08) ** 2) * drop - self.puff * tri * drop + strands * drop
        d = smax(d, hem - p[2], self.k)
        if self.opening:
            oz, ow, oh, oy = self.opening
            d = smax(d, -np.maximum(ellipse2(p[0] - c[0], p[2] - oz, ow, oh), p[1] - oy), 0.05)
        return d


# ------------------------------------------------------------------ series kit: stars, clouds

def slab2(d2, y, th, rnd):
    """Extrude a 2D distance d2 to half-thickness th along y, rounded by rnd."""
    q = np.abs(y) - th
    return np.sqrt(np.maximum(d2, 0) ** 2 + np.maximum(q, 0) ** 2) + np.minimum(np.maximum(d2, q), 0) - rnd


def puffy_star(p, c, R, r, rf=0.5, th=0.07, rnd=0.03):
    """Pillowy five-point star in the local XZ plane (points up +Z), thickest in the middle."""
    x, y, z = local(p, c, R)
    d2 = star2(x, z, r - rnd, rf)
    t = th * (0.4 + 0.8 * np.clip(-d2 / (0.42 * r), 0.0, 1.0))
    return slab2(d2, y, t, rnd)


def star_ramp(c, r):
    """Ramp coordinate for a glowing star: bright centre (0) to warm rim (1)."""
    c = np.asarray(c, float)
    return lambda x, y, z: np.clip(np.sqrt((x - c[0]) ** 2 + (y - c[1]) ** 2 + (z - c[2]) ** 2) / r, 0, 1)


def puffs(p, balls, k=0.04):
    """Cloud: a smooth union of (x, y, z, r) balls."""
    return union_all([sphere(p, (x, y, z), r) for x, y, z, r in balls], k)


# ------------------------------------------------------------------ series kit: the white cat

def cat_mats(N):
    return {
        "fur": (f"{N}_Cat", Mat("#F7F4EF", rough=0.45, coat=0.2)),
        "ear": (f"{N}_CatEars", Mat("#F2B7B2", rough=0.5)),
        "eye": (f"{N}_CatEyes", Mat("#3A2E29", rough=0.3, coat=0.4)),
        "nose": (f"{N}_CatNose", Mat("#E99C9A", rough=0.45)),
        "blush": (f"{N}_CatBlush", Mat("#F6C0B8", rough=0.6)),
    }


class Cat:
    """Little white cat: a round head with pointed ears, in a local frame facing local -Y.

    `c` is the head centre, `R` the head's frame and `s` its scale (s = 1: head 0.4 wide).
    Bodies, paws and tails differ per pose and are built by each figure around `at()`.
    """

    def __init__(self, c, R=None, s=1.0, closed=False, ears=1.0):
        self.c = np.asarray(c, float)
        self.R = np.eye(3) if R is None else R
        self.s = s
        self.closed = closed
        self.ears = ears

    def at(self, v):
        return self.c + self.R @ (np.asarray(v, float) * self.s)

    def _ear(self, p, sx):
        s = self.s
        a, b = self.at((sx * 0.1, 0.01, 0.1)), self.at((sx * 0.155, 0.02, 0.1 + 0.15 * self.ears))
        return round_cone(p, a, b, 0.07 * s, 0.022 * s)

    def head(self, p):
        s = self.s
        d = ellipsoid(p, self.c, (0.2 * s, 0.17 * s, 0.16 * s), self.R)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, self.at((sx * 0.075, -0.07, -0.05)), (0.1 * s, 0.09 * s, 0.085 * s), self.R),
                     0.04 * s)
            d = smin(d, self._ear(p, sx), 0.03 * s)
        return d

    def uvw(self, p):
        x, y, z = local(p, self.c, self.R)
        return x / self.s, y / self.s, z / self.s

    def ear_inner(self, p):
        reg = None
        for sx in (-1, 1):
            u, w, v = self.uvw(p)
            e = np.maximum(round_cone((u, w, v), (sx * 0.11, 0.0, 0.13), (sx * 0.15, 0.0, 0.22), 0.04, 0.012),
                           w + 0.02)
            reg = e if reg is None else np.minimum(reg, e)
        return overlay(self.head(p), reg * self.s, 0.008 * self.s, depth=0.03 * self.s, k=0.004 * self.s)

    def face(self, N, base, cm, extra=()):
        """Eyes (dots or sleeping arcs), nose, mouth and blush as skins on `base` (the cat's union)."""
        s = self.s

        def front(p):
            return self.uvw(p)[1] + 0.06

        def eyes(p):
            u, w, v = self.uvw(p)
            regs = []
            for sx in (-1, 1):
                if self.closed:
                    R_ = 0.045
                    regs.append(arc2(u - sx * 0.075, v - 0.005 - R_ * 0.7, R_, 55.0, 0.0085))
                else:
                    regs.append(ellipse2(u - sx * 0.078, v - 0.005, 0.027, 0.033))
            reg = np.maximum(np.minimum(*regs), front(p))
            return overlay(base(p), reg * s, 0.008 * s, depth=0.03 * s, k=0.002 * s)

        def mouth(p):
            u, w, v = self.uvw(p)
            reg = np.minimum(arc2(u - 0.018, v + 0.055, 0.018, 70.0, 0.006), arc2(u + 0.018, v + 0.055, 0.018, 70.0, 0.006))
            return overlay(base(p), np.maximum(reg, front(p)) * s, 0.006 * s, depth=0.03 * s, k=0.002 * s)

        nose_c = surface_point(base, self.at((0, 0, -0.025)), self.R @ np.array([0.0, -1.0, 0.0]))

        def nose(p):
            return ellipsoid(p, nose_c, (0.022 * s, 0.014 * s, 0.016 * s), self.R)

        def blush(p):
            u, w, v = self.uvw(p)
            reg = np.minimum(ellipse2(u - 0.135, v + 0.04, 0.04, 0.026), ellipse2(u + 0.135, v + 0.04, 0.04, 0.026))
            return overlay(base(p), np.maximum(reg, front(p)) * s, 0.005 * s, depth=0.03 * s, k=0.006 * s)

        return [
            Comp(f"{N}_CatEars", self.ear_inner, cm["ear"], voxel=0.004, tris=800),
            Comp(f"{N}_CatEyes", eyes, cm["eye"], voxel=0.003, tris=700),
            Comp(f"{N}_CatMouth", mouth, cm["eye"], voxel=0.003, tris=500),
            Comp(f"{N}_CatNose", nose, cm["nose"], voxel=0.003, tris=300),
            Comp(f"{N}_CatBlush", blush, cm["blush"], voxel=0.0035, tris=600),
        ]


# ------------------------------------------------------------------ series kit: books, faceted star

class Book:
    """A closed hardback: boards (covers and spine) round a page block inset on three sides.

    `c` centre, `half` half extents (x, y, z) in the frame R, `spine` = +1/-1 for a spine on the
    frame's +Y/-Y side. Pages show fine horizontal leaf lines.
    """

    def __init__(self, c, half, R=None, spine=1, board=0.03, inset=0.035):
        self.c = np.asarray(c, float)
        self.h = np.asarray(half, float)
        self.R = np.eye(3) if R is None else R
        self.spine, self.board, self.inset = spine, board, inset

    def q(self, p):
        return local(p, self.c, self.R)

    def boards(self, p):
        x, y, z = self.q(p)
        hx, hy, hz = self.h
        outer = round_box((x, y, z), (0, 0, 0), (hx, hy, hz), 0.025)
        b, i = self.board, self.inset
        cavity = round_box((x, y + self.spine * b, z), (0, 0, 0), (hx - 0.0 + 0.1, hy + 0.0, hz - b), 0.01)
        cavity = smax(cavity, self.spine * y - (hy - b - 0.002), 0.005)
        return smax(outer, -cavity, 0.006)

    def pages(self, p):
        x, y, z = self.q(p)
        hx, hy, hz = self.h
        b, i = self.board, self.inset
        d = round_box((x, y + self.spine * (i - b) * 0.5, z), (0, 0, 0), (hx - i, hy - b * 0.5 - i * 0.5, hz - b + 0.004),
                      0.008)
        return d + 0.0035 * np.abs(np.sin(z * 260.0)) ** 2


def faceted_star(p, c, r, rf, h_top, h_bot, wall=0.12, top=None, yaw=0.0, rnd=0.012):
    """Low-poly star seat: a five-point star prism (blunt points `wall` thick either side of the
    midplane) whose outline shrinks linearly toward a top and bottom apex, so every face is a flat
    facet. `top` cuts a flat seat at that height above the midplane. One point faces -Y at yaw 0."""
    x, y, z = local(p, c, rot(0, 0, yaw))
    zz = np.maximum(np.abs(z) - wall, 0.0)
    s = np.where(z > 0, 1.0 - zz / (h_top - wall), 1.0 - zz / (h_bot - wall))
    s = np.clip(s, 1e-3, 1.0)
    d2 = star2(x / s, -y / s, r, rf) * s
    d = np.maximum(d2 * 0.75, np.maximum(z - h_top, -z - h_bot))
    if top is not None:
        d = np.maximum(d, z - top)
    return d - rnd


# ------------------------------------------------------------------ series kit: scale, flowers, prints

def scale_comps(comps, s):
    """Scale finished components uniformly about the origin (figures whose props run tall)."""
    for c in comps:
        c.fn = (lambda f: lambda p: f((p[0] / s, p[1] / s, p[2] / s)) * s)(c.fn)
        if c.ramp is not None:
            c.ramp = (lambda r: lambda x, y, z: r(x / s, y / s, z / s))(c.ramp)
    return comps


def scaled_bounds(lo, hi, s):
    return tuple(v * s for v in lo), tuple(v * s for v in hi)


def astroid2(u, v, r):
    """Four long thin points (a twinkle star) of radius r; approximate distance."""
    a = (np.abs(u) + 1e-9) ** (2 / 3) + (np.abs(v) + 1e-9) ** (2 / 3)
    return (a ** 1.5 - r) * 0.5


def twinkle2(u, v, r):
    """Eight-point print star: four long points and four short diagonal ones."""
    c, s = math.cos(math.pi / 4), math.sin(math.pi / 4)
    return np.minimum(astroid2(u, v, r), astroid2(u * c + v * s, -u * s + v * c, r * 0.55))


class Daisy:
    """A white daisy: puffy petals round a domed yellow centre, facing `n`."""

    def __init__(self, c, n, r=0.12, petals=8, spin=0.0):
        self.c = np.asarray(c, float)
        self.R = frame(n) @ rot(0, 0, spin)
        self.r, self.n = r, petals

    def petals(self, p):
        x, y, z = local(p, self.c, self.R)
        a = np.arctan2(y, x)
        k = self.n / (2 * math.pi)
        f = a * k - np.floor(a * k + 0.5)
        rho = np.sqrt(x * x + y * y)
        w = np.abs(f) / k * rho  # distance across the nearest petal's axis
        petal = np.sqrt(np.maximum(rho - self.r, 0) ** 2 + (w * 1.4) ** 2) - self.r * 0.34
        petal = smax(petal, -rho + self.r * 0.15, 0.01)
        bulge = 0.25 * self.r * np.clip(1 - rho / (self.r * 1.3), 0, 1)
        return slab2(np.minimum(petal, rho - self.r * 0.4), z - bulge * 0.3, self.r * 0.11, self.r * 0.08)

    def centre(self, p):
        return ellipsoid(p, self.c + self.R @ np.array([0, 0, self.r * 0.16]), (self.r * 0.38, self.r * 0.38, self.r * 0.22),
                         self.R)


def clover(p, base, h, leaf=0.16, leaves=3, spin=0.0, lean=(0, 0)):
    """A clover sprig: a stem from `base` up `h`, heart-shaped leaflets fanning at the top."""
    b = np.asarray(base, float)
    top = b + np.array([lean[0], lean[1], h])
    d = round_cone(p, b, top, 0.04, 0.03)
    for i in range(leaves):
        a = math.radians(spin + i * 360.0 / leaves)
        dirv = np.array([math.cos(a), math.sin(a), 0.9])
        tip = top + unit(dirv) * leaf * 1.6
        nrm = (-0.8 * math.sin(a), 0.8 * math.cos(a), 0.6)
        lf = Leaf(top, tip, leaf * 0.66, 0.03, nrm, mid=0.62, r_base=0.02, r_tip=leaf * 0.36, crease=0.012, cup=0.02)
        d = smin(d, lf(p), 0.02)
    return d


def star_prints(base, centre, dirs, r, out=0.008):
    """Small star prints as skins on `base`, placed by direction from an interior `centre`."""
    marks = [Tangent(base, centre, d, spin=i * 23.0) for i, d in enumerate(dirs)]

    def fn(p):
        reg = union_all([t.region(p, lambda u, v: star2(u, v, r, 0.5), reach=0.1) for t in marks])
        return overlay(base(p), reg, out, depth=0.03, k=0.003)

    return fn


def face_dir(n, spin=0.0):
    """Frame for a puffy star (or other local-XZ shape) whose broad face looks along `n`."""
    return frame(n) @ rot(90, 0, 0) @ rot(0, spin, 0)


# ---------------------------------------------------------------- Reminiscence Star

def reminiscence():
    N = "Reminiscence"
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    cm = cat_mats(N)
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    vest_m = (f"{N}_Vest", Mat("#E06A55", rough=0.85))
    sweater_m = (f"{N}_Sweater", Mat(["#93C1DE", "#A8D6C8", "#9FD08F"], rough=0.85))
    pants_m = (f"{N}_Pants", Mat("#8FA8D4", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#F1ECE3", rough=0.45, coat=0.15))
    board_m = (f"{N}_Board", Mat("#E8BD86", rough=0.7))
    ink_m = (f"{N}_Doodles", Mat("#8C6448", rough=0.6))
    crayon_m = (f"{N}_Crayon", Mat("#4B4442", rough=0.5))

    # Head group, modelled upright and tipped forward over the board about the neck.
    H = 1.5
    pivot = np.array([0.0, 0.05, H - 0.75])
    tilt = rot(18, 0, 0)
    head = star_head(H)
    HC = np.array([0.0, 0.03, H + 0.08])
    HR = (0.88, 0.84, 0.78)
    hair_shell = Bob(HC, HR, hem=[(0, H + 0.17), (34, H + 0.15), (46, H + 0.0), (58, H - 0.14), (90, H - 0.22),
                                  (180, H - 0.52)],
                     bell=(H + 0.05, H - 0.52, 0.1), locks=40, tip=0.06, groove=0.024, puff=0.014, k=0.07,
                     opening=(H - 0.3, 0.62, 0.47, -0.15))
    buns = [np.array([sx * 0.78, 0.3, H - 0.1]) for sx in (-1, 1)]

    def hair(p):
        d = hair_shell(p)
        for b in buns:
            e = sphere(p, b, 0.26) - 0.012 * np.abs(np.sin(np.arctan2(p[2] - b[2], p[1] - b[1]) * 7)) ** 0.5
            d = smin(d, e, 0.06)
        return d

    # Cat lying over the crown: head at the front of the character's right side, body to the back.
    cat = Cat((-0.5, -0.36, H + 0.8), R=rot(0, 0, -12), s=1.3)

    def cat_body(p):
        d = ellipsoid(p, (-0.05, 0.12, H + 0.86), (0.42, 0.26, 0.18), rot(0, 0, 30))
        d = smin(d, cat.head(p), 0.08)
        for c in ((-0.62, -0.5, H + 0.66), (-0.36, -0.56, H + 0.68)):
            d = smin(d, ellipsoid(p, c, (0.075, 0.1, 0.065)), 0.04)
        leg = tube(p, [(0.28, 0.32, H + 0.84), (0.38, 0.58, H + 0.62), (0.4, 0.66, H + 0.42)], [0.08, 0.075, 0.07], k=0.03)
        tail = tube(p, [(0.32, 0.2, H + 0.86), (0.6, 0.1, H + 0.78), (0.72, -0.06, H + 0.66)], [0.07, 0.06, 0.05], k=0.03)
        return smin(smin(d, leg, 0.05), tail, 0.04)

    head_group = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Cat", cat_body, cm["fur"], voxel=0.006, tris=10000),
    ]
    head_group += cat.face(N, cat_body, cm)
    head_group += star_face(N, head, fm, H, look=0.1)
    pose_comps(head_group, pivot, tilt)

    RT = rot(28, 0, 0)

    def torso(p):
        return ellipsoid(p, (0.0, 0.02, 0.62), (0.42, 0.34, 0.38), RT)

    def vest(p):
        d = smax(torso(p), p[2] - 0.98 + 0.4 * p[1], 0.05)
        return d - 0.012 * np.abs(np.cos(p[0] * 55.0)) ** 0.5

    arm_r = arm_parts([(-0.38, -0.14, 0.82), (-0.52, -0.38, 0.54), (-0.4, -0.62, 0.3)], [0.15, 0.14, 0.12],
                      (-0.34, -0.72, 0.24), (0.3, -0.5, -0.6), thumb=(1, 0, 0.4), hand_r=(0.09, 0.08, 0.1))
    arm_l = arm_parts([(0.38, -0.14, 0.82), (0.54, -0.36, 0.52), (0.55, -0.6, 0.26)], [0.15, 0.14, 0.12],
                      (0.56, -0.7, 0.19), (0.0, -1.0, -0.3), thumb=(-1, -0.2, 0), hand_r=(0.1, 0.11, 0.07))

    def sweater(p):
        d = np.minimum(arm_r[0](p), arm_l[0](p))
        d = smin(d, smax(ellipsoid(p, (0.0, -0.02, 0.66), (0.4, 0.33, 0.35), RT), p[2] - 1.0, 0.04), 0.04)
        return d - 0.008 * np.abs(np.sin(np.arctan2(p[2] - 0.6, np.abs(p[0]) - 0.4) * 10)) ** 0.5

    def sweater_t(x, y, z):
        return np.clip((0.86 - z) / 0.6, 0, 1)

    def hands(p):
        return np.minimum(arm_r[1](p), arm_l[1](p))

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def pants(p):
        seat = ellipsoid(p, (0, 0.22, 0.38), (0.38, 0.3, 0.2))
        thigh = round_cone(m(p), (0.2, 0.24, 0.36), (0.22, -0.1, 0.15), 0.18, 0.15)
        shin = round_cone(m(p), (0.22, -0.1, 0.14), (0.23, 0.36, 0.12), 0.14, 0.12)
        return smax(smin(smin(seat, thigh, 0.08), shin, 0.06), -p[2], 0.02)

    def shoes(p):
        d = ellipsoid(m(p), (0.24, 0.5, 0.14), (0.15, 0.17, 0.14))
        return smax(d, -p[2], 0.02)

    BC, BH = np.array([0.0, -0.62, 0.06]), (1.08, 0.56, 0.06)

    def board(p):
        d = round_box(p, BC, BH, 0.04)
        slot = round_box(p, (0.86, -0.2, 0.06), (0.1, 0.035, 0.2), 0.025)
        grain = 0.002 * np.sin(p[0] * 30 + 2 * np.sin(p[1] * 9))
        return smax(d, -slot, 0.01) - grain

    def doodles(p):
        u, v = p[0], p[1]
        lines = [np.abs(star2(u + 0.42, v + 0.8, 0.09, 0.5)) - 0.008,
                 np.abs(star2(u - 0.12, v + 0.88, 0.065, 0.5)) - 0.007,
                 np.abs(star2(u - 0.52, v + 0.55, 0.06, 0.5)) - 0.007,
                 np.abs(ellipse2(u + 0.05, v + 0.62, 0.15, 0.11)) - 0.008,
                 ellipse2(u + 0.1, v + 0.62, 0.016, 0.016), ellipse2(u - 0.0, v + 0.62, 0.016, 0.016),
                 np.abs(ellipse2(u - 0.3, v + 0.72, 0.1, 0.075)) - 0.007]
        reg = np.maximum(union_all(lines), BC[2] + BH[2] - 0.02 - p[2])
        return overlay(board(p), reg, 0.004, depth=0.02, k=0.002)

    def crayon(p):
        d = round_cone(p, (-0.33, -0.78, 0.15), (-0.3, -0.62, 0.44), 0.025, 0.04)
        return smax(d, 0.11 - p[2], 0.005)

    comps = head_group + [
        Comp(f"{N}_Vest", vest, vest_m, voxel=0.006, tris=10000),
        Comp(f"{N}_Sweater", sweater, sweater_m, voxel=0.006, tris=9000, ramp=sweater_t),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Pants", pants, pants_m, voxel=0.006, tris=8000),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.005, tris=3000),
        Comp(f"{N}_Board", board, board_m, voxel=0.006, tris=8000),
        Comp(f"{N}_Doodles", doodles, ink_m, voxel=0.003, tris=4000),
        Comp(f"{N}_Crayon", crayon, crayon_m, voxel=0.004, tris=1200),
    ]
    return assemble(N, "Reminiscence Star", "Common", comps, {}, ((-1.3, -1.3, -0.2), (1.3, 1.3, 3.0)),
                    catalog="star.reminiscence")


# ---------------------------------------------------------------- Mirrorlight Star

def mirrorlight():
    N = "Mirrorlight"
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    cm = cat_mats(N)
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    hoodie_m = (f"{N}_Hoodie", Mat("#4A77C2", rough=0.85))
    dot_m = (f"{N}_Dots", Mat("#F3F0EA", rough=0.8))
    pants_m = (f"{N}_Pants", Mat("#E39A4C", rough=0.85))
    cuff_m = (f"{N}_Cuffs", Mat("#EDB57D", rough=0.85))
    sock_m = (f"{N}_Socks", Mat("#F3EFE8", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#F2ECE1", rough=0.4, coat=0.2))
    sole_m = (f"{N}_Sole", Mat("#D8CDBE", rough=0.6))
    stool_m = (f"{N}_Stool", Mat("#D6605A", rough=0.45, coat=0.2))
    star_m = (f"{N}_Star", Mat(GLOW, rough=0.3, coat=0.4))

    H = 2.05
    head = star_head(H)
    HC = np.array([0.0, 0.03, H + 0.08])
    HR = (0.88, 0.84, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.17), (34, H + 0.16), (44, H + 0.02), (52, H - 0.52), (90, H - 0.6),
                            (180, H - 0.68)],
               bell=(H - 0.05, H - 0.6, 0.12), roll=0.13, locks=40, tip=0.05, groove=0.024, puff=0.014,
               k=0.06, opening=(H - 0.3, 0.62, 0.47, -0.15))

    # Sleeping cat lying across the top of the head, paws over the bangs, tail down the back.
    cat = Cat((0.0, -0.5, 2.88), s=1.45, closed=True)

    def cat_body(p):
        d = ellipsoid(p, (0.0, -0.06, 2.98), (0.27, 0.42, 0.18))
        d = smin(d, cat.head(p), 0.08)
        d = smin(d, tube(p, [(0.2, -0.55, 2.84), (0.23, -0.82, 2.62), (0.24, -0.9, 2.42)], [0.08, 0.075, 0.072],
                         k=0.03), 0.05)
        d = smin(d, sphere(p, (0.24, -0.91, 2.38), 0.085), 0.03)
        d = smin(d, tube(p, [(-0.2, -0.6, 2.8), (-0.24, -0.8, 2.66)], [0.08, 0.075], k=0.03), 0.05)
        d = smin(d, sphere(p, (-0.24, -0.82, 2.62), 0.082), 0.03)
        tail = tube(p, [(0.05, 0.32, 2.96), (0.14, 0.72, 2.7), (0.17, 0.9, 2.36), (0.15, 0.92, 2.2)],
                    [0.075, 0.07, 0.065, 0.06], k=0.03)
        return smin(d, tail, 0.05)

    def torso(p):
        return ellipsoid(p, (0.0, 0.04, 1.08), (0.48, 0.41, 0.44))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.4, 0.02, 1.36), (sx * 0.54, -0.16, 1.06), (sx * 0.38, -0.46, 1.08),
                             (sx * 0.3, -0.54, 1.12)], [0.17, 0.17, 0.16, 0.14], (sx * 0.25, -0.62, 1.16),
                            (-sx, -0.4, 0.2), thumb=(0, -0.2, 1), hand_r=(0.1, 0.08, 0.11)))

    def hood(p):
        return ellipsoid(p, (0.0, 0.34, 1.44), (0.36, 0.2, 0.2), rot(-20, 0, 0))

    def hoodie(p):
        d = smax(torso(p), p[2] - 1.5, 0.06)
        d = smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.05)
        d = smin(d, hood(p), 0.06)
        d = smin(d, torus(p, (0, 0.04, 0.78), 0.38, 0.06), 0.04)
        return d - 0.004 * waves(p, 20.0, 7)

    dot_dirs = [(-0.9, -0.5, 0.2), (0.85, -0.6, 0.0), (-0.3, -1.0, -0.5), (0.4, -1.0, -0.55), (1.0, 0.2, 0.3),
                (-1.0, 0.25, -0.1), (0.3, 1.0, 0.3), (-0.4, 1.0, -0.1), (0.0, 1.0, -0.5), (0.9, 0.6, -0.4),
                (-0.8, 0.5, 0.45)]
    dots = [Tangent(hoodie, (0, 0.04, 1.08), dv) for dv in dot_dirs]
    sleeve_dots = [Tangent(hoodie, (sx * 0.44, -0.12, 1.06), (sx, -0.2, 0.1)) for sx in (-1, 1)]

    def polka(p):
        reg = union_all([t.region(p, lambda u, v: ellipse2(u, v, 0.1, 0.09), reach=0.15) for t in dots + sleeve_dots])
        return overlay(hoodie(p), reg, 0.008, depth=0.04, k=0.01)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    SC = np.array([0.0, -0.7, 1.2])
    RS = rot(-12, 0, 0)

    def star(p):
        return puffy_star(p, SC, RS, 0.34, 0.5, 0.09, 0.035)

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def pants(p):
        seat = smax(ellipsoid(p, (0, 0.02, 0.86), (0.38, 0.32, 0.18)), 0.7 - p[2], 0.02)
        thigh = round_cone(m(p), (0.2, 0.0, 0.88), (0.21, -0.5, 0.88), 0.19, 0.17)
        shin = round_cone(m(p), (0.21, -0.52, 0.86), (0.22, -0.54, 0.62), 0.16, 0.15)
        d = smin(smin(seat, thigh, 0.08), shin, 0.06)
        return d - 0.012 * np.abs(np.cos(p[0] * 70.0)) ** 0.5

    def cuffs(p):
        return torus(m(p), (0.22, -0.54, 0.6), 0.15, 0.055) - 0.004 * waves(p, 30.0, 9)

    def socks(p):
        d = round_cone(m(p), (0.22, -0.53, 0.58), (0.22, -0.52, 0.4), 0.11, 0.11)
        return d - 0.008 * np.abs(np.cos(np.arctan2(np.abs(p[0]) - 0.22, p[1] + 0.53) * 7)) ** 0.6

    heel = np.array([0.22, -0.42, 0.27])

    def shoes(p):
        return shoe(m(p), heel, 0.44, 0.3, 0.24, yaw=-4)

    def soles(p):
        return overlay(shoes(p), p[2] - (heel[2] + 0.045), 0.01, depth=0.04, k=0.006)

    def stool(p):
        seat = cylinder(p, (0, 0.0, 0.66), 0.45, 0.05, 0.03)
        q = (np.abs(p[0]), np.abs(p[1]), p[2])
        legs = round_cone(q, (0.29, 0.29, 0.62), (0.37, 0.37, 0.0), 0.055, 0.06)
        d = smin(seat, legs, 0.04)
        rung_x = round_cone(q, (0.0, 0.345, 0.24), (0.34, 0.345, 0.24), 0.038, 0.038)
        rung_y = round_cone(q, (0.345, 0.0, 0.32), (0.345, 0.34, 0.32), 0.035, 0.035)
        return smax(smin(smin(d, rung_x, 0.02), rung_y, 0.02), -p[2], 0.01)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Cat", cat_body, cm["fur"], voxel=0.006, tris=10000),
        Comp(f"{N}_Hoodie", hoodie, hoodie_m, voxel=0.007, tris=12000),
        Comp(f"{N}_Dots", polka, dot_m, voxel=0.004, tris=4000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Star", star, star_m, voxel=0.005, tris=6000, ramp=star_ramp(SC, 0.34)),
        Comp(f"{N}_Pants", pants, pants_m, voxel=0.006, tris=10000),
        Comp(f"{N}_Cuffs", cuffs, cuff_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Socks", socks, sock_m, voxel=0.005, tris=3000),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.005, tris=5000),
        Comp(f"{N}_Soles", soles, sole_m, voxel=0.004, tris=2500),
        Comp(f"{N}_Stool", stool, stool_m, voxel=0.007, tris=9000),
    ]
    comps += cat.face(N, cat_body, cm)
    comps += star_face(N, head, fm, H)
    return assemble(N, "Mirrorlight Star", "Common", comps, {}, ((-1.3, -1.3, -0.2), (1.3, 1.3, 3.4)),
                    catalog="star.mirrorlight")


# ---------------------------------------------------------------- Wishing Star

def wishing():
    N = "Wishing"
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#D8909A")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat("#EE9DB0", rough=0.6, coat=0.08))
    shirt_m = (f"{N}_Shirt", Mat("#F5F3EF", rough=0.85))
    check_m = (f"{N}_Gingham", Mat("#7F9FD9", rough=0.85))
    skirt_m = (f"{N}_Skirt", Mat("#A6DCC4", rough=0.85))
    sock_m = (f"{N}_Socks", Mat("#F4EEEA", rough=0.85))
    stripe_m = (f"{N}_SockStripes", Mat("#EFA6B6", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#F0A5B5", rough=0.45, coat=0.15))
    sole_m = (f"{N}_Sole", Mat("#F6EEE8", rough=0.6))
    star_m = (f"{N}_StarSeat", Mat("#F6DA6E", rough=0.55, coat=0.15))
    paper_m = (f"{N}_Notebook", Mat("#F4E8D2", rough=0.8))
    doodle_m = (f"{N}_Doodles", Mat("#EE9A6E", rough=0.6))
    pencil_m = (f"{N}_Pencil", Mat("#E04B3B", rough=0.45, coat=0.2))
    wood_m = (f"{N}_PencilWood", Mat("#EBCB9E", rough=0.7))
    lead_m = (f"{N}_PencilLead", Mat("#3E3A38", rough=0.5))

    H = 2.6
    head = star_head(H)
    HC = np.array([0.0, 0.03, H + 0.08])
    HR = (0.88, 0.84, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.2), (34, H + 0.18), (44, H + 0.04), (52, H - 0.5), (90, H - 0.56),
                            (180, H - 0.62)],
               bell=(H - 0.05, H - 0.56, 0.14), roll=0.14, locks=40, tip=0.05, groove=0.022, puff=0.014, k=0.06,
               opening=(H - 0.3, 0.62, 0.48, -0.15))

    SEAT = 0.98

    def star_seat(p):
        return smax(faceted_star(p, (0, 0.05, 0.44), 1.16, 0.52, 0.78, 0.56, wall=0.05, top=0.52), -p[2], 0.01)

    def torso(p):
        return ellipsoid(p, (0.0, 0.04, 1.5), (0.44, 0.37, 0.48))

    arm_r = arm_parts([(-0.38, 0.02, 1.84), (-0.52, -0.3, 1.56), (-0.32, -0.58, 1.86)], [0.15, 0.15, 0.13],
                      (-0.24, -0.66, 1.96), (0.4, -0.3, 0.6), thumb=(1, -0.5, 0.3), hand_r=(0.09, 0.08, 0.1))
    arm_l = arm_parts([(0.38, 0.02, 1.84), (0.5, -0.24, 1.48), (0.34, -0.5, 1.36)], [0.15, 0.15, 0.13],
                      (0.27, -0.58, 1.34), (-0.4, -0.6, -0.3), thumb=(0, -0.4, 1), hand_r=(0.09, 0.09, 0.08))

    def shirt(p):
        d = smax(torso(p), p[2] - 1.96, 0.06)
        return smin(d, np.minimum(arm_r[0](p), arm_l[0](p)), 0.05)

    def gingham(p):
        reg = np.minimum(bands(p[0] + 0.03, 0.13, 0.26), bands(p[2] + 0.02, 0.13, 0.26))
        return overlay(shirt(p), reg, 0.005, depth=0.04, k=0.004)

    def collar(p):
        d = torus(p, (0, -0.02, 1.95), 0.27, 0.06, rot(-16, 0, 0))
        return smax(d, -p[1] - 0.05 - 0.0 * p[2], 0.03)

    def hands(p):
        return np.minimum(arm_r[1](p), arm_l[1](p))

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def skirt(p):
        waist = round_cone(p, (0, 0.04, 1.26), (0, 0.02, SEAT + 0.06), 0.42, 0.52)
        thighs = round_cone(m(p), (0.2, 0.0, SEAT + 0.16), (0.22, -0.46, SEAT + 0.16), 0.24, 0.22)
        d = smax(smin(waist, thighs, 0.12), SEAT - p[2], 0.03)
        return d - 0.016 * np.abs(np.cos(np.arctan2(p[0], -(p[1] + 0.1)) * 11)) ** 0.6

    def shins(p):
        return round_cone(m(p), (0.21, -0.56, SEAT + 0.14), (0.2, -0.66, SEAT + 0.1), 0.11, 0.1)

    def socks(p):
        return round_cone(m(p), (0.2, -0.62, SEAT + 0.12), (0.2, -0.7, SEAT + 0.1), 0.115, 0.11)

    def sock_stripes(p):
        return overlay(socks(p), bands(p[1] + 0.6, 0.07, 0.45), 0.006, depth=0.03, k=0.003)

    heel = np.array([0.2, -0.64, SEAT])

    def shoes(p):
        return shoe(m(p), heel, 0.36, 0.26, 0.2, yaw=-6)

    def soles(p):
        return overlay(shoes(p), p[2] - (SEAT + 0.04), 0.01, depth=0.03, k=0.005)

    NB = np.array([0.06, -0.56, 1.28])
    RNB = rot(-24, 0, -6)

    def notebook(p):
        x, y, z = local(p, NB, RNB)
        dip = 0.06 * np.abs(x) / 0.34
        return round_box((x, y, z - dip), (0, 0, 0), (0.34, 0.24, 0.022), 0.012)

    def nb_doodles(p):
        x, y, z = local(p, NB, RNB)
        lines = [np.abs(star2(x + 0.18, -y + 0.02, 0.07, 0.5)) - 0.007,
                 np.abs(star2(x - 0.12, -y - 0.04, 0.09, 0.5)) - 0.007,
                 np.abs(star2(x - 0.24, -y + 0.1, 0.045, 0.5)) - 0.006]
        reg = np.maximum(union_all(lines), -(z - 0.0))
        return overlay(notebook(p), reg, 0.004, depth=0.02, k=0.002)

    PA, PB = np.array([-0.1, -0.72, 2.14]), np.array([-0.72, -0.78, 1.96])

    def pencil(p):
        return round_cone(p, PA, PA + (PB - PA) * 0.8, 0.036, 0.036)

    def pencil_wood(p):
        tip = PA + (PB - PA) * 0.97
        return round_cone(p, PA + (PB - PA) * 0.79, tip, 0.034, 0.012)

    def pencil_lead(p):
        return sphere(p, PA + (PB - PA) * 0.985, 0.014)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Shirt", shirt, shirt_m, voxel=0.007, tris=10000),
        Comp(f"{N}_Gingham", gingham, check_m, voxel=0.004, tris=14000),
        Comp(f"{N}_Collar", collar, shirt_m, voxel=0.005, tris=3000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Skirt", skirt, skirt_m, voxel=0.006, tris=9000),
        Comp(f"{N}_Legs", shins, skin, voxel=0.005, tris=2000),
        Comp(f"{N}_Socks", socks, sock_m, voxel=0.005, tris=2500),
        Comp(f"{N}_SockStripes", sock_stripes, stripe_m, voxel=0.004, tris=2500),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Soles", soles, sole_m, voxel=0.004, tris=2000),
        Comp(f"{N}_StarSeat", star_seat, star_m, voxel=0.008, tris=4000),
        Comp(f"{N}_Notebook", notebook, paper_m, voxel=0.005, tris=3000),
        Comp(f"{N}_NotebookDoodles", nb_doodles, doodle_m, voxel=0.003, tris=2500),
        Comp(f"{N}_Pencil", pencil, pencil_m, voxel=0.004, tris=2000),
        Comp(f"{N}_PencilWood", pencil_wood, wood_m, voxel=0.004, tris=800),
        Comp(f"{N}_PencilLead", pencil_lead, lead_m, voxel=0.003, tris=300),
    ]
    comps += star_face(N, head, fm, H, look=0.12)
    return assemble(N, "Wishing Star", "Common", comps, {}, ((-1.4, -1.4, -0.2), (1.4, 1.4, 3.7)),
                    catalog="star.wishing")


# ---------------------------------------------------------------- Page Turner Star

def page_turner():
    N = "PageTurner"
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    cm = cat_mats(N)
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    sweater_m = (f"{N}_Sweater", Mat("#F1E5D2", rough=0.9))
    pants_m = (f"{N}_Pants", Mat(["#F2B5BE", "#E3B6CB"], rough=0.85))
    sock_r = (f"{N}_SockGrey", Mat("#DCD8D4", rough=0.85))
    sock_l = (f"{N}_SockPeach", Mat("#F3C7AE", rough=0.85))
    cover_m = (f"{N}_BookCover", Mat("#5E8566", rough=0.6, coat=0.1))
    gold_m = (f"{N}_Gold", Mat("#E1BC63", rough=0.35, metal=0.4))
    page_m = (f"{N}_Pages", Mat("#F4EAD6", rough=0.8))
    cream_m = (f"{N}_TopBook", Mat("#F2E3C2", rough=0.7))
    edge_m = (f"{N}_TopBookEdge", Mat("#93A9D4", rough=0.7))
    pink_m = (f"{N}_PinkBook", Mat("#EE9F9E", rough=0.7))
    blue_m = (f"{N}_BlueBook", Mat("#6F8CC2", rough=0.7))
    star_m = (f"{N}_CatStar", Mat("#F3CF5A", rough=0.5))

    H = 2.08
    head = star_head(H)
    HC = np.array([0.0, 0.05, H + 0.08])
    HR = (0.88, 0.86, 0.78)
    hair_shell = Bob(HC, HR, hem=[(0, H + 0.17), (32, H + 0.15), (44, H + 0.0), (52, H - 0.9), (90, H - 1.1),
                                  (180, H - 1.16)],
                     bell=(H - 0.05, H - 1.16, 0.4), wave=(0.07, 10.0), locks=26, tip=0.11, groove=0.045,
                     puff=0.035,
                     k=0.08, opening=(H - 0.32, 0.62, 0.49, -0.15))
    buns = [np.array([sx * 0.58, 0.4, H + 0.5]) for sx in (-1, 1)]

    def hair(p):
        d = hair_shell(p)
        for b in buns:
            d = smin(d, sphere(p, b, 0.15) - 0.01 * np.abs(np.sin(np.arctan2(p[2] - b[2], p[0] - b[0]) * 6)) ** 0.5,
                     0.05)
        return d

    cat = Cat((-0.12, -0.42, H + 0.96), R=rot(0, 0, -8), s=1.3)

    def cat_body(p):
        d = ellipsoid(p, (0.16, 0.02, H + 0.92), (0.3, 0.42, 0.17), rot(0, 0, 28))
        d = smin(d, cat.head(p), 0.08)
        for c in ((-0.26, -0.62, H + 0.8), (0.04, -0.62, H + 0.8)):
            d = smin(d, ellipsoid(p, c, (0.075, 0.1, 0.06)), 0.04)
        leg = tube(p, [(0.38, -0.12, H + 0.86), (0.52, -0.22, H + 0.72), (0.56, -0.26, H + 0.58)], [0.08, 0.075, 0.07],
                   k=0.03)
        tail = tube(p, [(0.3, 0.32, H + 0.9), (0.52, 0.4, H + 0.82), (0.66, 0.3, H + 0.68)], [0.065, 0.055, 0.045],
                    k=0.03)
        return smin(smin(d, leg, 0.05), tail, 0.04)

    def cat_star(p):
        return puffy_star(p, cat.at((0.0, -0.13, 0.11)), rot(-20, 0, -8), 0.075, 0.5, 0.02, 0.01)

    def torso(p):
        return ellipsoid(p, (0.0, 0.06, 1.1), (0.44, 0.38, 0.44))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.38, 0.04, 1.38), (sx * 0.54, -0.2, 1.1), (sx * 0.52, -0.5, 1.2)],
                            [0.16, 0.16, 0.14], (sx * 0.5, -0.6, 1.26), (-sx * 0.3, -0.5, 0.6), thumb=(-sx, -0.3, 0.5),
                            hand_r=(0.09, 0.08, 0.1)))

    def sweater(p):
        d = smax(torso(p), p[2] - 1.52, 0.06)
        d = smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.05)
        return d - 0.01 * np.abs(np.sin(p[2] * 40.0)) ** 0.5 * np.clip((1.3 - p[2]) / 0.3, 0, 1)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    SEAT = 0.62

    def legs(p):
        d = None
        for sx in (-1, 1):
            hip, knee, ankle = (sx * 0.22, 0.04, SEAT + 0.16), (sx * 0.5, -0.42, SEAT + 0.15), (-sx * 0.04, -0.62, SEAT + 0.14)
            e = smin(round_cone(p, hip, knee, 0.2, 0.17), round_cone(p, knee, ankle, 0.15, 0.13), 0.05)
            d = e if d is None else smin(d, e, 0.04)
        seat = ellipsoid(p, (0, 0.08, SEAT + 0.16), (0.42, 0.34, 0.17))
        return smax(smin(d, seat, 0.08), SEAT - p[2], 0.02)

    def pants_t(x, y, z):
        return np.clip((np.abs(x) - 0.1) / 0.4, 0, 1)

    def sock_a(p):
        return ellipsoid(p, (0.2, -0.68, SEAT + 0.14), (0.15, 0.13, 0.12))

    def sock_b(p):
        return ellipsoid(p, (-0.2, -0.7, SEAT + 0.13), (0.15, 0.13, 0.12))

    BK = np.array([0.0, -0.78, 1.4])

    def covers(p):
        d = None
        for sx in (-1, 1):
            R = rot(0, 0, sx * 32)
            c = BK + R @ np.array([sx * 0.31, 0.0, 0.0])
            e = round_box(p, c, (0.31, 0.024, 0.37), 0.012, R)
            d = e if d is None else np.minimum(d, e)
        spine = cylinder(p, BK + np.array([0, 0.0, 0.0]), 0.05, 0.37, 0.012)
        return smin(d, spine, 0.02)

    def pages(p):
        d = None
        for sx in (-1, 1):
            R = rot(0, 0, sx * 30)
            c = BK + R @ np.array([sx * 0.29, 0.06, 0.02])
            e = round_box(p, c, (0.28, 0.045, 0.35), 0.01, R)
            d = e if d is None else np.minimum(d, e)
        return smax(d, -(covers(p) - 0.004), 0.004)

    def constellations(p):
        reg = None
        for sx in (-1, 1):
            R = rot(0, 0, sx * 32)
            c = BK + R @ np.array([sx * 0.31, 0.0, 0.0])
            u, w, v = local(p, c, R)
            pts = [(-0.15, 0.17), (0.0, 0.22), (0.12, 0.05), (-0.05, -0.07), (0.1, -0.22), (-0.15, -0.17)]
            if sx > 0:
                pts = [(-0.12, 0.2), (0.1, 0.15), (0.15, -0.05), (-0.02, -0.02), (-0.12, -0.2), (0.07, -0.24)]
            lines = [seg2(u, v, a, b, 0.006) for a, b in zip(pts[:-1], pts[1:])]
            dots = [star2(u - a, v - b, 0.03, 0.5) for a, b in pts[::2]]
            e = np.maximum(union_all(lines + dots), w + 0.0)
            reg = e if reg is None else np.minimum(reg, e)
        return overlay(covers(p), reg, 0.006, depth=0.02, k=0.002)

    top = Book((0.0, 0.0, 0.62 - 0.12), (0.88, 0.62, 0.12), spine=1)
    bottom = Book((0.0, 0.0, 0.19), (0.98, 0.7, 0.19), spine=-1)

    def top_edges(p):
        x, y, z = top.q(p)
        reg = np.abs(np.abs(z) - 0.1) - 0.02
        return overlay(top.boards(p), reg, 0.004, depth=0.03, k=0.003)

    def blue_wrap(p):
        return smax(bottom.boards(p), p[0] + 0.32, 0.004)

    def pink_boards(p):
        return smax(bottom.boards(p), -(p[0] + 0.32), 0.004)

    def gold_bands(p):
        x = p[0]
        reg = np.minimum(np.abs(x + 0.26) - 0.022, np.abs(x + 0.36) - 0.016)
        return overlay(bottom.boards(p), reg, 0.008, depth=0.03, k=0.003)

    def book_stars(p):
        reg = np.minimum(np.maximum(star2(p[0] + 0.72, p[2] - 0.2, 0.06, 0.5), p[1] + 0.6),
                         np.maximum(star2(p[0] - 0.62, p[2] - 0.2, 0.05, 0.5), p[1] + 0.6))
        return overlay(bottom.boards(p), reg, 0.006, depth=0.02, k=0.002)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Cat", cat_body, cm["fur"], voxel=0.006, tris=10000),
        Comp(f"{N}_CatStar", cat_star, star_m, voxel=0.003, tris=600),
        Comp(f"{N}_Sweater", sweater, sweater_m, voxel=0.007, tris=11000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Pants", legs, pants_m, voxel=0.006, tris=9000, ramp=pants_t),
        Comp(f"{N}_SockLeft", sock_a, sock_l, voxel=0.005, tris=1500),
        Comp(f"{N}_SockRight", sock_b, sock_r, voxel=0.005, tris=1500),
        Comp(f"{N}_BookCover", covers, cover_m, voxel=0.005, tris=5000),
        Comp(f"{N}_BookPages", pages, page_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Constellations", constellations, gold_m, voxel=0.003, tris=4000),
        Comp(f"{N}_TopBook", top.boards, cream_m, voxel=0.006, tris=5000),
        Comp(f"{N}_TopBookEdge", top_edges, edge_m, voxel=0.004, tris=4000),
        Comp(f"{N}_TopBookPages", top.pages, page_m, voxel=0.005, tris=8000),
        Comp(f"{N}_BottomBookPink", pink_boards, pink_m, voxel=0.006, tris=5000),
        Comp(f"{N}_BottomBookBlue", blue_wrap, blue_m, voxel=0.006, tris=3000),
        Comp(f"{N}_BottomBookPages", bottom.pages, page_m, voxel=0.005, tris=8000),
        Comp(f"{N}_BookBands", gold_bands, gold_m, voxel=0.004, tris=3000),
        Comp(f"{N}_BookStars", book_stars, gold_m, voxel=0.003, tris=800),
    ]
    comps += cat.face(N, cat_body, cm)
    comps += star_face(N, head, fm, H, look=0.06)
    return assemble(N, "Page Turner Star", "Common", comps, {}, ((-1.4, -1.4, -0.2), (1.4, 1.4, 3.6)),
                    catalog="star.page-turner")


# ---------------------------------------------------------------- Nightlight Star

def nightlight():
    N = "Nightlight"
    S_ = 0.82  # the lampshade makes her 4.3 studs at the series head size; scaled to the shelf range
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    shade_m = (f"{N}_Lampshade", Mat("#F5C5C8", rough=0.75))
    print_m = (f"{N}_ShadeStars", Mat("#5E7FCB", rough=0.6))
    cord_m = (f"{N}_Cord", Mat("#6F86C9", rough=0.8))
    cardi_m = (f"{N}_Cardigan", Mat("#F3B9C6", rough=0.95))
    skirt_m = (f"{N}_Dress", Mat("#7E8ED0", rough=0.85))
    sock_m = (f"{N}_Socks", Mat("#F4EEE8", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#F2A9B8", rough=0.45, coat=0.15))
    base_m = (f"{N}_Base", Mat("#8FC4A7", rough=0.9))
    red_m = (f"{N}_RedBook", Mat("#EE7468", rough=0.6, coat=0.1))
    creamb_m = (f"{N}_CreamBook", Mat("#F1E4C6", rough=0.7))
    blueb_m = (f"{N}_BlueBook", Mat("#7E97CF", rough=0.6, coat=0.1))
    page_m = (f"{N}_Pages", Mat("#F6EEDC", rough=0.8))
    gold_m = (f"{N}_Gold", Mat("#E9C25E", rough=0.4, metal=0.3))

    H = 2.38
    head = star_head(H)
    HC = np.array([0.0, 0.05, H + 0.08])
    HR = (0.88, 0.85, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.17), (32, H + 0.15), (44, H + 0.0), (52, H - 0.85), (90, H - 0.95),
                            (180, H - 1.05)],
               bell=(H - 0.05, H - 1.0, 0.4), wave=(0.07, 10.0), locks=26, tip=0.11, groove=0.045,
               puff=0.035, k=0.08, opening=(H - 0.32, 0.62, 0.49, -0.15))

    SB = np.array([0.0, 0.05, 2.76])
    RSH = rot(8, 0, 0)
    SH_H, SH_R0, SH_R1 = 1.3, 1.14, 0.57
    slope = math.atan((SH_R0 - SH_R1) / SH_H)

    def shade_r(z):
        return SH_R0 - (SH_R0 - SH_R1) * z / SH_H

    def shade_shape(p):
        x, y, z = local(p, SB, RSH)
        rho = np.sqrt(x * x + y * y)
        return smax((rho - shade_r(np.clip(z, 0, SH_H))) * math.cos(slope), np.maximum(-z, z - SH_H), 0.03)

    def shade(p):
        x, y, z = local(p, SB, RSH)
        rho = np.sqrt(x * x + y * y)
        wall = np.abs(rho - shade_r(z)) * math.cos(slope) - 0.045
        d = smax(wall, np.maximum(-z, z - SH_H), 0.02)
        rims = np.minimum(torus((x, y, z), (0, 0, 0.02), SH_R0 - 0.01, 0.05), torus((x, y, z), (0, 0, SH_H - 0.02), SH_R1, 0.045))
        return smin(d, rims, 0.02) - 0.003 * waves(p, 25.0, 41)

    rng = np.random.default_rng(5)
    big = [(az, zf, rng.uniform(0.17, 0.26), rng.uniform(-20, 20)) for az, zf in
           ((-40, 0.55), (10, 0.35), (55, 0.62), (100, 0.3), (150, 0.58), (-160, 0.35), (-110, 0.62), (200, 0.75),
            (-80, 0.25))]
    small = [(az, zf) for az, zf in ((-15, 0.7), (30, 0.2), (80, 0.8), (125, 0.15), (-60, 0.85), (175, 0.2),
                                     (-135, 0.2), (-25, 0.2), (40, 0.82), (-95, 0.45))]

    def shade_point(az, zf):
        a = math.radians(az)
        z = zf * SH_H
        r = shade_r(z) + 0.08
        return SB + RSH @ np.array([math.sin(a) * r, -math.cos(a) * r, z]), SB + RSH @ np.array([0, 0, z])

    marks = []
    for az, zf, r, spin in big:
        pt, ax = shade_point(az, zf)
        marks.append((Tangent(shade_shape, ax, pt - ax, spin=spin), "big", r))
    for az, zf in small:
        pt, ax = shade_point(az, zf)
        marks.append((Tangent(shade_shape, ax, pt - ax), "dot", 0.035))

    def shade_stars(p):
        regs = []
        for t, kind, r in marks:
            shape = (lambda u, v, r=r: twinkle2(u, v, r)) if kind == "big" else (lambda u, v, r=r: np.sqrt(u * u + v * v) - r)
            regs.append(t.region(p, shape, reach=0.12))
        return overlay(shade(p), union_all(regs), 0.006, depth=0.03, k=0.003)

    def cord(p):
        path = [(-0.86, -0.46, 3.1), (-0.78, -0.48, 2.72), (-0.8, -0.5, 2.35), (-0.72, -0.45, 2.0), (-0.6, -0.36, 1.74)]
        d = tube(p, path, [0.065] * 5, k=0.02, samples=8)
        return d - 0.01 * np.abs(np.sin(p[2] * 45.0)) ** 0.6

    def torso(p):
        return ellipsoid(p, (0.0, 0.04, 1.36), (0.54, 0.44, 0.5))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.46, 0.02, 1.66), (sx * 0.74, -0.12, 1.36), (sx * 0.68, -0.42, 1.32)],
                            [0.25, 0.27, 0.22], (sx * 0.62, -0.54, 1.3), (-sx, -0.2, 0.0), thumb=(0, -0.2, 1),
                            hand_r=(0.09, 0.08, 0.11)))

    def cardigan(p):
        d = smin(torso(p), round_cone(p, (0, 0.04, 1.3), (0, 0.04, 0.9), 0.52, 0.58), 0.1)
        d = smax(smax(d, p[2] - 1.78, 0.06), 0.84 - p[2], 0.04)
        d = smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.06)
        return d - 0.012 * np.abs(waves(p, 38.0, 43)) - 0.006 * waves(p, 80.0, 44)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    def skirt(p):
        az = np.arctan2(p[0], -(p[1] - 0.02))
        d = round_cone(p, (0, 0.02, 1.0), (0, 0.02, 0.6), 0.52, 0.6)
        return d - 0.016 * np.abs(np.cos(az * 18)) ** 0.6

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def legs(p):
        return round_cone(m(p), (0.17, 0.0, 0.66), (0.17, 0.0, 0.52), 0.1, 0.1)

    def socks(p):
        return round_cone(m(p), (0.17, 0.0, 0.58), (0.17, 0.0, 0.5), 0.11, 0.115)

    heel = np.array([0.17, 0.06, 0.42])

    def shoes(p):
        return shoe(m(p), heel, 0.42, 0.3, 0.2, yaw=-5)

    def base(p):
        d = round_box(p, (0, 0.05, 0.21), (0.78, 0.62, 0.21), 0.07)
        return d - 0.006 * np.abs(waves(p, 30.0, 45))

    books = [Book((0.0, -0.6, 1.13), (0.56, 0.3, 0.11), R=rot(0, 0, -3), spine=-1),
             Book((0.02, -0.6, 1.32), (0.53, 0.29, 0.08), R=rot(0, 0, 2), spine=-1),
             Book((-0.01, -0.62, 1.52), (0.6, 0.31, 0.12), R=rot(0, 0, 4), spine=-1)]

    def top_star(p):
        reg = np.maximum(star2(p[0] + 0.32, p[2] - 1.52, 0.07, 0.5), p[1] + 0.85)
        return overlay(books[2].boards(p), reg, 0.008, depth=0.03, k=0.003)

    def pages(p):
        return union_all([b.pages(p) for b in books])

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Lampshade", shade, shade_m, voxel=0.007, tris=14000),
        Comp(f"{N}_ShadeStars", shade_stars, print_m, voxel=0.004, tris=8000),
        Comp(f"{N}_Cord", cord, cord_m, voxel=0.005, tris=5000),
        Comp(f"{N}_Cardigan", cardigan, cardi_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Dress", skirt, skirt_m, voxel=0.006, tris=9000),
        Comp(f"{N}_Legs", legs, skin, voxel=0.005, tris=1500),
        Comp(f"{N}_Socks", socks, sock_m, voxel=0.005, tris=2000),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Base", base, base_m, voxel=0.008, tris=6000),
        Comp(f"{N}_BlueBook", books[0].boards, blueb_m, voxel=0.005, tris=4000),
        Comp(f"{N}_CreamBook", books[1].boards, creamb_m, voxel=0.005, tris=4000),
        Comp(f"{N}_RedBook", books[2].boards, red_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Pages", pages, page_m, voxel=0.004, tris=10000),
        Comp(f"{N}_BookStar", top_star, gold_m, voxel=0.003, tris=600),
    ]
    comps += star_face(N, head, fm, H, look=0.04)
    scale_comps(comps, S_)
    return assemble(N, "Nightlight Star", "Uncommon", comps, {},
                    scaled_bounds((-1.5, -1.5, -0.2), (1.5, 1.5, 4.5), S_), catalog="star.nightlight")


# ---------------------------------------------------------------- Lamplight Star

def lamplight():
    N = "Lamplight"
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    cm = cat_mats(N)
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    cap_m = (f"{N}_Nightcap", Mat("#5D6EAE", rough=0.9))
    trim_m = (f"{N}_CapTrim", Mat("#F1E5CF", rough=0.95))
    gold_m = (f"{N}_CapStars", Mat("#F2C94C", rough=0.55))
    pj_m = (f"{N}_Pajamas", Mat("#AEBCE8", rough=0.9))
    collar_m = (f"{N}_Collar", Mat("#B7C3EA", rough=0.85))
    pj_star = (f"{N}_PajamaStars", Mat("#F4D77A", rough=0.6))
    feet_m = (f"{N}_Socks", Mat("#F1E2CB", rough=0.85))
    cloud_m = (f"{N}_Cloud", Mat("#F2E6CF", rough=0.8))
    blue_cloud = (f"{N}_BlueCloud", Mat("#6A7CBC", rough=0.85))
    star_m = (f"{N}_Stars", Mat(GLOW, rough=0.3, coat=0.4))

    H = 1.9
    head = star_head(H)
    HC = np.array([0.0, 0.05, H + 0.08])
    HR = (0.88, 0.85, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.12), (32, H + 0.1), (44, H - 0.05), (52, H - 0.55), (90, H - 0.65),
                            (180, H - 0.78)],
               bell=(H - 0.05, H - 0.7, 0.3), wave=(0.055, 11.0), locks=26, tip=0.1, groove=0.04, puff=0.03,
               k=0.07, opening=(H - 0.32, 0.62, 0.47, -0.15))

    TC = np.array([0.0, 0.12, H + 0.58])
    RT = rot(-12, 0, 0)
    tail_path = [(0.0, 0.2, H + 1.02), (0.45, 0.22, H + 1.08), (0.82, 0.12, H + 0.84), (1.0, 0.0, H + 0.42),
                 (1.0, -0.04, H + 0.02)]

    def cap_shape(p):
        dome = ellipsoid(p, TC + np.array([0, 0.03, 0.12]), (0.86, 0.82, 0.62), RT)
        dome = smax(dome, -local(p, TC, RT)[2], 0.04)
        tail = tube(p, tail_path, [0.5, 0.38, 0.27, 0.17, 0.1], k=0.12, samples=8)
        return smin(dome, tail, 0.15)

    def cap(p):
        return cap_shape(p) - 0.006 * waves(p, 24.0, 51)

    def trim(p):
        d = torus(p, TC, 0.84, 0.15, RT)
        return d - 0.008 * np.abs(waves(p, 40.0, 52))

    PP = np.array([1.0, -0.05, H - 0.13])

    def pompom(p):
        return sphere(p, PP, 0.17) - 0.012 * np.abs(waves(p, 40.0, 53))

    dirs = [(-30, 25), (15, 40), (50, 20), (90, 35), (140, 30), (-150, 28), (-95, 40), (180, 55), (-60, 55),
            (30, 70), (110, 60), (-120, 15)]
    cap_t = [Tangent(cap_shape, TC + np.array([0, 0, 0.25]), sph_dir(a, e), spin=a * 0.4) for a, e in dirs]
    cap_t += [Tangent(cap_shape, np.array(tail_path[i]), d_) for i, d_ in ((2, (0.3, -1, 0.5)), (3, (0.2, -1, 0.0)),
                                                                             (2, (0.2, 1, 0.6)), (3, (0.4, 1, 0.0)))]

    def cap_stars(p):
        reg = union_all([t.region(p, lambda u, v: star2(u, v, 0.075, 0.5), reach=0.12) for t in cap_t])
        return overlay(cap_shape(p), reg, 0.014, depth=0.04, k=0.004)

    def torso(p):
        return ellipsoid(p, (0.0, 0.05, 0.86), (0.44, 0.38, 0.42))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.37, 0.03, 1.14), (sx * 0.5, -0.14, 0.88), (sx * 0.32, -0.42, 0.84)],
                            [0.16, 0.16, 0.14], (sx * 0.24, -0.52, 0.88), (-sx, -0.3, 0.2), thumb=(0, -0.2, 1),
                            hand_r=(0.09, 0.08, 0.1)))

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def pajamas(p):
        d = smax(torso(p), p[2] - 1.26, 0.06)
        d = smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.05)
        legs = smin(round_cone(m(p), (0.2, 0.0, 0.62), (0.22, -0.46, 0.64), 0.2, 0.17),
                    round_cone(m(p), (0.22, -0.46, 0.64), (0.23, -0.6, 0.62), 0.16, 0.15), 0.05)
        d = smin(d, legs, 0.08)
        return smax(d, 0.44 - p[2], 0.03) - 0.004 * waves(p, 30.0, 54)

    def collar(p):
        d = torus(p, (0, -0.02, 1.24), 0.27, 0.07, rot(-16, 0, 0))
        return smax(d, -p[1] - 0.1, 0.03)

    pj_t = [Tangent(pajamas, (0, 0.05, 0.86), sph_dir(a, e), spin=a) for a, e in
            ((-60, 10), (60, 15), (-100, -10), (100, -5), (160, 20), (-160, 0), (180, -25), (40, -30))]
    pj_t += [Tangent(pajamas, (sx * 0.2, -0.3, 0.64), (sx * 0.3, 0, 1)) for sx in (-1, 1)]

    def pj_stars(p):
        reg = union_all([t.region(p, lambda u, v: star2(u, v, 0.045, 0.5), reach=0.1) for t in pj_t])
        return overlay(pajamas(p), reg, 0.006, depth=0.03, k=0.003)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    def feet(p):
        return ellipsoid(m(p), (0.24, -0.78, 0.6), (0.14, 0.11, 0.16))

    SC = np.array([0.0, -0.62, 0.92])

    cream = [(0.0, -0.05, 0.22, 0.42)]
    for i in range(11):
        a = math.radians(i * 360 / 11 + 10)
        cream.append((0.98 * math.sin(a), -0.05 - 0.68 * math.cos(a), 0.22 + 0.03 * math.cos(i * 1.7),
                      0.26 + 0.03 * math.sin(i * 2.1)))
    blue = []
    for i in range(9):
        a = math.radians(-100 + i * 25)
        blue.append((1.12 * math.sin(a), 0.22 + 0.45 * -math.cos(a) * 0.55, 0.5 + 0.08 * math.sin(i * 1.3),
                     0.34 + 0.04 * math.cos(i * 1.9)))
    blue += [(-1.12, -0.25, 0.5, 0.32), (1.12, -0.25, 0.48, 0.32), (0.0, 0.42, 0.62, 0.38)]

    def cloud(p):
        return smax(puffs(p, cream, 0.06), -p[2], 0.02) - 0.004 * waves(p, 30.0, 55)

    def cloud_blue(p):
        d = smax(puffs(p, blue, 0.07), 0.1 - p[2], 0.04)
        return smax(d, -(cloud(p) + 0.01), 0.02)

    cat = Cat((-0.98, -0.5, 0.74), R=rot(0, 0, -14), s=1.25)

    def cat_body(p):
        d = ellipsoid(p, (-0.96, -0.2, 0.62), (0.26, 0.32, 0.2), rot(0, 0, -14))
        d = smin(d, cat.head(p), 0.07)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, cat.at((sx * 0.09, -0.12, -0.13)), (0.07, 0.09, 0.05)), 0.03)
        tail = tube(p, [(-0.8, 0.05, 0.56), (-0.62, -0.05, 0.52), (-0.58, -0.25, 0.5)], [0.065, 0.06, 0.05], k=0.03)
        return smin(d, tail, 0.04)

    stars = [(SC, rot(-10, 0, 0), 0.31), (np.array([0.46, -0.76, 0.62]), rot(-8, 0, 18), 0.21),
             (np.array([0.94, -0.48, 0.78]), rot(-6, 0, 32), 0.17), (np.array([-1.24, -0.36, 0.84]), rot(0, 0, -20), 0.11)]

    def glow(p):
        return union_all([puffy_star(p, c, R, r, 0.5, r * 0.28, r * 0.1) for c, R, r in stars])

    def glow_t(x, y, z):
        t = None
        for c, R, r in stars:
            e = np.sqrt((x - c[0]) ** 2 + (y - c[1]) ** 2 + (z - c[2]) ** 2) / r
            t = e if t is None else np.minimum(t, e)
        return np.clip(t, 0, 1)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Nightcap", cap, cap_m, voxel=0.007, tris=14000),
        Comp(f"{N}_CapTrim", trim, trim_m, voxel=0.006, tris=8000),
        Comp(f"{N}_CapStars", cap_stars, gold_m, voxel=0.004, tris=6000),
        Comp(f"{N}_Pompom", pompom, trim_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Pajamas", pajamas, pj_m, voxel=0.007, tris=14000),
        Comp(f"{N}_PajamaStars", pj_stars, pj_star, voxel=0.0035, tris=3000),
        Comp(f"{N}_Collar", collar, collar_m, voxel=0.005, tris=3000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Socks", feet, feet_m, voxel=0.005, tris=2000),
        Comp(f"{N}_Cloud", cloud, cloud_m, voxel=0.008, tris=14000),
        Comp(f"{N}_BlueCloud", cloud_blue, blue_cloud, voxel=0.008, tris=12000),
        Comp(f"{N}_Cat", cat_body, cm["fur"], voxel=0.006, tris=8000),
        Comp(f"{N}_Stars", glow, star_m, voxel=0.005, tris=9000, ramp=glow_t),
    ]
    comps += cat.face(N, cat_body, cm)
    comps += star_face(N, head, fm, H, look=0.12)
    return assemble(N, "Lamplight Star", "Uncommon", comps, {}, ((-1.6, -1.4, -0.2), (1.6, 1.4, 3.4)),
                    catalog="star.lamplight")


# ---------------------------------------------------------------- Garden Star

def garden():
    N = "Garden"
    S_ = 0.86  # the flower hat makes her 4.1 studs at the series head size
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    hat_m = (f"{N}_Hat", Mat("#9DC36F", rough=0.7))
    vein_m = (f"{N}_HatVeins", Mat("#86AE58", rough=0.7))
    leaf_m = (f"{N}_Leaves", Mat("#7FB15A", rough=0.6, coat=0.1))
    petal_m = (f"{N}_Petals", Mat("#FAF7F0", rough=0.5))
    yolk_m = (f"{N}_FlowerCentres", Mat("#F2BE45", rough=0.5))
    jacket_m = (f"{N}_Jacket", Mat("#F3E3C2", rough=0.9))
    shorts_m = (f"{N}_Shorts", Mat("#7EA559", rough=0.8))
    sock_m = (f"{N}_Socks", Mat("#F5ECDC", rough=0.85))
    shoe_m = (f"{N}_Shoes", Mat("#8DB561", rough=0.45, coat=0.15))
    pot_m = (f"{N}_Pot", Mat("#C9805B", rough=0.75))
    soil_m = (f"{N}_Soil", Mat("#6E4A35", rough=0.9))
    bag_m = (f"{N}_Backpack", Mat("#BC8C60", rough=0.7))
    blob_m = (f"{N}_Friend", Mat("#F6F3EE", rough=0.45, coat=0.2))
    dot_m = (f"{N}_FriendFace", Mat("#3A2E29", rough=0.4))
    ground_m = (f"{N}_Ground", Mat("#EADDBA", rough=0.9))
    moss_m = (f"{N}_Moss", Mat("#9CC46D", rough=0.9))

    H = 2.33
    head = star_head(H)
    HC = np.array([0.0, 0.05, H + 0.08])
    HR = (0.88, 0.85, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.14), (32, H + 0.12), (44, H - 0.02), (52, H - 0.7), (90, H - 0.82),
                            (180, H - 0.9)],
               bell=(H - 0.05, H - 0.85, 0.34), wave=(0.06, 11.0), locks=26, tip=0.1, groove=0.04,
               puff=0.03, k=0.07, opening=(H - 0.3, 0.62, 0.48, -0.15))

    # Leaf bucket hat: a domed crown and a wide drooping brim with scalloped leaf edges.
    HB = np.array([0.0, 0.06, H + 0.36])

    def hat_shape(p):
        x, y, z = p[0] - HB[0], p[1] - HB[1], p[2] - HB[2]
        rho = np.sqrt(x * x + y * y)
        az = np.arctan2(x, -y)
        crown = smax(ellipsoid(p, HB + np.array([0, 0, 0.12]), (0.9, 0.86, 0.92)), -z - 0.05, 0.04)
        R_brim = 1.26 + 0.05 * np.cos(az * 9)
        brim_z = -0.04 - 0.2 * np.clip((rho - 0.75) / 0.5, 0, 1) ** 1.4
        brim = smax(np.abs(z - brim_z) - 0.055, rho - R_brim, 0.05)
        return smin(crown, smax(brim, 0.55 - rho, 0.05), 0.12)

    def hat(p):
        az = np.arctan2(p[0] - HB[0], -(p[1] - HB[1]))
        return hat_shape(p) - 0.01 * np.abs(np.sin(az * 6 + 2 * np.sin((p[2] - HB[2]) * 5))) ** 0.5

    def veins(p):
        az = np.arctan2(p[0] - HB[0], -(p[1] - HB[1]))
        el = p[2] - HB[2]
        reg = np.abs(np.sin(az * 6 + 2 * np.sin(el * 5))) - 0.06
        reg = np.maximum(reg, -(el + 0.1))
        return overlay(hat_shape(p), reg * 0.2, 0.006, depth=0.03, k=0.002)

    top_leaves = [Leaf(HB + (0.05, 0.1, 0.98), HB + (-0.3, 0.05, 1.32), 0.17, 0.04, (0.4, -0.5, 0.6), crease=0.02, bend=0.05),
                  Leaf(HB + (0.1, 0.12, 0.98), HB + (0.38, 0.0, 1.3), 0.16, 0.04, (-0.4, -0.5, 0.6), crease=0.02, bend=0.05),
                  Leaf(HB + (0.0, 0.2, 0.96), HB + (0.08, 0.5, 1.22), 0.14, 0.04, (0, -0.3, 0.8), crease=0.02, bend=0.04)]

    def hat_leaves(p):
        return union_all([lf(p) for lf in top_leaves], 0.02)

    daisy_spots = [(-30, 40, 0.24), (25, 52, 0.26), (60, 30, 0.2), (-65, 20, 0.18), (110, 45, 0.19), (-120, 50, 0.2),
                   (170, 35, 0.18), (5, 75, 0.2)]
    daisies = []
    for az, el, r in daisy_spots:
        n = sph_dir(az, el)
        c = surface_point(hat_shape, HB + np.array([0, 0, 0.12]), n) + n * 0.02
        daisies.append(Daisy(c, n, r, spin=az))

    def jacket_torso(p):
        return ellipsoid(p, (0.0, 0.04, 1.3), (0.47, 0.4, 0.44))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.4, 0.02, 1.58), (sx * 0.56, -0.2, 1.3), (sx * 0.32, -0.5, 1.26)],
                            [0.19, 0.19, 0.17], (sx * 0.27, -0.6, 1.26), (-sx, -0.2, 0.1), thumb=(0, -0.2, 1),
                            hand_r=(0.09, 0.08, 0.11)))

    def jacket(p):
        d = smax(jacket_torso(p), p[2] - 1.7, 0.06)
        d = smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.06)
        d = smin(d, torus(p, (0, 0.04, 1.66), 0.3, 0.09), 0.05)  # hood collar
        return d - 0.012 * np.abs(np.sin(p[2] * 22.0)) ** 0.5 - 0.004 * waves(p, 30.0, 61)

    def hands(p):
        return np.minimum(sl[0][1](p), sl[1][1](p))

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def shorts(p):
        d = round_cone(p, (0, 0.04, 1.0), (0, 0.04, 0.82), 0.4, 0.42)
        return smax(d, 0.74 - p[2], 0.03)

    def legs(p):
        return round_cone(m(p), (0.19, 0.03, 0.82), (0.19, 0.02, 0.5), 0.12, 0.11)

    def socks(p):
        d = round_cone(m(p), (0.19, 0.02, 0.66), (0.19, 0.02, 0.5), 0.125, 0.125)
        frill = torus(m(p), (0.19, 0.02, 0.68), 0.12, 0.04) - 0.01 * np.abs(np.cos(np.arctan2(p[1], np.abs(p[0]) - 0.19) * 9))
        return smin(d, frill, 0.02)

    heel = np.array([0.2, 0.08, 0.3])

    def shoes(p):
        d = shoe(m(p), heel, 0.5, 0.36, 0.25, yaw=-6)
        return smin(d, bow(m(p), heel + np.array([0.0, -0.3, 0.2]), rot(-30, 0, 0), 0.07), 0.01)

    PC = np.array([0.0, -0.66, 1.24])

    def pot(p):
        x, y, z = p[0] - PC[0], p[1] - PC[1], p[2] - PC[2]
        rho = np.sqrt(x * x + y * y)
        body = smax(rho - (0.24 + 0.06 * (z + 0.22) / 0.4), np.abs(z) - 0.2, 0.03)
        rim = smax(np.abs(z - 0.17) - 0.06, rho - 0.33, 0.02)
        d = smin(body, rim, 0.02)
        return smax(d, -smax(rho - 0.26, -(z - 0.14), 0.02), 0.02)

    def soil(p):
        return cylinder(p, PC + np.array([0, 0, 0.13]), 0.27, 0.03, 0.01)

    sprout = [Leaf(PC + (0.0, 0.0, 0.16), PC + (-0.32, -0.08, 0.5), 0.15, 0.035, (0.5, -0.3, 0.8), crease=0.02,
                   bend=0.06),
              Leaf(PC + (0.0, 0.0, 0.16), PC + (0.32, -0.06, 0.52), 0.15, 0.035, (-0.5, -0.3, 0.8), crease=0.02,
                   bend=0.06)]

    def sprout_fn(p):
        stem = round_cone(p, PC + (0, 0, 0.12), PC + (0, -0.02, 0.24), 0.03, 0.025)
        return smin(stem, union_all([lf(p) for lf in sprout], 0.02), 0.02)

    pot_daisy = Daisy(PC + np.array([0.0, -0.31, -0.03]), (0, -1, 0), 0.075)

    BP = np.array([0.0, 0.5, 1.28])

    def backpack(p):
        return round_box(p, BP, (0.3, 0.12, 0.3), 0.1)

    def straps(p):
        return fold(lambda q: tube(q, [(0.22, 0.42, 1.55), (0.3, 0.0, 1.72), (0.36, -0.3, 1.55), (0.36, -0.34, 1.2)],
                                   [0.035] * 4, k=0.01))(p)

    bag_daisy = Daisy(BP + np.array([0.0, 0.14, 0.0]), (0, 1, 0), 0.1)

    FC = np.array([-0.92, -0.4, 0.66])

    def friend(p):
        return smax(ellipsoid(p, FC, (0.42, 0.38, 0.38)), 0.3 - p[2], 0.03)

    def friend_face(p):
        u, w, v = local(p, FC, rot(0, 0, -15))
        reg = np.minimum(np.minimum(ellipse2(u - 0.1, v - 0.04, 0.022, 0.028), ellipse2(u + 0.1, v - 0.04, 0.022, 0.028)),
                         np.minimum(arc2(u - 0.018, v + 0.03, 0.018, 70, 0.006), arc2(u + 0.018, v + 0.03, 0.018, 70, 0.006)))
        return overlay(friend(p), np.maximum(reg, w + 0.2), 0.008, depth=0.03, k=0.002)

    def ground(p):
        x, y = p[0], p[1] - 0.05
        d = smax(np.sqrt((x / 1.4) ** 2 + (y / 1.1) ** 2) * 1.1 - 1.1, np.abs(p[2] - 0.15) - 0.15, 0.05)
        return d - 0.008 * waves(p, 12.0, 62)

    def moss(p):
        reg = 0.25 * waves(p, 6.0, 63) + 0.1
        reg = np.maximum(reg, 0.25 - p[2])
        return overlay(ground(p), reg, 0.025, depth=0.04, k=0.02) - 0.008 * np.abs(waves(p, 45.0, 64))

    clovers = [((-1.22, -0.2, 0.28), 0.42, 0), ((-1.05, 0.4, 0.28), 0.5, 40), ((1.18, -0.28, 0.28), 0.36, 15),
               ((1.12, 0.32, 0.28), 0.55, 70), ((0.55, -0.72, 0.28), 0.22, 30), ((-0.42, 0.72, 0.28), 0.4, 10),
               ((0.5, 0.66, 0.28), 0.3, 55), ((-0.55, -0.82, 0.28), 0.18, 80)]

    def clover_fn(p):
        return union_all([clover(p, b, h, 0.26, 3, s) for b, h, s in clovers], 0.01)

    ground_daisies = [Daisy(c, (0.0, -0.3, 1.0), 0.07, spin=i * 20) for i, c in
                      enumerate([(-0.3, -0.85, 0.31), (0.85, -0.6, 0.31), (-1.25, 0.1, 0.31), (0.25, -0.8, 0.31),
                                 (1.0, 0.0, 0.31)])]

    all_daisies = daisies + [pot_daisy, bag_daisy] + ground_daisies

    def petals(p):
        return union_all([d.petals(p) for d in all_daisies])

    def centres(p):
        return union_all([d.centre(p) for d in all_daisies])

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Hat", hat, hat_m, voxel=0.007, tris=16000),
        Comp(f"{N}_HatVeins", veins, vein_m, voxel=0.004, tris=8000),
        Comp(f"{N}_HatLeaves", hat_leaves, leaf_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Petals", petals, petal_m, voxel=0.0035, tris=16000),
        Comp(f"{N}_FlowerCentres", centres, yolk_m, voxel=0.0035, tris=4000),
        Comp(f"{N}_Jacket", jacket, jacket_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Shorts", shorts, shorts_m, voxel=0.006, tris=5000),
        Comp(f"{N}_Legs", legs, skin, voxel=0.005, tris=2000),
        Comp(f"{N}_Socks", socks, sock_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.005, tris=6000),
        Comp(f"{N}_Pot", pot, pot_m, voxel=0.005, tris=5000),
        Comp(f"{N}_Soil", soil, soil_m, voxel=0.005, tris=1200),
        Comp(f"{N}_Sprout", sprout_fn, leaf_m, voxel=0.004, tris=3000),
        Comp(f"{N}_Backpack", backpack, bag_m, voxel=0.006, tris=4000),
        Comp(f"{N}_Straps", straps, bag_m, voxel=0.005, tris=3000),
        Comp(f"{N}_Friend", friend, blob_m, voxel=0.006, tris=6000),
        Comp(f"{N}_FriendFace", friend_face, dot_m, voxel=0.003, tris=800),
        Comp(f"{N}_Ground", ground, ground_m, voxel=0.008, tris=8000),
        Comp(f"{N}_Moss", moss, moss_m, voxel=0.006, tris=12000),
        Comp(f"{N}_Clover", clover_fn, leaf_m, voxel=0.004, tris=14000),
    ]
    comps += star_face(N, head, fm, H, look=0.1)
    scale_comps(comps, S_)
    return assemble(N, "Garden Star", "Uncommon", comps, {}, scaled_bounds((-1.7, -1.5, -0.2), (1.7, 1.5, 4.4), S_),
                    catalog="star.garden")


# ---------------------------------------------------------------- Sanctuary Star

def sanctuary():
    N = "Sanctuary"
    S_ = 0.95
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    cm = cat_mats(N)
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    cream_m = (f"{N}_Sweater", Mat("#F7EEDC", rough=0.9))
    orange_m = (f"{N}_Stripes", Mat("#F09A45", rough=0.9))
    shorts_m = (f"{N}_Shorts", Mat("#F2E8D6", rough=0.85))
    boot_m = (f"{N}_Boots", Mat("#F4C440", rough=0.35, coat=0.3))
    canopy_m = (f"{N}_Canopy", Mat("#A9C4F0", rough=0.15, alpha=0.45, coat=0.6))
    rib_m = (f"{N}_Ribs", Mat("#7C9FE0", rough=0.3, coat=0.3))
    ustar_m = (f"{N}_CanopyStars", Mat("#F5D25C", rough=0.4))
    handle_m = (f"{N}_Handle", Mat("#F2CF55", rough=0.35, coat=0.3))
    grass_m = (f"{N}_Grass", Mat("#7DBE4F", rough=0.85))
    flower_m = (f"{N}_Petals", Mat("#FAF7F0", rough=0.5))
    yolk_m = (f"{N}_FlowerCentres", Mat("#F2BE45", rough=0.5))
    leaf_m = (f"{N}_Leaves", Mat("#5FA840", rough=0.6))

    H = 2.31
    head = star_head(H)
    HC = np.array([0.0, 0.04, H + 0.08])
    HR = (0.88, 0.85, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.14), (32, H + 0.12), (44, H - 0.02), (52, H - 0.55), (90, H - 0.62),
                            (180, H - 0.72)],
               bell=(H - 0.05, H - 0.66, 0.14), roll=0.13, locks=40, tip=0.05, groove=0.024, puff=0.014, k=0.06,
               opening=(H - 0.3, 0.62, 0.47, -0.15))

    def torso(p):
        return ellipsoid(p, (0.0, 0.04, 1.36), (0.44, 0.37, 0.42))

    arm_r = arm_parts([(-0.38, 0.02, 1.62), (-0.52, -0.06, 1.3), (-0.44, -0.12, 1.06)], [0.16, 0.16, 0.14],
                      (-0.42, -0.16, 0.94), (0.1, -0.1, -1.0), thumb=(0.3, -1, 0), hand_r=(0.1, 0.08, 0.12))
    arm_l = arm_parts([(0.38, 0.02, 1.62), (0.58, -0.18, 1.42), (0.74, -0.36, 1.5)], [0.16, 0.16, 0.14],
                      (0.8, -0.42, 1.48), (0.2, -0.3, -0.4), thumb=(-0.5, -0.4, 0.6), hand_r=(0.1, 0.09, 0.1))

    def sweater(p):
        d = smax(torso(p), p[2] - 1.74, 0.06)
        d = smin(d, np.minimum(arm_r[0](p), arm_l[0](p)), 0.05)
        return d - 0.008 * np.abs(np.sin(p[0] * 40.0) * np.sin(p[2] * 40.0)) ** 0.5

    def stripes(p):
        reg = bands(p[2] - 0.98, 0.16, 0.5)
        reg = np.maximum(reg, 1.0 - p[2])
        return overlay(sweater(p), reg, 0.006, depth=0.04, k=0.003)

    def hands(p):
        return np.minimum(arm_r[1](p), arm_l[1](p))

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def shorts(p):
        d = round_cone(p, (0, 0.03, 1.08), (0, 0.03, 0.86), 0.39, 0.42)
        return smax(d, 0.8 - p[2], 0.03)

    def legs(p):
        return round_cone(m(p), (0.18, 0.03, 0.86), (0.18, 0.02, 0.5), 0.11, 0.1)

    def boots(p):
        d = round_cone(m(p), (0.18, 0.02, 0.62), (0.18, 0.0, 0.32), 0.15, 0.16)
        d = smin(d, shoe(m(p), np.array([0.18, 0.08, 0.25]), 0.48, 0.34, 0.24, yaw=-5), 0.06)
        top = torus(m(p), (0.18, 0.02, 0.63), 0.14, 0.035)
        return smin(d, top, 0.02)

    # Clear umbrella, tilted toward the character's left, shaft down to her raised left hand.
    UC = np.array([-0.13, -0.05, 3.56])  # centred so the tilted canopy balances the bounds (runtime facing)
    RU = rot(-6, -12, 0)  # tilted along the shaft, rim low on the character's right as on the sheet
    ribs_n = 8

    def can_coords(p):
        x, y, z = local(p, UC, RU)
        rho = np.sqrt(x * x + y * y)
        az = np.arctan2(y, x)
        return x, y, z, rho, az

    def canopy_surface_z(rho):
        return -0.68 * (rho / 1.45) ** 1.6

    def canopy(p):
        x, y, z, rho, az = can_coords(p)
        f = az / (2 * math.pi) * ribs_n
        f = f - np.floor(f) - 0.5
        scallop = 1.45 - 0.1 * (1 - (2 * f) ** 2)
        sag = 0.04 * (1 - np.abs(2 * f)) * (rho / 1.3)
        d = np.abs(z - canopy_surface_z(rho) + sag) - 0.035
        return smax(d, rho - scallop, 0.03)

    def ribs(p):
        x, y, z, rho, az = can_coords(p)
        f = az / (2 * math.pi) * ribs_n
        f = f - np.floor(f + 0.5)
        across = np.abs(f) * 2 * math.pi / ribs_n * rho
        d = np.sqrt(across ** 2 + (z - canopy_surface_z(rho) - 0.02) ** 2) - 0.03
        d = smax(d, rho - 1.47, 0.02)
        tips = None
        for i in range(ribs_n):
            a = (i + 0.0) * 2 * math.pi / ribs_n
            c = UC + RU @ np.array([1.46 * math.cos(a), 1.46 * math.sin(a), canopy_surface_z(1.46)])
            e = sphere(p, c, 0.045)
            tips = e if tips is None else np.minimum(tips, e)
        return np.minimum(d, tips)

    star_spots = [(0.55, 20), (1.0, 70), (0.78, 135), (1.12, 200), (0.6, 250), (1.05, 300), (0.38, 330), (0.95, 165),
                  (1.18, 25), (0.85, 105), (1.2, 250)]

    def canopy_stars(p):
        x, y, z, rho, az = can_coords(p)
        reg = None
        for r, a in star_spots:
            a = math.radians(a)
            e = star2(x - r * math.cos(a), y - r * math.sin(a), 0.085, 0.5)
            reg = e if reg is None else np.minimum(reg, e)
        top = np.abs(z - canopy_surface_z(rho) - 0.0) - 0.05
        return smax(reg, top, 0.004)

    TOP = UC + RU @ np.array([0, 0, 0.0])
    SH_B = np.array([0.82, -0.42, 1.36])

    def shaft(p):
        d = round_cone(p, TOP + RU @ np.array([0, 0, -0.05]), SH_B, 0.035, 0.035)
        knob = ellipsoid(p, TOP + RU @ np.array([0, 0, 0.06]), (0.13, 0.13, 0.08), RU)
        ax = unit(SH_B - TOP)
        hook = tube(p, [SH_B, SH_B + ax * 0.2, SH_B + ax * 0.3 + np.array([-0.08, 0, -0.02]),
                        SH_B + ax * 0.22 + np.array([-0.18, 0, 0.0])], [0.05, 0.05, 0.05, 0.05], k=0.02, samples=8)
        return smin(smin(d, knob, 0.03), hook, 0.03)

    cat = Cat((-0.66, -0.62, 1.1), R=rot(0, 0, -10), s=1.75)

    def cat_body(p):
        d = ellipsoid(p, (-0.7, -0.42, 0.62), (0.34, 0.3, 0.4), rot(-12, 0, 0))
        d = smin(d, cat.head(p), 0.1)
        for sx in (-1, 1):
            d = smin(d, round_cone(p, cat.at((sx * 0.1, -0.05, -0.3)), cat.at((sx * 0.11, -0.08, -0.48)), 0.075, 0.07),
                     0.05)
            d = smin(d, ellipsoid(p, cat.at((sx * 0.12, -0.13, -0.5)), (0.085, 0.11, 0.06)), 0.03)
        tail = tube(p, [(-0.9, -0.2, 0.36), (-1.08, -0.1, 0.58), (-1.06, -0.18, 0.86), (-0.96, -0.26, 0.96)],
                    [0.08, 0.075, 0.07, 0.06], k=0.03)
        return smax(smin(d, tail, 0.05), 0.24 - p[2], 0.02)

    def grass(p):
        d = smax(np.sqrt(p[0] ** 2 + (p[1] - 0.02) ** 2) - 1.08, np.abs(p[2] - 0.125) - 0.125, 0.06)
        return d - 0.018 * np.abs(waves(p, 40.0, 71)) - 0.01 * waves(p, 12.0, 72)

    flowers = [Daisy(c, (0.0, -0.4, 1.0), 0.06, petals=6, spin=i * 25) for i, c in
               enumerate([(-0.25, -0.85, 0.27), (0.6, -0.72, 0.27), (0.95, -0.2, 0.27), (-0.95, 0.3, 0.27),
                          (0.3, 0.85, 0.27), (-0.5, 0.8, 0.27), (0.1, -0.95, 0.24), (0.85, 0.5, 0.27)])]

    def petals(p):
        return union_all([f.petals(p) for f in flowers])

    def centres(p):
        return union_all([f.centre(p) for f in flowers])

    sprigs = [((-0.0, -0.75, 0.24), 25), ((0.78, -0.48, 0.24), 70), ((-0.85, -0.1, 0.24), 10), ((0.65, 0.65, 0.24), 45),
              ((-0.7, 0.62, 0.24), 80), ((0.35, -0.9, 0.22), 50)]

    def leaves(p):
        d = None
        for (x, y, z), s in sprigs:
            for k in range(3):
                a = math.radians(s + k * 120)
                lf = Leaf((x, y, z), (x + 0.16 * math.cos(a), y + 0.16 * math.sin(a), z + 0.14), 0.06, 0.025,
                          (0, 0, 1), mid=0.5, r_base=0.02, r_tip=0.02, crease=0.01)
                e = lf(p)
                d = e if d is None else np.minimum(d, e)
        return d

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Sweater", sweater, cream_m, voxel=0.006, tris=12000),
        Comp(f"{N}_Stripes", stripes, orange_m, voxel=0.0045, tris=12000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Shorts", shorts, shorts_m, voxel=0.006, tris=5000),
        Comp(f"{N}_Legs", legs, skin, voxel=0.005, tris=2000),
        Comp(f"{N}_Boots", boots, boot_m, voxel=0.005, tris=7000),
        Comp(f"{N}_Canopy", canopy, canopy_m, voxel=0.006, tris=14000),
        Comp(f"{N}_Ribs", ribs, rib_m, voxel=0.005, tris=8000),
        Comp(f"{N}_CanopyStars", canopy_stars, ustar_m, voxel=0.004, tris=6000),
        Comp(f"{N}_Handle", shaft, handle_m, voxel=0.005, tris=5000),
        Comp(f"{N}_Cat", cat_body, cm["fur"], voxel=0.006, tris=10000),
        Comp(f"{N}_Grass", grass, grass_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Petals", petals, flower_m, voxel=0.003, tris=6000),
        Comp(f"{N}_FlowerCentres", centres, yolk_m, voxel=0.003, tris=1500),
        Comp(f"{N}_Leaves", leaves, leaf_m, voxel=0.004, tris=6000),
    ]
    comps += cat.face(N, cat_body, cm)
    comps += star_face(N, head, fm, H, look=0.12)
    scale_comps(comps, S_)
    return assemble(N, "Sanctuary Star", "Rare", comps, {}, scaled_bounds((-1.6, -1.5, -0.2), (1.8, 1.5, 4.0), S_),
                    catalog="star.sanctuary")


# ---------------------------------------------------------------- Echo Star

def echo():
    N = "Echo"
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    lav_m = (f"{N}_Lavender", Mat("#B7A3D8", rough=0.85))
    dress_m = (f"{N}_Dress", Mat("#BBA8DA", rough=0.9))
    yellow_m = (f"{N}_StarPrints", Mat("#F2CF63", rough=0.55))
    shoe_m = (f"{N}_Shoes", Mat("#EEE4D2", rough=0.5, coat=0.15))
    glass_m = (f"{N}_Jar", Mat("#E6EEF4", rough=0.08, alpha=0.4, coat=0.8))
    lid_m = (f"{N}_Lid", Mat("#C8CAD2", rough=0.3, metal=0.6))
    cotton_m = (f"{N}_Clouds", Mat("#F6F2EC", rough=0.7))
    star_m = (f"{N}_Star", Mat(GLOW, rough=0.3, coat=0.4))

    H = 2.0
    pivot = np.array([0.0, 0.0, H - 0.72])
    tilt = rot(0, 8, 0)
    head = star_head(H)
    HC = np.array([0.0, 0.05, H + 0.08])
    HR = (0.88, 0.85, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.15), (32, H + 0.13), (44, H - 0.02), (52, H - 0.8), (90, H - 0.92),
                            (180, H - 1.0)],
               bell=(H - 0.05, H - 0.95, 0.42), wave=(0.06, 11.0), locks=26, tip=0.1, groove=0.04,
               puff=0.03, k=0.08, opening=(H - 0.32, 0.62, 0.48, -0.15))

    RB = rot(-14, 0, 0)

    def band(p):
        x, y, z = local(p, HC, RB)
        rho = np.sqrt(x * x + z * z)
        d = smax(np.abs(rho - 0.9) - 0.06, np.abs(y + 0.05) - 0.17, 0.05)
        d = smax(d, -z - 0.1, 0.05)
        return d - 0.008 * np.abs(np.sin(np.arctan2(x, z) * 14)) ** 0.5

    BW = HC + RB @ np.array([-0.42, -0.05, 0.84])
    RBW = rot(-10, 0, -20) @ rot(0, -35, 0)

    def bow_fn(p):
        d = bow(p, BW, RBW, 0.3)
        for sx, ln in ((-1, 0.55), (1, 0.38)):
            tail = Leaf(BW + np.array([0.0, 0.05, -0.05]), BW + np.array([sx * 0.12 - 0.25, 0.1, -ln]), 0.08, 0.025,
                        (0, -1, 0.2), mid=0.4, r_base=0.05, r_tip=0.06, bend=0.03)
            d = smin(d, tail(p), 0.02)
        return d - 0.006 * np.abs(np.sin(p[2] * 40)) ** 0.5

    def side_tails(p):
        a = HC + np.array([-0.84, -0.12, 0.25])
        return union_all([Leaf(a, a + np.array([dx, -0.06, -0.85]), 0.075, 0.025, (-1, -0.4, 0), mid=0.35, r_base=0.06,
                               r_tip=0.06, bend=0.04)(p) for dx in (-0.06, 0.06)], 0.02)

    clip_c = HC + np.array([-0.93, -0.32, 0.12])

    def clip(p):
        return puffy_star(p, clip_c, rot(0, 0, -60), 0.14, 0.5, 0.04, 0.02)

    band_marks = []
    for th in (-62, -30, 8, 44, 76):
        t = math.radians(th)
        radial = RB @ np.array([math.sin(t), 0.0, math.cos(t)])
        band_marks.append(Tangent(band, HC + RB @ np.array([0.0, -0.05, 0.0]) + radial * 0.9, radial, spin=th * 0.5))

    def band_stars(p):
        reg = union_all([t.region(p, lambda u, v: star2(u, v, 0.06, 0.5), reach=0.1) for t in band_marks])
        return overlay(band(p), reg, 0.008, depth=0.03, k=0.003)

    head_group = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Headband", band, lav_m, voxel=0.005, tris=8000),
        Comp(f"{N}_Bow", bow_fn, lav_m, voxel=0.005, tris=8000),
        Comp(f"{N}_BowTails", side_tails, lav_m, voxel=0.004, tris=3000),
        Comp(f"{N}_StarClip", clip, yellow_m, voxel=0.004, tris=1500),
        Comp(f"{N}_HeadbandStars", band_stars, yellow_m, voxel=0.0035, tris=1500),
    ]
    head_group += star_face(N, head, fm, H, look=0.16)
    pose_comps(head_group, pivot, tilt)

    JC = np.array([0.46, -0.6, 0.0])
    JR, JH = 0.46, 1.26

    def jar_solid(p):
        x, y, z = p[0] - JC[0], p[1] - JC[1], p[2] - JC[2]
        rho = np.sqrt(x * x + y * y)
        r = np.where(z > JH - 0.18, JR - 0.1 * np.clip((z - (JH - 0.18)) / 0.08, 0, 1), JR)
        return smax(smax(rho - r, -z + 0.03, 0.08), z - JH, 0.04)

    def jar(p):
        return np.abs(jar_solid(p)) - 0.022

    def lid(p):
        x, y, z = p[0] - JC[0], p[1] - JC[1], p[2] - JC[2]
        d = cylinder(p, JC + np.array([0, 0, JH + 0.06]), JR - 0.04, 0.07, 0.03)
        return d - 0.006 * np.abs(np.cos(np.arctan2(x, -y) * 30)) ** 0.5

    cotton = [(JC[0] + x, JC[1] + y, 0.16 + z, r) for x, y, z, r in
              ((0.0, 0.0, 0.02, 0.14), (0.22, 0.08, 0.0, 0.13), (-0.22, 0.06, 0.0, 0.13), (0.1, -0.22, 0.0, 0.13),
               (-0.12, -0.2, 0.02, 0.13), (0.24, -0.16, 0.12, 0.11), (-0.24, -0.12, 0.13, 0.11), (0.0, 0.24, 0.1, 0.12),
               (0.05, -0.1, 0.18, 0.12))]

    def clouds(p):
        return smax(puffs(p, cotton, 0.03), jar_solid(p) + 0.03, 0.02)

    SC = JC + np.array([0.0, 0.0, 0.66])

    def star(p):
        return puffy_star(p, SC, rot(-6, 0, 4), 0.3, 0.5, 0.09, 0.035)

    JB = JC + np.array([0.43, -0.12, 1.02])

    def jar_bow(p):
        d = bow(p, JB, rot(0, 0, 45) @ rot(0, 70, 0), 0.13)
        string = round_cone(p, JB, JB + np.array([0.04, -0.02, -0.26]), 0.018, 0.018)
        return smin(d, string, 0.01)

    def charm(p):
        return puffy_star(p, JB + np.array([0.05, -0.03, -0.36]), rot(0, 0, 40), 0.1, 0.5, 0.035, 0.015)

    def torso(p):
        return ellipsoid(p, (0.0, 0.08, 1.0), (0.42, 0.36, 0.4))

    arm_r = arm_parts([(-0.37, 0.06, 1.24), (-0.44, -0.3, 0.98), (-0.2, -0.6, 1.06)], [0.15, 0.15, 0.13],
                      (-0.04, -0.68, 1.12), (1, -0.3, 0.0), thumb=(0, -0.3, 1), hand_r=(0.09, 0.08, 0.11))
    arm_l = arm_parts([(0.37, 0.06, 1.24), (0.56, -0.24, 1.3), (0.5, -0.5, 1.44)], [0.15, 0.15, 0.13],
                      (0.48, -0.58, 1.46), (0.0, -0.4, -1.0), thumb=(-1, -0.3, 0), hand_r=(0.1, 0.11, 0.07))

    def dress(p):
        d = smax(torso(p), p[2] - 1.36, 0.06)
        d = smin(d, np.minimum(arm_r[0](p), arm_l[0](p)), 0.05)
        x, y = p[0], p[1] - 0.12
        rho = np.sqrt((x / 1.25) ** 2 + (y / 0.95) ** 2)
        pool = 0.42 + 0.7 * np.clip(1.0 - p[2] / 0.7, 0, 1) ** 1.8  # the dress pools on the ground round her knees
        skirt = smax(rho * 1.1 - pool * 1.1, p[2] - 0.92, 0.1)
        skirt = skirt - 0.025 * np.abs(np.sin(np.arctan2(x, -y) * 7)) ** 0.7 * np.clip(1 - p[2] / 0.6, 0, 1)
        d = smin(d, skirt, 0.12)
        return smax(d, -p[2], 0.02)

    dress_stars = star_prints(dress, (0, 0.08, 0.5), [sph_dir(a, e) for a, e in
                                                     ((-70, -15), (-110, -5), (-150, -20), (170, -10), (130, -25),
                                                      (90, -30), (-40, -35), (-90, 20), (150, 15), (-130, 25), (60, -10),
                                                      (-20, -45), (110, 10))], 0.07)

    def hands(p):
        return np.minimum(arm_r[1](p), arm_l[1](p))

    def shoes(p):
        a = shoe(p, np.array([-0.66, -0.74, 0.0]), 0.42, 0.32, 0.24, yaw=-14)
        b = shoe(p, np.array([-0.24, -0.86, 0.0]), 0.42, 0.32, 0.24, yaw=4)
        return np.minimum(a, b)

    comps = head_group + [
        Comp(f"{N}_Dress", dress, dress_m, voxel=0.007, tris=16000),
        Comp(f"{N}_DressStars", dress_stars, yellow_m, voxel=0.0035, tris=4000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=4000),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Jar", jar, glass_m, voxel=0.005, tris=10000),
        Comp(f"{N}_Lid", lid, lid_m, voxel=0.005, tris=5000),
        Comp(f"{N}_Clouds", clouds, cotton_m, voxel=0.005, tris=6000),
        Comp(f"{N}_Star", star, star_m, voxel=0.005, tris=5000, ramp=star_ramp(SC, 0.3)),
        Comp(f"{N}_JarBow", jar_bow, lav_m, voxel=0.004, tris=3000),
        Comp(f"{N}_Charm", charm, yellow_m, voxel=0.004, tris=1200),
    ]
    return assemble(N, "Echo Star", "Rare", comps, {}, ((-1.5, -1.4, -0.2), (1.5, 1.4, 3.6)),
                    catalog="star.echo")


# ---------------------------------------------------------------- Radiant Star

def radiant():
    N = "Radiant"
    S_ = 0.88  # the wizard hat makes her 4 studs at the series head size
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    hat_m = (f"{N}_Hat", Mat("#F5C35A", rough=0.85))
    cream_m = (f"{N}_Cream", Mat("#F8EED8", rough=0.7))
    robe_m = (f"{N}_Robe", Mat("#F6D47A", rough=0.85))
    cape_m = (f"{N}_Cape", Mat("#F4B27E", rough=0.8))
    boot_m = (f"{N}_Boots", Mat("#F6E3B4", rough=0.5, coat=0.15))
    bow_m = (f"{N}_Bow", Mat("#A7BDEB", rough=0.4, coat=0.3))
    wand_m = (f"{N}_WandRing", Mat("#A9C4F2", rough=0.2, coat=0.6))
    stick_m = (f"{N}_WandStick", Mat("#D9A867", rough=0.5))
    cloud_m = (f"{N}_Cloud", Mat("#F6EEDE", rough=0.75))
    star_m = (f"{N}_Stars", Mat(["#FFF0B0", "#FAD66C", "#F4C04C"], rough=0.45, coat=0.3))
    pearl_m = (f"{N}_Pearls", Mat("#F8F0E2", rough=0.25, coat=0.6))

    H = 2.23
    head = star_head(H)
    HC = np.array([0.0, 0.05, H + 0.08])
    HR = (0.88, 0.85, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.13), (32, H + 0.11), (44, H - 0.04), (52, H - 0.82), (90, H - 0.92),
                            (180, H - 0.95)],
               bell=(H - 0.05, H - 0.92, 0.36), wave=(0.065, 11.0), locks=34, tip=0.09, groove=0.028,
               puff=0.018, k=0.07, opening=(H - 0.32, 0.62, 0.48, -0.15))

    HB = np.array([0.0, 0.06, H + 0.32])
    hat_path = [HB + (0, 0.02, 0.1), HB + (0.0, 0.06, 0.48), HB + (0.08, 0.1, 0.8), HB + (0.26, 0.08, 1.0),
                HB + (0.44, 0.02, 1.06)]

    def hat_shape(p):
        x, y, z = p[0] - HB[0], p[1] - HB[1], p[2] - HB[2]
        rho = np.sqrt(x * x + y * y)
        brim = smax(np.abs(z - 0.02 + 0.1 * np.clip((rho - 0.7) / 0.45, 0, 1)) - 0.07, rho - 1.15, 0.06)
        cone = tube(p, hat_path, [0.8, 0.56, 0.34, 0.17, 0.07], k=0.1, samples=8)
        cone = smax(cone, -z, 0.05)
        return smin(brim, cone, 0.12)

    def hat(p):
        return hat_shape(p) - 0.005 * waves(p, 25.0, 81)

    hat_t = [Tangent(hat_shape, HB + (0, 0.05, 0.3), sph_dir(a, e), spin=a) for a, e in
             ((-35, 20), (25, 35), (70, 15), (120, 30), (170, 20), (-120, 25), (-75, 45), (40, 60), (-170, 50))]

    def hat_stars(p):
        reg = union_all([t.region(p, lambda u, v: star2(u, v, 0.13, 0.5), reach=0.16) for t in hat_t])
        return overlay(hat_shape(p), reg, 0.06, depth=0.05, k=0.02)

    TIP = hat_path[-1]

    def tip_charm(p):
        string = round_cone(p, TIP, TIP + np.array([0.06, -0.02, -0.34]), 0.016, 0.016)
        ball = sphere(p, TIP + np.array([0.0, 0.0, 0.0]), 0.07)
        bead = sphere(p, TIP + np.array([0.06, -0.02, -0.38]), 0.06)
        return union_all([string, ball, bead], 0.01)

    def torso(p):
        return ellipsoid(p, (0.0, 0.06, 1.18), (0.44, 0.38, 0.42))

    arm_r = arm_parts([(-0.37, 0.04, 1.46), (-0.52, -0.2, 1.2), (-0.5, -0.48, 1.24)], [0.17, 0.17, 0.16],
                      (-0.54, -0.56, 1.28), (0.0, -0.2, 1.0), thumb=(1, -0.3, 0), hand_r=(0.09, 0.09, 0.1))
    arm_l = arm_parts([(0.37, 0.04, 1.46), (0.5, -0.24, 1.18), (0.26, -0.46, 1.06)], [0.17, 0.17, 0.16],
                      (0.16, -0.54, 1.04), (-1, -0.2, -0.3), thumb=(0, -0.3, 1), hand_r=(0.09, 0.08, 0.1))

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def robe(p):
        d = smax(torso(p), p[2] - 1.56, 0.06)
        d = smin(d, np.minimum(arm_r[0](p), arm_l[0](p)), 0.05)
        lap = smin(round_cone(m(p), (0.22, 0.0, 0.88), (0.3, -0.5, 1.05), 0.24, 0.2),
                   ellipsoid(p, (0, 0.06, 0.86), (0.48, 0.42, 0.22)), 0.1)
        d = smin(d, lap, 0.1)
        return smax(d, 0.6 - p[2], 0.03) - 0.004 * waves(p, 25.0, 82)

    def trim(p):
        cuffs = [torus(p, c, 0.15, 0.05, frame(dv)) for c, dv in (((-0.51, -0.43, 1.23), (0.0, -1, 0.2)),
                                                               ((0.3, -0.44, 1.07), (-1, -0.4, -0.3)))]
        collar = torus(p, (0, -0.02, 1.54), 0.28, 0.07, rot(-14, 0, 0))
        placket = smax(round_box(p, (0, -0.38, 1.25), (0.06, 0.06, 0.28), 0.05), -torso(p) - 0.02, 0.01)
        return union_all(cuffs + [collar, placket], 0.02)

    def brooch(p):
        return puffy_star(p, (0, -0.44, 1.46), rot(-15, 0, 0), 0.1, 0.5, 0.03, 0.015)

    def cape(p):
        x, y, z = p
        rho = np.sqrt((x / 1.0) ** 2 + ((y - 0.06) / 0.86) ** 2)
        shell = np.abs(rho - (0.5 + 0.16 * np.clip((1.56 - z) / 0.7, 0, 1))) - 0.045
        d = smax(shell, np.maximum(z - 1.58, 0.86 - z), 0.05)
        d = smax(d, np.maximum(0.28 - np.abs(x), -y - 0.15), 0.08)  # two side panels; the back bow shows between
        return d - 0.012 * np.abs(np.sin(np.arctan2(x, y) * 6)) ** 0.6

    def boots(p):
        d = None
        for c, yaw in (((-0.5, -0.72, 0.56), -20), ((-0.06, -0.84, 0.52), 0)):
            e = shoe(p, np.array(c), 0.56, 0.4, 0.36, yaw=yaw)
            cuff = torus(p, np.array(c) + np.array([0, 0.08, 0.33]), 0.17, 0.06)
            e = smin(e, cuff, 0.03)
            d = e if d is None else np.minimum(d, e)
        return d

    def shins(p):
        a = round_cone(p, (-0.2, -0.4, 0.98), (-0.48, -0.64, 0.86), 0.15, 0.14)
        b = round_cone(p, (0.18, -0.42, 0.98), (-0.06, -0.76, 0.84), 0.15, 0.14)
        return np.minimum(a, b)

    BB = np.array([0.0, 0.5, 1.02])

    def back_bow(p):
        d = bow(p, BB, rot(0, 0, 180), 0.32)
        for sx in (-1, 1):
            d = smin(d, Leaf(BB + (sx * 0.05, 0.04, -0.05), BB + (sx * 0.24, 0.12, -0.5), 0.09, 0.03, (0, 1, 0), mid=0.4,
                             r_base=0.06, r_tip=0.08)(p), 0.02)
        return d

    WR = np.array([-1.0, -0.5, 1.86])

    def wand_ring(p):
        ring = torus(p, WR, 0.3, 0.05, frame((0.25, -1, 0.1)))
        cone = round_cone(p, WR + np.array([0.02, 0.08, -0.12]), WR + np.array([0.0, 0.1, 0.28]), 0.09, 0.02)
        return np.minimum(ring, cone)

    def wand_stick(p):
        return round_cone(p, (-0.56, -0.58, 1.12), WR + np.array([0.08, 0.0, -0.3]), 0.04, 0.035)

    def wand_star(p):
        return puffy_star(p, WR + np.array([0.0, -0.03, 0.0]), rot(-5, 0, -14), 0.22, 0.5, 0.07, 0.03)

    cream_puffs = [(0.0, 0.0, 0.25, 0.48)]
    for i in range(12):
        a = math.radians(i * 30 + 5)
        cream_puffs.append((1.1 * math.sin(a), -0.78 * math.cos(a), 0.27 + 0.04 * math.cos(i * 1.3),
                            0.3 + 0.04 * math.sin(i * 2.2)))
    for i in range(6):
        a = math.radians(i * 60 + 20)
        cream_puffs.append((0.6 * math.sin(a), -0.45 * math.cos(a), 0.48, 0.3))

    def cloud(p):
        return smax(puffs(p, cream_puffs, 0.05), -p[2], 0.02) - 0.004 * waves(p, 30.0, 83)

    rng = np.random.default_rng(7)
    cloud_star_dirs = [(-55, 0.2), (-15, 0.3), (25, 0.15), (60, 0.25), (110, 0.2), (160, 0.3), (-160, 0.25),
                       (-110, 0.3), (85, 0.5), (-80, 0.55), (10, 0.55)]
    cloud_stars = []
    for a, dz in cloud_star_dirs:
        dv = np.array([math.sin(math.radians(a)), -math.cos(math.radians(a)), dz])
        c = surface_point(lambda q: puffs(q, cream_puffs, 0.05), (0, 0, 0.3), dv)
        cloud_stars.append((c, face_dir(dv, rng.uniform(0, 70)), rng.uniform(0.12, 0.19)))
    floating = [(np.array([-1.36, -0.28, 1.05]), rot(0, 20, -30), 0.15), (np.array([1.3, -0.25, 1.3]), rot(10, -15, 30), 0.17),
                (np.array([1.0, 0.35, 2.15]), rot(0, 10, 50), 0.12), (np.array([-0.95, 0.3, 2.4]), rot(0, 0, -40), 0.1)]

    def stars(p):
        return union_all([puffy_star(p, c, R, r, 0.5, r * 0.3, r * 0.12) for c, R, r in cloud_stars])

    def floating_stars(p):
        return union_all([puffy_star(p, c, R, r, 0.5, r * 0.3, r * 0.12) for c, R, r in floating])

    pearl_pts = [surface_point(lambda q: puffs(q, cream_puffs, 0.05), (0, 0, 0.3),
                               (math.sin(math.radians(a)), -math.cos(math.radians(a)), dz))
                 for a, dz in ((-35, 0.1), (5, 0.05), (45, 0.4), (135, 0.1), (-135, 0.2), (75, 0.1), (-95, 0.05),
                               (195, 0.3))]

    def pearls(p):
        return union_all([sphere(p, c, 0.055) for c in pearl_pts])

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Hat", hat, hat_m, voxel=0.007, tris=14000),
        Comp(f"{N}_HatStars", hat_stars, cream_m, voxel=0.004, tris=6000),
        Comp(f"{N}_HatCharm", tip_charm, star_m, voxel=0.004, tris=1500),
        Comp(f"{N}_Robe", robe, robe_m, voxel=0.007, tris=14000),
        Comp(f"{N}_Trim", trim, cream_m, voxel=0.005, tris=5000),
        Comp(f"{N}_Brooch", brooch, star_m, voxel=0.004, tris=1200),
        Comp(f"{N}_Cape", cape, cape_m, voxel=0.006, tris=10000),
        Comp(f"{N}_Legs", shins, robe_m, voxel=0.005, tris=3000),
        Comp(f"{N}_Boots", boots, boot_m, voxel=0.005, tris=6000),
        Comp(f"{N}_Hands", lambda p: np.minimum(arm_r[1](p), arm_l[1](p)), skin, voxel=0.005, tris=4000),
        Comp(f"{N}_BackBow", back_bow, bow_m, voxel=0.005, tris=6000),
        Comp(f"{N}_WandRing", wand_ring, wand_m, voxel=0.004, tris=4000),
        Comp(f"{N}_WandStick", wand_stick, stick_m, voxel=0.004, tris=1500),
        Comp(f"{N}_WandStar", wand_star, star_m, voxel=0.004, tris=2500),
        Comp(f"{N}_Cloud", cloud, cloud_m, voxel=0.008, tris=14000),
        Comp(f"{N}_CloudStars", stars, star_m, voxel=0.005, tris=12000),
        Comp(f"{N}_FloatingStars", floating_stars, star_m, voxel=0.005, tris=4000),
        Comp(f"{N}_Pearls", pearls, pearl_m, voxel=0.004, tris=2000),
    ]
    comps += star_face(N, head, fm, H, look=0.12)
    scale_comps(comps, S_)
    return assemble(N, "Radiant Star", "Rare", comps, {}, scaled_bounds((-1.7, -1.4, -0.2), (1.7, 1.4, 4.0), S_),
                    catalog="star.radiant")


# ---------------------------------------------------------------- Cloud Rest Star

def cloud_rest():
    N = "CloudRest"
    S_ = 0.9
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    fm["lash"] = (f"{N}_Lash", Mat("#4A3128", rough=0.5))
    cm = cat_mats(N)
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    pj_m = (f"{N}_Pajamas", Mat("#D2DDF5", rough=0.9))
    pj_star = (f"{N}_PajamaStars", Mat("#F4D77A", rough=0.6))
    feet_m = (f"{N}_Socks", Mat("#F3E6D2", rough=0.85))
    cloud_m = (f"{N}_Cloud", Mat("#A3BCE8", rough=0.55, coat=0.2))
    pillow_m = (f"{N}_StarPillow", Mat("#F6D46E", rough=0.7))
    arch_m = (f"{N}_Mobile", Mat("#F2BD58", rough=0.4, coat=0.3))
    white_m = (f"{N}_MobileCloud", Mat("#F8F5F0", rough=0.6))
    blue_m = (f"{N}_BlueStars", Mat("#7F9EE0", rough=0.5, coat=0.2))
    gold_m = (f"{N}_YellowStars", Mat("#F4C94F", rough=0.5, coat=0.2))
    catstar_m = (f"{N}_CatStar", Mat("#F3CF5A", rough=0.5))

    # Head group, modelled upright and tipped toward the character's right onto the cloud.
    H = 1.93
    pivot = np.array([0.0, 0.0, H - 0.7])
    tilt = rot(0, -10, 0)
    head = star_head(H)
    HC = np.array([0.0, 0.05, H + 0.08])
    HR = (0.88, 0.85, 0.78)
    hair_shell = Bob(HC, HR, hem=[(0, H + 0.16), (32, H + 0.14), (44, H - 0.0), (52, H - 0.55), (90, H - 0.6),
                                  (180, H - 0.7)],
                     bell=(H - 0.05, H - 0.65, 0.26), wave=(0.04, 12.0), locks=34, tip=0.09, groove=0.028, puff=0.018,
                     k=0.07, opening=(H - 0.3, 0.62, 0.48, -0.15))

    def hair(p):
        flow = ellipsoid(p, (0.62, 0.3, H - 0.45), (0.62, 0.42, 0.34), rot(0, 15, 0))
        flow = flow - 0.025 * np.abs(np.sin(p[1] * 22 + p[2] * 6)) ** 0.6
        return smin(hair_shell(p), flow, 0.18)

    head_group = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
    ]
    head_group += star_face(N, head, fm, H, closed=True, brows=(0.3, 0.06, 0.014, 0.0))
    pose_comps(head_group, pivot, tilt)

    blue = [(0.0, 0.05, 0.55, 0.7)]
    for i in range(12):
        a = math.radians(i * 30 + 12)
        blue.append((1.22 * math.sin(a), 0.05 - 0.72 * math.cos(a), 0.4 + 0.05 * math.cos(i * 1.4),
                     0.42 + 0.04 * math.sin(i * 2.1)))
    for x in (-0.95, -0.4, 0.2, 0.75, 1.2):
        blue.append((x, 0.38, 0.95 + 0.05 * math.sin(x * 4), 0.44))
    for x in (-0.6, 0.0, 0.6):
        blue.append((x, -0.42, 0.56, 0.38))

    def cloud(p):
        return smax(puffs(p, blue, 0.05), -p[2], 0.02) - 0.003 * waves(p, 30.0, 91)

    def torso(p):
        return ellipsoid(p, (0.62, 0.0, 1.2), (0.52, 0.4, 0.34), rot(0, -12, 0))

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def pajamas(p):
        d = torso(p)
        arm_a = tube(p, [(0.25, -0.15, 1.38), (0.0, -0.5, 1.18), (-0.25, -0.62, 1.12)], [0.15, 0.14, 0.13], k=0.03)
        arm_b = tube(p, [(0.55, -0.25, 1.32), (0.25, -0.62, 1.16), (0.0, -0.72, 1.0)], [0.15, 0.14, 0.13], k=0.03)
        thigh_a = round_cone(p, (0.95, -0.05, 1.1), (0.62, -0.55, 1.02), 0.2, 0.17)
        thigh_b = round_cone(p, (1.0, 0.05, 1.18), (0.78, -0.48, 1.18), 0.2, 0.17)
        shin_a = round_cone(p, (0.62, -0.55, 1.02), (0.3, -0.72, 0.9), 0.15, 0.13)
        shin_b = round_cone(p, (0.78, -0.48, 1.18), (0.58, -0.72, 0.96), 0.15, 0.13)
        d = union_all([d, arm_a, arm_b, thigh_a, thigh_b, shin_a, shin_b], 0.06)
        return d - 0.012 * np.abs(np.sin((p[0] + p[2]) * 16)) ** 0.5 * np.abs(np.sin((p[0] - p[2]) * 16)) ** 0.5

    pj_stars = star_prints(pajamas, (0.62, 0.0, 1.2), [sph_dir(a, e) for a, e in
                                                       ((-20, 10), (20, 30), (-60, 40), (60, -10), (0, -20), (100, 20))],
                           0.05)

    def hands(p):
        return np.minimum(mitten(p, (-0.3, -0.66, 1.12), (-1, -0.2, 0), (0.09, 0.08, 0.1)),
                          mitten(p, (-0.06, -0.78, 0.98), (-1, -0.3, 0), (0.09, 0.08, 0.1)))

    def feet(p):
        return np.minimum(ellipsoid(p, (0.22, -0.8, 0.86), (0.13, 0.16, 0.12), rot(0, 0, -20)),
                          ellipsoid(p, (0.5, -0.82, 0.92), (0.13, 0.16, 0.12), rot(0, 0, -10)))

    cat = Cat((-0.4, -0.84, 1.1), R=rot(0, 0, 8), s=1.3, closed=True)

    def cat_body(p):
        d = ellipsoid(p, (-0.32, -0.56, 0.92), (0.3, 0.27, 0.19))
        d = smin(d, cat.head(p), 0.06)
        for sx in (-1, 1):
            d = smin(d, ellipsoid(p, cat.at((sx * 0.1, -0.1, -0.15)), (0.07, 0.08, 0.05)), 0.03)
        return d

    def cat_star(p):
        return puffy_star(p, cat.at((0.0, -0.06, 0.15)), rot(-35, 0, 8), 0.06, 0.5, 0.018, 0.01)

    def pillow(p):
        return puffy_star(p, (-1.1, 0.12, 1.35), rot(-18, 0, 14), 0.56, 0.52, 0.17, 0.06)

    arch_path = [(1.25, 0.42, 0.8), (1.25, 0.42, 2.3), (1.18, 0.38, 3.0), (0.86, 0.3, 3.45), (0.38, 0.24, 3.62),
                 (0.0, 0.2, 3.52)]

    def mobile(p):
        d = tube(p, arch_path, [0.065] * 6, k=0.02, samples=8)
        end = np.array(arch_path[-1])
        for a in range(4):
            ang = math.radians(a * 90 + 20)
            d = smin(d, sphere(p, end + np.array([0.11 * math.cos(ang), 0.0, 0.11 * math.sin(ang)]), 0.075), 0.02)
        collar = torus(p, (1.25, 0.42, 2.3), 0.07, 0.035)
        hook = np.array([0.5, 0.24, 3.6])
        string = round_cone(p, hook, hook + np.array([0.0, 0.0, -0.34]), 0.022, 0.022)
        strings = [round_cone(p, hook + np.array([dx, 0.0, -0.6]), hook + np.array([dx, 0.0, -0.9]), 0.02, 0.02)
                   for dx in (-0.18, 0.2)]
        return union_all([d, collar, string] + strings, 0.01)

    MC = np.array([0.5, 0.24, 3.08])

    def mobile_cloud(p):
        return puffs(p, [(MC[0] + x, MC[1], MC[2] + z, r) for x, z, r in
                         ((0.0, 0.05, 0.16), (-0.17, -0.02, 0.12), (0.18, -0.02, 0.13), (0.08, 0.14, 0.12),
                          (-0.08, 0.12, 0.11))], 0.04)

    hang = [(MC + np.array([-0.18, 0.0, -0.5]), gold_m, 0.15), (MC + np.array([0.2, 0.0, -0.52]), blue_m, 0.17)]

    cluster = [(1.3 + x, 0.2 + y, 1.82 + z, 0.17) for x, y, z in
               ((0.0, 0.0, 0.0), (-0.15, -0.12, 0.2), (0.15, -0.1, 0.18), (0.0, -0.15, -0.18), (0.12, 0.1, 0.32),
                (-0.12, 0.1, -0.1))]

    def blue_balls(p):
        return union_all([sphere(p, (x, y, z), r) - 0.004 * waves(p, 50.0, 92) for x, y, z, r in cluster], 0.03)

    ball_stars = star_prints(blue_balls, (1.3, 0.2, 1.82), [(0, -1, 0.3), (-0.6, -1, 0.6), (0.6, -1, 0.4), (0.3, -1, -0.6)],
                             0.06, out=0.012)

    def gold_stars(p):
        return union_all([puffy_star(p, hang[0][0], rot(0, 0, 0), 0.15, 0.5, 0.045, 0.02),
                          puffy_star(p, (1.05, 0.55, 1.28), rot(-20, 0, 160), 0.16, 0.5, 0.05, 0.02)])

    def blue_star(p):
        return puffy_star(p, hang[1][0], rot(0, 0, 10), 0.17, 0.5, 0.05, 0.02)

    comps = head_group + [
        Comp(f"{N}_Pajamas", pajamas, pj_m, voxel=0.007, tris=14000),
        Comp(f"{N}_PajamaStars", pj_stars, pj_star, voxel=0.0035, tris=2000),
        Comp(f"{N}_Hands", hands, skin, voxel=0.005, tris=3000),
        Comp(f"{N}_Socks", feet, feet_m, voxel=0.005, tris=2500),
        Comp(f"{N}_Cloud", cloud, cloud_m, voxel=0.008, tris=19000),
        Comp(f"{N}_Cat", cat_body, cm["fur"], voxel=0.005, tris=8000),
        Comp(f"{N}_CatStar", cat_star, catstar_m, voxel=0.003, tris=500),
        Comp(f"{N}_StarPillow", pillow, pillow_m, voxel=0.006, tris=8000),
        Comp(f"{N}_Mobile", mobile, arch_m, voxel=0.005, tris=8000),
        Comp(f"{N}_MobileCloud", mobile_cloud, white_m, voxel=0.005, tris=3000),
        Comp(f"{N}_YellowStars", gold_stars, gold_m, voxel=0.004, tris=3000),
        Comp(f"{N}_BlueStar", blue_star, blue_m, voxel=0.004, tris=2000),
        Comp(f"{N}_BlueFlowers", blue_balls, blue_m, voxel=0.005, tris=6000),
        Comp(f"{N}_FlowerStars", ball_stars, gold_m, voxel=0.0035, tris=1500),
    ]
    comps += cat.face(N, cat_body, cm)
    scale_comps(comps, S_)
    return assemble(N, "Cloud Rest Star", "Legendary", comps, {}, scaled_bounds((-1.8, -1.4, -0.2), (1.9, 1.4, 4.0), S_),
                    catalog="star.cloud-rest")


# ---------------------------------------------------------------- Meteor Shower

def meteor_shower():
    N = "MeteorShower"
    S_ = 0.63  # the star hood and antenna make her 5.6 studs at the series head size
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    hood_m = (f"{N}_Hood", Mat("#F7CD62", rough=0.85))
    line_m = (f"{N}_HoodTrim", Mat("#F2A452", rough=0.8))
    petal_m = (f"{N}_Skirt", Mat(["#FBD678", "#F7B85A", "#F19A45"], rough=0.75))
    print_m = (f"{N}_SkirtPrints", Mat("#FBF5EA", rough=0.6))
    top_m = (f"{N}_Top", Mat("#F8EEDA", rough=0.85))
    boot_m = (f"{N}_Boots", Mat("#F8F3EC", rough=0.45, coat=0.15))
    cuff_m = (f"{N}_BootCuffs", Mat("#F39C4E", rough=0.6))
    peach_m = (f"{N}_AntennaStar", Mat("#F3A08C", rough=0.5, coat=0.2))
    spring_m = (f"{N}_Spring", Mat("#E2B85C", rough=0.35, metal=0.5))
    cloud_m = (f"{N}_Cloud", Mat("#F7F0E4", rough=0.75))
    star_m = (f"{N}_Stars", Mat(["#FFF1B8", "#FAD86E", "#F5C24E"], rough=0.45, coat=0.3))
    trail_m = (f"{N}_Trails", Mat("#FFF3C9", rough=0.2, alpha=0.5, coat=0.5))

    H = 3.74
    head = star_head(H)
    HC = np.array([0.0, 0.05, H + 0.08])
    HR = (0.88, 0.85, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.14), (32, H + 0.12), (44, H - 0.04), (52, H - 0.5), (90, H - 0.55),
                            (180, H - 0.6)],
               bell=(H - 0.05, H - 0.55, 0.14), locks=36, tip=0.06, groove=0.024, puff=0.014, k=0.06,
               opening=(H - 0.3, 0.62, 0.47, -0.15))
    buns = [(np.array([-0.98, 0.32, H - 0.68]), 0.3), (np.array([1.0, 0.36, H - 0.56]), 0.3)]

    def bun_fn(p):
        d = None
        for c, r in buns:
            e = sphere(p, c, r) - 0.014 * np.abs(np.sin(np.arctan2(p[2] - c[2], p[1] - c[1]) * 7)) ** 0.5
            d = e if d is None else np.minimum(d, e)
        return d

    def hair_all(p):
        return smin(hair(p), bun_fn(p), 0.06)

    # Star-frame hood: a thick five-point star round the face, over a dome covering the head.
    SF = np.array([0.0, -0.52, H - 0.12])
    RSF = rot(0, 7, 0)

    def frame_shape(p):
        x, y, z = local(p, SF, RSF)
        d2 = star2(x, z, 1.5, 0.56)
        slab = slab2(d2, y + 0.06, 0.2, 0.09)
        hole = ellipse2(x, z + 0.06, 0.66, 0.6)
        return smax(slab, -np.maximum(hole, np.abs(y) - 0.6), 0.06)

    def hood(p):
        dome = ellipsoid(p, HC + np.array([0, 0.08, 0.02]), (1.0, 0.95, 0.9))
        dome = smax(dome, -(p[1] - SF[1] - 0.05), 0.08)
        return smin(frame_shape(p), dome, 0.12) - 0.004 * waves(p, 25.0, 101)

    def hood_trim(p):
        x, y, z = local(p, SF, RSF)
        line = np.abs(star2(x, z, 1.33, 0.58)) - 0.035
        line = np.maximum(line, 0.12 - ellipse2(x, z + 0.06, 0.66, 0.6))  # keep the outline clear of the face
        darts = None
        for i in range(5):
            a = math.radians(i * 72)
            c = (math.sin(a) * 1.0, math.cos(a) * 1.0)
            e = star2(x - c[0] * 1.05, z - c[1] * 1.05, 0.08, 0.45)
            darts = e if darts is None else np.minimum(darts, e)
        reg = np.maximum(np.minimum(line, darts), y + 0.05)
        return overlay(frame_shape(p), reg, 0.012, depth=0.04, k=0.004)

    top_pt = SF + RSF @ np.array([0.1, 0.45, 1.12])
    coil_path = [top_pt + np.array([0.0, 0.0, 0.0]), top_pt + np.array([0.03, -0.02, 0.18]),
                 top_pt + np.array([0.05, -0.03, 0.34])]

    def spring(p):
        return coil(p, coil_path, ring=0.07, wire=0.022, pitch=0.07)

    def antenna_star(p):
        return puffy_star(p, coil_path[-1] + np.array([0.02, 0.0, 0.17]), rot(0, -10, 0), 0.21, 0.5, 0.07, 0.03)

    def torso(p):
        return ellipsoid(p, (0.0, 0.08, 2.8), (0.46, 0.38, 0.44))

    arm_l = arm_parts([(0.38, 0.1, 3.0), (0.85, 0.12, 3.15), (1.3, 0.12, 3.36)], [0.15, 0.14, 0.13],
                      (1.46, 0.1, 3.44), (1, 0, 0.4), thumb=(0, -1, 0.3), hand_r=(0.09, 0.1, 0.12))
    arm_r = arm_parts([(-0.38, 0.1, 2.96), (-0.85, 0.12, 2.98), (-1.28, 0.1, 3.04)], [0.15, 0.14, 0.13],
                      (-1.44, 0.08, 3.06), (-1, 0, 0.2), thumb=(0, -1, 0.3), hand_r=(0.09, 0.1, 0.12))

    def top(p):
        d = smax(torso(p), p[2] - 3.2, 0.06)
        return smin(d, np.minimum(arm_l[0](p), arm_r[0](p)), 0.06)

    WAIST = np.array([0.0, 0.06, 2.56])
    rng = np.random.default_rng(11)
    petals = []
    for layer, (n, r0, r1, z1, ph) in enumerate(((11, 0.36, 1.08, 1.5, 0.0), (11, 0.32, 0.92, 1.66, 16.0))):
        for i in range(n):
            a = math.radians(ph + i * 360.0 / n + rng.uniform(-5, 5))
            dv = np.array([math.sin(a), -math.cos(a), 0.0])
            base = WAIST + dv * r0 + np.array([0, 0, -0.02 * layer])
            tip = WAIST + dv * (r1 * rng.uniform(0.92, 1.08)) + np.array([0, 0, z1 - WAIST[2] + rng.uniform(-0.08, 0.08)])
            petals.append(Leaf(base, tip, 0.2, 0.04, dv + np.array([0, 0, 0.3]), mid=0.45, r_base=0.12, r_tip=0.03,
                               bend=-0.05, crease=0.015))

    def skirt(p):
        return union_all([lf(p) for lf in petals], 0.03)

    def skirt_t(x, y, z):
        return np.clip((WAIST[2] - z) / 1.0, 0, 1)

    def skirt_prints(p):
        regs = []
        for i, lf in enumerate(petals[:11]):
            a, s_, n = lf.coords(p)
            regs.append(np.maximum(star2(s_, a - lf.L * 0.55, 0.06, 0.5), -n))
            if i % 2 == 0:
                regs.append(np.maximum(seg2(s_, a, (0.0, lf.L * 0.15), (0.0, lf.L * 0.42), 0.012), -n))
        return overlay(skirt(p), union_all(regs), 0.006, depth=0.03, k=0.003)

    def legs(p):
        stand = round_cone(p, (0.16, 0.0, 1.9), (0.2, -0.05, 1.0), 0.13, 0.11)
        kick_t = round_cone(p, (-0.0, 0.05, 1.9), (0.5, 0.42, 1.48), 0.13, 0.12)
        kick_s = round_cone(p, (0.5, 0.42, 1.48), (0.96, 0.66, 1.66), 0.12, 0.1)
        return union_all([stand, kick_t, kick_s], 0.04)

    boots_at = [(np.array([0.2, -0.02, 0.62]), np.eye(3)), (np.array([1.08, 0.74, 1.52]), rot(-70, 0, -40))]

    def boots(p):
        d = None
        for c, R in boots_at:
            calf = round_cone(p, c + R @ np.array([0, 0.05, 0.05]), c + R @ np.array([0, 0.03, 0.42]), 0.15, 0.15)
            e = smin(shoe(p, c, 0.5, 0.36, 0.3, R=R @ rot(0, 0, 0)), calf, 0.06)
            d = e if d is None else np.minimum(d, e)
        return d

    def boot_cuffs(p):
        return union_all([torus(p, c + R @ np.array([0, 0.03, 0.42]), 0.15, 0.05, R) for c, R in boots_at])

    cream = [(-0.1, 0.0, 0.3, 0.5)]
    for i in range(11):
        a = math.radians(i * 360 / 11 + 8)
        cream.append((-0.1 + 1.2 * math.sin(a), -0.85 * math.cos(a), 0.3 + 0.04 * math.cos(i * 1.7),
                      0.33 + 0.04 * math.sin(i * 2.3)))
    for i in range(5):
        a = math.radians(i * 72 + 20)
        cream.append((-0.1 + 0.6 * math.sin(a), -0.45 * math.cos(a), 0.5, 0.32))

    def cloud(p):
        return smax(puffs(p, cream, 0.05), -p[2], 0.02) - 0.004 * waves(p, 30.0, 102)

    cloud_star_dirs = [(-50, 0.3), (-10, 0.2), (40, 0.3), (75, 0.5), (130, 0.3), (-120, 0.4), (180, 0.4), (10, 0.7)]
    cs = []
    for a, dz in cloud_star_dirs:
        dv = np.array([math.sin(math.radians(a)), -math.cos(math.radians(a)), dz])
        c = surface_point(lambda q: puffs(q, cream, 0.05), (-0.1, 0, 0.35), dv)
        cs.append((c, face_dir(dv, a), 0.2 + 0.05 * math.sin(a)))
    flying = [((-1.75, -0.2, 2.1), (0.7, 0.1, 0.7), 0.26), ((-1.25, -0.45, 1.1), (0.8, 0.0, 0.6), 0.32),
              ((1.85, 0.0, 3.9), (-0.5, 0.2, 0.8), 0.22), ((1.85, -0.15, 2.65), (-0.3, 0.1, 0.9), 0.2),
              ((1.7, 0.25, 1.45), (0.6, 0.2, 0.75), 0.22), ((-1.55, 0.3, 3.2), (0.3, 0.3, 0.9), 0.17)]

    def stars(p):
        d = union_all([puffy_star(p, c, R, r, 0.5, r * 0.3, r * 0.12) for c, R, r in cs])
        for c, tv, r in flying:
            d = np.minimum(d, puffy_star(p, np.array(c), face_dir((0.2, -1.0, 0.1), 20), r, 0.5, r * 0.3, r * 0.12))
        return d

    def trails(p):
        d = None
        for c, tv, r in flying[:5]:
            c = np.array(c)
            tv = unit(tv)
            e = round_cone(p, c - tv * 0.05, c - tv * 0.75 + np.array([0, 0.05, 0]), r * 0.45, 0.03)
            d = e if d is None else np.minimum(d, e)
        return d

    def star_ramp_all(x, y, z):
        t = None
        for c, R, r in cs + [(np.array(c), None, r) for c, _, r in flying]:
            e = np.sqrt((x - c[0]) ** 2 + (y - c[1]) ** 2 + (z - c[2]) ** 2) / r
            t = e if t is None else np.minimum(t, e)
        return np.clip(t, 0, 1)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair_all, hair_m, voxel=0.007, tris=16000),
        Comp(f"{N}_Hood", hood, hood_m, voxel=0.008, tris=16000),
        Comp(f"{N}_HoodTrim", hood_trim, line_m, voxel=0.005, tris=8000),
        Comp(f"{N}_Spring", spring, spring_m, voxel=0.005, tris=6000),
        Comp(f"{N}_AntennaStar", antenna_star, peach_m, voxel=0.005, tris=2000),
        Comp(f"{N}_Top", top, top_m, voxel=0.007, tris=8000),
        Comp(f"{N}_Hands", lambda p: np.minimum(arm_l[1](p), arm_r[1](p)), skin, voxel=0.006, tris=3000),
        Comp(f"{N}_Skirt", skirt, petal_m, voxel=0.007, tris=19000, ramp=skirt_t),
        Comp(f"{N}_SkirtPrints", skirt_prints, print_m, voxel=0.005, tris=6000),
        Comp(f"{N}_Legs", legs, skin, voxel=0.006, tris=4000),
        Comp(f"{N}_Boots", boots, boot_m, voxel=0.006, tris=6000),
        Comp(f"{N}_BootCuffs", boot_cuffs, cuff_m, voxel=0.005, tris=3000),
        Comp(f"{N}_Cloud", cloud, cloud_m, voxel=0.009, tris=14000),
        Comp(f"{N}_Stars", stars, star_m, voxel=0.006, tris=14000, ramp=star_ramp_all),
        Comp(f"{N}_Trails", trails, trail_m, voxel=0.006, tris=5000),
    ]
    comps += star_face(N, head, fm, H, look=0.1)
    scale_comps(comps, S_)
    return assemble(N, "Meteor Shower", "Legendary", comps, {}, scaled_bounds((-2.2, -1.5, -0.2), (2.3, 1.5, 6.0), S_),
                    catalog="star.meteor-shower")


# ---------------------------------------------------------------- Dreamcatcher Star

def dreamcatcher():
    N = "Dreamcatcher"
    S_ = 0.72  # hoop, loop and hanging charms make her 4.9 studs at the series head size
    fm = face_mats(N, iris=("#120C09", "#1B120D", "#3A2619", "#4E3423", "#1E140E"), brow="#A97A5E")
    skin = (f"{N}_Skin", Mat(SKIN, rough=0.55, subsurface=0.08))
    hair_m = (f"{N}_Hair", Mat(HAIR, rough=0.6, coat=0.08))
    sweater_m = (f"{N}_Sweater", Mat("#F3AABF", rough=0.9))
    jeans_m = (f"{N}_Jeans", Mat("#7F9DCD", rough=0.8))
    shoe_m = (f"{N}_Shoes", Mat("#F3E7DA", rough=0.5, coat=0.15))
    wood_m = (f"{N}_Hoop", Mat("#E1B27B", rough=0.55, coat=0.15))
    rope_m = (f"{N}_Rope", Mat("#F2E8D4", rough=0.85))
    gold_m = (f"{N}_RopeGold", Mat("#E2BE66", rough=0.6))
    star_m = (f"{N}_Stars", Mat(["#FFF0B4", "#FAD66C", "#F4C04C"], rough=0.45, coat=0.3))
    feather_m = (f"{N}_Feathers", Mat("#FAF8F4", rough=0.6))
    plush_m = (f"{N}_CloudPlush", Mat("#F8F6F2", rough=0.7))
    face_m = (f"{N}_PlushFace", Mat("#3A2E29", rough=0.4))
    blush_m = (f"{N}_PlushBlush", Mat("#F5B8B6", rough=0.6))
    stand_m = (f"{N}_Stand", Mat("#C99863", rough=0.55, coat=0.15))

    C = np.array([0.0, 0.15, 2.58])  # hoop centre; the hoop lies in the XZ plane
    R, RT = 1.35, 0.09

    def hoop_pt(deg, r=R):
        a = math.radians(deg)  # 0 = top, clockwise toward +X
        return C + np.array([math.sin(a) * r, 0.0, math.cos(a) * r])

    def hoop(p):
        x, y, z = p[0] - C[0], p[1] - C[1], p[2] - C[2]
        rho = np.sqrt(x * x + z * z)
        d = np.sqrt((rho - R) ** 2 + y * y) - RT
        return d - 0.003 * np.sin(np.arctan2(x, z) * 40)

    def grips(p):  # the carved hand-shaped grips over the top of the hoop on the sheet
        d = None
        for deg in (-48, 48):
            c = hoop_pt(deg, R + 0.02)
            t = unit(np.cross(np.array([0, 1.0, 0]), c - C))
            palm = ellipsoid(p, c + (c - C) / R * 0.06 + np.array([0, -0.05, 0]), (0.15, 0.13, 0.13), frame(t))
            for k in (-1.5, -0.5, 0.5, 1.5):
                f0 = c + t * k * 0.055 + (c - C) / R * 0.08
                f1 = c + t * k * 0.06 - (c - C) / R * 0.06 + np.array([0, -0.11, 0])
                palm = smin(palm, round_cone(p, f0, f1, 0.035, 0.03), 0.02)
            d = palm if d is None else np.minimum(d, palm)
        return d

    wraps = (-78, 78, -140, 140, 0)

    def rope_turns(p, parity):
        d = None
        for deg in wraps:
            n = 7 if deg else 5
            for i in range(n):
                if i % 2 != parity:
                    continue
                dd = deg + (i - (n - 1) / 2) * 2.6
                c = hoop_pt(dd)
                t = unit(np.cross(np.array([0, 1.0, 0]), c - C))
                e = torus(p, c, RT + 0.035, 0.032, frame(t))
                d = e if d is None else np.minimum(d, e)
        return d

    LC = C + np.array([0.0, 0.0, R + 0.5])

    def loop(p):
        x, z = p[0] - LC[0], p[2] - LC[2]
        d2 = np.abs(ellipse2(x, z, 0.3, 0.4))
        d = np.sqrt(d2 ** 2 + (p[1] - C[1]) ** 2) - 0.05
        d = smax(d, -(p[2] - (C[2] + R + 0.08)), 0.02)
        knot = ellipsoid(p, C + np.array([0, 0, R + 0.12]), (0.13, 0.12, 0.1))
        return smin(d, knot, 0.03)

    def loop_gold(p):
        reg = bands(p[0] * 0.7 + p[2] * 0.7, 0.1, 0.4)
        return overlay(loop(p), reg, 0.006, depth=0.03, k=0.004)

    def webs(p):
        hub = C + np.array([0.0, 0.05, -0.2])
        d = None
        for deg in (-78, 78, -140, 140):
            a = hoop_pt(deg, R - 0.06)
            e = round_cone(p, a, hub + (a - hub) * 0.45, 0.025, 0.025)
            d = e if d is None else np.minimum(d, e)
        return d

    charms = [(-140, 1.08, 0.42), (180, 0.86, 0.18), (140, 1.08, 0.42)]  # (hoop angle, star z, feather tip z)

    def charm_parts(i):
        deg, sz, bottom = charms[i]
        top = hoop_pt(deg, R + RT * 0.5)
        top = np.array([top[0], C[1], top[2]])
        return top, sz, bottom

    def strings(p):
        d = None
        for i in range(3):
            top, sz, bottom = charm_parts(i)
            e = round_cone(p, top, np.array([top[0], top[1], sz + 0.24]), 0.028, 0.028)
            e = np.minimum(e, round_cone(p, np.array([top[0], top[1], sz - 0.16]), np.array([top[0], top[1], sz - 0.28]),
                                         0.025, 0.025))
            d = e if d is None else np.minimum(d, e)
        return d

    def beads(p):
        d = None
        for i in range(3):
            top, sz, bottom = charm_parts(i)
            for z in (sz + 0.25, sz - 0.25):
                e = sphere(p, (top[0], top[1], z), 0.07)
                d = e if d is None else np.minimum(d, e)
        return d

    def charm_stars(p):
        return union_all([puffy_star(p, (charm_parts(i)[0][0], C[1], charm_parts(i)[1]), np.eye(3), 0.2, 0.5, 0.06,
                                     0.025) for i in range(3)])

    def feathers(p):
        d = None
        for i in range(3):
            top, sz, bottom = charm_parts(i)
            a = np.array([top[0], C[1], sz - 0.3])
            b = np.array([top[0] + 0.03, C[1] - 0.02, bottom])
            lf = Leaf(a, b, 0.13, 0.04, (0, -1, 0), mid=0.45, r_base=0.05, r_tip=0.04, crease=0.015,
                      serrate=(0.012, 0.06))
            e = lf(p)
            d = e if d is None else np.minimum(d, e)
        return d

    # The girl, seated on the bottom of the hoop.
    H = 2.72
    head = star_head(H, y=-0.12)
    HC = np.array([0.0, -0.06, H + 0.08])
    HR = (0.88, 0.85, 0.78)
    hair = Bob(HC, HR, hem=[(0, H + 0.15), (32, H + 0.13), (44, H - 0.02), (52, H - 0.55), (90, H - 0.62),
                            (180, H - 0.7)],
               bell=(H - 0.05, H - 0.62, 0.16), roll=0.12, locks=40, tip=0.05, groove=0.024, puff=0.014, k=0.06,
               opening=(H - 0.3, 0.62, 0.47, -0.26))

    def torso(p):
        return ellipsoid(p, (0.0, -0.04, 1.74), (0.43, 0.35, 0.38))

    sl = []
    for sx in (-1, 1):
        sl.append(arm_parts([(sx * 0.36, -0.04, 1.98), (sx * 0.48, -0.26, 1.7), (sx * 0.3, -0.56, 1.66)],
                            [0.15, 0.15, 0.14], (sx * 0.22, -0.66, 1.7), (-sx, -0.3, 0.1), thumb=(0, -0.2, 1),
                            hand_r=(0.09, 0.08, 0.1)))

    def sweater(p):
        d = smax(torso(p), p[2] - 2.06, 0.06)
        d = smin(d, np.minimum(sl[0][0](p), sl[1][0](p)), 0.05)
        return d - 0.008 * np.abs(np.sin(p[2] * 36.0)) ** 0.5 * np.clip((1.62 - p[2]) / 0.2, 0, 1)

    def m(p):
        return (np.abs(p[0]), p[1], p[2])

    def jeans(p):
        seat = ellipsoid(p, (0, -0.04, 1.48), (0.4, 0.32, 0.16))
        thigh = round_cone(m(p), (0.2, -0.06, 1.5), (0.22, -0.5, 1.54), 0.18, 0.16)
        shin = round_cone(m(p), (0.22, -0.52, 1.52), (0.23, -0.6, 1.3), 0.14, 0.13)
        return union_all([seat, thigh, shin], 0.06)

    heel = np.array([0.23, -0.52, 1.12])

    def shoes(p):
        return shoe(m(p), heel, 0.38, 0.28, 0.22, yaw=-6)

    PC = np.array([0.0, -0.64, 1.78])
    plush_balls = [(PC[0] + x, PC[1] + y, PC[2] + z, r) for x, y, z, r in
                   ((0.0, 0.0, 0.04, 0.24), (-0.22, 0.04, -0.02, 0.18), (0.22, 0.04, -0.02, 0.18), (-0.1, 0.02, 0.2, 0.17),
                    (0.12, 0.02, 0.2, 0.17))]

    def plush(p):
        return puffs(p, plush_balls, 0.05)

    def plush_face(p):
        u, v = p[0] - PC[0], p[2] - PC[2]
        reg = np.minimum(np.minimum(ellipse2(u - 0.09, v - 0.08, 0.025, 0.03), ellipse2(u + 0.09, v - 0.08, 0.025, 0.03)),
                         np.minimum(arc2(u - 0.02, v - 0.03, 0.02, 70, 0.007), arc2(u + 0.02, v - 0.03, 0.02, 70, 0.007)))
        return overlay(plush(p), np.maximum(reg, p[1] - PC[1] + 0.1), 0.008, depth=0.03, k=0.002)

    def plush_blush(p):
        u, v = p[0] - PC[0], p[2] - PC[2]
        reg = np.minimum(ellipse2(u - 0.17, v - 0.03, 0.04, 0.026), ellipse2(u + 0.17, v - 0.03, 0.04, 0.026))
        return overlay(plush(p), np.maximum(reg, p[1] - PC[1] + 0.1), 0.005, depth=0.03, k=0.005)

    def held_star(p):
        return puffy_star(p, PC + np.array([0.06, -0.24, -0.02]), rot(-10, 0, 12), 0.17, 0.5, 0.05, 0.02)

    def stand(p):
        base = smax(np.sqrt((p[0] / 0.95) ** 2 + ((p[1] - 0.45) / 0.85) ** 2) * 0.9 - 0.9, np.abs(p[2] - 0.08) - 0.08,
                    0.04)
        post = round_cone(p, (0.0, 1.05, 0.1), (0.0, 1.05, 4.86), 0.075, 0.065)
        arm = tube(p, [(0.0, 1.05, 4.86), (0.0, 0.9, 5.0), (0.0, 0.5, 5.02), (0.0, C[1], 4.98), (0.0, C[1] - 0.04, 4.86)],
                   [0.06] * 5, k=0.02, samples=8)
        tip = sphere(p, (0.0, C[1] - 0.04, 4.84), 0.07)
        return union_all([base, post, arm, tip], 0.04)

    comps = [
        Comp(f"{N}_Head", head, skin, voxel=0.008, tris=12000),
        Comp(f"{N}_Hair", hair, hair_m, voxel=0.007, tris=19500),
        Comp(f"{N}_Sweater", sweater, sweater_m, voxel=0.007, tris=11000),
        Comp(f"{N}_Hands", lambda p: np.minimum(sl[0][1](p), sl[1][1](p)), skin, voxel=0.005, tris=3000),
        Comp(f"{N}_Jeans", jeans, jeans_m, voxel=0.006, tris=8000),
        Comp(f"{N}_Shoes", shoes, shoe_m, voxel=0.005, tris=4000),
        Comp(f"{N}_CloudPlush", plush, plush_m, voxel=0.005, tris=5000),
        Comp(f"{N}_PlushFace", plush_face, face_m, voxel=0.003, tris=800),
        Comp(f"{N}_PlushBlush", plush_blush, blush_m, voxel=0.0035, tris=500),
        Comp(f"{N}_HeldStar", held_star, star_m, voxel=0.004, tris=2000),
        Comp(f"{N}_Hoop", hoop, wood_m, voxel=0.006, tris=10000),
        Comp(f"{N}_Grips", grips, wood_m, voxel=0.005, tris=4000),
        Comp(f"{N}_RopeCream", lambda p: rope_turns(p, 0), rope_m, voxel=0.004, tris=10000),
        Comp(f"{N}_RopeGold", lambda p: rope_turns(p, 1), gold_m, voxel=0.004, tris=8000),
        Comp(f"{N}_Loop", loop, rope_m, voxel=0.005, tris=5000),
        Comp(f"{N}_LoopTwist", loop_gold, gold_m, voxel=0.004, tris=4000),
        Comp(f"{N}_Web", webs, rope_m, voxel=0.004, tris=3000),
        Comp(f"{N}_Strings", strings, rope_m, voxel=0.004, tris=3000),
        Comp(f"{N}_Beads", beads, rope_m, voxel=0.004, tris=2000),
        Comp(f"{N}_CharmStars", charm_stars, star_m, voxel=0.005, tris=6000),
        Comp(f"{N}_Feathers", feathers, feather_m, voxel=0.004, tris=6000),
        Comp(f"{N}_Stand", stand, stand_m, voxel=0.006, tris=6000),
    ]
    comps += star_face(N, head, fm, H, look=0.12, ylim=-0.37)
    scale_comps(comps, S_)
    return assemble(N, "Dreamcatcher Star", "Mythical", comps, {}, scaled_bounds((-1.7, -1.4, -0.2), (1.7, 1.5, 5.4), S_),
                    catalog="star.dreamcatcher")


FIGURES = {  # catalog order
    "reminiscence": reminiscence,
    "mirrorlight": mirrorlight,
    "wishing": wishing,
    "page-turner": page_turner,
    "nightlight": nightlight,
    "lamplight": lamplight,
    "garden": garden,
    "sanctuary": sanctuary,
    "echo": echo,
    "radiant": radiant,
    "cloud-rest": cloud_rest,
    "meteor-shower": meteor_shower,
    "dreamcatcher": dreamcatcher,
}
