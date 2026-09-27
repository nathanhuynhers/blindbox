# Display + Showroom foundation

Implemented candidate, September 26, 2026. This records the scoped functional foundation for
[the product direction](DISPLAY_AND_SHOWROOMS.md). Native Studio, device, multi-client and real
DataStore acceptance remain pending. No publishing, monetization or asset uploads occurred.

## Architecture and checkpoints

1. **A — Display and migration:** separate schema-v3 aggregates, three default/six maximum
   Display slots, existing income/reservation rules. Domain, persistence fault and migration
   tests passed before Gallery implementation.
2. **B — ownership and runtime:** data-driven collection unlocks, owner-specific Gallery
   membership and isolated allocations, lazy room templates. Unlock/lifecycle regression tests
   and Luau Language Server analysis passed before editor UI integration.
3. **C — editing and visiting:** typed/replay-protected cosmetic edits, discovered-figure
   eligibility, owned palette selection, read-only guests, runtime-generation checks, minimal
   UI and controller lifecycle tests. See the verification record below.

`Rules` reads **only** `state.display.slots` for income, reservations, daily Display goals and
the themed bonus. The formula is unchanged: sum of occupied Display rates plus a single
+1 Coin/sec when at least three distinct Display figures share a collection. No Showroom
figure contributes to any economy calculation. Settlement still precedes Display mutation.

`DisplayConfig` defines default 3, maximum 6 and separate extra-slot acquisition policies.
Capacity remains sequential: granting capacity N unlocks the first N slots. This deliberately
simple representation supports different acquisition methods at successive slots. Non-sequential
entitlements would require an explicit later migration. Only the existing fourth-slot purchase
(4,000 Coins) is implemented; slots 5/6 remain locked with unassigned unlock policies. No permanent
prices or Game Pass IDs were invented. Physical positions and protocol/storage accept all six.

## Saved data and migration

Schema **3** stores `display = {unlocked, slots}` and
`showrooms = {rooms, palette, palettes}` separately. See [the exact data model](DATA_MODEL.md).

- Version 1: validate and copy all seven original fields; move the three slots into Display;
  add three-slot capacity, the free Grove palette and unclaimed daily defaults.
- Version 2: validate and move slots/unlocked into Display unchanged; move `theme`/`themes`
  into Showroom palette preference/ownership. Preserve Coins, Scrap, quantities, permanent
  discovery, onboarding step, daily box day, goal day/progress/claim exactly.
- Both versions: derive earned collection rooms from the saved discoveries. Newly earned rooms
  inherit the preserved palette preference. Players without completed collections retain their
  palettes for later rooms. Nothing is charged, refunded, reset or deleted.
- Version 3: validate and deep-copy room/anchor/figure identities, then reconcile any missing
  earned rooms. Repeated loading does not duplicate rooms or overwrite their customization.

Migration is deterministic, does not mutate its input, and runs inside the existing validated
lease acquisition path. Unknown schemas/fields, invalid reservations or incompatible cosmetic
data fail closed; no fallback profile overwrites valid progress. Store names, envelopes, leases,
autosave behavior and offline-income behavior are unchanged. Older servers cannot decode v3:
replace the running server fleet when deploying this schema. Do not roll back to a v2-only writer.

Legacy palette purchases are preserved but new palette shopping is retired for this foundation.
The owner can select owned palettes in a Showroom, affecting that room's walls/floor only.
Display has no palette editor. The saved legacy preference remains the default for future earned
rooms; changing an individual room does not rewrite all rooms.

## Showroom identity and placement

Catalog collections explicitly define `showroomId`. Existing stable collection IDs remain
`grove` and `tide`; they were not renamed to visible names. Earned room IDs are
`collection:grove` and `collection:tide`. A room stores its `roomId`, `sourceType`, optional
`sourceCollectionId`, theme, placements and customization map. `Custom` rooms accept stable
`custom:<opaque-id>` identifiers without requiring a collection; no acquisition flow exists.
Names and world coordinates are never persistent keys. The room map has no four-room cap.

Every successful Buy, Daily or Redeem discovery reconciles collection completion. Profile
decoding also reconciles completion for migration/reconnect. Current completion means all six
catalog figures in the collection; no Secret requirements or Claim button were added.

**Showroom figures are cosmetic references to permanent discovered IDs. They reserve zero
inventory copies.** One discovered figure may appear in Display and any number of configured
Showroom anchors/rooms at once. Cross-collection placement is allowed. Recycling eligibility,
inventory quantities, Display reservations and income are unaffected. Unknown/undiscovered
figure IDs are rejected on the server.

The placeholder uses configurable stable anchors `figure_1` through `figure_6`. Six is a
template proving the system, not a final Showroom capacity decision. Wall, floor, lighting,
shelves, pedestals, furniture, decorations and effects have named template hooks and shared
category definitions. Empty persisted customization maps reserve the extension point; adding
real items requires definitions, validation, ownership rules and migration. No arbitrary client
properties, free placement or speculative decor catalog are accepted.

## Runtime, access and teardown

`PlayerPlot` replaces legacy `Rooms`; Workspace uses `PlayerPlots`. Each main plot has its
economic Display and **one** primitive `ShowroomGalleryEntrance`, labeled with the owner.
The core API is independent of Pocket Grove visual identity.

The entrance's server-owned prompt identifies the host. The server verifies a loaded session,
living character, proximity and navigation cooldown. Same-server visitors can walk there or use
the existing Social plot directory first. No client-supplied host establishes edit authority.

`GallerySessions` owns runtime membership and generations. `GalleryRuntime` owns geometry,
prompts, connections and sanitized views. The first participant allocates an owner's Gallery;
other participants join that same space. Multiple owners receive separate 640-stud-wide lanes
at elevated interior coordinates. Rooms use 64-stud cells within their owner's lane and are
instantiated only when entered. Positions are temporary and have no persistence meaning.

A hall shows at most six owned room entrances. Additional rooms use physical Next/Previous
hall portals; there is no permanent room-count cap. Pagination changes the shared visible hall
for that owner. Doors and figure models rebuild only when their relevant state changes.

Leaving a room destroys it when its last participant leaves. Leaving a Gallery destroys it
when its last participant leaves. Character removal/reset clears participation immediately;
respawn returns the player to their plot. Owner departure returns remaining guests home;
visitor departure removes only that participant. Explicit instance destruction also clears
membership and returns affected players. Each owned connection is disconnected before normal
destruction. No per-frame Gallery polling or all-owned-room instantiation was added.

Each Gallery **and each room incarnation** has a fresh runtime token. Cosmetic intents carry
the current room token, stable room/anchor IDs and profile revision. Recreating a room within an
existing Gallery invalidates earlier room tokens. Server access derives actor/host/membership,
checks the live room and proximity, then the existing token bucket, exact receipt matching and
revision checks protect mutations. Guests cannot place/remove figures or change themes.

Public Gallery views contain owner ID/name, the bounded visible room labels, current cosmetic
room projection, runtime token and server-derived edit permission. They omit owner balances,
inventory, discoveries, owned palette inventory, progression, storage keys and leases. A visitor's
normal owner snapshot still describes **their own** profile. Cosmetic room state alone is safe
to render. Physical models are public presentation, never authority.

## Placeholder world and UI

```text
Main plot (PlayerPlots/<owner>)
  Display: [1] [2] [3]       3 unlocked initially
           [4] [5] [6]       locked markers; six permanent positions
  One labeled Gallery entrance
         |
         v
Separate owner Gallery lane
  Walkable hall + home exit
  Up to six reusable room portals + hall paging when needed
         |
         v
Lazy Showroom: walls/floor, six labeled figure pedestals, Gallery exit
              named customization hooks; owner/room/runtime attributes
```

Display controls show all six slots, locks, figures, per-figure and total rate, placement,
replacement and removal. Social controls switch to a compact Gallery/Showroom panel on entry.
Close the panel to walk; use physical prompts to enter/exit rooms. Inside a room, an owner
selects an anchor and a discovered figure or removes/replaces the current one. Owned palettes
can be selected. Visitors see room/anchor contents without editor controls. Exit-to-plot is
available in the panel. Global navigation, Collection Book, Shop and opening layouts are retained.
All new geometry/UI is replaceable placeholder work awaiting visual mockups; no screenshots
are represented as actual Studio output.

## Verification and remaining Studio acceptance

Checks actually run successfully:

- `rokit install --no-trust-check` provisioned the exact existing pins; no upgrades.
  The initial sandbox attempt could not reach GitHub; the authorized retry succeeded.
- Pinned `wally install` succeeded after granting access to its existing cache. Dependencies
  remain empty and lockfile contents are unchanged.
- `stylua src`, `stylua --check src`: passed with StyLua 2.5.2.
- `selene src`: 0 errors, 0 warnings, 0 parse errors with Selene 0.31.0. Its attempted API refresh
  was unavailable; it explicitly used the existing Roblox standard-library cache.
- `python tests/run.py build/tools/luau/luau.exe`: all existing/new suites passed, including
  87 Display/Showroom foundation checks and 28 Gallery controller checks. Existing suites report
  8,878 economy/request checks, 82 persistence/fault checks, 1,839 UI checks, 1,732 opening checks,
  72 collection layout checks and the scrolling/asset/configuration fixtures.
- `rojo sourcemap default.project.json -o sourcemap.json` and
  `rojo build default.project.json -o RobloxWorkspace.rbxlx`: passed with pinned Rojo 7.7.0.
- Luau Language Server 1.70.0 `analyze` over `src`, using that sourcemap and installed Roblox
  definitions: no diagnostics. `git diff --check`: passed.

Automated coverage lives in `tests/DisplayShowrooms.spec.luau` and
`tests/GalleryRuntime.spec.luau`, in addition to the existing regression/fault suites.
The latter executes the production controller with engine boundaries shimmed, including
multi-participant sharing, lazy rooms, public projections, instance destruction, stale prompts,
room recreation, owner/visitor departures and connection teardown. It does **not** test Roblox
physics, rendering, network replication or native prompt behavior.

Required manual tests in Studio:

1. Fresh profile: three usable Display slots, three locked markers; place/replace/remove and
   confirm per-figure rates and the +1 themed bonus. Buy slot 4 once. Slots 5/6 have no purchase.
   In an isolated server-side fixture only, load a valid six-slot profile and use all six.
2. Discover the final figure of each collection (or seed only an expendable server/test-store
   fixture); confirm automatic room access. Enter via the single plot entrance, close the panel
   and walk through the hall. Enter both collection rooms and return through their exit prompts.
3. Place a Display figure into several cosmetic anchors in both rooms. Confirm inventory,
   Scrap/recycling, Display rate and bonus do not change. Replace/remove; test owned palette reuse.
4. Start at least three clients. Two visitors enter one host's Gallery and the same room; edits
   replicate to both. Visitors cannot edit even with crafted intents. Activate another owner's
   Gallery simultaneously and verify spaces/permissions remain isolated.
5. Reset each role, exit the last room/Gallery participant, leave as host/guest, repeatedly enter
   and leave, and destroy a runtime instance from the server. Check return positions, Workspace
   cleanup and Output. Retry captured old room intents after recreating a room.
6. In the isolated Studio persistence store, load representative v1/v2 saves with expansion,
   discoveries, palettes and daily claims. Save/rejoin and compare every field, Showroom placement
   and theme. Rehearse existing lease/failure tests; never fault-inject real player records.
7. Mouse/touch/gamepad, small screens, collision/teleport landing, figure readability, prompt
   distance, simultaneous arrivals and 24-player performance/soak tests remain unmeasured.

Studio defaults to unsaved preview. Real persistence requires the existing private test-experience
setup in [operations](OPERATIONS.md). No further external action is needed to inspect the code or
build; Studio and account-side persistence validation are the remaining manual actions.

## Changed-file map

All source paths below are relative to `src/`; docs/tests/README use repository-relative paths.

| Area | Files |
| --- | --- |
| Display refactor | `server/Rooms.luau` replaced by `server/PlayerPlot.luau`; new `client/DisplayScreen.luau`; `server/Rules.luau`; new `shared/DisplayConfig.luau` |
| Showroom domain and rendering | New `server/Showrooms.luau`, `server/SpaceTemplate.luau`, `shared/ShowroomConfig.luau`; `shared/Catalog.luau`; cosmetic rewrite of `client/ShowroomScreen.luau` |
| Gallery lifecycle | New `server/GallerySessions.luau`, `server/GalleryRuntime.luau`; `server/init.server.luau` |
| Schema and requests | `server/Profile.luau`, `server/Protocol.luau`, `server/Transactions.luau`, `shared/Types.luau` |
| UI/terminology integration | `client/Interface.luau`, `client/Navigation.luau`, `client/VisitsScreen.luau`, `client/GoalsScreen.luau`, `client/Visitors.luau`, `client/init.client.luau`; naming/messages in `server/World.luau`, `server/Persistence.luau`, `server/Storage.luau` |
| Tests | New `tests/DisplayShowrooms.spec.luau`, `tests/GalleryRuntime.spec.luau`, `tests/GalleryEngine.luau`; adapted `tests/Mvp.spec.luau`, `tests/FullGame.spec.luau`, `tests/UI.spec.luau`, `tests/run.py` |
| Documentation | `README.md`; `docs/ARCHITECTURE.md`, `DATA_MODEL.md`, `DISPLAY_AND_SHOWROOMS.md`, new `DISPLAY_SHOWROOM_IMPLEMENTATION.md`, `ECONOMY.md`, `FULL_GAME.md`, `GAME_DESIGN.md`, `MONETIZATION.md`, `OPERATIONS.md`, `ROADMAP.md`, `UI_UX.md` |

Tool pins, Rojo mappings, package dependencies, figure economics and store names are unchanged.
Generated build/sourcemap/test files remain ignored. No historical MVP document was rewritten.
