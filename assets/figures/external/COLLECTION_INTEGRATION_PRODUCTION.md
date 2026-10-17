# Collection integration: 42-model production receipt

Uploaded on 2026-10-17 under creator user `103346374` following explicit owner approval of all 42 models as shown, including the documented source-art limitations. No live place was published. Native acceptance is recorded in [the integration report](../../../docs/COLLECTION_INTEGRATION.md).

Approved canonical plan SHA256: `832d3c11e2cd7cd921752b06284e9db66597260f635596eb4238b902060b8957`.

## Conversion and publication

```powershell
python tools/figures/external.py build/collection-integration/textures/prepared --manifest build/collection-integration/textures/prepared-batch.json
python tools/figures/external.py --publish build/figures/external/collection-integration-042/plan.json --approve-plan 832d3c11e2cd7cd921752b06284e9db66597260f635596eb4238b902060b8957
```

All 808,216 source triangles were retained by lossless partitioning; each figure has 2–4 MeshParts and every part is below 20,000 triangles. Cuts intentionally have open boundaries. Geometry/UV/normal reimport and embedded material checks passed. Minimum silhouette IoU was 0.9999668636438946; maximum foreground RGB MAE was 0.00022227146837394685. These are preservation checks, not artistic-likeness scores or proof of Roblox map delivery.

Each immutable `<collection>/<figure>/<fingerprint>/` directory contains the original GLB, packed source/production blends, production GLB, source/export front/three-quarter/side/back renders and a hashed validation report. Source maps, UVs, normals and materials are retained; no new character geometry or textures were authored for this import. Blender is +Z up/front −Y; runtime `ModelAssets` turns the eyes toward −Z, applies the existing 0.8 scale and grounds the base. Table sizes use Blender X/Y/Z (width/depth/height), before runtime scale.

## Accepted source-art limitations

Several provided sources have broad flat rear fills and side projection stretching. Virgo has a duplicated front/face projection on its back, the clearest rear-view discrepancy. Skeleton Butler, Mummy Sorcerer and Desert read at a pronounced angle in the geometric front view. These source limitations were explicitly disclosed and accepted as shown; conversion did not repaint or recreate them. The [review report](../../../build/figures/external/collection-integration-042/report.html) preserves all source/export comparisons.

## Uploaded models and aliases

`assets/uploads.json`, `AssetIds.luau` and generated `FigureAssetEntries.luau` are the runtime mapping records. All actions created new assets; no prior model IDs were replaced.

### astral-signs

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Aries / `astral.aries` | Uncommon | `astral_aries` / `Models.AstralSigns.AstralAries` | 3 | 18,903 | 3.733 × 2.968 × 3.572 | 9,597 | 86797348490914 |
| Capricorn / `astral.capricorn` | Uncommon | `astral_capricorn` / `Models.AstralSigns.AstralCapricorn` | 3 | 18,864 | 3.502 × 2.745 × 3.572 | 14,567 | 86444663625804 |
| Leo / `astral.leo` | Uncommon | `astral_leo` / `Models.AstralSigns.AstralLeo` | 3 | 18,882 | 3.833 × 3.052 × 3.572 | 12,788 | 80477109617206 |
| Taurus / `astral.taurus` | Common | `astral_taurus` / `Models.AstralSigns.AstralTaurus` | 3 | 19,008 | 3.654 × 2.664 × 3.572 | 14,457 | 137320104077544 |
| Virgo / `astral.virgo` | Common | `astral_virgo` / `Models.AstralSigns.AstralVirgo` | 3 | 18,542 | 3.191 × 2.488 × 3.572 | 16,701 | 98611913839076 |

### biomes

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Desert / `biome.desert` | Uncommon | `biome_desert` / `Models.Biomes.BiomeDesert` | 2 | 19,316 | 2.847 × 2.722 × 3.572 | 19,159 | 114567602422609 |
| Savanna / `biome.savanna` | Common | `biome_savanna` / `Models.Biomes.BiomeSavanna` | 2 | 19,082 | 3.021 × 2.282 × 3.572 | 18,743 | 110900938334909 |
| Taiga / `biome.taiga` | Rare | `biome_taiga` / `Models.Biomes.BiomeTaiga` | 2 | 19,538 | 2.695 × 2.087 × 3.572 | 19,375 | 86170277262591 |

### birthstones

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Garnet / `birthstone.garnet` | Uncommon | `birthstone_garnet` / `Models.Birthstones.BirthstoneGarnet` | 3 | 19,255 | 2.508 × 2.309 × 3.572 | 12,894 | 82389359404214 |
| Peridot / `birthstone.peridot` | Common | `birthstone_peridot` / `Models.Birthstones.BirthstonePeridot` | 2 | 19,780 | 2.563 × 1.766 × 3.572 | 19,513 | 116516371426083 |

### desserts

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Cupcake / `dessert.cupcake` | Common | `dessert_cupcake` / `Models.Desserts.DessertCupcake` | 2 | 19,424 | 2.127 × 1.742 × 3.572 | 19,175 | 135655293687389 |
| Dessert Skater / `dessert.dessert-skater` | Uncommon | `dessert_dessert_skater` / `Models.Desserts.DessertDessertSkater` | 3 | 19,346 | 2.620 × 2.785 × 3.572 | 13,128 | 135120170498546 |
| Donut / `dessert.donut` | Uncommon | `dessert_donut` / `Models.Desserts.DessertDonut` | 2 | 19,564 | 2.481 × 2.565 × 3.572 | 19,304 | 132284442614377 |
| Macaron / `dessert.macaron` | Common | `dessert_macaron` / `Models.Desserts.DessertMacaron` | 2 | 19,132 | 2.045 × 1.994 × 3.572 | 19,037 | 110578994914600 |
| Matcha Mochi / `dessert.matcha-mochi` | Rare | `dessert_matcha_mochi` / `Models.Desserts.DessertMatchaMochi` | 2 | 19,276 | 2.294 × 2.128 × 3.572 | 19,066 | 109547465681316 |
| Strawberry Shortcake / `dessert.strawberry-shortcake` | Rare | `dessert_strawberry_shortcake` / `Models.Desserts.DessertStrawberryShortcake` | 3 | 19,664 | 2.140 × 2.101 × 3.572 | 13,659 | 94924764946882 |

### five-senses

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Smell / `sense.smell` | Uncommon | `sense_smell` / `Models.FiveSenses.SenseSmell` | 2 | 19,186 | 2.477 × 1.928 × 3.572 | 19,064 | 97547876670540 |
| Touch / `sense.touch` | Common | `sense_touch` / `Models.FiveSenses.SenseTouch` | 2 | 19,518 | 3.036 × 2.235 × 3.572 | 19,316 | 136624773079375 |

### halloween

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Candy Corn Jester / `halloween.candy-corn-jester` | Common | `halloween_candy_corn_jester` / `Models.Halloween.HalloweenCandyCornJester` | 2 | 19,890 | 2.546 × 1.904 × 3.572 | 19,671 | 91372332612173 |
| Ghost with Lantern / `halloween.ghost-with-lantern` | Rare | `halloween_ghost_with_lantern` / `Models.Halloween.HalloweenGhostWithLantern` | 2 | 19,252 | 2.783 × 1.924 × 3.572 | 19,072 | 117360866263757 |
| Mummy Sorcerer / `halloween.mummy-sorcerer` | Rare | `halloween_mummy_sorcerer` / `Models.Halloween.HalloweenMummySorcerer` | 2 | 19,678 | 2.480 × 3.066 × 3.572 | 19,377 | 91269394188516 |
| Pumpkin Trick-or-Treater / `halloween.pumpkin-trick-or-treater` | Uncommon | `halloween_pumpkin_trick_or_treater` / `Models.Halloween.HalloweenPumpkinTrickOrTreater` | 2 | 19,734 | 2.766 × 2.441 × 3.572 | 19,597 | 104046146249949 |
| Skeleton Butler / `halloween.skeleton-butler` | Common | `halloween_skeleton_butler` / `Models.Halloween.HalloweenSkeletonButler` | 2 | 19,144 | 2.074 × 2.533 × 3.572 | 19,025 | 119967896633961 |
| Werewolf / `halloween.werewolf` | Rare | `halloween_werewolf` / `Models.Halloween.HalloweenWerewolf` | 2 | 19,160 | 3.206 × 2.872 × 3.572 | 18,815 | 96021621640835 |
| Witch Catgirl / `halloween.witch-catgirl` | Uncommon | `halloween_witch_catgirl` / `Models.Halloween.HalloweenWitchCatgirl` | 2 | 19,354 | 2.293 × 2.284 × 3.572 | 19,161 | 122960749581395 |

### human-emotions

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Anger / `emotion.anger` | Uncommon | `emotion_anger` / `Models.HumanEmotions.EmotionAnger` | 2 | 19,338 | 2.802 × 2.331 × 3.572 | 19,151 | 89999717712325 |
| Disgust / `emotion.disgust` | Common | `emotion_disgust` / `Models.HumanEmotions.EmotionDisgust` | 2 | 19,706 | 2.220 × 2.125 × 3.572 | 19,509 | 139063001864035 |
| Envy / `emotion.envy` | Rare | `emotion_envy` / `Models.HumanEmotions.EmotionEnvy` | 2 | 18,639 | 2.892 × 2.729 × 3.572 | 18,536 | 103998196923174 |
| Fear / `emotion.fear` | Uncommon | `emotion_fear` / `Models.HumanEmotions.EmotionFear` | 2 | 19,267 | 2.696 × 1.803 × 3.572 | 19,148 | 132427545444043 |
| Joy / `emotion.joy` | Common | `emotion_joy` / `Models.HumanEmotions.EmotionJoy` | 4 | 18,884 | 2.636 × 2.079 × 3.572 | 10,433 | 99911172311034 |
| Surprise / `emotion.surprise` | Uncommon | `emotion_surprise` / `Models.HumanEmotions.EmotionSurprise` | 2 | 19,260 | 2.159 × 1.940 × 3.572 | 19,105 | 105272620530319 |

### humanoid-chess-pieces

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Pawn / `chess.pawn` | Common | `chess_pawn` / `Models.HumanoidChessPieces.ChessPawn` | 3 | 19,072 | 1.863 × 2.135 × 3.572 | 12,127 | 70526730067606 |
| Rook / `chess.rook` | Uncommon | `chess_rook` / `Models.HumanoidChessPieces.ChessRook` | 2 | 19,048 | 3.625 × 3.151 × 3.572 | 18,734 | 95359027078165 |

### olympians

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Apollo / `olympian.apollo` | Rare | `olympian_apollo` / `Models.Olympians.OlympianApollo` | 2 | 19,475 | 2.477 × 1.814 × 3.572 | 19,360 | 104776987484795 |
| Ares / `olympian.ares` | Uncommon | `olympian_ares` / `Models.Olympians.OlympianAres` | 3 | 18,706 | 3.648 × 2.159 × 3.572 | 10,470 | 113142099866146 |
| Artemis / `olympian.artemis` | Common | `olympian_artemis` / `Models.Olympians.OlympianArtemis` | 2 | 19,246 | 2.097 × 2.876 × 3.572 | 19,111 | 128290581477315 |
| Hera / `olympian.hera` | Rare | `olympian_hera` / `Models.Olympians.OlympianHera` | 2 | 19,345 | 2.838 × 1.995 × 3.572 | 19,120 | 79257957346622 |
| Hermes / `olympian.hermes` | Common | `olympian_hermes` / `Models.Olympians.OlympianHermes` | 2 | 19,094 | 3.117 × 1.470 × 3.572 | 18,661 | 120075247877269 |

### pocket-orbit

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Earth / `orbit.earth` | Common | `orbit_earth` / `Models.PocketOrbit.OrbitEarth` | 3 | 19,078 | 2.805 × 1.794 × 3.572 | 12,470 | 81146575532383 |

### seven-deadly-sins

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Pride / `sin.pride` | Common | `sin_pride` / `Models.SevenDeadlySins.SinPride` | 3 | 18,958 | 3.065 × 2.577 × 3.572 | 12,207 | 120244975928386 |

### weather

| Figure / catalog ID | Rarity | Alias / semantic key | Parts | Triangles | W × D × H studs | Largest part | Model asset ID |
| --- | --- | --- | ---: | ---: | --- | ---: | --- |
| Fog / `weather.fog` | Common | `weather_fog` / `Models.Weather.WeatherFog` | 3 | 19,826 | 2.308 × 1.884 × 3.572 | 9,906 | 83756796010860 |
| Hail / `weather.hail` | Uncommon | `weather_hail` / `Models.Weather.WeatherHail` | 3 | 18,782 | 2.916 × 2.322 × 3.572 | 10,280 | 104250728707773 |

## Remaining native acceptance

Follow [the figure runbook](../../../docs/FIGURE_COLLECTION_RUNBOOK.md#7-studio-checklist-for-the-user): all load statuses Ready, front/grounding/scale, discovered colors and undiscovered silhouettes, opening, Display, Shelves, PBR maps and another client’s view at desktop and landscape-phone viewports. Toggle discovery and close/reopen previews to check material teardown. Physical-device, full input and multiplayer acceptance remain separate from conversion and upload.
