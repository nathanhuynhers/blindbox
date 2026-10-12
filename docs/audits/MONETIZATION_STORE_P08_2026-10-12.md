# P08 Store integration and P09 handoff — 2026-10-12

**Implemented; verification pending. Sales and paid-effect rollout gates remain off.**
This report covers the attached integration request, the current approval table in
[MONETIZATION](../MONETIZATION.md), and the existing approved Store. No product was created,
no place was published, no production server was restarted, and no production data was accessed.

## Implementation and authority

- `StoreBinding` owns the single client PurchaseState subscription and client-side Roblox
  metadata cache. `PurchaseClient` coordinates Store and offline purchases through P02's existing
  PurchaseRequest path. There is no client native launcher or purchase-completion grant callback.
  Configured available offers use `GetProductInfoAsync` with GamePass/Product InfoType on the
  viewing client. Missing/off-sale/failed metadata disables buying; there is no list-price fallback.
  Roblox documents this client lookup for [regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing).
- `StoreProjection` maps all retained logical product keys, all three Coin-token durations,
  authoritative grant/benefit descriptors, owned/superseded/claimed state, package protected
  credit, and actual Coin/Luck inputs into the retained cards and My Perks. Luck sheets show
  server-produced base/current/proposed itemized odds for every existing collection. Free pity,
  batch pity advancement and reward floors remain separate from paid weight changes.
- Coin pack cards use the approved direct purchase action. Other offers use the product sheet
  and the same controller. Prompting, verification, saving, cancellation and recovery are distinct;
  Reserved is never treated as spendable Coins or an active boost. The balance and token inventory
  are taken from gameplay snapshots, never added from a receipt promise or native callback.
- `PurchaseJournal` fixes the pre-receipt reconnect gap in P02. It records a bounded status
  obligation **before** invoking the native prompt, under `Prompt_<UserId>` keys in the existing
  purchase sidecar store. The version-1 receipt aggregate and Economy2 profile schemas are unchanged.
  Journal recovery blocks another prompt and identifies the recovering product after rejoin.
  Verified ownership, confirmed receipt fulfillment or a definite native cancellation resolves it;
  an uncertain store/platform response does not. This journal grants nothing. A lost journal-clear
  response defers acknowledgment; receipt replay and refresh recover the original value.
- Confirmed delivery counts distinguish already delivered ledger entries from still reserved
  value. Join/refresh replays P02's existing committed-entry callbacks to reconstruct this view.
  The receipt ledger retains the original immutable promises and all paid markers.
- `ConvenienceOwner` completes P05's missing server bootstrap integration. One captured-session
  Auto Open/Auto Collect owner reuses PlayerMovement, Rules.transferBank and Transactions.process.
  The existing one-second scheduler settles income before automation; no per-player loop was added.
  Movement/Auto Collect preferences use the existing v15 boundary. The ordinary Buy before/after
  envelope is retained independently of the transient gameplay receipt cache. Repeated deliveries
  cannot purchase again. Manual opening conflicts, flow/collection changes, reset, focus loss,
  uncertain ownership and AFK handoff stop spending; a committed result still needs acknowledgment.
- Coin Shop setup exposes chosen collection, a 1–100 box budget and an integer Coin reserve,
  explicit Start/Stop, Auto Collect and movement settings. A safe-area Stop control survives the
  opening overlay and binds gamepad X above its input handler. Existing Open 10 and Skip remain.
- Boost activation selects an actual unused token (including its Coin duration), confirms wall-time
  rules, and uses BoostActivate's exact request/revision. Lost replies retry the same identity.
  Uncertain activation saves remain pending. Backend activation reasons share Boosts' actual
  preflight; incompatible, redundant, queued or unverified tokens are not advertised as ready.
  Absolute UTC timers tick at most once per second on the visible Store. Routine clock observations
  do not recreate controls or erase confirmation; hidden Store observations allocate no UI.
- MN-22 retains the welcome-back card and P03B frozen N/2N, reservation and receipt recovery.
  The client does not recalculate or multiply N. The same coordinated purchase lock applies;
  cancellation restores free Claim and does not claim purchase success or erase a reserved bonus.

## Product-by-product readiness

All rows currently have **nil platform kind/ID**, `salesEnabled = false`, and
`integrationReady = false` in PurchaseConfig. Thus every new purchase is honestly unavailable;
the UI never fabricates a Robux price. Wiring readiness below is separate from sales readiness.

| Retained product / P02 key | Integrated contract | Additional blocker before native sales/use |
| --- | --- | --- |
| Permanent Coin 2 / 4 / 8 — `coins_2`, `coins_4`, `coins_8` | Verified tier, highest-tier ownership presentation, actual earning inputs and full-price upgrade disclosure | D2 policy/earned-lineage validation, Coin effects gate; 4/8 pacing and D3 release decision |
| Coin packs — `pack_small`, `pack_medium`, `pack_large`, `pack_huge` | Fixed configured promise, capacity preflight, immutable P06 delivery and protected credit | P06 paid-path/lineage transfer remains closed; Large/Huge D3 decision |
| Starter — `starter` | Verified pass, lifetime eligibility/claimed marker, fixed Coins plus unused Coins2_15 token | P06 paid-path validation and protected-credit usability; token activation gate |
| Auto Open — `auto_open` | P05 session owner, approved setup, ordinary Buy/results, Stop/reset/focus/AFK lifecycle | Validated paid-automation policy and authoritative spendable-balance provider are deliberately absent; no visible-wallet fallback |
| Auto Collect — `auto_collect` | Verified ownership, saved opt-in, shared bank transfer, tutorial protection, cadence | Platform configuration and separately approved sales/release; native lesson/overflow/respawn acceptance |
| Movement — `movement` | Verified ownership, saved toggle, existing initial/late Humanoid/respawn resolver | Platform configuration and separately approved sales/release; native collision/device acceptance |
| VIP — `vip` | Verified benefits, applied factor, UTC daily supplement state and protected-credit disclosure | P06 paid-path gate; native daily boundary and lineage acceptance |
| Timed Coins — `coins_boost_15`, `coins_boost_30`, `coins_boost_60` | Configured tokens, explicit activation, actual timers and Coin input | D2 policy/lineage/disclosure provider and Boosts effects gate |
| Permanent Luck — `luck` | Verified ownership, actual applied Luck, exact server-produced odds comparison | Same D2 gates plus platform paid-random acceptance and D3 decision |
| Timed Luck / combo — `luck_boost_2`, `luck_boost_4`, `combo_boost` | Authoritative unused token, activation compatibility/redundancy, timers and odds | Same D2 gates; native normalization/floors/stacking acceptance and D3 decision |
| Per-return Double & Claim — `offline_double` | Frozen N/2N, existing P03B prepare/fulfill, common lock and recovery | MN-22 price/type/association/cancelled-epoch decisions; associationApproved and paidPathValidated remain false |

Coin/boost/Auto Open purchase preflight now routes to the authoritative readiness and validation
boundaries; the production policy provider still returns Unknown/false. Completing the UI odds
presentation does **not** certify `disclosureReady`, paid-random eligibility, lineage or sales.
No current switch was enabled as a substitute for those services.

## Verification evidence

Affected gate union: UI/input/lifecycle, opening conflicts, server purchase/economy authority,
persistence/offline recovery, private owner contracts and tooling. Figure/world changes are N/A.

| Status | Check actually run / boundary |
| --- | --- |
| PASS | `rokit install`: unchanged pinned versions; `wally install`: empty dependencies resolved, no dependency added |
| PASS | `stylua src` and `stylua --check src` |
| PASS | `selene src`: zero errors, warnings or parse errors |
| PASS | `rojo sourcemap default.project.json -o sourcemap.json`; `rojo build default.project.json -o RobloxWorkspace.rbxlx` |
| PASS | Luau LSP 1.70.1 full-source analysis with current sourcemap and local Roblox definitions: no type diagnostics |
| PASS | Full existing `tests/run.py` suite with the existing standalone Luau executable, including 18 invalid-configuration fixtures |
| PASS | New StoreIntegration: 70 assertions covering authoritative projection, actual price labels, duplicate requests, receipt/save recovery, cancellation even with a lost authorization reply, pass ownership, all retained mappings/durations, direct pack/sheet actions, shared offline lock, stable activation controls despite unrelated price updates and hidden UI allocation |
| PASS | New StoreBinding fixtures: correct metadata InfoType, loading/failure/retry/cache expiry, coordinated offline/Store and activation requests, uncertain activation save, exact retries, focus return and late lookup teardown |
| PASS | New ConvenienceOwner fixture: captured-session readiness, shared ordinary Buy, retained delivery after receipt eviction, policy/prompt conflict refusal and fraction-preserving Auto Collect |
| PASS | New PurchaseJournal fixture: strict decode, corrupt/future records preserved, lost commit, reconnect before receipt, duplicate prompt prevention, receipt/close order and cancellation recovery |
| PASS | Existing Store presentation 499 assertions; purchase foundation 105; offline/P02 dispatch 52; offline client/popup 34; Coin modifiers 191; Luck/boost domain 988; boost persistence 29; boost activation 22; package domain 105 and persistence 50; relevant convenience/opening/free-gameplay regressions also passed |
| FAIL | None remaining in automated checks. Intermediate fixture/type failures were repaired before the final run |
| NOT RUN | Native Studio/platform/PolicyService/DataStore, multi-client ownership and isolated persistence rejoin. Studio MCP discovery returned no connected instances |
| NOT RUN | D1 1920×1080, D2 1280×720, M1 667×375 and M2 inset landscape-phone native visual acceptance, actual safe areas, scrolling endpoints, long/localized price text, owned/pending/error variants, resize, reduced motion, touch/gamepad and native prompt focus |
| NOT RUN | Physical phone and physical gamepad acceptance. Engine/UI doubles do not render text, resolve real bounds or prove device input |
| N/A | Figure creation/upload/reference-image gates; live publication, production mutations and sales activation are outside this task |

The fixtures use injected services/storage or generated ignored copies; they are **not** real
platform purchases, persistence sessions or visual/device evidence. Generated logs, maps and place
builds stay ignored. The local test executable was
`C:/Users/natha/Documents/RobloxWorkspace/build/tools/luau/luau.exe`; the worktree lacked its own
installation. The available bundled Python executable ran the harness.

## Precise P09 handoff

1. Keep every rollout switch off. Confirm the current deployment and approve D3, platform types/IDs,
   historical identity retention, and MN-22 pricing/association treatment separately. Do not treat
   this report or passing fixtures as release permission.
2. Supply real server PolicyService eligibility, validated earned/assisted spending and fixed-credit
   transfer, and disclosure acceptance. Replace the Unknown/false eligibility/spendable providers
   with those authoritative services; route the same current proof to Coin, boosts, Auto Open,
   package and offline preflight/use. Confirm that charged recovery ignores new-sale restrictions.
3. Review Economy2 v15/v16/v17/v18 compatibility before any released writer change. This integration
   does not add a profile schema, but the existing offline award writer and saved preferences already
   require the documented drain/barrier or tested compatibility bridge. Older purchase code ignores
   `Prompt_` journal keys and could reprompt an unresolved payment: exclude those servers before
   authorizing sales. Keep the original receipt aggregate/store and all original grant promises.
4. On an explicitly authorized private test surface, check Journal + ledger + profile save failure,
   lost response, pre-receipt disconnect/rejoin, receipt before/after prompt close, actual pass cache
   refresh and replay. An interrupted/uncertain prompt may need verified support evidence to resolve;
   no timeout or client reset clears the journal. Do not erase a production obligation to unblock UI.
   Review the existing 2,048-marker and token bounds and the additional per-prompt journal I/O budget.
5. Exercise success, cancellation, restricted eligibility, metadata failure, delay, duplicate input,
   close/reopen, reset, focus loss/return and rejoin for every row. Verify Starter's once-only bundle,
   VIP UTC boundaries, all token durations/strength compatibility, redundant Luck, reserve/budget
   stops, tutorial collection protection and respawn speed. Compare frozen N free Claim versus
   purchased 2N, cancellation/free Claim, base-claimed late receipt, popup dismissal and overflow
   credit recovery. Run two clients for owner privacy and cross-owner rejection.
6. Run `tests/StudioStore.client.luau`, `tests/StudioStoreCheck.client.luau` and applicable existing UI /
   opening fixtures according to their headers. Then inspect the actual integrated Store, Coin Shop
   controls and offline card at D1/D2/M1/M2. Check last scroll items, inset clearance, long platform
   prices, every ownership/recovery/error state, reduced motion, input switching and gamepad Stop X
   vs free Skip B. Measure connection/instance growth over at least 25 open/close and reset cycles.
   Record actual viewports and screenshots; label fixtures separately from platform behavior.
7. Record the native/physical-device acceptance in a dated P09 audit. Any live sales activation,
   product creation, publication, production data operation or restart needs a separate instruction.

Release impact: no live changes performed; configuration and validation remain closed. Required
runtime/visual/service acceptance is pending.
