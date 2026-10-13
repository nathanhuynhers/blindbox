--!strict
local Journal = require("./PurchaseJournal")
local Config = require("./PurchaseConfig")
local Service = require("./PurchaseService")
local database, snapshots = {}, {}
local mode, now, prompts = "ok", 0, 0
local function update(key, transform)
	if mode == "fail" then error("isolated unavailable store") end
	local result=transform(database[key]); if result then database[key]=result end
	if mode == "yield-begin" and result and result.pending then mode="ok"; coroutine.yield() end
	if mode == "lost-clear" and string.sub(key,1,7)=="Prompt_" and result and not result.pending then error("lost journal-clear response after commit") end
	if mode == "lost" then error("isolated lost reply after commit") end
	return result
end
local pending={id="request1",product="pack_small",platformId=101,kind="DeveloperProduct",baseline=0}
assert(Journal.load(update,7),"empty journal")
mode="lost"; assert(not Journal.begin(update,7,pending),"lost begin response fails closed")
mode="ok"; assert(Journal.load(update,7).pending.id=="request1","uncertain prompt obligation survives")
assert(not Journal.begin(update,7,pending),"unresolved obligation can't be overwritten")
assert(not Journal.resolve(update,7,"different"),"old callback can't clear newer obligation")
assert(Journal.resolve(update,7,"request1") and not Journal.load(update,7).pending,"confirmed resolution")
for _, raw in { {version=2}, {version=1,pending={}}, {version=1,pending={id="x",product="p",platformId=0/0,kind="Pass",baseline=0}}, {version=1,unknown=true}, {version=1,pending={id="x",product="p",platformId=1,kind="Pass",baseline=math.huge}} } do assert(Journal.decode(raw)==nil,"corrupt/future journal fails closed") end
local raw={version=2}; database.Prompt_8=raw
assert(not Journal.load(update,8) and database.Prompt_8==raw,"newer record never overwritten")
local product=table.clone(Config.find("pack_small")); product.platformId=101; product.kind="DeveloperProduct"; product.integrationReady=true; product.salesEnabled=true
local service=Service.create({now=function() return now end,ready=function() return true end,update=update,owns=function() return false end,eligible=function() return true end,
	prompt=function() prompts+=1; return true end,deliverReserved=function() return true end,send=function(userId,value) snapshots[userId]=value end}, {product})
service.add(7); service.request(7,{id="paid",action="Purchase",product="pack_small"})
assert(prompts==1 and Journal.load(update,7).pending,"journal committed before sole native prompt")
service.finished(7,101,"DeveloperProduct",true)
service.remove(7); service.add(7)
assert(snapshots[7].recoveryProduct=="pack_small" and service.busy(7),"rejoin retains pre-receipt obligation")
service.request(7,{id="new",action="Purchase",product="pack_small"})
assert(prompts==1,"rejoin can't reprompt unresolved payment")
mode="lost"
assert(not service.receipt({PurchaseId="late",PlayerId=7,ProductId=101}),"lost receipt reply defers")
mode="ok"
assert(service.receipt({PurchaseId="late",PlayerId=7,ProductId=101}),"delayed receipt resolves journal and original grant")
assert(not Journal.load(update,7).pending and not service.busy(7),"durable fulfillment releases recovery")
service.request(7,{id="receipt-first",action="Purchase",product="pack_small"})
assert(service.receipt({PurchaseId="early",PlayerId=7,ProductId=101}),"receipt before close")
assert(service.busy(7),"native prompt still active")
service.finished(7,101,"DeveloperProduct",true)
assert(not service.busy(7),"both obligations resolved in either order")
now+=10
service.request(7,{id="cancel",action="Purchase",product="pack_small"}); service.finished(7,101,"DeveloperProduct",false)
service.remove(7); service.add(7)
assert(not service.busy(7) and not Journal.load(update,7).pending,"cancelled journal resolves across rejoin")
mode="yield-begin"
local attempted=prompts
local oldJoin=coroutine.create(function() service.request(7,{id="old-join",action="Purchase",product="pack_small"}) end)
assert(coroutine.resume(oldJoin),"prompt journal yields")
service.remove(7); service.add(7)
assert(coroutine.resume(oldJoin),"old request finishes its status save")
assert(prompts==attempted,"old join cannot launch native prompt for a replacement session")
now+=11; service.refresh(7)
service.request(7,{id="lost-clear",action="Purchase",product="pack_small"})
service.finished(7,101,"DeveloperProduct",true)
mode="lost-clear"
assert(not service.receipt({PurchaseId="clear-lost",PlayerId=7,ProductId=101}),"unconfirmed journal clear defers receipt acknowledgement")
mode="ok"; now+=11; service.refresh(7)
assert(service.receipt({PurchaseId="clear-lost",PlayerId=7,ProductId=101}),"receipt replay resolves a lost clear response")
assert(snapshots[7].receiptCount==3 and not service.busy(7),"lost clear does not duplicate paid value or lose recovery")
print("PASS: durable prompt-status journal corruption, lost replies, reconnect, receipt order and cancellation fixtures")
