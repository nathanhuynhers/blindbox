# Standard rarity architecture

The supported hierarchy is **Common < Uncommon < Rare < Legendary < Mythical**.
Mythical is the highest standard tier. Support does not imply obtainable content: the twelve
live figures still use Common, Uncommon and Rare. Sunbeam Sprite and Pearl Regent remain Rare.
No figures, rates, weights, prices or live probabilities were added or changed by this integration.

## Canonical definitions and audit

`src/shared/Rarity.luau` owns the closed `Id` union, frozen ordered list, rank/comparator,
strict parse/validation and public color identities. Invalid labels are rejected by validation;
the Common fallback in presentation helpers does not make arbitrary strings valid rarities.
Definitions include primary, accent and highlight colors plus readable ink/on-tint colors.

| Audited system | Integration / retained behavior |
| --- | --- |
| Types / Catalog | Figure rarity uses `Rarity.Id`; startup validates every figure. Existing content is unchanged. |
| Server Rules / Economy | Explicit per-figure rates and weights remain server-only. Original three numeric rate bands remain enforced; every populated higher tier must earn more than every populated lower tier. No default Legendary/Mythical rate or weight exists. |
| ShopState / ShopLayout / ShopScreen | Odds use canonical order, show only tiers with actual figures, and size the panel to the row count. No empty or invented high-tier odds. |
| CollectionStyle / CollectionControls / CollectionAssets | Canonical badge palette and contrast colors, optional artwork slots for every supported tier. FigureCard and FigureDetails consume these existing helpers. |
| UITheme / OpeningView | Readable canonical ink on ordinary UI; opening result uses its configured presentation label and lighter text on the dark stage. |
| Inventory / Display / Shelves / completion | Existing paths use catalog figure IDs, rates, ownership and discovery counts, not a three-tier switch. No persistence migration or fake completion entries. |
| OpeningConfig / State / Flight / Cinematic / Effects / Audio | All five profiles use the existing phase machine and lifecycle; optional signature data drives the new effects. No rarity-name branches in controllers. |
| Development fixture | Studio-only presentation override; actual figure/result/catalog metadata remain unchanged. No requests or grants. |

There is no rarity-weight table. `Economy.entries` supplies each figure's explicit weight;
the server divides by the selected collection's total. Present collections still contain
three Commons at 20% each, two Uncommons at 15% each and one Rare at 10%.

## Presentation configuration

| Tier | Identity | Transition | Recognition hold | Silhouette |
| --- | --- | --- | --- | --- |
| Common | Mint / cream, restrained taper | 0.19s | 0.25s | 0.35s |
| Uncommon | Lavender, wider aura and glints | 0.22s | 0.35s | 0.48s |
| Rare | Warm gold, stronger pulse and ring | 0.25s | 0.55s | 0.65s |
| Legendary | Crimson / orange-gold, two separated pulses, gold inner trail | 0.30s | 0.70s | 0.80s |
| Mythical | Pink-violet / pearl / cyan, quiet compression beat, spectral rim and three trail layers | 0.38s | 0.90s | 0.95s |

Legendary has a radiant second pulse, crimson/gold impact layers and a warm result halo.
Mythical briefly hushes emitters and flight audio, then brings in a pearl core, cyan highlight
and slowly drifting spectral rim. Its impact layers are pink-violet, cyan and pearl; the result
has a cyan edge and sparse pearl/cyan dust. Neither profile cycles hues. Both retain Rare's
particle/Bloom budgets and the shared 1.8 direct-light ceiling; their differences use timing,
composition, trail layers, palette and restrained camera response.

`OpeningConfig.Profile.signature` owns pulse times/spans/strengths, quiet fraction, compression,
accent delay, trail layer count, spectral treatment, transformation rings, light scale,
camera pull, hold FOV adjustment and ring colors. `cues` selects transformation/impact/reveal
hooks. The new sound slots are empty and safely silent until original/licensed IDs are supplied.
Reduced motion preserves the full recognition holds, softened pulses and spectral identity
with a fixed camera/FOV and disabled moving trails/streaks. All new objects belong to existing
FlightEffects, ImpactEffects or ResultEffects families; no extra render loop or unowned task.

## Adding future content

1. Obtain the actual approved figure design, collection placement and economic values. Add its
   stable Catalog entry using `rarity = "Legendary"` or `"Mythical"`, and the normal model/asset
   mapping. A supported rarity alone is not authorization to invent content.
2. Add the explicitly chosen server `Economy.entries` rate and weight. Missing entries fail
   startup. Positive finite values and strictly increasing rates between populated tiers are
   required; current lower-tier bands remain enforced. Review collection odds deliberately
   because adding a weight changes that collection's normalization.
3. Update content/manifest expectations and run the repository checks. Collection discovery,
   inventory, Shop rows and opening selection use the new real entry automatically.
4. Preview in Studio and test server purchase/grant, discovery, Display/Shelves and two-client
   isolation. The presentation fixture cannot validate those gameplay paths.

For a future new standard rarity, extend the union/order/definition together and supply one
complete OpeningConfig profile and sound slots. UI iteration and layout follow the canonical
order/count; ordinary effects use signature configuration. Update hierarchy expectations and
review contrast/timing. No broad controller switch or five-row layout limit is required.

## Exact Studio preview procedure

1. Sync through Rojo, or open the freshly built `RobloxWorkspace.rbxlx`. Start **Play**, select
   **Client** in the Command Bar, and paste the entire `tests/StudioOpening.client.luau` file.
   This unmapped script asserts Studio and creates its own local preview controller.
2. Leave **Reduced motion: OFF**, **Result: NEW**, **Skip test: Manual**. Click
   **Compare all five tiers: manually Open / Continue each**. Press **Tap to Open**, watch through
   Result, then **Continue** for each tier. Order is Common, Uncommon, Rare, Legendary, Mythical;
   every preview uses the existing Pebble Pip model for a consistent comparison. Output checks
   the result rarity label. Each preview allows up to 180 seconds for manual interaction.
3. Repeat the comparison with **Reduced motion: ON**. Verify fixed framing, full recognition
   hold, softened Legendary double pulse, Mythical quiet/spectral beat and hidden figure colors
   until Reveal. Record both runs at the same graphics quality and viewport.
4. Cycle **Presentation rarity** to **Legendary**, click a catalog model button for an individual
   preview, then run **10-opening regression: manually Open / Continue each**. Repeat for
   Mythical, then both with reduced motion. Compare opening 1 and 10, holding Result for 15s:
   no accumulating Bloom/lights, stale package/nameplate, active flight tail or phase residue.
5. For both high tiers, switch Result to duplicate and cycle Skip test through Flight, Rarity
   hold, Dive, Impact and Impact peak. Verify correct figure, preview rarity, NEW/quantity and
   cleanup. Repeat NEW/reduced motion; restore Manual. Run the existing 20-interruption check.
6. Record desktop and phone portrait/landscape; inspect result contrast and hierarchy at paused
   transformation/impact/silhouette frames. Separately test actual purchases in a two-client
   session. Catalog-mode buttons still preview the six existing collection/rarity combinations.
   Exit the fixture when finished; no live data was changed.

The controller rejects a presentation override outside Studio and rejects unknown tiers before
allocating a session or consuming a receipt. Its accepted override affects only the profile
and local result label, never the authoritative figure ID, ownership, quantity or request.

## Automated coverage and acceptance limits

`tests/Rarity.spec.luau` covers hierarchy/sorting, strict validation, all five UI/profile/audio
definitions, exact timing, separated pulses, quiet beat, bounded light/particle/Bloom budgets,
unchanged live catalog/weights/rates/odds and responsive odds panels (including a future sixth row).
Opening state and flight suites cover every profile. Controller tests cover Studio gating,
authoritative-result preservation, cues, Skip and reduced motion. Actual-module resource tests
add forty full high-tier sessions (ten per tier per motion mode), first/tenth phase counts and
mid-transformation/dive/impact Skip, while retaining prior interruption/stale-work regressions.

See [opening validation](OPENING.md#five-rarity-integration-validation) for checks actually run.
Engine doubles do not establish visual quality, Roblox rendering, device performance or audio
delivery. Native Studio visual acceptance remains pending. The separate final cinematic polish
pass has not been started.
