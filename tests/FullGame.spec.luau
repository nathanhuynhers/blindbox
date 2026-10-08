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
local state=Rules.new(0)
check(not Rules.mutate(state,request("Expand",0),0,10),"expansion affordability")
state.coins=4440000
for slot=4,6 do
 check(Rules.mutate(state,request("Expand",state.revision),0,10),"sequential slot purchase")
 check(state.display.unlocked==slot and #state.display.slots==slot,"dense unlocked slots")
end
check(state.coins==0 and not Rules.mutate(state,request("Expand",state.revision),0,10),"six-slot bound")
local restored=Rules.new(0)
restored.owned["grove.pebble"]=2000
restored.discovered["grove.pebble"]=true
restored.display.slots[1]="grove.pebble"
restored.pityByGroup.echo={legendaryDryRolls=99,mythicalDryRolls=500}
local encoded=Profile.encode(restored)
local loaded=Profile.decode(encoded,10000)
check(loaded and loaded.owned["grove.pebble"]==2000 and loaded.pityByGroup.echo.mythicalDryRolls==500,"quantity and pity round trip")
encoded.pityByGroup.echo.mythicalDryRolls=0
check(restored.pityByGroup.echo.mythicalDryRolls==500,"pity snapshot deep copy")
for _, field in {"coins","step","lastDailyDay","goalDay","goalProgress"} do
 for _, bad in {0/0,math.huge,-999,1.25} do
  local corrupt=Profile.encode(restored);corrupt[field]=bad
  check(Profile.decode(corrupt,0)==nil,"invalid numeric field")
 end
end
for _, mutate in {
 function(s) s.pityByGroup.echo.legendaryDryRolls=0/0 end,
 function(s) s.pityByGroup.echo.mythicalDryRolls=-1 end,
 function(s) s.pityByGroup.echo.extra=true end,
 function(s) s.pityByGroup.foreign={legendaryDryRolls=0,mythicalDryRolls=0} end,
 function(s) s.owned["unknown"]=1 end,
 function(s) s.display.slots[2]="grove.pebble" end,
 function(s) s.display.slots[2]="tide.ray" end,
 function(s) s.display.slots[2]=nil end,
 function(s) s.scrap=0 end,
 function(s) s.schemaVersion=5 end,
 function(s) s.schemaVersion=15 end,
 function(s) s.goalClaimed=true; s.goalProgress=0 end,
} do
 local corrupt=Profile.encode(restored);mutate(corrupt)
 check(Profile.decode(corrupt,0)==nil,"invalid profile fails closed")
end
check(Rules.mutate(restored,request("Daily",0,"grove"),0,10),"daily claim")
check(not Rules.mutate(restored,request("Daily",0,"grove"),0,9),"daily clock rollback")
local again=Profile.decode(Profile.encode(restored),100)
check(not Rules.mutate(again,request("Daily",0,"grove"),0,10),"rejoin cannot reclaim")
check(Rules.mutate(again,request("Daily",0,"grove"),0,11),"next UTC day")
for slot,id in {"grove.pebble","grove.sprout","grove.acorn"} do
 restored.owned[id]=1;restored.discovered[id]=true;restored.display.slots[slot]=id
end
Rules.refreshDay(restored,20)
local cappedGoal=Profile.decode(Profile.encode(restored),0)
assert(cappedGoal)
cappedGoal.coins=Economy.coinLimit
check(not Rules.mutate(cappedGoal,request("Goal",cappedGoal.revision),0,20)
 and not cappedGoal.goalClaimed and cappedGoal.goalProgress==3,"failed claim preserves active unclaimed goal")
local before=restored.coins
check(Rules.mutate(restored,request("Goal",0),0,20) and restored.coins==before+Economy.goalReward,"daily goal")
check(not Rules.mutate(restored,request("Goal",0),0,20),"goal once")
local goalReload=Profile.decode(Profile.encode(restored),200)
assert(goalReload)
check(goalReload.goalClaimed and goalReload.goalProgress==3 and goalReload.goalDay==20,"claimed goal and progress survive save/rejoin")
local claimedCoins=goalReload.coins
check(not Rules.mutate(goalReload,request("Goal",goalReload.revision),0,20) and goalReload.coins==claimedCoins,"rejoin cannot reclaim goal")
check(not Rules.mutate(goalReload,request("Goal",goalReload.revision),0,19),"clock rollback cannot reclaim goal")
Rules.refreshDay(goalReload,21)
check(not goalReload.goalClaimed and goalReload.goalProgress==3,"next UTC day legitimately restores goal")
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
check(original.coins==4500,"new persisted profile gets starter once")
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
original.pityByGroup.echo={legendaryDryRolls=70,mythicalDryRolls=400}
local snapshot=Profile.encode(original)
check(not Persistence.save(uncertain,handle,snapshot,112,false),"unknown save outcome")
check(Persistence.save(uncertain,handle,snapshot,113,false) and handle.generation==2,"uncertain save recovered without duplicate generation")
check(Persistence.save(update,handle,snapshot,114,true),"release saves and unlocks")
local newHandle,rejoined=Persistence.load(update,"p","server-b",115,900)
assert(newHandle and rejoined)
check(rejoined.coins==300 and rejoined.pityByGroup.echo.mythicalDryRolls==400,"rejoin restores, no extra starter")
check(not Persistence.save(update,handle,snapshot,116,false),"old owner cannot overwrite new owner")
local takeover=Persistence.load(update,"p","server-c",236,0)
assert(takeover)
check(not Persistence.save(update,newHandle,Profile.encode(rejoined),237,false),"expired owner rejected after takeover")
database["broken"]={foo="bar"}
check(Persistence.load(update,"broken","server-a",200,0)==nil,"corrupt stored record blocked")
check((database["broken"] :: {foo:string}).foo=="bar","corrupt data preserved")
local active=Transactions.new(0)
active.state.coins=100000
local expansion=request("Expand",0)
local first=Transactions.process(active,expansion,0,true,0,50)
local repeated=Transactions.process(active,expansion,1,true,0,50)
check(first~=nil and first==repeated and active.state.coins==60000,"expansion replay safe")
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
check(acquiredState.coins == 4500, "acquisition retry does not double starter grant")
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
