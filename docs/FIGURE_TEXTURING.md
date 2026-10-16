# Reusable GLB texture preparation

Use this entry point for gray, incompletely textured or disconnected Tripo GLBs. It extends
the [external importer](TRIPO_BATCH_IMPORT.md), rather than introducing another uploader or
runtime asset system. Python 3.10+ and the existing Blender installation are sufficient;
no packages, API credentials or AI service are needed for texture preparation.

## What is automatic

`tools/figures/texture_prepare.py` discovers GLBs recursively, records mesh primitives,
hierarchy/transforms, material assignments, UV/color attributes, texture/image references
and triangle counts. It preserves already textured inputs byte for byte. An explicit recipe
can reconnect an embedded texture or embed a supplied UV-aligned PNG/JPEG into an existing
material. Geometry, accessors, normals, UV coordinates and original source files are preserved.
Existing albedo factors, normal scale and occlusion strength are retained.

Every run writes machine-readable `textures.json` and a local `textures.html` inspection
report. It includes input/output and map hashes, optional reference hash, exact failures,
warnings and pending visual acceptance. Prepared GLBs are content-addressed; unchanged
outputs reuse their location. Failures do not stop inspection of other inputs. Any failure
returns a nonzero exit code and blocks generation of a complete import manifest.

**This does not paint missing character details from reference art.** A single photograph or
character sheet is not a UV texture atlas. A connected albedo can still contain gray pixels or
the wrong character colors. The report's `ready_for_import_review` means the existing importer's
technical source checks passed; reference likeness, seam quality and Studio appearance remain
unverified. No automatic artistic similarity score or segmentation is claimed.

## Folder and reference conventions

Put inputs under `assets/incoming/`. For the first test, use a dedicated subdirectory so the
command processes only that detailed figure:

```text
assets/incoming/first-figure/
  figure.glb
  figure_reference.png
  authored_albedo.png       # optional, already aligned to the model's original UV0
  authored_normal.png       # optional, tangent-space OpenGL +Y
  authored_rm.png           # optional, green roughness / blue metalness
```

References match the GLB stem with no suffix, `_reference`, or `_sheet`, using lowercase
`.png`, `.jpg`, `.jpeg` or `.webp` extensions. Multiple matches require explicit selection.
Use a recipe for different filenames, uppercase extensions or references in another subfolder.
Reference/map paths are relative to the supplied incoming directory and cannot escape it.
Never use a reference sheet as `albedo` unless it really is a UV-aligned texture atlas.

```powershell
python tools/figures/texture_prepare.py assets/incoming/first-figure --output build/figures/first-textures
```

Open `build/figures/first-textures/textures.html`. The inventory includes material indices and
original image/texture indices. It is read-only inspection of source assets; no Blender scene
or runtime configuration changes occur. Materials or UVs that are completely absent require
authoring rather than a guessed mapping. Unsupported source extensions are reported by the
existing strict importer, even when the source has textures.

## Explicit repair recipe

Save a JSON file outside the source assets, for example `build/figures/first-recipe.json`:

```json
{
  "figure.glb": {
    "reference": "figure_reference.png",
    "materials": {
      "0": {
        "albedo": "authored_albedo.png",
        "normal": "authored_normal.png",
        "metallic_roughness": "authored_rm.png"
      },
      "1": {"albedo": {"texture": 2}}
    }
  }
}
```

Keys are exact relative GLB paths and existing zero-based material indices. Omit channels
and material entries that need no change. `{ "texture": 2 }` explicitly reconnects the
existing glTF texture at index 2; it is not an image index or Roblox asset ID. `occlusion`
is also supported. New image maps are bounded to 4096px and 64 MB each. This preflight reads
PNG/JPEG metadata; the later Blender conversion must actually decode and render those maps.
Transparency is preserved, not inferred from reference art or converted automatically.

```powershell
python tools/figures/texture_prepare.py assets/incoming/first-figure --recipe build/figures/first-recipe.json --output build/figures/first-textures
```

When a map changes, it produces a new prepared path and hash. Previously prepared binaries
remain immutable; use only paths in the current report. A failed reprocessing run never lists
an earlier success as current. Do not point the importer at a parent containing unrelated old
prepared outputs; the importer intentionally rejects unmapped GLBs.

## Continue through the existing batch importer

Copy [the existing manifest example](../tools/figures/tripo_batch.example.json) and supply the
existing catalog identity, exact source node for the eyes or face patch, orientation, height
and budgets. The original manifest's source is relative to your incoming folder. Identity is
never guessed from a filename and unknown catalog figures are never registered automatically.

Pass that manifest to preparation to emit a remapped `prepared-batch.json`. This retains
identity and processing options, replacing only source paths with prepared content hashes:

```powershell
python tools/figures/texture_prepare.py assets/incoming/first-figure --recipe build/figures/first-recipe.json --manifest first-batch.json --output build/figures/first-textures
python tools/figures/external.py build/figures/first-textures/prepared --manifest build/figures/first-textures/prepared-batch.json --dry-run
python tools/figures/external.py build/figures/first-textures/prepared --manifest build/figures/first-textures/prepared-batch.json
```

Use a fresh output folder per input selection or deliberate recipe revision to avoid collecting
unmapped historical prepared files. All input GLBs must have one manifest mapping and pass
preparation before a remapped manifest is emitted. A new run removes an old remapped manifest
before processing so a failed batch cannot leave a current-looking import selection.

The external worker provides normalization, grounding, UV/normal preservation, lossless
partitioning below 19,999 triangles per part, explicitly configured optimization, optional normal
baking, four source and four exported/reimported renders, source/export loss alarms and a review
plan. Its unchanged-output cache and existing uploader avoid duplicate uploads. Report paths
and exact publication commands are described in [TRIPO_BATCH_IMPORT.md](TRIPO_BATCH_IMPORT.md).
Preparation does not bypass that review gate. Uploading still requires review of a concrete
plan; uploading figure assets never publishes a live place.

## When artistic authoring is needed

Missing UV0, materials, face colors, hair gradients or accessory segmentation are **manual
review**, not a license to assign random palettes. Use a textured Tripo export or an artist/
texture-authoring service to supply UV-aligned maps. More reference views help with hidden
surfaces. The existing `tools/figures/baking.py` can bake reviewed Blender materials after
authoring and unwrapping; it cannot infer anatomical regions or reference likeness. Automatic
UV regeneration and atlas baking are deliberately not applied to textured inputs because they
would invalidate existing maps. A gray monolithic mesh needs this authoring stage before it
can be declared a faithfully colored figure.

## Visual acceptance and batch rollout

Before scaling up, review one detailed figure's reference, all Blender fidelity views, then
the actual Roblox import. Check face/pupils/highlights, clean boundaries, accessories, UV seams,
gray surfaces, alpha, silhouette, size/orientation and PBR differences. Source/export comparisons
measure conversion loss; they do not prove fidelity to the reference.

Follow the [runbook Studio checklist](FIGURE_COLLECTION_RUNBOOK.md#7-studio-checklist-for-the-user)
and [device matrix](qa/DEVICE_TEST_MATRIX.md): Collection discovered/undiscovered tile and detail,
opening, Display, Shelves, fallback/loading and another client's view. Record desktop 1920×1080
and landscape phone 667×375, actual graphics settings and relevant inset preset. Blender output
is never recorded as a Studio screenshot. Only expand the input selection after that first
figure passes. The same commands operate on larger directories; recipes contain data rather
than character-specific Python code.

## Future chat prompt

> Use docs/FIGURE_TEXTURING.md and the figure runbook. Inspect the GLB and reference in
> assets/incoming/MY-FIGURE. Run texture_prepare.py first and show any missing-color or UV
> limitations. Repair only explicit, justified material connections or authored maps. Reuse
> the external batch importer and existing catalog identity. Compare reference, Blender fidelity
> views and Roblox Studio when available. Keep originals untouched and mark unavailable visual
> checks NOT RUN. Prepare the exact upload plan for review before uploading; do not publish a place.

## Regression checks

```powershell
python -m unittest discover -s tests -p test_texture_prepare.py -v
python -m unittest discover -s tests -p test_external_figures.py -v
```

These are offline tests. They cover byte preservation, explicit reconnection, external embedding,
hash changes, stale failure handling, ambiguity/path rejection and complete identity remapping.
They do not certify texture decode, artistic quality or Roblox rendering.
