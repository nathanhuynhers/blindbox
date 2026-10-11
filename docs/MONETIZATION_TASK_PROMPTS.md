# Monetization task prompts

Prepared 2026-10-11 from the [monetization plan](MONETIZATION.md) and the user's feature removals
and addition of 2x offline earnings. These are copy-ready prompts for future tasks, not evidence
of implementation or authorization to run them during this documentation task.

Each text block is a complete prompt. Product rules stay in `docs/MONETIZATION.md`; approved
design decisions should be recorded there before dependent implementation. All product IDs,
Robux prices, pack amounts, benefit values and unresolved purchase types remain undecided.

## Grouping and execution order

| Prompt | Grouped work | Plan IDs | Depends on |
| --- | --- | --- | --- |
| P01 | Product rules, economy/value and platform review | MN-01, MN-02; decisions for all retained products | Current repository and user review |
| P02 | Shared purchases, entitlements and durable fulfillment | MN-03 | Approved P01 contracts |
| P03 | Permanent Coin tiers and 2x offline earnings | MN-04, MN-22 | P01, P02 |
| P04 | Permanent Luck and timed Coin/Luck/combo boosts | MN-11, MN-12 | P01, P02, P03's modifier interface |
| P05 | Auto Open, Auto Collect and movement upgrade | MN-07, MN-08, MN-09 | P01, P02; existing gameplay paths |
| P06 | Coin packs, Starter Pack and VIP | MN-05, MN-06, MN-10 | P01, P02; required benefits from P03–P05 |
| P07 | Central Robux store UI design | All retained features | P01 for final copy; labelled fixtures can be designed earlier |
| P08 | Store UI implementation and purchase integration | P07 design plus MN-03/product presentation | Approved P07; P02–P06 contracts |
| P09 | End-to-end monetization acceptance | All retained features | Implemented P02–P06 and P08 |

Run P01 first. P07 can then establish the design before feature implementation; P02–P06 build
the shared backend and grouped products, followed by P08 and P09. P04 stays late relative to
core gameplay polish, as required by the existing Luck backlog. Dependencies describe sequencing,
not a request to run multiple agents or make unrelated changes together.

The remaining eleven player-facing features are Coin multipliers, Coin packs, Starter Pack,
Auto Open, Auto Collect, movement speed upgrade, VIP, timed Coin boosts, permanent Luck,
timed Luck/combo boosts and 2x offline earnings. Timed Coin/Luck effects share an implementation;
Coin/offline modifiers share earnings rules; Coin packs/Starter Pack/VIP share configured benefits.
Convenience passes share entitlement integration but retain separate runtime modules.

Fast Open, Premium Multi Open, paid Shelf/plot/Display/opening/status cosmetics, premium rotating
shop, general bundles, storage upgrades, Pocket Pass, subscriptions and gifting remain excluded.
A central Robux store is an interface for retained products, not the removed rotating-shop system.
Starter Pack and VIP remain allowed packages; do not use them to restore excluded benefits.

## P01 — Product decisions, economy and platform requirements

```text
Prepare the monetization product specification for Blindbox Town. This task is design and
research only; do not implement gameplay, create platform products, publish, or change pricing.

Read AGENTS.md, docs/MONETIZATION.md, docs/GAME_DESIGN.md, docs/archive/MVP.md,
docs/ROADMAP.md, docs/ECONOMY.md, docs/ARCHITECTURE.md and docs/DATA_MODEL.md. Inspect the current
server economy/configuration and relevant tests before proposing changes. Source is the actual
baseline when an older planning value disagrees. Preserve the free loop and all excluded features.

Cover every retained product family: permanent 2x/4x/8x Coins; Small/Medium/Large/Huge Coin packs;
Starter Pack; Auto Open; Auto Collect; movement upgrade; VIP; timed Coin boosts; permanent Luck;
timed Luck/combo boosts; and 2x offline earnings. Consolidate shared rules rather than inventing
different stacking or purchase semantics per feature.

Produce a concrete product matrix: player benefit, proposed platform purchase type, amount/tier/
duration, eligible Coin sources, eligibility and purchase limits, ownership/upgrade behavior,
activation/expiry, stacking, free-player behavior, dependencies, and proposed Robux value/price.
Mark recommendations and unresolved decisions clearly. Do not invent approved product IDs/prices.
Account for existing Open 10/Skip, free rewards, duplicate income, pity, six Coin-unlocked Display
slots, Coin-funded Shelf acquisition, offline claims and the current movement baseline.

Resolve these choices into reviewable recommendations:
- Coin tier acquisition/upgrade rules and which grants/rates they affect.
- Luck's exact normalized distribution and interaction with pity/guarantees, within-rarity weights,
  and paid/free/reward opening paths; never describe 2x Luck as a guarantee without the math.
- Boost duration/activation, elapsed-time clock, expiry, same-effect repurchases and logout behavior.
- Coin pack values, Starter Pack eligibility/contents, and the actual non-cosmetic VIP benefits.
- Auto Open cadence, supported ordinary purchase mode and stop/resume behavior; Auto Collect rules.
- Movement benefit and stacking without lowering the current free movement speed.
- Permanent entitlement versus per-return purchase for 2x offline earnings. It doubles the normal
  offline reward: current 0.5x becomes 1x before other modifiers, with the same six-hour cap and
  60-second minimum. Define eligibility timing, pending rewards, rounding and modifier composition.

Verify current official Roblox Creator/platform documentation for selected purchase types,
receipts/entitlements, paid randomized items, applicable per-player restrictions and odds disclosure,
including the indirect path of paid Coins buying randomized boxes. Cite primary sources with access
date; distinguish actual requirements from recommendations. Do not assume Coin packs or Luck can
ship simply because the underlying box uses Coins. Define required server gating and user messages.

Use existing pacing tools where applicable; label simulations and their assumptions. Compare free,
paid and unlucky progression, one-box affordability and collection completion. Do not make free
play artificially worse, reset progression, or add future collections/variants as part of pricing.

Update docs/MONETIZATION.md with findings and a concise decision table. Present the smallest set of
remaining product choices for the user to settle. Only mark a choice approved when the user has
actually approved it; dependent implementation must consume those decisions, not silently pick them.
```

## P02 — Purchase and entitlement foundation

```text
Implement the shared monetization purchase foundation for Blindbox Town using the approved P01
specification. Read AGENTS.md, docs/MONETIZATION.md, docs/MONETIZATION_TASK_PROMPTS.md (P01/P02),
docs/GAME_DESIGN.md, docs/archive/MVP.md, docs/ROADMAP.md, docs/ARCHITECTURE.md, docs/DATA_MODEL.md
and docs/OPERATIONS.md. Inspect Protocol, Transactions, Rules, Profile, Storage, Persistence,
server lifecycle and Rojo/tool mappings first. Identify missing product decisions concretely;
continue independent foundation work without inventing product benefits or IDs.

Build small strict Luau modules for the approved server-owned catalog, verified permanent
entitlements, product dispatch and durable consumable fulfillment. Preserve existing replication
boundaries and pinned tools; add no framework/dependency. Do not create Roblox products or publish.
Missing or invalid product configuration must disable that offer rather than trigger a fake purchase.

Verify the relevant current official Roblox purchase APIs before implementation. Server verification
and durable fulfillment determine benefits; client purchase-completion events are not grant authority.
Allowlist product identities and use the platform-provided purchaser identity. Handle verification
failure distinctly from verified non-ownership. Refresh entitlements through supported server APIs
and define what happens to active benefits during failed checks; never trust client ownership flags.

Design durable receipt deduplication, grant and acknowledgement together with existing profile leases
and generations. Never acknowledge a consumable as fulfilled before its grant and receipt marker are
durably safe. Existing gameplay receipts are bounded/transient and do not satisfy this requirement.
Handle duplicate/concurrent receipt delivery, player absence, unknown products, storage pause,
failed saves, lost responses, lease conflicts, server crashes and delayed retry after rejoin.
Prevent lost rewards and duplicate rewards. Review marker growth and retention explicitly.
If schema changes are necessary, upgrade current valid data without resetting or overwriting it.

Expose a typed presentation contract for owner-visible products, eligibility, verified ownership,
active benefits and fulfillment state. Keep authoritative grant rules server-only; a shared public
product descriptor is allowed but never becomes authority. Define supported purchase initiation,
cancellation, retry, unavailable and pending-recovery states for later UI work. Apply P01's platform
eligibility restrictions server-side and share the truthful result with the owner UI.

This task creates reusable plumbing and meaningful test fixtures, not all product implementations
or the final store UI. Keep test grants/providers out of production mappings. Test fulfillment
failure/recovery and migration behavior in addition to happy paths, including save-failed and
response-lost-after-commit scenarios. Run required pinned checks and Luau diagnostics; perform native
Studio/service checks where available. Report exactly what ran and what remains unverified.
Document the purchase contracts and persistence changes in the relevant existing system references.
```

## P03 — Coin multipliers and 2x offline earnings

```text
Implement permanent Coin tiers and the 2x offline earnings bonus as one coherent earnings task.
Read AGENTS.md, docs/MONETIZATION.md (MN-04/MN-22), docs/MONETIZATION_TASK_PROMPTS.md (P01–P03),
docs/GAME_DESIGN.md, docs/archive/MVP.md, docs/ROADMAP.md, docs/ECONOMY.md, docs/ARCHITECTURE.md,
docs/DATA_MODEL.md and docs/AFK_RECONNECT.md. Inspect actual earning/claim paths and tests first.
Require approved source eligibility, tier/upgrade, stacking and offline purchase-type decisions
from P01, and use P02's purchase/entitlement contracts. Do not invent prices, product IDs or stacking.

Implement 2x/4x/8x as the approved effective tier model, avoiding accidental multiplication of all
owned tiers. Centralize earnings modifier resolution so later timed boosts/VIP can compose with it.
Keep direct grants, Coin packs, rewards and offline income excluded or included exactly as specified.
Settle elapsed online earnings at the previous effective rate before any modifier starts, changes
or ends; buying a multiplier cannot retroactively multiply existing banked Coins. Preserve unique
Display placement, duplicates, themed bonuses, per-figure banks, fractions and wallet safety limits.

Implement 2x offline Coins as twice the ordinary eligible offline reward. The current free rate is
0.5 of effective online Display income, so this feature alone raises that to 1.0, not 2.0. Keep the
six-hour cap and 60-second minimum. Use server-owned saved time and state; never accept a client
duration, reward amount or multiplier. Apply the approved rules for other modifiers, eligibility
during absence and pending earnings. Handle AFK reconnect/save-release handoffs without double accrual.

If P01 selects a permanent entitlement, grant the doubled offline amount once under the approved
entitlement timing. If P01 selects a per-return purchase, use P02's durable receipt path and identify
the eligible return reward robustly: delayed receipts, a normal claim before fulfillment, repeated
claims and rejoining must not lose or duplicate the purchased bonus. Implement only the selected
model. Preserve the existing free claim/tap-outside flow and leftover pending-reward recovery.

Expose owner-visible effective modifiers and an honest base/bonus/total offline breakdown for P08;
do not build the whole shop. Test tier combinations, source eligibility, mid-interval changes,
rounding/overflow, offline boundaries, pending reward handling, reconnects, receipt replay and
save failures. Update economy/data contracts as needed without changing unrelated tuning.
Run repository-required checks, Luau diagnostics and relevant persistent/multi-client Studio checks;
clearly separate automated results from remaining native/platform acceptance.
```

## P04 — Luck and timed Coin/Luck boosts

```text
Implement permanent Luck and timed Coin/Luck/combo boosts, sharing modifier and timer rules.
Read AGENTS.md, docs/MONETIZATION.md (MN-11/MN-12), docs/MONETIZATION_TASK_PROMPTS.md (P01–P04),
docs/GAME_DESIGN.md, docs/archive/MVP.md, docs/ROADMAP.md, docs/ECONOMY.md, docs/ARCHITECTURE.md
and docs/DATA_MODEL.md. Inspect CollectionEconomy, Rules, pity/odds projections, income settlement,
ShopLuck and applicable tests. Core gameplay polish and P01's approved Luck/boost specification
must precede final implementation. Use P02 for fulfillment and P03's earnings modifier interface.

Implement only approved Luck tiers/formulas and boost SKUs. The illustrative 2x/4x Luck and
15/30/60-minute durations are not permission to select final values. Make permanent Luck, timed
Luck, VIP and pity composition explicit. One authoritative normalized distribution must drive
both rolls and published rarity/figure odds. Retain independent pity counters, guarantees and
simultaneous priority according to the approved composition, across all supported collections.
Audit Buy, BuyTen, Deal, Daily, Login and Welcome grant paths against the approved applicability
matrix. No client supplies Luck, probabilities, expiry or grants.

Implement the approved activation/expiry and repurchase rules for timed Coins, timed Luck and
combo boosts. Persist the necessary state with valid schema upgrades; restore/reconcile on rejoin.
Use the approved online-time or wall-clock policy without silently switching clocks. Segment
income settlement at timer boundaries and preserve fractions: a late scheduler tick must not
apply an expired Coin boost to the whole elapsed interval. Apply the approved offline treatment.
Receipt retries cannot activate/grant the same boost twice; genuine separate purchases follow
the specified extension/stacking/replacement rule. Keep tasks bounded and lifecycle-owned.

Expose active effects/remaining time and base/current odds for the owner UI. Distinguish Luck
from free pity; do not imply the rarity chances literally double unless the approved math does.
Enforce P01's current platform restrictions and odds disclosures before relevant randomized actions,
including automation. Do not add Secrets, variants, mastery or new collections.

Test normalization, rarity/figure odds agreement, guarantee boundaries, all modifier combinations,
expiry crossings, logout/rejoin, clock edge cases, duplicate delivery and failure recovery. Verify
free-player probabilities remain unchanged. Run required pinned checks, Luau diagnostics and native
Studio/multi-client checks for affected behavior; record remaining service/device acceptance.
```

## P05 — Convenience passes: Auto Open, Auto Collect and movement

```text
Implement the approved convenience upgrades: Auto Open, Auto Collect and movement speed.
Read AGENTS.md, docs/MONETIZATION.md (MN-07/MN-08/MN-09), docs/MONETIZATION_TASK_PROMPTS.md
(P01/P02/P05), docs/GAME_DESIGN.md, docs/archive/MVP.md, docs/ROADMAP.md, docs/ARCHITECTURE.md,
docs/ECONOMY.md, docs/DATA_MODEL.md, docs/OPENING.md and docs/AFK_RECONNECT.md. Inspect current
purchase/collection/character lifecycles and opening focus before editing. Use approved P01 benefit
rules and P02 entitlements. Share entitlement plumbing but keep each runtime in a focused module.

Auto Open: automate only the approved ordinary Coin purchase mode through the existing authoritative
purchase/grant path. Permit at most one owned purchase/reveal workflow at a time; schedule the next
only when confirmed state and presentation permit it. Recheck affordability, eligibility, rates,
session readiness and paid-random restrictions server-side. Implement approved stop/resume behavior
for user Stop, insufficient Coins, unavailable products/collection, errors, storage pause,
death/reset, disconnect, entitlement changes and conflicting UI/focus. Do not speed up animations,
gate Open 10/Skip, add a paid batch mode or invent a bypass remote. A UI toggle requests automation;
it never authorizes spending arbitrary amounts or client-selected outcomes.

Auto Collect: transfer only the owner's eligible Display banks at the approved bounded cadence,
using server-owned bank transfer rules. Ongoing automation must not rely on spoofed physical-touch
events or client amounts. Retain manual and replacement collection, fractions, wallet overflow
and one-bank-per-figure behavior. Apply the approved Welcome Quest treatment so automation cannot
accidentally break onboarding. Collection itself is not a second income multiplier.

Movement: integrate the approved speed upgrade into the existing PlayerMovement resolver.
Read the current baseline (36 studs/second at prompt creation), do not restore the older 20 value
or reduce free speed to sell the upgrade. Handle initial/late Humanoids, respawn, entitlement
refresh and teardown; cinematics and Home must not overwrite the resolved speed. Do not add sprinting.

Integrate automation with pending transactions, opening batches and AFK save/release handoff:
pause or stop before frozen/released storage; do not duplicate loops after rejoin. Add only the
necessary usable gameplay toggles/status via current UI components; defer final store styling to P08.
Test one-loop ownership, stop conditions, retry/rapid input, simultaneous collection, character
lifecycle and cross-owner rejection. Run required checks/diagnostics and relevant native two-client
Studio checks, recording what is still blocked or untested.
```

## P06 — Coin packs, Starter Pack and VIP

```text
Implement Coin packs, Starter Pack and VIP using shared configured grants and benefits.
Read AGENTS.md, docs/MONETIZATION.md (MN-05/MN-06/MN-10), docs/MONETIZATION_TASK_PROMPTS.md
(P01/P02/P03/P04/P06), docs/GAME_DESIGN.md, docs/archive/MVP.md, docs/ROADMAP.md, docs/ECONOMY.md,
docs/ARCHITECTURE.md and docs/DATA_MODEL.md. Inspect reward/profile paths and the implemented
foundation/modifier interfaces. Require approved contents, eligibility, limits, Coin-source
rules and purchase types; do not invent amounts, prices or VIP perks.

Coin packs: configure the approved Small/Medium/Large/Huge offers, with amounts computed and
validated server-side under P01's fixed/progression-sensitive rule. Do not multiply a paid direct
grant by Coin/Luck bonuses unless explicitly approved. Define wallet-cap handling before enabling
a purchase; a receipt cannot silently consume real payment while dropping the intended reward.
Use P02's durable consumable fulfillment and product eligibility checks.

Starter Pack: grant only approved Coins/boosts, keep it separate from free Welcome rewards and
enforce the approved eligibility/purchase limit across sessions. Commit all contents and claim/
receipt state coherently, or preserve a durable recoverable obligation; a partial failure must not
leave an acknowledged but incomplete package. Decide the treatment of a purchase arriving after
eligibility changes from the approved rules, not from client display state.

VIP: apply only the approved non-cosmetic benefits through shared earnings/Luck/reward interfaces.
Entitlement refresh must not rerun one-time grants, retroactively pay already claimed dailies,
or stack the same VIP benefit multiple times. Use existing UTC reward claim rules and persistence.
Permanent entitlement and consumable rewards have distinct verification/fulfillment lifecycles.

Do not reintroduce paid cosmetics, tags/titles/auras, general bundles, subscriptions, rotating
offers, storage or gifting through Starter Pack or VIP. Expose typed product descriptions,
actual benefit values, eligibility, owned/claimed state and fulfillment feedback for P08.
Keep the final store UI out of this task.

Test pack grants, caps, Starter eligibility, partial/lost-save recovery, duplicate receipts,
concurrent requests, VIP refresh, reward-day boundaries and modifier composition. Confirm paid
products cannot alter another profile or replace failed loads with defaults. Run pinned checks,
Luau diagnostics and relevant persistent/multi-client Studio checks. Update only meaningful
product and system contracts, and report unverified platform-purchase cases explicitly.
```

## P07 — Design the central Robux store UI

```text
Design the central Robux store for Blindbox Town. Deliver a concrete visual design and developer
handoff; do not implement production purchases, change gameplay or create platform products.

Read AGENTS.md, docs/MONETIZATION.md and docs/MONETIZATION_TASK_PROMPTS.md (P01/P07),
docs/GAME_DESIGN.md, docs/ui-redesign/BRIEF.md and docs/ui-redesign/IMPLEMENTATION.md. Inspect
current UIStyle, UIKit, UIButton, ScreenShell, UILayout, NavigationConfig, Interface, ShopScreen,
UIState, OfflineEarnings and opening focus behavior. Use current source/screens as the actual
design reference; do not redesign the whole interface or assume old dock/layout notes are current.

Create one understandable place to buy every retained Robux product: 2x/4x/8x Coin tiers;
Small/Medium/Large/Huge Coin packs; Starter Pack; Auto Open; Auto Collect; movement upgrade;
VIP; timed Coin boosts; permanent Luck; timed Luck/combo boosts; 2x offline earnings.
Group them into a small number of clear categories, for example Upgrades, Coins, Boosts and
Starter/VIP. Recommend the entry point and relationship to the existing Coin box Shop: preserve
ordinary box browsing/Open 10 and make the difference between Coins and Robux immediately clear.
A stationary store interface is allowed; the removed rotating premium shop is not.

Match the cozy collectible-town style: warm white surfaces, plum outlines/hard shadows,
violet/gold/mint accents, existing Fredoka/Nunito typography and clear product illustrations/icons.
Use the existing UI components/tokens wherever practical. Product benefits, owned state and Robux
price should be legible at a glance; avoid an oversized grid of loud purchase buttons.
Do not invent final prices, product IDs, pack values or benefit promises. Use labelled fixture
data/TBD in mockups until P01 supplies them, and specify platform-sourced price fields for runtime.

Design product cards/details and category navigation, tier comparison and ownership, boost
duration/stacking explanation, Starter eligibility/claimed state, VIP benefit list, and a clear
explanation of the 2x offline bonus. If its purchase type is still unresolved, provide labelled
permanent-pass and per-return alternatives rather than silently choosing. For the per-return
variant, design a secondary action on the existing offline popup with base/bonus/total Coins,
while keeping the ordinary free Claim prominent and usable. For a permanent pass, show ownership
and the applied bonus. Show active boosts and Auto Open/Auto Collect controls/status where useful.

Specify every relevant state: loading price/ownership, available, owned, lower/superseded tier,
already claimed, ineligible/restricted, unavailable configuration/service, native purchase prompt,
cancelled, purchase awaiting verification, delayed fulfillment/recovery, confirmed grant,
failure and retry. Show Owned/granted only after the verified server state. Purchase is not the
same as boost activation or an automation toggle. Give restrictions useful plain-language copy.

Cover desktop and phone landscape, safe areas, short/narrow viewports, scrolling endpoints,
44px minimum touch targets, gamepad focus/Back, reduced motion, long labels and large/localized
prices. Do not add a portrait flow to a landscape game. Handle close/reopen, resize, native prompt
focus return and cinematic conflicts without obstructing Stop or free gameplay. Avoid forced
store popups, fake timers, misleading discounts and repeated pressure when a player lacks Coins.

Deliver desktop and narrow-phone layouts, a clickable prototype or equivalent annotated screen
flow with key error/pending/owned states, and a component/state/data handoff ready for P08.
Save the design brief under docs/ui-redesign/MONETIZATION_STORE.md, keeping any prototype assets
beside it. Treat fixtures as non-live previews. Validate the layouts visually and list unresolved
product decisions separately from design decisions. Keep all removed features out of the design.
```

## P08 — Implement the Robux store and connect product UI

```text
Implement the approved central Robux store design and connect the retained monetization products.
Read AGENTS.md, docs/MONETIZATION.md, docs/MONETIZATION_TASK_PROMPTS.md (P02–P08),
docs/ui-redesign/MONETIZATION_STORE.md, docs/ui-redesign/IMPLEMENTATION.md, docs/GAME_DESIGN.md,
docs/archive/MVP.md, docs/ROADMAP.md, docs/ARCHITECTURE.md and docs/DATA_MODEL.md. If the design or
product contract is absent, identify that dependency and prepare a concrete integration plan;
do not invent an approved design, product ID or benefit. Inspect current UI/input/router modules.

Build the approved store entry point, categories, product cards/details and state presentation
with the existing visual system and focused strict Luau components. Reuse existing layout,
scrolling, safe-area, input, sound, motion and cleanup conventions. Preserve the Coin box Shop,
free Open 10/Skip, Welcome guidance and ordinary free offline claim. Include every retained product
and exclude all removed ones; do not add a physical kiosk, world redesign or rotating-shop backend.

Use actual supported platform product/price metadata, including the user's applicable price when
the platform provides one. Distinguish Robux price from Coin reward. Loading or failed metadata
must not display an invented price, discount or ownership. Allow purchase initiation only for
configured, eligible products through P02's supported path and native platform confirmation.
Revalidate eligibility on the server. Never deduct/grant currency, set Luck, turn on unowned
features or mark a reward received from a client purchase-completion callback.

Follow the approved lifecycle: available -> native prompt -> verification/fulfillment pending ->
server-confirmed result, with cancellation, rejection, delay, recovery and unavailable states.
Prevent rapid duplicate prompt launches. Closing the UI cannot discard a paid fulfillment obligation.
Refresh ownership/eligibility/products when reopened or confirmed state changes. Keep context/focus
stable when returning from a native prompt. Long waits need truthful messaging and recovery controls,
not optimistic success or a suggestion to buy the same product again.

Wire the approved offline purchase model, automation controls, active boost timers, tier/ownership
states, VIP/Starter status and Luck/base/current odds presentation. Display useful product rules
without leaking internal architecture into player copy. Update timers at a bounded cadence only
where needed; hidden screens must not keep unnecessary loops or duplicate listeners.

Verify desktop/narrow-phone landscape, safe areas, resize, scrolling endpoints, real gamepad focus,
motion off, long labels/prices, absent/restricted products and native prompt return. Exercise
close/reopen, delayed grant, retry, reset, rejoin and opening-focus conflicts. Use labelled non-live
fixtures for presentation cases; distinguish them from real platform purchase tests. Run required
pinned checks, Luau diagnostics and relevant native Studio/persistent/multi-client checks.
Document the UI contract, evidence and remaining device/platform acceptance; do not publish.
```

## P09 — Monetization acceptance and release handoff

```text
Verify the implemented monetization lineup and Robux store end to end, fixing reproducible defects
within that scope. Read AGENTS.md, docs/MONETIZATION.md, docs/MONETIZATION_TASK_PROMPTS.md,
the approved product/UI specifications, docs/ROADMAP.md, docs/OPERATIONS.md,
docs/ARCHITECTURE.md, docs/DATA_MODEL.md, docs/ECONOMY.md and docs/AFK_RECONNECT.md. Check the
actual source/configuration and prior verification records; plans and fixtures are not proof.

Create a coverage matrix for every retained product and shared purchase state. Verify entitlement
refresh, native prompt cancellation/failure, delayed/replayed/concurrent receipt delivery,
durable grant/acknowledgement, disconnect/rejoin, lease conflict, failed saves, lost replies,
unknown products, restricted eligibility and disabled configuration. Use existing authorized
private test surfaces and isolated stores where available; do not charge accounts, modify live
products/stores, publish or enable live sales as part of this task.

Verify effects: exclusive Coin tier selection; qualifying sources; correct settlement before
modifier changes/expiry; normalized Luck and disclosed odds with pity/guarantees; boost timers
and repurchases; pack/Starter grant consistency; VIP day-boundary benefits; automation start/stop
and one-loop ownership; movement on spawn/respawn; 2x offline base/bonus/total, cap/minimum,
pending claim, chosen purchase model and AFK save-release handoff. Free/ordinary paths must retain
their approved behavior, including manual collection, Open 10, Skip and free offline Claim.

Test owner privacy and cross-owner rejection with two native clients, plus the store at desktop
and narrow-phone landscape sizes and on actual supported touch/gamepad inputs where available.
Inspect owned/loading/ineligible/pending/error states, scrolling, native prompt focus return,
Stop controls, cinematic conflicts, teardown and repeated store/opening sessions. Confirm excluded
features have not reappeared and no client can choose a price, grant, odds or entitlement.

Recheck applicable official platform requirements from P01 against the final money-to-reward
paths and actual gating/disclosures. Run required pinned formatter/lint/build checks, Luau
diagnostics and meaningful domain/persistence tests. Keep generated output out of version control.

Record Pass/Fail/Blocked/Not run/Not applicable with evidence and precise remaining work in a
dated monetization acceptance report under docs/audits/. Distinguish mocked/platform-sandbox
coverage from real purchase/service behavior and native device evidence. Produce a concrete
release handoff with configuration prerequisites and rollback/recovery considerations; no
publication or live-sales activation. Do not claim launch readiness while required gates are open.
```
