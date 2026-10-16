"""Texture repair safety tests; no Blender, network, assets or credentials."""
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/figures"))
from test_external_figures import glb
from glb import read_document
from texture_prepare import prepare, repair, import_manifest


class TextureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.incoming = self.root / "incoming"
        self.incoming.mkdir()
        self.output = self.root / "output"
        self.source = self.incoming / "figure.glb"
        glb(self.source)

    def row(self, recipes=None):
        return prepare(self.incoming, self.output, recipes)["figures"][0]

    def test_preserves_textured_source_bytes_and_does_not_infer_likeness(self):
        before = self.source.read_bytes()
        row = self.row()
        self.assertEqual(row["status"], "ready_for_import_review")
        self.assertEqual(Path(row["prepared"]).read_bytes(), before)
        self.assertEqual(self.source.read_bytes(), before)
        self.assertEqual(row["reference_likeness"], "NOT RUN")
        self.assertEqual(self.row()["prepared"], row["prepared"])

    def test_reconnects_only_explicit_map_and_preserves_geometry(self):
        glb(self.source, lambda d, b: d["materials"][0].pop("pbrMetallicRoughness"))
        original, doc, binary = read_document(self.source)
        self.assertEqual(self.row()["status"], "manual_review")
        row = self.row({"figure.glb": {"materials": {"0": {"albedo": {"texture": 0}}}}})
        self.assertEqual(row["status"], "ready_for_import_review")
        _, result, after = read_document(Path(row["prepared"]))
        self.assertEqual(result["meshes"], doc["meshes"])
        self.assertEqual(result["accessors"], doc["accessors"])
        self.assertEqual(after, binary)
        self.assertEqual(self.source.read_bytes(), original)

    def test_embeds_authored_maps_with_hash_and_preserves_factors(self):
        _, doc, binary = read_document(self.source)
        view = doc["bufferViews"][doc["images"][0]["bufferView"]]
        image = binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]]
        (self.incoming / "authored.png").write_bytes(image)
        doc["materials"][0]["pbrMetallicRoughness"]["baseColorFactor"] = [.5, .6, .7, 1]
        result, new_binary, dependencies = repair(doc, binary, {"materials": {"0": {"albedo": "authored.png"}}}, self.incoming)
        self.assertIn("authored.png", dependencies)
        self.assertEqual(result["materials"][0]["pbrMetallicRoughness"]["baseColorFactor"], [.5, .6, .7, 1])
        self.assertEqual(new_binary[:len(binary)], binary)
        self.assertEqual(result["meshes"], doc["meshes"])
        self.assertEqual(len(doc["images"]), 1)

    def test_reference_is_not_silently_used_as_uv_texture(self):
        (self.incoming / "figure_reference.png").write_bytes(b"reference-only")
        glb(self.source, lambda d, b: d["materials"][0].clear())
        row = self.row()
        self.assertIn("reference", row)
        self.assertEqual(row["status"], "manual_review")
        self.assertNotIn("prepared", row)

    def test_ambiguous_references_require_selection(self):
        for name in ("figure.png", "figure_sheet.jpg"):
            (self.incoming / name).write_bytes(b"reference")
        self.assertIn("ambiguous", self.row()["error"])
        self.assertIn("reference", self.row({"figure.glb": {"reference": "figure.png"}}))

    def test_path_escape_and_unknown_recipe_fail(self):
        row = self.row({"figure.glb": {"materials": {"0": {"albedo": "../secret.png"}}}})
        self.assertIn("escapes", row["error"])
        with self.assertRaises(ValueError):
            prepare(self.incoming, self.output, {"unknown.glb": {}})
        with self.assertRaises(ValueError):
            prepare(self.incoming, self.incoming / "generated")

    def test_invalid_reconnect_and_missing_uv_require_review(self):
        self.assertEqual(self.row({"figure.glb": {"materials": {"0": {"albedo": {"texture": -1}}}}})["status"], "manual_review")
        glb(self.source, lambda d, b: d["meshes"][0]["primitives"][0]["attributes"].pop("TEXCOORD_0"))
        self.assertIn("UV0", self.row()["error"])

    def test_failed_reprocessing_does_not_report_stale_success(self):
        self.row()
        self.source.write_bytes(b"broken")
        row = self.row()
        self.assertEqual(row["status"], "manual_review")
        self.assertNotIn("prepared", row)

    def test_changed_texture_creates_distinct_output(self):
        _, doc, binary = read_document(self.source)
        view = doc["bufferViews"][doc["images"][0]["bufferView"]]
        path = self.incoming / "map.png"
        path.write_bytes(binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]])
        recipe = {"figure.glb": {"materials": {"0": {"albedo": "map.png"}}}}
        first = self.row(recipe)
        path.write_bytes(path.read_bytes() + b"changed")
        self.assertNotEqual(first["prepared"], self.row(recipe)["prepared"])

    def test_batch_mapping_preserves_identity_and_rejects_partial_results(self):
        batch = {"figures": [{"source": "figure.glb", "figure_id": "tide.bubble"}]}
        row = self.row()
        mapped = import_manifest(batch, [row], self.output)
        self.assertEqual(mapped["figures"][0]["figure_id"], "tide.bubble")
        self.assertEqual(batch["figures"][0]["source"], "figure.glb")
        self.assertTrue((self.output / "prepared" / mapped["figures"][0]["source"]).is_file())
        with self.assertRaises(ValueError):
            import_manifest(batch, [], self.output)
        row["status"] = "manual_review"
        with self.assertRaises(ValueError):
            import_manifest(batch, [row], self.output)


if __name__ == "__main__":
    unittest.main()
