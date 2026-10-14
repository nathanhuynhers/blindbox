"""Strict embedded static GLB checks for external imports (stdlib, no Blender)."""
from __future__ import annotations

import math
from pathlib import Path
import struct

from glb import read_document, summary

SOURCE_MAX_BYTES = 512_000_000
MAX_BYTES = 20_000_000
MAX_TRIS = 19_999  # Preserve the existing publisher's conservative boundary.


def image_dimensions(data: bytes) -> tuple[int, int]:
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        return struct.unpack_from(">II", data, 16)
    if data.startswith(b"\xff\xd8"):
        offset = 2
        while offset < len(data):
            if data[offset] != 255:
                raise ValueError("invalid JPEG marker")
            while offset < len(data) and data[offset] == 255:
                offset += 1
            marker = data[offset]
            offset += 1
            if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
                continue
            length = struct.unpack_from(">H", data, offset)[0]
            if length < 2 or offset + length > len(data):
                break
            if marker in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack_from(">HH", data, offset + 3)
                return w, h
            offset += length
    raise ValueError("texture must be a complete embedded PNG/JPEG")


def inspect(path: Path, *, production: bool = False, texture_limit: int = 4096) -> dict:
    if not 0 < path.stat().st_size <= (MAX_BYTES if production else SOURCE_MAX_BYTES):
        raise ValueError("GLB exceeds production 20 MB or source 512 MB limit")
    data, doc, binary = read_document(path)
    if doc.get("asset", {}).get("version") != "2.0":
        raise ValueError("expected glTF 2.0")
    if doc.get("extensionsUsed") or doc.get("extensionsRequired"):
        raise ValueError("unsupported glTF extensions; export an embedded core GLB")
    if doc.get("skins") or doc.get("animations") or any("skin" in n for n in doc.get("nodes", [])):
        raise ValueError("static collectibles cannot contain skins or animations")
    for node in doc.get("nodes", []):
        for key, length in (("translation", 3), ("rotation", 4), ("scale", 3), ("matrix", 16)):
            if key in node and (len(node[key]) != length or any(not isinstance(x, (int, float)) or not math.isfinite(x) for x in node[key])):
                raise ValueError("invalid node transform")
    buffers = doc.get("buffers", [])
    if len(buffers) != 1 or buffers[0].get("uri") or not 0 <= len(binary) - buffers[0]["byteLength"] <= 3:
        raise ValueError("GLB needs one complete embedded binary buffer")
    views = doc.get("bufferViews", [])
    for view in views:
        start, length = view.get("byteOffset", 0), view["byteLength"]
        if view.get("buffer", 0) != 0 or start < 0 or length <= 0 or start + length > buffers[0]["byteLength"]:
            raise ValueError("bufferView outside embedded buffer")
    formats = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
    widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    accessors = doc.get("accessors", [])

    def values(index):
        a = accessors[index]
        if "sparse" in a or a["componentType"] not in formats or a["type"] not in widths:
            raise ValueError("unsupported sparse/accessor format")
        fmt = "<" + formats[a["componentType"]] * widths[a["type"]]
        element = struct.calcsize(fmt)
        view = views[a["bufferView"]]
        stride, start = view.get("byteStride", element), a.get("byteOffset", 0)
        count = a["count"]
        if count <= 0 or start < 0 or stride < element or start + (count - 1) * stride + element > view["byteLength"]:
            raise ValueError("accessor outside bufferView")
        base = view.get("byteOffset", 0) + start
        for i in range(count):
            value = struct.unpack_from(fmt, binary, base + i * stride)
            if not all(math.isfinite(x) for x in value):
                raise ValueError("non-finite accessor data")
            yield value

    for i in range(len(accessors)):
        for _ in values(i):
            pass
    textures = []
    for image in doc.get("images", []):
        if "uri" in image or image.get("mimeType") not in ("image/png", "image/jpeg"):
            raise ValueError("external or unsupported texture")
        view = views[image["bufferView"]]
        start = view.get("byteOffset", 0)
        w, h = image_dimensions(binary[start:start + view["byteLength"]])
        if not 0 < w <= texture_limit or not 0 < h <= texture_limit:
            raise ValueError(f"texture {w}x{h} exceeds {texture_limit}px; explicitly opt into resizing")
        textures.append({"name": image.get("name", "image"), "width": w, "height": h})
    materials = doc.get("materials", [])
    for material in materials:
        slots = [material.get("pbrMetallicRoughness", {}).get(k) for k in ("baseColorTexture", "metallicRoughnessTexture")]
        slots += [material.get(k) for k in ("normalTexture", "occlusionTexture", "emissiveTexture")]
        if slots[0] is None:
            raise ValueError("every imported material needs its original embedded albedo")
        if material.get("alphaMode", "OPAQUE") not in ("OPAQUE", "BLEND"):
            raise ValueError("MASK alpha is unsupported by the existing figure contract")
        if material.get("emissiveTexture") or any(material.get("emissiveFactor", [0, 0, 0])):
            raise ValueError("emission requires an explicit material conversion; no silent loss")
        for slot in slots:
            if slot is not None:
                if slot.get("texCoord", 0) != 0:
                    raise ValueError("only UV0 is supported")
                texture = doc["textures"][slot["index"]]
                if texture.get("source") not in range(len(textures)):
                    raise ValueError("texture lacks embedded image")
    triangles = []
    for mesh in doc.get("meshes", []):
        if production and len(mesh.get("primitives", [])) != 1:
            raise ValueError("production MeshParts must have one material")
        for p in mesh.get("primitives", []):
            attrs = p.get("attributes", {})
            if p.get("mode", 4) != 4 or p.get("targets") or any(k.startswith(("JOINTS", "WEIGHTS", "TEXCOORD_1")) for k in attrs):
                raise ValueError("only static UV0 triangles are supported")
            if not {"POSITION", "NORMAL", "TEXCOORD_0"} <= attrs.keys():
                raise ValueError("geometry must include original normals and UV0")
            if p.get("material") not in range(len(materials)):
                raise ValueError("missing material")
            count = accessors[attrs["POSITION"]]["count"]
            for kind, width in (("POSITION", "VEC3"), ("NORMAL", "VEC3"), ("TEXCOORD_0", "VEC2")):
                if accessors[attrs[kind]]["type"] != width or accessors[attrs[kind]]["count"] != count:
                    raise ValueError("attribute count/type mismatch")
            indices = list(values(p["indices"]))
            if accessors[p["indices"]]["componentType"] not in (5121, 5123, 5125) or accessors[p["indices"]]["type"] != "SCALAR":
                raise ValueError("invalid index format")
            if len(indices) % 3 or any(not 0 <= v[0] < count for v in indices):
                raise ValueError("invalid triangle indices")
            n = len(indices) // 3
            if production and not 0 < n <= MAX_TRIS:
                raise ValueError(f"mesh exceeds {MAX_TRIS} triangles")
            uv = list(values(attrs["TEXCOORD_0"]))
            if production and any(not -1e-6 <= x <= 1 + 1e-6 for v in uv for x in v):
                raise ValueError("production UVs must be within 0..1")
            triangles.append(n)
    if not triangles:
        raise ValueError("no mesh triangles")
    names = [n.get("name") for n in doc.get("nodes", []) if "mesh" in n]
    if any(not n for n in names) or len(names) != len(set(names)):
        raise ValueError("mesh node names must be present and unique")
    result = {"bytes": len(data), "textures": textures, "primitive_triangles": triangles,
              "triangles": sum(triangles), "mesh_nodes": names}
    if production:
        result.update(summary(path))
        if result["errors"]:
            raise ValueError("; ".join(result["errors"]))
    return result


def material_signatures(path: Path) -> dict:
    """Portable appearance metadata, independent of texture/node index renumbering."""
    _, doc, binary = read_document(path)
    result = {}
    for material in doc.get('materials', []):
        pbr = material.get('pbrMetallicRoughness', {})
        maps = {}
        slots = {'albedo': pbr.get('baseColorTexture'), 'metallic_roughness': pbr.get('metallicRoughnessTexture'),
                 'normal': material.get('normalTexture'), 'occlusion': material.get('occlusionTexture')}
        for key, slot in slots.items():
            if slot is None:
                continue
            texture = doc['textures'][slot['index']]
            image = doc['images'][texture['source']]
            view = doc['bufferViews'][image['bufferView']]
            start = view.get('byteOffset', 0)
            dimensions = image_dimensions(binary[start:start + view['byteLength']])
            sampler = doc.get('samplers', [])[texture['sampler']] if 'sampler' in texture else {}
            maps[key] = {'dimensions': dimensions, 'texCoord': slot.get('texCoord', 0),
                         'wrapS': sampler.get('wrapS', 10497), 'wrapT': sampler.get('wrapT', 10497)}
        result[material.get('name', 'Material')] = {
            'baseColorFactor': pbr.get('baseColorFactor', [1, 1, 1, 1]),
            'metallicFactor': pbr.get('metallicFactor', 1), 'roughnessFactor': pbr.get('roughnessFactor', 1),
            'alphaMode': material.get('alphaMode', 'OPAQUE'), 'doubleSided': material.get('doubleSided', False),
            'normalScale': material.get('normalTexture', {}).get('scale', 1),
            'occlusionStrength': material.get('occlusionTexture', {}).get('strength', 1), 'maps': maps}
    return result
