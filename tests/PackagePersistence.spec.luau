--!strict
local Engine = require("./AfkEngine")
local Storage = require("./Storage")
local Runtime = require("./PackageRuntime")
local Grants = require("./PackageGrants")
local Rules = require("./Rules")
local Profile = require("./Profile")
local Config = require("./PurchaseConfig")
local Service = require("./PurchaseService")
local Protocol = require("./PurchaseProtocol")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function product(key, id)
	local p = table.clone(Config.find(key))
	p.platformId, p.kind = id, if p.permanent then "Pass" else "DeveloperProduct"
	p.integrationReady, p.salesEnabled = true, true
	return p
end
local products = { product("pack_small", 101), product("starter", 102), product("vip", 103) }
local sessions, database, states = {}, {}, {}
local function open(userId)
	local s = Storage.open(userId)
	assert(s and s.handle)
	sessions[userId] = s
	return s
end
local owns, ownsError = false, false
local after, deliveries = 0, 0
local service = Service.create({
	now = function() return Engine.now end,
	ready = function(userId)
		local s = sessions[userId]
		return s ~= nil and s.handle ~= nil and s.ready and not s.busy and not s.closed and not s.transferring and s.pendingSave == nil and Engine.now < s.safeUntil
	end,
	update = function(key, transform)
		transform(database[key])
		local result = transform(database[key])
		if result then database[key] = result end
		if after > 0 then after -= 1; error("lost sidecar reply") end
		return result
	end,
	owns = function() if ownsError then error("ownership unavailable") end; return owns end,
	prompt = function() error("Production gate must prevent prompts") end,
	eligible = function(userId, p) return Runtime.eligible(sessions[userId], p, Engine.now) end,
	packageState = function(userId, p)
		local s = sessions[userId]
		return Grants.view(s.state, p.key, s.ready and s.pendingSave == nil, Runtime.eligible(s, p, Engine.now))
	end,
	send = function(userId, snapshot) states[userId] = snapshot end,
	deliverReserved = function(userId, id, entry)
		deliveries += 1
		return Runtime.fulfill(sessions[userId], id, entry, Engine.now)
	end,
}, products)
local function receipt(userId, id, productId)
	return { PlayerId = userId, PurchaseId = id, ProductId = productId or 101 }
end
local s, other = open(8101), open(8102)
check(Protocol.parse({ id = "amount", action = "Purchase", product = "pack_small", amount = 999 }) == nil, "Client cannot select paid grant")
service.add(8101); service.add(8102)
service.request(8101, { id = "blocked", action = "Purchase", product = "pack_small" })
check(not states[8101].products[1].available and not states[8101].products[1].package.eligible, "Configured fixture still blocked by production validation")
after = 1
check(not service.receipt(receipt(8101, "lost-sidecar")), "Lost sidecar reply not acknowledged")
check(s.state.packages == nil and database.Player_8101.entries["receipt:lost-sidecar"] ~= nil, "Reservation retained without profile grant")
check(service.receipt(receipt(8101, "lost-sidecar")), "Sidecar retry reconciles then saves profile")
check(s.state.packages.assistedCredit == 15000 and other.state.packages == nil, "Owner isolation")
check(service.receipt(receipt(8101, "lost-sidecar")) and s.state.packages.assistedCredit == 15000, "Durable duplicate receipt")
Engine.before = 3
check(not service.receipt(receipt(8101, "failed-profile")), "Profile save failure no acknowledgement")
check(not s.ready and s.pendingSave.packages.assistedCredit == 30000 and database.Player_8101.entries["receipt:failed-profile"] ~= nil, "Immutable full obligation retained")
check(not service.receipt(receipt(8101, "failed-profile")), "Duplicate while paused remains deferred")
check(not states[8101].products[1].package.confirmed and states[8101].products[1].package.fulfilledCoins == 0, "Unconfirmed memory not shown as received")
check(Storage.flush(s, false), "Exact pending snapshot recovered")
check(service.receipt(receipt(8101, "failed-profile")) and s.state.packages.assistedCredit == 30000, "Recovery exactly once")
Engine.after = 3
check(not service.receipt(receipt(8101, "lost-profile")), "Lost profile responses no acknowledgement")
check(Engine.database.Player_8101.data.packages.assistedCredit == 45000, "Profile did commit")
check(Storage.flush(s, false), "Lost-response generation reconciled")
check(service.receipt(receipt(8101, "lost-profile")) and s.state.packages.assistedCredit == 45000, "Lost reply replay no regrant")
-- Reentrant platform receipt during UpdateAsync sees P02's serialization lock.
local concurrent: boolean? = nil
Engine.onUpdate = function()
	Engine.onUpdate = nil
	concurrent = service.receipt(receipt(8101, "concurrent"))
end
check(service.receipt(receipt(8101, "concurrent")) and concurrent == false, "Concurrent callback defers while first owns lock")
check(service.receipt(receipt(8101, "concurrent")) and s.state.packages.assistedCredit == 60000, "Concurrent replay credits once")
check(not service.receipt(receipt(9999, "absent")), "Absent owner stays pending")
check(not service.receipt(receipt(8101, "unknown", 999)), "Unknown platform product stays pending")
check(not service.claimPass(8101, "starter"), "Unowned Starter cannot claim")
owns = true
Engine.now += 30; service.refresh(8101)
Engine.before = 3
check(not service.claimPass(8101, "starter"), "Partial Starter save not acknowledged")
check(s.pendingSave.packages.starterClaim == "pass:102" and s.pendingSave.packages.assistedCredit == 67500 and s.pendingSave.boosts.tokens.Coins2_15 == 1, "Starter all components and marker share exact snapshot")
check(not s.ready and not service.claimPass(8101, "starter"), "No second package while save unresolved")
check(Storage.flush(s, false), "Starter retry confirms aggregate")
check(service.claimPass(8101, "starter") and s.state.boosts.tokens.Coins2_15 == 1 and s.state.packages.assistedCredit == 67500, "Verified reconciliation once")
local vip = function(key) return service.ownership(8101, key) end
check(Runtime.sync(s, products, vip, true, Engine.now), "VIP via shared verified ownership")
check(s.state.earningFactors.vipFactor == 1.1, "VIP applied once")
ownsError = true; Engine.now += 30; service.refresh(8101)
Runtime.sync(s, products, vip, true, Engine.now)
check(s.state.earningFactors.vipFactor == 1.1 and service.ownership(8101, "vip") == "Owned", "Transient refresh failure retains verified rate")
check(not service.claimPass(8101, "starter"), "Stale ownership cannot mint a claim")
ownsError = false
-- Daily value and UTC marker use the same profile write; failed save replays exactly that aggregate.
check(Rules.mutate(s.state, { action = "Daily" }, 0.1, 50, Engine.now), "Eligible VIP daily")
Engine.after = 3
check(not Runtime.commitDaily(s, Engine.now), "Lost daily save replies pause")
check(s.pendingSave.lastDailyDay == 50 and s.pendingSave.packages.assistedCredit == 68000, "Daily marker and exact supplement atomic")
check(Storage.flush(s, false), "Daily save recovered")
check(not Rules.mutate(s.state, { action = "Daily" }, 0.1, 50, Engine.now), "Daily replay after recovery")
service.remove(8101)
check(Storage.close(s), "Release lease")
s = open(8101); service.add(8101)
check(s.state.packages.assistedCredit == 68000 and s.state.boosts.tokens.Coins2_15 == 1 and s.state.lastDailyDay == 50, "Rejoin preserves lifetime value and daily marker")
check(service.claimPass(8101, "starter") and s.state.boosts.tokens.Coins2_15 == 1, "Outside-game/rejoin reconciliation cannot repeat")
local view = states[8101].products[2].package
check(view.confirmed and view.claimed and view.fulfilledCoins == 7500 and view.fulfilledTokens == 1 and view.walletCredited == 0 and not view.creditUsable, "P08 truthful confirmed fulfillment")
for _, flag in { "closed", "transferring", "busy" } do
	s[flag] = true
	check(not Runtime.fulfill(s, "receipt:guard", { product = "pack_small", platformId = 101, kind = "DeveloperProduct", grant = products[1].grant }, Engine.now), "Lifecycle " .. flag)
	s[flag] = false
end
check(Profile.decode(Profile.encode(s.state), 0) ~= nil, "Valid schema after recovery/rejoin")
local capped = open(8103)
service.add(8103)
capped.state.boosts.tokens.Coins2_15 = 1000000
check(not service.claimPass(8103, "starter"), "Verified outside-game Starter retains obligation when token cap blocks delivery")
check(database.Player_8103.entries["pass:102"] ~= nil and capped.state.packages == nil, "No half bundle after capacity failure")
capped.state.boosts.tokens.Coins2_15 = nil
check(service.claimPass(8103, "starter") and capped.state.packages.assistedCredit == 7500 and capped.state.boosts.tokens.Coins2_15 == 1, "Capacity recovery fulfills entire reserved Starter once")
-- The actual platform adapter must check capacity after metadata yielded.
local owner, player, prompts = { state = Rules.new(0) }, {}, 0
local fillDuringLookup = false
local native = {
	GetProductInfoAsync = function()
		if fillDuringLookup then owner.state.packages = Grants.empty(); owner.state.packages.assistedCredit = Grants.creditLimit - Grants.creditLimit % 500 end
		return { IsForSale = true }
	end,
	PromptProductPurchase = function() prompts += 1 end,
}
local prompt = require("./PurchasePrompt")(
	{ GetPlayerByUserId = function() return player end }, function() return owner end,
	Engine.os, native, { InfoType = { GamePass = "Pass", Product = "DeveloperProduct" } },
	{ eligible = function(_, p) return Grants.capacity(owner.state, p) end }, function() return true end
)
fillDuringLookup = true
check(not prompt(8101, products[1]) and prompts == 0, "Capacity change during yielding metadata blocks native prompt")
fillDuringLookup, owner.state.packages = false, nil
check(prompt(8101, products[1]) and prompts == 1, "Actual adapter prompts only after fresh capacity check")
check(Storage.close(s) and Storage.close(other) and Storage.close(capped), "Clean isolated release")
print("Package persistence:", checks, "checks passed")
