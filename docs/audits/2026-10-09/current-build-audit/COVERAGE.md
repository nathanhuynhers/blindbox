# Coverage and remaining acceptance

Scope: the exact build in [REPORT.md](REPORT.md). Statuses describe **the named check and state**, never the entire feature.

- **Pass:** observed outcome met the stated check.
- **Fail:** a current defect was observed; the affected case links to its finding.
- **Blocked:** a specific environmental, permission, hardware or fixture constraint prevents acceptance.
- **Not run:** no execution evidence; no acceptance inference.
- **Not applicable:** the combination is not implemented or the fixture does not target it.

[Native layout records](evidence/native-layout-cases.json) contain 107 attempts: 100 valid layout/check records and seven excluded setup failures. The valid records comprise 94 screen/device baselines and six Display breakpoint probes. One additional small-phone HUD observation is documented in the natural walkthrough. This is representative coverage, not every device model.

## Devices, usable geometry and platforms

Simulator preset output is a viewport probe, not a claim that the named physical device was tested. Notch/inset presets were deliberately included. Values below are measured Camera/GUI pixels; raw SafeArea origins were (0,-58) because of the Studio top-bar coordinate system. Adding the measured GuiInset (0,58) gives screen-relative usable origin (0,0). The usable width/height equals each row's measured value. Cutouts can already reduce the camera viewport from the preset's nominal resolution; they must not be subtracted twice.

| Key / class | Preset or override | Nominal landscape pixels | Measured usable viewport | UIScale |
| --- | --- | --- | --- | --- |
| iphone7 / small phone | iphone_7 | 667×375 | 666×374 | 1 |
| a06 / short phone | samsung_galaxy_a06 | 800×360 | 705×338 | 1 |
| iphone13 / typical notched phone | iphone_13 | 844×390 | 749×388/389 | 1 |
| iphone16max / wide notched phone | iphone_16_pro_max | 956×440 | 830/831×439 | 1 |
| smalltablet | xiaomi_redmi_pad_se | 960×600 | 959×599 | 1 |
| ipad4x3 | ipad_6th_generation | 1024×768 | 1023×768 | 1 |
| largetablet | ipad_pro_M5_13in | 1376×1032 | 1375×1032 | about 1.074 |
| laptop | average_laptop | 1366×768 | 1365×768 | about 1.066 |
| hd720 / small desktop | hd_720 | 1280×720 | 1279×720 | 1 |
| desktop | hd_1080 | 1920×1080 | 1919×1079 | about 1.499 |
| hires | hd_1080 override 2561×1441 | custom | 2560×1440 | 2 |
| ultrawide | hd_1080 override 3441×1441 | custom | 3440×1440 | 2 |

One-pixel differences between passes are recorded in the raw cases, not rounded away. A later pixel-density experiment did not become a new physical-device class. Native desktop action tests also used the default 1529×730 editor viewport, scale about 1.014.

Roblox supports mobile, desktop, Xbox/PlayStation and Quest families, but this unpublished file does not establish which platforms are **enabled for this experience**. See official [mobile requirements](https://en.help.roblox.com/hc/en-us/articles/203625474-Roblox-Mobile-System-Requirements), [Quest/platform FAQ](https://en.help.roblox.com/hc/en-us/articles/17810433924628-Meta-Quest-FAQ) and [device simulator](https://create.roblox.com/docs/studio/device-simulator). Presets can model geometry without proving hardware compatibility. Physical Apple/Android/tablet/desktop-controller/console/VR acceptance is Blocked B02/B03; the Windows Studio host is the actual runtime host used.

## Baseline visual matrix

State: completed Grove 6/6, 12 naturally owned copies, one occupied Display slot, three unlocked slots, four owned Shelves, claimed Day 1 login, unclaimed daily goal with progress 1. Selected collection was Grove; other collections were visible in the rail/list. Settings was inspected after tutorial completion. “Pass” here means the baseline was captured and visually examined with no additional confirmed defect in that state; it does not certify deeper states or physical activation.

| Device | Collection | Display | Shop | Goals | Shelves | Login | HUD | Settings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| iphone7 | Pass | Fail AQ02 | Pass | Pass | Fail AQ01 | Pass | Pass, journey | Blocked B01 |
| a06 | Pass | Fail AQ02, compact pressure | Pass | Pass, DR01 | Pass | Pass | Pass | Pass |
| iphone13 | Pass | Pass, partial touch overlay noted | Pass | Pass | Fail AQ01 | Pass | Pass | Pass, partial knob overlay noted |
| iphone16max | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| smalltablet | Pass | Fail AQ01 | Pass | Pass, DR01 | Pass | Pass | Pass | Pass |
| ipad4x3 | Fail AQ03 | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| largetablet | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| laptop | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| hd720 | Fail AQ03 | Pass, rate fit risk measured | Pass | Pass | Pass | Pass | Pass | Pass |
| desktop | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| hires | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| ultrawide | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |

Complete screenshots were returned and inspected for the valid baseline sweep. A subset was retained as files: all six initial iPhone 7 screens, nine Display sizes and the natural journey. Other captures were inline only. Their absence from the directory does not mean a second inspection occurred; the retention gap and blocked recapture are explicit.

The native StudioUI fixture checked visible evaluated control sizes, safe-area containment, hit order and measured scroll canvases. It stops at the first failed assertion, so a failed screen does not imply all its remaining targets were checked. TextFits was recorded independently and visually interpreted: badge font-rounding failures alone were not reported as defects. Automatic-size rows can pass viewport tests while violating their own parent padding.

StudioScroll passed its Collection/Shop/Shelves endpoint checks where applicable, programmatically moving CanvasPosition and restoring it. Its “Open Collection (All), Shop or Shelves first” errors on other screens are **Not applicable fixture invocations**, not game failures or wheel/finger acceptance. Login/Goals/body scrolling still needs native endpoint activation.

### Invalid attempts excluded

Four early A06 routes stayed on Login rather than the requested screen. Three initial desktop Display probes had an invalid fixture expression. These are marked invalidSetup in the raw JSON, excluded from acceptance and rerun successfully. Later incorrect Daily-button routes were identified as HUD observations and relabelled by actual visible screen before the valid Login sweep. No wrong-screen capture is counted as Login acceptance. Three obsolete A06 captures and one truncated JPEG were removed; the setup-attempt records remain.

## Native input versus fixtures

| Input / method | Execution and result |
| --- | --- |
| Studio pointer on initial phone emulator | Native tool-dispatched activation completed Welcome, reveal/display, paid Buy, Welcome x10, Skip, Done, Shelf placement and Day 1 claim; no callbacks were manually fired |
| Keyboard movement | Ordinary W/A/S/D movement reached the owner's occupied collection plate and earned 538 Coins |
| Default desktop pointer | Primary routes, settings/sliders, Equip Best twice, daily goal claim, sequential unlocks 4–6 and Shelf purchases executed |
| Phone pointer after device changes | Blocked: requested versus observed coordinates shifted (e.g. requested x599, observed x552); success return did not mean Close Activated. This is an input-tool mapping limitation, not a confirmed game Close bug |
| Late pointer/capture calls | Blocked B01: calls stalled; subsequent runtime returned 1×1 viewport, including after restart and device override |
| ButtonR1/ButtonY through keyboard tool | Exercised key-code routing, but LastInputType stayed Keyboard and GetConnectedGamepads was empty; **not native gamepad acceptance** |
| Physical touch / controller / console / VR | Blocked B02/B03 |
| StudioUI/Scroll | Native engine geometry/hit testing; synthetic canvas movement; no physical input proof |
| Native two-client engine | Real Players, plots, remotes and disconnect lifecycle; gameplay requests were synthetic FireServer probes |
| tests/run.py | Production modules with engine/service doubles; no rendering, physical input, actual service durability or subjective audio proof |

[case-summary.json](evidence/case-summary.json) and [coverage-matrix.csv](evidence/coverage-matrix.csv) (2,144 scoped entries; see [counts](evidence/matrix-counts.json)) make the dimensions and evidence boundary explicit.

## Implemented screen and state inventory

All remaining visual/native states in this inventory expand across the 12 listed classes and relevant input methods. Except where a row below identifies an executed check, they are **Blocked B01** for further renderer/native interaction; physical inputs additionally have B02, and real returning-player states have B04. They must not inherit the baseline PASS.

| Surface | Meaningful implemented states | Execution / open cases |
| --- | --- | --- |
| HUD / dock | fresh quest, partial/full Display, claim-ready/claimed goal, large wallet, modal hidden row, active dock badge | Fresh/partial baseline and claim path exercised; full/large and focus-switch edges blocked |
| Settings popover | normal/reduced motion, SFX/Music sliders, pending/disabled, 0/50/100, close/reopen, saved rejoin | Native reduced toggle and both 50% values confirmed; endpoints/pending/rejoin blocked B01/B04 |
| Collection | empty, partial/complete; All/Found/Missing; five collection choices; discovered/unknown detail; display/placing routes; long names, large rate/owned count | Grove complete baseline; native first figure Display route; other filters/collections/edge text states blocked |
| Display | slots locked sequentially, empty/partial/full, selected target, placing, remove/cancel/browse, affordable/shortfall, bonus, banks | Natural place/collect, native Equip Best/bonus/expand; synthetic owner place/remove/retained bank; full/native swap/browse/large amounts blocked |
| Shop | Welcome, Welcome x10, normal/free/claimed, all collections, odds/pity, affordability, Open 1/Open 10, loading/fallback, pending/failure | Welcome/paid Grove/x10 natural, Grove baseline; per-collection expensive/odds/UI failure and paid Open 10 blocked |
| Goals | 0/1/2/3 progress, claim-ready/claimed, free-ready/claimed, five completion rows, countdown/reset, long copy | Progress 1 baselines, native progress 3 claim once; free claim/reset/late pending visuals blocked |
| Shelves | empty/partial/full unit, selected spot, filters, exhausted copies, clear, carousel, buy/limit, completion reward/editor pending | Natural partial placement/completion reward; native purchases; synthetic place/remove; full/copy-limit/native carousel states blocked |
| Daily Login | ready, claimed, each day 1–7, Coin/box/multi-box rewards, cycle/skip-day, countdown | Native Day 1 +500 once and claimed baselines; later days/time boundaries blocked B01/B04/B05 |
| Opening Await/reveal | five actual rarity tiers, five collections, NEW/duplicate, normal/reduced, Skip by phase, affordability/display/swap/Keep/another | Natural Uncommon/Rare single openings and batch Skip; Common awards seen in summary; remaining rendered combinations blocked |
| Pull summary | ten/fewer results, discovery completion/missing, duplicate/New, long names, done/origin, resize | Natural Welcome ten complete; AQ04; paid batch/later login collection and all-size edge states blocked |
| WelcomeReward | eligible, open/claim, dismissed/reopen, repeated/pending | Natural reward popup and x10 claim completed; interruption/dropped reply visuals blocked |
| Welcome Skip confirmation | first/second confirmation, undo/dismiss, hidden guidance/rejoin | No natural bypass used; deeper confirmation states blocked B01/B04 |
| Offline popup | pending amount, close-to-claim, failed/dropped claim/reopen, zero/overflow | No real offline amount generated; Blocked B04; domain tests passed |
| Deal popup / stalls | each offer, countdown/new hour, affordable/shortfall, private stock 3→0, sold out, stale window | Native engine synthetic deal purchases/stock/old-window denial passed; actual E/popup activation/rollover visual blocked |
| Notifications / coin effects | success/error, simultaneous quest/claim/toast, collection burst, bounded queue, large values | Natural success/collection toast observed; error/long message/update interruptions blocked |
| Owner world fixtures | Display figure click/tap/plate; E management; Shelf physical arrows; plot Shop/Peeka | Native plate collection; geometry/source reviewed; remaining actual prompt/click/arrow activation blocked |
| Plaza / leaderboard | stalls, paths, board stat cycling/loading/last-good/error, guest traversal | Two-client visitor location and server boundaries exercised by teleport fixture; walking tour/E/board viewing and real service page blocked B01/B04 |
| Plot lifecycle | owner/visitor, allocation, late models, disconnect, reassignment, respawn | Two-client allocation, synthetic permission denial, actual disconnect cleanup and new client reused slot 2 passed; native visitor input/respawn/full-load visuals blocked |

No input fields for user-authored gameplay text, trading dialogs, premium purchase confirmation, visitor directory or portrait redesign are implemented. Those are Not applicable. Unsupported collection/rarity pairs (e.g. Grove/Tide Legendary or Mythical) are Not applicable rather than missing content. Localization expansion is Blocked B03: no enabled-language configuration or published localization context was available.

## Breakpoint and transition checks

| Threshold / dimension | Current policy / actual check | Status |
| --- | --- | --- |
| width 900 | phone if width <900; measured 899,900,901 at height700; Display checked | Pass geometry. Returned captures in the final batch were not separately retained/re-reviewed after output truncation; no new visual PASS |
| height 560 | phone if height <560; measured 559,560,561 at width1000; Display checked | Pass geometry; same visual limit |
| scale lower/upper limits | clamp(min(W/1280,H/720),1,2); baseline 1279×720, high-res 2560×1440 and ultrawide examined | Representative baseline Pass; independent ±1 transition triplets blocked B01 |
| Collection compact detail | phone or body height <402; 720p/4:3 exposed AQ03 | Fail at observed classes; body-height 401/402/403 controlled probes blocked |
| Display card compact | card height <170; phone150 vs desktop176 | Both branches observed; isolated 169/170/171 fixture boundary blocked |
| Opening composition | H-32<648 and W-40>H-32; height680 and padded aspect condition | Natural phone branch observed; 679/680/681 and aspect neighbors blocked |
| Summary short header | result height <420 | Natural short branch observed; 419/420/421 and fewer-result cases blocked |
| Grid/list and HUD/toast adaptive thresholds | Layout.columns floor formula; panes minimum widths; 600px sheet placement span; 320px toast band; variable Settings/Shelf/Shop content widths | Source inventoried and baseline extremes inspected; each independent neighbor triplet blocked B01 |
| Rotation / landscape direction | StarterGui LandscapeSensor; tested presets set LandscapeLeft; device changes recovered baseline layouts | Configuration and repeated landscape setup observed. Portrait attempt, enforced rotation and recovery through right landscape **not accepted**, Blocked B01 |
| Resize / input / focus transitions | many device resizes updated active screens correctly; source selection and pending paths reviewed | Resize baseline exercised; actual focus loss/resume, GUI recreation, touch↔controller and interrupted transactional transitions blocked |

## Deeper execution ledger

- **Natural journey:** no developer grant or tutorial skip until all required stages and optional Shelf placement finished. See WALKTHROUGH.
- **Progressed native:** Equip Best filled Moon Moth/Sunbeam Sprite/Mallow Cap, total rate 54.655712 and bonus 4.968701; double click produced a successful no-op second result. Daily goal paid +1,000 once. After a labelled +20,000,000 Studio fixture grant, slots 4,5,6 unlocked for 40K/400K/4M. Two distinct Shelf clicks bought two units for 50K+125K; next cost 312.5K. This is not a duplicated-receipt bug. A separate collect: reply transferred 11,195 Coins during expansion and is recorded separately from purchase math.
- **Two-client:** ExecuteMultiplayerTestAsync(2) launched a real server/clients. Welcome exact retries granted once. Concurrent paid Buy exact retries charged 1,500 once per player. Altered reuse rejected. Client1 volume changed to20; client2 remained100 and its own inventory stayed private. Unknown foreign identity field and NaN payload caused no mutation; stale revision rejected. Visitor Place and remote Collect denied. Home ignored a supplied foreign identity. Owner place/remove retained its accrued bank; Shelf editor placement/removal succeeded. Funded synthetic deals reduced only client1 stock to0; fourth purchase denied; replacement client stock stayed3. Actual engine Kick disconnected player2, removed their plot, and AddPlayers(1) gave player3 the freed slot2. This does not certify physical visitor clicks or native prompt UI.
- **Presentation cleanup:** isolated controller presentation could not advance beyond Enter because viewport was1×1; it was destroyed. Opening GUI/stage/input binding were absent, camera Custom/FOV70 restored.
- **Performance:** approximately30-minute single-client sampler complete. Native eight-plot/full-Shelf/large-list/low-high graphics and network-throughput measurements blocked B01/B02. Engine-wide connection/task counts are not enumerable through the available probe; existing resource/lifecycle instrumentation passed in doubles.
- **Repository:** all existing Luau suites passed. Thirty Python tests passed on host retry. Formatter check, lint, build, sourcemap and LSP source diagnostics passed with the warnings stated in REPORT. No test was rewritten.
- **Time/service behavior:** daily boundaries, login cycles, offline cap/overflow, storage lease/migration/load/save failure passed existing isolated regression fixtures. No system clock changes or live keys were used. Actual service tests remain Blocked B04/B05.

## Concrete blockers and how to close them

| ID | Evidence / constraint | Cases it blocks / required environment |
| --- | --- | --- |
| B01 | Later pointer/capture calls stalled. Native clients and a fresh original-place restart reported Camera.ViewportSize 1×1 even after simulator override. Window activation via computer-use could not proceed because app approval timed out. [Runtime blocker log](evidence/runtime-blockers.json) | Remaining rendered screenshots, all-size deep states, native controls, rotation/focus/GUI recreation, interrupted journeys, low/high graphics and native opening/scroll/lifecycle fixture completion. Restore an approved, rendering Studio viewport and repeat named cases |
| B02 | No physical touch/controller/console/VR devices connected; GetConnectedGamepads empty; keyboard ButtonR1/Y remained Keyboard | Hardware ergonomics, real touch slop, gamepad selection/focus/A/B, console/VR acceptance, hardware FPS/audio listening. Use connected target hardware or functioning approved Controller Emulator, then verify actual input type |
| B03 | PlaceId/GameId0; experience enabled-platform/language configuration unavailable | Enabled-platform applicability, native non-Windows clients, localized expansion. Inspect an existing authorized experience's configuration; no new publication was authorized |
| B04 | Unsaved preview; no existing authorized private test place with isolated test stores | Real save/rejoin, durable claims, offline return, real migration/lease/load-failure/global leaderboard service acceptance. Use that private test environment following OPERATIONS |
| B05 | No time advancement/system clock changes authorized; no live persistent reward history | Real day/hour boundaries and login-cycle return. Use current isolated time fixtures (passed) or an authorized test clock injection in a separate task |
| B06 | StudioSystemScreens asserts slots5–6 Coming later | That fixture's current-build acceptance. Reconcile its assumptions separately; no test changes were authorized here |
| B07 | Reference browser loopback connection timed out; file URL rejected by browser security policy. No bypass used | Rendered mockup pixel comparison. Source/approved-deviation comparison was performed; use the original canvas or an allowed accessible reference surface |

### Omitted combinations

The CSV expands every primary baseline across device × input dimensions. It additionally expands the meaningful edge-state inventory across all12 device classes and all3 input families. Remaining native/visual combinations carry B01, hardware ones B02, and service-dependent ones B04/B05; they are not silently omitted. Headless multiplayer and mocked regressions are recorded separately because they have no valid target viewport.

Not run families with no accepted configuration are console/VR/locale applicability (B03). Their implementation/input acceptance is Blocked pending that configuration, not declared Not applicable. Remaining rare/expensive states on small phone, standard desktop and other sensitive layouts are blocked B01; the fixture grant did not make those visuals tested.

## Artifact integrity / end state

The isolated tests were stopped and the original audit Studio returned to Edit. Device simulation was stopped and its selection restored. The observer was disconnected, the soak ended, the preview controller was destroyed, and no temporary scripts were saved. The other Studio window was left untouched. All remaining JPEG files decode successfully. Full/crop pairs are retained for AQ01/AQ02/AQ04; AQ03's missing capture pair is explicitly open. Existing user edits remained unchanged.
