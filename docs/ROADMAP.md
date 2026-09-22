# Development roadmap

Status: proposed sequence, not authorization to implement. Each milestone is a review gate.
Authorize one bounded task at a time; finishing a task does not authorize the next milestone.
The docs describe intended behavior, while source files show what actually exists.

## Milestone 0 — Review the plan

- **Goal:** agree on a small experiment using the existing working tooling.
- **Systems:** documentation and repository baseline only.
- **Dependencies:** none; this planning task is the deliverable.
- **Definition of done:** review the six documents, resolve or accept provisional MVP scope,
  and explicitly authorize a first implementation task. No gameplay or dependencies added.
- **Studio:** no gameplay test applies; optionally confirm the existing starter still connects.
- **Automatic checks:** documentation links, diff/scope review; existing verification commands
  only if changes affect tooling, mappings, or source. Do not provision dependencies for this
  documentation-only task.

Before milestone 1, approve session-only resets, three fixed slots, one six-figure placeholder
collection, manual capped-bank collection, and recycle-to-choice duplicates. Final names, art,
rarity labels, and exact numbers can remain tuning decisions. Requesting changes to this plan
does not itself authorize implementation.

## Milestone 1 — First playable loop (the entire MVP)

- **Goal:** prove open -> collect -> display -> earn -> buy again, with composition and useful
  duplicates. Use [MVP acceptance criteria](MVP.md) as the release checklist.
- **Systems:** public catalog/types, server state and transactions, box/inventory/display/income,
  validated remotes, combined inventory/index UI, fixed room geometry, local visitors.
- **Dependencies:** milestone 0 approval; no saving, framework, asset pack, or package needed.
- **Definition of done:** the MVP checklist passes in closed Studio testing, reset behavior is
  labeled, and observations inform a continue/revise decision. Do not substitute more content
  for a failed loop.
- **Studio:** fresh player tutorial; common-only and duplicate-heavy sessions; reveal skip;
  two clients attempting cross-owner actions; idle/full bank; leave/rejoin reset; low frame rate;
  mouse/touch controls; 10- and 30-minute pacing observations.
- **Automatic checks:** catalog validation, deterministic roll boundaries, conservation and
  reservation rules, diversity/cap arithmetic, malformed requests, replay/stale requests,
  teardown bounds, source format/lint/build, and Luau diagnostics.

Suggested separately authorized tasks, each leaving an inspectable playable increment:

1. **Buy and reveal:** six-entry catalog, minimal session state, authoritative one-box purchase,
   tiny reveal and count UI. Verify balance/item conservation and repeated request behavior.
2. **Place and earn:** one room, three slots, minimal place/remove UI, capped bank and collect
   action, simple visitors. Complete the first loop; test ownership with two clients.
3. **Compose and complete:** distinct-figure bonus, expanded index, recycle/redeem actions,
   completion stamp and onboarding prompts. Test common usefulness and worst-case duplicates.
4. **Evaluate:** usability and abuse checks, fix observed issues, record tuning evidence. Avoid
   starting persistence until the review establishes a reason to keep developing this loop.

## Milestone 2 — A showroom worth returning to

- **Goal:** retain progress safely and offer one bounded showroom expansion.
- **Systems:** persistence/migrations/session ownership, one fixed-cost slot unlock, continued
  use of existing placement and income rules, persistent one-time starter grant.
- **Dependencies:** positive milestone 1 review; explicit persistence implementation/library
  decision and inventory identity review. No library is approved by this roadmap.
- **Definition of done:** rejoin restores balances, inventory, discoveries, slots, bank, and
  progression; failed loads cannot overwrite saves; conflicting sessions cannot mutate the
  same profile; one expansion remains economically bounded. Acknowledgement/durability and
  crash-loss behavior are documented and tested before external progression testing.
- **Studio:** leave/rejoin, expansion then rejoin, failure messages, shutdown/restart, competing
  sessions, corrupted/old-version fixtures, and poor connectivity using isolated test data.
- **Automatic checks:** migration fixtures, load-vs-absent distinction, save retries, session
  exclusion, grant recovery, unlock affordability/idempotency, rate-cap behavior and regression suite.

Task sequence: saving/restoring the existing loop first; recovery and conflict tests next;
one expansion last. Do not build every future backend service before another playable benefit.

## Milestone 3 — Deeper collecting and expression

- **Goal:** make another collection and display choice worthwhile without multiplying income.
- **Systems:** second original collection, one explicit themed-shelf bonus, cosmetic completion
  plaque, and a small customization choice; existing redemption remains available.
- **Dependencies:** milestone 2 data safety, approved original content budget, and revised
  slot/bonus budget supporting actual set sizes. No variants by default.
- **Definition of done:** new content is added through definitions/assets; common figures remain
  relevant; completing a set grants its cosmetic once; no dominant rare-only strategy emerges.
- **Studio:** compare themed versus mixed displays, new/old collection pacing, plaque readability,
  returning-player experience, and existing collection completion after content changes.
- **Automatic checks:** definition references, bonus eligibility/caps, completion reward claims,
  compatibility fixtures, no unintended change to existing IDs or ownership.

## Milestone 4 — Modest reasons to return

- **Goal:** test repeat-session appeal after collection/showroom play is enjoyable.
- **Systems:** one daily free box and one simple collection/display goal, added sequentially.
  Streaks, rotating availability, and seasons remain deferred unless evidence supports them.
- **Dependencies:** reliable persistent claims, server time rules, economy review, and returning
  playtesters. The core loop must work without the free reward.
- **Definition of done:** each reward is server-validated and recoverable, cannot be claimed twice
  at a time boundary or reconnect, and does not replace normal earning/collecting goals.
- **Studio:** first/returning/missed-day sessions, claim during interruption, understandable
  eligibility feedback, and optional-goal usefulness.
- **Automatic checks:** injected-time boundary tests, repeated claims, concurrent requests,
  inventory-full reward handling, save interruption and grant reconciliation.

## Milestone 5 — Show others the collection

- **Goal:** validate social pride with same-server showroom visits and public display inspection.
- **Systems:** visit navigation, observer presentation with visibility limits, public catalog
  inspection. Likes, wishlists, featured rooms, and leaderboards require later individual tasks.
- **Dependencies:** safe room ownership, stable public/private projections, performance budgets,
  and enough visual variety to make visits interesting.
- **Definition of done:** a guest can visit/inspect but cannot modify or collect from the host;
  observer visitors/models stay bounded; hosts leaving cleanly returns visitors to a valid state.
- **Studio:** multiple hosts/guests, join/leave during visits, attempted unauthorized edits,
  touch navigation, crowded room performance and visual clutter.
- **Automatic checks:** public-state allowlist, access rules, cleanup, bounded replication and
  unchanged inventory/bank after guest interactions.

Trading is not included. A separate go/no-go proposal must address per-item identity migration,
two-profile transfers, duplication/replay attacks, recovery, audit, and economy effects before
trading work is authorized. Variants/crafting are likewise separate optional branches.

## Milestone 6 — Launch readiness for the approved feature set

- **Goal:** make the chosen scope reliable and understandable for real players.
- **Systems:** original final assets, onboarding polish, accessibility/input support, performance,
  operational recovery, limited metrics and release procedure. Monetization is optional separate scope.
- **Dependencies:** approved launch feature list, passing persistence/security gates, content
  rights review, and current platform-policy review for any proposed paid/random mechanic.
- **Definition of done:** agreed device/player-load targets pass; recovery and rollback are
  rehearsed; no known ownership/currency duplication path; new users understand the loop;
  remaining risks are recorded and accepted before release. Release requires explicit authorization.
- **Studio:** multi-client soak, mobile input/performance, reconnects and failures, missing assets,
  first-session comprehension, effects/sound readability, and launch-build regression checklist.
- **Automatic checks:** full regression and migration suites, configuration validation, pinned
  formatting/lint/build/type checks, and release diff review. Tests do not prove policy compliance
  or replace live device evaluation.

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
   broader milestones and public deployment need their own authorization.

A useful task request names the milestone/subtask, desired behavior, exclusions, acceptance
criteria, and whether Studio validation is available. Documentation-only changes need link and
diff checks; they do not require tool installation or a gameplay build unless configuration or
source behavior is affected.
