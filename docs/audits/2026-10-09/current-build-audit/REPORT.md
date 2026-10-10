# Blindbox Town current-build audit

Audit date: 2026-10-09 (America/Los_Angeles). Final review: 2026-10-10 UTC.
**Recommendation: continue isolated testing; hold public release acceptance.** The ordinary Welcome Quest completed successfully, but touch controls obstruct menu targets, compact Display content overflows, and critical hardware/persistence/edge-state gates remain open. No P0 or P1 failure was established in the executed cases. That is not evidence that those failures cannot exist.

This task produced audit artifacts only. No game source, tests, dependencies, economy, production records, API-access setting or published experience was changed.

## Exact build and evidence boundary

- Branch: master. Commit: 4b50fb76debb34507e0bc6a6b242a26d501412be.
- Eight pre-existing documentation changes were preserved: README.md; docs/ECONOMY.md, GAME_DESIGN.md, MONETIZATION.md, PLAYER_PLOTS_AND_SHELVES.md, PRODUCT_BACKLOG.md, PRODUCT_BACKLOG_PLAYTEST_2026-10-05.md and ROADMAP.md. They do not change the Rojo-built scripts.
- Tested place: ignored build/audit-2026-10-09.rbxlx, built with pinned Rojo 7.7.0. Original audit Studio ID: 699754e3-3629-4a24-a30a-61954502d507. The user's other Studio instance was left untouched.
- All 131 mapped script sources matched repository text using normalized line endings, length and a rolling hash. See [source comparison](evidence/source-comparison.json). This checks source identity, not published asset provenance.
- GameId and PlaceId were 0. Persistence reported “Studio preview - not saved”; StudioPersistenceTest was not enabled. Schema 14 is implemented. No real save/rejoin, migration or offline-service acceptance was claimed.
- Current scope: 43 figures, five collections, all five rarity identities, Display slots 3–6, cosmetic Shelves, Welcome Quest, daily/login/offline rewards, Shop/Open 10, hourly per-player plaza deals, Home, settings, public plots and global leaderboard presentation. Trading, premium purchases, visit directories, customization and other proposed roadmap features are outside the implemented scope.

[Coverage](COVERAGE.md) distinguishes visual inspection, native input, engine fixtures, synthetic remotes and mocked regressions. [Walkthrough](WALKTHROUGH.md) records the natural journey before fixture grants.

## Prioritized findings

| ID | Priority | Category | Finding |
| --- | --- | --- | --- |
| AQ01 | P2 | Input / mobile UI | TouchGui overlays selectable menu targets |
| AQ02 | P2 | Spacing / text | Six-across compact Display squeezes price controls and rate badges beyond their cards |
| AQ03 | P2 | Text / information | Collection income stat loses its unit in some desktop/tablet layouts |
| AQ04 | P2 | Text / usability | Welcome x10 summary truncates figure identities with no visible detail interaction |
| AQ05 | P2 | Documentation / verification | Current schema and six-slot behavior conflict with active reference/checklist text |

AQ01–AQ04 are current observations, not recycled historical screenshots. AQ03's retained visual evidence is incomplete: its full screen was viewed in the session, but its JPEG and crop could not be recovered after capture stopped working. That limitation is explicit below.

### AQ01 — Touch controls obstruct menu targets

**Affected state/device/input:** populated Shelves at effective viewports 666×374 and 749×388/389; Display at 959×599. Studio touch-control presentation and native engine hit testing. Physical finger activation was unavailable.

**Prerequisite:** this build, active mobile/tablet emulator, six Grove figures discovered; for Display, at least one owned figure and the Equip Best button visible. The natural journey produced the required inventory.

**Reproduction:**
1. Use the iPhone 7 preset in landscape; open Shelves and leave the picker at its initial scroll position.
2. Inspect Sunbeam Sprite at the bottom-right of the picker and the Jump button over it.
3. Run the existing StudioUI fixture. It reports the selectable grove.star target behind TouchGui.TouchControlFrame.JumpButton.
4. Repeat on iPhone 13. On the small-tablet preset, open Display and inspect Equip Best.

**Expected:** menu actions retain the intended touch target and input priority while the menu is open. **Actual:** Jump is visibly above the picker/action. Native hit testing selects Jump at the intended control's center. The same symptom appeared visually over parts of other controls, but only the three center-hit failures are counted as confirmed obstructions.

**Evidence:** [full Shelves screen](evidence/iphone7--Shelves.jpg), [close-up](evidence/AQ01-touch-closeup.png), [full small-tablet Display](evidence/smalltablet--Display.jpg), [Display close-up](evidence/AQ01-display-closeup.png), [measured failures](evidence/finding-measurements.json). Effective safe rectangles are 666×374, 749×388/389 and 959×599; UIScale 1. Raw GUI origins include the -58 top-bar coordinate offset, which is not itself clipping.

**Impact/frequency:** significant accidental-jump or failed-selection risk; reproducible in three tested screen/device combinations. Some controls remain reachable at an uncovered edge or after scrolling, so widespread inability to play is not established.

**Root cause confidence: confirmed layering/hit order; suspected complete implementation cause.** PocketGrove uses the default ScreenGui DisplayOrder while the engine's TouchGui remains active. Interface's modal backdrop does not remove these touch controls. See C:/Users/natha/Documents/RobloxWorkspace/src/client/Interface.luau:91 and tests/StudioUI.client.luau:357.

**Focused recommendation:** give menu content a deliberate layer/input policy above world controls, or suppress world touch controls while a modal owns input and restore them on every exit. Do not only move the affected button.

**Acceptance:** native finger taps at center and edges on the failing phone/tablet sizes and neighbors must activate the intended action; opening/closing, respawn, Home and cinematic transitions must restore world movement. Run whole-target overlap checks in addition to the existing center check.

### AQ02 — Compact Display price and rate content exceeds its card

**Affected state/device/input:** 666×374 phone Display with Moon Moth occupied, 3 unlocked slots, Coins 4,038, next price 40K and shortfall 35.9K. Similar compact-card pressure is visible on the short phone. A rate fit failure also occurred at 1279×720.

**Reproduction:**
1. Complete the natural journey, leave Moon Moth displayed and accumulate a few thousand Coins in its bank.
2. Open Display on the iPhone 7 landscape preset.
3. Inspect slot 4's disabled Unlock control and slot 1's income/ready badge at normal viewing size.
4. Compare the full screenshot with its crops; inspect TextFits and the automatic-size price row.

**Expected:** label, coin icon, price, shortfall and bank value stay inside their own containers with comfortable padding. **Actual:** the Unlock label extends beyond its narrow button and crowds the coin/40K pill; “Need 35.9K more” has no comfortable horizontal room. The ready badge extends beyond the earning card. This is visible overflow, not solely a TextFits assertion.

**Evidence:** [full Display](evidence/iphone7--Display.jpg), [Unlock crop](evidence/AQ02-text-closeup.png), [rate crop](evidence/AQ02-rate-closeup.png), [cross-size full screens](evidence/display-contact.png), [measurements](evidence/finding-measurements.json).
At 666×374, scale 1, the recorded shortfall is “Need 35.9K more” in an 85×17 text container and rate text “+10.95/s · 3,851 ready” in 109×26. Both reported TextFits false. The screenshot was captured slightly later and shows 3,873 ready because income continues accruing.

**Impact/frequency:** P2 financial/progression clarity and cramped interaction; confirmed in the small-phone screen, with neighboring short-phone visual pressure. The balance and price still identify their numeric values, and desktop unlock purchases succeeded.

**Root cause confidence: confirmed.** DisplayScreen keeps six slots in one row; DisplaySlot restricts Unlock to slot width minus 16. UIButton's automatically sized label/price/detail content can exceed that allocation. Sources: src/client/DisplayScreen.luau:123, DisplaySlot.luau:122, UIButton.luau:112.

**Focused recommendation:** reflow compact slot price/shortfall and bank information into bounded rows or an adequately wide selected-slot panel. Preserve readable fonts and exact accessible values; do not solve it by shrinking all text.

**Acceptance:** check 666×374, 705×338, 899/900/901×700 and 1000×559/560/561 with occupied banks, zero/large balances, affordable/shortfall 40K, 400K and 4M states. Visually verify content and padding; all price/rate components must remain inside their own controls. The six existing Display breakpoint probes passed geometry checks, which did not detect this text-quality problem.

### AQ03 — Collection income stat truncates the unit

**Affected state/device/input:** Collection detail for Pebble Pip, owned ×2 and duplicate-adjusted rate 4.733959…; 1279×720 desktop preview and 1023×768 4:3 tablet. Standard layout, UIScale 1.

**Reproduction:** open Collection, choose Pocket Grove/Pebble Pip, use the 720p desktop or 4:3 tablet preset, inspect the Earns stat in the right detail column.

**Expected:** the complete meaningful value “4.73 coins/s” or a readable equivalent retains its unit. **Actual:** rendered text is “4.73…” in the failing layout. Other layouts use compact “4.73/s” successfully. This makes the income stat less interpretable despite an otherwise readable detail pane.

**Evidence:** [exact live measurements](evidence/finding-measurements.json), [baseline records](evidence/native-layout-cases.json). At 1279×720 the value was “4.73 coins/s”, TextSize 18, TextTruncate.AtEnd, AbsoluteSize 90×22, TextBounds 47×18 and TextFits false; the short TextBounds reflects the truncated rendering. Full-screen captures were viewed inline during the baseline sweep. The JPEG/crop was not retained, and recapture is **Blocked B01**; this finding needs its missing image pair before a visual fix is signed off.

**Impact/frequency:** repeated in two inspected classes; unit/number clarity, not a grant or rate-computation failure.

**Root cause confidence: confirmed.** CollectionScreen puts three stats in a limited-width detail column and selects the longer unit based on its compact-layout branch. Sources: src/client/CollectionScreen.luau:205 and :295; UIKit's default end truncation.

**Focused recommendation:** use a consistent short unit, wrap the unit on a second readable line, or adapt stat columns to their minimum text width.

**Acceptance:** retain full units for minimum/large/duplicate rates on the two failing classes and adjacent detail-layout transitions. Inspect at normal viewing size and retain the complete screen plus crop. A bounds-only PASS is insufficient.

### AQ04 — Batch summary loses full figure names

**Affected state/device/input:** naturally earned Welcome x10, 666×374 effective phone viewport, Grove completed 6/6. Native Skip reached the summary; Done returned to the previous route.

**Reproduction:** complete the Welcome Quest, accept the x10, Skip to the summary and inspect the ten cards. Try to obtain the full Sunbeam Sprite or Sprout Scout name from a card.

**Expected:** each awarded figure can be identified by a full readable name or an obvious reachable detail affordance. **Actual:** labels include “Sunbeam…” and repeated “Sprout…”. The summary displays all ten results and correct NEW/duplicate semantics, but its tiles do not navigate or offer visible name disclosure.

**Evidence:** [full summary](evidence/welcome-ten-summary.jpg), [close-up](evidence/AQ04-summary-closeup.png), [natural grant trace](evidence/final-runtime.json). The supplied image is 450×253 capture pixels, distinct from the measured 666×374 GUI viewport, scale 1. It was reviewed at that normal capture size. Per-label geometry was not preserved at this stage; recapture/measurement is Blocked B01.

**Impact/frequency:** significant identification friction in this one natural batch; no item was missing or incorrectly awarded. Collection later shows the full identities.
AccessibleName attributes do contain full names, but they are not a visible mouse/touch disclosure mechanism.

**Root cause confidence: confirmed summary interaction/layout.** PullSummary fixes up to five columns beside a 200px-minimum progress panel and supplies no-op tile callbacks. FigureTile truncates ordinary card names. Sources: src/client/PullSummary.luau:52, :174; FigureTile.luau:130 and :177.

**Focused recommendation:** allow readable multiline names, fewer columns with scrolling, or a full-name/detail interaction while preserving the complete batch count.

**Acceptance:** all ten identities remain readable or discoverable on 666×374 and 705×338; check the 13-figure collections, long names, duplicate rarity/owned text and 419/420/421-height transitions. Add measured label geometry and screenshots before closing.

### AQ05 — Reference/checklist contradictions can invalidate QA

**Affected system:** active documentation and unmapped StudioSystemScreens fixture, independent of device/input. Current build prerequisite verified above.

**Reproduction:** compare the current Profile schema and the successful native unlock sequence with the cited documents/test assertions.

**Expected:** current operational guidance and active acceptance fixtures describe the implemented schema and sequential six-slot expansion. **Actual:**
- ROADMAP.md:6 calls the current build schema 13; Profile is schema 14.
- OPERATIONS.md:167–168 still frames the later storage acceptance/older-writer warning around v13; the current writer is v14.
- ui-redesign/BRIEF.md:110 and IMPLEMENTATION.md:30/:234 say slots 5–6 are Coming later, while later integration text in the same implementation document and current source say sequential unlock.
- tests/StudioSystemScreens.client.luau:36 asserts the obsolete Coming later state.
- OPENING.md:191 describes Redeem as current even though the production protocol/result adapter rejects the retired action.

**Evidence:** native expansion in [progressed results](evidence/progressed.json), current schema in src/server/Profile.luau, and the exact document/test locations above. This is reproduced source/reference conflict, not a rendering bug.

**Impact/frequency:** deterministic; can generate false failures, incorrect acceptance expectations and misleading migration/rollback guidance. StudioSystemScreens was deliberately not counted as a valid current-build test.

**Root cause confidence: confirmed stale text/fixture assumptions.**

**Focused recommendation:** reconcile the active sections and fixture with the current accepted model, keeping historical material explicitly historical. Do not change game behavior to satisfy obsolete mockups.

**Acceptance:** one consistent schema-14 operational path; all six slot states tested sequentially; retired Redeem excluded; no active Coming later assertion for slots 5–6. Re-run the corrected fixture after a separate authorized change.

## Design recommendations and unverified risks

These are not additional confirmed gameplay failures.

- **DR01 / P3:** short Goals layouts place the claim action below the first visible portion of the vertically scrolling card. Geometry checks kept it reachable, but a stronger scroll cue or fixed claim affordance would reduce hesitation. Native wheel/finger endpoint activation remains blocked.
- **R01 / release gate:** the roughly 30-minute instrumented Studio sampler spent substantial time near 15 FPS. Median reported FPS was 15.00; median maximum frame interval per sampling window was 68.50ms, with a 200.26ms maximum. Background Studio throttling, device resizes and the editor are confounders. No physical-phone or loaded-server performance claim follows from this.
- **R02:** memory rose from 2,641.71MB to 2,841.74MB across mixed viewport/menu work, peaking at 2,932.20MB. GUI count warmed from 3,740 to 4,180 and settled near 4,180; instances ended at 15,809. This does not establish a leak. A fixed-size warmed repetition run with post-cleanup measurements is still required.
- **R03:** full Shelf/Display geometry and eight occupied plots were not rendered under low/high graphics. Shim budgets (1,090/1,100 world parts; 53 + 2 lights per active plot / 72; 171/184 active plot parts) passed; imported figure geometry is additional.
- **R04:** persistence, offline earnings across real rejoin, service failures and migration/lease races passed domain fixtures only. No live test store was used.
- **R05:** human listening was unavailable. The inspected native client had 34 Sound instances with IsLoaded true, one world music loop playing, RequestQueueSize 0 and no opening residue after the presentation fixture was destroyed. Loading and cleanup do not establish audio quality.
- **R06:** console/VR and experience-enabled platform/language configuration cannot be established from an unpublished PlaceId 0 file. No console support PASS or unsupported-platform exclusion is inferred from a Studio preset.

## Historical findings and reference comparison

The current UI follows the shared white/plum outlined system, collection accent/icon treatment, filter-grid-detail Collection, neutral Shop, six Display cards, Goals cards and wooden Shelves in the local references. Sample balances/counts, retired Scrap/Recycle/Redeem, mockup image URLs and Coming later slots are not current requirements.

Approved deviations recorded by IMPLEMENTATION.md include larger 44px controls, horizontally scrolling Shelf filters, actual server-driven bonuses/odds/free-box choice, and the short-landscape sheet/dock policy. Those are not audit bugs.

The prior 2026-10-09 ui-review fixes were used as regression prompts:
- Welcome tutorial/reveal controls completed the natural small-phone journey; no stuck guidance was observed.
- The ten-result grid and 6/6 completion panel were present; AQ04 records remaining name clarity rather than claiming that old missing-summary behavior returned.
- Shop contents had readable separate tiles, quantities and odds in inspected baselines.
- Shelf picker names and cabinet scroll hint were present, and the read-only scroll endpoint fixture passed; AQ01 is a current touch-layer obstruction.
- The historical Goals title/card overlap was not reproduced in the populated baseline.
- Moon Moth revealed successfully on the small phone. Legendary/Mythical recognition, full cross-collection tours and low/high-graphics/day/night ranking are still blocked, not historical fixes re-certified.

Local HTML source was inspected against the running layouts. Pixel comparison in a rendered reference browser was blocked: loopback browsing timed out and file URLs were rejected by the browser URL policy. No security bypass was attempted. Canvas-only /_blob assets and dynamic sc-* elements must not be mistaken for missing game assets.

## Checks completed

| Check | Actual result / limit |
| --- | --- |
| Pinned tools | Rokit 1.2.0; Wally 0.3.2; StyLua 2.5.2; Selene 0.31.0; Rojo 7.7.0; Luau LSP 1.70.1 |
| wally install | Passed on host retry; no dependencies added or lockfile content changed |
| stylua --check src | Passed; formatting was not applied |
| selene src | Host retry passed: zero errors/warnings/parse errors; first sandbox API fetch failed |
| rojo build default.project.json -o build/audit-2026-10-09.rbxlx | Host retry passed; ignored audit build |
| rojo sourcemap default.project.json -o sourcemap.json | Host retry passed |
| luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=build/tools/globalTypes.PluginSecurity.d.luau src | Exit 0, no source diagnostics; watcher-registration warning; cached PluginSecurity definitions are a superset |
| python tests/run.py build/tools/luau/luau.exe | Passed all existing suites; engine doubles are not native visual tests |
| python -m unittest discover -s tests -p test_*.py | Host retry passed 30 tests; two ResourceWarning messages in synthetic HTTP-error cleanup; initial sandbox temporary-directory failures preserved |
| StudioUI / StudioScroll | Executed on baseline screens; three touch center-hit failures. Scroll endpoint mutation is a read-only fixture, not wheel/finger input |
| StudioSystemScreens | Blocked by obsolete Coming later assertions; not modified |
| Native opening/lifecycle fixtures | Natural opening/Skip/summary completed; deeper fixture attempt blocked by 1×1 renderer; cancellation cleanup verified |
| Native multiplayer | Two actual clients, distinct plots; synthetic authority/private-state/purchase/deal/cleanup probes passed |
| Soak | 180 samples, 1,792.89 seconds (29m53s), single-client editor session with resizes/menu work |
| git diff --check | Passed |
| Final source/config preservation | No source, dependency, mapping or tool-version diff; existing user documentation changes retained |

[Verification outcomes](evidence/verification-summary.json), [regression output](evidence/regression.txt), [initial sandbox failures](evidence/static-and-python.json), [tool versions](evidence/tool-versions.json), [soak](evidence/soak-summary.json), [multiplayer probes](evidence/multiplayer.json).

## Release gates and cleanup

Before public acceptance: resolve AQ01/AQ02 and verify their native touch regressions; finish real isolated persistence/rejoin acceptance; verify actual enabled platforms and connected controller/touch input; finish rare/duplicate/batch opening visuals and interruption cases; measure full loaded plots under low/high graphics on target hardware. AQ03/AQ04 need the missing label/image measurements as well as their focused readability checks.

The isolated multiplayer test ended through StudioTestService.EndTest. A renderer-recovery restart also returned to Edit. Device simulation was stopped; the audit instance was restored to iPhone 7 / LandscapeLeft / ScaleToPhysicalSize / pixel density 96 selection. Observer and preview resources were disconnected/destroyed or removed by stopping Play. No temporary scripts were added to the saved project. The user's other Studio window was not edited.

Every remaining matrix family has a concrete blocker in COVERAGE.md. “Blocked” is an open acceptance gate, not a PASS.
