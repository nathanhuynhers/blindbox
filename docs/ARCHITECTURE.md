# Implemented architecture

The user accepted the MVP and authorized the full-game roadmap. The new candidate implements
that feature set; real storage, device and multi-client acceptance are still pending. See
[scope](FULL_GAME.md) and [operations](OPERATIONS.md). No package/framework dependency was added.

## Server ownership

- `init.server.luau`: player lifecycle, server-created remotes, the single elapsed-income
  scheduler, sanitized owner snapshots, public showroom directory, and visit navigation.
- `Transactions.luau`: exact parsed intents, token-bucket limits, mutation revisions and bounded
  receipts (64 / 120 seconds). Mutations never yield. The callback Player determines ownership.
- `Protocol.luau`: bounded payloads and allowlisted figure/collection/palette/slot IDs. Actions
  are Buy, Place, Remove, Recycle, Redeem, Expand, Theme, Daily, Goal. Optional `choice` is only
  allowed for box and palette actions; callers never supply price, rewards or owner identity.
- `Rules.luau` and `Economy.luau`: atomic in-memory domain mutations, per-figure rates, small
  themed-display bonus, fraction accounting, inventory reservations, daily eligibility and costs.
- `Profile.luau`: explicit serialized projection, bounded schema validation and v1-to-v2
  migration. Unknown/corrupt/incompatible data blocks loading and saving.
- `Persistence.luau`: non-yielding UpdateAsync transforms, exclusive leases, monotonically
  increasing save generations, writer identity and uncertain-commit reconciliation. Storage
  update is injected for fault tests; production only uses DataStoreService.
- `Storage.luau`: native service adapter, retries, autosaves, ready/paused state, final release,
  and explicitly configured Studio preview. A failed persistent load never becomes preview.
- `Rooms.luau`: bounded personal geometry, shelf models, palettes and completion plaques.
  Signature checks avoid rebuilding unchanged displays. Failed figure rendering uses a fallback.
- `World.luau`: static garden paths, trees and welcome plaza. `Settings.luau`: store names,
  Studio test setting and 24-room capacity.

Each player has one mutable State aggregate shared by Transactions and Storage. Before changing
slots, income settles at the old rate. Snapshots never expose accrual timestamps, fractions,
lease tokens, receipts or other players' balances. Passive income advances snapshot sequence,
not mutation revision. Server proximity checks apply to the caller's own shelf.

## Persistence and acknowledgement

See [data model](DATA_MODEL.md) for validation and [operations](OPERATIONS.md) for recovery.
Every load/acquire, save and release uses UpdateAsync. Lease tokens are unique per join. Leases
last 120 seconds, renew with 30-second autosaves, and local gameplay pauses after 85 seconds
without confirmed renewal. Save generations plus writer tokens reconcile responses lost after
commit. Snapshots are cloned before yielding; one write at a time runs for each profile.

Normal action replies acknowledge in-memory results, not durable storage. Daily claim markers
and grants are saved in the same aggregate; after a crash both roll back together to the last
snapshot. No transfers or paid grants exist. Recent unsaved soft-currency actions may be lost
on a crash. A failed save pauses new economic actions; it never overwrites data with defaults.
Leaving/shutdown attempts a bounded final save/release, with lease expiry as crash recovery.

## Client presentation

`init.client.luau` queues one mutation at a time and retries the same ID after delayed replies.
It reconciles ordered owner snapshots. `Interface.luau` owns Collection, Display, Shop, Goals
and Visits pages, reveals, room-rate label, status, filters and motion reduction. `Widgets.luau`
contains focused UI construction helpers. `Scroll.luau` explicitly measures layout content and
padding, listens for content/viewport changes, and cleans up listeners. This replaces reliance
on automatic canvas sizing that truncated the collection in the MVP. Layout uses the actual
safe-area Frame size so the lower menu is clear of the feedback bar on small devices.

`Visitors.luau` animates at most two local decorative visitors in the currently visited room
at 20 updates/second. Motion reduction hides them. Visitors never report or change payouts.
UI connections, models, spawn tasks and room instances have explicit owners and teardown.

Shared Catalog/Types/FigureModel contain only public definitions, contracts and original
procedural art. Figure identity is a quantity stack; trading/unique variants are not implemented.

## Social boundary

Visit requests accept only a bounded integer host ID (0 means home), resolve an online host,
check the caller's living character, and apply a two-second cooldown. The server determines
the destination. Public directory entries contain owner ID/name, displayed IDs, rate and theme.
No private inventory or balances are sent to guests. Host departure returns tracked guests home.
The server limits active/initializing rooms to 24; configure the experience player cap accordingly.

## Preserved tooling and evidence

Rojo 7.7.0 keeps Server as a Script, Client as a LocalScript, Shared as a Folder, and the optional
Packages Folder in ReplicatedStorage. Wally remains empty. Pinned StyLua/Selene are unchanged.
Server modules are never mapped to ReplicatedStorage. Generated builds, tools and API caches
are ignored. The standalone harness runs actual domain/persistence/scroll modules; only engine
resolution/colors/UI property signals are shimmed. It does not prove Roblox runtime behavior.
