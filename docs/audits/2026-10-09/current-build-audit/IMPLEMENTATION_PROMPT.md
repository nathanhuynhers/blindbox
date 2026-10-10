# Blindbox Town — finish the current game and prepare a controlled playtest

Copy the prompt below into the implementation chat. It authorizes implementation and verification of the current-build audit findings; it does not authorize new roadmap features or publication.

---

Bring the CURRENT IMPLEMENTED BUILD of Blindbox Town to a polished, reliable state ready for a controlled external playtest. Implement the required fixes, actually test them in Roblox Studio, and produce an evidence-based readiness decision. Continue beyond planning until the authorized work is complete or the remaining acceptance cases have concrete external blockers.

Use this audit as the starting point:
- docs/audits/2026-10-09/current-build-audit/REPORT.md
- docs/audits/2026-10-09/current-build-audit/COVERAGE.md
- docs/audits/2026-10-09/current-build-audit/WALKTHROUGH.md
- docs/audits/2026-10-09/current-build-audit/evidence/

The audited gameplay source was commit 4b50fb76debb34507e0bc6a6b242a26d501412be. Establish the actual current branch, commit, working-tree changes and Studio source before proceeding. Reproduce findings against the current build; do not assume intervening changes preserved them. Keep the original audit as historical evidence and record new results separately.

## Scope and guardrails

Follow AGENTS.md. Read GAME_DESIGN.md, archive/MVP.md, ROADMAP.md, ARCHITECTURE.md, DATA_MODEL.md, ECONOMY.md, PLAYER_PLOTS_AND_SHELVES.md, OPERATIONS.md, OPENING.md and the active UI redesign guidance before changing the relevant systems. Distinguish implemented behavior, accepted direction, historical references and unresolved proposals.

“Finished” means the current implemented game works consistently and has no unresolved defects blocking its controlled test. It does not mean implementing every proposed roadmap feature. Preserve the existing collection catalog, economy, pity rules, server authority, schema contract and landscape phone direction unless a demonstrated defect requires a focused change. Trading, premium purchases, visit directories, customization and other future proposals are outside this task.

Preserve user work. The audit session left eight pre-existing documentation edits untouched; inspect the current worktree and keep unrelated edits intact. Use focused commits. Preserve pinned tools, Rojo instance structure, strict Luau and replication boundaries. Do not add dependencies, upgrade tools, create or publish an experience, enable production API access, modify live records, delete saves, or change system time. Read FIGURE_COLLECTION_RUNBOOK.md before any necessary figure asset work.

Implement fixes and bounded regression coverage autonomously. Ask only for genuinely missing external access or a material design decision, explain the exact blocker, and continue independent work.

## 1. Resolve the five confirmed findings

**AQ01 — World touch controls obstruct menus.** Fix the shared modal layering/input policy so TouchGui cannot intercept menu actions. Reproduce Shelves/Sunbeam Sprite at measured 666×374 and 749×388/389, and Display/Equip Best at 959×599. Inspect whole target areas, not only centers. Preserve the project's 44px target minimum and comfortable separation. Verify modal open/close, route changes, Home, respawn, cinematic entry/exit and GUI recreation restore movement, camera and input ownership correctly. Do not only relocate the three reported controls.

**AQ02 — Compact Display cards overflow.** Rework compact layout or bounded information placement so all six slots remain understandable and reachable, with readable prices, Unlock labels, shortfalls, bank values and rates. Do not globally shrink text to hide overflow. Exercise 666×374, 705×338, widths 899/900/901 at height 700, and heights 559/560/561 at width 1000. Include empty/occupied/full slots; zero and large balances/banks; affordable, insufficient and pending states; sequential 40K/400K/4M unlocks. Test the actual rendered components against their own containers and padding, not just the viewport.

**AQ03 — Collection rate loses its unit.** Fix the detail stats so a meaningful income unit remains readable for duplicate-adjusted and large rates. Reproduce Pebble Pip ×2, approximately 4.73 coins/s, at 1279×720 and 1023×768 and probe neighboring layout thresholds. A consistent short unit, wrapping or appropriate stat-column reflow is acceptable. Capture the missing complete screenshot and close-up; the old numeric measurement alone cannot close this finding.

**AQ04 — Batch result names cannot be fully identified.** Make every awarded figure's full name readable or discoverable through an obvious, reachable mouse/touch/controller interaction. Preserve all ten results, NEW/duplicate semantics, rarity, counts, completion progress and Done/origin navigation. Test Welcome x10, paid batches, fewer-result rewards, long names, repeated duplicates and 13-figure collections at 666×374, 705×338 and the actual summary-height 419/420/421 threshold. An AccessibleName attribute alone is insufficient visible disclosure.

**AQ05 — Active guidance and fixture contradict the game.** Reconcile current schema-14 operational/migration guidance, sequential six-slot expansion and the retired Redeem protocol across the cited ROADMAP, OPERATIONS, UI BRIEF/IMPLEMENTATION, OPENING and StudioSystemScreens references. Preserve clearly historical material as historical. Update the obsolete fixture to assert the current six-slot contract meaningfully; do not change accepted gameplay to satisfy stale mockups or weaken assertions to hide failures.

Address **DR01** with a focused improvement to the short Goals card's claim discoverability, such as a clear scroll cue or persistent action, if the current layout still needs it. Preserve reachable content and avoid unrelated redesign.

## 2. Complete the player experience and regression pass

Inventory every implemented screen, popup and world action using COVERAGE.md. Give each primary surface a baseline visual inspection across the 12 representative device classes. Run deeper states on the smallest/shortest phone, standard desktop and layouts affected by each change. Record measured viewport, usable safe area and UI scale; simulator preset names are not physical-device certification.

Inspect text, spacing, hierarchy, icons, contrast, pending/disabled/error feedback, scrolling endpoints, overlays and control separation at normal viewing size. Check long names, large currency/rate/duplicate counts, changing labels and empty/loading/error states. Test width and height independently around relevant breakpoints. Respect landscape enforcement and verify rotation recovery without inventing a portrait redesign.

First repeat a fresh-player Welcome journey using ordinary native input, before grants or tutorial bypasses: join/load/spawn, Welcome Box, Display, earned Coins and world collection, funded purchase, tutorial x10/summary, Shelf placement/completion reward, Goals, Login, settings and Home. Record milestone times with instrumentation pauses identified.

Then use labelled isolated fixtures for progressed and expensive states. Cover Collection filters/details; Display placement/swap/removal/Equip Best/bonuses/retained banks; Shelf navigation/copy limits/full units/purchases; Shop odds/pity/free and paid openings; plaza offers and per-player stock; Goals, Daily Login and offline popup states; leaderboard loading/error/last-good behavior.

Verify opening presentation across all five implemented rarities and applicable collections, NEW and duplicates, Open 1/Open 10, Skip at each phase, View all results, Done/origin, normal/reduced motion, day/night and low/high graphics. Unsupported collection/rarity pairs are not missing content. Check models, framing, names/artwork, asset loads, sound settings and cleanup. Subjective audio acceptance requires actual listening.

Use native mouse/keyboard and real touch/gamepad where available for selection, scrolling, sliders, prompts and world controls. Exercise rapid/repeated actions, pending and stale/failed/lost responses, close/reopen, reset/death, Home during cinematics, leave/rejoin, resize/rotation, focus loss/resume, input switching and GUI recreation. Fix reproducible defects in existing functionality, with particular attention to duplicate rewards, lost currency, stale UI and stuck controls. Distinguish native activation from callbacks, synthetic remotes and geometry fixtures.

## 3. Close the environment, service and performance gates honestly

Recover a working Studio renderer first: the prior session ended with stalled capture/input and a 1×1 viewport. Do not count that as rendered acceptance. Recapture AQ03 and AQ04 measurements and verify the exact running source. Use approved tools; do not bypass app/browser security restrictions.

Run a real two-client Studio test for owner/visitor permissions, private state, concurrent purchases/claims, retry idempotency, per-player deal stock, stale/malformed requests, disconnect cleanup and plot reassignment. The old two-client results used real engine clients but synthetic requests and no valid rendered UI; rerun affected checks and add native visitor/world interactions.

Use real persistence only in an existing authorized private test experience with isolated stores, following OPERATIONS. Verify save/rejoin, settings, reward durability/idempotency, offline earnings, current migrations, leases and load/save failure behavior. Use existing safe fixtures for clock boundaries and injected failures. If real stores or reward-boundary conditions are unavailable, leave those acceptance gates open with a precise handoff; do not touch production settings or system time.

Check the existing experience's enabled platforms/languages before claiming applicability. Verify physical touch, actual gamepad input/focus/Back and relevant enabled console/VR/localization paths when available. Keyboard-generated gamepad key codes are not a controller test.

Measure low/high graphics with eight occupied plots, full Shelves/Display, large lists, repeated openings and menu transitions. Run a fixed-viewport warmed cleanup/repetition check and roughly 30-minute representative soak when tooling permits. Record hardware, foreground/background state, FPS/frame times, memory, instances, owned connections/tasks and available network metrics. Investigate growth that persists after cleanup. The earlier editor's 15 FPS and rising memory were confounded observations, not a proven game leak or hardware benchmark. Avoid speculative optimization; fix measured problems.

Track blockers B01–B07 from COVERAGE.md individually. Close each only with new evidence; otherwise identify the exact needed device, approved rendering/reference surface, existing private place or service access. Continue repository and other independent testing while external gates are blocked.

## 4. Verification and deliverables

Provision pinned tools with rokit install if needed; run wally install before builds. Format changed source with stylua src and verify stylua --check src, selene src, Rojo build/sourcemap, Luau Language Server diagnostics, existing tests/run.py suites and applicable Python regressions. Run current native UI, scroll, opening, lifecycle and corrected system-screen fixtures. Add focused tests for changed behavior and meaningful failure/recovery paths; formatter/lint/build passes do not prove runtime or visual quality.

Create a new dated remediation package under docs/audits/ with:
- A concise change report mapping AQ01–AQ05 and DR01 to fixes and verification.
- Updated coverage with Pass/Fail/Blocked/Not run/Not applicable, evidence links and explicit omissions.
- A fresh-player walkthrough and labelled progressed/multiplayer/service results.
- Full screenshots plus close-ups for each UI fix, exact text/state/viewport/safe area/scale, failing-size and neighboring-threshold checks.
- Actual commands/results/warnings, source identity, performance conditions, cleanup and remaining manual gates.

Do not overwrite the original audit's findings or fabricate missing historical evidence. Retest previously passing neighboring behavior affected by shared UI changes. Clean up owned test resources and return Studio to a usable state.

Finish with an honest decision: **ready for a controlled playtest**, **ready only for specified limited test conditions**, or **blocked**, supported by evidence. All five findings must be resolved or explicitly documented with their current reproduction and blocker; critical unsupported gates cannot become PASS by assumption. State public-release holds separately from readiness to run the next controlled test. Never claim “bug-free,” “all devices passed” or “fully complete” without evidence. Include changed files/commits, checks actually run, remaining risks and exact next manual actions.
