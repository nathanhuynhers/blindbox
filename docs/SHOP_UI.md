# Shop

**Superseded by the UI redesign.** The design source is [ui-redesign/BRIEF.md](ui-redesign/BRIEF.md);
the module map, behaviour notes, economy merge points and Studio checklist are in
[ui-redesign/IMPLEMENTATION.md](ui-redesign/IMPLEMENTATION.md). The implementation this file
described (and its modules) was removed on `claude/ui-redesign`; see git history for the old text.

The kept 3D box preview is still described here.

## Actual 3D product

`Models.BlindBoxBase` still resolves to **79870100381887**, owned by the configured creator
user **103346374**. No re-upload or source geometry changes were made in this reconstruction.

Path: generated AssetIds → AssetManifest → server `ModelAssets` / InsertService.LoadAsset
→ `ReplicatedStorage.ProductionModels.BlindBoxBase` → client clone in
`Shop…Product.ProductStage.BlindBoxPreview.ProductViewport.Scene.ProductModel`.
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

The old blur/warm Shop overlay (`BackgroundTreatment`) is gone; one shared world dim sits
behind every open screen.

Mesh/art preload must succeed before showing the product; neutral loading/unavailable
presentation is mutually exclusive with the viewport and plate title. Timers, preload tasks,
connections and clone ownership are cleaned up through UIScope. Snapshot updates do not
reclone/re-skin the same selected collection. Collection changes replace skin layers and
invalidate old asynchronous load results. Loading/replication is bounded; failures expose
`PreviewStatus` and `PreviewReason`. Server reasons are on `BlindBoxBaseReason`.
