"""Explicit Open Cloud image uploads. Python 3.10+, standard library only."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
import zlib

ROOT = Path(__file__).resolve().parents[1]
API = "https://apis.roblox.com/assets/v1/"
MAX_BYTES = 20_000_000  # Conservative decimal interpretation of Roblox's 20 MB limit.
KEY = re.compile(r"[A-Z][A-Za-z0-9]*(?:\.[A-Z][A-Za-z0-9]*)+")
ID = re.compile(r"[1-9][0-9]*")
OPERATION = re.compile(r"operations/[A-Za-z0-9_-]+")
IMAGE_FORMATS = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}
MODEL_FORMATS = {".glb": "model/gltf-binary"}


class PipelineError(Exception):
    """Only locally authored, credential-free messages may be shown to the user."""


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        raise PipelineError("Cannot read pipeline JSON; check manifest/mapping/journal syntax.") from None
    if not isinstance(value, dict):
        raise PipelineError("Pipeline JSON must contain an object.")
    return value


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n",
                                         dir=path.parent, delete=False) as stream:
            name = stream.name
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if name and Path(name).exists():
            Path(name).unlink()


def write_json(path: Path, value: dict) -> None:
    atomic_write(path, json.dumps(value, indent=2, sort_keys=True) + "\n")


def load_api_key(root: Path) -> str:
    # Verify before reading .env, even if the shell already supplies the key.
    git = ["git", "-c", f"safe.directory={root.as_posix()}", "-C", str(root)]
    ignored = subprocess.run(git + ["check-ignore", "-q", ".env"], capture_output=True)
    tracked = subprocess.run(git + ["ls-files", "--", ".env", ".env.*"], capture_output=True)
    tracked_names = tracked.stdout.decode("utf-8", errors="replace").splitlines()
    if ignored.returncode != 0 or tracked.returncode != 0 or any(
        name != ".env.example" for name in tracked_names
    ):
        raise PipelineError("Refusing credentials: .env must be ignored and secret environment files untracked.")
    key = os.environ.get("ROBLOX_API_KEY", "")
    if not key and (root / ".env").exists():
        # Parse only this variable. No shell evaluation, interpolation, or logging.
        for line in (root / ".env").read_text(encoding="utf-8-sig").splitlines():
            name, separator, value = line.strip().removeprefix("export ").partition("=")
            if separator and name.strip() == "ROBLOX_API_KEY":
                key = value.strip()
                if len(key) >= 2 and key[0] == key[-1] and key[0] in "\"'":
                    key = key[1:-1]
                break
    if not key or any(ord(c) < 33 or ord(c) > 126 for c in key):
        raise PipelineError("Set a valid single-line ROBLOX_API_KEY in the environment or ignored root .env.")
    return key


def image_info(path: Path) -> tuple[bytes, str, int, int]:
    if path.suffix.lower() not in IMAGE_FORMATS or not path.is_file():
        raise PipelineError("Source must be an existing PNG or JPEG file.")
    if not 0 < path.stat().st_size <= MAX_BYTES:
        raise PipelineError("Source must be non-empty and no larger than 20 MB.")
    data = path.read_bytes()
    if not 0 < len(data) <= MAX_BYTES:
        raise PipelineError("Source changed size while reading; retry with a stable export.")
    width = height = 0
    if path.suffix.lower() == ".png":
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise PipelineError("PNG signature does not match its filename.")
        offset, saw_pixels, finished = 8, False, False
        while offset + 12 <= len(data):
            size = struct.unpack_from(">I", data, offset)[0]
            kind = data[offset + 4:offset + 8]
            end = offset + 8 + size
            if end + 4 > len(data):
                break
            payload = data[offset + 8:end]
            crc = struct.unpack_from(">I", data, end)[0]
            if zlib.crc32(kind + payload) != crc:
                raise PipelineError("PNG checksum failed; re-export the source.")
            if offset == 8:
                if kind != b"IHDR" or size != 13:
                    raise PipelineError("PNG is missing a valid dimension header.")
                width, height = struct.unpack_from(">II", payload)
            saw_pixels |= kind == b"IDAT" and size > 0
            offset = end + 4
            if kind == b"IEND":
                finished = size == 0 and offset == len(data)
                break
        if not finished or not saw_pixels:
            raise PipelineError("PNG is incomplete or has no pixel data.")
    else:
        if not data.startswith(b"\xff\xd8") or not data.endswith(b"\xff\xd9"):
            raise PipelineError("JPEG signature/end marker is invalid.")
        offset = 2
        sof = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
        while offset + 4 <= len(data):
            if data[offset] != 0xFF:
                break
            while offset < len(data) and data[offset] == 0xFF:
                offset += 1
            if offset + 3 > len(data):
                break
            marker = data[offset]
            offset += 1
            if marker == 0xDA:  # Entropy-coded scan follows; no pixel decoding dependency.
                break
            length = struct.unpack_from(">H", data, offset)[0]
            if length < 2 or offset + length > len(data):
                break
            if marker in sof and length >= 8:
                height, width = struct.unpack_from(">HH", data, offset + 3)
                break
            offset += length
    if not 0 < width < 8000 or not 0 < height < 8000:
        raise PipelineError("Image dimensions must be positive and each smaller than 8000 pixels.")
    return data, IMAGE_FORMATS[path.suffix.lower()], width, height


def model_info(path: Path, required_nodes: object) -> tuple[bytes, str, list[str]]:
    if path.suffix.lower() not in MODEL_FORMATS or not path.is_file():
        raise PipelineError("Model source must be an existing GLB file.")
    if not 0 < path.stat().st_size <= MAX_BYTES:
        raise PipelineError("Model source must be non-empty and no larger than 20 MB.")
    data = path.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        raise PipelineError("GLB signature is invalid.")
    version, declared = struct.unpack_from("<II", data, 4)
    if version != 2 or declared != len(data):
        raise PipelineError("GLB must be version 2 with a complete declared length.")
    offset, document = 12, None
    while offset + 8 <= len(data):
        size, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        end = offset + size
        if end > len(data):
            raise PipelineError("GLB contains an incomplete chunk.")
        if kind == 0x4E4F534A and document is None:
            try:
                document = json.loads(data[offset:end].rstrip(b"\x00 ").decode("utf-8"))
            except (UnicodeDecodeError, ValueError):
                raise PipelineError("GLB JSON metadata is invalid.") from None
        offset = end
    if offset != len(data) or not isinstance(document, dict):
        raise PipelineError("GLB is missing valid JSON metadata.")
    nodes = document.get("nodes")
    if not isinstance(nodes, list):
        raise PipelineError("GLB contains no node hierarchy.")
    names = [node.get("name") for node in nodes if isinstance(node, dict)]
    names = [name for name in names if isinstance(name, str) and name]
    if required_nodes is not None:
        if (not isinstance(required_nodes, list)
                or any(not isinstance(name, str) or not name for name in required_nodes)):
            raise PipelineError("requiredNodes must be a list of non-empty GLB node names.")
        missing = [name for name in required_nodes if name not in names]
        if missing:
            raise PipelineError("GLB is missing required semantic nodes: " + ", ".join(missing))
    return data, MODEL_FORMATS[path.suffix.lower()], names


def creator_value(value: object) -> dict:
    if not isinstance(value, dict) or len(value) != 1:
        raise PipelineError('Set manifest creator to {"userId":"YOUR_ID"} or {"groupId":"YOUR_ID"}.')
    name, identifier = next(iter(value.items()))
    if name not in ("userId", "groupId") or not ID.fullmatch(str(identifier)):
        raise PipelineError("Creator must contain one positive userId or groupId.")
    return {name: str(identifier)}


def prepare(root: Path, entry: dict) -> dict:
    key, source = entry.get("key"), entry.get("source")
    if not isinstance(key, str) or not KEY.fullmatch(key):
        raise PipelineError("Semantic keys must use dotted PascalCase, for example Collection.BookOpen.")
    if not isinstance(source, str):
        raise PipelineError("Each asset needs a source path inside assets/.")
    path = (root / source).resolve()
    if not path.is_relative_to((root / "assets").resolve()):
        raise PipelineError("Source paths must remain inside assets/ (including symlink targets).")
    asset_type = entry.get("assetType", "Image")
    extension = "png|jpe?g" if asset_type == "Image" else "glb"
    if not re.fullmatch(rf"[a-z0-9]+(?:_[a-z0-9]+)*\.({extension})", path.name):
        raise PipelineError("Use a lowercase snake_case filename supported by its asset type.")
    if asset_type not in ("Image", "Model"):
        raise PipelineError("This pipeline supports Image and GLB Model assets only.")
    display = entry.get("displayName", path.stem)
    if not isinstance(display, str) or not 1 <= len(display) <= 50 or any(ord(c) < 32 for c in display):
        raise PipelineError("Display name must be 1-50 characters without control characters.")
    if asset_type == "Image":
        data, mime, width, height = image_info(path)
        detail = {"width": width, "height": height}
    else:
        data, mime, nodes = model_info(path, entry.get("requiredNodes"))
        detail = {"nodes": nodes}
    return {"key": key, "source": path.relative_to(root).as_posix(), "displayName": display,
            "assetType": asset_type, "sha256": hashlib.sha256(data).hexdigest(),
            "data": data, "mime": mime, **detail}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # Never forward an API key to a redirect target.


class Cloud:
    def __init__(self, key: str):
        self.key = key
        self.opener = urllib.request.build_opener(NoRedirect())

    def error_detail(self, payload: object) -> str:
        """Expose only structured error codes/messages, with credentials redacted."""
        if not isinstance(payload, dict):
            return ""
        errors = payload.get("errors", [payload])
        if not isinstance(errors, list):
            return ""
        details = []
        for error in errors[:3]:
            if not isinstance(error, dict):
                continue
            fields = [str(error[field]) for field in ("code", "message")
                      if isinstance(error.get(field), (str, int))]
            message = ": ".join(fields).replace(self.key, "[redacted]")
            if message:
                details.append(" ".join(message.split())[:1000])
        return "; ".join(details)

    def request(self, method: str, path: str, body: bytes | None = None,
                content_type: str = "application/json") -> dict:
        if path != "assets" and not OPERATION.fullmatch(path):
            raise PipelineError("Invalid Open Cloud operation path.")
        request = urllib.request.Request(API + path, data=body, method=method,
                                         headers={"x-api-key": self.key, "Content-Type": content_type})
        try:
            with self.opener.open(request, timeout=30) as response:
                value = json.loads(response.read(1_000_001))
            if not isinstance(value, dict):
                raise ValueError()
            return value
        except urllib.error.HTTPError as error:
            # Never dump response bodies/headers. Only allowlisted, redacted diagnostic fields.
            detail = ""
            try:
                detail = self.error_detail(json.loads(error.read(65_536)))
            except (OSError, ValueError, http.client.HTTPException):
                pass
            hints = {400: "Check asset format, name and creator.", 401: "Check API key validity.",
                     403: "Check assets Read/Write permissions, creator ownership and IP restrictions.",
                     404: "Operation was not found; check the Creator Dashboard before retrying.",
                     429: "Rate limited; resume later."}
            raise PipelineError(f"Roblox HTTP {error.code}. " + (detail or hints.get(error.code, "Resume later; check Roblox service status."))) from None
        except (OSError, ValueError, http.client.HTTPException):
            raise PipelineError("Network or response failure. No upload was retried; rerun to resume a known operation.") from None

    def create(self, item: dict, creator: dict) -> dict:
        boundary = "blindbox_" + uuid.uuid4().hex
        metadata = {"assetType": item["assetType"], "displayName": item["displayName"],
                    "description": "", "creationContext": {"creator": creator}}
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
                f'Content-Type: application/json\r\n\r\n{json.dumps(metadata)}\r\n'
                f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; '
                f'filename="{Path(item["source"]).name}"\r\nContent-Type: {item["mime"]}\r\n\r\n').encode()
        body += item["data"] + f"\r\n--{boundary}--\r\n".encode()
        return self.request("POST", "assets", body, "multipart/form-data; boundary=" + boundary)

    def poll(self, operation: dict, timeout: float) -> str:
        deadline = time.monotonic() + timeout
        while True:
            if operation.get("error") or operation.get("status"):
                detail = self.error_detail(operation.get("error") or operation.get("status"))
                raise PipelineError("Roblox operation failed. " + (detail or "Inspect it in Creator Dashboard; mapping was preserved."))
            if operation.get("done") is True:
                response = operation.get("response", {})
                asset_id = str(response.get("assetId", "")) if isinstance(response, dict) else ""
                if not ID.fullmatch(asset_id):
                    raise PipelineError("Completed operation has no valid asset ID; mapping was preserved.")
                return asset_id
            path = operation.get("path", "")
            if not isinstance(path, str) or not OPERATION.fullmatch(path):
                raise PipelineError("Roblox returned no valid operation path; inspect Creator Dashboard before retrying.")
            if time.monotonic() >= deadline:
                raise PipelineError("Polling timed out. Rerun the same command to resume without another upload.")
            time.sleep(min(2, max(0, deadline - time.monotonic())))
            operation = self.request("GET", path)


def generate(root: Path, mapping: dict) -> None:
    lines = ["--!strict", "-- Generated by scripts/upload_assets.py. Do not edit; source: assets/uploads.json.",
             "return {"]
    for key, record in sorted(mapping.items()):
        if not KEY.fullmatch(key) or not isinstance(record, dict) or not ID.fullmatch(str(record.get("assetId", ""))):
            raise PipelineError("Uploaded mapping contains an invalid semantic key or asset ID.")
        lines.append(f'\t["{key}"] = "{record["assetId"]}",')
    lines.append("} :: { [string]: string }")
    if not mapping:
        lines = lines[:2] + ["return {} :: { [string]: string }"]
    # The repository's StyLua configuration requires Windows line endings for Luau sources.
    atomic_write(root / "src/shared/AssetIds.luau", ("\n".join(lines) + "\n").replace("\n", "\r\n"))


@contextmanager
def exclusive(root: Path):
    path = root / "build/assets/upload.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        raise PipelineError("Uploader lock exists. Close other uploaders; remove build/assets/upload.lock only if stale.") from None
    try:
        os.close(descriptor)
        yield
    finally:
        path.unlink(missing_ok=True)


def upload(root: Path, items: list[dict], creator: dict, cloud: Cloud, replace: bool, timeout: float) -> None:
    mapping_path = root / "assets/uploads.json"
    mapping = read_json(mapping_path)
    generate(root, mapping)  # Repair an interrupted generation and validate before any network calls.
    journal_path = root / "build/assets/pending.json"
    journal = read_json(journal_path) if journal_path.exists() else {}
    for item in items:
        key = item["key"]
        old = mapping.get(key)
        same = old and old.get("sha256") == item["sha256"] and old.get("creator") == creator and old.get("assetType") == item["assetType"]
        if old and not same and not replace and key not in journal:
            raise PipelineError("An asset is already mapped. Use --replace to explicitly create a new asset.")
    for item in items:
        key = item["key"]
        identity = {field: item[field] for field in ("source", "sha256", "assetType")}
        identity["creator"] = creator
        old = mapping.get(key)
        if key not in journal and old and all(old.get(field) == identity[field] for field in ("sha256", "creator", "assetType")):
            if old.get("source") != item["source"]:
                old["source"] = item["source"]
                write_json(mapping_path, mapping)
            print(f"Unchanged {key}: {old['assetId']}")
            continue
        pending = journal.get(key)
        if pending:
            if pending.get("identity") != identity:
                raise PipelineError("Pending upload has different source/owner. Restore it and resume before replacing.")
            operation = pending.get("operation")
            if not operation:
                raise PipelineError("Upload outcome is unknown. Check Creator Dashboard and docs recovery steps; no retry sent.")
        else:
            journal[key] = {"identity": identity, "operation": None}
            write_json(journal_path, journal)  # Persist intent before sending an irreversible POST.
            operation = cloud.create(item, creator)
            # Persist only allowlisted response fields, never arbitrary remote text.
            path = operation.get("path")
            safe = {"path": path} if isinstance(path, str) and OPERATION.fullmatch(path) else {}
            if operation.get("done") is True:
                response = operation.get("response", {})
                identifier = str(response.get("assetId", "")) if isinstance(response, dict) else ""
                if ID.fullmatch(identifier):
                    safe.update({"done": True, "response": {"assetId": identifier}})
            journal[key]["operation"] = safe or None
            write_json(journal_path, journal)
        asset_id = cloud.poll(operation, timeout)
        mapping[key] = {**identity, "assetId": asset_id}
        write_json(mapping_path, mapping)
        generate(root, mapping)
        del journal[key]
        write_json(journal_path, journal)
        print(f"Uploaded {key}: {asset_id}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("assets", nargs="*", help="Explicit manifest aliases, or one assets/ image path with --key")
    parser.add_argument("--key", help="Semantic key for a direct file path")
    parser.add_argument("--name", help="Roblox display name for a direct path")
    parser.add_argument("--creator", help="Override manifest creator: user:123 or group:123")
    parser.add_argument("--replace", action="store_true", help="Allow creating a new asset for a changed existing key")
    parser.add_argument("--dry-run", action="store_true", help="Validate locally; no credentials or network")
    parser.add_argument("--generate", action="store_true", help="Regenerate Luau from uploads.json; no network")
    parser.add_argument("--timeout", type=int, default=180, help="Polling seconds per asset (1-1800)")
    args = parser.parse_args(argv)
    try:
        if args.generate:
            if args.assets:
                raise PipelineError("--generate does not accept uploads.")
            with exclusive(ROOT):
                generate(ROOT, read_json(ROOT / "assets/uploads.json"))
            print("Generated public asset ID module.")
            return 0
        if not args.assets or not 1 <= args.timeout <= 1800:
            raise PipelineError("Specify assets explicitly and use a timeout between 1 and 1800 seconds.")
        manifest = read_json(ROOT / "assets/manifest.json")
        if args.key:
            if len(args.assets) != 1:
                raise PipelineError("A direct path with --key accepts exactly one asset.")
            entries = [{"key": args.key, "source": args.assets[0],
                        "displayName": args.name or Path(args.assets[0]).stem}]
        else:
            configured = manifest.get("assets", {})
            if not isinstance(configured, dict) or any(name not in configured for name in args.assets):
                raise PipelineError("Unknown asset alias; add it to assets/manifest.json or use a path with --key.")
            entries = [configured[name] for name in args.assets]
        if not all(isinstance(entry, dict) for entry in entries):
            raise PipelineError("Each manifest asset must be an object.")
        items = [prepare(ROOT, entry) for entry in entries]  # Entire selection validated before first upload.
        if len({item['key'] for item in items}) != len(items):
            raise PipelineError("Selection contains duplicate semantic keys.")
        value = manifest.get("creator")
        if args.creator:
            match = re.fullmatch(r"(user|group):([1-9][0-9]*)", args.creator)
            if not match:
                raise PipelineError("--creator must be user:123 or group:123.")
            value = {match[1] + "Id": match[2]}
        if args.dry_run:
            if value is not None:
                creator_value(value)
            for item in items:
                detail = (f"{item['width']}x{item['height']}"
                          if item["assetType"] == "Image"
                          else f"{len(item['nodes'])} semantic nodes")
                print(f"Valid {item['key']}: {detail}, {len(item['data'])} bytes")
            if value is None:
                print("Creator is not configured; set it before uploading.")
            return 0
        creator = creator_value(value)
        with exclusive(ROOT):
            cloud = Cloud(load_api_key(ROOT))
            upload(ROOT, items, creator, cloud, args.replace, args.timeout)
        return 0
    except PipelineError as error:
        print(f"Asset upload: {error}", file=sys.stderr)
        return 1
    except (OSError, ValueError, TypeError, KeyError):
        print("Asset upload: local file/configuration failure. Check file permissions and JSON structure.", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Asset upload interrupted; pending state retained. Rerun to resume a known operation.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
