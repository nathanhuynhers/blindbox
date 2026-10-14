"""Batch external/Tripo GLB import. Python 3.10+, stdlib + installed Blender.

python tools/figures/external.py incoming --manifest batch.json [--dry-run | --validate-only]
python tools/figures/external.py --publish build/figures/external/batch/plan.json --approve-plan SHA256
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import html
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import quote

import publish
from external_glb import inspect, MAX_TRIS

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
NAME = re.compile(r"[A-Z][A-Za-z0-9]*")
VIEWS = ["front", "three_quarter", "side", "back"]


class ImportError(Exception):
    pass


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        value = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
        return value.hexdigest()


def canonical(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    temp.replace(path)


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def inside(base: Path, relative: str) -> Path:
    path = (base / relative).resolve()
    if not path.is_relative_to(base.resolve()):
        raise ImportError(f"path escapes its directory: {relative}")
    return path


def catalog(path: Path) -> dict:
    """Read only literal catalog records; fail closed on an unsupported layout."""
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    text = re.sub(r"--[^\n]*", "", text)
    figures = text.split("local figures:", 1)[1].split("local byId:", 1)[0].split("=", 1)[1]
    result = {}
    for block in re.findall(r"\{([^{}]*)\}", figures):
        fields = dict(re.findall(r'\b(id|name|collection|rarity)\s*=\s*"([^"\n]+)"', block))
        if fields.keys() != {"id", "name", "collection", "rarity"} or fields["id"] in result:
            raise ImportError("catalog literal parser needs updating; no identities inferred")
        result[fields["id"]] = fields
    if not result:
        raise ImportError("no catalog records")
    return result


def positive(value, name, maximum):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not 0 < value <= maximum:
        raise ImportError(f"{name} must be finite and between 0 and {maximum}")


def load_batch(file: Path, incoming: Path, root: Path = ROOT) -> tuple[dict, list[dict], list[str]]:
    batch = read_json(file)
    if batch.get("schema_version") != 1 or not SLUG.fullmatch(str(batch.get("batch_id", ""))):
        raise ImportError("manifest needs schema_version 1 and a kebab-case batch_id")
    records = batch.get("figures")
    if not isinstance(records, list) or not records:
        raise ImportError("manifest needs a nonempty figures list")
    known = catalog(root / "src/shared/Catalog.luau")
    assets = read_json(root / "assets/manifest.json")["assets"]
    runtime = (root / "src/shared/FigureAssetEntries.luau").read_text(encoding="utf-8")
    seen = {key: set() for key in ("source", "figure_id", "asset_key", "alias", "destination")}
    errors, valid = [], []
    for original in records:
        try:
            entry = dict(original)
            source = entry.get("source")
            if not isinstance(source, str) or "\\" in source or Path(source).is_absolute() or '..' in Path(source).parts or Path(source).suffix.lower() != ".glb":
                raise ImportError("source must be a relative GLB filename/path")
            source_path = inside(incoming, source)
            figure = known.get(entry.get("figure_id"))
            if not figure:
                raise ImportError("unmatched catalog figure_id; add no catalog entries automatically")
            if entry.get("collection_id") != figure["collection"] or entry.get("rarity") != figure["rarity"]:
                raise ImportError("collection_id/rarity does not match catalog")
            for key in ("collection_slug", "figure_slug"):
                if not SLUG.fullmatch(str(entry.get(key, ""))):
                    raise ImportError(f"invalid {key}")
            if not NAME.fullmatch(str(entry.get("root", ""))) or not re.fullmatch(r"[a-z0-9]+(?:_[a-z0-9]+)*", str(entry.get("alias", ""))):
                raise ImportError("invalid root or alias")
            if not re.fullmatch(r"Models\.[A-Z][A-Za-z0-9]*\.[A-Z][A-Za-z0-9]*", str(entry.get("asset_key", ""))):
                raise ImportError("invalid dotted model asset_key")
            # Existing catalog mappings may not silently get a second runtime identity.
            match = re.search(r'\["' + re.escape(entry["figure_id"]) + r'"\]\s*=\s*\{\s*key\s*=\s*"([^"]+)"', runtime)
            if match and match[1] != entry["asset_key"]:
                raise ImportError("asset_key differs from current runtime identity")
            old = assets.get(entry["alias"])
            if old and old["key"] != entry["asset_key"]:
                raise ImportError("alias belongs to another asset")
            if any(alias != entry["alias"] and item.get("key") == entry["asset_key"] for alias, item in assets.items()):
                raise ImportError("asset_key belongs to another alias")
            destination = f"{entry['collection_slug']}/{entry['figure_slug']}"
            for key in seen:
                value = destination if key == "destination" else entry[key]
                if value.casefold() in seen[key]:
                    raise ImportError(f"duplicate {key}: {value}")
                seen[key].add(value.casefold())
            positive(entry.get("height_studs"), "height_studs", 8)
            rotation = entry.get("rotation_degrees", [0, 0, 0])
            if len(rotation) != 3 or any(isinstance(n, bool) or not isinstance(n, (int, float)) or not math.isfinite(n) or abs(n) > 360 for n in rotation):
                raise ImportError("rotation_degrees needs three finite Euler angles in Blender axes")
            entry["rotation_degrees"] = rotation
            eyes = entry.get("eyes", {})
            if not isinstance(eyes.get("object"), str) or not eyes["object"]:
                raise ImportError("eyes.object must explicitly name a source mesh")
            if "region" in eyes:
                region = eyes["region"]
                if len(region) != 2 or any(len(v) != 3 for v in region) or any(not isinstance(n, (int, float)) or not math.isfinite(n) for v in region for n in v) or any(not 0 <= region[0][i] < region[1][i] <= 1 for i in range(3)):
                    raise ImportError("eyes.region needs normalized min/max XYZ after orientation")
            entry.setdefault("max_parts", 64)
            if type(entry["max_parts"]) is not int or not 2 <= entry["max_parts"] <= 256:
                raise ImportError("max_parts must be an integer from 2 to 256")
            entry.setdefault("texture_limit", 4096)
            if entry["texture_limit"] not in (512, 1024, 2048, 4096):
                raise ImportError("texture_limit must be 512, 1024, 2048 or 4096")
            if type(entry.get("resize_textures", False)) is not bool:
                raise ImportError("resize_textures must be boolean")
            entry.setdefault("protected_objects", [])
            if not isinstance(entry["protected_objects"], list) or any(not isinstance(s, str) for s in entry["protected_objects"]):
                raise ImportError("protected_objects must list exact source object names")
            for name, policy in entry.get("optimization", {}).items():
                if not isinstance(name, str) or not isinstance(policy, dict):
                    raise ImportError("optimization maps exact object names to policies")
                if type(policy.get("target_triangles")) is not int or policy["target_triangles"] < 4:
                    raise ImportError("optimization target_triangles must be an integer >= 4")
                positive(policy.get("max_surface_error"), "max_surface_error", .05)
                if type(policy.get("bake_normals", False)) is not bool:
                    raise ImportError("bake_normals must be boolean")
                if policy.get('bake_resolution', min(2048, entry['texture_limit'])) not in (128, 256, 512, 1024, 2048) or policy.get('bake_resolution', 128) > entry['texture_limit']:
                    raise ImportError('bake_resolution must be 128..2048 and fit texture_limit')
            entry["title"] = figure["name"]
            if type(entry.get('technical_fixture', False)) is not bool:
                raise ImportError('technical_fixture must be boolean')
            if not source_path.is_file():
                raise ImportError("source GLB is missing")
            valid.append(entry)
        except (ImportError, KeyError, TypeError, ValueError) as error:
            errors.append(f"{original.get('source', '?') if isinstance(original, dict) else '?'}: {error}")
    mapped = {e.get("source", "").casefold() for e in records if isinstance(e, dict)}
    for source in sorted(incoming.rglob("*")):
        if source.is_file() and source.suffix.lower() == ".glb" and source.relative_to(incoming).as_posix().casefold() not in mapped:
            errors.append(f"unmatched file: {source.relative_to(incoming).as_posix()}")
    return batch, sorted(valid, key=lambda e: e["source"]), errors


def fingerprint(source: Path, entry: dict, *, resolution: int, samples: int, blender_sha256: str = "", source_sha256: str | None = None) -> str:
    # Include implementations of reused geometry/render/bake helpers in cache identity.
    tooling = {p.name: digest(p) for p in HERE.glob("*.py")}
    return hashlib.sha256(canonical({"source": source_sha256 or digest(source), "entry": entry, "blender": blender_sha256,
                                    "tooling": tooling, "resolution": resolution, "samples": samples})).hexdigest()


def gate(report: dict, entry: dict) -> list[str]:
    errors = list(report.get("errors", []))
    if report.get("schema_version") != 3 or report.get("pipeline") != "external_glb":
        errors.append("unsupported external report")
    for field, value in (("catalog", entry["figure_id"]), ("root", entry["root"]), ("face", entry["root"] + "_Eyes")):
        if report.get(field) != value:
            errors.append(f"report {field} differs from manifest")
    parts = report.get("components", {})
    if not parts or report.get("meshes") != len(parts) or len(parts) > entry["max_parts"] or report.get("face") not in parts:
        errors.append("invalid MeshPart totals or missing eyes")
    if report.get("triangles") != sum(p.get("tris", 0) for p in parts.values()):
        errors.append("triangle totals differ")
    for name, part in parts.items():
        if type(part.get("tris")) is not int or not 0 < part["tris"] <= MAX_TRIS:
            errors.append(f"{name}: invalid triangle count")
        if not part.get("finite_vertices") or not part.get("finite_uvs") or part.get("materials") != 1:
            errors.append(f"{name}: invalid vertices/UVs/materials")
        if part.get("zero_area_faces") or part.get("duplicate_faces") or part.get("uv_zero_area_faces") or part.get("branch_edges"):
            errors.append(f"{name}: degenerate/duplicate geometry or UVs, or branching topology")
    size = report.get("size_xyz_studs", [])
    if len(size) != 3 or any(not isinstance(x, (int, float)) or not math.isfinite(x) or x <= 0 or x > 12 for x in size):
        errors.append("invalid figure bounds")
    elif abs(size[2] - entry["height_studs"]) > 2e-4:
        errors.append("height differs from requested size")
    if not report.get("facing_valid") or not report.get("grounded"):
        errors.append("eyes/front/grounding contract failed")
    g = report.get("glb", {})
    if not g.get("all_materials_textured") or g.get("errors", ["missing"]) or g.get("extensions_used") or not 0 < g.get("bytes", 0) <= 20_000_000:
        errors.append("production GLB/material inspection failed")
    ri = report.get("reimport", {})
    if ri.get("meshes") != len(parts) or ri.get("geometry_mismatches", {"missing": True}) or ri.get("triangle_mismatches", {"missing": True}) or ri.get("unexpected_parts", ["missing"]):
        errors.append("export/reimport changed geometry, UVs or normals")
    previews = report.get("previews", {})
    if previews.get("fidelity_sha256") != g.get("sha256") or previews.get("fidelity_source") != "exported_reimported_glb" or previews.get("view_names") != VIEWS:
        errors.append("previews not bound to production GLB")
    for kind in ("source_views", "fidelity_views"):
        images = previews.get(kind, [])
        if len(images) != 4 or len(set(images)) != 4 or any(not isinstance(p, str) or Path(p).name != p or not p.endswith('.png') for p in images):
            errors.append("all four source/fidelity previews required")
    comparison = report.get("visual_comparison", {})
    def comparison_passes(value):
        iou, mae = value.get('silhouette_iou'), value.get('foreground_rgb_mae')
        return (value.get('pass') is True and isinstance(iou, (int, float)) and math.isfinite(iou) and .97 <= iou <= 1
                and isinstance(mae, (int, float)) and math.isfinite(mae) and 0 <= mae <= .05)
    if set(comparison) != set(VIEWS) or any(not comparison_passes(v) for v in comparison.values()):
        errors.append("substantial source/export visual loss or missing comparison")
    if report.get('material_mismatches', ['missing material comparison']):
        errors.append('source/export material information changed')
    if not entry.get('optimization') and report.get('source_triangles') != report.get('triangles'):
        errors.append('lossless partition dropped source triangles')
    for name, info in report.get('optimization', {}).items():
        policy = entry.get('optimization', {}).get(name)
        if info.get('mode') == 'explicit_decimation' and (not policy or not math.isfinite(info.get('surface_error', float('inf'))) or info['surface_error'] > policy['max_surface_error']):
            errors.append(f'{name}: optimization exceeds reviewed quality policy')
    return errors


def verify(folder: Path, entry: dict, expected_fingerprint: str | None = None) -> dict:
    slug = publish.snake(entry["figure_slug"])
    report = read_json(folder / "validation" / f"{slug}_validation.json")
    if expected_fingerprint and report.get("fingerprint") != expected_fingerprint:
        raise ImportError("conversion inputs changed")
    errors = gate(report, entry)
    for relative, sha in report.get("artifacts", {}).items():
        path = inside(folder, relative)
        if not path.is_file() or digest(path) != sha:
            errors.append(f"missing/changed artifact: {relative}")
    required = [f"model/{slug}_roblox.glb", "source/original.glb"]
    required += [f"renders/{p}" for kind in ("source_views", "fidelity_views") for p in report.get("previews", {}).get(kind, [])]
    if any(relative not in report.get("artifacts", {}) for relative in required):
        errors.append("incomplete artifact hashes")
    if errors:
        raise ImportError("; ".join(errors))
    g = inspect(folder / "model" / f"{slug}_roblox.glb", production=True, texture_limit=entry["texture_limit"])
    if g["sha256"] != report["glb"]["sha256"]:
        raise ImportError("GLB hash differs from report")
    return report


@contextmanager
def batch_lock(folder: Path):
    folder.mkdir(parents=True, exist_ok=True)
    lock = folder / "batch.lock"
    try:
        handle = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        raise ImportError("batch.lock exists; close other converters, remove only if stale") from None
    try:
        os.close(handle)
        yield
    finally:
        lock.unlink(missing_ok=True)


def uploader():
    spec = importlib.util.spec_from_file_location("external_asset_upload", ROOT / "scripts/upload_assets.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@contextmanager
def upload_boundary(api):
    """Convert the existing uploader's safe errors, including lock/creator failures."""
    try:
        with api.exclusive(ROOT):
            yield
    except api.PipelineError as error:
        raise ImportError(str(error)) from None


def proposal(rows: list[dict], root: Path = ROOT) -> dict:
    manifest = read_json(root / "assets/manifest.json")
    uploads = read_json(root / "assets/uploads.json")
    records = []
    for row in rows:
        e, report = row["entry"], row["report"]
        folder = Path(row["folder"])
        identity = root / "assets/figures/external" / e["collection_slug"] / e["figure_slug"] / report["fingerprint"]
        model = identity / "model" / f"{publish.snake(e['figure_slug'])}_roblox.glb"
        item = {"key": e["asset_key"], "source": model.relative_to(root).as_posix(),
                "displayName": f"{publish.collection_title(e['collection_slug'])} - {e['title']}",
                "assetType": "Model", "requiredNodes": [report["root"], *report["components"]]}
        if len(item["displayName"]) > 50:
            item["displayName"] = e["title"][:50]
        records.append({"entry": e, "staging": folder.relative_to(root).as_posix(),
                        "destination": identity.relative_to(root).as_posix(), "manifest_entry": item,
                        "report_sha256": digest(folder / "validation" / f"{publish.snake(e['figure_slug'])}_validation.json"),
                        "glb_sha256": report["glb"]["sha256"],
                        "previous_manifest_entry": manifest["assets"].get(e["alias"]),
                        "previous_upload": uploads.get(e["asset_key"]),
                        "action": "replace" if e["asset_key"] in uploads else "create"})
    return {"schema_version": 1, "kind": "external_figure_review", "creator": manifest["creator"],
            "technical_fixture": any(row['entry'].get('technical_fixture') for row in rows),
            "catalog_sha256": digest(root / "src/shared/Catalog.luau"), "figures": records,
            "review": "Review source/fidelity views, face extraction, texture seams and every replacement. Approval uploads assets and changes local mappings; never deploys a place."}


def report_html(rows: list[dict], errors: list[str], folder: Path, plan_sha: str | None) -> None:
    escape = html.escape
    lines = ['<!doctype html><meta charset="utf-8"><title>Tripo batch review</title>',
             '<style>body{font:16px system-ui;background:#171c25;color:#edf1f7;margin:24px}article{background:#242d3b;padding:20px;margin:20px 0}table{width:100%}img{width:100%;max-width:240px}td{width:25%;vertical-align:top}pre{white-space:pre-wrap}a{color:#8ed1ff}</style>',
             '<h1>External figure batch review</h1><p>Blender comparisons; Roblox visual/runtime acceptance pending.</p>',
             f'<p>Approval digest: <code>{escape(plan_sha or "BLOCKED")}</code></p>',
             '<pre>' + escape('\n'.join(errors)) + '</pre>']
    if any(row['entry'].get('technical_fixture') for row in rows):
        lines.append('<p><strong>OFFLINE TECHNICAL FIXTURE: production upload is disabled.</strong></p>')
    for row in rows:
        e = row["entry"]
        r = row.get("report", {})
        lines += [f'<article><h2>{escape(e["title"])} · {escape(e["figure_id"])} · {escape(e["rarity"])}</h2>',
                  f'<p>{escape(row["status"])} · source {r.get("source_triangles", "?")} → {r.get("triangles", "?")} triangles · {r.get("meshes", "?")} MeshParts</p>',
                  '<pre>' + escape(row.get('error', '')) + '</pre>']
        if r:
            publication = row.get('publication', {})
            previous_id = publication.get('previous_upload', {}).get('assetId', 'none') if publication.get('previous_upload') else 'none'
            lines += [f'<p>Asset: {escape(e["asset_key"])} · alias {escape(e["alias"])} · action {escape(publication.get("action", "blocked"))} · previous ID {escape(str(previous_id))}</p>',
                      f'<p>GLB SHA256: <code>{escape(r["glb"]["sha256"])}</code></p>']
            lines.append('<table><tr>' + ''.join(f'<th>{v}</th>' for v in VIEWS) + '</tr>')
            for kind in ('source_views', 'fidelity_views'):
                lines.append('<tr>')
                for image in r['previews'][kind]:
                    link = os.path.relpath(Path(row['folder']) / 'renders' / image, folder).replace('\\', '/')
                    lines.append(f'<td>{kind}<br><a href="{escape(quote(link))}"><img src="{escape(quote(link))}" alt="{escape(image)}"></a></td>')
                lines.append('</tr>')
            lines += ['</table>', '<pre>' + escape(json.dumps(r.get('visual_comparison', {}), indent=2)) + '</pre>',
                      '<pre>' + escape('\n'.join(f"{n}: {p['tris']} tris" for n, p in r['components'].items())) + '</pre>']
        lines.append('</article>')
    (folder / 'report.html').write_text('\n'.join(lines), encoding='utf-8')


def publish_plan(file: Path, approval: str | None, dry_run: bool) -> None:
    plan = read_json(file)
    sha = hashlib.sha256(canonical(plan)).hexdigest()
    if not dry_run and approval != sha:
        raise ImportError(f"review {file} and report.html; --approve-plan must equal {sha}")
    if plan.get("kind") != "external_figure_review" or plan.get("schema_version") != 1 or not plan.get("figures"):
        raise ImportError("not an external batch review plan")
    if not dry_run and (plan.get('technical_fixture') or any(r['entry'].get('technical_fixture') for r in plan['figures'])):
        raise ImportError('technical fixture plans cannot be uploaded as production figures')
    api = uploader()
    with upload_boundary(api):
        manifest = read_json(ROOT / 'assets/manifest.json')
        uploads = read_json(ROOT / 'assets/uploads.json')
        if manifest['creator'] != plan['creator'] or digest(ROOT / 'src/shared/Catalog.luau') != plan['catalog_sha256']:
            raise ImportError("creator/catalog changed; regenerate review plan")
        creator = api.creator_value(plan['creator'])
        staging = []
        for record in plan['figures']:
            e, item = record['entry'], record['manifest_entry']
            current = manifest['assets'].get(e['alias'])
            old = uploads.get(item['key'])
            completed = old and old.get('sha256') == record['glb_sha256'] and old.get('source') == item['source'] and old.get('creator') == creator
            if current not in (record['previous_manifest_entry'], item) or (old != record['previous_upload'] and not completed):
                raise ImportError("production mapping changed; regenerate review plan")
            folder = inside(ROOT, record['staging'])
            validation = folder / 'validation' / f"{publish.snake(e['figure_slug'])}_validation.json"
            if digest(validation) != record['report_sha256']:
                raise ImportError("reviewed report changed")
            report = verify(folder, e)
            if report['glb']['sha256'] != record['glb_sha256']:
                raise ImportError("reviewed GLB changed")
            destination = inside(ROOT, record['destination'])
            if not destination.is_relative_to((ROOT / 'assets/figures/external').resolve()):
                raise ImportError("external destination required")
            expected_source = (destination / 'model' / f"{publish.snake(e['figure_slug'])}_roblox.glb").relative_to(ROOT).as_posix()
            if item['source'] != expected_source or item['key'] != e['asset_key'] or item['requiredNodes'] != [report['root'], *report['components']]:
                raise ImportError("proposal identities differ")
            if destination.exists():
                verify(destination, e, report['fingerprint'])
                if digest(destination / 'validation' / validation.name) != record['report_sha256']:
                    raise ImportError("immutable destination differs")
            # Validate uploader inputs from staging without promoting on dry runs.
            check_entry = dict(item, source=(folder / 'model' / f"{publish.snake(e['figure_slug'])}_roblox.glb").relative_to(ROOT).as_posix())
            # prepare requires assets/: model_info + field checks here; prepare again after promotion.
            api.model_info(ROOT / check_entry['source'], item['requiredNodes'])
            if not api.KEY.fullmatch(item['key']) or not 1 <= len(item['displayName']) <= 50:
                raise ImportError("invalid upload identity/display name")
            staging.append((record, folder, destination))
        if dry_run:
            print(f"Valid reviewed proposal {sha}; {len(staging)} figures; no credentials/network/mapping changes")
            return
        # Repository checks before irreversible uploads. No --no-checks release escape hatch.
        for name in ('rokit', 'wally'):
            executable = publish.TOOLS / f'{name}.exe'
            publish.run([str(executable) if executable.exists() else name, 'install'], f'{name} pinned provisioning')
        publish.checks()
        publish.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_external_figures.py'], 'External pipeline tests')
        for record, folder, destination in staging:
            if not destination.exists():
                destination.parent.mkdir(parents=True, exist_ok=True)
                temp = destination.with_name(destination.name + '.promoting')
                if temp.exists():
                    raise ImportError("incomplete promotion exists; inspect/remove it before retrying")
                temp.mkdir()
                report = verify(folder, record['entry'])
                files = [*report['artifacts'], f"validation/{publish.snake(record['entry']['figure_slug'])}_validation.json"]
                for relative in files:
                    target = inside(temp, relative)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(inside(folder, relative), target)
                verify(temp, record['entry'], report['fingerprint'])
                temp.replace(destination)
            manifest['assets'][record['entry']['alias']] = record['manifest_entry']
        items = [api.prepare(ROOT, r['manifest_entry']) for r, _, _ in staging]
        if any(item['sha256'] != record['glb_sha256'] for item, (record, _, _) in zip(items, staging)):
            raise ImportError('promoted GLB differs from reviewed proposal')
        api.write_json(ROOT / 'assets/manifest.json', manifest)
        try:
            # Reuse the existing credential boundary, transport, upload journal and ID generation.
            api.upload(ROOT, items, creator, api.Cloud(api.load_api_key(ROOT)), replace=True, timeout=600)
        except api.PipelineError as error:
            raise ImportError(str(error)) from None
        finally:
            # Partial uploads must not bind old uploaded IDs to newly staged reports.
            mapping = read_json(ROOT / 'assets/uploads.json')
            compatible = json.loads(json.dumps(manifest))
            for record, _, _ in staging:
                key, alias = record['manifest_entry']['key'], record['entry']['alias']
                if mapping.get(key, {}).get('sha256') != record['glb_sha256']:
                    previous = record['previous_manifest_entry']
                    if previous is None:
                        compatible['assets'].pop(alias, None)
                    else:
                        compatible['assets'][alias] = previous
            api.write_json(ROOT / 'assets/manifest.json', compatible)
            text = publish.luau_entries(publish.uploaded_reports(compatible, mapping))
            api.atomic_write(ROOT / 'src/shared/FigureAssetEntries.luau', text)
        publish.checks()
        print('Asset batch uploaded and local runtime mappings generated. No live place deployed; Studio acceptance pending.')


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('incoming', nargs='?', type=Path)
    parser.add_argument('--manifest', type=Path)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--validate-only', action='store_true', help='Validate existing conversions; never run Blender')
    parser.add_argument('--publish', type=Path, help='Upload a previously reviewed plan')
    parser.add_argument('--approve-plan', help='Exact digest printed in the contact sheet, after human review')
    parser.add_argument('--blender', default=str(publish.BLENDER))
    parser.add_argument('--resolution', type=int, default=1000)
    parser.add_argument('--samples', type=int, default=32)
    args = parser.parse_args(argv)
    try:
        if args.publish:
            if args.incoming or args.manifest or args.validate_only:
                raise ImportError('--publish is a separate command')
            publish_plan(args.publish.resolve(), args.approve_plan, args.dry_run)
            return 0
        if args.approve_plan or not args.incoming or not args.manifest or not args.incoming.is_dir():
            raise ImportError('provide an existing incoming directory and --manifest')
        if args.dry_run and args.validate_only:
            raise ImportError('choose --dry-run or --validate-only')
        if not 64 <= args.resolution <= 2048 or not 1 <= args.samples <= 256:
            raise ImportError('resolution 64..2048 and samples 1..256 required')
        incoming = args.incoming.resolve()
        batch, entries, errors = load_batch(args.manifest.resolve(), incoming)
        folder = ROOT / 'build/figures/external' / batch['batch_id']
        rows = []
        if args.dry_run:
            for e in entries:
                try:
                    stats = inspect(inside(incoming, e['source']), texture_limit=16384 if e.get('resize_textures') else e['texture_limit'])
                    print(f"Matched {e['source']} -> {e['figure_id']} ({e['rarity']}) -> {e['asset_key']}: {stats['triangles']} source triangles")
                    print('  source meshes: ' + ', '.join(stats['mesh_nodes']))
                except (ValueError, KeyError, IndexError, TypeError) as error:
                    errors.append(f"{e['source']}: {error}")
            for error in errors:
                print(error, file=sys.stderr)
            return int(bool(errors))
        blender_path = Path(args.blender) if Path(args.blender).is_file() else Path(shutil.which(args.blender) or args.blender)
        if not blender_path.is_file():
            raise ImportError('installed Blender required to bind conversion toolchain, including --validate-only')
        blender_sha = digest(blender_path)
        with batch_lock(folder):
            # Old proposals can never survive a newly failed/changed batch.
            (folder / 'plan.json').unlink(missing_ok=True)
            for e in entries:
                row = {'entry': e, 'status': 'failed'}
                rows.append(row)
                try:
                    source = inside(incoming, e['source'])
                    inspect(source, texture_limit=16384 if e.get('resize_textures') else e['texture_limit'])
                    source_sha = digest(source)
                    fp = fingerprint(source, e, resolution=args.resolution, samples=args.samples, blender_sha256=blender_sha, source_sha256=source_sha)
                    output = folder / 'figures' / e['figure_slug'] / fp
                    row['folder'] = str(output)
                    try:
                        report = verify(output, e, fp)
                        row.update(status='unchanged', report=report)
                    except (OSError, ValueError, ImportError, KeyError, IndexError, TypeError):
                        if args.validate_only:
                            raise ImportError('no valid unchanged conversion; process the batch first')
                        output.mkdir(parents=True, exist_ok=True)
                        job = {'entry': e, 'source': str(source), 'source_sha256': source_sha, 'output': str(output), 'fingerprint': fp,
                               'resolution': args.resolution, 'samples': args.samples}
                        write_json(output / 'job.json', job)
                        command = [args.blender, '-b', '--factory-startup', '--python-exit-code', '1', '--python', str(HERE / 'import_blender.py'), '--', str(output / 'job.json')]
                        print(f"Converting {e['source']} -> {e['figure_id']}", flush=True)
                        with (output / 'blender.log').open('w', encoding='utf-8') as log:
                            code = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT).returncode
                        if code:
                            raise ImportError(f'Blender failed ({code}); see {output / "blender.log"}')
                        report = verify(output, e, fp)
                        row.update(status='converted', report=report)
                except (OSError, ValueError, ImportError, KeyError, IndexError, TypeError) as error:
                    row['error'] = str(error)
                    errors.append(f"{e['source']}: {error}")
                    # Show rejected conversions and their loss measurements when available.
                    if row.get('folder'):
                        report_file = Path(row['folder']) / 'validation' / f"{publish.snake(e['figure_slug'])}_validation.json"
                        if report_file.is_file():
                            row['report'] = read_json(report_file)
            plan_sha = None
            if not errors and rows:
                plan = proposal(rows)
                for row, record in zip(rows, plan['figures']):
                    row['publication'] = record
                write_json(folder / 'plan.json', plan)
                plan_sha = hashlib.sha256(canonical(plan)).hexdigest()
            write_json(folder / 'batch.json', {'rows': rows, 'errors': errors, 'plan_sha256': plan_sha})
            report_html(rows, errors, folder, plan_sha)
            print(f"Contact sheet: {folder / 'report.html'}")
            if plan_sha:
                print(f"Review plan: {folder / 'plan.json'}\nApproval SHA256: {plan_sha}")
            for error in errors:
                print(error, file=sys.stderr)
            return int(bool(errors))
    except (ImportError, OSError, ValueError, KeyError, IndexError, TypeError, publish.PublishError) as error:
        print(f'External import stopped: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
