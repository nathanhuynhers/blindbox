--!strict
local Players = game:GetService("Players")
local Purchase = require(script.Parent.OfflinePurchase)
local Storage = require(script.Parent.Storage)
local Rules = require(script.Parent.Rules)
local Config = require(script.Parent.PurchaseConfig)
local Ledger = require(script.Parent.PurchaseLedger)
local Runtime = {}
-- Approval table MN-22 has no approved association/type/price. These are release gates,
-- not knobs that assigning a product id or integrationReady can bypass.
local associationApproved = false
local paidPathValidated = false
function Runtime.create(sessionFor: (Player) -> Storage.Session?, changed: (Player) -> ())
	local function session(userId: number): Storage.Session?
		local player = Players:GetPlayerByUserId(userId)
		return if player then sessionFor(player) else nil
	end
	local purchase = Purchase.create({
		associationApproved = associationApproved,
		paidPathValidated = paidPathValidated,
		state = function(userId)
			local owner = session(userId)
			return if owner then owner.state else nil
		end,
		ready = function(userId)
			local owner = session(userId)
			return owner ~= nil
				and owner.handle ~= nil
				and owner.ready
				and not owner.closed
				and not owner.transferring
				and not owner.busy
				and owner.pendingSave == nil
				and owner.pendingRelease == nil
				and os.clock() < owner.safeUntil
		end,
		persist = function(userId)
			local owner, player = session(userId), Players:GetPlayerByUserId(userId)
			if not owner or not player then
				return false
			end
			-- Promotion is forward-only and happens before snapshot capture.
			owner.state.schemaVersion = math.max(17, owner.state.schemaVersion)
			owner.state.revision += 1
			Rules.settle(owner.state, os.clock())
			owner.state.offlineCommitPending, owner.ready = true, false
			local saved = Storage.flush(owner, false)
			if session(userId) == owner then
				changed(player)
			end
			return saved
		end,
	})
	return {
		eligible = function(userId: number, product: Config.Product): boolean
			return product.key == "offline_double"
				and product.kind == "DeveloperProduct"
				and product.platformId ~= nil
				and purchase.eligible(userId, product.platformId)
		end,
		prepare = function(userId: number, product: Config.Product): boolean
			if product.key ~= "offline_double" then
				return true
			end
			return product.kind == "DeveloperProduct"
				and product.platformId ~= nil
				and purchase.prepare(userId, product.platformId)
		end,
		fulfill = function(receipt: Ledger.Receipt, product: Config.Product): boolean?
			if product.key ~= "offline_double" then
				return nil
			end
			return purchase.receipt(receipt)
		end,
	}
end
return Runtime
