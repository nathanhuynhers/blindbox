# Asset sources

Keep reviewed source artwork in the semantic folders below. The two Collection themes
have approved production corners and emblems; see the [batch receipt](../docs/COLLECTION_ASSET_BATCH.md).
`manifest.json` also retains the planned book-open entry, whose PNG is not supplied.

```text
assets/
  ui/
    global/
    collection/
      shared/
      pocket-grove/
      tidepool-tales/
  figures/
    pocket-grove/
    tidepool-tales/
  models/
    blind-box/    # reviewed reusable GLB source models
  boxes/
  showroom/
  processed/      # optional reviewed exports; no automatic conversion
  manifest.json  # authored aliases, semantic keys, sources, creator
  uploads.json   # generated public IDs/provenance; commit with AssetIds.luau
```

See [the pipeline guide](../docs/ASSET_PIPELINE.md) for commands, replacement and recovery.

`models/blind-box/blind_box_base.glb` is the reviewed reusable Shop package geometry. It is
uploaded as one Model asset; collection pattern, emblem, name and colors remain separate runtime
theme inputs.
