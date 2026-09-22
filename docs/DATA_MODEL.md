# Conceptual data model

Status: design sketch, not executable Luau or a persistence implementation. Field names below
define proposed boundaries; do not generate all types or unused fields before a scoped task.
[Architecture](ARCHITECTURE.md) owns behavior; [economy](ECONOMY.md) owns tuning.

## Identity and inventory decision

Use **quantity stacks keyed by collectible definition ID** for the MVP. All copies of a figure
are identical. This keeps UI, placement, and recycling small without pretending to support
individual provenance. `OwnedCollectible` means a stack record in this version, not a unique toy.

| Representation | Benefit | Cost / limitation |
| --- | --- | --- |
| Quantities | Small state, simple duplicate accounting | No per-copy history, variants, or unique trades |
| Unique instances | Natural serials, variants, item history | More IDs, records, indexing, transfer and lifecycle rules |
| Hybrid | Stack ordinary copies, identify special ones | Two ownership paths and more placement/transfer cases |

Choose quantities now; defer hybrid until there is an actual mixed use case. Before trading or
per-copy variants, migrate all existing copies to individual records, rather than adding a
second ownership truth. The owner is the enclosing server player profile; clients do not supply
or edit ownership information. Display models never prove ownership.

Stable IDs use lowercase namespaced strings, for example `collection.prototype_01`,
`figure.prototype_01.a`, `rarity.tier_a`, `box.prototype_01`, and `slot.shelf_01.01`.
These are placeholder identifiers, not final art names. Never key saves by localized display
names, array ordering, asset URLs, or Roblox Instances. Retire IDs instead of reusing them;
maintain explicit aliases/migrations for legitimate renames. User IDs identify profile owners.

## Definition records

Notation: `string`, `number`, and `boolean` are Luau-like scalar types; `{T}` is a list;
`{[string]: T}` is an ID map; `T?` is optional. Semantic integers must be checked explicitly.

| Record | Proposed fields | Constraints / visibility |
| --- | --- | --- |
| CollectibleDefinition | `id: string`, `displayName: string`, `collectionId: string`, `rarityId: string`, `modelKey: string` | Public presentation; references must resolve |
| CollectibleEconomyDefinition | `collectibleId: string`, `baseCoinsPerMinute: number` | Server config; publish a read-only preview as needed |
| CollectionDefinition | `id: string`, `displayName: string`, `collectibleIds: {string}`, `completionRewardKey: string` | Public; no repeated IDs; MVP reward is index stamp |
| RarityDefinition | `id: string`, `displayName: string`, `sortOrder: number`, `presentationKey: string` | Public; no hardcoded number of tiers |
| BoxDefinition | `id: string`, `coinCost: number`, `entries: {{collectibleId: string, weight: number}}` | Server authoritative; sanitized odds/prices visible before purchase |
| DisplaySlotDefinition | `id: string`, `shelfId: string`, `unlockLevel: number`, `anchorKey: string` | Server validates room template; clients may see anchors |

Rarity does not itself confer ownership or mandate income. Keeping income in server config
permits tuning without changing catalog identity. Asset keys resolve through an allowlisted
presentation catalog, not arbitrary client-supplied asset IDs. Public definitions are visible
to exploiters, including unknown figure names; collection-book concealment is a UX choice,
not a secrecy guarantee. Keep economy rules, RNG, and authoritative state server-only.

## Player and runtime records

| Concept | Proposed fields | Invariants |
| --- | --- | --- |
| OwnedCollectible | `collectibleId: string`, `quantity: number` | Positive finite integer; key agrees with ID; omit zero stacks |
| Inventory | `stacks: {[string]: OwnedCollectible}` | MVP sum of quantities <= 200 |
| Currencies | `coins: number`, `scrap: number` | Nonnegative bounded integers |
| DisplaySlot | `slotId: string`, `collectibleId: string?` | Nil means empty; occupied slot reserves one owned copy |
| ShowroomState | `layoutId: string`, `expansionLevel: number`, `slots: {[string]: DisplaySlot}`, `bankCoins: number` | MVP fixed layout, level 0, three known slots, bank <= 75 |
| Progression | `onboardingStep: string` | Allowlisted step; server advances only on successful actions |
| Settings | `musicEnabled: boolean`, `effectsEnabled: boolean` | Planned persistent preferences; no MVP settings screen required |
| PlayerData | `schemaVersion: number`, `inventory: Inventory`, `currencies: Currencies`, `discovered: {[string]: boolean}`, `showroom: ShowroomState`, `progression: Progression`, `settings: Settings` | One authoritative aggregate per player |
| PlayerSession (not saved) | owner UserId, data, revision, load status, last accrual time, fractional Coins, bounded request receipts, rate limits, owned cleanup handles | Ready state required for mutations; private to server |

For every figure: `reserved = number of slots referencing its ID`; `available = quantity -
reserved`; require `0 <= reserved <= quantity`. Placement changes reservations only. Replacing
a slot validates the final assignment as one transaction, so no intermediate invalid state is
observable. Placing the same figure in the same slot is a no-op. Recycling requires quantity
>= 2 and available >= 1. Redemption/purchase checks total capacity before spending.

Discovery is monotonic: rolling or redeeming sets `discovered[id] = true`; removal does not
erase it. Completion percentage is discovered members / members in that collection, not
currently owned quantity. Freeze published collection membership; use a new collection for
new waves so earned completion does not disappear. The MVP stamp is derived from discovery.
Later consumable completion rewards need separate recorded claims and atomic grants.

Runtime revision is for ordering state updates and rejecting stale client intent; it is not a
persistent economic counter. Persist facts only. Do not save computed rates, displayed models,
visitor positions, Roblox Instances, connections, temporary request receipts, or reveal state.
Additional future fields such as daily claims, unlocked cosmetics, and item-instance records
require explicit schema changes rather than an untyped catch-all metadata bag.

## Defaults and validation

A genuinely new profile starts at schema version 1 with 75 Coins, zero Scrap, empty inventory
and discovery, level 0, three empty slots, zero bank, and the first onboarding step. During the
session-only MVP these defaults are recreated on join and never saved. When saving is added,
grant them only after a successful load confirms no existing profile; never on load failure.

Validate known schema, map/list sizes, string lengths, finite bounded numbers, integer counts,
catalog references, slot IDs, discovery booleans, and ownership reservations. Choose generous
explicit currency safety ceilings before persistence; these are numeric safety bounds, not
balance targets. Reject operations that exceed them rather than silently lose earned value.
Definition retirement must preserve old inventory through a tombstone/alias policy. Unknown
definitions from incompatible content should prevent unsafe mutations and trigger recovery,
not deletion. A missing display asset can use a fallback model without changing ownership.

Missing optional fields may receive version-specific defaults through migration. Invalid
currency, inventory, incompatible future schema, or malformed required fields must not be
silently replaced and saved as an empty profile. Preserve the original payload for a restricted
recovery path; block economic play when safe state cannot be established. A repairable display
reference can be removed by an explicit logged migration while retaining inventory.

## Versioning and future item identity

Use ordered migrations from version N to N+1, operating on copies and validating each result.
Keep migration fixtures, deterministic transformations, and a recoverable previous record.
Migration failure or a newer unsupported schema blocks writes. A failed save never licenses
loading defaults over valid data. No persistence library is selected or installed.

For a later unique-item migration:

1. Exclusively load the old profile and record the source schema/identity migration version.
2. For each quantity Q, generate Q stable owner-scoped item IDs from the profile key, migration
   version, definition ID, and copy ordinal. Retrying the same input must produce the same IDs.
3. Build `itemsById` records with definition ID and explicit variant fields only when needed;
   point occupied slots to different generated item IDs in stable slot order.
4. Check total counts and discoveries are unchanged, then commit the new schema as one profile
   update. Do not enable old and new ownership representations concurrently.
5. Use globally unique server-issued IDs for new acquisitions thereafter; future transfers keep
   item IDs but change the owning profile through a separately designed recovery protocol.

Before trading, add provenance/audit and cross-profile transfer reconciliation. A per-player
atomic update alone cannot guarantee a safe two-player trade. This migration path preserves
today's progress without building that system into the MVP.
