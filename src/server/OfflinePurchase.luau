--!strict
local Currency = require(game:GetService("ReplicatedStorage").Shared.Currency)
local Awards = require(script.Parent.OfflineAwards)
local Ledger = require(script.Parent.PurchaseLedger)
export type Dependencies = {
	-- Both gates must be explicitly approved/validated before production use.
	associationApproved: boolean,
	paidPathValidated: boolean,
	state: (number) -> Awards.State?,
	ready: (number) -> boolean,
	persist: (number) -> boolean,
}
local Purchase = {}
function Purchase.create(deps: Dependencies)
	local working: { [number]: boolean } = {}
	local api = {}
	function api.eligible(userId: number, productId: number): boolean
		if
			not deps.associationApproved
			or not deps.paidPathValidated
			or working[userId]
			or not deps.ready(userId)
		then
			return false
		end
		local state = deps.state(userId)
		if not state then
			return false
		end
		local record = state.offlineData
		local current = if record then record.current else nil
		if
			not record
			or not current
			or current.baseClaimed
			or current.normal ~= state.offlinePending
			or next(record.exceptions) ~= nil
			or state.coins > Currency.limit - 2 * current.normal
		then
			return false
		end
		local probe: Awards.State = {
			coins = state.coins,
			offlinePending = state.offlinePending,
			offlineSeconds = state.offlineSeconds,
			offlineData = Awards.copy(record, state.offlinePending),
		}
		return (Awards.reserve(probe, productId))
	end
	function api.prepare(userId: number, productId: number): boolean
		if not api.eligible(userId, productId) then
			return false
		end
		local state = deps.state(userId)
		if not state then
			return false
		end
		working[userId] = true
		local ok, saved = pcall(function()
			local reserved = Awards.reserve(state, productId)
			return reserved and deps.persist(userId)
		end)
		working[userId] = nil
		-- Persist may yield: do not open a prompt after removal, replacement or handoff.
		return ok and saved == true and deps.state(userId) == state and deps.ready(userId)
	end
	function api.receipt(receipt: Ledger.Receipt): boolean
		-- No current policy/sales check for charged receipts. Schema + known immutable
		-- binding are sufficient recovery authority, even after a later policy change.
		if working[receipt.userId] or not deps.ready(receipt.userId) then
			return false
		end
		local state = deps.state(receipt.userId)
		if not state then
			return false
		end
		working[receipt.userId] = true
		local ok, confirmed = pcall(function()
			local granted = Awards.fulfill(state, receipt.productId, receipt.purchaseId)
			-- Persist exceptions too; NOT acknowledged pending explicit compensation/support.
			return deps.persist(receipt.userId) and granted
		end)
		working[receipt.userId] = nil
		return ok
			and confirmed == true
			and deps.state(receipt.userId) == state
			and deps.ready(receipt.userId)
	end
	return api
end
return Purchase
