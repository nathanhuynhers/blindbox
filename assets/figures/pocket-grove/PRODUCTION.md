# Pocket Grove production receipt

**Status: uploaded to Roblox and wired into the game. Loaded in-game through `ModelAssets` and
`FigureModel`; not yet verified in a Studio playtest.**

Six figures reconstructed from the approved character sheets in each figure's `reference/` folder:

| Figure | Catalog ID | Rarity | MeshParts | Triangles | Size W × D × H (studs) | Largest mesh |
| --- | --- | --- | ---: | ---: | --- | ---: |
| Pebble Pip | `grove.pebble` | Common | 8 | 28,796 | 2.13 × 2.02 × 3.25 | Head 11,000 |
| Sprout Scout | `grove.sprout` | Common | 14 | 47,588 | 2.84 × 1.89 × 3.25 | Head 11,000 |
| Acorn Dot | `grove.acorn` | Common | 10 | 43,492 | 2.44 × 2.24 × 2.89 | Cap 16,000 |
| Mallow Cap | `grove.mushroom` | Uncommon | 7 | 46,566 | 3.41 × 3.15 × 2.90 | Cap / Body 14,000 |
| Moon Moth | `grove.moth` | Uncommon | 12 | 63,984 | 3.14 × 1.54 × 3.43 | Wings 14,000 |
| Sunbeam Sprite | `grove.star` | Rare | 11 | 60,038 | 3.63 × 2.40 × 3.39 | Petals 17,942 |

MeshParts per figure (all prefixed `<Figure>_`):

- **Pebble Pip:** Head 11,000 · Body 7,000 · Clover 6,000 · CloverStem 1,600 · Eyes 1,398 · EyeShine 400 · Cheeks 898 · Mouth 500
- **Sprout Scout:** Head 11,000 · Body 8,998 · Sprout 8,000 · Scarf 4,998 · Strap 3,000 · Bag 2,500 · BagFlap 1,998 · Buckle 400 · Staff 2,498 · StaffLeaf 1,000 · Eyes 1,398 · EyeShine 400 · Cheeks 898 · Mouth 500
- **Acorn Dot:** Cap 16,000 · CapLeaf 800 · Head 9,998 · Body 8,000 · Acorn 2,500 · AcornCap 2,998 · Eyes 1,398 · EyeShine 400 · Cheeks 898 · Mouth 500
- **Mallow Cap:** Cap 14,000 · Gills 11,970 · Spots 4,000 · Body 14,000 (head, ears, arms and legs) · Eyes 1,198 · Cheeks 898 · Mouth 500
- **Moon Moth:** Head 8,998 · Face 4,000 · Ears 3,998 · EarInner 2,400 · Antennae 5,998 · Wings 14,000 · WingInner 9,998 · WingMarks 4,000 · Body 7,998 · Eyes 1,198 · Cheeks 898 · Mouth 498
- **Sunbeam Sprite:** Head 11,000 · Ears 4,000 · Petals 17,942 · Braid 5,000 · Crown 4,998 · Orb 3,000 · OrbSun 2,500 · Body 9,000 · Eyes 1,200 · Cheeks 898 · Mouth 500

Per figure folder (`<slug>/`):

- `model/<slug>_roblox.glb`: the import file. One root node named after the figure (for example
  `SproutScout`) with one child mesh per MeshPart.
- `model/<slug>_production.blend`: the same meshes and materials, for inspection or hand edits.
- `renders/`: `front`, `three_quarter`, `side`, `back` inspection renders and a `beauty` render,
  as PNG (transparent, with shadow) and WebP.
- `validation/<slug>_validation.json`: per-mesh audit, build timings, GLB summary and re-import check.
- `reference/<slug>_sheet.png`: the approved sheet the model was matched against.

`pocket_grove_lineup.png` shows all six side by side at true relative scale. The presentation
canvas (overview plus one board per figure) is https://claude.ai/artifact/UoCn91obDsrvmWHswRaRR1.

## How the figures are built

[figures.py](figures.py) defines each figure as signed-distance fields, using the shared
[tools/figures/](../../../tools/figures/) pipeline and the Tidepool Tales helpers (copied per the
runbook). Two Pocket Grove additions live in `figures.py`:

- `Leaf`: a pillowy blade with fully rounded edges (edge radius = half thickness, so nothing is
  paper-thin), plus bend, cup, midrib crease and optional scalloped outline. It builds the clover
  leaflets, sprout leaves, staff leaf, petals, lop ears, antennae and Moon Moth's wings.
- `face(...)` gained closed-eye variants: `sleepy` arcs (Mallow Cap, Moon Moth) and `happy` arcs
  (Sunbeam Sprite), each with a lash flick. Open eyes (Pebble Pip, Sprout Scout, Acorn Dot) keep
  the collection's domed dark oval with a white highlight.

Shared collection conventions: eye gloss `#35251F`, blush `#F4A7A0`, mouth `#4A2E26`, cheeks
outside and below the eyes, flat soles at Z = 0, accessories 0.08 studs or thicker.

```
python tools/figures/publish.py pocket-grove pebble-pip sprout-scout acorn-dot mallow-cap moon-moth sunbeam-sprite --build
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- pocket-grove lineup
```

Figure names are passed explicitly because `pebble-pip/validation/` still holds a legacy
`glb_validation.json` that also matches the publisher's report glob (see Pebble Pip below).

## Geometry checks (all six)

- Every MeshPart is a closed, manifold shell with positive volume. No boundary edges, no
  non-manifold edges, no zero-area faces. Loose specks under 24 faces are removed.
- Every MeshPart is under Roblox's 20,000-triangle limit. The largest is 17,942 (Sunbeam petals).
- Smooth shading, identity transforms, ground pivot at Z = 0 on the centreline, flat soles.
- GLB re-import: mesh count and per-mesh triangle counts match exactly for every figure.
- Parts intentionally interpenetrate (limbs into bodies, skins over surfaces). Nothing floats:
  the clover stem, sprout, staff, bag, cap, held acorn, antennae, wings, petals, braid, crown and
  orb all intersect their supporting parts.

## Materials

Every material has an embedded albedo PNG wired to Base Color, UV0 on every mesh and white
multipliers (Studio imports factor-only glTF colors near-white). The GLBs use **no glTF
extensions**. Everything is opaque (no glass parts).

- Flat colors use a 16×4 swatch; Moon Moth's wings and Sunbeam Sprite's petals use 64×4 ramps
  (wing lavender→purple by height, petals amber→yellow from the flower centre outward).
- Albedo is taken from each sheet's PALETTE swatches, nudged only where the swatch read differently
  from the hero render (brighter clover green, deeper acorn-cap brown, golden petals).
- Sunbeam's crown uses metallic 0.7, roughness 0.3; Sprout's buckle metallic 0.6.
- Render-only garnish (clear coat) does not reach the GLB.
- **Renders use `Khronos PBR Neutral` at −1.1 EV** (`RENDER_VIEW` in `figures.py`), not the
  Tidepool AgX look: AgX desaturated this pastel palette almost to white, so the neutral transform
  shows the albedo Roblox will actually receive. Studio lighting will still differ from the renders.

## Axes and scale

Blender: forward −Y, up +Z, 1 unit = 1 stud. The GLB uses glTF Y-up. Authored heights 2.89–3.43
studs, in the established collectible range; the shared `FigureAssets.scale` (0.8), Display
spacing and shelf spacing were **not** changed. Sunbeam Sprite (3.63 wide) and Mallow Cap
(3.41 wide) are the widest; at 0.8 scale they present at about 2.9 and 2.7 studs, within the
3.6-stud shelf spacing (Tidepool's Ripple Ray is 3.89 wide).

## Pebble Pip replacement

The earlier hand-built Pebble Pip (21 `PP_*_Export` nodes, never uploaded or adopted) is
superseded. The new model was rebuilt from the approved sheet with this pipeline and overwrote
`pebble-pip/model/pebble_pip_production.blend`, `pebble_pip_roblox.glb` and the four inspection
renders. The manifest alias `pebble_pip` / key `Models.PocketGrove.PebblePip` now lists the new
nodes, it was uploaded for the first time (asset 76559793748219), and `grove.pebble` resolves to it
in `FigureAssetEntries.luau`. There is only one Pebble Pip runtime entry.

Legacy files from the old model are **still on disk** because deleting them was not authorized in
this pass: `model/pebble_pip_master.blend`, `model/textures/`, `reference/pebble_pip_concept.png`,
and the old `validation/` artifacts (`glb_validation.json`, `master_*`, `reimport_*`,
`material_fix.json`, `production_audit.json`, `approved_live_snapshot.blend`,
`pebble_pip_color_factor_only.glb`), plus Blender's `pebble_pip_production.blend1` backup of the old
production file. None is referenced by the manifest or runtime; git history preserves them, so they
can be removed.

## Known differences from the sheets

- **Mallow Cap is the least exact.** Its cap is a rounded bell, where the sheet's cap rises to a
  slightly peaked cone. The sheet's front view also shows a wide band of cream gills under the
  front rim. The model tips the cap back 21° with ribbed cream gills, but from the standard slightly
  raised camera only a narrow gill band shows; the full underside reads from low or 3/4 angles. The
  sheet's front view has the feet splayed wider to the sides.
- Moon Moth's wings are cupped lobes that wrap from the back to the sides. From the pure side view
  they read narrower than the sheet's broad side lobe. The hero's crescent-moon seat is scenery and
  is not modelled (the views show her standing).
- Pebble Pip's clover trefoil faces front-and-up, matching the hero, front and 3/4 views. The sheet's
  side and back views also show a full trefoil, which no single flat clover can do, so from the side
  it reads as a tilted fan.
- Sunbeam Sprite uses the hero's happy closed eyes (^ ^), per the runbook's rule to model the hero's
  default expression. The front and 3/4 views show a wink. The petal halo is flatter and the braid
  sits over the back petals so both views read.
- Acorn Dot: the brown tufts beside the feet in the front and back views are not modelled (absent
  from the hero and side view, and not a readable form). The small round ears are subtle side lobes
  under the cap rim.
- Sprout Scout's leaf tips are slightly more pointed than the sheet's; the back view's curled
  tendril on the right leaf is omitted.
- Omitted as microscopic: Pebble Pip's stone speckles and moss fleck, the acorn cap's inner
  cross-hatching within each scale, knit texture on the scarf, leather stitching, wing sparkle
  speckles (replaced by six readable gold dots per wing), antenna fuzz.
- Expressions: only each hero's default expression is modelled.

## Roblox upload and runtime wiring

Uploaded by `publish.py` (creator user 103346374). IDs are recorded in `assets/uploads.json` and the
generated `src/shared/AssetIds.luau`; `src/shared/FigureAssetEntries.luau` was regenerated:

| Catalog ID | Semantic key | Model asset ID |
| --- | --- | --- |
| `grove.pebble` | `Models.PocketGrove.PebblePip` | 76559793748219 |
| `grove.sprout` | `Models.PocketGrove.SproutScout` | 122774967155364 |
| `grove.acorn` | `Models.PocketGrove.AcornDot` | 108614572737539 |
| `grove.mushroom` | `Models.PocketGrove.MallowCap` | 108811295282720 |
| `grove.moth` | `Models.PocketGrove.MoonMoth` | 112900779762440 |
| `grove.star` | `Models.PocketGrove.SunbeamSprite` | 89097067357395 |

No runtime code changed for this collection: `ModelAssets` loads each entry, validates parts and
proportions, turns the eyes toward −Z, scales by `FigureAssets.scale`, and publishes it to
`ReplicatedStorage.ProductionModels.Figures.<catalog id>` for Display, shelves, Collection previews
and the unboxing reveal.

## Repository checks (run by the publisher)

StyLua check, Selene (0 errors, 0 warnings), every Luau suite, the pipeline tests
(`test_asset_pipeline.py`, `test_figure_publish.py`: 26 passed) and the Rojo build all passed.
The upload dry run validated all six GLBs and their semantic nodes first. No Studio playtest was run.

### Studio acceptance checklist

1. Sync with Rojo, Play Solo and check the Output window for `Figure model load failed` or
   `validation failed`. `ReplicatedStorage.ProductionModels.Figures` should show `PebblePipStatus`,
   `SproutScoutStatus`, `AcornDotStatus`, `MallowCapStatus`, `MoonMothStatus` and
   `SunbeamSpriteStatus` = `Ready` (plus the six Tidepool ones).
2. On the Display counter and shelves, each Pocket Grove figure faces the player, stands flat on the
   surface, and shows its palette (not near-white). Check Sunbeam's gold crown and that nothing is
   unexpectedly transparent.
3. Open Pocket Grove in Collection: discovered figures in color, undiscovered as grey silhouettes.
   Check Mallow Cap's and Sunbeam Sprite's wide silhouettes are not clipped in portrait previews.
4. Unbox Pocket Grove boxes and check the reveal framing, especially Moon Moth's antennae (tallest,
   3.43) and Sunbeam's petal halo (widest, 3.63).
5. Run a two-player test to confirm the templates replicate and visitors see the same figures.
