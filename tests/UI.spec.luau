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
		scrap = 0,
		owned = {},
		discovered = {},
		slots = { "", "", "" },
		revision = 0,
		sequence = 1,
		rate = 0,
		step = 1,
		rates = Rules.rates,
		odds = Rules.odds,
		price = Economy.price,
		redeemCost = Economy.redeemCost,
		unlocked = 3,
		expansionCost = Economy.expansionCost,
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
	check(UI.price(snapshot, collection.id) == Economy.price, "price comes from the snapshot")
	local rows = UI.rarityOdds(snapshot, collection.id)
	local count, total = 0, 0
	for _, row in rows do
		count += row.count
		total += row.total
		check(row.total > 0, "rarity rows derive from server odds")
		if row.count > 1 and row.each then
			check(math.abs(row.each * row.count - row.total) < 1e-6, "uniform each sums to total")
		end
	end
	check(count == #UI.members(collection.id), "odds rows cover every figure")
	check(math.abs(total - 100) < 1e-6, "collection odds total 100%")
end
local totals: { [string]: number } = {}
for _, entry in Economy.entries do
	local id = Catalog.byId[entry.id].collection
	totals[id] = (totals[id] or 0) + entry.weight
end
for _, entry in Economy.entries do
	local expected = entry.weight / totals[Catalog.byId[entry.id].collection] * 100
	check(UI.figureOdds(snapshot, entry.id) == expected, "figure odds match configured weights")
	check(UI.figureRate(snapshot, entry.id) == entry.rate, "figure rate from snapshot")
end
local altered = fresh()
altered.price = 2400000
check(UI.need(altered, UI.price(altered, "grove")) == "Need 2.3M more", "shortfall abbreviates")
check(UI.need(snapshot, 150) == nil, "affordable has no shortfall")
check(#UI.freeBoxOptions(snapshot) == #Catalog.collections, "master free box: any collection")
check(UI.unlockPrice(snapshot, 4) == Economy.expansionCost, "slot 4 price from snapshot")
check(UI.unlockPrice(snapshot, 5) == nil and UI.unlockPrice(snapshot, 6) == nil, "no inferred 5/6 price")
check(UI.goalReward(snapshot) == Economy.goalReward, "goal reward from snapshot")

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
own("grove.star", 1) -- 7/s
own("grove.moth", 1) -- 4/s
own("tide.bubble", 1) -- 1.25/s
local picks = UI.picker(snapshot)
check(picks[1].id == "grove.star" and picks[2].id == "grove.moth", "picker sorts best earners first")
check(picks[#picks].rate <= picks[1].rate, "picker descending")
local place = UI.placement(snapshot, "grove.star")
check(place ~= nil and place.kind == "empty" and place.slot == 1, "empty slot placement")
snapshot.slots = { "grove.pebble", "tide.bubble", "grove.moth" }
check(#UI.emptySlots(snapshot) == 0, "full Display")
place = UI.placement(snapshot, "grove.star")
check(
	place ~= nil and place.kind == "swap" and place.slot == 1 and place.replaces == "grove.pebble",
	"swap replaces the lowest earner"
)
check(place ~= nil and place.gain == 6, "swap gain is the rate difference")
own("grove.acorn", 1) -- 2/s, beats only Pebble Pip (1/s)
place = UI.placement(snapshot, "grove.acorn")
check(place ~= nil and place.slot == 1, "swap only when it earns more than the lowest")
snapshot.slots = { "grove.star", "grove.moth", "grove.acorn" }
own("tide.bubble", 1)
check(UI.placement(snapshot, "tide.bubble") == nil, "weaker figure hides Put on Display")
check(UI.placement(snapshot, "grove.star") == nil, "already displayed figure is not offered")
for _, pick in UI.picker(snapshot) do
	check(not UI.displayed(snapshot, pick.id), "picker excludes displayed figures")
end
local bonus = UI.setBonus(snapshot)
check(bonus.collection == "grove" and bonus.best == 3 and not bonus.active, "set progress")
snapshot.bonus = 1
check(UI.setBonus(snapshot).active and UI.setBonus(snapshot).amount == 1, "active set bonus")
-- Set progress agrees with the actual domain rule for mixed sets and repeats.
local choices = { "grove.pebble", "grove.sprout", "grove.acorn", "tide.bubble", "" }
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
local reveal = UI.reveal(snapshot, "echo.feather-hush", true, 1)
check(reveal.place ~= nil and reveal.place.kind == "empty", "reveal places into an empty slot")
check(reveal.placeDetail == "You have 3 empty slots · +12/s", "reveal empty-slot detail")
check(reveal.earns == "Earns 12 coins/s on Display", "reveal earning chip")
check(reveal.progress == "Tender Echoes · 1 of 13 found", "reveal collection progress")
check(reveal.another.collection == "echo" and reveal.another.need == nil, "open another is affordable")
snapshot.coins = 10
reveal = UI.reveal(snapshot, "echo.feather-hush", false, 2)
check(reveal.another.need == "Need 140 more", "open another shows the shortfall")
own("grove.pebble", 1)
own("grove.sprout", 1)
own("grove.acorn", 1)
snapshot.slots = { "grove.pebble", "grove.sprout", "grove.acorn" }
reveal = UI.reveal(snapshot, "echo.feather-hush", false, 2)
check(reveal.placeLabel == "Swap for Pebble Pip" and reveal.placeDetail == "+11/s more", "swap copy")

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
		and reference.panel.height == 508,
	"reference panel is 1152x508 at (64, 84)"
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
