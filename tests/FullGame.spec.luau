--!strict
local Rules = require("./Rules")
local Profile = require("./Profile")
local Persistence = require("./Persistence")
local Transactions = require("./Transactions")
local Protocol = require("./Protocol")
local Types = require("./Types")
local Economy = require("./Economy")
local checks = 0
local function check(condition: boolean, message: string)
	assert(condition, message)
	checks += 1
end
local function request(action: string, revision: number, choice: string?, figure: string?, slot: number?): Types.Intent
	return { action = action, id = tostring(revision) .. action, revision = revision, choice = choice, figure = figure, slot = slot }
end
local state = Rules.new(0)
check(Rules.roll(0,"tide") == "tide.bubble" and Rules.roll(0.9,"tide") == "tide.pearl", "collection rolls isolated")
check(not Rules.mutate(state,request("Expand",0),0,10) and state.coins==450, "expansion affordability")
state.coins=10000
check(Rules.mutate(state,request("Expand",0),0,10), "expand")
check(state.unlocked==4 and #state.slots==4 and state.coins==6000, "single bounded expansion")
check(not Rules.mutate(state,request("Expand",1),0,10) and state.coins==6000, "expansion cannot charge twice")
check(Rules.mutate(state,request("Theme",1,"ocean"),0,10), "buy palette")
check(state.theme=="ocean" and state.themes.ocean and state.coins==4800, "palette conservation")
check(Rules.mutate(state,request("Theme",2,"grove"),0,10), "equip free owned palette")
check(Rules.mutate(state,request("Theme",3,"ocean"),0,10) and state.coins==4800, "owned palette free")
check(Rules.mutate(state,request("Daily",4,"tide"),0.99,10), "daily claim")
check(state.owned["tide.pearl"]==1 and state.coins==4800 and state.lastDailyDay==10, "daily marker and grant together")
check(not Rules.mutate(state,request("Daily",5,"grove"),0,10), "daily choice cannot bypass limit")
local restored=Profile.decode(Profile.encode(state),200)
assert(restored)
check(not Rules.mutate(restored,request("Daily",0,"grove"),0,10), "reconnect cannot reclaim")
check(not Rules.mutate(restored,request("Daily",0,"grove"),0,9), "clock rollback cannot reclaim")
check(Rules.mutate(restored,request("Daily",0,"grove"),0,11), "next UTC day eligible")
local full=Rules.new(0); full.owned["grove.pebble"]=200; full.discovered["grove.pebble"]=true
check(not Rules.mutate(full,request("Daily",0,"grove"),0,20) and full.lastDailyDay==-1, "full inventory preserves claim")
local distinct={"grove.pebble","grove.sprout","grove.acorn"}
for slot,id in distinct do restored.owned[id]=1; restored.discovered[id]=true; restored.slots[slot]=id end
Rules.refreshDay(restored,11)
check(restored.goalProgress==3 and Rules.bonus(restored)==1, "distinct themed shelf and goal")
local before=restored.coins
check(Rules.mutate(restored,request("Goal",restored.revision),0,11) and restored.coins==before+Economy.goalReward, "goal reward")
check(not Rules.mutate(restored,request("Goal",restored.revision),0,11), "goal cannot repeat")
Rules.refreshDay(restored,12)
check(not restored.goalClaimed and restored.goalProgress==3, "new day resets goal claim")
local duplicates=Rules.new(0); duplicates.owned["grove.star"]=3; duplicates.slots={"grove.star","grove.star","grove.star"}
check(Rules.bonus(duplicates)==0 and Rules.rate(duplicates)==21, "duplicates have no themed bonus")
local encoded=Profile.encode(restored)
local loaded=Profile.decode(encoded,10000)
assert(loaded)
check(loaded.coins==restored.coins and loaded.theme=="ocean" and loaded.unlocked==4 and loaded.lastDailyDay==11, "profile round trip")
check(loaded.time==10000 and loaded.fraction==0 and loaded.revision==0, "runtime data not persisted")
encoded.owned["grove.pebble"]=99
check(restored.owned["grove.pebble"]==1, "save snapshot owns copies")
for _,field in {"coins","scrap","step","unlocked","lastDailyDay","goalDay","goalProgress"} do
	for _,bad in {0/0,math.huge,-999,1.25} do
		local corrupt = Profile.encode(restored) :: unknown
		(corrupt :: { [string]: unknown })[field]=bad
		check(Profile.decode(corrupt,0)==nil,"reject corrupt numeric "..field)
	end
end
local corrupt=Profile.encode(restored); corrupt.schemaVersion=999
check(Profile.decode(corrupt,0)==nil,"future schema blocked")
corrupt=Profile.encode(restored); corrupt.owned["unknown"]=1
check(Profile.decode(corrupt,0)==nil,"unknown inventory ID blocked")
corrupt=Profile.encode(restored); corrupt.slots[1]="tide.ray"
check(Profile.decode(corrupt,0)==nil,"unowned reservation blocked")
corrupt=Profile.encode(restored); corrupt.themes.ocean=nil
check(Profile.decode(corrupt,0)==nil,"unowned theme blocked")
corrupt=Profile.encode(restored); corrupt.goalProgress=0; corrupt.goalClaimed=true
check(Profile.decode(corrupt,0)==nil,"invalid goal claim blocked")
local legacy: { [string]: unknown } = {schemaVersion=1,coins=123,scrap=2,step=3,owned={ ["grove.pebble"]=1 },discovered={ ["grove.pebble"]=true },slots={"grove.pebble","",""}}
local migrated=Profile.decode(legacy,90)
check(migrated~=nil and migrated.coins==123 and migrated.unlocked==3 and migrated.themes.grove and migrated.lastDailyDay==-1,"version-one migration preserves facts")
check(legacy.schemaVersion==1,"migration does not mutate input")
local database: { [string]: unknown }={}
local calls=0
local function update(key: string,transform: (unknown)->unknown): unknown
	calls+=1
	-- Roblox may retry a transform. It must not issue a second grant or advance local state.
	transform(database[key])
	local result=transform(database[key])
	if result~=nil then database[key]=result end
	return result
end
local handle, original=Persistence.load(update,"p","server-a",100,0)
assert(handle and original)
check(original.coins==450,"new persisted profile gets starter once")
local other=Persistence.load(update,"p","server-b",101,0)
check(other==nil,"active lease prevents competing server")
local ownRetry=Persistence.load(update,"p","server-a",102,0)
check(ownRetry~=nil,"uncertain acquire can retry same token")
original.coins=300
check(Persistence.save(update,handle,Profile.encode(original),110,false),"save owns lease")
check(handle.generation==1,"transform retry increments once")
local failBefore: Persistence.Update=function() error("injected offline") end
local absent=Persistence.load(failBefore,"p","server-z",111,0)
check(absent==nil,"failed read never creates defaults")
check(not Persistence.save(failBefore,handle,Profile.encode(original),111,false) and handle.generation==1,"failed save keeps generation")
local thrown=false
local uncertain: Persistence.Update=function(key,transform)
	local result=update(key,transform)
	if not thrown then thrown=true; error("reply lost after commit") end
	return result
end
original.scrap=6
local snapshot=Profile.encode(original)
check(not Persistence.save(uncertain,handle,snapshot,112,false),"unknown save outcome")
check(Persistence.save(uncertain,handle,snapshot,113,false) and handle.generation==2,"uncertain save recovered without duplicate generation")
check(Persistence.save(update,handle,snapshot,114,true),"release saves and unlocks")
local newHandle,rejoined=Persistence.load(update,"p","server-b",115,900)
assert(newHandle and rejoined)
check(rejoined.coins==300 and rejoined.scrap==6,"rejoin restores, no extra starter")
check(not Persistence.save(update,handle,snapshot,116,false),"old owner cannot overwrite new owner")
local takeover=Persistence.load(update,"p","server-c",236,0)
assert(takeover)
check(not Persistence.save(update,newHandle,Profile.encode(rejoined),237,false),"expired owner rejected after takeover")
database["broken"]={foo="bar"}
check(Persistence.load(update,"broken","server-a",200,0)==nil,"corrupt stored record blocked")
check((database["broken"] :: {foo:string}).foo=="bar","corrupt data preserved")
local active=Transactions.new(0)
active.state.coins=10000
local expansion=request("Expand",0)
local first=Transactions.process(active,expansion,0,true,0,50)
local repeated=Transactions.process(active,expansion,1,true,0,50)
check(first~=nil and first==repeated and active.state.coins==6000,"expansion replay safe")
check(Protocol.parse({action="Theme",id="x",revision=0,choice="fake"})==nil,"unknown cosmetic rejected")
check(Protocol.parse({action="Daily",id="x",revision=0,choice="fake"})==nil,"unknown daily box rejected")
check(Protocol.parse({action="Goal",id="x",revision=0,choice="grove"})==nil,"extra goal field rejected")
check(Protocol.parse({action="Expand",id="x",revision=0,price=0})==nil,"client expansion price rejected")
local extra = Profile.encode(restored) :: unknown
(extra :: { [string]: unknown }).futureField = true
check(Profile.decode(extra, 0) == nil, "unknown fields cannot be silently discarded")
local claimed = false
local lostAcquire: Persistence.Update = function(key, transform)
	local result = update(key, transform)
	if not claimed then claimed = true; error("lost acquisition response") end
	return result
end
check(Persistence.load(lostAcquire, "uncertain", "new-token", 300, 0) == nil, "uncertain acquisition is not playable")
local recovered, acquiredState = Persistence.load(lostAcquire, "uncertain", "new-token", 301, 0)
assert(recovered and acquiredState)
check(acquiredState.coins == 450, "acquisition retry does not double starter grant")
local releaseLost = false
local uncertainRelease: Persistence.Update = function(key, transform)
	local result = update(key, transform)
	if not releaseLost then releaseLost = true; error("lost release response") end
	return result
end
local releaseData = Profile.encode(acquiredState)
check(not Persistence.save(uncertainRelease, recovered, releaseData, 302, true), "uncertain release")
check(Persistence.save(uncertainRelease, recovered, releaseData, 303, true), "release retry reconciles own writer")
local conflict = Persistence.load(update, "uncertain", "third-token", 304, 0)
assert(conflict)
check(not Persistence.save(update, recovered, releaseData, 305, true), "old release cannot clear new lease")
local badEnvelope = database["uncertain"] :: Persistence.Record
badEnvelope.expires = 0 / 0
check(Persistence.load(update, "uncertain", "fourth-token", 306, 0) == nil, "NaN lease rejected")
print(string.format("PASS: %d full-game and persistence fault checks (%d storage calls)",checks,calls))
