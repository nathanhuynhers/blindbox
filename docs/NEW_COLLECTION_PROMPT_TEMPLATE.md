# New Collection Build Prompt Template

Use this prompt template when starting a fresh Claude session to build a new collection end-to-end.

---

## Template Prompt

```
I'm building a new blind box collection. Here are the 2D mockups:
[PASTE IMAGES HERE]

Build the collection end-to-end following [COLLECTION_BUILD_PIPELINE.md](docs/COLLECTION_BUILD_PIPELINE.md).

## Required Information

**Collection slug:** [e.g., "forest-friends"]
**Collection name:** [e.g., "Forest Friends"]
**Collection description:** [e.g., "Woodland critters and creatures"]
**Collection ID prefix:** [e.g., "forest" for "forest.squirrel"]

## Figure Details

| Figure Name | ID | Rarity | Hex Color | Notes |
|---|---|---|---|---|
| Figure 1 | collection.figure1 | Common | #XXXXXX | |
| Figure 2 | collection.figure2 | Common | #XXXXXX | |
| Figure 3 | collection.figure3 | Common | #XXXXXX | |
| Figure 4 | collection.figure4 | Uncommon | #XXXXXX | |
| Figure 5 | collection.figure5 | Uncommon | #XXXXXX | |
| Figure 6 | collection.figure6 | Rare | #XXXXXX | |

## Shop Theme Colors

Extract from PALETTE section of mockups or provide:
- **Primary:** #XXXXXX
- **Secondary:** #XXXXXX
- **Wash:** #XXXXXX
- **Ink:** #XXXXXX
- **Trim:** #XXXXXX

## What You'll Build

### Phase 1–4: Figure Modeling & Publishing
1. Create `assets/figures/<collection>/figures.py` with SDF definitions for all figures
2. Match each figure's silhouette, proportions, and features to the mockups
3. Preview and refine figures using the Blender preview loop
4. Run `python tools/figures/publish.py <collection> --build` to:
   - Build final GLB files
   - Validate geometry (closed, manifold, <20k tris/part)
   - Register in manifest.json
   - Upload to Roblox
   - Auto-generate AssetIds.luau and FigureAssetEntries.luau

### Phase 5: Shop & Collection UI
1. Create UI assets (emblem, shop pattern, corner graphics) in `assets/ui/`
2. Update `src/shared/AssetManifest.luau` with new asset keys
3. Update `src/client/ShopTheme.luau` with collection theme colors

### Phase 6: Economy
1. Update `src/shared/Catalog.luau` with figures and collection if not already present
2. Update `src/server/Economy.luau` with figure entries (rates and weights)
   - Rates: Common 1–2, Uncommon 3–4, Rare 6–8
   - Weights: validate they sum correctly per Rules.luau

### Phase 7: Verification & Documentation
1. Write `assets/figures/<collection>/PRODUCTION.md` receipt
2. Run format/lint/build checks: `stylua src`, `selene src`, `rojo build default.project.json`
3. Report what was built, all gates passed, and asset IDs

## Output & Next Steps

At the end:
1. **Report:** Per-figure parts, triangles, sizes; asset IDs; any known differences from mockups
2. **Artifacts/Canvas:** Create a Design canvas showing:
   - Lineup + per-figure stats
   - Per-figure: beauty render, 4 inspection views, source sheet, mesh/tri counts, palette swatches
   - Reference: [Tidepool Tales canvas](https://claude.ai/artifact/QBkNESqAC9X8UXNtLiYz4E)
3. **User Studio Checklist:**
   - Play Solo → no load errors, figures show correct colors
   - Collection UI displays discovered/undiscovered correctly
   - Unboxing reveal frames figures well
   - Two-player test confirms sync

## Standing Approval

- **Publish automatically** once all gates pass (no approval needed for upload)
- **Visual check is the gate:** Only publish if figures match their mockup (silhouette, proportions, features, colors)
- **Report honestly** which figure is least exact and why

## References

- [COLLECTION_BUILD_PIPELINE.md](docs/COLLECTION_BUILD_PIPELINE.md) — Full workflow reference
- [FIGURE_COLLECTION_RUNBOOK.md](docs/FIGURE_COLLECTION_RUNBOOK.md) — Detailed SDF modeling, building, publishing
- [Catalog.luau](src/shared/Catalog.luau) — Figure registry
- [Economy.luau](src/server/Economy.luau) — Blind box pool
- [ShopTheme.luau](src/client/ShopTheme.luau) — Shop theming
```

---

## Notes for Fresh Sessions

The fresh Claude session will have:
- ✅ Access to the repository structure
- ✅ The COLLECTION_BUILD_PIPELINE.md document for reference
- ✅ The FIGURE_COLLECTION_RUNBOOK.md for detailed modeling steps
- ✅ All existing code (Catalog, Economy, ShopTheme, etc.)
- ❌ No context from this session's exploration

**Key:** The prompt should be self-contained and reference the docs instead of re-explaining everything.

---

## Before Sending

Make sure to provide:
1. **2D mockups** (paste as images or describe paths)
2. **Collection metadata:** slug, name, description, ID prefix
3. **Figure table** with names, IDs, rarities, colors
4. **Shop theme colors** from the PALETTE
5. Any special notes (render presets for pastels, glass figures, etc.)

---

## Quick Checklist for Fresh Session Startup

- [ ] User provides mockups
- [ ] User provides collection slug, name, description, ID prefix
- [ ] User provides figure table (name, ID, rarity, color)
- [ ] User provides shop theme colors
- [ ] Claude reads COLLECTION_BUILD_PIPELINE.md
- [ ] Claude starts Phase 1: Save sheets, create figures.py
- [ ] Claude previews figures and refines
- [ ] Claude publishes with `python tools/figures/publish.py`
- [ ] Claude creates UI assets and updates configs
- [ ] Claude runs verification checks
- [ ] Claude writes PRODUCTION.md and reports results

---

## Example: Concepts Collection Prompt

```
I'm building a new blind box collection. Here are the 2D mockups for the Concepts collection:
[PASTE IMAGES HERE]

Build the collection end-to-end following [COLLECTION_BUILD_PIPELINE.md](docs/COLLECTION_BUILD_PIPELINE.md).

## Collection Info

**Collection slug:** concepts
**Collection name:** Concepts
**Collection description:** Personified ideas and abstract notions
**Collection ID prefix:** concept

## Figure Details

| Figure Name | ID | Rarity | Hex Color | Notes |
|---|---|---|---|---|
| Verity | concept.verity | Common | #FFEB3B | Truth, golden smiley face |
| Falsity | concept.falsity | Uncommon | #1E90FF | Deception, blue smiley face |
| Cruelty | concept.cruelty | Rare | #E91E1E | Suffering, red sinister sphere |
| Lovity | concept.lovity | Legendary | #FF1493 | Love/affection, pink with hearts |
| Verity True Form | concept.verity-true-form | Mythical | #D4AF37 | Truth revealed, golden skeletal form |

## Shop Theme Colors

- **Primary:** #D4A520 (warm gold)
- **Secondary:** #8B6914 (deeper brown)
- **Wash:** #F5F5DC (antique white)
- **Ink:** #2F2F2F (dark gray)
- **Trim:** #C0A76D (muted gold)

## Economy Rates

These must follow the hierarchy (Common < Uncommon < Rare < Legendary < Mythical):

- **Verity** (Common): rate = 1, weight = 20
- **Falsity** (Uncommon): rate = 3, weight = 15
- **Cruelty** (Rare): rate = 7, weight = 10
- **Lovity** (Legendary): rate = 12, weight = 8
- **Verity True Form** (Mythical): rate = 18, weight = 3

## Notes

- Verity and Verity True Form are conceptually linked (transformation)
- Verity True Form is skeletal/anatomical with visible structure
- Other figures are spheres with expressive faces
- All spheres have gloss/shine materials
- Verity True Form has matte/satin appearance with metallic gold finish
```
