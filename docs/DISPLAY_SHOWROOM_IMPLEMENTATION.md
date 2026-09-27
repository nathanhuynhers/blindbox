# Historical schema-v3 implementation note

**Historical; superseded September 27, 2026.** The Showroom/Gallery experiment was intentionally
replaced. It is not current design and does not remain as a parallel runtime system.

Current canonical concepts are large open **Player Plots**, earning **Display**, cosmetic
**Shelves** and **Shelf Pages**. Visitors walk between plots. There are no Gallery entrances,
interiors, room sessions, Showroom editors or collection-unlocked rooms.

See [current direction](PLAYER_PLOTS_AND_SHELVES.md), [schema-v4 migration](DATA_MODEL.md), and
[implementation/checks](PLOT_SHELF_IMPLEMENTATION.md). Valid legacy cosmetic figure references
are migrated into shelf pages; legacy room themes have no direct equivalent and are retired.
Collection-completion rewards are TBD. Git history retains the original experiment's details.
