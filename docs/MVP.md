# Historical MVP scope

Status: user playtested and accepted the MVP, reporting collection scroll truncation.
The new candidate fixes scrolling and expands beyond this historical scope; see [full-game scope](FULL_GAME.md).
The acceptance criteria below document the original MVP, not the current larger feature set.
Its use of "showroom" means the passive-income **Display** in current terminology, not the later
non-economic Showrooms defined in [Display and Showrooms](DISPLAY_AND_SHOWROOMS.md).
See [the verification and playtest checklist](STUDIO_TESTS.md).
[Game design](GAME_DESIGN.md) describes the vision; this document limits scope.
Milestone 1 in [the roadmap](ROADMAP.md) is the entire MVP, delivered in small playable steps.

## What ships in the prototype

| Area | Minimum behavior |
| --- | --- |
| Content | One original six-figure collection, three configurable tiers, one box |
| Opening | Server resolves purchase and grant together; short skippable reveal |
| Inventory/index | One combined panel: counts, discovered entries, silhouettes, completion stamp |
| Display | One simple personal main-plot Display per player; one shelf with three fixed slots; place/replace/remove |
| Display rates | Rarity-based per-figure rates, small within-tier differences; sum occupied slots; no diversity/set bonus |
| Income | Server credits Coins automatically while in-game; no counter, bank, or offline income |
| Visitors | At most two local decorative visitors for the owner's room; fixed waypoints, no effect on income |
| Duplicates | Recycle one extra undisplayed copy for Scrap; redeem six Scrap for a selected figure |
| Onboarding | 450 Coins once per session initialization; a short open/place/earn/buy prompt sequence |
| Isolation | Two simultaneous players have independent inventories, slots, and balances |
| Feedback | Clear insufficient-funds, invalid-action, inventory-full, and new-discovery feedback |

The initial 450 Coins buys three 150-Coin boxes. No starter figure or tutorial reward is also
granted. A player may place after the first opening or open all three first. If all results are
duplicates, displaying the three copies still funds more boxes. Never require an empty-handed
player to earn income before their first box.

Recycling/redemption is the one extra loop retained deliberately: without it the prototype
cannot test useful duplicates or a deterministic route past unlucky rolls. Avoid an additional
crafting screen; put these actions in the combined inventory/index panel.

## Explicit exclusions

No saving/loading, cross-session rewards, Display expansion, Showrooms, free placement, furniture shop,
multiple collections, variants, upgraded figures, unowned box inventory, full-set income bonuses,
visitor preferences, pathfinding, offline earnings, quests, daily rewards, streaks, seasons,
trading, visits browser, likes, leaderboards, monetization, analytics service, or dependencies.
Use temporary original geometry and simple UI, not a production asset pipeline. Physical room
coexistence in a multiplayer test is not a social feature. Prototype state resets on leaving;
label that clearly. It is not ready for public progression testing.

## Acceptance criteria

1. In a fresh session, open a box in under 30 seconds and display the result in under 60 seconds
   without developer instructions. These are usability targets, not guaranteed timings.
2. Complete open -> own -> display -> observe automatic income -> buy again within
   three minutes. Reveal dismissal and client reconnection to the UI cannot grant extra items.
3. A purchase deducts exactly 150 Coins and grants exactly one figure or changes nothing.
   A failed purchase never consumes currency. Client-supplied outcomes/prices are rejected.
4. Inventory counts, discovery, placement reservations, and balances remain consistent across
   place/replace/remove/recycle/redeem operations. A copy cannot occupy two slots.
5. Each higher-tier figure earns more than every lower-tier figure. Three copies of the rare
   figure earn 21 Coins/second; the three distinct commons earn 4.5. Inventory-only copies earn
   nothing. Figure and total rates are visible. See [the canonical formula](ECONOMY.md).
6. Elapsed-time income credits whole Coins automatically and retains fractional earnings.
   Display edits settle the old rate first; idle play keeps earning. Leaving/rejoining grants
   no offline rewards. The session reset is expected in this build.
7. Recycling cannot consume the last owned copy or a reserved copy. Six valid recycles fund
   one chosen figure. Redemption updates discovery and cannot produce negative Scrap.
8. Hidden/stalled visitor visuals do not alter income. Room objects, tasks, and connections
   are cleaned up when their owner leaves. There is no unbounded visitor spawning.
9. In a two-client Studio test, neither player can spend, place, or recycle for the
   other. Malformed, stale, repeated, and spammed requests do not corrupt state or crash handlers.
10. All six discoveries produce an index stamp; tests can seed state to verify this without
    waiting for favorable random results. Production clients cannot invoke test grants.

## What we need to learn

Observe a small initial group (for example five testers) without coaching. Record approximate
time to first display and second funded purchase, boxes opened, duplicate responses, chosen
display changes, and reasons for stopping. Hand notes are sufficient; do not add telemetry
infrastructure to this milestone.

Proceed only if most testers can explain the loop, understand displayed figures as the source of income,
and voluntarily want another figure or a better arrangement. Investigate when two or more
testers need coaching or report that passive waiting dominates play. This is directional
qualitative evidence, not statistical validation. Revisit the reveal and upgrade pacing before expanding the feature list. Use forced duplicate
and common-only scenarios to separate enjoyment from lucky outcomes.
