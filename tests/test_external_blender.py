"""Blender-only external mesh/UV/normal and optional optimization/baking tests."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/figures'))
import bpy
import numpy as np
import build
import import_blender as importer


class ExternalBlenderTests(unittest.TestCase):
    def setUp(self):
        build.reset()
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32)
        self.obj = bpy.context.object
        self.obj.name = 'ExplicitBody'
        mat = bpy.data.materials.new('Original')
        mat.use_nodes = True
        self.obj.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
        mod = self.obj.modifiers.new('Triangulate', 'TRIANGULATE')
        bpy.ops.object.modifier_apply(modifier=mod.name)
        self.out = ROOT / 'build/figures/external-unit-tests'
        self.out.mkdir(parents=True, exist_ok=True)

    def test_subset_keeps_uvs_split_normals_and_source(self):
        src = self.obj.data
        indices = list(range(300))
        before = len(src.polygons)
        part = importer.subset(self.obj, indices, 'SelectedOriginalTriangles', 0)
        old_loops = [i for f in indices for i in src.polygons[f].loop_indices]
        self.assertEqual(len(part.data.polygons), len(indices))
        self.assertEqual(len(src.polygons), before)
        for loop, old in zip(part.data.loops, old_loops):
            self.assertLess((part.data.uv_layers.active.data[loop.index].uv - src.uv_layers.active.data[old].uv).length, 1e-6)
            self.assertGreater(part.data.corner_normals[loop.index].vector.dot(src.corner_normals[old].vector), .99999)

    def test_lossless_default_and_protected_semantics(self):
        count = len(self.obj.data.polygons)
        self.assertEqual(importer.optimize(self.obj, None, self.out)['mode'], 'lossless')
        self.assertEqual(len(self.obj.data.polygons), count)
        entry = {'eyes': {'object': 'MonolithicSource'}, 'protected_objects': ['BespokeDetail']}
        for name in ('MonolithicSource', 'BespokeDetail', 'HairLock', 'FacePaint', 'Clothing', 'EyeLens', 'Accessory'):
            self.assertTrue(importer.protected_object(name, entry))
        self.assertFalse(importer.protected_object('Body', entry))

    def test_adaptive_decimation_respects_surface_error(self):
        info = importer.optimize(self.obj, {'target_triangles': 2400, 'max_surface_error': .02}, self.out)
        self.assertEqual(info['mode'], 'explicit_decimation')
        self.assertLessEqual(info['surface_error'], .02)
        self.assertLess(len(self.obj.data.polygons), info['before_triangles'])
        importer.geometry_check(self.obj)

    def test_excessive_loss_is_rejected(self):
        with self.assertRaises(ValueError):
            importer.optimize(self.obj, {'target_triangles': 4, 'max_surface_error': .00001}, self.out)

    def test_optional_normal_bake_preserves_uv_and_albedo_material(self):
        info = importer.optimize(self.obj, {'target_triangles': 2400, 'max_surface_error': .02,
                                           'bake_normals': True, 'bake_resolution': 128}, self.out)
        self.assertTrue((self.out / 'maps' / info['normal_bake']).is_file())
        shader = next(n for n in self.obj.data.materials[0].node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        self.assertTrue(shader.inputs['Normal'].is_linked)
        self.assertEqual(self.obj.data.materials[0].name, info['baked_material'])
        self.assertTrue(self.obj.data.uv_layers.active)

    def test_partition_boundaries_are_valid_but_degenerate_uvs_fail(self):
        part = importer.subset(self.obj, range(300), 'OpenOriginalPatch', 0)
        self.assertGreater(importer.geometry_check(part)['boundary_edges'], 0)
        for uv in part.data.uv_layers.active.data:
            uv.uv = (0, 0)
        with self.assertRaises(ValueError):
            importer.geometry_check(part)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ExternalBlenderTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        raise RuntimeError('External Blender tests failed')
