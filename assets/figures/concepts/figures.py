"""Concepts figure definitions, reconstructed from the approved character sheets.

Units are studs. +Z is up, every figure faces -Y, the character's left is +X,
and the lowest point of each figure rests on Z = 0 after grounding.
Helpers follow the Pocket Grove definitions (see the figure collection runbook). The four spheres
share one body and face construction; face shapes are measured from each sheet's FRONT view and
projected along Y, so their XZ coordinates are relative to the sphere centre.
"""

import math

import numpy as np

from sdf import ellipse2, ellipsoid, local, rot, round_cone, smax, smin, sphere, tube


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


def seg2(u, v, a, b, th):
    """2D capsule from a to b with half-thickness th."""
    bx, by = b[0] - a[0], b[1] - a[1]
    px, py = u - a[0], v - a[1]
    h = np.clip((px * bx + py * by) / (bx * bx + by * by), 0.0, 1.0)
    return np.sqrt((px - bx * h) ** 2 + (py - by * h) ** 2) - th


def flat_base(d, p):
    """Flat sole at Z = 0 so the figure stands squarely on its surface."""
    return smax(d, -p[2], 0.015)


def skin(base, region, out, depth=0.05, k=0.004):
    """Thin skin that sits `out` (scalar or array) above a base surface, clipped to a region."""
    shell = np.maximum(base - out, -(base + depth))
    return smax(shell, region, k)


def circle_through(w, ze, zb):
    """Circle through (+-w, ze) whose lowest point is (0, zb): returns (centre z, radius)."""
    h = ze - zb
    r = (w * w + h * h) / (2.0 * h)
    return zb + r, r


def smile2(u, v, w, ze, zb, th0, th1, tick=0.0):
    """Upturned smile through (+-w, ze) and (0, zb), th0 thick in the middle tapering to th1,
    with optional short ticks crossing each end (the sheets' little dimple marks)."""
    c, r = circle_through(w, ze, zb)
    A = math.asin(min(w / r, 1.0))
    ang = np.arctan2(u, c - v)
    rho = np.sqrt(u * u + (v - c) ** 2)
    t = np.clip(np.abs(ang) / A, 0.0, 1.0)
    ring = np.abs(rho - r) - (th0 + (th1 - th0) * t**1.4)
    end = np.sqrt((np.abs(u) - w) ** 2 + (v - ze) ** 2) - th1
    d = np.where(np.abs(ang) <= A, ring, end)
    if tick:
        dx, dz = w / r, (ze - c) / r  # radial direction at the right-hand end
        a = (w - dx * tick, ze - dz * tick)
        b = (w + dx * tick, ze + dz * tick)
        d = np.minimum(d, seg2(np.abs(u), v, a, b, th1 * 0.95))
    return d


# ---------------------------------------------------------------- sphere family

R_SPHERE = 1.1  # 2.2-stud sphere, sitting on a small flat contact patch
SINK = 0.05
CZ = R_SPHERE - SINK
FACE_Y = -0.2  # decals only land on the front hemisphere
# Faces are measured from the eye-level FRONT view; the hero and in-game views look down on the
# figure, so the whole face sits slightly higher to keep the eyes on the visual centre.
FACE_LIFT = 0.06


def sphere_body(p):
    return flat_base(sphere(p, (0.0, 0.0, CZ), R_SPHERE), p)


def front(p):
    """Front-view decal coordinates relative to the sphere centre, plus the front clip."""
    return p[0], p[2] - CZ - FACE_LIFT, p[1] - FACE_Y


def sphere_gloss(hexstr):
    return Mat(hexstr, rough=0.2, coat=0.7)


def oval_eyes(N, dx, ez, ru, rv, mat, dome=0.03, shine=None):
    """Glossy domed oval eyes; `shine` = (mat, du, dv, su, sv) adds an upper highlight."""

    def eye_field(p):
        u, v, clip = front(p)
        regs, raise_ = [], np.zeros_like(u)
        for sx in (-1.0, 1.0):
            eu, ev = u - sx * dx, v - ez
            regs.append(ellipse2(eu, ev, ru, rv))
            q = (eu / ru) ** 2 + (ev / rv) ** 2
            raise_ = np.maximum(raise_, dome * np.clip(1.0 - q, 0.0, 1.0))
        return np.maximum(np.minimum(*regs), clip), 0.014 + raise_

    def eyes(p):
        region, out = eye_field(p)
        return skin(sphere_body(p), region, out)

    comps = [Comp(f"{N}_Eyes", eyes, mat, voxel=0.005, tris=2400)]
    if shine:
        smat, du, dv, su, sv = shine

        def highlight(p):
            u, v, clip = front(p)
            _, out = eye_field(p)
            regs = [ellipse2(u - (sx * dx + du * ru), v - (ez + dv * rv), su * ru, sv * rv) for sx in (-1.0, 1.0)]
            region = np.maximum(np.minimum(*regs), clip)
            return skin(sphere_body(p) - out, region, 0.007, depth=0.02, k=0.002)

        comps.append(Comp(f"{N}_EyeShine", highlight, smat, voxel=0.004, tris=700))
    return comps


def smile_mouth(N, mat, w, ze, zb, th0, th1, tick):
    def mouth(p):
        u, v, clip = front(p)
        region = np.maximum(smile2(u, v, w, ze, zb, th0, th1, tick), clip)
        return skin(sphere_body(p), region, 0.012, depth=0.04, k=0.002)

    return Comp(f"{N}_Mouth", mouth, mat, voxel=0.004, tris=2400)


SPHERE_BOUNDS = ((-1.4, -1.4, -0.2), (1.4, 1.4, 2.5))

# Saturated vinyl washes toward pastel under AgX, so renders use the color-faithful Khronos
# PBR Neutral transform (as Pocket Grove does). The GLB albedo is unaffected.
RENDER_VIEW = "Khronos PBR Neutral|None|-0.9"


# ---------------------------------------------------------------- 1. Verity

def verity():
    N = "Verity"
    body = (f"{N}_Vinyl", sphere_gloss("#F7CF16"))
    ink = (f"{N}_Ink", Mat("#141210", rough=0.15, coat=0.6))
    comps = [Comp(f"{N}_Body", sphere_body, body, voxel=0.012, tris=12000)]
    comps += oval_eyes(N, 0.2, 0.0, 0.088, 0.135, ink)
    comps.append(smile_mouth(N, ink, 0.64, -0.255, -0.625, 0.046, 0.017, 0.045))
    return assemble(N, "Verity", "Common", comps, {}, SPHERE_BOUNDS, catalog="concept.verity")


# ---------------------------------------------------------------- 2. Falsity

def falsity():
    N = "Falsity"
    body = (f"{N}_Vinyl", sphere_gloss("#1D6EEA"))
    ink = (f"{N}_Ink", Mat("#0E0F14", rough=0.15, coat=0.6))
    comps = [Comp(f"{N}_Body", sphere_body, body, voxel=0.012, tris=12000)]
    comps += oval_eyes(N, 0.2, 0.0, 0.085, 0.135, ink)
    comps.append(smile_mouth(N, ink, 0.66, -0.25, -0.63, 0.046, 0.017, 0.045))
    return assemble(N, "Falsity", "Uncommon", comps, {}, SPHERE_BOUNDS, catalog="concept.falsity")


# ---------------------------------------------------------------- 3. Cruelty

def cruelty():
    N = "Cruelty"
    body = (f"{N}_Vinyl", sphere_gloss("#E8141A"))
    paint = (f"{N}_Paint", Mat("#120C0C", rough=0.55))
    teeth_m = (f"{N}_Teeth", Mat("#F3EEE6", rough=0.35, coat=0.3))

    # Grin crescent from the FRONT view: pointed ends at (+-0.755, -0.06), upper lip at
    # -0.25 and lower lip at -0.825 on the centreline.
    w, ze = 0.755, -0.06
    cu, ru_ = circle_through(w, ze, -0.25)
    cl, rl = circle_through(w, ze, -0.825)
    cm, rm = circle_through(w, ze, -0.52)  # where the upper and lower teeth meet
    rim = 0.056  # painted outline around the teeth

    def crescent(u, v, inset=0.0):
        lower = np.sqrt(u * u + (v - cl) ** 2) - rl
        upper = np.sqrt(u * u + (v - cu) ** 2) - ru_
        return np.maximum(lower + inset, -(upper - inset))

    def mouth(p):
        u, v, clip = front(p)
        return skin(sphere_body(p), np.maximum(crescent(u, v), clip), 0.012, depth=0.04, k=0.002)

    pitch, gap = 0.108, 0.014

    def teeth(p):
        u, v, clip = front(p)
        region = crescent(u, v, rim)
        seam = np.abs(np.sqrt(u * u + (v - cm) ** 2) - rm) - gap
        upper_row = np.sqrt(u * u + (v - cm) ** 2) > rm
        cols = np.where(upper_row, u, u + pitch * 0.5)  # lower teeth sit half a tooth over
        split = np.abs((cols + pitch * 0.5) % pitch - pitch * 0.5) - gap
        region = smax(region, -np.minimum(seam, split), 0.012)
        return skin(sphere_body(p), np.maximum(region, clip), 0.024, depth=0.04, k=0.003)

    def eyes(p):
        u, v, clip = front(p)
        regs = []
        for sx in (-1.0, 1.0):
            a = math.radians(8.0) * sx  # tops lean outward
            eu, ev = u - sx * 0.355, v - 0.06
            eu, ev = eu * math.cos(a) - ev * math.sin(a), eu * math.sin(a) + ev * math.cos(a)
            # teardrop: the lower half narrows to a soft point
            narrow = 1.0 - 0.32 * np.clip(-ev / 0.28, 0.0, 1.0) ** 1.5
            regs.append(ellipse2(eu / narrow, ev, 0.122, 0.28) * np.minimum(narrow, 1.0))
        return skin(sphere_body(p), np.maximum(np.minimum(*regs), clip), 0.012, depth=0.04, k=0.003)

    comps = [
        Comp(f"{N}_Body", sphere_body, body, voxel=0.012, tris=12000),
        Comp(f"{N}_Eyes", eyes, paint, voxel=0.005, tris=2400),
        Comp(f"{N}_Mouth", mouth, paint, voxel=0.005, tris=4000),
        Comp(f"{N}_Teeth", teeth, teeth_m, voxel=0.004, tris=12000),
    ]
    return assemble(N, "Cruelty", "Rare", comps, {}, SPHERE_BOUNDS, catalog="concept.cruelty")


# ---------------------------------------------------------------- 4. Lovity

def heart2(u, v):
    """Inigo Quilez's 2D heart: tip at (0, 0), lobes up to v ~ 1.1, width ~ +-0.6."""
    u = np.abs(u)
    lobe = np.sqrt((u - 0.25) ** 2 + (v - 0.75) ** 2) - math.sqrt(2.0) / 4.0
    m = 0.5 * np.maximum(u + v, 0.0)
    body = np.sqrt(np.minimum(u * u + (v - 1.0) ** 2, (u - m) ** 2 + (v - m) ** 2)) * np.sign(u - v)
    return np.where(u + v > 1.0, lobe, body)


def puffy_heart(p, centre, width, turn=0.0, roll=0.0):
    """Glossy pillow heart facing -Y: fully rounded rim, domed faces. `width` in studs."""
    s = width / 1.2
    R = rot(0.0, roll, turn)
    x, y, z = local(p, centre, R)
    u, v, w = x / s, z / s + 0.55, y / s  # centre the heart's mass on `centre`
    h = 0.21
    inner = heart2(u, v) + h
    bulge = 0.2 * np.clip(-inner / 0.35, 0.0, 1.0)
    return (np.sqrt(np.maximum(inner, 0.0) ** 2 + w * w) - h - bulge) * s


def lovity():
    N = "Lovity"
    body = (f"{N}_Vinyl", sphere_gloss("#F56BA4"))
    eye_m = (f"{N}_EyeGloss", Mat("#5E0A22", rough=0.12, coat=0.8))
    shine_m = (f"{N}_EyeShine", Mat("#FFFFFF", rough=0.3))
    mouth_m = (f"{N}_Mouth", Mat("#6A0F2C", rough=0.3, coat=0.4))
    comps = [Comp(f"{N}_Body", sphere_body, body, voxel=0.012, tris=12000)]
    comps += oval_eyes(N, 0.45, 0.0, 0.105, 0.2, eye_m, dome=0.035,
                       shine=(shine_m, 0.3, 0.42, 0.3, 0.26))
    comps.append(smile_mouth(N, mouth_m, 0.61, -0.26, -0.6, 0.05, 0.02, 0.045))
    heart_m = (f"{N}_Heart", Mat("#F2336C", rough=0.15, coat=0.8))
    # Four hearts orbit the sphere in every CHARACTER VIEW: placement from the FRONT view
    # (x, z relative to the sphere centre), depth from the SIDE and 3/4 views. They are
    # free-floating; the runtime anchors every part.
    hearts = [
        ((0.7, 0.25, CZ + 1.42), 0.62, 28.0, -18.0),  # large, above the right shoulder
        ((-1.17, -0.3, CZ + 0.72), 0.44, -38.0, 20.0),  # upper left
        ((1.33, 0.15, CZ + 0.0), 0.4, 42.0, -14.0),  # right, mid height
        ((-1.28, -0.45, CZ - 0.62), 0.44, -32.0, 12.0),  # lower left, in front
    ]

    def heart_fn(p):
        d = None
        for c, w, turn, roll in hearts:
            h = puffy_heart(p, c, w, turn, roll)
            d = h if d is None else np.minimum(d, h)
        return d

    comps.append(Comp(f"{N}_Hearts", heart_fn, heart_m, voxel=0.006, tris=9000))
    return assemble(N, "Lovity", "Legendary", comps, {}, ((-1.9, -1.5, -0.2), (1.9, 1.5, 3.1)),
                    catalog="concept.lovity")


# ---------------------------------------------------------------- 5. Verity True Form

def verity_true_form():
    N = "VerityTrueForm"
    flesh = (f"{N}_Flesh", Mat("#BEA862", rough=0.62, subsurface=0.12))
    void = (f"{N}_Void", Mat("#0D0C0A", rough=0.3, coat=0.3))
    seam = (f"{N}_Seam", Mat("#1E1912", rough=0.5))

    # Hunched pose from the FRONT and SIDE views: the head hangs forward of the chest and
    # tilts toward the character's right; arms reach to mid-thigh; legs splay slightly.
    # The head stays on the centreline (tilted, not shifted): ModelAssets faces each figure
    # along centre -> eyes, so an off-centre head would turn the whole figure sideways.
    HC = np.array([0.0, -0.24, 3.21])
    HR = rot(20.0, -12.0, 0.0)  # face pitched down, crown tipped toward -X

    def torso_core(p):
        cage = ellipsoid(p, (0.0, 0.0, 2.5), (0.2, 0.135, 0.36))
        yoke = smin(round_cone(p, (-0.24, 0.05, 2.76), (0.0, 0.05, 2.85), 0.062, 0.07),
                    round_cone(p, (0.24, 0.05, 2.76), (0.0, 0.05, 2.85), 0.062, 0.07), 0.04)
        belly = ellipsoid(p, (0.0, 0.025, 2.12), (0.125, 0.095, 0.24))
        pelvis = ellipsoid(p, (0.0, 0.04, 1.97), (0.165, 0.115, 0.13))
        d = smin(smin(cage, yoke, 0.1), smin(belly, pelvis, 0.08), 0.1)
        for sx in (-1.0, 1.0):
            d = smin(d, ellipsoid(p, (sx * 0.075, 0.1, 1.95), (0.085, 0.07, 0.1)), 0.04)  # seat
            d = smin(d, sphere(p, (sx * 0.265, 0.04, 2.76), 0.068), 0.05)  # shoulder caps
            d = smin(d, round_cone(p, (sx * 0.03, -0.11, 2.79), (sx * 0.23, -0.02, 2.8), 0.022, 0.026), 0.03)
        return d

    def torso(p):
        d = torso_core(p)
        x, y, z = p
        # ribs: ridges sweeping down and outward over the front and sides of the cage
        phase = (z + 0.42 * np.abs(x)) / 0.078
        ridge = np.clip(np.cos(2 * math.pi * phase), 0.0, 1.0) ** 2
        env = (np.clip((z - 2.16) / 0.08, 0, 1) * np.clip((2.74 - z) / 0.06, 0, 1)
               * np.clip((0.06 - y) / 0.08, 0, 1) * np.clip((np.abs(x) - 0.025) / 0.04, 0, 1))
        d = d - 0.013 * ridge * env
        # sternum groove and a shallow navel
        d = d + 0.006 * np.exp(-(x / 0.018) ** 2) * np.clip((z - 2.25) / 0.1, 0, 1) * (y < 0)
        d = smax(d, -sphere(p, (0.0, -0.118, 2.06), 0.014), 0.008)
        return d

    spine_pts = [surface_point(torso_core, (0.0, 0.0, z), (0.0, 1.0, 0.0)) for z in np.arange(1.98, 2.86, 0.062)]

    def neck(p):
        return tube(p, [(0.0, 0.05, 2.78), (0.0, -0.07, 2.97), (0.01, -0.17, 3.09)], [0.052, 0.042, 0.04], k=0.0)

    def limbs(p):
        d = None
        for sx in (-1.0, 1.0):
            arm = tube(p, [(sx * 0.275, 0.04, 2.74), (sx * 0.31, 0.05, 2.35), (sx * 0.33, 0.04, 1.91),
                           (sx * 0.345, 0.02, 1.5), (sx * 0.355, -0.005, 1.1)],
                       [0.054, 0.048, 0.043, 0.039, 0.031], k=0.0)
            arm = smin(arm, sphere(p, (sx * 0.33, 0.05, 1.91), 0.047), 0.03)  # elbow
            leg = tube(p, [(sx * 0.085, 0.04, 2.0), (sx * 0.11, 0.02, 1.5), (sx * 0.14, 0.0, 1.07),
                           (sx * 0.17, 0.02, 0.6), (sx * 0.2, 0.045, 0.12)],
                       [0.085, 0.068, 0.053, 0.052, 0.034], k=0.0)
            leg = smin(leg, sphere(p, (sx * 0.14, -0.01, 1.07), 0.058), 0.03)  # knee
            foot = smin(ellipsoid(p, (sx * 0.205, -0.085, 0.04), (0.058, 0.18, 0.042)),
                        sphere(p, (sx * 0.2, 0.06, 0.05), 0.045), 0.06)
            leg = smin(leg, foot, 0.05)
            part = smin(arm, leg, 0.0)
            d = part if d is None else np.minimum(d, part)
        return d

    def body(p):
        d = smin(torso(p), neck(p), 0.05)
        d = smin(d, limbs(p), 0.05)
        for c in spine_pts:
            d = smin(d, sphere(p, c, 0.02), 0.02)
        return flat_base(d, p)

    def head_local(p):
        return local(p, HC, HR)

    def head_core(p):
        q = head_local(p)
        cranium = ellipsoid(q, (0.0, 0.0, 0.035), (0.178, 0.185, 0.175))
        jaw = ellipsoid(q, (0.0, -0.065, -0.1), (0.105, 0.095, 0.085))
        d = smin(cranium, jaw, 0.07)
        for sx in (-1.0, 1.0):  # cheekbones
            d = smin(d, ellipsoid(q, (sx * 0.085, -0.115, -0.045), (0.04, 0.035, 0.03)), 0.04)
        return d

    eye_dx, eye_z, eye_r = 0.07, -0.03, (0.037, 0.041)

    def head(p):
        q = head_local(p)
        d = head_core(p)
        for sx in (-1.0, 1.0):  # sunken sockets
            d = smax(d, -ellipsoid(q, (sx * eye_dx, -0.2, eye_z), (eye_r[0] * 1.15, 0.06, eye_r[1] * 1.15)), 0.025)
        return d

    def face_uv(p):
        q = head_local(p)
        return q[0], q[2], q[1] + 0.05  # clip to the face side of the head

    def eyes(p):
        u, v, clip = face_uv(p)
        regs = [ellipse2(u - sx * eye_dx, v - eye_z, *eye_r) for sx in (-1.0, 1.0)]
        return skin(head(p), np.maximum(np.minimum(*regs), clip), 0.006, depth=0.03, k=0.003)

    def mouth(p):
        u, v, clip = face_uv(p)
        # thin upturned smile, reaching higher on the right cheek (+X), and two nostril dots
        a = math.radians(9.0)
        su, sv = u - 0.012, v + 0.088
        su, sv = su * math.cos(a) + sv * math.sin(a), -su * math.sin(a) + sv * math.cos(a)
        line = smile2(su, sv - 0.088, 0.085, -0.088, -0.128, 0.0065, 0.004)
        nose = np.minimum(ellipse2(u - 0.014, v + 0.072, 0.008, 0.006), ellipse2(u + 0.014, v + 0.072, 0.008, 0.006))
        return skin(head(p), np.maximum(np.minimum(line, nose), clip), 0.004, depth=0.02, k=0.002)

    def hands(p):
        d = None
        for sx in (-1.0, 1.0):
            x0 = sx * 0.357
            palm = ellipsoid(p, (x0, -0.01, 0.99), (0.026, 0.05, 0.1))
            palm = smin(palm, round_cone(p, (x0, -0.005, 1.13), (x0, -0.01, 1.0), 0.03, 0.035), 0.03)
            hand = palm
            for fy, length in ((-0.042, 0.19), (-0.014, 0.21), (0.014, 0.2), (0.04, 0.16)):
                finger = tube(p, [(x0, fy, 0.92), (x0 - sx * 0.008, fy - 0.006, 0.92 - length * 0.55),
                                  (x0 - sx * 0.02, fy - 0.018, 0.92 - length)],
                              [0.016, 0.014, 0.011], k=0.0)
                hand = smin(hand, finger, 0.012)
            thumb = tube(p, [(x0 - sx * 0.005, -0.045, 1.02), (x0 - sx * 0.012, -0.08, 0.94),
                             (x0 - sx * 0.02, -0.085, 0.87)], [0.016, 0.014, 0.011], k=0.0)
            hand = smin(hand, thumb, 0.015)
            d = hand if d is None else np.minimum(d, hand)
        return d

    comps = [
        Comp(f"{N}_Body", body, flesh, voxel=0.0055, tris=19000),
        Comp(f"{N}_Head", head, flesh, voxel=0.004, tris=9000),
        Comp(f"{N}_Hands", hands, flesh, voxel=0.0032, tris=9000),
        Comp(f"{N}_Eyes", eyes, void, voxel=0.0035, tris=1600),
        Comp(f"{N}_Mouth", mouth, seam, voxel=0.0025, tris=1600),
    ]
    return assemble(N, "Verity True Form", "Mythical", comps, {}, ((-0.7, -0.7, -0.2), (0.7, 0.6, 3.7)),
                    catalog="concept.verity-true-form")


def assemble(name, title, rarity, comps, mats, bounds, **info):
    """Resolve material tuples into a flat figure description."""
    materials = {}
    for c in comps:
        mname, m = c.mat
        materials[mname] = m
        c.mat = mname
    return dict(name=name, title=title, rarity=rarity, comps=comps, mats=materials, bounds=bounds, **info)


FIGURES = {
    "verity": verity,
    "falsity": falsity,
    "cruelty": cruelty,
    "lovity": lovity,
    "verity-true-form": verity_true_form,
}
