# Implemented architecture

`src/shared/Rarity.luau` owns public rarity identity/order/type/palette. Server
`Economy` defines reusable economic tiers, bucket/pity/duplicate profiles, collection references
and explicit figure income units/weights. `CollectionEconomy` validates configuration and derives
prices, base rates, current odds, rolls and duplicate multipliers. `Rules` owns atomic mutations,
income settlement and unique Display placement. See [economy](ECONOMY.md).

The user accepted the MVP and authorized the full-game roadmap. The new candidate implements
that feature set; real storage, device and multi-client acceptance are still pending. See
[roadmap](ROADMAP.md) and [operations](OPERATIONS.md). No package/framework dependency was added.

The active world uses fixed open Player Plots, earning Display and cosmetic Shelf Units.
See [canonical direction](PLAYER_PLOTS_AND_SHELVES.md) and [current data model](DATA_MODEL.md).
The former separate Gallery/room runtime has been removed, not retained as an alternate path.

## Server ownership

- `init.server.luau`: reserves fixed plot slots before profile load, owns player lifecycle and
  remotes, validates ready sessions, sends private owner snapshots and runs the existing income clock.
- `PlotConfig`/`PlotSlots`: eight finite locations; unique pending/active allocation and explicit release.
- `World`: builds Blindbox Town once per server and returns its root, leaderboard board, plaza
  spawn and light entries: grass island, eight paths with bollards, Market Street with lanterns,
  gap gift-box stacks/statue gardens, the hedge/tree edge and invisible boundary walls.
- `TownModels`/`TownPlacements`: server-only templates for the uploaded tree and Peeka statue
  models (part-count, collision and facing checks), and the registry that swaps each part
  placeholder for a scaled copy when its model loads. Failed loads keep the placeholders.
  `PlazaFixture` owns the plaza, giant blind box, pop-up stalls, planters, board placement and the
  pre-assignment `SpawnLocation`. `TownLayout` holds every radius/angle and the part/light
  budgets, `TownStyle` the pastel palette, and `TownProps` the reusable native-part prop builders.
- `PlotGeometry`/`PlotFixture`/`PlotStyle`/`Awning`: one plot-local `CFrame` per plot; layered
  platforms with potted plants; the session-owned walk-through entrance arch and flush spawn pad;
  striped awnings for Display/Shelves. `PlotStyle.accent(ownerId)` is the single accent accessor.
- `PlayerSpawn`: binds a loaded player to their plot's server-computed spawn `CFrame` for the
  current character, respawns and reloads; unbound on leave.
- `MovementConfig`/`PlayerMovement`: server-only baseline WalkSpeed (20 studs/second for
  LOGIC-03 playtesting), bound before profile loading for initial characters and every respawn.
  A character-owned ChildAdded watcher handles late Humanoids without polling or waits and
  disconnects on success, removal, replacement or unbind. No modifiers or movement entitlements
  exist. Future server-owned speed resolution belongs in PlayerMovement. Opening input/camera
  teardown and Home teleports do not write or restore WalkSpeed.
- `DayNight`/`NightLights`: a 1-second server loop sets `Lighting.ClockTime` and interpolated
  lighting looks over a 20-minute cycle; `NightLights` is a 72-light budgeted registry that
  switches lights and lens glows only when crossing dusk/dawn. One lifecycle-owned controller
  per active plot also retunes its existing Display and Shelf wash lights at those transitions;
  controllers consume no actual-light budget and add no per-frame work.
- `Leaderboard`/`LeaderboardStore`/`LeaderboardStats`/`LeaderboardBoard`: presentation-only global
  leaderboard. The service runs background loops for writes (throttled per player, on leave, budget
  checked, backoff), reads (top 5 per stat every 90 s, last good page kept) and the 8-second page
  cycle; the store is pure and injected with DataStore I/O; the board is the two-sided physical sign.
- `PlayerPlot`: owner sign, horizontal growing Display, three shelf units, shared physical arrows,
  owner/plot-containment checks, runtime carousel start index and connection/content teardown.
- `CollectionFixture`: native oak/ivory three-bay Collection installation, permanent Shelves
  SurfaceGui header, row lighting, icon-only side controls and runtime anchors. Visual construction
  is separate from shelf ownership, carousel decisions and migration; indices stay in owner UI.
- `FigureSlots`: per-slot figure cache using existing FigureModel assets; replace only changed IDs,
  or a figure whose production template became ready (`FigureModel.variant`).
- `Shelves`: owned-copy placement limits across all persistent units, visible owned-unit validation,
  stable slot IDs, deterministic load repair, runtime carousel revision/wraparound/cooldown and
  bounded three-unit projections. Display placement and Shelf allowance remain independent.
- `ShelfShowcase`: runtime per-plot cadence, browsing idle delay and owner editor hold, driven by
  the existing one-second scheduler through `PlayerPlot`'s shared turn/render path. The owner-only
  `ShelfEditor` presentation remote accepts a boolean and bounded monotonic token; owner snapshots
  acknowledge that token with the current view. Client `ShelfEditor` enables edits only after this
  acknowledgement and retains the hold until pending edits receive their receipt, including when
  the screen closes. No progression authority, persisted fields or extra plot tasks are added.
- `Rules`/`Economy`/`CollectionEconomy`: collection prices, soft pity, permanent duplicate income,
  unique earning placements, sequential Coin slot unlocks and Starter-only daily grants. Buy and
  Daily also increment the persistent `boxesOpened` counter in the same atomic grant.
- `Deals`: plaza stall deals. Offers per UTC hour from the window index and config seed alone
  (no cross-server state), the rounded deal price, per-player stock refresh and the private
  snapshot view (offers, own stock, window end). `Rules` runs the `Deal` intent through the Shop
  `Buy` grant. `PlazaFixture` adds one "See deal" ProximityPrompt and a `DealStall` attribute per
  stall; no parts. See [economy](ECONOMY.md#plaza-stall-deals-hourly).
- `Protocol`/`Transactions`: allowlisted typed fields/actions, token bucket, profile revision and
  exact retry receipts. Shelf edits additionally require visible persistent Shelf Unit ID and carousel revision and owner access.
- `Profile`: schema-14 validation/deep copies of pity, per-figure earnings, Display, Shelves,
  rewards, audio settings, Welcome Quest state and plaza stall stock. Valid Economy2 schemas 6–13 upgrade as
  [specified in the data model](DATA_MODEL.md); unsupported or corrupt records fail closed.
  New save namespaces implement the authorized reset; retired legacy adapters are not invoked.
  Shelf decode removes unowned/excess placements in stable unit and numeric row/slot order so
  repaired state follows the normal save path.
- `Persistence`/`Storage`: existing UpdateAsync leases/generations, failure pauses, autosaves and
  isolated Studio/live stores. Failed loads never overwrite progress with defaults.

`Intent`, `State` and `RequestState` retain their profile transaction roles. The parameterless
`Home` event is separate because returning to a plot is non-persistent and needs no revision,
receipt or state reply. Its server callback ignores client payloads, resolves the callback Player's
active session and server-owned plot spawn, validates the live character and ownership, and applies
a one-second per-session cooldown. No owner/plot identity comes from a
mutation request. Requests resolve to the callback Player's session. Display placement checks
that the living player owns and is physically inside the active plot. Shelf edits use the same
own-plot boundary and require a visible owned unit ID, configured local slot,
discovery, ownership, remaining Shelf copy capacity, profile revision and carousel revision;
A-B-A navigation invalidates stale edits.
Physical arrows are server-bound to a plot, validate living character/distance/session, and use
a shared per-plot cooldown. They change only runtime visibility, not saved progression.

## Persistence and acknowledgement

Displayed figures accrue into persisted per-ID banks, never directly into the wallet. PlayerPlot
owns six bounded ClickDetector targets for clicks/taps, validates living owner/exact-target
distance and ancestry, and disconnects input handlers on teardown. Native server callbacks mint
collection requests through Transactions with a server-only authorization flag. Remote Collect
requests cannot set that flag. Rate limits and receipts share the normal transaction path.
Rules.collect and validated Display replacement share a server-only bank transfer helper that
retains overflow/fractions. Place validates before settling the old loadout, transfers only the
outgoing figure's bank and swaps with one revision update in the non-yielding mutation. Rejected
placements leave gameplay state unchanged. Only genuine collection advances the Welcome Quest;
no gamepass service is implemented. Owner snapshots expose balances
only to the owner. Native E proximity prompts near the Display and Shelves open their corresponding
management screens through `DisplayInteraction` and the existing Interface router. They never send
mutation requests. Local ownership, living-character and distance checks guard those routes;
server ownership and plot-containment checks guard edits; close physical distance still guards
per-figure coin collection. The client owns three
service listeners for its lifetime and refreshes the device-aware counter plaque through the
existing snapshot updates, so late plot replication and respawn need no new listeners. Prompt
hiding is presentation, not an authorization check.

`DisplayFixture` also owns six retained collection plates, two parts each, aligned to the same
plot-local slot X coordinates and recentered on every capacity change. Only unlocked plates are
visible; empty ones use muted panels and occupied ones use a pastel inset/gold Coin cue. No lights
or per-frame work are added. `PlayerPlot.bindCollectors` owns six `Touched` listeners alongside
the six click listeners. Contacts resolve the current character through Players, then require a
living owner, attached character/current plot, exact fixture/plate ancestry, narrow local physical
proximity, and a current ready session with an unexpired storage lease. The current authoritative
slot chooses the figure, so replacement never collects a cached target. Both inputs mint the same
non-yielding Transactions request; receipts, settlement, wallet/fraction/overflow and Welcome Quest
semantics are unchanged. A 0.35-second per-slot debounce retains only current character identity
and time; respawn needs no new listeners. Teardown disconnects all listeners and destroys all pads.
The six target parts keep `CanTouch` enabled even while empty/locked, because Roblox disconnects
touch listeners when it becomes false ([BasePart API](https://create.roblox.com/docs/reference/engine/classes/BasePart#CanTouch));
eligibility is enforced by server state instead. Eight plots add 96 parts and 48 touch listeners,
with no additional lights. The runtime fixture budget increases by those twelve parts to 162 per
plot; the contact suite counts 153 BaseParts including awning wedges and click targets at six slots
(figure asset geometry excluded). World and light budgets are unchanged. The plot Shop
(`ShopFixture`, 19 kiosk parts plus an 8-part Peeka stand-in) later raised the budget to 184,
measured at 180 with click targets; it adds no lights, remotes or listeners on the server. Its
uploaded shopkeeper is a `TownPlacements` spot: the module caches ready templates so plots made
after loading swap at once, and plot teardown removes the spot. The client `ShopKeeper` polls
every 0.5 s and binds `RenderStepped` only while a shopkeeper is within 40 studs.

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
goals and `ShelvesScreen`, a minimal owner editor with three-unit selection and carousel controls
and an owned-figure picker. Native nearby prompts route to the existing Display and Shelves screens;
they do not send mutation requests. Exhausted figures remain non-actionable using the existing tile state.
There is no visit directory or teleport callback.
`Onboarding` presents the Welcome Quest from the server-owned `step` (schema 13, shared
`Tutorial` ids): Welcome Box → Display → collect → paid box → free x10, then an optional Shelves
tip. `Rules` advances the stage only from the action each stage teaches (see
[data model](DATA_MODEL.md#welcome-quest-v13)); the client never infers progress from wallet
changes, screen visits or ownership. A quest card shows the current action, progress pips and the
x10 reward; a pulsing gold ring sits on the one control the step needs (dock tiles add a pointer,
in-screen targets a corner badge that survives phone sheets), and the collect step adds a world
pointer and glow on the displayed figure. It never blocks input or sends gameplay intents; two-tap
Skip sends `SkipTutorial`. `ShopScreen` offers the Welcome Box and later the x10 as its primary
"gift" action, `WelcomeReward` is the quest-complete popup, and competing badges, the goal card and
the Daily Login auto-open stay quiet while the quest guides.
`UIStyle`, `UIKit`, `UIButton`, `UIBadge`, `UIProgress`, `UIIcons` and `UIPreview` provide tokens,
primitives, controls, progress, icon shapes and 3D portraits. `UIState` derives read-only
presentation metadata and is the only reader of snapshot economy fields; `UIScope` owns
connections/tweens/timers. A bounded `Notifications` component handles feedback. Claimed daily
goals hide from both HUD variants and show an empty state in Goals; saved claim markers and UTC rollover remain unchanged.

`Scroll.bind` accepts both list and grid layouts and measures content plus padding explicitly.
Nested tile groups report their measured height to the outer list. Filtering and safe-area
resize preserve access to every figure. The client UI is one visual system: `Interface` routes five screens built from shared
components (`ScreenShell`, `Dock`, `Hud`, `CollectionList`, `FigureTile`, `UIButton`) over a
`UIScale` stage. `UIState` is the single projection of snapshot economy fields; `UILayout` owns
geometry; `UIStyle` owns tokens and collection accents. See
[ui-redesign/IMPLEMENTATION.md](ui-redesign/IMPLEMENTATION.md).

Plaza stalls are client presentation over the snapshot's `deals` view. `DealStalls` fills each
stall's slots locally: the skinned production box (native collection box as fallback) on
`Counter.BoxAnchor`, a price tag and sticker panel (client-only parts, outside the world part
budget), the player's own stock pips on `Body.StockPips.Strip` and the countdown on
`ClockTag.ClockFace`, refreshed by one half-second loop from `workspace:GetServerTimeNow()`. Sold
out dims the box, shows the banner and squashes the stall Peeka's eyes shut; a new window shows
NEW! for a minute and the Peeka hops once. `DisplayInteraction` routes the stall prompt to
`DealPopup`, which follows every snapshot (live rollover) and sends only the `Deal` intent.

Sound is client presentation only. `SoundManifest` is the single list of asset IDs and levels.
`Sfx.play(name)` plays pooled, rate-limited voices in `SoundService.Master` (UI / SFX / Reveal)
with saved Sound effects and Music volume sliders in Settings (the `SetVolume` intent, added in schema 12). `Music.play(name)` loops one background track per area or
context (only `world` today) in the Music group, started once on the first ready snapshot. UI components and the existing reply handler call it, and
the opening's cue slots read the same manifest. No remotes, server logic or saved data are
involved. See [game soundpack](SOUND.md).

Opening presentation is separate (the Welcome Box and Welcome x10 use it unchanged): `OpeningResult` derives immutable presentation metadata from
the pre-request and confirmed reply snapshots; `OpeningController` owns one opening session,
input focus, sound timing and teardown. `OpeningState` is a deterministic clock/interaction
state machine. `OpeningCinematic` owns an isolated client-only 3D stage; `OpeningCamera` and
`OpeningScope` restore camera/input/UI on every exit. `OpeningBox` animates the existing production
package with an independent lid pivot and emergency procedural fallback. `OpeningEffects` provides
real particles, comet flight, rarity tease and impact; `OpeningFigure` reuses the awarded figure
factory for silhouette/reveal. `OpeningView` is the responsive overlay, while `OpeningConfig`
and `OpeningAudio` own data-driven presentation and optional licensed sound cues. Buy/Daily
show a box. Retired redemption is rejected. Skipping or interrupting presentation
cannot affect the already-granted item. See [opening behavior and Studio checks](OPENING.md).
No opening-specific remotes or server logic were introduced.

There are no simulated visitor actors. Real players walk into open plots. Players without a plot
spawn on the plaza `SpawnLocation`; once their plot is assigned, every spawn and respawn lands on
their own plot's spawn pad. It does not reset shelves or require visit sessions. Leaving destroys owner content and connections and releases the slot. Visitors remain
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
collection asset keys and palette inputs; `UIState` derives figures, unique progress and
current/base rarity odds from Catalog/snapshots; `UILayout` owns responsive geometry; `BlindBoxPreview`
and `BlindBoxSkin` provide the standardized 3D package and exclusive native fallback. Catalog iteration
creates the carousel and possible-figure entries, so another collection does not require a Shop
layout fork. Buy still uses the existing server-authoritative intent and opening-result path.

## Public/private boundary and rendering

Only owner-labelled geometry, active Display figures/rates and visible shelf figures/Collection signage
are public. Owner state events never go to guests. Each owner gets only three visible Shelf Units with IDs, indexes and local placements,
owned count, carousel revision and navigation availability. The server sends no private balances, inventory, discovery or progression
to visitors. Visitors may turn physical shelf arrows but cannot mutate the owner's saved state.

No per-frame plot or world work is added; the day/night and leaderboard loops are 1-8 second intervals. Static geometry persists for the session. Rendering compares
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
