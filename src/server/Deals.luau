--!strict
-- Plaza pop-up stall deals (LOGIC-05): the offers every server derives from the UTC window index
-- and the config seed alone, the discounted price, and each player's own per-window stock.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Economy = require(script.Parent.Economy)
local CollectionEconomy = require(script.Parent.CollectionEconomy)
local config = Economy.deals
local Deals = {}

local starter = Economy.collections[Economy.dailyCollection].tier
assert(config.windowSeconds >= 1 and config.windowSeconds % 1 == 0, "Invalid deal window length")
assert(config.seed >= 0 and config.seed < 4294967296 and config.seed % 1 == 0, "Invalid deal seed")
assert(config.discount >= 0 and config.discount < 1, "Invalid deal discount")
assert(config.stock >= 1 and config.stock % 1 == 0 and config.stock <= 1000, "Invalid deal stock")
assert(config.stalls >= 1 and config.stalls % 1 == 0 and config.stalls <= 16, "Invalid stall count")
assert(config.refreshSoonSeconds >= 0, "Invalid deal refresh threshold")
assert(#config.weights > 0, "Deals need at least one collection")
for _, entry in config.weights do
	local economy = Economy.collections[entry.collection]
	assert(
		economy
			and CollectionEconomy.prices[entry.collection]
			and entry.collection ~= Economy.dailyCollection
			and entry.collection ~= Economy.welcome.collection
			and economy.tier ~= starter,
		"Deals may only offer purchasable non-Starter collections"
	)
	assert(entry.weight > 0 and entry.weight < math.huge, "Invalid deal weight")
end

-- Exact 32-bit multiply: every partial product stays below 2^53.
local function mul32(a: number, b: number): number
	local high = bit32.band(bit32.rshift(a, 16) * b, 0xFFFF)
	return bit32.band(high * 65536 + bit32.band(a, 0xFFFF) * b, 0xFFFFFFFF)
end

-- MurmurHash3's finalizer: a stateless hash, so the rotation never depends on an engine RNG.
local function mix(value: number): number
	local h = bit32.bxor(value, bit32.rshift(value, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

-- Uniform in [0, 1) for one stall of one window.
local function draw(window: number, stall: number): number
	return mix(bit32.bxor(mix(bit32.bxor(window, config.seed)), stall)) / 4294967296
end

function Deals.window(time: number, seconds: number?): number
	return time // (seconds or config.windowSeconds)
end

local cachedWindow: number? = nil
local cachedOffers: { string } = {}
-- Collection offered at each stall. Earlier stalls' picks are skipped while others remain.
function Deals.offers(window: number): { string }
	if cachedWindow == window then
		return cachedOffers
	end
	local chosen: { string } = {}
	for stall = 1, config.stalls do
		local fresh, all = 0, 0
		for _, entry in config.weights do
			all += entry.weight
			if not table.find(chosen, entry.collection) then
				fresh += entry.weight
			end
		end
		-- Fewer configured collections than stalls: the later stalls may repeat one.
		local repeats = fresh <= 0
		local remaining = draw(window, stall) * (if repeats then all else fresh)
		local pick = ""
		for _, entry in config.weights do
			if repeats or not table.find(chosen, entry.collection) then
				pick = entry.collection
				remaining -= entry.weight
				if remaining < 0 then
					break
				end
			end
		end
		chosen[stall] = pick
	end
	cachedWindow, cachedOffers = window, table.freeze(chosen)
	return cachedOffers
end

-- Whole Coins, rounded half up, never below 1.
function Deals.price(normal: number): number
	return math.max(1, math.floor(normal * (1 - config.discount) + 0.5))
end

-- Forget a previous window's purchases; stock refills when the window changes.
function Deals.refresh(state: Types.State, window: number)
	if state.deals.window ~= window then
		state.deals = { window = window, bought = table.create(config.stalls, 0) }
	end
end

function Deals.left(state: Types.State, stall: number): number
	return math.max(0, config.stock - (state.deals.bought[stall] or 0))
end

-- The only deal data a client receives: this window's offers and the player's own stock.
function Deals.view(state: Types.State, window: number, seconds: number?): Types.DealView
	Deals.refresh(state, window)
	local offers: { Types.DealOffer } = {}
	for stall, collection in Deals.offers(window) do
		local price = CollectionEconomy.prices[collection]
		offers[stall] = {
			collection = collection,
			price = price,
			deal = Deals.price(price),
			left = Deals.left(state, stall),
		}
	end
	return {
		window = window,
		ends = (window + 1) * (seconds or config.windowSeconds),
		stock = config.stock,
		soon = config.refreshSoonSeconds,
		offers = offers,
	}
end

return Deals
