# Collection Build Pipeline

Complete reference for building a new collection from 2D mockups to live in-game.

## Quick Reference

For detailed figure modeling: see [FIGURE_COLLECTION_RUNBOOK.md](FIGURE_COLLECTION_RUNBOOK.md) (steps 1–6 below reference it).

---

## Pipeline Phases

### Phase 1: Setup & Reference Organization
- **Save reference sheets** → `assets/figures/<collection-slug>/<figure-slug>/reference/<figure_snake>_sheet.webp`
- **Validate catalog entries** in [Catalog.luau](../src/shared/Catalog.luau)
  - Confirm figure IDs exist (e.g., `tide.bubble`)
  - If new, must be added to catalog (authorization required)
- **Create `figures.py`** → `assets/figures/<collection-slug>/figures.py`
  - Copy [Tidepool Tales template](../assets/figures/tidepool-tales/figures.py)
  - Define FIGURES dict with SDF-based figure definitions

### Phase 2: Figure Modeling (SDF-based, Code-Driven)
**→ See [FIGURE_COLLECTION_RUNBOOK.md §3](FIGURE_COLLECTION_RUNBOOK.md#3-how-the-figures-are-modeled)**

Sculpt each figure as signed-distance fields (SDFs) in code:
- **Coordinates:** +Z up, figure faces −Y, character's left is +X
- **Height:** ~2.2–3.4 studs per collection
- **Materials:** Use `Mat` class (color, rough, metal, alpha)
- **Components:** Use `Comp` class (mesh parts, voxel size ~0.009–0.012, <20k tris/part)
- **Measurement:** Extract proportions from CHARACTER VIEWS; use helper functions like `face()`, `overlay()`

### Phase 3: Preview Loop & Refinement
**→ See [FIGURE_COLLECTION_RUNBOOK.md §4](FIGURE_COLLECTION_RUNBOOK.md#4-preview-loop)**

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- <collection> <figure> preview
```

- Renders 420px views (front/3/4/side/back) to `build/figures/<collection>/preview/`
- Compare against reference sheets: silhouette → proportions → features → colors
- Iterate until match

### Phase 4: Build, Validate & Publish
**→ See [FIGURE_COLLECTION_RUNBOOK.md §5](FIGURE_COLLECTION_RUNBOOK.md#5-build-publish-and-wire-up-one-command)**

When previews match sheets:
```bash
python tools/figures/publish.py <collection> <figure> [<figure> ...] --build
```

**Automatically:**
1. Builds production `.blend` and GLB (parallel, ~5–20 min for collection)
2. Validates: closed meshes, manifold, zero-area-free, positive-volume, <20k tris/part
3. Registers in `assets/manifest.json` (catalog ID → required parts)
4. Uploads GLBs via Roblox API (`ROBLOX_API_KEY` from `.env`)
5. Generates:
   - `src/shared/AssetIds.luau` (catalog → asset ID)
   - `src/shared/FigureAssetEntries.luau` (runtime model data)
6. Runs verification: StyLua, Selene, Luau, pipeline tests, Rojo build

### Phase 5: Shop & Collection UI Setup

#### Add UI Assets
Create in Photoshop/Figma from mockups:
- **Emblem:** `assets/ui/collection/<collection>/<collection>_emblem.png`
- **Shop pattern:** `assets/ui/shop/<collection>/<collection>_shop_pattern.png`
- **Corner graphics** (4 files): top-left, top-right, bottom-left, bottom-right
  - Path: `assets/ui/collection/<collection>/<collection>_corner_{top_left,top_right,bottom_left,bottom_right}.png`
  - See README.md in those directories for specs

#### Update [AssetManifest.luau](../src/shared/AssetManifest.luau)
```lua
Manifest.Collection.<NewCollectionPascal> = {
    Emblem = "Collection.<NewCollectionPascal>.Emblem",
    ShopPattern = "Collection.<NewCollectionPascal>.ShopPattern",
    CornerTopLeft = "Collection.<NewCollectionPascal>.CornerTopLeft",
    CornerTopRight = "Collection.<NewCollectionPascal>.CornerTopRight",
    CornerBottomLeft = "Collection.<NewCollectionPascal>.CornerBottomLeft",
    CornerBottomRight = "Collection.<NewCollectionPascal>.CornerBottomRight",
}
```

#### Update [ShopTheme.luau](../src/client/ShopTheme.luau)
```lua
ShopTheme.collections.<collection> = {
    collectionId = "<collection>",
    emblemKey = Manifest.Collection.<NewCollection>.Emblem,
    patternKey = Manifest.Collection.<NewCollection>.ShopPattern,
    primary = Color3.fromRGB(...),    -- from PALETTE
    secondary = Color3.fromRGB(...),
    wash = Color3.fromRGB(...),
    ink = Color3.fromRGB(...),
    trim = Color3.fromRGB(...),
}
```

### Phase 6: Economy Configuration

Follow [economy collection onboarding](ECONOMY_COLLECTION_ONBOARDING.md).
Select a reusable economic tier, bucket profile and independent pity group in
[Economy.luau](../src/server/Economy.luau), then add explicit figure units and weights:
```lua
{ id = "<collection>.<figure>", units = X, weight = Y },
```

**Normalized income units:** Common 0.55-0.70; Uncommon 1.20-1.40; Rare 2.80-3.20;
Legendary 7.50-8.50; Mythical 22. Actual Coins/sec is derived from the collection tier.

**Weights:** Relative shares within the same rarity in the selected collection. Rarity bucket
percentages and soft pity are separate profiles validated by CollectionEconomy.

### Phase 7: Catalog Updates (If Needed)

If figures are new to [Catalog.luau](../src/shared/Catalog.luau), add entries:
```lua
{
    id = "<collection>.<figure>",
    name = "<Figure Name>",
    collection = "<collection>",
    rarity = "<Rarity>",
    color = Color3.fromRGB(...),
    shape = "<descriptor>",
}
```

Also add collection if needed:
```lua
{
    id = "<collection>",
    name = "<Collection Name>",
    description = "<tagline>",
    color = Color3.fromRGB(...),
}
```

### Phase 8: Verification & Documentation
**→ See [FIGURE_COLLECTION_RUNBOOK.md §6–7](FIGURE_COLLECTION_RUNBOOK.md#6-present-the-result)**

- **Write receipt:** `assets/figures/<collection>/PRODUCTION.md`
  - Per-figure: parts, triangles, size
  - Build command, geometry/material checks
  - Known differences from sheets
  - Asset ID table
  
- **Studio playtest checklist** (user runs):
  1. Play Solo → no load errors on figures
  2. Figures face player, stand correctly, colors correct
  3. Collection shows discovered in color, undiscovered as grey silhouettes
  4. Unboxing reveal frames each figure well
  5. Two-player test confirms sync

- **Create Design canvas** (reference: [Tidepool Tales](https://claude.ai/artifact/QBkNESqAC9X8UXNtLiYz4E))
  - Lineup + per-figure stats
  - Per-figure: beauty render, 4 views, sheet, mesh/tri counts, palette swatches
  - Upload WebP renders as assets

---

## Key Systems

| System | Reference |
|--------|-----------|
| **Figure modeling** | [FIGURE_COLLECTION_RUNBOOK.md](FIGURE_COLLECTION_RUNBOOK.md) |
| **Asset pipeline** | [ASSET_PIPELINE.md](ASSET_PIPELINE.md) |
| **Economy & rates** | [ECONOMY.md](ECONOMY.md) |
| **Rarity hierarchy** | [RARITY.md](RARITY.md) |
| **Shop UI** | [SHOP_UI.md](SHOP_UI.md) |
| **Runtime figure loading** | `src/server/ModelAssets.luau`, `src/shared/FigureModel.luau` |

---

## Files You'll Create/Edit

```
assets/figures/<collection>/
├── figures.py                          ← SDF definitions
├── <figure>/reference/<figure>_sheet.webp
├── <figure>/model/                     ← Auto-generated by publish.py
│   ├── <figure>_roblox.glb
│   ├── <figure>_production.blend
│   └── validation/
└── PRODUCTION.md                       ← Receipt (phase 8)

assets/ui/collection/<collection>/
├── <collection>_emblem.png
└── <collection>_corner_*.png (4 files)

assets/ui/shop/<collection>/
└── <collection>_shop_pattern.png

src/shared/
├── Catalog.luau                        ← Add figures/collection if needed
└── AssetManifest.luau                  ← Add emblem/pattern keys

src/client/
└── ShopTheme.luau                      ← Add collection theme

src/server/
└── Economy.luau                        ← Add figure entries
```

---

## Standing Approval

When the user provides 2D mockups for figures, build them from start to finish following this pipeline. Publish automatically once every gate passes. Do not stop to ask for design approval or upload permission (granted 2026-09-29).

Your visual check is the approval gate: only publish figures that match their sheet (silhouette, proportions, face, accessories, colors).

---

## Quick Command Reference

```bash
# Preview single figure
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- <collection> <figure> preview

# Build & publish all figures in collection
python tools/figures/publish.py <collection> --build

# Build & publish specific figures
python tools/figures/publish.py <collection> <figure> <figure> --build

# Render lineup
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/figures/build.py -- <collection> lineup

# Format/lint/build
stylua src
selene src
rojo build default.project.json -o RobloxWorkspace.rbxlx
```

---

## References

- [FIGURE_COLLECTION_RUNBOOK.md](FIGURE_COLLECTION_RUNBOOK.md) — Detailed modeling, building, publishing workflow
- [ASSET_PIPELINE.md](ASSET_PIPELINE.md) — Asset registration and upload
- [ECONOMY.md](ECONOMY.md) — Blind box pool configuration
- [Catalog.luau](../src/shared/Catalog.luau) — Figure and collection registry
