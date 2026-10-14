"""Headless Blender regression checks. Writes only ignored build/figures/test-maps."""
import importlib.util
from pathlib import Path
import sys
import unittest

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/figures"))
import build
from baking import bake_maps
from glb import summary
from materials import Mat, preset
from modeling import Comp
from sdf import sphere


class BlenderTests(unittest.TestCase):
    def setUp(self):
        build.reset()

    def test_color_encoding_and_data_maps(self):
        mat = build.make_material("Color", preset("satin_vinyl", "#80A0C0", pbr=True))
        images = [n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"]
        color = next(i for i in images if i.colorspace_settings.name == "sRGB")
        expected = 128 / 255
        self.assertAlmostEqual(color.pixels[0], expected, places=5)
        packed = next(i for i in images if i.colorspace_settings.name == "Non-Color")
        # PNG channels are 8-bit; accept only the expected encoding quantization.
        self.assertAlmostEqual(packed.pixels[1], 0.38, delta=1 / 255)
        self.assertAlmostEqual(packed.pixels[2], 0, places=5)

    def test_identical_slivers_are_not_a_surface_change(self):
        # A long obtuse sliver beside its neighbours: BVH sampling alone reports a nonzero self-distance.
        verts = [(0, 0, 0), (0.081, 0, 0), (0.0645, 0.0002, 0), (0.03, -0.02, 0), (0.05, 0.03, 0.001)]
        faces = [(0, 1, 2), (0, 3, 1), (0, 2, 4), (2, 1, 4)]
        a, b = bpy.data.meshes.new("A"), bpy.data.meshes.new("B")
        a.from_pydata(verts, [], faces)
        b.from_pydata(verts[::-1], [], [tuple(4 - i for i in f[::-1]) for f in faces])
        self.assertEqual(build.face_set(a), build.face_set(b))
        moved = bpy.data.meshes.new("Moved")
        moved.from_pydata([verts[0], verts[1], (0.0645, 0.0005, 0), verts[3], verts[4]], [], faces)
        self.assertNotEqual(build.face_set(a), build.face_set(moved))

    def test_excessive_decimation_and_clipped_bounds_fail(self):
        col = bpy.context.scene.collection
        c = Comp("OverOptimized", lambda p: sphere(p, (0, 0, 0), 0.4), "m",
                 bounds=((-0.6,)*3, (0.6,)*3), voxel=0.025, tris=16, max_surface_error=0.001)
        with self.assertRaisesRegex(ValueError, "optimization moved"):
            build.build_object(c, c.bounds, col)
        c = Comp("Clipped", lambda p: sphere(p, (0, 0, 0), 0.4), "m",
                 bounds=((-0.3,)*3, (0.3,)*3), voxel=0.03)
        with self.assertRaisesRegex(ValueError, "touches sampling bounds"):
            build.build_object(c, c.bounds, col)

    def test_object_factory_mesh_takes_component_name(self):
        def source():
            bpy.ops.mesh.primitive_cube_add(size=1)
            bpy.context.object.data.name = "ImportedMesh"
            return bpy.context.object
        col = bpy.data.collections.new("factory-name")
        obj, _ = build.build_object(Comp("Named_Body", None, "m", mesh=source, tris=100), None, col)
        self.assertEqual(obj.data.name, "Named_Body")

    def test_procedural_and_high_to_low_bakes_survive_export(self):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.5)
        low = bpy.context.object
        low.name = "BakeSwatch"
        low.data.materials.append(build.make_material("Paint", Mat("#6080A0", rough=0.6, metal=0.2)))
        mat = low.data.materials[0]
        nt = mat.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        checker = nt.nodes.new("ShaderNodeTexChecker")
        nt.links.new(checker.outputs["Color"], bsdf.inputs["Base Color"])
        original_node_count = len(nt.nodes)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=0.5)
        high = bpy.context.object
        high.name = "HighReference"
        paths = bake_maps(low, ROOT / "build/figures/test-maps", resolution=128,
                          channels=("color", "roughness", "metalness", "normal"), high=high, cage=0.15)
        self.assertEqual(len(nt.nodes), original_node_count)
        self.assertEqual(nt.nodes["Material Output"].inputs["Surface"].links[0].from_node, bsdf)
        self.assertTrue(all(Path(p).is_file() for p in paths.values()))
        normal = build.load_map(paths["normal_map"], "Non-Color")
        data = np.array(normal.pixels[:]).reshape(-1, 4)
        self.assertGreater(data[:, 0].std(), 0.01)
        bpy.data.objects.remove(high, do_unlink=True)
        low.data.materials.clear()
        low.data.materials.append(build.make_material("BakedPaint", Mat("#FFFFFF", pbr=True, **paths)))
        # Use builder preparation to triangulate, preserve UVs and normalize normals.
        obj, _ = build.build_object(Comp("ExportSwatch", None, "m", mesh=low), ((-1,)*3, (1,)*3), bpy.context.scene.collection)
        obj.data.materials.clear()
        obj.data.materials.append(build.make_material("FinalBaked", Mat("#FFFFFF", pbr=True, **paths)))
        root = bpy.data.objects.new("Root", None)
        bpy.context.scene.collection.objects.link(root)
        obj.parent = root
        path = str(ROOT / "build/figures/test-maps/baked.glb")
        build.export_glb(root, [obj], path)
        self.assertEqual(summary(path)["errors"], [])
        self.assertEqual(len(summary(path)["pbr_materials"]), 1)
        snapshots = build.snapshots_for([obj])
        check = build.reimport_check(path, {obj.name: len(obj.data.polygons)}, snapshots)
        self.assertEqual(check["geometry_mismatches"], {})

    def test_old_definitions_load_without_rebuilding(self):
        for path in (ROOT / "assets/figures").glob("*/figures.py"):
            spec = importlib.util.spec_from_file_location(path.parent.name, path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            self.assertTrue(mod.FIGURES, str(path))
        # Exercise the old duck-typed component/material path on a synthetic sphere.
        class LegacyComp:
            name, mat, voxel, tris, ramp, min_faces = "Legacy", "m", 0.04, 2000, None, 24
            fn = staticmethod(lambda p: sphere(p, (0, 0, 0.5), 0.2))
        class LegacyMat:
            color, rough, metal, alpha, render = "#80A0C0", 0.5, 0.0, 1.0, {}
        spec = dict(name="LegacyRoot", comps=[LegacyComp()], mats={"m": LegacyMat()}, bounds=((-1,)*3, (1,)*3))
        _, objs, _, _ = build.build_figure(spec, bpy.context.scene.collection)
        self.assertEqual(build.audit(objs[0])["non_manifold_edges"], 0)


if __name__ == "__main__":
    result = unittest.main(argv=[sys.argv[0]], exit=False).result
    if not result.wasSuccessful():
        raise RuntimeError("Blender regression tests failed")
