--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Offline = require(game:GetService("ReplicatedStorage").Shared.OfflineTypes)
local Ledger = require(script.Parent.PurchaseLedger)
local Credits = require(script.Parent.OfflineCredits)
export type Dependencies = {
	now: () -> number,
	state: (number) -> Types.State?,
	ready: (number) -> boolean,
	allowed: (number) -> boolean,
	busy: (number) -> boolean,
	persist: (number) -> boolean,
}
type Bucket = { state: Types.State, time: number, tokens: number }
local Service = {}
function Service.parse(raw: unknown): Offline.CreditRequest?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	for key in value do
		if key ~= "id" and key ~= "action" and key ~= "awardId" then
			return nil
		end
	end
	if
		typeof(value.id) ~= "string"
		or #value.id < 1
		or #value.id > 64
		or typeof(value.awardId) ~= "string"
		or #value.awardId > 128
		or not string.match(value.awardId, "^offline:%d+$")
		or (value.action ~= "Select" and value.action ~= "Redeem")
	then
		return nil
	end
	return { id = value.id, awardId = value.awardId, action = value.action :: "Select" | "Redeem" }
end
function Service.create(deps: Dependencies)
	local working: { [number]: boolean } = {}
	local buckets: { [number]: Bucket } = {}
	local function commit(userId: number, state: Types.State, changed: boolean): boolean
		local saved = not changed or deps.persist(userId)
		return saved and deps.state(userId) == state and deps.ready(userId)
	end
	local api = {}
	function api.receipt(receipt: Ledger.Receipt): boolean
		if working[receipt.userId] or not deps.ready(receipt.userId) then
			return false
		end
		local state = deps.state(receipt.userId)
		if not state then
			return false
		end
		working[receipt.userId] = true
		local ok, confirmed = pcall(function()
			local granted, _, changed = Credits.grant(state, receipt.productId, receipt.purchaseId)
			return granted and commit(receipt.userId, state, changed)
		end)
		working[receipt.userId] = nil
		return ok and confirmed == true
	end
	function api.request(userId: number, raw: unknown): Offline.CreditResult?
		local state = deps.state(userId)
		if not state then
			return nil
		end
		local bucket = buckets[userId]
		local now = deps.now()
		if not bucket or bucket.state ~= state then
			bucket = { state = state, time = now, tokens = 4 }
			buckets[userId] = bucket :: Bucket
		end
		bucket.tokens = math.min(4, bucket.tokens + math.max(0, now - bucket.time))
		bucket.time = now
		if bucket.tokens < 1 then
			return nil
		end
		bucket.tokens -= 1
		local request = Service.parse(raw)
		if not request then
			return nil
		end
		local result: Offline.CreditResult = {
			id = request.id,
			awardId = request.awardId,
			status = "Rejected",
			reason = "Unavailable",
		}
		if working[userId] or not deps.ready(userId) or deps.busy(userId) then
			return result
		end
		if not deps.allowed(userId) then
			result.reason = "ValidationPending"
			return result
		end
		working[userId] = true
		local ok, confirmed, reason = pcall(function(): (boolean, string)
			local mutate: (Types.State, string) -> (boolean, string, boolean) = Credits.select
			if request.action == "Redeem" then
				mutate = Credits.redeem
			end
			local accepted, message, changed = mutate(state, request.awardId)
			if not accepted then
				return false, message
			end
			return commit(userId, state, changed), "SaveUnconfirmed"
		end)
		working[userId] = nil
		if deps.state(userId) ~= state then
			return nil
		end
		result.status = if ok and confirmed
			then (if request.action == "Select" then "Selected" else "Redeemed")
			elseif not ok or reason == "SaveUnconfirmed" then "Recovering"
			else "Rejected"
		result.reason = if ok and confirmed then "Durable" else reason or "SaveUnconfirmed"
		return result
	end
	function api.remove(userId: number)
		buckets[userId] = nil
	end
	return api
end
return Service
