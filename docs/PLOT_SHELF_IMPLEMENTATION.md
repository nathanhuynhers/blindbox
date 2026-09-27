# Player Plot and Shelf implementation report

Implemented September 27, 2026 as a functional placeholder candidate. This replaces the
Showroom/Gallery architecture completely. Native Studio playtests have **not** been run by the
agent. [Canonical design](PLAYER_PLOTS_AND_SHELVES.md) and [schema](DATA_MODEL.md) describe the
current behavior; final visual design and release acceptance remain pending.

## Architecture and runtime

- **Fixed plots:** `PlotConfig` defines 24 locations in a six-column grid, each 100 by 96 studs
  with 20-stud gaps. `PlotSlots` reserves the first available location before loading a profile;
  duplicate reservations and full-server joins are rejected. Failed/aborted loads release their
  reservations when loading returns. Departures disconnect character/plot callbacks, destroy
  owned content and release the slot. Set the Roblox experience player cap to match this limit.
  A DisplayName sign identifies each owner. Join/respawn places that character inside its own plot.
  Plot index and coordinates are session-only. Visitors walk between open plots.
- **Horizontal Display:** three starting slots, six current maximum, one row at constant Y/Z.
  Unlocking capacity reveals the next position to the right and resizes the existing stand;
  it does not rebuild the plot. The existing fourth-slot 4,000-Coin unlock and server rate,
  themed bonus, copy reservation and recycle rules remain. Slots 5/6 acquisition is unassigned.
- **Shelves:** three fixed physical units, three rows each, three positions per row. Counts
  come from `ShelfConfig`. Every fresh profile owns one page; additional stored pages reuse
  those same units. Pages have no permanent count cap, and no acquisition or pricing flow.
- **Stable identity:** ordered pages have unique IDs such as `page:1`. Placements use keys
  such as `unit:2/row:3/slot:1`, independent of geometry/world coordinates. Decoding preserves
  structurally valid keys outside current geometry; only configured visible slots can be edited.
  Each page has an empty, validated customization map for later versioned extension.
- **Carousel:** Previous/Next use `(index - 1 + direction) % pageCount + 1`, so both ends wrap.
  All viewers see the same server-rendered page. Page index/revision/cooldown are runtime-only,
  starting at page 1 each join. Physical prompts work for nearby living owners and visitors;
  a shared half-second cooldown bounds turns. Owner UI also supports navigation near shelves.
- **Editing:** the minimal Shelves screen replaces the old Social navigation position. It shows
  page/count, logical slots, selected slot and discovered-figure picker, with place/replace/remove.
  Discovery suffices with zero owned copies; repeated figures and simultaneous Display use work.
  Shelves earn zero Coins, reserve zero copies and contribute no bonus or daily Display progress.
- **Permissions:** remote callbacks select the caller's own session. No owner/plot ID is accepted.
  Edits require owner identity, proximity, known discovered figure, valid owned current page and
  visible slot, matching profile/page revisions, and existing rate/receipt validation. A page
  changed away and back still invalidates a stale edit. Visitors can only view and turn the
  exhibit; private inventories, balances, discoveries and progression never go to other clients.
  Only the owner's current page is included in its private snapshot, not the entire page list.
- **Performance/lifecycle:** static geometry is cached. Figure rendering compares IDs per slot,
  replacing only changed models and reusing matching figures between pages. Visible models are
  bounded by 27 shelf positions plus six Display positions per plot, regardless of page count.
  No per-frame plot loop was added. Connections, owned models and pending spawn tasks are cleaned
  up on departure. Actual 24-player/mobile rendering cost still requires measurement.

The only remotes are Intent, State and RequestState. No Gallery entrances, hallway, pagination,
room instances, portals, visit tokens/sessions, Showroom editor, palette UI or completion room
grants remain. Simulated visitor actors tied to the former plot presentation were retired.
Shop, Collections, opening presentation, active balance values, Rojo mappings/pins, packages and
storage namespace/lease implementation remain unchanged.

## Schema v4 and legacy conversion

Valid v1 and v2 profiles migrate directly to v4 with one empty shelf page. Valid v3 profiles
retain Coins, Scrap, owned/discovered figures, Display capacity/placements, onboarding and daily
state. Completion stays derivable from discoveries. No collection-completion reward is invented;
future completion rewards are **TBD**.

`LegacyCosmetics` is decode-only compatibility, not a retained runtime. It validates the old
palette/room structure and figure eligibility, sorts room IDs lexicographically, then reads each
room's `figure_1` through `figure_6`. Every reference, including repeated figures and discoveries
with zero copies, is packed into a frozen 3-by-3-by-3 layout. Reference 28 starts page 2, and so on.
Pages are created only as needed to preserve placements, with a minimum of one. Migration never
deduplicates or overwrites those references. Empty rooms grant no additional pages.

Old room identity/origin/ownership, palette preference/ownership, themes and empty customization
have no new equivalent and are retired without refunds or speculative paid entitlements. Unknown
nonempty customization was invalid under v3 and still blocks loading. All invalid/unsupported
schemas fail closed; they never reset to defaults. Encoding writes v4, and decoding v4 preserves
the existing page identities and placements, making subsequent round trips idempotent. Runtime
plot assignment and visible-page state are excluded. Existing storage leases and deep snapshot
copies protect the aggregate. Deploying v4 requires replacing older writers; rollback code must
retain v4 support. No production store or published experience was changed during this work.

## Verification actually run

- Provisioned exact pinned tools with `rokit install --no-trust-check`; `wally install` succeeded
  with zero dependencies. No tool version, project property or dependency was changed.
- `stylua src` and `stylua --check src`: pass.
- `selene src`: 0 errors, 0 warnings, 0 parse errors. Network API refresh was unavailable;
  Selene used the existing Roblox API cache.
- Rojo 7.7.0 sourcemap generation and `rojo build default.project.json -o RobloxWorkspace.rbxlx`:
  pass. Build and sourcemap remain ignored generated outputs.
- Luau Language Server 1.70.0 CLI analysis with the generated sourcemap and local Roblox
  PluginSecurity definitions: no source diagnostics. CLI reports its normal file-watcher
  registration warning; that is not a source diagnostic.
- `git diff --check` and local file-link checks for all changed/new Markdown: pass.
- `python tests/run.py build/tools/luau/luau.exe`: all suites pass, 13,138 checks/fixtures total:

| Suite | Checks |
| --- | ---: |
| MVP domain/request regression | 8,878 |
| Full-game/persistence faults (19 storage calls) | 81 |
| Scroll sizing/lifecycle | 4 |
| Opening state/results | 1,732 |
| UI projections/layout/lifecycle | 1,839 |
| Collection book layout/selection | 72 |
| Public asset manifest | 26 |
| Artwork/fallback mounts | 25 |
| Semantic model binding | 4 |
| Shelf schema/migration/permissions/abuse | 121 |
| Plot allocation/geometry/targeted render/cleanup | 352 |
| Invalid configuration startup fixtures | 4 |

New tests cover multi-page migration/round trips, preserved unrelated progress, invalid/future
schemas, valid collection rooms, unknown anchors/customization, discovery-only cosmetics,
reservation/income/bonus isolation, unowned/stale pages, malformed identities/numbers, retry
receipts, many pages, both wraps, visitor permissions, finite unique allocation, non-overlapping
plots, one-row Display growth, targeted rendering, rejoin/reassignment and stale-prompt cleanup.
Runtime tests run actual plot modules against engine property/signal shims; they do not prove
Roblox physics, rendering, native replication or input. Persistence tests use injected storage.

## Required Studio acceptance

1. **Join/leave/respawn:** run multiple clients; verify unique fixed locations, DisplayName signs
   and safe spawns. Reset characters; rapidly join/leave while profiles load; inject failed loads.
   Reuse released slots, reject overflow gracefully, and check no stale content/tasks/prompts.
2. **Open social space:** walk between plots without prompts/teleports. Verify clear circulation,
   no perimeter walls, readable signs and public Display rates. Host departure leaves guests on
   shared ground. Confirm private data is never sent to a visitor client.
3. **Display:** fresh capacity 3, one-time slot-4 charge, same-height horizontal growth. Use an
   isolated six-slot fixture for 5/6 (there is deliberately no live acquisition UI). Place,
   replace/remove, inspect locked slots, rates and themed bonus; attempt edits from other plots.
4. **Shelves:** owner selects all 27 logical slots and places/replaces/removes figures, including
   repeats and zero-copy discoveries. Verify inventory, recycling and income remain unchanged.
   Attempt distant, visitor, stale revision, invalid page/slot and undiscovered-figure requests.
5. **Shared carousel:** seed only isolated test profiles with multiple pages or legacy placements.
   Test both wrap directions, rapid owner/visitor turns, cooldown, simultaneous editing and A-B-A
   stale requests. All clients must see the same figures; other plots stay unchanged. Rejoin
   resets the visible page to 1 while retaining every saved page.
6. **Persistence:** in the private Studio test store, load v1/v2/v3 fixtures, including 42 legacy
   references crossing a page boundary; compare every preserved field. Save/rejoin into a
   different plot, repeat round trips, exercise save failures/leases and reject corrupt/future
   fixtures without overwriting data. Follow [operations](OPERATIONS.md) for isolated setup.
7. **Completion/UI:** complete both collections, confirm tracking and no new grant. Exercise
   Display and Shelf editor with mouse, touch, narrow phone, tablet and gamepad. Check scroll,
   selection, error toasts and safe-area bounds. Regress Shop, Collections and opening controls.
8. **Performance/cleanup:** populate up to 24 plots with 27 shelf and six Display figures each;
   measure target-device frame rate, memory and replication during repeated turns/edits. Soak
   joins/leaves/respawns for 30 minutes and confirm stable instance/connection counts and Output.

## Documentation and placeholder work

`DISPLAY_AND_SHOWROOMS.md` and `DISPLAY_SHOWROOM_IMPLEMENTATION.md` were replaced with explicit
historical pointers. Current design, architecture, schema, economy, scope, UI, roadmap, operations,
monetization ideas, backlog, asset guidance and root README now describe open plots and shelves.
Earlier MVP milestones remain clearly historical. The old artwork folder is marked retired;
no source art was deleted. This report and `PLAYER_PLOTS_AND_SHELVES.md` are the current references.

Final map theming, plot surfaces, Display stand, shelf boards/supports, arrows, signage, circulation
layout and Shelf editor still need visual design. Existing collectible models/assets are reused.
No new final art, skin/customization UI, furniture, page pricing, monetization products, Game Pass
kiosk, new completion reward or additional Display capacity was implemented.

## Exact file manifest

The lists below are relative to the repository root and cover this architecture replacement.
Generated ignored build/cache files are excluded.

### Added

- `docs/PLAYER_PLOTS_AND_SHELVES.md`
- `docs/PLOT_SHELF_IMPLEMENTATION.md`
- `src/client/ShelvesScreen.luau`
- `src/server/FigureSlots.luau`
- `src/server/LegacyCosmetics.luau`
- `src/server/PlotConfig.luau`
- `src/server/PlotGeometry.luau`
- `src/server/PlotSlots.luau`
- `src/server/Shelves.luau`
- `src/shared/ShelfConfig.luau`
- `tests/PlotEngine.luau`
- `tests/Plots.spec.luau`
- `tests/Shelves.spec.luau`

### Removed

- `src/client/ShowroomScreen.luau`
- `src/client/Visitors.luau`
- `src/client/VisitsScreen.luau`
- `src/server/GalleryRuntime.luau`
- `src/server/GallerySessions.luau`
- `src/server/Showrooms.luau`
- `src/server/SpaceTemplate.luau`
- `src/shared/ShowroomConfig.luau`
- `tests/DisplayShowrooms.spec.luau`
- `tests/GalleryEngine.luau`
- `tests/GalleryRuntime.spec.luau`

### Modified

- `README.md`
- `assets/README.md`
- `assets/showroom/README.md`
- `docs/ARCHITECTURE.md`
- `docs/ASSET_PIPELINE.md`
- `docs/DATA_MODEL.md`
- `docs/DISPLAY_AND_SHOWROOMS.md`
- `docs/DISPLAY_SHOWROOM_IMPLEMENTATION.md`
- `docs/ECONOMY.md`
- `docs/FULL_GAME.md`
- `docs/GAME_DESIGN.md`
- `docs/MONETIZATION.md`
- `docs/MVP.md`
- `docs/OPERATIONS.md`
- `docs/PRODUCT_BACKLOG.md`
- `docs/ROADMAP.md`
- `docs/UI_UX.md`
- `src/client/DisplayScreen.luau`
- `src/client/GoalsScreen.luau`
- `src/client/Interface.luau`
- `src/client/Navigation.luau`
- `src/client/UIContext.luau`
- `src/client/UIIcons.luau`
- `src/client/UILayout.luau`
- `src/client/init.client.luau`
- `src/server/Economy.luau`
- `src/server/PlayerPlot.luau`
- `src/server/Profile.luau`
- `src/server/Protocol.luau`
- `src/server/Rules.luau`
- `src/server/Settings.luau`
- `src/server/Transactions.luau`
- `src/server/World.luau`
- `src/server/init.server.luau`
- `src/shared/Catalog.luau`
- `src/shared/Types.luau`
- `tests/FullGame.spec.luau`
- `tests/UI.spec.luau`
- `tests/run.py`
