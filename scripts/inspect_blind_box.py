"""Read-only inspection of the approved Roblox model; never uploads or changes permissions."""
import json
import urllib.error
import urllib.parse
import urllib.request

from upload_assets import ROOT, Cloud, NoRedirect, load_api_key


def main():
    key = load_api_key(ROOT)
    cloud = Cloud(key)
    opener = urllib.request.build_opener(NoRedirect())
    mapping = json.loads((ROOT / "assets/uploads.json").read_text())
    identifier = mapping["Models.BlindBoxBase"]["assetId"]
    for path in (f"assets/v1/assets/{identifier}",
                 f"asset-delivery-api/v1/assetId/{identifier}"):
        request = urllib.request.Request("https://apis.roblox.com/" + path,
                                         headers={"x-api-key": key})
        try:
            with opener.open(request, timeout=30) as response:
                document = json.load(response)
        except urllib.error.HTTPError as error:
            detail = cloud.error_detail(json.loads(error.read(65536)))
            print(f"Inspection HTTP {error.code}: {detail}")
            continue
        if path.startswith("assets/"):
            print(json.dumps({field: document.get(field) for field in
                              ("assetId", "assetType", "displayName", "creationContext", "state")}))
        else:
            location = document.get("location")
            if not location and document.get("locations"):
                location = document["locations"][0].get("location")
            if not isinstance(location, str):
                print("Delivery returned no location; fields: " + ", ".join(document))
                continue
            parsed = urllib.parse.urlparse(location)
            if parsed.scheme != "https" or not (parsed.hostname or "").endswith(".rbxcdn.com"):
                raise ValueError("Unexpected asset delivery host")
            # The CDN request has no API-key header.
            with urllib.request.urlopen(location, timeout=30) as response:
                content = response.read(20_000_001)
            if len(content) > 20_000_000:
                raise ValueError("Unexpected model size")
            destination = ROOT / "build/assets/blind_box_imported.rbxm"
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
            print(f"Downloaded {len(content)} bytes to {destination.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
