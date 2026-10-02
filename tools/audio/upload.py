"""Validate or explicitly upload the original opening pack using the existing asset pipeline."""
import argparse
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("upload_assets", ROOT / "scripts/upload_assets.py")
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upload", action="store_true", help="Create Roblox audio assets; otherwise validate offline")
    parser.add_argument("--only", help="One cue key for a pilot upload")
    args = parser.parse_args()
    try:
        pack = pipeline.read_json(ROOT / "assets/audio/opening/pack.json")
        entries = pack["assets"]
        if len(entries) != 48 or (args.only and args.only not in entries):
            raise pipeline.PipelineError("Expected the complete 48-cue opening pack and a known cue key.")
        items = []
        for key, entry in entries.items():
            item = pipeline.prepare(ROOT, entry)
            if item["assetType"] != "Audio" or item["sha256"] != entry["sha256"]:
                raise pipeline.PipelineError("Pack source changed; rebuild and review before uploading.")
            if item["key"] != "Audio.Opening." + key[0].upper() + key[1:]:
                raise pipeline.PipelineError("Pack cue and semantic key disagree.")
            if not args.only or key == args.only:
                items.append(item)
        creator = pipeline.creator_value(pipeline.read_json(ROOT / "assets/manifest.json")["creator"])
        print(f"Validated {len(entries)} PCM WAV files; selected {len(items)}; creator {creator}.", flush=True)
        if args.upload:
            with pipeline.exclusive(ROOT):
                cloud = pipeline.Cloud(pipeline.load_api_key(ROOT))
                pipeline.upload(ROOT, items, creator, cloud, False, 180)
        return 0
    except pipeline.PipelineError as error:
        print(f"Audio pack: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
