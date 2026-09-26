# Asset pipeline

The pipeline registers artwork and reviewed GLB models; individual UI adoptions are explicit. Both Collection
screens now use production corners and tab emblems; see the [batch receipt](COLLECTION_ASSET_BATCH.md). Python 3.10+ and Git
are required; there are no added packages. Run commands from the repository root.

## Sources and stable names

Place reviewed artwork under [assets](../assets/README.md): `ui/global`,
`ui/collection/shared`, `ui/collection/pocket-grove`, `ui/collection/tidepool-tales`,
`figures/pocket-grove`, `figures/tidepool-tales`, `boxes`, `display`, or `showroom`.
Display assets belong to the economic main-plot fixture; Showroom assets belong to the separate
zero-income gallery/room system described in [Display and Showrooms](DISPLAY_AND_SHOWROOMS.md).
If an export needs processing elsewhere, keep the reviewed output in `assets/processed`
and point the manifest at that file. The uploader never resizes, re-encodes or transforms source
content; transparent PNG and GLB bytes are sent unchanged.

Use lowercase snake_case filenames, such as `collection_book_open.png`,
`pocket_grove_emblem.png`, `tidepool_corner_bottom_right.png`, and `icon_collection.png`.
Use stable dotted PascalCase semantic keys, such as `Collection.PocketGrove.Emblem`.
The alias is the short command name; the semantic key is the permanent code reference.
Replacing a file does not require renaming its key or editing UI references.

Reviewed reusable models live under `assets/models/<model-slug>/`. Model entries use
`assetType: Model`, a lowercase snake_case `.glb` source, and may declare `requiredNodes`.
Dry-run validation checks the GLB 2.0 container and every declared semantic node before upload.

## One-time configuration and secrets

The root `.env` is ignored, as are `.env.*`; only `.env.example` is eligible for Git.
The example contains exactly `ROBLOX_API_KEY=`. Leave the existing secret unchanged.
The script reads `ROBLOX_API_KEY` from the process environment first, otherwise from the
root `.env`. Plain or quoted single-line values work; shell expressions are never evaluated.
It checks Git ignore/tracking rules before reading credentials. Dry runs, regeneration and
offline tests never load the repository secret.

In [assets/manifest.json](../assets/manifest.json), replace `"creator": null` with either
`"creator": {"userId": "YOUR_NUMERIC_ID"}` or `"creator": {"groupId": "YOUR_NUMERIC_ID"}`.
This is public ownership configuration, not a credential. A one-command override is
`--creator user:123` or `--creator group:123` using your actual ID.

Configure the key for **assets Read and Write**, the intended creator, and any applicable
IP restrictions/expiration. Group uploads require permission to manage that group's assets.
See Roblox's [official usage guide](https://create.roblox.com/docs/cloud/guides/usage-assets)
and [API-key configuration](https://create.roblox.com/docs/cloud/auth/api-keys).
The key, HTTP authorization headers and raw service responses are never printed or recorded.
Do not put credentials in arguments, asset metadata, shared Luau, screenshots or commits.

## Upload one asset

Put the real PNG at
`assets/ui/collection/pocket-grove/pocket_grove_corner_top_left.png`.
That planned alias already exists in the manifest. Validate without a network request:

```powershell
python scripts/upload_assets.py pocket_grove_corner_top_left --dry-run
```

After setting the creator, upload explicitly:

```powershell
python scripts/upload_assets.py pocket_grove_corner_top_left
```

Or upload a file without first adding an alias:

```powershell
python scripts/upload_assets.py assets/ui/global/icon_collection.png --key Global.IconCollection --name "Collection Icon"
```

Success prints the semantic name and asset ID. No arguments never upload anything.
An unchanged file/owner/type already recorded under that key is skipped. Renaming its
source path updates provenance without another upload. Name changes alone do not modify
Roblox metadata; manage that through Creator Dashboard.

The reusable blind-box model is selected explicitly in the same way:

```powershell
python scripts/upload_assets.py blind_box_base --dry-run
python scripts/upload_assets.py blind_box_base
```

It uploads `assets/models/blind-box/blind_box_base.glb` as `Models.BlindBoxBase` with MIME type
`model/gltf-binary`. Roblox imports the GLB as a package Model containing MeshParts. The runtime
loader validates the same semantic contract before replicating a sanitized preview template.

The first production upload completed under creator user `103346374` as Model asset
`79870100381887`. Its source SHA-256 is
`9bad381e0e12ef02115db560681b360db90af192d7456b5e43f5ec6a73a8cb0d`.

## Selected group

Pass only the aliases you want, separated by spaces:

```powershell
python scripts/upload_assets.py collection_book_open pocket_grove_corner_top_left --dry-run
python scripts/upload_assets.py collection_book_open pocket_grove_corner_top_left
```

All selected files are validated first; uploads then run sequentially. A later failure
preserves earlier successes. Rerunning skips those successes and resumes pending work.
There is no directory scan, wildcard upload, or automatic upload on build.

## IDs and Luau access

The uploader records each semantic key's `source`, `assetId`, `sha256`, `assetType` and
`creator` in [assets/uploads.json](../assets/uploads.json), then generates the dedicated
[AssetIds.luau](../src/shared/AssetIds.luau) module. Commit both together with the sources
and manifest. No script edits hand-authored Luau. If generation was interrupted:

```powershell
python scripts/upload_assets.py --generate
```

[AssetManifest.luau](../src/shared/AssetManifest.luau) is the hand-authored public interface:

```lua
local Assets = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)
local image = Assets.resolve(Assets.Collection.PocketGrove.Emblem)
-- Equivalent extensible lookup: Assets.resolve("Collection.PocketGrove.Emblem")
-- Returns rbxassetid://<id>, or "" for an absent/invalid ID.
```

Collection artwork slots retain their native rendering until explicitly adopted.
A future approved adoption can pass `{ id = image }` to an existing `CollectionAssets.mount`
slot. A valid resolved `rbxassetid://` reference selects only the ImageLabel; a missing
or invalid reference selects only native artwork. Loading state never selects the fallback.
Uploading alone does not activate additional slots. Test approved art in Studio for moderation,
experience access, dimensions, slicing and visual fit before publishing. Luau modules are
cached per session: restart the play session after syncing a changed generated mapping.

The Shop reuses the canonical collection emblems and adds transparent repeating pattern inputs at
`assets/ui/shop/<collection-slug>/`. Their semantic keys are
`Collection.<Collection>.ShopPattern`. Shop pattern and emblem slots use the same exclusive rule:
a resolved production ID displays the ImageLabel, while an absent ID displays only the native fallback.

## Replace art or add a collection

Replace the source file under the same key, dry-run it, then explicitly allow replacement:

```powershell
python scripts/upload_assets.py pocket_grove_corner_top_left --replace
```

Image content cannot currently be updated in place through this API; replacement creates
a new Image ID and switches the mapping only after success. The old Roblox asset remains;
Git history preserves its prior mapping. This follows the
[official API's content-update restriction](https://create.roblox.com/docs/cloud/reference/assets#PATCH-v1-assets-assetId).

For another collection, add `assets/ui/collection/<collection-slug>/` and optionally
`assets/figures/<collection-slug>/`, then add explicit manifest entries:

```json
"new_collection_emblem": {
  "key": "Collection.NewCollection.Emblem",
  "source": "assets/ui/collection/new-collection/new_collection_emblem.png",
  "displayName": "New Collection Emblem",
  "assetType": "Image"
}
```

Use the same command with the new alias. String-key resolution works immediately; add
optional typed convenience constants to `AssetManifest` when adopting the new collection.

## API behavior, validation and recovery

The uploader sends multipart `request` metadata and original `fileContent` bytes to
`POST https://apis.roblox.com/assets/v1/assets`, with the manifest's `Image` or `Model` asset type so the returned ID
is an image resource suitable for UI. It polls the returned operation through
`GET https://apis.roblox.com/assets/v1/operations/{operationId}` until `done`/failure.
See [Roblox's endpoint schemas](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/cloud/assets/v1.json).
No cookies, legacy endpoints, redirects or automatic POST retries are used.

PNG/JPG/JPEG are supported. Local checks include file presence, extension/signature,
nonzero size, at most 20,000,000 bytes, and each dimension from 1 through 7999.
PNG chunk boundaries/checksums/end markers and JPEG frame dimensions/end markers are
checked. This is lightweight structural validation, not a full pixel decoder; Roblox
still validates content and performs moderation. The byte/dimension caps are based on
the [official upload limits](https://create.roblox.com/docs/cloud/guides/usage-assets#supported-asset-types-and-limits).
Model uploads are intentionally disabled; a future file validator/type adapter can reuse
the multipart transport, operation polling and recording logic.

`build/assets/pending.json` is an ignored local journal containing only source hashes,
creator IDs and allowlisted operation fields. Preserve it until all pending uploads finish.
Timeouts, polling HTTP errors or interruptions with a known operation resume on the same
command; the default polling window is 180 seconds (`--timeout 600` allows longer).
A filesystem lock prevents concurrent local writers. Remove `build/assets/upload.lock`
only after confirming no uploader is running if a hard process termination left it behind.

If the initial POST loses its response, the tool cannot know whether Roblox created the
asset. It deliberately blocks a second POST. In this exceptional case, inspect Creator
Dashboard first. If you recover an operation ID, set that key's journal `operation` to
`{"path":"operations/RECOVERED_ID"}` and rerun. If you verify the completed Image ID,
set it to `{"done":true,"response":{"assetId":"VERIFIED_ID"}}` and rerun to record it.
Only remove that key's journal entry to retry after confirming the request failed and
created no asset. The same manual confirmation applies to a terminal operation failure.
Never delete pending state merely to get past an error. Do not run uploads for the same
keys from several machines at once; the lock is local, not distributed.

HTTP errors report structured codes/messages with credentials redacted, without dumping
raw responses or headers. The initial infrastructure tests were offline; the first
explicitly authorized live upload is recorded below.

## Verification

```powershell
python -m unittest discover -s tests -p test_asset_pipeline.py -v
python scripts/upload_assets.py --generate
stylua --check src
selene src
python tests/run.py build/tools/luau/luau.exe
rojo build default.project.json -o RobloxWorkspace.rbxlx
```

The upload tests use temporary fixtures, synthetic credentials and mocked HTTP. They
cover byte preservation, validation, mapping generation, explicit replacement, unchanged
skips, interrupted/unknown upload recovery, redirect rejection, credential-safe errors,
and dry runs that never load credentials. They create no Roblox assets.

Implementation verification: pinned Rokit/Wally installation, StyLua formatting/check,
Luau LSP source diagnostics, Rojo sourcemap/build, the existing game suite, 10 new Luau
manifest checks and 18 offline Python tests passed. New Luau files lint with zero errors
or warnings. Full-source Selene uses the cached Roblox API and reports one pre-existing
`roblox_manual_fromscale_or_fromoffset` warning in `FigureDetails.luau:56`; that UI file
was not changed for this task. No Studio playtest or live upload was performed.

## First live upload and Pocket Grove adoption

This historical receipt predates the [complete production batch](COLLECTION_ASSET_BATCH.md).
The original PNG is now archived, and its live semantic mapping has been replaced.

- Source: `assets/ui/collection/pocket-grove/pocket_grove_corner_top_left.png`.
- Creator: user `103346374`; manifest ownership schema and dry-run passed.
- Unmodified PNG: 1430x1100, 924735 bytes; SHA-256
  `370cd996cda3bfc17991fa04b46d361bb2f9a1353ed7d91406dff7ed4c91fc2a`.
- Pixel inspection confirmed transparency in the empty area, with no opaque background.
- The single-asset Open Cloud upload and operation polling succeeded: **78396978639853**.
- The pipeline recorded `Collection.PocketGrove.CornerTopLeft` in `assets/uploads.json`
  and regenerated `src/shared/AssetIds.luau`. The semantic resolver returns
  `rbxassetid://78396978639853`.
- `CollectionAssets.collections.grove.cornerTopLeft` supplies the semantic image and
  aspect-fit option. `CollectionSkin` applies it only to `Corner1`, at
  `Collection/PhysicalBook/BookSkin/Native/BookOrnaments/Corner1/Artwork`.
- Existing 110x110 corner bounds at X=0, Y=-10 are unchanged. Fit draws the full 13:10
  image at approximately 110x84.6 without distortion. The transparent, untinted image
  remains inside the existing decoration exclusion area. No title/progress/layout moved.
- The existing native corner stays available, but is visible only when the asset reference
  is missing/invalid. A resolved production image hides it immediately, including while
  loading. Other Grove corners and all Tidepool artwork remain unchanged.

Live-pass checks: 19 offline pipeline tests, the full game suite (including 11 asset
manifest checks), formatting, Luau LSP diagnostics, and Rojo build passed. Changed asset
modules lint cleanly. Full-source lint retains the previously documented FigureDetails
warning. The source image hash is unchanged. No Studio playtest was run; code resolution
does not prove Roblox client delivery or visual approval.

Studio checklist after Rojo sync and a fresh Play session:

1. Open Pocket Grove Collection. Confirm the leaf/flower corner loads without a rectangular
   background, tint, or stretching; title and discovery progress must remain unobstructed.
2. Check desktop and narrow/mobile views. The decoration must stay within its reserved corner.
3. Switch to Tidepool and back. Tidepool must retain its native decoration; only Grove's
   upper-left corner uses the uploaded PNG.
4. Run `tests/StudioCollection.client.luau` in the client Command Bar with each collection
   open. It reports whether Grove loaded or is using fallback and checks isolation/spacing.
5. In an unsaved test session, temporarily clear `CollectionAssets.get("grove").cornerTopLeft.id`
   to `""`, switch collections away/back, and confirm the native corner appears. Stop/restart
   Play to restore the module state. Review Studio Output for asset permission/moderation errors.

### Follow-up: native corner remained visible

A read-only Open Cloud metadata check confirmed asset `78396978639853` is an `Image`,
owned by user `103346374`, with moderation state `Approved`. The mount had set the
ImageLabel invisible until `IsLoaded`, creating a visibility/loading dependency. Assigned
images were made visible so Roblox could render/load them. The subsequent exclusivity
fix also removes the loading-state dependency from native visibility: a valid resolved
asset ID selects production artwork only; an empty/invalid ID selects native artwork only.
`CollectionAssets.mount` applies this rule to every uploaded/native slot, and the Studio
check verifies that the two representations cannot both be visible. No artwork, asset ID,
sizing or layout changed. Sync and restart Play to replace the cached module.

The exclusivity regression suite runs the actual mount against lightweight engine shims:
15 checks cover initial fallback, pending/complete/repeated loading states, Grove/Tidepool
switching, empty/invalid references, Image property changes, and listener teardown.
