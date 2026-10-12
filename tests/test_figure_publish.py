"""Offline tests for tools/figures/publish.py. Never uploads or runs Blender."""
import copy
import importlib.util
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "publish", Path(__file__).resolve().parents[1] / "tools/figures/publish.py")
publish = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(publish)


def report(**overrides):
    value = {
        "figure": "BubbleBean", "title": "Bubble Bean", "root": "BubbleBean", "catalog": "tide.bubble",
        "face": "BubbleBean_Eyes", "glass": ["BubbleBean_BubbleCap"], "meshes": 2,
        "size_xyz_studs": [2.2, 1.7, 3.1],
        "components": {
            "BubbleBean_Eyes": {"tris": 1400, "non_manifold_edges": 0, "boundary_edges": 0,
                                "zero_area_faces": 0, "signed_volume": 0.01},
            "BubbleBean_BubbleCap": {"tris": 5000, "non_manifold_edges": 0, "boundary_edges": 0,
                                     "zero_area_faces": 0, "signed_volume": 0.5},
        },
        "reimport": {"meshes": 2, "triangle_mismatches": {}},
        "glb": {"all_materials_textured": True, "extensions_required": [], "extensions_used": []},
    }
    value.update(overrides)
    return value


class GateTests(unittest.TestCase):
    def test_v2_geometry_and_fidelity_gates(self):
        value = report(schema_version=2)
        value["triangles"] = 6400
        value["glb"].update(errors=[], sha256="a" * 64)
        value["reimport"].update(geometry_mismatches={}, unexpected_parts=[])
        views = ["front", "three_quarter", "side", "back"]
        value["previews"] = dict(fidelity_source="exported_reimported_glb", fidelity_sha256="a" * 64,
                                 fidelity_views=[f"{v}.png" for v in views], beauty_views=[f"beauty_{v}.png" for v in views], view_names=views)
        for part in value["components"].values():
            part.update(finite_vertices=True, finite_uvs=True, materials=1, islands=1, non_positive_islands=0, duplicate_faces=0)
        self.assertEqual(publish.gate(value), [])
        for field, change in (
            ("reimport", {"geometry_mismatches": {"eyes": ["UVs changed"]}}),
            ("glb", {"errors": ["missing normal map"]}),
            ("previews", {"fidelity_sha256": "b" * 64}),
            ("constraints", {"BubbleBean_Eyes": {"expected_islands": 2}}),
            ("constraints", {"BubbleBean_Eyes": {"max_surface_error": 0.01}}),
        ):
            broken = copy.deepcopy(value)
            broken.setdefault(field, {}).update(change)
            self.assertTrue(publish.gate(broken), field)
        partial = report(schema_version=2)
        self.assertTrue(publish.gate(partial))

    def test_clean_report_passes(self):
        self.assertEqual(publish.gate(report()), [])

    def test_hyphenated_figure_ids_pass(self):
        self.assertEqual(publish.gate(report(catalog="concept.verity-true-form")), [])

    def test_malformed_catalog_ids_block_publishing(self):
        for bad in ("concept", "concept.", "Concept.verity", "concept.-x", "concept.x-", "concept.x--y", "concept.x y"):
            self.assertTrue(publish.gate(report(catalog=bad)), bad)

    def test_each_defect_blocks_publishing(self):
        cases = []
        broken = report()
        broken["components"]["BubbleBean_Eyes"]["boundary_edges"] = 3
        cases.append(broken)
        heavy = report()
        heavy["components"]["BubbleBean_BubbleCap"]["tris"] = 20_000
        cases.append(heavy)
        cases.append(report(reimport={"meshes": 1, "triangle_mismatches": {}}))
        cases.append(report(glb={"all_materials_textured": False, "extensions_required": [], "extensions_used": []}))
        cases.append(report(glb={"all_materials_textured": True, "extensions_required": [], "extensions_used": ["KHR_x"]}))
        cases.append(report(catalog=None))
        cases.append(report(face="BubbleBean_Nose"))
        for case in cases:
            self.assertTrue(publish.gate(case), case)


class WiringTests(unittest.TestCase):
    def test_blender_build_errors_stop_and_use_python_failure_status(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(publish, "ROOT", Path(folder)), patch.dict(os.environ, {"FIG_BUILD_JOBS": "1"}):
            with patch.object(publish.subprocess, "run", return_value=SimpleNamespace(returncode=1)) as run:
                with self.assertRaises(publish.PublishError):
                    publish.build("technical-fixture", ["swatch"])
                command = run.call_args.args[0]
                self.assertIn("--python-exit-code", command)
                self.assertEqual(command[command.index("--python-exit-code") + 1], "1")

    def test_manifest_entry_uses_collection_key_and_all_nodes(self):
        entry = publish.manifest_entry("tidepool-tales", "bubble-bean", report())
        self.assertEqual(entry["key"], "Models.TidepoolTales.BubbleBean")
        self.assertEqual(entry["displayName"], "Tidepool Tales - Bubble Bean")
        self.assertEqual(entry["source"], "assets/figures/tidepool-tales/bubble-bean/model/bubble_bean_roblox.glb")
        self.assertEqual(entry["requiredNodes"], ["BubbleBean", "BubbleBean_Eyes", "BubbleBean_BubbleCap"])

    def test_manifest_upsert_is_idempotent_and_keeps_order(self):
        manifest = {"creator": {"userId": "1"}, "assets": {"first": {"key": "A.B"}}}
        entry = publish.manifest_entry("tidepool-tales", "bubble-bean", report())
        self.assertTrue(publish.upsert_manifest(manifest, {"bubble_bean": entry}))
        snapshot = copy.deepcopy(manifest)
        self.assertFalse(publish.upsert_manifest(manifest, {"bubble_bean": entry}))
        self.assertEqual(manifest, snapshot)
        self.assertEqual(list(manifest["assets"]), ["first", "bubble_bean"])

    def test_luau_entries_swap_to_roblox_axes(self):
        text = publish.luau_entries([("Models.TidepoolTales.BubbleBean", report())])
        self.assertTrue(text.startswith("--!strict\r\n"))
        self.assertIn('["tide.bubble"] = {', text)
        self.assertIn("size = Vector3.new(2.2, 3.1, 1.7),", text)  # width, height, depth
        self.assertIn('glass = { "BubbleBean_BubbleCap" },', text)
        self.assertIn("parts = 2,", text)
        plain = publish.luau_entries([("K.A", report(glass=[]))])
        self.assertIn("glass = {},", plain)


if __name__ == "__main__":
    unittest.main()
