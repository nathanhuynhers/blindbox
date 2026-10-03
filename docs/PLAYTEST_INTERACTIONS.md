# Display, Shelves and Daily Goal follow-up

Implemented October 2, 2026. Automated verification passes. Native Studio acceptance is pending:
the Studio connector returned no connected instances, so no Studio playtest was run.
Backlog items 3, 6 and 11 are marked completed, with this remaining gate explicitly recorded.

## Behavior and boundaries

- A single native `ProximityPrompt` at the Display counter offers **E · Manage Display** within
  12 studs. The client routes its own living player's activation into the existing Display screen,
  checks target ancestry and distance again, and respects pending requests/opening focus. The
  existing dock and Display placement validation remain intact. E cannot invoke collection.
- Each figure retains its existing server-bound `ClickDetector`. Native mouse clicks and touch
  taps enter one handler, with no additional touch listener or remote. The server checks the
  living owner, exact target ancestry, 12-stud distance and plot bounds. The existing session/
  storage-readiness gate, token bucket, revision/receipt handling and non-yielding transaction
  transfer remain authoritative. Only the selected bank transfers whole Coins; zero balances,
  fractional remainders, wallet overflow, income generation and saved banks retain their rules.
- An oak/ivory plaque on the counter front explains collecting each figure. The owner sees
  **Click to Collect** or **Tap to Collect** plus “Each Figure”; input changes update the wording.
  The replicated fallback is “Click or Tap Each Figure to Collect.” The plaque has no controls.
  Three client service listeners are owned for the client lifetime and disconnected on teardown.
  Existing snapshot refreshes resolve late/replaced plots without adding connections.
- The physical shelf header now says **Shelves**. The Shelf menu already used that title. Actual
  Collection pages, identifiers, services, catalog entries and completion rules retain their names.
- An unconfirmed or failed Daily Goal claim keeps its existing presentation. A confirmed claimed
  snapshot hides the desktop tracker and phone claim chip. Goals replaces its daily card with a
  small “All daily goals finished” message; the free box and collection progress still work.
  The existing game has one daily goal. Its saved progress/claim marker and UTC rollover are
  unchanged, including when reopening, resizing, respawning or creating a new client UI tree.

No new dependencies, remotes, persistent fields, save namespaces or figure assets were introduced.
Existing transaction acknowledgements are in-memory, with the existing aggregate autosave behavior;
these changes do not alter crash recovery or storage guarantees.

## Important source and test files

- `src/client/DisplayInteraction.luau`, `init.client.luau`, `Interface.luau`: prompt routing,
  input wording, snapshot integration and lifetime management.
- `src/server/DisplayFixture.luau`, `PlayerPlot.luau`: management prompt/plaque and removal of
  per-figure collection prompts while retaining validated click/tap targets.
- `src/server/CollectionFixture.luau`: exact physical Shelf heading correction.
- `src/client/GoalTracker.luau`, `GoalsScreen.luau`: active-goal visibility and empty state.
- Display screen/HUD copy and the remote-collection rejection message explain click/tap collection.
- `tests/DisplayInteraction.spec.luau`, `Plots.spec.luau`, `Screens.spec.luau`,
  `FullGame.spec.luau`, `PlotEngine.luau`, `run.py`: targeted regressions using existing harnesses.

## Verification performed

- Provisioned the unchanged pinned tools with `rokit install --no-trust-check`; installed tool
  cache/network access required an escalated run. Ran `wally install` with zero dependencies;
  `wally.lock` has no content change.
- `stylua src`, `stylua --check src`: pass.
- `selene src`: zero errors, warnings or parse errors.
- Luau Language Server 1.70.1 `analyze --platform roblox --sourcemap sourcemap.json` with the
  installed Roblox `globalTypes.PluginSecurity.d.luau`: no source diagnostics. Only the standalone
  file-watcher registration notice is emitted.
- `rojo sourcemap default.project.json -o sourcemap.json` and
  `rojo build default.project.json -o RobloxWorkspace.rbxlx`: pass using pinned Rojo 7.7.0.
- `python tests/run.py build/tools/luau/luau.exe`: every suite and all 12 invalid-configuration
  startup fixtures pass. Relevant suites include 126 Display interaction checks, 19,049 plot checks,
  132 screen checks, 2,220 economy/transaction checks and 80 full-game/persistence checks.
  The opening cleanup fault printed by the suite is an intentional existing fault-injection case.
- The active plot remains within its tested runtime part budget: 140 / 150 at six Display slots.
- `git diff --check`: pass. Generated builds, sourcemaps and harness copies remain ignored.

These harnesses execute real modules with engine boundaries shimmed. They do not simulate native
mouse/touch delivery, prompt rendering, physics, network replication or real DataStore sessions.

## Remaining Studio acceptance

Use the built place or sync the repository into an isolated Studio test. Watch Output throughout.

1. **Management:** on a fresh empty Display and a populated three/six-slot Display, approach the
   counter and press E. Only management opens; the wallet and banks do not collect. Close it,
   move more than 12 studs from the management target and confirm E no longer opens it. Test
   death/respawn and repeat during an opening cinematic and a pending request.
2. **Mouse and touch:** let at least two displayed figures bank Coins, then click one and tap one
   with Studio device emulation. Only the selected bank transfers. Check every slot, zero/fractional
   earnings, and rapid repeated input. Newly accrued Coins may legitimately be collected again;
   the same banked amount must not pay twice. A tap on management must not also collect a figure.
3. **Presentation:** inspect the counter plaque and physical Shelves header on desktop and phone
   portrait/landscape, day and night. Switch mouse/touch on a hybrid device. Check that prompts,
   figures, camera controls and plaque do not obscure or intercept each other.
4. **Two clients:** try clicking/tapping another owner's figures, triggering their management
   prompt, forged remote Collect requests and collection from outside the 12-stud target range.
   Confirm no unauthorized wallet/bank changes. Walk away and return; normal owner input recovers.
5. **Lifecycle and persistence:** replace/remove/expand Display slots, respawn, then leave/rejoin
   after a confirmed save. Confirm saved banks/placement survive, no offline income appears,
   departed plots disappear and replacement plots have exactly one management prompt and one
   collection handler per figure target. Test storage pause using the existing isolated workflow.
6. **Daily Goal:** check incomplete, complete/unclaimed, delayed/failed claim, successful claim,
   reopening, device resize and respawn. On success neither HUD variant leaves a claimed card;
   Goals shows the empty state while the free box and collection links work. Rejoin after a saved
   claim and attempt it again; no second reward. The next UTC day should restore the goal normally.

No known failing automated cases remain. Native device usability, visual fit, multi-client delivery
and real save/rejoin behavior remain unverified until the above Studio checks are recorded.
