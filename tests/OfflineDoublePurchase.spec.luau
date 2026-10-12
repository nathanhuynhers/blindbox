--!strict
-- P02's actual dispatcher + the variable-award handler. No native prompts/charges.
local Service = require("./PurchaseService")
local Ledger = require("./PurchaseLedger")
local Awards = require("./OfflineAwards")
local Purchase = require("./OfflinePurchase")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function fixture()
	local state = { coins = 0, offlinePending = 10000, offlineSeconds = 3600 }
	Awards.freeze(state, "normal_v1")
	local clock, available, saveMode, durable, record = 0, true, "ok", nil, nil
	local prompts, events = 0, {}
	local product = {
		key = "offline_double",
		permanent = false,
		kind = "DeveloperProduct",
		platformId = 101,
		salesEnabled = true,
		integrationReady = true,
		economic = true,
	}
	local offline = Purchase.create({
		associationApproved = true,
		paidPathValidated = true,
		state = function(id)
			return if id == 7 then state else nil
		end,
		ready = function(id)
			return id == 7 and available
		end,
		persist = function()
			if saveMode == "fail" then
				available = false
				return false
			end
			durable = {
				coins = state.coins,
				offlinePending = state.offlinePending,
				offlineSeconds = state.offlineSeconds,
				offlineData = Awards.copy(state.offlineData, state.offlinePending),
			}
			if saveMode == "lost" then
				available = false
				return false
			end
			return true
		end,
	})
	local service = Service.create({
		now = function()
			return clock
		end,
		ready = function(id)
			return available and id == 7
		end,
		update = function(_, transform)
			record = transform(record) or record
			return record
		end,
		owns = function()
			return false
		end,
		eligible = function(id, p)
			return offline.eligible(id, p.platformId)
		end,
		prepare = function(id, p)
			return offline.prepare(id, p.platformId)
		end,
		fulfill = function(receipt)
			return offline.receipt(receipt)
		end,
		prompt = function()
			check(
				durable.offlineData.bindings["101"].award.normal == 10000,
				"P02 prompt occurs only AFTER durable exact reservation"
			)
			prompts += 1
			return true
		end,
		send = function(id, _, result)
			check(id == 7, "P02 state owner isolation")
			if result then
				table.insert(events, result)
			end
		end,
	}, { product })
	service.add(7)
	return {
		service = service,
		state = state,
		events = events,
		prompts = function()
			return prompts
		end,
		mode = function(mode)
			saveMode = mode
		end,
		resume = function()
			available = true
		end,
		advance = function()
			clock += 20
		end,
		durable = function()
			return durable
		end,
	}
end
local function request(f, id)
	f.service.request(7, { id = id, action = "Purchase", product = "offline_double" })
end
local function receipt(f, id)
	return f.service.receipt({ PlayerId = 7, ProductId = 101, PurchaseId = id })
end
local f = fixture()
request(f, "one")
request(f, "one")
request(f, "two")
check(f.prompts() == 1 and f.service.busy(7), "Shared launcher prevents repeat/competing prompts")
f.service.finished(7, 101, "DeveloperProduct", true)
check(
	f.state.coins == 0 and f.state.offlinePending == 10000,
	"Purchase-completion event grants nothing"
)
check(
	receipt(f, "charged") and not f.service.busy(7),
	"Receipt after prompt close confirms fulfillment"
)
check(
	f.state.coins == 10000 and f.state.offlineData.assistedCredit == 10000,
	"P02 variable fulfillment delivers exact 2N"
)
check(
	receipt(f, "charged") and f.state.coins + f.state.offlineData.assistedCredit == 20000,
	"P02 repeated receipt cannot pay twice"
)
check(
	not receipt(f, "extra") and f.durable().offlineData.exceptions.extra == 101,
	"P02 extra charged receipt durable and unacknowledged"
)
local first = fixture()
request(first, "first")
check(
	receipt(first, "first_receipt") and first.service.busy(7),
	"Receipt before prompt closes retains launcher mutex"
)
first.service.finished(7, 101, "DeveloperProduct", true)
check(not first.service.busy(7), "Receipt-first order releases after platform close")
local cancelled = fixture()
request(cancelled, "cancel")
cancelled.service.finished(7, 101, "DeveloperProduct", false)
check(
	not cancelled.service.busy(7) and cancelled.state.offlineData.active == "101",
	"Cancel restores free Claim and preserves reservation"
)
Awards.claim(cancelled.state)
check(
	receipt(cancelled, "late")
		and cancelled.state.coins == 10000
		and cancelled.state.offlineData.assistedCredit == 10000,
	"Late charged receipt after cancelled/free claim pays only extra"
)
local reopened = fixture()
request(reopened, "cancel")
reopened.service.finished(7, 101, "DeveloperProduct", false)
reopened.advance()
request(reopened, "reopen")
check(
	reopened.prompts() == 2 and reopened.state.offlineData.bindings["101"].award.id == "offline:1",
	"Reopening preserves original association"
)
local failed = fixture()
failed.mode("fail")
request(failed, "failed")
check(failed.prompts() == 0, "Save failure never opens launcher")
local lost = fixture()
request(lost, "lost")
lost.mode("lost")
check(
	not receipt(lost, "lost_reply") and lost.durable().offlineData.receipts.lost_reply == "101",
	"Save response loss defers platform acknowledgement"
)
lost.resume()
lost.mode("ok")
check(
	receipt(lost, "lost_reply")
		and lost.state.coins + lost.state.offlineData.assistedCredit == 20000,
	"Replay recovers known grant once"
)
-- Post-commit fixed-grant delivery must use the original immutable promise, not live config.
local raw, deliveryReady, delivered, now = nil, false, 0, 0
local product = {
	key = "coins_boost_15",
	permanent = false,
	kind = "DeveloperProduct",
	platformId = 201,
	salesEnabled = true,
	integrationReady = true,
	grant = { coins = 0, tokens = { Coins2_15 = 1 } },
}
local committed = Service.create({
	now = function()
		return now
	end,
	ready = function()
		return true
	end,
	update = function(_, transform)
		raw = transform(raw) or raw
		return raw
	end,
	owns = function()
		return false
	end,
	prompt = function()
		return true
	end,
	eligible = function()
		return true
	end,
	send = function() end,
	deliverReserved = function(_, key, entry)
		check(
			raw.entries[key] ~= nil and entry.grant.tokens.Coins2_15 == 1,
			"Fixed delivery uses committed immutable promise"
		)
		if not deliveryReady then
			return false
		end
		if delivered == 0 then
			delivered += entry.grant.tokens.Coins2_15
		end
		return true
	end,
}, { product })
committed.add(7)
check(
	not committed.receipt({ PlayerId = 7, ProductId = 201, PurchaseId = "token" }),
	"Unconfirmed token transfer defers receipt ack"
)
product.grant.tokens.Coins2_15 = 99
deliveryReady, now = true, 20
committed.refresh(7)
check(delivered == 1, "Join/refresh recovery preserves original grant")
check(
	committed.receipt({ PlayerId = 7, ProductId = 201, PurchaseId = "token" }) and delivered == 1,
	"Post-commit replay idempotent"
)
print(string.format("PASS: %d integrated offline/P02 dispatch fixtures", checks))
