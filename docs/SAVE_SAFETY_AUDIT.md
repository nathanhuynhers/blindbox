# Production save safety audit — October 11, 2026

Scope: source persistence/lifecycle, deterministic fault tests, compatibility and manual release
workflow for `nathanhuynhers/blindbox`. The owner confirms Blind Box is live. No production records
were read or modified, no namespaces/IDs changed, and no publishing/server restart was performed.
Local source does not prove which version currently runs in production.

## Existing protections retained

`Profile` validates/encodes schema 14 and deterministically upgrades valid Economy2 versions 6–13.
Malformed, missing required, unknown/future fields and unsupported schemas block loading. Optional
defaults are version-specific; a present-format field is not silently reset. Existing Shelf
reconciliation deliberately removes excess/unowned placements in stable order and grants no inventory;
historical completion rewards reconcile idempotently. Customization currently supports only an empty
map; unknown customization blocks loading instead of being erased. Hidden logical slots survive.

`Storage` selects unsaved Studio preview, opt-in Studio persistence, or live persistence. Native
UpdateAsync operates on the single `{data, token, expires, generation, writer}` aggregate in
`BlindBox_Economy2_Live`/`BlindBox_Economy2_Studio`, default global scope, `Player_<UserId>`.
Only a confirmed absent key gets a starter profile. Load retries (four, waits 1/2/3 seconds) never
substitute defaults for errors or rejected records. Acquisition retries retain the same GUID.

Session leases last 120 seconds; gameplay checks a conservative 85-second local safety deadline.
Autosaves run about every 30 seconds with three attempts and waits 1/2 seconds. Failure immediately
pauses authoritative actions; failed batches retry after five seconds. Tokens, generations and writer
identity reconcile committed-but-unacknowledged operations and reject other/expired owners. Callbacks
validate the latest record on every UpdateAsync retry and never grant gameplay rewards or yield.

`PlayerRemoving` freezes/removes the session and attempts a final aggregate save/release. BindToClose
blocks requests/new joins, closes profiles concurrently and waits at most 25 seconds; Storage waits
up to 20 seconds for an existing write. Loading sessions finishing during shutdown close without
entering gameplay. Unresolved calls cannot be cancelled or bypassed safely. AFK handoff sets its
barrier before yielding, drains autosave, freezes a checkpoint, releases the lease, and never writes
again after a confirmed release. Cancellation reclaims only the same writer/generation without
rewriting data; a destination acquisition prevents source recovery. Teleport metadata carries no data.

## Persisted progression coverage

| Progress | Saved fields and conservation |
| --- | --- |
| Wallet and figure banks | `coins`, `earnings`; fractions and non-displayed banks remain in the aggregate |
| Inventory/discovery | `owned` duplicate counts, permanent `discovered`; all owned IDs must be discovered |
| Display | `display.unlocked`, dense unique earning `slots` |
| Shelves | Ordered unit IDs, placements including hidden coordinates, empty customization, optional dormant overflow; `shelfRewards` prevents repeated completion grants |
| Pity | Per-group Legendary/Mythical dry-roll counters |
| Tutorial/rewards | `step`, `tutorialHidden`; one-time Welcome rewards advance the persisted stage atomically |
| Daily/login/goals | `lastDailyDay`, consistent `lastLoginDay`/`loginStreak`, `goalDay`/`goalProgress`/`goalClaimed` |
| Offline income | `lastSeen`, `offlinePending`; claim and wallet changes save together; prior pending auto-claims on next join |
| Statistics/settings | Lifetime `boxesOpened`, `sfxVolume`, `musicVolume` |
| Hourly purchases | `deals.window` and per-stall `bought` counters; spend, figure grant, pity and stock change together |

Runtime revision, clocks, plot coordinates, carousel, connections and request receipts are not saved.
Receipts protect retries within a session (120 seconds/64 entries); purchases and rewards mutate
without yielding. Daily/Welcome/completion/offline markers protect durable claims across joins.
There are no paid receipts or cross-player transfers; future paid grants need separate durable
idempotency. Leaderboard stores are rebuildable presentation indexes, never profile inputs.

## Findings and changes

| Severity | Finding | Resolution |
| --- | --- | --- |
| High | `Storage.flush` forgot an unconfirmed autosave between batches. If it committed but all replies failed, final release used the old generation with a different release mode and was rejected. Actions completed while the initial save yielded could be omitted from the final checkpoint, with an unnecessary lock until expiry. | Added runtime `pendingSave`, retained the immutable ordinary checkpoint until confirmation, then wrote/released the latest state. Reclaim clears reconciled pending snapshots. A new regression fails on the original code and passes after this fix. No envelope/schema change. |
| Medium | `Profile.decode` used `#bought == count` to test deal array density. Luau can choose a border inside a sparse table (e.g. keys 2/4), allowing missing counters past validation. | Check every index explicitly. All 256 layouts of eight slots verify dense-only acceptance, including valid short arrays. Valid schema-14 data stays compatible. |
| High operational risk | Schema-13 servers cannot read v14 writes; acquisition can already upgrade data. A normal publish/restart overlaps incompatible jobs. New figure/group/collection IDs can also break old readers without changing the schema. | Maintenance/drain/lease-expiry/snapshot procedure documented; a future compatibility bridge must preserve newer fields and semantics, not only accept the version number. Old writers remain fail-closed. |
| Medium operational risk | Removing catalog or pity/collection IDs makes previously valid profiles unloadable. They are currently rejected rather than truncated. | Keep historical IDs readable; coordinate and test any future retirement. No IDs changed. |
| Medium documentation risk | README wrote schema 13 and README/operations/roadmap/architecture/design described an unpublished candidate. Target production IDs were absent. | Corrected current schema/live status; documented exact target verification as a publisher gate. Historical audit records retain their historical status. |

Source changes are confined to `Storage.luau` and `Profile.luau`. `tests/SaveSafety.spec.luau`
uses the existing engine double and production modules; `tests/run.py` includes it in the normal
suite. No framework, dependency, economy, DataStore identity, content ID or persisted format changed.
The audit found no default overwrite path on failed loads, stale-owner overwrite path, or
independent durable reward/claim writes in the inspected implementation.
Historical verification: the pre-deals `Profile` at `960b109^` writes schema 13 and accepts
only versions 6–13; its version allowlist rejects v14 before decoding fields. An older-code
rollback therefore cannot be assumed safe after the current writer has acquired profiles.

## Verification and release readiness

The complete deterministic Luau 0.739 suite passed, including the new save suite and
18 invalid-configuration startup fixtures. After adding dormant-overflow and missing-version
fixtures, the focused final save suite passed **458 checks**. New checks cover all supported populated schemas,
exact current aggregate reload, every missing required field, future readers/writers/reclaim,
removed IDs/customization, failed loads, before/after-commit failures, a purchase during an
unacknowledged autosave, final release/rejoin, one-time offline claims, takeover, shutdown timeout,
cancelled-handoff recovery and callbacks retried against changed ownership. Existing daily/login,
Welcome, goals, purchase, shelf and AFK suites also passed. Engine doubles are not native tests.

Pinned `rokit install`, `wally install`, StyLua formatting/check, Selene (zero errors/warnings),
Rojo sourcemap/build, Luau Language Server 1.70.1 analysis of all `src` (zero diagnostics), and
`git diff --check` passed. Cache/path restrictions required tool execution outside the sandbox;
the initial analysis without a successfully generated sourcemap was discarded and rerun correctly.
Generated outputs stay ignored.

Readiness: **CONDITIONAL**. Before publishing, confirm actual production PlaceId/UniverseId and
running versions, complete isolated native persistent leave/rejoin/shutdown and two-server tests,
rehearse real AFK teleports, and confirm the pre-release native snapshot. No Studio was connected;
no native Studio playtest, real DataStore rehearsal, production snapshot or published test was run
in this audit. Existing recorded native UI checks do not close those gates.

## Limits that remain

- Action success acknowledges memory, not durable storage. A hard crash or Roblox outage can lose
  progress since the last committed aggregate (normally about 30 seconds plus latency, potentially
  longer on failure). Final saves and the 25-second shutdown deadline are best-effort. The new fix
  reconciles uncertain generations; it cannot make an unavailable API succeed.
- An unsaved reward rolls back with its cost/claim marker and downstream mutations. With no external
  transfer system, this avoids preserving a reward while independently resetting its claim marker;
  it does not promise that the player will retain every action seen on screen.
- Crashes leave leases until expiry. A rapid rejoin may exhaust its short load retries and need a
  later rejoin after the 120-second lease horizon. This favors safety over availability.
- Offline computation uses saved wall time. A crash can count time since the last checkpoint as
  absence, including some prior online time. Clock skew near an hourly boundary can refresh deal
  stock when the window moves backward; the existing documented policy accepts this edge.
- Changed content/rules can change income or hide geometry; preserving IDs and fields does not
  guarantee identical presentation/rates in future releases. This audit changes neither.
- Existing offline claims (including automatic claims on join) discard any award above wallet
  capacity, as specified in [economy](ECONOMY.md#offline-earnings). Figure-bank collection retains
  overflow. These existing cap semantics were preserved, not changed as part of save safety.
- Native historical versions have granularity/retention limits. Code rollback does not undo data;
  blindly restoring an envelope can revive a stale lease, and restoring old data loses later
  progress. Recovery requires quiescence, conditional writes and separate approval.

Follow [DEPLOYMENT.md](DEPLOYMENT.md) for routine updates, incompatible releases, monitoring,
backups, player reports and rollback decisions. Do not reset records to resolve a failed load.
