# Rarity, duplicates and collection-economy redesign

Status: **implemented candidate on `codex/economy-redesign`; Studio acceptance pending**.
The discussion below is the original design record. [ECONOMY.md](ECONOMY.md) owns current tuning,
[DATA_MODEL.md](DATA_MODEL.md) owns schema 7 (including valid schema-6 upgrades), and
[verification](ECONOMY_REDESIGN_VERIFICATION.md) records checks and simulation assumptions.

Implementation decisions superseding the original candidate sections below:

- The user requested a full progression reset: fresh save namespaces, no Scrap conversion.
- The user selected fully random first three Starter purchases.
- The user selected roughly 4-6 hours to the first Mythical on entering a tier.
- Starter/near-starter normalization remains 180 seconds; Niche uses 550 and Prestige 850.
  The uniform 180-second higher-tier normalization and its illustrative rate tables are superseded.
- Tender Echoes and We Are All Stars remain equal-price Prestige peers with independent pity.
- Slots 4/5/6 use the proposed sequential Coin prices; the daily free box is Pocket Grove only.
- Adding a collection follows [the onboarding guide](ECONOMY_COLLECTION_ONBOARDING.md).

## Confirmed direction

- The standard hierarchy remains Common < Uncommon < Rare < Legendary < Mythical.
- A standard five-rarity box starts at a **1% total Legendary bucket** and a **0.1% total
  Mythical bucket**. These are tier probabilities, not per-figure probabilities.
- Scrap, duplicate recycling and targeted Scrap redemption will be removed.
- Every owned copy remains permanently owned. Copies after the first automatically increase that
  figure's Display income, with stronger percentage gains for harder rarities and diminishing
  returns at high quantities.
- Boxes do not all cost the same. Collections reference reusable economic tiers so multiple
  collections can share a price and income scale.
- Tender Echoes and We Are All Stars occupy the same economic tier.
- Later collections may introduce more expensive tiers. Adding a collection should be primarily
  configuration and content work, not new Shop, pity or income logic.
- Pity does not force a result at a fixed count. Missing a Legendary or Mythical gradually raises
  that rarity's chance until it drops.
- Coin values scale upward between economic tiers so players visibly progress from thousands to
  millions and beyond while the time-to-box remains deliberately controlled.

## Two progression axes

**Economic tier** controls a collection's box price and the magnitude of its Coin generation.
**Rarity** controls odds and relative figure strength within that collection. Two collections can
share an economic tier without sharing their figures, completion, presentation or pity state.

The initial price ladder to simulate is:

| Economic tier | Candidate box price | Current/provisional collections |
| --- | ---: | --- |
| Starter | 1,500 Coins | Pocket Grove |
| Near-starter | 2,000 Coins | Tidepool Tales |
| Niche | 20,000 Coins | Concepts |
| Prestige | 200,000 Coins | Tender Echoes; We Are All Stars |
| Future | 2,000,000 Coins | Future collections |
| Future+ | 20,000,000 Coins | Future collections if needed |

The collection assignments other than the confirmed shared Prestige tier are candidate
progression placements. New tiers must be introduced intentionally; a collection may reuse an
existing tier when it should be an equally valuable alternative rather than a progression step.

## Standard rarity buckets

The default full-roster profile is:

| Rarity | Total base chance | Natural average |
| --- | ---: | ---: |
| Common | 60% | 1 per 1.7 boxes |
| Uncommon | 25% | 1 per 4 boxes |
| Rare | 13.9% | 1 per 7.2 boxes |
| Legendary | 1% | 1 per 100 boxes |
| Mythical | 0.1% | 1 per 1,000 boxes |
| **Total** | **100%** | |

For a roster with four Commons, three Uncommons, three Rares, two Legendaries and one Mythical,
equal within-tier weights produce 15% per Common, about 8.33% per Uncommon, about 4.63% per Rare,
0.5% per Legendary and 0.1% for the Mythical. Within-tier weights may differ, but the public Shop
must derive and display the actual server-configured odds.

Collections that omit rarities use an explicit compatible bucket profile. A three-rarity starter
profile may use 60% Common, 30% Uncommon and 10% Rare. Missing rarities receive no synthesized
odds or pity counters.

## Coin-generation anchor

The initial pacing rule is:

```text
expected base income of one random figure = box price / 180 per second
```

Before duplicate and themed bonuses, three statistically average figures from a collection fund
another box in about 60 seconds. Six average figures fund one in about 30 seconds. This preserves
an understandable play rhythm while the visible numbers grow substantially.

| Box price | Expected figure | Three average figures | Six average figures |
| ---: | ---: | ---: | ---: |
| 1,500 | 8.33/sec | 25/sec | 50/sec |
| 2,000 | 11.11/sec | 33.33/sec | 66.67/sec |
| 20,000 | 111.11/sec | 333.33/sec | 666.67/sec |
| 200,000 | 1,111.11/sec | 3,333.33/sec | 6,666.67/sec |
| 2,000,000 | 11,111.11/sec | 33,333.33/sec | 66,666.67/sec |

The target is a weighted average, not a promise about every inventory. All-Common starts are
slower; stronger rarities and duplicates are faster. The grind should come from building a
collection, moving into a higher economic tier and chasing rare results, not primarily from
waiting several minutes between ordinary boxes.

### Normalized rarity power

The candidate within-collection power curve is:

| Rarity | Candidate normalized values |
| --- | ---: |
| Common | 0.55-0.70 |
| Uncommon | 1.20-1.40 |
| Rare | 2.80-3.20 |
| Legendary | 7.50-8.50 |
| Mythical | 22.00 |

For the standard full-roster bucket, these values have a weighted expected value of approximately
1.219. A tier scale can therefore be derived for planning as:

```text
collection scale = box price / (180 * weighted normalized value)
figure base rate = configured normalized figure value * collection scale
```

Production definitions should store explicit validated server values or explicit income units;
clients must not synthesize authoritative rates. A collection's weighted base income should be
within a small review tolerance, initially +/-5%, of its economic tier target.

The formula intentionally lets an exceptional figure from the previous tier help bootstrap the
next tier. A later Common does not need to replace an earlier Mythical immediately, while later
Rares and Legendaries eventually make the new tier economically dominant.

## Duplicate enhancement

Copies are permanent quantity stacks by figure ID. The first copy unlocks the figure; all later
copies automatically enhance that figure whenever it is on the Display. No copy is consumed.

```text
extraCopies = ownedCopies - 1
duplicateBonus = maximumBonus * extraCopies / (extraCopies + curve)
effectiveFigureRate = baseFigureRate * (1 + duplicateBonus)
```

This asymptotic curve gives a meaningful first duplicate, makes every later duplicate add some
value and prevents unlimited linear growth.

| Rarity | First duplicate | Maximum approached bonus | Curve |
| --- | ---: | ---: | ---: |
| Common | +10% | +60% | 5 |
| Uncommon | +15% | +90% | 5 |
| Rare | +25% | +125% | 4 |
| Legendary | +50% | +150% | 2 |
| Mythical | +100% | +300% | 2 |

Candidate rate bands and duplicate ceilings must preserve this invariant within one economic tier:

> A maximally enhanced lower-rarity figure remains weaker than the weakest unenhanced figure in
> the next rarity.

With the candidate normalized ranges, the limiting comparisons are 0.70 * 1.60 = 1.12 below
1.20; 1.40 * 1.90 = 2.66 below 2.80; 3.20 * 2.25 = 7.20 below 7.50; and 8.50 * 2.50 = 21.25
below 22.00.

The preferred Display rule is one placement per unique figure ID. Inventory retains the entire
owned count, but the player cannot both enhance a figure with duplicates and fill multiple earning
slots with enhanced copies. Shelves remain cosmetic permanent-discovery references and may repeat
figures without reserving copies or affecting income.

## Increasing-chance pity

Pity is server-owned and collection-specific by default. Each eligible pity group stores two dry
counts: boxes since its last Legendary and boxes since its last Mythical. There is no hard-guarantee
box in this proposal.

### Legendary curve

```text
legendaryChance = min(8%, 1% + max(0, legendaryDryRolls - 40) * 0.05%)
```

The increment is 0.05 percentage points per additional miss.

| Legendary dry rolls | Chance on next box |
| ---: | ---: |
| 0-40 | 1% |
| 60 | 2% |
| 100 | 4% |
| 150 | 6.5% |
| 180+ | 8% maximum |

### Mythical curve

```text
mythicalChance = min(2%, 0.1% + max(0, mythicalDryRolls - 300) * 0.0015%)
```

The increment is 0.0015 percentage points per additional miss.

| Mythical dry rolls | Chance on next box |
| ---: | ---: |
| 0-300 | 0.1% |
| 500 | 0.4% |
| 750 | 0.775% |
| 1,000 | 1.15% |
| 1,500 | 1.9% |
| 1,567+ | 2% maximum |

The counters are independent. A Legendary resets only Legendary dry rolls; a Mythical resets only
Mythical dry rolls. Thus an unusually lucky Mythical does not erase accumulated Legendary luck,
and a Legendary does not erase the longer Mythical chase.

Each box performs one rarity selection, never independent Legendary and Mythical result rolls.
The server first calculates the current high-tier bucket sizes. Any additional high-tier chance is
taken proportionally from Common, Uncommon and Rare while preserving their relative base weights.
It then selects a figure using the chosen rarity's configured within-tier weights.

The Shop should show the player's current chance, base chance and added luck for the selected box.
A meter may visualize increasing luck, but the UI must not imply a countdown or guaranteed result.

### Pity grouping

Every collection has a `pityGroupId`. The default is a unique group per collection so cheap boxes
cannot build luck for an expensive collection. Collections may intentionally share a pity group
only when product design explicitly wants shared progress and their economic relationship has been
reviewed. Sharing an economic tier does not automatically share pity: Tender Echoes and We Are All
Stars are both Prestige collections but keep separate pity by default.

## Display and themed bonus

The candidate calculation order is:

```text
1. Read each unique displayed figure's server base rate.
2. Apply its owned-count duplicate multiplier.
3. Sum all displayed figure rates.
4. Apply at most one themed collection bonus.
5. Settle elapsed-time income while retaining server-side fractions.
```

The existing flat +1/sec themed bonus will become negligible at higher tiers. The redesign candidate
is +10% total Display income when at least three distinct displayed IDs share one collection, applied
at most once. This percentage and its interaction with mixed-tier Displays require simulation and
playtesting before approval.

## Progression values affected by the new scale

Candidate values that preserve the current early relationships after the nominal increase are:

| Parameter | Candidate value |
| --- | ---: |
| New profile | 4,500 Coins, enough for three Starter boxes |
| Daily Display goal | 1,000 Coins |
| Display slot 4 | 40,000 Coins |
| Display slot 5 | 400,000 Coins, provisional |
| Display slot 6 | 4,000,000 Coins, provisional |
| Coin safety ceiling | 1 trillion, subject to numeric/storage review |

A daily free choice among every collection would bypass expensive-tier progression. The candidate
replacement is one free Starter box per UTC day, affecting only that box's pity group. Higher-tier
event boxes would be explicit rewards rather than an accidental consequence of a generic free-box
claim.

Large values should use readable abbreviations such as 1.5K, 2.4M, 3.1B and 1.0T while details or
tooltips retain an exact value. Server calculations retain fractions and authoritative balances;
clients only present sanitized values.

## Inventory and persistence consequences

The implemented 200-total-copy product limit is incompatible with permanent duplicates and a long
Mythical chase. The redesign stores one bounded integer quantity per figure ID and has no ordinary
player-facing total-copy capacity. Decoder and arithmetic guards remain mandatory, but they are
safety limits rather than progression limits.

Pity should use a bounded map rather than a new profile field for every collection:

```text
pityByGroup[groupId] = {
    legendaryDryRolls,
    mythicalDryRolls,
}
```

The decoder must validate known group IDs, dense/bounded storage, non-negative integer counts and
reasonable counter ceilings. Unknown future group state must not silently corrupt or reset valid
progress.

Removing Scrap requires an explicit migration policy before implementation. If meaningful player
data exists, candidate options are a documented Coin conversion or a one-time duplicate-progress
conversion. If all affected data is disposable internal test data, an authorized reset may be
simpler. Scrap must never silently disappear from persistent player data.

## Data-driven onboarding of collections

The design separates three reusable configuration layers:

### Economic tier

Defines an ID, box price, target pacing, Coin-scale bounds and default duplicate profile. Multiple
collections may reference the same tier.

### Pity and rarity profiles

Define base buckets, increasing-chance curves and supported rarities. Profiles are reusable but
remain server-authoritative.

### Collection definition

References an economic tier, rarity profile, pity profile and pity group, then lists its figures
with explicit rarity, within-tier weight, income units/rate and presentation metadata.

Adding a collection to an existing tier should require:

1. Define the collection and select an existing economic tier.
2. Select compatible rarity and pity profiles.
3. Assign a unique pity group unless shared pity is explicitly intended.
4. Add figures with explicit rarity, within-tier weight and income values.
5. Add presentation assets through the existing collection/figure pipelines.
6. Pass startup validation, probability checks and the weighted-income budget.
7. Let catalog iteration populate the Shop and Collection Book without a layout fork.

Adding the first collection at a new price requires one new economic-tier definition; subsequent
collections can reuse it. Core purchase, pity, duplicate, Display and Shop logic should not require
collection-name branches.

## Authority and validation requirements

The server owns box prices, balances, rarity selection, within-tier selection, pity counters, owned
quantities, duplicate multipliers, Display validation and income settlement. A client cannot submit
an outcome, current odds, price, rate, duplicate bonus, pity count or identity.

Startup/configuration validation must reject:

- non-positive or non-finite prices, rates, weights or curve values;
- rarity profiles whose buckets do not total 100%;
- figures assigned to missing or unsupported rarity buckets;
- a populated rarity with no selection weight;
- higher rarities that fail the strict rate-ordering invariant;
- duplicate ceilings that let a lower rarity cross the next rarity's base band;
- a weighted collection income outside its approved tier tolerance;
- invalid economic-tier, pity-profile or pity-group references; and
- unsafe Coin, counter or quantity bounds.

## Required balance work before implementation

The formulas above are coherent candidate defaults, not proof of fun or long-term balance. Before
coding the redesign, simulate at least first-session, 100-box, 1,000-box and multi-tier progression
with unlucky, median and lucky outcomes. Review time to first box in each tier, time to bridge tiers,
duplicate income concentration, current-chance pity distribution, mixed-tier optimal Displays,
slot-unlock affordability, daily-reward value and the rate at which late-game balances approach the
numeric ceiling. Studio playtests must still confirm that the result feels active rather than like
passive waiting.
