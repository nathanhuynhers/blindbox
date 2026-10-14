# Offline Double & Claim (MN-22)

**Approved and implemented; native verification pending, 2026-10-12.** The user approved **49 Robux** and one saved, single-use credit with explicit frozen-return redemption. This supersedes automatic fulfillment from a reusable receipt. All catalog IDs remain absent, sales/integration flags remain false, and paid usability/policy validation remains closed. No publishing or production migration occurred.

## Player and purchase contract

P04 computes and floors the ordinary offline return N. Its six-hour cap, 60-second minimum, modifiers and clock rules are unchanged. Free Claim remains available. The server freezes account-local award identity, exact N, source partition and calculation version; it never accepts a client amount or recomputes a return during purchase.

With no owned credit, Buy credit first persists the selected frozen return under the current profile lease. Only confirmed selection may authorize P02's native prompt. A genuine receipt saves one credit identified by PurchaseId and acknowledges only confirmed durability. Receipt delivery does not select an award, claim the base, add a bonus or redeem a credit. Distinct recurring receipts grant distinct credits; receipt replay grants none.

The player then confirms Redeem +N. One unused credit and one permanent redemption marker atomically pay the frozen extra N, plus the base if it remains unclaimed. If the base was claimed earlier or auto-claimed on rejoin, only the extra is paid. The extra is assisted credit; base source labels are preserved. Full wallets retain earned and assisted overflow. An already redeemed award cannot consume another credit or produce 4N.

The selected return survives cancellation, Later, logout and AFK. Rejoin offers the old frozen amount; Store → Double & Claim → View saved return can reopen it. A delayed receipt never automatically doubles a newer return. An owned credit requires no new price lookup or Robux prompt to redeem. Capacity or policy rejection retains the credit and return.

## Durable schema and historical compatibility

Schema **19** adds server-only offlineCredits alongside existing offlineData and schema18 packages. It contains bounded receipt IDs, copied frozen returns, award-to-credit redemption markers and an optional selected award. Decode validates field names, numbers, award serials/source labels, base-claim coherence, unique credit consumption, capacities and historical receipt/binding collisions. Encode deep-copies the validated aggregate. New free profiles retain their existing schema until a credit/selection promotes them. The Economy2 namespace is unchanged.

Current capacities are 2,048 receipt IDs and 256 retained returns. No marker pruning is implemented. Selection/checkout and economic redemption fail closed at capacity; do not erase paid markers or reuse identities. A capacity expansion/partition plan is a separate future operation.

Historical schema17 product-to-award bindings, pending reservations, receipt markers and charged exceptions remain untouched. Their configured IDs route through the historical variable-grant handler, retaining the exact original extra N. A historical sold product identity or bound award cannot be converted into a new credit. Historical exception compensation remains an unresolved operation; no compensating amount or destructive repair is invented.

Old readers supporting only through schema18 reject schema19. Before any authorized release, review mixed-server reader/writer compatibility and rollback while retaining all paid records and both handlers. Do not downgrade or reset profiles. This task authorizes no release.

## Authority, retry and owner privacy

P02 remains the sole native launcher and ProcessReceipt adapter. OfflineCreditRequest supports only bounded id, Select/Redeem action and awardId. Identity comes from the supplied Roblox Player. Requests are rate-limited and rejected during purchase, automation, lease/save uncertainty or closed economic validation. Receipt grants still preserve already charged obligations while sales/redemption are gated.

Selection, grant and redemption use the same leased profile/pending-save barrier. Before success, recheck the captured state/session and confirmed readiness after yielding persistence. Failed or lost committed responses retain the original generation; replay cannot repeat benefit. Released, detached, replaced or expired owners cannot acknowledge/deliver into a newer session.

Private owner snapshots contain credit count and selected award/amount, plus normal claim and protected credit totals. Receipt IDs, historical bindings and the ledger are never exposed. The client retries an exact pending request and nonce, waits for confirmed selection before checkout, and requires a separate redemption confirmation after a receipt. Popup dismissal cannot claim a newer base when showing an already claimed old return.

## Verification

Applicable union: economy/server authority, profile/storage/retry, AFK lifecycle, owner privacy/remotes, and affected Store/popup UI. Figure/model gates are N/A.

| Status | Evidence |
| --- | --- |
| PASS | New OfflineCredit.spec:42 domain/profile/receipt checks; OfflineCreditClient.spec:18 client/popup fixtures; OfflineCreditStorage.spec:18 actual Storage/Persistence/Runtime/AFK checks with an isolated fake DataStore. **78 new assertions.** |
| PASS | Full repository regression suite, including historical MN-22/P02, save safety, packages, boosts, opening and snapshot suites. |
| PASS | Strict Luau diagnostics, formatting/lint and local Rojo mapping/build checks. |
| NOT RUN | Native credit receipts, native isolated persistence, two-client owner isolation, actual AFK teleport and physical-device input; no configured authorized test catalog. |
| NOT RUN | Final credit popup native visual acceptance. Local Studio remained Edit after the attempted Play start; scripted UI fixtures do not establish native rendering or input behavior. Earlier native Store evidence predates this new credit flow. |
| FAIL | Overall paid launch readiness: policy/earned lineage, usable assisted delivery and native acceptance remain incomplete. |
| N/A | Live catalog creation, sales activation, publishing, production data mutation and figure/model work. |

See [the dated acceptance audit](audits/2026-10-12/monetization/ACCEPTANCE.md), [approved decision](audits/2026-10-12/monetization/DOUBLE_CLAIM_DECISION.md) and [catalog setup handoff](audits/2026-10-12/monetization/CATALOG_SETUP.md).
