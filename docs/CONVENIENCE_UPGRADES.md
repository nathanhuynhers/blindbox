# Convenience upgrades (P05 / focused ownership handoff)

Implemented modules and isolated tests, October 11, 2026. **Gameplay integration,
native runtime and visual/device verification are pending.** This worktree deliberately
does not edit Rules, Profile, shared Types, server init, purchase dispatch or income
resolution while P03A owns them. Store presentation/purchase wiring remains P08.
No platform identity, sale, live place version or production profile was changed.

Read with [monetization decisions](MONETIZATION.md#concise-decision-table--smallest-remaining-user-choices),
[purchase interfaces](PURCHASE_FOUNDATION.md), [opening](OPENING.md),
[AFK handoff](AFK_RECONNECT.md), [quality gates](qa/QUALITY_GATES.md) and
[device matrix](qa/DEVICE_TEST_MATRIX.md). The local decision table still records D2 as
pending. P03A reports subsequent D2 approval with the policy/earned-lineage validation
gate; consume the reconciled decision table at integration. Either way, this task supplies
no policy/lineage implementation and `policyAllowed` must remain false until upstream
validation authorizes the ordinary randomized purchase and paid automation treatment.
P02 remains unconfigured and off sale. Ownership is Unknown in that configuration.

## Delivered boundaries

- `AutoOpen`: explicit collection, 1–100 boxes (UI default 10), integer reserve; one
  Pending/Presenting workflow, at least three seconds between starts across runs.
  Every spend rechecks readiness, living character, fresh ownership, policy, focus,
  spendable balance/reserve and ordinary cooldown. The injected ordinary purchase
  callback still owns copy/pity/collection checks and the atomic Buy mutation.
  Stop does not cancel committed delivery. Completion, errors, storage loss, death,
  changed collection and focus loss stop spending. No funds/respawn/rejoin restart.
- `AutoCollect`: externally stepped once per second **after settlement**. Only unique
  occupied/unlocked Display IDs are selected. Calls the existing bank helper without
  multiplying value; one aggregate revision for any positive transfer. Stage 1–3 of
  Welcome Quest blocks automation even when guidance is hidden. No character/distance
  requirement for automation; normal respawn can retain the saved opt-in.
- `PlayerMovement`: baseline 36; selected, ready, fresh verified movement ownership
  resolves to 48. Initial/late Humanoids, respawn and refresh share one boundary.
  Duplicate binds return the existing binding; unbind and late refresh are inert.
  Unknown/stale ownership conservatively uses 36; it never erases the saved choice.
- `ConvenienceProtocol/Service/Runtime`: dedicated typed private channels, strict fields,
  finite/bounded numbers, no caller/price/amount fields; callback Player identity only.
  Four-token control bucket (one/sec). Valid Stop/flow close is honored even without a token,
  but does not emit unbounded replies. Increasing control serials fence a delayed
  Start behind Stop. 256 Start/preference request identities per session fail closed
  at capacity and cannot be replayed to resurrect a stopped run.
- `ConvenienceClient/Controls`: Coin Shop/settings panel with chosen collection, finite
  run count, actual integer reserve, maximum cost, Start/Stop, opt-in Auto Collect and
  free/upgraded speed selector. Uses UIKit/UIButton/UIScope, explicit scroll height and
  44px targets. A separate `createStop` mounts in opening's safe-area overlay so Stop
  remains accessible while `openingFocus` hides gameplay screens.
- `ConvenienceResults/Presentation`: bounded single confirmed-result queue and replay
  guard; uses existing `OpeningResult.fromReply` and the existing reveal. The new
  `OpeningController.advanceAutomatic(requestId)` activates only matching ordinary
  single-box Await/Result interaction gates; no timed phase changes, Skip gating or
  "another" purchase choice. `create(..., completed?)` reports full teardown vs
  cancellation. The final budget box still finishes; stopping restores manual reveal
  interaction. Completion before the automation snapshot and dropped acknowledgements
  reconcile at a bounded cadence.

## Exact shared-file requirements for P03A

P03A reports these contracts implemented in worktree 17cb; they are **not merged in
this worktree**. Merge the shared work before wiring the modules:

1. Export `Rules.transferBank(state: Types.State, id: string): number` as the exact
   existing helper. No settlement, quest change or revision in this export. Do not
   replace it with `Rules.collect`: that advances the genuine manual lesson. Future
   provenance handling must stay inside this shared helper for manual/swap/automatic
   transfers equally.
2. Add `state.convenience = {autoCollect: boolean, movement: boolean}`, defaults false.
   Supply `Rules.setConveniencePreference(state, key, enabled): boolean`, keys
   `auto_collect`/`movement`, with one revision on actual change and dirty marking by
   the session adapter. Replays/no-op selections must not revise. Auto Collect is a
   saved opt-in; neither preference proves pass ownership. Do not persist a running
   Auto Open job. Its count/reserve remain session setup only, initialized to 10/0.
3. Profile owns strict round trips/migration. P03A's proposed v15 writer is promoted
   only on changed convenience preferences/applied earnings and defaults legacy
   preferences false. Old v14 readers reject v15: enabling saved controls requires
   the same reviewed mixed-server drain/barrier or compatibility bridge as P03A.
   No live writer activation or migration is authorized by this handoff.
4. Use P02's server `purchases.ownership(userId, key)` for `(Ownership, fresh)`; adapt
   to `(ownership == "Owned", fresh)`. Keys: `auto_open`, `auto_collect`, `movement`.
   P03A's optional `ownershipChanged(userId)` observer on PurchaseRuntime must call
   `convenience.refresh(userId)` immediately, after verification and session identity
   checks. It must stop Auto Open on ownership uncertainty, not wait for another spend.
   `refresh` resolves movement/snapshot; the next bounded `step` revalidates opening.
   On a known revocation/uncertainty also call the owner's `open.stop(...)` directly.

No extension of general `Types.Snapshot` is needed: dedicated
`ConvenienceTypes.Snapshot` and `OpeningDelivery` are private wire contracts.

## Bootstrap and lifecycle hooks (shared init owner)

Start once next to existing remotes/P02:

```luau
local convenience = ConvenienceRuntime.start(folder)
-- Runtime creates ConvenienceRequest, ConvenienceState and ConvenienceResult.
-- No heartbeat, coroutine, income scheduler or ProcessReceipt is installed.
```

After profile/plot initialization and existing movement binding, create exactly one
AutoOpen and one AutoCollect, then `convenience.add(player, owner)` where
`owner: ConvenienceService.Owner` is:

```luau
{
    open = openController,
    collect = collectController,
    binding = movement[player], -- reuse existing PlayerMovement.bind lifecycle
    preferences = function() return session.transaction.state.convenience end,
    setPreference = function(key, enabled)
        -- Non-yielding Rules.setConveniencePreference; mark dirty on changed revision.
        return Rules.setConveniencePreference(session.transaction.state, key, enabled)
    end,
    ready = automationReady,
    ownership = verifiedOwnership, -- wraps P02 ownership as described above
    openAllowed = autoOpenEligible, -- same conservative checks as context, no yield
    collection = function(id) activeCollection = id end, -- empty ID closes flow
}
```

`automationReady()` requires the **same captured session is still current**, a loaded
profile and active lease, no closed/transferring state, `storage.ready`,
`now < storage.safeUntil`, no busy/uncertain save or release. Mirror P02's readiness
boundary; never infer it solely from a client snapshot. Unit preview substitutes
injected readiness/entitlements only; do not grant real effects in unsaved preview.

AutoCollect dependencies, all non-yielding:

```luau
{
    now = os.clock,
    ready = automationReady,
    ownership = function() return verifiedOwnership("auto_collect") end,
    enabled = function() return state.convenience.autoCollect end,
    state = function() return state end,
    transferBank = Rules.transferBank,
}
```

In the existing one-second heartbeat, finish Storage.step and Rules.settle for the
ready sessions first, then call `convenience.step()` once. Mark profiles with changed
revision dirty using existing handling, and use existing rendering/owner-state sends
for wallet/bank changes. Do not start per-player loops. Manual/swap/automatic transfer
callbacks must all stay non-yielding, operating on the same current state aggregate.

AutoOpen dependencies:

- `now=os.clock`, `id=function() return "auto:"..HttpService:GenerateGUID(false) end`.
- `context(collection)` returns the exact `AutoOpen.Context` record. Use server
  `Rules.prices[collection]`, verified P02 ownership, current Humanoid Health,
  `automationReady`, server-tracked active collection/opening flow, existing opening
  mutex/pending manual transaction and cooldown. `spendable` comes from the approved
  ordinary spending interface; never assume the visible total is spendable. Unavailable
  policy/lineage/paid-automation validation means `policyAllowed=false`.
- `purchase(id, collection, reserve)` is a **single non-yielding adapter around the
  existing authoritative ordinary Buy path**. Revalidate current session, ownership,
  policy generation, actual price/spendable balance/reserve, collection, copy safety
  and cooldown immediately before `Transactions.process`. Construct server intent
  `{id=id, action="Buy", choice=collection, revision=state.revision}`. Pass the same
  normal roll/day/window/access arguments as manual Buy; do not add another spender,
  bank implementation or purchase dispatcher. Use existing changed-state handling.
  Do not retry Buy from this callback for a missing reply.
- Capture an immutable **before snapshot before this call**, and the same committed
  after snapshot/intent/reply for its single delivery obligation. Do not recompute NEW
  or duplicate baselines from a later snapshot. `deliver(reply)` calls
  `convenience.deliver(player, {request=intent,before=before,after=after,reply=reply})`.
  Keep this envelope until Presented; repeated delivery uses the identical baseline.
- `reconcile(id)` is **receipt lookup only** (and verifies the stored intent matches).
  It must never call Transactions.process, mint an ID, roll, spend or expire-and-buy.
  Existing Transactions receipts expire at 120s and are capped at 64. Retain the one
  active automation obligation independently until resolved, or pin that receipt via
  a shared-owner hook. If no receipt can be proven, keep stopped/uncertain; returning
  nil forever is safer than buying again. The module stops after a ten-second uncertain
  wait and continues lookup/redelivery only. It never automatically resumes the run.

At manual box/reward/presentation conflicts: stop the automation before dispatch;
reject another opening while `convenience.busy(userId)` is true. Do not gate ordinary
Open 10 or Skip on ownership. Collection selection change, leaving Shop/opening flow,
death and reset must explicitly stop, including while a result is already committed.
Maintain flow state server-side from validated dedicated controls; a client only asks
for focus/selection and cannot authorize price, funds, odds or outcomes.

Immediately before `Storage.prepareTeleport`, call
`if not convenience.beforeHandoff(userId) then return false end`.
It stops Auto Open, defers freeze while Pending/Presenting, and pauses Auto Collect
only when safe to prepare. On confirmed same-lease recovery call
`convenience.recover(userId)`; Auto Collect resumes its saved opt-in at normal cadence,
Auto Open stays stopped. On leave use `convenience.remove(userId)` before teardown;
Runtime also observes PlayerRemoving idempotently. On shutdown destroy it once.
Existing movement unbind remains owned by player lifecycle.

## Client hookup (dedicated controls; no Store dispatch)

1. Subscribe to `ConvenienceState`/`ConvenienceResult` before sending State. Create one
   ConvenienceClient with GUID ids and `requestRemote:FireServer(request)`. Call
   `client.ready()` initially and after AFK recovery; it requests state only.
2. Construct `ConvenienceResults` with `applySnapshot` routed through the existing
   snapshot update path with its stale-revision guard. `present(result,before,after)`
   sets existing `revealBefore`/`reveal`, uses `revealModel(after,result)` and calls
   `opening.present(...)` exactly as ordinary single Buy. It never populates a fabricated
   manual `pending` or sends Buy. On an error, call `client.stop()`, show the message and
   `client.presented(id)` to clear a failed presentation obligation after Stop.
3. Construct ConveniencePresentation. Pass a forwarding callback as the new fourth
   argument of `OpeningController.create`: `bridge.completed(id, finished)` (use a
   nullable bridge until construction completes). This fires after full scope teardown,
   even for Keep, and distinguishes cancellation/death from normal completion.
4. Existing client tick calls `resultQueue.step()` and `bridge.step(os.clock())`.
   No second render loop. Redelivery is ignored after the matching result was presented.
5. Mount ConvenienceControls in the existing Coin Shop/settings surface. Its collection
   callback must return the current chosen ID/name and confirmed ordinary price, and
   `panel.update()` follows accepted convenience snapshots/selection changes. Call
   `panel.layout(availableWidth,availableHeight)` inside existing responsive layout.
   A dedicated safe-area opening overlay uses `Controls.createStop(...)`; show it while
   the automatic workflow is active/committed and leave it accessible during focus.
   The parent must clear topbar/notch insets and have an appropriate DisplayOrder.
6. Call `client.collection(currentId)` on initial Shop shown, `client.collection(newId)`
   on selection changes, and `client.collection("")` plus `client.stop()` on leaving
   the opening flow, death/reset, conflicting result actions or presentation failures.
   Continue committed result delivery after Stop. A revealed "another" action first
   stops automation and then uses the ordinary manual path after workflow release.
7. Before AFK client confirmation call `client.beforeHandoff()` and include
   `resultQueue.busy()` plus the automatic workflow in the existing busy predicate.
   Destroy the client/result queue, scopes/remote connections and overlay during teardown.
   No reconnect flag, saved preference or new income event calls Start.

## Verification record and remaining acceptance

Selected union: UI/input and opening lifecycle, gameplay/security, Display ownership,
bank conservation, storage/AFK and migration compatibility at shared integration.
The added suites are registered in tests/run.py. Its generated test-only Rules export
exposes the actual existing private helper until P03A's export merges; it contains no
replacement transfer formula. Production Modules are used with injected services and
engine/UI doubles. Tests are not mapped into Rojo or installed as production grants.

PASS: pinned `rokit install --no-trust-check` and `wally install`; `stylua src`,
`stylua --check src`, `selene src` (0 errors/warnings/parse errors), Rojo sourcemap/build,
`git diff --check`, and Luau LSP 1.70.1 full-source analysis with Roblox definitions and
the generated sourcemap. Sandbox provisioning/canonicalization limitations were resolved
with approved escalation. The LSP CLI watcher-registration warning is not a source error.
Final behavioral test results are recorded below. No connected Studio was available
(`list_roblox_studios` returned an empty list).

PASS: full `python tests/run.py
C:/Users/natha/Documents/RobloxWorkspace/build/tools/luau/luau.exe` regression suite,
including the six new convenience suites, movement, existing opening/UI/Store, bank
replacement/Equip Best, purchases, Welcome Quest, persistence, AFK and Home/Plaza.
All 18 invalid-configuration startup fixtures also passed. After the final control
close/scroll changes, the affected suites and full-source static checks passed again:
43 Auto Open, 32 Auto Collect, 29 service, 41 client/control, 14 opening bridge,
9 confirmed-result delivery and 31 movement checks. These are isolated module/engine-double checks, not integrated
feature runtime tests. FAIL: none outstanding.

Required **NOT RUN** acceptance after merging/wiring: native two-client callback owner
isolation and replication, real P02 ownership refresh/revocation, manual/automatic/swap
collection races and full wallets, initial/late Humanoid/death/respawn, opening error/
Skip/Stop/recovery, private persistent v15 rejoin and lost-save/lease/AFK release/reclaim.
Verify one scheduler and no growth after rapid controls/reconnect. Inspect free 36 vs 48
with collisions, Home/Plaza and mobile/gamepad navigation. No production fixtures.

Required UI matrix (all **NOT RUN**): D1 1920×1080, D2 1280×720, M1 667×375 landscape,
M2 actual inset landscape phone preset. Check chosen collection/max cost, editable count
and reserve, owned/unowned/stale/pending/error/full-wallet/tutorial states, scrolling,
safe-area overlay Stop, mouse/keyboard/touch/gamepad focus and teardown. UI-double target
assertions do not prove rendering, perceived quality, measured bounds or real input.
Physical phone is separately NOT RUN. T1 is N/A for the focused panel unless integration
changes tablet navigation. Figures/art/audio changes and live sales/release/data mutation
are N/A. Store wiring is deferred to P08 by scope.
