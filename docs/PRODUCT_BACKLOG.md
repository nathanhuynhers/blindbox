# Product backlog

This is the current product-direction backlog after the first full-game candidate. The existing backend and persistence foundation should generally be preserved while player-facing quality improves. Priorities can change after playtesting.


## Current playtest TODO

These are the current discrete follow-up tasks from playtesting. Each numbered item is intended to stay as one task rather than being split into implementation subtasks.

1. **Add coin collection animation**
   - Play a satisfying animation when coins are collected from a figure.

2. **Show earnings above figures**
   - Show how many coins each individual displayed figure has accumulated.
   - Also show the combined earnings for the whole Display.

3. [x] **Rework Display interaction** — completed and manually accepted. See [verification](PLAYTEST_INTERACTIONS.md).
   - E opens the Display UI only when the player is nearby.
   - The E prompt follows the front-left edge of every Display width so it does not cover a figure or intercept the middle figure's collection click. Native Studio MCP verification passes; final user visual confirmation of the relocation is pending.
   - E no longer collects coins.
   - Desktop players click individual figures to collect.
   - Mobile players tap individual figures to collect.
   - Add a nearby sign explaining how to collect, ideally device-specific wording such as "Click to Collect" or "Tap to Collect."

4. **Add Shelf/Page progression**
   - Treat a Shelf and a Page as the same progression unit.
   - Completing a Collection for the first time unlocks a new Shelf/Page.
   - Players can also purchase additional Shelf/Pages using coins.

5. [x] **Increase Shelf and Display brightness at night** â€” implementation and automated checks complete; Studio visual/mobile acceptance pending.
   - Make figures and their furniture easier to see without making the whole plot overly bright.
   - Native Studio MCP instance, transition, expansion, carousel and cleanup checks pass; subjective 3D visual/mobile acceptance remains pending.

6. [x] **Rename Collection to Shelves** — completed and manually accepted. See [verification](PLAYTEST_INTERACTIONS.md).
   - Change the incorrect "Collection" title at the top of the Shelf interface to "Shelves."

7. [x] **Restrict Shelf placement to owned figures** â€” implementation and automated checks complete; Studio persistence/multiplayer acceptance pending.
   - Players can only place copies they actually own.
   - If they own two copies of a figure, they can only have two copies placed across their Shelves.
   - Native Studio MCP authority, repair and picker-state checks pass; isolated DataStore rejoin and two-client acceptance remain pending.

8. **Add Auto Open Gamepass**
   - Automatically keep opening boxes.
   - Let the player stop manually.
   - Allow stopping automatically when a chosen rarity is pulled.

9. **Add x10 Open**
   - Everyone can open 10 boxes at once as long as they can afford all 10.

10. **Add offline earnings + Robux double**
    - Displayed figures continue earning while the player is offline.
    - Offline earnings should generate at a reduced rate of about 0.5x normal online earnings to prevent abuse; exact tuning can be adjusted during economy balancing.
    - Offline earnings stop accumulating after a TBD number of hours.
    - On return, show how much was earned.
    - The player can claim normally or spend Robux to double the offline earnings.

11. [x] **Remove finished Daily Goals** — completed and manually accepted. See [verification](PLAYTEST_INTERACTIONS.md).
    - After a Daily Goal is completed and claimed, remove it from the HUD instead of leaving the "Claimed" card there.

12. **Add consecutive Daily Login Rewards**
    - Rewards improve each consecutive day.
    - Day 7 gives a particularly strong reward.
    - Missing a day resets the streak back to Day 1.

13. [x] **Remove proximity requirement for Display and Shelf editing inside own plot** — implementation, automated checks and native Studio authority checks complete. See [verification](PLAYTEST_INTERACTIONS.md).
    - Remove the "Walk Closer" requirement for placing/editing figures on the Display.
    - Remove the equivalent proximity requirement for editing Shelves.
    - As long as the player is physically inside their own plot, they should be able to manage both.
    - Players should not be able to manage these systems from outside their own plot.

14. **Add Auto Collect Gamepass**
    - While the player is online, automatically collect earnings from all displayed figures once per second.
    - Players with the Gamepass should not need to manually click or tap each figure to collect online earnings.
    - This is separate from the offline earnings system.

15. [x] **Add Jump to Plot / Home button** — implementation, automated checks, native Studio single-client behavior and mobile layout checks complete; multi-client and true-touch acceptance pending.
    - Add a button that teleports the player back to their own plot.
    - Player-facing naming/iconography can use "Home" if that fits the UI better than "Jump to Plot."
    - Teleport the character to a safe, consistent location within their own plot.

16. **Add full game soundpack**
    - Add cohesive sound effects across the game for important interactions and feedback.
    - Cover UI clicks/navigation, box opening, rarity/reveal moments, coin collection, purchases/claims, Display/Shelf interactions, Daily Goals/Rewards, and other important gameplay actions.
    - Keep the sound direction consistent with the game's polished blind-box collectible feel.

17. **Add background music**
    - Add looping background music for the main world/plot experience.
    - Keep it subtle enough that gameplay sound effects remain clear.
    - Leave room for area-specific or special-event music later if needed.

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
     acceptance is pending. Superseded by the one-system redesign; see
     [ui-redesign/IMPLEMENTATION.md](ui-redesign/IMPLEMENTATION.md).

3. **Production-quality collectible models**
   - Replace procedural placeholder figures with original, desirable collectible characters.
   - Give each collection a cohesive art direction and each figure a recognizable silhouette.
   - Prioritize the collectibles themselves because desire to own/display them drives the game.

4. **Collection book redesign**
   - Visual grid/book with silhouettes for undiscovered figures, discovery state, quantities, rarity, collection completion, and a focused detail view.
   - Make completing a collection feel celebratory.

5. **Player Plot, Display and Shelves (functional candidate implemented)**
   - Fixed open plots contain a horizontal three-to-six-slot earning Display and cosmetic Shelves.
   - Three persistent Shelf Units start with nine positions each; a fixed three-structure viewport
     shifts one owned unit per turn. Future expansion adds individual units; no product-design maximum.
   - Schema v5 preserves legacy cosmetic references and converts each retired v4 page into three units. Walking replaces visit/teleport navigation.
   - Final art, shelf customization and individual Shelf Unit acquisition/pricing are future work, not implemented.
   - Collection-completion rewards are TBD; tracking remains.
   - Follow [Player Plots and Shelves](PLAYER_PLOTS_AND_SHELVES.md).

## Phase 2: Build depth

6. **Physical blind-box shop and polished world**
   - Move beyond menu-only purchasing toward a physical shop/hub with visible collection boxes and open player plots.

7. **Secret figures**
   - Consider one optional chase Secret per collection.
   - Standard collection completion should not require the Secret.
   - Avoid generic rarity inflation.

8. **Collector progression**
   - Add long-term account progression based on collecting/discovery/completion rather than exponential power multipliers.
   - Progression rewards need a separate decision; collection-completion rewards remain TBD.

9. **Social plot features**
   - Walk-in viewing and shared shelf navigation are implemented; evaluate these with multiple clients.
   - Later consider likes, favorite/rarest figure showcases, collection inspection, completion badges, and recent-pull presentation.

10. **More collections and content pipeline**
    - Make adding an original collection a repeatable content update rather than an architecture rewrite.
    - New collections should combine figures and packaging; completion rewards and matching decor require separate decisions.

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

- The core fantasy is: **open cute blind boxes, build a collection, build a personal collection exhibit, and show it to other players.**
- Display earning, collecting, and cosmetic Shelves should reinforce each other while Shelves stay non-economic.
- Prefer visual communication over walls of text.
- Avoid turning the game into a generic exponential-upgrade simulator.
- New systems should strengthen collecting, expression, anticipation, or social pride.
- Keep all characters, collections, packaging, and visual identity original rather than copying real blind-box IP.
