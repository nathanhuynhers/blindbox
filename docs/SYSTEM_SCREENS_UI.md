# Display, Shelves and Goals

Implemented client presentation candidate. Native Studio visual, device and input acceptance
has not been run. No server, shared domain, economy, profile, remote, world or opening behavior
changes. No uploads, dependencies or asset placeholders are required for these screen surfaces.

## Neutral visual system

`SystemStyle` provides an oak edge around inset ivory surfaces, charcoal type, restrained lilac
selection, warm reward gold and muted green earnings/completion. Collection motifs appear only
inside Goals cards that explicitly represent a Catalog collection. Figures use the existing
`UIPreview` with bounds-based product-shot fitting and remain separate from native UI decoration.
Global Widgets, UITheme, Collection, Shop and navigation implementations are unchanged.

`SystemLayout` measures content instead of shrinking it to fit short viewports. Each screen has
one vertical scroll canvas; mobile keeps readable targets and moves secondary content beneath
the main composition. `UILayout` supplies larger presentation bounds and clears bottom navigation.
Close and Motion remain in their existing reserved top row. The new screens use a neutral 24%
dim with 3px blur; opening focus, close and screen switching retain existing cleanup paths.

## Screen responsibilities

- **DisplayScreen / DisplaySlotCard:** a curated plinth lineup, authoritative total income and
  per-figure rates, capacity, distinct matching-set progress, placement preview/Cancel and valid
  target outlines. Filled cards emphasize Change over Remove. Empty cards invite a choice.
  Slot four retains the configured legacy Coin action and affordability gate. Unassigned slots
  have truthful "Coming later" presentation with no actionable button. Returning from Collection
  uses the existing direct-slot or choose-target flow. No copy or income changes are optimistic.
- **ShelvesScreen / ShelfFigureCard:** the selected persistent Shelf Unit is a visual 3x3 cabinet.
  Config supplies rows/positions and local slot keys. Three visible selectors display the real
  wrapped indexes. Selection persists by shelf ID until it leaves the shared viewport, then falls
  back to the first visible unit. A details region identifies the row/position and current figure.
  The discovered-only picker pages through six reusable preview cards, so another collection
  adds no permanent picker viewports. The editor holds nine shelf previews plus six picker
  previews. Empty discovery offers Shop. Local browsing stays usable while mutations are pending;
  mutation controls remain gated by canAct and the existing owner/proximity server validation.
- **GoalsScreen / DailyGoalCard:** a three-segment daily requirement, distinct Coin reward ticket,
  claim-ready action, and completed receipt state. Incomplete goals use progress text without a
  disabled pseudo-action. Free-box choices and completion cards come from Catalog. The daily
  reset retains 00:00 UTC wording, with no local timer or streak. Completed collections receive
  a completion label, not a new reward. Another collection requires no screen layout fork.

`SystemState` contains only read-only presentation decisions. All sends retain the existing
Expand, Place, Remove, ShelfPlace, ShelfRemove, ShelfNext, ShelfPrevious, Goal and Daily semantics.
Models are reused by `UIPreview` until their IDs change. No idle or per-frame animation exists.
Button feedback uses the current motion setting; progress changes use a short cancelable tween
owned by UIScope. Root instances and all connections share the existing interface lifetime.

## Automated evidence

`tests/SystemScreens.spec.luau` runs production screen constructors, updates and callbacks with
`SystemUIEngine` stubbing instance/UI/preview primitives. It checks slot counts, slot-four funds,
no actions for slots five/six, selection/Cancel, rates, reservation gating, removal, persistent
shelf-ID payloads, all nine local positions, wrap labels, disabled arrows, discovered-only/zero-copy
picking, page rebinding without new previews, no-discovery navigation, goal states/rewards, daily
claims and Catalog-derived completion. Geometry sweeps cover narrow through large widths, and
5/10/30 collection layouts plus a 1,000-entry picker check future scale. These do not simulate
Roblox rendering, input focus resolution or actual model loading.

Run `python tests/run.py build/tools/luau/luau.exe`, the pinned format/lint/build commands and
Luau LSP diagnostics. In Studio, `tests/StudioSystemScreens.client.luau` is a read-only runtime
structure/model check for the currently open system screen. Neither test helper is mapped by Rojo.

## Manual Studio acceptance (pending)

1. **General:** desktop, narrow window, tablet, phone portrait and short landscape; mouse, touch
   and gamepad Y/B/shoulders/A. Check Close, Motion: low, navigation switching, no clipping or
   overlap with HUD/navigation, and long figure/collection names. Reach the last control by
   scrolling and gamepad selection. Run StudioUI and StudioSystemScreens on each open screen.
2. **Display:** empty/filled/locked; slot four affordable/unaffordable; choose via Collection;
   selected-figure placement, replacement, Cancel, no-spare-copy status and removal. Check total
   and individual rates, matching-set 0/1/2/3, active bonus, and 3/4/5/6 unlocked test states.
   Slots five/six must have no acquisition action. Repeat with delayed replies and paused storage.
3. **Shelves:** empty/full units, all nine positions, three visible selectors, placement,
   replacement/removal, discoveries with zero copies, zero discoveries and multiple picker pages.
   Check three-owned disabled arrows and 4+ fixtures with wraparound. Turn physical arrows from
   another client and confirm persistent-ID selection and stale-request rejection remain correct.
   Repeated snapshots and page switches must not grow the fixed pool of preview instances.
4. **Goals:** 0/1/2/3 unclaimed and claimed; free box ready/claimed and opening handoff; partial
   and completed collections; long Catalog names and more collection entries. Verify reward
   values match server snapshots, no completion rewards are implied, and repeat claims fail.
5. **Lifecycle:** close/reopen and switch screens repeatedly, respawn, interrupt with box opening,
   and compare instance counts. Verify progress transitions stop/settle in reduced motion, all
   controls remain usable without hover, and Studio Output has no errors.

Visual quality and real mouse/touch/gamepad behavior require these native checks. Automated
source, binding and geometry checks are not a substitute for Studio acceptance.

## Verification record for this pass

- Pinned `rokit install --no-trust-check` and `wally install` succeeded. The initial normal
  Rokit attempt stopped on its local trust list; tool versions were not changed.
- `stylua src` and `stylua --check src` passed using pinned StyLua 2.5.2.
- Selene 0.31.0: zero errors/warnings in source and the two Studio UI check scripts, using
  the cached Roblox standard library after the API refresh was unavailable.
- Installed Luau LSP 1.70.1: full source and both Studio UI check scripts passed diagnostics
  with the Rojo sourcemap and installed Roblox definitions.
- `python tests/run.py build/tools/luau/luau.exe`: all suites passed, including 1,152 new
  screen binding/state/geometry checks. UI primitives and engine behavior are stubbed there.
- Rojo 7.7.0 sourcemap and `RobloxWorkspace.rbxlx` build succeeded; `git diff --check` passed.
- The Studio scripts were type-checked but not executed in Studio. No visual or native input
  acceptance, multiplayer playtest, or publication was performed.
