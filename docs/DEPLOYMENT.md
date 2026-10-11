# Blind Box production deployment and recovery

Blind Box is live, as confirmed by the owner on October 11, 2026. Treat every production
profile as real progression. This is a manual release workflow; this audit did not publish,
restart servers, inspect production records, or perform a production migration.
See [save safety findings](SAVE_SAFETY_AUDIT.md), [data model](DATA_MODEL.md), and
[native acceptance checks](OPERATIONS.md). Passing local checks does not certify live durability.

## Permanent identity and release record

Repository: `nathanhuynhers/blindbox`. Current writer schema: **14**; valid Economy2
schemas **6–14** load. Live standard DataStore: `BlindBox_Economy2_Live`; Studio standard
DataStore: `BlindBox_Economy2_Studio`. Scope: **global** (GetDataStore has no scope argument).
Key: `Player_<numeric UserId>`. DataStores belong to the **universe**, not a Git branch or
place version. Keep names, scope, key convention, figure IDs, collection IDs, pity group IDs,
and persistent Shelf Unit IDs stable. The old economy reset is historical, not a release step.

**Production PlaceId and UniverseId are not recorded in this repository and could not be
verified during the audit (no connected Studio).** The publisher must obtain them from the
existing experience in Creator Hub before releasing. Never infer the target from a display name.
Record these alongside the intended branch/commit, previous and new published place versions,
UTC release time, schema read/write ranges, snapshot result/time, checks, and publisher:

| Identity | How to confirm |
| --- | --- |
| UniverseId | Creator Hub experience URL/identity; equals Studio `game.GameId` |
| PlaceId | Creator Hub Configure > Places, select the existing start place; equals `game.PlaceId` |
| Known-good place version | The currently published version in Version History; retain notes and a local copy |
| Candidate source | `git rev-parse HEAD`, clean/reviewed `git status`, and the selected Rojo working directory |

Open the intended existing place using its Creator Hub **Edit in Studio** action. In the
edit Command Bar, read `print(game.PlaceId, game.GameId, game.PlaceVersion)` and compare both
IDs with the release record. An imported local `.rbxlx` may show IDs of zero; it is not evidence
of a production target. A private **place in the live universe is not isolated storage**.
Use a separate private test **experience/universe** for published persistence/teleport tests;
it can use the same store names without accessing the live universe's records.

## What each operation does

| Operation | Effect |
| --- | --- |
| Git commit / push | Records/shares source. Does not update Roblox. |
| Rojo build | Produces a local `RobloxWorkspace.rbxlx`; does not upload it. |
| Rojo sync | Updates the connected Studio edit DataModel from the selected source tree. Does not publish. |
| Studio Save to File / Save to Roblox | Saves a local/cloud editing checkpoint. Confirm publication separately. |
| Studio Publish to Roblox | Publishes a place version to the selected existing Roblox place. New servers use it. |
| Active server replacement | Retires running old code. Publishing alone leaves old servers alive until they empty or are restarted. |

The last distinction follows [Roblox's release workflow](https://create.roblox.com/docs/projects/update-games).
Cloud save and publish checkpoints are explained in [Version History](https://create.roblox.com/docs/projects/version-history).

## Local validation and rehearsal

1. Edit the intended checkout in VS Code/Codex. Inspect the diff and migrations; preserve
   `rokit.toml`, `default.project.json`, `Settings` store identities and catalog IDs. Do not
   increment the schema for content/UI changes or this audit's runtime-only save fix.
2. From that checkout, run the pinned tools and full deterministic suite:

   ```powershell
   rokit install
   wally install
   stylua src
   stylua --check src
   selene src
   rojo sourcemap default.project.json -o sourcemap.json
   rojo build default.project.json -o RobloxWorkspace.rbxlx
   python tests/run.py build/tools/luau/luau.exe
   git diff --check
   ```

   The ignored standalone Luau executable is not provisioned by Rokit; supply the existing
   official Luau 0.739 executable path if this checkout lacks `build/tools/luau/luau.exe`.
   Do not add a gameplay dependency to obtain the test runner. Generate the sourcemap before
   type analysis. With the installed Roblox definitions, also run:

   ```powershell
   luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions <path-to-globalTypes.PluginSecurity.d.luau> src
   ```

   Replace the placeholder with the local definition file path, or check Luau Language Server
   diagnostics in VS Code with the correct Rojo mapping. Fix diagnostics before publication.
3. In Studio, open the local build for unsaved preview, or start
   `rojo serve default.project.json` and connect the Rojo plugin to the correct checkout.
   Preview resets on exit by design. It is not a save test. Source creates the world at runtime;
   inspect the sync diff and retain unrelated authored place properties/assets.
4. For persistence rehearsal use a separate private universe. In Studio there, enable API
   access and set the `ServerScriptService.StudioPersistenceTest` attribute **before Play**
   as described in [operations](OPERATIONS.md#run-now). Leave `Settings.studioPersistence = false`
   in release source. Published test servers automatically use the Live-named store **in the
   test universe**. Never enable Studio API access on the live experience for this rehearsal.
5. Use disposable accounts and record before/after progression. Verify current and old valid
   fixture loads, two-server ownership, leave/rejoin, final saves on shutdown/restart, failures
   before/after commit, blocked corrupt/future profiles, and recovery on copied test records.
   Rehearse real AFK handoff/cancellation following [AFK checks](AFK_RECONNECT.md#published-test-checklist).
   Run multi-client Studio checks plus actual Roblox application tests in the private universe;
   a Studio engine double cannot validate DataStore latency, shutdown or TeleportAsync.
6. Compare Coins and figure banks (allow expected income), duplicate quantities, discoveries,
   all Display slots/unlocks, visible/hidden Shelf placements, unit IDs, pity, tutorial/reward
   markers, daily/login/goal claims, offline claim conservation, boxesOpened, volumes and same-hour
   deal stock. Save and rejoin twice; one-time rewards must not recur. Remove all test injections.

## Routine release: mutually compatible readers and writers

1. Finish validation/rehearsal and record the known-good source and published place version.
   Compatibility includes fields, identifiers and reward semantics, not only the schema number.
   New catalog IDs can make an old decoder reject profiles even without a schema increment;
   retain historical IDs and coordinate replacement or maintenance for that release too.
2. For changes to persistence logic, request and confirm a native DataStore snapshot before
   publishing (see recovery below). This audit changes persistence logic despite keeping schema 14.
3. Open the existing production place from Creator Hub, verify PlaceId/UniverseId, stop Play,
   start Rojo from the tested checkout, and sync. Review what will change. Check the source in
   `ServerScriptService.Server`, unchanged store names, absence of test fixtures and the intended
   mappings. A Git push or sync alone has not released anything.
4. Use **File > Publish to Roblox** for that already-associated place. Record the newly published
   version and Git commit in version notes/release notes. Avoid publishing as a new experience.
   If importing a build instead, **Publish to Roblox As** must select and overwrite the exact
   existing place in the verified universe; do not choose Add as a new place. Prefer the associated
   place plus sync because it makes target verification straightforward.
5. Verify a newly started published server's PlaceId, UniverseId and place version. Publishing
   does not change existing jobs. For this save-safety fix, replace outdated servers so they stop
   using the defective final-save path. In Creator Hub, **Configure > Server Management > Restart
   Servers**, select the intended place and **Restart only servers with outdated versions**.
   A delay can give players time to leave normally when formats are mutually compatible.
   Replacement still relies on bounded final saving, not guaranteed crash-proof storage.
6. On test accounts with existing progress, perform leave/rejoin and compare the persisted
   invariants above. Confirm no starter reset, duplicate claim, unexpected stock refill or lost
   shelf. Check remaining old jobs and new jobs' versions. Record failures with UserId, UTC time,
   PlaceId, JobId, place version and observed save status.
7. Monitor Creator Hub errors and server logs during rollout and at least through several
   autosaves and reconnects. Look for `Profile load blocked`, `Profile autosave paused`,
   `Profile final save was not confirmed`, incompatible snapshot/ownership messages and AFK
   recovery warnings. Compare error frequency and affected users with the previous version.
   There is no custom telemetry here. Investigate unexpected failures promptly; do not delete keys.

## Incompatible migration or content release

Current schema-13 code cannot read schema-14 records: the v14 acquisition itself can upgrade
the saved envelope before the first autosave. An old server will block that player, and an old
writer will reject the newer record. This prevents overwrite but causes availability failures.
**Publish then restart is not a barrier:** versions overlap while servers drain, and joins,
invites and teleports can race. Do not use an ordinary rolling release for incompatible readers.

For future incompatible schema/identifier changes, default to a coordinated maintenance release:

1. Prepare and test deterministic migrations from every supported valid version; reject malformed
   and future records. Test populated fixtures and conservation of claim markers. Record the
   rollback reader requirements. Preserve old fixtures; defaults apply only to versions predating
   a field, never to missing required fields in a version that already required it.
2. Make the experience private to stop public re-entry, and shut down/drain **all affected places
   and old writers** in that universe. Do not leave owner/test sessions or AFK source jobs alive.
   Confirm old jobs are gone and final-save attempts completed; wait out the 120-second lease
   horizon after the last possible old acquisition/renewal. Inspect suspicious active leases
   read-only rather than clearing them. If quiescence cannot be confirmed, do not start migration.
3. After old writers are drained, confirm a native snapshot so final old-version saves are included.
   Keep access closed until the new build is published and verified. Do not run a bulk migration
   against production as part of an ordinary release; existing migrations happen on validated load.
4. Publish only the tested reader/writer, verify the place version and disposable account
   progression, then reopen access. Confirm every new server uses the compatible build.
5. If failures occur after any new-schema saves, keep access closed and prefer a tested roll-forward
   fix. A rollback must read and preserve **all formats/IDs already written**, not just the former
   format. Never change store names or delete new fields to make old code run.

A future alternative is a two-release compatibility bridge: first deploy a reader/writer that
understands both formats/IDs, continues the old format for old records and preserves the newer
format whenever it is already present. Replace every older server before enabling the new-format
upgrade. The bridge must preserve new progression and reward semantics on
every save; an older decoder with an increased version allowlist is insufficient. This bridge
does not exist today and needs its own tests/authorization. Maintenance requires no new framework.

## Backups, read-only inspection and recovery

- Retain a known-good published place version, its exact Git commit, release notes and a local
  place copy. Use Version History to inspect/restore a chosen place. Reverting a place is a code
  operation; to make a restored editing version live, publish it and replace affected servers.
  It does **not** rewind DataStores. See [Roblox Version History](https://create.roblox.com/docs/projects/version-history).
- Use Creator Hub **Data Stores Manager** in the verified production universe for initial
  read-only inspection of `BlindBox_Economy2_Live`, scope `global`, key `Player_<UserId>`.
  Confirm the numeric UserId rather than username. Preserve the complete envelope, record/version
  identity and UTC timestamps privately; currency, inventory and the lease envelope are sensitive.
  Never press delete/reset/edit to unblock a player. Do not call `Storage.open` or `Persistence.load`
  for inspection: those acquire leases and can write migrations.
- If deeper inspection is needed, use authorized, read-only native `ListVersionsAsync` /
  `GetVersionAsync`, or a narrowly permissioned Open Cloud read operation. Retain an exact version
  copy and metadata outside public Git. A cached GetAsync result alone is insufficient evidence
  for a restoration decision. No recovery CLI or production access credential is added here.
- Standard DataStores retain version history with hourly granularity; it is **not one backup
  per autosave** and overwritten historical versions expire. Before persistence changes, use
  Roblox's **Snapshot Data Stores** Open Cloud operation for the verified UniverseId and retain
  its successful result/time. It protects a pre-release boundary that ordinary within-hour
  history can miss; snapshots have a once-per-day limit. This audit did not request one. If a
  snapshot cannot be confirmed, postpone an incompatible migration. See
  [versioning and snapshots](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching)
  and [native snapshot API](https://create.roblox.com/docs/cloud/reference/features/storage).
- For a missing-progress report, collect UserId, last good session/release time, actual target
  universe/place, JobId/place version if available, and save/load errors. Check preview versus
  persistent play, a blocked lease, failed final saving, retired namespaces, unsupported schema,
  deleted catalog references, and crash rollback. Preserve both the current record and candidate
  historical versions. Reproduce decoder failure locally on a copy; do not alter the original.
- Compare wallet/banks, copies, shelves, claim markers, lastSeen/offlinePending and deal stock
  together. Never restore only a reward marker or only a wallet: that can duplicate rewards or
  charge for missing inventory. Confirm whether the reported actions reached a durable checkpoint.
- Any actual player restoration is a separate explicitly approved operation, rehearsed on a
  copy first. Ensure no active owner, quiesce writers and verify the record has not changed since
  inspection using a conditional UpdateAsync transform. Restore reviewed **profile data** into a
  correctly fenced current envelope; never blindly replay an old token/writer/expiry/generation
  or use an unconditional SetAsync over a session. Preserve the damaged version and later valid
  progress where possible. No such restoration or restoration script was performed here.

Rollback is safe only when the chosen code understands everything already saved. If the bad
release wrote valid newer progression, a compatible roll-forward fix generally preserves more
than reverting to an old reader or restoring old data. Data restoration may itself lose later
legitimate actions; it is a reviewed recovery decision, never an automatic consequence of rollback.
