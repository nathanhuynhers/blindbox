# Figure Collection Runbook

The step-by-step process for turning a set of approved character sheets into 3D figures that are
uploaded to Roblox and shown in the game. It is written from the Tidepool Tales collection, which
went through every step. **Read this whole document before starting a new collection or figure.**

[FIGURE_PRODUCTION_WORKFLOW.md](FIGURE_PRODUCTION_WORKFLOW.md) describes the long-term goal. This
runbook is the process that works today.

## 0. Ground rules

- **The sheet is the source of truth.** Reconstruct the character; do not redesign, "improve" or
  simplify it. When views disagree, follow the orthographic FRONT / 3/4 / SIDE / BACK views, keep the
  hero render's silhouette, and choose the simplest physically coherent shape.
- **Standing approval to publish (granted by the user on 2026-09-29).** When the user provides sheets
  for figures, build them, check them yourself against the sheets, and publish automatically with
  `tools/figures/publish.py` once every gate passes. Do not stop to ask for design approval or
  upload permission. Present the result afterwards (step 6). This covers uploading these figures to
  the configured creator and wiring them into the existing figure pipeline. It does not cover
  new gameplay, catalog, economy or UI changes; ask about those as usual.
- **Your own visual check is the approval gate.** A figure can pass every geometry gate and still look
  wrong. Only publish figures that match their sheet: silhouette, proportions, face, accessories and
  colors.
- Follow [AGENTS.md](../AGENTS.md): strict Luau, focused modules, server-owned state, no new
  dependencies, and no gameplay changes beyond what was asked.
- Model only the collectible and its permanently attached accessories, never the sheet's environment
  (rocks, water, background props).

## 1. What the user provides

Usually one sheet per figure, in the same layout as the Tidepool Tales mockups:

| Sheet area | Use |
| --- | --- |
| Hero render | Silhouette, pose, overall read |
| CHARACTER VIEWS (front, 3/4, side, back) | **Geometry.** Measure proportions here |
| DETAILS | Close-ups of accessories and features that need real geometry |
| PALETTE | Material colors (hex values picked from these swatches) |
| EXPRESSIONS | Reference only; model the hero's default expression |
| Name, rarity, tagline | Must match the catalog entry |

Save each sheet as `assets/figures/<collection-slug>/<figure-slug>/reference/<figure_snake>_sheet.<ext>`.
Image attachments land in the session's temp `images/` folder; copy them from there.

Look up each figure's catalog ID (for example `tide.bubble`) in
[src/shared/Catalog.luau](../src/shared/Catalog.luau). If the collection or a figure is not in the
catalog, ask before adding it: that is a gameplay change and is not covered by the standing approval.

## 2. Layout

```text
tools/figures/                      shared tooling, never copied per collection
  sdf.py                            signed-distance sculpting primitives
  modeling.py                       optional mesh sweeps, braids, garment lofts, Comp profiles
  materials.py / baking.py          portable presets and optional Cycles map baking
  glb.py                            embedded core-glTF inspection
  build.py                          Blender: mesh, audit, export GLB, re-import, render
  publish.py                        gates, manifest, upload, runtime wiring, checks
assets/figures/<collection-slug>/
  figures.py                        this collection's figure definitions (FIGURES dict)
  PRODUCTION.md                     collection receipt (step 8)
  <collection_snake>_lineup.png/.webp
  <figure-slug>/
    reference/<figure>_sheet.webp
    model/<figure>_roblox.glb       the upload file
    model/<figure>_production.blend
    renders/<figure>_{beauty,fidelity}_{front,three_quarter,side,back}.{png,webp}
    renders/<figure>_{beauty,fidelity}_sheet.png
    validation/<figure>_validation.json
build/figures/<collection>/         ignored scratch: previews and build logs
```

Slugs are kebab-case folders and snake_case filenames (`bubble-bean/`, `bubble_bean_roblox.glb`).
Use [the Tidepool Tales figures.py](../assets/figures/tidepool-tales/figures.py) as the template for a
new collection's `figures.py`.

## 3. How the figures are modeled

Figures can mix **signed-distance fields (SDFs)** meshed by Blender 5.2's bundled OpenVDB and
procedural/native mesh components. No interactive Blender or MCP is required; figures rebuild from
`figures.py`. Blender is at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`; override the
path with the `BLENDER` environment variable.

### Conventions

- 1 unit = 1 stud. **+Z up, figure faces −Y, the character's left is +X.** `build.py` grounds the
  lowest point to Z = 0 on the centreline.
- Authored heights of about 2.2–3.4 studs, matching the collection. Tidepool Tales: Bubble Bean
  3.09 tall, Ripple Ray 3.89 wide and 1.98 tall, Pearl Regent 3.38 tall. The runtime then applies one
  uniform scale (step 7).
- Keep one collection-wide visual language: chunky chibi forms, soft bevels, the same face
  construction, matte/satin vinyl, and thick accessories. Nothing paper-thin.

### Building blocks ([sdf.py](../tools/figures/sdf.py))

| Need | Tool |
| --- | --- |
| Soft body masses | `ellipsoid` joined with `smin(a, b, k)` (k ≈ 0.1–0.35 fillets) |
| Limbs, tentacles, tails, branches | `tube(points, radii)` or `round_cone` |
| Books, boxes, bands | `round_box`, `cylinder`, `torus` |
| Cuts and openings | `smax(d, -cut, k)` |
| Scallop ribs (shells) | `fan_angle` from a hinge point + `ribs`, subtracted as displacement |
| Faces, bellies, spots, trims | `overlay(base, region, out, depth)`: a thin skin that follows the surface |
| Front-projected shapes | `front_decal` with `ellipse2` / `arc2` |

Existing collection-specific `face(...)` helpers remain supported. New definitions should use
shared `surface_point` (fails when no crossing exists), `surface_normal`, `project_decal`, `shell`
and `subtract` from `sdf.py` for oriented eyes, lids, eyebrows, lips, cheeks and recessed features.
Place features on the **outermost** skin. These are geometry operations, not a facial anatomy preset.

### Hybrid modeling (opt-in)

Import `Comp` from `modeling.py` and `Mat`/`preset` from `materials.py` in **new** definitions.
Keep existing definitions and their local classes unchanged. Pass a material key directly in a
spec's `mats` dictionary, or use the existing collection `assemble` helper with material tuples.

| Need | Shared capability |
| --- | --- |
| Layered bangs, locks, flowing clumps, ponytails, limbs, seam trim | `hair_lock(points, widths, depths)` / `sweep(points, radii)`; transported elliptical sections, explicit sampling, rounded ends and UVs |
| Braids | `braid(points, radius, spread, turns)`; three closed overlapping strands; declare `expected_islands=3` |
| Skirts, dress/coats, cuffs, collars | `garment_loft(centers, radii, thickness, folds, fold_depth)`; inner/outer rings joined at rims. Rings must ascend in Z; use mesh factories for posed sleeves or open jackets |
| Scarves, ribbons, lapels, footwear, headwear, hands, props | Flattened/tapered sweeps, custom `MeshData(vertices, faces, uvs)`, or a callable returning a Blender mesh object with applied modifiers |
| Intentional separate pieces sharing material | `join_meshes`; concatenation, **not boolean union**. Declare island count. Keep separate Comp objects when budgets/materials differ |

Native factories must return a temporary mesh object. The builder copies evaluated modifiers,
world transforms and UVs and removes that source object; the Comp's material replaces its slots.
Clean up any other construction helpers in the factory. Arbitrary self-intersections, garment fit,
hand anatomy and reference accuracy still require artistic inspection; these helpers cannot infer them.

```python
from modeling import Comp, hair_lock
from materials import preset

mats = {"hair": preset("satin_vinyl", "#49302B", pbr=True)}
comps = [Comp("Example_Lock", None, "hair", quality="high",
              mesh=lambda: hair_lock([(0, 0, 2), (0.2, -0.4, 1.6), (0.25, -0.5, 1.2)],
                                     [0.16, 0.12, 0.025], [0.07, 0.06, 0.025]))]
# Return the same name/title/rarity/catalog/comps/mats/bounds spec as existing definitions.
```

### Detail and optimization controls

New `Comp` profiles are starting points, not per-figure quality promises:

| Profile | SDF voxel (studs) | Per-part triangle target | Max sampled optimization movement (studs) |
| --- | --- | --- | --- |
| simple | 0.012 | 6,000 | 0.012 |
| medium | 0.008 | 10,000 | 0.008 |
| high | 0.004 | 16,000 | 0.004 |

Override `voxel`, `tris`, `max_surface_error` per component. Preserve faces/hair edges/accessories
as separate parts with tighter limits rather than raising every part's budget. Author native
topology when SDF sampling would spend most triangles on a thin ribbon or pleated garment.
Legacy components retain their voxel, budget, smooth shading and cleanup defaults.

- For thin SDF geometry, supply tight `bounds=(lo, hi)` with positive margin and `min_feature`
  (full thickness); at least three voxels must span it. Legacy coarse 0.04-stud discovery can miss
  narrow disconnected details. Explicit bounds bypass that scan. Bounds touching the surface fail.
- New components keep small islands (`min_faces=0`), require `expected_islands=1` by default,
  and support `smooth=False` for hard surfaces. Tiny details should not be silently cleaned away.
  Counts refer to connected surface islands. Closed cavity shells with disconnected inward-facing
  inner skins fail the orientation gate; use open garment shells with joined/capped rims, or custom
  connected topology. Clip SDF `shell` to a region for facial patches and closed garment edges.
- Optimization measures symmetric distances from vertices and face centers before/after cleanup
  and decimation. Exceeding a new component's limit fails: split geometry or increase its budget.
  This is sampled geometry evidence, not a Hausdorff guarantee or visual-quality score.
- The dense-grid memory guard defaults to 64 million cells (`FIG_MAX_GRID_CELLS`). Tighten bounds
  or split parts before raising it. No automatic smoothing/subdivision is added.
- Keep each part **below 20,000 triangles**, preserving the existing conservative publisher gate.
  [Roblox's general limit](https://create.roblox.com/docs/art/modeling/specifications) is 20,000.

### Materials and maps

`preset(name, hex_color, pbr=False, **overrides)` supports `satin_vinyl`, `glossy_vinyl`,
`matte_plastic`, `glossy_eyes`, `painted_resin`, `soft_fabric`, `polished_metal`, `pearlescent`,
and `translucent`. `pbr=True` embeds a small packed G-roughness/B-metalness map even for uniform
presets. Flat albedo remains sufficient for many simple parts; share materials between parts.
Pearlescence is a roughness/metalness approximation; interference, coat, subsurface and refraction
remain optional **beauty-only** `render={...}` effects.

`Mat` accepts `color_map`, `roughness_map`, `metalness_map`, `normal_map` PNG paths. Color is sRGB;
data maps are Non-Color; normals must be tangent-space OpenGL (+Y). Roughness and metalness maps
must have matching dimensions. Default map budget is at most 2048px; prefer 256–512px for small
figures and use larger maps only for visible detail. Spatial maps require valid nondegenerate UVs;
native UVs are preserved, otherwise new components use smart projection. Legacy flat/ramp UVs
are supported, but are unsuitable for spatial maps. Sweep caps have disk UVs; cap/side charts
overlap, so unwrap uniquely in Blender when the painting/bake requires unique texels.

`baking.bake_maps(obj, directory, resolution=512, channels=(...), high=None, cage=0.02)` bakes
opaque Principled color, roughness and metalness through emission (no lighting), and tangent-space
normals from an optional selected high-resolution source. UVs must already be unwrapped. It restores
nodes, selection and render settings on success/failure. Bake before assembling the spec, then pass
the returned PNG paths to `Mat`. Do not leave the high-resolution source in the production collection.
Alpha is explicit in Mat; transmission is not baked. Check bake seams and projection cages visually.

### Defining a figure

Each figure is a function that returns
`assemble(name, title, rarity, comps, {}, bounds, catalog="<catalog id>")`:

- `catalog` is **required**. The publisher uses it to wire the model to the catalog figure.
- `Mat(color, rough, metal, alpha, **render)` is a material. `color` is a hex string, or a list of
  hex strings for a gradient ramp. Keyword extras (`coat`, `thin_film`, `subsurface`,
  `transmission`) affect **renders only** and never reach the GLB. A material with `alpha` below 1
  makes its parts see-through in game.
- `Comp(name, fn, (material_name, Mat), voxel, tris, ramp=None)` is one MeshPart.
  - `voxel`: 0.009–0.012 for large bodies, 0.004–0.006 for skins and small accessories. A skin needs
    at least 4 voxels through its `out + depth` thickness.
  - `tris`: the decimation budget. Keep every part under 20,000 (Roblox's limit). Figures totaled
    28k–53k triangles.
  - `ramp`: `fn(x, y, z) -> 0..1`, mapping the ramp material along height or distance from a hinge.
- Name parts `<FigureName>_<Part>` (`CoralCuddle_Starfish`), and give materials the same prefix.
  **The eyes part must be `<FigureName>_Eyes`**, because runtime facing uses it.
- `bounds` must enclose the figure with margin, or parts get clipped.
- Register the function in the module's `FIGURES` dict under its slug, in catalog order.

### Measuring the sheet

Estimate proportions in pixels from the CHARACTER VIEWS: overall width and height, head-to-body
ratio, eye height and spacing, eye size, and accessory positions. Convert them with one
pixel-to-stud factor per figure. Eyes are tall dark ovals at about 0.085–0.1 × 0.11–0.13 studs on a
head about 1.6 studs wide, with a white highlight at the upper left. Cheeks sit outside and below the
eyes, and the mouth is a small arc between and below them.

## 4. Preview loop

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- <collection> <figure> preview
```

This writes `build/figures/<collection>/preview/<figure>_beauty_sheet.png`: four 420 px views (about
10–100 s each). Run figures in parallel as background processes. Look at the sheet next to the
reference views and fix the biggest mismatch first: silhouette, then proportions, then features,
then color. Environment variables: `FIG_VIEWS=front,side` renders a subset, `FIG_TAG=_x` suffixes the
output name, and `FIG_VIEW="AgX|AgX - Punchy|-0.35"` sets the tone mapping. A collection can set its
default the same way with a module-level `RENDER_VIEW = "<transform>|<look>|<exposure>"` in its
`figures.py`; renders only, the GLB albedo is unaffected. Pocket Grove uses
`"Khronos PBR Neutral|None|-1.1"` because AgX washed its pastel palette toward white.

### Lessons from Tidepool Tales

- **Lighting:** use AgX with the "AgX - Punchy" look at −0.35 exposure (the default). The Standard
  view transform blows out pastels and hides problems.
- **Stacked skins bury each other.** Ripple Ray's cream belly skin (out 0.012) hid its cheeks and
  mouth. Put face decals on the outermost skin: `face(N, lambda p: torso(p) - 0.012, ...)`.
- **Two-tone parts:** use a skin (`overlay`) on the underside region, never a second solid offset
  inside the first; that leaves serrated seams at the edges.
- **Glass:** Cycles transmission with thin film renders almost opaque. The render garnish uses a
  mostly transparent glossy skin instead. Export glass as albedo alpha (Bubble Bean 0.38), and the
  runtime sets MeshPart transparency.
- **Wide or thin forms** (wings, fins): taper the chord from root to tip, sweep the tip back, keep
  the thickness at 0.14 or more, and check the SIDE view; a constant chord reads as a flat slab.
- **Accessories:** exaggerate thickness for readability (pencil radius 0.058, scepter 0.05,
  crown spikes 0.085). Coral branches needed a radius of 0.13–0.165 to stop looking spidery.
- **Faces:** match eye size first; small eyes lose the chibi read immediately.
- **Degenerate faces:** `build.py` dissolves slivers (2e-5); the audit must report zero.
- Skip microscopic details (sparkle speckles) and say so in the receipt.

### Beauty versus production fidelity

`preview` uses source geometry and optional Blender garnish. `final` saves a clean production
blend/GLB, resets Blender, reimports that GLB, and renders `*_fidelity_*` views with fixed Khronos
PBR Neutral lighting/color management and no garnish. It then reopens the source blend to render
`*_beauty_*` views. Both use the same measured framing at the four standard angles, fitting varied
heights/widths automatically. `FIG_VIEW` and collection `RENDER_VIEW` affect **beauty only**.
Use `build.py -- <collection> <figure> fidelity` to rerender an existing GLB without rebuilding it.
Neither mode is a Roblox screenshot. Compare both sheets to the reference before publication.

Final defaults are 1000px/96 samples. `FIG_RENDER_RES` and `FIG_RENDER_SAMPLES` allow faster
technical fixture runs; full production review should use the defaults and all four views.
Lineups remain source/beauty renders. Previously produced filenames are not rewritten by this upgrade.

### Infrastructure regression checks (no uploads)

```powershell
python -m unittest tests/test_asset_pipeline.py tests/test_figure_publish.py tests/test_figure_glb.py
& "$env:BLENDER" -b --factory-startup --python-exit-code 1 --python tests/test_figure_modeling.py
& "$env:BLENDER" -b --factory-startup --python-exit-code 1 --python tests/test_figure_blender.py
& "$env:BLENDER" -b --factory-startup --python-exit-code 1 --python tools/figures/build.py -- --fixture technical final
```

Set `BLENDER` to the installed executable first. The fixture is isolated geometry/material swatches,
not a character or collection; all outputs stay in ignored `build/`. Never pass it to `publish.py`.

## 5. Build, publish and wire up: one command

When the previews match the sheets:

```bash
python tools/figures/publish.py <collection> <figure> [<figure> ...] --build
```

With no figure names it publishes every figure in the collection that has a validation report.
Without `--build` it reuses the existing final builds. It stops at the first failure and changes
nothing further. In order, it:

1. **Builds** each figure in parallel (Blender `final` mode, about 5–20 minutes for a collection):
   production `.blend`, GLB, a validation report, a clean re-import, and 1000 px inspection and
   beauty and reimported fidelity renders. Logs go to `build/figures/<collection>/`.
   Default concurrency is two isolated Blender processes (`FIG_BUILD_JOBS` overrides it); high-detail
   grids need substantial memory, so size concurrency to available RAM.
2. **Gates** every report: each part closed, manifold, zero-area-free and positive-volume; under
   20,000 triangles per part; the GLB re-imports with identical mesh and triangle counts; every
   material has an embedded albedo texture (Studio imports factor-only colors near-white); no glTF
   extensions; a catalog ID and an `_Eyes` part are present.
   New schema-2 reports additionally gate finite vertices/UVs, one material per part, duplicate
   faces, orientation of disconnected surfaces, declared island counts, measured optimization
   error, embedded PBR data and triangle/UV/normal export attributes. Reimport checks surface,
   bounds, volume, topology, UV corners and shading normals, not just counts. A GLB SHA-256 binds
   its report and fidelity preview to the upload input; changed binaries require a new build.
   Old reports remain supported. Technical gates do not establish reference likeness or detect
   every self-intersection, hidden overlap, texture seam or thin feature omitted by its definition.
   Schema-2 publication requires all four beauty/fidelity inspection files. Blender exceptions
   return a nonzero process status so `--build` stops rather than accepting an older report.
3. **Registers** each figure in `assets/manifest.json` as alias `<figure_snake>` and key
   `Models.<CollectionPascal>.<FigureName>`, with every part as a required node.
4. **Uploads** through `scripts/upload_assets.py` (dry run first). It uses `ROBLOX_API_KEY` from the
   ignored root `.env` (never read, print or handle the key yourself) and uploads as the manifest
   creator (`103346374`). Unchanged GLBs are skipped. A changed GLB for an already-uploaded figure is
   uploaded as a replacement asset. IDs land in `assets/uploads.json` and the generated
   `src/shared/AssetIds.luau`.
5. **Wires** the runtime by regenerating `src/shared/FigureAssetEntries.luau` from every uploaded
   figure's report (catalog ID → key, root, face part, part count, size in Roblox axes, glass parts).
   Never edit that file by hand.
6. **Checks** the repository: StyLua, Selene, the Luau suites, the pipeline tests (including
   `tests/test_figure_publish.py`) and the Rojo build. `--no-checks` skips this; don't use it for a
   real publish.

Then render the lineup (`build.py -- <collection> lineup`) and check that no figure is cropped.

### How the runtime uses the models (already built; no code changes per collection)

- **Server:** [ModelAssets.luau](../src/server/ModelAssets.luau) loads each entry with
  `InsertService:LoadAsset`. It checks the part count and proportions (±20% on X and Z relative to
  height), turns the eyes toward −Z, scales to `height × FigureAssets.scale` (0.8), sets the pivot at
  the centre of the base, applies glass transparency, anchors and makes parts non-colliding, and
  publishes the model to `ReplicatedStorage.ProductionModels.Figures.<catalog id>`, incrementing
  `FigureRevision`. On failure it keeps the placeholder and sets `<Root>Status` and `<Root>Reason`
  attributes on the `Figures` folder.
- **Shared:** [FigureModel.luau](../src/shared/FigureModel.luau) `create(id, at)` clones the template
  once its replicated part count matches; otherwise it returns the procedural placeholder.
  `variant(id)` and `onTemplatesChanged(callback)` let callers rebuild when a template arrives.
- **Consumers:** `FigureSlots` (Display and shelves; rebuilds when the variant changes; standing
  scale is relative), `UIPreview` (all portrait previews; rebuilds on template arrival; undiscovered
  previews also hide `TextureID`), and `OpeningFigure` (the unboxing reveal). The server re-renders
  every plot on `FigureRevision`.
- **PBR:** the loader preserves imported `SurfaceAppearance`, normals and material properties;
  it does not fabricate texture IDs or change world lighting. `UIPreview` temporarily detaches
  PBR surfaces as well as hiding `TextureID` for undiscovered silhouettes, restores them for
  discovered previews, and destroys detached surfaces when the model/screen is replaced.
  [SurfaceAppearance](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance)
  depends on graphics settings, environment reflections and uploaded maps; a portable GLB is
  not proof that Open Cloud or Studio has imported every map correctly. Verify imported color,
  roughness, metalness and normal maps before accepting a future PBR collection.
- **Tuning** lives in [FigureAssets.luau](../src/shared/FigureAssets.luau): `scale` (0.8) and
  `glassTransparency` (0.55). If a collection's figures are much larger or smaller than about 3 studs,
  or break the display (8-stud spacing) or shelf (3.6-stud spacing, 4.2-stud rows) layouts, discuss
  `scale` before changing it: it applies to every figure.

## 6. Present the result

After publishing, show the result on a Design canvas: one overview board with the lineup and a
per-figure stats row, then one board per figure with the beauty render, the four inspection views
(same 85 mm camera for every figure), the source sheet, the MeshPart and triangle list, and palette
swatches. Upload the WebP renders as canvas assets. The Tidepool Tales canvas is the template:
https://claude.ai/artifact/QBkNESqAC9X8UXNtLiYz4E

State honestly which figure is least exact and why, and list the asset IDs. If the user asks for
revisions, follow step 9.

## 7. Studio checklist for the user

The command-line checks do not prove runtime behavior. Give the user this checklist and never claim
a playtest you did not run:

1. Play Solo. Output shows no `Figure model load failed` or `validation failed`, and every
   `…Status` attribute on `ReplicatedStorage.ProductionModels.Figures` is `Ready`.
2. Figures face the player, stand on their surface, show their colors (not near-white), and glass
   and metal look right.
3. Collection shows color for discovered figures and grey silhouettes for undiscovered ones.
4. The unboxing reveal frames each figure well.
5. A two-player test shows the same figures for visitors.

For new PBR assets, also compare exported/reimported fidelity views to Studio at the same angles,
neutral daytime lighting and a recorded graphics level. Inspect Collection tile/detail **discovered
and undiscovered** states, unboxing, Display and Shelves at desktop 1920×1080 and landscape phone
667×375 (plus relevant inset preset per the [device matrix](qa/DEVICE_TEST_MATRIX.md)). Toggle
discovered state repeatedly, replace figures and close/reopen screens; check no detached material
instances remain. ViewportFrame lighting differs from Workspace; do not promise identical gloss,
refraction or shadows. Preserve existing runtime glass overrides (0.55) when comparing alpha.

## 8. Receipt

Write `assets/figures/<collection>/PRODUCTION.md` following
[the Tidepool Tales receipt](../assets/figures/tidepool-tales/PRODUCTION.md). Include per-figure
parts, triangles and size; the build and publish commands; geometry and material checks; known
differences from the sheets; the asset ID table; and the Studio checklist. Add the new aliases to
[ASSET_PIPELINE.md](ASSET_PIPELINE.md). Do not commit unless asked.

## 9. Revising a figure later

Edit the collection's `figures.py`, preview until it matches, then run
`python tools/figures/publish.py <collection> <figure> --build`. The changed GLB is uploaded as a
replacement asset and the runtime entry regenerates. Update the receipt and the canvas.
