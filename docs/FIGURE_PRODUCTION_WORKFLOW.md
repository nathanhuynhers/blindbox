# Figure Production Workflow

> For the concrete, working process used today (character sheets to uploaded, wired figures), follow
> [FIGURE_COLLECTION_RUNBOOK.md](FIGURE_COLLECTION_RUNBOOK.md). This document describes the long-term goal.

This document defines the intended end-to-end workflow for producing collectible figures for the Blind Box game.

The goal is to keep **art direction and approval human-controlled** while automating the repetitive technical work between Blender and Roblox.

## High-Level Flow

```text
ChatGPT concept
      ↓
Codex + Blender MCP
      ↓
Editable master .blend
      ↓
Review renders
      ↓
HUMAN APPROVAL
      ↓
Automated production preparation
      ↓
Roblox Blender integration / Open Cloud publishing
      ↓
Roblox asset ID
      ↓
Existing asset manifest / uploads.json
      ↓
AssetIds.luau
      ↓
Shared figure resolver
      ↓
Collection / Unboxing / Display / Shelves
```

The approved Blender master is the visual source of truth. A technically valid model must never be published automatically if it has not been visually approved.

## 1. Create the Concept

Each figure begins with an individual concept sheet.

The concept should define:

- silhouette
- proportions
- face
- pose
- accessories
- material/color palette
- personality
- rarity cues
- front, three-quarter, side, and back views when useful

The 3D pipeline should reproduce an approved design rather than ask the 3D system to invent the character.

## 2. Create the Blender Master

Codex uses Blender through Blender MCP to construct the figure.

Expected output:

```text
assets/figures/<collection>/<figure>/
  reference/
  model/
    <figure>_master.blend
  renders/
    <figure>_front.png
    <figure>_three_quarter.png
    <figure>_side.png
    <figure>_back.png
```

The master should remain editable.

Codex should use successful figures from the same collection as references for shared conventions such as:

- overall scale
- head/body proportions
- eye and mouth construction
- material response
- coordinate orientation
- naming conventions
- studio lighting
- review cameras

This does **not** mean copying an existing figure and attaching different accessories. Each figure should retain its own silhouette and personality.

## 3. Human Approval Gate

Before production/publishing, review the rendered figure.

Possible outcomes:

```text
REVISE
  → Codex returns to Blender

APPROVE
  → production pipeline may continue
```

Artistic approval is intentionally not automated.

A figure can pass every geometry test and still be visually bad. In that situation, revise or regenerate it rather than publishing it.

## 4. Prepare the Roblox Production Model

After approval, deterministic Blender tooling should prepare a production version without destructively modifying the master.

The production process should:

1. Create a production copy/collection.
2. Exclude cameras, lights, backdrop, ground, references, and construction helpers.
3. Audit vertices, faces, triangles, modifiers, transforms, dimensions, and materials.
4. Check for duplicate or accidental geometry.
5. Check normals and non-manifold geometry.
6. Remove unnecessary hidden/internal geometry.
7. Optimize only where it does not visibly damage the silhouette.
8. Normalize scale, orientation, pivot/origin, and ground contact.
9. Verify Roblox-compatible materials.
10. Validate the resulting production representation.

Visual fidelity matters more than achieving the absolute lowest polygon count.

The figure must still look good in:

- unboxing reveals
- Collection inspection
- the player's Display
- shelves
- future showrooms/inspection views

## 5. Blender Automation

Creative modeling uses Codex + Blender MCP.

Production work should eventually use reusable Blender Python scripts so it does not require manual Blender interaction.

Target structure:

```text
tools/figures/
  publish_figure.py
  validate_figure.py

  blender/
    prepare.py
    optimize.py
    export.py
    render_qa.py
```

The scripts should be able to run Blender in background/headless mode for deterministic tasks.

MCP is the creative interface.

Scripts are the production factory.

## 6. Preview vs Publish

There are two separate workflows.

### Send to Studio

Used during development to quickly inspect a model inside Roblox.

```text
Blender
  ↓
Roblox Blender integration
  ↓
Studio
  ↓
Visual inspection
```

This is a preview/testing loop.

### Publish Figure

Used after final approval.

```text
Approved master
  ↓
Production preparation
  ↓
Validation
  ↓
Roblox upload
  ↓
Asset ID
  ↓
Game registration
```

This is the production path.

## 7. Automatic Roblox Upload and Registration

The long-term publisher should use Roblox's supported asset/Open Cloud infrastructure and the repository's existing asset pipeline.

Do not create a second competing asset registry.

The publisher should:

1. Upload the prepared figure.
2. Poll the Roblox operation until processing succeeds or fails.
3. Capture the resulting asset ID.
4. Update the canonical upload/asset manifest.
5. Regenerate `AssetIds.luau`.
6. Associate the Catalog figure ID with the asset.
7. Make the asset available through the shared figure resolver.

Example:

```text
grove.pebble
      ↓
Figure model resolver
      ↓
Roblox model asset
      ↓
clone/configure
      ↓
Collection / Unboxing / Display / Shelves
```

Gameplay/UI systems should request a figure by ID. They should not know or care whether its model originally came from Blender, another modeling tool, or a placeholder.

## 8. Runtime Figure Configuration

Do not manually select every imported MeshPart to configure physics.

The shared figure loader/resolver should configure all BasePart descendants automatically:

```lua
for _, object in figure:GetDescendants() do
    if object:IsA("BasePart") then
        object.Anchored = true
        object.CanCollide = false
        object.CanTouch = false
        object.CanQuery = false
    end
end
```

The exact query behavior can be changed later if gameplay interactions require it.

This means figure authors should never need to manually toggle collision properties for every part.

## 9. One-Command Goal

The desired production interface is approximately:

```bash
python tools/figures/publish_figure.py grove pebble
```

Expected behavior:

```text
POCKET GROVE / PEBBLE PIP

Approval........................ PASS
Master.......................... PASS

Preparing Blender asset...
Geometry........................ PASS
Materials....................... PASS
Scale........................... PASS
Orientation..................... PASS
Triangle budget................. PASS

Publishing to Roblox...
Upload.......................... PASS
Asset ID........................ 123456789

Updating game...
uploads.json.................... PASS
AssetIds.luau................... PASS
Catalog mapping................. PASS

grove.pebble published successfully
```

The user should not need to:

- manually export/import every GLB
- use Import Preview for every figure
- select every MeshPart
- toggle collision properties
- copy asset IDs
- manually edit `AssetIds.luau`
- manually drag a figure onto displays or shelves

## 10. Validation and Safety Gates

Publishing must stop if required validation fails.

At minimum, check:

- figure is explicitly approved
- expected master exists
- figure geometry exists
- transforms are sane
- scale is within the collection convention
- orientation is correct
- feet/base are positioned correctly
- geometry limits are respected
- required materials are present
- no accidental studio objects are included
- upload succeeds before registration occurs

Keep the approved master untouched.

Keep Roblox/Open Cloud credentials outside Git, for example in environment variables.

Do not register an asset ID until Roblox has actually returned a successful upload result.

Placeholders should remain available as fallback for figures that do not yet have production assets.

## 11. Parallel Production

Creation and publishing can happen in parallel.

Example:

```text
TRACK A                    TRACK B

Pebble Pip publishing      Sprout Scout modeling
        ↓                           ↓
Pebble Pip integration     Sprout Scout review
        ↓                           ↓
DONE                       APPROVED
        ↓                           ↓
Sprout Scout publishing    Acorn Dot modeling
```

Once the workflow is stable, multiple modeling jobs can run concurrently using isolated Blender processes and Git worktrees.

Do not have multiple Codex agents manipulate the same interactive Blender scene simultaneously.

A future setup could use:

```text
Codex A → Blender A → Acorn Dot
Codex B → Blender B → Mallow Cap
Codex C → Blender C → Moon Moth
```

Each job should have isolated files/worktrees.

## 12. Pocket Grove Rollout

The intended rollout is:

1. **Pebble Pip**
   - First approved Blender figure.
   - Pipeline prototype.
   - Complete the full Blender → Roblox → `grove.pebble` path.

2. **Sprout Scout**
   - Use Pebble Pip as the first collection reference.
   - Tests clothing/accessories and a more complicated silhouette.
   - Ideally becomes the first figure to use the automated publisher.

3. After Pebble Pip and Sprout Scout establish conventions, parallelize:
   - Acorn Dot
   - Mallow Cap
   - Moon Moth

4. Produce **Sunbeam Sprite** after the pipeline has matured because it is the more complex Rare centerpiece.

## 13. Current Pebble Pip Lesson

Pebble Pip proved that the basic pipeline is viable:

```text
2D concept
  ↓
Codex + Blender
  ↓
approved master
  ↓
Roblox-compatible geometry
  ↓
Studio
```

The first manual Studio import was useful because it exposed real production concerns such as material transfer, orientation, scale, model hierarchy, and runtime configuration.

Pebble Pip should be used to finalize those conventions before the remaining collection is mass-produced.

## 14. Desired End State

The final workflow should feel like:

```text
ChatGPT designs
      ↓
Codex models
      ↓
Human approves
      ↓
Publish Figure
      ↓
Roblox game
```

The user's job is art direction and approval.

Codex's job is model construction and revision.

Blender's job is the 3D workshop.

Deterministic scripts handle technical preparation and validation.

Roblox publishing tooling handles upload and registration.

The game's shared figure resolver handles Collection, unboxing, Display, Shelves, and future systems.

The pipeline should make adding the tenth or fiftieth figure substantially easier than adding the first.
