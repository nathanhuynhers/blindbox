 # Development roadmap

Status: the user accepted the MVP after manual playtesting and authorized autonomous full-game
implementation. Milestones 2-5 are implemented in the current candidate; milestone 6 has code,
original procedural assets and automated checks, with native storage/device/multiplayer release
validation still pending. See [scope](FULL_GAME.md) and [operations](OPERATIONS.md).

Implementation approvals between these milestones are superseded by the user's broader request.
Public deployment, paid mechanics and trading remain outside scope. The milestone definitions
below are review criteria, not claims that every runtime test has passed.

## Current architecture redirection

The implemented candidate now uses fixed open Player Plots, a horizontal three-to-six-slot
Display and cosmetic Shelves: three physical units, three rows, three positions per row.
Players start with three persistent Shelf Units of nine positions. Each carousel turn shifts
one owned unit through three fixed physical positions and wraps; navigation is disabled with
three owned units. Future acquisition adds individual units, with no product-design maximum.
Visitors walk directly between plots. Schema v5 migrates legacy placements; completion tracking
remains but completion rewards are TBD. See [canonical design](PLAYER_PLOTS_AND_SHELVES.md)
and [implementation and verification](PLOT_SHELF_IMPLEMENTATION.md).

The world is now **Blindbox Town** (plaza giant blind box, Market Street, gap gift-box stacks and
statue gardens, hedge edge), with walk-through plot arches, awnings, own-plot spawning, a
server-driven day/night cycle and a presentation-only global leaderboard (schema 8 adds
`boxesOpened`). The leaderboard grants no rewards. See [canonical design](PLAYER_PLOTS_AND_SHELVES.md).

Remaining gate: native Studio multi-client, input, rendering, persistence and performance
acceptance. Final art, shelf customization and individual Shelf Unit acquisition/pricing remain future work.
The economy redesign is authorized and implemented on its branch: permanent duplicate income, soft pity,
collection-tier prices, sequential Coin unlocks for slots 4-6 and a fresh-save reset. See [economy](ECONOMY.md).

## Historical milestones

Milestones 0-6 below record previous planning and review criteria. Room themes, completion
rewards, simulated visitors and visit navigation mentioned there are historical, superseded
features, not current requirements. Follow the current architecture above for new work.

## Workflow for future Codex sessions

1. Read AGENTS.md, the authorized task, relevant docs, current source and Rojo mappings. Confirm
   which milestone is implemented already; these documents are proposals, not implementation evidence.
2. Define the smallest task outcome and acceptance checks. Surface scope conflicts before expanding
   work. Use the document owner for each concern: MVP for exclusions, ECONOMY for tuning,
   DATA_MODEL for schema, ARCHITECTURE for boundaries, GAME_DESIGN for intent, ROADMAP for gates.
3. Implement only that task, using strict Luau and clear ownership. Preserve unrelated user work,
   pinned tools, existing properties, and replication boundaries. Install no new dependency without
   authorization. Do not prebuild later features because their file names appear in the architecture.
4. For implementation work, provision pinned tools with `rokit install` if needed, run
   `wally install` before building/serving, format with `stylua src`, then run
   `stylua --check src`, `selene src`, and
   `rojo build default.project.json -o RobloxWorkspace.rbxlx`. Keep generated output ignored.
   Run relevant domain/integration tests once a harness exists and inspect Luau Language Server
   diagnostics. Report unavailable checks instead of substituting lint for type checking.
5. Fix failures, review the diff for scope/security/lifecycle issues, and update only docs whose
   intended behavior changed. Run affected checks again after corrections.
6. Report changed behavior, verification actually run, limitations, and precise Studio playtest
   steps still needed. Never claim a playtest without running it. Pause at the agreed task gate;
   public deployment and features outside the approved full-game scope need separate authorization.

A useful task request names the milestone/subtask, desired behavior, exclusions, acceptance
criteria, and whether Studio validation is available. Documentation-only changes need link and
diff checks; they do not require tool installation or a gameplay build unless configuration or
source behavior is affected.

