# Permanent Coin modifiers — P03A

Implemented; native verification pending. D1 tier acquisition and full D2 were approved on
October 11, 2026. D2 approval retains the policy/earned-lineage validation gate. The checked-in
runtime has `CoinModifiers.effectsValidated = false`; `PurchaseConfig` still has no platform
types/IDs and no enabled sales or integrations. This task does not implement lineage, policy
services, timed token activation, VIP fulfillment, P03B Double & Claim or final Store wiring.

## Authority and earning contract

`CoinModifiers.resolve(products, ownership, allowed)` consumes P02 configured Pass entries
and its server-only ownership callback. It selects the maximum owned 2/4/8 tier, never their
product. Any tier can be acquired directly; upgrades are full price without automatic credit.
P02 retains acquisition, superseded-offer checks, verification and platform price authority.
Unconfigured identities cannot produce a benefit. Sales switches do not revoke already-owned
benefits; integration readiness and the validation gate control application. A failed refresh
retains a previously verified Owned tier with `ownershipFresh = false`; Unknown grants nothing.
Successful verified non-ownership removes the tier. No saved tier proves current ownership.

`CoinModifiers.factor(inputs, source)` is the common explicit composition boundary:

```luau
inputs = { permanentTier = 1, vipFactor = 1, timedCoinFactor = 1 }
-- permanentTier: 1/2/4/8; VIP: 1/1.1; timed Coin: 1/2
```

Only `Display` and `OfflineDisplay` resolve the product of these factors. `BankTransfer`,
`FixedReward` and `CoinPack` resolve 1. Starting Coins, goals, Login Coins, fixed grants, packs,
Starter/VIP fixed Coins, prices, box odds/outcomes and Shelf acquisition are unchanged. Shelves
earn nothing. P03A activates only the permanent component in isolated tests; VIP/timed values
are arithmetic contracts for P04/P06, without ownership or timer implementation.

`Rules.baseRate` remains R0 after duplicate bonuses and one themed-trio bonus. `Rules.rate`
is the effective online rate. Settlement apportions that factor into the same per-figure banks,
preserving fractions and their existing ceilings. `Rules.setCoinModifiers(state, view, now)`
settles old inputs first, then changes the tier and revision. Inventory grants, Display edits
and admin final-copy preflight also account for the preceding effective rate. Collection and
replacement transfer existing whole value through the same helper; no second multiplier.

`CoinModifierRuntime.sync(storage, products, ownership, allowed, now)` is non-yielding and
bounded. It refuses closed, paused, frozen, busy, uncertain-save/release or expired-lease
sessions. P02's new optional `ownershipChanged(userId)` observer invokes it immediately after
verification, only for the current P02 session. The existing one-second server loop reconciles
deferred changes. No new tasks, timers or connections are owned by the Coin modules; P02 owns
refresh teardown and late-result suppression.

## Owner snapshot

The existing owner-only `State` snapshot now includes:

```luau
coinModifiers = {
    verifiedTier = 1, -- highest configured verified ownership, even while gated
    appliedTier = 1,  -- actually applied to current accrual
    ownershipFresh = false,
    reason = "ValidationPending", -- also IntegrationPending / Ready
}
earningFactors = { permanentTier = 1, vipFactor = 1, timedCoinFactor = 1 }
```

`rate` includes the applied factors. `rates`, `baseRates`, `nextRates` and `bonus` retain their
existing duplicate/set projections; later UI must combine them with `earningFactors` for paid
presentation. The existing banks and `offlinePending` are already computed values and must
never be multiplied in presentation or collection. These fields are optional in the shared
snapshot type for old clients/fixtures, but the new server always supplies them. No guest gets
the private modifier snapshot. P08 must distinguish verified ownership from an applied benefit.

## Offline checkpoint and schema compatibility

Schemas 6–14 still decode and default to free inputs and disabled convenience preferences.
Fresh/free profiles keep writing v14 until an applied paid tier or changed P05 preference
requires v15. Once v15, they never downgrade after revocation. V15 requires both records:

```luau
earningInputs = { permanentTier = 1 } -- effective tier at saved lastSeen, not ownership
convenience = { autoCollect = false, movement = false } -- P05 integration contract
```

Strict decoding rejects missing fields, unknown record keys, invalid tiers/non-boolean toggles
and new fields smuggled into old schemas. Records are copied into immutable save aggregates.
Lease acquisition validates and re-encodes profiles: `Profile.encode` must preserve the decoded
earning checkpoint until `Rules.offline` consumes it. Online inputs still start at 1 pending
P02 verification. After the return calculation, the checkpoint is cleared from runtime and
future saves record current applied inputs alongside the normal settled `lastSeen` boundary.

`Rules.offline(state, wall, paidEffectsAllowed?)` retains pending auto-claim, the free 0.5 rate,
six-hour cap, 60-second minimum, rollback/unknown-clock handling and one final floor. A saved
permanent tier applies only when the server explicitly supplies `true`. Production Storage
currently omits that authorization and remains free. Future integration must obtain validated
per-owner policy/lineage eligibility before computing offline income; flipping the online
gate alone is insufficient. Newly verified ownership at return cannot revalue the prior absence,
old pending award or banks. AFK settlement/save/release and source recovery remain unchanged.

P04 must supply effective **intervals** covering the capped absence/online settlement window,
split at approved timer boundaries, and use `factor(interval.inputs, source)` for each interval.
Sum unrounded amounts, then clamp/floor the normal offline reward once. The persisted current
timed power alone cannot determine overlap; P04 must add its approved timestamp state and schema
validation. P03A selects no activation, expiry, extension, clock-backtracking or token rules.
P03B adds an extra N for an immutable displayed return; it must consume the already-computed N,
not recalculate elapsed earning or add a permanent offline pass.

**Mixed-server release constraint:** old v14 readers reject v15. They fail closed rather than
erase progress, but affected players cannot rejoin those servers. Keep the v15 writer/paid
activation gated until a verified server drain/maintenance barrier or tested compatibility
bridge is in place. A safe rollback must keep v15 support and all saved catalog IDs; do not
restore an old decoder, strip fields, reset progress or change Economy2 namespaces. Existing
lease generations do not by themselves solve incompatible-reader overlap. No release occurred.

## P05 handoff

Shared exports are ready in the P03A worktree:

- `Rules.transferBank(state, id) -> number`: existing private helper now server-exported, no
  settlement, revision, tutorial advancement or multiplier. P05 selects only unique occupied
  unlocked Display IDs and calls after normal settlement under the same non-yielding session.
- `state.convenience`: saved booleans above, default false. They grant no entitlement themselves.
- `Rules.setConveniencePreference(state, key, enabled) -> boolean`: accepts `auto_collect` or
  `movement`, changes one preference/revision and promotes to v15 only on a real change. P05's
  adapter must validate readiness, ownership and request identity before calling it, and mark
  the profile dirty after changes. Replays/same selections are successful no-ops.
- `PurchaseRuntime.start(folder, sessionFor, ownershipChanged?)`: shared non-yielding observer
  for verified movement/automation refresh. The callback must never trust client success.

P05's focused AutoOpen, AutoCollect, ConvenienceService/Protocol/Types, PlayerMovement,
dedicated client controls and tests are now merged alongside these shared contracts.
The stable bootstrap handoff is [Convenience upgrades](CONVENIENCE_UPGRADES.md).
Gameplay wiring and native verification remain pending. Auto
Open must remain gated on validated policy/lineage, use ordinary transactions and stop before
AFK handoff. Preserve P05's genuine collection lesson and opt-in behavior. Shared schema/init
changes were owned by P03A to avoid concurrent edits. The merge does not activate
paid effects, configure products or enable sales.

## Verification

Selected gate union: server economy/security, profiles/offline/schema, Display ownership and
replication; tooling checks for the test harness adapter. UI/3D/device visual gates are N/A for
this backend change. Existing UI/plot tests still ran as part of the domain regression suite.

PASS, October 11, 2026: pinned `rokit install`, `wally install`, `stylua src`,
`stylua --check src`, `selene src` (zero errors/warnings), Rojo sourcemap/build, `git diff --check`,
and Luau Language Server 1.70.1 analysis of all `src` with the Roblox definitions. The final
full standalone regression suite passed, including **191 new Coin checks** and 18 invalid-config
fixtures. Tests use actual source modules, isolated fixture IDs and injected storage/services,
never production profiles. Sandbox cache/canonicalization failures were resolved with approved
tool escalation. FAIL: none outstanding.

NOT RUN: native DataStore persistence/rejoin, two-client Studio replication/owner isolation and
real ownership refresh/purchase service acceptance. Studio MCP returned no connected instances.
Required isolated acceptance: configure fixture pass identities only in a private test build,
verify 1/2/4/8 refresh during an accrual interval, revocation/failure, owner-only snapshots,
manual/swap/automatic transfer races, v15 rejoin, lost-save recovery and AFK frozen/released
checkpoint behavior. Demonstrate old-reader refusal in isolated stores and the release barrier.
Real policy/earned-lineage validation is pending; effects must stay disabled until complete.

N/A: live products/sales, publication, paid offline fulfillment, P04 timers, VIP benefits,
production profile mutation and final Store integration.
