"""Publish a figure collection to Roblox and wire it into the game in one command.

Python 3.10+, standard library only. See docs/FIGURE_COLLECTION_RUNBOOK.md.

  python tools/figures/publish.py <collection> [figure ...] [--build] [--no-checks]

Steps, stopping at the first failure:
  1. --build: run the Blender final build for each figure (in parallel).
  2. Gate every figure on its validation report (closed manifold parts, < 20k tris each,
     exact GLB re-import, embedded textures, no glTF extensions, catalog ID present).
  3. Add or refresh each figure's entry in assets/manifest.json.
  4. Upload through scripts/upload_assets.py (unchanged GLBs are skipped; changed ones replace).
  5. Regenerate src/shared/FigureAssetEntries.luau from every uploaded figure's report.
  6. Run the repository checks (StyLua, Selene, Luau suites, pipeline tests, Rojo build).
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
FIGURES = ROOT / "assets" / "figures"
MANIFEST = ROOT / "assets" / "manifest.json"
UPLOADS = ROOT / "assets" / "uploads.json"
ENTRIES = ROOT / "src" / "shared" / "FigureAssetEntries.luau"
BLENDER = Path(os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"))
TOOLS = Path.home() / ".rokit" / "bin"
MAX_TRIS = 20_000
CATALOG_ID = re.compile(r"[a-z][a-z0-9]*\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*")


class PublishError(Exception):
    pass


def snake(slug: str) -> str:
    return slug.replace("-", "_")


def pascal(slug: str) -> str:
    return "".join(part.capitalize() for part in slug.split("-"))


def report_path(collection: str, figure: str) -> Path:
    return FIGURES / collection / figure / "validation" / f"{snake(figure)}_validation.json"


def figures_in(collection: str) -> list[str]:
    folder = FIGURES / collection
    if not (folder / "figures.py").is_file():
        raise PublishError(f"No figures.py in assets/figures/{collection}.")
    return sorted(p.parent.parent.name for p in folder.glob("*/validation/*_validation.json"))


def gate(report: dict) -> list[str]:
    """Every reason this figure must not be published. Empty means it passes."""
    problems = []
    for name, part in report.get("components", {}).items():
        for field in ("non_manifold_edges", "boundary_edges", "zero_area_faces"):
            if part.get(field):
                problems.append(f"{name}: {part[field]} {field}")
        if part.get("signed_volume", 0) <= 0:
            problems.append(f"{name}: non-positive volume")
        if part.get("tris", MAX_TRIS) >= MAX_TRIS:
            problems.append(f"{name}: {part.get('tris')} triangles (limit {MAX_TRIS})")
    if not report.get("components"):
        problems.append("no components")
    reimport = report.get("reimport", {})
    if reimport.get("triangle_mismatches") or reimport.get("meshes") != report.get("meshes"):
        problems.append("GLB re-import does not match")
    glb = report.get("glb", {})
    if not glb.get("all_materials_textured"):
        problems.append("a material lacks an embedded albedo texture")
    if glb.get("extensions_required") or glb.get("extensions_used"):
        problems.append("GLB uses glTF extensions")
    if not CATALOG_ID.fullmatch(str(report.get("catalog", ""))):
        problems.append("missing catalog ID (pass catalog= to assemble in figures.py)")
    if report.get("face") not in report.get("components", {}):
        problems.append("missing <Figure>_Eyes part used for runtime facing")
    if report.get("schema_version", 1) >= 2:
        if report["schema_version"] != 2:
            problems.append("unsupported validation schema")
        if len(report.get("components", {})) != report.get("meshes") or sum(p.get("tris", 0) for p in report.get("components", {}).values()) != report.get("triangles"):
            problems.append("component totals do not match report")
        if report.get("glb", {}).get("errors", ["missing GLB inspection"]):
            problems.append("GLB inspection failed: " + str(report.get("glb", {}).get("errors")))
        if reimport.get("geometry_mismatches", {"missing": True}) or reimport.get("unexpected_parts", ["missing"]):
            problems.append("GLB geometry re-import changed")
        previews = report.get("previews", {})
        if previews.get("fidelity_source") != "exported_reimported_glb" or not previews.get("fidelity_views") or previews.get("fidelity_sha256") != glb.get("sha256"):
            problems.append("missing matching production fidelity preview")
        if set(previews.get("view_names", [])) != {"front", "three_quarter", "side", "back"} or len(previews.get("beauty_views", [])) != 4 or len(previews.get("fidelity_views", [])) != 4:
            problems.append("all four beauty and fidelity inspection views are required")
        for name, part in report.get("components", {}).items():
            if not all(isinstance(part.get(k), (int, float)) and math.isfinite(part[k]) for k in ("tris", "signed_volume")):
                problems.append(f"{name}: non-finite geometry statistics")
            if not part.get("finite_vertices") or not part.get("finite_uvs") or part.get("materials") != 1:
                problems.append(f"{name}: invalid vertices, UVs or material slots")
            if part.get("duplicate_faces") or part.get("non_positive_islands"):
                problems.append(f"{name}: duplicate faces or incorrectly oriented solid")
            constraints = report.get("constraints", {}).get(name, {})
            islands = constraints.get("expected_islands")
            if islands is not None and part.get("islands") != islands:
                problems.append(f"{name}: unexpected disconnected geometry")
            build_info = report.get("build", {}).get(name, {})
            limit = constraints.get("max_surface_error")
            if limit is not None and build_info.get("surface_error", float("inf")) > limit:
                problems.append(f"{name}: optimization exceeds surface error limit")
    return problems


def manifest_entry(collection: str, figure: str, report: dict) -> dict:
    return {
        "key": f"Models.{pascal(collection)}.{report['root']}",
        "source": f"assets/figures/{collection}/{figure}/model/{snake(figure)}_roblox.glb",
        "displayName": f"{collection_title(collection)} - {report['title']}",
        "assetType": "Model",
        "requiredNodes": [report["root"], *report["components"]],
    }


def collection_title(collection: str) -> str:
    return " ".join(part.capitalize() for part in collection.split("-"))


def upsert_manifest(manifest: dict, entries: dict[str, dict]) -> bool:
    """Insert or refresh aliases, keeping existing order; returns whether anything changed."""
    assets = manifest.setdefault("assets", {})
    changed = False
    for alias, entry in entries.items():
        if assets.get(alias) != entry:
            assets[alias] = entry
            changed = True
    return changed


def luau_entries(records: list[tuple[str, dict]]) -> str:
    lines = [
        "--!strict",
        "-- Generated by tools/figures/publish.py from figure validation reports. Do not edit.",
        "return {",
    ]
    for key, report in sorted(records, key=lambda item: item[1]["catalog"]):
        x, y, z = report["size_xyz_studs"]  # Blender: y is depth, z is height
        glass = ", ".join(f'"{name}"' for name in report.get("glass", []))
        lines += [
            f'\t["{report["catalog"]}"] = {{',
            f'\t\tkey = "{key}",',
            f'\t\troot = "{report["root"]}",',
            f'\t\tface = "{report["face"]}",',
            f'\t\tparts = {report["meshes"]},',
            f"\t\tsize = Vector3.new({x}, {z}, {y}),",
            f"\t\tglass = {{ {glass} }}," if glass else "\t\tglass = {},",
            "\t},",
        ]
    lines.append("}")
    return "\r\n".join(lines) + "\r\n"


def uploaded_reports(manifest: dict, uploads: dict) -> list[tuple[str, dict]]:
    """Every figure whose manifest key has a recorded Roblox asset, with its report."""
    records = []
    for entry in manifest.get("assets", {}).values():
        source = entry.get("source", "")
        key = entry.get("key", "")
        if entry.get("assetType") != "Model" or not source.startswith("assets/figures/") or key not in uploads:
            continue
        model = ROOT / source
        report_file = model.parent.parent / "validation" / model.name.replace("_roblox.glb", "_validation.json")
        if report_file.is_file():
            report = json.loads(report_file.read_text(encoding="utf-8"))
            if report.get("catalog"):
                records.append((key, report))
    return records


def run(command: list[str], label: str) -> None:
    print(f"-- {label}", flush=True)
    if subprocess.run(command, cwd=ROOT).returncode != 0:
        raise PublishError(f"{label} failed.")


def build(collection: str, figures: list[str]) -> None:
    print(f"-- Blender final build: {', '.join(figures)}", flush=True)
    logs = ROOT / "build" / "figures" / collection
    logs.mkdir(parents=True, exist_ok=True)
    workers = int(os.environ.get("FIG_BUILD_JOBS", "2"))
    if workers < 1:
        raise PublishError("FIG_BUILD_JOBS must be positive")

    def build_one(figure):
        command = [str(BLENDER), "-b", "--factory-startup", "--python-exit-code", "1", "--python",
                   str(ROOT / "tools" / "figures" / "build.py"), "--", collection, figure, "final"]
        with open(logs / f"{figure}_final.log", "w", encoding="utf-8") as log:
            return figure, subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT).returncode

    # High-detail voxel grids can consume hundreds of MB each; do not launch an
    # entire collection simultaneously. Each worker has its own Blender process.
    with ThreadPoolExecutor(max_workers=workers) as pool:
        failed = [figure for figure, code in pool.map(build_one, figures) if code != 0]
    if failed:
        raise PublishError(f"Blender build failed for {', '.join(failed)}; see build/figures/{collection}/.")


def checks() -> None:
    tool = lambda name: str(TOOLS / name) if (TOOLS / f"{name}.exe").exists() or (TOOLS / name).exists() else name
    run([tool("stylua"), "--check", "src"], "StyLua")
    run([tool("selene"), "src"], "Selene")
    run([sys.executable, "tests/run.py", str(ROOT / "build" / "tools" / "luau" / "luau.exe")], "Luau suites")
    run([sys.executable, "-m", "unittest", "tests/test_asset_pipeline.py", "tests/test_figure_publish.py", "tests/test_figure_glb.py"], "Pipeline tests")
    run([tool("rojo"), "build", "default.project.json", "-o", "RobloxWorkspace.rbxlx"], "Rojo build")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("collection", help="Collection folder under assets/figures, e.g. tidepool-tales")
    parser.add_argument("figures", nargs="*", help="Figure slugs (default: every built figure)")
    parser.add_argument("--build", action="store_true", help="Run the Blender final build first")
    parser.add_argument("--no-checks", action="store_true", help="Skip repository checks at the end")
    args = parser.parse_args(argv)
    try:
        figures = args.figures or figures_in(args.collection)
        if not figures:
            raise PublishError("No figures found; run the final build first or pass --build with figure slugs.")
        if args.build:
            build(args.collection, figures)
        reports, failures = {}, []
        for figure in figures:
            path = report_path(args.collection, figure)
            if not path.is_file():
                failures.append(f"{figure}: no validation report (run the final build)")
                continue
            report = json.loads(path.read_text(encoding="utf-8"))
            failures += [f"{figure}: {problem}" for problem in gate(report)]
            if report.get("schema_version", 1) >= 2:
                model = path.parent.parent / "model" / f"{snake(figure)}_roblox.glb"
                if not model.is_file() or hashlib.sha256(model.read_bytes()).hexdigest() != report.get("glb", {}).get("sha256"):
                    failures.append(f"{figure}: GLB changed since validation")
                previews = report.get("previews", {})
                for image in previews.get("fidelity_views", []) + previews.get("beauty_views", []):
                    if Path(image).name != image or not (path.parent.parent / "renders" / image).is_file():
                        failures.append(f"{figure}: missing inspection render {image}")
            reports[figure] = report
        if failures:
            raise PublishError("Gates failed:\n  " + "\n  ".join(failures))
        print(f"-- Gates passed for {len(reports)} figure(s)", flush=True)

        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        entries = {snake(f): manifest_entry(args.collection, f, r) for f, r in reports.items()}
        if upsert_manifest(manifest, entries):
            MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
            print("-- Manifest updated", flush=True)

        aliases = list(entries)
        run([sys.executable, "scripts/upload_assets.py", *aliases, "--dry-run"], "Upload dry run")
        uploads = json.loads(UPLOADS.read_text(encoding="utf-8"))
        # A mapped key whose GLB changed is an intended revision: create the replacement asset.
        replace = any(entry["key"] in uploads for entry in entries.values())
        run([sys.executable, "scripts/upload_assets.py", *aliases, "--timeout", "600",
             *(["--replace"] if replace else [])], "Roblox upload")

        uploads = json.loads(UPLOADS.read_text(encoding="utf-8"))
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        text = luau_entries(uploaded_reports(manifest, uploads))
        ENTRIES.write_bytes(text.encode("utf-8"))
        print(f"-- Wired {ENTRIES.relative_to(ROOT).as_posix()}", flush=True)

        if not args.no_checks:
            checks()
        for figure, report in reports.items():
            key = entries[snake(figure)]["key"]
            print(f"{report['catalog']:<14} {key:<40} {uploads[key]['assetId']}")
        print("Published. Studio playtest still required for runtime behaviour.")
        return 0
    except PublishError as error:
        print(f"Publish stopped: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
