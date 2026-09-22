# First-draft economy

All numbers here are **prototype tuning values**, not final balance. This document owns the
numeric defaults referenced by the [MVP](MVP.md). No Robux or purchasable currency is proposed.

## MVP configuration

| Parameter | Prototype value |
| --- | --- |
| Session starting Coins | 75, granted once when session state is created |
| One box | 25 Coins; one immediate figure grant |
| Content | Six figures: three tier A, two tier B, one tier C |
| Per-figure roll weights | A: 20 each; B: 15 each; C: 10; total 100 |
| Tier names | Common, Uncommon, Rare as replaceable labels |
| Base income per displayed copy | A: 8, B: 10, C: 12 Coins/minute |
| Display slots | Three |
| Diversity bonus | +9 Coins/minute per distinct displayed figure after the first |
| Total room rate cap | 54 Coins/minute |
| Bank cap | 75 Coins |
| Accrual step | About one second, using server elapsed time |
| Recycling | One eligible extra copy -> one Scrap |
| Targeted redemption | Six Scrap -> one chosen figure, any prototype tier |
| Inventory safety bound | 200 total owned copies; reject purchases/redemptions before charging if full |

Weights belong to box entries, not a globally hardcoded rarity probability. Each A figure has
20% probability, each B 15%, and C 10% in this one box. Rarity labels and visual treatments
are presentation definitions. No extra secret tier, pity counter, or paid roll is needed.

## Income and composition

For the MVP let N be occupied slots and U be distinct figure IDs among them:

`rate = min(54, sum(base rate for each displayed copy) + 9 * max(0, U - 1))`

An empty shelf produces zero. Each reserved copy contributes its base rate once. Diversity
counts definitions, not stack quantity or future variant IDs. There are no multipliers.

| Three-slot display | Coins/minute |
| --- | --- |
| Three copies of the tier C figure | 36 |
| Three distinct tier A figures | 42 |
| One A, one B, one C | 48 |
| The two distinct B figures and the C figure | 50 |

The 54 rate ceiling is a guard, not a currently achievable composition. Common figures remain
useful for diversity and completing discoveries. Later collection/shelf bonuses should be
small additive amounts within a global bonus budget. Require distinct named members for a
set and count it once per eligible shelf, with a room-level cap. No stacking multiplicative
set, rarity, visitor, prestige, and paid bonuses. Specific set rules are deferred past MVP.

Server accounting keeps fractional accrual in a runtime remainder and adds whole Coins to
the bank. Settle elapsed time at the old rate before a display change; then calculate the new
rate. Never retroactively apply a newly placed rare figure to an earlier interval. At the cap,
discard excess and clear the remainder; it cannot bank hidden income. Collection settles to
the current server time, transfers the bank once, and leaves only any sub-Coin remainder.
No client timer or visitor animation controls accounting. Later persistence saves the integer
bank; the fractional remainder is disposable. No cross-session elapsed-time catch-up.

## Active versus passive

Visitors are the explanation for earnings, not individually simulated wallets. Rate continues
while the bank has space, irrespective of rendering. At 24 Coins/minute (three A copies), the
bank fills in 3.125 minutes; at 50 it fills in 1.5 minutes. An unattended player earns at most
75 uncollected Coins, whether absent for five minutes or five hours. An active player collects,
opens, and changes displays to continue earning. There is no playtime multiplier.

This does not stop automated collection. Server proximity checks and action rate limits bound
abuse but do not prove a human is playing. Do not implement intrusive idle detection or reward
remote spam. If testing shows repetitive collection is optimal and boring, evaluate a bounded
session activity bonus in a later experiment; it is not an MVP dependency.

## Duplicates and deterministic progress

Recycle only when total owned quantity for that figure is at least two and at least one copy
is not reserved on a shelf. One action removes one available copy and grants one Scrap.
No direct Coin sale, Scrap-to-Coin exchange, random reroll, or rarity-dependent Scrap yield.
Six Scrap buys any chosen figure, including an undiscovered one. A redeemed extra copy can be
recycled, but returns only one of its six Scrap cost, preventing a resource-positive cycle.

In the worst case of repeatedly rolling one figure, seven box acquisitions leave a retained
copy plus six recyclable duplicates: a chosen new discovery becomes achievable. This is a
duplicate conversion bound, not a promise of six openings from every inventory state; players
may retain or display copies. Once each subsequent result repeats an owned figure, each six
recycled results funds another choice. No luck is required to keep earning or use redemption.

## Pacing hypotheses

| Window | Intended experience, not a guaranteed completion target |
| --- | --- |
| First minute | Open first of three funded boxes; place a figure and see visitors |
| First 3 minutes | Fill up to three slots, collect, and buy an earned box |
| First 10 minutes | Learn diversity; open roughly 10-18 total boxes if actively collecting; begin Scrap decisions |
| First 30 minutes | Roughly 30-60 openings; targeted redemption and full discovery are plausible; observe whether interest survives completion |
| First few sessions, after persistence | Resume collection, afford one bounded expansion, work toward a cosmetic completion reward |

For a conservative example, three identical A figures earn 24/minute: the next 25-Coin box
takes about 63 seconds after the shelf is filled. A 42/minute diverse shelf earns a box in
about 36 seconds. Over ten fully productive minutes these rates fund 9.6-16.8 additional
boxes; onboarding, bank overflow, menus, and player choices reduce realized income. The
first 10/30-minute ranges are hypotheses to measure, not targets that require extra rewards.
There is intentionally little long-term depth in six figures. Do not disguise that with grind.

## Later progression, rewards, and sinks

Coins primarily leave circulation through boxes; later sinks can be fixed-cost showroom
expansions, furniture, shelf skins, and purely cosmetic effects. Scrap remains a collection
resource. No upkeep fees or loss of earned collectibles are recommended.

For a later expansion experiment, consider one additional slot costing 250 Coins, then
re-evaluate the room cap and bonus budget together. This is not an MVP purchase or approved
balance. Compare marginal additional income to cost: payback minutes = cost / added
Coins-per-minute. Avoid chains of upgrades whose payback gets shorter and shorter. Bound
slot count and make some upgrades cosmetic so progression need not compound indefinitely.

Daily reward candidate after saving: one free box per eligible day, with a server-recorded
claim and no streak multiplier. Missions and forgiving streak cosmetics are separate tests.
Do not assume daily grants when balancing the base loop or first session. Returning players
do not receive the prototype's session-reset 75 Coins; persistent starter funds are a one-time
new-profile grant. No offline income is currently planned.

Inflation remains possible even with a bounded rate: active players can accumulate currency
over many hours. Watch net Coins earned/spent, stockpiles, discoveries per hour, time between
boxes, bank overflow, and redemption use. Start with playtest notes; collect production metrics
only in a separately scoped task. Tune rates, prices, fixed caps, and cosmetic sinks together.
Trading and paid currency would invalidate some assumptions and require a separate economy review.

## Data-driven tuning

Keep starting funds, box prices/entry weights, collectible base rates, diversity increments,
room/bank/quantity caps, slot unlock costs, recycle yield, redemption costs, accrual cadence,
and later reward/bonus budgets in server-owned configuration. Publish only the display/preview
values clients need; the server always computes the result. Configure visitor count and
animation cadence separately so visual density cannot accidentally increase payouts.
Validate references, positive weights, nonnegative finite values, integer currency bounds,
and capacity at startup. No content-specific conditional branches in gameplay systems.
