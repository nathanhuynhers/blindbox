# Approved Collection book implementation

This pass implements only the Collection experience from the approved mockup/asset-sheet direction.
The asset sheet and earlier Collection composition are the visual targets, not a new visual proposal.
**Native Studio visual, input and device acceptance remains pending.** No screenshot or Studio
playtest was produced by the coding agent. Procedural figure models remain the existing models.

## Physical construction and composition

On a standard desktop, the book is a broad open volume with three portrait slots across two rows
on the left and a product-shot hero/detail presentation on the right. The cover sits behind two
separate page volumes; five edge layers, rotated page stacks, warm paper gradients, printed margins,
soft underlays and a multi-stop shaded fold provide depth. Catalog-generated index tabs protrude
from the left. Their emblems, labels and discovery counts remain independent of global navigation.
Grove has leaves/flowers and warm paper; Tide has shell fans, bubbles, coral and pale blue paper.

Cards have recessed portrait wells, small rarity badges and a blue selected outline. Unknowns
retain real model silhouettes with neutral colors and a question mark; their names and rarity
badges are hidden. The right page hides unknown metadata as well. Discovery history continues
showing a discovered figure after recycling its copies. Model framing uses actual bounds only for
Collection; other screens keep their existing preview fitting.

The right page uses the largest available portrait area next to compact information on wide pages;
narrower pages stack the hero over readable controls in a measured scroll container. Display is
green; Recycle is amber and disabled when no eligible extra exists. Redemption remains accessible.
Common/Uncommon/Rare use green/periwinkle/purple Collection badges. Opening rarity colors, catalog
rarities, rates and odds are unchanged. A six-thumbnail strip and previous/next controls provide
selection without another modal. The strip disappears when it cannot fit its 44px targets.

Global currency pills and the existing left navigation remain separate. Close sits at the book's
upper-right edge. Collection hides the floating Motion button; the same session preference remains
available on other screens. No new idle animation loop was added. Existing reduced-motion button
feedback still applies. Other screens, opening files and server behavior were preserved.

On small screens, compact emblem/progress index tabs remain on the left; one page is visible at a
time. The grid opens first, selecting a figure opens its detail page, and the explicit back control
returns to the grid. A newly acquired figure is the exception: the next Collection entry retains
its selection and detail view. A slot picker always opens the owned grid. Filtering and selection
never remove catalog entries or change ownership. Overflow stays scrollable.

## Modules and asset replacement

- `CollectionScreen`: composes book, tabs, grid, details and thumbnails from snapshots.
- `CollectionSelection`: catalog-bound selection, wraparound and acquisition/picker transitions.
- `CollectionLayout`: page/grid/detail geometry and responsive breakpoints.
- `CollectionSkin`: native cover/page stacks, fold, shadows and decorative skin slots.
- `CollectionTabs`: physical catalog-generated index tabs and progress.
- `CollectionArt`: book emblems/corner illustrations; the existing Shop renderer is unchanged.
- `CollectionStyle`: existing per-collection colors plus separate Collection rarity badge colors.
- `CollectionControls`: specialized glossy paper, green Display and amber Recycle surfaces.
- `FigureCard` / `FigureDetails`: mounted portraits and the right-page showcase.
- `CollectionAssets`: optional uploaded artwork, with native fallback retained while loading/failing.

All asset IDs currently are empty. There are no downloaded assets, fake IDs or baked dynamic labels.
The precise insertion points in `src/client/CollectionAssets.luau` are:

| Config key | Artwork to supply |
| --- | --- |
| `collections.grove.spread.id`, `collections.tide.spread.id` | Whole open-book skin, excluding dynamic text, controls, tabs and figures |
| `collections.<id>.page.id` | Single-page book skin for narrow layouts |
| `collections.<id>.corner.id` | Transparent decorative corner flourish |
| `collections.<id>.tab.id`, `.emblem.id` | Blank index-tab surface and transparent collection emblem |
| `collections.<id>.card.id` | Normal blank portrait mount |
| `collections.<id>.cardSelected.id`, `.cardLocked.id` | Selected/unknown portrait mounts; no character/name baked in |
| `collections.<id>.detail.id` | Blank right-page showcase border/background |
| `buttons.display.id`, `buttons.recycle.id`, `buttons.paper.id` | Text-free button surfaces |
| `badges.Common.id`, `badges.Uncommon.id`, `badges.Rare.id` | Text-free rarity pills |

Set `id` to the actual uploaded `rbxassetid://...`. Each entry optionally takes
`slice = {left, top, right, bottom}` in source-image pixels for nine-slice scaling. Without a
slice rectangle, a skin stretches to its slot. Full book art should keep its fold centered and
leave content clear inside the existing page insets. Corners embedded in a full spread/page skin
replace the native corners too. Smaller independent corner assets apply to the native book.
Card/portrait imagery stays separate: models, names, counts and badges are live UI siblings.
A missing/unloaded image keeps the native surface visible. Swap artwork without changing selection,
remotes, ownership, model construction or the book's content hierarchy.

The native cover, paper, page depth, flowers/leaves, shells/coral/bubbles, tabs, mounts, badges and
button surfaces are clear original placeholders for final art. The procedural 3D figures are a
separate production-model task. No uploaded art is required for this implementation to function.

## Checks and Studio review

The standalone suite covers desktop/narrow book bounds, two-row/six-card fit at standard desktop
sizes, touch/thumbnail sizing, selection wraparound, acquisition retention and owned-picker entry.
The existing UI, scrolling, opening, gameplay and persistence suites remain applicable. Static
checks include pinned StyLua, Selene, Luau LSP diagnostics and the Rojo build.

Use the current sync or rebuilt `RobloxWorkspace.rbxlx`, open Collection, then:

1. Compare 1280x720 and 1920x1080 side by side with the approved reference. Check the broad book
   silhouette, distinct layered pages, central fold, projecting left tabs, six portrait mounts,
   hero emphasis, warm paper, corner art and independent world/HUD/navigation. The close button
   must not cover the page title. Native placeholders should be recognizable as the specified
   elements even before production art replaces them.
2. Switch Grove/Tide repeatedly; inspect tab counts, paper, cover, emblems and decorations.
   Select each card and thumbnail, then previous/next. The highlight and right-page model must
   agree. Run `tests/StudioCollection.client.luau` in the **client Command Bar** for read-only
   structural, model/silhouette and selection assertions. It does not approve the visual result.
3. Inspect unknown, discovered, zero-copy-discovered, duplicate and fully reserved figures.
   Unknown names/rarity/metadata remain hidden. Try Display from the book and a chosen shelf slot;
   recycle an extra, protect the last copy/reserved copies, and redeem with sufficient Scrap.
   Compare counts/rates to server replies; use a second client for isolation.
4. Run `tests/StudioScroll.client.luau` with All figures and the grid visible for both collections.
   Repeat after filtering, resizing and respawn. Reach the last card with mouse, touch and gamepad.
5. Test 320x568 portrait, 568x320 landscape and tablet sizes. One-page mode must keep readable
   text, an obvious back button and accessible actions. Thumbnail strips may disappear. Repeat
   `tests/StudioUI.client.luau` to check targets, canvases and safe-area containment.
6. Buy/claim/redeem through the existing flow, finish/skip the opening, then open Collection.
   Verify the newly acquired figure remains selected; in narrow mode its detail appears. A new
   slot-picking action must instead open the owned grid. Reset during opening and during browsing.
7. Toggle Motion: low from another screen and return. Test gamepad Y/B/shoulders/A and focus in
   both scroll containers. Switch collection/selection 20 times without gameplay changes and
   compare instance counts for growth. Check Output for errors.
8. Later, test one real uploaded skin and one unavailable asset ID in an isolated local edit:
   native artwork remains until the image loads, and text/models/input keep working. Restore
   that local test config afterward. No remote grant or persistence test is needed for artwork.

All manual Studio steps above remain unrun by the coding agent.

## Change and verification record

Changed client files: `CollectionScreen.luau`, `CollectionArt.luau`, `CollectionStyle.luau`,
`FigureCard.luau`, `FigureDetails.luau`, `Interface.luau`, `UILayout.luau`, `UIPreview.luau`.
Added client files: `CollectionAssets.luau`, `CollectionControls.luau`, `CollectionLayout.luau`,
`CollectionSelection.luau`, `CollectionSkin.luau`, `CollectionTabs.luau`.
Changed test files: `tests/run.py`, `tests/StudioScroll.client.luau`.
Added tests: `tests/Collection.spec.luau`, `tests/StudioCollection.client.luau`.
Documentation: this file, `docs/UI_UX.md`, `docs/ARCHITECTURE.md`.

Checks actually run for this pass:

- `rokit install --no-trust-check` and pinned `wally install` succeeded; versions/dependencies unchanged.
- `stylua src` and `stylua --check src` passed, including changed/new Luau test files.
- `selene src` plus changed/new Luau tests: zero errors/warnings using cached Roblox API definitions.
- Luau LSP diagnostics passed for source and both Studio Collection/scroll scripts.
- `python tests/run.py build/tools/luau/luau.exe`: 8,878 MVP, 86 full-game/persistence, 4 scrolling,
  1,732 opening, 1,292 existing UI, 72 new Collection checks and 4 invalid-config fixtures passed.
- `rojo sourcemap default.project.json -o sourcemap.json` and
  `rojo build default.project.json -o RobloxWorkspace.rbxlx` succeeded.
- `git diff --check` passed. Byte comparisons confirmed the other screen modules, HUD/navigation,
  global theme/widgets, opening files, server/shared code, networking coordinator, mapping and
  pinned manifests/lockfile stayed unchanged.

These are source/build and deterministic checks, not evidence of a rendered visual match.
