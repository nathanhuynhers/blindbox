"""Read Roblox moderation metadata for the uploaded pack; never changes permissions."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import sys
import urllib.error
import urllib.request

from upload import ROOT, pipeline


def main():
    pack = pipeline.read_json(ROOT / "assets/audio/opening/pack.json")
    mapping = pipeline.read_json(ROOT / "assets/uploads.json")
    key = pipeline.load_api_key(ROOT)
    records = {}
    for cue, entry in pack["assets"].items():
        record = mapping[entry["key"]]
        if record["sha256"] != entry["sha256"] or not pipeline.ID.fullmatch(str(record["assetId"])):
            raise pipeline.PipelineError("Pack upload is missing or stale.")
        records[cue] = record

    def get(pair):
        cue, record = pair
        identifier = record["assetId"]
        request = urllib.request.Request(pipeline.API+"assets/"+identifier, headers={"x-api-key":key})
        try:
            opener = urllib.request.build_opener(pipeline.NoRedirect())
            with opener.open(request, timeout=30) as response:
                value = json.loads(response.read(1000000))
        except urllib.error.HTTPError as error:
            raise pipeline.PipelineError(f"Metadata lookup failed with HTTP {error.code}.") from None
        except (OSError, ValueError):
            raise pipeline.PipelineError("Metadata lookup failed; no upload was attempted.") from None
        state = value.get("moderationResult",{}).get("moderationState","Unknown")
        if state not in ("Approved","Rejected","Reviewing","MODERATION_STATE_APPROVED","MODERATION_STATE_REJECTED"):
            state = "Unknown"
        return cue, {"assetId":identifier,"creator":record["creator"],"moderationState":state}

    with ThreadPoolExecutor(max_workers=4) as executor:
        results = dict(executor.map(get, records.items()))
    report = {"checkedAt":datetime.now(timezone.utc).isoformat(),"assets":results}
    pipeline.write_json(ROOT/"assets/audio/opening/roblox_status.json",report)
    totals = {}
    for value in results.values():
        state = value["moderationState"]
        totals[state] = totals.get(state,0)+1
    print("Roblox moderation:",json.dumps(totals,sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except pipeline.PipelineError as error:
        print("Audio status:",error,file=sys.stderr)
        sys.exit(1)
