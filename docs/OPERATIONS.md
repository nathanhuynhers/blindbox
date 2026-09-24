# Full-game testing and release

The user accepted the MVP. The expanded game is a **closed-test candidate**, not published or
verified in live Roblox servers. The agent has no Studio control connector and has not run the
new engine, mobile, multiplayer or real DataStore tests. Existing MVP playtesting is not proof
that newly added features pass those tests.

## Run now

Open `RobloxWorkspace.rbxlx` and Play, or sync the source through Rojo. Studio starts in an
explicitly labeled **unsaved preview** by default. All content, UI, expansion, daily rewards,
palettes and same-server visits work in preview; leaving resets it. There is no paid content.

To test real saving, use a separate, privately published test experience. Enable **Experience
Settings > Security > Enable Studio Access to API Services**, as described in [Roblox's data
store setup](https://create.roblox.com/docs/cloud-services/data-stores#enable-studio-access).
Before starting Play, run this in the Studio Command Bar:

```lua
game:GetService("ServerScriptService"):SetAttribute("StudioPersistenceTest", true)
```

Alternatively set `studioPersistence = true` in `src/server/Settings.luau`. The attribute only
affects Studio. Studio uses `PocketGrove_Studio_v1`; live servers always use `PocketGrove_Live_v1`.
To return to preview, clear the attribute and leave the source setting false. A failed persistent
load never falls back to preview. No game setting or secret needs to be supplied by a client.

## Automated verification

Use the unchanged pinned tools and no Wally dependencies:

```powershell
rokit install
wally install
stylua src
stylua --check src
selene src
rojo sourcemap default.project.json -o sourcemap.json
rojo build default.project.json -o RobloxWorkspace.rbxlx
python tests/run.py build/tools/luau/luau.exe
```

Standalone Luau 0.739 is present in the ignored build/tools path. Any separately installed
compatible Luau executable can be supplied to the harness. Luau Language Server 1.70.0 analysis
uses the generated sourcemap and the locally installed Roblox definition file. The agent ran
that check; formatting/lint are not substitutes for it. Selene used its cached Roblox API file.

The regression suite runs actual domain, request, schema and storage-transform code:

- 8,878 economy/inventory/request assertions, including 1,000 mixed requests.
- 86 full-game/persistence fault checks: expansion, palettes, daily/goal claims, migration, corrupt
  payloads, competing leases, stale writers, uncertain committed replies, retries and release.
- Four scroll-content/lifecycle assertions with engine property/signal shims; these verify the
  sizing logic, not actual Roblox layout rendering.
- Four invalid economy/catalog startup fixtures.

`tests/StudioScroll.client.luau` is an additional engine regression script. During Play, open
Collection with the all-figures filter and paste its contents into the **client** Command Bar.
It checks all twelve cards exist, six match the selected collection, and content plus padding
fits the canvas, then scrolls to the final card. Repeat for both collections and phone sizes.
This script is not mapped into the game and has not been run by the agent.

## Required closed tests

1. **Collection regression:** reach the last figure of each collection with wheel, touch and
   scrollbar; change filters, resize the viewport, hide/show the menu and reopen after respawn.
   Check the last card is clear of the lower feedback bar. Run the client regression above.
2. **Core loop:** buy both box types, skip reveals, reserve/replace/remove copies, recycle only
   extras, redeem missing discoveries, and verify individual plus themed total rates. At the
   inventory cap, a daily box must remain claimable after space is made.
3. **Progression:** buy the fourth slot once; try again and confirm no charge. Buy and switch
   palettes; re-equipping owned palettes is free. Complete each collection and check its plaque.
4. **Persistence:** in the isolated test store, open/place, unlock, recolor and claim rewards.
   Wait for a successful autosave, stop/rejoin and compare balances/counts/slots/palette/claims.
   Reset character without resetting the profile. Verify no repeated starter grant or offline
   earnings. Disable API access for a fresh persistent join: play must be blocked, not reset.
5. **Failures:** use the deterministic injected failures first, then test interruption/shutdown
   with expendable private test profiles. Confirm failures pause economic actions and a later
   successful save resumes. An unconfirmed final save may leave the key locked until its lease
   expires; retry joining after two minutes. Never fault-inject against real player profiles.
6. **Daily rules:** one free chosen box and one display-goal claim per UTC day, including rejoin.
   Both markers survive saves. Use the injected-day tests for boundaries rather than changing
   production server time. Inspect invalid-state fixtures before any schema change.
7. **Visits:** two or more clients, distinct private inventories. Visit a host, inspect public
   figures, try editing from their room, then have the host leave. Guests return home. Dead or
   missing-character navigation is rejected. Nobody spends or grants on another player's behalf.
8. **Abuse/recovery:** spam malformed payloads, stale revisions, request-ID reuse, fake prices,
   unknown IDs and arbitrary visit destinations. Confirm no handler crashes or balance changes.
   Delay replies and retry the same ID; purchases and unlocks must not run twice.
9. **Device/performance:** target 30 FPS on representative mobile hardware, 60 FPS on desktop,
   and a 24-player server cap. These are targets, not measured results. Check mouse/touch/gamepad,
   reading sizes, reduced motion, respawn, repeated join/leave and a 30-minute soak. There are
   at most two local decorative visitors and bounded public directory/receipt/inventory sizes.
10. **Pacing:** observe returning sessions, weak/common-only luck, duplicates and completion.
    Record time to next box, fourth slot and palette; ensure twelve-figure content is enjoyable
    without adding artificial grind. Hand notes and server Output are sufficient for this build.

## Persistence guarantees and limits

Native UpdateAsync callbacks validate before writing and do not yield, following [Roblox's
UpdateAsync contract](https://create.roblox.com/docs/cloud-services/data-stores#update-data).
They acquire/renew a unique session token, validate existing data, and commit the whole profile.
The starter grant only occurs for a confirmed absent key. Unknown/corrupt/newer schemas fail
closed; they are never replaced with defaults. No paid receipts or cross-player transfers exist.

Leases last 120 seconds. Autosaves run about every 30 seconds; gameplay stops after 85 seconds
without a confirmed renewal or immediately on a save failure. Bounded retries use the same
snapshot and save generation. A response lost after commit is reconciled using the writer token
and generation; an expired or replaced owner cannot write. Room mutations never yield.

Action replies acknowledge **in-memory progress**. A hard crash may roll progress back to the
last successful save, normally up to an autosave interval plus request latency, and potentially
longer during service failure. Daily grants/claims and their downstream mutations are stored
together, so unsaved claims roll back with their rewards. Leaving/shutdown makes a bounded final
save/release attempt; it cannot guarantee durability during a Roblox outage or process kill.
The UI reports preview, pending save, saving, saved or paused state; it does not promise every
just-clicked action was durably saved. No offline catch-up is computed on load.

## Recovery and release procedure

- Use server Output and Creator Hub's Data Stores Manager for initial operational inspection.
  There is no third-party telemetry or automatic destructive repair.
- On incompatible/corrupt data, preserve the record, isolate the test profile and reproduce
  validation failure locally. Do not delete the key to make the player load. Review migrations
  and a known-good record before an explicitly approved restoration.
- Rehearse recovery in the private test experience: snapshot an expendable profile, inject a
  bad version, confirm load is blocked, restore the inspected test record only while no session
  owns it, then verify inventory/claim conservation. This rehearsal is still pending.
- Before public release, pass the above tests, choose a 24-player cap, retain a known-good place
  version, confirm live/Studio store isolation, and review progression-loss behavior. Restart
  servers on incompatible schema changes; never run an older writer against a newer schema.
- Public publishing requires the user's separate release instruction. Nothing was published
  or monetized during implementation. Rolling back code must preserve valid stored schemas;
  data rollback is a distinct, reviewed action, not a side effect of reverting the place.

Runtime test record: pending for the expanded candidate. User acceptance applies to the original
MVP, with the scrolling issue reported. No claim of launch readiness replaces these checks.
