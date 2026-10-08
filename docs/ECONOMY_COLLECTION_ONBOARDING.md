# Adding a collection to the economy

The economy is configured in `src/server/Economy.luau`; all tuning remains server-only.
Use the [figure collection runbook](FIGURE_COLLECTION_RUNBOOK.md) for authorized figure production
and the existing Catalog/art pipelines for identity and presentation.

1. Add the approved collection and stable figure IDs to shared Catalog.
2. Choose an existing economic tier, or add a new tier with an explicit integer box price and
   positive `paybackSeconds`. Reusing Prestige makes the collection a peer of Tender Echoes and
   We Are All Stars. A higher price plus a reviewed income scale creates a progression step.
3. Add a server collection definition with `tier`, `buckets`, `group` and optional `pity`.
4. Add every figure to `entries` with explicit positive `units` and `weight`. Rarity is read from
   Catalog; the weight is relative only to other figures in that rarity and collection.
5. Add visual assets/theme data through the existing pipelines. Shop, Book, prices, odds, duplicate
   projections and purchases iterate Catalog/configuration rather than branching on collection names.
6. Run the domain suite, invalid-configuration tests, progression simulation, format/lint/type checks
   and Rojo build. Check new collection UI and acquisition in Studio.

Example server configuration for an approved future full-roster collection:

```luau
-- Existing tier:
newcollection = {
    tier = "prestige",
    buckets = "standard",
    pity = "standard",
    group = "newcollection",
}
-- Add explicit entries using stable Catalog IDs, for example:
{ id = "newcollection.example", units = 0.60, weight = 1 }
```

This is illustrative configuration, not authorization to create that content. A five-tier profile
requires figures in all five buckets. The starter profile supports Common/Uncommon/Rare and omits
pity. A new roster/profile combination must never silently invent a missing rarity.

Use a unique pity group by default. Sharing a tier does not share luck. Shared groups are accepted
only with the same tier, buckets and pity profile; this blocks building cheap pity for costly boxes.
Keep published group IDs stable. Removing or renaming a persisted group requires a migration;
unknown saved groups fail closed. Adding a new unique group needs no schema change, because an
absent group means zero dry rolls.

Pity curves define base, warm-up start and a positive percentage-point increment, with no
separate maximum. Each curve must reach 100% before the persisted counter safety guard; startup
rejects unreachable guarantees. Both Legendary and Mythical curves are required for a high-tier
profile. Combined demands over 100% share the budget proportionally; simultaneous guarantees
grant Mythical first and retain Legendary for the following box. See ECONOMY.md for current tuning.

Base rates are derived once at startup:

```text
expectedUnits = sum(base bucket fraction * within-bucket weight share * units)
baseRate = units * tier.price / (tier.paybackSeconds * expectedUnits)
```

This normalizes the roster's average base income, but it does not predict the optimal Display.
Run simulation after adding a tier, changing roster size, changing odds or changing income units.
Multiple same-tier collections offer more distinct strong earners and make established-tier
collecting faster. Consider that effect before lowering tier pacing to match a short isolated test.

Startup rejects missing/duplicate figure entries, unknown collection/profile references, invalid
or non-finite numbers, buckets not totaling 100%, missing bucket figures, unsafe pity profiles and
duplicate ceilings crossing the next rarity's base band. Keep full progression and unlucky-start
tests in addition to these configuration checks.
