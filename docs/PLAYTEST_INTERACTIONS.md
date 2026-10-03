# Display, Shelves and Daily Goal follow-up

Implemented October 2, 2026. Automated verification passes. The user subsequently inspected the
result in Roblox Studio and reported that everything looked and worked correctly. Backlog items
3, 6 and 11 are fully completed and manually accepted.

## Behavior and boundaries

- A single native `ProximityPrompt` centered near the floor in front of the Display counter offers
  **E · Manage Display** within 12 studs. Its anchor stays at the same low center point as capacity
  grows from three through six slots, keeping the native prompt card below the figures.
  The client routes its own living player's activation into the existing Display screen,
  checks target ancestry and distance again, and respects pending requests/opening focus. The
  existing dock and Display placement validation remain intact. E cannot invoke collection.
- A matching native `ProximityPrompt` centered near the floor in front of the three physical Shelf
  bays offers **E · Manage Shelves** within 12 studs. It routes into the existing Shelves screen
  without sending a mutation. The client checks local plot ownership, target ancestry, living
  character state and distance; the existing server-authoritative own-plot boundary still guards
  every Shelf edit.
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

- `src/client/DisplayInteraction.luau`, `init.client.luau`, `Interface.luau`: Display/Shelves prompt routing,
  input wording, snapshot integration and lifetime management.
- `src/server/DisplayFixture.luau`, `PlayerPlot.luau`: management prompt/plaque and removal of
  per-figure collection prompts while retaining validated click/tap targets.
- `src/server/CollectionFixture.luau`: physical Shelf heading and low management prompt.
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
  startup fixtures pass. Relevant suites include 126 Display interaction checks, 19,101 plot checks,
  132 screen checks, 2,220 economy/transaction checks and 80 full-game/persistence checks.
  The opening cleanup fault printed by the suite is an intentional existing fault-injection case.
- The active plot remains within its tested runtime part budget: 140 / 150 at six Display slots.
- `git diff --check`: pass. Generated builds, sourcemaps and harness copies remain ignored.

These harnesses execute real modules with engine boundaries shimmed. They do not simulate native
mouse/touch delivery, prompt rendering, physics, network replication or real DataStore sessions.

On October 3, 2026, the initial side placement passed native Studio checks, then user review moved
the target to the Display's horizontal center near the floor. The low anchor remains below the
collection plaque at capacities 3, 4, 5 and 6. No pressure plates or collection-rule changes were
added. Final user visual confirmation of this centered low placement remains pending.

Also on October 3, 2026, a fresh Rojo build verified the matching Shelves prompt at plot-local
position `(33, 0.45, -4)`: centered across all three bays, seven studs inward from the shelf face
and below the bottom row. The prompt was enabled with a 12-stud range, and pressing E opened the
Shelves screen while the Display screen remained closed. Studio MCP's capture omits Roblox's native
prompt overlay, so final user visual confirmation of the prompt card remains pending.

## Own-plot management boundary (October 3, 2026)

Backlog item 13 replaces the narrow Display and Shelf editor bands with one server-authoritative
rule: a living owner may mutate either system anywhere inside their active 100-by-96-stud plot and
within 20 vertical studs of its origin. Ownership still comes from the remote callback Player and
active session; visitors, missing/dead characters and owners beyond any plot boundary are rejected.
The nearby E prompts remain physical shortcuts for opening Display and Shelf management, while
clicking or tapping a figure to collect Coins retains its independent 12-stud physical range.

The full harness passes with center, rear and far-corner access plus immediate X/Z/vertical outside
denial. A fresh Rojo build was also opened through Studio MCP. Native Player/Character/CFrame checks
accepted Display and Shelf placement from the opposite plot corner, rejected a non-owner standing
inside the plot, and rejected the owner immediately beyond the X, Z and vertical boundaries without
mutating state. No remote, persistent field, plot size or client-trusted authorization was added.

## Manual acceptance

On October 2, 2026, the user manually checked the integrated result in Roblox Studio and reported
that everything appeared correct, closing the original visual and interaction acceptance gate for
backlog items 3, 6 and 11. The October 3 prompt-position adjustment above was subsequently requested
and has native Studio verification; its final visual confirmation is still pending.
