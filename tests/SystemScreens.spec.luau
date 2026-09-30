--!strict
local Engine = require("./SystemUIEngine")
local Layout = require("./SystemLayout")
local Projection = require("./SystemState")
local Catalog = require("./Catalog")
local Config = require("./DisplayConfig")
local ShelfConfig = require("./ShelfConfig")
local Scope = require("./UIScope")
local Rules = require("./Rules")
local Economy = require("./Economy")
local Types = require("./Types")
local Display = require("./DisplayScreen")
local Shelves = require("./ShelvesScreen")
local Goals = require("./GoalsScreen")
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local snapshot: Types.Snapshot = {
	shelves = {
		ownedCount = 5,
		canNavigate = true,
		carouselRevision = 2,
		visible = {
			{ id = "shelf:4", index = 4, placements = {} },
			{ id = "shelf:5", index = 5, placements = {} },
			{ id = "shelf:1", index = 1, placements = {} },
		},
	},
	coins = 0,
	scrap = 0,
	owned = {},
	discovered = {},
	slots = { "", "", "" },
	revision = 0,
	sequence = 1,
	rate = 12.5,
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
	goalReward = 137,
	nextDay = 86400,
	saveStatus = "Preview",
	ready = true,
	bonus = 0,
}
local scope = Scope.create()
local requests = {}
local picked, navigated = 0, ""
local pending = false
local ctx = {
	scope = scope,
	effects = function()
		return false
	end,
	snapshot = function()
		return snapshot
	end,
	canAct = function()
		return snapshot.ready and not pending
	end,
	send = function(action, figure, slot, choice)
		table.insert(requests, { action = action, figure = figure, slot = slot, choice = choice })
	end,
	pick = function(slot)
		picked = slot
	end,
	navigate = function(id)
		navigated = id
	end,
	inspect = function() end,
	place = function() end,
	message = function() end,
}
local host = Engine.Instance.new("Frame")
local display = Display.create(host, ctx)
display.update(snapshot)
for slot = 1, Config.maxSlots do
	local card = Engine.find(display.root, "DisplaySlot" .. slot)
	check(
		card:GetAttribute("Locked") == (slot > 3),
		"all configured cards show authoritative lock state"
	)
end
check(
	Engine.find(display.root, "TotalIncome").Text == "12.5 Coins/sec",
	"income uses snapshot rate including fractions"
)
Engine.click(Engine.find(display.root, "DisplaySlot1"), "Choose figure")
check(picked == 1, "Choose routes to existing Collection slot picker")
Engine.click(Engine.find(display.root, "DisplaySlot4"), "Choose figure")
check(#requests == 0, "unaffordable expansion cannot submit")
snapshot.coins = snapshot.expansionCost
display.update(snapshot)
Engine.click(Engine.find(display.root, "DisplaySlot4"), "Choose figure")
check(requests[#requests].action == "Expand", "only legacy fourth slot submits Expand")
local before = #requests
for slot = 5, Config.maxSlots do
	Engine.click(Engine.find(display.root, "DisplaySlot" .. slot), "Choose figure")
end
check(#requests == before, "unassigned slots never invent an action")
local figure = Catalog.figures[1].id
snapshot.owned[figure] = 1
snapshot.discovered[figure] = true
display.select(figure)
check(Engine.find(display.root, "PlacementBanner").Visible, "placement mode has a visible banner")
Engine.click(Engine.find(display.root, "DisplaySlot2"), "Choose figure")
check(
	requests[#requests].action == "Place"
		and requests[#requests].slot == 2
		and requests[#requests].figure == figure,
	"placement preserves slot and figure payload"
)
snapshot.slots[2] = figure
display.update(snapshot)
before = #requests
Engine.click(Engine.find(display.root, "DisplaySlot1"), "Choose figure")
check(#requests == before, "fully reserved figure cannot be placed again")
Engine.click(Engine.find(display.root, "DisplaySlot2"), "Remove")
check(
	requests[#requests].action == "Remove" and requests[#requests].slot == 2,
	"remove retains existing intent"
)
Engine.click(display.root, "Cancel")
check(
	not Engine.find(display.root, "PlacementBanner").Visible,
	"Cancel clears placement immediately"
)
for unlocked = 3, Config.maxSlots do
	snapshot.unlocked = unlocked
	display.update(snapshot)
	for slot = 1, Config.maxSlots do
		check(
			Engine.find(display.root, "DisplaySlot" .. slot):GetAttribute("Locked")
				== (slot > unlocked),
			"capacity variants do not infer acquisition"
		)
	end
end
local shelves = Shelves.create(host, ctx)
shelves.update(snapshot)
check(
	shelves.root:GetAttribute("SelectedShelfId") == "shelf:4",
	"initial selection uses persistent visible ID"
)
check(
	Engine.find(shelves.root, "VisibleShelves").Text == "Viewing 4, 5, 1 of 5 shelves",
	"wrapped visible indices remain truthful"
)
Engine.click(shelves.root, "Shelf 2") -- second visible button retains its construction name
check(
	shelves.root:GetAttribute("SelectedShelfId") == "shelf:5",
	"unit selection uses ID rather than viewport index"
)
for index, slotId in ShelfConfig.slots() do
	Engine.click(shelves.root, slotId)
	check(shelves.root:GetAttribute("SelectedSlotId") == slotId, "every 3x3 position is selectable")
	Engine.click(shelves.root, "FigureChoice1")
	local request = requests[#requests]
	check(
		request.action == "ShelfPlace" and request.slot == index and request.choice == "shelf:5",
		"picker sends selected slot index and persistent shelf ID"
	)
end
snapshot.shelves.visible[2].placements["row:3/slot:3"] = figure
shelves.update(snapshot)
Engine.click(shelves.root, "Remove")
check(
	requests[#requests].action == "ShelfRemove"
		and requests[#requests].choice == "shelf:5"
		and requests[#requests].slot == 9,
	"remove uses same target"
)
Engine.click(shelves.root, "NextShelves")
check(requests[#requests].action == "ShelfNext", "next shifts existing shared carousel")
Engine.click(shelves.root, "PreviousShelves")
check(requests[#requests].action == "ShelfPrevious", "previous preserves existing intent")
snapshot.shelves.canNavigate = false
shelves.update(snapshot)
before = #requests
Engine.click(shelves.root, "NextShelves")
check(#requests == before, "three-shelf navigation disables mutation")
for _, entry in Catalog.figures do
	snapshot.discovered[entry.id] = true
end
snapshot.owned = {} -- cosmetic picker must allow permanent discoveries with zero copies
shelves.update(snapshot)
local previewCount = #Engine.previews
Engine.click(shelves.root, "NextFigures")
Engine.click(shelves.root, "FigureChoice1")
check(
	requests[#requests].figure == Catalog.figures[7].id,
	"paged picker binds displayed figure rather than old card identity"
)
check(#Engine.previews == previewCount, "catalog browsing reuses a bounded pool of previews")
snapshot.shelves.visible = {
	{ id = "shelf:1", index = 1, placements = {} },
	{ id = "shelf:2", index = 2, placements = {} },
	{ id = "shelf:3", index = 3, placements = {} },
}
shelves.update(snapshot)
check(
	shelves.root:GetAttribute("SelectedShelfId") == "shelf:1",
	"removed visible selection recovers to first current shelf"
)
snapshot.discovered = {}
shelves.update(snapshot)
check(Engine.find(shelves.root, "NoDiscoveries").Visible, "no-discovery state guides toward Shop")
Engine.click(shelves.root, "Explore Shop")
check(navigated == "Shop", "empty shelves offer a useful next action")
local goals = Goals.create(host, ctx)
for progress = 0, 3 do
	snapshot.goalProgress = progress
	goals.update(snapshot)
	check(
		Engine.find(goals.root, "DailyDisplayGoal"):GetAttribute("GoalState")
			== (if progress == 3 then "ready" else "progress"),
		"goal progress states derive from snapshot"
	)
	check(
		Engine.find(goals.root, "Claim reward").Visible == (progress == 3),
		"incomplete goal shows status instead of a disabled CTA"
	)
end
Engine.click(goals.root, "Claim reward")
check(requests[#requests].action == "Goal", "goal uses existing claim intent")
check(
	Engine.find(goals.root, "Claim reward").Text == "Claim 137 Coins",
	"reward text uses snapshot tuning"
)
snapshot.goalClaimed = true
snapshot.dailyReady = false
goals.update(snapshot)
before = #requests
Engine.click(goals.root, "Claim reward")
for _, collection in Catalog.collections do
	Engine.click(goals.root, "Daily_" .. collection.id)
end
check(#requests == before, "claimed daily actions cannot resubmit")
snapshot.dailyReady = true
for _, collection in Catalog.collections do
	goals.update(snapshot)
	Engine.click(goals.root, "Daily_" .. collection.id)
	check(
		requests[#requests].choice == collection.id and requests[#requests].action == "Daily",
		"free box options derive from Catalog"
	)
end
for _, entry in Catalog.figures do
	snapshot.discovered[entry.id] = true
end
goals.update(snapshot)
for _, collection in Catalog.collections do
	check(
		Engine.find(goals.root, "CollectionProgress_" .. collection.id):GetAttribute("Complete"),
		"all dynamic progress cards recognize completion"
	)
end
pending = true
display.update(snapshot)
shelves.update(snapshot)
goals.update(snapshot)
before = #requests
Engine.click(shelves.root, "FigureChoice1")
Engine.click(goals.root, "Daily_" .. Catalog.collections[1].id)
Engine.click(Engine.find(display.root, "DisplaySlot2"), "Remove")
check(#requests == before, "pending requests disable screen mutations")
-- Exercise layout contracts across narrow/short through large desktop canvases.
for width = 248, 1440, 17 do
	for _, placing in { false, true } do
		local g = Layout.display(width, Config.maxSlots, placing)
		check(
			g.columns * g.cell + (g.columns - 1) * 12 <= width,
			"Display grid stays within content width"
		)
		check(
			g.cell >= 190 and g.top >= g.header + 16,
			"Display previews and placement keep clear space"
		)
	end
	local s = Layout.shelves(width, 3, 3)
	check(s.slotWidth >= 64 and s.slotHeight >= 100, "mobile keeps all nine readable shelf targets")
	check(
		s.pickerX + s.pickerWidth <= width and s.pickerY + s.pickerHeight <= s.height,
		"picker stays inside measured canvas"
	)
	check(
		s.columns * s.cell + (s.columns - 1) * 12 <= s.pickerWidth - 24,
		"paged thumbnails fit editor"
	)
	for _, count in { 2, 5, 10, 30 } do
		local g = Layout.goals(width, count)
		check(
			g.progressY >= g.freeY + g.freeHeight,
			"future collections cannot overlap completion section"
		)
		check(
			g.height >= g.progressY + 48 + math.ceil(count / g.columns) * 142,
			"all collection progress remains reachable"
		)
	end
end
local many = {}
for i = 1, 1000 do
	many[i] = "figure:" .. i
end
local page, number, total = Projection.picker(many, 999, 6)
check(
	#page == 4 and number == 167 and total == 167,
	"large picker clamps final page without losing figures"
)
scope.destroy()
print(
	"PASS: "
		.. checks
		.. " system-screen bindings, state and responsive checks (engine/UI primitives stubbed)"
)
