--!strict
local Types = require("./Types")
local Rules = require("./Rules")
local Shelves = require("./Shelves")
local Config = require("./ShelfConfig")
local Display = require("./DisplayConfig")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local Persistence = require("./Persistence")
local Catalog = require("./Catalog")
local checks = 0
local function check(value: boolean, message: string) assert(value, message); checks += 1 end
local state = Rules.new(0)
check(state.schemaVersion == 4 and state.display.unlocked == 3 and Display.maxSlots == 6, "fresh Display 3..6")
check(#state.shelves.pages == 1 and state.shelves.pages[1].id == "page:1", "fresh shelf page")
check(#Config.slots() == 27 and Config.shelfUnitsPerPage == 3 and Config.rowsPerShelfUnit == 3 and Config.slotsPerRow == 3, "provisional 3x3x3")
local view = Shelves.newView()
local access = { actorId = 1, ownerId = 1, near = true, view = view }
local function request(action: string, figure: string?, slot: string?): Types.Intent
	return { action = action, figure = figure, shelfSlotId = slot, pageId = state.shelves.pages[view.index].id,
		pageRevision = view.revision, revision = state.revision, id = action .. state.revision }
end
local id = "grove.star"
local first, second = Config.slots()[1], Config.slots()[2]
check(not Shelves.mutate(state, request("ShelfPlace", id, first), access, 0), "undiscovered figure denied")
state.discovered[id] = true; state.owned[id] = 1; state.display.slots[1] = id
check(Shelves.mutate(state, request("ShelfPlace", id, first), access, 0), "owner places Display copy cosmetically")
check(Shelves.mutate(state, request("ShelfPlace", id, second), access, 0), "one figure repeats in shelves")
check(state.owned[id] == 1 and Rules.available(state, id) == 0 and Rules.rate(state) == 7, "no cosmetic reservation or income")
state.display.slots[1] = ""
check(Rules.rate(state) == 0 and Rules.available(state, id) == 1, "shelves alone earn zero")
state.owned[id] = 2
check(Rules.mutate(state, { action = "Recycle", id = "r", revision = state.revision, figure = id }, 0), "shelf references do not block recycling")
state.owned[id] = nil
check(Shelves.mutate(state, request("ShelfPlace", id, first), access, 0), "permanent discovery sufficient without inventory")
access.actorId = 2
check(not Shelves.mutate(state, request("ShelfRemove", nil, first), access, 0), "visitor cannot edit shelves")
access.actorId = 1; access.near = false
check(not Shelves.mutate(state, request("ShelfRemove", nil, first), access, 0), "remote shelf edit denied")
access.near = true
check(not Shelves.mutate(state, request("ShelfPlace", "unknown", first), access, 0), "unknown figure denied")
check(not Shelves.mutate(state, request("ShelfPlace", id, "unit:8/row:1/slot:1"), access, 0), "invisible slot denied for edits")
check(Shelves.mutate(state, request("ShelfRemove", nil, second), access, 0), "owner removes")
for index = 2, 50 do table.insert(state.shelves.pages, { id = "page:" .. index, placements = {}, customization = {} }) end
check(#state.shelves.pages == 50, "many owned pages supported without pricing")
check(Shelves.turn(state.shelves, view, -1, 1) and view.index == 50, "backward wrap")
check(Shelves.turn(state.shelves, view, 1, 2) and view.index == 1, "forward wrap")
local stale = request("ShelfPlace", id, first)
Shelves.turn(state.shelves, view, 1, 3); Shelves.turn(state.shelves, view, -1, 4)
check(not Shelves.mutate(state, stale, access, 4), "A-B-A carousel rejects old editor revision")
check(not Shelves.turn(state.shelves, view, 1, 4.1), "shared carousel rate limit")
state.shelves.pages[1].placements["unit:1/row:1/slot:4"] = id
local decoded = Profile.decode(Profile.encode(state), 0); assert(decoded)
check(decoded.shelves.pages[1].placements["unit:1/row:1/slot:4"] == id, "stored logical slots survive smaller geometry configs")
local old = { schemaVersion = 3, coins = 9876, scrap = 5, step = 5, owned = { [id] = 2 }, discovered = {},
	display = { unlocked = 4, slots = { id, "", "", id } }, lastDailyDay = 101, goalDay = 102, goalProgress = 3, goalClaimed = true,
	showrooms = { palette = "dusk", palettes = { grove = true, dusk = true }, rooms = {} } }
for _, figure in Catalog.figures do old.discovered[figure.id] = true end
for roomIndex = 1, 7 do
	local roomId = "custom:" .. roomIndex
	local placements = {}
	for anchor = 1, 6 do placements["figure_" .. anchor] = Catalog.figures[(roomIndex + anchor) % #Catalog.figures + 1].id end
	old.showrooms.rooms[roomId] = { roomId = roomId, sourceType = "Custom", theme = "dusk", placements = placements, customization = {} }
end
local migrated = Profile.decode(old, 30); assert(migrated)
check(migrated.schemaVersion == 4 and #migrated.shelves.pages == 2, "v3 creates only sufficient pages for 42 references")
local seen = 0
for _, page in migrated.shelves.pages do for _ in page.placements do seen += 1 end end
check(seen == 42, "all legacy references preserved without overwriting")
check(migrated.shelves.pages[1].placements[first] == old.showrooms.rooms["custom:1"].placements.figure_1, "deterministic room and anchor ordering")
check(migrated.shelves.pages[2].placements[first] == old.showrooms.rooms["custom:5"].placements.figure_4, "deterministic page boundary")
check(migrated.display.unlocked == 4 and migrated.display.slots[4] == id, "legacy Display progress retained")
check(migrated.coins == 9876 and migrated.scrap == 5 and migrated.owned[id] == 2 and migrated.discovered["tide.pearl"], "unrelated economy/discovery retained")
check(migrated.step == 5 and migrated.lastDailyDay == 101 and migrated.goalDay == 102 and migrated.goalProgress == 3 and migrated.goalClaimed, "daily/onboarding preserved")
local repeated = Profile.decode(Profile.encode(migrated), 50); assert(repeated)
check(#repeated.shelves.pages == 2 and old.schemaVersion == 3, "idempotent migration never mutates source")
for pageIndex, page in migrated.shelves.pages do
	for slot, figure in page.placements do check(repeated.shelves.pages[pageIndex].placements[slot] == figure, "placement round trip") end
end
local snapshot = Profile.encode(migrated); snapshot.shelves.pages[1].placements[first] = nil
check(migrated.shelves.pages[1].placements[first] ~= nil, "nested persistence snapshot owns copies")
local empty = table.clone(old); empty.showrooms = { palette = "grove", palettes = { grove = true }, rooms = {} }
local completed = Profile.decode(empty, 0); assert(completed)
check(#completed.shelves.pages == 1 and next(completed.shelves.pages[1].placements) == nil, "completion and old empty room ownership grant no pages or placements")
local v2 = { schemaVersion = 2, coins = 123, scrap = 1, step = 4, owned = { [id] = 1 }, discovered = { [id] = true }, slots = { id, "", "", "" }, unlocked = 4,
	theme = "ocean", themes = { grove = true, ocean = true }, lastDailyDay = 10, goalDay = 10, goalProgress = 2, goalClaimed = false }
local migrated2 = Profile.decode(v2, 0); assert(migrated2)
check(migrated2.coins == 123 and migrated2.display.unlocked == 4 and #migrated2.shelves.pages == 1, "v2 direct migration")
local v1 = { schemaVersion = 1, coins = 33, scrap = 2, step = 3, owned = { [id] = 1 }, discovered = { [id] = true }, slots = { id, "", "" } }
check(Profile.decode(v1, 0) ~= nil, "v1 direct migration")
for _, action in { "ShowroomPlace", "ShowroomRemove", "ShowroomTheme", "GalleryEnter", "Theme", "Visit" } do
	check(Protocol.parse({ action = action, id = "old", revision = 0 }) == nil, "obsolete action rejected: " .. action)
end
for _, field in { "ownerId", "plotIndex", "roomId", "runtimeId", "price" } do
	local spoof = request("ShelfPlace", id, first) :: unknown
	(spoof :: { [string]: unknown })[field] = 1
	check(Protocol.parse(spoof) == nil, "authority spoof rejected")
end
local tx = Transactions.new(0); tx.state = state
local action = request("ShelfPlace", id, first)
local reply = Transactions.process(tx, action, 0, false, 0, 0, access)
local again = Transactions.process(tx, action, 0, false, 0, 0, access)
check(reply ~= nil and reply.ok and again == reply, "shelf retry receipts prevent repeat mutation")
state.owned[id] = 6; state.display.unlocked = 6; state.display.slots = { "", "", "", "", "", "" }
for slot = 1, 6 do check(Rules.mutate(state, { action = "Place", id = "d", revision = state.revision, slot = slot, figure = id }, 0), "six valid Display placements") end
check(Rules.rate(state) == 42, "Display formula unchanged")
state.display.unlocked = 3; state.display.slots = { "", "", "" }
check(not Rules.mutate(state, { action = "Place", id = "d", revision = state.revision, slot = 4, figure = id }, 0), "locked Display denied")
local denied = Transactions.process(tx, { action = "Place", id = "foreign", revision = state.revision, figure = id, slot = 1 }, 1, false, 0)
check(denied ~= nil and not denied.ok, "visitor cannot mutate a Display at a foreign plot")
local database: unknown = { data = old, token = "", writer = "old", expires = 0, generation = 9 }
local update: Persistence.Update = function(_, transform) local result = transform(database); if result then database = result end; return result end
local handle, persisted = Persistence.load(update, "test", "new", 1000, 0)
check(handle ~= nil and persisted ~= nil and persisted.coins == 9876 and #persisted.shelves.pages == 2, "v3 migration through real lease acquisition transform")

-- Corrupt/future state must block decoding, never erase placements or grant fresh defaults.
local function invalidShelf(change)
	local data = Profile.encode(migrated)
	change(data.shelves)
	check(Profile.decode(data, 0) == nil, "invalid shelf data fails closed")
end
invalidShelf(function(s) s.pages = {} end)
invalidShelf(function(s) s.pages[1] = nil end)
invalidShelf(function(s) s.pages["unexpected"] = s.pages[1] end)
invalidShelf(function(s) s.pages[2].id = s.pages[1].id end)
invalidShelf(function(s) s.pages[1].id = "not-a-page" end)
invalidShelf(function(s) s.pages[1].customization.skin = "future" end)
invalidShelf(function(s) s.pages[1].placements[first] = "unknown" end)
invalidShelf(function(s) s.pages[1].placements["unit:0/row:1/slot:1"] = id end)
invalidShelf(function(s) s.pages[1].placements["unit:01/row:1/slot:1"] = id end)
invalidShelf(function(s) s.pages[1].placements["unit:1/row:1/slot:1000001"] = id end)
invalidShelf(function(s) s.visiblePage = 2 end)
local undiscovered = Profile.encode(Rules.new(0))
undiscovered.shelves.pages[1].placements[first] = id
check(Profile.decode(undiscovered, 0) == nil, "undiscovered persisted shelf reference rejected")
local future = Profile.encode(migrated); future.schemaVersion = 5
check(Profile.decode(future, 0) == nil, "future schema never resets progress")
local collectionLegacy = table.clone(old)
collectionLegacy.showrooms = { palette = "grove", palettes = { grove = true }, rooms = {
	["collection:grove"] = { roomId = "collection:grove", sourceType = "Collection", sourceCollectionId = "grove", theme = "grove", placements = { figure_6 = id }, customization = {} },
} }
local collectionMigrated = Profile.decode(collectionLegacy, 0); assert(collectionMigrated)
check(collectionMigrated.shelves.pages[1].placements[first] == id, "valid completed collection room migration")
collectionLegacy.showrooms.rooms["collection:grove"].placements.figure_7 = id
check(Profile.decode(collectionLegacy, 0) == nil, "unknown legacy anchors never silently discarded")
collectionLegacy.showrooms.rooms["collection:grove"].placements.figure_7 = nil
collectionLegacy.showrooms.rooms["collection:grove"].customization.future = true
check(Profile.decode(collectionLegacy, 0) == nil, "unknown legacy customization fails closed")
for _, value in { -1, 0.5, math.huge, 0/0 } do
	local malformed = request("ShelfPlace", id, first); malformed.pageRevision = value
	check(Protocol.parse(malformed) == nil, "invalid numeric carousel revision rejected")
end
local malformed = request("ShelfPlace", id, first); malformed.pageId = string.rep("p", 65)
check(Protocol.parse(malformed) == nil, "oversize page key rejected")
malformed = request("ShelfPlace", id, string.rep("s", 65))
check(Protocol.parse(malformed) == nil, "oversize logical slot rejected")
local wrongPage = request("ShelfPlace", id, first); wrongPage.pageId = "page:unowned"
check(not Shelves.mutate(state, wrongPage, access, 10), "unowned page rejected")
local bonusState = Rules.new(0)
bonusState.discovered["grove.pebble"] = true
bonusState.discovered["grove.sprout"] = true
bonusState.discovered["grove.acorn"] = true
bonusState.shelves.pages[1].placements = { [first] = "grove.pebble", [second] = "grove.sprout", [Config.slots()[3]] = "grove.acorn" }
check(Rules.bonus(bonusState) == 0 and Rules.rate(bonusState) == 0 and bonusState.goalProgress == 0, "cosmetic matching set contributes no income, bonus or daily progress")
print(string.format("PASS: %d plot/shelf schema and domain checks", checks))
