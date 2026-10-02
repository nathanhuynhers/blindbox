# We Are All Stars production receipt

**Status: uploaded to Roblox and wired into the game (figures, catalog, economy, Shop theme and
collection artwork). Loaded in-game through `ModelAssets` and `FigureModel`; not yet verified in a
Studio playtest.**

Thirteen figures reconstructed from the approved character sheets in each figure's `reference/`
folder. Rarities follow the brief, not the "COMMON" printed on most sheets.

| Figure | Catalog ID | Rarity | MeshParts | Triangles | Size W × D × H (studs) | Largest mesh |
| --- | --- | --- | ---: | ---: | --- | ---: |
| Reminiscence Star | `star.reminiscence` | Common | 24 | 49,988 | 2.16 × 2.03 × 2.50 | Hair 9,602 |
| Mirrorlight Star | `star.mirrorlight` | Common | 26 | 56,202 | 2.20 × 2.08 × 3.27 | Hair 9,662 |
| Wishing Star | `star.wishing` | Common | 26 | 52,754 | 2.26 × 2.23 × 3.46 | Hair 9,680 |
| Page Turner Star | `star.page-turner` | Common | 33 | 65,220 | 2.55 × 2.17 × 3.40 | Hair 9,748 |
| Nightlight Star | `star.nightlight` | Uncommon | 25 | 64,820 | 2.17 × 2.02 × 3.43 | Hair 9,748 |
| Lamplight Star | `star.lamplight` | Uncommon | 28 | 72,022 | 2.94 × 2.21 × 3.51 | Hair 9,746 |
| Garden Star | `star.garden` | Uncommon | 31 | 89,380 | 2.61 × 2.22 × 3.51 | Hair 9,748 |
| Sanctuary Star | `star.sanctuary` | Rare | 30 | 77,708 | 2.80 × 2.81 × 3.59 | Hair 9,678 |
| Echo Star | `star.echo` | Rare | 25 | 59,878 | 2.82 × 2.33 × 3.22 | Hair 9,664 |
| Radiant Star | `star.radiant` | Rare | 28 | 75,234 | 2.57 × 2.13 × 3.34 | Hair 9,746 |
| Cloud Rest Star | `star.cloud-rest` | Legendary | 26 | 59,558 | 2.96 × 2.03 × 3.34 | Hair 9,622 |
| Meteor Shower | `star.meteor-shower` | Legendary | 24 | 75,126 | 2.88 × 1.50 × 3.43 | Skirt 9,490 |
| Dreamcatcher Star | `star.dreamcatcher` | Mythical | 30 | 70,542 | 2.17 × 1.63 × 3.66 | Hair 9,702 |

868,432 triangles in all. Every figure's parts are listed in its `validation/` report. Per-figure
folders follow the runbook layout. `we_are_all_stars_lineup.png` shows all thirteen at true relative
scale in catalog order.

## How the figures are built

[figures.py](figures.py) defines each figure as signed-distance fields on the shared
[tools/figures/](../../../tools/figures/) pipeline. The base kit (`Mat`, `Comp`, `Leaf`, `Head`,
`kid_face`, `Hair`, `fringe`, `lock_mop`, limbs, `assemble` with `TRI_SCALE` 0.5) is copied from
Tender Echoes. `kid_face` gained two options (`iris` size and an upturned `smile`). The series kit
adds:

- `star_head` / `star_face`: this series' face, measured on the Mirrorlight FRONT view: large round
  dark eyes set low, a soft glance toward the viewer's right, lashes with a flick, faint brows, a
  tiny nose, a small smile and blush. **The symmetric eye whites are the `_Eyes` part.**
- `Bob`: hair whose sides hang as a skirt below the cap, with an optional flare, soft horizontal
  `wave` and an outward-curled `roll` at the hem (Mirrorlight, Wishing, Sanctuary, Dreamcatcher).
- `puffy_star`, `faceted_star` (Wishing's low-poly seat), `puffs` (clouds), `Book`, `Daisy`,
  `clover`, `twinkle2` (Nightlight's lampshade print), `star_prints`.
- `Cat`: the recurring little white cat (head, pointed ears, dot or sleeping eyes, nose, mouth,
  blush); each figure builds its own pose around it.
- `scale_comps`: uniform scale for figures whose props run tall at the series head size (Nightlight
  0.82, Garden 0.86, Sanctuary 0.95, Radiant 0.88, Cloud Rest 0.9, Meteor Shower 0.63,
  Dreamcatcher 0.72), so every figure lands at 2.5–3.66 studs.

```
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- we-are-all-stars <figure> final
python tools/figures/publish.py we-are-all-stars <figure> [...] --no-checks
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- we-are-all-stars lineup
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python assets/figures/we-are-all-stars/ui_art.py
```

Final builds ran as a detached queue, four at a time, and the 1000 px renders were checked against
the sheets before upload; `publish.py` reused those builds. `--no-checks` was used because StyLua
stops on a formatting diff in the uncommitted `src/client/OpeningAudioConfig.luau` (opening-audio
work in progress, not part of this collection); every check was run separately (below).

## Geometry checks (all thirteen)

- Every MeshPart is a closed, manifold shell with positive volume: no boundary edges, no
  non-manifold edges, no zero-area faces.
- Every MeshPart is under Roblox's 20,000-triangle limit; the largest is 9,748.
- GLB re-import: mesh count and per-mesh triangle counts match exactly for every figure.
- Runtime facing, predicted from `ModelAssets.prepareFigure` (bounds centre to `_Eyes` centre):
  eleven figures turn 4.1° or less; Echo 5.8° and Cloud Rest 7.8° (her jar and his mobile arch sit
  off-centre). Sanctuary first turned 15.7° because the tilted umbrella shifted the bounds; the
  canopy was re-centred and now turns 1.4°.

## Materials

Embedded albedo PNGs on every material, no glTF extensions. Three see-through parts use albedo alpha
(the runtime applies `glassTransparency`): Sanctuary's clear canopy, Echo's jar and Meteor Shower's
star trails. **Glowing stars are albedo only** (Mirrorlight, Lamplight, Echo): a pale warm yellow
ramp from `#FFF6CF` at the centre to `#F9D774` at the rim, so they read as lit without emission.
Albedo follows each sheet; your hex colors are used for catalog identity. Renders use
`Khronos PBR Neutral` at −1.1 EV (`RENDER_VIEW`), as Pocket Grove and Tender Echoes do.

## Axes and scale

2.50 (Reminiscence, kneeling) to 3.66 studs tall (Dreamcatcher on her stand). Widths 2.16–2.96.
`FigureAssets.scale` (0.8), Display and shelf spacing were not changed.

## Design choices and known differences from the sheets

- **Dreamcatcher's stand (your note):** the sheet hangs her from a rope loop, so she sits on a small
  round wooden base with a slim post that arches over and hooks through the loop, in the hoop's
  darker wood (`#C99863`). The hoop, carved grips, rope wraps, three star-and-feather charms and her
  pose are unchanged. The stand is the only addition and sits behind her.
- **Floating stars:** Meteor Shower's six flying stars and Radiant's two are free parts within the
  figure, as on Lovity; Meteor Shower's trails are translucent.
- **Echo is the least exact.** Her sheet shows a ruffled skirt pooling round kneeling legs; the
  model's dress pools as a smooth flared cone with star prints, and her shoes peek out in front.
- Cloud Rest's curled-up legs sink further into the cloud than on the sheet.
- Reminiscence is modelled with the head tipped 18° (the sheet is steeper) so the face reads from
  the front; her buns sit lower at the sides.
- Hair is sculpted in locks and soft waves, not individual strands; Garden's and Lamplight's hair
  reads straighter than their sheets.
- Small print details are simplified: Reminiscence's board doodles, Wishing's notebook sketches,
  Page Turner's constellations and Radiant's hat stars are single skins.

## Collection artwork

Rendered from the production models by [ui_art.py](ui_art.py) (adapted from the Tender Echoes
script; transparent 1254×1254 PNGs, same contract):

- Emblem: Wishing Star on her star seat inside a soft blue sky ring, with yellow and blush stars.
- Four corners, each laid out in its own corner with upright figures (Sanctuary, Page Turner, Echo,
  Lamplight), a dotted blue shooting-star trail, puffy stars and twinkle dots.
- Shop pattern: a seamlessly wrapping scatter of ten figures, puffy stars and twinkle dots.

## Roblox upload and runtime wiring

Creator user 103346374. IDs are in `assets/uploads.json` and the generated
`src/shared/AssetIds.luau`. `src/shared/FigureAssetEntries.luau` was regenerated.

| Catalog ID / use | Semantic key | Asset ID |
| --- | --- | --- |
| `star.reminiscence` | `Models.WeAreAllStars.Reminiscence` | 130504878326463 |
| `star.mirrorlight` | `Models.WeAreAllStars.Mirrorlight` | 105614547598449 |
| `star.wishing` | `Models.WeAreAllStars.Wishing` | 112630885709193 |
| `star.page-turner` | `Models.WeAreAllStars.PageTurner` | 111663122828184 |
| `star.nightlight` | `Models.WeAreAllStars.Nightlight` | 119163583320627 |
| `star.lamplight` | `Models.WeAreAllStars.Lamplight` | 94070351560106 |
| `star.garden` | `Models.WeAreAllStars.Garden` | 135211187065217 |
| `star.sanctuary` | `Models.WeAreAllStars.Sanctuary` | 74567398331175 |
| `star.echo` | `Models.WeAreAllStars.Echo` | 136744471215309 |
| `star.radiant` | `Models.WeAreAllStars.Radiant` | 98643059757696 |
| `star.cloud-rest` | `Models.WeAreAllStars.CloudRest` | 137863487676817 |
| `star.meteor-shower` | `Models.WeAreAllStars.MeteorShower` | 77397231399682 |
| `star.dreamcatcher` | `Models.WeAreAllStars.Dreamcatcher` | 95975185997814 |
| Tab emblem | `Collection.WeAreAllStars.Emblem` | 137750789220313 |
| Shop pattern | `Collection.WeAreAllStars.ShopPattern` | 84784740115916 |
| Book corner top left | `Collection.WeAreAllStars.CornerTopLeft` | 115295506558442 |
| Book corner top right | `Collection.WeAreAllStars.CornerTopRight` | 75765151187034 |
| Book corner bottom left | `Collection.WeAreAllStars.CornerBottomLeft` | 87828702597323 |
| Book corner bottom right | `Collection.WeAreAllStars.CornerBottomRight` | 129835011701228 |

Code wiring for the new collection (`star`):

- `Catalog.luau`: collection `star`, "We Are All Stars", "Little lights for kinder tomorrows"
  (color `#8FA7CF`), and the thirteen figures with your hex colors.
- `Economy.luau`: your rates and weights. Weights total 173, so in-box odds per figure are
  Common 11.6%, Uncommon 8.7%, Rare 5.8%, Legendary 4.6%, Mythical **1.2%**. Common, Uncommon and
  Rare rates sit inside the enforced bands, and every tier's rates exceed the tier below.
- `ShopTheme.luau` (your five theme colors), `CollectionStyle.luau` (book colors from the same
  palette, `spark` motif), `CollectionAssets.luau` + `AssetManifest.luau` (emblem, corners, pattern
  keys), `OpeningConfig.luau` (packaging entry; generic `mote` opening motif).
- `Rarity.spec.luau`: the golden live-economy table lists the We Are All Stars rows, and the
  per-collection tier and size tables include `star` (5 tiers, 13 figures).
- `docs/ECONOMY.md` and `docs/ASSET_PIPELINE.md` describe the collection and its aliases.

## Repository checks

Selene (0 errors, 0 warnings), all 19 Luau suites, the pipeline tests (30 passed) and the Rojo
build passed after the final wiring. StyLua passes on every file this collection touched; the one
diff it reports is in the uncommitted `src/client/OpeningAudioConfig.luau`. Luau Language Server
diagnostics were not run. No Studio playtest was run.

### Studio acceptance checklist

1. Sync with Rojo, Play Solo, and check Output for `Figure model load failed` or `validation failed`.
   `ReplicatedStorage.ProductionModels.Figures` should show a `…Status` = `Ready` for all thirteen
   (`ReminiscenceStatus` … `DreamcatcherStatus`).
2. On Display and shelves, each figure faces the player and rests on its surface; colors are the
   sheet pastels, not near-white; the glowing stars read pale yellow. Check Sanctuary's canopy, Echo's
   jar and Meteor Shower's trails are see-through, and that Dreamcatcher's stand and Sanctuary's
   umbrella clear the shelf above.
3. Shop: the We Are All Stars box shows the star-blue/blush theme, emblem and pattern, and lists five
   tiers with the odds above.
4. Collection: the We Are All Stars tab emblem and corners; thirteen figures page correctly;
   discovered figures in color, undiscovered as grey silhouettes.
5. Unbox We Are All Stars boxes and check the reveal framing, especially Dreamcatcher (tallest) and
   Cloud Rest (widest).
6. Run a two-player test to confirm visitors see the same figures.
