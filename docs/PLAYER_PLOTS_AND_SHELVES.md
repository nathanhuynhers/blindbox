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

### Blindbox Town (shared world)

The shared world is **Blindbox Town**, a cozy blind-box shopping town built from native Parts
(no stores, townhouses, shop buildings or box machines). `World`, `PlazaFixture`, `TownProps`,
`TownLayout` and `TownStyle` build it once per server; one plot-local `CFrame` still places each plot.

- **Ground:** a grass island (top Y=0.5, radius 276) with a stone curb edge and soil skirt.
  Plot platforms rest on the grass; paths, plaza and street fill down to it.
- **Plaza (radius 50):** paved surface, oak-stone trim and an inlay ring. In the center is the
  giant blind-box landmark: a pastel pink 18-by-16-by-18 box with "?" on all four sides on a round
  wooden base, its ribboned, bowed lid hinged at the back, tipped 24 degrees open and lifted, with
  a soft inner glow and four neon sparkles. Three benches, four planters and the leaderboard sit
  at radius 44-45 in the gaps between path mouths; tests assert that every plaza prop stays
  outside every path's walking corridor. A flush neutral `SpawnLocation` (no force field) sits on
  open paving beside the leaderboard for players who do not have a plot yet.
- **Paths:** eight 16-stud paths from the plaza to each plot entrance, 0.01 studs below the plot
  floor so their overlap never z-fights, each with oak edge strips and four bollards (at radius 62
  and 116, clear of the street).
- **Market Street:** a 14-stud cobbled ring centered at radius 99 over a 16-stud stone curb ring,
  crossing all eight paths. Two lanterns stand in each gap between paths, one on each side of the
  street (radius 88.5 and 109.5).
- **Between plots:** each gap has a tree near the street, a flower bed, two framing trees and,
  alternating, a giant gift-box stack (three oversized ribboned pastel boxes plus one tumbled box)
  or a statue garden: a marble statue of Peeka, the town's original mascot, on a ribbon pedestal
  ringed by pastel blooms, with an uplight that turns on at dusk.
- **Edge:** a small gift-box stack behind every plot, a 24-tree line, a continuous 48-segment
  hedge ring (radius 264) and 32 invisible, 60-stud-tall boundary walls just behind it.

Budgets: at most 1,100 static world parts (1,021 native parts at start, including the eight
platforms, petal carpets and statue gardens) and 64 dusk-to-dawn lights (53 static plus one arch
glow per active plot, 61 at eight players). Once the uploaded models load, the world holds about
1,190 parts, most of them MeshParts.

### Trees and statues (uploaded models)

Trees and statues are sculpted in Blender with the figure pipeline (`assets/models/town-trees`,
`assets/models/peeka-statues`) and uploaded as Models. Each spot is first built from native
parts; `TownModels` loads the uploaded models on the server and `TownPlacements` swaps every
placeholder for a scaled, turned copy. A failed load keeps the part version.

| Model | Where | Size | Triangles |
| --- | --- | --- | --- |
| Sakura (bonsai style, blossom clusters, coral flecks) | all 26 pink trees | canopy width 1.25x the placeholder (2.5x by the street, about 2.25x on the outer line; the root mound is half sunk into the grass) | about 51k |
| Puffball | 12 green trees by the street and framing gardens | height 1.5x | about 22k |
| Poplar | 12 green trees on the outer line | height 1.5x | about 15k |
| Topiary Ball | 2 green plaza planters | height 6 studs | about 13k |
| Peeka statues: Peekaboo (mint), Ta-da! (sky), Big Hug (lilac), Nap Time (butter) | the 4 statue gardens | pedestal 12 studs across | 62k-75k each |

Every tree gets its own deterministic turn and a size within 10%. Sakura outside the plaza
stand on a pink petal carpet, and the 8 sakura framing the gardens drop drifting petals (one
uploaded petal texture). Green trees and canopies never collide; trunks, stems and statues do.

### Day and night

`DayNight` advances `Lighting.ClockTime` on the server once per second over a 20-minute cycle:
9 minutes of day, 3 of golden hour into dusk, 5 of night and 3 of dawn. Ambient, outdoor
ambient, brightness, sun tint and an owned `Atmosphere` interpolate between day, golden-hour,
dusk, night and dawn looks. At dusk (17.8, as the default sky sets) and dawn (6.2) `NightLights` switches every registered
lantern, bollard, giant-box and arch light and swaps lens parts to Neon or back. Switching only
happens when that state changes; nothing runs per frame.

### Plot platforms and entrances

Each plot's local `-Z` entrance faces the plaza and local `+Z` rear Display faces outward.
Each logical plot is a gently raised showroom platform: a rounded warm-white base, inset pale-oak
perimeter trim, quiet pale WoodPlanks walking surface and four thin inner-edge accents in the plot
accent color. Static potted plants flank every entrance outside the arch posts. Players walk
directly onto other players' plots: no permission prompt, browser, visit session or teleport is
needed. There are no perimeter walls, rails or separate interior spaces.

**One accent color.** Every plot uses pastel pink `#F08FB0`, stored once as
`PlotStyle.DefaultAccent` and always read through `PlotStyle.accent(ownerId)`. A future
per-player customization system can override that accessor per plot; no customization exists.

An active plot adds a **walk-through entrance arch**: two oak posts at local X=+-11.2 (outside the
16-stud path), a pink accent beam, two lamp lenses and an oak-framed sign reading
`<DisplayName>'s Showroom` on both faces. The sign's underside is 9.5 studs above the walking
surface; the only thing in the doorway is a flush 0.12-stud oak deck. It also adds a flush,
noncolliding three-ring **spawn pad** on the open right floor (local X=-18, Z=-28) and striped
**awnings**: one above the Display sign that resizes with Display capacity, and one above the
Shelves header. Neither awning enters the horizontal expansion zones or the open center/right.
An active plot uses at most 150 runtime parts (140 at six Display slots).

### Spawning

Players spawn on **their own plot**. When a profile loads and a plot is assigned, `PlayerSpawn`
moves the current character and every later respawn or character reload to that plot's spawn pad,
facing into the plot. The target is a server-computed `CFrame`; no client position is trusted.
Before assignment (or if loading fails and the player is kicked), Roblox spawns the character on
the plaza `SpawnLocation`. Leaving unbinds the spawn handler, destroys the plot and releases its
light from the budget.

### Global leaderboard

A physical two-sided board between two plaza path mouths shows the top five for one stat at a
time, cycling every 8 seconds with page dots: **Most Figures** (permanently discovered figures),
**Top Coins/sec** (current Display rate) and **Most Boxes Opened** (persistent `boxesOpened`).
It is global across servers through one OrderedDataStore per stat, presentation only, and grants
no rewards. Scores are written at most once a minute per player (only changed values) and on
leave; the top five are read every 90 seconds. Request budgets are checked, failures back off,
and the last good page stays visible. Names come from a cached UserService lookup. The board
shows "Loading..." placeholders until the first read succeeds.

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
provisional counts. **Shelves** is the physical presentation name: three adjoining oak-framed
bays, ivory boards, recessed warm back panels, charcoal plinths and a continuous ivory canopy.
One integrated physical SurfaceGui header says only **Shelves**. Each row has a short, subtle
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
Open plot — walk-through name arch at front; no enclosing walls

                    BACK
           Display [1] [2] [3]
       (only unlocked slots; stays centered)

   [ Shelves ]
   > [ Shelf C ]
     [ Shelf B ]              open center/right
   < [ Shelf A ]             walking / future space
   3 x 3 each; faces inward; arrows at installation ends

          (o) spawn pad          Owner's Plot
              [ arch: <Name>'s Showroom ]
                  path to Market Street
```

Display and Collection now follow the supplied collectible-store fixture concepts, pending
native visual acceptance. Shared ground, existing figure art and Shelf editor remain provisional;
the layered plot platform follows the supplied floor concept, and the town, arch, awnings, spawn pad
and leaderboard follow the approved Blindbox Town mockup. Pocket Grove
remains a collection, not a core world API/theme dependency. No themed
forest environment, Game Pass kiosk, shelf pricing, final art, extra Display capacity, likes,
ratings, trading, cross-server travel or free placement is part of this implementation.
