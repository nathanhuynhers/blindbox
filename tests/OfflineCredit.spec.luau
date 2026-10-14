--!strict
local Rules = require("./Rules")
local Profile = require("./Profile")
local Awards = require("./OfflineAwards")
local Credits = require("./OfflineCredits")
local Service = require("./OfflineCreditService")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function reward(n, assisted)
	local state = Rules.new(0)
	state.offlinePending, state.offlineSeconds = n, 3600
	Awards.freeze(state, "display-v1", assisted)
	state.schemaVersion = 17
	return state
end
local state = reward(100, 20)
check(Credits.select(state, "offline:1"), "Freeze explicit return before prompting")
check(Credits.grant(state, 101, "first"), "First receipt grants saved credit")
check(state.coins == 4500 and state.offlinePending == 100 and Credits.available(state.offlineCredits) == 1,
	"Receipt never claims, doubles or spends current return")
check(Credits.grant(state, 101, "first") and Credits.available(state.offlineCredits) == 1,
	"Receipt replay cannot duplicate saved credits")
check(not Credits.grant(state, 102, "first"), "Receipt identity cannot change product")
check(Credits.grant(state, 101, "second") and Credits.available(state.offlineCredits) == 2,
	"Reusable product grants distinct recurring credits")
check(Credits.redeem(state, "offline:1"), "Explicit redemption succeeds")
check(state.coins == 4580 and state.offlineData.assistedCredit == 120 and state.offlinePending == 0,
	"Base sources and extra N preserved exactly once")
check(Credits.redeem(state, "offline:1") and Credits.available(state.offlineCredits) == 1
	and state.offlineData.assistedCredit == 120, "Redemption replay cannot consume another credit")
check(state.schemaVersion == 19 and Profile.decode(Profile.encode(state), 0) ~= nil,
	"Forward schema19 aggregate round trips")
local delayed = reward(10000)
check(Credits.select(delayed, "offline:1"), "Selected old return retained")
check(Rules.claimOffline(delayed) == 10000, "Free claim stays available after selecting")
delayed = assert(Profile.decode(Profile.encode(delayed), 0))
delayed.offlinePending = 7
Awards.freeze(delayed, "display-v2")
check(Credits.grant(delayed, 101, "late") and delayed.offlinePending == 7
	and delayed.offlineData.assistedCredit == 0, "Delayed credit never doubles newer return")
check(Credits.redeem(delayed, "offline:1") and delayed.offlinePending == 7
	and delayed.coins == 14500 and delayed.offlineData.assistedCredit == 10000,
	"Confirm old selection adds only its frozen extra")
check(Credits.grant(delayed, 101, "next") and Credits.redeem(delayed, "offline:2")
	and delayed.coins == 14507 and delayed.offlineData.assistedCredit == 10007,
	"Next return uses the same platform identity with a new credit")
local full = reward(50)
full.coins = 1000000000000
check(Credits.grant(full, 101, "full") and Credits.redeem(full, "offline:1"), "Full wallet protects benefit")
check(full.offlineData.earnedCredit == 50 and full.offlineData.assistedCredit == 50,
	"No clipping earned or assisted overflow")
local legacy = reward(10)
check(Awards.reserve(legacy, 202), "Historical sold binding fixture")
check(not Credits.select(legacy, "offline:1") and not Credits.grant(legacy, 202, "legacy"),
	"Historical sold identities and awards never convert to credits")
check(Awards.fulfill(legacy, 202, "legacy"), "Historical receipt promise remains fulfillable")
for _, mutate in {
	function(r) r.offlineCredits.surprise = true end,
	function(r) r.offlineCredits.receipts.first = 0 end,
	function(r) r.offlineCredits.redemptions["offline:1"] = "missing" end,
	function(r) r.offlineCredits.returns["offline:1"].normal = 1 end,
	function(r) r.offlineCredits.selected = "offline:1" end,
	function(r) r.schemaVersion = 18 end,
} do
	local corrupt = Profile.encode(state)
	mutate(corrupt)
	check(Profile.decode(corrupt, 0) == nil, "Corrupt or downgraded paid aggregate fails closed")
end
local cap = reward(10)
check(Credits.grant(cap, 101, "capacity"), "Capacity fixture has credit")
cap.offlineData.assistedCredit = Awards.creditLimit
check(not Credits.redeem(cap, "offline:1") and Credits.available(cap.offlineCredits) == 1
	and cap.offlinePending == 10 and cap.offlineCredits.selected == nil,
	"Capacity rejection preserves credit, return and selection")
local owner, other = reward(10), reward(99)
local mode, ready, allowed, now = "ok", true, false, 0
local durable = nil
local api = Service.create({
	now = function() return now end,
	state = function(id) return if id == 7 then owner else other end,
	ready = function() return ready end,
	allowed = function() return allowed end,
	busy = function() return false end,
	persist = function()
		if mode == "fail" then ready = false; return false end
		durable = Profile.encode(owner)
		if mode == "lost" then ready = false; error("Lost reply after commit") end
		if mode == "replace" then owner = reward(999) end
		return true
	end,
})
check(api.request(7, {id="select",action="Select",awardId="offline:1"}).reason == "ValidationPending",
	"Design approval cannot bypass paid release validation")
mode = "lost"
check(not api.receipt({userId=7,productId=101,purchaseId="lost"}) and durable.offlineCredits.receipts.lost == 101,
	"Charged receipt grant survives lost persistence response even while sales gated")
check(not api.receipt({userId=7,productId=101,purchaseId="lost"}), "Unconfirmed save cannot acknowledge")
owner, ready, mode = assert(Profile.decode(durable, 0)), true, "ok"
check(api.receipt({userId=7,productId=101,purchaseId="lost"}) and Credits.available(owner.offlineCredits) == 1,
	"Confirmed rejoin retry acknowledges one saved credit")
allowed = true
mode = "fail"
check(api.request(7,{id="use",action="Redeem",awardId="offline:1"}).status == "Recovering",
	"Unconfirmed redemption exposes recovery")
check(not ready and owner.offlineCredits.redemptions["offline:1"] == "lost", "Mutation marker retained through uncertainty")
durable = Profile.encode(owner)
owner, ready, mode = assert(Profile.decode(durable, 0)), true, "ok"
check(api.request(7,{id="use",action="Redeem",awardId="offline:1"}).status == "Redeemed"
	and owner.coins == 4510 and owner.offlineData.assistedCredit == 10,
	"Redemption retry after rejoin cannot repeat benefit")
mode = "replace"
check(not api.receipt({userId=7,productId=101,purchaseId="detached"}) and owner.offlineCredits == nil,
	"Yielding save cannot acknowledge or deliver into replacement profile")
check(other.coins == 4500 and other.offlinePending == 99, "Other player stays isolated")
for _, raw in {
	{id="a",action="Redeem",awardId="offline:1",coins=10000},
	{id="a",action="Redeem",awardId="offline:1",userId=8},
	{id="a",action="Redeem",awardId=0/0},
	{id=string.rep("a",65),action="Redeem",awardId="offline:1"},
	{id="a",action="Grant",awardId="offline:1"},
} do check(Service.parse(raw) == nil, "Forged remote fields rejected") end
print(string.format("PASS: %d recurring offline credit/profile/receipt checks", checks))
