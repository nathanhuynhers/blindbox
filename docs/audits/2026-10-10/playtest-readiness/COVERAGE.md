# Coverage and remaining acceptance

Statuses apply to **the named check on the named build**, never to a whole feature:
**Pass** (observed and met), **Fail** (defect observed; links the finding), **Blocked** (named
constraint), **Not run** (no execution evidence), **Not applicable** (not implemented or not
targeted). Method tags: **N** native Studio pointer/keyboard input, **K** menu keys through
VirtualInput (routing only), **F** real screen/component module rendered from a labelled
snapshot fixture, **S** synthetic remote, **U** unit suite with engine doubles.

## Device classes and measured geometry

Simulator presets are viewport probes, not physical-device certification. SafeArea equals the
measured viewport in every row (raw GUI origin −58 is the Studio top-bar coordinate offset).

| Class | Preset | Measured viewport | UIScale | Touch emulated |
| --- | --- | --- | --- | --- |
| iphone7 | iphone_7 | 666×374 | 1.00 | yes |
| a06 | samsung_galaxy_a06 | 705×338 | 1.00 | yes |
| iphone13 | iphone_13 | 749×388 | 1.00 | yes |
| iphone16max | iphone_16_pro_max | 830×439 | 1.00 | yes |
| smalltablet | xiaomi_redmi_pad_se | 959×599 | 1.00 | yes |
| ipad4x3 | ipad_6th_generation | 1023×768 | 1.00 | yes |
| largetablet | ipad_pro_M5_13in | 1375×1032 | 1.07 | yes |
| laptop | average_laptop | 1365×768 | 1.07 | no |
| hd720 | hd_720 | 1279×720 | 1.00 | no |
| desktop | hd_1080 | 1919×1079 | 1.50 | no |
| hires | hd_1080 + 2560×1440 | 2560×1440 | 2.00 | no |
| ultrawide | hd_1080 + 3440×1440 | 3440×1440 | 2.00 | no |

Exact breakpoint sizes (666×374, 705×338, 899/900/901×700, 1000×559/560/561, 900×419/420/421,
1279/1280/1281×720, 1023/1024/1025×768) were set with `SetResolutionAsync` on `hd_720`, which
maps one-to-one. Odd sizes were not reachable on the iPhone preset.

## Baseline matrix (StudioUI: whole-target hit order, 44px targets, safe area, scroll canvases, touch ownership)

Progressed fixture state. Sessions 2 and 3; method N/K. Screens show "Pass n/m" = visible
targets / whole-target hit points in the raw files.

| Class | World | Collection | Display | Shop | Goals | Shelves | Login | Settings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| iphone7 | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| a06 | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Not run (pointer offset) |
| iphone13 | Pass | Pass | Pass | Pass | Pass | Pass | Not run (pointer offset) | Not run (pointer offset) |
| iphone16max | Pass | Pass | Pass | Pass | Pass | Pass | Not run | Not run |
| smalltablet | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| ipad4x3 | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Not run |
| largetablet | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| laptop | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| hd720 | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| desktop | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| hires | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| ultrawide | Pass | Pass | Pass | Pass | Pass | Pass | Not run | Pass |

Text notes found by the same sweep were fixed (AQ08) and re-verified at 4 sizes. A first hires run
reported four false corner-sample Backdrop hits caused by the fixture (corner offsets were not
scaled by UIScale 2); the fixture was corrected and the rerun passed. Login/Settings rows marked
Not run were covered at neighboring classes. Baseline screenshots were not retained for every
cell; the StudioUI records are the evidence ([session 2](evidence/device-sweep-session2.json),
[session 3](evidence/device-sweep-session3.json)).

## Finding acceptance

| Case | Status | Method | Evidence |
| --- | --- | --- | --- |
| AQ01 reproduce on current build (runtime revert) | Pass (reproduced: 4/9 and 2/9 blocked) | N + engine hit test | REPORT |
| AQ01 Shelves 666×374, 749×388; Display/Equip Best 959×599 | Pass | N/K + StudioUI | [close-up](evidence/AQ01-closeup-666x374-shelves-fixed.png), sweeps |
| AQ01 restore: close, route, respawn, cinematic exit, Home | Pass | N | WALKTHROUGH |
| AQ01 restore on GUI teardown | Pass (unit) / Not run (Studio) | U | Screens.spec |
| AQ01 physical finger taps at edges | Blocked B02 | — | — |
| AQ02 64-case matrix | Pass | F | REPORT, [natural](evidence/AQ02-display-666x374-natural-live.jpg), [close-up](evidence/AQ02-closeup-666x374-natural.png), [4M state](evidence/AQ02-display-666x374-short4M-fixture-prewrap.jpg) |
| AQ02 native sequential 40K/400K/4M | Pass | N | WALKTHROUGH |
| AQ03 51-case matrix + old-string control | Pass | F | [1279×720](evidence/AQ03-collection-1279x720.jpg), [close-up](evidence/AQ03-closeup-1279x720.png), [1023×768](evidence/AQ03-collection-1023x768.jpg), [close-up](evidence/AQ03-closeup-1023x768.png) |
| AQ04 native tap disclosure | Pass | N | [Welcome](evidence/AQ04-closeup-666x374-sprout-named.png), [paid](evidence/AQ04-closeup-666x374-paid-reminiscence.png) |
| AQ04 35-case matrix incl. 419/420/421, 13-figure, fewer results | Pass | F (real PullSummary) + engine selection | [705×338 caption](evidence/AQ04-summary-705x338-star13-caption-capture-no-viewports.jpg) (capture tool omitted ViewportFrames; models verified present) |
| AQ05 docs + fixture | Pass | review + StudioSystemScreens 3/6 and 6/6 | REPORT |
| DR01 cue | Pass | N | [cue](evidence/DR01-closeup-666x374-cue.png) |
| AQ06/AQ07/AQ08 | Pass | N/F | REPORT |

## Implemented surfaces

| Surface | Executed | Status / open |
| --- | --- | --- |
| HUD/dock | Fresh and progressed states; dock routes; Daily badge; touch ownership | Pass; large-wallet abbreviation via U |
| Settings | Reduced toggle saved (N); StudioUI on 9 classes | Pass; slider endpoints and save across rejoin Not run/B04 |
| Collection | Filters/details/route to Shop (N); AQ03 matrix (F) | Pass |
| Display | Place, Equip Best, unlock 4–6, full 6/6, picker (N); AQ02 matrix (F) | Pass; swap/remove natively Not run this session (unit + audit) |
| Shop | Welcome, paid Open 1/Open 10, all five collections, free box offered (N) | Pass; luck/pity panel visuals Not run |
| Goals | Cue, ready free box (N); StudioUI | Pass; goal claim Not run this session |
| Shelves | Placement completing the tip (N); StudioUI | Pass; full unit/copy limit/purchase Not run this session |
| Daily Login | Day 1 claim once (N) | Pass; later days Blocked B05 |
| Opening | Common/Uncommon/Rare results (N + layout); Skip at Await/Charge/Shake; Open 1/10; View all results; Done/origin; cleanup | Pass; **Legendary/Mythical presentation Not run**; reduced motion opening, day/night and low/high graphics Not run |
| Pull summary | All AQ04 cases | Pass |
| Welcome reward / Skip confirm | Natural popup; two-tap Skip (N) | Pass |
| Offline popup | — | Blocked B04 (domain suites pass) |
| Deal popup/stalls | Native E, shortfall, purchase ×3, sold out, per-player stock (2 clients) | Pass; hour rollover Blocked B05 |
| World collection / visitor rules | Plate, figure click, prompts (2 clients) | Pass |
| Plot lifecycle | Kick cleanup; slot reuse | Pass |
| Leaderboard | — | Not run (service needs a published experience, B04) |
| Rotation / focus loss / input switching | — | Not run (landscape enforcement unchanged; needs a device or approved emulator) |
| Audio | — | Blocked (no human listening) |

Not applicable: trading, premium purchases, visit directories, customization and portrait
layouts (not implemented).

## Blockers

See [REPORT](REPORT.md#blockers) for B01–B07 status and exact handoffs.
