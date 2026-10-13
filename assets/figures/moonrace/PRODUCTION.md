# Moonrace production receipt

**Status: all 13 figures and the collection artwork are uploaded to Roblox and wired into the game
(catalog, economy, Shop theme, Collection, opening packaging, Display/Shelves through the shared
figure resolver). Studio Play Solo loaded every model as `Ready`; opening reveal, Display, Shelves,
discovered-state previews, landscape phone and two-client checks are still pending (see the end).**

Thirteen original Chinese-zodiac designer toys reconstructed from the approved character sheets in each
figure's `reference/` folder (originals kept in `assets/incoming/moonrace_<figure>_sheet.png`). Catalog
collection `moon`, rarities per the brief. The Cat is the lost thirteenth sign and the Mythical chase figure.

| Figure | Catalog ID | Rarity | MeshParts | Triangles | Size W × D × H (studs) | Largest mesh | Roblox asset |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Rat | `moon.rat` | Common | 31 | 62,532 | 2.74 × 1.42 × 3.12 | Gold 7,000 | 89864961293110 |
| Ox | `moon.ox` | Common | 27 | 60,998 | 2.50 × 2.93 × 3.26 | Gold 7,998 | 90519645854260 |
| Tiger | `moon.tiger` | Legendary | 31 | 102,754 | 2.55 × 3.29 × 3.02 | StripesLeft 10,800 | 95678223448330 |
| Rabbit | `moon.rabbit` | Common | 27 | 45,800 | 1.91 × 1.69 × 3.25 | Head 6,000 | 125098612349310 |
| Dragon | `moon.dragon` | Legendary | 25 | 78,864 | 2.84 × 2.12 × 3.34 | Body 9,600 | 86625290881445 |
| Snake | `moon.snake` | Uncommon | 24 | 52,098 | 2.14 × 2.26 × 2.65 | Body 7,000 | 99526443758779 |
| Horse | `moon.horse` | Uncommon | 26 | 67,190 | 1.93 × 3.02 × 2.93 | Gold 7,000 | 89454442431132 |
| Goat | `moon.goat` | Common | 22 | 46,990 | 2.51 × 2.49 × 2.71 | Body 8,000 | 96999427483853 |
| Monkey | `moon.monkey` | Uncommon | 24 | 47,586 | 1.52 × 1.95 × 2.88 | Head 6,000 | 136022389345173 |
| Rooster | `moon.rooster` | Uncommon | 23 | 55,688 | 2.46 × 2.17 × 2.96 | Body 7,000 | 104113895492534 |
| Dog | `moon.dog` | Rare | 24 | 48,196 | 1.92 × 2.66 × 2.88 | Body 7,000 | 94277193176846 |
| Pig | `moon.pig` | Rare | 18 | 39,482 | 1.86 × 2.18 × 2.66 | Body 8,000 | 126529031599245 |
| Cat | `moon.cat` | Mythical | 2 | 20,886 | 4.20 × 3.41 × 3.40 | Body 18,498 | 139335350043376 |

803,444 triangles in all; every part is below 11k (gate: 20k). Manifest keys are
`Models.Moonrace.Moon<Figure>`, aliases are the figure slugs. Monkey and Rabbit were republished once as
replacement assets (see "Studio verification"); the IDs above are current, the earlier ones are orphaned.

Collection artwork (`Collection.Moonrace.*`): Emblem 92403306538274, ShopPattern 114583744329921,
CornerTopLeft 127733455868952, CornerTopRight 80811549341422, CornerBottomLeft 112568218620262,
CornerBottomRight 134517993058743. Rendered from the production models by [ui_art.py](ui_art.py): the Rabbit
before a gold full-moon ring for the emblem; Tiger, Rat, Pig and Rooster with coins, clouds and lanterns
for the corners; a tileable scatter of twelve figures for the Shop pattern. The Cat is kept out of all
artwork as the secret chase figure. The art was rendered before Monkey/Rabbit's facing fix: the Rabbit's
side hoop is slightly larger in the emblem than in the final model. Corners are uploaded for parity with
the other collections; like theirs, no runtime surface consumes them yet.

## Visual evidence

- `moonrace_lineup.png/.webp`: all thirteen at true relative scale, catalog order.
- `moonrace_fidelity_grid.webp`: three-quarter production-fidelity view of every figure (reimported GLB).
- `<figure>/renders/<figure>_beauty_sheet.png` and `<figure>_fidelity_sheet.png`: four 1000 px views each.
- `<figure>/renders/<figure>_reference_compare.webp`: the approved sheet beside the fidelity front,
  three-quarter and side views.

## How the figures are built

[figures.py](figures.py) is the first collection on the hybrid components (`modeling.Comp`, `sweep`,
`join_meshes`, `materials.preset`). The local kit:

- `C` / `S`: one MeshPart from an SDF or from native sweeps, with explicit island counts, per-part
  voxel/triangle budgets and an optimization limit of 2.5 voxels. `min_faces=12` drops Decimate debris
  (lone or twin flattened triangles in thin skins that fail the orientation/duplicate gates).
- `Decal`: oriented 2D shapes laid on any surface as thin skins (faces, masks, stripes, belly plates,
  embroidery, coin faces). `eyes`: the collection face, as five real geometry layers (dark eye body
  = `_Eyes`, ramped iris, pupil, two highlights, lash line with an outer flick), plus optional lids/brows.
- `Mantle`: hanging cape/cloak shells with a flared, waved, folded hem, an optional front-rising hem and
  layered lining (Tiger cape, Cat cloak, Monkey vest). `tassel`, `coin`, `bell`, `flower`, `spikes`,
  `ridged` (ram horns), `puff_points` (wool), `spiral2` (cloud swirls), `star4`, `path_param` /
  `path_centre` (banded tails, two-tone coils).
- Native sweeps carry every horn, tail, whisker, mane lock, ribbon, strap, pole and cord.

Materials are flat embedded albedo from the shared presets (satin/glossy vinyl, matte plastic, soft
fabric; gold is painted resin with 0.45 metal). No PBR maps: every material is uniform, so maps would add
texture cost and an unverified SurfaceAppearance import without a visible gain. Gradients (eyes, horns,
peach, lantern, Tiger's banded tail, Cat's tail, Snake's tail) are albedo ramps. No glTF extensions.

```
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- moonrace <figure> preview
python tools/figures/publish.py moonrace --build
python tools/figures/publish.py moonrace monkey rabbit --build
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- moonrace lineup
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python assets/figures/moonrace/ui_art.py
python scripts/upload_assets.py moonrace_emblem moonrace_shop_pattern moonrace_corner_top_left moonrace_corner_top_right moonrace_corner_bottom_left moonrace_corner_bottom_right
```

`MOON_FAST=<factor>` coarsens SDF voxels for quick preview iteration only. Each figure went through
three to five preview → compare → fix rounds against its sheet (silhouette, proportions, pose, face,
accessories, colour), then a full-resolution component audit, then final builds whose 1000 px
production-fidelity sheets were reviewed before publishing. The publisher's `--build` rebuild was
byte-identical to the reviewed GLBs (SHA-256 compared).

## Geometry and material checks

All 13 reports pass the schema-2 publisher gates: closed, manifold, positive-volume, no duplicate faces or
inverted islands, declared island counts, sampled optimization error within each part's limit, finite
vertices/UVs, one material per part, every material with an embedded albedo texture, no extensions,
identical surface/bounds/volume/UVs/normals after GLB re-import, and hash-bound fidelity renders.

Pipeline fix made during this build (shared tooling, needed to publish):
`build.reimport_check` reported "surface changed" for **bit-identical** geometry because
`BVHTree.find_nearest` is inexact on long obtuse sliver triangles (`surface_error(mesh, mesh)` returned
5.1e-5 against a 2e-5 tolerance). It now compares exact rounded triangle sets first and only falls back to
sampling when the triangles differ (`build.face_set`). Regression test:
`tests/test_figure_blender.py::test_identical_slivers_are_not_a_surface_change`. The technical fixture
still produces 6 parts / 18,134 triangles with zero reimport mismatches.

## Known differences from the sheets

Candid notes, most significant first:

- **Cat (Mythical), replaced with a Tripo model.** The SDF Cat (`cat()` in figures.py, kept for
  reference) was replaced by `cat_tripo()`: a Tripo image-to-3D model of the sheet. The export also
  modelled the sheet's small turnaround views; `cat/source/prep_tripo.py` keeps only the largest island
  (the hero cat, 216k triangles), scales it to 3.4 studs, decimates it to 18.5k, repairs collapse fins
  and saves a 1024 px basecolor (Tripo's roughness/metal and normal maps are unused: no verified
  SurfaceAppearance path). `MoonCat_Eyes` is a hidden marker sphere inside the head for runtime facing.
  Loaded in Edit Studio from the asset: textured, both parts named correctly, facing -Z
  (`cat/renders/cat_studio_*.jpg`). At 4.20 studs wide (ribbons and tails) it is the widest figure.
- **Cat, earlier SDF version (superseded).** Silhouette, navy/cream mask, gold face marks, blue star-lit eyes, crescent-ring
  crown with star and dangling gems, bow medallion, layered cloak with lavender lining, cream ribbons and
  a gradient tail all read. The sheet's cloak billows far more dramatically, with a printed star field
  and gold-edged swirls; ours is a hanging bell cloak with seven scattered gold stars, a gold hem and
  wide sweeping ribbons. The crown's filigree is simplified to a solid crescent, spire and star. It is
  the most ornamented figure in the set and clearly the premium one, but it is a toy-scale translation of
  a painterly hero image, not a 1:1 reproduction.
- **Tiger (Legendary).** Strong: bold face stripes, white ruff and cheek fluff, red cape with gold hem,
  swirl embroidery and shoulder guards, heart medallion with knot and tassel, banded tail. The cape hem is
  a regular wave rather than the sheet's freer folds. At 102,754 triangles it is the heaviest figure
  (stripes split into two parts to keep thin bands accurate).
- **Dragon (Legendary).** Crest, gold antlers, gold and jade whiskers, cheek fins, coil with gold seam and
  cream underside, ridged belly, star charm and the swirl cloud base all present. The coil is a smooth
  tube; the sheet's individual scale texture is not modelled. The head reads cream/white where the
  sheet's head has more teal shading.
- Rabbit's side hoop and Monkey's tail curl sit closer to the body than on the sheets. The runtime aims
  each figure from its bounding-box centre to `_Eyes`; the sheet-accurate placements rotated Monkey 28.6°
  (rejected by the loader) and Rabbit 12°. Both now face straight ahead (0.1° and 0.0°).
- Snake's coil is a regular spiral; the sheet's coil is looser. Horse's mane locks are separate sweeps;
  the sheet's mane is a softer continuous mass.
- Embroidered fabric patterns on the sheets (Ox's cloth, Horse's blanket, Dog's scarf, Pig's rope) are
  simplified to trims, swirls and motifs. Sparkle particles, typography and scenery are not modelled.
- Expressions follow the hero renders, not the EXPRESSIONS panels.

## Integration

- `src/shared/Catalog.luau`: collection `moon` ("Moonrace") and the 13 figures in zodiac order.
- `src/server/Economy.luau`: `moon = { tier = "prestige", buckets = "standard", pity = "standard", group = "moon" }`
  (a new unique pity group needs no schema change); units Common 0.55/0.60/0.65/0.70, Uncommon
  1.20/1.25/1.35/1.40, Rare 2.8/3.2, Legendary 7.5/8.5, Mythical 22; all weights 1. Same tier, price and
  bands as Tender Echoes and We Are All Stars. Deal stalls are unchanged (Moonrace is not offered there).
- `src/shared/AssetManifest.luau` (`Collection.Moonrace.*`), `src/client/ShopTheme.luau` (lacquer red,
  gold, cream), `src/client/UIStyle.luau` (`MR` monogram, emblem), `src/client/OpeningConfig.luau`
  (box packaging). Generated: `AssetIds.luau`, `FigureAssetEntries.luau`; `assets/manifest.json` /
  `uploads.json` by the publisher and uploader.
- Tests aware of the collection: `tests/Rarity.spec.luau` (five tiers, 13 figures) and
  `tests/EconomySimulation.luau` (Moonrace after Stars).

No figure IDs, profile schema, persistence, monetization or other gameplay changed.

## Automated results

| Check | Status |
| --- | --- |
| StyLua check, Selene (0 errors, 0 warnings), Rojo build | PASS |
| Luau suites (`tests/run.py`, every suite incl. Rarity, Mvp and economy invalid-configuration checks) | PASS |
| Pipeline unit tests (34), Blender pipeline tests (5 incl. new regression), modeling tests (7) | PASS |
| Technical fixture `--fixture technical final` | PASS |
| Publisher gates and upload, 13/13 figures; artwork dry run and upload, 6/6 | PASS |
| Progression simulation, 300 seeded runs | PASS: Moonrace median 1.19 h, 445 boxes (p10 0.34 h, p90 1.88 h) after Stars |

The simulation enters Moonrace after the other Prestige collection, so its time to Mythical is shorter
than Stars' (1.66 h) because the player already earns at a Prestige rate. This mirrors how Stars compares
to Echo; it is an idealized online baseline, not engagement evidence.

## Studio verification (2026-10-12, Play Solo, owner account, preview profile)

| Case | Status | Evidence |
| --- | --- | --- |
| All 13 models load, `<Root>Status = Ready` | PASS | Server probe after the Monkey/Rabbit fix |
| Orientation: eyes face −Z, grounded at Y = 0 | PASS | Probe: eyes direction (0, −1) ±0.02, min Y 0.00 |
| Colours/materials (textured, not near-white) | PASS | Every MeshPart has `TextureID`; world lineup capture matches the fidelity renders |
| Client replication of templates, production variant | PASS | Client probe: 13/13 full part counts, `FigureModel.variant` = production |
| Shop: Moonrace list entry, emblem, 3D box, 200K price, odds | PASS | Desktop capture, 1529×730 viewport |
| Collection: Moonrace list, 13 undiscovered cards, rarity bands, income | PASS | Same "?" cards as We Are All Stars (current design) |
| Output free of figure load/validation errors | PASS | Console |
| Monkey initially `Invalid proportions differ on Z` | FIXED | Facing yaw from asymmetric tail; rebuilt and republished |
| Opening reveal of a Moonrace figure | NOT RUN | Needs 200K Coins; the admin grant was not run in this session |
| Discovered Collection previews (colour vs grey) | NOT RUN | Needs owned figures |
| Display and Shelves placement | NOT RUN | Needs owned figures |
| Landscape phone (667×375 / inset preset) | NOT RUN | Figure presentation needs owned figures |
| Two-client visibility | NOT RUN | Client-side replication probed; no second client |

### Remaining manual checklist

1. Play Solo; use the admin console (F2) to grant Coins, buy a Moonrace box from the Shop, and check the
   opening reveal framing for a Common and (via repeated opens or `GrantFigure`) Tiger, Dragon and Cat.
2. `GrantCollection moon`; Collection should show colour previews for discovered figures; toggle a figure
   away to confirm the grey silhouette state on detail and tiles.
3. Place Tiger, Dragon, Cat and Rat on Display slots and Shelves; check scale (8-stud Display spacing,
   3.6-stud Shelf spacing) and that nothing clips: Cat (4.20), Dragon (2.84) and Rat (2.74) are the
   widest; Tiger (3.29) and Horse (3.02) the deepest, before the runtime 0.8 scale.
4. Repeat 1–3 at landscape phone 667×375 and an inset phone preset.
5. Two-client test: a visitor sees the same Moonrace figures on the owner's Display.
