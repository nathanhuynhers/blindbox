# Concepts production receipt

**Status: uploaded to Roblox and wired into the game (figures, catalog, economy, Shop theme and
collection artwork). Loaded in-game through `ModelAssets` and `FigureModel`; not yet verified in a
Studio playtest.**

Five figures reconstructed from the approved character sheets in each figure's `reference/` folder:

| Figure | Catalog ID | Rarity | MeshParts | Triangles | Size W × D × H (studs) | Largest mesh |
| --- | --- | --- | ---: | ---: | --- | ---: |
| Verity | `concept.verity` | Common | 3 | 16,798 | 2.20 × 2.23 × 2.15 | Body 12,000 |
| Falsity | `concept.falsity` | Uncommon | 3 | 16,798 | 2.20 × 2.23 × 2.15 | Body 12,000 |
| Cruelty | `concept.cruelty` | Rare | 4 | 30,396 | 2.20 × 2.20 × 2.15 | Body 12,000 |
| Lovity | `concept.lovity` | Legendary | 5 | 26,496 | 2.95 × 2.20 × 2.79 | Body 12,000 |
| Verity True Form | `concept.verity-true-form` | Mythical | 5 | 40,198 | 0.79 × 0.62 × 3.42 | Body 18,998 |

MeshParts per figure (all prefixed `<Figure>_`):

- **Verity:** Body 12,000 · Eyes 2,398 · Mouth 2,400
- **Falsity:** Body 12,000 · Eyes 2,398 · Mouth 2,400
- **Cruelty:** Body 12,000 · Eyes 2,400 · Mouth 3,998 (painted crescent) · Teeth 11,998
- **Lovity:** Body 12,000 · Eyes 2,398 · EyeShine 700 · Mouth 2,398 · Hearts 9,000 (four floating hearts)
- **Verity True Form:** Body 18,998 (torso, neck, arms, legs, feet) · Head 9,000 · Hands 9,000 · Eyes 1,600 · Mouth 1,600

Per-figure folders follow the runbook layout (`model/` GLB and production `.blend`, `renders/`
PNG + WebP, `validation/` report, `reference/` sheet). `concepts_lineup.png` shows all five at true
relative scale.

## How the figures are built

[figures.py](figures.py) defines each figure as signed-distance fields on the shared
[tools/figures/](../../../tools/figures/) pipeline.

- **Sphere family:** one 2.2-stud glossy sphere on a small flat contact patch. Face shapes are
  measured from each sheet's FRONT view and projected along Y (`front`, `smile2`, `oval_eyes`).
  Faces are lifted 0.06 studs (`FACE_LIFT`) because the build and in-game cameras look down on the
  figure; this keeps the eyes on the visual centre, as in each hero render.
- **Cruelty's grin** is a crescent between two circular arcs: a painted black outline, then a raised
  white teeth skin cut by a row seam and tooth gaps (lower row offset half a tooth).
- **Lovity's hearts** are pillow hearts (`puffy_heart`, a 2D heart profile with fully rounded rim)
  placed from the FRONT view, with depth from the SIDE and 3/4 views, and yawed 28–42° so they read
  from the side as well as the front. They are free-floating; the runtime anchors every part.
- **Verity True Form** is a hunched, long-limbed figure: rib ridges sweep down the cage, spine
  bumps run down the back, sunken eye sockets, the head is pitched 20° forward and tipped 12°
  toward the character's right, and arms reach mid-thigh.

```
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- concepts <figure> final
python tools/figures/publish.py concepts verity falsity cruelty lovity verity-true-form
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- concepts lineup
```

The final builds were run first so the 1000 px renders could be checked against the sheets before
anything uploaded; `publish.py` then reused those builds (no `--build`).

## Geometry checks (all five)

- Every MeshPart is a closed, manifold shell with positive volume: no boundary edges, no
  non-manifold edges, no zero-area faces.
- Every MeshPart is under Roblox's 20,000-triangle limit. The largest is 18,998 (True Form body).
- Smooth shading, ground pivot at Z = 0 on the centreline, flat contact patches / soles.
- GLB re-import: mesh count and per-mesh triangle counts match exactly for every figure.

## Materials

Embedded albedo PNGs on every material, no glTF extensions, everything opaque. Albedo follows each
sheet's palette: Verity `#F7CF16`, Falsity `#1D6EEA`, Cruelty `#E8141A` with `#F3EEE6` teeth,
Lovity `#F56BA4` with `#5E0A22` eyes and `#F2336C` hearts, True Form `#BEA862` with `#0D0C0A` eyes.
The catalog colors you supplied (`#FFEB3B`, `#1E90FF`, `#E91E1E`, `#FF1493`, `#D4AF37`) are used
for catalog/UI identity only; the models follow the sheets.

Renders use `Khronos PBR Neutral` at −0.9 EV (`RENDER_VIEW`), because AgX washed the saturated
vinyl toward pastel. Under the render lights the True Form looks lighter than its khaki albedo.

## Axes and scale

Spheres are 2.15 tall. Lovity is 2.95 wide with its hearts. True Form is 3.42 tall, the top of the
established range. The shared `FigureAssets.scale` (0.8), Display and shelf spacing were not changed.

## Known differences from the sheets

- **Verity True Form is the least exact.** Its anatomy is simplified: smooth limbs, fewer muscle
  and tendon details, ribs as regular ridges, and fingers that read as a slim mitten at game scale.
  The sheet's views disagree on the head tilt, so it uses the FRONT view's tilt. The head is
  tilted but kept on the centreline (the sheet also shifts it toward the character's right).
  `ModelAssets` faces each figure from its bounds centre toward the `_Eyes` part, and the
  off-centre head turned the first upload (asset 113015697640282, superseded) 16° sideways, which
  pushed its depth ratio to the edge of the ±20% check, and it showed the placeholder in game.
  The replacement faces within 4° of straight with a 6% depth difference. Skin texture
  (surface pores) is omitted.
- **Lovity:** the four hearts follow the FRONT view. The sheet's other views place them
  inconsistently (and always face-on), which no single rigid arrangement can match. **The Lovity
  sheet with hearts was attached inline only, so `lovity/reference/lovity_sheet.webp` is still the
  earlier heart-less sheet.** Drop the new sheet there.
- Cruelty's eyes and grin are clean shapes. The sheet's brush-stroke edges are omitted.
- Expressions: only each sheet's default expression is modelled.

## Collection artwork

Rendered from the production models by [ui_art.py](ui_art.py) (transparent 1254×1254 PNGs, same
contract as Pocket Grove and Tidepool Tales):

- Emblem: Verity inside a tilted gold orbit carrying Falsity, Cruelty and Lovity.
- Four corners, each laid out in its own corner with upright faces: a gold swoosh, the four sphere
  concepts, and sparkles.
- Shop pattern: a seamlessly wrapping scatter of the four spheres, gold sparkles and dots.

## Roblox upload and runtime wiring

Creator user 103346374. IDs are in `assets/uploads.json` and the generated `src/shared/AssetIds.luau`.
`src/shared/FigureAssetEntries.luau` was regenerated.

| Catalog ID / use | Semantic key | Asset ID |
| --- | --- | --- |
| `concept.verity` | `Models.Concepts.Verity` | 109372339520223 |
| `concept.falsity` | `Models.Concepts.Falsity` | 96309730880296 |
| `concept.cruelty` | `Models.Concepts.Cruelty` | 89159574176340 |
| `concept.lovity` | `Models.Concepts.Lovity` | 81477041201834 |
| `concept.verity-true-form` | `Models.Concepts.VerityTrueForm` | 119788043148480 |
| Tab emblem | `Collection.Concepts.Emblem` | 123227463141624 |
| Shop pattern | `Collection.Concepts.ShopPattern` | 117202962378521 |
| Book corner top left | `Collection.Concepts.CornerTopLeft` | 110567541144322 |
| Book corner top right | `Collection.Concepts.CornerTopRight` | 137938464993853 |
| Book corner bottom left | `Collection.Concepts.CornerBottomLeft` | 127603092899733 |
| Book corner bottom right | `Collection.Concepts.CornerBottomRight` | 91589004947316 |

Code wiring for the new collection (`concept`):

- `Catalog.luau`: collection `concept`, shown in game as "Verities" with the tagline
  "All the Verities!", and the five figures.
- `Economy.luau`: rates 1 / 3 / 7 / 12 / 18 and weights 20 / 15 / 10 / 8 / 3. Weights total 56, so
  in-box odds are 35.7 / 26.8 / 17.9 / 14.3 / **5.4%** (the sheet labels Mythical 0.1%).
- `ShopTheme.luau` (your palette), `CollectionStyle.luau` (book colors from the same palette, neutral
  `spark` motif), `CollectionAssets.luau` + `AssetManifest.luau` (emblem, corners, pattern keys),
  `OpeningConfig.luau` (packaging entry; generic `mote` opening motif).
- `tools/figures/publish.py`: the catalog-ID gate now accepts hyphenated figure IDs
  (`concept.verity-true-form`), with tests.
- Tests that hardcoded two six-figure collections now derive counts from the catalog. The golden
  live-economy table in `Rarity.spec.luau` lists the Concepts rows explicitly.

## Repository checks

StyLua check, Selene (0 errors, 0 warnings), every Luau suite, the pipeline tests (28 passed) and
the Rojo build all passed after the final wiring. No Studio playtest was run.

### Studio acceptance checklist

1. Sync with Rojo, Play Solo, and check Output for `Figure model load failed` or `validation failed`.
   `ReplicatedStorage.ProductionModels.Figures` should show `VerityStatus`, `FalsityStatus`,
   `CrueltyStatus`, `LovityStatus` and `VerityTrueFormStatus` = `Ready`.
2. On Display and shelves, each figure faces the player and rests on its surface. Lovity's hearts
   float around it, and True Form's thin limbs and dark eye sockets read at game scale.
3. Shop: the Concepts box shows the gold theme, emblem and pattern, and lists five tiers.
4. Collection: Concepts tab emblem and corners, discovered figures in color, undiscovered as grey
   silhouettes. Check that Lovity's hearts and True Form's height are not clipped in portraits.
5. Unbox Concepts boxes and check the reveal framing, especially True Form (tallest) and Lovity
   (widest).
6. Run a two-player test to confirm visitors see the same figures.
