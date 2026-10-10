# Evidence guide

Captures come from the Studio MCP `screen_capture`. iPhone-preset captures are 450×253 pixels
for a 666×374 GUI viewport; later presets are larger. Close-ups (`*-closeup-*.png`) are
nearest-neighbor crops of the full image beside them. While the Studio window is covered, the
capture tool omits ViewportFrame portraits and the 3D stage; files that show this say so in
their name, and model presence was checked programmatically.

| File | What it is |
| --- | --- |
| journey-*.jpg, journey-trace.json | Native fresh-player journey, session 1 (666×374 touch preset) |
| AQ01-shelves-666x374-fixed.jpg, AQ01-closeup-* | Shelves with Jump no longer over the picker |
| AQ02-display-666x374-natural-live.jpg, AQ02-closeup-666x374-natural.png | Live Display after the journey: stacked Unlock/40K, "Need 35.9K more", separate bank line |
| AQ02-display-666x374-short4M-fixture-prewrap.jpg, close-up | Labelled fixture state (4M shortfall, five banks) before the AQ07 name wrap |
| AQ02-display-666x374-live-equipbest-wrap.jpg | Live Equip Best with a two-line name (AQ07) |
| AQ03-collection-1279x720.jpg / 1023x768.jpg, close-ups | Pebble Pip ×2, "Earns coins +4.73/s" |
| AQ04-summary-666x374-default.jpg / -sprout-named.jpg / -paid-star10-native-tap.jpg, close-ups | Summary caption before and after native taps |
| AQ04-summary-705x338-star13-caption-capture-no-viewports.jpg | Real PullSummary at 705×338, controller-selected Dreamcatcher Star; portraits not drawn by the capture tool |
| AQ06-closeup-666x374-before.png / -fixed.png, AQ06-shop-666x374-fixed.jpg, journey-02 | Welcome Box label overflow and fix |
| DR01-goals-666x374-cue.jpg / -after-cue.jpg, close-up | Claim below cue and the scrolled result |
| welcome-skip-confirm-666x374.jpg | "Sure?" skip confirmation |
| opening-paid-star10-first-reveal.jpg, opening-rare-result-1279x720-ui-only.jpg | Paid reveal UI; Rare result controls (3D stage not drawn) |
| deal-popup-soldout-player1.jpg | Plaza deal sold out for Player1 |
| device-sweep-session2.json, device-sweep-session3.json | StudioUI baseline sweep across 12 classes |
| openings-session3.json | Paid batch contents, charges, native result layout and skips |
| multiplayer-session4.json | Two-client native/synthetic/lifecycle results |
| performance-session4.json | Menu/opening repetition and soak samples |
| source-identity.json | 131/131 script hash match for the final session |

The original audit's evidence is in `../../2026-10-09/current-build-audit/evidence/` and was not
modified.
