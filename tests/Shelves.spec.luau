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
check(state.schemaVersion == 5 and #state.shelves.units == 3, "fresh schema 5 owns three independent shelves")
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
check(state.owned[id] == 1 and Rules.available(state, id) == 0 and Rules.rate(state) == 7, "no shelf reservations or income")
state.display.slots[1] = ""
check(Rules.rate(state) == 0 and Rules.available(state, id) == 1, "shelves alone earn zero")
state.owned[id] = 2
check(Rules.mutate(state, { action="Recycle", id="r", revision=state.revision, figure=id }, 0), "shelves do not block recycling")
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

-- Retired schema-v4 migration fixtures: each page contains three logical units.
local function legacy4(count)
	local raw = Profile.encode(Rules.new(0)); raw.schemaVersion = 4
	raw.coins=9876; raw.scrap=5; raw.step=5; raw.lastDailyDay=101; raw.goalDay=102; raw.goalProgress=3; raw.goalClaimed=true
	raw.owned[id]=2; raw.display={unlocked=4,slots={id,"","",id}}
	for _, figure in Catalog.figures do raw.discovered[figure.id]=true end
	raw.shelves={pages={}}
	for index=1,count do
		local page={id="page:"..index,placements={},customization={}}
		for unit=1,3 do for row=1,3 do for slot=1,3 do
			page.placements[string.format("unit:%d/row:%d/slot:%d",unit,row,slot)] = Catalog.figures[(index+unit+row+slot)%#Catalog.figures+1].id
		end end end
		table.insert(raw.shelves.pages,page)
	end
	return raw
end
for _, capacity in {1,2} do
	local raw = legacy4(capacity)
	local migrated = Profile.decode(raw,30); assert(migrated)
	check(migrated.schemaVersion==5 and #migrated.shelves.units==capacity*3,"every v4 page becomes exactly three shelves")
	for index,page in raw.shelves.pages do for unit=1,3 do for row=1,3 do for slot=1,3 do
		local target=migrated.shelves.units[(index-1)*3+unit]
		check(target.id=="shelf:"..((index-1)*3+unit) and target.placements[Config.slotId(row,slot)]==page.placements[string.format("unit:%d/row:%d/slot:%d",unit,row,slot)],"every retired placement maps without deduplication")
	end end end end
	check(migrated.coins==9876 and migrated.scrap==5 and migrated.display.unlocked==4 and migrated.display.slots[4]==id and migrated.step==5 and migrated.lastDailyDay==101 and migrated.goalDay==102 and migrated.goalProgress==3 and migrated.goalClaimed,"all unrelated v4 progression preserved")
	check(same(Profile.encode(migrated),Profile.encode(Profile.decode(raw,50))) and raw.schemaVersion==4,"migration deterministic without mutating input")
	check(same(Profile.encode(migrated),Profile.encode(Profile.decode(Profile.encode(migrated),50))),"v5 round trip idempotent")
end
local empty=legacy4(2); for _,page in empty.shelves.pages do page.placements={} end
check(#Profile.decode(empty,0).shelves.units==6,"empty capacity preserved")
local hidden=legacy4(1)
hidden.shelves.pages[1].placements["unit:999/row:1/slot:2"]=id
hidden.shelves.pages[1].placements["unit:4/row:8/slot:7"]=id
local retained=Profile.decode(hidden,0); assert(retained)
check(#retained.shelves.units==3 and #retained.shelves.legacyOverflow==2 and retained.shelves.legacyOverflow[1].logicalUnit==4,"overflow preserved deterministically without capacity grant")
check(retained.shelves.legacyOverflow[2].placements["row:1/slot:2"]==id and same(Profile.encode(retained),Profile.encode(Profile.decode(Profile.encode(retained),0))),"dormant zero-copy references survive v5 round trip")
local snapshot=Profile.encode(retained); snapshot.shelves.legacyOverflow[1].placements["row:8/slot:7"]=nil
check(retained.shelves.legacyOverflow[1].placements["row:8/slot:7"]==id,"dormant snapshots deep copied")
check(Shelves.publicView(retained.shelves,Shelves.newView()).legacyOverflow==nil,"dormant references never projected")
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
local future=Profile.encode(state); future.schemaVersion=6
check(Profile.decode(future,0)==nil,"future schemas fail closed")
local corrupt=legacy4(1); corrupt.shelves.pages[1].customization.future=true
check(Profile.decode(corrupt,0)==nil,"unknown retired customization never erased")
corrupt=legacy4(2); corrupt.shelves.pages[2].id=corrupt.shelves.pages[1].id
check(Profile.decode(corrupt,0)==nil,"duplicate retired identifiers rejected")

-- Retired v3 compatibility still uses validated deterministic packing before v4 conversion.
local old=legacy4(1); old.schemaVersion=3; old.shelves=nil
old.showrooms={palette="dusk",palettes={grove=true,dusk=true},rooms={}}
for roomIndex=1,7 do
	local roomId="custom:"..roomIndex; local placements={}
	for anchor=1,6 do placements["figure_"..anchor]=Catalog.figures[(roomIndex+anchor)%#Catalog.figures+1].id end
	old.showrooms.rooms[roomId]={roomId=roomId,sourceType="Custom",theme="dusk",placements=placements,customization={}}
end
local migrated=Profile.decode(old,0); assert(migrated)
check(#migrated.shelves.units==6,"v3 retains capacity of its two intermediate v4 configurations")
for index=1,42 do
	local room=math.floor((index-1)/6)+1; local anchor=(index-1)%6+1
	local shelf=math.floor((index-1)/9)+1; local localIndex=(index-1)%9
	check(migrated.shelves.units[shelf].placements[Config.slotId(math.floor(localIndex/3)+1,localIndex%3+1)]==old.showrooms.rooms["custom:"..room].placements["figure_"..anchor],"every legacy v3 reference preserved in deterministic order")
end
local v1={schemaVersion=1,coins=33,scrap=2,step=3,owned={[id]=1},discovered={[id]=true},slots={id,"",""}}
local v2=table.clone(v1); v2.schemaVersion=2; v2.unlocked=3; v2.theme="grove"; v2.themes={grove=true}; v2.lastDailyDay=-1; v2.goalDay=-1; v2.goalProgress=0; v2.goalClaimed=false
check(#Profile.decode(v1,0).shelves.units==3 and #Profile.decode(v2,0).shelves.units==3,"v1/v2 migrate to three empty persistent units")
local database: unknown={data=old,token="",writer="old",expires=0,generation=9}
local update: Persistence.Update=function(_,transform) local result=transform(database); if result then database=result end; return result end
local handle,loaded=Persistence.load(update,"test","new",1000,0)
check(handle~=nil and loaded~=nil and loaded.schemaVersion==5 and #loaded.shelves.units==6,"v3 migration through storage lease acquisition")
local complete=Profile.decode(legacy4(1),0); assert(complete)
check(#complete.shelves.units==3,"completion tracking creates no new capacity or reward")
check(Profile.encode(state).shelves.startIndex==nil and Shelves.newView().startIndex==1,"carousel is runtime only and resets on rejoin")
print(string.format("PASS: %d Shelf Unit schema/migration/carousel/domain checks",checks))
