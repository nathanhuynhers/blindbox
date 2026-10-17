# Collection integration candidate

Status: implemented; full verification pending. The owner approved the exact 42-model plan as shown, all 42 assets were uploaded, and all 160 catalog models reached Ready in an isolated nonpersistent Studio place. Native acceptance is partial: desktop Shop, landscape-phone Moonrace surfaces and all 42 new models in a native preview fixture were observed. The full device and multiplayer matrix remains pending. No live place has been published.

## Approved scope

117 figures across 13 new collections, bringing the catalog to 160 figures in 18 collections. The original 43 figure IDs, probabilities, weights and income remain unchanged. Moonrace keeps all 13 IDs while its approved rarities replace the earlier metadata. Existing ownership, discoveries, banks, Display/Shelf references and pity are retained. The acquisition-time coming-soon refund/removal has been retired.

This integration added no discovery gates or collection unlock requirements. The separately authorized follow-up now adds [collection purchase progression](COLLECTION_PROGRESSION.md). `Catalog.comingSoon` reflects missing production model registration only, independently of progression. This content-readiness check clears automatically after approved publication regenerates `FigureAssetEntries`; it never removes progress. Pending figures show a loading state instead of an invented collectible.

## Prices, base rarity budgets and provisional income

All probabilities below are percentage points **per category**, before pity, Luck or reward conditioning. Each present category is split equally among its figures. Absent category budgets go only to Common. Every new collection asserts at least one Common. Existing five-collection distributions and weighting remain unchanged.

| Collection | Figures | Box / Open 10 Coins | C / U / R / L / M % | Provisional expected Coins/s | Rate per unit |
| --- | ---: | ---: | --- | ---: | ---: |
| Moonrace | 13 | 2,000,000 / 20,000,000 | 60 / 25 / 13.9 / 1 / 0.1 | 2,000.000000 | 1,640.689089 |
| Desserts | 10 | 10,000,000 / 100,000,000 | 60 / 25 / 13.9 / 1 / 0.1 | 7,000.000000 | 5,742.411813 |
| Halloween | 10 | 10,000,000 / 100,000,000 | 60 / 25 / 13.9 / 1 / 0.1 | 7,000.000000 | 5,742.411813 |
| Humanoid Chess Pieces | 6 | 50,000,000 / 500,000,000 | 60 / 25 / 13.9 / 1 / 0.1 | 24,500.000000 | 20,098.441345 |
| Human Emotions | 10 | 250,000,000 / 2,500,000,000 | 60 / 25 / 13.9 / 1 / 0.1 | 85,750.000000 | 70,344.544709 |
| Astral Signs | 13 | 1,250,000,000 / 12,500,000,000 | 60 / 25 / 13.9 / 1 / 0.1 | 300,125.000000 | 246,205.906481 |
| Biomes | 6 | 6,250,000,000 / 62,500,000,000 | 60 / 25 / 13.9 / 1 / 0.1 | 1,050,437.500000 | 861,720.672683 |
| Weather | 7 | 6,250,000,000 / 62,500,000,000 | 73.9 / 25 / 0 / 1 / 0.1 | 1,050,437.500000 | 1,181,760.652510 |
| Five Senses | 5 | 31,250,000,000 / 312,500,000,000 | 60 / 25 / 13.9 / 1 / 0.1 | 3,676,531.250000 | 3,016,022.354389 |
| Olympians | 10 | 156,250,000,000 / 1,562,500,000,000 | 60 / 25 / 13.9 / 1 / 0.1 | 12,867,859.375000 | 10,556,078.240361 |
| Birthstones | 10 | 781,250,000,000 / 7,812,500,000,000 | 73.9 / 25 / 0 / 1 / 0.1 | 45,037,507.812500 | 50,667,987.976375 |
| Seven Deadly Sins | 8 | 3,906,250,000,000 / 39,062,500,000,000 | 85 / 0 / 13.9 / 1 / 0.1 | 157,631,277.343750 | 150,089,290.496310 |
| Pocket Orbit | 9 | 19,531,250,000,000 / 195,312,500,000,000 | 98.9 / 0 / 0 / 1 / 0.1 | 551,709,470.703125 | 766,130,145.048603 |

A figure's base Coins/s is `rate per unit × rarity units`: Common 0.625, Uncommon 1.3, Rare 3, Legendary 8, Mythical 22. Rates retain full calculation precision; the table is rounded for reading. New `expectedIncome` targets in server `Economy.collections` are independent of tier prices. Price-only changes do not change their income. The new tier payback values describe the current ratio, rather than driving these rates.

**Provisional pacing, not final approval:** Moonrace starts at a 2,000 Coins/s random-figure expectation. The next prestige level uses 7,000, then each level uses a draft 3.5× expected income. Equal-price peers share the same expected income despite different rarity counts/budgets. This is a temporary comparison baseline, not an assertion that 3–4× per 5× price is balanced or approved. One base-odds figure repays its own collection price in about 1,000 seconds at Moonrace and 35,401 seconds at Pocket Orbit. Three independent base-odds Display earners would divide those times by three, before selection, duplicates, set bonuses, pity, Luck and modifiers. Sparse rosters have different variance and chase income; expected-value parity does not prove equal optimized progression. Playtest/simulation tuning is still required.

Offline income remains half-rate for up to six hours. Duplicate curves, set bonuses, daily/Welcome/completion rewards, pity resets/curves, paid enablement and slot 5–6 gamepass handling are preserved. Slot 4 costs 1,000,000 Coins. Every new collection uses its own pity group; Moonrace retains `moon`.

## Numeric contract and rollout

`Currency.limit = 1,000,000,000,000,000` (one quadrillion): shared numeric metadata, never wallet authority. Wallets, individual banks, frozen/pending offline rewards, saved returns, receipt grants, Auto Open reserves/affordability and admin SetBalance use this bound. Profiles and snapshots keep ordinary finite Luau numbers and the existing serialized field shapes. Existing smaller saves remain valid without conversion or namespace changes.

- Final single box: 19,531,250,000,000; Open 10: 195,312,500,000,000. The wallet holds 51 singles or five full Open 10 purchases, with 23,437,500,000,000 Coins left after five batches.
- Six full Display banks total 6,000,000,000,000,000, below `2^53 - 1 = 9,007,199,254,740,991`. A 100-box Auto Open budget is 1,953,125,000,000,000 and is also exact; each individual spend and reserve is rechecked.
- Durable credit limits remain 9,007,199,254,740,990. Purchase-ledger decoding and summary bound the cumulative promise before addition, and receipt commit refuses an over-cap promise before writing it. Inventory-wide admin removal refuses before accumulating banks beyond wallet room. Admin grant/remove per-command safety limits remain unchanged; authorized SetBalance supports the full new wallet range.
- Integer wallets remain exact. Banks preserve their existing floor-on-transfer, residual overflow and floating-point fraction semantics. IEEE-754 spacing is 0.125 near this ceiling; arbitrary sub-eighth increments cannot be exactly represented there. No whole-Coin loss or forced reset is introduced; this change does not promise arbitrary decimal precision.
- Exact-value UI uses fixed decimal integer formatting, with thousands separators; compact counters add `Qa`. The remaining `1e12` in `UIState` is the trillions display unit. Timestamp, quantity, probability, serial and request limits are unrelated and remain unchanged.

**Required release barrier:** schema field shapes stay 14–20, but this is not backward compatible with older readers. Old servers reject new figure/pity IDs and balances above their old cap; worse, the old Moonrace acquisition refund can still accept its stable IDs and erase/reprice that progress. Before any separately authorized release, drain incompatible servers and prevent rejoins until all readers/writers contain the new catalog, numeric bounds and removal of the refund path, or implement/test a compatibility bridge. Retain Economy2 stores and paid receipt/credit recovery. Rollback must include these readers and all saved IDs. Restarting after publishing alone does not prove a drain barrier. Do not reset profiles or test migration on production data.

## Artwork and model assets

Moonrace was redesigned in the same style at the owner's follow-up request. Thirteen transparent emblems use actual approved figure references and the existing Moonrace badge style, generated with the built-in imagegen tool. The same emblem is reused as the repeated box-panel motif. Collection titles use a separate scaled/wrapped nameplate label rather than raster text. See [artwork receipt and prompts](../assets/ui/collection/NEW_COLLECTION_ART.md) and [preview](../assets/ui/collection/new_collections_preview.jpg).

The original 75 registered models among the requested 117 are reused, including Sound, King, Chocolate Cherry Queen, Vampire Queen and Rain. The other 42 painted GLBs are preserved and mapped explicitly in [the import manifest](../assets/figures/collection-import.json). Texture preflight passed all 42; orientation patches were chosen against the existing hero renders and checked geometrically. The external importer supplies source/export eight-view comparisons, topology/material checks, immutable artifacts and the hashed plan. Inferred backs/far sides from earlier painting remain an artistic review limitation: several existing sources have broad flat-color rear regions and projection stretches on side details. Virgo's rear includes a duplicated front/face projection. Skeleton Butler, Mummy Sorcerer and Desert also read at a pronounced angle in the geometric front view despite passing the face-patch bounds check. A technical fidelity pass means the import retained the source; it does not certify these source textures or their artistic likeness. Review the actual images before accepting them.

The completed [42-model review report](../build/figures/external/collection-integration-042/report.html) and [upload plan](../build/figures/external/collection-integration-042/plan.json) created 42 new assets for creator user ID `103346374`, with no replacements. The publisher's canonical plan SHA256 is `832d3c11e2cd7cd921752b06284e9db66597260f635596eb4238b902060b8957`. Seven [reference/production contact sheets](../build/collection-integration/review-1.jpg) are available as `review-1.jpg` through `review-7.jpg` beside that first sheet. All seven were inspected, and the owner explicitly approved all 42 as shown after disclosure of the caveats above. The [production receipt](../assets/figures/external/COLLECTION_INTEGRATION_PRODUCTION.md) lists every model ID, alias, part count, triangle count and size. Generated mappings now register all 160 figures, clearing all content-readiness locks.

Do not route these external GLBs through the SDF publisher to bypass approval. The final review report and exact plan digest must be reviewed by the owner before `external.py --publish ... --approve-plan ...`. Uploaded assets are not a published live game.

## Verification record

PASS: complete standalone Luau suite including original odds/income snapshots, sparse probability/pity/Luck/reward tests, current and content-ready BuyTen transaction fixtures, high wallet/bank/offline/receipt totals, replay, overflow and save/reload checks. Content-ready fixtures change only metadata inside ignored test copies and do not certify model uploads or native gameplay.

PASS: pinned provisioning/Wally, formatting, lint (zero errors/warnings), Luau LSP analysis with local Roblox definitions, and Rojo mapping build. Pipeline tests use temporary fixtures and mocked HTTP; initial sandbox temp-directory failures were rerun with access to the appropriate fixture directories.

PASS (technical): all 42 external conversions, preserving all 808,216 source triangles in 2–4 MeshParts per figure, with no conversion errors. Across the paired renders, minimum silhouette IoU was 0.9999668636438946 and maximum foreground RGB MAE was 0.00022227146837394685 (gate 0.05). The publisher dry run validated the exact 42-create plan without credentials, network activity or mapping changes. These measurements certify source preservation, not artistic quality or native Roblox PBR delivery.

PASS: all 42 approved uploads, manifest/runtime mapping generation and the publisher's final formatting, zero-warning lint, complete Luau suite, pipeline tests and Rojo build. A stale test assumption that Desserts must be unavailable was replaced with an isolated unavailable-content fixture; that fixture and the fully registered production catalog both pass. Final Luau LSP analysis reported no diagnostics.

PASS: a fresh Play in the isolated local place loaded all 160 registered models with every status Ready. At actual viewport 666×374, a six-at-a-time native `UIPreview` fixture showed all 42 imported models in color across seven captured pages after texture streaming. All 42 passed texture/appearance removal assertions when toggled undiscovered, and the final page was captured as grey silhouettes. The fixture was destroyed and Play stopped afterward. These previews establish native loading, color delivery and this fixture's framing; they do not certify all Collection/Reveal/Display/Shelf surfaces or full PBR channel parity.

PASS: local nonpersistent Studio place (place ID 0), with the user's live game instance untouched. All 118 currently registered models reached Ready with no model-load issues. At desktop viewport 1529×730, Shop selection/scrolling and Pocket Orbit's 98.9 / 1 / 0.1 category odds were observed. At landscape-phone viewport 666×374, Moonrace's uploaded emblem and box motif, undiscovered Shop tiles, discovered Collection tiles/detail, Rabbit's reduced-motion direct reveal fixture, Display and Shelf placement were observed. The real server accepted SetBalance to 1 quadrillion, charged exactly 2M for Buy and 20M for BuyTen, increased boxes opened to 11, retained granted Moonrace discoveries, accepted Display/Shelf placement and charged exactly 1M for slot 4. Purchases/placements were sent through real remotes from a test fixture; this does not certify the full interactive purchase/reveal flow. All these profiles reported `persistent=false`.

PASS: `StudioUI.client.luau` bounds, 44px targets and hit-order checks on the phone Shop, Collection and Shelves screens with the owner-only admin overlay hidden, matching the ordinary player's view. Candy Confectioner Princess's full detail name reports `TextFits=true` in a 226×32 label. Humanoid Chess Pieces's full Shop title fits in 134×44; its Collection name and progress count fit on one line after bounded title sizing. Missing Strawberry Shortcake production registration shows an explicit loading label. Mouse navigation through Shop, Collection, Display and Shelves was observed. A fresh native Play confirmed the final admin base/effective odds agree for Orbit, Weather and Birthstones, and forcing absent Orbit Rare is refused as ineligible.

FAIL (existing owner-only overlay): the first phone Shelves UI check found the Admin launcher covering a Snake picker target. Hiding that unrelated overlay in the test instance allowed the normal-player UI check to pass. Its source was not changed. Console output also contained existing Core UI warnings, leaderboard DataStore failures in the unpublished place and an old audio asset-type mismatch; no claim of an empty console is made.

NOT RUN: all 42 models on every gameplay presentation surface and full PBR channel parity; complete discovered/undiscovered and long-name coverage; interactive Open 1/Open 10 reveal/skip/result actions across rarities; completion reward interaction; desktop 1920×1080/1280×720, inset phone preset, touch/gamepad and two-client visitor replication. Physical-phone acceptance and native isolated persistence rejoin are also NOT RUN. These checks must be completed before describing the candidate as fully verified.

N/A: live publishing, production profile mutation, discovery/unlock gates and slot 5–6 purchase changes; none are part of this implementation.
