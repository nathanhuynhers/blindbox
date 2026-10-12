# Automatic AFK reconnect

Implementation is enabled for published **public servers** only. Studio preview and
private/reserved servers do not initiate automatic teleports. There are no packages,
new profile fields, input simulation, reservations, or economy tuning changes.
Live teleport and native device acceptance remain release gates; this document is
not evidence that either passed.

## Flow and configuration

`src/shared/AfkConfig.luau` owns the enable switch, 1,110-second idle target,
90-second safety margin before the nominal 20-minute idle limit, freshness and
confirmation timeouts, two retries, 3/8-second retry delays, and debug switch.
The effective target is the earlier of the idle target and limit minus margin.
This is an approximate target: event delivery, input, save latency and matchmaking
can move it later. Changing shared config requires restarting both server and client.

`AfkClient` uses `LocalPlayer.Idled`'s reported seconds and a monotonic local clock.
InputBegan/InputChanged/InputEnded (including processed menu/chat input), focus
return and character changes reset eligibility. Small neutral gamepad stick noise
is ignored. Fresh engine idle events are required; the clock stops being usable
after 45 seconds without one. Reports are bounded to once per 15 seconds.

`AfkReconnect` tracks each ready session using server time. A first report can
backdate only the initial two-minute detection delay, bounded by the last server
activity. The server also requires a full idle interval since join/last activity,
observes character movement in the existing one-second loop, and treats gameplay
requests and native collections as activity. Malformed payloads, client destinations,
nonfinite/out-of-range durations, stale tokens and duplicate confirmations are rejected.
The destination is always server-selected `game.PlaceId` with ordinary public
matchmaking through `TeleportAsync`; no client chooses a server or place.

After eligibility, a fresh server challenge asks the client to confirm it is still
idle and has no pending transaction, reveal or remaining batch presentation. The
client guards new requests before acknowledging. Only then does the reconnect
notification appear, using the existing UIStyle/UIKit tokens. After saving, another
fresh challenge checks activity again immediately before invoking TeleportAsync.
Every retry gets a new confirmation and token. The clone of the notification is the
custom teleport loading screen. Input, cancellation and failure destroy owned UI;
a subtle welcome appears once the normal destination snapshot is ready.

## Profile and earnings handoff

`Storage.prepareTeleport` sets a transfer barrier **before yielding**, drains any
in-flight autosave, verifies the safe lease, settles active Display banks, and freezes
authoritative changes and earnings. The normal `Profile.encode` aggregate saves
every implemented persistent field through the existing UpdateAsync lease/generation
protocol. The immutable checkpoint's lastSeen matches this settlement boundary.
The save releases the source lease, so destination initialization uses the normal
Storage.open, offline calculation, plot allocation and spawn binding without waiting
for source PlayerRemoving. Teleport data carries only an AFK flag and attempt
correlation metadata; it carries no profile, currency, inventory or lease secret.

Autosaves and all purchase/reward/collection paths stay blocked during handoff.
MN-22 additionally blocks AFK confirmation/preflight during an active P02 prompt or
fulfillment. Cancelled reservations remain in schema17 through the normal checkpoint;
destination base auto-claim and delayed extra-N receipt recovery are independent. See
[offline award/receipt contract](OFFLINE_DOUBLE_CLAIM.md). These additions were verified
with Storage/Persistence fixtures; native AFK/purchase behavior remains pending.
Source PlayerRemoving skips a second write after a confirmed release, preventing a
stale source from overwriting its destination. Existing atomic grants and retry
receipts remain unchanged. P02/MN-22/boost receipt adapters now honor the same transfer
barrier and retain obligations through handoff; actual paid use remains disabled.

On arrival, active banks retain their fractions and overflow. Offline earnings
consider only elapsed time **after** the frozen checkpoint: the existing minimum
absence, half rate, six-hour cap, multipliers, wallet limit and one-time claim rules
still apply. Auto reconnect does not auto-collect figure banks. Repeated AFK cycles
extend ordinary online earning time by design, but add no new rate, reward, claim,
or uncapped offline calculation.

If teleport fails or activity resumes, `Persistence.resume` uses UpdateAsync to
reclaim only the same writer and generation (including a release/reclaim whose
response was lost), without rewriting stored data. It cannot take a profile another
server acquired. Only confirmed ownership enables gameplay again; source recovery
settles paused handoff time as active income and does not calculate offline income.
The next normal save promptly advances lastSeen. Save/reclaim failures retain the
profile and pause gameplay; rejoining may be necessary when recovery cannot finish.

## Failure and security limits

Synchronous errors and correlated TeleportInitFailed events permit at most two
retries, without another checkpoint. A missing confirmation, slow save or delayed
initialization cancels with bounded recovery. An unresolved yielding API cannot be
cancelled safely: the UI recovers, but no retry/reclaim overlaps that call; recovery
waits for its return. Player removal and shutdown invalidate callbacks; no per-player
timers, connections or retry queues survive them. A failed idle cycle stays exhausted
until new activity. Diagnostics are bounded to these attempts.

Roblox exposes idle/input evidence on the client, so server checks cannot prove the
absence of all physical input. An exploiter can suppress input reports, but cannot
bypass the server's elapsed eligibility interval, choose another destination, claim
extra progress, or trigger overlapping calls. There is also an unavoidable network
race: input **after** the final confirmation/API invocation cannot recall a teleport
already submitted to Roblox. It cancels further retries. Disconnects, lost connectivity,
matchmaking failure and indefinitely delayed engine/service calls remain possible;
uninterrupted AFK sessions are not guaranteed.

## Verification

Changed files: new `src/shared/AfkConfig.luau`, `src/shared/AfkIdle.luau`,
`src/server/AfkReconnect.luau`, `src/client/AfkClient.luau` and
`src/client/AfkNotice.luau`; integration changes in both `init` scripts,
`Storage.luau` and `Persistence.luau`; three AFK specs plus `tests/AfkEngine.luau`
and the existing `tests/run.py`; this document and `docs/ARCHITECTURE.md`.

The existing standalone Luau harness runs real production modules with engine I/O
doubles. New suites are `AfkReconnect.spec`, `AfkStorage.spec` and `AfkClient.spec`.
They cover client clocks/input, threshold/authority, token and rate checks,
duplicate requests/events, busy presentation, activity during saves and queued API
calls, failed/uncertain writes, reclaim conflicts, aggregate round trips, transaction
replay, active/offline boundaries, bounded retries/timeouts, source removal, normal
joins, responsive geometry and repeated teardown. Engine doubles do not validate
actual rendering, platform input or live teleport execution.

Verification performed on October 11, 2026: pinned `rokit install` and `wally install`,
full standalone regression suite (including 148 new AFK checks and 18 invalid-config
fixtures), `stylua --check src`, `selene src` (zero errors/warnings), Rojo sourcemap/build,
`git diff --check`, and Luau Language Server analysis of all `src` passed. The final
AFK suites were rerun after the last cleanup changes. No Studio playtest or published
Roblox teleport test was performed.

### Published test checklist

1. Publish this build to an isolated test experience and join a public server through
   the Roblox application. Use disposable test accounts and separate stores if the
   experience shares production users. Record PlaceId/JobId and a profile snapshot.
2. Remain idle through the real 18.5-minute interval. Check the notification, custom
   loading screen, same PlaceId, different public JobId, normal newly allocated plot,
   restored figures/Display/Shelves/pity/rewards/upgrades and welcome message.
3. Repeat with keyboard/mouse, touch and gamepad. Input in chat/menus, focus return,
   walking and respawn near the threshold must cancel before API invocation. Hold
   movement/continuous input through the threshold; it must not reconnect.
4. Start Buy/Open 10 and a reward claim near eligibility. Pending receipts and reveals
   must finish without interruption; currency and inventory must round-trip once.
5. Compare bank fractions, wallet, unclaimed offline award and lastSeen across several
   cycles. A short hop awards no extra offline income. An extended destination load
   uses only post-checkpoint absence and the existing caps/multipliers.
6. In a private test build, inject failure at the TeleportAsync adapter and copied
   TeleportInitFailed options. Check three maximum calls with 3/8-second backoff, one
   checkpoint, UI recovery, no repeat cycle without activity, and safe resumed play.
7. Inject DataStore failures before/after commit, slow saves and unavailable reclaim.
   No known failed checkpoint may teleport; uncertain results must reconcile safely.
   If another server acquires first, source gameplay must remain paused.
8. Leave or shut down during preparation/retry and repeat with two accounts. Check
   independent profiles/plots, no source write after destination acquisition, no stale
   callbacks and no growing connection/task count. Normal joins and Studio preview
   must keep their existing behavior. Remove every fault injection before release.
