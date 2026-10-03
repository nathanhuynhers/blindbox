--!strict
-- UIState projections (the economy merge surface), UILayout geometry, navigation config,
-- 3D box themes and UIScope lifetime. Real modules; no engine.
local UI = require("./UIState")
local Layout = require("./UILayout")
local Scope = require("./UIScope")
local Rules = require("./Rules")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local Types = require("./Types")
local ShopTheme = require("./ShopTheme")
local BlindBoxSpec = require("./BlindBoxSpec")
local NavigationConfig = require("./NavigationConfig")
local checks = 0
local function check(condition: boolean, message: string)
	checks += 1
	assert(condition, message)
end
local state = Rules.new(0)
local function fresh(): Types.Snapshot
	return {
		shelves = {
			ownedCount = 3,
			visible = {
				{ id = "shelf:1", index = 1, placements = {} },
				{ id = "shelf:2", index = 2, placements = {} },
				{ id = "shelf:3", index = 3, placements = {} },
			},
			carouselRevision = 0,
			canNavigate = false,
		},
		coins = 450,
		earnings = {},
		owned = {},
		discovered = {},
		slots = { "", "", "" },
		revision = 0,
		sequence = 1,
		rate = 0,
		step = 1,
		rates = Rules.rates,
		baseRates = Rules.rates,
		nextRates = Rules.rates,
		odds = Rules.odds,
		baseOdds = Rules.odds,
		prices = Rules.prices,
		dailyCollection = Economy.dailyCollection,
		unlocked = 3,
		expansionCost = Economy.expansionCosts[4],
		dailyReady = true,
		goalProgress = 0,
		goalClaimed = false,
		goalReward = Economy.goalReward,
		nextDay = 86400,
		saveStatus = "Preview",
		ready = true,
		bonus = 0,
	}
end
local snapshot = fresh()

-- Formatting: exact, abbreviated (never rounds up), rates and percentages.
check(UI.number(1000000000) == "1,000,000,000" and UI.number(0) == "0", "exact currency")
check(UI.number(0 / 0) == "0" and UI.number(-5) == "0", "invalid currency fails closed")
check(UI.compact(9999) == "9,999" and UI.compact(10599) == "10.5K", "thousands abbreviate down")
check(UI.compact(2499999) == "2.4M" and UI.compact(1000000) == "1M", "millions abbreviate down")
check(UI.compact(3.19e9) == "3.1B" and UI.compact(1e12) == "1T", "billions and trillions")
check(UI.rate(1.25) == "+1.25/s" and UI.rate(35) == "+35/s", "small rates keep fractions")
check(UI.rate(1111.11) == "+1,111/s" and UI.rate(2400000) == "+2.4M/s", "large rates abbreviate")
check(UI.percent(20) == "20%" and UI.percent(4.615) == "4.6%", "chances at one decimal")
check(UI.percent(0.1) == "0.1%" and UI.percent(0.05) == "0.05%", "sub-1% chances stay readable")
check(UI.percent(0 / 0) == "0%" and UI.percent(140) == "100%", "invalid chances fail closed")

-- Economy fields: price, odds and rates are read through UIState only.
for _, collection in Catalog.collections do
	check(UI.price(snapshot, collection.id) == Rules.prices[collection.id], "price per collection")
	local rows = UI.rarityOdds(snapshot, collection.id)
	local count, total = 0, 0
	for _, row in rows do
		count += row.count
		total += row.total
		check(row.total > 0 and math.abs(row.base - row.total) < 1e-9, "rows derive from server odds")
		if row.count > 1 and row.each then
			check(math.abs(row.each * row.count - row.total) < 1e-6, "uniform each sums to total")
		end
	end
	check(count == #UI.members(collection.id), "odds rows cover every figure")
	check(math.abs(total - 100) < 1e-6, "collection odds total 100%")
end
for _, figure in Catalog.figures do
	check(UI.figureOdds(snapshot, figure.id) == Rules.odds[figure.id], "current odds from snapshot")
	check(UI.baseOdds(snapshot, figure.id) == Rules.odds[figure.id], "base odds from snapshot")
	check(UI.figureRate(snapshot, figure.id) == Rules.rates[figure.id], "figure rate from snapshot")
end
-- Increasing-chance luck shows the base beside the raised current chance.
local lucky = fresh()
local luckyOdds = table.clone(Rules.odds)
luckyOdds["grove.star"] *= 2
lucky.odds = luckyOdds
local sawLuck = false
for _, row in UI.rarityOdds(lucky, "grove") do
	if row.rarity == "Rare" then
		sawLuck = string.find(UI.oddsLabel(row), "base " .. UI.percent(row.base), 1, true) ~= nil
	end
end
check(sawLuck, "raised chance shows its base")
local altered = fresh()
altered.prices = { grove = 2400000 }
check(UI.need(altered, UI.price(altered, "grove")) == "Need 2.3M more", "shortfall abbreviates")
check(UI.need(snapshot, 150) == nil, "affordable has no shortfall")
local options = UI.freeBoxOptions(snapshot)
check(#options == 1 and options[1] == Economy.dailyCollection, "free box: the daily collection")
check(UI.unlockPrice(snapshot, 4) == Economy.expansionCosts[4], "next slot price from snapshot")
check(UI.unlockPrice(snapshot, 5) == nil and UI.unlockPrice(snapshot, 6) == nil, "only the next slot")
check(UI.lockedText(snapshot, 6) == "Unlock slot 5 first", "later coin slots unlock in order")
check(UI.goalReward(snapshot) == Economy.goalReward, "goal reward from snapshot")
snapshot.earnings = { ["grove.pebble"] = 12.9 }
check(UI.earnings(snapshot, "grove.pebble") == 12, "banked earnings round down")
check(UI.earnings(snapshot, "grove.star") == 0, "no earnings without a bank")
snapshot.earnings = {}

-- Collections and filters.
local found, total = UI.completion(snapshot, "grove")
check(found == 0 and total == 6, "empty collection still lists every figure")
snapshot.discovered["grove.pebble"] = true
snapshot.owned["grove.pebble"] = 3
check(#UI.filtered(snapshot, "grove", "found") == 1, "Found filter")
check(#UI.filtered(snapshot, "grove", "missing") == 5, "Missing filter")
check(#UI.filtered(snapshot, "grove", "all") == 6, "All filter")
check(UI.progressText(snapshot, "grove") == "1 of 6 found · 5 left to discover", "progress copy")
local allFound, allTotal = UI.totalCompletion(snapshot)
check(allFound == 1 and allTotal == #Catalog.figures, "total discovery")

-- Display: picker, placement, swap and set bonus.
local function own(id: string, count: number)
	snapshot.owned[id] = count
	snapshot.discovered[id] = true
end
local function rate(id: string): number
	return UI.figureRate(snapshot, id)
end
own("grove.star", 1)
own("grove.moth", 1)
own("tide.bubble", 1)
local picks = UI.picker(snapshot)
for index = 2, #picks do
	check(picks[index - 1].rate >= picks[index].rate, "picker sorts best earners first")
end
local best = math.max(rate("grove.star"), rate("grove.moth"), rate("tide.bubble"), rate("grove.pebble"))
check(picks[1].rate == best, "BEST is the top earner")
local place = UI.placement(snapshot, "grove.star")
check(place ~= nil and place.kind == "empty" and place.slot == 1, "empty slot placement")
-- One placement per unique figure: extra copies never free a second slot.
snapshot.slots = { "grove.pebble", "", "" }
local owned, free = UI.copies(snapshot, "grove.pebble")
check(owned == 3 and free == 0, "a displayed figure has no free copy")
owned, free = UI.copies(snapshot, "grove.star")
check(owned == 1 and free == 1, "an undisplayed owned figure has one placement")
snapshot.slots = { "grove.pebble", "tide.bubble", "grove.moth" }
check(#UI.emptySlots(snapshot) == 0, "full Display")
local lowestSlot, lowestRate = 1, math.huge
for slot, id in snapshot.slots do
	if rate(id) < lowestRate then
		lowestSlot, lowestRate = slot, rate(id)
	end
end
place = UI.placement(snapshot, "grove.star")
check(rate("grove.star") > lowestRate, "fixture: a Rare out-earns the lowest displayed figure")
check(
	place ~= nil
		and place.kind == "swap"
		and place.slot == lowestSlot
		and place.replaces == snapshot.slots[lowestSlot],
	"swap replaces the lowest earner"
)
check(
	place ~= nil and math.abs(place.gain - (rate("grove.star") - lowestRate)) < 1e-9,
	"swap gain is the rate difference"
)
own("grove.mushroom", 1)
snapshot.slots = { "grove.star", "grove.moth", "grove.mushroom" }
check(
	rate("grove.pebble") < rate("grove.moth") and rate("grove.pebble") < rate("grove.mushroom"),
	"fixture: Common under Uncommon"
)
check(UI.placement(snapshot, "grove.pebble") == nil, "weaker figure hides Put on Display")
check(UI.placement(snapshot, "grove.star") == nil, "already displayed figure is not offered")
for _, pick in UI.picker(snapshot) do
	check(not UI.displayed(snapshot, pick.id), "picker excludes displayed figures")
end
local bonus = UI.setBonus(snapshot)
check(bonus.collection == "grove" and bonus.best == 3 and not bonus.active, "set progress")
snapshot.bonus = 1.5
check(UI.setBonus(snapshot).active and UI.setBonus(snapshot).amount == 1.5, "active set bonus")
-- Set progress agrees with the actual domain rule for mixed sets and repeats.
local choices = { "grove.pebble", "grove.sprout", "grove.acorn", "tide.bubble", "" }
for _, id in choices do
	if id ~= "" then
		state.owned[id] = 1
	end
end
for _, first in choices do
	for _, second in choices do
		for _, third in choices do
			state.display.slots = { first, second, third }
			snapshot.slots = { first, second, third }
			snapshot.bonus = Rules.bonus(state)
			check(
				(UI.setBonus(snapshot).best == 3) == (Rules.bonus(state) > 0),
				"set preview agrees with domain"
			)
		end
	end
end

-- Reveal card model.
snapshot = fresh()
own("echo.feather-hush", 1)
local hush = rate("echo.feather-hush")
local reveal = UI.reveal(snapshot, "echo.feather-hush", true, 1)
check(reveal.place ~= nil and reveal.place.kind == "empty", "reveal places into an empty slot")
check(reveal.placeDetail == "You have 3 empty slots · " .. UI.rate(hush), "reveal empty-slot detail")
check(reveal.earns == "Earns " .. UI.amount(hush) .. " coins/s on Display", "reveal earning chip")
check(reveal.progress == "Tender Echoes · 1 of 13 found", "reveal collection progress")
snapshot.coins = 10
local echoPrice = UI.price(snapshot, "echo")
reveal = UI.reveal(snapshot, "echo.feather-hush", false, 2)
check(reveal.another.collection == "echo" and reveal.another.price == echoPrice, "same box again")
check(
	reveal.another.need == "Need " .. UI.compact(echoPrice - 10) .. " more",
	"open another shows the shortfall"
)
snapshot.coins = echoPrice
check(UI.reveal(snapshot, "echo.feather-hush", false, 2).another.need == nil, "affordable")
own("grove.pebble", 1)
own("grove.sprout", 1)
own("grove.acorn", 1)
snapshot.slots = { "grove.pebble", "grove.sprout", "grove.acorn" }
local weakest, weakestRate = "", math.huge
for _, id in snapshot.slots do
	if rate(id) < weakestRate then
		weakest, weakestRate = id, rate(id)
	end
end
reveal = UI.reveal(snapshot, "echo.feather-hush", false, 2)
check(reveal.placeLabel == "Swap for " .. Catalog.byId[weakest].name, "swap names the lowest earner")
check(reveal.placeDetail == UI.rate(hush - weakestRate) .. " more", "swap shows the gain")

-- Badges, goals and countdown.
snapshot = fresh()
local badges = UI.badges(snapshot)
check(badges.Display == "3 empty" and badges.Shop == "FREE" and badges.Goals == nil, "dock badges")
snapshot.goalProgress = 3
check(UI.badges(snapshot).Goals == "1" and UI.goal(snapshot) == "ready", "claimable goal badge")
snapshot.goalClaimed = true
snapshot.dailyReady = false
check(UI.badges(snapshot).Goals == nil and UI.badges(snapshot).Shop == nil, "claimed clears badges")
local text, delay = UI.countdown(86400, 86400 - (5 * 3600 + 11 * 60 + 30))
check(text == "5h 12m" and math.abs(delay - 30.05) < 1e-6, "countdown text and next refresh")
text, delay = UI.countdown(1000, 1000 - 120)
check(text == "2m" and delay == 60, "minute boundary waits a whole minute")
text = UI.countdown(1000, 2000)
check(text == "any moment", "past reset fails closed")
for remaining = 1, 7200, 37 do
	local _, wait = UI.countdown(10000, 10000 - remaining)
	check(wait >= 1 and wait <= 60, "countdown refreshes at most once a minute")
end

-- Grid cells never truncate the last column.
for width = 120, 1600, 17 do
	for columns = 1, 7 do
		local cell = UI.cells(width, columns, 10)
		check(cell * columns + 10 * (columns - 1) <= width, "cells fit their width")
	end
end

-- Layout: desktop reference, scaling, phone landscape.
local reference = Layout.frame(1280, 720, { left = 104, right = 1280 })
check(not reference.phone and reference.scale == 1, "1280x720 is the desktop reference")
check(
	reference.panel.x == 64
		and reference.panel.y == 84
		and reference.panel.width == 1152
		and reference.panel.height == 496,
	"reference panel is 1152x496 at (64, 84), clear of the raised dock"
)
check(reference.dock.x == 366 and reference.dock.y == 606, "reference dock at (366, 606)")
check(reference.dock.width == 548 and reference.dock.itemHeight == 94, "dock tiles 100x94")
check(reference.hud.x == 114 and reference.hud.y == 14, "HUD sits right of the Roblox buttons")
local large = Layout.frame(1920, 1080, { left = 104, right = 1920 })
check(large.scale == 1.5 and large.width == 1280 and large.height == 720, "1080p scales 1.5x")
local phone = Layout.frame(844, 390, { left = 96, right = 844 })
check(phone.phone and phone.scale == 1 and not phone.dockWhileOpen, "phone landscape")
check(phone.panel.x == 104 and phone.panel.width == 732 and phone.panel.height == 376, "phone sheet")
check(phone.dock.width == 372 and phone.dock.y == 390 - 10 - 70, "phone dock 68x70")
for _, viewport in
	{ { 900, 560 }, { 1024, 600 }, { 1024, 768 }, { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 } }
do
	local geometry = Layout.frame(viewport[1], viewport[2], { left = 104, right = viewport[1] })
	check(not geometry.phone, "desktop sizes stay desktop")
	local panel = geometry.panel
	check(panel.x >= 0 and panel.x + panel.width <= geometry.width, "panel inside the screen")
	check(panel.y >= geometry.hud.y + geometry.hud.height, "panel below the HUD")
	check(panel.y + panel.height <= geometry.dock.y, "panel above the dock")
	check(panel.height >= 300, "panel keeps a usable body")
	check(geometry.dock.x >= 0 and geometry.dock.x + geometry.dock.width <= geometry.width, "dock fits")
	check(geometry.scale >= 1 and geometry.scale <= 2, "scale bounded so 44px targets never shrink")
end
for _, viewport in { { 667, 375 }, { 740, 360 }, { 844, 390 }, { 932, 430 }, { 1024, 500 } } do
	local geometry = Layout.frame(viewport[1], viewport[2], { left = 96, right = viewport[1] })
	check(geometry.phone and geometry.scale == 1, "phone landscape sizes use the sheet layout")
	check(geometry.panel.width >= 540 and geometry.panel.height >= 340, "phone sheet usable")
	check(geometry.dock.x >= 0 and geometry.dock.x + geometry.dock.width <= geometry.width, "phone dock fits")
	check(geometry.gear.x + geometry.gear.width <= geometry.width, "gear inside the screen")
end
local list, main, side = Layout.panes(1146, 256, 404, 300)
check(list + main + side == 1146 and main >= 300, "three-pane body fills its width")
list, main, side = Layout.panes(852, 256, 404, 300)
check(side == 300 and main >= 290 and list + main + side == 852, "narrow desktop shrinks the side pane first")

-- Navigation and 3D box themes.
check(#NavigationConfig.items == 5, "dock keeps the five destinations")
for index, id in { "Collection", "Display", "Shop", "Goals", "Shelves" } do
	check(NavigationConfig.pages[index] == id, "dock order")
	check(NavigationConfig.items[index].assetKey == "Navigation." .. id, "dock artwork key")
end
for _, collection in Catalog.collections do
	local theme = ShopTheme.get(collection.id)
	check(theme.collectionId == collection.id and theme.emblemKey ~= "", "3D box theme per collection")
end
check(ShopTheme.get("future").collectionId == "", "future collections get a neutral box")
local semanticNames = {}
for _, name in BlindBoxSpec.required do
	semanticNames[name] = true
end
check(#BlindBoxSpec.missing(semanticNames) == 0, "blind-box semantics satisfy preview contract")

-- Projections work with fully frozen state (screens never mutate snapshots).
snapshot = fresh()
own("grove.star", 2)
table.freeze(snapshot.owned)
table.freeze(snapshot.discovered)
table.freeze(snapshot.slots)
table.freeze(snapshot)
for _, figure in Catalog.figures do
	UI.copies(snapshot, figure.id)
	UI.placement(snapshot, figure.id)
end
UI.picker(snapshot)
UI.reveal(snapshot, "grove.star", false, 2)
UI.badges(snapshot)
UI.setBonus(snapshot)
check(true, "projections are read-only")

-- UIScope lifetime.
local alive = 0
local signal = {
	Connect = function(_self: unknown, _callback: (...unknown) -> ())
		alive += 1
		return {
			Disconnect = function()
				alive -= 1
			end,
		}
	end,
}
local scope = Scope.create()
local order = {}
scope.connect(signal :: any, function() end)
scope.add(function()
	table.insert(order, 1)
end)
scope.add(function()
	table.insert(order, 2)
end)
scope.destroy()
scope.destroy()
check(alive == 0 and #order == 2 and order[1] == 2, "cleanup once, in reverse order")
scope.add(function()
	table.insert(order, 3)
end)
check(order[3] == 3, "late registration after teardown runs immediately")
print("PASS: " .. checks .. " UI projection, layout, navigation and lifecycle checks")
