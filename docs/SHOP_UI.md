# Scalable blind-box Shop

The Shop is a neutral reusable presentation, with collection identity limited to cards,
product skin, emblems and progress/purchase accents. No world, Collection screen, figures,
economy, persistence, purchase protocol or opening behavior is changed by this reconstruction.

## Composition and palette

`ShopStyle` owns the local palette: surface `#F7EEDC`, elevated `#FFF9EE`, secondary
`#EFE1C5`, light wood `#C9965A`, trim `#8A5A32`, gold `#D8AD5A`, ink `#493426`,
secondary text `#796657`. Shared UITheme and other screens retain their own styling.

The giant background slab is gone, including the Shop-only host shadow. A compact cream
navigation panel, light shelf detail, neutral product stage and ivory information panel
provide the structure while leaving the world visible. Blind Boxes has a gold selected
treatment. The three unavailable categories remain labeled and disabled on desktop;
compact navigation retains Shop and Blind Boxes without crowding the mobile header.

`ShopCollectionCard` is the same 240 x 118 component for every catalog entry: emblem,
name, low-opacity tiled pattern, discovery count and slim progress. Selection changes
outline/shadow, never size. There are no miniature fake boxes or fake future collections.
The 180px selector starts at the left and scrolls horizontally. Touch scrolling, pointer
browse buttons and gamepad selection-follow scrolling share the same catalog-driven list.

`ShopProductStage` provides one neutral arch, low two-layer pedestal, product plaque,
symmetrical navigation controls and the actual `BlindBoxPreview`. Desktop uses a 37% hero
column beside the information column. Smaller widths stack the sections on a vertical
scrolling canvas. Short/mobile screens use compact navigation. Desktop product height is
bounded at 400–448px so tall windows do not introduce a huge empty details panel.

`ShopLayout.details` coordinates the editorial header, progress, possible figures, rarity
odds and purchase cluster. Wide columns place figures and odds side by side. Intermediate
columns put odds beside purchase; small screens stack them. All six figures fit a single
desktop row; narrow strips can scroll. Discovered portraits and undiscovered silhouettes
reuse `UIPreview`. No new figure art is created.

## Data and behavior

`ShopScreen` creates cards and figures from Catalog; `ShopState` derives unique discovery
progress and grouped rarity odds from the authoritative snapshot. Odds are not independently
hardcoded. One-member rarities omit "each"; another rarity can use the same row component.

`ShopTheme` supplies emblem/pattern keys, primary/secondary/wash/ink colors and trim.
Future catalog collections use the same card, stage, model, camera and layout. An absent
theme resolves to the existing neutral fallback. Add the catalog data and theme record;
no per-collection Shop component or environment is needed.

Quantity stays fixed at **1 Box** because the server supports one box per request. Buy
uses the existing selected-collection intent and pending/funds gate. Insufficient funds
show the shortfall; a pending request shows "Please wait...". Daily remains secondary.
The client request coordinator, server validation and opening handoff are unchanged.

## Actual 3D product

`Models.BlindBoxBase` still resolves to **79870100381887**, owned by the configured creator
user **103346374**. No re-upload or source geometry changes were made in this reconstruction.

Path: generated AssetIds → AssetManifest → server `ModelAssets` / InsertService.LoadAsset
→ `ReplicatedStorage.ProductionModels.BlindBoxBase` → client clone in
`Shop.ShopContent.ProductStage.BlindBoxPreview.ProductViewport.Scene.ProductModel`.
One sanitized template is published; one clone is reused per preview.

`BlindBoxModel` binds actual BaseParts under semantic objects, including importer-created
Model wrappers. Organizational `BlindBox_Root` naming is not required. Empty/missing
semantic geometry fails with a specific reason. The server publishes an expected part
count; the client waits for full geometry, including late replication attributes.

`BlindBoxSkin` uses the existing approved pattern Textures on front/side/top panels and
the existing emblem as a Decal on EmblemBadge. It removes previous skin layers and imported
SurfaceAppearance layers that could mask tint; the source GLB has no image textures.
The geometry and mesh IDs are unchanged. Body, cap, trim, nameplate and accent-band colors
come from one selected theme. Original artwork pixels are not recolored.

The previous SurfaceGui emblem/name path is replaced: the emblem uses a viewport-compatible
Decal, and catalog name text is projected onto the plate in screen space for the fixed
camera. This text projection is an approximation, not a perspective-warped texture.
Faces and camera axes derive from semantic surface positions and local part transforms,
rather than assuming importer-preserved axes. The bounds-fit camera shows front, right
and top, with shared warm neutral ambient/key lighting. No per-frame work is needed. Its
`1.02` framing margin makes the product 6.9% larger than the prior `1.09` margin while
retaining the same angle and automatic fit.

The Shop keeps a transparent root. `BackgroundTreatment` places a warm neutral 38% overlay
below the UI and enables an 8px native BlurEffect on the 3D world while Shop is open. It uses
no transition, so reduced-motion mode introduces no extra animation. Leaving Shop, entering
the opening presentation, or destroying the interface disables or removes the treatment.

Mesh/art preload must succeed before showing the product; neutral loading/unavailable
presentation is mutually exclusive with the viewport and plate title. Timers, preload tasks,
connections and clone ownership are cleaned up through UIScope. Snapshot updates do not
reclone/re-skin the same selected collection. Collection changes replace skin layers and
invalidate old asynchronous load results. Loading/replication is bounded; failures expose
`PreviewStatus` and `PreviewReason`. Server reasons are on `BlindBoxBaseReason`.

## Verification status and Studio checklist

Open Cloud metadata inspection confirmed the mapped model is Active. The read-only asset
delivery request returned HTTP 403 (`0: Forbidden`), so this environment could not download
and inspect the actual Roblox-imported hierarchy. No permissions were changed. The provided
Studio screenshot demonstrates loaded geometry; it does not establish which runtime issue
caused any earlier unavailable message. The structural, branding and timing defects above
are fixed in code; actual rendering and imported hierarchy still require Studio verification.

`scripts/inspect_blind_box.py` repeats the read-only metadata/delivery inspection without
uploading or changing permissions. `tests/StudioShop.client.luau` prints the runtime hierarchy
and status/reason, then requires a Ready preview, matching skin and correct camera quadrant.
It does not silently pass an unavailable preview and never submits a purchase.

In a fresh Studio play session:

1. Open Shop and run the client StudioShop check; repeat after selecting Tidepool Tales.
2. Confirm emblems/patterns, readable plate names, front/right/top framing, neutral lighting,
   no clipping, no duplicated skin layers and no fallback alongside the model.
3. Check desktop and phone/short-landscape sizes, card selection/navigation, six figures,
   title/progress readability and purchase controls. Compare visually to the approved mockup.
4. Check owned/unknown figures, funds shortfall, pending Buy, successful opening handoff and
   daily claim using normal gameplay. Close/reopen and switch collections repeatedly.
5. If unavailable, capture `BlindBoxBaseStatus`/`BlindBoxBaseReason`, `PreviewStatus`/
   `PreviewReason` and Studio Output. A Studio permission failure requires its exact error;
   the separate delivery API 403 alone does not prove InsertService is blocked.

Automated domain, layout, semantic-binding, lint, type diagnostics and builds do not prove
visual quality. Native Studio visual/play verification has not been run by the coding agent.
