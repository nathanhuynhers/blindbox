--!strict
local E = require("./UIEngine")
local Client = require("./OfflinePurchaseClient")
local Popup = require("./OfflineEarnings")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local now, sent, paints, reads = 0, {}, {}, 0
local price = nil
local client = Client.create({
	now = function()
		return now
	end,
	id = function()
		return "attempt-1"
	end,
	send = function(request)
		table.insert(sent, request)
	end,
	price = function()
		reads += 1
		return price
	end,
	format = function(n)
		return tostring(n)
	end,
	paint = function(input)
		table.insert(paints, input)
	end,
})
local sequence = 0
local item = {
	key = "offline_double",
	available = false,
	reason = "Unconfigured",
	ownership = "Unknown",
	ownershipFresh = false,
	fulfillment = "None",
}
local function snapshot(prompt, result)
	sequence += 1
	client.update({
		sequence = sequence,
		ready = true,
		ledgerStatus = "Ready",
		products = { item },
		promptProduct = prompt,
		reserved = { coins = 0, tokens = {} },
		receiptCount = 0,
	}, result)
end
client.award({
	awardId = "offline:1",
	normal = 10,
	doubled = 20,
	claimable = true,
	earnedCredit = 0,
	assistedCredit = 0,
})
snapshot()
check(
	reads == 0 and not client.purchase() and #sent == 0,
	"Unconfigured/ineligible never priced or prompted"
)
item.available = true
snapshot()
check(not client.purchase() and #sent == 0, "Price loading blocks purchase")
price = "R$ 31"
snapshot()
check(
	paints[#paints].baseText == "10"
		and paints[#paints].doubleText == "20"
		and paints[#paints].priceText == price,
	"Exact server N/2N and actual price"
)
check(
	client.purchase() and #sent == 1 and not client.purchase(),
	"Single explicit action, repeated clicks blocked"
)
check(paints[#paints].outcome == "prompting", "Lock competing actions before remote send")
check(client.busy(), "AFK confirmation blocks during prompt")
now = 2
client.step()
check(#sent == 2 and sent[1] == sent[2] and sent[2].id == "attempt-1", "Lost reply retries same id")
snapshot("offline_double", {
	id = "attempt-1",
	product = "offline_double",
	status = "PromptOpened",
	reason = "PlatformPrompt",
})
now = 5
client.step()
check(#sent == 2, "Known prompt stops authorization retries")
snapshot(
	nil,
	{ id = "platform", product = "offline_double", status = "Cancelled", reason = "PromptClosed" }
)
check(
	paints[#paints].outcome == "cancelled"
		and paints[#paints].reason:find("Claim is still free", 1, true),
	"Cancellation restores free flow without charge guarantee"
)
check(not client.busy(), "Cancellation releases AFK presentation barrier")
client.award({ normal = 0, doubled = 0, claimable = false, earnedCredit = 0, assistedCredit = 0 })
check(not client.purchase(), "Zero/already claimed cannot prompt")
client.destroy()
now = 99
client.step()
check(#sent == 2, "Teardown stops retries")
local lost = Client.create({
	now = function()
		return 0
	end,
	id = function()
		return "lost"
	end,
	send = function() end,
	price = function()
		return "R$ 31"
	end,
	format = tostring,
	paint = function() end,
})
local function recoverySnapshot(seq, prompt, result)
	lost.update({
		sequence = seq,
		ready = true,
		ledgerStatus = "Ready",
		products = { item },
		promptProduct = prompt,
		reserved = { coins = 0, tokens = {} },
		receiptCount = 0,
	}, result)
end
lost.award({ normal = 10, doubled = 20, claimable = true, earnedCredit = 0, assistedCredit = 0 })
recoverySnapshot(1)
check(lost.purchase(), "Lost prompt reply fixture starts once")
recoverySnapshot(
	2,
	nil,
	{ id = "platform", product = "offline_double", status = "Cancelled", reason = "PromptClosed" }
)
check(not lost.busy(), "Cancel clears authorization retries even if opening reply was lost")
recoverySnapshot(
	3,
	nil,
	{ id = "lost", product = "offline_double", status = "PromptOpened", reason = "Cached" }
)
check(not lost.busy(), "Cached prompt result cannot relock a cancelled purchase")
recoverySnapshot(4, "offline_double", {
	id = "platform",
	product = "offline_double",
	status = "AwaitingReceipt",
	reason = "PromptClosed",
})
lost.award({
	normal = 10,
	doubled = 20,
	claimable = false,
	fulfilled = true,
	earnedCredit = 0,
	assistedCredit = 10,
})
check(lost.busy(), "Durable award does not bypass still-open native window")
recoverySnapshot(5)
check(
	not lost.busy(),
	"Confirmed owner award recovers a lost fulfillment reply after window closes"
)
recoverySnapshot(
	6,
	nil,
	{ id = "platform", product = "offline_double", status = "AwaitingReceipt", reason = "Late" }
)
check(not lost.busy(), "Late close status cannot undo confirmed fulfillment")
lost.award({
	normal = 7,
	doubled = 14,
	claimable = true,
	recoveryRequired = true,
	earnedCredit = 0,
	assistedCredit = 10,
})
check(
	not lost.purchase() and not lost.busy(),
	"Durable exception hides new offers while restoring free Claim"
)
lost.destroy()
-- Real popup components under deterministic engine fixtures; visual/device acceptance separate.
local claims, purchases = 0, 0
local popup = Popup.create(function()
	return false
end, function()
	claims += 1
end, function()
	purchases += 1
	return true
end)
local gui = E.game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local function find(name)
	return assert(gui:FindFirstChild(name, true))
end
local offer = {
	fixture = false,
	baseText = "10,000",
	doubleText = "20,000",
	freeText = "10,000",
	eligible = true,
	buyAllowed = true,
	priceText = "R$ 31",
	outcome = "idle",
}
popup.present(offer)
popup.show("10,000", "6h")
check(
	find("DoubleClaim"):GetAttribute("Enabled"),
	"Eligible configured action uses provided purchase callback"
)
E.click(find("DoubleClaim"))
E.click(find("DoubleClaim"))
E.click(find("Claim"))
E.click(find("Backdrop"))
check(
	purchases == 1 and claims == 0 and popup.isOpen(),
	"Repeated click/free/outside suppressed during purchase"
)
offer.outcome = "cancelled"
offer.noChargeConfirmed = true
offer.reason = "Purchase window closed. Claim is still free; any delayed purchase will recover."
popup.present(offer)
E.click(find("Claim"))
check(claims == 1 and not popup.isOpen(), "Cancelled prompt restores ordinary Claim")
offer.outcome = "recovering"
popup.present(offer)
popup.show("10,000", "6h")
E.click(find("Backdrop"))
check(popup.isOpen() and claims == 1, "Recovery cannot dismiss into competing claim")
offer.outcome, offer.claimed = "idle", true
popup.present(offer)
check(
	not popup.isOpen() and claims == 1,
	"Authoritative completion closes without second free claim"
)
popup.destroy()
check(E.connections == 0, "Popup connection cleanup")
for _, viewport in { { 1920, 1080 }, { 1280, 720 }, { 667, 375 }, { 844, 390 } } do
	E.screen = { X = viewport[1], Y = viewport[2] }
	offer.fixture, offer.claimed, offer.outcome = true, nil, "idle"
	popup.present(offer)
	popup.show("1,000,000,000,000", "6h")
	local card = find("Card")
	local claim, double = find("Claim"), find("DoubleClaim")
	check(
		card.Size.X.Offset <= viewport[1] - 32 and card.Size.Y.Offset <= viewport[2] - 16,
		"Popup scripted geometry fits fixture viewport"
	)
	check(
		claim.Size.Y.Offset >= 44 and double.Size.Y.Offset >= 44,
		"Both popup fixture targets meet minimum height"
	)
	popup.destroy()
end
check(E.connections == 0, "Viewport fixture teardown")
print(string.format("PASS: %d offline client/popup fixture checks", checks))
