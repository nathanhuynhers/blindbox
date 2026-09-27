# Player Plot, Shelf Units and Collection implementation

Implemented September 27, 2026. Current schema is **5**. This report covers the correction to
individually persistent Shelf Units and a three-shelf viewport. It supersedes the earlier v4
Shelf Page implementation report. Native Studio acceptance has **not** been run by the agent.
See [canonical design](PLAYER_PLOTS_AND_SHELVES.md) and [data model](DATA_MODEL.md).

## Collection visual pass (current physical presentation)

The subsequent visual pass implements the supplied Collection concept board with the dedicated
`src/server/CollectionFixture.luau` builder. **Collection** is the physical presentation name;
persistent Shelf Units and schema v5 remain unchanged. The builder creates three adjoining bays,
each with oak uprights, a recessed warm back panel, three ivory shelf boards and a charcoal
plinth. A continuous ivory canopy and pale oak crown join the installation. Construction uses
56 native Parts plus two invisible hitbox Parts; no mesh, uploaded texture, per-frame loop or
new dependency is involved. Native visual acceptance remains pending.

The fixture stays at plot-relative X=40 and faces inward along -X. Bay centers are Z=-16/-4/8,
12 studs apart, with 10.9-stud clear boards and 5-stud depth. The full installation, including
side wings, spans 44.4 studs along Z and reaches Y=17.05. The center/right and rear Display
remain undisturbed. Each bay contains nine anchors: three at 3.6-stud spacing on each board,
with row 1/2/3 surfaces at Y=10/5.8/1.6 above plot origin. Figure scale remains 1; the existing
renderer now applies its bottom-alignment option to shelves so all figures stand on the boards.
Display scale, construction and rendering behavior are unchanged.

| Use | Material / exact RGB |
| --- | --- |
| Uprights, control panels, crown and sign frame | Wood; oak (198,165,120) |
| Boards, canopy, bases and control wings | SmoothPlastic; ivory (242,235,220) |
| Recessed backs | SmoothPlastic; warm panel (235,225,204) |
| Plinths / sign lettering | SmoothPlastic / text; charcoal (48,46,43) |
| Header inset | SmoothPlastic; recess (171,143,106) |
| Header face | SmoothPlastic; cream (255,246,222) |
| Diffusers / enabled arrow accents | SmoothPlastic; warm ivory (255,237,199) |
| Disabled arrow accents | SmoothPlastic; muted oak-gray (163,146,122) |
| Light color | Warm (255,227,180) |

The layered header has a Left-facing SurfaceGui on its physical cream face, dark GothamBlack
lettering, `AlwaysOnTop=false` and `LightInfluence=0.35`. Its only text is **COLLECTION**. No
visible shelf numbers, zero-Coin copy or Previous/Next labels remain in the world. Detailed
indices still appear in the unchanged owner Shelf editor. Nine short downward SurfaceLights,
one per row, use brightness 0.35, range 5, angle 110 and no shadows. No neon or arrow lights.

Oak/ivory side wings carry two-bar solid chevrons and thin warm trim. Native Parts simplify
the reference's curved side profiles. Each control retains a queryable, noncolliding, invisible
5-by-10-by-7 hitbox under the plot root. Existing ClickDetector reach (160 studs), server plot
area/living-actor validation, shared cooldown and independent editor proximity remain intact.
Three owned units disable detection and mute the icon/trim colors; more than three enables both.
Carousel turns retain the furniture, header and lights and use the existing targeted figure cache.

### Visual-pass file manifest

Added `src/server/CollectionFixture.luau`. No files removed. Modified:

- `src/server/PlayerPlot.luau` — delegate construction; remove world status text; set visual availability.
- `src/server/PlotGeometry.luau` — coordinated bay spacing and board-top anchor heights.
- `src/server/FigureSlots.luau` — clarify the existing optional alignment comment; algorithm unchanged.
- `tests/Plots.spec.luau` — retain architecture/Display checks; add physical fixture assertions.
- `tests/PlotEngine.luau` — add the Left surface enum to the engine shim.
- `tests/run.py` — load the new builder in the standalone harness.
- `docs/PLAYER_PLOTS_AND_SHELVES.md`, `docs/ARCHITECTURE.md`, `docs/UI_UX.md` and this report.

Compared with the pre-visual-pass baseline, `DisplayFixture`, Shelf configuration/types/domain,
profile/schema/migration modules, economy/rules, plot allocation/dimensions, protocol, owner editor
and every Shelf architecture test remain byte-for-byte unchanged. No purchasing, customization,
completion rewards or new persistent fields were added.

### Visual-pass verification and manual acceptance

Rokit provisioning, Wally resolution, `stylua src`, `stylua --check src`, `selene src`, Rojo
sourcemap/build, Luau Language Server analysis and `git diff --check` pass. Selene uses the
cached Roblox API definitions because its network refresh is unavailable; no lint diagnostics.
Luau analysis has no source diagnostics (only the standalone watcher-registration notice).
All automated suites pass, including the unchanged **222 Shelf Unit checks** and expanded
**1,369 plot checks**. Other suite counts remain listed below. New checks cover three bays,
nine anchors per bay, board contact, scale, widest-figure clearance, all physical part bounds,
single constant COLLECTION text, lighting/material budgets, icon availability and static reuse.
Existing tests still cover long-range input, wraparound, visitors, stale edits and cleanup.

**Manual Studio checks still required:** inspect front/side/three-quarter views against the
concept; check wood grain, header readability, chevron direction and muted/enabled states.
Populate all 27 positions with the twelve current figures and check contact/clearance. Test
mouse/touch controls from across the plot with two clients and four/five owned shelves; confirm
shared one-unit movement, both wraps, visitor edit denial and unchanged owner editor targets.
Regress Display appearance/rates, save/rejoin, and measure nine row lights per plot at low/high
graphics quality and a full 24-player server. No native Studio playtest or visual approval is
claimed. Existing collectible art, ground/plot surfaces, owner signage and Shelf editor styling
remain provisional; the Collection furniture/sign/control visual pass itself is implemented.

## Earlier architecture correction (schema and migration unchanged by visual pass)

## Persistent model and runtime behavior

- `shelves.units[]` is an ordered array of `{id, placements, customization}`. Fresh players own
  exactly three units with stable IDs `shelf:1` through `shelf:3`. Placements use local
  `row:R/slot:S` keys; each unit currently has three rows of three positions. Customization is
  validated as empty and belongs to the persistent unit.
- `ShelfConfig` defines starting/visible unit counts, rows and slots. Future acquisition adds
  individual units, currently nine positions at a time. Policy is `Unassigned`; no prices,
  products, purchase flow or product-design maximum were introduced. Server decoder guards
  (10,000 units, 20,000 placements, 10,000 dormant records) prevent excessive allocation and
  are documented separately from progression design.
- `Shelves.View = {startIndex, revision, lastTurn}` is runtime-only. It starts at 1 each join.
  Next increments and Previous decrements by **one**, with wrapping and the shared 0.5-second
  cooldown. At most three owned units fixes the initial order and disables world/editor arrows.
- Three permanent physical structures (`ShelfPosition_1..3`) act as viewport positions. Position
  P renders owned index `(startIndex + P - 2) % ownedCount + 1`. Their `ShelfId` attributes expose
  the currently rendered persistent IDs. Local placements map to runtime-only FigureSlots keys
  `viewport:P/row:R/slot:S`; these are never saved. No furniture is added when capacity grows.
- The world and owner snapshots share the same visible trio. Owner snapshots contain only
  `{ownedCount, visible = {{id, index, placements}, ...}, carouselRevision, canNavigate}`.
  Hidden units and dormant migration data are excluded. Existing FigureSlots caching replaces
  only changed figures at physical anchors; rendering remains at most 27 shelf figures per plot.
- The minimal Shelf editor selects one of three visible units, then one of nine local slots and
  a discovered figure. It labels wrapped indexes explicitly, e.g. “Viewing shelves 4, 5, 1 of 5”.
  Requests target `shelfId` plus `shelfSlotId` and require current profile/carousel revisions,
  visible ownership, discovery and proximity. A-B-A browsing invalidates stale edits.
- Visitors can click/tap the same world controls and see the same trio; they cannot edit or
  receive private profile state. Existing 160-stud detector reach, server plot-area/living-actor
  checks, independent close-range editor validation and cleanup remain in place.
- Shelves reserve/consume zero copies, generate zero Coins and do not affect Display bonuses,
  recycling or daily goals. Repeated discoveries and simultaneous Display/shelf use still work.

| Owned count | Successive Next viewports |
| --- | --- |
| 3 | 1,2,3; navigation disabled |
| 4 | 1,2,3 → 2,3,4 → 3,4,1 → 4,1,2 → 1,2,3 |
| 5 | 1,2,3 → 2,3,4 → 3,4,5 → 4,5,1 → 5,1,2 → 1,2,3 |

Previous traverses the same sequence in reverse. Contents follow the persistent unit ID through
all three physical positions. Browsing changes no saved content, balance or profile revision.

## Migration and data preservation

The decode-only `LegacyShelfPages` module validates the retired v4 representation and converts
each source page into exactly three units in source array order. Old page P, logical unit U
maps to index `(P-1)*3+U`, ID `shelf:<index>`; `unit:U/row:R/slot:S` becomes `row:R/slot:S`.
One old page becomes three units; two become six, including empty units and empty positions.
Duplicates, zero-copy discoveries, Display capacity/placements, currency, inventory, discovery,
onboarding and daily state survive. The decoder does not mutate input; v5 round trips are stable.

Per the user's explicit choice, valid old logical units above 3 remain as dormant
`legacyOverflow` records `{sourceId, logicalUnit, placements}`. They retain retired source IDs
and all references without granting extra shelves. Records are sorted deterministically,
validated, deep-copied through saves and excluded from rendering, editing and client projections.
Valid hidden row/slot coordinates within units 1..3 remain attached to their new Shelf Unit.

The v3 adapter retains its deterministic room-ID/numeric-anchor order and frozen packing into
the retired v4 intermediate representation, then immediately converts to units. For example,
42 references become six units, including trailing empty capacity. No old room runtime or
completion grant returns. v1/v2 profiles receive three empty units and retain their existing
progress/defaults. Unknown fields/customization, corrupt or future schemas and excessive data
fail closed without resetting profiles. Storage leases, save generations and failure behavior
are unchanged; v5 deployment requires compatible decoding across replacement servers.

## Preserved Display and physical design

The earlier concept-board Display is unchanged by this correction: one continuous off-white
counter, oak base, recessed charcoal plinth, broad warm back panel, end supports, canopy,
warm diffuser and integrated DISPLAY/rate sign. The existing 14 native Parts resize for
capacities 3/4/5/6 to counter widths 28/36/44/52 studs, centered at X=0/Z=36, top Y=3 and
8-stud figure spacing. Display figures retain 2x scale and bounding-box bottom alignment;
shelf figures remain at their existing scale. The sign still uses the actual server rate.

During the preceding architecture correction, `DisplayFixture`, `FigureSlots`, Display UI,
economy, plot allocation/configuration and the engine shim matched its pre-correction baseline.
The visual pass above now replaces shelf/control geometry while preserving the open 100-by-96
plot, left-side installation, persistent identities and Display rendering. Completion
rewards, shelf acquisition/customization, final art and carousel animation remain unresolved.

## Verification actually run

- Provisioned exact pinned tools with Rokit and resolved the empty Wally dependency set.
- `stylua src` and `stylua --check src`: pass.
- `selene src`: zero errors, warnings or parse errors. Roblox API refresh was unavailable;
  Selene used the existing cached Roblox definitions successfully.
- `rojo sourcemap default.project.json -o sourcemap.json`: pass.
- `rojo build default.project.json -o RobloxWorkspace.rbxlx`: pass with pinned Rojo 7.7.0.
- Luau Language Server analysis of all `src`, with the Rojo sourcemap and Roblox definitions:
  zero source diagnostics. Its standalone watcher-registration warning is informational.
- `git diff --check`: pass.
- `python tests/run.py build/tools/luau/luau.exe`: all suites pass:

| Suite | Checks |
| --- | ---: |
| MVP | 8,878 |
| Full game / persistence faults | 81 (19 storage calls) |
| Scrolling | 4 |
| Opening | 1,732 |
| UI projections/layout/lifecycle | 1,839 |
| Collection layout/selection | 72 |
| Asset manifest | 26 |
| Asset mount/fallback | 25 |
| Model binding | 4 |
| Shelf Unit schema/migration/carousel/domain | 222 |
| Plot allocation/geometry/render/lifecycle | 966 |
| Invalid startup configuration | 4 |

Shelf coverage includes fresh capacity, exact four/five-unit sequences, both directions,
disabled three-unit navigation, all visible owner targets, wrapped edits, visitor rejection,
stale profile and A-B-A carousel revisions, local ID/payload validation, zero economy/copy
effects, retry receipts, 250 owned units with bounded projection/rendering, every v4 placement,
empty capacity, deterministic/idempotent migration, dormant overflow, all 42 v3 references,
v1/v2 defaults, persistence acquisition, corrupt/future data and decoder resource guards.

Plot tests exercise actual modules with engine property/signal shims: three fixed structures,
every figure following its persistent unit across all viewport positions and wraps, targeted
model reuse, long-range owner/visitor input, cooldown/proximity denial, rejoin and teardown.
The earlier Display fixture/rate/resize checks remain. Shims and injected persistence do not
prove native input, replication, physics, rendering or real DataStore behavior.

## Required manual Studio acceptance

1. Run two clients with fresh three-unit profiles; confirm fixed 1,2,3 order and disabled world
   and editor navigation. Select/edit all three units with mouse/touch and zero-copy discoveries.
2. Seed isolated four/five-unit test profiles. Verify every sequence above in both directions,
   shared owner/visitor visibility, wrapped labels/selection, rapid-turn cooldown and stale edits.
   Confirm each unit's contents follow its ID and hidden units create no instances.
3. Attempt visitor, distant, malformed and stale edits; confirm privacy and owner-only changes.
   Check physical click/tap controls retain across-plot reach without expanding edit proximity.
4. In the private Studio test store, load v1/v2/v3/v4 fixtures, including empty capacity, 42 v3
   references and v4 overflow. Save/rejoin into a different plot; compare all progress and dormant
   records, with runtime visibility reset to 1,2,3. Exercise failures/leases without live data.
5. Check phone/tablet/desktop editor sizing, scroll/selection, gamepad navigation, respawn and
   owner departure/replacement. Regress Display capacities/rates, Collection, Shop and opening.
6. Populate up to 24 plots with 27 shelf and six Display figures each. Measure replication,
   frame rate/memory and repeated carousel/joins/leaves; confirm stable instance/connection counts.

See [operations](OPERATIONS.md) for isolated storage and release procedures. These Studio tests
remain pending and are not implied by passing automated checks.

## Files changed by this correction

The manifest below is relative to the snapshot taken immediately before this task. It excludes
prior uncommitted Display implementation work and ignored generated tools/build/cache files.
The documentation list also covers the two historical Showroom pointers, whose current links
now describe Shelf Units. Shelf Page terminology appears only in explicitly retired
schema migration code/fixtures/notes; unrelated Collection Book page terminology is unchanged.

### Added

- `src/server/LegacyShelfPages.luau`

### Removed

None.

### Modified

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/DATA_MODEL.md`
- `docs/DISPLAY_AND_SHOWROOMS.md`
- `docs/DISPLAY_SHOWROOM_IMPLEMENTATION.md`
- `docs/ECONOMY.md`
- `docs/FULL_GAME.md`
- `docs/GAME_DESIGN.md`
- `docs/MONETIZATION.md`
- `docs/OPERATIONS.md`
- `docs/PLAYER_PLOTS_AND_SHELVES.md`
- `docs/PLOT_SHELF_IMPLEMENTATION.md`
- `docs/PRODUCT_BACKLOG.md`
- `docs/ROADMAP.md`
- `docs/UI_UX.md`
- `src/client/ShelvesScreen.luau`
- `src/client/init.client.luau`
- `src/server/LegacyCosmetics.luau`
- `src/server/PlayerPlot.luau`
- `src/server/PlotGeometry.luau`
- `src/server/Profile.luau`
- `src/server/Protocol.luau`
- `src/server/Rules.luau`
- `src/server/Shelves.luau`
- `src/shared/ShelfConfig.luau`
- `src/shared/Types.luau`
- `tests/Plots.spec.luau`
- `tests/Shelves.spec.luau`
- `tests/UI.spec.luau`
- `tests/run.py`
