# Per-return offline Double & Claim (MN-22)

Implemented; runtime and visual verification pending, 2026-10-11. The current [decision table](MONETIZATION.md#concise-decision-table--smallest-remaining-user-choices)
approves Claim N / purchased 2N for this return only. **Price, platform type, association,
exception compensation and release are undecided.** All real purchase gates remain closed;
no IDs, price defaults, sales, products, publication or production data are added.

## Award and durable transaction contract

P04 owns ordinary offline computation. MN-22 consumes its whole `offlinePending = N` after
the final floor, without rerunning Display, Coin tier, VIP or boost calculations. The normal
six-hour cap, 60-second minimum and unknown/backward-clock behavior remain there.
`OfflineAwards.freeze` assigns monotonic account-local `offline:<serial>` and freezes N,
base source partition and `display-boost-overlap-v1`. Raw 10.75 supplies N=10 and extra=10;
10,000 supplies 10,000 free and 20,000 total purchased value.

Forward-only profile schema **17** adds `offlineData`, strictly decoded/copied by
`OfflineAwards`. It contains current frozen award, identity serial, immutable historical
product-to-award bindings, one active reservation, receipt markers, charged exceptions,
earned overflow credit and assisted credit. P04's schema 16 fields remain intact. Nothing
is stored in teleport data, replicated to visitors or entrusted to client payloads.

Reserve under the profile lease and confirm `Storage.flush` **before** P02's sole native
prompt. This write captures exact extra N and current base claim status. A save failure or
uncertain reply cannot open a prompt. `PurchaseService` owns the prompt mutex; a server
ClaimOffline guard rejects competing claims while prompting or fulfilling. Cancellation
clears this transient mutex, never the durable reservation. Reopening can target only the
same unclaimed award. Free claim and rejoin auto-claim mark both current and bound base
claimed, then preserve the exact reserved extra independently of subsequent awards.

Receipt fulfillment credits unclaimed base N plus extra N, or only extra N if the base
was claimed. Wallet/credit, base claim, reservation fulfillment and PurchaseId commit in
the **same leased profile snapshot**, through P02's optional profile-fulfillment hook.
No copying/consumption between the P02 sidecar and the profile is used for this variable grant.
Failed saves retain the immutable pending snapshot and pause authority. Lost responses are
reconciled by existing save generations. A receipt is acknowledged only after confirmed
durability; duplicate receipts do not add value. Removal, lease conflict/expiry and AFK
handoff defer receipts. A new return cannot redirect an older bonus.

The full purchased extra is assisted credit. It never enters today's undifferentiated
wallet or finances restricted random boxes. Base source labels are preserved. P04 has no
validated source partition yet, so paid earning effects and MN-22 prompts stay off. Earned
base overflow remains credit and drains when a later offline claim/rejoin finds wallet
space. Assisted credit is a durable obligation; usable transfer needs the separately
validated policy/lineage wallet path. This implementation does not imply that path is ready.

## Association candidate for review

Roblox receipts identify account, product and PurchaseId; they carry no popup award ID and
pending receipt order is not deterministic. See [MarketplaceService ProcessReceipt](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt).
A reusable product ID + "first receipt wins" is ambiguous after an extra old charge and
a newer reservation. Cancellation is not evidence that all receipts have arrived.

The tested **candidate**, not an approved protocol, permanently binds a product identity
epoch to one award **per account**. An identity is never reused for a different award on
that account. Keep all historical configured identities in P02 dispatch. Only one binding
may be unresolved at a time; a cancelled reservation cannot expire or be rebound. A later
award would need a different platform identity from an approved epoch pool. A single
configured identity consequently allows only one purchased return per account; it is not
a viable recurring launch catalog by itself. No pool, IDs or platform product type has
been selected or created. This cost/finite-capacity limitation needs a product decision.

The first charged receipt for an identity fulfills that identity's frozen award. Replays
acknowledge its marker. A distinct extra receipt for the same identity, or a known charge
without a binding, is recorded in `exceptions`, never attached to the newest award and
never silently acknowledged. Exceptions block new offers. Return NotProcessedYet until an
explicitly approved compensation/support operation records the obligation and resolution.
No compensation amount or destructive repair command is invented here. Marker/binding
retention is permanent; capacity fails closed (256 bindings, 2,048 receipt/exception IDs).
An approved capacity/partition plan is required before repeatable sales.

## P02/P04/P08 handoff

- P02 remains sole `PurchaseRequest`/`PurchaseState`, native launcher and ProcessReceipt
  adapter. New optional `eligible`, `prepare` and variable `fulfill` callbacks are server-only.
  Missing integrations deny sales; fixed products retain their durable sidecar path.
- Final integration owner is this MN-22 task. P04 supplies stable shared schema/earnings
  patches first; final Profile/Types/Rules/server-init integration happens in this worktree.
  Never substitute a join-time boost factor for P04's interval calculation.
- Ordinary offline: call the claim hook before computing a new N, then freeze the resulting
  N. Preserve legacy `offlinePending` exactly, auto-claiming it under existing join semantics.
  Schema upgrade must validate existing player progress and all P04 fields without resets.
- Owner snapshot `offlineAward` contains id, exact numeric N/2N, claimability, confirmed
  fulfillment, charged recovery requirement and protected
  credit totals. It excludes receipt IDs/bindings. `OfflinePurchaseBinding` subscribes to P02,
  projects this owner view and requests actual viewing-player platform info only when eligible
  and configured. It sends no client award/amount/completion and invokes no platform prompt.
- OfflineEarnings keeps its approved card, free Claim/outside tap and gamepad-first Claim.
  Its optional purchase callback goes to P02. Prompt/fulfillment locks both actions; cancellation
  restores free Claim. Server-completed claims close without issuing a second free claim.
  Protected credit must never be described as a wallet deposit or trigger a misleading Coin burst.
- P08 should reuse these hooks, reconcile purchase state and preserve the price/eligibility
  gates. Do not add a second native launcher or a new Store layout.

## Compatibility and release review

Schema 17 is forward-only and is written even by a free positive offline return. Readers supporting only 14/15/16 reject it rather than
dropping reservations, credits or receipt markers. This prevents stale old writers from
silently erasing purchased value but requires a coordinated reader/writer release barrier
or a reviewed compatibility bridge before enabling its writer in a live update. Keep the
Economy2 namespaces and P02 historical dispatch unchanged. Rollback must retain new records
and their handlers; rolling back to an old executable can deny affected players access.
Do not downgrade profiles or prune markers. This task authorizes no release.

## Verification selection and remaining native checks

Union: economy/server authority, persistence/migrations/retry, AFK lifecycle and affected UI.
Fixtures exercise production modules with injected storage/platform boundaries; they are
not real charges, native DataStores, rendering or physical input evidence.

Required native acceptance remains pending: isolated DataStore migration/rejoin/fault tests,
two-client owner isolation, real receipt/prompt ordering/cancellation in an authorized private
test catalog, AFK handoff and D1 1920×1080, D2 1280×720, M1 667×375 landscape, M2 landscape
phone with safe insets. Inspect loading/unconfigured/ready/prompt/cancel/recovery/completed,
zero/claimed, large amounts/full wallet, repeated reopen and mouse/keyboard/touch/gamepad.
Physical phone is a separate pending pass. T1 tablet is conditional; 3D/figure gates are N/A.

## Final verification evidence

Integration includes P04's stable commits `165b55b` and `e18988e`, preserving their formula,
timers, normalized roll/disclosure, pending-save barrier and closed economic validation gates.

| Status | Evidence |
| --- | --- |
| **PASS** | Pinned `rokit install --no-trust-check` and `wally install`; unchanged empty dependencies/lock. Initial sandbox/cache restrictions and a sourcemap approval timeout were resolved by successful retries. |
| **PASS** | Full `python tests/run.py C:/Users/natha/Documents/RobloxWorkspace/build/tools/luau/luau.exe` regression suite. After final recovery hardening, affected suites rerun: offline41, P02 dispatch52, client/popup34, actual Storage/Persistence/AFK43 (**170 MN-22 assertions**); P02 baseline105; ordinary offline40; save-safety458; AFK storage42; owner snapshot27; Store presentation499; P04 Luck/boost988, persistence29, activation22. All are fixtures with engine/platform/store injection. |
| **PASS** | `stylua src`, `stylua --check src`, `selene src` (0 errors/warnings/parse errors), `git diff --check`; Rojo sourcemap and local `rojo build default.project.json -o RobloxWorkspace.rbxlx`. Generated files remain ignored. |
| **PASS** | Full-source Luau LSP1.70.1 diagnostics using Roblox definitions and the generated sourcemap: no source errors. CLI watcher-registration notice only. |
| **PASS** | Scripted popup geometry/60px action-height fixtures at1920×1080,1280×720,667×375 and844×390. Simulated Activated signals cover free/outside/double/repeated clicks; disposal leaves no connections. These are not rendering, text measurement, safe-inset or device-input checks. |
| **FAIL** | None remaining. |
| **NOT RUN** | Native isolated DataStore/schema rejoin, real platform charges/prompts/receipt order, two-client replication/remote abuse, actual AFK teleport: Studio MCP returned no connected instances; no approved configured test catalog. |
| **NOT RUN** | D1/D2/M1/M2 native visual/safe-area checks, keyboard/gamepad/simulated touch and physical phone input/readability. No connected Studio/device. T1 extended tablet review is conditional. |
| **N/A** | Figure/model work, Store redesign, live product creation, enabling sales, publishing and production-data mutation. None was requested/performed. |

Remaining before purchases: approve MN-22 price/type and association/cancelled-epoch treatment,
implement an approved identity-pool dispatch/exception compensation plan, validate the usable
assisted-credit/lineage/policy path, complete native/device acceptance and review the schema17
reader/writer release barrier. A single reusable developer-product identity cannot safely be
turned on for repeated returns under this candidate. No release action is implied.
