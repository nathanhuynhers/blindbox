# Pocket Grove Figure Production Prompt

> Reusable one-shot execution prompt for Claude. Attach the final approved character design sheets when using this prompt.

# COMPLETE FIGURE PRODUCTION TASK

I am providing you with a set of **final approved character design sheets** for figures that need to be turned into production-ready 3D Roblox collectibles.

Your job is to take these reference sheets and execute the **entire existing figure-production pipeline**, from reference sheet → 3D reconstruction → visual QA → production build → validation → Roblox upload → runtime integration.

This is an **execution task**.

Do not just make a plan.
Do not just analyze the references.
Do not stop after producing Blender files.
Do not ask me to manually walk you through the pipeline.

The repository already contains a working runbook and tooling specifically for this process.

---

# 1. READ THE RUNBOOK FIRST

Before doing anything else, thoroughly inspect the repository and read:

`docs/FIGURE_COLLECTION_RUNBOOK.md`

Treat this as the authoritative technical procedure for the task.

Also inspect any files that the runbook references and any existing implementation necessary to understand:

- the SDF figure system
- figure definitions
- preview generation
- production builds
- validation
- GLB export
- asset registration
- Roblox uploading
- runtime figure wiring
- production receipts
- final verification

Do not invent a parallel workflow when the repository already has one.

If an older document describes a different workflow, the **current Figure Collection Runbook wins**.

---

# 2. THE PROVIDED CHARACTER SHEETS ARE THE ABSOLUTE VISUAL SOURCE OF TRUTH

This is extremely important.

The reference sheets I provide with this prompt define what the figures should look like.

**Do not use existing figures in the repository as a visual quality ceiling.**

Existing figures may be inspected to understand technical conventions, file organization, runtime requirements, naming, export constraints, or reusable tooling.

They must NOT constrain:

- geometric complexity
- silhouette complexity
- accessory complexity
- detail level
- modeling ambition
- proportions
- character construction
- number of necessary components
- overall visual fidelity

Some of these new designs may be **substantially more difficult and sophisticated** than figures previously produced by this pipeline.

That is intentional.

Do not simplify a design merely because an older figure was simpler.
Do not make a difficult character resemble an easier existing character.
Do not force every character into an established body template.
Do not lower the quality of a new figure to make it visually comparable to an older one.

### The hierarchy is:

**REFERENCE SHEET determines the art.**

**RUNBOOK determines the production process.**

**ROBLOX constraints determine the technical limits.**

Existing figures are implementation examples only.

---

# 3. RECONSTRUCT, DO NOT REDESIGN

Treat every supplied character as an approved production design.

Your job is to reconstruct it faithfully in 3D.

Do not:

- redesign it
- reinterpret it
- make it "your version"
- remove difficult features without necessity
- replace unique geometry with generic shapes simply because they are easier
- change proportions to resemble another figure
- add arbitrary details
- remove defining details
- model the surrounding environment shown on the sheet

Preserve the character's silhouette, proportions, pose, head/body relationship, face, eye shape, eye size, eye spacing, mouth, limbs, clothing, accessories, appendages, wings, leaves, horns, caps, crowns, tails, surface features, color blocking, material appearance, asymmetry, and personality.

If a character requires substantially more geometry or more sophisticated SDF construction than previous figures, **build the more sophisticated geometry**.

Difficulty is not permission to deviate from the design.

---

# 4. READ THE SHEETS LIKE A 3D MODELER

Do not model primarily from the hero render. Study the entire sheet.

Use:

**CHARACTER VIEWS → geometry and proportions**

**HERO RENDER → overall character read, silhouette and personality**

**DETAILS → construction of important features**

**PALETTE → materials and colors**

Where views disagree slightly, use the rules in the runbook and choose the most physically coherent interpretation while preserving the intended design.

Measure proportions rather than relying entirely on intuition. Pay particular attention to total height, width, depth, head and body dimensions, head/body ratio, eyes, face height, limb placement and thickness, accessory dimensions, appendage thickness, front-to-back relationships, ground contact, and silhouette landmarks.

A figure should remain recognizable from its silhouette alone.

---

# 5. MODEL AT THE HIGHEST FIDELITY PRACTICAL FOR ROBLOX

These are not temporary placeholders. They are collectible figures intended to be repeatedly viewed in unboxing reveals, Collection previews, close-up inspection, player Displays, shelves, plots, and future presentation systems.

Treat them like premium stylized collectible toys being translated into Roblox.

Prioritize:

1. silhouette accuracy
2. proportion accuracy
3. recognizable character geometry
4. face accuracy
5. major accessories
6. pose
7. secondary forms
8. color/material accuracy
9. smaller details

Use as much geometric sophistication as necessary **within the pipeline's Roblox constraints**.

Do not chase low polygon counts at the expense of visible quality. Do not create unnecessary geometry either. Spend geometry where it changes what the player actually sees.

---

# 6. USE THE EXISTING SDF SYSTEM INTELLIGENTLY

Follow the current modeling architecture described by the runbook and use the tools under `tools/figures/` and the existing SDF primitives and helpers.

However, do not treat the currently existing helper functions as the maximum vocabulary available to you.

If an approved design requires geometry that existing helpers cannot reproduce cleanly:

- compose existing SDF primitives in more sophisticated ways
- create reusable mathematical helpers
- create additional local figure helpers
- extend shared figure tooling when genuinely appropriate
- construct complex shapes from multiple coherent SDF operations

Do not abandon a defining shape simply because there is no single preexisting helper for it.

The tooling exists to serve the design, not the other way around.

Any extension should remain deterministic, maintainable, and compatible with the existing production pipeline.

---

# 7. HANDLE COMPLEX DESIGNS PROPERLY

Some supplied characters may contain significantly more challenging forms.

For complex geometry, decompose the design into logical volumes such as primary body masses, secondary masses, silhouette-changing appendages, surface overlays, inset/cut geometry, layered accessories, front-projected facial features, tubes/branches/tails, wings/fins, clothing layers, decorative geometry, and transparent/translucent components where applicable.

Solve difficult forms deliberately instead of flattening them into generic approximations.

Accessories must have enough physical thickness to survive Roblox presentation. Thin features should still read clearly from the normal gameplay camera.

---

# 8. EACH CHARACTER IS ITS OWN MODELING PROBLEM

Do not assume that because one figure uses a particular construction, another should use it too.

For every character, determine the best representation from its sheet.

The collection can share face philosophy, material response, production scale, softness, toy-like finish, and technical conventions.

But characters should retain their individual silhouettes, anatomy, proportions, geometry, accessories, and personality.

Avoid the "same base model with different accessories" effect.

---

# 9. ITERATIVE VISUAL QA IS MANDATORY

The first generated model is not automatically the final model.

For each character:

**BUILD → RENDER → COMPARE → IDENTIFY BIGGEST ERROR → FIX → RENDER AGAIN**

Repeat as necessary.

Compare generated inspection views directly against the corresponding views in the reference sheet.

Correct discrepancies in this order:

1. overall silhouette
2. proportions
3. primary volumes
4. pose
5. face
6. defining geometry
7. accessories
8. secondary details
9. materials/colors
10. polish

Do not spend time polishing tiny details while the silhouette is wrong.

A technically valid model can still fail. Passing topology/export validation does **not** mean the figure is finished. The figure must also visually resemble the approved sheet.

Be critical of your own output. If the render next to the sheet is obviously wrong, continue iterating.

---

# 10. DO NOT ARTIFICIALLY LIMIT ITERATIONS

Do not assume one or two preview passes are enough.

Simple characters may converge quickly. Complex characters may require many revisions. That is acceptable.

The objective is not to minimize tool calls. The objective is to produce the best practical reconstruction of the approved design.

---

# 11. REBUILD PEBBLE PIP

An older Pebble Pip model already exists in the repository. Replace it.

Do not preserve its geometry merely because work has already been done on it.

Treat the newly supplied Pebble Pip reference sheet exactly like every other approved reference. Reconstruct it using the current pipeline.

The previous version may be inspected for historical technical context, but it is **not a visual source of truth**.

Once the new version passes the current runbook's gates, use the established replacement/publishing mechanism so the new production model supersedes the old one.

There should ultimately be one authoritative production Pebble Pip.

---

# 12. PRODUCE THE COMPLETE COLLECTION

The target collection contains:

- Pebble Pip
- Sprout Scout
- Acorn Dot
- Mallow Cap
- Moon Moth
- Sunbeam Sprite

Use the existing catalog IDs already defined in the repository.

Do not modify their gameplay data merely as part of model production.

Create the appropriate collection-level figure definition structure required by the runbook and register every figure correctly.

---

# 13. PARALLELIZE WHERE SAFE

This is a multi-figure production job.

Use parallel execution where the work is independent and doing so is safe.

For example, independent Blender preview/final builds may be parallelized where supported.

Do not introduce race conditions in shared manifests, generated files, upload state, or other mutable shared resources.

Optimize execution time without sacrificing visual review.

---

# 14. TECHNICAL QUALITY GATES

Every final figure must satisfy all requirements defined by the current runbook, including where applicable:

- valid closed geometry
- manifold geometry
- positive volume
- no zero-area geometry
- no degenerate faces
- Roblox triangle limits
- correct part naming
- required Eyes part
- valid bounds
- correct catalog association
- correct orientation
- correct grounding
- valid materials
- embedded albedo textures
- proper transparency handling
- successful GLB export
- successful clean GLB re-import
- matching mesh/triangle counts
- no unsupported extensions
- valid production `.blend`
- validation report
- inspection renders
- beauty render

Do not weaken validation to force a figure through the pipeline. Fix the figure instead.

---

# 15. MATERIALS MUST SURVIVE ROBLOX IMPORT

Follow the material requirements discovered by the existing asset pipeline.

Do not rely on factor-only GLTF colors if the pipeline documents that Roblox imports them incorrectly. Use the established embedded albedo texture approach.

The Roblox version should preserve the intended colors, transparency, material separation, and visual readability within the capabilities of the production pipeline.

---

# 16. PUBLISH AUTOMATICALLY AFTER PASSING THE GATES

Follow the standing authorization contained in `docs/FIGURE_COLLECTION_RUNBOOK.md`.

Once a figure has passed both **VISUAL QA** and **TECHNICAL QA**, continue through the existing publishing pipeline.

Do not stop to ask me for routine upload permission.

Use the existing publisher rather than manually reproducing its responsibilities.

Allow it to handle production builds, validation, manifest registration, uploads, replacement uploads, upload records, AssetIds generation, FigureAssetEntries generation, runtime wiring, and repository checks.

Never expose or manually manipulate secrets.

Do not use shortcuts such as disabling final checks merely to finish faster.

---

# 17. VERIFY THE ENTIRE COLLECTION AS A SET

After all figures are individually complete, generate the collection lineup required by the runbook.

Evaluate the lineup as a final QA artifact.

Check relative scale, silhouette diversity, visual cohesion, character recognizability, face consistency where appropriate, material consistency, grounding, cropping, spacing, and whether any character looks noticeably unfinished compared with the others.

If the lineup exposes a weak figure, return to that figure and fix it.

The lineup is a QA stage, not merely a presentation render.

---

# 18. COMPLETE ALL REPOSITORY INTEGRATION

Follow the runbook through completion.

The task includes all required reference organization, figure definitions, production models, GLBs, validation reports, renders, manifest entries, Roblox uploads, generated asset mappings, generated figure runtime mappings, production documentation, asset pipeline documentation updates, and repository validation.

Do not manually edit generated files when the repository provides generators for them.

Do not make unrelated gameplay or UI changes.

Do not commit unless I explicitly ask you to commit.

---

# 19. CREATE THE PRODUCTION RECEIPT

Create/update the Pocket Grove production receipt according to the current runbook.

Document each figure's catalog ID, parts, triangle counts, dimensions, materials, validation status, Roblox asset ID, relevant production commands, intentional simplifications, known visual deviations, and upload status.

Document the Pebble Pip replacement clearly.

Do not hide compromises.

---

# 20. REQUIRED INDIVIDUAL MODEL IMAGES

In addition to the normal inspection renders, lineup, and final presentation, generate a **clean standalone image for every completed figure**.

This is a required deliverable.

There must be **six separate individual images**, one for each model:

- Pebble Pip
- Sprout Scout
- Acorn Dot
- Mallow Cap
- Moon Moth
- Sunbeam Sprite

These must be separate image files, not six characters combined into one image.

Each image must show the **actual completed 3D production model**, not an AI-generated reinterpretation of the character and not the original 2D reference artwork.

## Individual image presentation

Render each character as a polished collectible product image.

Use:

- the completed production model
- a consistent three-quarter hero angle
- a consistent camera and presentation style across all six figures
- the entire character visible
- enough margin around the silhouette
- no cropping of wings, ears, leaves, accessories, tails, crowns, or other appendages
- high resolution
- clean antialiasing
- high-quality lighting
- accurate production materials and colors
- a simple neutral background that does not compete with the figure
- no text
- no labels
- no UI
- no dimensions
- no reference-sheet elements
- no other characters
- no decorative scenery unless absolutely necessary for grounding

The character should occupy most of the frame while retaining comfortable breathing room around the complete silhouette.

## Consistency

All six images should feel like photographs/renders from the **same premium collectible product line**.

Keep consistent camera focal length, camera elevation, three-quarter viewing angle, lighting setup, background, framing philosophy, render quality, and color management.

Do not make one figure dramatically larger in frame simply because its proportions differ.

Adjust camera distance intelligently so every complete silhouette fits while maintaining a consistent presentation.

## Fidelity requirement

These renders are also another visual QA gate.

Before accepting each image, compare it against the corresponding approved character sheet.

If the standalone render exposes a proportion, silhouette, face, accessory, material, or construction problem that was less obvious in the technical views, **fix the model and rerender it**.

Do not hide modeling problems through camera angles.

## Output

Save the six standalone hero renders in the appropriate figure render directories using clear stable filenames such as:

- `pebble_pip_hero.png`
- `sprout_scout_hero.png`
- `acorn_dot_hero.png`
- `mallow_cap_hero.png`
- `moon_moth_hero.png`
- `sunbeam_sprite_hero.png`

If the existing runbook has a stronger naming convention for equivalent beauty/hero renders, follow the repository convention instead of creating redundant files.

At completion, surface all six individual renders to me so I can inspect every finished model independently.

**The task is not complete if I only receive a lineup image. I need an individual final image of every single production model.**

---

# 21. FINAL PRESENTATION

After the collection is finished, produce the final review presentation specified by the runbook.

For each figure, show enough information for me to compare the actual production model against its source design.

Include the appropriate:

- source sheet
- individual hero render
- front render
- three-quarter render
- side render
- back render
- palette/material information
- production statistics
- Roblox asset ID

Also show the complete collection lineup.

This presentation is for evaluating what was actually built, not for selling me on the result.

If something differs from the sheet, state it clearly.

---

# 22. BE SELF-CRITICAL

At completion, tell me which figure was the hardest to reconstruct and which figure has the largest remaining discrepancy from its reference.

Explain the specific discrepancy.

Do not automatically claim every model is perfect.

I would rather receive an accurate assessment and an excellent production batch than false confidence.

---

# 23. ONLY STOP FOR REAL BLOCKERS

You have autonomy to execute the normal production workflow.

Do not repeatedly ask me whether you should continue, render another preview, fix an obvious mismatch, build the next figure, upload after the gates pass, or replace the old Pebble Pip.

Those decisions are already covered.

Only stop if there is a genuine blocker such as:

- a required reference sheet is unavailable or unreadable
- required catalog data is missing
- an external service prevents progress
- a requested design fundamentally cannot satisfy a Roblox technical limitation without a meaningful visual compromise
- completing the task requires an unrelated gameplay/UI/economy decision
- the runbook contains a destructive ambiguity that cannot safely be resolved

Otherwise, use your judgment and continue.

---

# DEFINITION OF DONE

Do not consider the task complete simply because models were generated.

The task is complete when the current Figure Collection Runbook has been executed end-to-end for every supplied figure.

That means the approved reference sheets have become:

**faithful 3D reconstructions → validated production models → individual final renders → Roblox assets → runtime-integrated figures → documented production outputs**

The final deliverables must include:

- all completed production models
- all validation outputs
- all six individual standalone hero images
- all required orthographic/inspection renders
- the full collection lineup
- Roblox asset IDs
- runtime integration
- production documentation
- final QA results

Above everything else:

## DO NOT LET PREVIOUS FIGURES DEFINE THE QUALITY OF THESE FIGURES.

The new reference sheets define the target.

If a new design is dramatically more complex than anything currently in the repository, rise to the complexity of the reference rather than reducing the reference to the complexity of the existing models.

**Match the sheet as closely as technically practical. Use the runbook to get it into the game. Then give me a clean individual final render of every model so I can inspect exactly what was built.**
