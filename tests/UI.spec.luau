--!strict
local UI = require("./UIState")
local Scope = require("./UIScope")
local Rules = require("./Rules")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local Types = require("./Types")
local ShopLayout = require("./ShopLayout")
local ShopState = require("./ShopState")
local ShopTheme = require("./ShopTheme")
local checks = 0
local function check(condition: boolean, message: string)
	checks += 1
	assert(condition, message)
end
local state = Rules.new(0)
local snapshot: Types.Snapshot = {
	coins = state.coins,
	scrap = state.scrap,
	owned = state.owned,
	discovered = state.discovered,
	slots = state.slots,
	revision = 0,
	sequence = 1,
	rate = 0,
	step = 1,
	rates = Rules.rates,
	odds = Rules.odds,
	price = Economy.price,
	redeemCost = Economy.redeemCost,
	unlocked = 3,
	theme = state.theme,
	themes = state.themes,
	expansionCost = Economy.expansionCost,
	themeCost = Economy.themeCost,
	dailyReady = true,
	goalProgress = 0,
	goalClaimed = false,
	goalReward = Economy.goalReward,
	nextDay = 86400,
	saveStatus = "Preview",
	ready = true,
	rooms = {},
	visiting = 1,
	bonus = 0,
}
local id = "grove.pebble"
local found, total = UI.completion(snapshot, "grove")
check(found == 0 and total == 6, "empty book still has all catalog entries")
check(UI.matches(snapshot, id, "grove", false), "undiscovered silhouette included")
check(not UI.matches(snapshot, id, "grove", true), "owned filter hides unknown figures")
check(not UI.matches(snapshot, id, "tide", false), "collection filtering is immediate")
snapshot.owned[id] = 3
snapshot.discovered[id] = true
snapshot.slots[1] = id
snapshot.slots[2] = id
local owned, free = UI.copies(snapshot, id)
check(owned == 3 and free == 1 and UI.recycle(snapshot, id), "only free duplicate can recycle")
check(UI.matches(snapshot, id, "grove", true), "owned filter shows duplicates")
snapshot.slots[3] = id
check(not UI.recycle(snapshot, id), "all reserved copies disable recycle")
snapshot.slots[1] = ""
snapshot.slots[2] = ""
snapshot.slots[3] = ""
snapshot.owned[id] = 1
check(not UI.recycle(snapshot, id), "last copy protected in presentation")
snapshot.owned[id] = nil
found, total = UI.completion(snapshot, "grove")
check(found == 1 and total == 6, "discovery survives zero copies")
snapshot.owned["tide.bubble"] = 1
check(UI.ownedCollection(snapshot, 1) == 2, "slot picker opens a populated collection")
snapshot.owned[id] = 2
check(UI.ownedCollection(snapshot, 1) == 1, "slot picker keeps current populated collection")
snapshot.ready = false
check(not UI.recycle(snapshot, id), "paused storage disables mutation affordance")
snapshot.ready = true

local totalWeights: { [string]: number } = {}
for _, entry in Economy.entries do
	local collection = Catalog.byId[entry.id].collection
	totalWeights[collection] = (totalWeights[collection] or 0) + entry.weight
end
for _, entry in Economy.entries do
	local collection = Catalog.byId[entry.id].collection
	local expected = entry.weight / totalWeights[collection] * 100
	check(snapshot.odds[entry.id] == expected, "snapshot odds derive from configured roll weights")
	check(
		UI.percent(snapshot.odds[entry.id]) == UI.percent(expected),
		"Collection odds format derived values"
	)
end
check(UI.percent(20) == "20%", "whole pull chances omit decimal noise")
check(UI.percent(12.345) == "12.35%", "fractional pull chances keep useful precision")
check(UI.percent(0 / 0) == "0%", "invalid pull chances fail closed")
for _, collection in Catalog.collections do
	local figures = ShopState.figures(collection.id)
	local shopFound, shopTotal = ShopState.progress(snapshot, collection.id)
	local stateFound, stateTotal = UI.completion(snapshot, collection.id)
	check(#figures == shopTotal and shopTotal > 0, "Shop cards derive from collection membership")
	check(
		shopFound == stateFound and shopTotal == stateTotal,
		"Shop progress counts unique discoveries"
	)
	local oddsCount = 0
	for _, row in ShopState.rarityOdds(snapshot, collection.id) do
		oddsCount += row.count
		check(
			row.minimum > 0 and row.maximum >= row.minimum,
			"Shop rarity odds derive from snapshot"
		)
	end
	check(oddsCount == #figures, "Shop rarity rows cover arbitrary collection figures")
	local shopTheme = ShopTheme.get(collection.id)
	check(
		shopTheme.collectionId == collection.id
			and shopTheme.emblemKey ~= ""
			and shopTheme.patternKey ~= "",
		"every production collection has small Shop theme data"
	)
end
check(ShopTheme.get("future").collectionId == "", "future collections get neutral Shop fallback")
for _, viewport in { { 320, 480 }, { 568, 320 }, { 900, 600 }, { 1280, 720 } } do
	local shopGeometry = ShopLayout.calculate(viewport[1], viewport[2])
	check(
		shopGeometry.contentX >= 0
			and shopGeometry.contentY >= 0
			and shopGeometry.contentWidth > 0
			and shopGeometry.canvasHeight >= shopGeometry.contentHeight,
		"Shop responsive geometry remains reachable"
	)
end

-- Six current figures must fit one desktop row after gutters, without hidden slots.
for width = 256, 1000, 13 do
	local size = ShopLayout.figureSize(width, 6)
	check(size * 6 + 8 * 5 <= width, "Shop six-figure row fits its actual available width")
	check(size >= 36 and size <= 78, "Shop figure slots stay readable and bounded")
end
for _, viewport in { { 1124, 624 }, { 1360, 616 }, { 1360, 780 } } do
	local geometry = ShopLayout.calculate(viewport[1], viewport[2])
	check(geometry.infoX > geometry.heroWidth, "desktop Shop retains two lower columns")
	check(geometry.carouselHeight >= 190, "desktop Shop reserves a prominent product shelf")
	check(geometry.detailY >= geometry.carouselHeight + 12, "shelf clears lower content")
	check(geometry.infoHeight >= 374, "desktop details and purchase controls remain reachable")
	check(
		geometry.canvasHeight <= geometry.contentHeight + 4,
		"normal desktop avoids a tall dashboard canvas"
	)
end

for width = 760, 1100, 20 do
	local geometry = ShopLayout.calculate(width, 620)
	check(
		geometry.infoHeight >= (if geometry.infoWidth < 480 then 510 else 370),
		"Shop stacked controls fit narrow detail columns"
	)
end
check(ShopLayout.calculate(844, 390).compact, "short landscape uses compact navigation")

-- Cross-check set progress against the actual unchanged domain, including mixed sets/repeats.
local choices = { "grove.pebble", "grove.sprout", "grove.acorn", "tide.bubble", "" }
for _, first in choices do
	for _, second in choices do
		for _, third in choices do
			snapshot.slots[1], snapshot.slots[2], snapshot.slots[3] = first, second, third
			check(
				(UI.bonusProgress(snapshot) == 3) == (Rules.bonus(state) > 0),
				"set preview agrees with domain"
			)
		end
	end
end
for _, figure in Catalog.figures do
	snapshot.discovered[figure.id] = true
end
for _, collection in Catalog.collections do
	found, total = UI.completion(snapshot, collection.id)
	check(found == total and total == 6, "completed collection derives from catalog membership")
end
for width = 240, 1600, 17 do
	for maximum = 1, 4 do
		local columns, cell = UI.grid(width, 126, maximum)
		check(columns >= 1 and columns <= maximum, "responsive column bound")
		check(columns * cell + (columns - 1) * 12 <= width - 32, "no horizontal card truncation")
		check(cell >= 126, "readable card width at supported window sizes")
	end
end
check(UI.number(1000000000) == "1,000,000,000", "full currency precision")
check(UI.number(450) == "450" and UI.number(0) == "0", "starter and zero balance formatting")
check(
	UI.compact(10599) == "10.5K" and UI.compact(1000000) == "1M",
	"HUD abbreviations never round up available money"
)
check(UI.compact(1000000000) == "1B" and UI.compact(150) == "150", "HUD cap and everyday balance")

table.freeze(snapshot.owned)
table.freeze(snapshot.discovered)
table.freeze(snapshot.slots)
table.freeze(snapshot)
for _, figure in Catalog.figures do
	UI.copies(snapshot, figure.id)
	UI.recycle(snapshot, figure.id)
end
UI.completion(snapshot, "tide")
UI.bonusProgress(snapshot)
UI.ownedCollection(snapshot, 1)
check(true, "presentation projections work with fully frozen ownership state")

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
local destroyed = {}
scope.connect(signal, function() end)
scope.add(function()
	table.insert(destroyed, 1)
end)
scope.add(function()
	table.insert(destroyed, 2)
end)
scope.destroy()
scope.destroy()
check(
	alive == 0 and #destroyed == 2 and destroyed[1] == 2,
	"screen resources cleaned once, in reverse construction order"
)
scope.add(function()
	table.insert(destroyed, 3)
end)
scope.connect(signal, function() end)
check(alive == 0 and destroyed[3] == 3, "late registration after teardown cannot leak")
local Layout = require("./UILayout")
local Style = require("./CollectionStyle")
check(Layout.desktop(1280, 720, false), "desktop gets the floating rail")
check(not Layout.desktop(568, 284, true), "short touch screens do not get a forced desktop rail")
check(not Layout.desktop(1024, 768, true), "touch tablet keeps compact bottom navigation")
for _, viewport in
	{
		{ 320, 480 },
		{ 360, 760 },
		{ 568, 284 },
		{ 844, 342 },
		{ 1024, 720 },
		{ 1280, 680 },
		{
			1920,
			1040,
		},
	}
do
	for _, touch in { true, false } do
		local desktop = Layout.desktop(viewport[1], viewport[2], touch)
		for _, screenId in { "Collection", "Display", "Shop", "Goals", "Visits" } do
			local rect = Layout.screen(screenId, viewport[1], viewport[2], desktop)
			check(
				rect.x >= 0
					and rect.y >= 0
					and rect.x + rect.width <= viewport[1]
					and rect.y + rect.height <= viewport[2],
				"presentation stays in safe area"
			)
			check(
				rect.width >= 290 and rect.height >= 200,
				"usable presentation area on supported devices"
			)
			if desktop then
				check(rect.x >= 144, "desktop navigation does not cover presentation")
			end
		end
	end
end
local book = Layout.screen("Collection", 1280, 720, true)
local room = Layout.screen("Display", 1280, 720, true)
local goals = Layout.screen("Goals", 1280, 720, true)
check(room.height < book.height and room.y > book.y, "room controls preserve the upper world view")
check(
	goals.width < book.width and goals.height < book.height,
	"daily sheet has its own compact composition"
)
check(
	Style.get("grove").motif == "leaf" and Style.get("tide").motif == "shell",
	"collection art identities are independent"
)
check(Style.get("future").motif == "spark", "unknown collection gets neutral fallback art")
for _, collection in Catalog.collections do
	check(
		Style.collections[collection.id] ~= nil,
		"every shipped collection has explicit art direction"
	)
end
print(
	"PASS: " .. checks .. " UI projection, responsive layout, collection style and lifecycle checks"
)
