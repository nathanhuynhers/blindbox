# Figure Production Workflow

The implemented factory is `tools/figures/build.py` → `publish.py`, with the existing asset
manifest, uploaded IDs and figure resolver. Follow [the collection runbook](FIGURE_COLLECTION_RUNBOOK.md)
for exact commands, APIs, gates and the standing authorization for approved reference sheets.
This workflow does not authorize new collections/gameplay, replacement assets during infrastructure
tests, or deployment of the live place.

## Reference to production

1. Receive an approved reference sheet. Record proportions, silhouette, expression, layered clothing,
   hair flow, palette and permanent accessories. Use the catalog identity already authorized by the user.
2. Choose geometry per feature. SDFs remain effective for rounded bodies, organic joints and surface
   relief. Use transported mesh sweeps for locks/trim/limbs, hollow lofts for garments, and native mesh
   factories for hard surfaces or bespoke topology. Design decisions stay in collection `figures.py`.
3. Allocate **component** detail budgets. Start at medium; reserve high for the face, hair edges and
   readable attachments. Supply explicit SDF bounds and minimum thickness for thin geometry. Avoid
   making every body part high resolution. Keep one material per MeshPart and below 20,000 triangles.
4. Assign shared material presets. Flat color is still the cheapest robust option. Opt into embedded
   PBR only when gloss, fabric/paint detail, metal or sculpted normal maps contribute visibly. Share
   maps/materials; prefer 256–512px. Bake unsupported procedural detail into portable maps as needed.
5. Run `preview` and iterate against the reference: silhouette/proportions first, then face, hair,
   outfit and colors. Keep all construction/editable choices in the definition or mesh factory.
6. Run `final`. The builder prepares meshes, checks bounded optimization loss, saves a clean
   production blend, exports core GLB and reimports it. It creates separate production fidelity and
   beauty contact sheets at matching measured framing and four standard views.
7. Review **both** sheets against the reference. A clean report proves only its measured technical
   properties. Fix loss, seams, floating parts, intersections, wrong expressions or unreadable features
   before publishing. There is no automated artistic similarity score.
8. Publish only within the authorized figure-production scope and after all gates pass. The existing
   publisher gates the report/binary hash, updates the canonical manifest, uploads through the existing
   uploader, captures Roblox IDs and regenerates runtime entries. Do not create another registry.
9. Compare the actual Roblox asset on Collection, opening, Display and Shelves, including undiscovered
   silhouettes and visitor views. Record graphics level, lighting and desktop/landscape phone viewport
   per [the device matrix](qa/DEVICE_TEST_MATRIX.md). Report unobserved tests as **NOT RUN**.

## Why the hybrid path exists

The original factory sampled all shapes through a scalar distance field, discovered bounds at
0.04-stud spacing, and uniformly collapsed meshes to a per-part budget. It worked well for large
rounded figures. Thin disconnected details could evade discovery; small locks, garment rims and
facial relief could vanish during sampling, speck cleanup or decimation. Shader garnish made the
source Blender inspection views look different from the uploaded asset.

Those are factory constraints. Incorrect anatomy, absent clothing folds, primitive-looking locks,
poor reference measurements and unresolved intersections are also **definition** problems; increasing
voxel resolution cannot repair them. New components offer explicit bounds, declared thickness/islands,
small-feature preservation, sampled optimization limits and alternate topology without replacing SDFs
or rewriting old definitions. Approximate/strongly warped fields still need conservative bounds and
careful sampling; the block evaluator assumes distance-like behavior.

`sweep` transports its elliptical section along a sampled curve, avoiding arbitrary frame twists.
`hair_lock` exposes independent width/depth profiles with rounded tapered ends; `braid` joins three
intentional overlapping strands. `garment_loft` makes closed inner/outer surfaces with pleats and rims.
They do not solve every hairstyle, posed sleeve, open jacket, hand or shoe. Use `MeshData` or a native
Blender factory for those forms, and keep attached accessories separate when their budgets differ.

## Export and presentation contract

- Coordinates stay one unit per stud, +Z up, front −Y. GLB exports +Y up; the existing runtime grounds,
  orients from `<Figure>_Eyes`, validates proportions and scales figures exactly as before.
- Production contains only the root and declared meshes. Modifiers are evaluated, geometry triangulated,
  normals exported, and UVs/materials preserved. Exporter options are checked explicitly; necessary options
  are no longer silently discarded on version mismatch.
- Each material carries an embedded albedo texture. Optional roughness/metalness use core glTF's packed
  G/B channels; normals are tangent-space OpenGL. Alpha is explicit blend/albedo alpha. Unsupported glTF
  extensions remain forbidden. No Blender transmission/refraction/iridescence is promised in Roblox.
- **Beauty Preview** uses source geometry and optional render garnish/collection color management.
  **Production Fidelity Preview** uses the actual exported/reimported GLB, fixed neutral color management
  and no garnish. Neither is an actual Roblox screenshot. The binary hash ties fidelity renders to the
  report; the publisher rejects a changed binary until it is rebuilt and reviewed.
- The loader preserves imported `SurfaceAppearance`. It does not invent map IDs, modify global lighting
  or override every mesh's material/render fidelity. Uniform runtime glass transparency remains 0.55.
  `UIPreview` hides/restores PBR surfaces alongside TextureID so undiscovered figures remain grey.
- Workspace and ViewportFrame use different lighting; gloss, normal detail and alpha need inspection
  at gameplay scale. The [Roblox PBR guide](https://create.roblox.com/docs/art/modeling/surface-appearance)
  and [SurfaceAppearance reference](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance)
  describe map/color-space, reflection and graphics-quality constraints. Core GLB conformance alone
  cannot establish how Studio/Open Cloud imports a particular PBR asset.

## Reliable gates and their limits

Schema-2 reports extend existing closed/manifold/positive-volume/triangle-count gates with finite
vertices/UVs, duplicate faces, per-surface orientation, declared connected-island counts, embedded
PBR data, UV/normal attributes, sampled optimization loss, and reimport comparisons of surface,
bounds, volume, topology, UV corners and shading normals. Old reports and collection-local Mat/Comp
classes are supported. Split budgets or adjust topology when optimization loses a protected detail.

Not all intersections are defects: hair layers, eyelids, garment trim and braids intentionally overlap.
The factory does not reject every intersection or claim to certify garment fit. Inspect front, 3/4,
side/back and close views. Minimum thickness is authored, not inferred; a feature never defined or
never sampled cannot be recovered by a reimport check. Surface-distance sampling is not a mathematical
proof that every silhouette or thin feature survived. UV unwrapping also does not prove a seam-free bake.

## Infrastructure verification receipt (October 11, 2026)

This upgrade uses synthetic swatches only, confined to ignored `build/`: a rounded SDF, a 0.024-stud
surface skin, a curved tapered lock, a pleated hollow garment, a native beveled mesh and a three-strand
braid. No existing figure was rebuilt, visually redesigned, uploaded or replaced.

- **PASS:** six-part synthetic GLB (18,134 triangles), embedded portable material maps, four-angle
  exported/reimported fidelity and beauty renders, unchanged measured geometry/UVs/normals after import.
- **PASS:** geometry/material unit tests, native/legacy compatibility fixtures, procedural color/data-map
  baking, high-to-low normal baking, excessive-decimation and clipping rejection, offline publish/GLB/
  asset-pipeline regression tests; pinned formatter, Selene, Rojo and targeted Luau LSP checks.
- **NOT RUN:** actual Roblox visual/PBR import, discovered/silhouette interaction and material-lifetime
  checks, desktop/landscape phone and multiplayer acceptance. Studio MCP listed no connected instances.
  Apply the runbook checklist to the next authorized reference-based collection.
- **N/A:** reference likeness for these technical swatches, production asset publication, live deployment,
  economy/progression and persistence changes.

Implemented; Roblox visual and runtime verification pending. The next character references still require
artistic modeling/iteration and visual acceptance; this upgrade provides the reusable tools, not an
automatic guarantee of high-fidelity reconstruction from arbitrary artwork.
