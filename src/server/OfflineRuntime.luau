--!strict
local Players = game:GetService("Players")
local Purchase = require(script.Parent.OfflinePurchase)
local Storage = require(script.Parent.Storage)
local Rules = require(script.Parent.Rules)
local Config = require(script.Parent.PurchaseConfig)
local Ledger = require(script.Parent.PurchaseLedger)
local Credits = require(script.Parent.OfflineCredits)
local CreditService = require(script.Parent.OfflineCreditService)
local Lineage = require(script.Parent.PaidLineage)
local Runtime = {}
-- 49-Robux saved-credit/redemption flow approved 2026-10-12. Historical epoch
-- association remains closed; paid usability/policy validation is a separate release gate.
local associationApproved = false
local paidPathValidated = true
function Runtime.create(
	sessionFor: (Player) -> Storage.Session?,
	changed: (Player) -> (),
	policyAllowed: ((number) -> boolean)?
)
	local function session(userId: number): Storage.Session?
		local player = Players:GetPlayerByUserId(userId)
		return if player then sessionFor(player) else nil
	end
	local function allowed(userId: number): boolean
		local owner = session(userId)
		return paidPathValidated
			and (
				if policyAllowed
					then policyAllowed(userId) and owner ~= nil and owner.state.lineage ~= nil
					else true
			)
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
			Lineage.drain(owner.state, if policyAllowed then policyAllowed(userId) else false)
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
	local credits = CreditService.create({
		now = os.clock,
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
		allowed = allowed,
		busy = function()
			return false
		end, -- Bootstrap fences native purchases/automation before control dispatch.
		persist = function(userId)
			local owner, player = session(userId), Players:GetPlayerByUserId(userId)
			if not owner or not player then
				return false
			end
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
		control = credits.request,
		remove = credits.remove,
		view = function(owner: Storage.Session)
			return Credits.view(
				owner.state,
				owner.ready
					and not owner.busy
					and owner.pendingSave == nil
					and owner.pendingRelease == nil
					and not owner.transferring
					and not owner.closed
					and os.clock() < owner.safeUntil,
				paidPathValidated
					and (if policyAllowed then owner.state.paidBoostsAllowed else true)
			)
		end,
		eligible = function(userId: number, product: Config.Product): boolean
			if
				product.key == "offline_double"
				and product.benefits
				and product.benefits.offlineCredits == 1
			then
				local owner = session(userId)
				local state = if owner then owner.state else nil
				local selected = if state and state.offlineCredits
					then state.offlineCredits.selected
					else nil
				local current = if state and state.offlineData
					then state.offlineData.current
					else nil
				return allowed(userId)
					and owner ~= nil
					and owner.handle ~= nil
					and owner.ready
					and not owner.closed
					and not owner.busy
					and not owner.transferring
					and owner.pendingSave == nil
					and owner.pendingRelease == nil
					and os.clock() < owner.safeUntil
					and product.kind == "DeveloperProduct"
					and product.platformId ~= nil
					and state ~= nil
					and Credits.purchaseCapacity(state)
					and Credits.available(state.offlineCredits) == 0
					and (selected ~= nil or (current ~= nil and not current.baseClaimed))
			end
			return product.key == "offline_double"
				and product.kind == "DeveloperProduct"
				and product.platformId ~= nil
				and purchase.eligible(userId, product.platformId)
		end,
		prepare = function(userId: number, product: Config.Product): boolean
			if product.key ~= "offline_double" then
				return true
			end
			if product.benefits and product.benefits.offlineCredits == 1 then
				local owner = session(userId)
				return paidPathValidated
					and owner ~= nil
					and owner.state.offlineCredits ~= nil
					and owner.state.offlineCredits.selected ~= nil
					and owner.ready
					and owner.handle ~= nil
					and not owner.closed
					and not owner.busy
					and not owner.transferring
					and owner.pendingSave == nil
					and owner.pendingRelease == nil
					and os.clock() < owner.safeUntil
					and Credits.purchaseCapacity(owner.state)
					and Credits.available(owner.state.offlineCredits) == 0
			end
			return product.kind == "DeveloperProduct"
				and product.platformId ~= nil
				and purchase.prepare(userId, product.platformId)
		end,
		fulfill = function(receipt: Ledger.Receipt, product: Config.Product): boolean?
			if product.key ~= "offline_double" then
				return nil
			end
			local owner = session(receipt.userId)
			local data = if owner then owner.state.offlineData else nil
			-- Historical sold identities retain the immutable award promise, never become a credit.
			if
				product.benefits
				and product.benefits.offlineCredits == 1
				and not (data and data.bindings[tostring(receipt.productId)])
			then
				return credits.receipt(receipt)
			end
			return purchase.receipt(receipt)
		end,
	}
end
return Runtime
