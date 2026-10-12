"""Offline core-glTF inspection. Shared by Blender and tests; standard library only."""
import hashlib
import json
import struct


def read_document(path):
    with open(path, "rb") as fh:
        data = fh.read()
    if len(data) < 20 or struct.unpack_from("<4sII", data) != (b"glTF", 2, len(data)):
        raise ValueError("invalid GLB header/length")
    size, kind = struct.unpack_from("<II", data, 12)
    if kind != 0x4E4F534A or size % 4 or 20 + size > len(data):
        raise ValueError("invalid GLB JSON chunk")
    doc = json.loads(data[20:20 + size])
    binary = b""
    if len(data) > 20 + size:
        n, kind = struct.unpack_from("<II", data, 20 + size)
        if kind != 0x004E4942 or n % 4 or 28 + size + n != len(data):
            raise ValueError("invalid GLB binary chunk")
        binary = data[28 + size:]
    return data, doc, binary


def inspect_document(doc, binary):
    errors = []
    views = doc.get("bufferViews", [])
    images = doc.get("images", [])
    textures = doc.get("textures", [])

    def embedded(texture):
        try:
            image = images[textures[texture["index"]]["source"]]
            view = views[image["bufferView"]]
            start, size = view.get("byteOffset", 0), view["byteLength"]
            return (view.get("buffer", 0) == 0 and not image.get("uri") and
                    image.get("mimeType") in ("image/png", "image/jpeg") and
                    0 <= start < start + size <= len(binary))
        except (KeyError, IndexError, TypeError):
            return False

    for mat in doc.get("materials", []):
        name = mat.get("name", "material")
        pbr = mat.get("pbrMetallicRoughness", {})
        if not embedded(pbr.get("baseColorTexture", {})):
            errors.append(f"{name}: missing embedded albedo")
        for slot in (pbr.get("metallicRoughnessTexture"), mat.get("normalTexture")):
            if slot is not None and not embedded(slot):
                errors.append(f"{name}: missing embedded PBR map")
        for slot in (pbr.get("baseColorTexture"), pbr.get("metallicRoughnessTexture"), mat.get("normalTexture")):
            if slot and slot.get("texCoord", 0) != 0:
                errors.append(f"{name}: only UV0 is supported by this pipeline")
        if mat.get("alphaMode", "OPAQUE") not in ("OPAQUE", "BLEND"):
            errors.append(f"{name}: unsupported alpha mode")
    accessors = doc.get("accessors", [])
    for mesh in doc.get("meshes", []):
        primitives = mesh.get("primitives", [])
        if len(primitives) != 1:
            errors.append(f"{mesh.get('name')}: expected one material primitive per MeshPart")
        for p in primitives:
            attrs = p.get("attributes", {})
            if p.get("mode", 4) != 4 or any(k not in attrs for k in ("POSITION", "NORMAL", "TEXCOORD_0")):
                errors.append(f"{mesh.get('name')}: missing triangle/normal/UV data")
            if p.get("material") not in range(len(doc.get("materials", []))):
                errors.append(f"{mesh.get('name')}: missing material")
            if p.get("targets") or any(k.startswith("JOINTS") for k in attrs):
                errors.append(f"{mesh.get('name')}: collectible must be static")
            try:
                triangles = accessors[p["indices"]]["count"] // 3
                if not 0 < triangles < 20000:
                    errors.append(f"{mesh.get('name')}: invalid triangle budget")
            except (KeyError, IndexError):
                errors.append(f"{mesh.get('name')}: missing indices")
    if any(b.get("uri") for b in doc.get("buffers", [])):
        errors.append("external buffer")
    if doc.get("extensionsUsed") or doc.get("extensionsRequired"):
        errors.append("unsupported glTF extensions")
    return errors


def summary(path):
    data, doc, binary = read_document(path)
    mats = doc.get("materials", [])
    return dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                nodes=[n.get("name") for n in doc.get("nodes", [])],
                meshes=len(doc.get("meshes", [])), materials=len(mats),
                images=len(doc.get("images", [])), textures=len(doc.get("textures", [])),
                all_materials_textured=bool(mats) and all("baseColorTexture" in m.get("pbrMetallicRoughness", {}) for m in mats),
                extensions_required=doc.get("extensionsRequired", []), extensions_used=doc.get("extensionsUsed", []),
                errors=inspect_document(doc, binary),
                pbr_materials=[m.get("name") for m in mats if "metallicRoughnessTexture" in m.get("pbrMetallicRoughness", {}) or "normalTexture" in m])
