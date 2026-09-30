"""Offline tests for tools/figures/publish.py. Never uploads or runs Blender."""
import copy
import importlib.util
from pathlib import Path
import unittest

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
    def test_clean_report_passes(self):
        self.assertEqual(publish.gate(report()), [])

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
