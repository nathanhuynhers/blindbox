# Coin packs, Starter Pack and VIP (P06)

Implemented; native verification pending. Consumes the recorded D1/D2 approvals in
[MONETIZATION](MONETIZATION.md), P02's sole purchase dispatcher, P03A earning factors and
P04 unused tokens/save barrier. No client presentation files or live configuration changed.

## P08 handoff and availability

All six products remain **unavailable**. `PurchaseConfig` retains nil platform types/IDs,
`salesEnabled = false`, `integrationReady = false`. Platform configuration/types, policy and
earned/assisted lineage validation, disclosure integration, launch subset and release remain
unresolved. Assigning an ID alone cannot enable sales. These interfaces are ready for disabled
Store wiring and isolated fixtures, not for sales or spendable paid-Currency fulfillment.

| P02 key | Approved promise | Eligibility |
| --- | --- | --- |
| `pack_small` | 15,000 fixed Coins | Repeatable; full amount must fit before prompt |
| `pack_medium` | 60,000 fixed Coins | Same |
| `pack_large` | 240,000 fixed Coins | Same; no release approval |
| `pack_huge` | 1,200,000 fixed Coins | Same; no release approval |
| `starter` | 7,500 Coins + one `Coins2_15` unused token, 900 seconds | Lifetime once per account; verified pass; no age/progress/prior-spend condition |
| `vip` | 1.10 Display-derived rate + 500 fixed Coins on the existing daily Grove claim | Verified entitlement; existing UTC marker; no retroactive daily replay |

Keep P02's `PurchaseRequest`/`PurchaseState`, logical keys, ownership, availability, fulfillment
and result states. Actual prices require platform metadata after configuration. Only additive
optional owner-only `ProductState.package` (`PurchaseTypes.PackageState`) was introduced:

- `eligible`, `eligibilityReason`: server preflight. Reasons: `ProfileUnavailable`,
  `AlreadyClaimed`, `CapacityUnavailable`, `ValidationPending`, `UnsupportedProduct`, `Available`.
  P02's top-level `reason` remains `Unconfigured` for all current offers.
- `coins`, `token`, `tokenSeconds`, `vipFactor`, `dailyCoins`: exact promise; unrelated fields nil.
- `claimed`: confirmed lifetime Starter marker. False during an unconfirmed save cannot
  authorize another prompt; use top-level availability/recovery. Ownership is separate.
- `confirmed`, `fulfilledCoins`, `fulfilledTokens`: durable product deliveries, cumulative for
  that product. Pending in-memory changes never count as confirmed fulfillment.
- `assistedCredit`: account-wide reserved package/daily Coins, not a per-product wallet balance.
  `walletCredited = 0`, `creditUsable = false` until lineage transfer is integrated. Do not show
  spendable Coins or a wallet burst from `Verified` alone.
- `appliedVipFactor`: actual input, currently 1. `dailyClaimed`, `dailySupplementAvailable`:
  server UTC VIP claim state, not a second claim action. Existing gameplay fields supply
  `dailyReady` and `nextDay`.

P02's `snapshot.reserved` remains its immutable sidecar promise summary, not a wallet deposit
or tokens to add again to gameplay inventory. Starter uses the existing explicit P04
`BoostActivate` flow; delivery never starts its clock. Older consumers can ignore optional
package data. There is no new purchase remote, launcher or client completion authority.

## Fulfillment, restrictions and P02 changes

`PackageGrants` validates approved fixed promises and capacity. `PackageRuntime.fulfill`
consumes P02's committed immutable `Ledger.Entry`; P02 still serializes PurchaseId under the
purchaser's sidecar key. Delivery saves assisted credit, marker and Starter token together.
No fixed amount is multiplied by Coin tiers, VIP, timed effects or Luck.

The current wallet has no paid lineage. Purchased Coins, post-prompt overflow and verified
VIP daily supplements therefore remain **assisted credit**. No box/Deal/batch/slot/Shelf spend
or later earnings path can consume it. There is no credit-transfer function in this schema.
Before sales, shared lineage work must add and validate capacity-aware transfer, paid-derived
figures/duplicate/slot-income treatment and the restricted player's earned-only route. Until
then, package prompts and VIP's rate benefit stay disabled. Paid value is preserved even when
current policy restricts use; the unused Starter token also remains saved but activation gated.

P02 changes are limited to optional `packageState` feedback, invoking existing `deliverReserved`
after `claimPass` reserves its promise (failure returns Recovering), and rechecking integration
eligibility after the yielding metadata lookup immediately before a prompt. The sole dispatcher,
ownership authority, sidecar schema and protocol are preserved. Starter reconciles fresh verified
ownership on the existing scheduler at a 30-second retry cadence, outside the non-yielding
ownership observer. Its profile lifetime marker prevents replay across sessions or ID changes.

Sidecar/profile failures defer acknowledgement. A crash between stores leaves the whole
obligation reserved. Profile failure freezes gameplay and retains the exact pending snapshot;
lost replies reconcile its generation. Replay never regrants. Credit/token/marker capacity
failure preserves the sidecar obligation. Both histories are bounded at P02's 2,048 markers,
never pruned; sustained sales require a future safe partition/retention plan. Historical IDs and
immutable promises must remain recoverable and must not be repurposed.

## VIP and daily claims

`PackageRuntime.sync` reads P02 server ownership. `Rules.setVip` settles the old interval before
assigning factor 1/1.10, never multiplying existing banks or stacking refreshes. Composition is
highest Coin tier * VIP * shared Coin timer once. Offline saves reuse P04's VIP checkpoint and
timer-overlap formula. Failed ownership refresh preserves prior verified ownership; rejoin
requires verification again. VIP gives no Luck, speed, automation, cosmetics or join bonus.

Successful `Daily` preflights credit capacity and adds exactly 500 assisted Coins in the same
mutation as the Grove box and `lastDailyDay`. Verified ownership preserves that fixed promise
as credit even when rate use is suppressed. `commitDaily` saves before success acknowledgement;
failure retains the full aggregate for recovery. Same/backward UTC day, late ownership after
that day's claim and rejoin cannot replay it. Login, goal and Welcome rewards remain separate.

## Schema and release compatibility

Forward-only Economy2 **v18** adds required `packages = {assistedCredit, deliveries, starterClaim?}`.
Entries retain exact P02 identity/kind/grant. Decode validates finite bounded values/maps,
approved contents, a single lifetime Starter, preserved purchased credit and 500-Coin supplement
increments. Starter retains its token or an activation record. Encode/decode deep-copy data;
malformed/future/downgraded records fail closed, never reset.

Valid schemas 6–17 retain progress and do not promote just by loading. V18 is written only by
package delivery or VIP daily credit; VIP rate checkpoints use existing v16. Promotion freezes
older pending offline value into the existing v17 structure. Economy2 namespaces and P02's
sidecar version are unchanged. Free profiles remain v14 unless existing features promote them.

Old readers reject v18. Release requires a separately authorized reader/writer barrier or tested
bridge for schemas 15–18, including pre-existing v17 offline returns. Never downgrade, erase
credit/markers or reset stores. No product creation, sales, publishing or production mutation
was performed. Schema implementation is not release approval.

## Verification

Affected gates: server economy/purchase authority, persistence/rewards, owner isolation and
compatibility. Actual P02, Rules, Profile, Storage and Persistence modules run with isolated
clock/DataStore fault injection; configured IDs and ownership exist only in test fixtures.

PASS: 155 new package/recovery checks (105 domain, 50 persistence/adapter); 21 relevant suites
including existing purchase, modifiers, boosts, offline, daily/Welcome and save-safety suites.
Pinned checks: `rokit install`, `wally install`, `stylua src`, `stylua --check src`, `selene src`
(0 errors/warnings), `rojo build default.project.json -o RobloxWorkspace.rbxlx`, `git diff --check`.
Luau Language Server 1.70.1 analyzed all changed source modules and their dependencies with the
generated sourcemap and local Roblox definitions, with no diagnostics. The deterministic harness
used existing Luau 0.739 at `C:/Users/natha/.codex/worktrees/f23a/RobloxWorkspace/build/tools/luau/luau.exe`.
FAIL: none remaining.

NOT RUN: native isolated DataStore save/rejoin, two-client isolation/replication and real platform
purchase/ownership/policy tests; Studio MCP reported no connected instances. Remaining native
cases: capacity changes during prompts, delayed charged receipts/disconnect/rejoin, lost service
responses, UTC midnight and private owner snapshots. D2 policy/lineage/disclosure acceptance
must complete before paid use.

N/A: client/device visuals and figure assets (untouched); live catalog/release activities
(outside this task). Initial local sandbox tool-cache failures were resolved with reviewed tool
execution; no source/tool version upgrade or dependency addition was made.

Official [paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
and [receipt/persistence guidance](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing)
were rechecked on 2026-10-11. Restrictions cover Robux-purchased in-game currency used for random
items; this supports retaining the specification's paid-path gates rather than mixing paid credit
into today's wallet. This review does not certify the unimplemented lineage path or approve release.
