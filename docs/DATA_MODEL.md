# Persistent data model

Current schema: **8**, in the Economy2 namespace. Valid schemas 6 and 7 upgrade (6 with empty
banks; both with `boxesOpened = 0`); schemas 1-5 remain rejected. Existing catalog figure IDs are unchanged.
See [canonical direction](PLAYER_PLOTS_AND_SHELVES.md).

Rarity is catalog metadata, not a persisted player field. `Types.Figure.rarity` uses the closed
shared `Rarity.Id` type: Common, Uncommon, Rare, Legendary or Mythical. Catalog startup rejects
unknown labels. The economy reset introduces permanent duplicates and persisted pity. Figure assignments are unchanged. See [rarity architecture and future content](RARITY.md).

| Field | Meaning |
| --- | --- |
| schemaVersion | 8 written; valid 6/7 upgrade; unsupported versions block loading/writing |
| coins | Integer in 0..1,000,000,000,000; no Scrap field |
| earnings | Owned figure IDs to finite amounts in 0..1,000,000,000,000, including fractional Coins; retained while not displayed |
| pityByGroup | Known active group IDs to integer legendaryDryRolls/mythicalDryRolls, each 0..1,000,000 |
| owned | Known figure IDs to integer counts 1..1,000,000,000 each; no ordinary total-copy cap |
| discovered | Known figure IDs to true; permanent; includes every owned ID |
| display | `{unlocked, slots}`: capacity 3..6, dense slot array of that length, empty string or owned figure ID; nonempty IDs must be unique |
| shelves | `{units, legacyOverflow?}`: ordered persistent Shelf Units; optional dormant migration records |
| step | Onboarding stage 1..5 |
| lastDailyDay | Last claimed free-box UTC day or -1 |
| goalDay / goalProgress / goalClaimed | Daily Display goal day, highest distinct count 0..3, claim marker |
| boxesOpened | Lifetime boxes opened, integer 0..1,000,000,000 (`Rules.boxesOpenedLimit`); presentation only |

Each unit is `{id, placements, customization}`. IDs such as `shelf:1` are stable and unique
within the ordered array. `placements` maps local `row:R/slot:S` keys to known permanently
discovered figure IDs. No physical position or world coordinate is saved. Fresh players own
exactly three units, currently nine positions each. Future acquisition adds individual units;
no acquisition policy, pricing or product-design maximum is defined.

Rows/slots are configured independently of identity. Positive logical coordinates up to
1,000,000 and identifiers up to 64 characters bound parsing. Valid saved local keys outside the
current geometry survive and remain hidden. `customization` belongs to each persistent unit
and must currently be empty; unknown future state fails closed rather than being erased.

Only Display earns Coins; one earning placement per unique owned figure is permitted. Across all
persistent Shelf Units, the count of a figure's placements may not exceed its owned quantity.
Display placement counts independently and does not reduce that Shelf allowance. Shelf references
do not consume inventory or affect duplicate bonuses, income or daily goals. Unknown fields, duplicate unit
IDs, invalid reservations, undiscovered/unknown figures and inconsistent daily state fail closed.

## Decoder resource guards

`Shelves.decodeLimits` bounds one profile to 10,000 owned units, 20,000 stored placements total
(including hidden local keys and dormant records), and 10,000 dormant overflow records. Arrays
must be dense; at least three owned units are required. These are server decoding/allocation
safety guards, **not product-design progression maximums**. Raising them requires storage and
performance review before introducing acquisition. Oversized data blocks loading without a
default reset or truncated save. Legacy inputs are also bounded before allocation.

## Authorized progression reset

The user requested a fresh start. Settings now select `BlindBox_Economy2_Studio` and
`BlindBox_Economy2_Live`. Old namespaces are not read or overwritten, and schemas 1-5 are not
accepted in these new stores. There is no Scrap conversion or legacy progression migration.

A fresh profile has 4,500 Coins, no owned/discovered figures, empty pity, three unlocked Display
slots, three empty Shelf Units and `boxesOpened = 0`. The first three Starter purchases remain fully random.

- **v6 / v7:** no `boxesOpened` field; they decode with `boxesOpened = 0` (a v6/v7 record that
  already contains the field is invalid and blocks loading). Earlier boxes were never counted,
  so no history is reconstructed.
- **v8:** v7 plus the required `boxesOpened` counter. A missing, negative, fractional,
  non-number or over-limit value fails closed; it is never reset to zero.

Schema 6 validates and deep-copies quantities, pity entries, unique Display placements and Shelf
Units. Unknown fields/groups, NaN, infinity, fractional counters, out-of-bounds quantities,
unowned or duplicate Display placements and inconsistent daily claims fail closed. Pity storage
is bounded by the configured group set. Encoding owns copies of both the outer pity map and every
counter record. Schema 7 also validates and deep-copies earnings; fractions now persist inside
each figure's bank. Runtime time/revision/receipts are not persisted. No offline accrual is awarded.

The shelf decoder retains its existing safety guards and optional dormant-reference representation.
After structural validation it reconciles active Shelf Units in array order and numeric row/slot
order. It keeps the earliest placements allowed by `owned`, removes later excess and wholly
unowned placements, and grants nothing. The repair is idempotent and the decoded state is saved
through the ordinary autosave/final-save path; no schema or namespace reset is involved.
The retired legacy adapters are no longer used by the active Profile decoder.

## Storage and runtime boundaries

The envelope remains `{data, token, expires, generation, writer}` under `Player_<UserId>`.
Store names change as described above; native UpdateAsync leases, generations, retries and
pause-on-failure behavior are unchanged. A failed load never becomes a new profile. Only validated
schema-7 snapshots enter the acquisition/save path (valid schema 6 is upgraded first).
Wallet and banks save atomically in one aggregate. Acknowledgements mean in-memory success; crash rollback affects the
entire last saved aggregate. No offline income. See [operations](OPERATIONS.md).

Runtime `View = {startIndex, revision, lastTurn}` starts at index 1 each join. Position P renders
owned index `(startIndex + P - 2) % ownedCount + 1` for P=1..3. Next/Previous changes start by
one with wrapping and a shared 0.5-second cooldown. At most three owned units fixes start/order
at 1 and disables navigation. Mutation revision, timing, receipts, plot assignment, coordinates,
carousel state and instances are **not persisted**.

Owner snapshots add per-collection prices, current/base figure odds and effective/base/next-copy
rates, private per-figure uncollected earnings and `shelfAvailable`, a server-derived remaining
Shelf-copy map that includes hidden units. They include only this public Shelf projection:
`shelves = {ownedCount, visible = {{id, index, placements}, ...}, carouselRevision, canNavigate}`.
Only three units and their configured local slots are projected. Edits require the visible
persistent `shelfId`, local `shelfSlotId`, profile revision, carousel revision and owner/proximity
validation. Visitors receive replicated geometry, never private inventory/discoveries/balances.

## Box counter and leaderboards

`boxesOpened` increments only inside `Rules.mutate`, in the same non-yielding step that spends
Coins (Buy) or records the daily claim (Daily) and grants the rolled figure. Rejected requests and
replayed request IDs never count. It is clamped at its numeric guard and grants nothing; it
exists for the global leaderboard. The global leaderboard OrderedDataStores
(`Settings.liveLeaderboard` / `Settings.studioLeaderboard`, scope = stat key) are a separate,
rebuildable presentation index keyed by UserId string. They are never read back into a profile,
so they cannot corrupt or roll back progress.

Deploy with coordinated server replacement. Rolling back Settings restores the old namespace,
not progress made in Economy2. A rollback that preserves new progress must support schema 8;
older (schema-7) code cannot read v8 saves.
