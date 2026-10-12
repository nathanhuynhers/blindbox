"""Opt-in hybrid components. Units/axes match sdf.py; no Blender dependency.

Keep design decisions in figures.py. Mesh factories return MeshData, or a Blender
object (evaluated modifiers and transforms are copied by build.py).
"""
from dataclasses import dataclass
import math

import numpy as np

from sdf import catmull


QUALITY = {
    "simple": dict(voxel=0.012, tris=6000, max_surface_error=0.012),
    "medium": dict(voxel=0.008, tris=10000, max_surface_error=0.008),
    "high": dict(voxel=0.004, tris=16000, max_surface_error=0.004),
}


class Comp:
    """One material / MeshPart. Existing collection-local Comp classes still work.

    bounds bypasses coarse SDF discovery (essential for thin isolated features).
    min_feature is authored full thickness, not an inferred visual-quality score.
    expected_islands declares intentionally disconnected solids. min_faces=0 keeps
    all authored islands. smooth=False preserves hard surfaces. uv='auto' unwraps
    for maps; mesh UVs are preserved unless ramp is supplied.
    """
    def __init__(self, name, fn, mat, *, mesh=None, quality="medium", voxel=None,
                 tris=None, bounds=None, min_feature=None, expected_islands=1,
                 max_surface_error=None, min_faces=0, smooth=True, uv="auto", ramp=None):
        if (fn is None) == (mesh is None):
            raise ValueError("supply exactly one of fn or mesh")
        q = QUALITY[quality]
        self.name, self.fn, self.mat, self.mesh = name, fn, mat, mesh
        self.voxel = q["voxel"] if voxel is None else voxel
        self.tris = q["tris"] if tris is None else tris
        self.max_surface_error = q["max_surface_error"] if max_surface_error is None else max_surface_error
        self.bounds, self.min_feature = bounds, min_feature
        self.expected_islands, self.min_faces = expected_islands, min_faces
        self.smooth, self.uv, self.ramp = smooth, uv, ramp
        if not 0 < self.tris < 20000 or self.voxel <= 0 or self.max_surface_error <= 0:
            raise ValueError("invalid component budget/resolution")
        if min_feature is not None and (min_feature <= 0 or (fn is not None and self.voxel > min_feature / 3)):
            raise ValueError("SDF min_feature needs at least three voxels across thickness")


@dataclass
class MeshData:
    vertices: object
    faces: object
    # Optional per-face, per-corner UVs, so a seam does not require duplicate vertices.
    uvs: object = None


def _path(points, samples):
    p = np.asarray(points, dtype=float)
    if p.ndim != 2 or p.shape[1] != 3 or len(p) < 2 or not np.isfinite(p).all():
        raise ValueError("path needs at least two finite 3D points")
    if samples < 1 or np.any(np.linalg.norm(np.diff(p, axis=0), axis=1) < 1e-8):
        raise ValueError("path has repeated points or invalid sampling")
    return np.asarray(catmull(p, samples))


def transport_frames(path, up=(0, 0, 1)):
    """Rotation-minimizing frames avoid clump/ribbon twisting along curved paths."""
    p = np.asarray(path, dtype=float)
    tangents = np.gradient(p, axis=0)
    lengths = np.linalg.norm(tangents, axis=1)
    if np.any(lengths < 1e-8):
        raise ValueError("curve reverses direction; split it into separate sweeps")
    tangents /= lengths[:, None]
    n = np.asarray(up, dtype=float)
    n = n - np.dot(n, tangents[0]) * tangents[0]
    if np.linalg.norm(n) < 1e-8:
        n = np.eye(3)[np.argmin(np.abs(tangents[0]))]
        n -= np.dot(n, tangents[0]) * tangents[0]
    n /= np.linalg.norm(n)
    frames = []
    prev = tangents[0]
    for t in tangents:
        axis = np.cross(prev, t)
        sine, cosine = np.linalg.norm(axis), np.dot(prev, t)
        if cosine < -0.999:
            raise ValueError("curve reverses direction; split it")
        if sine > 1e-8:
            axis /= sine
            n = n * cosine + np.cross(axis, n) * sine + axis * np.dot(axis, n) * (1 - cosine)
        n -= np.dot(n, t) * t
        n /= np.linalg.norm(n)
        frames.append((n.copy(), np.cross(t, n)))
        prev = t
    return tangents, np.asarray(frames)


def sweep(points, radii, *, samples=8, sides=16, up=(0, 0, 1), cap_rings=4):
    """Closed elliptical sweep with hemispherical ends: locks, limbs, trim, ribbons.

    radii: scalar or one (width, depth) pair per control point. Positive final
    radius gives a rounded tapered tip, rather than a collapsed/degenerate ring.
    For buns/ponytails use curved paths; retain overlapping locks as separate comps.
    """
    path = _path(points, samples)
    if sides < 6 or cap_rings < 1:
        raise ValueError("sweep needs >=6 sides and >=1 cap ring")
    r = np.asarray(radii, dtype=float)
    if r.ndim == 0:
        r = np.full((len(points), 2), r)
    if r.shape != (len(points), 2) or not np.isfinite(r).all() or np.any(r <= 0):
        raise ValueError("radii must be positive scalar or (width, depth) per control")
    t = np.linspace(0, len(points) - 1, len(path))
    rs = np.stack([np.interp(t, np.arange(len(points)), r[:, i]) for i in range(2)], axis=1)
    tangent, frames = transport_frames(path, up)
    rings = []
    for end, sign in ((0, -1),):
        for a in np.linspace(math.pi / 2, 0, cap_rings + 1)[1:-1]:
            rings.append((path[end] + sign * tangent[end] * min(rs[end]) * math.sin(a),
                          frames[end], rs[end] * math.cos(a)))
    rings += list(zip(path, frames, rs))
    for a in np.linspace(0, math.pi / 2, cap_rings + 1)[1:-1]:
        rings.append((path[-1] + tangent[-1] * min(rs[-1]) * math.sin(a), frames[-1], rs[-1] * math.cos(a)))
    theta = np.arange(sides) * 2 * math.pi / sides
    verts = [c + f[0] * r[0] * math.cos(a) + f[1] * r[1] * math.sin(a)
             for c, f, r in rings for a in theta]
    faces = []
    uv = []
    for j in range(len(rings) - 1):
        for i in range(sides):
            k = (i + 1) % sides
            faces.append((j * sides + i, j * sides + k, (j + 1) * sides + k, (j + 1) * sides + i))
            uv.append(((i / sides, j / (len(rings) - 1)), ((i + 1) / sides, j / (len(rings) - 1)),
                       ((i + 1) / sides, (j + 1) / (len(rings) - 1)), (i / sides, (j + 1) / (len(rings) - 1))))
    for end, sign, ring in ((0, -1, 0), (-1, 1, len(rings) - 1)):
        idx = len(verts)
        verts.append(path[end] + sign * tangent[end] * min(rs[end]))
        for i in range(sides):
            a, b = ring * sides + i, ring * sides + (i + 1) % sides
            faces.append((idx, b, a) if sign < 0 else (idx, a, b))
            disk = lambda j: (0.5 + 0.45 * math.cos(j * 2 * math.pi / sides), 0.5 + 0.45 * math.sin(j * 2 * math.pi / sides))
            uv.append(((0.5, 0.5), disk(i + 1), disk(i)) if sign < 0 else ((0.5, 0.5), disk(i), disk(i + 1)))
    return MeshData(np.asarray(verts), faces, uv)


def hair_lock(points, widths, depths, **kwargs):
    return sweep(points, np.column_stack((widths, depths)), **kwargs)


def join_meshes(meshes):
    """Concatenate, without boolean fusion. Declare expected_islands accordingly."""
    vertices, faces, uvs = [], [], []
    offset = 0
    meshes = list(meshes)
    for mesh in meshes:
        vertices.extend(mesh.vertices)
        faces.extend(tuple(v + offset for v in face) for face in mesh.faces)
        if mesh.uvs is not None:
            uvs.extend(mesh.uvs)
        offset += len(mesh.vertices)
    return MeshData(vertices, faces, uvs if all(m.uvs is not None for m in meshes) else None)


def braid(points, radius=0.08, spread=0.09, turns=3, samples=16, sides=12):
    """Three interwoven sweeps. No implicit union; overlapping strands are intentional."""
    path = _path(points, samples)
    _, frames = transport_frames(path)
    phase = np.linspace(0, turns * 2 * math.pi, len(path))
    strands = []
    for i in range(3):
        a = phase + i * 2 * math.pi / 3
        centers = path + spread * (frames[:, 0] * np.cos(a)[:, None] + frames[:, 1] * np.sin(a)[:, None])
        strands.append(sweep(centers, radius, samples=1, sides=sides))
    return join_meshes(strands)


def garment_loft(centers, radii, *, thickness=0.04, sides=48, folds=0, fold_depth=0.0):
    """Closed hollow elliptical garment along +Z: skirt, coat body, cuff or collar.

    Rings are authored anatomy, not a character template. Add intermediate rings
    for curved hems/waists; offset centers for asymmetry. Rims join inner and outer
    surfaces. folds are radial, geometry-based pleats (not Blender shader effects).
    """
    c, r = np.asarray(centers, float), np.asarray(radii, float)
    if c.shape != (len(r), 3) or r.shape != (len(c), 2) or len(c) < 2:
        raise ValueError("loft needs matching center and radius rings")
    if not np.isfinite(c).all() or not np.isfinite(r).all() or sides < 8 or thickness <= 0:
        raise ValueError("invalid loft parameters")
    if np.any(np.diff(c[:, 2]) <= 0) or np.any(r <= thickness + abs(fold_depth)):
        raise ValueError("loft rings must ascend and have positive inner radii")
    a = np.arange(sides) * 2 * math.pi / sides
    fold = fold_depth * np.cos(folds * a) if folds else np.zeros(sides)
    verts = []
    for inset in (0, thickness):
        for center, radii in zip(c, r):
            verts.extend(center + np.column_stack(((radii[0] - inset + fold) * np.cos(a),
                                                   (radii[1] - inset + fold) * np.sin(a), np.zeros(sides))))
    count = len(c) * sides
    faces = []
    for layer in range(2):
        for j in range(len(c) - 1):
            for i in range(sides):
                k = (i + 1) % sides
                f = (j * sides + i, j * sides + k, (j + 1) * sides + k, (j + 1) * sides + i)
                faces.append(tuple(v + layer * count for v in (f if layer == 0 else f[::-1])))
    for j in (0, len(c) - 1):
        for i in range(sides):
            a, b = j * sides + i, j * sides + (i + 1) % sides
            f = (a, a + count, b + count, b)
            faces.append(f[::-1] if j == 0 else f)
    return MeshData(verts, faces)
