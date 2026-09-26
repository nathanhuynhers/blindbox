"""Offline upload tests. Never reads the repository .env or contacts Roblox."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch, Mock
import urllib.error
import zlib

SPEC = importlib.util.spec_from_file_location("upload_assets", Path(__file__).resolve().parents[1] / "scripts/upload_assets.py")
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)


def png(width=1, height=1):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\xff\x00\x00\x00")) + chunk(b"IEND", b""))


def glb(nodes=("BlindBox_Root", "BoxBody")):
    document = json.dumps({"asset": {"version": "2.0"},
                           "nodes": [{"name": name} for name in nodes]},
                          separators=(",", ":")).encode()
    document += b" " * (-len(document) % 4)
    chunk = struct.pack("<II", len(document), 0x4E4F534A) + document
    return struct.pack("<4sII", b"glTF", 2, 12 + len(chunk)) + chunk


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / "assets").mkdir()
        self.path = self.root / "assets/test_image.png"
        self.path.write_bytes(png())
        self.entry = {"key": "Collection.BookOpen", "source": "assets/test_image.png"}
        (self.root / "assets/uploads.json").write_text("{}", encoding="utf-8")
        self.creator = {"userId": "123"}
        self.item = pipeline.prepare(self.root, self.entry)
        self.cloud = Mock()
        self.cloud.create.return_value = {"path": "operations/test-123"}
        self.cloud.poll.return_value = "456"

    def upload(self, replace=False):
        with contextlib.redirect_stdout(io.StringIO()):
            pipeline.upload(self.root, [self.item], self.creator, self.cloud, replace, 1)

    def test_png_transparency_bytes_untouched(self):
        data, mime, width, height = pipeline.image_info(self.path)
        self.assertEqual((data, mime, width, height), (png(), "image/png", 1, 1))

    def test_png_corruption_empty_and_limits(self):
        for data in (b"", b"bad", png()[:-1], png(8000), png(0), png()[:40] + b"broken" + png()[46:]):
            with self.subTest(size=len(data)):
                self.path.write_bytes(data)
                with self.assertRaises(pipeline.PipelineError):
                    pipeline.image_info(self.path)

    def test_jpeg_dimension_header_and_truncation(self):
        path = self.path.with_suffix(".jpg")
        # Header-only fixture exercises parsing, not complete JPEG decoding.
        data = b"\xff\xd8\xff\xc0\x00\x0b\x08\x00\x10\x00\x20\x01\x01\x11\x00\xff\xd9"
        path.write_bytes(data)
        self.assertEqual(pipeline.image_info(path)[1:], ("image/jpeg", 32, 16))
        path.write_bytes(data[:-2])
        with self.assertRaises(pipeline.PipelineError):
            pipeline.image_info(path)

    def test_glb_model_semantic_nodes_and_corruption(self):
        path = self.root / "assets/blind_box_base.glb"
        path.write_bytes(glb())
        entry = {"key": "Models.BlindBoxBase", "source": "assets/blind_box_base.glb",
                 "assetType": "Model", "requiredNodes": ["BlindBox_Root", "BoxBody"]}
        item = pipeline.prepare(self.root, entry)
        self.assertEqual(item["mime"], "model/gltf-binary")
        self.assertEqual(item["assetType"], "Model")
        self.assertEqual(item["nodes"], ["BlindBox_Root", "BoxBody"])
        with self.assertRaisesRegex(pipeline.PipelineError, "missing required semantic nodes"):
            pipeline.prepare(self.root, {**entry, "requiredNodes": ["FrontPatternPanel"]})
        for invalid in (b"", b"not glb", glb()[:-1]):
            path.write_bytes(invalid)
            with self.assertRaises(pipeline.PipelineError):
                pipeline.prepare(self.root, entry)

    def test_reject_escaping_path_invalid_name_key_and_type(self):
        for change in ({"source": "../secret.png"}, {"source": "assets/Bad Name.png"},
                       {"key": 'Collection.Bad"Injection'}, {"assetType": "Model"}):
            with self.subTest(change=change), self.assertRaises(pipeline.PipelineError):
                pipeline.prepare(self.root, {**self.entry, **change})

    def test_upload_records_and_generates_then_skips_duplicate(self):
        self.upload()
        record = pipeline.read_json(self.root / "assets/uploads.json")[self.item['key']]
        self.assertEqual(record['assetId'], "456")
        self.assertEqual(record['source'], "assets/test_image.png")
        self.assertIn('["Collection.BookOpen"] = "456"', (self.root / "src/shared/AssetIds.luau").read_text())
        self.upload()
        self.cloud.create.assert_called_once()

    def test_renaming_identical_source_does_not_reupload(self):
        self.upload()
        self.item['source'] = "assets/renamed.png"
        self.upload()
        self.cloud.create.assert_called_once()
        self.assertEqual(pipeline.read_json(self.root / "assets/uploads.json")[self.item['key']]['source'], "assets/renamed.png")

    def test_replacement_requires_flag_preserves_old_until_success(self):
        self.upload()
        self.item['sha256'] = "changed"
        with self.assertRaises(pipeline.PipelineError):
            self.upload()
        self.cloud.poll.side_effect = pipeline.PipelineError("timeout")
        with self.assertRaises(pipeline.PipelineError):
            self.upload(replace=True)
        self.assertEqual(pipeline.read_json(self.root / "assets/uploads.json")[self.item['key']]['assetId'], "456")
        self.cloud.poll.side_effect = None
        self.cloud.poll.return_value = "789"
        self.upload(replace=True)
        self.assertEqual(self.cloud.create.call_count, 2)
        self.assertEqual(pipeline.read_json(self.root / "assets/uploads.json")[self.item['key']]['assetId'], "789")

    def test_timeout_resume_does_not_repeat_post(self):
        self.cloud.poll.side_effect = pipeline.PipelineError("timeout")
        with self.assertRaises(pipeline.PipelineError):
            self.upload()
        self.cloud.poll.side_effect = None
        self.upload()
        self.cloud.create.assert_called_once()

    def test_unknown_post_outcome_blocks_retry(self):
        self.cloud.create.side_effect = pipeline.PipelineError("connection dropped")
        with self.assertRaises(pipeline.PipelineError):
            self.upload()
        self.cloud.create.side_effect = None
        with self.assertRaisesRegex(pipeline.PipelineError, "outcome is unknown"):
            self.upload()
        self.cloud.create.assert_called_once()

    def test_journal_keeps_only_allowlisted_response_fields(self):
        self.cloud.create.return_value = {"path": "operations/abc", "debug": "synthetic-secret-echo"}
        self.cloud.poll.side_effect = pipeline.PipelineError("timeout")
        with self.assertRaises(pipeline.PipelineError):
            self.upload()
        journal = (self.root / "build/assets/pending.json").read_text(encoding="utf-8")
        self.assertNotIn("synthetic-secret-echo", journal)
        self.assertEqual(json.loads(journal)[self.item['key']]['operation'], {"path": "operations/abc"})

    def test_connection_exception_does_not_echo_partial_response(self):
        cloud = pipeline.Cloud("synthetic-test-credential")
        cloud.opener.open = Mock(side_effect=pipeline.http.client.IncompleteRead(b"synthetic-test-credential"))
        with self.assertRaises(pipeline.PipelineError) as caught:
            cloud.request("GET", "operations/abc")
        self.assertNotIn("synthetic-test-credential", str(caught.exception))

    def test_changed_pending_input_blocks_resume(self):
        self.cloud.poll.side_effect = pipeline.PipelineError("timeout")
        with self.assertRaises(pipeline.PipelineError):
            self.upload()
        self.item['sha256'] = "different"
        with self.assertRaisesRegex(pipeline.PipelineError, "different source/owner"):
            self.upload(replace=True)

    def test_cloud_poll_success_failure_timeout_and_url_allowlist(self):
        cloud = pipeline.Cloud("synthetic-test-credential")
        cloud.request = Mock(return_value={"done": True, "response": {"assetId": "12345"}})
        with patch.object(pipeline.time, "sleep"):
            self.assertEqual(cloud.poll({"path": "operations/abc"}, 1), "12345")
        for operation in ({"error": {"message": "sensitive"}}, {"status": {"code": 3}},
                          {"done": True, "response": {}}, {"path": "https://evil.test"}):
            with self.assertRaises(pipeline.PipelineError):
                cloud.poll(operation, 0)
        with self.assertRaisesRegex(pipeline.PipelineError, "timed out"):
            cloud.poll({"path": "operations/abc"}, 0)
        with self.assertRaises(pipeline.PipelineError):
            pipeline.Cloud("synthetic").request("GET", "https://evil.test")

    def test_http_error_does_not_expose_headers_or_response(self):
        cloud = pipeline.Cloud("synthetic-test-credential")
        cloud.opener.open = Mock(side_effect=urllib.error.HTTPError(
            "https://example.test", 403, "synthetic-test-credential", {}, io.BytesIO(b"synthetic-test-credential")))
        with self.assertRaises(pipeline.PipelineError) as caught:
            cloud.request("POST", "assets", b"payload")
        self.assertNotIn("synthetic-test-credential", str(caught.exception))
        self.assertIn("403", str(caught.exception))
        self.assertIsNone(pipeline.NoRedirect().redirect_request(None, None, 302, "", {}, "https://evil.test"))

    def test_structured_api_error_preserves_reason_but_redacts_key(self):
        cloud = pipeline.Cloud("synthetic-test-credential")
        payload = {"errors": [{"code": "PERMISSION_DENIED", "message": "Denied synthetic-test-credential"}],
                   "headers": {"x-api-key": "synthetic-test-credential"}}
        cloud.opener.open = Mock(side_effect=urllib.error.HTTPError(
            "https://example.test", 403, "", {}, io.BytesIO(json.dumps(payload).encode())))
        with self.assertRaises(pipeline.PipelineError) as caught:
            cloud.request("POST", "assets", b"payload")
        self.assertEqual(str(caught.exception), "Roblox HTTP 403. PERMISSION_DENIED: Denied [redacted]")
        with self.assertRaisesRegex(pipeline.PipelineError, "PERMISSION_DENIED"):
            cloud.poll({"error": {"code": "PERMISSION_DENIED", "message": "Denied"}}, 1)

    def test_multipart_uses_image_type_creator_and_original_bytes(self):
        cloud = pipeline.Cloud("synthetic-test-credential")
        cloud.request = Mock(return_value={"path": "operations/abc"})
        cloud.create(self.item, {"groupId": "123"})
        method, endpoint, body, content_type = cloud.request.call_args.args
        self.assertEqual((method, endpoint), ("POST", "assets"))
        self.assertIn(b'"assetType": "Image"', body)
        self.assertIn(b'"groupId": "123"', body)
        self.assertIn(png(), body)
        self.assertNotIn(b"synthetic-test-credential", body)
        self.assertTrue(content_type.startswith("multipart/form-data; boundary="))

    def test_multipart_uses_model_type_and_glb_content_type(self):
        path = self.root / "assets/blind_box_base.glb"
        path.write_bytes(glb())
        item = pipeline.prepare(self.root, {"key": "Models.BlindBoxBase",
            "source": "assets/blind_box_base.glb", "assetType": "Model"})
        cloud = pipeline.Cloud("synthetic-test-credential")
        cloud.request = Mock(return_value={"path": "operations/abc"})
        cloud.create(item, self.creator)
        body = cloud.request.call_args.args[2]
        self.assertIn(b'"assetType": "Model"', body)
        self.assertIn(b"Content-Type: model/gltf-binary", body)
        self.assertIn(glb(), body)

    def test_env_precedence_and_ignore_guard_only_with_synthetic_key(self):
        (self.root / ".env").write_text('ROBLOX_API_KEY="synthetic-file-key"\n', encoding="utf-8")
        good = [subprocess.CompletedProcess([], 0, b"", b""), subprocess.CompletedProcess([], 0, b".env.example\n", b"")]
        with patch.object(pipeline.subprocess, "run", side_effect=good), patch.dict(os.environ, {}, clear=True):
            self.assertEqual(pipeline.load_api_key(self.root), "synthetic-file-key")
        with patch.object(pipeline.subprocess, "run", side_effect=good), patch.dict(os.environ, {"ROBLOX_API_KEY": "synthetic-shell-key"}):
            self.assertEqual(pipeline.load_api_key(self.root), "synthetic-shell-key")
        bad = [subprocess.CompletedProcess([], 1, b"", b""), subprocess.CompletedProcess([], 0, b".env\n", b"")]
        with patch.object(pipeline.subprocess, "run", side_effect=bad):
            with self.assertRaisesRegex(pipeline.PipelineError, "Refusing credentials"):
                pipeline.load_api_key(self.root)

    def test_dry_run_never_loads_credentials_or_network(self):
        pipeline.write_json(self.root / "assets/manifest.json", {"creator": None, "assets": {"test": self.entry}})
        with patch.object(pipeline, "ROOT", self.root), patch.object(pipeline, "load_api_key") as key, patch.object(pipeline, "Cloud") as cloud:
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(pipeline.main(["test", "--dry-run"]), 0)
            key.assert_not_called()
            cloud.assert_not_called()

    def test_lock_and_bad_generated_mapping(self):
        with pipeline.exclusive(self.root):
            with self.assertRaises(pipeline.PipelineError):
                with pipeline.exclusive(self.root):
                    pass
        self.assertFalse((self.root / "build/assets/upload.lock").exists())
        with self.assertRaises(pipeline.PipelineError):
            pipeline.generate(self.root, {"Collection.Bad": {"assetId": "not-an-id"}})


if __name__ == "__main__":
    unittest.main()
