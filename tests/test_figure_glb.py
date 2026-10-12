"""Portable GLB contract checks, without Blender or network access."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/figures"))
from glb import inspect_document


def document():
    return dict(bufferViews=[dict(buffer=0, byteOffset=0, byteLength=8)],
                images=[dict(bufferView=0, mimeType="image/png")], textures=[dict(source=0)],
                materials=[dict(name="Paint", pbrMetallicRoughness=dict(baseColorTexture=dict(index=0)))],
                accessors=[dict(count=30)], meshes=[dict(name="Part", primitives=[dict(indices=0, material=0,
                    attributes=dict(POSITION=0, NORMAL=0, TEXCOORD_0=0))])])


class GLBTests(unittest.TestCase):
    def test_core_embedded_pbr_is_accepted(self):
        d = document()
        d["materials"][0]["pbrMetallicRoughness"]["metallicRoughnessTexture"] = dict(index=0)
        d["materials"][0]["normalTexture"] = dict(index=0)
        self.assertEqual(inspect_document(d, b"12345678"), [])

    def test_unsupported_and_missing_export_data_fail(self):
        cases = []
        for defect in ("uv", "normals", "image", "pbr", "budget", "extensions", "external", "split", "alpha"):
            d = document()
            p = d["meshes"][0]["primitives"][0]
            if defect == "uv":
                del p["attributes"]["TEXCOORD_0"]
            elif defect == "normals":
                del p["attributes"]["NORMAL"]
            elif defect == "image":
                d["images"][0] = dict(uri="missing.png")
            elif defect == "pbr":
                d["materials"][0]["normalTexture"] = dict(index=4)
            elif defect == "budget":
                d["accessors"][0]["count"] = 60000
            elif defect == "extensions":
                d["extensionsUsed"] = ["KHR_materials_transmission"]
            elif defect == "external":
                d["buffers"] = [dict(uri="missing.bin")]
            elif defect == "split":
                d["meshes"][0]["primitives"].append(copy.deepcopy(p))
            elif defect == "alpha":
                d["materials"][0]["alphaMode"] = "MASK"
            cases.append((defect, d))
        for label, d in cases:
            self.assertTrue(inspect_document(d, b"12345678"), label)


if __name__ == "__main__":
    unittest.main()
