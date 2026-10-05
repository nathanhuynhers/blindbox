# Persistent data model

Current schema: **13**, in the Economy2 namespace. Valid schemas 6-12 upgrade (6 with empty
banks; 6/7 with `boxesOpened = 0`; 6-8 with empty `shelfRewards`; 6-9 with `lastSeen = 0`, `offlinePending = 0`; 6-10 with an unclaimed login streak; 6-11 with full volume; 6-12 with a mapped Welcome Quest stage, see below); schemas 1-5 remain rejected. Existing catalog figure IDs are unchanged.
See [canonical direction](PLAYER_PLOTS_AND_SHELVES.md).

Rarity is catalog metadata, not a persisted player field. `Types.Figure.rarity` uses the closed
shared `Rarity.Id` type: Common, Uncommon, Rare, Legendary or Mythical. Catalog startup rejects
unknown labels. The economy reset introduces permanent duplicates and persisted pity. Figure assignments are unchanged. See [rarity architecture and future content](RARITY.md).

| Field | Meaning |
| --- | --- |
| schemaVersion | 13 written; valid 6-12 upgrade; unsupported versions block loading/writing |
| coins | Integer in 0..1,000,000,000,000; no Scrap field |
| earnings | Owned figure IDs to finite amounts in 0..1,000,000,000,000, including fractional Coins; retained while not displayed |
| pityByGroup | Known active group IDs to integer legendaryDryRolls/mythicalDryRolls, each 0..1,000,000 |
| owned | Known figure IDs to integer counts 1..1,000,000,000 each; no ordinary total-copy cap |
| discovered | Known figure IDs to true; permanent; includes every owned ID |
| display | `{unlocked, slots}`: capacity 3..6, dense slot array of that length, empty string or owned figure ID; nonempty IDs must be unique |
| shelves | `{units, legacyOverflow?}`: ordered persistent Shelf Units; optional dormant migration records |
| step | Welcome Quest stage 1..7 (shared `Tutorial` ids): 1 Welcome Box, 2 Display, 3 collect, 4 paid box, 5 free x10 waiting, 6 optional Shelves tip, 7 done. Server-advanced only; it is also the one-time claim marker for both Welcome rewards (v13; 1..5 with older meanings before) |
| tutorialHidden | The player skipped Welcome Quest guidance; rewards stay claimable (v13; required) |
| lastDailyDay | Last claimed free-box UTC day or -1 |
| lastLoginDay / loginStreak | Daily Login: last claimed UTC day (-1 never) and the consecutive-day streak it completed (0 only when never claimed); v11, required as a consistent pair |
| goalDay / goalProgress / goalClaimed | Daily Display goal day, highest distinct count 0..3, claim marker |
| boxesOpened | Lifetime boxes opened, integer 0..1,000,000,000 (`Rules.boxesOpenedLimit`); presentation only |
| shelfRewards | Known collection IDs to true: collections whose first completion already granted a free Shelf Unit (v9+; required) |
| lastSeen | UTC `os.time()` of the last save, integer 0..100,000,000,000; 0 = unknown (new or upgraded), awards nothing (v10; required) |
| offlinePending | Whole offline Coins not yet claimed, integer 0..1,000,000,000,000; auto-claimed on the next join (v10; required) |
| sfxVolume / musicVolume | Player audio settings, whole percent 0..100 of the default mix (100 = default); set only by the validated `SetVolume` intent; presentation only (v12; required) |

Each unit is `{id, placements, customization}`. IDs such as `shelf:1` are stable and unique
within the ordered array. `placements` maps local `row:R/slot:S` keys to known permanently
discovered figure IDs. No physical position or world coordinate is saved. Fresh players own
exactly three units, currently nine positions each. Units are added (never removed) by the first
completion of each collection (free, recorded in `shelfRewards`) and by `BuyShelf` purchases, up to
`ShelfConfig.maxShelfUnits` = 100. Owned count is `#units`; no separate count is stored. Decode
re-runs the completion grant, so collections completed before v9 grant their unit once on load.

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
each figure's bank. Runtime time/revision/receipts are not persisted. Offline earnings use only the wall-clock
`lastSeen` and `offlinePending` fields; see [economy](ECONOMY.md#offline-earnings).

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
schema-13 snapshots enter the acquisition/save path (valid schemas 6-12 are upgraded first).
Wallet and banks save atomically in one aggregate. Acknowledgements mean in-memory success; crash rollback affects the
entire last saved aggregate, including `offlinePending` and `lastSeen`. See [operations](OPERATIONS.md).

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
persistent `shelfId`, local `shelfSlotId`, profile revision, carousel revision and validation that
the living owner is inside their own plot. Visitors receive replicated geometry, never private
inventory/discoveries/balances.

## Box counter and leaderboards

`boxesOpened` increments only inside `Rules.mutate`, in the same non-yielding step that spends
Coins (Buy) or records the daily claim (Daily) and grants the rolled figure. Rejected requests and
replayed request IDs never count. It is clamped at its numeric guard and grants nothing; it
exists for the global leaderboard. The global leaderboard OrderedDataStores
(`Settings.liveLeaderboard` / `Settings.studioLeaderboard`, scope = stat key) are a separate,
rebuildable presentation index keyed by UserId string. They are never read back into a profile,
so they cannot corrupt or roll back progress.

Deploy with coordinated server replacement. Rolling back Settings restores the old namespace,
not progress made in Economy2. A rollback that preserves new progress must support schema 13;
older (schema-12) code cannot read v13 saves.

## Daily Login streak (v11)

`Rules` owns the claim (`Login` intent, no payload fields). One claim per server UTC day
(`os.time() // 86400`); a claim the day after `lastLoginDay` continues the streak, any gap
restarts at 1, and a server clock earlier than the last claim refuses. The reward is
`LoginRewards.reward(streak)` from the shared placeholder table (cycle of its entries, so day 8
pays Day 1 again). Coins and any boxes are granted in the same non-yielding step that writes the
marker; a full wallet or box safety limit refuses the whole claim. Box rewards roll, count toward
`boxesOpened`/pity and play the normal opening. v6-v10 decode as never claimed; a v11 record with a
missing, non-integer or inconsistent pair fails closed.

## Welcome Quest (v13)

`step` is the first-session quest stage and the only record of its one-time rewards. `Rules`
advances it from the action each stage teaches: the `Welcome` intent (1→2, a free Pocket Grove box
rolled at Uncommon or better), a Display `Place` (2→3), a genuine server-authorized Display
collection in `Rules.collect` (3→4; Daily Login, goals, offline Coins, Studio grants and other wallet
changes never advance it), any paid `Buy`/`BuyTen` (4→5; the Daily free box does not count), the
`WelcomeTen` intent (5→6, ten free Pocket Grove boxes whose last roll is raised to Rare only when the
first nine had none) and a successful `ShelfPlace` (6→7). Each Welcome intent is accepted only at its
own stage, in the same non-yielding step that grants, counts `boxesOpened` and writes the next stage,
so retries, replays, rejoins and skips cannot repeat a grant. `SkipTutorial` sets
`tutorialHidden`; it hides guidance only and changes no stage or reward. A v13 record with a stage
outside 1..7 or a missing/non-boolean `tutorialHidden` fails closed.

Older stages meant something else and there was no Welcome reward, so a v6-v12 profile that never
opened a box and owns nothing upgrades to stage 1 (it receives the quest and its rewards); every
other upgraded profile becomes stage 7 (finished, no Welcome rewards). Ownership is used only for this
one-time legacy mapping, never to decide a v13 player's progress.
