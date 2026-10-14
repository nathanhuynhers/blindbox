# Double & Claim recurring purchase decision — 2026-10-12

Status: **approved by the user, 2026-10-12** — 49 Robux and one saved single-use credit with explicit frozen-return redemption. Implemented in source; native receipt/persistence, policy/usable-credit and release verification remain pending. No catalog creation, sales activation or publishing was performed.

## Recommended price and catalog

Recommend **49 Robux default list price**, one repeatable developer product. This is an introductory pricing hypothesis, aligned with Starter, Small pack and Coin2/30-minute boost list prices; it is not evidence of spending willingness or a claim that every N is equally valuable. Actual viewing-player price comes from Roblox metadata. Six-hour offline N can be substantial; keep the existing economy/policy/pacing gate and do not nerf free earnings to support pricing.

The approved catalog benefit is **one consumable Double & Claim credit**, redeemable once against a frozen positive return. It is not a permanent offline entitlement or fixed Coin pack. Proposed catalog description:

> One single-use Double & Claim credit. Redeem it to add the same number of Coins as one eligible offline return. Free Claim remains available. An unused credit is saved until redeemed.

## Why the current reusable-variable-grant candidate cannot satisfy every requirement

Official [MarketplaceService receipt contract](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService) supplies user, product and PurchaseId, but no developer-controlled offline award/request ID for developer-product purchases. Receipt ordering is nondeterministic. A different receipt API/handler does not add that missing developer-product correlation.

Consider an already fulfilled old return A=10,000 and a new reservation B=7. A distinct late receipt for a second old purchase and a receipt for the new purchase both appear as an unseen PurchaseId for the same user/product. The server cannot infer which return generated that ID. Assigning the first unseen receipt to B can consume an old charge on B. Cancellation, UI close, a clock timeout, client success or current prompt state cannot establish the missing identity.

The current candidate avoids this with never-reused product IDs per account. It is safe for the association math, but a finite pool is finite recurrence; cancelled prompts consume identities and the current single unresolved binding blocks further offers. Extending it needs pool dispatch, multiple pending bindings, strict schema changes, capacity maintenance and exception compensation. Do not tell the user to create many identical offline products as if that resolves everything.

## Recommended durable credit/redemption protocol

1. A verified receipt for the one SKU durably grants exactly **one unused credit** with its PurchaseId in the same recoverable profile aggregate. No receipt evaluates the current offline N, selects an award or changes any bank/wallet/claim. Duplicate receipt grants zero additional credits; distinct genuine receipts grant distinct credits.
2. Selecting Double & Claim captures the server's displayed N and immutable award ID. If a credit is already owned, the server redeems it against that selected award with no new Robux prompt. Otherwise the UI discloses purchase of one saved credit and opens the native prompt.
3. Receipt arrival refreshes the private credit balance. The initial Double & Claim selection is not used to guess which receipt was just delivered. Offer a **Complete Double & Claim** confirmation for the frozen return. After disconnect/rejoin, offer **Finish previous Double & Claim: add N** with the original frozen N, even when its base was auto-claimed.
4. Redemption atomically consumes one unused credit, records a permanent redemption marker for that award and credits the frozen extra N. If its base is still unclaimed, the same operation also pays the base N; if the base was paid earlier, it adds only N. No reroll/recompute, newer-award substitution or4N.
5. A receipt never automatically consumes a credit on a newer return. Players explicitly choose which frozen eligible return to finish. Abandoning/cancelling a checkout never destroys already paid credit. Unused credits survive logout. No free credit comes from cancellation or a client purchase callback.
6. Wallet overflow retains earned/assisted credit and the charged obligation. The new credit ledger and redemption aggregate must integrate with the approved policy/lineage path before any sale. Unknown/restricted policy can block an economic redemption while preserving its purchased credit; free earned Claim remains usable.
7. Update current strict schema/decoder, sidecar/profile consumption protocol, owner snapshots, popup copy and tests. Preserve all legacy offline product/award bindings and unresolved exceptions unchanged; route historical IDs through their historical promise. No old receipt becomes a new credit unless an explicitly approved migration proves that promise is satisfied.

## Approved behavior change

The purchased platform item becomes a saved single-use credit, and fulfillment may require explicit confirmation to finish the originally frozen return. This intentionally avoids inferring a variable award from receipt timing. It does **not** claim to implement the original “charged receipt automatically adds old N” contract with one reusable identity.

If automatic old-N delivery is mandatory, retain the existing immutable identity-epoch approach and resolve the larger catalog/schema/operations plan instead. The reusable credit protocol is now implemented, with the release gates closed. Historical identity bindings retain their prior handler. No safety gate is lifted by this recommendation.

## Acceptance before sale

Test identical/reordered/concurrent receipts, extra independent charges, credit capacity, arbitrary popup close/cancel, selection before/after receipt, base free Claim/rejoin auto-claim, new returns, explicit older-award redemption, duplicate redemption, full wallets, lost committed responses, failed saves, lease conflict, disconnect/rejoin and AFK. All token/marker/credit and base/bonus changes must be durable before success acknowledgement. Include actual native receipts and isolated persistence after mocked tests; physical and multiplayer gates remain separate.

## Catalog setup the user can do meanwhile

In [Creator Dashboard](https://create.roblox.com/dashboard/creations), select the correct published Blindbox Town experience and owner. Under Monetization, create the **9 permanent passes** and **11 repeatable developer products** in [CATALOG_SETUP.md](CATALOG_SETUP.md); offline_double is now one reusable **Double & Claim credit**, default price **49 Robux**. Use approved list prices and benefit descriptions; keep passes off sale, leave all products unlisted in Monetization → Shop, do not promote them, do not buy with real Robux yet, and do not publish the candidate build as part of catalog setup.

For each item use its ⋯ menu → Copy Asset ID, then send logical key, Pass/Developer Product and numeric ID. Preserve IDs as immutable identities; do not reuse another game's products. [Pass creation](https://create.roblox.com/docs/production/monetization/passes), [developer-product creation](https://create.roblox.com/docs/production/monetization/developer-products). Unlisted is not a substitute for a correct receipt handler; keep product IDs private until the matching receipt/policy/fulfillment release is ready.
