--!strict
local Config = require("./PurchaseConfig")
local Ledger = require("./PurchaseLedger")
local Entitlements = require("./Entitlements")
local Protocol = require("./PurchaseProtocol")
local Service = require("./PurchaseService")
local Availability = require("./PurchaseAvailability")
local Rules = require("./Rules")
local Economy = require("./Economy")
local assertions = 0
local function check(value: boolean, message: string)
	assertions += 1
	assert(value, message)
end
local active = { handle = {}, ready = true, closed = false, transferring = false, busy = false,
	pendingSave = nil, pendingRelease = nil, safeUntil = 85 }
local readinessClock = 0
local present = true
local adapterReady = require("./PurchaseReadiness")(
	{ GetPlayerByUserId = function(_, userId) return if userId == 7 and present then {} else nil end },
	function() return active end,
	{ clock = function() return readinessClock end }
)
check(adapterReady(7) and not adapterReady(8), "Actual adapter accepts only loaded owner")
active.handle = nil
check(not adapterReady(7), "Preview cannot fulfill paid receipt")
active.handle = {}
for _, flag in { "closed", "transferring", "busy" } do
	active[flag] = true
	check(not adapterReady(7), "Lifecycle barrier " .. flag)
	active[flag] = false
end
active.ready = false
check(not adapterReady(7), "Storage failure pause")
active.ready = true
active.pendingSave = {}
check(not adapterReady(7), "Lost profile save reply blocks paid actions")
active.pendingSave, active.pendingRelease = nil, {}
check(not adapterReady(7), "Uncertain handoff release blocks paid actions")
active.pendingRelease = nil
readinessClock = 85
check(not adapterReady(7), "Lease safety expiry fails closed")
readinessClock, present = 0, false
check(not adapterReady(7), "Disconnect fails closed")
present = true
for _, product in Config.products do
	check(product.platformId == nil and product.kind == nil and not product.salesEnabled and not product.integrationReady, "No invented identity/type/sale")
end
check(#Config.products == 20, "Every retained D1 variant")
check(Config.find("offline_double").defaultPrice == nil and Config.find("offline_double").grant == nil, "Offline undecided")
check(Config.find("pack_huge").grant.coins == 1200000 and Config.find("starter").grant.tokens.Coins2_15 == 1, "D1 promises")
check(Protocol.parse({ id = "a", action = "Purchase", product = "movement", userId = 42 }) == nil, "Spoofed identity denied")
check(Protocol.parse({ id = "a", action = "Purchase", product = "movement", price = 1 }) == nil, "Price denied")
check(Protocol.parse({ id = "a", action = "Complete", product = "movement" }) == nil, "No completion endpoint")
check(Protocol.parse({ id = string.rep("a", 65), action = "State" }) == nil, "Bounded request")
check(Ledger.receipt({ PurchaseId = "p", PlayerId = 0/0, ProductId = 1 }) == nil, "Finite receipt identity")
check(Ledger.receipt({ PurchaseId = "p", PlayerId = 1, ProductId = math.huge }) == nil, "Finite product")
check(Ledger.grant({ coins = 1, tokens = {}, surprise = 1 }) == nil, "Strict grant schema")
check(Ledger.grant({ coins = 1, tokens = { Unknown = 1 } }) == nil, "Allowlisted tokens")
local entry = { product = "pack_small", platformId = 101, kind = "DeveloperProduct", grant = { coins = 15000, tokens = {} } }
local raw = nil
local mode = "ok"
local writes = 0
local function update(_key, transform)
	if mode == "fail" then error("injected unavailable") end
	local nextValue = transform(raw)
	if nextValue ~= nil then raw = nextValue; writes += 1 end
	if mode == "lost" then error("injected reply lost AFTER commit") end
	return raw
end
check(Ledger.load(update, 7) ~= nil, "Absent sidecar initialized")
mode = "fail"
check(Ledger.commit(update, 7, "receipt:a", entry) == nil and next(raw.entries) == nil, "Failed save neither grants nor acknowledges")
mode = "lost"
check(Ledger.commit(update, 7, "receipt:a", entry) == nil and raw.entries["receipt:a"].grant.coins == 15000, "Lost reply commit retained")
mode = "ok"
local recovered = Ledger.commit(update, 7, "receipt:a", entry)
local total, count = Ledger.summary(recovered)
check(count == 1 and total.coins == 15000, "Uncertain commit retry deduplicated")
entry.grant.coins = 3
check(raw.entries["receipt:a"].grant.coins == 15000, "Saved grant deep copied")
check(Ledger.commit(update, 7, "receipt:a", entry).entries["receipt:a"].grant.coins == 15000, "Replay retains original promise")
entry.platformId = 102
check(Ledger.commit(update, 7, "receipt:a", entry) == nil, "Receipt identity collision rejected")
entry.platformId, entry.grant.coins = 101, 15000
local corrupt = { version = 2, entries = raw.entries }
raw = corrupt
check(Ledger.load(update, 7) == nil and Ledger.commit(update, 7, "receipt:b", entry) == nil and raw == corrupt, "Future schema never overwritten")
raw = { version = 1, entries = { bad = { product = "x" } } }
check(Ledger.load(update, 7) == nil, "Corrupt sidecar blocked")
raw = Ledger.empty()
for i = 1, Ledger.maxEntries do raw.entries["receipt:" .. i] = entry end
check(Ledger.commit(update, 7, "receipt:overflow", entry) == nil, "Capacity never prunes paid markers")
check(Ledger.commit(update, 7, "receipt:1", entry) ~= nil, "Duplicate still acknowledged at capacity")
-- UpdateAsync may invoke callbacks repeatedly and concurrently with another server.
raw = Ledger.empty()
local retryCalls = 0
local function conflictUpdate(key, transform)
	local discarded = transform(raw)
	retryCalls += 1
	check(next(raw.entries) == nil, "Callback has no mutation side effect")
	Ledger.commit(update, 7, "receipt:other", entry)
	local candidate = transform(raw)
	check(discarded.entries["receipt:other"] == nil, "Discarded candidate isolated")
	raw = candidate
	return raw
end
check(Ledger.commit(conflictUpdate, 7, "receipt:new", entry) ~= nil, "Conflict retry succeeds")
total, count = Ledger.summary(raw)
check(count == 2 and total.coins == 30000 and retryCalls == 1, "Concurrent deliveries conserve both grants")
local ownership = {}
local function unavailable() error("ownership unavailable") end
check(not Entitlements.refresh(ownership, "movement", 7, 201, unavailable), "Initial verification failure")
check(Entitlements.view(ownership, "movement") == "Unknown", "No unverified entitlement")
check(Entitlements.refresh(ownership, "movement", 7, 201, function() return true end), "Verified entitlement")
check(not Entitlements.refresh(ownership, "movement", 7, 201, unavailable), "Refresh failure")
local owned, fresh = Entitlements.view(ownership, "movement")
check(owned == "Owned" and not fresh, "Prior verified benefit retained with stale flag")
local verify = coroutine.create(function()
	Entitlements.refresh(ownership, "movement", 7, 201, function() coroutine.yield(); return false end)
end)
check(coroutine.resume(verify), "Verification yields")
check(not Entitlements.refresh(ownership, "movement", 7, 201, function() return true end), "Concurrent refresh serialized")
check(coroutine.resume(verify), "Verification resumed")
check(Entitlements.view(ownership, "movement") == "NotOwned", "Verified removal reflected")
local pack = { key = "pack_small", kind = "DeveloperProduct", platformId = 101, permanent = false,
	salesEnabled = true, integrationReady = true, grant = entry.grant, defaultPrice = 49 }
local pass = { key = "movement", kind = "Pass", platformId = 201, permanent = true, salesEnabled = true, integrationReady = true }
local starter = { key = "starter", kind = "Pass", platformId = 202, permanent = true, salesEnabled = true, integrationReady = true,
	grant = { coins = 7500, tokens = { Coins2_15 = 1 } } }
check(not pcall(Config.validate, { pack, pack }), "Duplicate config identities rejected")
local context = { ready = true, ledgerReady = true, ledgerCount = 0, ownership = "NotOwned", fresh = true, highestCoinTier = 8, prompt = false, eligible = true }
local tier = table.clone(pass)
tier.coinTier = 2
check(Availability.reason(tier, context) == "Superseded", "Highest-owned D1 tier excludes inferior offers")
context.fresh = false
check(Availability.reason(pass, context) == "OwnershipUnavailable", "Stale ownership blocks prompts")
local now, ready, eligible, owns, ownershipFail = 0, true, true, false, false
local gameplay = Rules.new(0)
gameplay.coins = 0
local prompts, sends = 0, 0
local view, reply = nil, nil
raw, mode = Ledger.empty(), "ok"
local deps = {
	now = function() return now end,
	ready = function() return ready end,
	update = update,
	owns = function() if ownershipFail then error("unavailable") end; return owns end,
	eligible = function(_, product)
		return eligible and (not product.grant or gameplay.coins <= Economy.coinLimit - product.grant.coins)
	end,
	prompt = function() prompts += 1; return true end,
	send = function(_, snapshot, result) view = snapshot; reply = result; sends += 1 end,
}
local service = Service.create(deps, { pack, pass, starter })
check(service.ownership(7, "movement") == "Unknown", "Server ownership accessor fails closed without session")
local receipt = { PurchaseId = "purchase1", PlayerId = 7, ProductId = 101 }
check(not service.receipt(receipt), "Missing player defers")
service.add(7)
service.request(7, { id = "buy", action = "Purchase", product = "pack_small" })
check(prompts == 1 and reply.status == "PromptOpened", "Server-authorized prompt")
service.request(7, { id = "buy", action = "Purchase", product = "pack_small" })
check(prompts == 1, "Lost request reply cannot reprompt")
service.request(7, { id = "buy", action = "Purchase", product = "movement" })
check(reply.reason == "RequestIdReused" and prompts == 1, "Changed replay rejected")
service.request(7, { id = "other", action = "Purchase", product = "movement" })
check(prompts == 1 and reply.reason == "PurchasePending", "One platform prompt")
now = 10
service.finished(7, 101, "DeveloperProduct", true)
check(view.reserved.coins == 0 and view.receiptCount == 0 and view.promptProduct == "pack_small", "Completion event never grants")
ready = false
check(not service.receipt(receipt), "Storage pause / lease conflict defers")
ready = true
mode = "lost"
check(not service.receipt(receipt) and view.ledgerStatus == "Recovering", "Unconfirmed fulfillment not acknowledged")
mode, eligible = "ok", false
gameplay.coins = Economy.coinLimit
pack.salesEnabled = false
check(service.receipt(receipt) and view.reserved.coins == 15000 and view.receiptCount == 1, "Delivered receipt recovers despite sales/policy changes")
check(gameplay.coins == Economy.coinLimit and view.reserved.coins == 15000, "Full wallet cannot clip durable purchased credit")
check(service.receipt(receipt) and view.reserved.coins == 15000, "Duplicate cannot grant again")
check(view.promptProduct == nil, "Receipt plus closed prompt releases slot")
service.remove(7)
check(not service.receipt(receipt), "Disconnect delivery defers")
service.add(7)
check(view.reserved.coins == 15000 and service.receipt(receipt), "Rejoin loads paid value and dedup")
check(not service.receipt({ PurchaseId = "unknown", PlayerId = 7, ProductId = 999 }), "Unknown product defers")
check(not service.receipt({ PurchaseId = "spoof", PlayerId = 8, ProductId = 101 }), "Receipt cannot target another session")
eligible, pack.salesEnabled = true, true
gameplay.coins = 0
now = 20
service.request(7, { id = "before-event", action = "Purchase", product = "pack_small" })
check(service.receipt({ PurchaseId = "purchase2", PlayerId = 7, ProductId = 101 }), "Receipt before prompt event")
check(view.promptProduct == "pack_small", "Receipt alone cannot release open native prompt")
service.finished(7, 101, "DeveloperProduct", true)
check(view.promptProduct == nil and view.reserved.coins == 30000, "Receipt/event order independent")
service.finished(7, 202, "Pass", true)
check(view.reserved.coins == 30000 and not service.claimPass(7, "starter"), "Pass event boolean is not proof")
owns = true
service.refresh(7)
check(service.claimPass(7, "starter") and view.reserved.coins == 37500 and view.reserved.tokens.Coins2_15 == 1, "Verified bundle reserved atomically")
check(service.claimPass(7, "starter") and view.reserved.coins == 37500, "Lifetime bundle claim deduplicates")
ownershipFail = true
now = 30
service.refresh(7)
check(not service.claimPass(7, "starter") and view.products[2].ownership == "Owned" and not view.products[2].ownershipFresh, "Failure keeps verified ownership but disables fresh grants")
local serverOwned, serverFresh = service.ownership(7, "movement")
check(serverOwned == "Owned" and not serverFresh, "Server accessor preserves verified stale ownership")
local before = prompts
now = 30
for i = 1, 12 do service.request(7, { id = "spam" .. i, action = "Purchase", product = "movement" }) end
check(prompts == before, "Rate/ownership guards prevent spam prompts")
-- Suspend actual commit: local concurrency, disconnect and late reply cannot send to rejoin.
ownershipFail, owns = false, false
local blocked = true
deps.update = function(key, transform)
	if blocked then blocked = false; coroutine.yield() end
	return update(key, transform)
end
local worker = coroutine.create(function() return service.receipt({ PurchaseId = "yielded", PlayerId = 7, ProductId = 101 }) end)
check(coroutine.resume(worker), "Receipt save yields")
check(not service.receipt({ PurchaseId = "yielded", PlayerId = 7, ProductId = 101 }), "Concurrent local receipt defers")
service.remove(7)
service.add(7)
local beforeLate = sends
local ok, acknowledged = coroutine.resume(worker)
check(ok and acknowledged and sends == beforeLate, "Durable disconnected completion cannot send stale state to rejoin")
service.refresh(7)
now = 40
service.refresh(7)
check(view.reserved.coins == 52500, "Late disconnected reward recovered")
local noWrites = writes
local disabled = Service.create(deps, Config.products)
disabled.add(7)
disabled.request(7, { id = "off", action = "Purchase", product = "pack_small" })
check(reply.reason == "Unconfigured" and writes == noWrites and prompts == before, "Production defaults never access paid store or prompt")
-- A platform exception leaves the native prompt uncertain, and cannot invite repurchase.
deps.prompt = function() prompts += 1; error("uncertain platform prompt") end
local uncertain = Service.create(deps, { pack })
uncertain.add(7)
now = 50
uncertain.request(7, { id = "uncertain", action = "Purchase", product = "pack_small" })
check(reply.status == "Recovering" and view.promptProduct == "pack_small", "Prompt error remains reserved")
local attempted = prompts
uncertain.request(7, { id = "new", action = "Purchase", product = "pack_small" })
check(prompts == attempted and reply.reason == "PurchasePending", "Prompt uncertainty blocks new charge")
uncertain.finished(7, 101, "DeveloperProduct", false)
check(view.promptProduct == nil and reply.status == "Cancelled" and view.reserved.coins == 52500, "Cancellation never erases paid value")
-- Snapshot/refresh polling never uses up purchase-ID retention, and refresh is throttled.
local readWrites = writes
for i = 1, 300 do
	now += 1
	uncertain.request(7, { id = "state" .. i, action = "State" })
end
uncertain.request(7, { id = "refresh", action = "Refresh" })
local refreshWrites = writes
uncertain.request(7, { id = "refresh2", action = "Refresh" })
check(writes <= refreshWrites and refreshWrites <= readWrites + 1, "Refresh calls coalesced")
now += 10
uncertain.request(7, { id = "after-poll", action = "Purchase", product = "pack_small" })
check(reply.status == "Recovering" and prompts == attempted + 1, "Polling does not exhaust purchase capacity")
uncertain.finished(7, 101, "DeveloperProduct", false)
deps.prompt = function() return false end
now += 10
uncertain.request(7, { id = "not-for-sale", action = "Purchase", product = "pack_small" })
check(reply.status == "Rejected" and reply.reason == "PlatformUnavailable" and view.promptProduct == nil, "Unavailable metadata before prompt does not strand prompt slot")
print("Purchases:", assertions, "assertions passed")
