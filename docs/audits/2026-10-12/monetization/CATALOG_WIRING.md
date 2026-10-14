# Catalog wiring verification — 2026-10-12

Implemented catalog mapping; paid release verification pending. The owner supplied screenshots of all20 products. All9 passes and11 developer products are configured in src/server/PurchaseConfig.luau with their actual IDs; the permanent/repeatable contract determines Pass versus DeveloperProduct. The mapping uses the existing PurchaseRuntime/Service handlers, not another receipt dispatcher.

## Observed platform metadata

Roblox Studio MCP executed read-only MarketplaceService:GetProductInfoAsync calls against every supplied ID in the connected local Edit place. All20 calls succeeded. Names and list prices match the intended rows in [CATALOG_SETUP.md](CATALOG_SETUP.md); every icon ID is positive. All9 passes report creator AsianBaconRoblox (103346374). Developer-product metadata reports CreatorId0, so that field does not prove experience association. The owner then opened the published Blindbox Bonanza/BlindBox experience: Place94818553489889, Universe10767565308, creator103346374. GetDeveloperProductsAsync enumerated exactly the11 configured developer products and returned UniverseId10767565308 for each; their experience association is verified. Pass metadata verifies the same creator, name and intended ID, but those calls alone do not prove pass-to-universe association.

All20 metadata records report IsForSale=true. That is platform sale availability, separate from the game salesEnabled flag. No external sale settings were changed. Keep the platform catalog unavailable to buyers until the current candidate is verified and released.

Roblox names Luck 2x / Luck 4x / Coins 2x + Luck 2x differ stylistically from the suggested names; their IDs, duration, prices and benefit mappings agree. Runtime purchases still use Roblox metadata/viewing-player prices, never the planning defaultPrice as a fallback.

## Existing routes now connected

- Pass IDs flow through server UserOwnsGamePassAsync and the owner-only purchase snapshot to convenience, Coin, Luck and VIP resolvers. Starter reconciliation retains the once-per-account platform marker and immutable bundle.
- Developer-product IDs flow through the sole ProcessReceipt callback. Fixed packs/tokens route to their committed ledger promise and existing durable profile delivery. Unknown identities defer; client completion events never grant value.
- Double & Claim ID3718304498 routes to one saved credit with explicit frozen-return redemption. Historical award-bound identities retain historical handling.
- Owned movement/Auto Collect continue through existing P05 verified-ownership adapters. Mapping economic passes does not activate their unvalidated modifiers.

## Readiness

Local salesEnabled and integrationReady remain false. Economic policy providers still supply Unknown, earned/assisted spending and usable paid Coin transfer are missing, and Boosts/CoinModifiers/PackageRuntime/OfflineRuntime validation gates remain closed. Auto Open still lacks its policy/spendable provider. These are missing implementation/validation boundaries, not merely Dashboard settings. Catalog IDs must not be used as justification to flip those gates.

PASS: all20 native metadata queries; actual ID/type lookup; relevant automated purchase/receipt replay, ownership, session/lease, package, boost, offline-credit and Store integration checks.

NOT RUN: independent pass-to-universe association; native purchase cancellation/receipt delivery; isolated real DataStore save/rejoin; restricted/unknown/allowed policy flows; regional-price/native-prompt agreement; multiplayer and affected physical-device acceptance. No Robux was spent and no live profiles were changed.

Release impact: configuring IDs activates sidecar loading and periodic ownership refresh for loaded sessions even with prompts disabled. Economy2 stores and profile promises remain unchanged. A generated local build is not a deployed update. The intended published Studio place is now open and locally synced. Isolated persistent test stores and a validated paid path are still required for native purchase acceptance. Publishing and production mutations remain separate release actions.

## Studio candidate sync and preview

The opened published Edit place had the older pre-purchase source. Before mutation, all146 existing mapped script sources were captured to an ignored local backup (build/catalog-wiring/studio-before.json). The focused sync updated17 existing scripts and added44 missing modules. No mapped scripts, assets, properties or extra user instances were deleted. Preflight compared class/source hashes to detect concurrent edits; postflight verified all190 mapped script sources against the repository and loaded all20 configured identities in native Edit. These are local Studio edits, not a saved/published place version.

Native UserOwnsGamePassAsync checks succeeded for all9 configured passes; the creator account103346374 owns all9. This is a read-only ownership query, not an in-game purchase/benefit test.

A native Play preview started successfully with Settings.studioPersistence=false. The bootstrap created PurchaseRequest/State, BoostActivate/Result, OfflineCreditRequest/State and ConvenienceRequest/State/Result. The owner snapshot carried all20 actual IDs/types and SalesDisabled for every row. ready=false / ledgerStatus=Loading is expected without a persistent lease in preview; it does not verify receipt or save behavior. Native mouse interaction opened the Store, and its closed purchase controls were observed. No purchase was requested or charged.

Console output showed existing Studio leaderboard API access failures (GetSortedAsync/SetAsync on BlindboxTown_Studio_Leaderboard_v1); no purchase/bootstrap Lua exception was observed. Studio API access is disabled, so those leaderboard writes were rejected. Studio preview is not a persistent/native fulfillment test. Play was stopped and the place returned to Edit with candidate sources intact.

PASS: rokit install; wally install; formatting; Selene0 errors/warnings; Rojo build and sourcemap; full regression suite exit0; Luau LSP exit0/no type errors; git diff --check. The first type analysis found string widening in the new kind field; adding Types.PlatformKind fixed it and targeted purchase tests passed again. Tests now assert configured dispatch while preserving closed purchase gates, rather than the obsolete nil-ID baseline.
