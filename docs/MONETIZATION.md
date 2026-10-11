# Monetization plan and review worklist

> **Status:** Consolidated planning reference, reviewed against repository sources on
> 2026-10-11. Robux products, prices, balance and launch scope are not approved. This document
> authorizes no implementation or publication. Grouped task prompts were prepared on 2026-10-11
> in [Monetization task prompts](MONETIZATION_TASK_PROMPTS.md); unresolved product decisions remain open.

This is the single planning reference for retained monetization ideas, dependencies, unresolved choices
and future tasks. The [roadmap](ROADMAP.md) still governs scope and release gates;
[economy](ECONOMY.md), [plots and shelves](PLAYER_PLOTS_AND_SHELVES.md),
[architecture](ARCHITECTURE.md) and [data model](DATA_MODEL.md) remain authoritative for
implemented behavior. Historical audit/backlog records retain their evidence and original IDs.

## Feature scope decisions

The user removed **Fast Open**, **Premium Multi Open**, and features **13–23** from the
feature review list: Shelf, plot, Display and opening cosmetics; premium status cosmetics;
rotating premium shop; bundles; storage upgrades; Pocket Pass; Collector Club subscription;
and gifting. These are excluded from the monetization plan, rather than deferred candidates.

The remaining features are Coin multipliers, Coin packs, Starter Pack, Auto Open, Auto Collect,
movement speed upgrades, VIP, timed Coin boosts, permanent Luck, timed Luck/combo boosts,
and a **2x offline earnings Coin bonus** added by the user.
Starter Pack and VIP benefits must use retained features; removed cosmetic products must not
return through those packages. Existing free/Coin-funded gameplay is unchanged.

## Direction and guardrails

Monetize the desire to keep collecting, opening and progressing.
Purchases should support the loop: earn Coins, buy boxes, discover figures, improve Display
income and complete collections. Existing cosmetic exhibits remain part of the free game.

- Preserve enjoyable free progression. Do not make existing collections artificially grindy to
  force purchases, sell instant collection completion, or eliminate the reason to keep playing.
- Keep important gameplay systems accessible without Robux. VIP and Starter Pack must remain optional.
- Do not charge to repair frustrating controls, make batch skipping usable, or explain duplicates.
- Shelves and their cosmetics generate no income. Paid earning capacity beyond the current six
  Display slots needs separate economy and fairness review.
- Preserve meaningful earned accomplishments.
- Show truthful offer availability and timers; avoid misleading scarcity.
- Review current Roblox requirements before implementing paid/randomized mechanics, including
  Robux-purchasable Coins and Luck. This consolidation is not a platform-policy assessment.
- Future content, variants, mastery, inventory limits, furniture and trading require separate
  design scope; listing them here does not authorize those systems.

## Implemented baseline to preserve

In existing docs, **paid box**, **paid Shelf** and the Welcome Quest's paid-box step mean
**Coin-funded**, not a Robux transaction. There are no implemented Robux products, gamepass
entitlement checks, MarketplaceService purchase prompts or paid receipt handlers in `src`.
Repository checks and previously recorded Studio checks do not close persistent, multiplayer
or physical-device acceptance.

| Area | Current behavior | Implication for monetization review |
| --- | --- | --- |
| Collections | Five collections, 43 figures; four economic tiers | Use existing content and pacing as the starting point |
| Box prices | Pocket Grove 1,500; Tidepool Tales 2,000; Concepts 20,000; Tender Echoes and We Are All Stars 200,000 Coins | Provisional economy tuning, not a Robux conversion |
| Rarity/pity | Common through Mythical; five-tier base Legendary 1%, Mythical 0.1%; persisted, independent increasing-chance pity | Existing pity is free; paid Luck is a separate proposed modifier |
| Duplicates | All copies retained; diminishing-return income enhancement; no ordinary total-copy cap | No paid storage product is planned |
| Display | Three starting earning slots; sequential Coin unlocks to six at 40K / 400K / 4M; one earning placement per figure ID; one +10% themed-trio bonus | Keep free slot progression and server-owned income |
| Collection | Owner steps on a plate or clicks/taps a figure; replacement attempts to collect the outgoing bank; Remove preserves it | Paid ongoing Auto Collect is distinct from implemented swap collection |
| Offline Coins | Half of effective Display rate, at most six hours; absences under 60 seconds grant nothing | A 2x offline Coin bonus is planned under MN-22; no paid bonus is implemented |
| Shelves | Three initial persistent units; nine positions each; three-unit physical viewport; first completion grants one unit; additional units cost `50,000 * 2.5^n` Coins, excluding free units; current cap 100 | Existing acquisition is not a Robux product; paid cosmetics are excluded |
| Opening | Single and Open 10 through ordinary Coin purchases; skippable presentation and batch results; free Welcome x10 | Fast Open and Premium Multi Open are excluded; Auto Open remains a proposal |
| Free rewards | 4,500 starting Coins, UTC daily Grove box, 1,000-Coin Display goal, looping seven-day Login rewards and one-time Welcome rewards | Account for all free grants before setting paid value |
| Plaza deals | Three globally synchronized hourly discounted box offers; per-player persisted stock | Coin deals remain; a premium rotating shop is excluded |
| Movement | Server-owned baseline 36 studs/second; no speed entitlement | Additional movement speed is only a future upgrade idea |
| Cosmetics/status | Empty per-Shelf customization hooks; no customization catalog/store/editor; collection completion and global leaderboards exist | Paid cosmetic/status products are excluded |
| Persistence | Economy2 schema 14; leases, validation and failure pauses; gameplay request receipts are transient | Durable paid fulfillment needs its own design; request receipts alone are insufficient |

Exact formulas, safety guards and native acceptance checks remain in the implementation references.
Secrets, Shinies, mastery, collection levels and Collection Score are ideas, not implemented
rarity tiers or player progression fields. Current Mythical odds are not evidence of a Secret system.

## Product idea catalog

Every retained entry below is a proposal. No price, product type, tier or benefit has been
finalized. Review tasks are indexed later in this doc.

### Coin multipliers — MN-04

Permanent **2x / 4x / 8x Coins**, designed as upgrade tiers without accidentally multiplying
together. Their intended value is more opportunities to open boxes as collection costs rise.

Decide separate passes versus an upgrade model, what each tier costs, how prior purchases are
credited, and which Coin sources qualify. Online Display, offline income, daily/login rewards,
starter grants and direct Coin packs cannot silently share an unspecified multiplier rule.
Evaluate free and paid pacing, duplicates and themed bonuses together before setting prices.
Define how these tiers interact with the separate 2x offline earnings bonus under MN-22.

### Coin packs — MN-05

Repeatable Small / Medium / Large / Huge packs. Amounts and Robux-to-Coin conversion remain TBD
until earning rates, time per box and long-term progression are reviewed. Decide fixed versus
progression-sensitive value and interaction with multipliers/boosts. Include paid currency used
to buy randomized boxes in the policy review.

### Starter Pack — MN-06

A low-cost first purchase could combine Coins and a temporary boost.
Do not lock an important gameplay figure behind it.
Decide contents, price, eligibility, purchase limits and availability. Keep it distinct from the
free Welcome Quest; boost benefits depend on the boost system existing first.

### Auto Open — MN-07

Automatically continue buying/opening boxes. Open 10 and usable skipping already exist without
a Robux entitlement and remain unchanged. Fast Open and Premium Multi Open are excluded.

Decide free/progression/premium access, automation behavior, and Auto Open stop
conditions. Server purchases, affordability, cooldowns, pity and grants must remain authoritative.
Skipping, interruptions and retries must never grant additional figures or spend twice.

### Auto Collect — MN-08

A future gamepass for ongoing collection of Display banks, deferred by the product backlog.
It is separate from the free outgoing-bank collection on replacement. Decide cadence, eligible
banks, online/offline behavior, entitlement handling and impact on the Welcome Quest.
Reuse server-owned bank transfer rules, including fractions and wallet overflow. Preserve
manual collection and distinguish collection convenience from an income multiplier.

### Movement speed upgrade — MN-09

The playtest backlog identifies extra speed as a future monetization/upgrade vector.
No pass, benefit or price is defined. Decide whether this belongs in the product lineup,
free versus premium acquisition, speed value, stacking and character lifecycle behavior.
Use the existing server movement boundary if separately authorized.

### VIP / Premium Collector — MN-10

Possible permanent benefits: enhanced daily reward, small Coin bonus or small Luck bonus.
Select the actual bundle and price; economic bonuses, Luck and improved daily grants are unresolved.
VIP should feel prestigious and useful while normal progression remains enjoyable without it.

### Timed boosts — MN-11

Repeatable **2x Coins**, **2x Luck**, Super Luck, or Coin + Luck boosts in example
**15 / 30 / 60 minute** durations. These could support continued play during the boost window.
Decide activation, online time versus wall-clock expiry, logout handling, repeat-purchase behavior,
stacking with permanent tiers/VIP and clear remaining-time presentation. Values are illustrative.

### Luck and gamepass integration — MN-12

Ideas: permanent **2x Luck**, **4x Luck / Super Luck**, temporary Super Luck and combined boosts.
The playtest backlog's initial acquisition direction is gamepasses; exact products, tiers and
values remain TBD, including whether permanent Luck should exist at all.

Preserve the original **STRETCH-LOGIC-02 + STRETCH-UI-02** requirements:

- Finalize the mathematical modifier and how it composes with existing pity before implementation.
- Keep outcomes server-owned; never accept client-provided Luck or odds tables.
- Keep probabilities valid and normalized, tuning configurable, and test all rarity tiers.
- Show active Luck and its effect on odds clearly; distinguish paid Luck from free pity progress.
- Integrate pass presentation without making the Shop feel dominated by paywalls.
- Implement late, after core polish, product/tuning decisions and paid-random policy review.

If future Shiny/Secret content is separately approved, decide whether Luck affects it; do not
require those systems merely to review the present five-tier catalog.

### 2x offline earnings Coin bonus — MN-22

Double the Coins earned while offline. This is **2x the normal offline reward**, not twice the
online Display rate. With the current free offline rate of 0.5x, the bonus would yield 1x the
effective online Display rate before any other paid modifiers. The existing six-hour accrual
cap and 60-second minimum absence remain the baseline; this feature increases Coins, not duration.

Price and purchase type remain open: decide a permanent entitlement versus a per-return
double-reward purchase, when eligibility is determined, and how it stacks with Coin multipliers,
timed boosts and VIP. Resolve treatment of already pending earnings before implementation.
The server must calculate and fulfill the reward using persisted offline state, with durable
paid fulfillment and no repeat bonus from duplicate claims, retries or rejoining.

## Economy dependencies — MN-01

Current tiers, prices, rarity odds, duplicate value, pity, daily grants and free boxes are defined
in the economy reference. Their tuning and actual free-player pacing still need acceptance;
the old instruction to "define the economy" should not discard implemented systems.

Before final pricing, review base/progression Coins per minute, time to earn each box, completion
pull distributions, unlucky runs, duplicate income, free rewards, offline income and Display
slot purchases. Compare proposed 2x/4x/8x tiers, packs, boosts and the 2x offline bonus
against that baseline.
Existing pacing simulations are idealized earning estimates, not retention or affordability proof.

New collection content, mastery, variants and duplicate sinks remain separate game-design scope,
not monetization tasks or prerequisites to reviewing the retained features.

## Shared purchase foundation and verification — MN-02 / MN-03

These are consolidated engineering prerequisites for future products, not an implemented service
or a selected dependency. Determine product types and current platform support during design.

- Review current paid-random requirements for the complete money-to-reward path: direct purchases,
  paid Coins used for boxes, Luck, boosts and any randomized Starter Pack/VIP benefits.
  Record applicable eligibility/restrictions and required disclosures before implementation.
- Define a server-owned product catalog, verified entitlements, purchase/fulfillment lifecycle,
  durable idempotency and recovery. Client purchase completion is not proof of a valid grant.
- Keep prices, grants, multipliers, probabilities and authoritative state on the server. Replicate
  only necessary public metadata and owner presentation state; validate and rate-limit requests.
- Account for repeat delivery, disconnects, lost replies, failed saves, concurrent sessions and
  purchases while storage is paused. Define when fulfillment is durably safe to acknowledge.
- Extend the profile/schema deliberately where needed; preserve valid saves, existing leases,
  fail-closed loads and Studio/live isolation. Transient gameplay receipts cannot be treated as
  a durable real-money fulfillment ledger.
- Keep modules focused, strict Luau and existing replication boundaries. Add no framework,
  dependency, product ID, purchase prompt or live product as part of this planning work.

Future implementation acceptance must include domain tests for grant/stacking/expiry/retry rules,
Luau diagnostics, pinned formatting/lint/build checks, persistent recovery and native Studio
behavior. Use multi-client tests for ownership, private state and remote isolation; test mobile,
desktop and relevant gamepad purchase presentation.
Record what actually ran and leave platform purchase/release acceptance explicit.

## Priority decisions and review worklist

The original idea bank's first candidates were **Coin multipliers, Coin packs, Starter Pack,
opening convenience, then VIP**. Opening convenience now means Auto Open only.
The historical audit's cosmetics-first recommendation is superseded by the user's removal
of paid cosmetic products; its free-control and progression guardrails still apply.
The [product backlog](PRODUCT_BACKLOG.md#later-separate-design-decisions) defers monetization
until core-loop polish; the playtest backlog places Luck/gamepasses last.

**The retained feature list is set for further review; execution order remains open.** Suggested
review order is baseline and policy, then select the first products from the retained features
and scope their shared purchase foundation. All candidates require a cost/benefit review before
a separate implementation authorization.

These IDs map to the [grouped task prompts](MONETIZATION_TASK_PROMPTS.md). They are not approved implementation
tickets, and we do not need to implement every idea. A task can be selected, revised or deferred.

| ID | Review/task area | Decision needed before an implementation prompt |
| --- | --- | --- |
| MN-01 | Free/paid economy and pricing | Accepted baseline, eligible Coin sources, modeled paid impact, price/value targets |
| MN-02 | Platform/policy review | Current supported product types and requirements for each selected money-to-reward path |
| MN-03 | Purchase foundation | Selected catalog, entitlement/fulfillment design, durable recovery, schema and test scope |
| MN-04 | Coin multipliers | Tier acquisition/upgrades, stacking, qualifying income and prices |
| MN-05 | Coin packs | Sizes, conversion/value model, multiplier interaction and prices |
| MN-06 | Starter Pack | Contents, eligibility, limits, availability and price |
| MN-07 | Auto Open | Free/premium access, automation and stop rules; existing Open 10/Skip remain unchanged |
| MN-08 | Auto Collect | Eligible banks, cadence, entitlement and tutorial/offline behavior |
| MN-09 | Movement upgrade | Include or defer; acquisition, speed, stacking and price |
| MN-10 | VIP | Final benefits, economic bonuses, dependencies and price |
| MN-11 | Timed boosts | Effects, durations, clocks, stacking, activation and prices |
| MN-12 | Luck + presentation | Acquisition, formula, pity composition, normalized odds, disclosures and prices |
| MN-22 | 2x offline earnings Coin bonus | Price, permanent versus per-return purchase, eligibility timing, stacking, pending-reward treatment and duplicate-claim recovery |

Existing MN-01 through MN-12 IDs are preserved. MN-13 through MN-20 are retired following the
feature removals; MN-21's future collection work is separate game-design scope and is no longer
a monetization task. MN-22 tracks the newly added 2x offline bonus without reusing retired IDs.

The [prompt pack](MONETIZATION_TASK_PROMPTS.md) groups related products and includes separate
Robux store design, UI implementation and end-to-end acceptance prompts. Its first task resolves
player benefits, free-player behavior, product/value choices, dependencies and acceptance criteria
before dependent implementation. Product decisions remain here; implementation and launch require
their own authorized tasks.

## Consolidated sources and maintenance

| Source | Guidance brought into this document |
| --- | --- |
| Original `MONETIZATION.md` idea bank | Retained product families, economy dependencies, guardrails and open questions; user scope decisions above supersede removed ideas |
| [Product backlog](PRODUCT_BACKLOG.md) | Core-polish deferral; Auto Open, Auto Collect and Robux multiplier candidates; separate cost/benefit scope |
| [Playtest backlog](PRODUCT_BACKLOG_PLAYTEST_2026-10-05.md) | Movement upgrade idea; STRETCH-LOGIC-02 / STRETCH-UI-02 Luck requirements and late ordering |
| [Game audit](GAME_AUDIT.md#14-monetization) | No live monetization audited; free-control guardrails retained; cosmetics-first recommendation superseded |
| [Economy](ECONOMY.md) | Manual/swap collection, offline behavior, free rewards, Coin purchases, odds/pity/duplicates and pacing evidence limits |
| [Plots and shelves](PLAYER_PLOTS_AND_SHELVES.md) | Cosmetic/economic split, Shelf acquisition, completion reward, customization hooks and excluded kiosk/capacity work |
| [Game design](GAME_DESIGN.md), [roadmap](ROADMAP.md), [historical MVP](archive/MVP.md) | Current experience, scope boundary, acceptance gates and historical monetization exclusion |
| [Architecture](ARCHITECTURE.md), [data model](DATA_MODEL.md), [opening](OPENING.md) | Server/replication/persistence boundaries and existing free Open 10/Skip behavior |

Maintain future monetization decisions and product tasks here. Other active docs should link
here for planning rather than duplicate product specifications. Keep implemented formulas and
system contracts in their existing references; keep historical audit evidence unchanged.
