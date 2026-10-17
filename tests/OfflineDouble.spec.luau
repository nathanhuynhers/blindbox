--!strict
local Awards = require("./OfflineAwards")
local Purchase = require("./OfflinePurchase")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function reward(n, coins)
	local state = { coins = coins or 0, offlinePending = n, offlineSeconds = 3600 }
	Awards.freeze(state, "normal_v1")
	return state
end
local state = reward(math.floor(10.75))
check(state.offlineData.current.normal == 10, "Freeze displayed whole N")
check(Awards.reserve(state, 101), "Reserve exact N")
check(
	Awards.reserve(state, 101) and not Awards.reserve(state, 102),
	"Repeated clicks preserve single binding"
)
check(Awards.fulfill(state, 101, "a"), "Verified fulfillment")
check(
	state.coins == 10 and state.offlineData.assistedCredit == 10 and state.offlinePending == 0,
	"Exactly 2N, bonus retained as assisted"
)
check(
	Awards.fulfill(state, 101, "a") and state.coins + state.offlineData.assistedCredit == 20,
	"No 4N from replay"
)
check(
	not Awards.fulfill(state, 101, "extra") and state.offlineData.exceptions.extra == 101,
	"Extra charge retained for explicit recovery"
)
check(Awards.decode(state.offlineData, 0) ~= nil, "Coherent marker/claim/credit")
check(
	not Awards.view(state, false).fulfilled and Awards.view(state, true).fulfilled,
	"Owner fulfillment projection requires confirmed durability"
)
local free = reward(10000)
check(Awards.claim(free) == 10000 and free.coins == 10000, "Ordinary free Claim")
check(Awards.claim(free) == 0 and not Awards.reserve(free, 101), "Claimed award never offered")
local zero = reward(0)
check(zero.offlineData.current == nil and not Awards.reserve(zero, 101), "Zero never offered")
local delayed = reward(10000)
check(Awards.reserve(delayed, 101), "Durable cancelled reservation")
check(Awards.claim(delayed) == 10000, "Cancellation restores free claim")
delayed.offlineData = Awards.copy(delayed.offlineData, 0)
delayed.offlinePending = 7
Awards.freeze(delayed, "normal_v2")
check(not Awards.reserve(delayed, 102), "New return cannot replace unresolved reservation")
check(
	Awards.fulfill(delayed, 101, "old")
		and delayed.coins == 10000
		and delayed.offlinePending == 7
		and delayed.offlineData.assistedCredit == 10000,
	"Delayed old receipt pays only frozen extra, preserving new award"
)
check(
	not Awards.reserve(delayed, 101) and Awards.reserve(delayed, 102),
	"Identity epoch never reuses a product for another award"
)
check(
	not Awards.fulfill(delayed, 101, "older_extra") and delayed.offlinePending == 7,
	"Out-of-order old extra cannot consume newer award"
)
check(
	Awards.fulfill(delayed, 102, "new")
		and delayed.coins == 10007
		and delayed.offlineData.assistedCredit == 10007,
	"Correct new receipt keeps both promises"
)
local full = reward(50, require("./Currency").limit)
check(
	Awards.reserve(full, 101) and Awards.fulfill(full, 101, "full"),
	"Charged purchase survives full wallet"
)
check(
	full.offlineData.earnedCredit == 50 and full.offlineData.assistedCredit == 50,
	"No clipped purchased benefit"
)
full.coins -= 10
check(
	Awards.drainEarned(full) == 10 and full.offlineData.earnedCredit == 40,
	"Earned overflow drains without repeating receipt"
)
local legacy = { coins = 0, offlinePending = 42, offlineSeconds = 0 }
check(Awards.claim(legacy) == 42, "Exact legacy pending preserved")
local labels = reward(10)
labels.offlineData.current.assisted = 3
check(
	Awards.reserve(labels, 103) and Awards.fulfill(labels, 103, "labels"),
	"Frozen base source labels"
)
check(
	labels.coins == 7 and labels.offlineData.assistedCredit == 13,
	"Base assisted kept; entire bonus assisted"
)
for _, mutate in
	{
		function(r)
			r.version = 2
		end,
		function(r)
			r.surprise = true
		end,
		function(r)
			r.earnedCredit = 0 / 0
		end,
		function(r)
			r.bindings["101"].award.normal = 5
		end,
		function(r)
			r.receipts.a = "999"
		end,
		function(r)
			r.active = "101"
		end,
	}
do
	local corrupt = Awards.copy(state.offlineData, 0)
	mutate(corrupt)
	check(Awards.decode(corrupt, 0) == nil, "Invalid aggregate fails closed")
end
-- Inject persistence loss and competing profile ownership at the actual product boundary.
local owners = { [7] = reward(10), [8] = reward(99) }
local ready = true
local mode = "ok"
local durable = nil
local pending = nil
local nativePrompts = 0
local product = Purchase.create({
	associationApproved = true,
	paidPathValidated = true,
	state = function(id)
		return owners[id]
	end,
	ready = function(id)
		return owners[id] ~= nil and ready
	end,
	persist = function(id)
		local owner = owners[id]
		pending = pending
			or {
				coins = owner.coins,
				offlinePending = owner.offlinePending,
				offlineSeconds = owner.offlineSeconds,
				offlineData = Awards.copy(owner.offlineData, owner.offlinePending),
			}
		if mode == "fail" then
			ready = false
			return false
		end
		durable = pending
		if mode == "lost" then
			ready = false
			error("lost response after commit")
		end
		pending = nil
		return true
	end,
})
local disabled = Purchase.create({
	associationApproved = false,
	paidPathValidated = true,
	state = function(id)
		return owners[id]
	end,
	ready = function()
		return true
	end,
	persist = function()
		error("must not save")
	end,
})
check(
	not disabled.eligible(7, 101) and not disabled.prepare(7, 101),
	"Unapproved protocol never enables prompt"
)
mode = "fail"
if product.prepare(7, 101) then
	nativePrompts += 1
end
check(
	nativePrompts == 0 and pending.offlineData.bindings["101"].award.normal == 10,
	"Failed reservation cannot prompt"
)
ready, mode = true, "ok"
check(
	product.prepare(7, 101) and durable.offlineData.active == "101",
	"Reconciled immutable reservation persists before prompt"
)
mode = "lost"
local receipt = { userId = 7, productId = 101, purchaseId = "lost" }
check(
	not product.receipt(receipt) and durable.offlineData.receipts.lost == "101",
	"Lost reply retains coherent paid obligation without ack"
)
check(not product.receipt(receipt), "Paused/uncertain save cannot acknowledge")
ready, mode = true, "ok"
check(
	product.receipt(receipt) and owners[7].coins + owners[7].offlineData.assistedCredit == 20,
	"Retry reconciles once, no repeated bonus"
)
check(owners[8].offlinePending == 99 and owners[8].coins == 0, "Owner isolation")
ready = false
check(
	not product.receipt({ userId = 8, productId = 101, purchaseId = "competing" }),
	"Lease/handoff readiness barrier"
)
ready = true
check(
	not product.receipt({ userId = 8, productId = 101, purchaseId = "external" })
		and owners[8].offlineData.exceptions.external == 101,
	"No reservation charge gets durable recovery exception"
)
check(not product.eligible(8, 102), "Recovery exception blocks more prompts")
print(string.format("PASS: %d offline Double & Claim domain/adapter checks", checks))
