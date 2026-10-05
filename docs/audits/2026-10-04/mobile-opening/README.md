# A01 / A02 mobile opening follow-up

Native screenshots and checks from 2026-10-04. The original reproduction used `ede5c21`.
The mobile changes were committed as `4f32dc9`; master `12817af` was then merged as `efa77ba`.
Master's Welcome Quest, duplicate upgrade feedback, stable batch Skip and scoped local lighting
hold are preserved. This follow-up implements only A01/A02.

## Diagnosis and change

- The camera faces +Z, so screen right is world -X. The old positive result target shift put
  the figure beneath the right column. Camera/UI also used different compact thresholds, and
  vertically stacked chips/actions exceeded short safe-area heights. A shared safe-area predicate,
  aspect/FOV-aware camera translation, bounded title/chip rows and 44px minimum actions now keep
  the model and choices separate. Batch Next and Skip fit without dropping odds.
- The lower full-width purple result scrim covered the mobile figure. Comparing the same active
  Moon Moth at night, stage lights on with scrim and camera post effects off remained readable at
  quality 1 and 21; disabling stage lights darkened it. Camera grading produced a smaller tint.
  Global Voxel Lighting/night ambient affected the base illumination, but night alone did not
  explain the device-dependent result. The compact scrim now paints only the controls column.
  Master's temporary local daytime ambient hold provides a stable base and restores the latest
  replicated town look on release. Server/town lighting, stage light budgets, rarity choreography,
  reward authority and desktop camera/card composition are unchanged by the mobile fix.

## Native comparisons

| State | Before | After |
| --- | --- | --- |
| Android landscape, night, reduced-motion Moon Moth duplicate/intermediate batch | [Original overlap/dark scrim](before-android-night-moth.jpg) | [Clear left figure and batch controls](after-android-night-moth-batch.jpg) |
| Android landscape, night, full-motion Pebble Pip | [Original clipped title/overlap](before-android-night-pebble.jpg) | [Mobile layout before master merge](after-iphone-night-pebble.jpg) |

The second comparison uses iPhone landscape after the fix, not identical Android dimensions.
The first retains the device/figure/motion/batch state; economic labels differ with the local
snapshot, and master adds the stable Skip control and ambient hold.

Additional merged renders inspected: [Android new Moon Moth](after-android-night-moth.jpg),
[iPhone guided Welcome Box](after-iphone-welcome-night.jpg), [actual paid Open 10 first result](after-iphone-confirmed-ten-night.jpg),
[actual duplicate rate upgrade](after-iphone-confirmed-duplicate-night.jpg), and
[laptop Pearl Regent](after-laptop-night-pearl.jpg).
The [Legendary](after-iphone-night-legendary.jpg) and [Mythical](after-iphone-night-mythical-batch.jpg)
captures were inspected before the master merge; their layout is retained, with master's ambient
hold added afterwards. All five actual catalog models were loaded as production models in the
merged native matrix.

## Checks actually completed

- Device simulator presets: iPhone 7 landscape (667×375; camera 666×374), Samsung Galaxy A06
  landscape (800×360 preset; observed safe camera 705×338), average laptop (1366×768;
  camera 1365×768). No physical hardware was available.
- 60 merged native direct-reveal/result cases: three presets × day/night × full/reduced motion
  × five actual figures: Pebble Pip, Moon Moth, Pearl Regent, Cloud Rest Star, Dreamcatcher Star.
  Day used quality 21, night quality 1. Cases covered new/duplicate, empty/full/unavailable
  Display, swap with a long name, affordable/unaffordable repeat opening and batch Next/Skip.
  Native bounds/text/projection assertions and exact camera restoration passed in every case.
- Native screenshot inspection covered all five rarities before merging; merged render inspection
  covered Common/Uncommon/Rare, long duplicate feedback, guided results and batch controls.
- Native input walkthrough at iPhone landscape/night/quality 1: server-confirmed Welcome Box and
  placement, paid single and paid Open 10 in full motion, Next to a duplicate upgrade and Skip to
  the summary; paid single and Open 10 in reduced motion also reached results/summary. Reduced
  Await/Result had zero render connections. The settings panel was exposed via a Studio-only
  visibility change because MCP could not activate the top gear; its existing Reduced button
  was then clicked and its selected state verified. No product settings code was changed.
- 20 native interruptions after camera takeover, alternating motion settings, using cancel and
  GUI destruction: camera type/subject/CFrame/Focus/FOV restored exactly; latest world night
  restored; no stage, camera effects, audio folder or opening input/movement bindings remained.
  Actual result closure and batch Skip also returned camera type Custom and world clock 0.
- Full standalone regression suite, StyLua check, Selene, Luau Language Server diagnostics with
  Roblox definitions/sourcemap, and Rojo build passed. Tool provisioning used pinned versions;
  Wally dependencies stayed empty.

`tests/StudioOpeningLayout.client.luau` projects actual native model bounds, checks safe-area
containment, visible text fitting, minimum touch sizes and model/control/scrim separation. It is
Studio-only and is not mapped into the game. Conservative MeshPart boxes contain empty space
below curved bases; desktop NEW-badge collision is therefore checked in screenshots, while its
safe-area/text checks and every compact collision check remain automated.

Later optional extra captures stalled with a presentation still in Enter; they are excluded
from the completed checks above. Temporary fixture controllers/connections were destroyed,
quality returned to Automatic, Play stopped and device simulation stopped.

## Remaining acceptance / compromises

Physical iPhone/Android low-graphics rendering, true touch/notch safe areas, readable small chip
text and subjective face/silhouette readability still need acceptance. Repeat daytime/nighttime
single/Open 10, all five rarities, long names and interruption/restoration on hardware. Compact
secondary text scales down (minimum 10px chips, 14px title); all actions remain at least 44px.
Desktop composition is retained. Full rarity choreography/audio/performance and persistent
multi-client release gates remain separate; these result checks do not close them.
