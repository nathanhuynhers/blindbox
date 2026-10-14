--!strict
local E = require("./UIEngine")
local Client = require("./OfflinePurchaseClient")
local Popup = require("./OfflineEarnings")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local now, nonce, sent, creditSent, input = 0, 0, {}, {}, nil
local client = Client.create({
	now=function() return now end,
	id=function() nonce += 1; return "credit:" .. nonce end,
	send=function(value) table.insert(sent, value) end,
	creditSend=function(value) table.insert(creditSent, value) end,
	price=function() return "R$ 49" end,
	format=tostring,
	paint=function(value) input = value end,
})
local view = {creditFlow=true,credits=0,normal=10,doubled=20,awardId="offline:1",
	claimable=true,earnedCredit=0,assistedCredit=0,redeemAllowed=true}
local product = {key="offline_double",available=true,reason="Available",ownership="Unknown",
	ownershipFresh=false,fulfillment="None"}
local function catalog(seq, result)
	client.update({sequence=seq,ready=true,ledgerStatus="Ready",products={product},
		reserved={coins=0,tokens={}},receiptCount=0}, result)
end
client.award(view)
catalog(1)
check(client.purchase() and #creditSent == 1 and #sent == 0, "Persist explicit selection before native purchase")
check(not client.purchase() and client.busy(), "Pending selection blocks repeats and AFK")
now = 2
client.step()
check(#creditSent == 2 and creditSent[1] == creditSent[2], "Lost selection reply retries same request")
client.creditUpdate(view, {id="forged",awardId="offline:1",status="Selected",reason="Durable"})
check(#sent == 0, "Unmatched selection response cannot authorize checkout")
view.selectedAwardId, view.selectedNormal = "offline:1", 10
client.creditUpdate(view, {id=creditSent[1].id,awardId="offline:1",status="Selected",reason="Durable"})
check(#sent == 1 and sent[1].action == "Purchase", "Durable matching selection opens exactly one checkout")
catalog(2, {id="platform",product="offline_double",status="Verified",reason="Durable"})
view.credits = 1
client.award(view)
check(#creditSent == 2 and input.redemption and not input.claimed and not client.busy(),
	"Receipt shows saved credit and never auto-redeems")
product.available = false
catalog(3)
check(input.buyAllowed and input.priceText == nil and client.purchase(), "Owned credit redeems without new price or sale")
local redemption = creditSent[#creditSent]
check(redemption.action == "Redeem" and #sent == 1, "Explicit credit redemption never buys another product")
client.creditUpdate(view, {id=redemption.id,awardId="offline:1",status="Recovering",reason="SaveUnconfirmed"})
check(client.busy(), "Unconfirmed redemption locks competing actions")
now = 4
client.step()
check(creditSent[#creditSent] == redemption, "Unconfirmed redemption retries exact award and nonce")
view.credits, view.claimable, view.fulfilled, view.selectedAwardId = 0, false, true, nil
client.creditUpdate(view, {id=redemption.id,awardId="offline:1",status="Redeemed",reason="Durable"})
check(input.claimed and not client.busy(), "Confirmed redemption closes and releases activity barrier")
view.selectedAwardId, view.selectedNormal, view.selectedBaseClaimed, view.credits = "offline:old", 10000, true, 1
client.award(view)
check(input.eligible and not input.claimed and input.actionText == "Redeem +10000",
	"An older frozen return remains reviewable after newer return fulfilled")
client.destroy()
now = 100
client.step()
local claims, purchases = 0, 0
local popup = Popup.create(function() return false end, function() claims += 1 end,
	function() purchases += 1; return true end)
local gui = E.game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local function find(name) return assert(gui:FindFirstChild(name, true)) end
input.outcome, input.freeClaimAvailable = "idle", false
popup.present(input)
popup.show("10000", "saved return")
check(find("DoubleClaim"):GetAttribute("Enabled"), "No-price saved redemption button is enabled")
E.click(find("Claim"))
check(claims == 0 and not popup.isOpen(), "Later dismisses old return without claiming a newer base")
popup.show("10000", "saved return")
E.click(find("DoubleClaim"))
E.click(find("DoubleClaim"))
check(purchases == 1 and popup.isOpen(), "Explicit redemption click locks immediately")
input.outcome, input.freeClaimAvailable, input.freeText = "idle", true, "7"
popup.present(input)
E.click(find("Backdrop"))
check(claims == 0 and not popup.isOpen(), "Dismissing an older card never claims newer free N")
popup.show("10000", "saved return")
E.click(find("Claim"))
check(claims == 1 and not popup.isOpen(), "Explicit current Claim remains available beside old credit")
popup.destroy()
check(E.connections == 0, "Credit popup releases connections")
print(string.format("PASS: %d offline credit client/popup fixture checks", checks))
