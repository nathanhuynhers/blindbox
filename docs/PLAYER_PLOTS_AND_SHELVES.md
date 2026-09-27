# Player Plots, Display and Shelves

**Canonical current direction — September 27, 2026.** This replaces the abandoned Showroom/Gallery
architecture. The functional placeholder is implemented; native Studio acceptance is pending.
See [implementation and checks](PLOT_SHELF_IMPLEMENTATION.md), [schema](DATA_MODEL.md),
[architecture](ARCHITECTURE.md) and [economy](ECONOMY.md).

## Player Plot

Each server has a fixed configured set of 24 plot locations. Joining players reserve an available
slot before profile loading; failed/disconnected joins release it. Loaded players receive one
large open 100-by-96-stud plot, identified by `Player.DisplayName`. On departure, owned runtime
content/connections are destroyed and the slot becomes available for another player. Assignment
and world coordinates are never saved. The experience player cap must match the configured limit.

The shared world has flat neutral ground and 20-stud gaps between plots. Players walk directly
onto other players' plots: no permission prompt, browser, visit session or teleport is needed.
There are no plot perimeter walls or separate interior spaces. Initial layout leaves open
circulation space and unused corners/edges for future systems.

## Display

Display is the **only** Coin-generating collectible placement system. It starts with 3 unlocked
slots and currently supports at most 6. Only unlocked positions have physical pads, labels or
figure anchors; locked positions have no world geometry. The visible row stays centered along
the back of the plot as capacity grows. Its existing stand widens and retained figures move
with their logical slots without rebuilding the plot. Locked slots remain visible in the UI.

Relative to plot origin, the Display is centered at X=0, Z=36, with figure anchors at Y=5 and
12-stud spacing. Capacities 3/4/5/6 have stand widths 38/50/62/74 studs; the stand is 3 studs
high and 12 deep. The entrance remains at negative Z, facing toward the back along positive Z.

Each Display position reserves one owned inventory copy. Placement, replacement and removal stay
server-authoritative. Income remains the sum of base figure rates plus the existing single
themed bonus: +1 Coin/sec for three distinct Display figures from one collection. Inventory-only
and shelf figures contribute zero. Rarity rates, odds, acquisition costs and daily rewards remain
unchanged. The legacy fourth-slot unlock still costs 4,000 Coins. Slots 5/6 have no acquisition
method or invented price; future methods remain independently configurable.

## Shelves and shelf pages

Every plot has **three physical shelf units**, each with **three horizontal rows** and currently
**three figure positions per row**: 27 visible cosmetic positions. `ShelfConfig` owns these
provisional counts. Shelf visuals are simple generic boards/supports with no customization UI.
They form one installation on the left **when looking in from the entrance**: X=40, unit centers
at Z=-28/-4/20, with figure fronts facing inward along negative X. Center/right space stays open.

Every fresh profile owns one shelf page. A page stores a complete placement configuration for
the same three physical units. More pages are supported with no permanent page-count cap. There
is no acquisition endpoint, purchase UI, product or pricing curve yet. Configuration and the
ordered page data model are the extension points for a later acquisition system. Legacy migration
may create additional pages solely to retain saved figure references.

Large Previous/Next controls above the shelf installation accept desktop clicks and mobile taps
through ClickDetectors on generous transparent, non-colliding hitboxes. No ProximityPrompt or E
key is required. Owners and visitors can operate them from across the plot. Detector reach is
160 studs, with an independent server check requiring a living actor inside the plot footprint
plus an 8-stud perimeter margin and within 20 vertical studs of its origin. Other plots cannot
be controlled from across the map. The server binds each control to its active plot and direction.

Page changes remain shared, runtime-only, start on page 1 each join and wrap at both ends. They
use the existing per-plot 0.5-second cooldown and change no saved state. Single-page controls
remain visible but do nothing. The page indicator belongs to the shelf installation. Owner UI
navigation/editing remains close-range: inside the own plot and within 16 studs of the shelf
plane. Expanding physical navigation range does not expand editing range.

Pages use stable IDs such as `page:1`; placements use logical keys such as
`unit:2/row:3/slot:1`. Moving or reskinning geometry never changes these keys. Increasing geometry
capacity exposes additional keys without migration. If a future layout is smaller, saved keys
outside the current visible layout remain stored and are not silently deleted or remapped.

## Cosmetic eligibility and permissions

Shelves reference **permanently discovered** figure IDs. They consume/reserve zero physical copies,
produce zero Coins, and never count toward Display bonuses or daily Display goals. Repeated shelf
figures and simultaneous Display/shelf use are allowed. Discovery remains usable even when no
physical inventory copy remains. Recycling rules are unchanged.

Only owners can place, replace or remove their shelf figures. Server callback identity resolves
the profile and plot; no submitted owner ID or plot index is accepted. Requests require an owned
page, configured visible slot, known discovered figure, profile revision, current visible-page ID
and carousel revision, plus a living character near their own shelves. Changing pages away and
back invalidates old edits. Existing request receipts and rate limits protect retries.

Visitors can walk, look and turn the shared carousel. They cannot edit Display/shelves, unlock
slots, buy pages or change another player's progression. Rendered figures and owner/page signage
are public. Owner snapshots go only to that owner and project one shelf page; inventories, balances,
discoveries and other progression are never sent to visitors to render a plot.

## Completion and customization

Collection completion remains derived from permanent discoveries and visible in the Collection
Book/Goals. **Collection-completion rewards are TBD.** Completing a collection does not unlock a
room, shelf page, skin, currency, trophy, plaque or title. Legacy world completion plaques were
derived presentation, not stored grants; they are retired with the old plot geometry.

Each page has an empty `customization` map for a future versioned extension. No customization
catalog, ownership, purchase, skin editor, furniture or arbitrary property API exists. Potential
future shelf skins, materials, colors, backgrounds, lighting, trim, decorations, effects and
collection styling need separate definitions and authorization.

## Scope and placeholder structure

```text
Open plot — owner name at front; no enclosing walls

                    BACK
           Display [1] [2] [3]
       (only unlocked slots; stays centered)

   [ Shelf C ]  Next >
   [ Shelf B ]  Page 1 / N       open center/right
   [ Shelf A ]  < Previous      walking / future space
   3 x 3 each; faces inward

                    Owner's Plot
                  shared walkway
```

The plot, stand, shelves, arrow signs, owner sign and Shelf UI are placeholders awaiting final
mockups. Pocket Grove remains a collection, not a core world API/theme dependency. No themed
forest environment, Game Pass kiosk, shelf pricing, final art, extra Display capacity, likes,
ratings, trading, cross-server travel or free placement is part of this implementation.
