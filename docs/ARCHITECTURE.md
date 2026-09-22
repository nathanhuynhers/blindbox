# Proposed architecture

Status: planning only. No modules described here exist yet except the three starter files.
Implement only the authorized [roadmap](ROADMAP.md) task. No framework or dependency is selected.

## Inspected baseline

The repository contains strict startup scripts and `Hello.luau`, with no gameplay. The current
project maps `src/server/init.server.luau` to `ServerScriptService.Server` (Script),
`src/client/init.client.luau` to `StarterPlayer.StarterPlayerScripts.Client` (LocalScript),
and `src/shared` to `ReplicatedStorage.Shared` (Folder). Sibling modules under server/client
become children of those Script/LocalScript roots; entrypoints can require their child modules.
Do not rename init files or silently replace these roots with Folders.

`ReplicatedStorage.Packages` is an explicit Folder with an optional `Packages` path. Wally has
zero dependencies. Pinned tools are Rojo 7.7.0, Wally 0.3.2, StyLua 2.5.2, and Selene 0.31.0.
Selene uses the Roblox standard library; StyLua uses Luau, tabs, Windows line endings, and a
100-column width. VS Code selects StyLua and PATH lookup. No aggregate verification script or
automated gameplay test runner exists. README lists the individual verification commands.

Workspace Baseplate, lighting, filtering, and sound properties remain as configured. Ignored
place builds and sourcemap are derived artifacts, not architecture sources; the inspected
sourcemap and `test.rbxlx` do not include the current Packages mapping. Do not edit or use
them to override `default.project.json`. No tooling changes are needed for this plan.

## Proposed source layout and ownership

This is a destination sketch, not a mandate to create empty modules in advance.

```text
src/server/
  init.server.luau            composition and lifecycle only
  PlayerState.luau            sole owner of state and serialized player mutations
  BoxService.luau             validate price, roll, request acquisition transaction
  InventoryService.luau       grant, reserve, recycle, redeem, discovery rules
  ShowroomService.luau        slots, room lifecycle, placement and counter distance
  IncomeService.luau          elapsed accrual, bank cap, collection
  RemoteRouter.luau           payload validation, rate limits, replies, owner snapshots
  Config/Boxes.luau           authoritative box entries/prices
  Config/Economy.luau         rates, caps, duplicate conversion
  Domain/InventoryRules.luau  pure proposed-state transformations
  Domain/IncomeRules.luau     pure composition/accrual calculations
  Persistence.luau            later milestone only: load/save/migrate boundary
src/client/
  init.client.luau            composition and teardown
  StateController.luau       authoritative snapshot/revision handling
  CollectionController.luau  inventory/index and duplicate actions
  BoxController.luau         purchase intent and skippable reveal
  DisplayController.luau     selection, slot preview, place/remove intent
  VisitorController.luau     bounded cosmetic movement and reactions
  HudController.luau         Coins, Scrap, bank and onboarding prompts
src/shared/
  Types.luau                 strict record and network contract types
  Catalog/Collectibles.luau  public collectible presentation definitions
  Catalog/Collections.luau   public membership and completion labels
  Catalog/Rarities.luau      public tier presentation
```

Keep the starter Hello module until a scoped implementation naturally replaces it. Split a
module further only when a concrete responsibility warrants it. Services are ordinary modules
with explicit dependencies passed at startup, not a service-locator framework. Pure domain
functions receive state/config/time or a supplied roll value and return proposed results/errors;
they do not call remotes or storage. Inject RNG for tests, but production draws only on server.

For MVP, create simple original room/figure geometry through a focused server room builder
owned by ShowroomService. This keeps temporary content reproducible without changing Rojo
mappings or requiring external assets. Publish only public room owner/slot/figure information
in Workspace. A later authored asset task must define its source and mapping explicitly.
Private inventory, bank, and progression stay in server memory, not Workspace attributes.

## State and transaction boundary

PlayerState owns each player's authoritative aggregate. Other modules propose changes through
one per-player serialized transaction boundary; none retains a second writable inventory.
Validate and compute before committing. Balance deduction, item grant, discovery, and revision
advance occur together or not at all. No yielding external calls inside a mutation. Income
updates use the same ordering, preventing collection and accrual from racing.

This is a small in-memory transaction boundary, not a generic database framework. It protects
MVP integrity and gives future saving one coherent aggregate. Only ready sessions accept
economic requests. All modules clean up tasks, connections, request caches, and room instances
on player removal and shutdown. Rejoining creates fresh state only in the explicitly session-only MVP.

## Networking contract

Create a small named remote set under a server-created `ReplicatedStorage.Remotes` Folder
during startup; no Rojo mapping change is required for these runtime objects. Use intent/reply
events and owner-only state snapshots. For six figures and three slots, full sanitized snapshots
on successful mutations are simpler than delta reconciliation. Coalesce bank updates to about
once per second per owner; do not send per-frame or broadcast private player records.

| Intent | Client supplies | Server decides |
| --- | --- | --- |
| RequestState | no economic state | Current sanitized owner snapshot |
| BuyOpenBox | box ID, request ID, expected revision | Price, eligibility, roll, charge, grant |
| PlaceDisplay | slot ID, figure ID, request ID, expected revision | Ownership, capacity, final reservation |
| RemoveDisplay | slot ID, request ID, expected revision | Slot ownership and return to available copies |
| CollectIncome | request ID, expected revision | Own-counter proximity and transferable bank |
| RecycleDuplicate | figure ID, request ID, expected revision | Available extra copy and Scrap yield |
| RedeemFigure | figure ID, request ID, expected revision | Eligibility, Scrap cost, capacity and grant |

Use the callback Player as caller; no client owner ID, price, quantity to grant, arbitrary
Instance, CFrame, payout, RNG seed, or rarity is accepted. One figure/action per mutation bounds
work. Place/collect interactions validate character existence and distance to the player's
server-known shelf/counter. Box/inventory UI actions can operate anywhere in the player's session.

Every handler checks exact payload shape, bounded string lengths, allowlisted IDs, finite integer
revision, ready state, semantic permissions, ownership, cooldown/rate limits, and bounds. Validate
at the remote boundary even if Luau types compile. Initial configurable limits might allow a
burst of four mutations and replenish two per second per player, with a separate tighter state
request limit. Tune for normal input and bound both queued work and rejection logging.

Each valid attempted request uses a bounded request ID and expected mutation revision. Retain
recent outcomes (for example 64 receipts per player for 120 seconds). Identical retries return
the recorded outcome without rerolling or spending; reusing an ID with a different payload is
rejected. Cache lookup precedes revision validation for retries. A committed mutation advances
the revision; passive bank ticks do not, so routine income updates do not invalidate UI intent.
For the same revision, use a monotonically increasing snapshot sequence to order bank updates.
After an evicted receipt, an old committed request's revision is stale and must resync, not
execute again. A client queues one mutation at a time and does not blindly retry unknown
outcomes under a new ID. Session receipts do not promise cross-server exactly-once delivery.

## Authoritative flows

**Buy/open/acquire:** client requests configured box -> server validates caller, revision,
balance, and inventory cap -> production RNG selects from validated entries -> one transaction
deducts Coins, increases the stack, and records discovery -> reply carries result and snapshot
-> client animates that result. A lost reply recovers via the same request receipt/state sync.
The same inventory grant rules serve redemption and later rewards. No grant remote is exposed.

**Inventory:** join sends a sanitized owner snapshot after session readiness. UI derives
available quantities from authoritative slots and totals. Acquisitions, recycles, redemption,
and display edits return an updated snapshot. Clients may preview actions but reconcile to
server truth and discard out-of-order sequences. No successful reveal acknowledgement is needed.

**Display:** select figure and fixed slot -> server validates room ownership, distance and
final reservations -> settle income under the old composition -> commit slot change and new
rate -> update public display models and owner UI. Rendering failure uses a placeholder and
does not delete inventory. Remove/replace do not create new copies.

**Visitors/income:** one bounded server scheduler settles player banks from elapsed time and
validated composition -> owner receives rate/bank and a small public visitor-intensity hint ->
client loops at most two cosmetic waypoint visitors in its own room. Visitors browse/react/leave
without reporting payouts. Suppress visitor earning effects at a full bank or empty display.
Collect at the own-room counter -> settle -> atomically transfer bank to Coins -> reply.
Hidden windows or stalled animation do not change the server rate. Later observers can render
public rooms without receiving their owners' private data. No per-NPC server economic tasks.

## Persistence and future purchases

The MVP uses in-memory state only. Add Persistence in milestone 2 behind explicit load/save/
release operations; do not build interchangeable storage backends or install a library now.
Before external progression testing, design exclusive session ownership, schema migration,
bounded retry/backoff, periodic saves, dirty tracking, leave/shutdown handling, and recovery
tests. Distinguish a successfully absent record from a failed read. Block economic play after
failed/incompatible loads and never overwrite with defaults. See [data model](DATA_MODEL.md).

In-memory atomicity does not guarantee crash durability. Milestone 2 must choose and document
when an operation is acknowledged as durably saved and what recent soft-currency progress can
be lost between saves. Do not promise durable exactly-once rewards from transient receipts.
Trading and paid grants need separately reviewed durable transaction/receipt recovery before
they exist. Library recommendations, if needed later, require evaluation and authorization.

Future monetization can call the same server validation/grant boundary, with a durable purchase
receipt identity and source-specific eligibility. This is an architectural seam, not an MVP
entitlement system. No Robux products, premium RNG, or paid currency now. Review current Roblox
policies and applicable eligibility requirements when a concrete paid-random proposal exists;
this plan makes no policy-compliance claim.

## Verification strategy

Test pure rules with controlled state, roll inputs, and elapsed time: weight boundaries,
invalid catalogs, purchase conservation, insufficient funds/capacity, reservation invariants,
recycling the last/reserved copy, redemption, discovery permanence, diversity math, bank caps,
and rate changes between ticks. Test remote adapters for malformed payloads, wrong owner,
distance failures, stale revisions, replayed IDs, and bounded spam. Prefer deterministic checks
over flaky statistical rarity tests. Adopt a small repository-local test harness in the relevant
implementation task; a new test framework/dependency needs separate authorization.

Use Studio tests for two-client isolation, visual feedback, mobile input, cleanup, frame-rate
independence, and perceived pacing. Later persistence tests must simulate failed loads/saves,
session conflicts, migrations, shutdown, and interrupted grants in an isolated test data scope.
Do not use real player data for fault injection.

Follow existing tool checks and Luau Language Server diagnostics as described in AGENTS.md.
Formatting, lint, and Rojo build cannot establish type correctness, remote security, or fun.
Report checks actually run and leave explicit Studio steps whenever runtime testing is unavailable.
