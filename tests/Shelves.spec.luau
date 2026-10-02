--!strict
local Types = require("./Types")
local Rules = require("./Rules")
local Shelves = require("./Shelves")
local Config = require("./ShelfConfig")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local Persistence = require("./Persistence")
local Catalog = require("./Catalog")
local checks = 0
local function check(value: boolean, message: string) assert(value, message); checks += 1 end
local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in a do if not same(value, b[key]) then return false end end
	for key in b do if a[key] == nil then return false end end
	return true
end
local state = Rules.new(0)
check(state.schemaVersion == 6 and #state.shelves.units == 3, "fresh schema 6 owns three independent shelves")
check(#Config.slots() == 9 and Config.visibleShelfUnits == 3 and Config.shelfAcquisition == "Unassigned", "nine configured local positions and no acquisition policy")
local view = Shelves.newView()
local access = { actorId = 1, ownerId = 1, near = true, view = view }
local function visible(shelves, current)
	local ids = {}; for _, unit in Shelves.publicView(shelves, current).visible do table.insert(ids, unit.index) end
	return table.concat(ids, ",")
end
check(visible(state.shelves, view) == "1,2,3" and not Shelves.publicView(state.shelves, view).canNavigate, "starting trio fixed and controls disabled")
view.startIndex = 3
check(not Shelves.turn(state.shelves, view, 1, 0) and view.startIndex == 1 and view.revision == 0, "three shelves cannot rotate or advance revision")
local id = "grove.star"
local first, second = Config.slots()[1], Config.slots()[2]
local function request(action: string, figure: string?, slot: string?, shelfId: string?): Types.Intent
	return { action = action, figure = figure, shelfSlotId = slot, shelfId = shelfId or "shelf:1", carouselRevision = view.revision, revision = state.revision, id = action .. state.revision }
end
check(not Shelves.mutate(state, request("ShelfPlace", id, first), access, 0), "undiscovered figure denied")
state.discovered[id] = true; state.owned[id] = 1; state.display.slots[1] = id
check(Shelves.mutate(state, request("ShelfPlace", id, first), access, 0), "owner places simultaneously with Display")
check(Shelves.mutate(state, request("ShelfPlace", id, first, "shelf:2"), access, 0), "same discovery repeats across persistent units")
check(Shelves.mutate(state, request("ShelfPlace", id, second), access, 0), "same discovery repeats within a unit")
check(state.owned[id] == 1 and Rules.available(state, id) == 0 and Rules.rate(state) == Rules.rates[id], "no shelf reservations or income")
state.display.slots[1] = ""
check(Rules.rate(state) == 0 and Rules.available(state, id) == 1, "shelves alone earn zero")
state.owned[id] = 2
check(state.owned[id] == 2, "shelf use leaves duplicate count intact")
state.owned[id] = nil
check(Shelves.mutate(state, request("ShelfPlace", id, first, "shelf:3"), access, 0), "zero-copy discovered cosmetics remain usable")
access.actorId = 2
check(not Shelves.mutate(state, request("ShelfRemove", nil, first), access, 0), "visitor cannot edit")
access.actorId = 1; access.near = false
check(not Shelves.mutate(state, request("ShelfRemove", nil, first), access, 0), "distant owner cannot edit")
access.near = true
for _, shelfId in { "shelf:foreign", "PhysicalCenter", "viewport:1" } do check(not Shelves.mutate(state, request("ShelfRemove", nil, first, shelfId), access, 0), "edit requires an owned visible persistent identity") end
check(not Shelves.mutate(state, request("ShelfPlace", "unknown", first), access, 0), "unknown figure denied")
check(not Shelves.mutate(state, request("ShelfPlace", id, "row:9/slot:1"), access, 0), "nonvisible local slot denied")
check(Shelves.mutate(state, request("ShelfRemove", nil, second), access, 0), "owner removes")
table.insert(state.shelves.units, { id="shelf:4", placements={}, customization={} })
check(#state.shelves.units == 4, "adding one unit adds exactly one shelf of capacity")
local baseline = Profile.encode(state)
for step, expected in { "2,3,4", "3,4,1", "4,1,2", "1,2,3" } do
	check(Shelves.turn(state.shelves, view, 1, step), "next turns once")
	check(visible(state.shelves, view) == expected, "four-unit sliding viewport sequence")
end
check(Shelves.turn(state.shelves, view, -1, 5) and visible(state.shelves, view) == "4,1,2", "previous wraps one shelf")
check(not Shelves.mutate(state, request("ShelfRemove", nil, first, "shelf:3"), access, 5), "owned hidden shelf cannot be edited")
check(same(Profile.encode(state), baseline), "browsing never changes persisted placements or economy")
check(Shelves.mutate(state, request("ShelfPlace", id, second, "shelf:4"), access, 5), "wrapped viewport edits persistent shelf four at its current position")
check(state.shelves.units[4].placements[second] == id and state.shelves.units[1].placements[second] == nil, "wrapped edit affects only target unit, never viewport position")
table.insert(state.shelves.units, { id="shelf:5", placements={}, customization={} })
view = Shelves.newView(); access.view = view
check(visible(state.shelves, view) == "1,2,3", "five-unit initial trio")
for step, expected in { "2,3,4", "3,4,5", "4,5,1", "5,1,2", "1,2,3" } do
	check(Shelves.turn(state.shelves, view, 1, step) and visible(state.shelves, view) == expected, "five-unit sliding viewport sequence")
end
local stale = request("ShelfPlace", id, first)
Shelves.turn(state.shelves, view, 1, 6); Shelves.turn(state.shelves, view, -1, 7)
check(not Shelves.mutate(state, stale, access, 7), "A-B-A movement rejects stale editing revision")
local staleProfile = request("ShelfPlace", id, first)
staleProfile.revision -= 1
check(not Shelves.mutate(state, staleProfile, access, 7), "unchanged carousel still rejects stale profile revision")
check(not Shelves.turn(state.shelves, view, 1, 7.49), "shared half-second cooldown")
for _, direction in {0,2,math.huge,0/0} do check(not Shelves.turn(state.shelves, view, direction, 8), "invalid direction rejected") end
for index = 6, 250 do table.insert(state.shelves.units, {id="shelf:"..index,placements={},customization={}}) end
check(Profile.decode(Profile.encode(state), 0) ~= nil and #Shelves.publicView(state.shelves, view).visible == 3, "many shelves decode while projection stays three units")
local projection = Shelves.publicView(state.shelves, view)
check(projection.ownedCount == 250 and projection.units == nil and projection.legacyOverflow == nil and projection.coins == nil, "projection excludes hidden units and private data")
projection.visible[1].placements[first] = nil
check(state.shelves.units[1].placements[first] == id, "visible projection owns copies")
state.shelves.units[1].placements["row:1/slot:4"] = id
check(Profile.decode(Profile.encode(state), 0).shelves.units[1].placements["row:1/slot:4"] == id, "future row capacity can expose preserved hidden local slots without migration")
local tx = Transactions.new(0); tx.state = state
local action = request("ShelfPlace", id, first)
local reply = Transactions.process(tx, action, 0, false, 0, 0, access)
local again = Transactions.process(tx, action, 0, false, 0, 0, access)
check(reply and reply.ok and again == reply, "identical retries reuse receipt")
for _, field in {"ownerId", "plotIndex", "physicalPosition", "price", "pageId", "pageRevision"} do
	local spoof = request("ShelfPlace", id, first) :: unknown; (spoof :: {[string]:unknown})[field] = 1
	check(Protocol.parse(spoof) == nil, "identity/retired-field spoof rejected")
end
for _, value in {-1,0.5,math.huge,0/0} do local bad = request("ShelfPlace",id,first); bad.carouselRevision=value; check(Protocol.parse(bad)==nil,"invalid carousel numeric revision denied") end
for _, key in {"unit:1/row:1/slot:1", "viewport:1/row:1/slot:1", "row:0/slot:1", string.rep("x",65)} do check(Protocol.parse(request("ShelfPlace",id,key))==nil,"only bounded local slot identity accepted") end
local nav = {action="ShelfNext",id="next",revision=state.revision,carouselRevision=view.revision}
check(Protocol.parse(nav) ~= nil, "navigation needs revision, not an arbitrary shelf identity")
local badNav = table.clone(nav); badNav.shelfId="shelf:1"
check(Protocol.parse(badNav)==nil,"navigation rejects redundant target identity")

for _, mutate in {
	function(s) s.units={} end,
	function(s) s.units[1]=nil end,
	function(s) s.units[2].id=s.units[1].id end,
	function(s) s.units[1].placements[first]="unknown" end,
	function(s) s.units[1].placements["row:01/slot:1"]=id end,
	function(s) s.units[1].customization.skin="future" end,
	function(s) s.startIndex=2 end,
	function(s) s.legacyOverflow={{sourceId="bad",logicalUnit=4,placements={[first]=id}}} end,
} do local raw=Profile.encode(state); mutate(raw.shelves); check(Profile.decode(raw,0)==nil,"corrupt shelf representation fails closed") end
local huge=Profile.encode(Rules.new(0))
for index=4,Shelves.decodeLimits.units+1 do table.insert(huge.shelves.units,{id="shelf:"..index,placements={},customization={}}) end
check(Profile.decode(huge,0)==nil,"unit decoding allocation guard")
huge=Profile.encode(Rules.new(0)); huge.discovered[id]=true
for index=1,Shelves.decodeLimits.placements+1 do huge.shelves.units[1].placements["row:1/slot:"..index]=id end
check(Profile.decode(huge,0)==nil,"placement decoding budget")
local future=Profile.encode(state); future.schemaVersion=7
check(Profile.decode(future,0)==nil,"future schemas fail closed")

for version=1,5 do
 local old=Profile.encode(state);old.schemaVersion=version
 check(Profile.decode(old,0)==nil,"old schemas cannot enter the reset save namespace")
end
check(Profile.encode(state).shelves.startIndex==nil and Shelves.newView().startIndex==1,"carousel remains runtime only")
print("PASS: "..checks.." Shelf Unit persistence, validation and carousel checks")

