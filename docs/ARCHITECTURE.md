# Implemented architecture

`src/shared/Rarity.luau` is the canonical public rarity identity/order/type/palette module:
Common < Uncommon < Rare < Legendary < Mythical. Catalog validates against it; server Rules
retains explicit per-figure weights/rates and checks rate ordering across populated tiers.
UI colors and Shop ordering consume it, while client OpeningConfig owns presentation profiles.
The new tiers are supported without adding obtainable content. See [the audit and extension
procedure](RARITY.md); persistence, inventory and grants remain figure-ID based.

The user accepted the MVP and authorized the full-game roadmap. The new candidate implements
that feature set; real storage, device and multi-client acceptance are still pending. See
[scope](FULL_GAME.md) and [operations](OPERATIONS.md). No package/framework dependency was added.

The active world uses fixed open Player Plots, earning Display and cosmetic Shelf Units.
See [canonical direction](PLAYER_PLOTS_AND_SHELVES.md) and [schema-v5 migration](DATA_MODEL.md).
The former separate Gallery/room runtime has been removed, not retained as an alternate path.

## Server ownership

- `init.server.luau`: reserves fixed plot slots before profile load, owns player lifecycle and
  remotes, validates ready sessions, sends private owner snapshots and runs the existing income clock.
- `PlotConfig`/`PlotSlots`: eight finite locations; unique pending/active allocation and explicit release.
- `World`/`PlotGeometry`/`PlotFixture`: a recessed circular warm-neutral foundation, two-layer
  100-stud ivory/oak plaza, eight trimmed radial paths with 32 bounded bollard lights and eight
  layered open platforms on a 170-stud-radius ring. Deliberately separated top planes prevent
  path/plaza z-fighting. One plot-local `CFrame` rotates each complete fixture inward. Static
  world geometry persists; owner identity remains session-owned and is destroyed with `PlayerPlot`.
- `PlayerPlot`: owner sign, horizontal growing Display, three shelf units, shared physical arrows,
  proximity checks, runtime carousel start index and connection/content teardown.
- `CollectionFixture`: native oak/ivory three-bay Collection installation, permanent COLLECTION
  SurfaceGui header, row lighting, icon-only side controls and runtime anchors. Visual construction
  is separate from shelf ownership, carousel decisions and migration; indices stay in owner UI.
- `FigureSlots`: per-slot figure cache using existing FigureModel assets; replace only changed IDs,
  or a figure whose production template became ready (`FigureModel.variant`).
- `Shelves`: discovered-reference rules, visible owned-unit validation, stable slot IDs, runtime carousel
  revision/wraparound/cooldown and bounded three-unit projections. Zero economy/inventory reservations.
- `Rules`/`Economy`: unchanged Display rate/bonus/reservations, purchases, inventory and daily logic.
- `Protocol`/`Transactions`: allowlisted typed fields/actions, token bucket, profile revision and
  exact retry receipts. Shelf edits additionally require visible persistent Shelf Unit ID and carousel revision and owner access.
- `Profile`/`LegacyCosmetics`/`LegacyShelfPages`: schema-v5 validation/deep copies and decode-only
  v1-v4 conversion. Legacy modules contain no runtime rooms, browsing or completion grants.
- `Persistence`/`Storage`: existing UpdateAsync leases/generations, failure pauses, autosaves and
  isolated Studio/live stores. Failed loads never overwrite progress with defaults.

Only `Intent`, `State` and `RequestState` remotes remain. No owner/plot identity comes from a
mutation request. Requests resolve to the callback Player's session. Display placement checks
that player's own plot/proximity. Shelf edits require a visible owned unit ID, configured local slot,
discovery, profile revision and carousel revision; A-B-A navigation invalidates stale edits.
Physical arrows are server-bound to a plot, validate living character/distance/session, and use
a shared per-plot cooldown. They change only runtime visibility, not saved progression.

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
goals and `ShelvesScreen`, a minimal owner editor with three-unit selection and carousel controls and a discovered
figure picker. There is no visit directory or teleport callback.
`UITheme`, `Widgets`, `UIIcons` and `UIPreview` provide common tokens, touch controls, progress,
original icon shapes and static asset slots. `UIState` derives read-only presentation metadata;
`UIScope` owns connections/tweens/timers. A bounded `Notifications` component handles feedback.

`Scroll.bind` accepts both list and grid layouts and measures content plus padding explicitly.
Nested tile groups report their measured height to the outer list. Filtering and safe-area
resize preserve access to every figure. Independent presentation hosts replace the common menu shell: desktop rail, themed book spread,
package-led shop, compact Goals/Shelves sheets and bottom Display controls. Narrow/touch windows use
bottom navigation; short landscape gives its space to the active screen until close. `UILayout`
owns bounds, while `CollectionStyle`/`CollectionArt` isolate collection identity from neutral
`UITheme` controls. Details replace the book grid on narrow screens. `CollectionSelection`, `CollectionLayout`,
`CollectionSkin`, `CollectionTabs`, `CollectionControls` and `CollectionAssets` separate state,
physical presentation and uploaded/native artwork; see [Collection](COLLECTION_UI.md). See the
[UI behavior, module boundaries and Studio checklist](UI_UX.md).

Opening presentation is separate: `OpeningResult` derives immutable presentation metadata from
the pre-request and confirmed reply snapshots; `OpeningController` owns one opening session,
input focus, sound timing and teardown. `OpeningState` is a deterministic clock/interaction
state machine. `OpeningCinematic` owns an isolated client-only 3D stage; `OpeningCamera` and
`OpeningScope` restore camera/input/UI on every exit. `OpeningBox` animates the existing production
package with an independent lid pivot and emergency procedural fallback. `OpeningEffects` provides
real particles, comet flight, rarity tease and impact; `OpeningFigure` reuses the awarded figure
factory for silhouette/reveal. `OpeningView` is the responsive overlay, while `OpeningConfig`
and `OpeningAudio` own data-driven presentation and optional licensed sound cues. Buy/Daily
show a box, Redeem goes directly to the figure spotlight. Skipping or interrupting presentation
cannot affect the already-granted item. See [opening behavior and Studio checks](OPENING.md).
No opening-specific remotes or server logic were introduced.

There are no simulated visitor actors. Real players walk into open plots. Character respawn
returns only that character to its assigned plot; it does not reset shelves or require visit
sessions. Leaving destroys owner content and connections and releases the slot. Visitors remain
on the shared ground safely. Plot allocation/coordinates and carousel visibility are not saved.

Shared Catalog/Types/FigureModel contain only public definitions, contracts and original
procedural art. Production figure models: `ModelAssets` (server) loads each `FigureAssets` entry (generated
`FigureAssetEntries`, written by `tools/figures/publish.py`)
with `InsertService`, validates part count and authored proportions, turns the eyes toward -Z,
applies the uniform collection scale and a base-centre pivot, and publishes the template to
`ReplicatedStorage.ProductionModels.Figures.<catalog id>`, incrementing `FigureRevision`.
`FigureModel.create` clones a template once its replicated part count matches and otherwise
builds the procedural placeholder. Plots re-render and `UIPreview` rebuilds when a template
arrives; undiscovered previews hide production textures. Failures leave the placeholder and set
`<Root>Status`/`<Root>Reason` attributes on the `Figures` folder. Figure identity is a quantity stack; trading/unique variants are not implemented.

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

## Public/private boundary and rendering

Only owner-labelled geometry, active Display figures/rates and visible shelf figures/Collection signage
are public. Owner state events never go to guests. Each owner gets only three visible Shelf Units with IDs, indexes and local placements,
owned count, carousel revision and navigation availability. The server sends no private balances, inventory, discovery or progression
to visitors. Visitors may turn physical shelf arrows but cannot mutate the owner's saved state.

No per-frame plot work is added. Static geometry persists for the session. Rendering compares
slot figure IDs on successful mutations/carousel changes; one changed figure creates one replacement,
and unchanged IDs can be reused between viewport positions. The visible load is bounded at 27 cosmetic figures
plus at most six Display figures per player. Native eight-player/mobile performance is unmeasured.

## Preserved tooling and evidence

Rojo 7.7.0 keeps Server as a Script, Client as a LocalScript, Shared as a Folder, and the optional
Packages Folder in ReplicatedStorage. Wally remains empty. Pinned StyLua/Selene are unchanged.
Server modules are never mapped to ReplicatedStorage. Generated builds, tools and API caches
are ignored. The standalone harness runs actual domain/persistence/scroll modules; only engine
resolution/colors/UI property signals are shimmed. It also checks the client opening clock and
confirmed-result adapter. It does not prove Roblox runtime behavior.
