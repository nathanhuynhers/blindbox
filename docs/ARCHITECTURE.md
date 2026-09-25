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
It reconciles ordered owner snapshots and exposes pending-request state to the UI. `Interface`
composes dedicated HUD, navigation, book/details, shop, showroom, goals and visits modules.
`UITheme`, `Widgets`, `UIIcons` and `UIPreview` provide common tokens, touch controls, progress,
original icon shapes and static asset slots. `UIState` derives read-only presentation metadata;
`UIScope` owns connections/tweens/timers. A bounded `Notifications` component handles feedback.

`Scroll.bind` accepts both list and grid layouts and measures content plus padding explicitly.
Nested tile groups report their measured height to the outer list. Filtering and safe-area
resize preserve access to every figure. Independent presentation hosts replace the common menu shell: desktop rail, themed book spread,
package-led shop, compact daily/social sheets and bottom room controls. Narrow/touch windows use
bottom navigation; short landscape gives its space to the active screen until close. `UILayout`
owns bounds, while `CollectionStyle`/`CollectionArt` isolate collection identity from neutral
`UITheme` controls. Details replace the book grid on narrow screens. `CollectionSelection`, `CollectionLayout`,
`CollectionSkin`, `CollectionTabs`, `CollectionControls` and `CollectionAssets` separate state,
physical presentation and uploaded/native artwork; see [Collection](COLLECTION_UI.md). See the
[UI behavior, module boundaries and Studio checklist](UI_UX.md).

Opening presentation is separate: `OpeningResult` derives immutable presentation metadata from
the pre-request and confirmed reply snapshots; `OpeningController` owns one opening session,
input focus, sound timing and teardown. `OpeningState` is a deterministic clock/interaction
state machine. `OpeningView`, `OpeningBox`, `OpeningConfig` and `OpeningAudio` own procedural
viewport packaging, rarity visuals, responsive UI and optional licensed sound cues. Buy/Daily
show a box, Redeem goes directly to the figure spotlight. Skipping or interrupting presentation
cannot affect the already-granted item. See [opening behavior and Studio checks](OPENING.md).
No opening-specific remotes or server logic were introduced.

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
resolution/colors/UI property signals are shimmed. It also checks the client opening clock and
confirmed-result adapter. It does not prove Roblox runtime behavior.
