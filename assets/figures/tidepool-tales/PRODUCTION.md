# Tidepool Tales production receipt

**Status: uploaded to Roblox and wired into the game. Loaded in-game through `ModelAssets` and
`FigureModel`; not yet verified in a Studio playtest.**

Six figures reconstructed from the approved character sheets in each figure's `reference/` folder:

| Figure | Rarity | MeshParts | Triangles | Size W × D × H (studs) | Largest mesh |
| --- | --- | ---: | ---: | --- | ---: |
| Bubble Bean | Common | 10 | 27,990 | 2.23 × 1.74 × 3.09 | Body 12,000 |
| Coral Cuddle | Common | 11 | 41,290 | 2.36 × 1.87 × 3.03 | CoralCrown 16,000 |
| Shell Scribe | Common | 15 | 45,268 | 2.23 × 1.92 × 2.95 | ShellHood 17,578 |
| Jelly Jive | Uncommon | 8 | 28,890 | 2.48 × 1.98 × 2.22 | Bell 13,998 |
| Ripple Ray | Uncommon | 12 | 50,292 | 3.89 × 2.22 × 1.98 | Wings 9,000 each |
| Pearl Regent | Rare | 10 | 53,464 | 3.25 × 2.38 × 3.38 | ShellThrone 18,956 |

Per figure folder (`<slug>/`):

- `model/<slug>_roblox.glb`: the import file. One root node named after the figure (for example
  `BubbleBean`) with one child mesh per MeshPart (`BubbleBean_Body`, `BubbleBean_BubbleCap`, …).
- `model/<slug>_production.blend`: the same meshes and materials, for inspection or hand edits.
- `renders/`: `front`, `three_quarter`, `side`, `back` inspection renders and a `beauty` render,
  as PNG (transparent, with shadow) and WebP.
- `validation/<slug>_validation.json`: per-mesh audit, build timings, GLB summary and re-import check.
- `reference/<slug>_sheet.webp`: the approved sheet the model was matched against.

`tidepool_tales_lineup.png` shows all six side by side at true relative scale.

## How the figures are built

The models are generated reproducibly by [generator/](generator/). `figures.py` defines each figure
as signed-distance fields (smooth unions of ellipsoids, tapered tubes and rounded boxes; sculpted
scallop ribs; coral branches). Faces, bellies, spots, cheeks and trims are thin skins that conform
to the underlying surface rather than floating decals. `build.py` runs inside Blender 5.2: it meshes
each part with OpenVDB (bundled with Blender), collapse-decimates it to a per-part triangle budget,
grounds the figure, assigns materials, exports GLB, re-imports it and renders.

```
blender -b --factory-startup --python assets/figures/tidepool-tales/generator/build.py -- bubble-bean final
```

`preview` instead of `final` writes a quick four-view contact sheet to `generator/_preview/`
(scratch, safe to delete). `x lineup` renders the six-figure lineup from the production `.blend` files.

## Geometry checks (all six)

- Every MeshPart is a closed, manifold shell with positive volume. No boundary edges, no
  non-manifold edges, no zero-area faces. Loose specks under 24 faces are removed.
- Every MeshPart is under Roblox's 20,000-triangle limit. The largest is 18,956.
- Smooth shading, consistent outward normals, identity transforms, ground pivot at Z = 0 on the
  figure's centreline.
- GLB re-import: mesh count and per-mesh triangle counts match exactly for every figure.
- Parts intentionally interpenetrate (limbs into bodies, skins over surfaces), as Pebble Pip's do.
  Nothing floats: the bubble cluster, starfish, book, pencil, crown and scepter all intersect
  their supporting parts.

## Materials

The Pebble Pip color fix is followed: every material has an embedded albedo PNG wired to Base
Color, UV0 on every mesh, and white base-color multipliers. The GLBs use **no glTF extensions**.

- Flat colors use a 16×4 swatch. Gradients (Shell Scribe's hood, Jelly Jive's bell, Pearl
  Regent's shell) use a 64×4 ramp with UVs mapped along height or distance from the scallop hinge.
- Bubble Bean's bubble is exported at 38% alpha. Everything else is opaque.
- Pearl Regent's gold uses metallic 0.85, roughness 0.32.
- Render-only garnish (coat, thin-film iridescence, subsurface on Jelly Jive, the soap-film bubble
  look) is added after export and does not reach the GLB. Studio will show the flat albedo and
  roughness. Pearlescent sheen and jelly translucency, if wanted in game, need a SurfaceAppearance
  or Transparency decision during Studio acceptance.

## Axes and scale

Blender: forward -Y, up +Z, 1 unit = 1 stud. The GLB uses glTF Y-up (forward +Z). As with Pebble Pip,
check facing after import and, if needed, rotate the whole Model 180° about Y around the ground
pivot. Final shelf and display scale is a Studio acceptance decision.

## Known differences from the sheets

- Ripple Ray is the least exact. Its wings are thick, swept, mint-over-cream horns with spots and
  read correctly from front, side and back, but they are narrower in planform than the sheet's hero
  image. The sheet's own views disagree on the wing's broadness, so this follows the turnaround views.
- Bubble Bean's bubble is a solid transparent mesh (simple for Roblox), not a thin film.
- Tiny sparkle speckles on the Shell Scribe hood and Jelly Jive bell are omitted: they would be
  microscopic geometry. The speckle-free palette colors match.
- Expressions: only the default expression from each hero render is modelled.

## Roblox upload and runtime wiring

Uploaded with `python scripts/upload_assets.py bubble_bean coral_cuddle shell_scribe jelly_jive
ripple_ray pearl_regent` (creator user 103346374). IDs are recorded in `assets/uploads.json` and the
generated `src/shared/AssetIds.luau`:

| Catalog ID | Semantic key | Model asset ID |
| --- | --- | --- |
| `tide.bubble` | `Models.TidepoolTales.BubbleBean` | 133206366502054 |
| `tide.coral` | `Models.TidepoolTales.CoralCuddle` | 97988350261409 |
| `tide.shell` | `Models.TidepoolTales.ShellScribe` | 96721580926536 |
| `tide.jelly` | `Models.TidepoolTales.JellyJive` | 93788585590607 |
| `tide.ray` | `Models.TidepoolTales.RippleRay` | 85804505305548 |
| `tide.pearl` | `Models.TidepoolTales.PearlRegent` | 140650013990266 |

At server start `ModelAssets` loads each one and normalizes it once. It checks the part count and
the authored proportions (which catches a wrong up-axis), turns the eyes toward -Z, scales it by
`FigureAssets.scale` (0.8, so the tallest figure is about 2.7 studs and Ripple Ray about 3.1 studs
wide), sets the pivot to the centre of the base, makes the bubble 55% transparent, and publishes it
to `ReplicatedStorage.ProductionModels.Figures.<catalog id>`. Every consumer (Display counter,
Collection shelves, Collection/Display/Shop/Shelves previews, the unboxing reveal) goes through
`FigureModel.create`, so all of them show the real figures. Placeholders stay until a template is
ready, then swap in. A failed or invalid load keeps the placeholder and records
`<Root>Status` / `<Root>Reason` attributes on `ProductionModels.Figures`.

### Studio acceptance checklist

1. Play Solo and check the Output window for `Figure model load failed` or `validation failed`.
   `ReplicatedStorage.ProductionModels.Figures` should show six `…Status = Ready` attributes.
2. Confirm each figure faces the player on the Display counter and shelves, stands on the surface,
   and has its colors (not near-white). Check the bubble's transparency and Pearl Regent's gold.
3. Open Collection: discovered figures show in color, undiscovered ones as grey silhouettes.
4. Unbox a Tidepool box and check the reveal framing.
5. Run a two-player test to confirm the templates replicate and visitors see the same figures.
