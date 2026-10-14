# Tripo / external GLB batch import

This is a separate import path beside the existing SDF/hybrid factory. Download textured,
static GLBs manually from Tripo; no Tripo API, AI calls, packages or humanoid rigging are needed.
Python 3.10+ and the existing Blender installation (`BLENDER` or `--blender`) are sufficient.
It uses the existing catalog, uploader, upload recovery journal, asset IDs and runtime entry
generator. It never deploys a Roblox place. The sheet workflow's standing publication approval
does **not** apply to these batches: each proposed batch requires explicit human review.

## Import a batch

1. Put downloads in `assets/incoming/tripo/` (ignored), or another local directory.
2. Copy [the manifest example](../tools/figures/tripo_batch.example.json) to a named batch JSON.
   Add one explicit entry per source file. Use existing catalog IDs, rarity, aliases and semantic
   keys; the importer rejects unknown figures, conflicts and unmapped GLBs, and never guesses
   identities from filenames. Keep this manifest in version control once it is filled in.
3. Run a dry run to check mappings, source format and source mesh names. Set `eyes.object` to
   the exact source node name shown, then review/set orientation and the face region.
4. Process the directory with one reusable command:

```powershell
python tools/figures/external.py assets/incoming/tripo --manifest tripo-batch.json --dry-run
python tools/figures/external.py assets/incoming/tripo --manifest tripo-batch.json
```

The manifest's `batch_id` determines `build/figures/external/<batch_id>/`. Open `report.html`:
it shows each figure's source and exported/reimported front, three-quarter, side and rear views,
conversion status, errors, source/production triangle counts, MeshPart counts and visual losses.
`batch.json` contains machine-readable results; a passing batch also produces `plan.json`.
Failed figures do not stop other conversions, but **any** unmatched file or failure prevents a
publishable plan. The command exits nonzero on failure. Worker logs and partial source renders
remain beside each failed figure's `job.json` for diagnosis.

Re-running skips successful unchanged figures, after rechecking every artifact hash and the
production GLB. Cache identity covers source bytes, manifest options, shared Python tooling,
Blender executable and render settings. Source/production GLBs, packed editable blends, renders
and reports live in content-addressed staging directories. Failed outputs are never accepted as
completed work. Processing is sequential to bound Blender memory usage.

```powershell
# Recheck an existing conversion without launching Blender. Use the original render settings.
python tools/figures/external.py assets/incoming/tripo --manifest tripo-batch.json --validate-only
# Faster technical previews; production review defaults to 1000px / 32 samples.
python tools/figures/external.py assets/incoming/tripo --manifest tripo-batch.json --resolution 256 --samples 8
```

## Orientation, face extraction and quality

- Blender coordinates stay **+Z up, front -Y, one unit per stud**. GLB import already converts
  glTF axes to Blender. `rotation_degrees` is an explicit XYZ Euler rotation applied after import;
  its default preserves imported orientation. Nothing infers front from an AI filename.
  Uniform scaling sets `height_studs`; the base is grounded and centered. Original GLB bytes are
  copied unchanged to `source/original.glb` before any conversion.
- The existing loader determines front from the bounding center of `<Root>_Eyes`. Use a genuine
  separate eyes mesh when available (`eyes.object`, omit `region`). For painted eyes on a single
  mesh, specify a front face patch: `eyes.region` is `[min_xyz, max_xyz]` within normalized **whole
  figure bounds after orientation**, before partitioning. Each coordinate is 0..1; front is near
  Y=0. The importer extracts existing triangles by centroid into the eyes MeshPart without adding,
  duplicating or repainting geometry. The patch must contain both eyes/central face, fit one material
  and fewer than 20,000 triangles, and have its center on the front near the centerline. An empty,
  oversized or off-center patch fails. The example region is illustrative; inspect your source.
- Existing source objects/material boundaries are retained. Connected islands are packed without
  dropping small details; oversized islands are split by deterministic spatial bisection. Triangle
  corners retain UV0, vertex colors and custom normals. No voxelization, remeshing, caps, invented
  primitives, smoothing or flat-material replacement is used.
- Default conversion is **lossless triangle partitioning**, rather than a shared per-character
  triangle target. Every production part is at most 19,999 triangles, preserving the existing
  conservative publisher gate. Open boundaries at part cuts are intentional: the assembled surface
  is unchanged. External schema-3 reports allow these boundaries; the SDF closed-solid gate is
  unchanged. Geometry with zero-area/duplicate faces, branching edges or degenerate UVs fails.
- `protected_objects` lists exact object names. Eyes-source objects and names containing face,
  eye, hair, accessory or clothing hints are also protected against decimation. Logical segmentation
  of a single painted mesh is not inferred; keep it lossless or prepare named source parts in Blender.
- `max_parts` defaults to 64 (explicit reviewed range 2..256). If partitioning exceeds it or the
  GLB exceeds 20,000,000 bytes, the pipeline fails rather than discarding detail. Inspect draw-call
  and memory cost on filled shelves before accepting a large-part figure.
- Original embedded albedo, roughness/metalness, normal and occlusion information is retained and
  checked after export, alongside a clean geometry/UV/normal reimport. Default texture cap is 4096px;
  smaller caps can be chosen. Oversized textures fail unless `resize_textures: true` is explicit;
  original textures remain in the source GLB/blend. Resizing is reported and compared visually.
  Production requires UV0 within 0..1 and one material per MeshPart. Skins, animations, morphs,
  glTF extensions, external resources, alpha MASK and emission fail with no silent material loss.
  Source input is bounded to 512 MB; imported PNG/JPEG data is decoded by Blender.
- Only named, unprotected objects can opt into `optimization`:

```json
"optimization": {
  "Body": {
    "target_triangles": 28000,
    "max_surface_error": 0.008,
    "bake_normals": true,
    "bake_resolution": 1024
  }
}
```

This uses Blender decimation, followed by sampled symmetric vertex/face-center surface distance.
It rejects losses above the authored error limit (studs), then partitions as needed. Different
objects/figures can use different budgets. Normal baking reuses `baking.py` with the high-resolution
source and retained UVs; it needs one opaque Principled material, no existing normal map and a
supported 128..2048px bake size within `texture_limit`. Existing normal maps are never replaced
automatically. Vertex-painted meshes cannot be decimated without a dedicated color bake: keep
those lossless. Texture/normal baking is optional because lossless imports already have maps.

Paired renders use identical source-measured camera framing, lighting and neutral color management.
Silhouette intersection-over-union below 0.97 or foreground RGB mean absolute error above 0.05
blocks conversion. These are **loss alarms**, not an artistic similarity score or proof of seam-free
textures. Examine faces, hair, accessories and clothing at full resolution before approving.
Neither Blender source nor fidelity images are Roblox screenshots. Roblox's
[mesh specifications](https://create.roblox.com/docs/art/modeling/specifications) and
[texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications)
remain the platform reference; actual PBR delivery and device texture quality need Studio review.

## Review and publish separately

Review `report.html` and `plan.json`: exact semantic identities, create/replace actions, previous
asset IDs/records, old/new manifest entries, GLB/report hashes and all eight images per figure.
After explicit approval of those changes, use the digest printed by the command/contact sheet:

```powershell
python tools/figures/external.py --publish build/figures/external/tripo-review-001/plan.json --dry-run
python tools/figures/external.py --publish build/figures/external/tripo-review-001/plan.json --approve-plan <REVIEWED_SHA256>
```

The dry run loads no credentials, uploads nothing and does not promote models or change mappings.
Real publication provisions pinned Rokit tools/Wally packages and rechecks the approved artifact hashes, creator, catalog and selected production
baselines under the existing uploader lock. It runs the repository checks and new batch tests
before network activity, promotes only deliverable artifacts to immutable
`assets/figures/external/<collection>/<figure>/<fingerprint>/`, prepares the whole upload selection,
then reuses `scripts/upload_assets.py`'s credential boundary, uploader, pending journal, unchanged
skip behavior, `assets/uploads.json` and `AssetIds.luau`. Old approved source/model files are never
overwritten; reviewed replacements create new Roblox asset IDs through the existing transport.
The existing `publish.py` report scanner and generator regenerate `FigureAssetEntries.luau`
from canonical manifest sources, including both SDF and imported figures. No runtime loader edits
or per-collection gameplay work are needed.

On a partial failure, completed uploads remain recorded, failed selections keep their previous
canonical source/runtime report, and the same reviewed publish command resumes the existing
upload journal. Do not rerun conversion to get a new plan mid-upload, delete pending upload state,
or use the ordinary SDF publisher to bypass the external approval gate. Unknown POST outcomes
still require the [existing uploader recovery procedure](ASSET_PIPELINE.md#api-behavior-validation-and-recovery).
Changed production baselines, reports or images invalidate the approval. A stale local lock may
be removed only after confirming no converter/uploader is running. Locks are local, not distributed.

After uploading, apply the [figure runbook's Studio checklist](FIGURE_COLLECTION_RUNBOOK.md#7-studio-checklist-for-the-user):
load/fallback, front/grounding/scaling, discovered and undiscovered Collection previews, unboxing,
Display, Shelves, imported PBR and another client's view at desktop and landscape phone sizes.
The current scale and glass rules are preserved. Asset upload does not publish a live game version;
that remains a separate explicitly authorized release activity.

## Offline checks

```powershell
python -m unittest discover -s tests -p test_external_figures.py -v
python -m unittest tests/test_asset_pipeline.py tests/test_figure_publish.py tests/test_figure_glb.py
& "$env:BLENDER" -b --factory-startup --python-exit-code 1 --python tests/test_external_blender.py
& "$env:BLENDER" -b --factory-startup --python-exit-code 1 --python tests/fixtures/external_blender.py
python tools/figures/external.py build/figures/external-fixtures/incoming --manifest build/figures/external-fixtures/batch.json --resolution 128 --samples 4
```

Fixtures are textured technical surfaces mapped to existing identities solely for offline contract
tests. `technical_fixture: true` marks their generated plans, and real publication rejects them.
All fixture outputs stay in ignored `build/`. The mocked publication tests create no Roblox assets.
