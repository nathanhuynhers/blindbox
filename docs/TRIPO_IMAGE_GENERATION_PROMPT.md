# ChatGPT Image Generation Prompt — Tripo AI Figure References

Use this reusable prompt when creating original collectible-character concept images in ChatGPT for the **Blind Box Roblox game**. The images are intended to be fed to **Tripo AI Image-to-3D**, then exported and processed for Roblox.

This is the **single-character / batch collection image workflow**, separate from [ORIGINAL_CHARACTER_REFERENCE_PROMPT.md](ORIGINAL_CHARACTER_REFERENCE_PROMPT.md), which makes detailed human-readable multi-view reference sheets for the older procedural modeling workflow.

## How to use

1. Copy the prompt below into a ChatGPT conversation.
2. Provide the **collection name, theme, and character roster**, including each character's name, rarity, colors, and distinctive features.
3. Request a manageable batch of images. One prompt establishes the style and production rules; it does **not** guarantee that all 200 images can be generated in one response.
4. Save each **single-character image** using a consistent, descriptive name, for example `moonrace_cat.png`.
5. Upload **only a single character image** to Tripo's single-image generator. If ChatGPT outputs multiple characters in separate panels, crop those panels into individual images **before** using Tripo. Do not upload the entire collage as one image.
6. For complex figures that need more predictable side and rear geometry, prepare separate consistent views and use Tripo's multiview workflow. Keep the original high-detail images as visual references.

## Reusable ChatGPT image prompt

> Replace the character roster following this prompt with your own planned collection.

```text
Create a cohesive collection of premium designer blind-box figurines for my Roblox collectible game.

Use the character names and concepts I provide.

Each character must have a distinctive silhouette, charming proportions, expressive face, and polished vinyl/resin collectible aesthetic. Maintain consistent artistic quality across the entire collection while ensuring that every figure feels unique.

Generate clean, high-resolution 3D-style concept renders specifically optimized for Tripo AI image-to-3D reconstruction.

Production requirements:
- One complete character per output image.
- Three-quarter front view.
- Entire character visible, including all permanently attached accessories.
- Centered on a uniform light neutral background.
- No text, labels, additional characters, floor stands, or scenery.
- Strong dimensional forms and clear material separation.
- Rounded, sculptable anatomy and accessories with believable thickness.
- Attractive texture and ornamental details without excessive visual clutter.
- Preserve high-end collectible quality rather than simplifying everything for Roblox.

Prioritize beautiful, recognizable characters that will remain appealing from multiple viewing angles.

Use consistent naming and generate the requested figures in manageable batches. Do not combine unrelated characters into a single image intended for Tripo. If multiple figures share an output sheet for efficient generation, arrange them in separate, clearly crop-able panels.

Do not automatically generate extra alternatives. Focus on distinct, production-worthy designs.

Begin with the character roster I provide.
```

## Collection details to append

```text
Collection name: [NAME]
Collection theme / art direction: [THEME]
Number of figures in this batch: [COUNT]

Character roster:
1. [NAME] | [RARITY] | [COLORS] | [FEATURES / PERSONALITY]
2. [NAME] | [RARITY] | [COLORS] | [FEATURES / PERSONALITY]
3. ...

Keep every design original, visually distinctive, and cohesive as a collection.
```

## Downstream Roblox reminder

**Do not simplify the concept art to a fixed per-figure triangle count.** Preserve the important silhouette, eyes, accessories, and surface detail in the reference. Roblox's 20,000-triangle constraint applies **per MeshPart**, not to the entire character model; the downstream Blender/Roblox pipeline should optimize and, where useful, split imported Tripo geometry into multiple MeshParts while preserving textured detail and testing actual gameplay performance.

This document is a prompt library asset only. It does not change the current figure build/publish pipeline, import behavior, catalog, or live game.
