# Full-game candidate economy

These are tuning values for the user-authorized full-game candidate, not validated long-term
balance. Income remains automatic and server-owned; visitors cannot affect payouts. No paid currency,
offline income, trading or escalating multipliers are implemented.

Supported tiers are Common < Uncommon < Rare < Legendary < Mythical. Live content and odds
below remain unchanged. Weights belong to individual server economy entries, not rarity tiers;
no Legendary/Mythical weights or rates are synthesized. Future figures require explicit approved
values. Startup enforces positive finite rates/weights, existing Common/Uncommon/Rare bands and
strictly increasing rates across all populated tiers. See [rarity architecture](RARITY.md).

| Parameter | Value |
| --- | --- |
| New profile | 450 Coins once; unsaved Studio preview recreates this on join |
| Boxes | Pocket Grove, Tidepool Tales, Concepts or Tender Echoes; 150 Coins per figure |
| Content | Two fixed six-figure collections, each with 3 Commons, 2 Uncommons, 1 Rare; Concepts has one figure per tier (Common to Mythical); Tender Echoes has 4 Commons, 3 Uncommons, 3 Rares, 2 Legendaries, 1 Mythical |
| Per-figure odds | Grove/Tide: each Common 20%, each Uncommon 15%, Rare 10%; Concepts weights 20/15/10/8/3 of 56 (35.7%, 26.8%, 17.9%, 14.3%, 5.4%); Tender Echoes weights 20 each Common, 15 each Uncommon, 10 each Rare, 8 each Legendary, 2 Mythical of 173 (11.6%, 8.7%, 5.8%, 4.6%, 1.2% per figure), within selected collection |
| Grove rates | 1, 1.5, 2, 3, 4, 7 Coins/sec |
| Tide rates | 1.25, 1.75, 2, 3.25, 4, 7.5 Coins/sec |
| Concepts rates | 1, 3, 7, 12, 18 Coins/sec (Verity, Falsity, Cruelty, Lovity, Verity True Form) |
| Tender Echoes rates | Commons 1, 1.2, 1.4, 1.6; Uncommons 3, 3.5, 4; Rares 6, 7, 8; Legendaries 12, 14; Mythical 20 Coins/sec |
| Rate bands | Common 1-2, Uncommon 3-4, Rare 6-8; validated at startup |
| Display capacity | Starts at 3; supports 6; legacy fourth-slot unlock costs 4,000 Coins |
| Themed display | +1 Coin/sec once when at least 3 distinct displayed IDs share a collection |
| Shelf Units | Three starting units, nine cosmetic positions each; future expansion adds one unit; no price/curve or product-design maximum |
| Duplicates | Recycle one extra undisplayed copy for 1 Scrap; keep at least one owned copy |
| Targeted redemption | 6 Scrap for any chosen figure from any collection |
| Daily box | One free choice of collection per UTC day, no streak |
| Daily goal | Display 3 distinct figures simultaneously; claim 100 Coins once per UTC day |
| Completion | Permanent discovery/index tracking; rewards TBD, no room or Shelf Unit grant |
| Bounds | 200 total copies; 1 billion Coins; 1 million Scrap |

Display currently supports six positions in one horizontal row. Slot 5/6 acquisition methods
remain unresolved; the retained 4,000-Coin fourth slot is not a price for slots 5/6.
Shelves are cosmetic permanent-discovery references. They earn zero Coins, reserve zero copies
and never count toward themed Display bonuses or daily Display goals. Individual Shelf Unit pricing and
customization are unimplemented. The retired room palettes have no equivalent in the new system;
schema 5 validates old palette state before discarding it, while retaining all unrelated economic
progress and converting saved cosmetic figures. See [migration](DATA_MODEL.md).

`rate = sum(baseCoinsPerSecond for each occupied slot) + eligibleThemedBonus`

Only displayed copies earn, including repeats. Inventory-only figures do not. Three weakest
Common copies earn 3/sec, three distinct Grove Commons earn 5.5/sec including the bonus,
three Grove Rares earn 21/sec, and four Tide Rares earn 30/sec. The small set bonus does not
make a Common-only Display outperform a Rare-heavy Display. No multiplicative bonuses or rate cap.

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
Commons fund an earned box in 50 seconds once displayed. The legacy fourth-slot cost remains a bounded sink. Individual Shelf Unit acquisition is deferred. Test 10/30-minute sessions and returning
sessions for content exhaustion, value of both collections, idle dominance and stockpiling.
Current content is thirty figures; do not disguise that limit with artificial grind.

Prices, rates, box weights, safety bounds and rewards belong to server Economy. Clients receive
sanitized previews; they never calculate grants or authorize purchases. See [operations](OPERATIONS.md)
for saving guarantees, private testing and pending balance observations.
