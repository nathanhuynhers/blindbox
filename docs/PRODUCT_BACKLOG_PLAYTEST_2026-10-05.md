# Product Backlog — Playtest Round 2 (2026-10-05)

This document tracks the next batch of follow-up work captured from playtesting after the original
[Product Backlog](PRODUCT_BACKLOG.md). Tasks are separated by implementation surface so it is easy to
distinguish gameplay/system work from UI, visual, world, animation and experience work.

Agent labels in this document are **recommendations, not ownership rules**:
- **Codex** is a good fit for contained pure-logic, backend, economy and gameplay-system tasks.
- **Claude** can handle both logic and UI, and is generally the better fit when a task involves
  substantial UI/UX, visual design, world-building, animation or cross-cutting implementation.
- **Codex** is also reasonable for very small or straightforward UI changes when a separate design
  pass would add little value.
- Use whichever agent is the better fit for the actual scope once the task is opened.

Mixed features are split into paired logic and presentation tasks when that makes the work easier to
reason about, but the same agent may handle both parts when appropriate.

## Verified existing behavior — no new task

- **Duplicates already increase money generation.** The current economy applies a rarity-dependent
  duplicate multiplier to a displayed figure's effective income rate. The existing audit also records
  the duplicate rate-gain issue as fixed. Do not create a new duplicate-income feature unless a future
  playtest finds a concrete mismatch.
- **Pity is already implemented.** High-tier five-rarity collections track server-owned Legendary and
  Mythical dry-roll pity. The Shop already shows current odds versus base odds when pity changes them,
  but the raw counters are intentionally private today. A new UI task below intentionally adds a
  player-facing pity presentation using server-authoritative state.
- **Pocket Grove / other three-rarity starter collections do not have Legendary/Mythical pity** because
  those rarities are absent.
- **Starter boxes being smaller than the others is already fixed** and is not part of this backlog.

---

# Bug Fixes

## UI / World / Design bugs

**Agent recommendation:** Claude for visual/world investigation or polish; Codex is also fine when the
fix is a simple instance/code cleanup with little design judgment.

### BUG-UI-01 — Remove the white tile in the middle of the plaza

- Find the incorrect white tile/part in the plaza and remove or replace it so the plaza floor is
  visually continuous.
- Verify the fix in Studio from normal gameplay camera angles.
- Do not alter unrelated plaza geometry.

Implementation: the pale tile was the runtime `MainWorld.MainPlaza.PlazaSpawn` marker, whose
top protruded 0.02 studs above the paving. `PlazaFixture` now makes that already noncolliding
marker invisible while retaining its enabled spawn routing. The original solid `PlazaSurface`
covers the full footprint; no floor geometry or collision was removed.

### BUG-UI-02 — Remove the stray Pebble Pip from the plaza

- Investigate why a Pebble Pip figure/model is sitting loose somewhere in the main plaza.
- Remove the unintended world instance while preserving the real collectible asset and any legitimate
  uses of Pebble Pip in boxes, inventory, Display, Shelves or previews.
- Verify it does not reappear after a fresh server/session.

Implementation: the inspected Studio place retained the old direct Workspace model
`EXPORT_PebblePip` (21 imported `PP_*` parts), outside the town placement registry. Rojo preserves
unmapped Workspace children, so `World.create` removes only that exact direct-child Model on
each server/world build. The canonical `grove.pebble` production template uses eight
`PebblePip_*` parts and remains registered and available; figure loaders and consumers are unchanged.

---

# New Implementation — Pure Logic / Gameplay Systems

**Agent recommendation:** Codex is usually the most efficient choice for contained logic-only work.
Claude is also a good choice when the logic task is coupled to broader feature implementation or when
you want one agent to carry the feature through end-to-end.

### LOGIC-01 — Per-figure Display pressure-plate collection

Paired with **UI-01**.

- Add one collection trigger for each occupied Display figure/slot.
- Walking over a figure's corresponding plate collects **only that figure's currently banked Coins**.
- This is not an "collect all Display Coins" plate.
- Reuse the existing authoritative per-figure collection/transfer path rather than trusting a
  client-supplied amount.
- Preserve ownership checks, debouncing/rate limits, wallet limits, bank fractions and anti-double-
  collection behavior.
- Empty slots must not produce collectible income.
- Support all currently unlockable Display widths/slots.

### LOGIC-02 — Auto-collect a figure's bank when it is swapped out of the Display

- When a player replaces a displayed figure with another figure, settle the outgoing figure's current
  earnings and attempt to collect its bank before completing the swap.
- Reuse the existing server-owned collection primitive.
- Never silently destroy uncollected value if the wallet cannot accept the full amount.
- Preserve atomicity/idempotency so retries cannot duplicate Coins.
- The resulting placement must still obey unique-figure Display rules.

### LOGIC-03 — Increase the default player walk speed

- Increase the game's baseline movement speed so normal traversal feels faster.
- Do **not** add sprinting in this task.
- Keep the implementation centralized/configurable because additional movement speed is planned as a
  future monetization/upgrade vector.
- Exact final speed can be tuned through playtesting.

### LOGIC-04 — Physical plot Shop interaction

Paired with **UI-07**.

- Add an interaction point for the physical Shop on each player's plot.
- When the player is close enough, pressing **E** opens the existing Shop UI.
- Interaction behavior should feel consistent with the existing Display and Shelves world prompts.
- Opening the physical Shop should use the existing Shop/economy purchase flow rather than creating a
  second store backend.
- Cleanly handle leaving range, respawn, plot teardown and ownership/session changes.

### LOGIC-05 — Hourly limited-stock discounted plaza shops

Paired with **UI-08**.

- Add small plaza shops that sell a limited selection of blind boxes at a discount.
- Inventory rotates on an hourly cadence.
- Stock quantity must be enforced server-side and purchases must use the authoritative economy path.
- The rotation should choose from valid collection boxes and expose enough server-owned state for the
  UI to show the current selection, normal price, discounted price, remaining stock and refresh time.
- Do not allow retries, reconnects or rapid clicks to duplicate stock or purchases.
- Keep discount amount, stock counts and selection weights configurable for economy tuning.
- Limited stock is **per player**. One player's purchase must not reduce another player's stock.
- The hourly offer rotation is **globally synchronized across all servers**: every server should show
  the same offers for the same hourly window.
- Derive the active rotation from a shared deterministic time window/server-authoritative schedule so
  reconnecting or server hopping cannot reroll the offers.
- Persist each player's purchased quantity for the active rotation window so joining another server
  cannot reset their personal stock.
- When the next global hourly window begins, the offer set and each player's personal stock refresh
  to that window's configured inventory.

### LOGIC-06 — Equip Best Display loadout

Paired with **UI-09**.

- Add an authoritative "Equip Best" action for the Display.
- Automatically choose the owned figures that maximize the player's current Display income for the
  number of unlocked slots.
- Account for:
  - each figure's effective income rate,
  - duplicate multipliers,
  - the unique-figure-ID Display rule,
  - the existing same-collection three-figure bonus,
  - unlocked Display capacity,
  - current ownership.
- Replace worse currently displayed figures as needed.
- Settle/preserve outgoing figure earnings correctly when replacing them.
- The operation should be deterministic, retry-safe and not mint/lose Coins.

---

# New Implementation — UI / World / Animation / Experience

**Agent recommendation:** Claude is preferred for substantial UI/UX, visual design, world-building,
animation and experience work. Codex is also a reasonable choice for simple, well-specified UI changes
that do not require much visual iteration or design judgment.

### UI-01 — Design and add per-figure Display pressure plates

Paired with **LOGIC-01**.

- Create one polished collection plate/pad for each Display figure/slot.
- The plates should look intentional and premium, not like default Roblox pressure plates.
- Match the game's warm blind-box collectible aesthetic and existing Display materials.
- They should visually communicate that stepping on them collects the Coins for the corresponding
  figure without cluttering the Display.
- Layout must continue to look good as the Display expands through its supported slot counts.
- Empty/inactive positions should not look falsely collectible.

### UI-02 — Animate the Coins number in sync with the existing collection animation

- Preserve the current coin-collection animation and the satisfying effect where incoming Coins hit
  the number/HUD element.
- Fix the current timing problem where the displayed number jumps to the final value immediately at
  the beginning.
- Make the number update dynamically as the collection animation lands/impacts so the visual count and
  the coin hits feel synchronized.
- Reconcile to the exact authoritative final wallet value at the end of the animation.
- Keep large-number abbreviation and rapid/repeated collection behavior clean.

Implementation (2026-10-05): client presentation implemented; native visual acceptance remains
open. `CoinCounter` tracks only the unlanded portion of confirmed collection deltas, independently
of the immediate authoritative snapshot. The existing `CoinBurst` impact boundary is the moment
a homing world-space Coin comes within 1.6 studs of the player's root and disappears; that same
callback kicks the HUD and now advances its number. There is no additional animation timer.
Predicted impacts are recorded before confirmation without changing the wallet. Overlapping
collections retain separate tokens; completions use the latest wallet rather than a captured
balance. Unclassified wallet changes and snapshot gaps reconcile immediately, as do skipped
effects, interruption, reset/death, teardown and failures. HUD exact-value taps, screen balances
and affordability still use snapshots. The existing HUD abbreviation threshold and round-down
formatting are preserved. Frame listeners exist only while world Coins are flying.

Deterministic coverage is in `tests/CoinCounter.spec.luau` (actual counter, earnings and burst
modules with engine primitives shimmed) and `tests/Screens.spec.luau` (actual HUD/Interface).
No server economy, reward, snapshot timing, remote or schema change is part of UI-02.

Verification: `rokit install` and `wally install` succeeded with normal cache access; the
lockfile content is unchanged. The full `tests/run.py` harness passed, including economy,
persistence and UI suites plus 47 Coin presentation assertions. The final screen suite passed
1,100 assertions. `stylua src`, `stylua --check src`, `selene src` (zero errors/warnings),
`rojo build default.project.json -o RobloxWorkspace.rbxlx` and `git diff --check` passed.
Changed-client-file Luau LSP analysis with a fresh Rojo sourcemap and installed Roblox
definitions reported no source diagnostics; it emitted only the standalone file-watcher warning.

Studio checklist (not run: no Studio instance connected during implementation):

- One collection: the number trails initially, each landing kick advances it, and the final
  number and exact-value tap agree with the wallet. Listen for unchanged collect/landing sounds.
- Spam collections on one and several figures, including slots 4–6: progress stays monotonic
  except actual spending/corrections, and all bursts end at the newest wallet.
- Buy a box or Display slot while Coins are flying: the deduction appears immediately, flying
  Coins cannot restore spent value, and affordability uses the exact wallet. Also claim a reward.
- Reset during flight; toggle effects off; start a box opening; rebuild/remove the UI: the
  presentation reconciles immediately and no old flight can change it afterwards.
- Large balances: cross 10 million, billion and trillion boundaries; verify abbreviations round
  down and a HUD tap still shows the exact wallet, including when a collection is in flight.
- Repeat on a narrow phone viewport and gamepad; verify HUD sizing, sheet balance, input and
  selection behavior. With effects off, collections should update immediately without a flight.

Visual tuning remains: assess the readability of equal per-impact shares at small balances and
under large-number abbreviation, and the feel of overlapping landing kicks. Existing Coin paths,
counts, impact radius and HUD styling were retained.

### UI-03 — Add an aesthetic pity-progress presentation

- Pity already exists for eligible high-tier collections; this task is presentation, not a new pity
  algorithm.
- Show the player's current pity/progress somewhere natural in the Shop / box-purchase experience.
- The presentation should feel polished and collectible-focused rather than exposing a raw debug
  counter.
- Use only server-authoritative pity/progress data. Do not infer a hidden counter from client purchase
  history.
- Handle Legendary and Mythical pity clearly without overwhelming the normal odds UI.
- For collections that do not have those rarities/pity, omit the indicator or use an intentional
  "no pity for this collection" state rather than showing meaningless progress.
- Preserve the existing current-vs-base odds presentation.

### UI-04 — Add decorative lighting to player plots

- Add tasteful decorative lighting so plots feel warmer, more premium and more alive.
- Keep lighting secondary to the figures, Display and Shelves.
- Avoid excessive brightness, neon/simulator styling or lights that interfere with figure readability.
- Ensure repeated neighboring plots still look cohesive.

### UI-05 — Add continuous showcase auto-scroll to Shelves

- Make the player's Shelves continuously and smoothly scroll through their figures so the collection
  feels like a living showcase.
- Keep the motion slow enough to admire figures and avoid motion sickness.
- Manual browsing must remain usable; auto-scroll should not fight the player's own navigation.
- Preserve current shelf/page selection behavior and all placement/editing interactions.
- Verify the experience with different amounts of unlocked Shelf content.

### UI-06 — Add opening/pull audio behavior and pause background music

- Add or refine sound design for the blind-box pulling/opening sequence.
- While the opening/reveal animation is active, pause the normal background music so the pull audio and
  rarity reveal have full focus.
- Resume the background music cleanly after the opening ends, including skip, cancel, reset and error
  paths.
- Preserve the existing SFX/Music volume settings.
- Keep Common through Mythical reveals differentiated without making lower rarities feel dead.

### UI-07 — Build the physical plot Shop with a cute Peeka shopkeeper

Paired with **LOGIC-04**.

- Add a small physical Shop area/building to the player's plot.
- Include a cute **Peeka shopkeeper** as the visual personality of the Shop.
- Match the existing plot, Display and Shelves art direction.
- Present a clear nearby **E** interaction prompt that opens the existing Shop UI.
- The physical Shop is an entry point to the current Shop UI, not a replacement for the Shop interface.
- Keep the footprint compatible with plot expansion and do not obstruct the Display or Shelves.

### UI-08 — Build tiny limited-stock shops in the main plaza

Paired with **LOGIC-05**.

- Replace/use the current bench areas for small, charming plaza shop stalls.
- Each stall should visually present its current discounted box offer, remaining stock and time until
  the hourly refresh.
- Make the discount feel exciting and discoverable without looking like an aggressive simulator sale
  banner.
- Keep the stalls visually coherent with the main world and Peeka/collectible theme.
- Design states for sold out, available, refresh-soon and newly refreshed inventory.

### UI-09 — Add an Equip Best control to the Display UI

Paired with **LOGIC-06**.

- Add a clear **Equip Best** button/control to the Display management UI.
- It should be easy to discover without dominating the existing figure-management controls.
- Provide satisfying feedback when the Display is reorganized.
- If the current Display is already optimal, communicate that cleanly instead of appearing broken.
- Keep mobile/gamepad layout in mind.

---

# Deferred / Stretch Goals

Do not prioritize these until the active bug fixes and implementation tasks above are in a strong,
playtested state.

## Stretch logic

**Agent recommendation:** Codex for isolated system/backend work; Claude is equally viable if the
stretch feature is being implemented together with its player-facing experience.

### STRETCH-LOGIC-01 — Achievements and titles system

- Build the underlying achievement/title progression model.
- Define server-authoritative unlock conditions, persistence and equipped-title state.
- Keep conditions data-driven so future collections/events can add achievements without rewriting the
  system.
- Avoid final visual design in this task.

### STRETCH-LOGIC-02 — Luck system and gamepass integration

**This should be one of the last systems implemented in this backlog.**

- Add a server-authoritative Luck modifier that improves box outcomes while preserving valid,
  normalized probabilities.
- Initial acquisition direction is through gamepasses; exact products, tiers and values are still TBD.
- Define how Luck composes with the existing pity system before shipping it.
- Never trust a client-provided Luck value or odds table.
- Keep tuning configurable and test the effect across all rarity tiers.
- Do not begin final implementation until the gamepass/tuning decisions are set.

## Stretch UI / design

**Agent recommendation:** Claude for design-heavy presentation work; Codex is acceptable for small,
straightforward UI implementation once the design is already decided.

### STRETCH-UI-01 — Achievements and titles presentation

Paired with **STRETCH-LOGIC-01**.

- Design the player-facing achievement list, unlock celebration and title selection/equipped-title
  presentation.
- Titles should feel collectible/prestigious rather than cluttering the HUD.

### STRETCH-UI-02 — Luck presentation

Paired with **STRETCH-LOGIC-02**.

- After the Luck rules are finalized, show active Luck and its effect on box odds in a clear,
  aesthetically consistent way.
- Integrate gamepass presentation without making the core Shop feel paywall-heavy.
- Keep pity and Luck visually distinct so players can understand both systems.

---

## Suggested execution order

1. Fix the two plaza/world bugs.
2. Pressure-plate collection pair (**LOGIC-01 + UI-01**).
3. Coin-number animation (**UI-02**).
4. Swap auto-collection (**LOGIC-02**).
5. Pity presentation (**UI-03**, plus minimal data exposure only if required).
6. Base walk-speed increase (**LOGIC-03**).
7. Decorative plot lights (**UI-04**).
8. Shelf showcase auto-scroll (**UI-05**).
9. Opening audio/music behavior (**UI-06**).
10. Physical plot Shop pair (**LOGIC-04 + UI-07**).
11. Plaza limited-shop pair (**LOGIC-05 + UI-08**).
12. Equip Best pair (**LOGIC-06 + UI-09**).
13. Achievements/titles stretch pair.
14. Luck/gamepass system last.
