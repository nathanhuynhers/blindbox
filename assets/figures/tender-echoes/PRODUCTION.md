# Tender Echoes production receipt

**Status: uploaded to Roblox and wired into the game (figures, catalog, economy, Shop theme and
collection artwork). Loaded in-game through `ModelAssets` and `FigureModel`; not yet verified in a
Studio playtest.**

Thirteen figures reconstructed from the approved character sheets in each figure's `reference/`
folder:

| Figure | Catalog ID | Rarity | MeshParts | Triangles | Size W × D × H (studs) | Largest mesh |
| --- | --- | --- | ---: | ---: | --- | ---: |
| Thread Parade | `echo.thread-parade` | Common | 36 | 70,462 | 2.18 × 2.19 × 3.24 | Hair 9,744 |
| Wander Knit | `echo.wander-knit` | Common | 30 | 54,824 | 2.04 × 1.73 × 3.26 | Beanie 8,804 |
| Dino Drift | `echo.dino-drift` | Common | 25 | 55,174 | 1.85 × 2.22 × 3.39 | Coat 9,000 |
| Still Pebble | `echo.still-pebble` | Common | 31 | 67,966 | 2.10 × 1.94 × 2.96 | Beanie 9,022 |
| Hearth Helm | `echo.hearth-helm` | Uncommon | 29 | 67,180 | 2.22 × 2.10 × 3.51 | Roof 9,576 |
| Echo Line | `echo.echo-line` | Uncommon | 31 | 61,284 | 2.17 × 1.90 × 3.47 | Hair 9,730 |
| Paper Crown | `echo.paper-crown` | Uncommon | 30 | 63,052 | 2.11 × 1.96 × 3.15 | Hair 9,748 |
| Mask Nuzzle | `echo.mask-nuzzle` | Rare | 40 | 85,234 | 2.09 × 2.02 × 3.37 | Hood 8,000 |
| Hush Veil | `echo.hush-veil` | Rare | 24 | 52,058 | 2.65 × 2.15 × 3.14 | Blanket 9,748 |
| Crate Spark | `echo.crate-spark` | Rare | 27 | 63,534 | 2.36 × 2.12 × 3.57 | Hair 9,724 |
| Feather Hush | `echo.feather-hush` | Legendary | 32 | 73,720 | 2.21 × 2.34 × 3.20 | HoodFeathers 9,702 |
| Mumble Beast | `echo.mumble-beast` | Legendary | 25 | 55,312 | 2.27 × 1.95 × 3.36 | Suit 9,742 |
| Moon Doze | `echo.moon-doze` | Mythical | 24 | 66,484 | 2.52 × 2.19 × 3.09 | Cloud 9,748 |

836,284 triangles in all. Every figure's parts are listed in its `validation/` report. Per-figure
folders follow the runbook layout (`model/` GLB and production `.blend`, `renders/` PNG + WebP,
`validation/` report, `reference/` sheet). `tender_echoes_lineup.png` shows all thirteen at true
relative scale in catalog order.

## How the figures are built

[figures.py](figures.py) defines each figure as signed-distance fields on the shared
[tools/figures/](../../../tools/figures/) pipeline. Unlike the earlier mascot collections these are
chibi children, so the file opens with a shared kit, measured from the standing sheets (about
3.3 studs tall, eyes at Z 1.95):

- `Head`: porcelain head with full low cheeks, small chin and a neck stub.
- `kid_face`: heavy-lidded eyes glancing toward the viewer's right, upper lashes with a flick,
  small brows, nose nub, pout and blush, all thin skins on the head; `closed=True` for Moon Doze.
  **The symmetric eye whites are the `_Eyes` part** used for runtime facing; the off-centre irises
  are `_Iris`, so the glance does not turn the figure.
- `Hair` (lock-tipped cap with grooves, strands and a face opening), `fringe` (individual bang
  locks), `lock_mop` (messy seeded locks) and `curl`.
- `knit`, `rib`, `boucle`, `shingles`, `coil` (telephone cord), `star2`, `bow`, `footprint2`:
  surface reliefs and accessories shared across figures.
- `standing_feet`, `SeatedLegs`, `arm_parts`, `shoe`, `sock`: limbs, socks and clogs.
- `pose_comps` turns a finished group rigidly (Still Pebble's tilted head).
- `TRI_SCALE` (0.5) halves every part's authored budget at assembly, keeping each figure at
  52–85k triangles. The first full builds were 98–170k; renders at half budget were checked
  against the full ones and kept the knit, hair and stitch detail.

```
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- tender-echoes <figure> final
python tools/figures/publish.py tender-echoes <figure> [...] --no-checks
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- tender-echoes lineup
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python assets/figures/tender-echoes/ui_art.py
```

The final builds ran first (four at a time) so the 1000 px renders could be checked against the
sheets before anything uploaded; `publish.py` then reused those builds. The repository checks it
skips with `--no-checks` were run separately afterwards (below).

## Geometry checks (all thirteen)

- Every MeshPart is a closed, manifold shell with positive volume: no boundary edges, no
  non-manifold edges, no zero-area faces. Hush Veil's dashed edge stitch first decimated into
  non-manifold slivers; it now uses rounder, thicker dashes and passes.
- Every MeshPart is under Roblox's 20,000-triangle limit; the largest is 9,748.
- GLB re-import: mesh count and per-mesh triangle counts match exactly for every figure.
- Runtime facing, predicted from `ModelAssets.prepareFigure` (bounds centre to `_Eyes` centre):
  every figure turns 4.2° or less, with no X/Z proportion drift beyond 1%.

## Materials

Embedded albedo PNGs on every material, no glTF extensions, everything opaque (no glass). Albedo
follows each sheet's palette (swatches per figure on the canvas). The hex colors you supplied are
used for catalog identity only. Renders use `Khronos PBR Neutral` at −1.1 EV (`RENDER_VIEW`), as
Pocket Grove does, because AgX washed the pastels toward white.

## Axes and scale

2.96 (Still Pebble, seated) to 3.57 studs tall (Crate Spark, with the party hat). Widths
1.85–2.65. All within the established range; `FigureAssets.scale` (0.8), Display and shelf spacing
were not changed.

## Known differences from the sheets

- **Hush Veil is the least exact.** The blanket's folds are shallower and more regular than the
  sheet's heavy drape, and its side locks are tucked inside the blanket rather than spilling out.
- **Thread Parade and Mask Nuzzle are modelled standing.** Their hero renders are seated, but all
  four orthographic views show them standing, and the runbook says the views win.
- **Still Pebble's sheet disagrees with itself:** its FRONT view is mirrored against the hero, 3/4
  and back views. The model follows the majority (dino plush on the character's right, scarf tail
  on the left).
- Fabric surfaces (fleece, boucle, felt, knit) are sculpted reliefs, not fibres: Dino Drift's and
  Moon Doze's fleece read smoother than the sheets; Mumble Beast's boucle and the knit beanies
  read closest.
- Faces are a shared construction; individual expressions differ through brow tilt, lid height
  and glance, not unique eye shapes. Only each sheet's default expression is modelled.
- Small print details are simplified: Paper Crown's crown doodles, the pouch face, and button
  holes are single skins.

## Collection artwork

Rendered from the production models by [ui_art.py](ui_art.py) (transparent 1254×1254 PNGs, same
contract as the earlier collections):

- Emblem: Wander Knit standing inside a wooden embroidery hoop, with felt stars and cross-stitches.
- Four corners, each laid out in its own corner with upright figures (Hearth Helm, Paper Crown,
  Still Pebble, Moon Doze), a dashed terracotta running stitch, felt stars and cross-stitches.
- Shop pattern: a seamlessly wrapping scatter of ten figures, felt stars and cross-stitches.

## Roblox upload and runtime wiring

Creator user 103346374. IDs are in `assets/uploads.json` and the generated
`src/shared/AssetIds.luau`. `src/shared/FigureAssetEntries.luau` was regenerated.

| Catalog ID / use | Semantic key | Asset ID |
| --- | --- | --- |
| `echo.thread-parade` | `Models.TenderEchoes.ThreadParade` | 99929948140391 |
| `echo.wander-knit` | `Models.TenderEchoes.WanderKnit` | 74450401894243 |
| `echo.dino-drift` | `Models.TenderEchoes.DinoDrift` | 111538227099957 |
| `echo.still-pebble` | `Models.TenderEchoes.StillPebble` | 109753811133527 |
| `echo.hearth-helm` | `Models.TenderEchoes.HearthHelm` | 92497511806284 |
| `echo.echo-line` | `Models.TenderEchoes.EchoLine` | 73170948668337 |
| `echo.paper-crown` | `Models.TenderEchoes.PaperCrown` | 90215258574522 |
| `echo.mask-nuzzle` | `Models.TenderEchoes.MaskNuzzle` | 121583876971898 |
| `echo.hush-veil` | `Models.TenderEchoes.HushVeil` | 92687355906820 |
| `echo.crate-spark` | `Models.TenderEchoes.CrateSpark` | 91143941429865 |
| `echo.feather-hush` | `Models.TenderEchoes.FeatherHush` | 103421071507922 |
| `echo.mumble-beast` | `Models.TenderEchoes.MumbleBeast` | 114114339910710 |
| `echo.moon-doze` | `Models.TenderEchoes.MoonDoze` | 71309632580103 |
| Tab emblem | `Collection.TenderEchoes.Emblem` | 133211070991916 |
| Shop pattern | `Collection.TenderEchoes.ShopPattern` | 106427566156643 |
| Book corner top left | `Collection.TenderEchoes.CornerTopLeft` | 134104301979046 |
| Book corner top right | `Collection.TenderEchoes.CornerTopRight` | 109232671065272 |
| Book corner bottom left | `Collection.TenderEchoes.CornerBottomLeft` | 128974677022896 |
| Book corner bottom right | `Collection.TenderEchoes.CornerBottomRight` | 127063035897430 |

Code wiring for the new collection (`echo`):

- `Catalog.luau`: collection `echo`, "Tender Echoes", "Gentle souls learning to move through the
  world with small, brave hearts", and the thirteen figures with your hex colors.
- `Economy.luau`: your rates and weights. Weights total 173, so in-box odds per figure are
  Common 11.6%, Uncommon 8.7%, Rare 5.8%, Legendary 4.6%, Mythical **1.2%**. The Common, Uncommon
  and Rare rates sit inside the enforced bands, and every tier's rates exceed the tier below.
- `ShopTheme.luau` (your five theme colors), `CollectionStyle.luau` (book colors from the same
  palette, neutral `spark` motif), `CollectionAssets.luau` + `AssetManifest.luau` (emblem, corners,
  pattern keys), `OpeningConfig.luau` (packaging entry; generic `mote` opening motif).
- `Rarity.spec.luau`: the golden live-economy table lists the Tender Echoes rows explicitly, and the
  per-collection tier and size tables include `echo` (5 tiers, 13 figures).
- `docs/ECONOMY.md` and `docs/ASSET_PIPELINE.md` describe the collection and its aliases.

## Repository checks

StyLua check, Selene (0 errors, 0 warnings), every Luau suite, the pipeline tests (28 passed) and
the Rojo build all passed after the final wiring. No Studio playtest was run.

### Studio acceptance checklist

1. Sync with Rojo, Play Solo, and check Output for `Figure model load failed` or `validation failed`.
   `ReplicatedStorage.ProductionModels.Figures` should show a `…Status` = `Ready` for all thirteen
   (`ThreadParadeStatus` … `MoonDozeStatus`).
2. On Display and shelves, each figure faces the player and rests on its surface; colors are the
   sheet pastels, not near-white. Check the seated figures (Paper Crown, Still Pebble, Moon Doze's
   cloud) sit flat, and that Crate Spark's party hat and Hearth Helm's chimney clear the shelf above.
3. Shop: the Tender Echoes box shows the sage/terracotta theme, emblem and pattern, and lists five
   tiers with the odds above.
4. Collection: Tender Echoes tab emblem and corners; thirteen figures page correctly; discovered
   figures in color, undiscovered as grey silhouettes.
5. Unbox Tender Echoes boxes and check the reveal framing, especially Crate Spark (tallest) and
   Hush Veil (widest).
6. Run a two-player test to confirm visitors see the same figures.
