--!strict
-- Isolated gate-enabled copies, actual Storage/Persistence/Runtime and fake DataStore.
local E = require("./AfkEngine")
local Storage = require("./Storage")
local Runtime = require("./OfflineRuntime")
local Awards = require("./OfflineAwards")
local Credits = require("./OfflineCredits")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local player = {UserId=17}
E.game:GetService("Players").GetPlayerByUserId = function(_,id) return if id==17 then player else nil end
local owner = assert(Storage.open(17))
local runtime = Runtime.create(function(p) return if p==player then owner else nil end, function() end)
local product={key="offline_double",kind="DeveloperProduct",platformId=101,benefits={offlineCredits=1}}
owner.state.offlinePending,owner.state.offlineSeconds=10000,3600
Awards.freeze(owner.state,"display-v1")
owner.state.schemaVersion=17
E.before=3
check(runtime.control(17,{id="select",action="Select",awardId="offline:1"}).status=="Recovering",
	"Failed real selection save cannot authorize purchase")
check(not owner.ready and owner.pendingSave.offlineCredits.selected=="offline:1", "Exact pending schema19 selection retained")
check(not runtime.prepare(17,product),"Unconfirmed selection cannot prompt")
check(Storage.flush(owner,false) and runtime.prepare(17,product),"Original save reconciliation authorizes selected return")
E.after=3
local receipt={userId=17,productId=101,purchaseId="lost"}
check(not runtime.fulfill(receipt,product),"Lost committed receipt response defers ack")
check(E.database.Player_17.data.offlineCredits.receipts.lost==101
	and E.database.Player_17.data.offlinePending==10000,"Receipt persists credit without paying or selecting a new award")
check(Storage.flush(owner,false) and runtime.fulfill(receipt,product),"Reconciled receipt replay acknowledges once")
check(Credits.available(owner.state.offlineCredits)==1 and not runtime.eligible(17,product), "Owned credit prevents competing new checkout")
check(Storage.prepareTeleport(owner),"AFK saves and releases paid credit and selection")
local source=owner
check(not runtime.fulfill({userId=17,productId=101,purchaseId="handoff"},product),"Released source cannot grant credits")
owner=assert(Storage.open(17))
check(owner.state.coins==14500 and owner.state.offlinePending==0
	and owner.state.offlineCredits.returns["offline:1"].baseClaimed,
	"Destination auto-claims base while retaining old frozen return and credit")
owner.state.offlinePending=7
Awards.freeze(owner.state,"display-v2")
check(Storage.flush(owner,false),"New return saved beside old selection")
E.after=3
check(runtime.control(17,{id="use",action="Redeem",awardId="offline:1"}).status=="Recovering",
	"Lost real redemption response retains atomic marker and extra")
check(E.database.Player_17.data.offlineData.assistedCredit==10000
	and E.database.Player_17.data.offlinePending==7,"Committed old extra never consumes newer N")
check(Storage.flush(owner,false),"Original redemption generation recovers")
check(runtime.control(17,{id="use",action="Redeem",awardId="offline:1"}).status=="Redeemed"
	and owner.state.offlineData.assistedCredit==10000,"Redemption replay never repeats N")
check(not Storage.recoverTeleport(source),"Old source cannot reacquire destination lease")
check(Storage.close(owner),"Destination safely persists and releases schema19")
print(string.format("PASS: %d actual recurring credit Storage/Persistence/AFK checks",checks))
