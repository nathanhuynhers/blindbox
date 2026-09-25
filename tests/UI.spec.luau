--!strict
local UI = require("./UIState")
local Scope = require("./UIScope")
local Rules = require("./Rules")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local Types = require("./Types")
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
