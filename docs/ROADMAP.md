# Development roadmap

## Current status

The implemented candidate runs in **Blindbox Town** with open Player Plots, an authoritative
Coin-generating Display, cosmetic Shelf Units, 43 figures across five collections, schema 14 in
the Economy2 namespace, and the merged economy, UI, audio and Welcome Quest work. See the
[data model](DATA_MODEL.md) for current stores and supported upgrades. Scrap, recycling, redemption,
the retired Showroom/Gallery runtime and teleport browsing are not part of the current game.

Automated and recorded single-client checks do not close the remaining release gate. Native
multi-client, device/input, persistent DataStore, rendering and performance acceptance are still
required. Public deployment, paid mechanics and trading remain outside the authorized scope.

## Sources of truth

- [Game design](GAME_DESIGN.md) — current player experience and world direction.
- [Player Plots, Display and Shelves](PLAYER_PLOTS_AND_SHELVES.md) — canonical plot, Display and
  Shelf behavior, capacity, paid progression and completion rewards.
- [Architecture](ARCHITECTURE.md) and [data model](DATA_MODEL.md) — system boundaries, authority,
  persistence and schema upgrades.
- [Economy](ECONOMY.md) — current prices, odds, pity, duplicate income and acceptance checklist.
- [UI redesign implementation](ui-redesign/IMPLEMENTATION.md) and
  [opening](OPENING.md) — merged client UI, opening flow, Open 10 and manual checks.
- [Game soundpack](SOUND.md) — sound manifest, asset sources, hooks and listening checks.
- [Operations](OPERATIONS.md) — current release and multi-client verification.
- [Product backlog](PRODUCT_BACKLOG.md) — remaining product work; entries are not authorization.
- [Archived milestones 0–6](archive/ROADMAP_MILESTONES.md) — historical planning only.

Final art and Shelf customization remain proposals. Paid Shelf acquisition and one free Shelf Unit
per first collection completion are implemented; their persistent and multiplayer acceptance is
still pending. Implement future work only when the user authorizes that specific task.
