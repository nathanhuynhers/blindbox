# Current implementation scope

The user accepted the original MVP on September 23, 2026 and subsequently authorized the expanded
candidate. On September 27 the user explicitly replaced the Showroom/Gallery experiment with
[open Player Plots, Display and Shelves](PLAYER_PLOTS_AND_SHELVES.md).

Implemented: twelve figures/two collections, server box rolls, owned/discovered state, automatic
Display income and themed bonus, three-to-six horizontal Display capacity with the existing
fourth-slot Coin unlock, Scrap recycling/redemption, daily box/Display goal, native persistent
profiles, fixed open plot assignment, three physical shelf units, cosmetic discovered-figure
placement, shared runtime one-unit carousel navigation and schema-v5 migration.

The existing Shop, Collection Book, opening experience, responsive UI helpers and asset pipeline
remain. The Social teleport directory was replaced with a minimal owner Shelf editor in the same
navigation position. Visitors walk into plots and see the replicated exhibit. Private profiles
are not exposed. Decorative visitor actors and old themed room geometry were retired.

Shelves reserve zero copies and earn zero Coins. New profiles own three persistent units of nine positions.
Three structures render a sliding viewport regardless of owned count; future expansion adds
individual units with no product-design maximum. Shelf purchases, pricing curves, slot 5/6 acquisition,
customization catalogs/UI, monetization, kiosks, free placement, likes, trading and final visual
design are excluded. **Collection-completion rewards are TBD**; discovery/completion tracking
remains intact without room unlocks or replacement grants.

Schema 5 reads valid v1-v4 profiles; each retired v4 page becomes exactly three Shelf Units. All unrelated progression survives; legacy room themes have
no equivalent and are explicitly retired. See [data model](DATA_MODEL.md) and
[implementation report](PLOT_SHELF_IMPLEMENTATION.md). No packages were added, no tool versions
were upgraded, and nothing was published. Automatic checks do not replace pending Studio/device,
real DataStore migration, multiplayer security or performance acceptance.
