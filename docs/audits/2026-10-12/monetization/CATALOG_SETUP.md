# Catalog setup handoff — 2026-10-12

The owner created all retained products and supplied their IDs on 2026-10-12. Roblox Studio MCP read-only GetProductInfoAsync checks verified all nine passes and eleven developer products: names, listed prices, kinds and nonzero uploaded icon IDs. PurchaseConfig now maps all20 actual identities to the existing handlers. Server metadata reports IsForSale=true for all20. Local salesEnabled/integrationReady remain false because policy, spendable earned/assisted lineage and native acceptance are incomplete. See [the wiring verification](CATALOG_WIRING.md). Viewing-player prices still come from Roblox; a metadata list-price check is not a regional-price/prompt test.

[Roblox passes](https://create.roblox.com/docs/production/monetization/passes) cover one-time permanent privileges; [developer products](https://create.roblox.com/docs/production/monetization/developer-products) cover repeatable purchases. Catalog creation takes place under the correct published experience in Creator Dashboard → Monetization. This is separate from publishing this candidate game build.

| Logical key | Suggested catalog name | Proposed type | Roblox ID | D1 default Robux | Benefit promise |
| --- | --- | --- | --- | --- | --- |
| coins_2 | 2x Display Coins | Pass |2033318306|149|Highest owned Coin tier2; future Display-derived accrual only|
| coins_4 | 4x Display Coins | Pass |2033540289|399|Highest owned Coin tier4; full-price upgrade, no prior-purchase credit|
| coins_8 | 8x Display Coins | Pass |2033354299|999|Highest owned Coin tier8; full-price upgrade, no prior-purchase credit|
| pack_small | Coin Pouch | Developer Product |3718301793|49|15,000 fixed Coins|
| pack_medium | Coin Stack | Developer Product |3718301871|149|60,000 fixed Coins|
| pack_large | Coin Sack | Developer Product |3718301920|499|240,000 fixed Coins|
| pack_huge | Treasure Chest | Developer Product |3718302063|1999|1,200,000 fixed Coins|
| starter | Starter Pack | Pass |2032688308|49|One lifetime7,500 Coins plus one unused15-minute Coin2 token|
| auto_open | Auto Open | Pass |2032580313|199|Explicit single-box runs, >=3 seconds, chosen count/reserve; no automatic Robux purchases|
| auto_collect | Auto Collect | Pass |2034032281|149|Online1-second bank transfer, saved opt-in, Welcome lesson protected|
| movement | Movement Upgrade | Pass |2033774293|49|Optional48 speed; free36 selection retained|
| vip | VIP | Pass |2034392290|199|10% Display-derived rate plus500 fixed Coins with existing UTC daily Grove claim|
| coins_boost_15 | 2x Coins — 15 minutes | Developer Product |3718304026|29|One unused Coin2 token; explicit wall-time activation|
| coins_boost_30 | 2x Coins — 30 minutes | Developer Product |3718304141|49|One unused Coin2 token; explicit wall-time activation|
| coins_boost_60 | 2x Coins — 60 minutes | Developer Product |3718304189|79|One unused Coin2 token; explicit wall-time activation|
| luck | Permanent Luck | Pass |2033054302|399|Normalized Rare-or-better weight2; unchanged pity/floors|
| luck_boost_2 | Luck2 — 30 minutes | Developer Product |3718304296|49|One unused Luck2 token|
| luck_boost_4 | Luck4 — 30 minutes | Developer Product |3718304365|99|One unused Luck4 token|
| combo_boost | Coins2 + Luck2 — 30 minutes | Developer Product |3718304403|79|One unused combo token; atomic compatible activation|
| offline_double | Double & Claim credit | Developer Product |3718304498|49|One saved single-use credit; explicit frozen-return redemption adds extra N once; no automatic receipt claim|

Historical creation instructions (completed by the owner; retained as a reference): identify the correct live/test experience and owner; explicitly approve platform creation and mapping; supply compliant product icons/names/descriptions; use the now-approved offline credit contract. One reusable offline ID is sufficient for the new credit flow; historical product bindings retain their historical promises.

All IDs and types are now configured. Keep local salesEnabled/integrationReady false; platform metadata currently reports the catalog on sale, so catalog availability must be turned off before exposing this unverified build to buyers. Verify Dashboard controls for developer-product sale availability rather than assuming an in-game flag blocks external purchases. No products should be exposed to buyers while credited value is unusable or validation remains incomplete.

Creating IDs alone does not close readiness: implement/validate policy and earned/assisted spending, paid credit delivery, native credit/recovery verification, native isolated receipts/persistence, multiplayer and remaining device/popup acceptance. Then obtain a separate release instruction.

## Gamepass artwork

The nine generated gamepass PNGs are named exactly for the catalog table and exported at 512×512. Download [gamepass-icons-v1.zip](../../../../assets/ui/gamepasses/gamepass-icons-v1.zip), or use [the icon mapping](../../../../assets/ui/gamepasses/README.md). Their built-in image_gen prompts are retained in prompts.json. The owner subsequently uploaded these icons during catalog creation; Roblox metadata confirms their icon asset IDs.

In Creator Dashboard, select the correct published experience, open Monetization → Passes → Create pass, upload its matching named PNG, then enter the table name and benefit description. Keep sales disabled. For each pass, use ⋯ → Copy Asset ID and send the logical key and ID. Repeatable packs, tokens and Double & Claim credit belong under Developer Products; this icon set covers only the nine passes.

## Developer product artwork

All11 developer-product icons are available as named512×512 PNGs in [developer-product-icons.zip](../../../../assets/ui/developer-products/developer-product-icons.zip). This includes the four Coin packs plus the three timed Coin boosts, two timed Luck boosts, combined30-minute boost and Double & Claim credit. See [the filename and benefit mapping](../../../../assets/ui/developer-products/README.md); exact built-in image_gen prompts are included. The owner subsequently uploaded the icons and created these catalog identities. This agent verified metadata and configured local identities; it did not change platform sales settings.
