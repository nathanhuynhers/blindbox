# Player Plot, Shelf Units and Collection implementation

Status: implemented on `master`. This report records the plot/Shelf implementation and its
verification boundaries. The current profile writes schema 13; valid Economy2 schemas 6–12
upgrade, while schemas 1–5 are rejected. See the canonical
[Player Plots, Display and Shelves](PLAYER_PLOTS_AND_SHELVES.md) direction and
[data model](DATA_MODEL.md).

## Current world and plot behavior

**Blindbox Town** places eight open plots around the plaza and Market Street. Direct paths lead
from the plaza to walk-through owner arches and flush spawn pads. Gift-box stacks, Peeka statues,
trees, hedges, lanterns and invisible island boundaries fill the shared world. A server-driven
20-minute day/night cycle switches town lights at dusk and retunes each active plot's existing
Display and Shelf wash lights without adding per-frame work.

The presentation-only global leaderboard rotates Most Figures, Top Coins/sec and Most Boxes
Opened. It grants no rewards and never feeds leaderboard data back into a player profile.
Schema 8 introduced `boxesOpened`; valid schema 6 and 7 upgrades initialize it to zero. The
current written schema and later field additions are in the [data model](DATA_MODEL.md).

Plot ownership, allocation and cleanup remain server-owned. Players spawn on their assigned plot
and visitors walk between plots without a teleport or room session. The owner may open Display or
Shelves management anywhere inside their own plot while alive; visitors and out-of-bounds edits
are rejected. Physical Shelf carousel controls are public browsing controls and do not grant edit
authority.

## Display and Shelf behavior

The Display is the only earning placement system. It begins with three slots and expands
sequentially to six through the current Coin unlocks. A figure ID may earn in only one slot.
Each figure banks its own income until the owner clicks or taps it; the nearby E prompt opens
management rather than collecting. Uncollected banks survive removal and rejoining.

Shelf Units are persistent cosmetic exhibits. The authoritative capacity, viewport, owned-copy
placement rule, navigation and implemented progression rewards are defined in
[Player Plots, Display and Shelves](PLAYER_PLOTS_AND_SHELVES.md). Display placement is independent
of Shelf placement and does not consume a Shelf copy allowance.

The server projects only the visible Shelf Units into the owner snapshot and world. Runtime
carousel state starts from the first unit on join and is not persisted. `FigureSlots` caches
physical figures and replaces only changed IDs or figures whose production model becomes ready.
Plot teardown disconnects owned connections, destroys content and releases the slot.

The Collection installation is a three-bay oak-and-ivory fixture with bounded native parts,
row lighting, a permanent Shelves header and shared physical navigation controls. It is visual
presentation only; Shelf ownership, placement limits and carousel decisions remain server-owned.

## Authority and lifecycle checks

Current implementation and regression coverage verify:

- unique pending and active allocation across eight fixed plot slots, explicit release, spawn
  rebinding on respawn and cleanup when an owner leaves;
- server-computed plot containment, owner-only Display/Shelf mutation and visitor rejection;
- Shelf placement bounded by owned copies across visible and offscreen units, including stable
  repair of over-placed valid Economy2 records without granting inventory;
- carousel wrapping, disabled navigation at the starting capacity, stale revision rejection and
  bounded snapshot/world projection;
- Display capacities, figure caching, targeted updates and teardown without unbounded tasks,
  connections, lights or instances;
- exact world part/light budgets, dusk/dawn switching, plot fixture geometry and leaderboard
  throttling, backoff and last-good reads; and
- malformed payloads, replayed requests, rate limits, persistence failures and profile isolation.

Recorded native Studio MCP property checks covered real Instances for plot containment, Shelf
ownership rejection, carousel revision behavior, Display expansion, fixture lighting transitions
and cleanup. Those checks are evidence for those specific properties only; they do not replace
subjective rendering, true-touch, device-performance, DataStore rejoin or multi-client acceptance.

## Remaining manual acceptance

1. In a private multi-client Studio session, confirm unique plots, correct spawns and owner signs.
   Walk between plots, browse another player's Shelves and attempt every Display/Shelf edit as a
   visitor and from just outside the owner boundary.
2. Check mouse, touch and gamepad management from the rear, center and corners of the owner's plot.
   Verify edits reject immediately outside the horizontal footprint or vertical bound.
3. Exercise Display capacities 3–6 and repeated Shelf turns through day and night. Confirm figures
   remain readable, navigation wraps correctly, and respawn/leave/rejoin does not add lights,
   figures, connections or stale owner content.
4. In an isolated persistent test experience, save/rejoin current schema-13 Shelf placements,
   carousel-independent state, Display placements, earnings banks and `boxesOpened`. Load valid
   schema-6 through schema-12 Economy2 fixtures and confirm the
   [documented upgrade paths](DATA_MODEL.md#authorized-progression-reset).
5. Load an intentionally over-placed valid Economy2 Shelf record. Confirm the earliest allowed placements
   survive, unrelated progress is unchanged, and the repaired state remains after autosave/rejoin.
6. Check the Collection fixture, awnings, arches, trees, statues, leaderboard and day/night lighting
   on representative desktop and mobile devices, including an eight-player populated-server soak.

No build, lint, type analysis or Studio playtest was performed as part of this documentation-only
cleanup.
