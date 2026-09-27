# Current implementation scope

The user accepted the original MVP on September 23, 2026 and subsequently authorized the expanded
candidate. On September 27 the user explicitly replaced the Showroom/Gallery experiment with
[open Player Plots, Display and Shelves](PLAYER_PLOTS_AND_SHELVES.md).

Implemented: twelve figures/two collections, server box rolls, owned/discovered state, automatic
Display income and themed bonus, three-to-six horizontal Display capacity with the existing
fourth-slot Coin unlock, Scrap recycling/redemption, daily box/Display goal, native persistent
profiles, fixed open plot assignment, three physical shelf units, cosmetic discovered-figure
placement, shared runtime shelf-page navigation and schema-v4 migration.

The existing Shop, Collection Book, opening experience, responsive UI helpers and asset pipeline
remain. The Social teleport directory was replaced with a minimal owner Shelf editor in the same
navigation position. Visitors walk into plots and see the replicated exhibit. Private profiles
are not exposed. Decorative visitor actors and old themed room geometry were retired.

Shelves reserve zero copies and earn zero Coins. New profiles have one page; migration can create
more only to preserve legacy references. Page purchases, pricing curves, slot 5/6 acquisition,
customization catalogs/UI, monetization, kiosks, free placement, likes, trading and final visual
design are excluded. **Collection-completion rewards are TBD**; discovery/completion tracking
remains intact without room unlocks or replacement grants.

Schema 4 reads valid v1-v3 profiles. All unrelated progression survives; legacy room themes have
no equivalent and are explicitly retired. See [data model](DATA_MODEL.md) and
[implementation report](PLOT_SHELF_IMPLEMENTATION.md). No packages were added, no tool versions
were upgraded, and nothing was published. Automatic checks do not replace pending Studio/device,
real DataStore migration, multiplayer security or performance acceptance.
