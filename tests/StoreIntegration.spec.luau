--!strict
-- Actual coordinator, projection, Store and P02 service; injected platform/storage, no charges.
local Client = require("./PurchaseClient")
local Price = require("./PurchasePrice")
local Projection = require("./StoreProjection")
local Service = require("./PurchaseService")
local Config = require("./PurchaseConfig")
local Ledger = require("./PurchaseLedger")
local Rules = require("./Rules")
local Engine = require("./UIEngine")
local Store = require("./StoreScreen")
local Scope = require("./UIScope")
local Presentation = require("./StorePresentation")
local Offline = require("./OfflinePurchaseClient")
local checks = 0
local function check(ok, message) checks += 1; assert(ok, message) end
for _, raw in { {}, {PriceInRobux=49}, {IsForSale=false, PriceInRobux=49}, {IsForSale=true, PriceInRobux=0/0}, {IsForSale=true, PriceInRobux=math.huge}, {IsForSale=true, PriceInRobux=-1}, {IsForSale=true, PriceInRobux=1.5} } do
	check(Price.read(raw) == nil, "invalid metadata fails closed")
end
check(Price.read({IsForSale=true, PriceInRobux=0}) == 0, "actual zero platform price")
check(Price.read({IsForSale=true, PriceInRobux=1234567}) == 1234567, "long platform price retained")
local now, serial, prompts = 100, 0, 0
local canPrompt, metadata, delivered, failSave, owned = true, true, true, false, false
local sends = {}
local backing = {}
local products = {}
for _, definition in { {"pack_small",false,1}, {"movement",true,2}, {"offline_double",false,3}, {"coins_boost_15",false,4}, {"coins_boost_30",false,5}, {"coins_boost_60",false,6} } do
	local product = table.clone(Config.find(definition[1]))
	product.kind = if definition[2] then "Pass" else "DeveloperProduct"
	product.platformId, product.salesEnabled, product.integrationReady = definition[3], true, true
	if definition[1] == "offline_double" then product.grant = {coins=100, tokens={}} end
	table.insert(products, product)
end
local server
local client = Client.create({ now=function() return now end, id=function() serial+=1; return "ui:"..serial end,
	canPrompt=function() return canPrompt end, price=function() return if metadata then "R$ 1,234,567" else nil end,
	changed=function() end, send=function(request) table.insert(sends, table.clone(request)) end,
})
local lastSnapshot, lastResult
server = Service.create({ now=function() return now end, ready=function() return true end,
	update=function(key, transform) if failSave then error("isolated save failure") end; local nextValue=transform(backing[key]); if nextValue then backing[key]=nextValue end; return nextValue end,
	owns=function() return owned end, eligible=function() return true end,
	prompt=function() prompts+=1; return true end,
	deliverReserved=function() return delivered end,
	send=function(_, snapshot, result) lastSnapshot,lastResult=snapshot,result; client.receive(snapshot,result) end,
}, products)
server.add(77)
check(client.canPurchase("pack_small"), "configured eligible live price")
metadata=false
check(not client.purchase("pack_small"), "metadata failure cannot prompt")
metadata=true; canPrompt=false
check(not client.purchase("pack_small"), "opening/focus conflict cannot prompt")
canPrompt=true
check(client.purchase("pack_small"), "first explicit purchase")
local purchase = sends[#sends]
check(not client.purchase("pack_small") and not client.purchase("offline_double"), "all entry points share local lock")
now+=3; client.step()
check(sends[#sends].id == purchase.id, "lost reply retries exact purchase identity")
server.request(77,purchase)
server.request(77,sends[#sends])
check(prompts==1, "P02 launches exactly one native prompt")
server.finished(77,1,"DeveloperProduct",true)
check(client.busy() and client.state("pack_small").outcome=="saving", "client completion cannot grant")
client.refresh()
check(client.busy(), "refresh/reopen doesn't erase awaiting receipt")
check(server.receipt({PlayerId=77, ProductId=1, PurchaseId="purchase1"}), "confirmed durable receipt")
check(not client.busy() and lastSnapshot.products[1].fulfillment=="None", "delivered grant isn't shown as reserved")
check(lastSnapshot.products[1].confirmedDeliveries==1, "only confirmed delivery counted")
check(client.state("pack_small").outcome=="granted", "server delivery confirms success")
check(server.receipt({PlayerId=77, ProductId=1, PurchaseId="purchase1"}), "receipt replay")
check(lastSnapshot.products[1].confirmedDeliveries==1, "replay can't inflate delivery count")
check(client.purchase("pack_small"), "repeatable offer after delivery")
server.request(77,sends[#sends]); server.finished(77,1,"DeveloperProduct",false)
check(not client.busy() and client.state("pack_small").outcome=="cancelled", "cancel restores actions, no success")
check(client.purchase("pack_small"), "next explicit purchase")
server.request(77,sends[#sends]); server.finished(77,1,"DeveloperProduct",true)
delivered=false
check(not server.receipt({PlayerId=77,ProductId=1,PurchaseId="purchase2"}), "failed gameplay save defers receipt")
check(client.busy(), "failure keeps obligation and prevents another purchase")
delivered=true; now+=11; server.refresh(77)
check(lastSnapshot.products[1].fulfillment=="Pending", "native callback/receipt pending remains locked during refresh")
check(server.receipt({PlayerId=77,ProductId=1,PurchaseId="purchase2"}), "recovered save")
check(not client.busy(), "recovered receipt releases coordinated lock")
check(client.purchase("movement"), "pass request")
server.request(77,sends[#sends]); owned=true; server.finished(77,2,"Pass",true)
check(client.product("movement").ownership=="Owned" and not client.busy(), "server ownership refresh only")
check(not client.purchase("movement"), "owned pass not resold")
local stale = table.clone(lastSnapshot); stale.sequence-=1
check(not client.receive(stale), "stale snapshot ignored")

local gameplay = {ready=true, prices=Rules.prices, odds=Rules.odds, baseOdds=Rules.odds}
-- Use actual contract fields, never derive wallet/tokens from sidecar reserved values.
gameplay.boosts = {tokens={Coins2_15=2,Coins2_60=1}, coin={strength=2,started=864000,expires=864900},coinRemaining=900,luckRemaining=0,coinFactor=1,luckWeight=1,clockValid=true,paidAllowed=false,redundantLuck=false}
local projected = Projection.make(client,gameplay,nil,function() return "R$ 1,234,567" end,864000)
check(projected.offers.speed.availability=="owned", "verified ownership projected")
check(#projected.tokens==2 and projected.tokens[1].activation=="Unavailable", "unused tokens retained under policy suppression")
check(projected.timers[1].suppressed, "actual suppressed timer")
for key, logical in Projection.keys do check(Config.find(logical)~=nil, "retained key "..key) end
check(Projection.key("boostCoins",15)=="coins_boost_15" and Projection.key("boostCoins",60)=="coins_boost_60", "all Coin durations")

local scope, root = Scope.create(), Engine.Instance.new("Frame")
local attempts = {}
local convenience = {view=function() return nil end,collection=function() end, collect=function() end,movement=function() end}
local screen = Store.create(root,{scope=scope,effects=function() return false end,scale=function() return 1 end,snapshot=function() return gameplay end,canAct=function() return true end,send=function() error("generic intent used for purchase") end,navigate=function() end,close=function() end,message=function() end,
	commerce={convenience=convenience,purchase=function(key,minutes) table.insert(attempts,{key,minutes}); return true end,refresh=function() end,activate=function() end},
})
screen.shown(true); screen.layout(640,359,true); screen.present(projected); screen.route({tab="coins"})
Engine.click(root:FindFirstChild("Card_pouch",true))
check(attempts[1][1]=="pouch", "approved pack card uses coordinated path directly")
screen.route({tab="boosts"}); Engine.click(root:FindFirstChild("Card_boostCoins",true)); Engine.click(root:FindFirstChild("Length60",true)); Engine.click(root:FindFirstChild("Purchase",true))
check(attempts[2][1]=="boostCoins" and attempts[2][2]==60, "sheet selects real duration identity")
local footer = root:FindFirstChild("SheetFooter",true)
check(footer:FindFirstChild("Text",true).Text=="R$ 1,234,567", "actual long Robux price, no Coin label")
scope.destroy(); root:Destroy()

-- Routine authoritative clock observations preserve an activation confirmation.
local liveScope, liveRoot=Scope.create(),Engine.Instance.new("Frame")
projected.tokens[1].activation="Ready"
local activations=0
local live=Store.create(liveRoot,{scope=liveScope,effects=function() return false end,scale=function() return 1 end,snapshot=function() return gameplay end,canAct=function() return true end,send=function() end,navigate=function() end,close=function() end,message=function() end,
	commerce={convenience=convenience,purchase=function() return false end,refresh=function() end,activate=function() activations+=1 end},
})
live.shown(true); live.layout(640,359,true); live.present(projected); live.route({tab="boosts"}); Engine.click(liveRoot:FindFirstChild("Card_boostCoins",true))
Engine.click(liveRoot:FindFirstChild("Activate",true))
local confirmed=liveRoot:FindFirstChild("Activate",true)
local nextClock=table.clone(projected); nextClock.now+=1; live.present(nextClock)
check(liveRoot:FindFirstChild("Activate",true)==confirmed,"clock update preserves control and confirmation identity")
local unrelated=table.clone(nextClock); unrelated.offers=table.clone(nextClock.offers); unrelated.offers.pouch=table.clone(nextClock.offers.pouch); unrelated.offers.pouch.priceText="R$ 45"
live.present(unrelated)
check(liveRoot:FindFirstChild("Activate",true)==confirmed,"unrelated price lookup preserves activation confirmation")
Engine.click(confirmed); check(activations==1,"confirmation calls authoritative activation once")
live.shown(false); local created=Engine.created; nextClock.now+=1; live.present(nextClock)
check(Engine.created==created,"hidden Store observations allocate no UI")
liveScope.destroy(); liveRoot:Destroy()

-- Offline uses the same coordinator. Free cancellation remains independent of receipt recovery.
local offlineInput
local offline = Offline.create({now=function() return now end,id=function() serial+=1; return "offline:"..serial end,price=function() return "R$ 5" end,format=tostring,paint=function(value) offlineInput=value end,send=function(value) client.submit(value) end})
offline.award({awardId="return1",normal=50,doubled=100,claimable=true,fulfilled=false,recoveryRequired=false})
offline.update(lastSnapshot)
check(offline.purchase(), "offline reservation purchase path")
check(client.busy() and not client.purchase("pack_small"), "offline launch locks Store")
server.request(77,sends[#sends]); offline.update(lastSnapshot,lastResult)
server.finished(77,3,"DeveloperProduct",false); offline.update(lastSnapshot,lastResult)
check(offlineInput.freeClaimRestored and not client.busy(), "offline cancellation restores free claim")
client.destroy(); offline.destroy()
check(not client.purchase("pack_small"), "destroyed client can't prompt")
local lost=Client.create({now=function() return now end,id=function() return "lost-authorization" end,send=function() end,canPrompt=function() return true end,price=function() return "R$ 5" end,changed=function() end})
local cancelSnapshot={sequence=1,ready=true,ledgerStatus="Ready",receiptCount=0,reserved={coins=0,tokens={}},products={{key="offline_double",available=true,reason="Available",kind="DeveloperProduct",platformId=3,ownership="NotOwned",ownershipFresh=true,fulfillment="None"}}}
lost.receive(cancelSnapshot); lost.purchase("offline_double"); cancelSnapshot=table.clone(cancelSnapshot); cancelSnapshot.sequence=2
lost.receive(cancelSnapshot,{id="platform",product="offline_double",status="Cancelled",reason="PromptClosed"})
check(not lost.busy(),"native cancellation restores free actions even when authorization reply was lost")
lost.destroy()
print(`PASS: {checks} Store integration assertions; injected platform/storage/UI, no native purchases`)
