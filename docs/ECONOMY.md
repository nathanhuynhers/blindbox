# Collection economy

Implemented and merged into `master`; native Studio acceptance remains pending. The historical
[redesign plan](archive/RARITY_ECONOMY_REDESIGN.md) records the discussion. This document and the
server configuration are the current tuning reference. All prices, grants, odds, owned quantities,
pity and income calculations remain server-owned.

## Collection tiers and base income

| Tier | Collections | Box price | Expected-figure payback seconds |
| --- | --- | ---: | ---: |
| Starter | Pocket Grove | 1,500 | 180 |
| Near-starter | Tidepool Tales | 2,000 | 180 |
| Niche | Concepts | 20,000 | 550 |
| Prestige | Tender Echoes; We Are All Stars | 200,000 | 850 |

Expected-figure payback is a normalization parameter, not actual time per box. Strongest-figure
selection, duplicates, themed bonuses and additional slots accelerate actual income. The user
requested roughly 4-6 hours to the first Mythical after entering a new tier, so Niche/Prestige
no longer use the original uniform 180-second draft.

Each figure has explicit positive `units` and a within-rarity `weight` in server
`Economy.entries`. For its collection:

```text
expectedUnits = sum(base bucket probability * within-bucket share * figure units)
baseRate = figure units * box price / (paybackSeconds * expectedUnits)
```

The expected units are 1.065 for the two starter collections and 1.219 for the three five-tier
collections. All figures at one tier use the same economic scale when their weighted units agree.
Tender Echoes and We Are All Stars have matching rosters, unit values, prices and income scales.

| Rarity | Explicit income units |
| --- | --- |
| Common | 0.55-0.70 |
| Uncommon | 1.20-1.40 |
| Rare | 2.80-3.20 |
| Legendary | 7.50-8.50 |
| Mythical | 22 |

See [collection onboarding](ECONOMY_COLLECTION_ONBOARDING.md) for adding new collections and tiers.

## Rarity selection and increasing-chance pity

Five-tier base buckets are Common 60%, Uncommon 25%, Rare 13.9%, Legendary 1%, Mythical 0.1%.
Three-tier starter buckets are Common 60%, Uncommon 30%, Rare 10%. Equal within-rarity weights are
used today, so a Prestige Legendary is 0.5% per individual figure at base odds.

For the next box, where dry counts mean prior successful openings without that specific rarity:

```text
Legendary percent = min(8, 1 + max(0, legendaryDryRolls - 40) * 0.05)
Mythical percent  = min(2, 0.1 + max(0, mythicalDryRolls - 300) * 0.0015)
```

These are percentage-point increments. No hard guarantee exists. A Legendary resets only the
Legendary counter; a Mythical resets only the Mythical counter. Other counters advance once per
successful box. At one million dry rolls counters saturate; odds already reached their caps much
earlier. Common/Uncommon/Rare absorb added high-tier probability proportionally.

One server random value selects one figure from the final distribution. The Shop shows current
rarity totals and base values when pity increases them; figure details show individual current odds.
Counters remain private, persist per pity group and do not advance on failed purchases or replayed
requests. Each current high-tier collection has its own group. Starter collections have no pity
for absent rarities. Shared groups require identical economic tier, bucket and pity profiles.

## Permanent duplicates and Display income

Scrap, recycling and redemption are removed. All copies remain owned. Quantity storage is one
integer per figure ID, with a one-billion-per-figure safety guard and no ordinary total-copy limit.
If any figure in a requested collection is at that safety guard, opening is refused before spending
or rolling; the server never substitutes a different result.

```text
extra = max(0, owned - 1)
multiplier = 1 + maximumBonus * extra / (extra + curve)
effectiveRate = baseRate * multiplier
```

| Rarity | First duplicate | Asymptotic maximum bonus | Curve |
| --- | ---: | ---: | ---: |
| Common | +10% | +60% | 5 |
| Uncommon | +15% | +90% | 5 |
| Rare | +25% | +125% | 4 |
| Legendary | +50% | +150% | 2 |
| Mythical | +100% | +300% | 2 |

Only one instance of each figure ID may earn in Display. Three slots start unlocked; slots 4, 5
and 6 cost 40,000, 400,000 and 4,000,000 Coins, respectively, purchased sequentially. Inventory-only
figures earn zero. Shelves remain cosmetic, reserve zero copies and may repeat discoveries.

Displaying three distinct figures from one collection grants +10% of the total effective Display
rate, once only. This also applies to mixed-tier Displays that contain a qualifying trio.

The strongest fully enhanced lower rarity remains below the weakest unenhanced next rarity
within each collection. Cross-economic-tier comparisons intentionally differ: an earlier Mythical
can help finance a later box and may out-earn its early pulls.

Transactions settle elapsed time at the previous rate before changing inventory or placement.
Each displayed figure banks its own income, including fractional Coins and its proportional
share of the themed bonus. Coins enter the wallet only when the owner clicks or taps that
individual figure. E nearby opens Display management only. Shelves cannot collect or generate income.
Uncollected balances persist per figure ID even when removed or replaced; redisplay to collect.
Each bank has a one-trillion-Coin safety ceiling. Collection transfers only whole Coins that fit
in the wallet, retaining fractions and overflow. No ordinary bank timer/cap exists; offline earnings are separate (below).
Duplicate copies enhance one bank's earning rate, not multiple collection targets.

The server checks exact-target proximity (12 studs), living character, ownership, session readiness
and rate limits. Clients cannot supply collection amounts or authorize collection through remotes.
Auto-collect is a future gamepass: the shared server transfer primitive is ready for reuse, but no
entitlement checks, product IDs, purchase prompts or automatic collection are enabled yet.

## Offline earnings

Displayed figures keep earning while their owner is offline, Coin only. Server `Economy` tuning:
`offlineRate = 0.5` (fraction of the full online Display rate, including duplicates and the set
bonus), `offlineMaxSeconds = 6 h` (accrual cap) and `offlineMinSeconds = 60` (shorter absences,
such as server hops, award nothing). Every save stamps `lastSeen = os.time()`. On join, after the
lease is acquired, `Rules.offline` first auto-claims any `offlinePending` left from the previous
visit, then sets `offlinePending = floor(rate * min(now - lastSeen, cap) * offlineRate)` from the
saved Display. An unknown `lastSeen` (0) or a clock behind it awards nothing.

The client shows a welcome-back popup with the amount and absence; Claim or tapping outside sends
the `ClaimOffline` intent through the normal transaction path (token bucket, revision, receipts).
The client never supplies an amount. Claiming zeroes the pending amount in the same aggregate as
the wallet, so replays and second claims pay nothing; anything above the Coin limit is dropped.
Robux multipliers and paid boosts are not implemented.

## Starting and daily progression

New profiles receive 4,500 Coins once. The first three purchases use normal random odds; distinct
starters are not guaranteed. A duplicate-only start has one enhanced earning figure rather than
three earning copies. One free Pocket Grove box is available per UTC day. Other boxes cannot be
claimed free. The daily goal grants 1,000 Coins for displaying three distinct figures simultaneously.
The separate consecutive Daily Login reward pays one entry of `src/shared/LoginRewards.luau` per UTC
day (placeholder values: 500 / 1,000 Coins / one Grove box / 2,500 / 1,000 + one Tidepool box /
4,000 / 5,000 + one Concepts box), loops after Day 7 and restarts at Day 1 after a missed day.

After a successful claim, the daily goal disappears from the active HUD; the Goals screen shows
that no daily goals remain. Claim markers and grants are one profile aggregate. Existing
clock-rollback, storage-failure and session-exclusion rules remain. See [data model](DATA_MODEL.md).

## Fresh-save rollout and verification

The user explicitly requested a full progression reset. The new stores are
`BlindBox_Economy2_Studio` and `BlindBox_Economy2_Live`, now with schema 8. No old Coins, Scrap,
figures, discoveries, shelves or progress are imported. Old stores are untouched rollback backups;
no live store was deleted or published by this implementation. Unexpected old or corrupt data in
the new namespace fails closed rather than becoming a fresh profile. Valid schema-6 Economy2
profiles upgrade with empty earnings banks; valid schema-7 profiles retain their banks. Both
upgrade to schema 8 with `boxesOpened = 0`; schemas 1–5 remain rejected.

The verification record below captures automated checks and simulation assumptions. Native Studio,
real save/rejoin and multi-client playtests remain required.

## Verification record and acceptance checklist

The implementation checks covered weighted income, total probabilities, pity increments, caps and
independent resets, collection isolation, retry/failure atomicity, duplicate-only starts, numeric
guards, income settlement, unique placement, daily restrictions, malformed payloads and mixed
transactions. Persistence checks covered quantity/pity/bank round trips, deep copies, unsupported
schemas, corrupt values, competing sessions, leases, failed saves, lost replies and starter-grant
idempotency. Manual-collection checks covered bank/wallet conservation, proportional bonuses,
fractions, schema upgrades, full-wallet transfers, removed/redisplayed figures, remote rejection,
distance, character state, empty slots and teardown. These checks ran in the Luau engine shim, not
Roblox Studio.

The reproducible pacing simulation runs after the domain harness has generated its isolated modules:

```powershell
build/tools/luau/luau.exe tests/EconomySimulation.luau
```

Its 300 seeded runs use the actual Rules and CollectionEconomy modules, select the strongest Display,
consider themed trios and buy useful sequential slots. The simulation assumes instant collection and
excludes daily rewards, reveal/menu time, offline time and activity rewards, so it is an idealized
online earning baseline rather than engagement evidence or a guaranteed player outcome.

Remaining native Studio acceptance:

1. Start fresh with 4,500 Coins, three slots and no Scrap; buy three fully random Starter boxes.
   Include a duplicate-heavy run and confirm one enhanced figure can fund continued play.
2. Verify all five collection prices, matching Tender Echoes/We Are All Stars rates, boosted Shop
   odds, and details showing count, base/effective income, duplicate percentage and next-copy income.
3. Confirm no figure occupies two earning slots; cosmetic Shelves may repeat it within owned-copy
   limits. Buy slots 4, 5 and 6 in order and check layout, affordability and refreshed price.
4. Confirm duplicate grants settle prior income first, update income promptly and preserve quantity.
   Skip and retry reveals without extra grants.
5. Click or tap each occupied slot, including slots 4-6, and test the E management prompt. The wallet
   must remain unchanged while idle; only the selected figure's bank transfers. Cover feedback,
   visitors, dead characters, distance rejection, respawn, teardown and concurrent interactions.
6. Remove or replace an earning figure, save/rejoin, then redisplay it and confirm its bank remains.
   In isolated persistent Studio testing, verify schema-6 and schema-7 upgrades, Economy2 store
   identity, pity/duplicate round trips, UTC claims and pause-on-storage-failure; see offline checks below.
7. In two-client testing, verify private snapshot isolation and reject malformed, repeated, stale and
   cross-owner actions. Visitors may see public Display totals but never private pity data.
8. Check narrow/mobile details, current/base odds, large-Coin abbreviations, exact values and the
   single Starter daily action. Observe both normal and unlucky pacing.
9. With isolated persistent storage, display figures, leave for over a minute and rejoin: the popup
   shows half-rate Coins for the absence; Claim and tap-outside each credit once. Leave before
   claiming and rejoin: the leftover auto-claims. A quick server hop shows no popup.

Coordinate server replacement for rollout. Old namespaces remain rollback backups, but they do not
contain Economy2 progress.
