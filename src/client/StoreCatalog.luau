--!strict
-- Robux Store presentation copy: tabs and product cards for the retained monetization products.
-- Benefits follow the user-approved D1 values in docs/MONETIZATION.md. This is display text
-- only, never purchase authority: live promises, prices and availability come from P02.
local Style = require(script.Parent.UIStyle)
local AssetIds = require(game:GetService("ReplicatedStorage").Shared.AssetIds)
local Catalog = {}

export type Tab = "featured" | "upgrades" | "boosts" | "coins" | "perks"
export type TabInfo = {
	id: Tab,
	name: string,
	short: string, -- icon-rail label (phone / narrow desktop)
	icon: string, -- UIIcons name (fallback)
	image: string?, -- uploaded tab icon (assets/ui/store-tabs), image asset digits
	tint: Color3,
	top: Color3,
	bottom: Color3,
}
export type Product = {
	key: string,
	name: string,
	kind: string,
	benefit: string,
	gets: { string },
	rules: { string },
	-- Card art: the product's uploaded Roblox icon (image asset digits), else a UIIcons name,
	-- else a stroked glyph.
	image: string?,
	badge: string?, -- small number disc on the image (the slot passes)
	tile: boolean?, -- image is a full-bleed square tile: drawn as a rounded, outlined tile
	icon: string?,
	tint: Color3?, -- icon colour (default ink)
	glyph: string?,
	top: Color3,
	bottom: Color3,
	ribbon: string?,
	-- Sold on the welcome-back screen (Double & Claim), never from the Store.
	elsewhere: boolean?,
}

local hex = Style.hex
Catalog.tabs = table.freeze({
	table.freeze({
		id = "featured" :: Tab,
		name = "Starter & VIP",
		short = "VIP",
		tint = Style.violet,
		icon = "Gift",
		image = AssetIds["Store.TabFeatured"],
		top = hex(0xFFD3E6),
		bottom = Style.candyPink,
	}),
	table.freeze({
		id = "upgrades" :: Tab,
		name = "Upgrades",
		short = "Upgrade",
		tint = Style.violet,
		icon = "Star",
		image = AssetIds["Store.TabUpgrades"],
		top = hex(0xDCD2FF),
		bottom = Style.candyViolet,
	}),
	table.freeze({
		id = "boosts" :: Tab,
		name = "Boosts",
		short = "Boosts",
		tint = Style.ink,
		icon = "Clock",
		image = AssetIds["Store.TabBoosts"],
		top = hex(0xFFE0BC),
		bottom = hex(0xFFA64D),
	}),
	table.freeze({
		id = "coins" :: Tab,
		name = "Coins",
		short = "Coins",
		tint = Style.ink,
		icon = "Coin",
		image = AssetIds["Store.TabCoins"],
		top = hex(0xFFF0B8),
		bottom = Style.gold,
	}),
	table.freeze({
		id = "perks" :: Tab,
		name = "My Perks",
		short = "Perks",
		tint = Style.mintText,
		icon = "Check",
		image = AssetIds["Store.TabPerks"],
		top = hex(0xC8F3DC),
		bottom = hex(0x4FCB8E),
	}),
}) :: { TabInfo }

local boostRules = {
	"Buying adds it to My Perks; it starts when you activate it",
	"The timer runs in real time, even while you're offline",
	"The same boost again adds time, not strength",
}
local packRules = {
	"Coins go straight to your balance",
	"Packs don't change box odds",
	"Coin multipliers never apply to packs",
}

-- Specification examples; current/proposed player-specific odds are supplied by the server.
Catalog.luckExamples = table.freeze({
	"Grove / Tide — Common, Uncommon, Rare:\nBase: 60%, 30%, 10%\nLuck ×2: 54.545455%, 27.272727%, 18.181818%\nLuck ×4: 46.153846%, 23.076923%, 30.769231%",
	"Concepts / Echo / Stars — Common, Uncommon, Rare, Legendary, Mythical:\nBase: 60%, 25%, 13.9%, 1%, 0.1%\nLuck ×2: 52.173913%, 21.739130%, 24.173913%, 1.739130%, 0.173913%\nLuck ×4: 41.379310%, 17.241379%, 38.344828%, 2.758621%, 0.275862%",
})

-- Product art: the original square pass / developer-product tiles (assets/ui/store-icons,
-- uploaded as plain images). Roblox crops pass icons to circles, which clipped their text,
-- so the Store never uses the platform icon IDs. The slot passes reuse the Display navigation
-- sticker (NavigationAssetIds) with a number badge.
local display = "75697262694573"
Catalog.images = table.freeze({
	starter = AssetIds["Store.IconStarter"],
	vip = AssetIds["Store.IconVip"],
	coins2 = AssetIds["Store.IconCoins2"],
	coins4 = AssetIds["Store.IconCoins4"],
	coins8 = AssetIds["Store.IconCoins8"],
	autoOpen = AssetIds["Store.IconAutoOpen"],
	autoCollect = AssetIds["Store.IconAutoCollect"],
	speed = AssetIds["Store.IconSpeed"],
	luck = AssetIds["Store.IconLuck"],
	doubleClaim = AssetIds["Store.IconDoubleClaim"],
	boostCoins = AssetIds["Store.IconBoostCoins"],
	boostLuck2 = AssetIds["Store.IconBoostLuck2"],
	boostLuck4 = AssetIds["Store.IconBoostLuck4"],
	boostCombo = AssetIds["Store.IconBoostCombo"],
	pouch = AssetIds["Store.IconPouch"],
	stack = AssetIds["Store.IconStack"],
	sack = AssetIds["Store.IconSack"],
	chest = AssetIds["Store.IconChest"],
	slot5 = display,
	slot6 = display,
}) :: { [string]: string }

-- Each tile's own background colour (median edge pixel, sampled from the source PNG): the card
-- header is tinted from it so tile and card read as one piece.
Catalog.tileColors = table.freeze({
	starter = hex(0xFEBF42),
	vip = hex(0x733BE5),
	coins2 = hex(0x62E9A4),
	coins4 = hex(0x15C3FE),
	coins8 = hex(0xC52BF9),
	autoOpen = hex(0x15A0FE),
	autoCollect = hex(0x1CD7CC),
	speed = hex(0xFEB21C),
	luck = hex(0x2BEFE3),
	doubleClaim = hex(0x00ADFB),
	boostCoins = hex(0x15C9FE),
	boostLuck2 = hex(0x1CDDCE),
	boostLuck4 = hex(0xA76FE0),
	boostCombo = hex(0x6BE7CE),
	pouch = hex(0x52E9AA),
	stack = hex(0x15CDFE),
	sack = hex(0xD435FD),
	chest = hex(0xFEB822),
}) :: { [string]: Color3 }

local function product(fields: Product): Product
	fields.image = fields.image or Catalog.images[fields.key]
	local tile = Catalog.tileColors[fields.key]
	if tile then
		fields.tile = true
		fields.top = tile:Lerp(Style.white, 0.6)
		fields.bottom = tile:Lerp(Style.white, 0.15)
	end
	return table.freeze(fields)
end

local list: { Product } = {
	product({
		key = "starter",
		tint = Style.violet,
		name = "Starter Pack",
		kind = "One-time bundle",
		benefit = "7,500 Coins and a 15-min 2x Coins boost",
		gets = { "7,500 Coins, added once", "A 15-min 2x Coins boost to start whenever you like" },
		rules = {
			"Once per account, with no deadline",
			"No figures or cosmetics; the free Welcome Quest is separate",
		},
		icon = "Gift",
		top = Style.candyPinkLight,
		bottom = hex(0xFFE38F),
		ribbon = "ONCE PER ACCOUNT",
	}),
	product({
		key = "vip",
		tint = Style.violet,
		name = "VIP",
		kind = "Permanent pass",
		benefit = "+10% Display income and +500 Coins with each daily box",
		gets = {
			"+10% Display Coins, online and offline",
			"+500 Coins each time you claim the daily free box",
		},
		rules = {
			"Bought after today's daily box? The +500 starts tomorrow",
			"No Luck, speed, figures or cosmetics",
		},
		icon = "Star",
		top = hex(0xFFF0B8),
		bottom = Style.candyPinkLight,
		ribbon = "FOREVER",
	}),
	product({
		key = "coins2",
		name = "2x Coins",
		kind = "Permanent pass",
		benefit = "Double your Display income, forever",
		gets = { "2x Display Coins, online and offline" },
		rules = {
			"Only your highest Coin tier applies; tiers never stack",
			"Each tier is its own pass at full price",
		},
		glyph = "2x",
		top = hex(0xFFF0B8),
		bottom = Style.gold,
	}),
	product({
		key = "coins4",
		name = "4x Coins",
		kind = "Permanent pass",
		benefit = "4x your Display income, forever",
		gets = { "4x Display Coins, online and offline" },
		rules = {
			"Only your highest Coin tier applies; tiers never stack",
			"Each tier is its own pass at full price",
		},
		glyph = "4x",
		top = hex(0xFFE0BC),
		bottom = hex(0xFFA64D),
	}),
	product({
		key = "coins8",
		name = "8x Coins",
		kind = "Permanent pass",
		benefit = "8x your Display income, forever",
		gets = { "8x Display Coins, online and offline" },
		rules = {
			"Only your highest Coin tier applies; tiers never stack",
			"Each tier is its own pass at full price",
		},
		glyph = "8x",
		top = hex(0xFFD3E6),
		bottom = Style.candyPink,
	}),
	product({
		key = "autoOpen",
		tint = Style.violet,
		name = "Auto Open",
		kind = "Permanent pass",
		benefit = "Keeps opening the box you pick",
		gets = {
			"Opens one box at a time, at least 3 s apart",
			"Choose how many (1-100) and a Coin reserve",
		},
		rules = { "Start and stop it from the Shop", "Open 1, Open 10 and Skip stay free" },
		icon = "Gift",
		top = hex(0xFFD3E6),
		bottom = hex(0xFF9FC4),
	}),
	product({
		key = "autoCollect",
		name = "Auto Collect",
		kind = "Permanent pass",
		benefit = "Collects your Display Coins every second",
		gets = { "Collects every second while you play", "Switch it on or off any time" },
		rules = {
			"Never raises your income; plates and taps still work",
			"Starts after the Welcome Quest collecting step",
		},
		icon = "Coin",
		top = hex(0xFFD3E6),
		bottom = hex(0xFF7E9C),
	}),
	product({
		key = "speed",
		name = "Speedy Shoes",
		kind = "Permanent pass",
		benefit = "Walk speed 36 to 48",
		gets = { "Walk at speed 48 instead of 36", "Switch back to 36 any time" },
		rules = { "Everyone keeps speed 36 for free" },
		glyph = "48",
		top = hex(0xD6EEFF),
		bottom = hex(0x9AD6FF),
	}),
	product({
		key = "slot5",
		name = "5th Display",
		kind = "Permanent pass",
		benefit = "Unlocks Display slot 5 forever",
		gets = { "A 5th Display slot for another earning figure", "Yours to keep on every server" },
		rules = {
			"Unlock Display slot 4 (1M Coins) first",
			"Already unlocked slot 5? It stays yours; no need to buy",
		},
		badge = "5",
		top = hex(0xDCD2FF),
		bottom = Style.candyViolet,
	}),
	product({
		key = "slot6",
		name = "6th Display",
		kind = "Permanent pass",
		benefit = "Unlocks Display slot 6 forever",
		gets = { "A 6th Display slot for another earning figure", "Yours to keep on every server" },
		rules = {
			"Unlock Display slot 5 first",
			"Already unlocked slot 6? It stays yours; no need to buy",
		},
		badge = "6",
		top = hex(0xFFD3E6),
		bottom = Style.candyPink,
	}),
	product({
		key = "luck",
		name = "Lucky Charm",
		kind = "Permanent pass",
		benefit = "Rarer figures more often",
		gets = {
			"Rare, Legendary and Mythical weights x2",
			"Works on every box, free ones too",
		},
		rules = {
			"Not a guarantee; free pity stays the same",
			"You'll see the exact odds here before buying",
		},
		glyph = "x2",
		top = hex(0xC8F3DC),
		bottom = hex(0x5FD39A),
		ribbon = "LUCK x2",
	}),
	product({
		key = "doubleClaim",
		name = "Double & Claim",
		kind = "On your welcome-back screen",
		benefit = "Double what your Display earned while you were away",
		gets = { "Offered on the welcome-back screen each time you return" },
		rules = { "Claim stays free; doubling covers that return only" },
		glyph = "2N",
		top = hex(0xE6DEFF),
		bottom = hex(0xC9B9FF),
		elsewhere = true,
	}),
	product({
		key = "boostCoins",
		name = "2x Coins Boost",
		kind = "Timed boost",
		benefit = "2x Display Coins for 15, 30 or 60 min",
		gets = { "2x Display Coins while the timer runs" },
		rules = boostRules,
		glyph = "2x",
		top = hex(0xFFF0B8),
		bottom = hex(0xFFA64D),
	}),
	product({
		key = "boostLuck2",
		name = "Luck x2 Boost",
		kind = "Timed boost",
		benefit = "Luck x2 on every box for 30 min",
		gets = { "Rare, Legendary and Mythical weights x2 for 30 min" },
		rules = boostRules,
		glyph = "x2",
		top = hex(0xC8F3DC),
		bottom = hex(0x5FD39A),
	}),
	product({
		key = "boostLuck4",
		name = "Super Luck x4",
		kind = "Timed boost",
		benefit = "Luck x4 on every box for 30 min",
		gets = { "Rare, Legendary and Mythical weights x4 for 30 min" },
		rules = boostRules,
		glyph = "x4",
		top = hex(0xE6DEFF),
		bottom = Style.candyViolet,
		ribbon = "STRONGEST",
	}),
	product({
		key = "boostCombo",
		name = "Coins + Luck",
		kind = "Timed boost",
		benefit = "2x Coins and Luck x2 together for 30 min",
		gets = { "2x Display Coins and Luck x2 for 30 min" },
		rules = boostRules,
		glyph = "2x+",
		top = hex(0xFFF0B8),
		bottom = hex(0x7DE0AE),
	}),
	product({
		key = "pouch",
		name = "Coin Pouch",
		kind = "Coin pack",
		benefit = "15,000 Coins",
		gets = { "15,000 Coins, added once" },
		rules = packRules,
		icon = "Coin",
		top = hex(0xFFF6DA),
		bottom = hex(0xFFE38F),
	}),
	product({
		key = "stack",
		name = "Coin Stack",
		kind = "Coin pack",
		benefit = "60,000 Coins",
		gets = { "60,000 Coins, added once" },
		rules = packRules,
		icon = "Coin",
		top = hex(0xFFF6DA),
		bottom = Style.gold,
	}),
	product({
		key = "sack",
		name = "Coin Sack",
		kind = "Coin pack",
		benefit = "240,000 Coins",
		gets = { "240,000 Coins, added once" },
		rules = packRules,
		icon = "Coin",
		top = hex(0xFFF0B8),
		bottom = hex(0xFFA64D),
	}),
	product({
		key = "chest",
		name = "Treasure Chest",
		kind = "Coin pack",
		benefit = "1,200,000 Coins",
		gets = { "1,200,000 Coins, added once" },
		rules = packRules,
		icon = "Coin",
		top = hex(0xFFE0BC),
		bottom = Style.candyPink,
	}),
}
-- Display slot 4 is bought with Coins in-game, not a Robux product; the Store's Display Slots
-- panel shows it beside the slot passes so the two currencies read apart.
Catalog.coinSlot = product({
	key = "slot4",
	name = "4th Display",
	kind = "Coin unlock",
	benefit = "Unlocks Display slot 4 for Coins",
	gets = {},
	rules = {},
	image = display,
	badge = "4",
	top = hex(0xFFF0B8),
	bottom = Style.gold,
})
local byKey: { [string]: Product } = {}
for _, entry in list do
	assert(byKey[entry.key] == nil, "Duplicate Store product " .. entry.key)
	byKey[entry.key] = entry
end
Catalog.products = table.freeze(byKey)

-- What each tab shows, in order. "tiers" is the Coin Multiplier panel and "hero" the wide
-- Starter banner; the rest are ordinary cards. A product may appear in more than one tab.
export type Section = {
	hero: string?,
	tiers: { string }?,
	-- Display Slots panel: the coin slot 4 plus these Robux slot passes.
	slots: { string }?,
	cards: { string },
}
Catalog.sections = table.freeze({
	featured = table.freeze({ hero = "starter", cards = { "vip", "autoCollect", "boostCoins" } }),
	upgrades = table.freeze({
		slots = { "slot5", "slot6" },
		tiers = { "coins2", "coins4", "coins8" },
		cards = { "autoOpen", "autoCollect", "speed", "luck", "doubleClaim" },
	}),
	boosts = table.freeze({ cards = { "boostCoins", "boostLuck2", "boostLuck4", "boostCombo" } }),
	coins = table.freeze({ cards = { "pouch", "stack", "sack", "chest" } }),
	perks = table.freeze({ cards = {} }),
}) :: { [Tab]: Section }

function Catalog.tab(id: string?): Tab
	for _, info in Catalog.tabs do
		if info.id == id then
			return info.id
		end
	end
	return "featured"
end

return Catalog
