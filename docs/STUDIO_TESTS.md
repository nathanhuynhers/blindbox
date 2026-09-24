# Historical Milestone 1 verification

The user subsequently playtested and accepted the MVP, with a collection-scrolling bug.
That report does not establish every checklist item below as passed. Current candidate tests
and persistent setup are in [operations](OPERATIONS.md).

Implementation: Pocket Grove session-only prototype, 2026-09-23. No persistence or public
release. Milestone 1's evaluation gate remains open until the Studio checks below are run.

## Automated checks actually run

- Provisioned the existing pinned tools with `rokit install --no-trust-check`; no versions
  changed. Required cache/network access was granted after sandbox attempts failed.
- `wally install` succeeded with zero dependencies and no lockfile content change.
- `stylua src` and `stylua --check src`.
- `selene src`: zero errors/warnings; used its existing Roblox API cache because the sandbox
  could not refresh the API dump.
- Luau Language Server 1.70.0 analysis using the Rojo sourcemap and locally installed Roblox
  `globalTypes.PluginSecurity.d.luau` definitions. This checks types, not runtime behavior.
- `rojo build default.project.json -o RobloxWorkspace.rbxlx` succeeded. Build output is ignored.
- `python tests/run.py build/tools/luau/luau.exe`, using official standalone Luau 0.739:
  7,970 deterministic assertions, including 1,000 mixed requests, plus four invalid-config
  startup fixtures. The harness runs the actual domain/transaction code, with Roblox require
  resolution and catalog color construction shimmed. No engine/network simulation is claimed.

## Studio checks still required

No Studio playtest was run from this session: no Studio control connector is available.
Open the built `RobloxWorkspace.rbxlx`, or sync with Rojo before testing. Inspect Output for
errors throughout. Tests below must be recorded as pass/fail with notes, not assumed from a build.

1. **First session:** Play, confirm 450 Coins and the reset warning. Open within 30 seconds;
   exactly 150 Coins are spent and one owned copy appears. Skip the reveal immediately, then
   let the next reveal close automatically; neither changes the grant. Place within 60 seconds.
2. **Income:** put each owned figure into a slot near your shelf. Confirm individual rates,
   combined panel/billboard rate, and increasing Coins. Buy an earned box within three minutes.
   Remove/replace a figure and check the rate changes without changing owned totals. Inventory
   figures alone must not earn. Three weakest commons earn 3/sec; three rare copies earn 21/sec.
3. **Inventory/index:** select owned and unknown cards; verify unknown silhouettes, discovery
   names, owned/available counts and selected highlights. Try placing a copy twice, recycling
   the last copy or all-reserved copies, and redeeming without Scrap. Each fails clearly.
   Recycle six eligible extras and redeem an undiscovered figure; verify discovery and counts.
   All six discoveries must show the collection-complete stamp. The automated suite seeds
   its own isolated state for completion; there is no client grant/debug remote.
4. **Two clients:** start a local server with two players. Each gets a distinct room, inventory
   and balance. Walk into the other room and attempt placement/removal; it cannot change the
   host's display or state. From far away, editing your own shelf fails. Buying/recycling can
   occur anywhere. Rejoin one client and verify fresh 450 Coins, empty collection and no
   offline income; the other player's session must remain unchanged.
5. **Remote abuse:** in the client Command Bar, send extra owner/price fields, unknown IDs,
   oversized IDs, NaN/infinite revisions, and invalid slots to `ReplicatedStorage.Remotes.Intent`.
   No state changes or handler errors. Re-send an identical valid request ID and revision;
   it returns the same outcome without spending twice. A new ID with an old revision fails.
   Spam requests, then stop and confirm normal UI recovers. Automated tests cover these rules,
   but this check verifies the real engine adapter and player isolation.
6. **Delayed replies:** emulate network latency, click Open rapidly and dismiss reveals. One
   request remains pending; retries use the same ID. Verify no second deduction/grant from a
   retry, no stale snapshot overwrite, and normal controls resume after the reply.
7. **Lifecycle:** respawn, leave while spawning and reconnect repeatedly. Room counts track
   connected players, displays disappear on owner departure, and local decorative visitors
   stay at most two. Check for lingering rooms/tasks/errors. Hiding/deleting visitor visuals
   or lowering frame rate must not change server income. Idle in-game for several minutes;
   Coins keep accruing automatically.
8. **Input/layout:** use mouse and Studio device emulation for phone portrait/landscape.
   Scroll the collection, select a card, place/remove, recycle/redeem, skip reveals, and hide
   the panel to move freely. Verify no clipped text, unreachable buttons or blocked camera
   controls. Prototype figures should be distinguishable by silhouette.
9. **Pacing:** observe 10- and 30-minute common-only, duplicate-heavy and natural-roll runs.
   Record first display/earned purchase times, openings, redemption choices, upgrades and
   reasons to stop. Use isolated test states for arithmetic tests; any temporary tuning edits
   for Studio scenarios must be reverted before the final build. Do not add production grants.

## Review record

Studio date/tester: pending. Two-client isolation: pending. Mobile/layout: pending.
10/30-minute pacing observations: pending. Continue/revise decision: pending.
Saving, expansion and later milestones remain deferred until this review.
