# Blindbox Town monetization product specification

> **Current candidate, 2026-10-13:** all nine passes and eleven developer products are wired and enabled. Native policy, earned/paid lineage, durable receipt delivery, lost-reply recovery, client redemption, save/rejoin and two-client isolation checks passed. Shared pity is unchanged. The Coin Pouch native Studio test purchase completed without a charge. Temporary hooks were removed and original DataStore settings restored. This candidate is loaded in Studio Edit mode; it has **not been published**. Physical-device and new-buyer pass checks remain NOT RUN. See [enablement evidence and release instructions](audits/2026-10-13/monetization/ENABLEMENT.md). Historical milestone claims below describe earlier states.

> **Design/research only — 2026-10-11.** The user approved decision D1 (product benefits,
> amounts, entitlement model and the matrix's default list prices) and the MN-22 Double & Claim
> flow on 2026-10-11. The user also approved full D2 with a policy/earned-lineage validation gate
> on 2026-10-11. MN-22 pricing, platform types, fulfillment details and release
> remain **recommendations, not approved**. No platform product IDs exist in this specification. No gameplay, platform catalog, live pricing, publication or
> production data changes are authorized by this document. Implementation must consume explicit
> user decisions recorded in the decision table; it must not promote recommendations to defaults.

This replaces the earlier idea-only worklist with reviewable product rules. Read with
[game design](GAME_DESIGN.md), [economy](ECONOMY.md), [architecture](ARCHITECTURE.md),
[data model](DATA_MODEL.md), [roadmap](ROADMAP.md) and [historical MVP](archive/MVP.md).
Source is the baseline when historical planning differs. The retained families are in scope for
specification; listing a family does not approve building or launching it.

<a id="feature-scope-decisions"></a>

## Scope and protected free loop

Keep earning Coins, buying randomized boxes, retaining duplicates, improving Display income and
completing the **existing five collections / 43 figures** enjoyable without Robux. Do not increase
box/slot/Shelf costs, reduce free earnings, weaken pity/rewards, reset progress, sell collection
completion or require future content to justify a price.

**Excluded, not deferred candidates:** Fast Open, Premium Multi Open, Shelf/plot/Display/opening
cosmetics, paid status cosmetics, rotating premium shop, general bundles, storage upgrades,
Pocket Pass, Collector Club subscription and gifting. Starter Pack and VIP are the expressly
retained packages; they may contain only retained benefits. Scrap, recycling/redemption, trading,
variants, Secrets/Shinies, mastery, inventory limits and future collections are outside this task.
Free Open 10 and Skip remain usable with no entitlement. No paid seventh Display slot, paid Shelf
capacity, VIP-only figure or cosmetic benefit is proposed.

## Inspected source baseline

Reviewed `AGENTS.md` and all seven requested planning references, plus the relevant source and
tests listed below, on 2026-10-11. These are repository facts, not proof of current live deployment
or closure of native acceptance gaps.

| System | Actual configuration/behavior to preserve | Evidence |
| --- | --- | --- |
| Box prices / income scale | Grove 1,500; Tide 2,000; Concepts 20,000; Echo and Stars 200,000 Coins. Expected-figure payback parameters 180 / 180 / 550 / 850 seconds, **not time per box** | `src/server/Economy.luau`, `CollectionEconomy.luau` |
| Rarity | Starter: Common 60%, Uncommon 30%, Rare 10%. Five-tier: 60%, 25%, 13.9%, 1%, 0.1%. Within-rarity weights currently all 1 | `Economy`, `CollectionEconomy`, `src/shared/Catalog.luau` |
| Free pity | Legendary demand `1 + max(0,dL-40)*0.05`; Mythical `0.1 + max(0,dM-300)*0.0015`, in percentage points. Guarantees at dry counts 2,020 / 66,900 for the **next** box; Mythical wins simultaneous guarantees. Independent counters per collection; no former 8%/2% caps | `CollectionEconomy`, `tests/LinearPity.spec.luau` |
| Duplicates / set | All copies retained; one earning placement per ID. Rate multiplier `1 + maximum*extra/(extra+curve)`. Maximum bonuses C/U/R/L/M = 0.6/0.9/1.25/1.5/3; curves 5/5/4/2/2. A distinct themed trio gives +10% total Display rate once | `Economy`, `Rules.luau`, `tests/Mvp.spec.luau` |
| Display | Three free slots, sequential Coin unlocks to six at 40K / 400K / 4M. Each figure banks income; fractions/overflow retained. Plates/taps collect only the targeted figure. Replacement collects outgoing whole bank; Remove preserves it. Equip Best is free | `Rules`, `tests/DisplayReplacement.spec.luau`, `EquipBest.spec.luau` |
| Shelves | Three initial units; nine positions each; three-unit viewport. One free unit per first collection completion; additional units `50,000*2.5^n`, excluding free units; current acquisition cap 100. Cosmetic, no income | `Rules`, `src/shared/ShelfConfig.luau`, `tests/Shelves.spec.luau` |
| Offline | Saved Display including duplicate/set effects; 0.5x rate, six-hour cap, 60-second minimum. Unknown/rollback clock grants zero. Join auto-claims old pending, then computes new pending; claim clears it. Wallet overflow on offline claim is currently dropped | `Rules.offline/claimOffline`, `tests/Offline.spec.luau` |
| Free opening/rewards | 4,500 starting Coins; UTC daily Grove box; 1,000-Coin distinct-three Display goal. Welcome U/R box is 75%/25%, then ten Grove boxes with Rare on the tenth if first nine miss. Coin-funded quest purchase is not Robux | `Rules`, `tests/Tutorial.spec.luau` |
| Login | Seven-day loop: 500 / 1,000 / Grove box / 2,500 / 1,000 + Tide box / 4,000 / 5,000 + Concepts box. Missed day restarts at 1. Values remain source placeholders; unchanged here | `src/shared/LoginRewards.luau`, `tests/LoginRewards.spec.luau` |
| Deals / openings | Three hourly globally synchronized stalls; 25% discount; three boxes per player per stall/hour. Ordinary Single and atomic Open 10 with sequential pity, free Skip and results | `Deals.luau`, `Rules`, `tests/Deals.spec.luau`, `Opening.spec.luau` |
| Movement | Free server WalkSpeed **36 studs/s**, initial character and respawns. Older 16/20 planning values are not the baseline | `MovementConfig.luau`, `PlayerMovement.luau`, `tests/PlayerMovement.spec.luau` |
| Persistence / purchases | Economy2 schema 14; validated upgrades from 6–13; leases and failure pauses. Gameplay receipts are transient, acknowledgements ordinarily in memory. No MarketplaceService, entitlement, paid receipt or PolicyService integration found in `src` | `Profile.luau`, `Persistence.luau`, `Storage.luau`, `init.server.luau`, `Transactions.luau`, `tests/SaveSafety.spec.luau`; source search |

Historical MVP values (450 starting Coins, 150-Coin boxes, automatic wallet income and recycling)
are superseded. The historical reset does not authorize another reset. Preserve current stores,
catalog IDs, quantities, discovery, pity, Display/Shelves, rewards and pending balances.

## Shared rules — approval status follows the decision table

The following named rules are inherited by every matrix row. C/L/T/G are approved by D2 with
the validation gate; platform identities and release remain separate. A row changes only the
stated effect; there are no feature-specific receipt or stacking shortcuts.

**P — purchase/ownership.** Use passes for permanent entitlements, developer products (DP) for
repeatable fixed grants and boost tokens. Verify pass ownership on the server with
`UserOwnsGamePassAsync` at join and after a server-observed purchase event; client success is never
proof. Preserve prior verified benefits on a transient refresh failure; grant no newly unverified
benefit and disable new prompts until ready. Developer products use the shared server
`ProcessReceipt` dispatcher and durable fulfillment described below. One platform prompt at a
time; no automatic Robux purchases. Prompt authorization is separate from a delivered receipt:
an already charged receipt must be recovered even if the player disconnects or policy changes.
No entitlement is sold again in-game when owned, superseded or presently unusable.

**C — Coin composition.** Let `R0` be the current unmonetized Display rate after duplicates and
the single themed-trio bonus. `M = max(1, owned Coin tiers)` is 1/2/4/8, never 2*4*8.
`V = 1.10` with VIP, otherwise 1. `BC(t)` is 2 during an active Coin boost, otherwise 1.
Online accrual is `R0*M*V*BC(t)`, apportioned to the same displayed figure banks. Entitlement,
inventory, Display and expiry changes settle the preceding interval first; collection merely
transfers existing whole Coins and **never multiplies a bank again**. Maximum proposed online
factor is 17.6, a reason to hold higher tiers for pacing review.

| Coin source | Permanent tiers / VIP rate / timed Coin effect | 2x offline claim purchase |
| --- | --- | --- |
| Online Display banks, including duplicate and themed effects | Yes, once during accrual | No |
| Offline Display-derived reward | Yes; saved permanent factors and time overlap, as specified below | Yes, once |
| Existing banks accrued before ownership/activation | No retroactive multiplier | No |
| Starting 4,500; goal 1,000; Login Coins; existing fixed free grants | No | No |
| Coin packs / Starter Pack Coins / VIP extra daily Coins | No, exact advertised fixed amount | No |
| Box outcomes, prices, Display/Shelf acquisition costs | No Coin modifier changes these | No |

**L — Luck composition.** `L = max(1, verified permanent Luck, active timed Luck)` with a proposed
ceiling of 4. Combo is the same Coin/Luck effects, not a third multiplier. VIP grants no Luck.
The exact distribution and opening-path rules below are mandatory design inputs.

**T — boost lifecycle.** A receipt gives an unused token of the advertised effect/strength and
15/30/60-minute duration; it does not secretly begin a timer while loading or offline. Tokens do
not expire before activation. Activation is explicit, server-confirmed and durably consumes one
token and records UTC integer start/expiry timestamps in the same profile operation. Clock is
elapsed **wall time**, including logout, AFK, reconnect and server downtime. No pause/refund from
logout. Use a non-decreasing server clock during a session, persist the last accepted timestamp,
and fail closed on impossible/backward time instead of granting extra duration.

Same effect **and strength** activation extends `max(now, expiry)+duration`, with no increase in
power. Queue further tokens when the resulting active remaining duration would exceed 24 hours;
never consume a token partially or silently discard it. Different timed Luck strengths may not
overlap: reject activation and keep the token until the current timed Luck expires. Buying an
unused token is repeatable; buying is never required to keep a running timer. Disable purchases
and activation of Luck 2 when permanent Luck 2 already makes it redundant. If permanent Luck is
bought during a Luck 2 timer, warn that the timer adds no further odds; it still expires normally.
This is not a 4x upgrade. Luck 4 remains useful above permanent Luck 2.

Combo activation atomically extends compatible Coin 2 and Luck 2 timers; reject the whole
activation if either is incompatible, redundant or over the duration bound. A Coin-only token
and a combo's Coin component extend the **same** timer. An expired effect stops exactly at the
boundary; delayed ticks integrate intervals split at expiry. Unused tokens survive logout;
active clocks continue. Snapshots show unused tokens, actual active power and absolute expiry/
remaining time; no resetting promotional countdowns.

**G — gating.** All products require a ready loaded owner profile, healthy persistence and verified
offer/entitlement state. Economy/Luck offers additionally require the policy-safe money-to-box
path below. A cached client eligibility flag never authorizes purchase, activation or rolling.
No automatic pack upsell when Coins run out. Display exact benefits, full actual platform price,
limits, expiry/stacking and odds impact before the user confirms a prompt.

**F — free player.** Existing grants, odds/pity, rates, slots, Shelves, manual collection, Single,
Open 10, Skip, Equip Best and movement 36 remain unchanged. Unowned automation is off; unowned
rate/Luck factors are 1; offline remains 0.5x. Progression can reach every current figure without
buying any retained product. Paid convenience must not be used as a reason to make manual play worse.

## Concrete product matrix

**All prices below are proposed default Robux list prices for review, not approved prices or live
configuration.** Actual user prices must later come from platform product information, including
regional pricing; benefits do not scale with Robux spent. These are economy-based value hypotheses,
not competitor research or claims about willingness to pay. No product IDs are assigned.

| Family / ID | Player benefit; proposed type | Amount / tier / duration; proposed Robux price | Eligible Coin source | Eligibility, limit, ownership/upgrade | Activation, expiry and stacking | Free behavior; dependencies |
| --- | --- | --- | --- | --- | --- | --- |
| Permanent Coins — MN-04 | Faster earnings; three independent passes | 2x **149**; 4x **399**; 8x **999** | C: online and offline Display only | G; once per pass; direct purchase of any tier, no prerequisite. Highest owned wins. Full-price upgrades, no automatic prior-purchase credit | P; starts after verification/old-rate settlement, permanent; max tier with V and BC | F; durable offline snapshots, income integration, policy/provenance. Recommend initial review of 2x only; hold 4x/8x release |
| Coin packs — MN-05 | Immediate, fixed wallet value; four repeatable DPs | Small **15,000 / 49**; Medium **60,000 / 149**; Large **240,000 / 499**; Huge **1,200,000 / 1,999** | Fixed purchased Coins, no rate modifiers | G; repeatable, one pending prompt; no progression scaling or per-player daily stock. Disable prompt if full grant will not fit | P; receipt durably credits exact amount, no expiry/upgrade/stack multiplier; unexpected overflow becomes reserved purchase credit, never lost | F; no rate reduction; durable receipt/overflow ledger and paid-Coin route gating. Hold Large/Huge release with high Coin tiers |
| Starter Pack — MN-06 | One modest first package; pass conferring one lifetime bundle claim | **7,500 Coins + one Coin 2 token, 15 min / 49** | Coins fixed; token follows C/T | G; available once per account regardless of account age, prior Robux purchases or collection progress; no artificial countdown. Verified ownership plus durable claim marker prevents repeats | P; Coins awarded once after durable fulfillment; token waits for manual activation. No pass upgrade; C/T | F; Welcome rewards unchanged, no figure grant. Shared pass reconciliation, one-time bundle grant, boosts and policy gating |
| Auto Open — MN-07 | Repeat ordinary purchases without repeated clicks; pass | Single-box automation, minimum **3 s** between starts and current presentation completion; **199** | No new Coins or income multiplier | G; owned pass, explicit Start, chosen collection and run budget; stop rules below | P; permanent capability, session runs only; no faster reveal or extra batch mode | F: Single/Open 10/Skip remain free. Existing transactions/pity/results, server cadence and ordinary policy checks |
| Auto Collect — MN-08 | Collect displayed banks while online; pass | **1-second** server cadence / **149** | Existing online Display banks only; transfer, not accrual | G; owned pass and opt-in saved toggle; tutorial rule below. Only owner's occupied/unlocked slots | P; permanent, online only; no proximity requirement for this automation; no multiplier; preserves fractions/overflow | F: plates/taps and outgoing swap collection unchanged. Shared bank helper, session scheduler, tutorial protection |
| Movement — MN-09 | Optional extra movement; pass | WalkSpeed **48 studs/s** (36 + 12) / **49** | None | Ready profile / verified pass; once. Toggle to 36 remains available | P; permanent; highest eligible movement value, never additive across entitlements; apply initial character/late Humanoid/respawn | F: **36** retained. PlayerMovement boundary and device/collision acceptance; no VIP speed benefit |
| VIP — MN-10 | Two actual economic benefits; pass | **+10% Display-derived rate + 500 fixed Coins with each existing daily Grove claim / 199** | C for rate; fixed extra 500 excluded from C | G; once; daily supplement shares the existing UTC claim marker, no independent repeat. Buying after today's daily claim starts supplement next UTC day | P; permanent, V=1.10; no Luck, automation, movement, extra slots, exclusive figures or cosmetics | F: same daily box/goal/Login/Welcome. Rate composition, atomic daily supplement, policy/provenance |
| Timed Coins — MN-11 | Temporary 2x Display earnings; three DPs granting tokens | **2x, 15 / 30 / 60 min; 29 / 49 / 79** | C, including capped offline time overlap | G; repeatable tokens; ownership not permanent | P/T; same Coin timer, durations extend, not powers; M*V*BC | F; receipt/token ledger, expiry integration, offline overlap |
| Permanent Luck — MN-12 | Higher normalized Rare-or-better odds; pass | **Luck weight 2, permanent / 399** | No direct Coin grant; higher-rate figures can affect later R0 | G plus paid-random eligibility; once. One permanent tier proposed; no permanent Luck 4 pass | P/L; verified activation, no early pity guarantee; max with timed 4 | F: exact current odds and pity. Probability/disclosure/provenance systems; recommend late release |
| Timed Luck — MN-11/12 | Temporary odds reweighting; two token DPs | **Luck 2 / Luck 4, each 30 min; 49 / 99** | No direct grant | G plus paid-random eligibility; repeatable; hide redundant Luck 2 for permanent Luck owner | P/T/L; wall time, max strength, no different-strength overlap; exact odds below | F; same dependencies as permanent Luck plus tokens/clock |
| Timed combo — MN-11 | Coin 2 + Luck 2 together; token DP | **Both 30 min / 79** | C for Coin component | G plus paid-random eligibility; repeatable; do not offer if either component unusable/redundant | P/T/L; atomic compatible activation; shared timers, no extra power | F; both boost dependencies. Retained combo is not a reintroduction of excluded general bundles |
| 2x offline — MN-22 | At login, the welcome-back screen shows the Coins earned offline and offers **Claim** or **Double & Claim** | Example: the screen shows **10,000 Coins**; Claim pays **10,000**, Double & Claim pays **20,000** for that return | The amount shown on this return screen | Positive unclaimed reward; one double claim per return; ordinary Claim stays free | Choosing Double & Claim saves the frozen return, buys one saved credit if needed, then explicit redemption adds extra N once | Existing offline reward calculation supplies the shown amount. Requires pending-claim and credit recovery; 49-Robux saved-credit flow approved 2026-10-12 |

### Coin tier acquisition and value implications

Recommend **independent passes with highest-tier-wins**, rather than a repeatable developer product
pretending to be an upgrade with account-specific credit. A new player can buy 8x directly. An owner
of 2x pays the full 399 proposed Robux for 4x: cumulative spend 548; 2x→4x→8x totals 1,547,
versus 999 direct. This disadvantage must be explicit before the upgrade prompt. Hide lower/equal
offers once superseded, but a lower pass bought outside the game never removes a higher entitlement.
There is no refund, trade-in, discounted difference or multiplied ownership implied by this model.

This uses platform pass ownership directly; full-price upgrades may frustrate existing buyers.
If the user requires purchase credit, reopen MN-04 before implementation: approve a staged
durable entitlement/upgrade catalog with specified duplicate-receipt compensation and off-platform
offer handling. Do not simulate a discount by granting invented Robux, silently price a pass by
profile state, or use a repeatable paid receipt that can charge again for no benefit.

Packs are fixed across the game's four economic tiers so their promise remains exact at delayed
receipt delivery; no rate-sensitive or selected-box quote is needed. Their proposed value is:

| Pack | Coins per proposed Robux | Full-price boxes: Grove / Tide / Concepts / Prestige | Other existing Coin sinks |
| --- | ---: | --- | --- |
| Small | 306.12 | 10 / 7 + 1,000 Coins / 0 + 15,000 / 0 + 15,000 | Below slot 4 and first purchased Shelf |
| Medium | 402.68 | 40 / 30 / 3 / 0 + 60,000 | Can fund slot 4 or one 50K Shelf, not both from this grant alone |
| Large | 480.96 | 160 / 120 / 12 / 1 + 40,000 | Less than slot 5; can fund several earlier sinks |
| Huge | 600.30 | 800 / 600 / 60 / 6 | Below slot 6; can fund slots 4+5 but not 6 |

Box counts describe purchasing power, **not guaranteed discoveries or completion**. Deals reduce
the Coin price only when offered and in stock; packs grant no deal refresh or stock bypass. At
75%-price Prestige deals Huge buys eight boxes, subject to three-per-stall hourly stock. Fixed
packs have poor late-game time value and strong early-game skip value; recommend testing Small/
Medium first, not making early free play slower to improve their sale. Starter Pack Coins buy five
Grove boxes; its 15-minute token has rate-dependent value `R0*M*V*900` additional Coins if fully
used with a stable Display. It is not advertised as a fixed total Coin saving.

### Auto Open, Auto Collect and movement behavior

**Auto Open:** ordinary full-price `Buy` Singles only in this proposal. Ordinary manual Open 10
remains free and atomic; no premium bulk purchase, auto deal sniping or free-reward claiming.
Player chooses collection, a finite run limit (default 10, configurable 1–100) and optionally a
Coin reserve; show the maximum run cost before Start. One transaction in flight. Server recomputes
price, affordability/reserve, policy, copy guards, cooldown and current pity for every box. Next
start is at least three seconds after the previous start and only after its existing opening/
result flow completes or the player uses existing free Skip. Client presentation completion
cannot override the server cadence or grant a figure. Never require a new paid skip.

Stop immediately before the next spend on Stop, run budget completion, insufficient spendable
Coins, reserve violation, collection change, user leaving the opening flow, disconnect/death,
policy/entitlement uncertainty, copy safety guard, stale transaction or storage pause. A transaction
already committed still shows its result; Stop never reverses or repeats it. Preserve last settings
only, not a running job. Resume requires explicit Start, including after funds arrive from Auto
Collect, respawn, AFK reconnect or rejoin. Timeouts reconcile/retry the same request ID; they cannot
mint a second purchase. No offline box spending and no automatic Robux prompt.

<a id="auto-collect--mn-08"></a>

**Auto Collect:** once per second after normal settlement, transfer whole Coins from the owner's
currently displayed unlocked slots only, through the existing bank helper. No empty/locked slot,
visitor, Shelf, inventory-only bank, offlinePending or removed figure is a target. Distance and
living-character checks remain on manual collection; authorized automation can operate anywhere
while that owner's online profile/lease is ready, including respawn. It pauses on storage failure,
lease uncertainty and full wallet; residual fractions/overflow remain in the original banks.
Serialize with manual/swap collection so the same bank amount cannot pay twice.

Automatic transfers do not advance the Welcome Quest. Disable automation during its collection
lesson until the player performs a genuine plate/tap collection; skipping guidance does not skip
the lesson's reward stage. Once enabled it does not need to be restarted after ordinary respawn,
but a rejoin waits for a ready session and entitlement verification. The toggle never changes
R0, payout rate or offline reward; it is a collection convenience, not new earning capacity.

**Movement:** use `max(36, eligible selected movement benefits)`; this catalog has just 48 for the
movement pass and no VIP speed component. Owned users can select the free 36. No stacking with
Coin/Luck/timers, no jump or teleport benefit, no speed writes in opening teardown. Resolve on
initial character, late Humanoid, respawn and verified entitlement change. A 140-stud trip is
approximately 3.89 s at 36 or 2.92 s at 48; a 340-stud trip is 9.44 vs 7.08 s, excluding terrain
and acceleration. This is a modest optional convenience; retain existing free Home/Plaza actions.

<a id="luck-and-gamepass-integration--mn-12"></a>

## Exact Luck recommendation — MN-12

**Definition:** multiply the **weight** of each Rare/Legendary/Mythical rarity by L, then normalize
the distribution. Common and Uncommon weights are unchanged. This does not literally multiply
the final chance of every desirable outcome by L.

1. Compute the existing pity distribution `p[r]` in fractions totaling 1, with exactly the current
   warm-ups, increments, high-demand budget sharing and guarantee priority.
2. If a pity guarantee is due, use its existing 100% rarity distribution unchanged. Luck never
   changes the guarantee thresholds, priority, persisted progress or independent resets.
3. Otherwise, set `a[r]=L` for Rare/Legendary/Mythical and `a[r]=1` for Common/Uncommon.
   `Z=sum(p[r]*a[r])`; `q[r]=p[r]*a[r]/Z`. Only existing nonzero rarity buckets participate.
4. For figure i in rarity r, `Pr(i)=q[r]*weight[i]/sum(weights in r)`. Luck does not change
   within-rarity weights or favor undiscovered IDs. Duplicates remain possible and useful.
5. If the opening has a minimum-rarity reward floor, remove buckets below the floor and
   renormalize the remaining `q` before the figure draw. Preserve the existing reward guarantee.
6. Advance counters exactly once per successfully granted box using its actual resulting rarity.
   Failed, stopped and replayed requests advance nothing. Resolve a batch sequentially, never
   roll ten outcomes from one unchanged pity distribution.

| Pool at no pity | Luck weight | Common | Uncommon | Rare | Legendary | Mythical |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Grove/Tide | 1 | 60% | 30% | 10% | — | — |
| Grove/Tide | 2 | 54.545455% | 27.272727% | 18.181818% | — | — |
| Grove/Tide | 4 | 46.153846% | 23.076923% | 30.769231% | — | — |
| Concepts/Echo/Stars | 1 | 60% | 25% | 13.9% | 1% | 0.1% |
| Concepts/Echo/Stars | 2 | 52.173913% | 21.739130% | 24.173913% | 1.739130% | 0.173913% |
| Concepts/Echo/Stars | 4 | 41.379310% | 17.241379% | 38.344828% | 2.758621% | 0.275862% |

For standard base odds, `Z=1+0.15*(L-1)`. Luck 2 Mythical is `0.001*2/1.15`, an approximately
1.739x chance, not 2x or a guarantee. With no intervening pity changes, ten rolls at that chance
give `1-(1-0.0017391304)^10 ≈ 1.7256%` chance of at least one Mythical; ordinary batches actually
update pity each roll. At dry counts dL=100, dM=500, existing pity gives L=4%, M=0.4% and Rare
about 13.436603%; with Luck 2 the normalizer is about 1.178366 and the Mythical chance about
0.67891%. If both pity demands exhaust the high-tier budget, reweighting L/M equally preserves
their ratio and cannot resurrect zero lower buckets. A guaranteed Echo Legendary still splits
100% by its two equal weights: 50% each, not a guaranteed particular Legendary.

**Opening paths:** for an eligible user, apply the same active L to ordinary Single/Open 10,
Coin deal openings, Daily, Login box rewards and Welcome rewards. Free rewards do not receive
different hidden Luck semantics. Welcome U/R under Luck 2 becomes 60% U / 40% R after its floor;
under Luck 4, 42.857143% U / 57.142857% R. The Welcome tenth-box Rare guarantee still grants
Rare if needed; it does not become a Legendary/Mythical in the three-tier pool. For a restricted
or policy-unknown user, paid Luck is suppressed on **every** path; existing free pity and Welcome
guarantees stay in force. A paid-Luck-enhanced free reward is a paid-assisted outcome for lineage
and disclosure, even when no Coins are spent on that claim.

**Disclosure recommendation:** call it “2x Luck weights” with Rare-or-better explanation and actual
odds, or use a plain “Luck” title rather than promise twice every final probability. Before a Luck
purchase show all existing pools' base/current/new rarity and individual odds, affected paths,
expiry and stacking. Before a box spend show the current owner-specific itemized percentages in
a labeled “Odds details” control. Batch details explain conditional odds for each successive roll,
guarantee priority and changing pity; do not advertise current first-roll odds as the ten-roll
distribution. Auto Open refreshes odds after each result and expiry, with details accessible while
running. Use sufficient decimal precision plus the documented rounding disclaimer. Never round a
nonzero Mythical chance to 0%, fabricate odds from client inventory, or hide owned outcomes.

## 2x offline earnings — MN-22

**Approved 2026-10-12:** one repeatable developer product, default list price **49 Robux**, granting one saved, single-use credit. The player explicitly confirms redemption against a frozen return. This supersedes the earlier automatic receipt-to-award flow. Actual viewing-player price still comes from Roblox. IDs, sales and publishing remain disabled.

Free Claim pays the shown whole N. Select/checkout freezes the server award and N before prompting. A verified receipt saves one credit; it never evaluates N, pays Coins or automatically chooses a return. The popup then offers **Redeem +N** using one saved credit. If the base remains unclaimed, redemption pays base N and the extra N atomically; if it was claimed or auto-claimed on rejoin, redemption pays only extra N.

A delayed purchase therefore remains a saved credit until explicit confirmation, and never doubles a newer return automatically. Saved selections survive rejoin and remain accessible through the Store return card. Closing with Later retains the credit. No price or new purchase is required to redeem an owned credit. Capacity or policy rejection preserves its purchased obligation.

**Normal reward calculation:** keep the saved `lastSeen` start, the existing six-hour accrual cap
and 60-second minimum. Save the unmonetized Display rate/loadout inputs, verified permanent Coin
tier/VIP factors and active Coin boost interval at durable checkpoints. Those existing earning
modifiers determine N; there is **no saved offline ownership factor**. A double purchase is
eligible after returning while the current positive reward is pending, not before the absence.

Let `a=max(0, now-lastSeen)` and `d=min(a,21600)`. Unknown lastSeen, clock rollback, empty Display
or `a<60` yields zero. For the saved R0, M and V:

```text
I = integral over [lastSeen, lastSeen+d) of BC(t) dt
  = d + overlapSecondsWithSavedCoin2Boost
normal = floor(min(coinLimit, 0.5 * R0 * M * V * I))
freeClaimTotal = normal
doubleClaimTotal = 2 * normal  # one verified purchase, this absence only
```

Include only Coin boost overlap within the first six capped hours. A boost's state at return
cannot apply it to the entire absence. Luck affects saved figures/duplicates and therefore R0
once; Auto Collect adds nothing. Reconstruct R0 without paid rate factors so M/V/BC are not
applied twice. Double & Claim multiplies the **already computed normal reward** once; it does
not multiply the bonus again using Coin passes, VIP or a currently active boost.

For whole Coins, double the floored displayed N exactly: raw normal 10.75 yields free 10 or paid
20, not 21. The purchase promise is exactly `2*N` for the amount already shown on the screen.
Example: R0=100, one hour, M=2, V=1.1, Coin boost overlap
900 seconds: I=4,500; normal=495,000; Double & Claim=990,000. No boost: 396,000 / 792,000.
Free unmodified R0=100 for six hours: 1,080,000; that return's double purchase: 2,160,000.

Receipt markers, frozen selections, redemption markers and earned/assisted credits share the leased profile write. Replays cannot grant another credit or consume another one for an already redeemed award. Uncertain saves pause authority; recover the original pending generation before acknowledgement. Source schema19 and the historical schema17 product/award handler retain their separate promises. Unknown/restricted economic usability keeps new prompts/redemption closed, while charged receipts still save credits. No release gate is lifted by approval.

See [the implementation and verification contract](OFFLINE_DOUBLE_CLAIM.md) and [approved decision](audits/2026-10-12/monetization/DOUBLE_CLAIM_DECISION.md).


## Verified Roblox requirements and proposed server treatment — MN-02

Primary sources below were accessed **2026-10-11**. Requirements are distinguished from project
recommendations; this review is not approval from Roblox for a particular implementation.

**Platform requirements:** paid random items include direct Robux purchases, random outcomes bought
with Robux-purchasable currency, and probability modifiers such as Luck. Disclose possible final
outcomes and actual numerical percentage odds before spending; provide a clearly labeled details
view where necessary, normalized probabilities and appropriate precision/rounding disclosure.
Explain paid odds modifiers before purchase and dynamically update the active odds. Use
`PolicyService:GetPolicyInfoForPlayerAsync`; when `ArePaidRandomItemsRestricted` is true, block the
paid random generator, including the indirect currency path. Unpaid earnable alternatives are a
documented treatment. Trading restrictions use `IsPaidItemTradingAllowed`; this game retains no
trading. See [paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items).

[Roblox's May 26, 2026 clarification](https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622/1)
also describes outcomes purchased directly or indirectly and distinguishes genuinely earnable
paths where the random outcome cannot be bought. Coin denomination is not an exemption. The
original announcement was verified through the search index; direct opening returned a bot check,
so Creator Hub is the principal readable policy reference. Do not treat community replies as policy.

**Purchase platform:** [passes](https://create.roblox.com/docs/production/monetization/passes) support
a one-time fee for privileges; [developer products](https://create.roblox.com/docs/production/monetization/developer-products)
are suited to repeat purchases such as currency and potions, with server receipt handling and
creator-owned user purchase history. [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt)
documents `ProcessReceipt`, `PurchaseGranted`/`NotProcessedYet`, non-deterministic pending-receipt
order and no timed retry for legacy ProcessReceipt. Do not grant from `PromptProductPurchaseFinished`.
The newer `BindReceiptHandler` API also exists; recommend the documented ProcessReceipt flow for
this small catalog, one dispatcher, and do not register competing handlers for the same products.
[Roblox's purchasing/data guide](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing)
describes saving the benefit and PurchaseId before acknowledging fulfillment; its sample is
guidance, not a requirement to replace this repo's lease system with a framework.

[PolicyService reference](https://create.roblox.com/docs/reference/engine/classes/PolicyService)
provides the per-player lookup/error boundary. Do not substitute a hard-coded country/age list,
VPN assumptions, parent consent inferred by the game, or a client flag for its result.
[Regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing)
documents runtime product information for user-specific displayed prices. The design prices above
remain proposed defaults; implementation must display the actual platform price, not hard-code
this table into a store. There is no subscription or commerce-product selection here.

### Project gating recommendation: preserve a genuinely earned route

Do **not** launch packs, Luck, VIP or any Coin rate product with the current single undifferentiated
wallet and no policy checks. Hiding only the Robux prompt is insufficient: the server must gate
box spending, odds modifiers and paid-derived funds after purchase too. Removing all Coin boxes
for restricted players would damage the free loop and is not the recommendation.

Recommend a persisted distinction between **earned** and **paid-assisted** Coins/figure quantities,
with one visible total and clearly disclosed spendable amount when restrictions apply. This is a
design dependency, not an implemented second currency or approved schema. Initialize all valid
pre-monetization balances, banks, owned quantities and pending rewards as earned; no wipe or
progress conversion loss. Keep paid grants and their downstream earning increments traceable.

| Path | Recommended treatment for eligible user | Restricted user / policy unknown |
| --- | --- | --- |
| Packs, Starter Coins, VIP daily extra | Fixed grant is paid-assisted; boxes purchased with it use paid-random checks | Hide/deny new economy offers. Delivered receipts retain value in paid-assisted balance/reserved credit; cannot spend it on random boxes |
| Permanent/timed Coin bonus, VIP rate | Increment above the unmonetized earned reward is paid-assisted | Suppress paid effects on new accrual; earned baseline and existing earned rewards continue |
| Offline Double & Claim | Base N keeps its source labels; purchased extra N is paid-assisted; one award per receipt reservation | Hide/deny new double purchases; normal free Claim remains. An already charged bonus is recovered as assisted credit, not lost or spendable on restricted randomness |
| Ordinary Single/Open 10/Deal using Coins | Paid-funded or paid-odds result is tagged assisted; normal paid-random disclosure | Permit only an independently earned spending path with base/free-pity odds; reject assisted funding and Luck. All-or-nothing preflight for ten boxes |
| Paid Luck on Daily/Login/Welcome reward | Same L formula and item disclosure; result is assisted | Paid Luck off; free reward/guarantee still granted normally, no lost free claim |
| Auto Open | Same ordinary spend/odds checks for each automated box | Conservatively disable new/running Auto Open pending validation of paid automation treatment; manual earned Single/Open 10 remain |
| Auto Collect / movement | No new reward or odds; transfer source labels unchanged / deterministic movement | Can remain available for earned-bank convenience / movement. They cannot route assisted Coins into random openings |
| Previously paid-derived figures/duplicates | Their income retains provenance | A later policy change does not erase ownership/discovery. Earned copies keep the unassisted earning route; assisted-only income cannot finance restricted randomness |

**Lineage closure recommendation:** for each earning ID retain total and earned-only quantity.
Calculate the earned component from earned copies using the unchanged duplicate curve; the
difference from paid copies/paid modifiers is assisted. An assisted-only ID has zero earned
income component. Allocate any trio bonus using a corresponding earned-only valid Display
projection, not a trio created solely by paid figures. Assisted money spent on a slot/Shelf must
not turn its resulting earning-capacity increment into clean money. Track unlock provenance or
calculate earned income against the earning slots unlocked by earned funding. Shelves themselves
earn nothing. Preserve existing earned Display placement/acquisition rather than retroactively
tainting it. Mixed spending is labeled assisted if any assisted value is necessary; prefer earned
funding only when the player selects that route and can afford the **whole** spend. Free grants
fund the same current boxes, Display and Shelves without a monetization entitlement.

This conservative project treatment of indirect bonus income, paid automation and lineage is an
**inference/recommendation**, not a claim that Roblox specifies this exact ledger algorithm or
has certified it. Before shipping, validate that the chosen earned-only path and migrated paid
history satisfy current platform guidance, including paid-assisted roll history advancing shared
pity before a later earned opening. Preserve the existing shared counters; this specification
does not authorize resetting them or silently introducing separate free/paid pity. If platform
validation requires a different pity/provenance boundary, return that concrete exception for
design review before implementation. If the earned route cannot be demonstrated, keep affected products
off sale; do not close the earned path or call Coin packs exempt. Restriction changes at join and
while active must stop future assisted rolls. Unknown policy fails closed for paid pathways,
with retry/backoff, while already demonstrably earned, unmodified play stays usable.

**Server order:** acquire validated profile/lease → obtain per-player policy/ownership → calculate
approved offer availability → authorize prompt or activation → on each spend recheck current
policy, funding provenance, actual active odds and safety limits → atomically spend/roll/grant/
advance pity/tag result. Perform yielding lookups before the non-yielding mutation, then revalidate
the same session/revision/policy generation. A client cannot supply amount, price, rate, odds,
duration, provenance, receipt ID or eligibility. Disable paid paths during an unresolved policy
refresh; on becoming restricted suspend paid Luck, preserve unused tokens and stop Auto Open.
Active boost wall clocks still expire as disclosed; do not keep them running as hidden modifiers.

| Situation | Proposed user message |
| --- | --- |
| Restricted economic/Luck offer | “This purchase isn't available for your account. You can still earn Coins and open boxes through gameplay.” |
| Assisted Coins cannot buy a box | “These Coins can't be used for random boxes on your account. Earned Coins available: X; this box costs Y.” |
| Policy lookup unavailable | “We couldn't verify this purchase's availability. Please try again. Your earned Coins and free rewards are still available.” |
| Luck suppressed after restriction | “Paid Luck is unavailable for your account. Free odds, pity and reward guarantees still apply.” |
| Boost activation | “Activate 2x Coins for 30 minutes? The timer continues while you're offline. Same boosts add time, not strength.” |
| Redundant/incompatible Luck | “This boost won't improve your current Luck. Your unused boost has been kept.” |
| Receipt awaiting durable save | “Your purchase is being saved. It will be recovered if you reconnect. Don't purchase again to retry.” |
| Auto Open stopped | “Auto Open stopped: [reason]. No further Coins will be spent. Select Start to resume.” |
| Offline claim choice | “You earned N Coins while offline. Claim N for free, or purchase Double & Claim to receive 2N for this return.” |

## Shared fulfillment and implementation dependencies — MN-03

Recommend one server-only catalog with effect definitions, approved decision version and later
assigned platform IDs. A product stays unavailable while its decision is Recommended/Unresolved,
its ID is unassigned or its dependencies are unverified. No automatic use of these prices or
example types. Public display metadata may replicate; authoritative grants/odds/rates stay server-side.

For repeatable purchases, serialize fulfillment under the existing profile lease; verify the
platform receipt's player/product and allowlist mapping. Use PurchaseId as the durable key and
save the exact benefit, provenance and processed marker in the **same recoverable aggregate**.
Only acknowledge PurchaseGranted after confirmed durability, including reconciliation of a lost
save response. Do not separately mark a receipt processed before saving the grant. Failed load,
expired lease, unknown product, unavailable player or storage failure leaves it unacknowledged
for recovery. A duplicate receipt returns the recorded fulfillment without another grant.
Do not rely on callback ordering or the 64 transient gameplay receipts. Monitor unresolved
fulfillment; rejoining can trigger platform recovery, a local timer is not a promise of platform retry.

Passes use platform ownership as the entitlement authority, not a client receipt. Starter's
one-time Coins/token claim additionally requires a durable profile marker and benefit grant.
If a pass purchase succeeds outside the game, reconcile its capability/claim on next join; do
not deny an already owned benefit merely because an in-game prompt was not observed. Economic
benefits are suppressed where policy requires, without deleting ownership or their saved value.

Never discard charged pack Coins because a wallet fills between prompt and receipt. Store the
remainder as reserved purchase credit and release whole Coins when capacity becomes available,
without another receipt grant or multiplier. This is separate from ordinary free bank/offline
limit behavior. Recommend no external sale of consumable products at initial release; whether
external sales are later enabled, every real receipt must still be recoverable without a transient
in-game prompt reservation. No gifting/trading or limited-stock marketing is added.

Future schema work needs bounded, validated/deep-copied receipts/credit, unused tokens, timers,
verified offline snapshots, pending award identity and Coin/figure/unlock provenance. Decide a
receipt-ledger retention/partition strategy that cannot forget still-replayable purchases; do not
prune to the last 64. Preserve valid Economy2 progress and strict decoding. Test older valid schema
upgrades and mixed-server compatibility; coordinate a separately authorized release barrier or
compatibility bridge before new paid fields are written. Do not silently reset corrupt data or
change store namespace. No schema number or migration implementation is approved here.

## Pacing evidence and value risks — MN-01

**Existing tool, reproduced 2026-10-11:** `tests/run.py` generated isolated copies of the current
modules, then `tests/EconomySimulation.luau` ran with the repo's standalone Luau executable.
300 seeded runs; actual Rules/CollectionEconomy; strongest Display with themed alternatives;
buy useful sequential slots when cost ≤20 target boxes; 30 Grove + 30 Tide before Concepts,
then Echo, then Stars, stopping each high-tier collection at its first Mythical. Instant
collection; no reveal/menu delay, free rewards, offline time or Shelf purchases.

| Existing route: time within tier to first Mythical | Median | p90 | Median boxes |
| --- | ---: | ---: | ---: |
| Concepts | 5.06 h | 6.83 h | 484 |
| Echo | 4.28 h | 6.02 h | 438 |
| Stars | 1.59 h | 2.59 h | 439 |

The third collection is already faster because earlier Mythicals/duplicates fund it. These
results do not support making Stars more expensive as a monetization task. Neither the 550/850
payback parameter nor a guaranteed-rarity threshold is a player's time-to-box promise.

**One-box affordability, calculated from source, no wallet balance:**

| Earned Display fixture | Free | Coin 2 | Coin 4 | Coin 8 |
| --- | ---: | ---: | ---: | ---: |
| Three copies of weakest Grove Common, one ID earning; next Grove box | 297.54 s | 148.77 s | 74.38 s | 37.19 s |
| Three distinct Grove Commons + themed trio; next Grove box | 92.95 s | 46.47 s | 23.24 s | 11.62 s |
| One Concepts Mythical, no duplicate/set; first 200K Prestige box | 304.75 s | 152.38 s | 76.19 s | 38.09 s |

These are continuous rate waits before whole-bank collection rounding or movement/reveal time.
Buying a tier changes future accrual, not already banked amounts. A fresh 4,500 wallet already
buys three Grove or two Tide boxes, but cannot buy Concepts or Prestige. The free Welcome Box
guarantees at least an Uncommon (minimum ~9.39 Coins/s); its x10 gives at least one Rare. This
mitigates the duplicate-only fixture without paid intervention. Do not price Starter as the only
solution to an unlucky first three ordinary purchases.

**Completion comparison simulation:** see the table below. Research extends the existing tool's
strongest-Display and slot-purchase strategy using isolated actual modules; only hypothetical
Coin accrual and the proposed normalized Luck wrapper are changed. 300 seeded runs per scenario,
seed 97531 reset per scenario; complete Grove → Tide → Concepts → Echo → Stars, all 43 existing
figures. Three seconds of equal single-opening interaction time added per box, earning during
that time, then any affordability wait. No free rewards/deals/offline time or Shelf spending;
instant bank collection and optimal Display. Coin 2/4/8 are constant owned factors. Luck 2 is
constant permanent; the 17.6/Luck 4 case is a stress bound assuming continuously renewed boosts,
not one 30-minute purchase or a quoted Robux cost. No other economy tuning changes.

| Scenario | All 43 complete, median / p90 | Concepts complete, median / p90 | Echo complete, median / p90 | Stars complete, median / p90 |
| --- | --- | --- | --- | --- |
| Free | 11.359 / 13.997 h | 5.157 / 7.139 h | 4.387 / 5.931 h | 1.616 / 2.511 h |
| Coin 2 | 5.680 / 6.999 h | 2.578 / 3.569 h | 2.194 / 2.965 h | 0.808 / 1.256 h |
| Coin 4 | 2.869 / 3.526 h | 1.289 / 1.785 h | 1.097 / 1.483 h | 0.418 / 0.661 h |
| Coin 8 | 1.664 / 2.068 h | 0.658 / 0.937 h | 0.559 / 0.822 h | 0.397 / 0.631 h |
| Coin 2 + permanent Luck 2 | 4.347 / 5.561 h | 1.969 / 2.841 h | 1.711 / 2.324 h | 0.650 / 0.972 h |
| Coin 17.6 + Luck 4 stress bound | 0.768 / 1.113 h | 0.251 / 0.456 h | 0.229 / 0.459 h | 0.227 / 0.419 h |

Within-tier medians do not add to the median of whole-route totals. Completion pulls:

| Collection | Free / Coin-only median, p90 | Luck 2 median, p90 | Luck 4 stress median, p90 |
| --- | --- | --- | --- |
| Grove | 15, 25 | 14, 24 | 15, 26 |
| Tide | 15, 27 | 13, 21 | 15, 27 |
| Concepts | 469, 773 | 365, 628 | 241, 485 |
| Echo | 434, 732 | 363, 595 | 257, 533 |
| Stars | 476, 757 | 385, 612 | 272, 503 |

For the completion route, free first-Mythical medians/p90 are Concepts 5.157/7.139 h,
Echo 4.306/5.837 h and Stars 1.610/2.511 h. Coin 2 + Luck 2 yields 1.969/2.841,
1.702/2.324 and 0.646/0.972 h. These differ from the original first-Mythical tool because
the route completes each collection and includes the three-second delay. Research completed
one full six-scenario run; its successful output is the evidence reported here.

Free and Coin-only scenarios use paired draw streams and the same pull counts: Coin tiers
accelerate affordability, not collection probability. Luck changes both the draw distribution and
future earning loadout; it does not divide completion times or pull counts by the named factor.
p90 is an unlucky modeled percentile, not the guarantee threshold, a maximum or observed retention.
Full completion needs the missing ordinary items as well as a Mythical; high Luck can delay a
remaining Common, so no “faster guaranteed completion” promise is valid.

**Free rewards and sinks excluded from simulations, explicitly accounted for:** one successful
seven-day Login cycle gives 14,000 Coins plus Grove/Tide/Concepts boxes (23,500 full-price Coin
equivalent). Seven UTC daily Grove claims add seven boxes (10,500 equivalent); seven completed
goals add 7,000 Coins. Together 54,500 equivalent over that week, conditional on each claim/goal;
boxes are random outcomes, not liquid Coins or guaranteed completion. Starting Coins add 4,500
once; Welcome adds 11 boxes with its floors, not eleven wallet grants. VIP's proposed supplement
adds at most 3,500 fixed Coins across those seven daily claims, without improving their box odds.
Do not imply VIP doubles existing Login rewards.

Offline income adds 50% of the saved effective rate for up to six hours per qualifying absence;
a Double & Claim purchase doubles that return's displayed normal amount, not the cap. At the three-Common themed R0≈16.14,
free six-hour reward is ~174K Coins, enough for eight Concepts boxes at full price but below one
Prestige box; a double purchase for that return is ~348K, enough for one Prestige box. Stronger loadouts
change this sharply. Existing slot purchases total 4.44M Coins. Shelf purchases start at 50K,
125K and 312.5K and grant no income; each first completion instead grants one free Shelf unit.
Spending on Shelves or retaining a decorative Display makes progression slower than the optimizer,
while rewards/deals/offline income make it faster. No simulation here is a universal session budget.

**Recommendation from evidence:** preserve current free tuning; start product validation with
convenience, Coin 2 and modest fixed grants. Keep Coin 4/8, Large/Huge packs and Luck/combo on hold
for launch until the user accepts their completion acceleration and policy dependencies. The
stress combination can compress existing content substantially; adding variants/collections or
weakening free progression is not an authorized remedy. Price hypotheses need later real player
acceptance and spending data; current simulations cannot determine conversion or a fair market price.

## Verification and future acceptance

**PASS, 2026-10-11:** twelve focused existing suites run against isolated source-generated modules:
Mvp, LinearPity, Offline, SaveSafety, Tutorial, LoginRewards, Deals, DisplayReplacement, EquipBest,
PlayerMovement, Shelves and Opening. They cover existing distributions/guarantees, duplicate rates,
bank conservation, offline limits/replays, free claims, progression, persistence and movement.
Existing pacing tool reproduced; research extension results above. These tests do not test an
implemented paid system; none exists. **PASS:** document link/path and numerical consistency checks.
**NOT RUN:** live purchases, receipts, PolicyService emulation, native DataStore, multi-client,
physical-device playtests or monetized player studies. **N/A:** gameplay implementation, product
creation, price edits, publishing and production data mutation in this task.

Before any separately authorized implementation/launch, require:

- Deterministic odds tests at L=1/2/4 for every current pool, all pity boundaries, both guarantees,
  high-demand overlap, weighted items, reward floors, sequential batches and expiry between rolls;
  all probabilities valid/normalized and displayed from the authoritative distribution.
- Coin composition/settlement tests before/after ownership, duplicate grants, replacements and
  expiry; fixed grants unmultiplied; Auto Collect/manual/swap races conserve banks and tutorial rules.
- Boost token/activation/replay, mixed strengths, combo atomicity, same-effect extension, 24-hour
  bound, logout, backward clock and partial offline overlap checks.
- Offline 59/60 seconds, six-hour boundary, unknown/rollback lastSeen, legacy pending,
  odd/fractional rounding and modifier composition; free vs double claim, cancellation, repeated
  clicks, immutable award reservation, late receipt after base auto-claim, newer absences,
  cancelled/reopened prompts, extra receipts, bonus overflow credit and crash/save recovery.
- Durable paid receipt tests for duplicate/out-of-order/concurrent callbacks, lost replies,
  charged purchases without prompt state, overflow credit, disconnects and lease/save failure;
  no acknowledgement before confirmed benefit/marker persistence.
- Restricted/allowed/error policy emulation on all money-to-box paths, mixed balances,
  paid-derived duplicate/slot income, free rewards with paid Luck, policy changes while Auto Open
  runs and outside-game ownership. Verify paid products remain unavailable until the earned route
  is shown safe; no country/age guess and no backdoor via a Deal or batch request.
- Existing [quality gates](qa/QUALITY_GATES.md), native device/input and multi-client purchase/
  odds/expiry presentation, isolated persistent tests and separately authorized release review.

## Concise decision table — smallest remaining user choices

The rules above resolve the detailed options as recommendations. The user need only settle these
three bundles or name specific exceptions. **D1, full D2 with its validation gate, and MN-22's
per-return Double & Claim benefit flow were approved by the user on 2026-10-11. On 2026-10-12 the user selected **all retained products** for the configuration handoff (D3 subset).
MN-22's 49-Robux price and reusable credit developer-product flow are approved on 2026-10-12. Catalog creation and release were not performed.**

| Decision | Recommendation to accept or amend | Status / implementation consequence |
| --- | --- | --- |
| D1 — Product benefits, values and entitlement model | Adopt matrix amounts/prices as proposed defaults; independent highest-owned Coin passes with full-price upgrades/no credit; fixed packs; lifetime once-per-account Starter; concrete two-benefit VIP; 48 movement; user-confirmed return-screen Claim / Double & Claim flow; choose its purchase price separately | **Approved by the user, 2026-10-11** (benefits, amounts, entitlement model and the matrix's proposed default list prices). MN-22 price and credit/redemption DP protocol were approved on 2026-10-12; all20 product IDs are configured locally; sales/integration gates remain closed. Approval does not activate a catalog: live prices come from platform product info, and no product goes on sale before D2, the P02 foundation and a separate release decision. The Robux Store UI shows these benefits with buying switched off |
| D2 — Shared effects and paid-random boundary | Adopt C/L/T/G, normalized Rare-or-better Luck, unchanged pity/floors, elapsed wall-time tokens and overlap, earned/assisted lineage plus restricted-player earned path. Require validation of that path before economic/Luck launch | **Approved by the user, 2026-10-11, with validation gate.** Paid economic effects remain disabled until policy and earned-lineage implementation and validation are complete. Platform validation remains unresolved. No Luck/pack/income implementation may use a simpler ungated wallet or odds formula. Design approval does not authorize sales, product creation or publication |
| D3 — Initial product subset | All retained products selected by the user for the configuration handoff; earlier staged-release advice remains pacing/policy context | **Subset approved by the user, 2026-10-12: all retained products.** Sales and publishing remain disabled. This choice does not authorize platform catalog creation, waive validation gates or approve release. The user confirmed no platform products exist yet |

Record each future response with decision/date, any exceptions and approved benefit/price version.
“Retained”, “recommended”, a planning price or a task prompt is not approval. A dependent task must
stop only the dependent portion if a decision is still missing, and surface the missing decision;
it must not select a product price/type/upgrade/clock/Luck/offline model without authorization.

Keep original work IDs: MN-01 economy/pacing; MN-02 policy; MN-03 foundation; MN-04 Coins;
MN-05 packs; MN-06 Starter; MN-07 Auto Open; MN-08 Auto Collect; MN-09 movement; MN-10 VIP;
MN-11 timed boosts; MN-12 Luck; MN-22 offline. MN-13–20 remain retired, and MN-21 future collection
work remains separate. [Grouped task prompts](MONETIZATION_TASK_PROMPTS.md) must consume this
decision table; they do not approve or supersede it.

## Sources and maintenance

[Product backlog](PRODUCT_BACKLOG.md), [playtest backlog](PRODUCT_BACKLOG_PLAYTEST_2026-10-05.md),
[game audit](GAME_AUDIT.md) and [plots/Shelves](PLAYER_PLOTS_AND_SHELVES.md) retain their historical
evidence. The cosmetics-first monetization idea is superseded by the user's exclusions, and its
free-control guardrails remain. Current source configuration and the inspected tests establish
the baseline; official links above establish platform guidance as of the access date. Recheck
platform requirements before implementation and before release. No competitor prices, invented
approved IDs or undisclosed new gameplay assumptions are used as authority.
