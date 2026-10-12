"""Run inside Blender's bundled Python (numpy), or any numpy-equipped Python."""
import sys
from pathlib import Path
import unittest

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/figures"))
from materials import preset
from modeling import Comp, braid, garment_loft, hair_lock, sweep, transport_frames
from sdf import ellipse2, ellipsoid, round_cone, sphere, surface_normal, surface_point


class ModelingTests(unittest.TestCase):
    def test_sweep_closed_topology_and_finite_frames(self):
        mesh = hair_lock([(0, 0, 0), (0.3, -0.2, 1), (0.2, 0, 2)], [0.2, 0.3, 0.02], [0.1, 0.1, 0.02])
        edges = {}
        for f in mesh.faces:
            for a, b in zip(f, f[1:] + f[:1]):
                key = tuple(sorted((a, b)))
                edges[key] = edges.get(key, 0) + 1
        self.assertTrue(all(n == 2 for n in edges.values()))
        self.assertTrue(np.isfinite(mesh.vertices).all())
        self.assertEqual(len(mesh.faces), len(mesh.uvs))
        _, frames = transport_frames(np.array([[0, 0, 0], [0, 0, 1], [0.01, 0, 2]]))
        self.assertTrue(np.allclose(np.linalg.norm(frames, axis=2), 1))

    def test_garment_has_inner_outer_surfaces_and_closed_rims(self):
        mesh = garment_loft([(0, 0, 0), (0.1, 0, 1)], [(0.5, 0.4), (0.3, 0.3)], sides=16)
        self.assertEqual(len(mesh.vertices), 64)
        self.assertEqual(len(mesh.faces), 64)
        self.assertTrue(np.isfinite(mesh.vertices).all())

    def test_invalid_geometry_fails_early(self):
        for call in (
            lambda: sweep([(0, 0, 0), (0, 0, 0)], 0.1),
            lambda: sweep([(0, 0, 0), (0, 0, 1)], 0),
            lambda: garment_loft([(0, 0, 1), (0, 0, 0)], [(1, 1), (1, 1)]),
            lambda: Comp("Thin", lambda p: 0, "m", voxel=0.01, min_feature=0.02),
            lambda: Comp("OverBudget", None, "m", mesh=object(), tris=20000),
        ):
            with self.assertRaises(ValueError):
                call()

    def test_contained_taper_and_coincident_endpoints_are_finite(self):
        p = (np.array([0, 0.5, 2]), np.zeros(3), np.zeros(3))
        self.assertTrue(np.allclose(round_cone(p, (0, 0, 0), (0, 0, 0), 1, 0.5), sphere(p, (0, 0, 0), 1)))
        self.assertTrue(np.isfinite(round_cone(p, (0, 0, 0), (0, 0, 0.01), 1, 0.1)).all())

    def test_surface_projection_fails_without_crossing(self):
        fn = lambda p: sphere(p, (0, 0, 0), 1)
        self.assertTrue(np.allclose(surface_point(fn, (0, 0, 0), (0, -1, 0)), (0, -1, 0)))
        self.assertTrue(np.allclose(surface_normal(fn, (0, -1, 0)), (0, -1, 0)))
        with self.assertRaises(ValueError):
            surface_point(fn, (0, 0, 0), (0, -1, 0), tmax=0.2)
        with self.assertRaises(ValueError):
            surface_point(fn, (2, 0, 0), (0, -1, 0))

    def test_ellipsoid_and_eye_centers_are_inside(self):
        self.assertAlmostEqual(float(ellipsoid((0, 0, 0), (0, 0, 0), (1, 2, 3))), -1)
        self.assertAlmostEqual(float(ellipse2(0, 0, 0.1, 0.2)), -0.1)

    def test_presets_and_braid(self):
        self.assertEqual(preset("polished_metal", "#ABCDEF", pbr=True).metal, 1)
        mesh = braid([(0, 0, 0), (0, 0, 1)], turns=1)
        self.assertTrue(np.isfinite(mesh.vertices).all())


if __name__ == "__main__":
    result = unittest.main(argv=[sys.argv[0]], exit=False).result
    if not result.wasSuccessful():
        raise RuntimeError("Modeling regression tests failed")
