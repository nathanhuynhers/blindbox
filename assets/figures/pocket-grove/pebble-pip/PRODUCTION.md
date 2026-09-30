# Pebble Pip production receipt

**Ready for the first manual Studio test:** exported, re-imported, technically checked and visually compared. No Roblox upload or gameplay adoption was performed.

## Source and deliverables

- Approved source: [pebble_pip_master.blend](model/pebble_pip_master.blend), the live Blender scene open at the start of this task.
- The live scene had unsaved state. [approved_live_snapshot.blend](validation/approved_live_snapshot.blend) captures it before geometry changes and is the exact comparison source. Do not assume the older disk master contains every live change.
- The disk master was never saved over. Its SHA-256 remains `d8efe7e4d5fbc7c061a8c7e8b4d7f6996624b66e5f0e31386cc90bcb2a2e7705`.
- Working file: [pebble_pip_production.blend](model/pebble_pip_production.blend). `Scene` retains the approved source and presentation; `PebblePip_Production` contains only `EXPORT_PebblePip`; `PebblePip_GLB_Reimport` contains only the independently imported GLB.
- Import file: [pebble_pip_roblox.glb](model/pebble_pip_roblox.glb), 1,205,604 bytes. SHA-256: `524462ed3733fcc8d4cc60daf3a69ab78a6081e8ee458bd2252ba2294ad97030`.
- Registration: alias `pebble_pip`, key `Models.PocketGrove.PebblePip` in [the existing manifest](../../../manifest.json). All 21 figure nodes are required. No asset ID is assigned.

## Geometry and materials

| Measurement | Result |
| --- | ---: |
| GLB vertices | 26,556 (128 UV/normal attribute splits; geometry is unchanged) |
| GLB faces / triangles | 52,772 / 52,772 |
| Blender polygons before export triangulation | 27,080 |
| Exported mesh objects | 21 |
| Evaluated approved source triangles | 249,724 |
| Triangle reduction | 78.9% |
| Largest mesh: head | 16,128 triangles |
| Width / depth / height | 2.04149 / 1.50134 / 3.78700 units |
| Embedded albedo textures | 7 × 16×16 PNG |
| Rigs, bones, animations | 0 |

All logical names retain their original prefix with `_Export` appended to distinguish independent copies in the same Blender file. Blender adds `.001` on re-import because those names already exist; that suffix is not in the GLB.

Components: head, body, both legs, feet, arms, eyes and cheeks, back bump, mouth, stem, three leaves and three leaf veins. The source has 16 meshes and five curves. Four cameras, three lights and the ground plane belong to `PP_Presentation` and are excluded. No reference-image object or hidden construction helper was present among the figure objects.

Seven color-based Principled materials are exported (each name has `_Export` appended). Each
uses one uniform 16×16 sRGB albedo swatch connected directly to Principled Base Color; the blush
swatch also carries its approved alpha. The GLB embeds these images, so Studio receives explicit
color data rather than needing to translate a numeric material tint into a Roblox asset.

| Material | Linear RGB base color | Roughness | Alpha |
| --- | --- | ---: | ---: |
| PP_Body | 0.74118, 0.71765, 0.65882 | 0.72 | 1 |
| PP_Eyes | 0.055, 0.046, 0.038 | 0.24 | 1 |
| PP_Blush | 0.94118, 0.68627, 0.68235 | 0.62 | 0.68 |
| PP_Mouth | 0.070, 0.055, 0.045 | 0.36 | 1 |
| PP_CloverStem | 0.34, 0.54, 0.24 | 0.46 | 1 |
| PP_CloverLeaves | 0.48, 0.67, 0.33 | 0.42 | 1 |
| PP_CloverLeafSoftVein | 0.43922, 0.61961, 0.32157 | 0.46 | 1 |

These are linear shader values, not 0-255 sRGB UI colors. Metallic is zero throughout. There is
no procedural graph or lighting bake. GLB uses standard base-color textures and UV0, numeric
metallic/roughness factors, alpha blending for cheeks and optional `KHR_materials_specular`.
There are no required extensions. The source's double-sided material flags are retained.

### Roblox color fix

The first Studio import exposed a pipeline incompatibility: the original GLB contained correct
`baseColorFactor` values but **no `images`, `textures`, UVs or `baseColorTexture` entries**.
Blender honored those factors on round trip, while Studio imported the geometry with nearly white
materials. The mesh was therefore correct, but Studio had no dependable albedo asset to reproduce
the approved palette.

The production standard is now explicit flat-color textures. Each material uses a tiny uniform
sRGB PNG, a constant UV coordinate, and a white glTF base-color multiplier. This is deliberately
simple: it adds no painted detail, shading or redesign, and it follows Roblox's supported
[color-map workflow](https://create.roblox.com/docs/art/modeling/surface-appearance). The previous
factor-only GLB is retained as `validation/pebble_pip_color_factor_only.glb` for diagnosis.
[material_fix.json](validation/material_fix.json) records the encoded palette and geometry hash.

## Cleanup and fidelity

- Applied transforms to independent mesh data, preserving relative placement and proportions. Production objects have identity transforms and no modifiers.
- Kept one evaluated subdivision level on the head. Used the already dense control cages for body, limbs, eyes, cheeks, back bump and leaves. No global Decimate, remesh, boolean union or redesign.
- Converted all five curves at their original spline/bevel sampling. Added two caps to each, closing ten ends while retaining the curved surfaces.
- Recalculated consistent normals on copies and retained smooth shading. No duplicate welding was needed.
- Every final component has one connected shell and positive signed volume. No duplicate vertices at 1e-7 tolerance, duplicate faces, zero-area faces, loose/nonfinite vertices, hidden faces, open/non-manifold edges or inconsistent winding remain.
- Intentional intersecting component surfaces remain. No disconnected internal shell was found within an individual component. This is not a boolean union of the figure or proof that every triangle intersection is absent. Removing covered surfaces was unnecessary for this fidelity-first version.
- Bidirectional vertex-to-surface sampling against the evaluated master measured a maximum 0.002778-unit distance (0.073% of height), on a leaf; the head maximum is 0.000904. These are sampled distances, not a continuous Hausdorff bound.
- Differences are tessellation, ten caps, applied transforms and portable material representation. Pose, facial arrangement, colors and clover design are preserved. Four paired views show no visible design damage; minor fine-scale polygonization remains measurable.

## Scale and axes

Production Blender: **forward -Y, up +Z**, matching the master. Feet already reached Z=0, so no grounding translation was necessary. The origin retains the approved body centerline at X=0 and original Y alignment, with a ground-level pivot.

Unit scale is 1.0 with no export rescaling. Use **Studs** in Studio to test one numerical source unit as one stud: approximately **2.04149 X x 3.78700 Y x 1.50134 Z studs**.

GLB uses glTF Y-up conversion `(x,y,z) -> (x,z,-y)`: **forward +Z, up +Y**. The existing procedural figure faces Roblox -Z. Inspect Studio's resulting direction; if it faces +Z, rotate the complete Model 180 degrees about Y around the ground pivot. Do not mirror, rotate individual parts, or perform another up-axis conversion. The eventual runtime adapter must normalize forward direction once. Final Display/Shelf presentation scale remains a Studio acceptance decision.

## Validation evidence

Blender 5.2.2 LTS through Blender MCP performed inspection, preparation, export and clean-scene re-import. The installed Blender executable rendered comparisons from the preserved source and imported scenes.

- [Master inspection](validation/master_inspection.json): per-object transforms, dimensions, counts, modifiers, materials and evaluated topology.
- [Production audit](validation/production_audit.json): per-component counts, cleanup, sampled surface distances and dimensions.
- [GLB validation](validation/glb_validation.json): actual accessor counts, material payloads, re-import topology, hashes and visual receipt.
- All 21 nodes and seven materials survived. No studio node, camera, light, animation, skin, image or texture entered the GLB.
- Re-imported vertices matched production world-space vertices with measured maximum error **0.0**. Triangle counts and assignments match; imported corner normals are finite and unit length. Topology passes after triangulation.
- The production mesh geometry digest is unchanged before and after the material fix. GLB
  accessor positions re-import with maximum error **0.0**, and all 52,772 triangles remain.
- The seven embedded PNGs, seven glTF textures and seven `baseColorTexture` bindings are present.
  Base-color multipliers are white, preventing double tinting. Re-imported visible colors and
  alpha match the approved palette within the expected 8-bit PNG quantization tolerance.
- Roughness, metallic and effective specular strength survive. Blender may express specular levels
  above 0.5 using neutral tint multipliers; that is an equivalent representation.
- Eight 768x768 Cycles renders were inspected using identical original cameras, lighting, world and color management, 24 samples and denoising. Studio objects appear in comparison renders only.

| View | Approved live master | Re-imported GLB |
| --- | --- | --- |
| Front | [Master](validation/master_front.png) | [GLB](validation/reimport_front.png) |
| Three-quarter | [Master](validation/master_three_quarter.png) | [GLB](validation/reimport_three_quarter.png) |
| Side | [Master](validation/master_side.png) | [GLB](validation/reimport_side.png) |
| Back | [Master](validation/master_back.png) | [GLB](validation/reimport_back.png) |

Passed `python scripts/upload_assets.py pebble_pip --dry-run` and all 21 existing offline asset-pipeline tests. No credentials or network upload were used. No Luau or Rojo configuration changed; source formatting, type checks, game builds and Studio playtests were not run for this artifact-only task.

## First manual Studio import

Use a separate test place or unsaved copy. Controls follow the current [Roblox Importer documentation](https://create.roblox.com/docs/studio/importer).

1. Choose **File > Import**, select `model/pebble_pip_roblox.glb`, and open its preview/settings.
2. Set **Import Only As Model on**, **Merge Meshes off**, **Import as Package off**, **Anchored on**, **Set Pivot to Scene Origin on**, **Add to Workspace on**. Keep **Upload to Roblox off** for the first iteration, avoiding registration of a reusable inventory Model before approval. Choose **No Rig** if exposed; do not run avatar setup.
3. Set **Scale Unit = Studs**, scale factor 1 if exposed. Check the dimensions above and upright orientation. Review all warnings; do not accept automatic simplification. All meshes are below the documented [20,000-triangle limit](https://create.roblox.com/docs/art/modeling/specifications).
4. Import; verify the ground pivot and normalize the whole Model to -Z forward if needed. Name it `PebblePip`. Set every descendant MeshPart to `Anchored=true`, `CanCollide=false`, `CanTouch=false`, `CanQuery=false`. GLB does not encode these Roblox properties. Add no joints, Humanoid, scripts or physics simulation.
5. Inspect all 21 components from four directions, close up and at shelf size. Compare the renders. Check cheek transparency/layering, eye gloss, clover edges, normals, colors and foot contact. Preserve the approved protruding cheeks and component intersections rather than repositioning them as an import fix.
6. Test one figure, then repeated figures under game lighting and in a ViewportFrame. During later integration, verify Collection inspection, Display/Shelf fit and unboxing framing. This model is taller than the current procedural placeholder; deliberate presentation-scale acceptance is needed without redesigning UI.
7. After visual approval, manually upload/save the complete **Model** under the intended creator (manifest currently user `103346374`, or explicitly reconcile a different owner). Preserve all parts/materials and verify experience access. Record the top-level Model ID, not a child MeshId/image ID. The importer offers **Copy asset ID** for uploaded Models.

Re-import this revised GLB into Studio and verify that every MeshPart receives its color texture.
Studio acceptance of the revised color path remains pending; Blender verification cannot prove
Roblox's cheek blending or ViewportFrame shading. At 52,772 triangles and 21 MeshParts per figure,
repeated-display/mobile performance still needs measurement before further optimization.

## Existing pipeline and future integration: plan only

`AssetManifest.resolve` accepts arbitrary semantic keys, but `ModelAssets.publish` currently loads only the blind box. Recording an ID alone will not replace Pebble Pip's placeholder.

| File/reference | Later action after verifying the Model ID |
| --- | --- |
| `assets/manifest.json` / `pebble_pip` | Already prepared; retain source, required nodes and `Models.PocketGrove.PebblePip`. Raw IDs do not belong here. |
| `assets/uploads.json` | Record the verified Model ID under `Models.PocketGrove.PebblePip`, plus `assetType: Model`, GLB source/hash and actual creator. The uploader has no manual-ID registration command: reconcile the Studio import into this existing ledger without making a duplicate upload. Document Studio orientation/property adjustments in its receipt. |
| `scripts/upload_assets.py --generate` | Regenerate `src/shared/AssetIds.luau` from the ledger; never hand-edit generated Luau. |
| `src/shared/AssetManifest.luau` | Existing `resolve("Models.PocketGrove.PebblePip")` works once mapped. A typed convenience constant is optional during adoption. |
| `src/server/ModelAssets.luau` | Extend the existing loader with the figure contract, validation, failure handling and static-part sanitization; publish a template under existing `ReplicatedStorage.ProductionModels`. Preserve blind-box loading. |
| `src/shared/FigureModel.luau` / `create(id, at)` | For `grove.pebble`, clone the validated template, normalize forward/ground pivot and position at `at`. Keep the missing/failed procedural fallback. Define how already-created fallbacks refresh after asynchronous model loading. |
| `src/shared/Catalog.luau` / `grove.pebble` | Existing identity: Pebble Pip, collection `grove`, shape `round`. Use this dispatch ID; no rarity, balance, name or ID change is needed. |
| `src/server/FigureSlots.luau:68` | Existing Display/Shelf caller. Verify optional `ScaleTo(standingScale)` and bottom alignment. Do not duplicate the asset ID here. |
| `src/client/UIPreview.luau:69` | Existing Collection/selection/detail preview caller. It centers actual bounds and fits the camera; verify discovery tint and template readiness. No direct ID here. |
| `src/client/OpeningView.luau:175` | Existing unboxing caller. It centers bounds; verify reveal framing without animation redesign. No direct ID here. |
| `src/server/init.server.luau:17` | Already calls `ModelAssets.publish()`. Preserve lifecycle rather than adding a competing loader. |

Current placeholder: `FigureModel.create` reads `Catalog.byId[id]`, creates a ball body, eyes, smile and cheeks, and adds special details only for other shapes. Pebble Pip's `round` shape takes no extra branch. Factory adoption reaches server figures and client previews through established consumers.

The GLB uploader is viable after approval, but **do not run `python scripts/upload_assets.py pebble_pip` now**: without `--dry-run`, it uploads. Neither `uploads.json` nor `AssetIds.luau` was changed.

## Reuse for the next figure

Reuse the source/live-snapshot receipt, figure-only collection, per-component audits, applied
transforms and ground convention, conservative subdivision review, semantic-node manifest,
accessor inspection, clean-scene re-import and four identical-camera comparisons. For every
flat-color collectible material, export an explicit sRGB albedo swatch plus UV0 and validate that
the GLB contains `images`, `textures` and `baseColorTexture`; do not rely on `baseColorFactor`
alone. Optimization decisions remain per figure rather than copying subdivision levels blindly.

A future authorized `publish_figure(collection, figure)` can compose these gates with the current uploader and ID generation. Studio acceptance, ownership, model contracts, template readiness and rollback remain explicit steps. No new publishing framework, dependency, figure, gameplay feature or paid service was added.
