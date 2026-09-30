"""Signed-distance sculpting primitives for the Tidepool Tales figures.

Every function takes point arrays (x, y, z) of identical shape and returns a
distance array: negative inside, positive outside. Coordinates are Blender
figure space: +Z up, the figure faces -Y, the character's left is +X.
"""

import math

import numpy as np


def _v(a):
    return np.asarray(a, dtype=np.float64)


def rot(rx=0.0, ry=0.0, rz=0.0):
    """XYZ Euler rotation in degrees, returned as a 3x3 matrix."""
    rx, ry, rz = (math.radians(a) for a in (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    mx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    my = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    mz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return mz @ my @ mx


def frame(forward, up_hint=(0, 0, 1)):
    """Rotation whose local +Z axis points along `forward`."""
    f = _v(forward) / np.linalg.norm(forward)
    u = _v(up_hint)
    if abs(np.dot(f, u / np.linalg.norm(u))) > 0.98:
        u = _v((0, 1, 0))
    x = np.cross(u, f)
    x /= np.linalg.norm(x)
    y = np.cross(f, x)
    return np.stack([x, y, f], axis=1)


def local(p, c, R=None):
    x, y, z = p[0] - c[0], p[1] - c[1], p[2] - c[2]
    if R is None:
        return x, y, z
    # q = R^T (p - c)
    return (
        R[0, 0] * x + R[1, 0] * y + R[2, 0] * z,
        R[0, 1] * x + R[1, 1] * y + R[2, 1] * z,
        R[0, 2] * x + R[1, 2] * y + R[2, 2] * z,
    )


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def union(ds, k=0.0):
    out = ds[0]
    for d in ds[1:]:
        out = smin(out, d, k)
    return out


def sphere(p, c, r):
    x, y, z = local(p, c)
    return np.sqrt(x * x + y * y + z * z) - r


def ellipsoid(p, c, r, R=None):
    x, y, z = local(p, c, R)
    rx, ry, rz = r
    k0 = np.sqrt((x / rx) ** 2 + (y / ry) ** 2 + (z / rz) ** 2)
    k1 = np.sqrt((x / rx**2) ** 2 + (y / ry**2) ** 2 + (z / rz**2) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def round_box(p, c, half, r, R=None):
    x, y, z = local(p, c, R)
    qx, qy, qz = np.abs(x) - half[0] + r, np.abs(y) - half[1] + r, np.abs(z) - half[2] + r
    outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2 + np.maximum(qz, 0) ** 2)
    inside = np.minimum(np.maximum(qx, np.maximum(qy, qz)), 0.0)
    return outside + inside - r


def cylinder(p, c, radius, half_h, r=0.0, R=None):
    """Capped cylinder along local Z with rounded edges."""
    x, y, z = local(p, c, R)
    dx = np.sqrt(x * x + y * y) - radius + r
    dz = np.abs(z) - half_h + r
    return np.minimum(np.maximum(dx, dz), 0.0) + np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dz, 0) ** 2) - r


def torus(p, c, big, small, R=None):
    x, y, z = local(p, c, R)
    q = np.sqrt(x * x + y * y) - big
    return np.sqrt(q * q + z * z) - small


def round_cone(p, a, b, r1, r2):
    """Capsule from a to b whose radius tapers from r1 to r2 (Inigo Quilez)."""
    a, b = _v(a), _v(b)
    ba = b - a
    l2 = float(np.dot(ba, ba))
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pax, pay, paz = p[0] - a[0], p[1] - a[1], p[2] - a[2]
    y = pax * ba[0] + pay * ba[1] + paz * ba[2]
    z = y - l2
    wx, wy, wz = pax * l2 - ba[0] * y, pay * l2 - ba[1] * y, paz * l2 - ba[2] * y
    x2 = wx * wx + wy * wy + wz * wz
    y2 = y * y * l2
    z2 = z * z * l2
    k = math.copysign(1.0, rr) * rr * rr * x2
    d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - r1
    d1 = np.sqrt(x2 + z2) * il2 - r2
    d2 = np.sqrt(x2 + y2) * il2 - r1
    return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))


def catmull(points, samples=6):
    """Dense Catmull-Rom sampling of a control polyline."""
    pts = [_v(q) for q in points]
    pts = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-2])
    return out


def tube(p, points, radii, k=0.02, samples=6):
    """Smoothly tapered tube through control points; radii per control point."""
    path = catmull(points, samples)
    rs = np.interp(np.linspace(0, 1, len(path)), np.linspace(0, 1, len(radii)), radii)
    d = None
    for i in range(len(path) - 1):
        seg = round_cone(p, path[i], path[i + 1], rs[i], rs[i + 1])
        d = seg if d is None else smin(d, seg, k)
    return d


# ---------------------------------------------------------------- 2D decals

def ellipse2(u, v, ru, rv):
    k0 = np.sqrt((u / ru) ** 2 + (v / rv) ** 2)
    k1 = np.sqrt((u / ru**2) ** 2 + (v / rv**2) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def arc2(u, v, radius, aperture_deg, thickness):
    """Arc centred on (0,0) opening upward: its middle is at (0, -radius)."""
    s, c = math.sin(math.radians(aperture_deg)), math.cos(math.radians(aperture_deg))
    px = np.abs(u)
    py = -v
    d_end = np.sqrt((px - s * radius) ** 2 + (py - c * radius) ** 2)
    d_ring = np.abs(np.sqrt(px * px + py * py) - radius)
    return np.where(c * px > s * py, d_end, d_ring) - thickness


def front_decal(p, cx, cz, shape, y_limit=0.0, tilt_deg=0.0):
    """Project a 2D XZ shape along Y onto front-facing surfaces (y < y_limit)."""
    u = p[0] - cx
    v = p[2] - cz
    if tilt_deg:
        a = math.radians(tilt_deg)
        u, v = u * math.cos(a) + v * math.sin(a), -u * math.sin(a) + v * math.cos(a)
    return np.maximum(shape(u, v), p[1] - y_limit)


def overlay(base, region, out, depth=0.05, k=0.006):
    """Thin skin that sits `out` above a base surface, clipped to a region."""
    shell = np.maximum(base - out, -(base + depth))
    return smax(shell, region, k)


def fan_angle(p, hinge):
    """Angle of each point around a scallop hinge, measured from the YZ plane."""
    vx, vy, vz = p[0] - hinge[0], p[1] - hinge[1], p[2] - hinge[2]
    return np.arctan2(vx, np.sqrt(vy * vy + vz * vz)), np.sqrt(vx * vx + vy * vy + vz * vz)


def ribs(angle, count_per_radian, sharp=0.55):
    """Rounded rib profile in [0,1]: 1 on rib crowns, 0 in the grooves."""
    return np.abs(np.cos(angle * count_per_radian * 0.5)) ** sharp
