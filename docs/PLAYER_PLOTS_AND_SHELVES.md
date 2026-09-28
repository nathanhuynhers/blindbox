# Player Plots, Display and Shelves

**Canonical current direction — September 27, 2026.** This replaces the abandoned Showroom/Gallery
architecture. Display and Collection implement the supplied fixture concepts; native Studio acceptance is pending.
See [implementation and checks](PLOT_SHELF_IMPLEMENTATION.md), [schema](DATA_MODEL.md),
[architecture](ARCHITECTURE.md) and [economy](ECONOMY.md).

## Player Plot

Each server has eight fixed plot locations at 45-degree intervals on a 170-stud-radius ring.
Joining players reserve an available slot before profile loading; failed/disconnected joins
release it. Loaded players receive one large open 100-by-96-stud plot, identified by
`Player.DisplayName`. On departure, owned runtime content/connections are destroyed and the slot
becomes available for another player. Assignment, world transforms and carousel position are
never saved. The experience player cap must match the configured eight-plot limit.

The shared world is one 100-stud-diameter circular ivory plaza and eight direct 16-stud-wide
paths. Each path has two narrow pale-oak edge strips and two pairs of small warm-light bollards,
and runs from beneath the plaza perimeter to beneath one centered plot entrance. Paths and plot
walking surfaces meet at Y=1; the plaza trim/surface sit only 0.01/0.03 studs above that plane to
prevent coplanar rendering artifacts without creating a traversal obstacle. A visible circular
warm-neutral foundation is recessed 1.75 studs beneath the walking plane; there is no rectangular
baseplate. Each plot's local `-Z` entrance faces the plaza and local `+Z` rear Display faces
outward. A single `CFrame` placement rotates the platform, floor details, entrance, Display,
Collection, figure anchors and interaction hitboxes together.

Each logical plot is a gently raised showroom platform: a rounded warm-white base, inset pale-oak
perimeter trim, quiet pale WoodPlanks walking surface and four thin warm-colored inner-edge
accents. The accent uses noncolliding SmoothPlastic rather than Neon or per-plot lights. Players
walk directly onto other players' plots: no permission prompt, browser, visit session or teleport
is needed. There are no perimeter walls, rails or separate interior spaces.

The front-center entrance uses a shallow 22-by-4.2-stud oak deck and understated framed physical
plaque reading `<DisplayName>'s Showroom`. The cream SurfaceGui face uses charcoal text and small
warm-colored cap pieces; it is not a floating billboard and uses no actual light. Entrance pieces
remain inside the front edge. No props sit beside the left Collection or rear Display, preserving
their horizontal expansion zones and the large open center/right area for circulation and future
systems. `PlotFixture` centralizes all platform/entrance dimensions, colors and materials.

## Display

Display is the **only** Coin-generating collectible placement system. It starts with 3 unlocked
slots and currently supports at most 6. The concept-board fixture uses one continuous off-white
counter, pale oak base band, recessed charcoal plinth, broad warm back panel, simple end supports
and an integrated framed sign. All geometry is native Roblox Parts. A recessed, non-neon diffuser
provides one subtle downward warm light. There are no individual pads, cubbies, floating slot
labels or physical representations of locked slots. Locked slots remain visible in the UI.

`DisplayFixture` builds and resizes the same pieces for capacities 3/4/5/6, with counter widths
28/36/44/52 studs. Counter depth is 8.5 studs; its top and figure anchors are Y=3 above plot origin,
at 8-stud spacing. The structure stays centered at X=0, Z=36. Base, counter, back and canopy widen;
end supports move out and the sign stays centered. Logical figure slots and existing models are
retained. Display-only figures use 2x presentation scale and bounding-box bottom alignment so
they stand on the counter. Shelf figures are unaffected.

The physical SurfaceGui sign reads **DISPLAY** and the server-computed total rate, e.g.
**2 Coins/sec** when the Display earns 2. The reference number is not a hard-coded income promise.
The separate client floating Display-rate badge has been removed; Display controls still show
individual/total rates. The entrance remains at negative Z, facing toward the back along positive Z.

Each Display position reserves one owned inventory copy. Placement, replacement and removal stay
server-authoritative. Income remains the sum of base figure rates plus the existing single
themed bonus: +1 Coin/sec for three distinct Display figures from one collection. Inventory-only
and shelf figures contribute zero. Rarity rates, odds, acquisition costs and daily rewards remain
unchanged. The legacy fourth-slot unlock still costs 4,000 Coins. Slots 5/6 have no acquisition
method or invented price; future methods remain independently configurable.

## Shelf Units and the three-shelf viewport

Every plot has **three physical shelf units**, each with **three horizontal rows** and currently
**three figure positions per row**: 27 visible cosmetic positions. `ShelfConfig` owns these
provisional counts. **Collection** is the physical presentation name: three adjoining oak-framed
bays, ivory boards, recessed warm back panels, charcoal plinths and a continuous ivory canopy.
One integrated physical SurfaceGui header says only **COLLECTION**. Each row has a short, subtle
downward warm light. No customization UI is implemented.

The installation remains on the left **when looking in from the entrance**: X=40, bay centers
at Z=-16/-4/8, with figure fronts facing inward along negative X. Local anchors use 3.6-stud
horizontal spacing, board tops Y=10/5.8/1.6, and the existing figure scale of 1 with bottom
alignment to the boards. Center/right space stays open. `CollectionFixture` owns construction;
the plot, Display, persistent identities and carousel domain are unchanged.

Every fresh profile owns exactly **three persistent Shelf Units**, each with nine cosmetic
positions and its own placements/customization. The three physical structures are presentation
positions; they render a sliding viewport over the ordered owned units. Future acquisition adds
one Shelf Unit, currently nine positions, without widening the plot or adding furniture.
Acquisition policy is unassigned: no endpoint, purchase UI, product, price or curve exists.
There is no product-design maximum. Server decoder resource guards are documented in
[the data model](DATA_MODEL.md); they are not a progression cap.

Integrated oak/ivory side wings carry large solid left/right chevrons without text labels.
These accept desktop clicks and mobile taps through ClickDetectors on generous transparent,
non-colliding 5-by-10-by-7-stud hitboxes. No ProximityPrompt or E
key is required. Owners and visitors can operate them from across the plot. Detector reach is
160 studs, with an independent server check requiring a living actor inside the plot footprint
plus an 8-stud perimeter margin and within 20 vertical studs of its origin. Other plots cannot
be controlled from across the map. The server binds each control to its active plot and direction.

The carousel is shared and runtime-only. It starts with units 1,2,3 each join. Next/Previous
shift **exactly one unit** with wrapping and the existing per-plot 0.5-second cooldown; browsing
changes no saved state. With at most three owned units, order remains 1,2,3 and navigation is
disabled in the editor and world; physical chevrons/trim become muted oak-gray. Detailed visible
indexes and owned count remain in the owner editor/runtime view, never the physical header.

| Owned units | Successive Next viewports |
| --- | --- |
| 4 | 1,2,3 → 2,3,4 → 3,4,1 → 4,1,2 → 1,2,3 |
| 5 | 1,2,3 → 2,3,4 → 3,4,5 → 4,5,1 → 5,1,2 → 1,2,3 |

Previous reverses these sequences. Owner UI
navigation/editing remains close-range: inside the own plot and within 16 studs of the shelf
plane. Expanding physical navigation range does not expand editing range.

Shelf Units use stable IDs such as `shelf:1`; placements use local keys such as
`row:3/slot:1`. The unit ID owns the contents regardless of physical viewport position.
Moving or reskinning geometry never changes these keys. Increasing geometry
capacity exposes additional keys without migration. If a future layout is smaller, saved keys
outside the current visible layout remain stored and are not silently deleted or remapped.

## Cosmetic eligibility and permissions

Shelves reference **permanently discovered** figure IDs. They consume/reserve zero physical copies,
produce zero Coins, and never count toward Display bonuses or daily Display goals. Repeated shelf
figures and simultaneous Display/shelf use are allowed. Discovery remains usable even when no
physical inventory copy remains. Recycling rules are unchanged.

Only owners can place, replace or remove their shelf figures. Server callback identity resolves
the profile and plot; no submitted owner ID or plot index is accepted. Requests require an owned
Shelf Unit ID that is currently visible, configured local slot, known discovered figure, profile
revision and carousel revision, plus a living character near their own shelves. Turning the
carousel away and back invalidates old edits. Existing request receipts and rate limits protect retries.

Visitors can walk, look and turn the shared carousel. They cannot edit Display/shelves, unlock
slots, acquire shelves or change another player's progression. Rendered figures and owner/carousel
signage are public. The Collection header stays constant during browsing. Owner snapshots go
only to that owner and project only the three visible
units, owned count and navigation availability; inventories, balances, discoveries and other
progression are never sent to visitors to render a plot.

## Completion and customization

Collection completion remains derived from permanent discoveries and visible in the Collection
Book/Goals. **Collection-completion rewards are TBD.** Completing a collection does not unlock a
room, Shelf Unit, skin, currency, trophy, plaque or title. Legacy world completion plaques were
derived presentation, not stored grants; they are retired with the old plot geometry.

Each persistent Shelf Unit has an empty `customization` map for a future versioned extension. No customization
catalog, ownership, purchase, skin editor, furniture or arbitrary property API exists. Potential
future shelf skins, materials, colors, backgrounds, lighting, trim, decorations, effects and
collection styling need separate definitions and authorization.

## Scope and placeholder structure

```text
Open plot — owner name at front; no enclosing walls

                    BACK
           Display [1] [2] [3]
       (only unlocked slots; stays centered)

   [ COLLECTION ]
   > [ Shelf C ]
     [ Shelf B ]              open center/right
   < [ Shelf A ]             walking / future space
   3 x 3 each; faces inward; arrows at installation ends

                    Owner's Plot
                  shared walkway
```

Display and Collection now follow the supplied collectible-store fixture concepts, pending
native visual acceptance. Shared ground, existing figure art and Shelf editor remain provisional;
the layered plot platform and Showroom entrance now follow the supplied floor concept. Pocket Grove
remains a collection, not a core world API/theme dependency. No themed
forest environment, Game Pass kiosk, shelf pricing, final art, extra Display capacity, likes,
ratings, trading, cross-server travel or free placement is part of this implementation.
