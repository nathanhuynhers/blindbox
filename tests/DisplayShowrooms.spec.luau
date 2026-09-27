--!strict
local Rules = require("./Rules")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Config = require("./DisplayConfig")
local checks = 0
local function check(value: boolean, message: string)
	assert(value, message); checks += 1
end
local state = Rules.new(0)
check(state.display.unlocked == 3 and #state.display.slots == 3, "three default slots")
check(Config.maxSlots == 6, "six slot hard cap")
state.owned["grove.star"] = 6; state.discovered["grove.star"] = true
local function place(slot: number): boolean
	return Rules.mutate(state, { action = "Place", id = "p", revision = state.revision, slot = slot, figure = "grove.star" }, 0)
end
check(not place(4), "locked placement rejected")
state.display.unlocked = 6; state.display.slots = { "", "", "", "", "", "" }
for slot = 1, 6 do check(place(slot), "six valid placements") end
check(not place(7) and Rules.rate(state) == 42, "hard cap and unchanged base formula")
check(Profile.decode(Profile.encode(state), 10) ~= nil, "six slots round trip")
check(Protocol.parse({ action = "Place", id = "x", revision = 0, slot = 6, figure = "grove.star" }) ~= nil, "protocol permits six")
local legacy = { schemaVersion = 2, coins = 98765, scrap = 9, owned = { ["grove.star"] = 2 },
	discovered = { ["grove.star"] = true, ["tide.pearl"] = true }, slots = { "grove.star", "", "", "grove.star" },
	unlocked = 4, step = 5, theme = "dusk", themes = { grove = true, dusk = true },
	lastDailyDay = 123, goalDay = 124, goalProgress = 3, goalClaimed = true }
local migrated = Profile.decode(legacy, 90)
assert(migrated)
check(migrated.schemaVersion == 3 and migrated.display.unlocked == 4 and migrated.display.slots[4] == "grove.star", "v2 placement and expansion migration")
check(migrated.coins == 98765 and migrated.scrap == 9 and migrated.owned["grove.star"] == 2 and migrated.discovered["tide.pearl"], "migration preserves economy and discovery")
check(migrated.step == 5 and migrated.lastDailyDay == 123 and migrated.goalDay == 124 and migrated.goalProgress == 3 and migrated.goalClaimed, "migration preserves unrelated daily progression")
check(migrated.showrooms.palette == "dusk" and migrated.showrooms.palettes.dusk, "migration preserves earned palette ownership and preference")
local again = Profile.decode(Profile.encode(migrated), 99)
assert(again)
check(again.display.slots[4] == "grove.star" and again.showrooms.palette == "dusk", "migration is idempotent")
check(legacy.schemaVersion == 2 and legacy.slots[4] == "grove.star", "migration does not mutate source")
for _, bad in { 2, 7, 0/0, math.huge, 4.5 } do
	local corrupt = Profile.encode(state); corrupt.display.unlocked = bad
	check(Profile.decode(corrupt, 0) == nil, "invalid capacity fails closed")
end
local Catalog = require("./Catalog")
local Showrooms = require("./Showrooms")
local Sessions = require("./GallerySessions")
local Transactions = require("./Transactions")
local collectionState = Rules.new(0)
for _, collection in Catalog.collections do
	for _, figure in Catalog.figures do
		if figure.collection == collection.id then collectionState.discovered[figure.id] = true end
	end
	Showrooms.sync(collectionState)
	local room = collectionState.showrooms.rooms[collection.showroomId]
	check(room ~= nil and room.sourceCollectionId == collection.id, "collection unlocks stable room")
	Showrooms.sync(collectionState)
	check(collectionState.showrooms.rooms[collection.showroomId] == room, "unlock is idempotent")
end
local loaded = Profile.decode(Profile.encode(collectionState), 100)
assert(loaded)
local count = 0; for _ in loaded.showrooms.rooms do count += 1 end
check(count == 2, "reconnect does not duplicate rooms")
local registry = Sessions.new()
local host = Sessions.enter(registry, 1, 1)
local visitor = Sessions.enter(registry, 2, 1)
local other = Sessions.enter(registry, 3, 3)
check(host == visitor and host.ownerId == 1, "visitors share owner-specific runtime")
check(host.index ~= other.index, "owners use isolated runtime allocations")
check(Sessions.valid(registry, 2, host.id) and not Sessions.valid(registry, 3, host.id), "membership authorization")
registry.visits[2].roomId = "collection:grove"
check(Sessions.leave(registry, 1) == nil and registry.owners[1] ~= nil, "remaining visitor retains runtime")
check(Sessions.leave(registry, 2) == 1 and registry.owners[1] == nil, "last participant cleans runtime")
local recreated = Sessions.enter(registry, 2, 1)
check(recreated.id ~= host.id and not Sessions.valid(registry, 2, host.id), "stale runtime generation rejected")
Sessions.enter(registry, 4, 1)
local returned = Sessions.closeOwner(registry, 1)
check(#returned == 2 and registry.visits[2] == nil and registry.visits[4] == nil, "owner departure clears all guests")
check(registry.owners[3] == other and registry.visits[3] ~= nil, "cleanup preserves other owners")
local editState = loaded
editState.owned["grove.star"] = 1
editState.display.slots = { "grove.star", "", "" }
local access = { actorId = 1, ownerId = 1, runtimeId = "live", roomId = "collection:grove" }
local function edit(action: string, figure: string?, anchor: string?, room: string?): boolean
	return Showrooms.edit(editState, { action = action, id = "edit", revision = editState.revision,
		figure = figure, anchorId = anchor, roomId = room or access.roomId, runtimeId = access.runtimeId }, access)
end
local coins, scrap, income = editState.coins, editState.scrap, Rules.rate(editState)
check(edit("ShowroomPlace", "grove.star", "figure_1"), "owner can place Display figure cosmetically")
check(edit("ShowroomPlace", "grove.star", "figure_2"), "same single copy at multiple cosmetic anchors")
check(Rules.available(editState, "grove.star") == 0 and editState.owned["grove.star"] == 1, "Showroom reserves zero copies")
access.roomId = "collection:tide"
check(edit("ShowroomPlace", "grove.star", "figure_1"), "same figure may appear in multiple rooms")
check(edit("ShowroomPlace", "grove.pebble", "figure_2"), "discovery without inventory is cosmetic eligibility")
check(edit("ShowroomPlace", "grove.sprout", "figure_3"), "cross-collection placements")
check(edit("ShowroomPlace", "grove.acorn", "figure_4"), "third themed cosmetic figure")
check(Rules.bonus(editState) == 0 and Rules.rate(editState) == income, "cosmetics do not contribute themed bonus or income")
check(editState.coins == coins and editState.scrap == scrap, "cosmetic placement changes no balances")
Rules.refreshDay(editState, 500)
check(editState.goalProgress == 1, "Showroom figures do not count toward daily Display goal")
editState.showrooms.palettes.dusk = true
local themeIntent = { action = "ShowroomTheme", choice = "dusk", id = "theme", revision = editState.revision,
	roomId = access.roomId, runtimeId = access.runtimeId }
check(Showrooms.edit(editState, themeIntent, access), "owner reuses migrated owned palette in room")
check(editState.showrooms.rooms[access.roomId].theme == "dusk" and Rules.rate(editState) == income, "room palette cannot change Display income")
themeIntent.revision = editState.revision; themeIntent.choice = "ocean"
check(not Showrooms.edit(editState, themeIntent, access), "unowned palette denied without a purchase flow")
themeIntent.choice = "dusk"; access.actorId = 2
check(not Showrooms.edit(editState, themeIntent, access), "visitor cannot change palette")
access.actorId = 1
check(not edit("ShowroomPlace", "fake", "figure_1"), "invalid figure rejected")
check(not edit("ShowroomPlace", "grove.star", "bogus"), "invalid anchor rejected")
check(not edit("ShowroomPlace", "grove.star", "figure_1", "custom:unowned"), "invalid room rejected")
access.actorId = 2
check(not edit("ShowroomPlace", "grove.star", "figure_1"), "visitor placement denied")
check(not edit("ShowroomRemove", nil, "figure_1"), "visitor removal denied")
access.actorId = 1
check(edit("ShowroomPlace", "tide.pearl", "figure_1"), "owner replaces figure")
check(edit("ShowroomRemove", nil, "figure_1"), "owner removes figure")
editState.owned["grove.pebble"] = 2
check(Rules.available(editState, "grove.pebble") == 2, "cosmetic reference does not reserve recycling copies")
check(Rules.mutate(editState, { action = "Recycle", figure = "grove.pebble", id = "recycle", revision = editState.revision }, 0), "cosmetically placed copy remains recyclable")
local saved = Profile.encode(editState)
local roundTrip = Profile.decode(saved, 0)
assert(roundTrip)
check(roundTrip.showrooms.rooms["collection:tide"].placements.figure_2 == "grove.pebble", "stable room/anchor/figure persistence")
saved.showrooms.rooms["collection:tide"].placements.figure_2 = nil
check(editState.showrooms.rooms["collection:tide"].placements.figure_2 == "grove.pebble", "nested save snapshot is detached")
local blank = Rules.new(0)
blank.showrooms.rooms["custom:test-id"] = { roomId = "custom:test-id", sourceType = "Custom", theme = "grove", placements = {}, customization = {} }
check(Profile.decode(Profile.encode(blank), 0) ~= nil, "custom stable identity supported without acquisition flow")
for _, kind in { "room", "anchor", "figure", "theme", "customization" } do
	local corrupt = Profile.encode(roundTrip)
	local room = corrupt.showrooms.rooms["collection:tide"]
	if kind == "room" then room.roomId = "renamed"
	elseif kind == "anchor" then room.placements.unknown = "grove.star"
	elseif kind == "figure" then room.placements.figure_1 = "unknown"
	elseif kind == "theme" then room.theme = "unowned"
	else room.customization.unknown = "unapproved" end
	check(Profile.decode(corrupt, 0) == nil, "incompatible saved Showroom data fails closed: " .. kind)
end
check(not Showrooms.edit(blank, { action = "ShowroomPlace", id = "x", revision = 0, roomId = "custom:test-id", runtimeId = "live", anchorId = "figure_1", figure = "grove.star" },
	{ actorId = 1, ownerId = 1, runtimeId = "live", roomId = "custom:test-id" }), "undiscovered known figure rejected")
local transaction = Transactions.new(0); transaction.state = editState
local request = { action = "ShowroomPlace", id = "unique", revision = editState.revision,
	roomId = "collection:tide", runtimeId = "live", anchorId = "figure_1", figure = "grove.star" }
check(Protocol.parse(request) ~= nil, "typed Showroom intent accepted")
local reply = Transactions.process(transaction, request, 0, false, 0, 0, access)
local retry = Transactions.process(transaction, request, 0, false, 0, 0, access)
check(reply ~= nil and reply.ok and retry == reply, "Showroom retry is idempotent")
local stale = table.clone(request); stale.id = "stale"
local staleReply = Transactions.process(transaction, stale, 0, false, 0, 0, access)
check(staleReply ~= nil and not staleReply.ok, "stale revision rejected")
local oldRuntime = table.clone(request); oldRuntime.id = "old"; oldRuntime.revision = editState.revision; oldRuntime.runtimeId = "destroyed"
local oldReply = Transactions.process(transaction, oldRuntime, 0, false, 0, 0, access)
check(oldReply ~= nil and not oldReply.ok, "stale runtime cannot mutate recreated room")
check(Transactions.process(transaction, request, 0, false, 0, 0, access) == nil, "Showroom uses existing token bucket")
for _, field in { "ownerId", "price", "canEdit", "unlocked" } do
	local spoof = table.clone(request); spoof[field] = 1
	check(Protocol.parse(spoof) == nil, "client authority spoof rejected: " .. field)
end
for _, field in { "roomId", "runtimeId", "anchorId" } do
	local spoof = table.clone(request); spoof[field] = string.rep("x", 200)
	check(Protocol.parse(spoof) == nil, "oversized Showroom identity rejected")
end
local noRoom = table.clone(request); noRoom.roomId = nil
check(Protocol.parse(noRoom) == nil, "missing room identity rejected")
local tampered = table.clone(request); tampered.anchorId = "figure_2"
check(not Protocol.same(request, tampered), "receipt includes anchor identity")
local discovered = Rules.new(0)
for _, figure in Catalog.figures do
	if figure.collection == "grove" and figure.id ~= "grove.star" then discovered.discovered[figure.id] = true end
end
discovered.scrap = 6
check(Rules.mutate(discovered, { action = "Redeem", id = "last", revision = 0, figure = "grove.star" }, 0), "final discovery acquired")
check(discovered.showrooms.rooms["collection:grove"] ~= nil, "acquisition automatically unlocks collection room")
local oldComplete = table.clone(legacy); oldComplete.discovered = table.clone(discovered.discovered)
local migratedComplete = Profile.decode(oldComplete, 0)
check(migratedComplete ~= nil and migratedComplete.showrooms.rooms["collection:grove"] ~= nil, "v2 completion grants room during migration")
for _, id in { "grove.pebble", "grove.sprout", "grove.acorn" } do editState.owned[id] = 1 end
editState.display.slots = { "grove.pebble", "grove.sprout", "grove.acorn" }
check(Rules.bonus(editState) == 1 and Rules.rate(editState) == 5.5, "themed Display bonus unchanged with Showrooms")
editState.display.slots = { "", "", "" }
check(Rules.rate(editState) == 0 and Rules.bonus(editState) == 0, "Showrooms alone generate exactly zero")
print(string.format("PASS: %d Display/Showroom foundation checks", checks))
