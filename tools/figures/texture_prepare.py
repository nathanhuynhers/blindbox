"""Inventory and explicitly repair GLB textures before the existing external importer.

No AI inference, geometry changes, credentials, uploads or runtime mapping changes.
Python standard library only. See docs/FIGURE_TEXTURING.md.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import html
import json
from pathlib import Path
import struct
import sys

from external_glb import inspect, image_dimensions, SOURCE_MAX_BYTES
from glb import read_document


def sha(data):
    return hashlib.sha256(data).hexdigest()


def local(base, relative):
    if not isinstance(relative, str) or Path(relative).is_absolute():
        raise ValueError("expected relative input path")
    result = (base / relative).resolve()
    if not result.is_relative_to(base.resolve()):
        raise ValueError("input path escapes incoming directory")
    return result


def write_glb(doc, binary):
    payload = json.dumps(doc, separators=(",", ":"), allow_nan=False).encode()
    payload += b" " * (-len(payload) % 4)
    binary += b"\0" * (-len(binary) % 4)
    return (struct.pack("<4sII", b"glTF", 2, 28 + len(payload) + len(binary))
            + struct.pack("<II", len(payload), 0x4E4F534A) + payload
            + struct.pack("<II", len(binary), 0x004E4942) + binary)


def inventory(doc):
    """Descriptive inventory; never guesses anatomy from mesh names."""
    accessors = doc.get("accessors", [])
    meshes = []
    for index, mesh in enumerate(doc.get("meshes", [])):
        primitives = []
        for p in mesh.get("primitives", []):
            attrs = p.get("attributes", {})
            count = accessors[p["indices"]]["count"] if "indices" in p else accessors[attrs["POSITION"]]["count"]
            primitives.append({"material": p.get("material"), "attributes": sorted(attrs),
                               "triangles": count // 3 if p.get("mode", 4) == 4 else None,
                               "uv0": "TEXCOORD_0" in attrs, "vertex_colors": "COLOR_0" in attrs})
        meshes.append({"index": index, "name": mesh.get("name"), "primitives": primitives})
    return {"nodes": doc.get("nodes", []), "meshes": meshes,
            "materials": doc.get("materials", []), "images": doc.get("images", []),
            "textures": doc.get("textures", []), "extensions": doc.get("extensionsUsed", [])}


def references(source, incoming, recipe):
    if "reference" in recipe:
        candidates = [local(incoming, recipe["reference"])]
    else:
        candidates = [source.with_name(source.stem + suffix + ext)
                      for suffix in ("", "_reference", "_sheet")
                      for ext in (".png", ".jpg", ".jpeg", ".webp")]
        candidates = [p for p in candidates if p.is_file()]
    if len(candidates) > 1:
        raise ValueError("ambiguous reference images; specify reference in recipe")
    return candidates[0] if candidates else None


def repair(doc, binary, recipe, incoming):
    """Only named material indices and original UV0 maps may be repaired."""
    doc = copy.deepcopy(doc)
    dependencies = {}
    if set(recipe) - {"reference", "materials"}:
        raise ValueError("unknown recipe field")
    if not isinstance(recipe.get("materials", {}), dict):
        raise ValueError("materials must map existing material indices to map options")
    for index, maps in recipe.get("materials", {}).items():
        if not isinstance(index, str) or not index.isdigit() or int(index) >= len(doc.get("materials", [])):
            raise ValueError("material keys must be existing zero-based indices")
        if not isinstance(maps, dict) or not maps or set(maps) - {"albedo", "normal", "metallic_roughness", "occlusion"}:
            raise ValueError("supported maps: albedo, normal, metallic_roughness, occlusion")
        material = doc["materials"][int(index)]
        for channel, value in maps.items():
            if isinstance(value, dict) and set(value) == {"texture"}:
                texture_index = value["texture"]
                if type(texture_index) is not int or not 0 <= texture_index < len(doc.get("textures", [])):
                    raise ValueError("reconnect texture index does not exist")
            elif isinstance(value, str):
                path = local(incoming, value)
                if path.stat().st_size > 64_000_000:
                    raise ValueError("texture exceeds 64 MB input limit")
                image = path.read_bytes()
                width, height = image_dimensions(image)
                if not 0 < width <= 4096 or not 0 < height <= 4096:
                    raise ValueError("map exceeds 4096px; prepare a reviewed resize first")
                mime = "image/png" if image.startswith(b"\x89PNG") else "image/jpeg"
                dependencies[value] = sha(image)
                binary += b"\0" * (-len(binary) % 4)
                view = len(doc.setdefault("bufferViews", []))
                doc["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(image)})
                binary += image
                image_index = len(doc.setdefault("images", []))
                doc["images"].append({"name": path.name, "bufferView": view, "mimeType": mime})
                texture_index = len(doc.setdefault("textures", []))
                doc["textures"].append({"source": image_index})
            else:
                raise ValueError("map must be a UV-aligned PNG/JPEG path or {texture: index}")
            slot = {"index": texture_index, "texCoord": 0}
            if channel in ("albedo", "metallic_roughness"):
                key = "baseColorTexture" if channel == "albedo" else "metallicRoughnessTexture"
                pbr = material.setdefault("pbrMetallicRoughness", {})
                # Preserve authored factors, normal scale and occlusion strength.
                pbr[key] = {**pbr.get(key, {}), **slot}
            else:
                key = channel + "Texture"
                material[key] = {**material.get(key, {}), **slot}
    if recipe.get("materials"):
        if len(doc.get("buffers", [])) != 1 or doc["buffers"][0].get("uri"):
            raise ValueError("repairs require one embedded buffer")
        doc["buffers"][0]["byteLength"] = len(binary)
    return doc, binary, dependencies


def prepare(incoming, output, recipes=None):
    incoming, output = incoming.resolve(), output.resolve()
    if output == incoming or output.is_relative_to(incoming) or incoming.is_relative_to(output):
        raise ValueError("output and incoming directories must be separate")
    if not incoming.is_dir():
        raise ValueError("incoming directory is missing")
    recipes = recipes if recipes is not None else {}
    if not isinstance(recipes, dict):
        raise ValueError("recipe must map relative GLB paths to options")
    sources = sorted(p for p in incoming.rglob("*") if p.is_file() and p.suffix.lower() == ".glb")
    names = {p.relative_to(incoming).as_posix() for p in sources}
    if set(recipes) - names:
        raise ValueError("recipe contains an unknown GLB path")
    output.mkdir(parents=True, exist_ok=True)
    rows = []
    for source in sources:
        name = source.relative_to(incoming).as_posix()
        row = {"source": name, "status": "manual_review", "warnings": [], "studio": "NOT RUN",
               "reference_likeness": "NOT RUN"}
        rows.append(row)
        try:
            if source.stat().st_size > SOURCE_MAX_BYTES:
                raise ValueError("source exceeds 512 MB")
            data, doc, binary = read_document(source)
            row.update(source_sha256=sha(data), inventory=inventory(doc))
            recipe = recipes.get(name, {})
            if not isinstance(recipe, dict):
                raise ValueError("each GLB recipe must be an object")
            reference = references(source, incoming, recipe)
            if reference:
                row["reference"] = {"path": str(reference), "sha256": sha(reference.read_bytes())}
            else:
                row["warnings"].append("No matching reference; visual likeness cannot be reviewed.")
            repaired, binary, dependencies = repair(doc, binary, recipe, incoming)
            payload = write_glb(repaired, binary) if recipe.get("materials") else data
            # Immutable content-addressed output prevents stale successes after an input failure.
            target = output / "prepared" / sha(payload) / source.name
            target.parent.mkdir(parents=True, exist_ok=True)
            temp = target.with_suffix(".tmp")
            temp.write_bytes(payload)
            try:
                stats = inspect(temp)
            finally:
                temp.unlink(missing_ok=True)
            if not target.exists():
                target.write_bytes(payload)
            elif sha(target.read_bytes()) != sha(payload):
                raise ValueError("prepared output changed on disk")
            row.update(status="ready_for_import_review", prepared=str(target),
                       prepared_sha256=sha(payload), dependencies=dependencies, inspection=stats,
                       action="explicit_texture_repair" if recipe.get("materials") else "preserved")
            row["warnings"].append("Texture connectivity passed; gray pixels, seams and reference accuracy need visual review.")
        except (OSError, ValueError, KeyError, IndexError, TypeError, struct.error) as error:
            row["error"] = str(error)
            row["warnings"].append("Supply authored UV-aligned maps or a textured Tripo export; reference art is not a UV atlas.")
    report = {"schema_version": 1, "figures": rows,
              "errors": [] if sources else ["No GLB inputs found"],
              "release": "No uploads or game configuration changes performed."}
    (output / "textures.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    cards = []
    for row in rows:
        reference_image = ('<img style="max-width:480px;max-height:600px" alt="Reference image" src="'
                           + html.escape(Path(row["reference"]["path"]).as_uri(), quote=True) + '">' if "reference" in row else "")
        cards.append("<article><h2>" + html.escape(row["source"]) + "</h2>" + reference_image + "<pre>"
                     + html.escape(json.dumps(row, indent=2)) + "</pre></article>")
    (output / "textures.html").write_text('<!doctype html><meta charset="utf-8"><title>Texture preflight</title>'
        '<style>body{font:16px system-ui;max-width:1100px;margin:32px auto}pre{white-space:pre-wrap;overflow-wrap:anywhere}</style>'
        '<h1>Texture preflight</h1><p>Technical inspection only. Blender/reference and Roblox visual acceptance pending.</p>'
        + "".join(cards), encoding="utf-8")
    return report


def import_manifest(batch, rows, output):
    """Reuse existing identities; never infer a catalog mapping from a filename."""
    mapped = {entry["source"] for entry in batch["figures"]}
    if len(mapped) != len(batch["figures"]) or mapped != {r["source"] for r in rows}:
        raise ValueError("batch manifest must map every input GLB exactly once")
    if any(row["status"] != "ready_for_import_review" for row in rows):
        raise ValueError("manual-review inputs block the prepared batch manifest")
    prepared = {r["source"]: Path(r["prepared"]).relative_to(output.resolve() / "prepared").as_posix() for r in rows}
    result = copy.deepcopy(batch)
    for entry in result["figures"]:
        entry["source"] = prepared[entry["source"]]
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("incoming", type=Path)
    parser.add_argument("--output", type=Path, default=Path("build/figures/textures"))
    parser.add_argument("--recipe", type=Path)
    parser.add_argument("--manifest", type=Path, help="Existing external batch identities; emit a remapped batch on success")
    args = parser.parse_args(argv)
    try:
        generated = args.output / "prepared-batch.json"
        generated.unlink(missing_ok=True)
        recipes = json.loads(args.recipe.read_text(encoding="utf-8")) if args.recipe else None
        result = prepare(args.incoming, args.output, recipes)
        if args.manifest:
            from external import load_batch, ImportError as BatchError
            try:
                batch, entries, errors = load_batch(args.manifest.resolve(), args.incoming.resolve())
                if errors:
                    raise ValueError("; ".join(errors))
                remapped = import_manifest(batch, result["figures"], args.output)
                generated.write_text(json.dumps(remapped, indent=2) + "\n", encoding="utf-8")
            except BatchError as error:
                raise ValueError(str(error)) from None
        for row in result["figures"]:
            print(f"{row['status']}: {row['source']}" + (f": {row['error']}" if "error" in row else ""))
        print(f"Report: {args.output.resolve() / 'textures.html'}")
        return int(bool(result["errors"]) or any(r["status"] == "manual_review" for r in result["figures"]))
    except (OSError, ValueError, TypeError) as error:
        print(f"Texture preparation stopped: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
