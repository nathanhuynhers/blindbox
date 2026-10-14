# Monetization acceptance — 2026-10-12

**Implemented in part; verification pending. Not launch ready.** Inspected baseline commit: 052bf123fee64b867869e99ad3a25edded0d711e. Inspection and tests used this checkout, with focused purchase lifecycle, Store title, focus-scroll and test fixes. No native purchases, real Robux, production data changes, publishing or server restarts occurred. Initial Studio inspection returned “Place is not open”. An isolated generated local place was then opened (PlaceId/GameId0, persistence disabled) for native Store fixture and focus checks. Native Marketplace, DataStore, same-server multiplayer and physical-device acceptance remain open.

> Later catalog follow-up: the owner supplied all20 created IDs; native Roblox metadata checks succeeded and PurchaseConfig now maps them. Platform metadata reports all20 on sale; local sales/integration switches remain closed. Missing-ID findings below describe the original audit snapshot and are superseded by [CATALOG_WIRING.md](CATALOG_WIRING.md). Policy/lineage, usable paid value and native release acceptance remain incomplete.

## Findings and fix

| Status | Finding | Disposition |
| --- | --- | --- |
| PASS | Fresh output failed at ConvenienceOwner.spec because Storage imported AfkEngine before tests/run.py copied it. Prior generated output could mask the failure. | Copy AfkEngine before the first suites. Full suite rerun successfully, then build/tests renamed to an ignored backup and the full suite run successfully from fresh output. |
| FAIL | The claim that P01–P08 constitute a completed sellable system is not supported by current source. | All 20 PurchaseConfig variants have nil kind/platformId, salesEnabled=false and integrationReady=false. Keep closed; do not invent IDs or decisions. |
| FAIL | Economic policy/earned-lineage integration is incomplete. | Server bootstrap supplies policy Unknown, lineageValidated=false and disclosureReady=false; CoinModifiers and Boosts validation gates are closed. Auto Open policy authorization is closed. Implement and validate the approved restricted earned path before economic sales. |
| FAIL | Packs/Starter/VIP fixed Coins are conserved as assistedCredit, but do not enter a usable balance. | PackageGrants.view explicitly reports walletCredited=0 and creditUsable=false. Safe reservation is not advertised spendable fulfillment. Withdrawal/spending needs an approved, tested atomic lineage path. No shortcut wallet credit added. |
| FAIL | Double & Claim bonus is retained as assisted credit, not currently usable wallet value. Recurring credit flow approved and implemented; native/usability verification remains open. | 49-Robux reusable DP grants one saved credit, then explicit frozen-return redemption adds extra N once. Historical identity bindings and exceptions retain their handlers. Policy, usable assisted delivery, native receipts and capacity operations remain open. |
| PASS | Planning documents contained obsolete implementation statements. | GAME_DESIGN/OPERATIONS still describe schema14 and MONETIZATION/Store design historical “not implemented” claims. Actual Profile now supports 6–19. Added current acceptance notes to MONETIZATION, task prompts, Store design and OPERATIONS, and corrected the GAME_DESIGN paid-feature inventory. Use source-based reports and implementation contracts for release review; historical planning is not runtime proof. |

Additional defects reproduced and fixed in the deeper pass:

| Status | Defect | Fix / regression evidence |
| --- | --- | --- |
| PASS | Receipt/Starter sidecar writes could resume after replacement join or lease pause and invoke profile delivery by UserId. | PurchaseService rechecks captured session and readiness after yielding commits and delivery; detached callbacks do not resolve replacement journals. Durable sidecar promises retain their existing safe acknowledgement/recovery contract. New PurchaseLifecycle.spec:24 checks, failed before fix, passed after. |
| PASS | Long-label ordinary Store card titles clipped on desktop and landscape phone; Starter banner clipped on compact desktop. | Bounded TextScaled title constraints preserve space and readable minimums. All24 states/five tabs/two endpoints pass on allfour native presets. |
| PASS | At1.5 desktop scaling, production focus scrolling left selected Store card below the viewport. | Interface uses absolute canvas/window and CanvasPosition pixel units; native selected bottom855.69→621.69 within626.42 window. Screens.spec adds8 measured-bound regressions (2353 total). Fixture focus helper corrected too. |
| PASS | Native StudioStoreCheck multiplied CanvasPosition by UIScale a second time, falsely flagging scrolled targets. | Corrected assertion to native pixel units; all960 native matrix cases PASS. |

Missing launch decisions are not authorization to implement policy design, select a catalog or activate sales. No product-effect arithmetic defect was reproduced by the fixture suites. Lifecycle and native UI defects were reproduced and fixed below; passing fixtures cannot close the implementation/configuration gaps above.

## Gates and evidence meanings

Union: server economy/authority, storage/schema/failure recovery, Store/HUD/popups, opening and automation lifecycle, movement, AFK, owner privacy/multiplayer. Tooling gate applies to the harness fix. Figure creation/reference gates N/A: no asset changes.

PASS below means the listed fixture/check actually ran. Standalone domain/UI/store/platform adapters use injected engines or services. Native Store rendering/bounds and sampled focus/navigation were additionally tested in the isolated local place. Native platform purchases, native DataStores, physical input and complete visual acceptance are NOT RUN. Test counts are assertions, not independent player scenarios.

## Product configuration and effect coverage

Every row has configuration inspection PASS, but live configuration readiness FAIL (missing IDs/types and all switches off). D1 benefits/default list prices and D2 design were approved 2026-10-11; D3 now selects all retained products for the configuration handoff (user reply2026-10-12). Platform identities/types and MN-22 price/protocol remain unresolved; the user confirmed no products exist yet. Planning prices below are not actual displayed platform prices.

| Family / keys | Inspected promise | Effect fixtures actually PASS | Readiness |
| --- | --- | --- | --- |
| Coin tiers: coins_2/4/8 | 2/4/8 highest owned; default 149/399/999 | CoinModifiers.spec 191: max tier, source exclusion, old-rate settlement/banks, saved offline checkpoint; failed entitlement refresh through Purchases | FAIL: policy/lineage and catalog absent |
| Coin packs: pack_small/medium/large/huge | 15K/60K/240K/1.2M; default 49/149/499/1999 | Packages 105 + PackagePersistence 50: exact reserved grants, replay, full wallet, durable delivery and failure recovery | FAIL: value conserved but unusable; no approved downstream spend path |
| Starter: starter | Lifetime 7,500 + Coins2_15 token; default 49 | Same package suites: verified pass claim, one marker, tokens and credit atomic aggregate, replay/rejoin | FAIL: catalog and usable Coin delivery missing |
| Auto Open: auto_open | Single ordinary box, >=3s, explicit budget/reserve; default199 | AutoOpen43, ConvenienceOwner, Service29, Client41, Opening14, Results9: start/stop, flow fencing, validation, result conservation, no session restart | FAIL: policy provider/capability catalog missing; native opening/input NOT RUN |
| Auto Collect: auto_collect | Saved opt-in, 1s cadence; default149 | AutoCollect32: real Rules.transferBank, conservation, unique occupied slots and Welcome lesson protection; convenience lifecycle | FAIL: catalog missing; native manual/swap concurrency NOT RUN |
| Movement: movement | Free36 / selected paid48; default49 | PlayerMovement31: initial/late Humanoid, respawn, entitlement freshness and cleanup; convenience preference/control fixtures | FAIL: catalog missing; collision/cinematic/teleport native acceptance NOT RUN |
| VIP: vip | 1.10 Display factor +500 with existing UTC daily Grove claim; default199 | Packages/PackagePersistence: fixed unmultiplied supplement, shared day marker, ownership/rate settlement, failed/lost saves | FAIL: policy, usable supplement and catalog missing |
| Timed Coins: coins_boost_15/30/60 | Coin2 tokens 900/1800/3600s; default29/49/79 | LuckBoosts988, BoostPersistence29, BoostActivation22: receipt token replay, explicit activation, extension/24h bound, expiry integration, rejoin/offline overlap | FAIL: policy validation and catalog missing |
| Permanent Luck: luck | Weight2; default399 | LuckBoosts988 + LinearPity5449: every pool, item midpoint draw/disclosure agreement, normalized L1/2/4, unchanged guarantees and paid/free paths | FAIL: actual policy/lineage provider and catalog missing |
| Timed Luck/combo: luck_boost_2/4, combo_boost | Luck2/4 1800s; combo Coin2+Luck2 1800s; default49/99/79 | Same boost suites: max power, redundancy, incompatible strength, atomic combo, shared Coin timer, rollback clock, expiry and recovery | FAIL: actual policy/disclosure validation and catalog missing |
| Offline: offline_double | This return N free or reserved extra N paid; price unset | OfflineDouble41, Purchase52, Client34, Storage43: odd/zero rewards, free claim/cancel, delayed extra only, new award preserved, duplicate/extra receipt, overflow and AFK barriers | FAIL: usable bonus, recurring association, price/catalog and approval unresolved |

## Purchase lifecycle coverage matrix

The following applies **to every product row above**, avoiding an implied native pass from a mocked common dispatcher. Permanent capability persistence means platform ownership refreshed at join; saved preferences/checkpoints are not proof of ownership.

| Coverage dimension | Status | Evidence / limitation |
| --- | --- | --- |
| Configuration | PASS | PurchaseConfig inspected; Purchases asserts all20 disabled identities and approved promises. Configuration readiness FAIL as above. |
| Availability | PASS | PurchaseAvailability, StoreProjection and fixtures deny unconfigured/off-sale/integration/profile/lease/ownership/pending conditions. |
| Eligibility | PASS / NOT RUN | Fail-closed production gates and fixture eligibility checks PASS; actual per-player PolicyService, spendable lineage and platform enforcement NOT RUN and implementation incomplete. |
| Price display | PASS / NOT RUN | PurchasePrice rejects invalid/non-sale metadata with no planning fallback; StoreIntegration/Binding/Presentation use injected prices. Regional/localized actual price and native prompt agreement NOT RUN. |
| Initiation | PASS / NOT RUN | Purchases105, journal and Store integration: strict caller/key requests, one prompt, retry identity/rate limits. Native initiation NOT RUN. |
| Cancellation | PASS / NOT RUN | Purchases/journal/StoreBinding and OfflineDoubleClient preserve obligations and restore eligible controls; native cancellation/focus return NOT RUN. |
| Verification | PASS / NOT RUN | Server Entitlements and receipt allowlist fixtures, failure/stale preservation and no client completion authority. Actual ownership/service receipts NOT RUN. |
| Fulfillment | PASS / FAIL / NOT RUN | Durable reservation/replay fixtures PASS. Spendable pack/Starter/VIP/offline assisted credit FAIL readiness. Native grants NOT RUN. |
| Ownership / activation | PASS / NOT RUN | Actual resolver, boost and convenience modules through fixtures PASS; actual pass verification, activation UI and gameplay NOT RUN. |
| Persistence | PASS / NOT RUN | Package/boost/offline profile aggregates and SaveSafety458 through injected UpdateAsync PASS. Isolated native DataStore rejoin/migration NOT RUN. |
| Recovery | PASS / NOT RUN | Lost replies, pauses, lease barriers, reconnect journal and delayed obligations through fixtures PASS. Real platform retries, support exceptions and native AFK handoff NOT RUN. |
| UI feedback | PASS / NOT RUN | StorePresentation499, integration70, Binding, OfflineClient34, ShopLuck251 and screen fixtures PASS. Appearance/native input/real focus behavior NOT RUN. |

For Coin tiers, Auto Open/Collect, movement, VIP and permanent Luck: DP receipt fulfillment N/A to the permanent capability itself; Starter retains a durable bundle marker. Boost activation N/A to fixed packs, permanent capabilities and per-return offline purchase. Offline award association N/A to other families.

## Shared safety and free-player regressions

| Concern | Status | Evidence |
| --- | --- | --- |
| Server identity, amount/price/ownership forgery, unknown products | PASS | Purchases105, strict PurchaseProtocol/Ledger and server callback Player inspected; only ProcessReceipt can acknowledge DP delivery. |
| Repeated clicks, duplicate/concurrent receipts, callback retries | PASS | Purchases, journal, Store integration; injected UpdateAsync conflict merges deep-copied grant/marker, unknown receipts defer. |
| Disconnect/rejoin, screen close, delayed fulfillment | PASS | Journal/StoreBinding, OfflineDoublePurchase, reserved delivery and owner-session fixtures. No paid obligation depends on a visible screen. |
| Storage pauses, lease safety/conflicts, failed saves, lost committed responses | PASS | SaveSafety458, package50, boost29/22, offlineStorage43, AFK42; no successful acknowledgement before confirmed durable marker. Native storage NOT RUN. |
| Full wallet / fractions / swap/manual/automatic transfer | PASS | Package and offline protected credit, AutoCollect32, DisplayReplacement55 and Mvp2220. Usable assisted credit remains FAIL readiness. |
| Ordinary free earnings, Coin purchases, Open10/Skip | PASS | Mvp2220, Opening5029, lifecycle1087, CoinModifiers191; disabled production paid factors leave free inputs intact. |
| Welcome, Daily/Login, Shelf and normal offline Claim | PASS | Tutorial3179, Login98, Shelves102, Offline40, OfflineDouble41. Runtime usability NOT RUN. |
| Excluded products | PASS | PurchaseConfig retained20 variants inspected; no Fast Open/Premium multi-open/paid capacity/subscription/gifting products in configured catalog. This is catalog/source evidence, not a live-platform catalog audit. |

## Commands and observed results

- PASS: rokit install (pinned tool provisioning), wally install (empty dependency setup), stylua --check src.
- PASS: selene src: 0 errors, 0 warnings, 0 parse errors.
- PASS: git diff --check; local evidence links checked.
- PASS: rojo build default.project.json -o RobloxWorkspace.rbxlx; rojo sourcemap default.project.json -o sourcemap.json.
- PASS: python tests/run.py C:/Users/natha/Documents/RobloxWorkspace/build/tools/luau/luau.exe; full suite exit0, including18 invalid-config fixtures. The command passed with a fresh build/tests after the ordering fix; the final full suite also passed after all source fixes, including PurchaseLifecycle24 and Screens2353. [Full fresh output](regression.log).
- PASS: luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions=C:/Users/natha/Documents/RobloxWorkspace/build/tools/globalTypes.PluginSecurity.d.luau src; exit0, no type diagnostics. [Output](types.log). Definitions are locally available PluginSecurity definitions; this is static analysis, not runtime proof.

Initial sandbox attempts could not save Rokit trust data, fetch Selene API cache or canonicalize source for Rojo. Authorized elevated retries succeeded. Initial worktree-local Luau path was absent; existing standalone executable from the documented primary checkout used instead. The first full harness failure is fixed as recorded above.

## Native / visual / input acceptance

| Required case | Status | Remaining step |
| --- | --- | --- |
| D1 desktop1920×1080, D2 desktop1280×720 | PASS / NOT RUN | Store fixture matrix PASS at actual1919×1079 and1279×720; popup/HUD/opening comprehensive acceptance NOT RUN. Open known built place and inspect Store all tabs, HUD, offline popup, My Perks, automation controls and reveal/Stop. |
| M1 landscape667×375; M2 inset landscape phone | PASS / NOT RUN | Store fixture matrix PASS on iPhone7 actual666×374 and iPhone17 Pro actual750×381; other surfaces/input acceptance NOT RUN. Record actual device preset/viewport/insets; inspect safe areas,44px targets, final scroll row, long prices, large rewards and loading/owned/restricted/pending/error states. |
| Reopen/reset/rejoin/input switch/reduced motion | NOT RUN | Repeat sessions, observe instance/connection growth and native prompt focus return; exercise opening conflicts and Stop with committed final result. |
| Mouse/keyboard, supported simulated touch/gamepad | NOT RUN | Actually operate controls, focus navigation and scrolling in Studio. Fixture events are not input evidence. |
| Physical phone/gamepad | NOT RUN | Record device and real touch/readability/gamepad pass separately. |
| Two native Studio clients | NOT RUN | Same known build, sequential session; private owner snapshots, cross-owner requests, concurrent receipt/request boundaries, respawn/removal cleanup. |
| Isolated native persistence/service tests | NOT RUN | Disposable accounts/private place, explicit isolated store configuration; migration/rejoin, API failure and lost-response recovery. Never live keys. |
| Native Marketplace/policy/AFK | NOT RUN | Approved private test catalog and protocol needed; test cancellation/ordering/retry/outside-game ownership, actual PolicyService restrictions and published AFK transfer. No real Robux authorized. |
| T1 tablet | N/A | Conditional extended target; no UI layout changes made in this audit. Add before launch if shared layout changes. |
| 3D reference render / asset upload | N/A | No figures/assets changed. |

Native Store evidence is recorded in [NATIVE_EVIDENCE.md](NATIVE_EVIDENCE.md), with [initial desktop Store screenshot](D1-store.png) and [phone long-label screenshot](M2-long-labels.png). Store native bounds/text/target/scroll fixtures passed at D1 actual1919×1079, D2 actual1279×720, M1 actual666×374, M2 actual750×381:240 cases each. Native mouse HUD Store/Upgrades entry and virtual ButtonR1 tab switching were observed; production programmatic GuiService focus observer passed after the fix. Forty state/navigation cycles retained736 fixture descendants. This is partial native acceptance, not actual purchases or physical inputs.

Popup native acceptance remains NOT RUN. An attempted popup matrix initially used an incorrect control export; those apparent passes were discarded. Restart retry stalled and was terminated. Studio subsequently confirmed Edit mode; fixture removed and default viewport restored.

## Current official platform review

Accessed2026-10-12: [paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items), [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService), [developer products](https://create.roblox.com/docs/production/monetization/developer-products), [purchasing/data safety](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing), [server security](https://create.roblox.com/docs/scripting/security/client-server-boundary).

Paid random items, including currency purchasable with Robux, require actual numerical outcome odds and per-player ArePaidRandomItemsRestricted enforcement. Inference for this design: assisted economic and Luck routes need conservative authorization and lineage validation before enablement; reserving Coin value alone is not that validation. Current production bootstrap supplies no real policy provider. Fixture normalization/disclosure agreement is evidence about math, not actual platform compliance.

Developer products require ProcessReceipt handling; client purchase-finished events cannot prove grants. Receipts can replay/concurrently arrive and service retry timing is not a local promise. Inspected adapter uses one dispatcher, durable grants/markers and NotProcessedYet on unresolved delivery. Native service validation remains NOT RUN.

## Release handoff

1. D3 subset is now all retained products (user reply2026-10-12). Resolve platform types/IDs, MN-22 price and recurring receipt/compensation contract. Keep all sales/integration switches closed until explicit release approval.
2. Implement the approved per-player policy and earned/assisted spending lineage; validate restricted/unknown/allowed transitions on all box paths including deals, batches, free rewards under Luck and Auto Open. Make conserved paid credit usable without bypassing restrictions. Do not weaken free progression.
3. Preserve Economy2 namespaces and valid schemas6–18; schema15 convenience/earning inputs,16 boosts,17 offline reservations/credit,18 package delivery are forward-only. Positive free offline returns can promote to17 even while sales are off. Paid catalog disablement alone is not a schema release barrier.
4. Before any release, determine the actually deployed reader/writer version. Older14/15/16 readers reject later records; never permit older writers to erase paid fields. Establish coordinated exclusion/drain or tested compatibility bridge under separate release authorization. Sidecar v1 grant records and P08 Prompt_UserId journal also need compatible handlers on every server.
5. Rollback must retain readers/recovery for all written schemas and all historically sold identities/promises. Do not downgrade profiles, prune replayable markers or erase exceptions. Maintain receipt/ledger capacity strategy and support resolution for unknown/unbound/extra charges; a full ledger must fail closed without forgetting obligations.
6. Run the native matrix above, with isolated stores and known revision/build, sequential Studio sessions, captured evidence and real inputs. Keep physical acceptance separate from emulation. Only then request a separate launch decision; this report authorizes no catalog creation or deployment.

## Approved recurring-credit follow-up

The user approved 49 Robux and saved-credit/redemption on 2026-10-12. Source now supports strict schema19 credit receipts, frozen selection, explicit single-use redemption, owner projection and popup/Store recovery; historical promises are preserved. New suites add78 assertions across domain/profile, client/popup and actual Storage/Persistence/Runtime/AFK with injected services. The full regression suite passes. Final native credit/popup acceptance remains NOT RUN: the local Play attempt returned before finishing and Studio remained Edit. No native purchases or product creation occurred. All launch blockers above remain applicable except the resolved price/recurring-design decision. Nine named gamepass PNGs were generated and exported at512×512; they are catalog artwork, not uploaded figure/model work.
