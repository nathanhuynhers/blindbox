--!strict
-- Actual binding with isolated service signals and scheduled lookup coroutines.
local Engine = require("./UIEngine")
local Config = require("./PurchaseConfig")
local Presentation = require("./StorePresentation")
local queued = {}
Engine.task.defer = function(callback)
	local thread = coroutine.create(callback)
	table.insert(queued, thread)
	return thread
end
local function flush()
	local pending = queued; queued = {}
	for _, thread in pending do local ok, reason = coroutine.resume(thread); assert(ok, reason) end
end
local lookupCount, failed = 0, false
local kinds = {}
Engine.services.MarketplaceService = { GetProductInfoAsync=function(_, id, kind)
	lookupCount+=1; kinds[id]=kind
	if failed then error("isolated metadata failure") end
	return {IsForSale=true,PriceInRobux=1234567}
end }
local guid=0
Engine.services.HttpService = {GenerateGUID=function() guid+=1; return "guid"..guid end}
Engine.services.UserInputService.WindowFocused = Engine.Instance.new("Frame"):GetPropertyChangedSignal("WindowFocus")
local Binding = require("./StoreBinding")
local remotes = Engine.Instance.new("Folder")
local sent = {}
local function remote(name)
	local event = Engine.Instance.new("RemoteEvent"); event.Name=name; event.Parent=remotes
	event.OnClientEvent = event:GetPropertyChangedSignal("Wire")
	event.FireServer = function(_, request) table.insert(sent,{name=name,request=table.clone(request)}) end
	return event
end
remote("PurchaseRequest"); local state = remote("PurchaseState")
remote("BoostActivate"); local boostResult = remote("BoostResult")
local painted, offlineInput
local paints=0
local binding = Binding.create(remotes,function() return true end,function(value) painted=value; paints+=1 end,function(value) offlineInput=value end,tostring,function() end)
local function catalog(sequence)
	return {sequence=sequence,ready=true,ledgerStatus="Ready",receiptCount=0,reserved={coins=0,tokens={}},tokenBenefits=Config.tokenBenefits,
		products={
			{key="pack_small",kind="DeveloperProduct",platformId=11,available=true,reason="Available",ownership="NotOwned",ownershipFresh=true,fulfillment="None",grant={coins=15000,tokens={}}},
			{key="movement",kind="Pass",platformId=12,available=true,reason="Available",ownership="NotOwned",ownershipFresh=true,fulfillment="None",benefits={movementSpeed=48}},
			{key="offline_double",kind="DeveloperProduct",platformId=13,available=true,reason="Available",ownership="NotOwned",ownershipFresh=true,fulfillment="None"},
		}}
end
binding.gameplay({ready=true,revision=1,prices={},offlineAward={awardId="return:1",normal=37,doubled=74,claimable=true,earnedCredit=0,assistedCredit=0},boosts={tokens={Coins2_15=1},coinRemaining=0,luckRemaining=0,coinFactor=1,luckWeight=1,clockValid=true,paidAllowed=true,redundantLuck=false}})
state.OnClientEvent:Fire(catalog(1))
assert(not binding.purchase("pouch",nil), "lookup loading can't launch")
assert(#queued==3, "one lookup per identity despite duplicate projections")
failed=true; flush()
assert(painted.offers.pouch.availability=="unavailable" and not painted.offers.pouch.buyAllowed, "failed metadata is honestly unavailable")
assert(not binding.purchase("pouch",nil), "failed metadata cannot prompt")
Engine.advance(11); failed=false; binding.refresh(); state.OnClientEvent:Fire(catalog(2)); flush()
assert(lookupCount==6 and painted.offers.pouch.priceText=="R$ 1234567", "metadata retry uses actual client price")
assert(kinds[11]==Engine.Enum.InfoType.Product and kinds[12]==Engine.Enum.InfoType.GamePass, "correct platform types")
assert(binding.purchase("pouch",nil), "explicit configured offer")
assert(binding.busy() and not binding.double(), "Store launch blocks offline Double")
local request=sent[#sent].request
Engine.advance(3); binding.step()
assert(sent[#sent].request.id==request.id, "same authorization retry")
local opened=catalog(3); opened.promptProduct="pack_small"; opened.products[1].available=false; opened.products[1].fulfillment="Pending"
state.OnClientEvent:Fire(opened,{id=request.id,product="pack_small",status="PromptOpened",reason="PlatformPrompt"})
local cancelled=catalog(4)
state.OnClientEvent:Fire(cancelled,{id="platform",product="pack_small",status="Cancelled",reason="PromptClosed"})
local _, locked = Presentation.offline(offlineInput)
assert(not binding.busy() and not locked, "cancellation preserves free claim")
assert(binding.double(), "offline shares recovered lock")
local doubleRequest=sent[#sent].request
assert(doubleRequest.product=="offline_double", "no client award/amount on purchase wire")
assert(not binding.purchase("pouch",nil), "offline launch blocks Store")
state.OnClientEvent:Fire(catalog(5),{id=doubleRequest.id,product="offline_double",status="Rejected",reason="EligibilityUnavailable"})
assert(not binding.busy(), "explicit rejected authorization recovers")
Engine.advance(2)
binding.activate("Coins2_15"); local activation=sent[#sent]
assert(activation.name=="BoostActivate" and activation.request.token=="Coins2_15" and activation.request.revision==1, "activation uses authoritative revision and token identity")
binding.activate("Coins2_15")
assert(sent[#sent]==activation, "duplicate activation blocked")
assert(not binding.purchase("pouch",nil), "activation and purchases coordinated")
Engine.advance(3); binding.step()
assert(sent[#sent].request.id==activation.request.id, "activation retry never consumes another identity")
boostResult.OnClientEvent:Fire({id=activation.request.id,ok=false,reason="SavingUnavailable"})
assert(binding.busy(), "uncertain activation save retains exact recovery obligation")
boostResult.OnClientEvent:Fire({id=activation.request.id,ok=true,reason="Activated"})
assert(not binding.busy(), "only matching activation confirmation releases lock")
local nativeRequests=0
for _, item in sent do if item.request.action=="Purchase" then nativeRequests+=1 end end
Engine.services.UserInputService.WindowFocused:Fire()
local after=0
for _, item in sent do if item.request.action=="Purchase" then after+=1 end end
assert(nativeRequests==after, "focus return never purchases")
Engine.advance(121); state.OnClientEvent:Fire(catalog(6))
assert(#queued==3, "expired price cache revalidated")
binding.destroy(); local before=paints; flush()
assert(paints==before and not binding.purchase("pouch",nil), "late lookup and destroyed binding are inert")
remotes:Destroy()
print("PASS: Store binding metadata, coordinated offline, activation, retry, focus and teardown fixtures (no native services)")
