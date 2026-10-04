# UI redesign: implementation

Status: **implemented and merged into `master`; remaining Studio acceptance is listed below.** The design source
is [BRIEF.md](BRIEF.md) and the [mockup](mockup/). This file maps the code and lists the Studio
checks. It consolidates the useful implementation notes from the retired screen-specific UI docs.

The UI work itself changed no server, shared economy, Protocol, persistence or Types code;
those came from the merged economy redesign. The client sends no `Recycle`, `Redeem` or
`Collect` (collection is a world interaction) and shows no Scrap.

## Module map (`src/client`)

| Module | Owns |
| --- | --- |
| `init.client.luau` | Remotes, the single pending intent and retry, reply feedback, opening hand-off, dispatching Reveal choices |
| `Interface` | ScreenGui (DeviceSafeInsets), desktop `UIScale` stage, world dim, HUD, dock, the five screens, routing (`navigate(id, route)`/`close`), gamepad Y/B/L1/R1, selection ring, scroll-into-view |
| `UIState` | **The economy projection.** Formatting (exact, `compact` 2.4M, rates, %), price/odds/rate/set bonus/free-box options/slot price/goal reward, completion, filters, picker sort, placement/swap, Reveal model, dock badges, countdown |
| `UILayout` | Pure geometry: desktop reference 1280×720 scaled 1–2×, phone landscape sheet, dock, HUD, panes |
| `UIStyle` | Tokens (ink, surfaces, violet, gold, mint, alert, dim, reveal, wood), fonts (Fredoka/Nunito with a Gotham switch), collection accent table with neutral fallback |
| `UIKit` | Instance primitives: frame/text/image/list/grid, measured `scroll` (Scroll.bind), manual `canvas`, hard-shadow `card` |
| `UIButton` | Gold/violet/mint/white/ink/selected/ghost buttons, press drops the shadow (tween only with Motion on), disabled look + detail line, optional price pill |
| `UIBadge`, `UIProgress`, `UIIcons` | Pills/chips/rarity pill/corner badges; bar and segments; frame-drawn icons including the coin glyph |
| `ScreenShell` | Panel/sheet, 76px header (56 phone): nav icon, title, subtitle, right chips, round Close; phone coins chip |
| `Dock` | Five tiles, active raised on violet wash, Display/Shop/Goals badges |
| `Hud`, `SettingsMenu`, `GoalTracker` | Coins pill beside `GuiService.TopbarInset`; gear popover with Motion and a session-only Sound On/Off; desktop goal card / phone "Goal done · Claim" chip |
| `Sfx`, `Music`, `SoundManifest` | Client sounds and background music: one manifest of IDs and levels ([game soundpack](../SOUND.md)) |
| `CollectionList`, `FigureTile` | Shared collection list item (rail on phone); figure card/tile/pick/shelf variants, pooled and rebound |
| `ShopScreen` | List, kept `BlindBoxPreview`, Open 1 box, free box, What's inside, Drop odds |
| `CollectionScreen` | List, All/Found/Missing, 4-column grid, detail with Put on Display / On your Display · View / Find it in … boxes |
| `DisplayScreen`, `DisplaySlot`, `DisplayPicker` | Income chip, set-bonus banner, 6 slots (slot 4 unlock, 5–6 Coming later), picker drawer sorted by earnings with BEST, Remove, Browse Collection, placing mode |
| `GoalsScreen` | Unclaimed daily goal (empty state after claim), free box chooser, collection progress, minute countdown from `nextDay` |
| `ShelvesScreen` | Shelf tabs + prev/next, 3×3 cabinet, discovered-figure picker with collection chips, Clear spot |
| `LoginScreen` | Daily Login (routed by `Interface` without a dock tile; HUD Daily button with a "!" badge): one card per `LoginRewards` day (claimed mint / today violet outline + TODAY / locked), wider gold final day, streak chip, Claim. Auto-opens once per session on the first ready snapshot when claimable, except for players who own no figures |
| `RevealCard` | End-of-opening card: NEW (first discovery only), name + rarity pill, chips, owned count, Put on Display / Swap, Open another (price or shortfall), Keep |
| `OpeningView` | Kept Tap to Open, Skip, hint and curtain; the Result panel is now `RevealCard` |
| `OfflineEarnings` | Welcome-back card (white card, gold Claim) for offline Display Coins; Claim or tapping outside sends `ClaimOffline` |
| `OpeningController` | Kept phases, camera, Skip and input ownership; adds an optional `choose` callback (runs after the session fully closes), a Reveal model on `present`, and `refresh` for live affordability |
| Kept as-is | Opening cinematic/audio/state/box modules, `BlindBoxPreview` (now on `UIKit`), `BlindBoxSkin`, `ShopTheme` (3D box only), `UIPreview`, `UIScope`, `Scroll` (now scale-aware), `NavigationConfig` (simplified), `Notifications` (restyled) |

Deleted: `BackgroundTreatment`, `CollectionArt`, `CollectionAssets`, `CollectionControls`,
`CollectionLayout`, `CollectionSelection`, `CollectionSkin`, `CollectionStyle`, `CollectionTabs`,
`DailyGoalCard`, `DisplaySlotCard`, `FigureCard`, `FigureDetails`, `Navigation`,
`NavigationButton`, `ShelfFigureCard`, `ShopArtwork`, `ShopBox`, `ShopCollectionCard`,
`ShopLayout`, `ShopProductStage`, `ShopState`, `ShopStyle`, `SystemLayout`, `SystemState`,
`SystemStyle`, `UITheme`, `Widgets`.

## Behaviour notes

- **Snapshots are the only truth.** Screens render snapshots and send intents through
  `ctx.send`; Coins and inventory never change optimistically. While a request is pending (or
  the opening holds focus) every mutating button is disabled.
- **Rendering cost:** only the open screen receives snapshot updates; hidden screens refresh
  when opened. A screen re-lays out only when the panel size or phone mode changes. Pools
  (tiles, picks, shelf cards) grow to the largest list seen, bounded by the catalog, and are
  reused. There are no per-frame loops; the Goals countdown uses one `task.delay` that fires on
  minute boundaries only while Goals is visible.
- **Scaling:** desktop lays out in 1280×720 design units under one `UIScale` (1–2×), so 44px
  targets never shrink. `Scroll.bind` divides `AbsoluteContentSize` by that scale so canvases
  are neither short nor inflated.
- **Reveal choices:** Put on Display places in the first empty slot. When the Display is full,
  the card offers "Swap for <lowest earner>" only if the new figure earns more. Open another
  buys the same collection's box in one tap; it is disabled with "Need N more" when
  unaffordable. Keep (B, or A/Enter with nothing selected) returns to whatever screen was open.
  Each choice is sent only after the opening has closed and released focus.
- **Collection → Display:** Put on Display places directly when a slot is empty. Otherwise it
  opens Display in placing mode, where tapping a slot swaps the figure in. Display's picker has
  Browse Collection, which opens Collection with that slot as the target ("Put in slot N").
- **Phone landscape** (height < 560 or width < 900): near-full-screen sheet right of the Roblox
  buttons, 56px header with a coins chip, icon-only collection rail, and the dock hidden while
  a sheet is open.
- **Decisions not dictated by the mockup:**
  - The HUD goal card's Claim button and the phone goal chip claim directly; the rest of the
    card opens Goals.
  - Filter chips, slot buttons and choices are at least 44px tall, even where the mockup drew
    them at 34–40px.
  - Shelf collection chips scroll horizontally instead of collapsing into "More…".
  - The inactive set-bonus banner shows progress ("2 of 3") but no amount. Master only sends
    the bonus once it is active.

## Economy integration (merged from master)

The economy redesign is merged. Its snapshot fields are read only in **`UIState`'s "Economy
fields" section**:

| Function | Reads | Shown as |
| --- | --- | --- |
| `price(snapshot, collection)` | `prices[collection]` | Open 1 box / Open another price and "Need N more" |
| `figureRate(snapshot, id)` | `rates[id]` (effective, duplicates included) | Earns, picker sort, swap gain, slot rate |
| `figureOdds` / `baseOdds` | `odds[id]` (current, with luck) / `baseOdds[id]` | Box chance; Drop odds rows add "· base X%" when luck raises a chance |
| `totalRate`, `bonusAmount` | `rate`, `bonus` (Coins/s, server applies the %) | Header income chip, set-bonus banner amount |
| `earnings(snapshot, id)` | `earnings[id]` | Display slot "N ready" |
| `freeBoxOptions` | `{ dailyCollection }` | Goals hides the chooser; Shop shows "Claim free <name> box" |
| `unlockPrice`, `lockedText` | `expansionCost` for slot `unlocked + 1` | Unlock with price; later slots say "Unlock slot N first" |
| `goalReward` | `goalReward` | Goal card and HUD tracker |

What else the merge carried over:

- `UIState.copies` follows the server's one-placement-per-figure rule, so extra copies never
  offer a second slot.
- `init.client.luau` shows server-initiated `collect:` replies as toasts. `DisplayInteraction`
  routes the nearby owner-only management prompt into Display and updates the collection plaque
  for mouse/touch input. Per-figure ClickDetectors handle collection on the server.
- The Display subtitle and HUD toast explain collecting (click or tap each figure on your plot);
  E nearby manages Display.
- `OpeningResult` no longer accepts Redeem. That change came from master.
- Number fields are sized for abbreviated values. The HUD balance switches to `compact` at
  10M; prices, rates and shortfalls always use `compact`/`amount` (2.4M).

## 3D box preview

The Shop keeps one reusable 3D preview cloned from the sanitized
`ReplicatedStorage.ProductionModels.BlindBoxBase` template. The generated asset manifest resolves
the source asset, the server validates and publishes the template, and the client waits for its
complete replicated geometry before showing it. Collection changes reskin the same preview; stale
asynchronous results, timers, connections and owned clones are cleaned up through `UIScope`.

`BlindBoxSkin` binds semantic parts even when the importer inserts Model wrappers. It applies the
approved panel textures and emblem Decal, removes layers that can mask tint, and derives the fixed
camera from the model bounds and semantic faces. Loading and unavailable states are mutually
exclusive with the viewport. Failures expose `PreviewStatus`/`PreviewReason`, with the server-side
reason on `BlindBoxBaseReason`. The currently configured source asset is `79870100381887`, owned by
creator user `103346374`.

## Navigation image import and missing images

Rojo does not upload the five PNG files under `assets/ui/navigation/`. If a navigation semantic
key has no generated asset ID and no valid entry in `src/shared/NavigationAssetIds.luau`,
`AssetManifest.resolve()` returns an empty string and the icon intentionally does not render. The
runtime icon hierarchy, sizing and transparency are not a substitute for a Roblox-hosted image.

Import the Collection, Display, Shop, Goals and Shelves PNGs as **Image** assets in the experience's
Asset Manager, wait for moderation, then paste each numeric asset ID (without `rbxassetid://`) into
the matching field in `NavigationAssetIds.luau`. The module validates and prefixes IDs centrally;
the generated asset pipeline remains a fallback. Restart Play after syncing, verify all five icons
on desktop and phone-landscape layouts, and check Studio Output for ownership, permission or
moderation failures. Construction emits one warning per missing ID.

## Automated checks

`python tests/run.py <abs path>/build/tools/luau/luau.exe` runs:

- `UI.spec` (projections, formatting, layout geometry, nav and 3D themes, scope).
- `Screens.spec`: the real Interface, screens and components on `tests/UIEngine.luau`. It
  covers routing, every intent the UI sends, pending locks, gamepad B/Y/L1/R1, phone sheet
  rules, the countdown timer lifetime, no instance or connection growth across 25 screen
  cycles, Reveal card states, and teardown.
- `OpeningLifecycle` (adds Reveal choice timing: after close, guard, Keep/B/cancel send nothing).
- `Scroll.spec` (scale-aware canvas).

The engine double does not render, measure text, resolve fonts or images, or run layouts.

## Studio visual review (2026-10-02)

The first Studio pass used the MCP on mainline at 1529×770 (UIScale 1.07), plus a phone-landscape
preview made by shrinking `SafeArea` to 844×390. It confirmed that Fredoka and Nunito both
resolve. The Reveal flow worked end to end (Put on Display, Open another, Keep). Fixes from that
pass:

- **Panel height:** the desktop panel now ends 26px above the dock (496px tall at the
  reference), so its shadow clears the raised active tile and its badges.
- **Side columns** (`UIKit.column`): only the outer bottom corner is rounded, so the fill no
  longer pokes past the panel corner. A divider marks the inner edge.
- **Rarity edge:** the rarity colour is now the well's rounded bottom edge (cards, contents
  tiles, Collection detail), matching the mockup's border-bottom.
- **Grid outlines:** grids pad their canvas by 5px so card outlines and shadows aren't clipped.
- **Scrollbars:** manual canvases only scroll on real overflow (`Kit.fit`).
- **Screen-specific fixes:**
  - The shell subtitle appears once a screen sets its text.
  - Display uses 176px slots. With no slot chosen, the picker lists your figures: tapping one
    fills the next empty slot, or enters placing mode when the Display is full.
  - Goals' single daily collection fills the free-box card with its emblem and progress.
  - Shelves hides the filter chips until something is discovered.
  - Collection opens on the first found figure. Its "Find it in … boxes" action uses the
    quieter body type so long names fit, and compact (phone) cards keep both text lines.
  - On phone, the Shop box title wraps.
- **Reveal:** the NEW badge sits above the name, clear of the figure, with the rarity pill
  right beside the name.
- **Toasts:** with a screen open on desktop, toasts show above the panel rather than over its
  buttons.
- **Gear icon:** it now reads as a gear.

Open question for design: the server only accepts Place/Remove within ~15 studs of your own
Display (`PlayerPlot.nearDisplay`). The Reveal card's Put on Display, the Display picker and
Collection's Put on Display therefore fail with "Walk closer to your own Display" when used
elsewhere, for example at the Shop stall right after opening a box.

## Studio checklist (not yet run)

Sync with `rojo serve --port 34873` (not the other checkout's port). Run at **1280×720**,
**1920×1080** and **phone landscape** (Device emulator, e.g. iPhone 14 landscape, plus 667×375).
Paste the scripts in `tests/Studio*.client.luau` into the client Command Bar where noted.

1. **Fonts:** titles/numbers in Fredoka, body in Nunito. If either family falls back, set
   `gotham = true` in `UIStyle`.
2. **HUD:**
   - The Coins pill sits right of Roblox's buttons, with the exact balance and "+N/s".
   - Tapping it shows the exact value.
   - The gear popover toggles Motion (Full/Reduced), and outside taps or B close it.
   - The goal card shows progress and claims when ready.
   - On phone the "Goal done · Claim" chip appears only when the goal is ready.
   - With no screen open, nothing else covers the world. Run `StudioUI` here.
3. **Dock:**
   - Badges: Display "N empty", Shop FREE, Goals 1.
   - The active tile is raised.
   - The dock stays visible on desktop with a screen open and hides on phone sheets; Close
     restores it.
4. **Shop:**
   - Every collection shows the right box skin.
   - Open 1 box is affordable, or disabled with "Need N more" when not.
   - Claim today's free box appears only when ready.
   - Contents tiles open Collection.
   - Odds rows total about 100%.
   - Run `StudioShop`.
5. **Opening → Reveal:**
   - The animation, camera and Skip are unchanged.
   - NEW shows only on first discovery; duplicates show "You own ×N".
   - Put on Display with an empty slot places the figure.
   - With a full Display, Swap appears only for a better earner, and swaps out the lowest.
   - Open another starts the next opening in one tap. When unaffordable it is disabled with
     the shortfall, and it updates live as the balance changes.
   - Keep returns to the previous screen state.
   - Gamepad: A presses the selected choice, B keeps.
   - Reduced Motion still reaches the card.
   - Run `StudioOpening` comparisons (the rarity pill must match the tier).
6. **Display:**
   - Header income and set-bonus banner (on/off).
   - Tapping a slot opens the picker: BEST on top, Cancel works, a filled slot offers Remove.
   - Browse Collection → Put in slot N.
   - Slot 4 Unlock is affordable, or disabled with the shortfall; slots 5–6 say Coming later.
   - Collection Put on Display with a full Display enters placing mode.
   - Filled slots show "N ready" as earnings bank. Collecting in the world (click or tap) shows a
     toast and resets only that figure's count. Other players' management prompts stay hidden.
   - Run `StudioSystemScreens`.
7. **Collection:**
   - All/Found/Missing counts.
   - Undiscovered cards show "?" and "???"; ×N and ON DISPLAY tags.
   - Detail actions for each state; Find it opens that Shop collection.
   - Run `StudioCollection`, and `StudioScroll` on Tender Echoes/We Are All Stars.
8. **Goals:**
   - The countdown changes once a minute, and only while Goals is open.
   - Claim; the free box chooser plus Open free box; progress rows open Collection.
9. **Shelves:**
   - Tabs; prev/next disabled with exactly three shelves (enabled with more).
   - Spot selection, place, swap, Clear spot, collection chips.
   - The subtitle says shelves are cosmetic.
10. **Gamepad everywhere:**
    - Y opens or closes the last screen, B goes back (picker or popover first), L1/R1 cycle,
      A activates.
    - The selection ring is visible, and selected items scroll into view.
11. **Reset during opening:** reset or respawn mid-opening. The UI and input restore, and no
    Reveal choice is sent.
12. **Repeated switching:**
    - Run `StudioUI` on a screen, switch screens 20+ times, return and run it again: it fails
      on descendant growth.
    - Also watch the Developer Console memory for steady instance counts.
13. **Two clients:** each player's HUD, Display and Shelves reflect only their own snapshot.
