# Persistent data model

The candidate uses schema **3**, with explicit v1/v2 migration. Stable figure and collection IDs
are unchanged. See [migration details and examples](DISPLAY_SHOWROOM_IMPLEMENTATION.md).

## Stored profile

| Field | Meaning and constraints |
| --- | --- |
| schemaVersion | 3; unknown versions fail closed |
| coins, scrap | Integers in 0..1,000,000,000 and 0..1,000,000 |
| owned | Known figure IDs to positive quantities; at most 200 physical copies |
| discovered | Known figure IDs to true; all owned IDs must be discovered; permanent |
| display | `{unlocked, slots}`; capacity 3..6; dense slot list of that length |
| showrooms | `{rooms, palette, palettes}`; separate cosmetic state |
| step | Onboarding step 1..5 |
| lastDailyDay | Last free-box UTC day, or -1 |
| goalDay | Daily Display goal UTC day, or -1 |
| goalProgress | Highest simultaneous distinct Display count today, capped at 3 |
| goalClaimed | Boolean; true requires progress 3 |

Display slots contain a known figure ID or empty string. Each occupied slot reserves one owned
copy. Reservations cannot exceed quantities. Recycling requires two owned copies and a free copy.
Capacity is sequential; extra-slot method configuration is separate, with only legacy slot 4
currently purchasable. Slots 5/6 have no acquisition flow or price.

`showrooms.rooms` is a map of stable room IDs to these records:

| Room field | Meaning |
| --- | --- |
| roomId | Same stable ID as map key; independent of visible name/position |
| sourceType | Collection or Custom |
| sourceCollectionId | Catalog collection ID for Collection; absent for Custom |
| theme | Owned palette ID; applied only to this room |
| placements | Stable configured anchor ID -> permanently discovered figure ID |
| customization | Empty extension map until approved decor definitions/validation exist |

Catalog explicitly maps `grove` to `collection:grove` and `tide` to `collection:tide`. Collection
rooms require complete discovery. Custom identities use `custom:<opaque-id>`; the model supports
them but no acquisition endpoint exists. There is no four-room ownership cap. Current runtime
halls page six entrances at a time. Room coordinates/generations/instances are never saved.

**Showroom placements reserve zero copies and produce zero income.** The same discovered figure
may appear in multiple anchors/rooms and Display, including cross-collection cosmetic placement.
Inventory-only and Showroom figures never enter rate, bonus, reservation or daily Display checks.

`showrooms.palette` preserves the legacy equipped palette as a default for future earned rooms.
`showrooms.palettes` preserves all legacy owned palettes, including the required free `grove`.
Per-room palette changes use existing owned IDs; new palette purchases are retired. Unknown
fields/definitions, invalid reservations, unowned themes and ineligible placements block loading
and saving instead of silently deleting data. Nested snapshots are explicitly copied.

## Historical schemas and migration

Version 1 contained schemaVersion, coins, scrap, owned, discovered, slots and step, with three
slots. Decode preserves these facts and adds the free palette/capacity/daily defaults.

Version 2 added unlocked (3..4), theme, themes, lastDailyDay, goalDay, goalProgress and goalClaimed.
Decode moves slots/unlocked under Display and theme/themes under Showrooms. All economy,
inventory, discovery, onboarding and daily facts survive unchanged. Both migrations reconcile
completed collections into stable room IDs, using the saved palette preference. No manual claim,
extra currency, inventory reservation or duplicate room grant occurs.

Version 3 validates both aggregates and reconciles missing earned rooms on load. Reconciliation
never replaces an existing room. Migration works on fresh tables, is deterministic/idempotent,
and preserves the original input. The original session-only MVP had no real saved profiles.

## Stored envelope and runtime

The unchanged `Player_<UserId>` envelope is `{data, token, expires, generation, writer}`. Native
UpdateAsync validates the entire envelope/profile before every acquisition/write. Token and
generation protect exclusive session ownership and reconcile uncertain commits. Failed loads
never create fallback data. Store names and Studio/live isolation are unchanged; see
[operations](OPERATIONS.md). Replace old server writers when deploying schema 3.

State adds mutation revision, monotonic accrual time and fractional Coins; these are not saved.
No offline income is granted. Transactions own token-bucket state and bounded replay receipts.
Gallery membership, actor/owner identity, room lifetime tokens, allocation cells, connections and
Workspace models are temporary server state, independent of persistent room identity.

Owner snapshots retain flat `slots`/`unlocked` presentation fields for the existing Collection/
Shop/opening clients; those values project only Display. Snapshot `theme`/`themes` project the
owner's Showroom palette preference/ownership for compatibility, not Display cosmetics.
`rooms` remains the same-server public main-plot directory. Optional `gallery` contains only the
visited owner's public identity, current cosmetic room, visible room labels, runtime token and
server-derived edit permission. Guests never receive the host's balance, inventory, discoveries,
palette ownership, progression or storage/session secrets. Their own private snapshot is separate.

Acknowledgements confirm in-memory results, not durable saving. Whole-profile snapshots include
both aggregates; crash rollback affects them together. Existing lease, pause/retry and final-save
guarantees remain as documented in operations. No new external persistence system was added.
