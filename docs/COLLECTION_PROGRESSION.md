# Collection purchase progression

Implemented; full device and multiplayer acceptance pending. This follows the owner's approved progression task after the [117-figure integration](COLLECTION_INTEGRATION.md). It changes collection purchase access only. Prices, rarity assignments, probabilities, figure income, offline earnings, Display slot prices, gamepasses and completion rewards retain the integration's values. No live place was published and no production profile was changed.

## Qualification and buying window

The original five collections remain purchasable under their existing restrictions. Expansion purchases start locked. Qualifying in Tender Echoes **or** We Are All Stars opens expansion tiers 1 and 2. A qualification at expansion tier N opens purchases through N+2, capped at tier 11. The server uses the highest qualifying tier, even if every earlier collection and baseline route is incomplete. All collections below the frontier remain purchasable; normal prices and affordability still apply.

Qualification requires unique permanent discoveries within **one** collection, including at least one Legendary. The Legendary is part of the numerical target. Mythicals do not count or substitute for a Legendary; duplicate copies do not count. Same-tier alternatives are independent OR routes, never summed.

| Qualifying collection / alternatives | Tier | Non-Mythical discoveries including a Legendary | Purchases opened through |
| --- | ---: | ---: | --- |
| Tender Echoes OR We Are All Stars | Baseline 0 | 9 in either one | Desserts + Halloween (2) |
| Moonrace | 1 | 9 | Humanoid Chess Pieces (3) |
| Desserts OR Halloween | 2 | 7 in either one | Human Emotions (4) |
| Humanoid Chess Pieces | 3 | 4 | Astral Signs (5) |
| Human Emotions | 4 | 7 | Biomes + Weather (6) |
| Astral Signs | 5 | 9 | Five Senses (7) |
| Biomes OR Weather | 6 | 3 in either one | Olympians (8) |
| Five Senses | 7 | 3 | Birthstones (9) |
| Olympians | 8 | 6 | Seven Deadly Sins (10) |
| Birthstones | 9 | 3 | Pocket Orbit (11) |

Seven Deadly Sins and Pocket Orbit are buying tiers 10 and 11. No additional qualification thresholds are invented for them; Birthstone qualification already reaches the cap. Qualification is separate from full collection completion and its existing one-time Shelf reward.

## Authority and persistence

`server/CollectionAccess` derives qualification from `state.discovered`. Only known catalog IDs with value `true` count. This state is already permanent, validated and deep-copied by Profile, and retained when final owned copies are removed. Therefore access survives inventory changes and rejoining without a new saved marker, schema, namespace or migration. Existing discoveries count on the first snapshot/purchase after load, including higher-tier history without earlier qualifications. Failed profile loads retain the existing fail-closed behavior.

The approved qualification catalog/rarities and permanent discovery history must remain stable. A later change that removes qualifying IDs, changes their rarity or increases thresholds must explicitly preserve previously earned access with compatible migration/markers before release; do not treat such a change as a harmless catalog retune.

`Rules.mutate` preflights Buy, BuyTen and the server-derived Deal offer before day/stock refresh, settlement, spending, figure rolling, grant, pity or stock consumption. Transactions leaves paid-opening settlement to that preflighted path; retry receipts and token limits remain in place. Coming-soon/content-readiness checks remain distinct. Auto Open's captured-session adapter checks access/readiness at start, each step and immediately before the ordinary Buy transaction. Unknown or forged collection/access claims cannot authorize a purchase. The server callback Player still selects the session.

Daily, Login, Welcome, Welcome x10 and legitimate server reward/admin grants retain their existing authorization paths. Their discoveries can qualify normally; owning a rewarded figure alone does not grant purchase access. Owned figures remain usable in Collection, previews, Display and Shelves while their purchases are locked. There is no inventory removal or discovery reset.

No saved field changes are needed. Nevertheless, older servers lack this purchase rule and could sell expansions outside the new window. Drain incompatible servers as part of a separately authorized release, in addition to the integration's existing catalog/currency compatibility barrier. Old clients remain constrained by the new server. New clients fail closed for expansion purchases until an authoritative access view arrives. This is not authorization to deploy, restart servers or modify live data.

## Player presentation

Private owner snapshots include `collectionAccess`: highest qualifying tier, buying frontier, per-collection access and separate route progress/Legendary status. It is a presentation view, never a client claim or a persisted unlock record. It refreshes through the normal join and authoritative state/discovery updates.

Shop keeps every collection selectable. Its existing scrolling contents panel shows the minimum qualifying tier that opens the selected collection, with each same-tier OR route separately labeled, for example `Discoveries: 3/4 · Legendary: found`. Higher qualifying history is credited immediately by the server. Paid buttons, Auto Open controls, deal projection and post-reveal “another box” use the authoritative access view. Labels distinguish purchases locked, content coming soon, access confirmation and insufficient Coins. Viewing or placing an owned figure is not gated.

## Verification

**PASS:** complete standalone Luau regression suite; 292 qualification/authority/reward/discovery checks, 9 expansion-deal checks and 33 Shop component checks. Coverage includes every approved count and Legendary boundary, Mythical/duplicate exclusion, independent alternatives, all two-tier frontiers, higher-tier credit, final-copy removal, profile round trip, no mutation on locked Single/Open 10/Auto Open/deals, unchanged unlocked prices/retries, rewards, private snapshots and forged fields. Deal tests configure an expansion offer only in their isolated process; production deal weights are unchanged. Shop structure/control tests cover 1920×1080, 1280×720, 667×375 and 812×375 using UI doubles; these are not native device passes.

**PASS:** pinned Wally dependency resolution, `stylua --check src`, Selene with zero errors/warnings/parse errors, Luau LSP analysis with no diagnostics, `rojo build default.project.json -o RobloxWorkspace.rbxlx`, and `git diff --check`. Pins and dependencies are unchanged. The complete final suite is recorded in `build/collection-integration/progression-luau-final.log`.

**PASS:** native Studio at actual landscape-phone viewport 666×374, isolated local place ID 0 with `studioPersistence=false`. Real remotes rejected locked Moonrace Single/Open 10 with the 1-quadrillion wallet unchanged. The phone Shop showed separate baseline routes, and its labels reported TextFits. With Pawn, Knight and Mythical Queen discovered, Chess showed only 2/4 and Legendary needed. Adding Legendary King showed 3/4 and Legendary found, still locked. Adding Rook changed the authoritative frontier to 5 and enabled Astral purchases without baseline/Moonrace qualification. An Astral Single charged exactly 1.25B, Open 10 granted ten figures and charged 12.5B, and replay charged zero. Locked Biomes displayed its Human Emotions route and progress. Shop bounds/44px targets/hit order passed with the owner-only overlay hidden; repeated same-state checks showed no instance growth. The measurement baseline was reset when switching collections because their preview counts differ.

**FAIL (existing unrelated owner overlay):** the owner-only Admin launcher can overlap phone content, as recorded in the integration report. It was hidden only in the local ordinary-player UI fixture; its source was not changed.

**NOT RUN:** native desktop 1920×1080/1280×720 and inset-phone presets, simulated touch/gamepad and physical-phone acceptance, native multiplayer purchase-authority tests, native Auto Open with verified entitlement/policy, an expansion offer in the native deal popup, and isolated persistent Studio rejoin. The MCP session exposed a single client and its existing phone viewport; these checks remain manual acceptance gates. Deterministic player isolation and profile round trips passed, but do not substitute for those native tests.

**N/A:** schema migration/new unlock marker, price/odds/income tuning, gamepass changes, live publishing and production-data mutation.
