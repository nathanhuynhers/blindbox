# Economy redesign verification

Branch: `codex/economy-redesign`. This is implementation evidence, not a release approval.
No Studio playtest, live DataStore deletion, public deployment or device visual acceptance was
performed by the agent.

## Implemented scope

Variable collection-tier prices and derived income; server-owned rarity buckets and increasing
Legendary/Mythical odds; independent saved pity; permanent diminishing duplicate income;
unique earning placements; sequential slots 4-6; +10% themed income; Starter-only daily box;
1,000-Coin daily goal; 4,500 starting Coins and fully random starters; no Scrap gameplay/schema;
schema 7 in Economy2 save namespaces, including migration from valid schema 6. Manual per-figure
click/E/touch collection replaces automatic wallet credits; banks persist and retain fractions.
See [current values](ECONOMY.md).

## Automated checks

- Pinned tool setup with `rokit install`, then zero-dependency `wally install`.
- `stylua src`, `stylua --check src`, and `selene src`.
- Luau language-server analyze using the installed Roblox definitions and current Rojo sourcemap.
- `rojo build default.project.json -o RobloxWorkspace.rbxlx`.
- `python tests/run.py build/tools/luau/luau.exe`: actual domain modules under the existing
  engine shim; economy/protocol/persistence, opening lifecycle, UI projections/screens, shelves,
  plots and invalid configuration fixtures.

Economy checks cover weighted income, total probabilities, pity increments/caps/independent resets,
collection isolation, retry and failure atomicity, duplicate-only starters, unbounded product
inventory with numeric guards, settling pre-duplicate income, unique placement, daily restrictions,
malformed/spoofed payloads and 1,000 mixed transactions.

Persistence checks cover quantities and pity round trips/deep copies, unsupported schema rejection,
unknown groups, NaN/fractional/negative counters, duplicate/unowned placements, corrupted data,
competing sessions, expired leases, failed saves, lost replies and no repeated starter grants.
The old migration tests were replaced with reset-namespace rejection tests; storage-fault and
unrelated shelf/plot/UI coverage remains.

Manual collection follow-up checks also cover bank/wallet conservation, proportional themed
bonus, fractional persistence, schema-6 upgrade, invalid banks, partial full-wallet transfers,
removed/redisplayed figures, remote rejection, retry receipts and click/E callback ownership,
distance, dead-character, empty-slot and teardown checks. These run in the existing engine shim,
not Roblox Studio. Formatting, Selene, Rojo build, Luau diagnostics, full tests and the 300-run
pacing simulation were rerun successfully after this change. Median hours remain unchanged to
two decimal places under instant-collection simulation assumptions.

## Reproducible progression simulation

After the domain harness has generated its isolated modules:

```powershell
build/tools/luau/luau.exe tests/EconomySimulation.luau
```

300 seeded runs use actual Rules and CollectionEconomy. Each buys 30 Grove then 30 Tide boxes,
then hunts the first Concepts Mythical, the first Echo Mythical and the first Stars Mythical.
The player selects the strongest Display, considers qualifying themed trios, and buys sequential
slots when useful and their cost is at most 20 current boxes. Time includes earning the next
box/slot price, starting from existing Coins. No daily rewards, reveal delays, menu interactions,
offline time or activity rewards are simulated.

The manual-collection simulation collects displayed figures instantly when funding a purchase.
These results are an ideal earning-time baseline; walking and collection interaction add time.

| Collection stage | P10 hours | P25 hours | Median hours | P75 hours | P90 hours | Median boxes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| First Mythical tier: Concepts | 2.55 | 3.74 | 5.06 | 5.94 | 6.83 | 484 |
| First Prestige collection: Echo | 2.29 | 3.10 | 4.28 | 5.16 | 6.02 | 438 |
| Second Prestige collection: Stars | 0.40 | 1.03 | 1.59 | 2.07 | 2.59 | 439 |

This supports the requested roughly 4-6-hour median first-Mythical pacing at a newly entered
tier. It does not guarantee a player's result or measure engagement. Stars is faster here because
the account already owns a Prestige Mythical, Legendaries and expanded slots; reversing the two
equal-tier collections makes the earlier one the initial progression step. Soft pity still allows
first-box Mythicals and unlucky tails. Simulations are evidence for playtesting, not final balance.

## Remaining Studio acceptance

- Click and press E on each occupied slot, including slots 4-6 after expansion; test touch prompts.
  Wallet must stay unchanged while idle, and only the selected figure's bank should be collected.
- Verify private prompt amounts, success/empty/full-wallet feedback, visitors, dead characters,
  distance rejection, respawn and teardown. Test fast concurrent clicks with purchases/removal.
- Remove/replace an earning figure, save/rejoin, then redisplay it: its bank must remain available.
  Verify schema-6 upgrade and storage failure behavior without granting offline income.

1. Start fresh: 4,500 Coins, three slots, no Scrap; buy three fully random Starter boxes.
   Force/test a duplicate-heavy run and confirm that one enhanced figure funds continued play.
2. Verify all five prices, matching Echo/Stars rates, current boosted Shop odds and figure details
   showing owned count, base/effective income, duplicate percentage and next-copy income.
3. Verify no figure occupies two earning slots; cosmetic shelves may still repeat it.
   Buy slots 4/5/6 in order and check layout, affordability and refreshed price.
4. Confirm purchases that grant duplicates settle old income first, show the new income promptly
   and preserve original figures/quantity. Skip/retry reveals without extra grants.
5. In isolated persistent Studio testing, leave/rejoin with pity and duplicates; verify reset-store
   identity, round-trip state, one-time starter Coins, UTC claims and pause-on-storage-failure.
6. In two-client testing, inspect private snapshot isolation and try malformed, repeated, stale
   and cross-owner actions. Verify visitors see correct Display totals without private luck data.
7. Check narrow/mobile Figure Details wrapping, Shop current/base odds, large Coin abbreviations,
   exact values and the single Starter daily action. Observe normal and unlucky session pacing.

Coordinate server replacement before any later rollout. Old stores remain recoverable by reverting
the configured namespaces; they do not contain new-economy progress.
