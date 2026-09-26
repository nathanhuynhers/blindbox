# Display and Showroom System

> **Status:** Current product direction. This document is the canonical terminology and design direction for the money-generating Display system and the social/customizable Showroom system.
>
> This replaces the older use of "showroom" for the passive-income shelf. The two systems are now intentionally separate.

This document defines approved product direction, not implemented behavior. The current candidate
still has a three-to-four-slot earning area named `Room`/`Showroom` in parts of the UI and source,
room palettes attached to that area, and same-server visits to players' main plots. Those systems
must be migrated without implying that the six-slot Display or Showroom Gallery already ships.

Related documents distinguish those states explicitly:

- [Current implementation scope](FULL_GAME.md)
- [Current stored schema and migration direction](DATA_MODEL.md)
- [Implemented architecture and legacy names](ARCHITECTURE.md)
- [Future implementation order](ROADMAP.md)
- [Current economy values versus future slot decisions](ECONOMY.md)

## Core Separation

Pocket Grove has two different player-facing systems:

### Display

**Purpose:** Utility and money generation.

Players place owned figures into a small number of active Display slots. Only figures in these slots generate passive Coins.

Display is part of the main gameplay loop:

**Open boxes -> collect figures -> choose active earners -> generate Coins -> buy more boxes.**

Display is intentionally simple and should not become a major decoration system.

### Showrooms

**Purpose:** Collection completion, personalization, social visiting, and flexing.

Showrooms do **not** generate Coins. They are dedicated spaces where players can display collectibles, completion rewards, decorations, furniture, and room cosmetics without worrying about economic optimization.

Showrooms should become one of the strongest long-term expression and cosmetic systems in the game.

---

# 1. Display System

## Location

The Display stays physically visible in the player's main Pocket Grove plot / flat-world area.

It should remain close to the core gameplay because the player frequently interacts with it after opening new figures.

The player should be able to look at the plot and immediately understand which figures are currently earning Coins.

## Capacity

- Every player starts with **3 active Display slots**.
- The system supports up to **6 active Display slots maximum**.
- Slots 4, 5, and 6 are additional progression/purchase opportunities.
- Exact unlock methods and prices are not finalized yet.
- Extra slots may use Coins, progression requirements, Game Passes, or another approved purchase path.
- The hard maximum should remain six unless the economy is intentionally redesigned later.

The existing prototype's four-slot limit is no longer the intended final structure.

The three-to-six capacity change requires a new profile schema migration, protocol validation,
world geometry, UI, public projection, and economy review. It must not be implemented as a client-only
visual expansion or by silently extending persisted slot arrays.

## Figure Rules

- One owned figure copy occupies one active Display slot.
- A copy reserved in Display cannot simultaneously be used by another system that requires that physical copy.
- Repeated figures are allowed if the player owns enough copies.
- Inventory-only figures do not generate passive income.
- Showroom placement does not generate income.
- Server-authoritative income calculations remain required.

## Presentation

Display should be visually clean and easy to read rather than deeply customizable.

The player should be able to understand:

- which figure occupies each slot
- each figure's earning rate
- total earning rate
- which slots are locked
- how an additional slot can be unlocked

The physical layout should support six slots from the beginning even if only three are initially unlocked, so later expansion does not require rebuilding the plot.

A likely arrangement is two rows of three or another compact six-point arrangement that keeps the figures easy to see.

## Customization

Display customization is low priority.

Possible minor cosmetics later:

- pedestal material/style
- small display trim
- subtle effects
- premium display skin

These should never make Display compete with Showrooms as the main creative space.

---

# 2. Showroom System

## Unlock Philosophy

Completing a collection unlocks a **Showroom associated with that collection**.

Example:

**Complete Pocket Grove -> unlock Pocket Grove Showroom**

The Showroom is a meaningful completion reward rather than a Coin bonus or simple badge.

Players may also be able to acquire **additional blank/custom Showrooms** without completing a collection. Exact purchase methods are TBD.

This allows both:

- completion-based trophy rooms
- personal rooms made only to show favorite or rare collectibles

## Economic Separation

Showrooms generate **zero passive Coins**.

A player should never need to choose between:

- the figure they want to show off
- the figure that earns the most money

Display handles economic optimization. Showrooms handle expression.

## Collection Completion

A collection-themed Showroom should communicate that the owner finished the corresponding collection.

Potential collection completion rewards inside the room include:

- exclusive base room theme
- collection plaque
- themed furniture
- themed display furniture
- collection-specific decoration set

Future Secret / Super Secret completion can further upgrade the room or unlock an exclusive decoration, plaque state, effect, or pedestal.

The exact Secret reward is not finalized yet, but the system should be designed so this can be added without redesigning Showrooms.

## Figure Placement

Players can display any owned collectible in a Showroom, including figures from collections other than the room's original collection.

A Pocket Grove Showroom is not restricted to Pocket Grove figures after it has been unlocked.

Initial implementation should use controlled placement points / snap points rather than unrestricted building.

Possible placement categories:

- shelves
- pedestals
- display cases
- centerpiece pedestal
- wall display points

A more advanced free-placement editor can be reconsidered later if the simpler system proves too limiting.

## Customization

Showrooms are the primary customization system.

Long-term categories can include:

- walls
- flooring
- lighting
- shelves
- pedestals
- display cases
- furniture
- plants
- rugs
- lamps
- wall decorations
- room effects
- collection trophies
- seasonal decorations

These categories should be data-driven so future cosmetic content can be added without rewriting the room system.

---

# 3. Main-World Showroom Entrance

Do **not** place every owned Showroom as its own building on the player's main plot.

That does not scale when the game has many collections.

Instead, each player's main Pocket Grove plot should contain **one Showroom Gallery entrance/building**.

The entrance represents all of that player's Showrooms.

Potential exterior information:

- player's display name
- number of unlocked Showrooms
- number of completed collections
- featured Showroom
- optional featured collectible preview later

The entrance should be socially visible so other players walking through the main area notice it and can choose to visit.

---

# 4. Showroom Gallery Interior

Entering the Showroom Gallery takes the owner or visitor into a separate interior/gallery space.

This can remain within the same Roblox experience. It does not need to be a separate Roblox place unless future technical requirements justify that.

The important design rule is that the gallery interior is spatially separated from the main Pocket Grove plot.

## Gallery Structure

The preferred long-term concept is a walkable gallery/hallway rather than only a menu.

Example:

```
Main Entrance
      |
      v

[ Pocket Grove ]       [ Tidepool Tales ]
      |                       |

========== Gallery Hall ==========

      |                       |
[ Favorites ]           [ Future Room ]
```

Players should be able to physically walk through another player's gallery and enter individual rooms.

This makes the size and quality of a collection visually understandable without requiring a statistics screen.

## Scaling

The architecture should not assume a fixed lifetime maximum of four Showrooms.

As the game grows, the Gallery can support:

- multiple wings
- additional floors
- paged room groups
- portals/doors to additional sections

Only nearby/currently needed rooms should need to be fully rendered if performance becomes a concern.

---

# 5. Visiting

Showrooms are intended to become a social feature.

Visitors should eventually be able to:

- enter another player's Showroom Gallery
- walk through unlocked rooms
- inspect displayed figures
- see collection completion rewards
- see room customization

Visitors must never:

- edit another player's room
- move their figures
- change cosmetics
- affect the owner's income
- access private economy/profile information

Owner and visitor permissions must remain server-authoritative.

---

# 6. Data Model Direction

The long-term profile should treat Display and Showrooms as separate state.

Conceptually:

```lua
display = {
    unlockedSlots = 3, -- 3 to 6
    slots = { ... },   -- active Coin-generating figures
}

showrooms = {
    unlocked = { ... },
    rooms = {
        [showroomId] = {
            sourceCollection = "...", -- optional for blank rooms
            theme = "...",
            figurePlacements = { ... },
            furniturePlacements = { ... },
            featured = false,
        },
    },
}
```

This is illustrative, not a required literal schema.

Implementation should preserve migration compatibility with existing saved profiles. Do not destroy or silently reset valid player data.

---

# 7. Existing Prototype Migration

The current code uses "Showroom" to mean the four-slot passive-income room.

That terminology should be refactored.

Target terminology:

- current passive-income shelf/slot system -> **Display**
- new completion/customization/social rooms -> **Showrooms**
- collection of Showrooms -> **Showroom Gallery**

Current room palettes should eventually belong to the Showroom customization system rather than the Coin-generating Display.

Until that migration is implemented, existing palette ownership and equipped state remain valid
saved player data. A future migration must preserve them or deliberately map them to equivalent
Showroom cosmetics; it must not discard them as obsolete fields.

The existing Display functionality should be preserved while it is renamed/refactored.

---

# 8. Implementation Order

Recommended order:

1. Refactor existing passive-income "Showroom" terminology to Display.
2. Expand Display data/visual architecture from 4 possible slots to 6 possible slots, with 3 unlocked by default.
3. Preserve current income behavior and persistence through the migration.
4. Create the Showroom ownership/data model separately from Display.
5. Derive collection Showroom unlocks from completed collections.
6. Add one Showroom Gallery entrance to the main plot.
7. Build a simple placeholder gallery interior.
8. Allow owner/visitor entry and safe navigation.
9. Build one reusable placeholder Showroom template.
10. Add controlled figure placement anchors inside Showrooms.
11. Add data-driven room customization hooks.
12. Replace placeholder geometry with the final mockup/assets after visual design is approved.

---

# 9. What Is Locked vs TBD

## Locked Direction

- Display and Showrooms are separate systems.
- Display generates Coins.
- Showrooms generate no Coins.
- Display remains on the main flat-world plot.
- Display starts with 3 slots.
- Display maximum is 6 slots.
- Completing a collection unlocks a themed Showroom.
- Additional custom/blank Showrooms can be acquired separately.
- Showrooms support much deeper customization than Display.
- One Gallery entrance exists on the main plot.
- Actual Showrooms live in a separate gallery/interior space rather than each occupying main-world land.
- Other players can eventually visit.
- Showroom architecture must scale beyond a small fixed number of collections.

## Still TBD

- exact slot 4/5/6 unlock prices and purchase types
- whether every extra Display slot has a free progression path
- exact Showroom purchase pricing
- number and layout of figure placement points per Showroom
- final gallery exterior design
- final gallery interior design
- final room dimensions
- exact customization UI
- exact furniture system
- Secret / Super Secret completion reward
- visitor discovery/browser UI
- likes/favorites/ratings, if any
- whether advanced free placement is ever added

Do not invent permanent answers to these TBD items during implementation. Use configurable placeholders where necessary.
