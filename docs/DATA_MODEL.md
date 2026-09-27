# Persistent data model

Current schema: **4**. Stable `grove.*` and `tide.*` figure IDs and collection discovery are
unchanged. See [canonical direction](PLAYER_PLOTS_AND_SHELVES.md).

| Field | Meaning |
| --- | --- |
| schemaVersion | 4; unsupported versions block loading/writing |
| coins / scrap | Integers in 0..1,000,000,000 / 0..1,000,000 |
| owned | Known figure IDs to positive copy counts; total at most 200 |
| discovered | Known figure IDs to true; permanent; includes every owned ID |
| display | `{unlocked, slots}`: capacity 3..6, dense slot array of that length, empty string or known figure ID |
| shelves | `{pages}`: nonempty ordered page array; no permanent maximum count |
| step | Onboarding stage 1..5 |
| lastDailyDay | Last claimed free-box UTC day or -1 |
| goalDay / goalProgress / goalClaimed | Daily Display goal day, highest distinct count 0..3, claim marker |

Each page is `{id, placements, customization}`. IDs such as `page:1` are stable and unique across
the array. `placements` maps `unit:U/row:R/slot:S` to known permanently discovered figure IDs.
Positive logical coordinates are bounded for safe identifier parsing, independently of the
current geometry counts. Increasing row capacity needs no migration; temporarily hidden saved
slots survive smaller layouts. `customization` must currently be empty; unknown future state is
rejected rather than erased. Real customization requires approved definitions and validation.

Only Display reserves owned copies and earns Coins. Shelf references reserve zero copies and
can repeat across slots/pages, even while the same figure earns in Display. They do not affect
recycling, inventory, bonuses or daily goal checks. Unknown fields, invalid IDs, ineligible
figures, invalid reservations and inconsistent daily state fail closed.

## Deterministic migrations

`Profile.decode` validates v1/v2/v3 directly into a fresh v4 state. It does not mutate its input.
There is no intermediate room unlock/reward pass. Encoding always writes schema 4.

- **v1:** preserve Coins, Scrap, owned/discovered maps, three Display placements and onboarding.
  Add the existing unclaimed daily defaults and one empty shelf page.
- **v2:** preserve all economy, inventory, discovery, Display capacity/placements, onboarding and
  daily fields. Validate then retire legacy `theme`/`themes`; create one empty shelf page.
- **v3:** preserve the existing Display aggregate and all unrelated fields exactly. Validate old
  room IDs/origins, palette ownership, empty customization maps and eligible figure anchors.
  Sort room IDs lexicographically, then read `figure_1` through `figure_6` in numeric order,
  skipping empty anchors. Pack every reference into fresh pages without deduplication or
  overwrite: unit 1 row 1 slots 1..3, then subsequent rows/units, then the next page at reference 28.
  Minimum one page; page IDs are `page:1`, `page:2`, etc. A frozen 3x3x3 migration layout keeps
  conversion deterministic even if future visual configuration changes.
- **v4:** validate/deep-copy existing pages and placements as stored. Do not repack them, grant
  rooms or derive shelf progression from collection completion. Repeated decode/encode is idempotent.

All valid discovered legacy references survive, including duplicates and figures with zero owned
copies. Empty legacy room ownership does not grant pages. Migration pages exist only to retain
placements and imply no price or paid entitlement. Legacy room names/origins/ownership, palette
preference/ownership, per-room themes and empty customization maps are retired: there is no new
equivalent and no refund, paid-page assumption or speculative cosmetic conversion. Unknown
nonempty customization is invalid under the original v3 schema and blocks loading instead of
silently discarding it. Collection completion remains derivable from preserved discovery;
new completion rewards are TBD.

## Storage and runtime boundaries

The existing envelope remains `{data, token, expires, generation, writer}` under `Player_<UserId>`.
Store names, native UpdateAsync leases, generations, retries and pause-on-failure behavior are
unchanged. A failed load never becomes a new profile. Migration is applied within the validated
acquisition/save path. Acknowledgements mean in-memory success; crash rollback affects the entire
last saved aggregate. No offline income. See [operations](OPERATIONS.md).

Mutation revision, accrued fractions/timestamps, request receipts, assigned plot index, world
coordinates, visible shelf page, carousel revision and instances are **not persisted**. A player
may receive any available plot next join; pages always begin visibly at index 1. Owner snapshots
retain the existing flat Display `slots`/`unlocked` UI projection and add one `shelves` view with
page ID/index/count, carousel revision and visible placements. No full shelf-page inventory or
other owner's private profile is broadcast. Old Gallery projections and runtime tokens are gone.

Deploy v4 with a coordinated server replacement. Old v3-only code cannot read new saves; a code
rollback must keep schema-v4 decoding or use an explicitly reviewed recovery process.
