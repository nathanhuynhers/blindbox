# Persistent data model

The full-game candidate uses quantity stacks keyed by stable `grove.*` / `tide.*` definition
IDs. All copies of a figure are identical. No unique-item identity or trading is implemented.
These IDs must not be reused or renamed without a migration. See [architecture](ARCHITECTURE.md).

## Stored profile (schema version 2)

| Field | Meaning and constraints |
| --- | --- |
| schemaVersion | 2; version 1 has an explicit migration; unknown versions block writes |
| coins, scrap | Integers in 0..1,000,000,000 and 0..1,000,000 respectively |
| owned | Known figure IDs to positive integer quantities; total at most 200 |
| discovered | Known figure IDs to true; all owned IDs must be discovered |
| slots | Dense list of 3 or 4 strings; empty string means unoccupied |
| unlocked | 3 or 4; must match slot-list length |
| step | Onboarding step 1..5 |
| theme | Known equipped palette, present in themes |
| themes | Owned palette IDs to true; default grove is always owned |
| lastDailyDay | Last claimed free-box UTC day index, or -1 |
| goalDay | UTC day index for display goal, or -1 |
| goalProgress | Highest simultaneous distinct display count today, capped at 3 |
| goalClaimed | Boolean; true requires progress 3 |

The `slots`, `unlocked`, `theme`, and `themes` fields above describe the implemented schema, even
though some source and UI names still say room/showroom. Semantically, `slots` are active economic
**Display** slots. They are not Showroom placements.

Every slot reserves one owned copy. For each figure, reservations cannot exceed quantity.
Recycling requires at least two owned copies and one unreserved copy. Replacing/removing changes
reservations only. Discovery is permanent and completion plaques are derived per fixed collection;
there is no consumable plaque grant to duplicate. Every successful acquisition checks capacity
before charging or recording a daily claim. Unknown fields and definitions are rejected rather
than silently dropped. Models/presentation failures never delete owned items.

Version 1 consists of schemaVersion, coins, scrap, owned, discovered, slots and step. Migration
preserves those values, validates three slots, and adds the free palette, three-slot capacity,
and unclaimed daily defaults. Migration operates on a fresh record. The original session-only
MVP wrote no saves, so there is no real MVP progress to import.

## Stored envelope

One key `Player_<UserId>` holds `{data, token, expires, generation, writer}`. `data` is the whole
profile above. `token` owns the current lease (empty after release), `expires` is server UTC
seconds, `generation` advances on committed saves and `writer` identifies the last writer.
UpdateAsync validates the full envelope before mutation. Writer and generation jointly resolve
lost replies without accepting another server's save as our own. Failed reads never mean absent.
A confirmed absent key receives 450 starter Coins exactly once, as part of lease acquisition.

Studio and live use different store names. Preview deliberately bypasses storage and labels
itself unsaved. It is chosen before loading, never used as recovery from a failed live load.
No client can choose storage mode, owner identity, key, lease token or profile contents.

## Runtime and network records

State adds mutation revision, monotonic accrual time and a fractional Coin remainder. They are
not persisted; loading starts the accrual clock now, with no offline income. Transactions own
rate-limit tokens and recent request receipts. Server lifecycle owns legacy main-plot/Display models, character
connections and pending spawn tasks. Storage owns ready/busy flags and renewal deadlines.

Owner snapshots contain owned counts, discovery, slots, balances, progression, public economic
previews, save status and the public main-plot Display directory. A monotonic snapshot sequence orders passive
income updates. Private storage tokens/keys, callbacks and other owners' balances are omitted.
Profiles and snapshot maps are cloned before asynchronous or network boundaries.

## Approved future migration direction

The target direction separates economic Display state from non-economic Showroom state; see
[Display and Showrooms](DISPLAY_AND_SHOWROOMS.md). A later schema version should conceptually own:

- Display capacity from 3 through 6 and its active figure reservations;
- Showroom ownership, themes, figure placement, furniture placement, and featured-room state;
- a deliberate migration for existing palette ownership/equipped state.

The illustrative schema in the canonical design is not authorization to change schema version 2
in place. Existing `slots`/`unlocked` values and palette purchases must remain loadable. Showroom
placements must not contribute to passive income or consume Display capacity. If a physical copy
cannot be reserved by both systems, that reservation rule must be specified and migrated explicitly
before implementation rather than inferred from the planning example.

Normal action replies are not a promise of durable saving. Claim markers and their results share
one snapshot; crash rollback affects them together. Persistence/rollback testing and operating
limits are described in [operations](OPERATIONS.md). Unique variants or transfers require a new
schema and recovery design rather than a second ownership representation.
