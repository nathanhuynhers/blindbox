"""Package Tripo models that were exported straight into Roblox Studio as figure Model assets.

Python 3.10+, standard library only. Tripo's Roblox export already uploaded each mesh and its
SurfaceAppearance maps; this only wraps them in the shape ModelAssets expects (one Model named
<Root>, a <Root>_Body MeshPart and an invisible <Root>_Eyes front marker) as .rbxmx files,
then reuses the normal uploader and FigureAssetEntries generator.

  python tools/figures/studio_figures.py            # write rbxmx, reports and manifest entries
  python tools/figures/studio_figures.py --upload   # also upload and regenerate FigureAssetEntries

Spec: assets/figures/studio/tripo_studio_figures.json (properties read from Studio).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).resolve().parent))
import publish  # noqa: E402

ROOT = publish.ROOT
SPEC = ROOT / "assets" / "figures" / "studio" / "tripo_studio_figures.json"
EYE_HEIGHT, EYE_DEPTH = 0.72, 0.35  # Marker inside the front of the bounds, at head height.


def vector(name: str, x: float, y: float, z: float) -> str:
    return f'<Vector3 name="{name}"><X>{x!r}</X><Y>{y!r}</Y><Z>{z!r}</Z></Vector3>'


def axes(x: float, y: float, z: float) -> str:
    rotation = "".join(f"<R{i}{j}>{int(i == j)}</R{i}{j}>" for i in range(3) for j in range(3))
    return f"<X>{x!r}</X><Y>{y!r}</Y><Z>{z!r}</Z>{rotation}"


def cframe(x: float, y: float, z: float) -> str:
    return f'<CoordinateFrame name="CFrame">{axes(x, y, z)}</CoordinateFrame>'


def flags(*names: str, value: bool) -> str:
    return "".join(f'<bool name="{name}">{str(value).lower()}</bool>' for name in names)


def rbxmx(root: str, figure: dict) -> str:
    width, height, depth = figure["size"]
    content = lambda name, url: f'<Content name="{name}"><url>{escape(url)}</url></Content>'
    still = flags("CanCollide", "CanTouch", "CanQuery", value=False) + flags("Anchored", value=True)
    return "".join([
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">',
        f'<Item class="Model" referent="RBX0"><Properties><string name="Name">{root}</string>',
        f'<OptionalCoordinateFrame name="WorldPivotData"><CFrame>{axes(0, 0, 0)}</CFrame></OptionalCoordinateFrame>',
        "</Properties>",
        '<Item class="MeshPart" referent="RBX1"><Properties>',
        f'<string name="Name">{root}_Body</string>', still,
        cframe(0, height / 2, 0), vector("size", width, height, depth), vector("InitialSize", *figure["initial"]),
        content("MeshId", figure["meshId"]),
        '</Properties><Item class="SurfaceAppearance" referent="RBX2"><Properties>',
        '<string name="Name">SurfaceAppearance</string><token name="AlphaMode">0</token>',
        content("ColorMap", figure["colorMap"]), content("NormalMap", figure["normalMap"]),
        "</Properties></Item></Item>",
        '<Item class="Part" referent="RBX3"><Properties>',
        f'<string name="Name">{root}_Eyes</string>', still, flags("CastShadow", value=False),
        '<float name="Transparency">1</float>', cframe(0, height * EYE_HEIGHT, -depth * EYE_DEPTH),
        vector("size", 0.05, 0.05, 0.05),
        "</Properties></Item></Item></roblox>\n",
    ])


def write(spec: dict) -> list[str]:
    manifest = json.loads(publish.MANIFEST.read_text(encoding="utf-8"))
    entries = {}
    for root, figure in spec["figures"].items():
        collection = spec["collections"][figure["collection"]]
        folder = publish.FIGURES / figure["collection"] / figure["slug"]
        name = publish.snake(figure["slug"])
        model = folder / "model" / f"{name}_roblox.rbxmx"
        model.parent.mkdir(parents=True, exist_ok=True)
        model.write_text(rbxmx(root, figure), encoding="utf-8", newline="\n")
        width, height, depth = figure["size"]
        report = {
            "schema_version": 1, "pipeline": "studio_tripo",
            "catalog": f'{collection["catalog"]}.{figure["slug"]}', "collection_id": collection["catalog"],
            "rarity": figure["rarity"], "root": root, "figure": root, "title": figure["title"],
            "face": f"{root}_Eyes", "glass": [], "meshes": 2,
            "size_xyz_studs": [round(v, 4) for v in (width, depth, height)],  # Blender order, as luau_entries expects
            "components": [f"{root}_Body", f"{root}_Eyes"],
            "rbxmx": {"sha256": hashlib.sha256(model.read_bytes()).hexdigest()},
        }
        (folder / "validation").mkdir(exist_ok=True)
        (folder / "validation" / f"{name}_validation.json").write_text(
            json.dumps(report, indent=2) + "\n", encoding="utf-8", newline="\n")
        entries[f'{collection["catalog"]}_{name}'] = {
            "key": f'Models.{publish.pascal(figure["collection"])}.{root}',
            "source": model.relative_to(ROOT).as_posix(),
            "displayName": f'{collection["title"]} - {figure["title"]}',
            "assetType": "Model",
            "requiredNodes": [root, *report["components"]],
        }
    if publish.upsert_manifest(manifest, entries):
        publish.MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    return list(entries)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--upload", action="store_true", help="Upload and regenerate FigureAssetEntries")
    args = parser.parse_args(argv)
    aliases = write(json.loads(SPEC.read_text(encoding="utf-8")))
    uploader = [sys.executable, "scripts/upload_assets.py", *aliases]
    if subprocess.run([*uploader, "--dry-run"], cwd=ROOT).returncode != 0:
        return 1
    if not args.upload:
        return 0
    if subprocess.run([*uploader, "--timeout", "600"], cwd=ROOT).returncode != 0:
        return 1
    manifest = json.loads(publish.MANIFEST.read_text(encoding="utf-8"))
    uploads = json.loads(publish.UPLOADS.read_text(encoding="utf-8"))
    publish.ENTRIES.write_bytes(publish.luau_entries(publish.uploaded_reports(manifest, uploads)).encode("utf-8"))
    print(f"Wired {len(aliases)} figures. Studio playtest still required for runtime behaviour.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
