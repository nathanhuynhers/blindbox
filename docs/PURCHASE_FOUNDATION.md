# Purchase and entitlement foundation (P02)

Implemented 2026-10-11; native verification pending. Consumes approved P01 D1 and P07.
All twenty product variants have **nil platform types/IDs**, `salesEnabled = false` and
`integrationReady = false`. No launch subset was selected. No products, sales, place version
or production data were created/changed. Client presentation and final wiring are untouched.

## Modules and authority

`PurchaseConfig` owns the approved benefit promises, default list prices and future platform
allowlist. Defaults are planning metadata, never the price shown or charged. `PurchaseProtocol`
rejects extra fields, caller identities, prices, grants and completion messages. `Entitlements`
queries server `UserOwnsGamePassAsync`; successful false results remove ownership, transient
errors preserve previously verified session ownership with `ownershipFresh = false`. A new join
starts Unknown until verified. No benefits are inferred from a purchase-event boolean.

Server product modules can call the returned runtime's `ownership(userId, productKey)` for
`(Ownership, fresh)` and `claimPass` for a once-only bundle promise. Neither is a remote.
Missing sessions return Unknown/false. Product implementations must still check readiness and
settle preceding income intervals before changing effective benefits; no effect observer is
wired by P02 itself. P03A adds the optional non-yielding `ownershipChanged(userId)` dependency
and third `PurchaseRuntime.start` argument, called immediately after verification for the
current session. Consumers can read `ownership` inside it and settle before applying changes;
late results after removal cannot notify a replacement session. Never use the client's reported
ownership as server authority. See [Coin modifier and P05 integration contract](COIN_MODIFIERS.md).

`PurchaseAvailability` combines configuration, profile readiness, ledger health/capacity,
ownership, highest owned Coin tier, outstanding prompt and product integration eligibility.
`PurchaseService` owns request replay/rate limits, prompt state, reconciliation and fulfillment.
`PurchaseRuntime` is the sole `ProcessReceipt` adapter and binds owner-only remotes/lifecycle.
It accepts only the callback Player as remote identity. Product-finished events update prompt
presentation only; pass-finished events trigger ownership verification only.

The runtime readiness check requires an active loaded profile, persistent handle, ready and
unexpired lease, no busy save, no uncertain pending snapshot, no close or teleport handoff.
Unsaved Studio preview cannot prompt or fulfill real paid purchases. Configured ownership/ledger
refresh retries every 30 seconds while connected; explicit Refresh is coalesced to ten seconds.
With the checked-in unconfigured catalog, no purchase DataStore or ownership API is accessed.

## UI integration contract

Shared types: `src/shared/PurchaseTypes.luau`. The server adds:

```luau
ReplicatedStorage.Remotes.PurchaseRequest:FireServer({
    id = "unique-bounded-request-id", -- 1..64 bytes
    action = "State", -- or "Refresh"; neither accepts product
})
ReplicatedStorage.Remotes.PurchaseRequest:FireServer({
    id = "purchase-attempt-id",
    action = "Purchase",
    product = "pack_small", -- logical allowlisted key, NEVER a numeric product ID
})
-- PurchaseState.OnClientEvent(snapshot: PurchaseTypes.Snapshot, result: PurchaseTypes.Result?)
```

Subscribe before requesting State. Snapshots carry increasing per-join sequence numbers; ignore
older snapshots, reset on a new connection. They are sent only to the owner, never broadcast.
Use the product's `available`/`reason`; do not derive eligibility from default prices or UI cards.
Configured `kind` and `platformId` support the viewing client's official runtime price lookup
(`GetProductInfoAsync`, correct InfoType), including regional prices. No price is supplied until
the identity is configured; never display a default as a live price. Future preflight must verify
required disclosures before allowing a prompt.

| P02 key | Existing P07 card key |
| --- | --- |
| `starter`, `vip`, `luck` | same |
| `coins_2`, `coins_4`, `coins_8` | `coins2`, `coins4`, `coins8` |
| `auto_open`, `auto_collect`, `movement` | `autoOpen`, `autoCollect`, `speed` |
| `pack_small`, `pack_medium`, `pack_large`, `pack_huge` | `pouch`, `stack`, `sack`, `chest` |
| `coins_boost_15`, `coins_boost_30`, `coins_boost_60` | `boostCoins` with selected duration |
| `luck_boost_2`, `luck_boost_4`, `combo_boost` | `boostLuck2`, `boostLuck4`, `boostCombo` |
| `offline_double` | `doubleClaim` (information only; unavailable) |

Results distinguish Rejected, PromptOpened, Cancelled, AwaitingReceipt, Recovering, Reserved and
State. **Reserved confirms durable reward value, not a wallet deposit or active boost.** The
foundation has no timer activation, wallet release, movement toggle or gameplay multiplier.
Do not show a Coin burst, completed offline claim or activated perk on Reserved. `reserved`
contains exact Coin credit and unused token promises; `receiptCount` includes lifetime pass
bundle markers. Per-product fulfillment is None/Pending/Reserved/Recovering. Ownership is
independent of fulfillment. Previously verified ownership can remain Owned while stale; that
does not authorize new prompts. `Verified` is reserved in the result type for future integration;
current ownership confirmation is the snapshot's Owned + fresh state.

Requests use a four-token bucket refilling at one/second, including malformed requests. Excess
traffic is silently dropped; reconcile with State. A purchase ID replay returns the prior result
and a current snapshot; changing its product rejects it. Keep the same ID on a lost reply, never
purchase again to retry delivery. At most 256 distinct purchase attempts are retained per join;
State/Refresh do not consume that capacity. Capacity fails closed rather than forgetting attempts.
One native prompt is retained until cancellation or both prompt-close and receipt confirmation,
in either order. An uncertain platform prompt error blocks reprompting; reconcile via the platform
event/rejoin. AwaitingReceipt is not proof of a charge. There is no client completion endpoint.

## Durable fulfillment and compatibility

`PurchaseLedger` uses separate `BlindboxTown_Purchases_Studio_v1` /
`BlindboxTown_Purchases_Live_v1` stores, key `Player_<UserId>`. Its strict, deep-copied version-1
aggregate is `{version, entries}`. Each entry contains the immutable logical product, platform
identity/kind and exact reserved grant `{coins, tokens}`. Developer receipt keys are
`receipt:<PurchaseId>`; once-per-account verified pass bundle keys are `pass:<PassId>`.
`claimPass(userId, productKey)` is server-only and requires fresh verified ownership; product
implementation must invoke it after reconciliation/rejoin. A pass callback cannot grant a bundle.

Receipt marker and reward credit/token promise commit in the **same UpdateAsync value**.
Callbacks perform no gameplay mutation, network call or yield. Callback retries operate on
deep copies. Concurrent servers merge the current aggregate; concurrent local writes defer.
The return value is decoded and checked for the matching marker before PurchaseGranted.
A lost response returns NotProcessedYet even if committed; retry/rejoin recovers the original
promise without granting again. No prompt reservation is needed for fixed grants, so a charged
known product can recover after rejoin or outside-game purchase. Sales/eligibility changes and
wallet capacity do not cancel delivery. Missing players, paused/expired/conflicting leases,
unknown products, malformed receipts and unconfirmed storage return NotProcessedYet.

Never remove a previously sold identity from dispatch or change its promise. Keep disabled
historical entries for receipt recovery. Unknown/exception receipts require catalog/support
review; never acknowledge them to suppress retries. The platform has no timed retry guarantee
for ProcessReceipt: do not promise immediate recovery; rejoin/new purchases can trigger it.

Coins remain reserved at full wallet capacity. There is deliberately **no credit withdrawal**
API yet: copying a sidecar reward into a profile and marking it consumed in a second write would
create a crash duplication/loss window. Product integration must first establish one durable
aggregate for consumption + wallet/lineage, or a tested recoverable transfer protocol; never
mark consumed before wallet commit or release directly through ordinary transient Transactions.
Boost activation has the same requirement for token consumption + timer. Do not enable sales
while reserved value has no approved, implemented usable delivery path.

At the P02 foundation milestone, Economy2 schema14, schemas6–13 upgrades, namespaces,
offlinePending and player progress were unchanged. The later v17 integration is described
below and in DATA_MODEL.md. Older game servers cannot overwrite this sidecar, and its grants cannot
enter their undifferentiated wallet. This is compatible for the disabled foundation only.
Later wallet/lineage/award schema changes require a separately reviewed mixed-server barrier or
bridge; rollback must retain ledger records and dispatch identity history.

Retention: never prune receipt markers. Version 1 allows 2,048 lifetime entries per account
(bounded below the DataStore size limit with the validated field limits). At capacity it blocks
new prompts and new grants while still acknowledging confirmed duplicates. This is a storage
safety bound, not an approved product purchase limit. A reviewed partition/retention expansion
and capacity monitoring are **required before repeatable products launch**, to avoid a charged
overflow receipt needing an operational migration. Corrupt/newer/oversized data fails closed;
no reset, truncation or fallback profile is written.

## Offline Double & Claim: integrated, purchases disabled

MN-22 now supplies frozen awards, normal claims, reservations and receipt fulfillment in
schema17's **single profile aggregate** through P02's optional `prepare`/`fulfill` hooks.
The existing native launcher/remote protocol is reused. Its candidate permanent product/award
binding, retained credits, cancellation recovery, unresolved decisions and tests are documented
in [the offline implementation and P08 handoff](OFFLINE_DOUBLE_CLAIM.md). This supersedes the
future-integration status below; those design prerequisites remain protected and sales stay off.
P04's fixed token grants use `deliverReserved` only after an immutable sidecar entry commits;
bounded join/refresh replay recovers interruptions. Mixed Starter grants remain reserved.

The following records the original P02 design constraints, rather than current implementation status.

The approved promise is normal reward **N**, purchased extra **N** for one specific return.
There is no permanent offline entitlement. `OfflineAward` names the future server-created frozen
award identity, exact whole N, calculation version and base-claim status. The current remote
does not accept an award or amount. `offline_double` has no price/type/ID/grant and every receipt
for it is deferred. Generic fixed-grant dispatch must not be reused to guess N.

Before any prompt, durably persist the immutable award + bonus reservation. The future record
must retain awardId, N, calculation/version inputs, baseClaimed, reservation identity and status,
bound PurchaseId and bonusGranted. These fields, reward credit and receipt marker must share a
durable aggregate. A profile-schema design or recoverable migration of award authority into the
ledger is required first; this foundation does not pretend the two stores are atomic.

State transitions to implement/test in the offline task:

1. Pending award → Reserved: under the profile lease, freeze N and persist before prompting.
   Normal claims must respect this durable reservation; rejoin auto-claim cannot erase it.
2. Reserved → BonusGranted: match a server receipt to that reservation, record PurchaseId,
   receipt marker, purchased extra N and claim status atomically. If base was unclaimed, claim
   N + extra N once. If already claimed, preserve only the extra N credit. Never recompute N
   from current Display, a newer absence, current multipliers or the popup age.
3. Failed/unconfirmed write → Recovering: no acknowledgement; retry the identical frozen
   grant. Purchased extra credit never clips or expires; release only through the eventual
   durable wallet/lineage path.

**Association gate:** receipts contain no award/request ID. Allow one unresolved reservation per
account; never rebind it to a newer award. Cancellation is not evidence that no delayed receipt
exists. Retain the same reservation across cancellation/reopen/disconnect; reopening can only
target that same award. First matching PurchaseId consumes the reservation once; replay is
idempotent. A second distinct charged receipt is an exception, not a second double and not a
grant against the next return. The compensation/support treatment and a provably safe way to
release a cancelled reservation remain unresolved. Do not permit a new award's purchase until
those decisions and out-of-order/cancelled-prompt tests establish unambiguous association.

Keep the ordinary free claim available through a reviewed cancellation/recovery path and retain
the reserved extra after base auto-claim. With today's schema/auto-claim, these invariants cannot
be asserted, so this task leaves MN-22 entirely disabled and implements no offline gameplay.

## Remaining implementations and decisions

- D2: Coin/Luck composition, clock/stacking, policy-safe earned/assisted lineage and all
  downstream random-opening gates; D3: launch subset; explicit platform types/IDs and release.
- MN-04/05/06/10: income settlement, fixed-credit release, Starter reconciliation and VIP daily
  supplement. MN-07/08/09: Auto Open, Auto Collect and movement effects/toggles. MN-11/12:
  token activation, durable timers, Luck odds/disclosure. None is implemented here.
- MN-22: price/platform type, durable award schema, receipt association, cancellation and extra
  charged-receipt compensation. Follow the design above before enabling it.
- Integration: register non-yielding authoritative eligibility preflight in PurchaseRuntime
  (currently always false), implement benefit delivery, then connect P07 presentation and actual
  viewing-player prices. Configuring an ID or toggling a sale flag alone cannot open purchases.
- Repeatable launch: partition/capacity plan, private native persistence/rejoin, multiple clients,
  failure recovery and separately authorized release review. No production tests or mutation.

## Official API review and verification

Rechecked official documentation on 2026-10-11: [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService),
[developer products](https://create.roblox.com/docs/production/monetization/developer-products),
and [passes](https://create.roblox.com/docs/production/monetization/passes). The documented server
ProcessReceipt flow and ownership query are used. PromptProductPurchaseFinished is explicitly
not fulfillment proof. No competing BindReceiptHandler is registered.

Selected union: request/security, server gameplay/economy and persistence/failure recovery from
[quality gates](qa/QUALITY_GATES.md). Local tests use generated isolated copies and injected
stores/platform calls; test IDs never enter production source or Rojo mappings.

Verification results are recorded after the final checks below. Native purchase/persistence and
multiplayer checks remain NOT RUN: no Studio instance was connected. UI/device/figure gates are
N/A for this server-only task; final UI integration must run its own device matrix.

Final local record, 2026-10-11:

- **PASS:** `rokit install --no-trust-check` provisioned the exact existing pins;
  `wally install` resolved the unchanged empty manifest. No dependencies or tool upgrades.
- **PASS:** new/changed server/shared files formatted with pinned StyLua; `stylua --check src`,
  `selene src` (0 errors/warnings/parse errors), `git diff --check`.
- **PASS:** Rojo sourcemap and `rojo build default.project.json -o RobloxWorkspace.rbxlx`.
  No test source is mapped into the build; generated output/cache remains ignored.
- **PASS:** Luau LSP 1.70.1 full `src` diagnostics with Roblox definitions and sourcemap;
  zero type errors. Its CLI watcher-registration warning is not a source diagnostic.
- **PASS:** `python tests/run.py C:/Users/natha/Documents/RobloxWorkspace/build/tools/luau/luau.exe
  Purchases.spec SaveSafety.spec AfkStorage.spec Offline.spec Mvp.spec Tutorial.spec Deals.spec`:
  105 purchase assertions; 458 save-safety/migration; 42 AFK persistence; 40 offline;
  2,220 economy/transaction; 3,179 Welcome Quest; 140,138 deal checks. Includes exact runtime
  profile-readiness logic, ownership failures/concurrency, duplicate/uncertain receipts,
  callback conflict/retry, disconnect/rejoin, unknown products, capacity, wallet overflow
  credit, cancellation, prompt uncertainty/order and malformed/rate-limited requests.
- **FAIL:** none remaining. Initial sandbox/tool-cache and type-diagnostic failures were resolved.
- **NOT RUN:** native private DataStore rejoin, platform prompt/ownership-cache behavior and
  multiple-client remote tests: no connected Studio or configured test product identities.
- **N/A:** final UI/device/figure acceptance, production product creation/sales/publication/data
  mutation. Gameplay effects, credit consumption and full offline Double & Claim are deferred
  product/integration work, not verified by this foundation.
