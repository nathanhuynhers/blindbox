--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
export type Benefits = {
	movementSpeed: number?,
	displayRateBonus: number?,
	dailyCoins: number?,
	cadenceSeconds: number?,
	luckWeight: number?,
}
export type Product = {
	key: string,
	defaultPrice: number?,
	permanent: boolean,
	kind: Types.PlatformKind?,
	platformId: number?,
	salesEnabled: boolean,
	integrationReady: boolean,
	-- Immutable promise for this platform identity, not an active gameplay effect.
	grant: Types.Grant?,
	coinTier: number?,
	benefits: Benefits?,
}
local benefits: { [string]: Benefits } = {
	movement = table.freeze({ movementSpeed = 48 }),
	vip = table.freeze({ displayRateBonus = 0.10, dailyCoins = 500 }),
	auto_open = table.freeze({ cadenceSeconds = 3 }),
	auto_collect = table.freeze({ cadenceSeconds = 1 }),
	luck = table.freeze({ luckWeight = 2 }),
}
local products: { Product } = {}
local function add(
	key: string,
	price: number?,
	permanent: boolean,
	grant: Types.Grant?,
	tier: number?
)
	table.insert(
		products,
		table.freeze({
			key = key,
			defaultPrice = price,
			permanent = permanent,
			kind = nil,
			platformId = nil,
			salesEnabled = false,
			integrationReady = false,
			grant = grant,
			coinTier = tier,
			benefits = benefits[key],
		})
	)
end
local function reward(coins: number, token: Types.TokenId?): Types.Grant
	local tokens: { [Types.TokenId]: number } = {}
	if token then
		tokens[token] = 1
	end
	return table.freeze({ coins = coins, tokens = table.freeze(tokens) })
end
-- D1/D2 approved 2026-10-11; D2 policy/lineage validation is still pending.
-- Platform types, IDs and D3 remain undecided. No product is enabled by design approval.
add("coins_2", 149, true, nil, 2)
add("coins_4", 399, true, nil, 4)
add("coins_8", 999, true, nil, 8)
add("pack_small", 49, false, reward(15000, nil), nil)
add("pack_medium", 149, false, reward(60000, nil), nil)
add("pack_large", 499, false, reward(240000, nil), nil)
add("pack_huge", 1999, false, reward(1200000, nil), nil)
add("starter", 49, true, reward(7500, "Coins2_15"), nil)
add("auto_open", 199, true, nil, nil)
add("auto_collect", 149, true, nil, nil)
add("movement", 49, true, nil, nil)
add("vip", 199, true, nil, nil)
add("coins_boost_15", 29, false, reward(0, "Coins2_15"), nil)
add("coins_boost_30", 49, false, reward(0, "Coins2_30"), nil)
add("coins_boost_60", 79, false, reward(0, "Coins2_60"), nil)
add("luck", 399, true, nil, nil)
add("luck_boost_2", 49, false, reward(0, "Luck2_30"), nil)
add("luck_boost_4", 99, false, reward(0, "Luck4_30"), nil)
add("combo_boost", 79, false, reward(0, "Combo2_30"), nil)
add("offline_double", nil, false, nil, nil)
local Config = {
	products = table.freeze(products),
	-- D1 token promises only. Approved D2 activation/clock/stacking await P04 implementation.
	tokenBenefits = table.freeze({
		Coins2_15 = table.freeze({ coins = 2, luck = 1, seconds = 900 }),
		Coins2_30 = table.freeze({ coins = 2, luck = 1, seconds = 1800 }),
		Coins2_60 = table.freeze({ coins = 2, luck = 1, seconds = 3600 }),
		Luck2_30 = table.freeze({ coins = 1, luck = 2, seconds = 1800 }),
		Luck4_30 = table.freeze({ coins = 1, luck = 4, seconds = 1800 }),
		Combo2_30 = table.freeze({ coins = 2, luck = 2, seconds = 1800 }),
	}),
	-- New sidecar stores. Existing Economy2 schema/namespace is untouched.
	studioStore = "BlindboxTown_Purchases_Studio_v1",
	liveStore = "BlindboxTown_Purchases_Live_v1",
}
function Config.find(key: string): Product?
	for _, product in products do
		if product.key == key then
			return product
		end
	end
	return nil
end
function Config.byId(id: number, kind: Types.PlatformKind): Product?
	for _, product in products do
		if product.platformId == id and product.kind == kind then
			return product
		end
	end
	return nil
end
function Config.configured(product: Product): boolean
	local id = product.platformId
	return product.kind ~= nil and id ~= nil and id > 0 and id < 9007199254740991 and id % 1 == 0
end
-- Fail startup on ambiguous IDs rather than dispatching to the first match.
function Config.validate(entries: { Product })
	local keys: { [string]: boolean } = {}
	local ids: { [string]: boolean } = {}
	for _, product in entries do
		assert(not keys[product.key], "Duplicate purchase key")
		keys[product.key] = true
		if product.platformId ~= nil then
			assert(Config.configured(product), "Invalid purchase identity")
			assert(product.permanent == (product.kind == "Pass"), "Entitlement/platform mismatch")
			local identity = tostring(product.kind) .. ":" .. tostring(product.platformId)
			assert(not ids[identity], "Duplicate platform purchase identity")
			ids[identity] = true
		end
	end
end
Config.validate(products)
return table.freeze(Config)
