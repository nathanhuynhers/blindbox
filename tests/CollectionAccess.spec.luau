--!strict
local Access = require("./CollectionAccess")
local Catalog = require("./Catalog")
local Rules = require("./Rules")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local UI = require("./UIState")
local Owner = require("./ConvenienceOwner")
local Engine = require("./OpeningEngine")
local Movement = require("./PlayerMovement")
local SnapshotSender = require("./SnapshotSender")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local tiers = {moon=1,dessert=2,halloween=2,chess=3,emotion=4,astral=5,biome=6,weather=6,sense=7,olympian=8,birthstone=9,sin=10,orbit=11}
local targets = {echo={0,9},star={0,9},moon={1,9},dessert={2,7},halloween={2,7},chess={3,4},emotion={4,7},astral={5,9},biome={6,3},weather={6,3},sense={7,3},olympian={8,6},birthstone={9,3}}
local function history(collection, count, legendary)
	local result = {}
	local n = 0
	if legendary then
		for _, f in Catalog.figures do
			if f.collection == collection and f.rarity == "Legendary" then result[f.id] = true; n = 1; break end
		end
	end
	for _, f in Catalog.figures do
		if n < count and f.collection == collection and f.rarity ~= "Mythical" and (legendary or f.rarity ~= "Legendary") and not result[f.id] then
			result[f.id] = true; n += 1
		end
	end
	return result
end
local empty = Access.view({})
check(empty.frontier == 0 and empty.highestQualifiedTier == -1, "No expansion access initially")
for _, c in Catalog.collections do
	check(empty.collections[c.id].unlocked == (tiers[c.id] == nil), "Original five remain available: "..c.id)
end
for collection, target in targets do
	local below = history(collection,target[2]-1,true)
	check(Access.view(below).frontier == 0, "Exact count required: "..collection)
	for _, f in Catalog.figures do
		if f.collection == collection and f.rarity == "Mythical" then below[f.id] = true end
	end
	check(Access.view(below).frontier == 0, "Mythicals do not fill the missing discovery: "..collection)
	local noLegendary = history(collection,100,false)
	for _, f in Catalog.figures do if f.collection == collection and f.rarity == "Mythical" then noLegendary[f.id] = true end end
	check(Access.view(noLegendary).frontier == 0, "Mythical cannot substitute for Legendary: "..collection)
	local qualifying = history(collection,target[2],true)
	local view = Access.view(qualifying)
	check(view.frontier == math.min(11,target[1]+2) and view.highestQualifiedTier == target[1], "Approved two-tier advancement: "..collection)
	for id, tier in tiers do
		check(Access.canBuy(qualifying,id) == (tier <= view.frontier), "Everything below frontier remains available: "..collection..id)
	end
	check(not Access.canBuy(qualifying,"forged"), "Unknown collection cannot be authorized")
end
for _, pair in {{"echo","star"},{"dessert","halloween"},{"biome","weather"}} do
	local combined = history(pair[1],targets[pair[1]][2]-1,true)
	for id in history(pair[2],targets[pair[2]][2]-1,true) do combined[id] = true end
	check(Access.view(combined).frontier == 0, "OR routes never combine partial counts")
end
local state = Rules.new(0)
Rules.grantFigure(state,"moon.rabbit",10000)
check(Access.view(state.discovered).frontier == 0, "Duplicate copies count once")
state.discovered = history("dessert",7,true)
check(Access.view(state.discovered).frontier == 4 and not state.discovered["moon.rabbit"], "Higher qualification skips incomplete lower tiers and baseline")
check(not state.shelfRewards.dessert, "Qualification is not full completion")
local high = history("birthstone",3,true)
state.discovered = high
state.owned = {}
for id in high do state.owned[id] = 1 end
local ids = {}
for id in high do table.insert(ids,id) end
check(Rules.adminFigures(state,ids,1,true,0), "Final-copy removal succeeds")
check(next(state.owned) == nil and Access.view(state.discovered).frontier == 11, "Access survives loss of every qualifying copy")
local saved = Profile.encode(state)
local loaded = assert(Profile.decode(saved,10))
check(Access.view(loaded.discovered).frontier == 11 and loaded.schemaVersion == state.schemaVersion, "Existing-player discovery credit survives save/rejoin without new schema")
saved.discovered[ids[1]] = nil
check(loaded.discovered[ids[1]] == true, "Decoded discovery state is owned independently")

local function same(a,b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k,v in a do if not same(v,b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
for _, action in {"Buy","BuyTen"} do
	local s = Transactions.new(0)
	s.state.coins = 1e15
	Rules.grantFigure(s.state,"grove.pebble",1)
	s.state.display.slots[1] = "grove.pebble"
	s.state.earnings["grove.pebble"] = 12.5
	local before = Profile.encode(s.state)
	local rolls = 0
	local reply = Transactions.process(s,{id=action,action=action,choice="moon",revision=0},20,false,{0.9,0,0,0,0,0,0,0,0,0},10,nil,nil,0,function() rolls+=1; return "moon.rabbit" end)
	check(reply and not reply.ok and string.find(reply.message,"locked"), "Locked paid opening rejected")
	check(rolls == 0 and same(before,Profile.encode(s.state)) and s.state.time == 0, "Locked purchase has no economic/day/pity/settlement mutation")
	check(Transactions.process(s,{id=action,action=action,choice="moon",revision=0},21,false,0,10) == reply, "Locked receipt replays exactly")
	s.state.discovered = history("echo",9,true)
	local ok = Transactions.process(s,{id=action.."unlocked",action=action,choice="moon",revision=0},22,false,{0,0,0,0,0,0,0,0,0,0},10)
	check(ok and ok.ok and s.state.coins == 1e15 - (if action == "Buy" then 2e6 else 2e7), "Unlocked ordinary price/grant retained")
end
for _, extra in {{unlocked=true},{collectionAccess={frontier=11}},{discovered=high},{target=123}} do
	local raw = {id="forged",action="Buy",choice="moon",revision=0}
	for k,v in extra do raw[k]=v end
	check(Protocol.parse(raw) == nil, "Forged access fields are rejected")
end

-- The captured-session Auto Open adapter must stop before asking for rolls or a purchase.
local t = Transactions.new(0)
t.state.coins = 1e15
local rolls, changes = 0, 0
Engine.player.Character.ChildAdded = Engine.signal()
local binding = Movement.bind(Engine.player)
local owner = Owner.create({state=t.state,handle={},ready=true,closed=false,transferring=false,busy=false,safeUntil=1000},t,binding,{
	now=function() return 100 end,id=function() return "auto-gate" end,current=function() return true end,alive=function() return true end,
	ownership=function() return true,true end,purchaseBusy=function() return false end,policyAllowed=function() return true end,spendable=function() return t.state.coins end,
	snapshot=function() return {} end,rolls=function() rolls+=1; return {0} end,day=function() return 10 end,window=function() return 0 end,
	deliver=function() end,changed=function() changes+=1 end,
})
owner.collection("moon")
check(not owner.openAllowed() and not owner.open.start("moon",10,0), "Authoritative Auto Open cannot start locked collection")
owner.open.step()
check(rolls == 0 and changes == 0 and t.state.coins == 1e15 and t.state.boxesOpened == 0, "Locked Auto Open never rolls or mutates")
t.state.discovered = history("star",9,true)
check(owner.openAllowed() and owner.open.start("moon",1,0), "Auto Open reflects authoritative discoveries immediately")
owner.open.step()
check(rolls == 1 and changes == 1 and t.state.coins == 1e15-2e6, "Unlocked Auto Open uses ordinary transaction")
owner.open.destroy(); owner.collect.destroy(); Movement.unbind(binding)

-- Actual owner snapshots isolate access and refresh after authoritative grants.
local snapshots = {}
local send = SnapshotSender({FireClient=function(_,player,snapshot) snapshots[player]=snapshot end})
local function session()
	return {transaction=Transactions.new(0),sequence=0,plot={view={first=1,revision=0},showcase={editorToken=0}},storage={status="Ready",ready=true}}
end
local alice,bob = session(),session()
alice.transaction.state.discovered = history("biome",3,true)
send("alice",alice); send("bob",bob)
check(snapshots.alice.collectionAccess.frontier == 8 and snapshots.bob.collectionAccess.frontier == 0, "Private player access isolation")
snapshots.alice.collectionAccess.collections.olympian.unlocked = false
check(Access.canBuy(alice.transaction.state.discovered,"olympian"), "Forged presentation cannot change authority")
alice.transaction.state.discovered = history("chess",3,true)
send("alice",alice)
local text = UI.accessText(snapshots.alice,"astral")
check(string.find(text,"3/4",1,true) and string.find(text,"Legendary: found",1,true), "UI uses separate unique and Legendary progress")
check(UI.purchaseLock(snapshots.alice,"astral") == "Purchases locked", "Progression lock differs from affordability")
check(UI.purchaseLock({} :: any,"moon") == "Access confirmation pending", "Unknown authority fails closed")
local baselineText = UI.accessText(snapshots.bob,"moon")
check(string.find(baselineText,"Tender Echoes",1,true) and string.find(baselineText,"We Are All Stars",1,true) and string.find(baselineText,"\nOR\n",1,true), "Alternative route progress is separate")
-- Legitimate existing rewards remain claimable with no expansion qualification.
local reward = Rules.new(0)
check(Rules.mutate(reward,{action="Daily",id="daily",revision=0,choice="grove"},0,10), "Daily reward remains available")
check(Rules.mutate(reward,{action="Welcome",id="welcome",revision=reward.revision},0,10), "Welcome reward remains available")
reward.step = 5
check(Rules.mutate(reward,{action="WelcomeTen",id="welcome-ten",revision=reward.revision},{0,0,0,0,0,0,0,0,0,0},10), "Earned Welcome x10 remains available")
reward.lastLoginDay,reward.loginStreak = 9,2
check(Rules.mutate(reward,{action="Login",id="login",revision=reward.revision},0,10), "Login box reward remains available")
Rules.grantFigure(reward,"orbit.earth",1)
check(not Access.canBuy(reward.discovered,"orbit"), "Reward ownership alone cannot unlock purchases")
check(Rules.mutate(reward,{action="Place",id="place-locked-owned",revision=reward.revision,figure="orbit.earth",slot=1},0,10,0), "Owned locked-collection figure remains usable on Display")
check(reward.display.slots[1]=="orbit.earth" and UI.copies({owned=reward.owned,slots=reward.display.slots},"orbit.earth")==1,"Locked purchases do not hide owned figures")
print("PASS:",checks,"collection qualification, purchase authority, permanent discovery and access projection checks")
