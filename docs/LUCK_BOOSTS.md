# Luck and timed boosts integration contract

P02 and P03A are prerequisites. D1/D2 values are approved; the policy/earned-lineage
validation gate remains closed. Platform identities/types, sales and release are not enabled.
No Double & Claim behavior belongs to this implementation.

Shared integration ownership: f23a makes additive local Profile/Types/Rules/Storage/bootstrap
changes for this implementation. The MN-22 task in bfd0 owns the final cross-worktree merge,
applying these changes before its offline claim hooks. PurchaseService/PurchaseRuntime and
OfflineEarnings belong to MN-22 and are not edited here.

Proposed schema 16 adds `boosts`: unused token counts, Coin/Luck UTC timers, last accepted
clock, durable P02 delivery markers and activation request markers. Existing schemas 6–15
remain readable. Free profiles remain v14; v15 preferences/tiers remain v15. A boost operation
promotes to v16 permanently. No reset/store change; old readers refuse v16. A compatibility
bridge or drained-server barrier is required before enabling writes in a released game.

V16 `earningInputs` captures permanent tier, VIP factor and optional *eligible saved Coin
timer* at lastSeen. It is an offline calculation checkpoint, never entitlement proof.
Lease acquisition must preserve it until Rules.offline consumes it. Normal reward N uses
the FIRST capped absence interval [lastSeen, lastSeen + min(absence, cap)), saved factors,
eligible timer overlap and one final floor. Return-time ownership/timers never reprice it.
MN-22 freezes that computed whole offlinePending value rather than calculating it again.
The final combined MN-22 integration adds schema17 on a positive offline award, preserving
all >=16 fields/checkpoints and applying its reader/writer release barrier even to free returns.
See [final award/receipt and integration contract](OFFLINE_DOUBLE_CLAIM.md).

Boost delivery consumes a validated P02 ledger entry and its stable receipt key. It copies
token value and a marker into one profile save. Replays recover the same promise; failed or
uncertain saves pause activation and acknowledgement. The P02 reservation is never deleted.
The token-only handler refuses mixed Coin/token bundles so Starter fulfillment cannot grant
half a bundle; that owner must deliver both components atomically through its own adapter.

Activation accepts only server-resolved owner, request id, token id and expected revision.
No price, power, duration, UTC timestamp, eligibility or outcome is accepted from a client.
Same strength extends time up to 24 hours; other Luck strength, redundant Luck 2 and any
invalid combo component reject the whole operation with the unused token retained.

Implemented; native verification pending. The final integration owner must keep these guards
when merging MN-22 and must not set an economic validation switch as a substitute for lineage.

`BoostRuntime.sync(storage, products, ownership, eligibility, wall, now)` resolves permanent
Luck from P02 verified configured Pass ownership and observes UTC. `eligibility` is the
current server result `{policy = "Allowed" | "Restricted" | "Unknown", lineageValidated,
disclosureReady}`. All three checks **and** `Boosts.effectsValidated` are required. Production
bootstrap deliberately supplies Unknown/false until those services and Store disclosures exist.
Runtime activation repeats that eligibility check. These fields are never remote inputs.
Previously verified permanent ownership survives a failed refresh, with freshness exposed;
new Unknown never grants Luck. Redundant Luck 2 uses verified permanent ownership even when
its application is suppressed. Paid policy suppression applies centrally in `Rules.luck`,
so Single, Open 10, Deals, Daily, Login and both Welcome paths share the same restriction.
Pity and minimum-rarity rewards retain their independent free behavior.

`CollectionEconomy.buckets(collection, pity, luck?, minimum?)` is the authoritative percentage
distribution. It resolves existing pity first, multiplies Rare/Legendary/Mythical weights by
max(permanent, timed, 1), normalizes and conditions on a reward floor. Guarantees retain 100%
and Mythical priority. `odds(pity, luck?)`, `rarityOdds(pity, luck?)` and `roll(..., luck?)`
consume that distribution; within-rarity weights are unchanged. Batches advance pity after
each grant. `Rules.luck` supplies only current server inputs, never client odds or expiry.

`Rules.settle` integrates UTC timer overlap into monotonic elapsed income, including fractional
seconds. A delayed tick crossing expiry accrues the exact boosted part and the baseline rest.
Each inventory/Display/permanent-input change keeps the existing preceding settlement.
`Rules.earningFactors` resolves the current timed factor for rate and presentation; bank
collection never multiplies value again. The monotonic/UTC anchor is runtime only. UTC never
moves the accepted anchor backwards; invalid/backward observations suppress paid effects.
The accepted whole timestamp is persisted in v16 and checked before activation/offline rewards.
Timers remain saved after expiry; the `[started, expires)` predicate ends their effect exactly.

`BoostRuntime.fulfill(storage, receiptKey, committedEntry, now, commit?) -> boolean` is the
token-only P02 reserved-entry adapter. `commit` defaults to Storage.flush and is injected only
by tests. P02 must invoke it **after** its durable ledger commit, and replay committed entries
on join/refresh to recover a crash between sidecar and profile writes. Receipt acknowledgement
requires true; false retains the reservation. Do not recompute a saved entry from a newer SKU.
Mixed Starter entries return false and need the Starter owner's atomic whole-bundle adapter.
The P02 owner is adding this callback; PurchaseService/Runtime are deliberately untouched here.

`BoostRuntime.activate(storage, raw, eligibility, wall, now, commit?) -> Result?` parses only
`{id, token, revision}`. Confirmed replay returns success without spending a second token;
changed replay fails. Activation never accepts a duration, power, outcome or owner identity.
Bootstrap owns `BoostActivate`/`BoostResult`, resolves the callback Player's current session,
limits attempts to one per second, and drops late replies to replaced sessions. P08 owns later
client controls; this task does not change the Store layout or enable purchase prompts.

Both token delivery and activation set `storage.ready = false` and runtime
`state.boostCommitPending = true` before the potentially yielding save. Gameplay cannot consume
staged effects/tokens. Storage preserves its exact pending aggregate on lost replies/failure,
then clears the pending flag only after generation confirmation. Rejoining restores the saved
consume/marker/timers together, or restores the older aggregate with no partial combo. Ordinary
storage leases, failure pauses, AFK handoff and namespace behavior remain intact. Existing P02
2048-marker and 1,000,000-per-token safety bounds fail closed, retaining reservations/tokens;
they never evict paid markers. Before releasing sales, review long-term ledger capacity and
an approved archival strategy. These are engineering bounds, not advertised product limits.

Owner-only snapshots add `luckModifiers`, `boosts`, `rarityOdds` and `freePityOdds` alongside
the existing actual `odds`, untouched unmodified `baseOdds` and independent `pityProgress`.
The boost view includes unused tokens, saved strength/start/expiry, remaining seconds, actual
Coin factor/Luck weight, clock validity, paid eligibility and redundant Luck warning.
Luck is **weights**, not a promise to double every final probability. P08 must distinguish
paid weights from free pity and use these actual itemized odds before an eligible spend.
No guest receives private modifiers/tokens; absolute UTC expiry supports later UI countdowns.

Normal N remains `state.offlinePending`: a computed whole value, not a rate or mutable quote.
P03B must freeze it immediately after Rules.offline, before new ownership/tokens are applied.
Calculation identifier: `display-boost-overlap-v1`. This implementation produces no assisted
source partition. Production Storage therefore keeps `paidEffectsAllowed` omitted/false.
Isolated tests pass true only to verify the approved arithmetic; enabling that flag in a real
session requires the validated earned/assisted partition from the policy/lineage integration.
MN-22 extra N, reservations, receipt associations and popup controls are outside this patch.

Schema compatibility review: v6–v15 decode defaults preserve all banks, quantities, pity,
Display/Shelves and pending rewards; v16 required records fail closed on corruption. Timers,
delivery/request markers and saved earning checkpoints are deep-copied. Unchanged free profiles
still write v14, v15 never downgrades, and token operations promote permanently to v16.
V14/v15 readers reject v16. No release/writer activation is authorized without a drained-server
barrier or tested bridge; rollback must preserve v16 and all catalog IDs. Profiles are not reset.

PASS, October 11, 2026: rokit install; wally install; stylua src and --check; selene src
(0 errors/warnings); Rojo sourcemap/build; all-src Luau Language Server 1.70.1 with Roblox
definitions; git diff --check; full standalone domain/regression harness, including 988 new
Luck/boost checks, 29 token persistence/failure checks and 22 isolated activation checks.
The isolated activation fixture lifts the validation flag only in generated ignored copies.
Production source, product identities and all sales remain disabled. Existing Coin, pity,
offline, purchase, save-safety, Display and AFK regressions pass. Cache/path failures in sandboxed
Wally/Selene/Rojo were resolved by tool escalation. No outstanding FAIL.

NOT RUN: native Studio persistence/rejoin, paid service/policy/disclosure acceptance and
two-client owner isolation/replication, because Studio MCP returned no connected instances.
Required private acceptance: delayed expiry tick, paused/failed save + rejoin, combo replay,
policy change during active Luck on every opening path, UTC rollback, AFK rejoin and a second
client unable to observe/change the owner's tokens/odds. Actual earned/assisted lineage and
platform policy validation remain pending; effects must stay off. N/A: Store redesign, new
art/assets, physical-device visual changes, live product creation, sales and publication.

Shared files for the final integration owner: Types, Profile, Rules, Storage and server init;
CollectionEconomy is owned by this task. Adopt the new BoostTypes/Boosts/LuckModifiers/
BoostProtocol/BoostRuntime modules and test harness registrations before adding MN-22 schema
and claim hooks. Preserve `schemaVersion >= 16` handling when adding a later schema (replace
exact version tests only for the newly recognized compatible version), use max on promotions,
and compose receipt routing rather than replacing either owner’s handler.
