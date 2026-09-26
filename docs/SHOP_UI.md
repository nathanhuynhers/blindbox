# Scalable blind-box Shop

The Shop uses a neutral cream, ivory, wood and gold shell. Collection identity is contained
inside carousel cards, the standardized box, progress accents and the product header. Changing
collections never changes the room or global shell.

`ShopScreen` composes the presentation from `Catalog.collections`; no production collection
count is hardcoded. `ShopTheme` is the small presentation record for an individual collection:
collection ID, emblem key, pattern key and four colors. `ShopState` derives collection figures,
unique discovery progress and rarity-grouped odds from Catalog and the authoritative snapshot.
`ShopLayout` provides responsive geometry. `ShopBox` applies the selected theme to one reusable
box composition, and `ShopArtwork` enforces production-art-or-native-fallback exclusivity.

The current server protocol buys one box per request, so quantity is visibly fixed at one.
The Buy action sends the selected collection through the existing `Buy` intent. The shared client
request coordinator prevents another submission while one is pending; the server validates funds,
charges, rolls and grants. A successful reply continues through the existing opening controller.

Canonical emblems are reused from the Collection production set. Shop patterns use:

- `Collection.PocketGrove.ShopPattern`
- `Collection.TidepoolTales.ShopPattern`

For Studio verification, switch both collection cards and the stage arrows; confirm that only
emblem, pattern, box palette, accents and product data change. Check discovered and undiscovered
possible figures, unique progress, rarity odds, insufficient Coins, pending Buy, daily claim and
opening handoff. Resize through desktop, tablet, portrait and short landscape sizes and run
`tests/StudioShop.client.luau` from the client Command Bar.

## Native visual polish

The shelf reserves 190?250 pixels on desktop, with centered, bounded product cards and a gold
selection halo. Cards reuse the same square-aspect package as the hero: framed front pattern,
offset side, folded lid, emblem and contrasting title band. The product stage uses three neutral
ivory pedestal tiers, gold rims and a warm arched backdrop. No new artwork is needed.

The details surface uses typography and spacing instead of nested section outlines. At wide
detail widths, figures and odds sit side by side above a full-width purchase row. Narrower widths
move odds beside purchasing, then stack them on mobile. Six current figures fit one desktop row;
slot sizing derives from collection membership. A single figure in a rarity group omits ?each.?
The fixed quantity reads ?1 Box?; the existing action gate disables purchasing and displays
?Please wait...? while unavailable, including pending requests. Insufficient funds show the
shortfall. Purchase callbacks and opening coordination are unchanged.

Automated layout checks cover normal desktop and narrow columns. Actual appearance, switching,
pending interaction, and purchase-to-opening handoff still require a Studio playtest. The Studio
check verifies every selected catalog figure, desktop row bounds, purchase bounds, and artwork
fallback exclusivity; it does not submit a purchase.
