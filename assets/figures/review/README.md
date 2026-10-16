# Painted review figures (not in the catalog)

Untextured Tripo GLBs colored with `tools/figures/reference_paint.py` from each figure's hero image
in `assets/reference_models/`. They are kept for review only: the collections aren't in
`src/shared/Catalog.luau`, and nothing here is uploaded or wired. Each folder holds the painted GLB
(new UV0 and a 2048 px albedo; hidden sides are inferred), `paint.json` (fit and edge scores), the flat
hero view, and lit three-quarter and back views. To ship one, add the catalog entry, then run
`face_patch.py`, `texture_prepare.py` and `external.py` as in docs/FIGURE_TEXTURING.md.
