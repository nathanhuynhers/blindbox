# Implemented architecture

The user accepted the MVP and authorized the full-game roadmap. The new candidate implements
that feature set; real storage, device and multi-client acceptance are still pending. See
[scope](FULL_GAME.md) and [operations](OPERATIONS.md). No package/framework dependency was added.

The candidate now separates economic Display, cosmetic Showrooms and owner-specific spatial
Galleries. See [foundation implementation](DISPLAY_SHOWROOM_IMPLEMENTATION.md) and
[schema-v3 migration](DATA_MODEL.md). Native runtime acceptance remains pending.

## Server ownership

- `init.server.luau`: player lifecycle, server-created remotes, the single elapsed-income
  scheduler, sanitized owner snapshots, public Display directory, and main-plot visit navigation.
- `Transactions.luau`: exact parsed intents, token-bucket limits, mutation revisions and bounded
  receipts (64 / 120 seconds). Mutations never yield. The callback Player determines ownership.
- `Protocol.luau`: bounded payloads and allowlisted figure/collection/palette/slot IDs. Actions
  are Buy, Place, Remove, Recycle, Redeem, Expand, Daily, Goal, ShowroomPlace, ShowroomRemove and
  ShowroomTheme. Cosmetic edits carry stable room/anchor IDs and a current room runtime token.
  Callers never establish price, rewards, ownership or edit permission.
- `Rules.luau` and `Economy.luau`: atomic in-memory domain mutations, per-figure rates, small
  themed-display bonus, fraction accounting, inventory reservations, daily eligibility and costs.
- `Profile.luau`: explicit serialized projection, bounded schema validation and v1/v2-to-v3
  migration. Unknown/corrupt/incompatible data blocks loading and saving.
- `Persistence.luau`: non-yielding UpdateAsync transforms, exclusive leases, monotonically
  increasing save generations, writer identity and uncertain-commit reconciliation. Storage
  update is injected for fault tests; production only uses DataStoreService.
- `Storage.luau`: native service adapter, retries, autosaves, ready/paused state, final release,
  and explicitly configured Studio preview. A failed persistent load never becomes preview.
- `PlayerPlot.luau` (formerly Rooms): generic personal plot, six Display positions, lock markers,
  legacy plaques and one Gallery entrance. Signature checks avoid unchanged figure rebuilds.
- `Showrooms.luau`: collection completion reconciliation, cosmetic eligibility/edit rules,
  stable identity validation and deep public/save projections. No economy reads its placements.
- `GallerySessions.luau`: pure owner/participant membership, allocation and generation lifecycle.
- `GalleryRuntime.luau`: validated physical entrance/exit prompts, shared owner halls, paged
  doors, lazy room instances, separate room-generation tokens, proximity and cleanup.
- `SpaceTemplate.luau`: replaceable primitive hall/room/portal presentation and customization hooks.
- Shared `DisplayConfig`/`ShowroomConfig`: public capacity, anchor and extension definitions.
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
composes dedicated HUD, navigation, book/details, shop, Display controls (`DisplayScreen`),
goals and Social modules. `ShowroomScreen` supplies the minimal cosmetic editor/read-only view
inside Social during a Gallery visit.
`UITheme`, `Widgets`, `UIIcons` and `UIPreview` provide common tokens, touch controls, progress,
original icon shapes and static asset slots. `UIState` derives read-only presentation metadata;
`UIScope` owns connections/tweens/timers. A bounded `Notifications` component handles feedback.

`Scroll.bind` accepts both list and grid layouts and measures content plus padding explicitly.
Nested tile groups report their measured height to the outer list. Filtering and safe-area
resize preserve access to every figure. Independent presentation hosts replace the common menu shell: desktop rail, themed book spread,
package-led shop, compact daily/social sheets and bottom Display controls. Narrow/touch windows use
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

`Visitors.luau` animates at most two local decorative visitors in the currently visited main plot
at 20 updates/second. Motion reduction hides them. Visitors never report or change payouts.
UI connections, models, spawn tasks and room instances have explicit owners and teardown.

Shared Catalog/Types/FigureModel contain only public definitions, contracts and original
procedural art. Figure identity is a quantity stack; trading/unique variants are not implemented.

Shared `AssetManifest` resolves semantic artwork keys through generated `AssetIds`; absent
entries resolve to an empty string. The local standard-library Python uploader records public
IDs/provenance in `assets/uploads.json` and regenerates only the dedicated ID module. Credentials
stay in the local environment. Uploading does not activate UI artwork; existing Collection
native fallbacks remain until explicit adoption. See [asset pipeline](ASSET_PIPELINE.md).

The Shop is a neutral reusable shell composed by `ShopScreen`. `ShopTheme` contains only
collection asset keys and palette inputs; `ShopState` derives figures, unique progress and
rarity odds from Catalog/snapshots; `ShopLayout` owns responsive geometry; `BlindBoxPreview`,
`BlindBoxSkin`, and `ShopArtwork` provide the standardized 3D package and exclusive native fallback. Catalog iteration
creates the carousel and possible-figure entries, so another collection does not require a Shop
layout fork. Buy still uses the existing server-authoritative intent and opening-result path.

## Social and Gallery boundary

Existing plot visits resolve online hosts and living characters with a two-second cooldown. Each
plot has one Gallery entrance: a server-owned prompt resolves its host, validates physical
proximity and session availability, and joins an owner-specific runtime. Room portals expose only
that owner's unlocked rooms. A hall renders at most six doors and physical paging portals; the
persistent room map has no four-room cap. Rooms instantiate only while occupied.

Gallery and room generations are separate. Edits require the current room token, revision,
membership, room ownership, valid anchor, permanent figure discovery and live-room proximity.
All use the existing Intent/Transactions path and bounded receipts/token bucket. A visitor can
walk through and observe, but cannot edit. Public views omit private inventory, discovery,
balances, palette ownership, progression and storage data. Physical room models are public art.

Last-room-occupant departure destroys that room; last-Gallery-participant departure destroys the
hall. Owner leave returns guests home. Character reset, visitor leave, plot navigation and
externally destroyed instances clear membership and disconnect owned connections. Multiple owners
have isolated interior lanes. Runtime coordinates and membership are not persisted.

Display uses only its own slots for income, bonuses, reservations and daily goals. Cosmetic
Showroom references reserve zero copies and can repeat across rooms, even while the same figure
earns in Display. Collection acquisition and profile load reconcile earned rooms idempotently.
Legacy palette ownership/preference migrates to Showrooms; new palette purchasing is deferred.

## Preserved tooling and evidence

Rojo 7.7.0 keeps Server as a Script, Client as a LocalScript, Shared as a Folder, and the optional
Packages Folder in ReplicatedStorage. Wally remains empty. Pinned StyLua/Selene are unchanged.
Server modules are never mapped to ReplicatedStorage. Generated builds, tools and API caches
are ignored. The standalone harness runs actual domain/persistence/scroll modules; only engine
resolution/colors/UI property signals are shimmed. It also checks the client opening clock and
confirmed-result adapter. It does not prove Roblox runtime behavior.
