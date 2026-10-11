# Device and visual acceptance matrix

Use this for any change that affects GUI layout, visual presentation, interaction controls, viewport-based rendering, 3D figure framing, or the opening/reveal experience. It complements (does not replace) [quality gates](QUALITY_GATES.md), [existing UI Studio checklist](../ui-redesign/IMPLEMENTATION.md#studio-checklist-not-yet-run), [opening acceptance](../OPENING.md#studio-fixture-and-acceptance), and [full-game operations](../OPERATIONS.md).

## Intended support

The current approved UI direction is **desktop plus landscape phone**. Do **not** silently redesign for portrait or treat portrait as a required fully functional layout. Tablet landscape is a useful extended regression target; check it for major navigation/layout changes or when the change could affect tablets. A rotation/unsupported-orientation message is worth inspecting if implemented, but do not invent one.

Viewport numbers below are **test dimensions**, not assertions about physical display resolutions or Roblox's usable safe area. Device emulator chrome/insets can reduce usable GUI area. Always evaluate `GuiService`/Roblox safe insets and actual visible controls, not just raw pixels.

## Baseline matrix

| ID | Target | Example viewport / emulator | UI/layout change | Visual opening or figure-only change |
| --- | --- | --- | --- | --- |
| D1 | Standard desktop | `1920×1080` | Required | Required for affected presentation |
| D2 | Compact desktop/laptop | `1280×720` | Required | When layout/framing changes |
| M1 | Small landscape phone | `667×375` viewport | Required | Required for affected presentation |
| M2 | Modern landscape phone with inset/notch | Representative Studio phone device preset, landscape | Required | Required for affected presentation |
| T1 | Landscape tablet | Representative Studio tablet preset | Conditional | Conditional |

Select the nearest available supported Studio device/emulator preset if a literal viewport cannot be configured. **Record the actual preset and viewport**, not just the target. Emulated touch does not prove real-device latency, legibility or ergonomics. For a release-risky mobile UI change, also request a real phone pass, recorded separately as pending until performed.

For purely cosmetic figure geometry changes, D1 + M1 are the baseline **in-game** presentation views; D2/M2/T1 are required only if the framing, viewport UI, or aspect-sensitive composition changes. Multi-angle source render review is always separate.

## What to inspect on every affected screen

1. **Bounds and safe areas:** no cropped panel, unreadable label, scroll cutoff or unreachable button; HUD clears Roblox top-bar controls; touch controls, notch and rounded corners do not obstruct actions.
2. **Text and dynamic content:** check short and long collection/figure names, large coin amounts and rates, full/empty counts, shop prices, odds, daily timers, disabled explanations and localized-length-like strings where relevant. No critical text hiding under badges.
3. **Actions and interaction:** primary and secondary buttons remain clickable; touch targets meet the UI brief's **44px minimum** where applicable; no overlap or input blockers; overlays, Close, Back, filters, pickers and dialogs return to the expected state.
4. **Navigation and scrolling:** browse to the last item, including the last row/card; selection and scroll position remain coherent on filter changes, screen reopening and resize. No dead zones under the dock or feedback bar.
5. **State variants:** empty/full, locked/unlocked, loading/error or pending, claimable/unavailable, new/duplicate and modal/popover states when the change touches them.
6. **Input coverage:** desktop mouse/keyboard, simulated touch for phone; gamepad A/B/Y/shoulders, focus visibility and auto-scroll on navigation changes. Verify real device input if available, never infer it from a static screenshot.
7. **Motion/performance:** Reduced Motion where relevant; no unbounded tweens, per-frame loops, instance/connection growth, repeated sound, flashing or loss of control after respawn, rapid reopen, or skip/cancel.
8. **Appearance:** visual hierarchy, spacing, alignment, contrast, fonts, icons, shadows, depth and readable figure silhouettes. Automated UI scripts validate **constraints**, not perceived quality.

Use the correct feature checklist to decide which interactions and variants exist today; don't demand a nonexistent feature solely because it is mentioned here.

## Feature-specific passes

| Feature affected | Extra review |
| --- | --- |
| HUD/dock/top-right actions | World and open-sheet states; desktop dock visibility, phone short-sheet behavior, safe top inset, mobile thumbstick/jump controls |
| Shop/Collection | Grid/filter bounds, last scroll row, panels or phone rail, odds and changing prices, 3D previews, long names |
| Display/Shelves | Picker, disabled/locked slot states, ownership, in-world prompt, shelf carousel; rejoin/multiplayer if behavior changed |
| Opening/Reveal | Every affected rarity, Open 1/Open 10 results, NEW/duplicate, Skip/Continue, camera framing, motion settings, result actions |
| New/replaced figure | Front, 3/4, side, back and beauty vs source sheet; in-game Collection tile/detail, Shop when shown, opening, Display and Shelves, visitor's view; asset load/fallback |
| World interaction / 3D prompt | Relevant interaction distance, both desktop and phone prompt visibility, owner vs visitor, camera occlusion and nighttime legibility |

## Procedure

1. **Before edit:** identify changed screens/states and a reference or expected behavior; capture baseline only if it will help a comparison and the tools are available.
2. **After edit:** use Roblox Studio Play with Device Emulator (or an authorized connected Studio tool). Set D1/D2/M1/M2 per the table; open the affected UI and reproduce changed states.
3. **Functional fixtures:** where applicable, run `tests/StudioUI.client.luau` in the **client Command Bar**; use `tests/StudioScroll.client.luau`, `tests/StudioOpening.client.luau`, and other feature scripts as instructed in their docs. Rerun UI instance-growth checks after repeated navigation, not just once.
4. **Visually review:** if the tooling supports captures, keep before/after shots with matching state and viewport. Inspect the changed composition, not just success output. When visual references exist, compare against those.
5. **Validate inputs:** click/keyboard on desktop, simulated touch on phone and relevant gamepad paths; mark untested physical inputs explicitly.
6. **Report:** use the result table below, with `PASS`, `FAIL`, `NOT RUN` or `N/A` and a short observation or artifact link. If a required row is pending, say the change is implemented but **visual/device acceptance pending**.

### Copyable evidence table

| Case | Viewport/device used | State / input checked | Status | Evidence / issue |
| --- | --- | --- | --- | --- |
| D1 desktop | 1920×1080 | [screen + state] | NOT RUN | [reason or screenshot] |
| D2 compact | 1280×720 | [screen + state] | NOT RUN | [reason or screenshot] |
| M1 small phone | 667×375 landscape | [screen + state] | NOT RUN | [reason or screenshot] |
| M2 inset phone | [preset + actual viewport] | [screen + state] | NOT RUN | [reason or screenshot] |
| T1 tablet | [preset] | [screen + state] | N/A | [why not needed, or evidence] |
| Physical phone | [device] | [touch and readability] | NOT RUN | [pending unless actually checked] |

These are example **unrun** rows, not recorded test results. A PR or change report should replace them with its actual applicability and evidence. Do not claim Studio or real-device acceptance based solely on headless scripts.
