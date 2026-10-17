--!strict
-- Actual Shop/components with UIEngine; no native rendering claims.
local Engine = require("./UIEngine")
local Shop = require("./ShopScreen")
local Scope = require("./UIScope")
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local Catalog = require("./Catalog")
local SnapshotSender = require("./SnapshotSender")
local checks = 0
local function check(value,message) checks+=1; assert(value,message) end
local state
local session={transaction=Transactions.new(0),sequence=0,plot={view={first=1,revision=0},showcase={editorToken=0}},storage={status="Ready",ready=true}}
session.transaction.state.coins=1e15
session.transaction.state.step=7
local sendSnapshot=SnapshotSender({FireClient=function(_,_,snapshot) state=snapshot end})
sendSnapshot("owner",session)
local root=Engine.Instance.new("Frame")
local scope=Scope.create()
local requests={}
local autoRequests=0
local shop=Shop.create(root,{
	scope=scope,effects=function() return false end,scale=function() return 1 end,snapshot=function() return state end,canAct=function() return true end,
	send=function(action,_,_,choice) table.insert(requests,{action=action,choice=choice}) end,navigate=function() end,close=function() end,message=function() end,
	commerce={purchase=function() return false end,activate=function() end,refresh=function() end,convenience={
		view=function() return {openAllowed=true,open={phase="Idle",running=false,reason="Ready",completed=0,limit=10},collectAllowed=true,movementAllowed=true} end,
		start=function() autoRequests+=1 end,stop=function() end,collect=function() end,movement=function() end,
	}},
})
local function find(name) return Engine.find(root,name) end
for _,size in {{1920,1080},{1280,720},{667,375},{812,375}} do
	shop.layout(size[1],size[2],size[2]<460)
	shop.route({collection="moon"})
	check(shop.root:GetAttribute("SelectedCollection")=="moon" and shop.root:GetAttribute("PurchaseLocked"),"Locked collection remains selectable at each layout")
	check(find("Collection_moon").Visible and find("Collection_orbit").Visible,"All goals remain visible")
	check(find("BuyBox"):GetAttribute("Enabled")==false and find("BuyTen"):GetAttribute("Enabled")==false,"Both paid buttons reflect authority")
	local before=#requests
	find("BuyBox").Activated:Fire(); find("BuyTen").Activated:Fire()
	check(#requests==before,"Disabled paid buttons never dispatch")
	local hint=find("PurchaseAccess")
	check(hint.Visible and string.find(hint.Text,"\nOR\n",1,true) and string.find(hint.Text,"0/9",1,true),"Independent alternative routes retain progress")
	local canvas = find("Contents")
	check(math.max(canvas.CanvasSize.Y.Offset,canvas.Size.Y.Offset)>hint.Position.Y.Offset+hint.Size.Y.Offset,"Unlock message and contents fit the visible area or scroll canvas")
	find("AutoOpenSetup").Activated:Fire()
	find("StartAutoOpen").Activated:Fire()
	check(autoRequests==0,"Auto Open UI cannot bypass locked access even with entitlement view allowed")
end
-- Existing discovery history in a high tier unlocks lower collections on the next snapshot.
for _,f in Catalog.figures do if f.collection=="birthstone" and f.rarity~="Mythical" then session.transaction.state.discovered[f.id]=true end end
sendSnapshot("owner",session)
shop.update(state)
shop.route({collection="moon"})
check(not shop.root:GetAttribute("PurchaseLocked") and not find("PurchaseAccess").Visible,"Authoritative unlock refresh removes purchase lock")
check(find("BuyBox"):GetAttribute("Enabled")==true and find("BuyTen"):GetAttribute("Enabled")==true,"Unlocked paid controls use ordinary affordability")
find("BuyBox").Activated:Fire()
check(requests[#requests].action=="Buy" and requests[#requests].choice=="moon","Unlocked request retains normal protocol")
find("StartAutoOpen").Activated:Fire()
check(autoRequests==1,"Unlocked Auto Open remains available")
state.collectionAccess=nil
shop.update(state)
check(find("BuyBox"):GetAttribute("Enabled")==false,"Missing authority cannot imply unlock")
scope.destroy()
print("PASS:",checks,"Shop lock visibility, route progress, responsive structure and purchase-control checks (UI doubles)")
