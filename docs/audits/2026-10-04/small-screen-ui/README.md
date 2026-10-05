# A05 / A06 small-screen UI acceptance

2026-10-04. Fresh managed worktree from `origin/master` at `c90cd23`.
Disposable, unpublished Studio place; existing assets and presentation-only snapshots.
No live profiles, published place, dependencies or opening-camera implementation changed.

## Reproduction and changes

- **A05 reproduced before editing:** discovered/selectable Grove tiles measured **36×44**
  at iPhone 7's effective **666×374** safe area and **42×44** in the wider Android fixture
  pane at **705×338**. Columns now follow available width, the 44px target and an 8px gap.
  Native targets are **49×44** on iPhone and **46×44** on Android. All figures remain present.
  The product pane scrolls when necessary, preserving preview, progress, prices, Welcome/free
  box, Open 1 and Open 10 beside the independently scrolling contents and odds.
- **A06 reproduced before editing:** Android position 9 ended at **Y=280**, beyond the
  clipping body's **Y=272** boundary. The carousel now stays fixed above an independent
  cabinet scroller, separate from the picker. An overflow-only “Scroll for bottom shelf ↓”
  hint and scrollbar expose scrolling. At the Android scroll end, position 9 ends at **Y=224**,
  inside its **Y=250** window and **Y=272** body; its target is **82×48**. All nine positions
  are reachable. The iPhone and laptop cabinets fit without scrolling or a hint; desktop
  density and three visible unit tabs are retained.
- The wider screen pass exposed two small existing bounds errors: Goals' last collection
  target extended 2px beyond its canvas; Settings ended at Y=358 in a 338px safe height.
  Goals now includes its descendant row extent; Settings shifts up only when needed.

Measurements use native Roblox UI coordinates, not scaled screenshot pixels. Discovered fixtures
are controlled presentation data, not a claim that these figures were naturally earned.

## Before / after evidence

| Case | Before | After |
| --- | --- | --- |
| iPhone Shop | [36px targets](before-iphone-shop.jpg) | [49px targets](after-iphone-shop.jpg) |
| Android Shelves | [Clipped row](before-android-shelves.jpg) | [Scroll hint](after-android-shelves.jpg), [reachable last row](after-android-shelves-end.jpg) |
| Android Shop | Baseline measurement above | [Initial view](after-android-shop.jpg), [13 figures / odds / free-box endpoint](after-android-shop-scroll.jpg) |
| Settings | Baseline bounds above | [Android](after-android-settings.jpg), [iPhone](after-iphone-settings.jpg) |
| Native controller result | Opening fixes already merged | [Android](after-android-reveal.jpg), [iPhone](after-iphone-reveal.jpg) |
| Open 10 summary | Existing summary retained | [Android](after-android-summary.jpg), [iPhone](after-iphone-summary.jpg) |
| Taller cabinets | Existing density retained | [iPhone](after-iphone-shelves.jpg), [laptop](after-desktop-shelves.jpg) |

## Checks actually completed

- Pinned `rokit install` and `wally install`; zero dependencies retained.
- `stylua src`, `stylua --check src`, `selene src`: passed, zero lint errors/warnings.
- Rojo 7.7.0 build and sourcemap: passed.
- Luau LSP 1.70.1 analyze with Roblox definitions and sourcemap: exit 0, no source diagnostics;
  existing standalone watcher-registration warning only.
- Full standalone suite passed, including **1,091 screen checks**. New checks render unknown
  Shop state, discover figures, then inspect actual screen sizing for every collection. They
  cover found/unknown/selected/disabled component states, minimum targets, separation, purchase
  reachability, nine Shelf positions, sibling scrollers and Settings containment. Engine doubles
  run real modules but do not render Roblox UI.
- Native Samsung Galaxy A06 landscape (**705×338**) and iPhone 7 landscape (**666×374**).
  `DeviceSafeInsets` and `LandscapeSensor` retained. Shop, Collection, Display, Goals, Shelves,
  Daily Login and Settings were rendered and inspected at both sizes. Expanded native target,
  descendant-clipping, canvas, safe-area and hit-order checks passed. All five Shop collections
  passed, covering 5-, 6- and 13-figure counts.
- Expanded `StudioScroll.client.luau`: Shop product/contents, 13-figure Collection and Shelf
  cabinet/picker endpoints passed on both phones, restoring scroll positions afterwards.
  Cabinet scrolling left the picker unchanged. Laptop Shelves also passed UI and endpoint
  checks at **1365×768**, UIScale approximately **1.07**.
- `StudioOpeningLayout.client.luau`: **484 assertions** passed across four native direct-result
  cases (single and intermediate batch on both phones), using the merged controller, production
  Pebble model and reduced motion. Includes model projection, text fit, safe areas, minimum
  targets and hit order. This is presentation acceptance, not a new server-confirmed purchase
  walkthrough or full rarity/camera re-certification.
- Open 10 summary: ten result cards, six collection progress tiles and Done fit at both sizes;
  the new summary branch in `StudioUI.client.luau` passed.
- Actual Play hit order checked against `PlayerGui.TouchGui`: Shop/Shelf controls at scroll
  endpoints and result actions receive input. Home is hidden while the real Interface opens
  Shelves. Faint movement controls can remain visible in reveals but did not win tested action hits.

Fixture setup errors (missing expansion cost, global rather than sibling Z ordering and a Studio
tool camera-reset boundary) were corrected before final runs. The unpublished place logged its
existing leaderboard DataStore retry. No fixture grants or test scripts are Rojo-mapped. Native
instance-count baselines were cleared between newly constructed screens; no native leak-free
claim is made. Standalone lifecycle/reuse coverage passed. Play and device simulation were stopped.

## Repeat native checks

Build, start Play and use each phone preset in landscape. Discover a Grove figure through the
Welcome Box or a Studio fixture; empty discovery data alone is insufficient A05 acceptance.
Open Shop and switch through 5-, 6- and 13-figure collections, including funded Open 10 and free-box
states. Run `tests/StudioUI.client.luau` and `tests/StudioScroll.client.luau` in the CLIENT Command Bar.
Repeat on Collection (All / 13 figures) and Shelves, including cabinet endpoints, all unit tabs and
a populated picker. Check the other menus, Settings, settled reveal with
`tests/StudioOpeningLayout.client.luau`, and Open 10 summary with `tests/StudioUI.client.luau`.
Wait for viewport/preview updates before measuring.

## Physical-device acceptance — unavailable

Studio emulation does not certify physical touch or device-specific rendering. On real Android
and iPhone hardware, repeat both short safe-height cases, tap discovered figures and all nine
Shelf positions, scroll cabinet/picker independently, switch the carousel, use free box / Open 1 /
Open 10 and check movement/jump/Home priority. Repeat rotation, notch safe areas and low-quality
rendering. This gate remains pending; no physical-device pass is claimed.
