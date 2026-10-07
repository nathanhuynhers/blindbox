# Recent-change Studio verification — 2026-10-05

Tested `master` at `7b99d64` in a fresh `RobloxWorkspace.rbxlx` built from the repository.
Studio MCP connected after launching the installed Studio application. This was one native
Play client using **Studio preview - not saved**, with the actual server/client scripts,
Roblox physics, ClickDetectors, remotes and rendered HUD. Nothing was published.

## Scope and results

| Change | Native checks | Result |
| --- | --- | --- |
| `d615347` — collect outgoing Display bank on replacement | Replace an owned earner; reject an already displayed replacement; separate native server module fixture for wallet cap, retained fractions/overflow, unchanged collection quest stage and exact request replay | Passed. Live replacement transferred 216 whole Coins and retained approximately 0.190391 in the outgoing bank. Rejection changed the wallet by zero. The cap fixture transferred 5 from 15.75 and retained 10.75; replay transferred nothing again. |
| `21ff6bc` — baseline WalkSpeed 20 | Inspect actual server/client Humanoids at spawn and after death/respawn; return Home | Passed. WalkSpeed was 20; respawn retained the wallet and placements. |
| `778baf3` — per-figure collection plates | Walk onto an occupied plate; expand sequentially from 3 to 6; inspect all six recentered plates; walk onto newly occupied slot 6; remove its figure and check empty contact; re-place and walk away/back; collect after respawn | Passed. Native contacts collected the authoritative figure. Empty contact changed the wallet by zero. Reactivation and respawn retained working contact handlers. Unlocked empty plates showed a dash; occupied plates showed the collect cue. |
| `987bbd1` — animate HUD Coins at collection impacts | Record HUD text and authoritative wallet every 50 ms during a real plate collection; perform a native screen-coordinate click on a figure; inspect effect cleanup | Passed. For a 208-Coin plate collection, the wallet immediately became 4,989,708 while the HUD stayed at 4,989,500, then advanced through intermediate values before reaching 4,989,708. Coin effect parts returned to zero. Native figure click also collected and cleaned up. |

Additional live checks rejected a remote `Collect` request and a Display replacement from
outside the owner's plot, both with zero wallet delta. Six collection plates remained present
and touch-enabled on the server after expansion and respawn.

No reproducible bug was found in these four changes, so no gameplay code was changed.

## Output and supporting checks

Studio Output reported `Leaderboard DataStore requests are failing; showing last good data and retrying.`
Leaderboard storage was unavailable in this unsaved preview. No gameplay script errors were
reported. This session does not verify leaderboard persistence.

Pinned tool provisioning and empty-dependency Wally resolution completed. The full existing
standalone regression harness passed, including movement, replacement, collection plate and Coin
presentation suites. `stylua --check src`, `selene src`, Rojo sourcemap/build and Luau Language
Server analysis with the existing Roblox definitions passed. Engine-double regressions are
supporting evidence, distinct from the native checks above.

## Remaining acceptance

This targeted single-client pass does not close native multi-client visitor/owner isolation,
persistent save/rejoin, real touch/gamepad input, physical-device performance, or a populated
server soak. Coin interruption during an in-flight death or reduced-motion toggle and movement
through an actual opening sequence were covered by existing simulated regressions, not by this
native session. See [operations](OPERATIONS.md) for the broader release gates.
