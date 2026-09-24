# Full-game candidate economy

These are tuning values for the user-authorized full-game candidate, not validated long-term
balance. Income remains automatic and server-owned; visitors are decorative. No paid currency,
offline income, trading or escalating multipliers are implemented.

| Parameter | Value |
| --- | --- |
| New profile | 450 Coins once; unsaved Studio preview recreates this on join |
| Boxes | Pocket Grove or Tidepool Tales; 150 Coins per figure |
| Content | Two fixed six-figure collections, each with 3 Commons, 2 Uncommons, 1 Rare |
| Per-figure odds | Each Common 20%, each Uncommon 15%, Rare 10%, within selected collection |
| Grove rates | 1, 1.5, 2, 3, 4, 7 Coins/sec |
| Tide rates | 1.25, 1.75, 2, 3.25, 4, 7.5 Coins/sec |
| Rate bands | Common 1-2, Uncommon 3-4, Rare 6-8; validated at startup |
| Display capacity | Starts at 3; one fourth-slot unlock costs 4,000 Coins |
| Themed display | +1 Coin/sec once when at least 3 distinct displayed IDs share a collection |
| Palettes | Woodland free; Evening Lilac and Ocean Glass cost 1,200 Coins each, then equip freely |
| Duplicates | Recycle one extra undisplayed copy for 1 Scrap; keep at least one owned copy |
| Targeted redemption | 6 Scrap for any chosen figure from either collection |
| Daily box | One free choice of collection per UTC day, no streak |
| Daily goal | Display 3 distinct figures simultaneously; claim 100 Coins once per UTC day |
| Completion | Permanent index recognition and derived room plaque for each completed collection |
| Bounds | 200 total copies; 1 billion Coins; 1 million Scrap |

`rate = sum(baseCoinsPerSecond for each occupied slot) + eligibleThemedBonus`

Only displayed copies earn, including repeats. Inventory-only figures do not. Three weakest
Common copies earn 3/sec, three distinct Grove Commons earn 5.5/sec including the bonus,
three Grove Rares earn 21/sec, and four Tide Rares earn 30/sec. The small set bonus does not
make a Common-only shelf outperform a Rare-heavy shelf. No multiplicative bonuses or rate cap.

Each server settlement uses elapsed time and retains fractions. Settle at the previous rate
before editing a display. Credit whole Coins directly. At the numeric safety ceiling, stop and
discard excess/fractional earnings; spending resumes from current time without hidden credit.
The ceiling is a numeric guard, not a normal pacing target. Idle online players keep earning.

Daily eligibility uses server UTC day indices. Last claimed day never moves backwards; choosing
a different collection or reconnecting cannot repeat the same day. Full inventory leaves the
free-box claim available. Goal progress is capped and reset on a new UTC day; a qualifying
existing display satisfies it immediately. A failed reward action changes neither claim nor
balance. Save markers and rewards live in the same profile aggregate.

A new player can open three funded boxes plus the optional daily free box. Even three weakest
Commons fund an earned box in 50 seconds once displayed. Fourth-slot and palette costs provide
bounded sinks, not endlessly compounding expansion. Test 10/30-minute sessions and returning
sessions for content exhaustion, value of both collections, idle dominance and stockpiling.
Current content is twelve figures; do not disguise that limit with artificial grind.

Prices, rates, box weights, safety bounds and rewards belong to server Economy. Clients receive
sanitized previews; they never calculate grants or authorize purchases. See [operations](OPERATIONS.md)
for saving guarantees, private testing and pending balance observations.
