# Change-aware quality gates

This document is the **verification router** for agent-authored and human-authored changes to Blindbox Town. It does not replace the engineering rules in [AGENTS.md](../../AGENTS.md), the release checklist in [OPERATIONS.md](../OPERATIONS.md), the UI Studio checklist in [ui-redesign/IMPLEMENTATION.md](../ui-redesign/IMPLEMENTATION.md), the opening checklist in [OPENING.md](../OPENING.md), or the [figure collection runbook](../FIGURE_COLLECTION_RUNBOOK.md).

**Principle:** choose tests from the actual change surface, run what can be run, and report the remainder honestly. A code change is not visually or behaviorally verified merely because it builds. Conversely, a documentation-only edit does not require a Roblox Studio playtest.

## 1. Determine the change surface

Before making edits, inspect the smallest relevant code, configuration and documentation. Identify the affected subsystems and select the **union** of their gates below. Classify dependencies and effects, not just modified file extensions: for example, changing a figure asset can affect Collection previews, Reveal, Display, Shelves and other players' views even when no `src/client` file changes.

| Change surface / typical files | Required verification | Primary detail |
| --- | --- | --- |
| **UI, HUD, layout, navigation** — `src/client`, UI art and labels | Targeted automated tests; responsive viewport matrix; mouse/touch; relevant gamepad interactions; visual review of affected states | [Device matrix](DEVICE_TEST_MATRIX.md) and [UI Studio checklist](../ui-redesign/IMPLEMENTATION.md#studio-checklist-not-yet-run) |
| **Opening, rarity presentation, reveal, audio** | Relevant opening tests/fixtures, rarity and skip/cancel behavior; desktop/phone framing; audio and reduced-motion checks when affected | [Opening acceptance](../OPENING.md#studio-fixture-and-acceptance) |
| **Figure or collection assets / 3D** — models, materials, asset wiring, catalog | Runbook build/validation; render-to-reference comparison; runtime preview on affected surfaces; loading/fallback and multiplayer if exposed publicly | [Figure runbook](../FIGURE_COLLECTION_RUNBOOK.md), sections 4–9 |
| **Server gameplay, economy, inventory, progression** | Relevant deterministic Luau tests; protocol/auth checks; failure/retry and duplicate-action cases; Studio multiplayer where relevant | [Operations](../OPERATIONS.md#automated-verification) |
| **DataStore, profiles, migrations, offline rewards** | All relevant storage/schema and failure-injection tests; isolated persistence rejoin; forward/backward compatibility and release impact review | [Operations](../OPERATIONS.md#persistence-guarantees-and-limits) and [data model](../DATA_MODEL.md) |
| **Plots, Display, Shelves, social interactions** | Ownership/distance and replication tests; at least two Studio clients for affected behavior; populated-world performance when relevant | [Plot/Shelf implementation](../PLOT_SHELF_IMPLEMENTATION.md) |
| **Tooling, scripts, build pipeline** | Execute the changed command with safe fixtures or dry runs; confirm generated files/locks remain correct; run affected pipeline tests | [Asset pipeline](../ASSET_PIPELINE.md) and [Operations](../OPERATIONS.md) |
| **Documentation only** | Validate links, paths, commands and internal consistency; confirm no unintentional source changes | This document |

For cross-cutting changes, **combine** the applicable gates. Do not test unrelated features just to produce an impressive checklist; expand scope when architecture or regression risk justifies it.

## 2. Verification ladder

### A. Static / local checks (when source or build inputs change)

Use the tool versions pinned in `rokit.toml`. From the repository root:

```bash
rokit install
wally install
stylua --check src
selene src
rojo build default.project.json -o RobloxWorkspace.rbxlx
```

For Luau domain/regression changes, also run the existing test harness with an **available, compatible standalone Luau executable**:

```bash
python tests/run.py build/tools/luau/luau.exe
```

That executable lives in a locally ignored build path in the documented setup; install or supply it rather than assuming it exists on every agent host. Use Luau Language Server diagnostics when changing typed Luau. Add or update targeted tests when behavior changes and a suitable test harness exists.

For an **asset-only** change, run the existing asset/figure pipeline's scoped validation and tests per its runbook; run source checks when the pipeline alters Luau source or manifests. Do not use `--no-checks` for real figure publication. For a **docs-only** change, verify the Markdown links and exact repository paths; the above code checks are not required.

### B. Runtime checks (when Roblox behavior changes)

Use Roblox Studio Play, Studio test clients, or Studio MCP **only when access is available and it materially helps**. Run the relevant scripts, not all scripts indiscriminately. The repo has, for example:

- `tests/StudioUI.client.luau` for UI safe bounds, targets and instance growth.
- `tests/StudioScroll.client.luau` for Collection scroll end-state.
- `tests/StudioOpening.client.luau` for opening presentation fixtures.

Consult the specific runbook/checklist for other `tests/Studio*.client.luau` fixtures, preconditions and whether they belong in the **client Command Bar**. Some tests are read-only and others use fixtures; respect those distinctions. Verify actual interaction flows in Studio because headless tests cannot prove rendering, input or replication.

A Studio emulator is **not** a physical-device test; record them separately. If Studio or a device is unavailable, record that check as **NOT RUN** with a precise remaining manual step. Do not turn an unperformed test into a pass or silently treat it as N/A.

### C. Visual review

For UI, opening, and 3D presentation changes, use the [device matrix](DEVICE_TEST_MATRIX.md). Inspect the actual changed states at required sizes. When screenshots/captures are available, compare with the intended reference and attach or link evidence; name viewport, screen, state and date. A successful bounds assertion is not approval of aesthetics, composition, silhouette, legibility or motion. If visual access is unavailable, mark visual acceptance pending.

For figures, follow the runbook's explicit **sheet-as-source-of-truth** and multi-angle review. Recheck in-game previews (including smaller surfaces) after asset replacement. The runbook's standing approval to upload reviewed figure assets **does not** authorize publishing a new live Roblox place/game version.

## 3. Special gates for live-game safety

The game has been described by its owner as live; some older docs describe an earlier closed-test state. **Confirm actual deployment state before release decisions.** This file does not certify the currently deployed profile schema, publish state or test coverage.

- Keep private Studio/persistence tests separate from live player profiles and live DataStores. Never run destructive migration, reset, repair, fault injection or profile fixtures against live accounts.
- Any storage/schema change requires explicit migration and compatibility analysis, upgrade/rejoin tests against isolated stores, and a forward-only/rollback plan that does not erase legitimate progress. Existing live servers may overlap a new deploy; check mixed-version writer safety.
- For purchases, rewards, inventory, currencies and saves, retain server authority, idempotency and failure-safe behavior. Test retries, partial failures and replay paths.
- Do not publish the live experience, change production DataStore contents, or force server restarts as a side effect of coding/verification without a separate release instruction.
- A previously approved figure-asset publishing workflow remains governed by the figure runbook and is distinct from deploying the live game.

The comprehensive **release gate** remains [OPERATIONS.md](../OPERATIONS.md). Passing change-scoped checks is not permission to ship.

## 4. Evidence and definition of done

Use these statuses consistently:

| Status | Meaning |
| --- | --- |
| **PASS** | The check was actually run and succeeded; include command or device and meaningful output/evidence. |
| **FAIL** | The check ran and failed; include the failure and follow-up. |
| **NOT RUN** | Required/valuable, but blocked or unavailable; specify why and who/what can complete it. |
| **N/A** | Not relevant to the change; give a short reason if non-obvious. |

An implementation may be called **implemented** after code changes, but must not be labeled **fully verified** while required checks are FAIL or NOT RUN. Record pending review without blocking unrelated tasks. Do not claim a screenshot was captured, a Studio session ran, a phone was tested or an asset published without actual evidence.

Report in this compact format (a PR description can use the same fields):

```text
Changed: [what and where]
Affected gates: [UI / Opening / Figure / Gameplay / Persistence / ...]
PASS: [commands, fixtures, Studio device/state, links]
FAIL: [failed checks and consequences, or none]
NOT RUN: [required pending checks + reason, or none]
N/A: [important skipped categories if relevant]
Release impact: [none / manual review / migration or compatibility risk]
Remaining: [specific next actions]
```

For a small docs-only patch, a concise note that links/paths were reviewed and no runtime checks were applicable is sufficient. Prefer precise evidence over lengthy test narration.

## 5. Worked selection examples

- **Move a Shop button:** UI gate. Inspect Shop on desktop and the two phone landscape cases, check reachability/touch/overlap, run applicable UI scripts; server persistence tests are N/A unless request flow changed.
- **Replace one collectible mesh:** Figure gate. Validate export/reference, load status, Collection/Reveal/Display/Shelves framing at representative desktop and phone sizes, and another client's view where the model is replicated.
- **Change a coin reward:** Economy gate, plus UI gate only if presentation changed. Test server authority, transaction retries and relevant visible values.
- **Change a saved profile field:** Persistence and gameplay gates, isolated rejoin and migration/old-server compatibility review. No live publishing as part of the task.
- **Fix a typo in a Markdown file:** Docs-only gate; runtime checks N/A.
