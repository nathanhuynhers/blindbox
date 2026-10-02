# Persistent data model

Current schema: **6**. Stable `grove.*` and `tide.*` figure IDs and discovery are unchanged.
See [canonical direction](PLAYER_PLOTS_AND_SHELVES.md).

Rarity is catalog metadata, not a persisted player field. `Types.Figure.rarity` uses the closed
shared `Rarity.Id` type: Common, Uncommon, Rare, Legendary or Mythical. Catalog startup rejects
unknown labels. Five-tier support needs no schema migration; existing figure IDs and assignments
are unchanged. See [rarity architecture and future content](RARITY.md).

| Field | Meaning |
| --- | --- |
| schemaVersion | 6; unsupported versions block loading/writing |
| coins / scrap | Integers in 0..1,000,000,000 / 0..1,000,000 |
| owned | Known figure IDs to positive copy counts; total at most 200 |
| discovered | Known figure IDs to true; permanent; includes every owned ID |
| display | `{unlocked, slots}`: capacity 3..6, dense slot array of that length, empty string or known figure ID |
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

Only Display reserves owned copies and earns Coins. Shelf references reserve zero copies and
may repeat across units, even while the same figure earns in Display or has zero owned copies.
They do not affect recycling, inventory, bonuses or daily goals. Unknown fields, duplicate unit
IDs, invalid reservations, undiscovered/unknown figures and inconsistent daily state fail closed.

## Decoder resource guards

`Shelves.decodeLimits` bounds one profile to 10,000 owned units, 20,000 stored placements total
(including hidden local keys and dormant records), and 10,000 dormant overflow records. Arrays
must be dense; at least three owned units are required. These are server decoding/allocation
safety guards, **not product-design progression maximums**. Raising them requires storage and
performance review before introducing acquisition. Oversized data blocks loading without a
default reset or truncated save. Legacy inputs are also bounded before allocation.

## Deterministic migrations

`Profile.decode` validates v1-v6 into canonical Shelf Units without mutating the input. Encoding
always writes v6. All valid unrelated fields retain their existing validation and values.

- **v1:** preserve Coins, Scrap, ownership/discovery, three Display placements and onboarding;
  add the existing unclaimed daily defaults and three empty Shelf Units.
- **v2:** preserve economy, inventory, discovery, Display capacity/placements, onboarding and
  daily state. Validate then retire old `theme`/`themes`; create three empty Shelf Units.
- **v3:** validate old room IDs/origins, palette ownership, empty customization and eligible
  anchors. Sort room IDs lexicographically, then read `figure_1` through `figure_6` numerically,
  skipping empty anchors. Preserve duplicates and zero-copy discoveries. The decode-only
  `LegacyCosmetics` adapter retains the proven frozen packing order into the **retired v4
  representation** (27 references per legacy page, at least one); `LegacyShelfPages` immediately
  converts that representation to units. Thus 42 references become six units with the same order
  and trailing empty capacity. No room runtime, unlock pass or completion grant is restored.
- **v4 (retired Shelf Page model):** each old `shelves.pages[]` entry becomes **exactly three**
  Shelf Units, including empty ones. In source array order, page index P and logical unit U in
  1..3 map to new unit index `(P-1)*3+U`, ID `shelf:<index>`. Old
  `unit:U/row:R/slot:S` becomes local `row:R/slot:S`. One page becomes three units; two become six.
  No repacking, deduplication, new purchase entitlement or loss of empty capacity occurs.
- **v5:** validate and deep-copy the ordered units and optional dormant records. Repeated
  decode/encode round trips preserve IDs, contents, customization hooks and unrelated progress.
  v5 has no `boxesOpened` field; it decodes with `boxesOpened = 0` (a v5 record that already
  contains the field is invalid and blocks loading).
- **v6:** v5 plus the required `boxesOpened` counter. A missing, negative, fractional,
  non-number or over-limit value fails closed; it is never reset to zero. Every v1-v5 player
  starts at 0 because earlier boxes were never counted; no history is reconstructed.

The retired v4 decoder allowed logical unit numbers above 3, which had no visible furniture.
Per the user's migration choice, these references survive as optional dormant records:
`legacyOverflow = {{sourceId = "page:old", logicalUnit = 4, placements = {...}}}`. Entries use
local row/slot keys, preserve the retired source ID, and are ordered by source array position
then logical unit number. Source/unit pairs must be unique and placements nonempty/eligible.
They grant no additional units and are never rendered, edited, counted as capacity or projected
to clients. They remain deep-copied through saves for future explicit recovery.

Legacy room names/origins/ownership, palette preference/ownership and empty old customization
have no new equivalent and are retired without refunds or speculative cosmetic conversion.
Unknown nonempty customization was invalid under the old schemas and still blocks loading.
Empty v3 rooms grant no extra capacity. Completion remains derivable from discoveries; new
completion rewards remain TBD.

## Storage and runtime boundaries

The envelope remains `{data, token, expires, generation, writer}` under `Player_<UserId>`.
Store names, native UpdateAsync leases, generations, retries and pause-on-failure behavior are
unchanged. A failed load never becomes a new profile. Migration runs within the validated
acquisition/save path. Acknowledgements mean in-memory success; crash rollback affects the
entire last saved aggregate. No offline income. See [operations](OPERATIONS.md).

Runtime `View = {startIndex, revision, lastTurn}` starts at index 1 each join. Position P renders
owned index `(startIndex + P - 2) % ownedCount + 1` for P=1..3. Next/Previous changes start by
one with wrapping and a shared 0.5-second cooldown. At most three owned units fixes start/order
at 1 and disables navigation. Mutation revision, timing, receipts, plot assignment, coordinates,
carousel state and instances are **not persisted**.

Owner snapshots retain the existing flat Display projection and include only
`shelves = {ownedCount, visible = {{id, index, placements}, ...}, carouselRevision, canNavigate}`.
Only three units and their configured local slots are projected. Edits require the visible
persistent `shelfId`, local `shelfSlotId`, profile revision, carousel revision and owner/proximity
validation. Visitors receive replicated geometry, never private inventory/discoveries/balances.

## Box counter and leaderboards

`boxesOpened` increments only inside `Rules.mutate`, in the same non-yielding step that spends
Coins (Buy) or records the daily claim (Daily) and grants the rolled figure. Rejected requests,
Scrap redemptions and replayed request IDs never count. It is clamped at its numeric guard and
grants nothing; it exists for the global leaderboard. The global leaderboard OrderedDataStores
(`Settings.liveLeaderboard` / `Settings.studioLeaderboard`, scope = stat key) are a separate, rebuildable presentation index keyed by UserId
string. They are never read back into a profile, so they cannot corrupt or roll back progress.

Deploy v6 with coordinated server replacement. Older code cannot read v6 saves; rollback must
retain v6 decoding or use an explicitly reviewed recovery process. A parallel economy redesign
that also bumps the schema must be merged onto v6 (as v7), not renumbered.
