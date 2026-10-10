# Walkthrough and labelled results

Build and environment: see [REPORT](REPORT.md#source-and-environment). Studio sessions:
1 = b5779791 (1b90716), 2 = 9dca0c20 (89df9a2), 3 = e26ac926 (eea7737), 4 = 23f85aed (c30c4fe).

## Fresh-player journey (session 1, native, before any grant or bypass)

Device: StudioDeviceSimulatorService `iphone_7`, LandscapeLeft. Measured Camera 666×374,
SafeArea 666×374, GuiInset (0,58), UIScale 1, TouchEnabled true. This is emulated touch
presentation driven by the Studio tool pointer, not a physical phone. Times are seconds after
the observer was installed, about 2s after PocketGrove appeared. They include tool round trips,
screenshots and inspection pauses, so they are not an onboarding-speed benchmark.
([trace](evidence/journey-trace.json))

| Time | Step | Result |
| --- | --- | --- |
| 0.07 | Ready | 4,500 Coins, step 1, empty inventory. Touch thumbstick and Jump visible in the world; dock between them ([world](evidence/journey-01-fresh-world.jpg)) |
| — | Shop | Touch controls hidden while Shop open. **AQ06 found:** "Open your free Welcome Box" ran past its button ([before](evidence/AQ06-closeup-666x374-before.png)) |
| 70.81 | Welcome Box via Tap to Open | Moon Moth, Uncommon, NEW; step 2 ([await](evidence/journey-03-welcome-await.jpg), [reveal](evidence/journey-04-welcome-reveal.jpg)) |
| 102.39 | Put on Display | slot 1; step 3; world returns with touch controls restored after the cinematic ([world](evidence/journey-05-first-display.jpg)) |
| 150.92 | W, then W+D onto CollectionPlate1 | "Collected 532 Coins!"; step 4 |
| 160.84 | Paid Grove box; opened by tapping the box itself | 1,500 charged once; Sprout Scout, Common; step 5; Keep returned to Shop ([reveal](evidence/journey-06-paid-reveal.jpg)) |
| — | Welcome reward popup | OPEN 10 NOW ([popup](evidence/journey-07-reward-popup.jpg)) |
| 200.97 | Welcome x10 via Skip twice | Exactly 10 figures; Grove 6/6; caption "Tap a figure for its full name" ([summary](evidence/AQ04-summary-666x374-default.jpg)) |
| — | Native tile taps | "Sprout Scout · Common · ×3 owned" ([named](evidence/AQ04-summary-666x374-sprout-named.jpg), [close-up](evidence/AQ04-closeup-666x374-sprout-named.png)), then "Sunbeam Sprite · Rare · NEW!" |
| — | Done | Returned to Shop (origin); "Collection complete! New Shelf unlocked" ([shop](evidence/journey-08-done-origin-shop.jpg)) |
| — | Close, Shelves tip | Touch controls back ([tip](evidence/journey-09-world-shelf-tip.jpg)); Shelves opened, Jump no longer over the picker ([AQ01](evidence/AQ01-shelves-666x374-fixed.jpg)) |
| 558.87 | Picker tap at the old Jump location | Placed Mallow Cap; step 7. The intended target was Sunbeam Sprite, but the tool's coordinate mapping under the simulator selected another row (also seen in the audit) ([placed](evidence/journey-10-shelf-placed.jpg)) |
| — | Goals | "Claim below" cue shown for the ready free box; tap scrolled "Open free box" into view; cue hid ([cue](evidence/DR01-goals-666x374-cue.jpg), [after](evidence/DR01-goals-666x374-after-cue.jpg)) |
| 701.34 | Daily Login double click | +500 once ([login](evidence/journey-11-login.jpg)) |
| — | Settings → Reduced, Home | Saved selection; Home returned to spawn (18, 3.44, -142) with touch controls on ([settings](evidence/journey-12-settings.jpg)) |

Note: one extra "Shelf updated." at 580.41 came from an instance-path click on the hidden phone
dock tile, which landed on visible Shelves content. It was a tool artifact, not a player path.

Clarity notes: the Welcome Quest path was completed without a bypass. The new summary caption
made truncated names identifiable without leaving the summary. The Goals cue made the
below-the-fold reward obvious. After the AQ06 fix, the Shop's Welcome button reads cleanly
([after](evidence/AQ06-closeup-666x374-fixed.png)).

## Progressed states (labelled fixture funding)

Sessions 2–4 used the Studio-only `StudioGrantCoins` remote (unsaved, fixture money) after
dismissing the Welcome Quest with its own two-tap Skip ([confirm](evidence/welcome-skip-confirm-666x374.jpg)).

- Paid We Are All Stars ten at 666×374 natively: 2,000,000 once; first reveal "Reminiscence Star"
  ([reveal](evidence/opening-paid-star10-first-reveal.jpg)); View all results; native tap captioned
  "Reminiscence Star · Common · NEW!" ([summary](evidence/AQ04-summary-666x374-paid-star10-native-tap.jpg)).
- Equip Best at 666×374: three We Are All Stars figures, set bonus +73.43/s; "Page Turner Star"
  wrapped on its card ([display](evidence/AQ02-display-666x374-live-equipbest-wrap.jpg)).
- Native Unlock 4/5/6 at 666×374: 40,000, then 400,000 (double click, charged once), then
  4,000,000; StudioSystemScreens "6 of 6 slots unlocked in order".
- AQ02/AQ03/AQ04 real-component matrices: see REPORT and the files listed in
  [evidence README](evidence/README.md).
- 20 paid Open 10s across all five collections, with native Skip at Await/Charge/Shake and full
  stepping through one batch ([openings](evidence/openings-session3.json)).
- Collection → "Find it in … boxes" route to Shop kept touch controls hidden. Respawning with Shop
  open kept them hidden; Close restored TouchGui, Jump and the Custom camera on the new humanoid.

## Multiplayer (session 4, two real rendered clients)

See [multiplayer evidence](evidence/multiplayer-session4.json). Native: purchases, visitor prompt,
plate and figure-click denial, owner collect, deal stock and sold-out UI, Home. Synthetic and
labelled: malformed/stale Intent probes. Engine: Kick cleanup and AddPlayers reassignment.

## Returning-player and service boundaries

Not accepted in this session: real save/rejoin, offline return, migration, leases, load/save
failure, real hour/day boundaries and the global leaderboard service (B04/B05). The existing
domain suites passed (tests/run.py). No production settings, live stores or system clock were
touched.
