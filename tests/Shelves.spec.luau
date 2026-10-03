--!strict
local Types = require("./Types")
local Rules = require("./Rules")
local Shelves = require("./Shelves")
local Config = require("./ShelfConfig")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local Catalog = require("./Catalog")

local checks = 0
local function check(value: boolean, message: string)
	assert(value, message)
	checks += 1
end
local function same(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local state = Rules.new(0)
check(
	state.schemaVersion == 8 and #state.shelves.units == 3,
	"fresh schema 8 owns three independent shelves"
)
check(#Config.slots() == 9 and Config.visibleShelfUnits == 3, "nine configured local positions")
local view = Shelves.newView()
local access = { actorId = 1, ownerId = 1, near = true, view = view }
local function visible(shelves, current)
	local ids = {}
	for _, unit in Shelves.publicView(shelves, current).visible do
		table.insert(ids, unit.index)
	end
	return table.concat(ids, ",")
end
local function request(
	action: string,
	figure: string?,
	slot: string?,
	shelfId: string?
): Types.Intent
	return {
		action = action,
		figure = figure,
		shelfSlotId = slot,
		shelfId = shelfId or "shelf:1",
		carouselRevision = view.revision,
		revision = state.revision,
		id = action .. state.revision,
	}
end

check(
	visible(state.shelves, view) == "1,2,3"
		and not Shelves.publicView(state.shelves, view).canNavigate,
	"starting trio fixed"
)
view.startIndex = 3
check(
	not Shelves.turn(state.shelves, view, 1, 0) and view.startIndex == 1,
	"three shelves cannot rotate"
)

local id, other = "grove.star", "grove.moth"
local first, second = Config.slots()[1], Config.slots()[2]
check(
	not Shelves.mutate(state, request("ShelfPlace", id, first), access, 0),
	"undiscovered figure denied"
)
state.discovered[id] = true
check(
	not Shelves.mutate(state, request("ShelfPlace", id, first), access, 0),
	"discovered zero-copy figure denied"
)
state.owned[id] = 1
state.display.slots[1] = id
check(
	Shelves.mutate(state, request("ShelfPlace", id, first), access, 0),
	"one copy may be placed while also on Display"
)
check(
	not Shelves.mutate(state, request("ShelfPlace", id, first, "shelf:2"), access, 0),
	"one copy cannot fill two Shelf slots"
)
check(
	state.owned[id] == 1 and Rules.rate(state) == Rules.rates[id],
	"Shelves do not consume inventory or Display earnings"
)

table.insert(
	state.shelves.units,
	{ id = "shelf:4", placements = { [first] = id }, customization = {} }
)
state.owned[id] = 2
check(
	Shelves.availability(state.shelves, state.owned)[id] == 0,
	"hidden Shelf Units count against availability"
)
check(
	not Shelves.mutate(state, request("ShelfPlace", id, second, "shelf:2"), access, 0),
	"hidden placement blocks excess placement"
)
check(
	Shelves.mutate(state, request("ShelfRemove", nil, first), access, 0),
	"removing restores a copy"
)
check(Shelves.availability(state.shelves, state.owned)[id] == 1, "removed copy is available")
check(
	Shelves.mutate(state, request("ShelfPlace", id, second, "shelf:2"), access, 0),
	"restored copy can be placed"
)

state.discovered[other], state.owned[other] = true, 1
check(
	Shelves.mutate(state, request("ShelfPlace", other, second, "shelf:2"), access, 0),
	"atomic swap uses available incoming copy"
)
check(Shelves.availability(state.shelves, state.owned)[id] == 1, "swap releases outgoing copy")
check(
	not Shelves.mutate(state, request("ShelfPlace", other, first, "shelf:1"), access, 0),
	"exhausted incoming copy cannot replace another slot"
)
check(state.shelves.units[1].placements[first] == nil, "failed swap leaves target unchanged")
check(
	Shelves.mutate(state, request("ShelfRemove", nil, second, "shelf:2"), access, 0),
	"removal restores swapped figure"
)
check(Shelves.availability(state.shelves, state.owned)[other] == 1, "removed figure is available")

access.actorId = 2
check(
	not Shelves.mutate(state, request("ShelfRemove", nil, first), access, 0),
	"visitor cannot edit"
)
access.actorId, access.near = 1, false
check(
	not Shelves.mutate(state, request("ShelfRemove", nil, first), access, 0),
	"distant owner cannot edit"
)
access.near = true
for _, shelfId in { "shelf:foreign", "PhysicalCenter", "viewport:1" } do
	check(
		not Shelves.mutate(state, request("ShelfRemove", nil, first, shelfId), access, 0),
		"edit requires visible persistent identity"
	)
end
check(
	not Shelves.mutate(state, request("ShelfPlace", "unknown", first), access, 0),
	"unknown figure denied"
)
check(
	not Shelves.mutate(state, request("ShelfPlace", id, "row:9/slot:1"), access, 0),
	"nonvisible slot denied"
)

local baseline = Profile.encode(state)
for step, expected in { "2,3,4", "3,4,1", "4,1,2", "1,2,3" } do
	check(Shelves.turn(state.shelves, view, 1, step), "next turns once")
	check(visible(state.shelves, view) == expected, "four-unit viewport sequence")
end
check(
	Shelves.turn(state.shelves, view, -1, 5) and visible(state.shelves, view) == "4,1,2",
	"previous wraps"
)
check(
	not Shelves.mutate(state, request("ShelfRemove", nil, first, "shelf:3"), access, 5),
	"hidden shelf cannot be edited"
)
check(same(Profile.encode(state), baseline), "browsing never changes persistence or economy")
local stale = request("ShelfPlace", id, first, "shelf:4")
Shelves.turn(state.shelves, view, 1, 6)
Shelves.turn(state.shelves, view, -1, 7)
check(not Shelves.mutate(state, stale, access, 7), "A-B-A rejects stale carousel revision")
local staleProfile = request("ShelfPlace", id, first, "shelf:4")
staleProfile.revision -= 1
check(not Shelves.mutate(state, staleProfile, access, 7), "stale profile revision denied")
check(not Shelves.turn(state.shelves, view, 1, 7.49), "shared half-second cooldown")
for _, direction in { 0, 2, math.huge, 0 / 0 } do
	check(not Shelves.turn(state.shelves, view, direction, 8), "invalid direction rejected")
end

-- Load repair: unit order, then numeric row/slot order; unowned and excess copies are removed.
local raw = Profile.encode(Rules.new(0))
raw.coins = 321
raw.discovered[id], raw.discovered[other], raw.owned[id] = true, true, 1
raw.shelves.units[1].placements[second] = id
raw.shelves.units[1].placements[first] = id
raw.shelves.units[2].placements[first] = id
raw.shelves.units[2].placements[second] = other
raw.shelves.units[3].placements["row:4/slot:1"] = id
local repaired = Profile.decode(raw, 0)
assert(repaired)
check(repaired.coins == 321 and repaired.owned[id] == 1, "repair preserves unrelated profile data")
check(repaired.shelves.units[1].placements[first] == id, "earliest configured slot survives")
check(repaired.shelves.units[1].placements[second] == nil, "later same-unit copy is removed")
check(
	repaired.shelves.units[2].placements[first] == nil
		and repaired.shelves.units[3].placements["row:4/slot:1"] == nil,
	"later units and hidden slots are repaired"
)
check(repaired.shelves.units[2].placements[second] == nil, "unowned known figure is removed")
local repairedAgain = Profile.decode(Profile.encode(repaired), 0)
check(
	repairedAgain ~= nil and same(Profile.encode(repairedAgain), Profile.encode(repaired)),
	"repair is idempotent"
)

for index = 4, 250 do
	table.insert(
		repaired.shelves.units,
		{ id = "shelf:" .. index, placements = {}, customization = {} }
	)
end
local projection = Shelves.publicView(repaired.shelves, Shelves.newView())
check(
	#projection.visible == 3 and projection.ownedCount == 250,
	"many units keep bounded projection"
)
projection.visible[1].placements[first] = nil
check(repaired.shelves.units[1].placements[first] == id, "projection owns copies")

local txState = Rules.new(0)
txState.discovered[id], txState.owned[id] = true, 1
local tx = Transactions.new(0)
tx.state = txState
state, view = txState, Shelves.newView()
access.view = view
local action = request("ShelfPlace", id, first)
local reply = Transactions.process(tx, action, 0, false, 0, 0, access)
local again = Transactions.process(tx, action, 0, false, 0, 0, access)
check(reply and reply.ok and again == reply, "identical retries reuse receipt")
for _, field in { "ownerId", "plotIndex", "physicalPosition", "price", "pageId", "pageRevision" } do
	local spoof = request("ShelfPlace", id, first) :: unknown
	(spoof :: { [string]: unknown })[field] = 1
	check(Protocol.parse(spoof) == nil, "identity and retired-field spoof rejected")
end
for _, value in { -1, 0.5, math.huge, 0 / 0 } do
	local bad = request("ShelfPlace", id, first)
	bad.carouselRevision = value
	check(Protocol.parse(bad) == nil, "invalid carousel revision denied")
end
for _, key in
	{ "unit:1/row:1/slot:1", "viewport:1/row:1/slot:1", "row:0/slot:1", string.rep("x", 65) }
do
	check(
		Protocol.parse(request("ShelfPlace", id, key)) == nil,
		"only bounded local slot identity accepted"
	)
end

for _, mutate in
	{
		function(s)
			s.units = {}
		end,
		function(s)
			s.units[1] = nil
		end,
		function(s)
			s.units[2].id = s.units[1].id
		end,
		function(s)
			s.units[1].placements[first] = "unknown"
		end,
		function(s)
			s.units[1].placements["row:01/slot:1"] = id
		end,
		function(s)
			s.units[1].customization.skin = "future"
		end,
		function(s)
			s.startIndex = 2
		end,
		function(s)
			s.legacyOverflow =
				{ { sourceId = "bad", logicalUnit = 4, placements = { [first] = id } } }
		end,
	}
do
	local corrupt = Profile.encode(txState)
	mutate(corrupt.shelves)
	check(Profile.decode(corrupt, 0) == nil, "corrupt shelf representation fails closed")
end
local huge = Profile.encode(Rules.new(0))
for index = 4, Shelves.decodeLimits.units + 1 do
	table.insert(
		huge.shelves.units,
		{ id = "shelf:" .. index, placements = {}, customization = {} }
	)
end
check(Profile.decode(huge, 0) == nil, "unit allocation guard")
huge = Profile.encode(Rules.new(0))
for index = 1, Shelves.decodeLimits.placements + 1 do
	huge.shelves.units[1].placements["row:1/slot:" .. index] = id
end
check(Profile.decode(huge, 0) == nil, "placement allocation guard")
local future = Profile.encode(txState)
future.schemaVersion = 9
check(Profile.decode(future, 0) == nil, "future schema fails closed")
for version = 1, 5 do
	local old = Profile.encode(txState)
	old.schemaVersion = version
	check(Profile.decode(old, 0) == nil, "old schema rejected")
end
check(
	Profile.encode(txState).shelves.startIndex == nil and Catalog.byId[id] ~= nil,
	"carousel remains runtime only"
)
print("PASS: " .. checks .. " owned-copy Shelf persistence, repair, validation and carousel checks")
