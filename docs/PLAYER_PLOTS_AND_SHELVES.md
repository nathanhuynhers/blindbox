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
slots and currently supports at most 6. Slots form one horizontal row; unlocking capacity extends
the same stand to the right without rebuilding the plot. Locked future positions have subdued
markers and cannot accept figures. This replaces the former two-row layout.

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

Every fresh profile owns one shelf page. A page stores a complete placement configuration for
the same three physical units. More pages are supported with no permanent page-count cap. There
is no acquisition endpoint, purchase UI, product or pricing curve yet. Configuration and the
ordered page data model are the extension points for a later acquisition system. Legacy migration
may create additional pages solely to retain saved figure references.

Physical Previous/Next arrow prompts switch the page visible to everyone at that plot, wrapping
at either end. Nearby owners and visitors may turn the shared exhibit. Navigation is runtime-only
and starts on page 1 each join. It grants no ownership, mutates no saved profile, and is rate-limited
per plot. An owner can also use page controls in their Shelf UI while near their shelves.

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

       [ Shelf A ] [ Shelf B ] [ Shelf C ]
       3 x 3       3 x 3       3 x 3
   < Previous       Page 1 / N          Next >

             open walking / future space

       Display [1][2][3] -> [4] -> [5] -> [6]

                    Owner's Plot
                  shared walkway
```

The plot, stand, shelves, arrow signs, owner sign and Shelf UI are placeholders awaiting final
mockups. Pocket Grove remains a collection, not a core world API/theme dependency. No themed
forest environment, Game Pass kiosk, shelf pricing, final art, extra Display capacity, likes,
ratings, trading, cross-server travel or free placement is part of this implementation.
