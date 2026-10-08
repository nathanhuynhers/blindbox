--!strict
-- Plaza pop-up stall deals (LOGIC-05, schema 14): deterministic hourly rotation, deal pricing,
-- per-player stock that survives a rejoin and refills on rollover, and the Deal intent's
-- authority (stale window, sold out, wallet, replays). Real Deals/Rules/Transactions/Profile.
local Deals = require("./Deals")
local Rules = require("./Rules")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local Economy = require("./Economy")
local Tutorial = require("./Tutorial")
local Types = require("./Types")
local checks = 0
local function check(condition: boolean, description: string)
	assert(condition, description)
	checks += 1
end
local config = Economy.deals
local hour = 493000 -- a real 2026 UTC hour index

-- Rotation: same window, same offers, recomputed after other windows; no repeats in a window.
local first = table.clone(Deals.offers(hour))
check(#first == config.stalls, "one offer per stall")
Deals.offers(hour + 1)
local again = Deals.offers(hour)
for stall = 1, config.stalls do
	check(again[stall] == first[stall], "the same window always derives the same offers")
end
local weightOf: { [string]: number } = {}
local total = 0
for _, entry in config.weights do
	weightOf[entry.collection] = entry.weight
	total += entry.weight
end
local triples: { [string]: boolean } = {}
local distinct = 0
local counts: { [string]: number } = {}
local samples = 20000
for window = 1, samples do
	local offers = Deals.offers(window)
	local seen: { [string]: boolean } = {}
	for _, collection in offers do
		check(weightOf[collection] ~= nil, "only configured collections are offered")
		check(not seen[collection], "no box repeats at two stalls in one window")
		seen[collection] = true
	end
	check(not seen[Economy.dailyCollection], "the free Starter box is never a deal")
	local key = table.concat(offers, ",")
	if not triples[key] then
		triples[key] = true
		distinct += 1
	end
	counts[offers[1]] = (counts[offers[1]] or 0) + 1
end
check(distinct >= 12, "windows vary: many different offer sets appear")
for collection, weight in weightOf do
	local share = (counts[collection] or 0) / samples
	check(math.abs(share - weight / total) < 0.02, "stall 1 follows the configured weights")
end
check(Deals.window(hour * 3600 + 3599) == hour, "a window lasts the configured hour")
check(Deals.window(hour * 3600 + 3600) == hour + 1, "the next hour is the next window")

-- Price: discount rounded to whole Coins, half up, never below 1.
for normal, expected in { [2000] = 1500, [20000] = 15000, [200000] = 150000, [1] = 1, [2] = 2, [3] = 2, [5] = 4, [7] = 5 } do
	check(Deals.price(normal) == expected, `deal price of {normal} is {expected}`)
end

-- Protocol: only the stall and the window; the server supplies everything else.
local function deal(fields: { [string]: any }): { [string]: any }
	local made: { [string]: any } = { action = "Deal", id = "d", revision = 0, slot = 1, window = hour }
	for key, value in fields do
		made[key] = value
	end
	return made
end
check(Protocol.parse(deal({})) ~= nil, "a Deal with a stall and window parses")
check(Protocol.parse(deal({ slot = config.stalls })) ~= nil, "the last stall parses")
for _, bad in
	{
		deal({ slot = 0 }),
		deal({ slot = config.stalls + 1 }),
		deal({ slot = 1.5 }),
		deal({ slot = 0 / 0 }),
		deal({ slot = "1" }),
		deal({ window = -1 }),
		deal({ window = 1.5 }),
		deal({ window = 0 / 0 }),
		deal({ window = math.huge }),
		deal({ window = "493000" }),
		deal({ choice = "tide" }),
		deal({ figure = "grove.acorn" }),
		deal({ volume = 1 }),
		{ action = "Deal", id = "d", revision = 0, window = hour },
		{ action = "Deal", id = "d", revision = 0, slot = 1 },
		{ action = "Buy", id = "b", revision = 0, choice = "tide", window = hour },
	}
do
	check(Protocol.parse(bad) == nil, "malformed Deal or stray window rejected")
end
check(
	not Protocol.same(assert(Protocol.parse(deal({}))), assert(Protocol.parse(deal({ window = hour + 1 })))),
	"receipts tell windows apart"
)

-- Purchases through the transaction path.
local clock = 0
local sequence = 0
local function send(session: Transactions.Session, stall: number, window: number, current: number?, id: string?)
	clock += 1
	sequence += 1
	local raw = { action = "Deal", id = id or ("deal" .. sequence), revision = session.state.revision, slot = stall, window = window }
	return Transactions.process(session, raw, clock, true, { 0.5 }, 20000, nil, nil, current or window)
end
local function player(coins: number): Transactions.Session
	local session = Transactions.new(0)
	session.state.coins = coins
	session.state.step = Tutorial.done
	return session
end
local offers = Deals.offers(hour)
local price = Deals.price(Rules.prices[offers[1]])
local alice, bob = player(10000000), player(10000000)
local reply = assert(send(alice, 1, hour))
check(reply.ok and reply.figure ~= nil, "a deal buy opens a box like a Shop purchase")
check(alice.state.coins == 10000000 - price, "the wallet pays the discounted price")
check(alice.state.boxesOpened == 1 and alice.state.owned[reply.figure :: string] == 1, "the box is granted and counted")
check(Deals.left(alice.state, 1) == config.stock - 1 and Deals.left(alice.state, 2) == config.stock, "stock is per stall")
local bobView = Deals.view(bob.state, hour)
check(bobView.offers[1].left == config.stock, "another player's stock is untouched")
check(bob.state.coins == 10000000, "another player's wallet is untouched")

local OpeningResult = require("./OpeningResult")
local opened = OpeningResult.fromReply(
	{ action = "Deal", id = reply.id, revision = 0, slot = 1, window = hour },
	{ owned = {}, discovered = {} },
	{ owned = alice.state.owned, discovered = alice.state.discovered },
	reply
)
check(opened ~= nil and opened.figureId == reply.figure and opened.isNew, "a bought deal plays the normal opening")

-- Replays and rapid clicks: one purchase per accepted request.
local before = alice.state.coins
local fixed = "retry-me"
local firstReply = assert(send(alice, 2, hour, nil, fixed))
clock += 1
local replay = Transactions.process(
	alice,
	{ action = "Deal", id = fixed, revision = alice.state.revision - 1, slot = 2, window = hour },
	clock,
	true,
	{ 0.5 },
	20000,
	nil,
	nil,
	hour
)
check(firstReply.ok and replay == firstReply, "a retried request replays its receipt")
local price2 = Deals.price(Rules.prices[offers[2]])
check(alice.state.coins == before - price2 and Deals.left(alice.state, 2) == config.stock - 1, "the retry bought nothing more")
clock += 1
local stale = Transactions.process(
	alice,
	{ action = "Deal", id = "rapid", revision = alice.state.revision - 1, slot = 2, window = hour },
	clock,
	true,
	{ 0.5 },
	20000,
	nil,
	nil,
	hour
)
check(stale ~= nil and not stale.ok and Deals.left(alice.state, 2) == config.stock - 1, "a second click on the old revision is refused")

-- Stale window: the client saw last hour's offer.
local coins = alice.state.coins
local old = assert(send(alice, 1, hour - 1, hour))
check(not old.ok and alice.state.coins == coins and Deals.left(alice.state, 1) == config.stock - 1, "a stale-window buy is refused")
local blind = Rules.mutate(alice.state, { action = "Deal", id = "x", revision = alice.state.revision, slot = 1, window = hour }, 0.5, 20000, 0)
check(not blind and alice.state.coins == coins, "without a current window every Deal is refused")

-- Sold out.
for _ = 2, config.stock do
	check(assert(send(alice, 1, hour)).ok, "buy until the stall is empty for you")
end
coins = alice.state.coins
local sold = assert(send(alice, 1, hour))
check(not sold.ok and sold.message == "Sold out for you this hour." and alice.state.coins == coins, "sold out refuses without charging")
check(Deals.view(alice.state, hour).offers[1].left == 0, "the view shows the stall sold out")
check(Deals.view(bob.state, hour).offers[1].left == config.stock, "selling out never touches another player")

-- Not enough Coins.
local poor = player(Deals.price(Rules.prices[offers[3]]) - 1)
local short = assert(send(poor, 3, hour))
check(not short.ok and short.message == "Not enough Coins yet." and Deals.left(poor.state, 3) == config.stock, "insufficient Coins refuses")
check(poor.state.boxesOpened == 0, "nothing granted without Coins")

-- Rejoin / server hop keeps the window's count; the next window refills.
local function rejoin(session: Transactions.Session): Transactions.Session
	local fresh = Transactions.new(clock)
	fresh.state = assert(Profile.decode(Profile.encode(session.state), clock), "profile round trip")
	return fresh
end
local back = rejoin(alice)
check(Deals.left(back.state, 1) == 0 and Deals.left(back.state, 2) == config.stock - 1, "a rejoin keeps this window's stock")
local hop = assert(send(back, 1, hour))
check(not hop.ok and Deals.left(back.state, 1) == 0, "rejoining cannot reset a sold-out stall")
local nextView = Deals.view(back.state, hour + 1)
check(nextView.offers[1].left == config.stock and nextView.offers[2].left == config.stock, "the next window refills stock")
check(back.state.deals.window == hour + 1, "the stale window is dropped")
check(assert(send(back, 1, hour + 1)).ok, "buying works again in the new window")
local later = rejoin(back)
check(Deals.left(later.state, 1) == config.stock - 1 and later.state.deals.window == hour + 1, "rollover purchases persist")
check(nextView.ends == (hour + 2) * config.windowSeconds and nextView.stock == config.stock, "the view exposes the window end")
check(Deals.view(Rules.new(0), hour, 60).ends == (hour + 1) * 60, "a shortened Studio window reports its own end")

-- Welcome Quest: a deal is a paid box, so it teaches the paid-box step like a Shop purchase.
local learner = player(10000000)
learner.state.step = Tutorial.buy
check(assert(send(learner, 1, hour)).ok and learner.state.step == Tutorial.reward, "a deal advances the paid-box quest step")

-- Schema 14 persistence and migration.
local saved = Profile.encode(alice.state)
check(saved.schemaVersion == 14 and saved.deals.window == hour, "encodes schema 14 with the deal record")
saved.deals.bought[1] = 99
check(alice.state.deals.bought[1] == config.stock, "encoding copies the stock record")
for version = 6, 13 do
	local legacy = Profile.encode(Rules.new(0)) :: any
	legacy.schemaVersion = version
	legacy.deals = nil
	if version < 13 then
		legacy.tutorialHidden = nil
	end
	if version < 12 then
		legacy.sfxVolume, legacy.musicVolume = nil, nil
	end
	if version < 11 then
		legacy.lastLoginDay, legacy.loginStreak = nil, nil
	end
	if version < 10 then
		legacy.lastSeen, legacy.offlinePending = nil, nil
	end
	if version < 9 then
		legacy.shelfRewards = nil
	end
	if version < 8 then
		legacy.boxesOpened = nil
	end
	if version < 7 then
		legacy.earnings = nil
	end
	local upgraded = Profile.decode(legacy, 0)
	check(upgraded ~= nil and upgraded.deals.window == -1, "v" .. version .. " upgrades with full stall stock")
	check(legacy.deals == nil and legacy.schemaVersion == version, "migration does not mutate its input")
	check(Profile.encode(assert(upgraded)).schemaVersion == 14, "v" .. version .. " re-encodes as schema 14")
	check(Deals.view(assert(upgraded), hour).offers[1].left == config.stock, "upgraded players start with full stock")
	local premature = table.clone(legacy)
	premature.deals = { window = hour, bought = { 1, 0, 0 } }
	check(Profile.decode(premature, 0) == nil, "v" .. version .. " carrying a deal record fails closed")
end
local short3 = Profile.encode(alice.state) :: any
short3.deals = { window = hour, bought = { 2 } }
local padded = assert(Profile.decode(short3, 0))
check(#padded.deals.bought == config.stalls and padded.deals.bought[3] == 0, "a short stock array is padded densely")
for _, bad in
	{
		"none",
		{ window = hour },
		{ bought = { 0, 0, 0 } },
		{ window = hour, bought = { 0, 0, 0 }, extra = true },
		{ window = 1.5, bought = { 0, 0, 0 } },
		{ window = -2, bought = { 0, 0, 0 } },
		{ window = 0 / 0, bought = { 0, 0, 0 } },
		{ window = hour, bought = { -1, 0, 0 } },
		{ window = hour, bought = { 0.5, 0, 0 } },
		{ window = hour, bought = { 1000001, 0, 0 } },
		{ window = hour, bought = { [1] = 0, [3] = 0 } },
		{ window = hour, bought = { [17] = 0 } },
		{ window = hour, bought = { a = 1 } },
		{ window = hour, bought = "0,0,0" },
	} :: { any }
do
	local corrupt = Profile.encode(alice.state) :: any
	corrupt.deals = bad
	check(Profile.decode(corrupt, 0) == nil, "an invalid deal record fails closed")
end
local missing = Profile.encode(alice.state) :: any
missing.deals = nil
check(Profile.decode(missing, 0) == nil, "v14 without the deal record fails closed")

-- Client projection (UIState.deal): the five stall states, countdown and Buy button wording.
local UIState = require("./UIState")
local start = hour * config.windowSeconds
local function project(left: number, coins: number, at: number): any
	local view = Deals.view(Rules.new(0), hour)
	view.offers[1].left = left
	return UIState.deal({ coins = coins, deals = view } :: any, 1, at)
end
local rich, dealPrice = 10000000, Deals.price(Rules.prices[offers[1]])
local available = project(3, rich, start + 600)
check(available.status == "available" and available.clock == "50:00", "a mid-window deal is available")
check(available.canBuy and available.button == `Buy for {UIState.number(dealPrice)}`, "Buy shows the deal price")
check(available.percent == 25 and available.stockText == "3 left for you", "discount and stock wording")
check(available.collection == offers[1] and available.deal == dealPrice, "the projection carries the offer")
check(project(3, rich, start + 30).status == "fresh", "the first minute is Just refreshed")
local soon = project(2, rich, start + config.windowSeconds - 200)
check(soon.status == "soon" and soon.clock == "3:20" and soon.canBuy, "under five minutes is Refresh soon")
local last = project(1, rich, start + 600)
check(last.status == "last" and last.stockText == "Last one for you!" and last.canBuy, "one left is Last one")
local sold = project(0, rich, start + 600)
check(sold.status == "soldout" and not sold.canBuy, "no stock is Sold out")
check(sold.button == "Sold out · back in 50:00" and sold.clockLabel == "Restocks in", "sold out counts to the restock")
check(sold.stockText == "All yours! Thank you", "sold out thanks the player")
local poorDeal = project(3, dealPrice - 240, start + 600)
check(not poorDeal.canBuy and poorDeal.button == "Need 240 more", "short wallets show the shortfall")
local ended = project(3, rich, start + config.windowSeconds)
check(ended.status == "restocking" and not ended.canBuy and ended.button == "New deal coming…", "an ended window waits for the next snapshot")
check(UIState.deal({ coins = rich, deals = Deals.view(Rules.new(0), hour) } :: any, config.stalls + 1, start) == nil, "unknown stalls project nothing")
check(UIState.clock(0) == "0:00" and UIState.clock(59.2) == "1:00" and UIState.clock(3599) == "59:59", "countdown formatting")

local _: Types.DealView = Deals.view(alice.state, hour)
print(`PASS: {checks} plaza deal rotation, pricing, stock, authority and schema checks`)
