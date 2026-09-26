# Product backlog

This is the current product-direction backlog after the first full-game candidate. The existing backend and persistence foundation should generally be preserved while player-facing quality improves. Priorities can change after playtesting.

## Phase 1: Make the prototype feel like a game

1. **Blind-box opening overhaul**
   - Make opening the signature interaction: tactile, pleasing, exciting, fast, and skippable.
   - Use collection-specific box presentation, anticipation, rarity-specific reveals, sound/VFX hooks, NEW/duplicate feedback, and a strong Rare/Secret-ready structure.
   - Preserve server-authoritative purchase, roll, inventory, persistence, and economy behavior.

2. **UI/UX overhaul**
   - Replace the current text-heavy prototype interface with polished, visual Roblox UI.
   - Reduce instructional text, improve hierarchy, use icons/cards/progress visuals, and design for mouse, touch, and gamepad.
   - The current UI is functional scaffolding and does not need to be visually preserved.
   - The second visual candidate separates neutral global controls from collection art direction
     and replaces the shared menu shell with distinct presentations. Studio visual/device
     acceptance is pending; see [UI candidate and checklist](UI_UX.md).

3. **Production-quality collectible models**
   - Replace procedural placeholder figures with original, desirable collectible characters.
   - Give each collection a cohesive art direction and each figure a recognizable silhouette.
   - Prioritize the collectibles themselves because desire to own/display them drives the game.

4. **Collection book redesign**
   - Visual grid/book with silhouettes for undiscovered figures, discovery state, quantities, rarity, collection completion, and a focused detail view.
   - Make completing a collection feel celebratory.

5. **Separate Display from Showrooms**
   - Migrate the current earning shelf/Room into the focused three-to-six-slot Display system.
   - Build non-economic Showrooms separately; do not turn economic Display optimization into decorating.
   - Explore shelves, wallpaper, floors, rugs, plants, lighting, display cases, furniture, plaques, and collection-themed rewards.
   - Collection completion unlocks its associated Showroom; additional blank/custom rooms can be acquired separately.
   - Preserve schema-v2 slots and palette ownership through an explicit migration.
   - Follow the implementation order and unresolved decisions in [Display and Showrooms](DISPLAY_AND_SHOWROOMS.md).

## Phase 2: Build depth

6. **Physical blind-box shop and polished world**
   - Move beyond menu-only purchasing toward a cozy physical shop/hub with visible collection boxes and showroom access.

7. **Secret figures**
   - Consider one optional chase Secret per collection.
   - Standard collection completion should not require the Secret.
   - Avoid generic rarity inflation.

8. **Collector progression**
   - Add long-term account progression based on collecting/discovery/completion rather than exponential power multipliers.
   - Potential rewards: showroom space, cosmetics, shelves, titles, and other expression.

9. **Social showroom features**
   - Replace/extend current main-plot Display visits with one scalable Gallery entrance and safe visits to unlocked Showrooms.
   - Later consider likes, favorite/rarest figure showcases, collection inspection, completion badges, and recent-pull presentation.

10. **More collections and content pipeline**
    - Make adding an original collection a repeatable content update rather than an architecture rewrite.
    - New collections should combine figures, packaging, completion rewards, and optional matching decor.

11. **Daily/weekly quests**
    - Expand the lightweight daily system only after the core loop is fun.
    - Avoid punitive streaks and excessive chores.

12. **Achievements and titles**
    - Reward collecting milestones with visible cosmetics/titles as well as occasional currency.

## Later, separate design decisions

- **Variants/colorways:** potentially make duplicate pulls exciting, but this requires revisiting the quantity-stack data model and individual-copy identity.
- **Trading:** do not implement casually. It requires a separate design for identity, atomic two-profile transfers, replay/duplication prevention, recovery, and economy impact.
- **Monetization:** design after the core experience is compelling and validate current Roblox policy before implementing paid randomized mechanics.

## Product principles

- The core fantasy is: **open cute blind boxes, build a collection, create a beautiful showroom, and show it to other players.**
- Display earning, collecting, and Showroom decorating should reinforce each other without making Showrooms economic.
- Prefer visual communication over walls of text.
- Avoid turning the game into a generic exponential-upgrade simulator.
- New systems should strengthen collecting, expression, anticipation, or social pride.
- Keep all characters, collections, packaging, and visual identity original rather than copying real blind-box IP.
