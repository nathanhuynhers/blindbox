# Blindbox Town playtest-readiness remediation

Date: 2026-10-10 (America/Los_Angeles). Starting point: the
[2026-10-09 current-build audit](../../2026-10-09/current-build-audit/REPORT.md), which stays
unchanged as historical evidence. This package records new work and new results only.

**Decision: ready only for specified limited test conditions** (see [Decision](#decision)).
Public release stays on hold.

## Source and environment

- Branch `feat/playtest-readiness` in `.claude/worktrees/playtest-readiness`, based on `master`
  e8c2b69. e8c2b69 changed only audit documents; the gameplay source was the audited 4b50fb76.
- The eight user documentation edits in the main checkout (README.md, ECONOMY, GAME_DESIGN,
  MONETIZATION, PLAYER_PLOTS_AND_SHELVES, PRODUCT_BACKLOG, PRODUCT_BACKLOG_PLAYTEST_2026-10-05,
  ROADMAP) were left untouched. This branch edits ROADMAP.md line 6 only. The user's
  uncommitted ROADMAP hunk is near line 27.
- During this work, another session pushed three commits to master: HUD Daily/Home labels, the
  gear tile shape, and the Shelf auto-scroll toggle (0bb97f9). They were merged into this branch
  (33ce714) without conflicts. Formatting, lint, build, LSP, all 39 Luau suites and 30 Python tests
  were re-run on the merge. A fresh Studio session on the merged build matched all 131 mapped
  scripts, and StudioUI passed on every screen at 666×374, 705×338 and 1279×720
  ([source identity](evidence/source-identity.json)).
- The performance session ran c30c4fe, also with 131/131 scripts matching. Earlier sessions ran
  earlier commits of this branch; each result names its build. Deeper results (multiplayer,
  openings, soak) were not repeated on the merge. The merged commits change HUD labels and the
  Shelf auto-scroll, not those flows.
- The Studio place was the ignored `RobloxWorkspace.rbxlx` (PlaceId 0, unsaved preview). The
  user's other Studio window ("Blindbox Game", PlaceId 94818553489889) was not touched.
- Windows 11 host, Studio version-9b554450a0fc4e65, two 1920×1080 monitors. No physical phone,
  tablet, controller, console or VR device was connected (`GetConnectedGamepads` empty).

### Renderer blocker (B01) root cause

The audit's 1×1 viewport and stalled captures were reproduced and explained:

- Studio reports `Camera.ViewportSize` 1×1 while its window is fully covered by another window.
- Moving or resizing a running Studio window with Win32 calls (MoveWindow or maximize) corrupted
  its layout and left the viewport 1×1 until Studio was relaunched.
- With the user's approval, the test Studio was brought to the front. It rendered at 1529×730 and
  kept a valid viewport after it was covered again. The MCP `screen_capture` then still omits
  ViewportFrame portraits and the 3D stage while the window is covered. Portrait presence was
  therefore checked programmatically (model and camera inside each ViewportFrame).
- Device-simulator coordinate clicks land offset on presets with camera cutouts (A06, iPhone 13,
  iPhone 16 Pro Max). Those sweeps used the menu's bound ButtonY/ButtonR1 keys. They are recorded
  as routing, not as gamepad acceptance.
- The MCP `mouseButtonClick` action did not fire world `ClickDetector.MouseClick` in multi-client
  windows; explicit button down/up did.

## Findings and fixes

| ID | Status | Fix (commit) | Verification |
| --- | --- | --- | --- |
| AQ01 touch controls over menus | **Resolved** | PocketGrove DisplayOrder 10 above TouchGui (popups stay at 90–100). An open screen sets `GuiService.TouchControlsEnabled = false`; every close, screen focus change, teardown and scope destroy restores it (1ef9675) | Reproduced on the current build by reverting both settings at runtime: Sunbeam Sprite blocked at 4/9 sample points and Acorn Dot at 2/9 at 666×374. With the fix, 0 of 198 sample points were blocked. StudioUI now tests 9 points per target, accounting for UICorner and UIScale. Every primary screen passes on the 12 device classes, including Shelves at 749×388 and Display/Equip Best at 959×599. Restore paths verified: close, Collection→Shop route, respawn with a menu open then close (TouchGui enabled, Jump visible, camera Custom on the new humanoid), cinematic exit, Home. The Shelf tap at the old Jump location landed |
| AQ02 compact Display overflow | **Resolved** | Narrow cards (<146px) stack Unlock above its price, move the shortfall to its own wrapped line and give the bank its own "N ready" line (89799a3). Long names wrap on narrow cards (89df9a2) | A real-component fixture ran 64 cases: 666×374, 705×338, 899/900/901×700 and 1000×559/560/561 × eight states (natural; zero balance with full Display and 1.23M banks; 400K and 4M shortfalls; 9.99B affordable; pending; placing; choosing). Zero fails. The probe flags all three original symptoms when the old layout is restored. Live native checks: unlocks 4/5/6 at 666×374 charged 40K/400K/4M once each, including a double-click |
| AQ03 income unit | **Resolved** | Value is always the short `+4.73/s`; the label carries the unit ("Earns coins" on desktop, "Earns" on phone) (539989b) | Pebble Pip ×2 (natural, 4.73/s): 51 cases across 17 viewports (1279/1280/1281×720, 1023/1024/1025×768, 899–901×700, 1000×559–561, phones, 1919×1079, 2560×1440) × normal, +98.7K/s ×999 and +9,999/s. Zero fails. The old string reproduces the audit's numbers (TextFits false, 47×18 in 90×22). Full screenshots and close-ups were retained |
| AQ04 batch names | **Resolved** | Tapping, hovering or controller-selecting a result tile writes "Name · Rarity [· NEW!] [· ×N owned]" into a caption under the title and highlights the tile. Before any selection the caption reads "Tap a figure for its full name" (4f24956) | Native taps named "Sprout Scout · Common · ×3 owned" and "Sunbeam Sprite · Rare · NEW!" on the Welcome x10, and "Reminiscence Star · Common · NEW!" on a paid We Are All Stars ten (666×374). 35 real-module cases (7 viewports including 900×419/420/421 × Welcome, 13-figure long names with duplicates, paid Tender Echoes, a 3-figure login reward, a single result) named every tile via controller selection. NEW semantics, all ten tiles, 44px targets and no overlaps held |
| AQ05 stale guidance and fixture | **Resolved** | ROADMAP schema 14; OPERATIONS schema-14 migration step; BRIEF and IMPLEMENTATION use sequential coin unlock (BRIEF keeps a historical note); OPENING marks Redeem retired; StudioSystemScreens asserts the sequential six-slot contract (1b90716) | Corrected fixture passes on the current build at 3/6 (fresh multiplayer client) and 6/6 (after native unlocks). Schema 14 confirmed in Profile.luau/Rules.luau; Redeem rejection covered by Opening.spec and Mvp.spec |
| DR01 Goals claim discoverability | **Improved** | "Claim below" header button appears only while a ready Goal or free box button is below the fold, and scrolls it into view (29e311b) | Native at 666×374: the cue appeared for the ready free box; one tap scrolled "Open free box" into view and the cue hid itself. StudioUI passes on Goals for all 12 classes |
| AQ06 (new, P2) Welcome Box label overflow | **Resolved** | Phones show "Open Welcome Box"; FREE! tag unchanged (e139faa) | Found in the fresh journey: row 270px in a 236px button at 666×374. Fixed: row 188px, inside, at 666×374 and 705×338 |
| AQ07 (new, P3) narrow-card names | **Resolved** | Two-line names, slightly smaller portrait on narrow cards (89df9a2) | 7 of 43 names truncated before. Live Display at 666×374 shows "Page Turner Star" on two lines; 14 visible names untruncated at 4 sizes |
| AQ08 (new, P3) picker and Goals row names | **Resolved** | Picker names get two lines and columns adapt to keep ~96px (eea7737, c30c4fe); Goals rows shrink 15→12px like their title | Sweep found "Reminiscence/Mirrorlight/Wishing/Page Turner Star" truncated in the picker and "We Are All Stars" at 959×599. After the fix: 0 truncated picker names at 666×374, 705×338, 1023×768 and 1279×720; StudioUI pass |

Observations not changed (design questions, not defects):

- **O1:** during an Open 10, the first reveal's progress chip already shows the post-batch total
  (e.g. "6 of 13 found" on reveal 1), because the confirmed snapshot arrives before the reveals.
- **O2:** the Welcome Skip confirmation ("Sure?") expires after a few seconds. Two quick taps work;
  a slow second tap restarts the confirmation.
- **O3:** many long names still truncate on small Collection/summary tiles by design. The detail
  pane, the AQ04 caption and the picker now show them in full.

## Player experience and regression

[Walkthrough](WALKTHROUGH.md) covers the native fresh-player journey and the progressed,
multiplayer and service results. [Coverage](COVERAGE.md) lists every surface with
Pass/Fail/Blocked/Not run/Not applicable and links the evidence.

Highlights:

- **Fresh journey (native, no grants or bypasses, 666×374 touch preset):** Welcome Box → Moon Moth
  → Put on Display → W/A/S/D onto the plate (+532) → paid Grove (1,500 once) → Keep → Welcome
  x10 via Skip → summary names → Done to Shop → Shelf placement (step 7) → Goals cue → Day 1
  (+500 once under a double click) → Reduced motion → Home.
- **Device baseline:** 12 classes × World, Collection, Display, Shop, Goals, Shelves, Login and
  Settings. All executed StudioUI runs passed. Login/Settings were not run on three cutout
  presets because of the pointer offset ([sweep 2](evidence/device-sweep-session2.json),
  [sweep 3](evidence/device-sweep-session3.json)).
- **Two real clients:** visitor protections exercised natively (prompt hidden, E inert, plate
  inert, server-confirmed MouseClick denied), owner collect +562, concurrent paid buys charged once
  each, per-player deal stock 3→0 with sold-out UI while the other player kept 3, synthetic
  malformed/stale probes caused no mutation, Kick removed the plot and a new player reused slot 2
  ([multiplayer](evidence/multiplayer-session4.json)).
- **Openings:** 20 paid Open 10s and 6 paid singles (3 through plaza deals), across Pocket
  Grove, Tidepool Tales, Verities, Tender Echoes and We Are All Stars, each charged once. Native Skip at Await, Charge and Shake,
  Next figure, View all results and Done worked, and resources were cleaned up afterwards.
  StudioOpeningLayout passed on Common/Uncommon/Rare results at 1279×720 (246–292 checks each). A
  Legendary (Meteor Shower) rolled naturally but was skipped. **Legendary and Mythical reveal
  presentations were not observed** ([openings](evidence/openings-session3.json)).
- **Performance (single client, 1279×720, Studio in front):** see [Performance](#performance).

## Checks run

| Command / check | Result |
| --- | --- |
| rokit install; wally install | Pinned tools present (rokit 1.2.0, wally 0.3.2, rojo 7.7.0, stylua 2.5.2, selene 0.31.0, luau-lsp 1.70.1); no packages; wally.lock rewrite was line-ending only and was restored |
| stylua src; stylua --check src | Pass |
| selene src | 0 errors, 0 warnings, 0 parse errors |
| rojo build default.project.json -o RobloxWorkspace.rbxlx; rojo sourcemap | Pass |
| luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=…PluginSecurity.d.luau src | Exit 0, no diagnostics; watcher-registration warning only |
| python tests/run.py build/tools/luau/luau.exe | All 39 suites pass, including the new Screens.spec checks (touch ownership across 11 viewports, narrow Display cards at 8 sizes, income unit, summary caption for all 10 tiles). "Expected cleanup fault" is an intended fixture line |
| python -m unittest discover -s tests -p "test_*.py" | 30 tests OK |
| git diff --check e8c2b69 HEAD | Pass |
| StudioUI (updated: 9-point hit order, corner/UIScale-aware, touch ownership) | Pass on every executed screen/device record |
| StudioSystemScreens (corrected) | Pass at 3/6 and 6/6 |
| StudioOpeningLayout | Pass on 3 rarities |
| StudioScroll / StudioShop / StudioCollection | Not re-run (no scroll or Shop/Collection list logic changed; the StudioUI scroll-canvas checks ran) |

## Performance

Single client, Studio in front, fixed 1279×720 (hd_720 preset), UIScale 1. Progressed fixture
state: 30–80 owned copies across 5 collections, 6/6 Display full, 1 plot occupied. This is a
Studio editor client on the Windows host, not a phone benchmark.

- **Menu repetition:** 3 warm-up cycles, then 10 measured cycles of all five dock screens. Afterward
  GUI descendants 4,830→4,830, PlayerGui 4,988→4,988, workspace 4,735→4,735, Stats.InstanceCount
  59,745→59,745, memory 2,698.7→2,697.0MB, touch controls restored.
- **Repeated openings:** 3 paid Open 10s added 31 GUI descendants (picker/Collection pool growth
  for a newly owned figure). 2 further batches with no new figure types left GUI 4,861→4,861 and
  instances 59,776→59,776. No opening GUI, stage or summary remained; camera Custom.
- **Idle soak (30m22s, idle in the world, 182 ten-second windows):** FPS median 60.0 (min 58.6),
  p95 frame time median 18.0ms (max 18.2ms), worst single frame 267ms (one window near 15 min).
  Instances 59,776 and GUI 4,861 unchanged start to finish. Memory fell from 2,730MB to a flat
  2,328–2,350MB after collections. No growth trend. Studio was brought forward before sampling
  but was not continuously verified to stay uncovered
  ([performance](evidence/performance-session4.json)).

Not run: low/high graphics comparison (would change the user's Studio/Roblox quality setting),
eight occupied plots (2-client test only), full Shelves, network metrics, physical hardware.

## Blockers

| ID | Now | Evidence / exact need |
| --- | --- | --- |
| B01 renderer | **Partly closed** | Root cause above; rendered acceptance obtained with Studio visible. 3D/ViewportFrame screenshots still need the Studio window uncovered during capture |
| B02 physical touch/controller/console/VR | Blocked | No device connected. Needs a phone/tablet running the Roblox client, a connected controller (check `LastInputType` Gamepad1) and console/VR hardware if enabled |
| B03 enabled platforms/languages | Blocked | PlaceId 0. Inspect the existing experience's Configure > Places/Localization settings (owner action) |
| B04 real persistence | Blocked | No authorized isolated test experience was provided. Follow OPERATIONS steps 4, 12 and 13 in a private test experience with isolated stores. The "Blindbox Game" place was not used without authorization |
| B05 real day/hour boundaries | Blocked | Domain suites pass; real-clock acceptance needs a later session or an authorized clock-injection task |
| B06 StudioSystemScreens | **Closed** | Corrected fixture passes at 3/6 and 6/6 |
| B07 reference rendering | Not run | No mockup pixel comparison was needed for these fixes |

Additional open gates: Legendary/Mythical reveal tour (run `tests/StudioOpening.client.luau` from
Studio's own Command Bar), day/night and low/high graphics opening checks, subjective audio
listening, eight-plot load, rotation recovery on a device, focus loss/resume, and GUI-recreation
during play (the teardown path restores touch controls by code and unit test only).

## Decision

**Ready only for specified limited test conditions.** Run the next controlled playtest when:

1. Testers use desktop/laptop or phones/tablets in landscape on the current build, with an
   observer noting the device. Physical touch and controller behavior are being observed, not
   certified.
2. Progress is treated as disposable. Real DataStore save/rejoin, offline earnings across a
   rejoin and migration have not been accepted (B04). Use a private test experience with isolated
   stores, or tell testers progress may be wiped.
3. No premium purchases, trading or other unimplemented proposals are in scope.

All five audit findings and DR01 are resolved with rendered, native and fixture evidence, and no
P0/P1 failure was observed. That does not prove none exist.

**Public-release holds (separate):** B02–B05; Legendary/Mythical presentation tour; low/high
graphics and eight-plot performance on target hardware; audio listening; enabled-platform and
localization configuration.

## Changed files

Source: `src/client/Interface.luau`, `DisplaySlot.luau`, `UIButton.luau`, `CollectionScreen.luau`,
`PullSummary.luau`, `GoalsScreen.luau`, `ShopScreen.luau`, `FigureTile.luau`,
`DisplayPicker.luau`. Tests: `tests/StudioUI.client.luau`, `tests/StudioSystemScreens.client.luau`,
`tests/Screens.spec.luau`. Docs: `docs/ROADMAP.md`, `docs/OPERATIONS.md`, `docs/OPENING.md`,
`docs/ui-redesign/BRIEF.md`, `docs/ui-redesign/IMPLEMENTATION.md`, and this package.

Commits: 1ef9675, 89799a3, 539989b, 4f24956, 29e311b, 8506208, 1b90716, e139faa, 89df9a2,
eea7737, c30c4fe, de54c87, the master merge 33ce714, and the commit that adds this package. The
branch is not merged into master: the main checkout's uncommitted ROADMAP.md edit must be
committed or stashed by its owner first.

## Cleanup

Studio fixture modules lived only in ReplicatedStorage during Play and were never saved. Device
simulation, test servers and the multiplayer session were ended. The test Studio was left on the
worktree build in Edit. The user's other Studio and the main checkout's uncommitted edits were not
changed.

## Next manual actions

1. In a private test experience with isolated stores, run OPERATIONS persistence steps 4, 12 and 13.
2. On a real phone and with a controller: Shelves/Display/Equip Best taps near the Jump area,
   Back/B, focus, and rotation recovery.
3. From Studio's Command Bar, run `tests/StudioOpening.client.luau` and tour Legendary and
   Mythical in normal and reduced motion, day and night.
4. Listen to openings at both volumes; measure low/high graphics with several occupied plots on
   target hardware.
5. Review O1/O2 as design choices.
