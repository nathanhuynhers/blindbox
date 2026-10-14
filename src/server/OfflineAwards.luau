--!strict
-- No earning formula here. N is the already rounded, server-computed return reward.
-- Product identity epochs are a REVIEW CANDIDATE, never production authorization.
local Types = require(game:GetService("ReplicatedStorage").Shared.OfflineTypes)
local Lineage = require(script.Parent.PaidLineage)
local GameTypes = require(game:GetService("ReplicatedStorage").Shared.Types)
export type Award = Types.Award
export type Reservation = Types.Reservation
export type Record = Types.Record
export type State = {
	lineage: GameTypes.LineageRecord?,
	coins: number,
	offlinePending: number,
	offlineSeconds: number,
	offlineData: Record?,
}
local Awards = { maxBindings = 256, maxReceipts = 2048, creditLimit = 9007199254740990 }
local coinLimit = 1000000000000
local function integer(value: unknown, maximum: number): boolean
	return typeof(value) == "number" and value >= 0 and value <= maximum and value % 1 == 0
end
local function identifier(value: unknown): boolean
	return typeof(value) == "string"
		and #value > 0
		and #value <= 128
		and string.match(value, "^[%w_:%-]+$") ~= nil
end
local function fields(value: { [string]: unknown }, allowed: { string }): boolean
	for key in value do
		if not table.find(allowed, key) then
			return false
		end
	end
	return true
end
local function award(raw: unknown): Award?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	if
		not fields(value, { "id", "normal", "assisted", "calculationVersion", "baseClaimed" })
		or not identifier(value.id)
		or not identifier(value.calculationVersion)
		or not integer(value.normal, coinLimit)
		or value.normal == 0
		or not integer(value.assisted, value.normal :: number)
		or typeof(value.baseClaimed) ~= "boolean"
	then
		return nil
	end
	return {
		id = value.id :: string,
		normal = value.normal :: number,
		assisted = value.assisted :: number,
		calculationVersion = value.calculationVersion :: string,
		baseClaimed = value.baseClaimed :: boolean,
	}
end
local function count(map: { [string]: unknown }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end
function Awards.empty(): Record
	return {
		version = 1,
		serial = 0,
		bindings = {},
		receipts = {},
		exceptions = {},
		earnedCredit = 0,
		assistedCredit = 0,
	}
end
function Awards.decode(raw: unknown, pending: number): Record?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	if
		not fields(value, {
			"version",
			"serial",
			"current",
			"active",
			"bindings",
			"receipts",
			"exceptions",
			"earnedCredit",
			"assistedCredit",
		})
		or value.version ~= 1
		or not integer(value.serial, Awards.creditLimit)
		or not integer(value.earnedCredit, Awards.creditLimit)
		or not integer(value.assistedCredit, Awards.creditLimit)
		or typeof(value.bindings) ~= "table"
		or typeof(value.receipts) ~= "table"
		or typeof(value.exceptions) ~= "table"
	then
		return nil
	end
	local result = Awards.empty()
	result.serial = value.serial :: number
	result.earnedCredit, result.assistedCredit =
		value.earnedCredit :: number, value.assistedCredit :: number
	if value.current ~= nil then
		result.current = award(value.current)
		if not result.current or result.current.id ~= "offline:" .. tostring(result.serial) then
			return nil
		end
	end
	local current = result.current
	if pending ~= (if current and not current.baseClaimed then current.normal else 0) then
		return nil
	end
	local unresolved: string? = nil
	local awardIds: { [string]: boolean } = {}
	for key, rawBinding in value.bindings :: { [string]: unknown } do
		if typeof(rawBinding) ~= "table" then
			return nil
		end
		local binding = rawBinding :: { [string]: unknown }
		local frozen = award(binding.award)
		if
			not frozen
			or not fields(binding, { "award", "productId", "receiptId" })
			or not integer(binding.productId, Awards.creditLimit)
			or binding.productId == 0
			or key ~= tostring(binding.productId)
			or (binding.receiptId ~= nil and not identifier(binding.receiptId))
		then
			return nil
		end
		if awardIds[frozen.id] then
			return nil
		end
		awardIds[frozen.id] = true
		local serial = tonumber(string.match(frozen.id, "^offline:(%d+)$") or "")
		if
			not serial
			or serial < 1
			or serial > result.serial
			or frozen.id ~= "offline:" .. tostring(serial)
		then
			return nil
		end
		if binding.receiptId == nil then
			if unresolved then
				return nil
			end
			unresolved = key
		else
			if not frozen.baseClaimed then
				return nil
			end
		end
		if current and frozen.id == current.id then
			if
				frozen.normal ~= current.normal
				or frozen.assisted ~= current.assisted
				or frozen.calculationVersion ~= current.calculationVersion
				or frozen.baseClaimed ~= current.baseClaimed
			then
				return nil
			end
		end
		result.bindings[key] = {
			award = frozen,
			productId = binding.productId :: number,
			receiptId = binding.receiptId :: string?,
		}
	end
	if count(result.bindings) > Awards.maxBindings or value.active ~= unresolved then
		return nil
	end
	result.active = unresolved
	for id, key in value.receipts :: { [string]: unknown } do
		if not identifier(id) or typeof(key) ~= "string" then
			return nil
		end
		local binding = result.bindings[key]
		if not binding or binding.receiptId ~= id then
			return nil
		end
		result.receipts[id] = key
	end
	for key, binding in result.bindings do
		if binding.receiptId and result.receipts[binding.receiptId] ~= key then
			return nil
		end
	end
	for id, product in value.exceptions :: { [string]: unknown } do
		if
			not identifier(id)
			or not integer(product, Awards.creditLimit)
			or product == 0
			or result.receipts[id]
		then
			return nil
		end
		result.exceptions[id] = product :: number
	end
	if count(result.receipts) + count(result.exceptions) > Awards.maxReceipts then
		return nil
	end
	return result
end
function Awards.copy(record: Record, pending: number): Record
	local decoded = Awards.decode(record, pending)
	assert(decoded, "Invalid offline award aggregate")
	return decoded
end
local function ensure(state: State): Record
	local record = state.offlineData
	if not record then
		record = Awards.empty()
		state.offlineData = record
	end
	assert(record, "Offline record initialization failed")
	return record
end
-- Only earned credit can enter today's wallet. Assisted value waits for the approved
-- policy/lineage transfer path; it must never enter an undifferentiated random-box wallet.
function Awards.drainEarned(state: State): number
	local record = ensure(state)
	local amount = math.min(record.earnedCredit, coinLimit - state.coins)
	Lineage.creditEarned(state, amount)
	record.earnedCredit -= amount
	return amount
end
function Awards.view(state: State, confirmed: boolean?): Types.View
	local record = state.offlineData
	local current = if record then record.current else nil
	local fulfilled = false
	if confirmed and record and current then
		for _, binding in record.bindings do
			if binding.award.id == current.id and binding.receiptId then
				fulfilled = true
			end
		end
	end
	return {
		awardId = if current then current.id else nil,
		normal = if current then current.normal else state.offlinePending,
		doubled = 2 * (if current then current.normal else state.offlinePending),
		claimable = state.offlinePending > 0 and (not current or not current.baseClaimed),
		fulfilled = fulfilled,
		recoveryRequired = confirmed == true and record ~= nil and next(record.exceptions) ~= nil,
		earnedCredit = if record then record.earnedCredit else 0,
		assistedCredit = if record then record.assistedCredit else 0,
	}
end
function Awards.claim(state: State): number
	local record = ensure(state)
	local current = record.current
	local normal = state.offlinePending
	local assisted = if current then current.assisted else 0
	assert(
		record.earnedCredit <= Awards.creditLimit - (normal - assisted),
		"Offline earned credit capacity"
	)
	assert(
		record.assistedCredit <= Awards.creditLimit - assisted,
		"Offline assisted credit capacity"
	)
	record.earnedCredit += normal - assisted
	record.assistedCredit += assisted
	if current then
		current.baseClaimed = true
		for _, binding in record.bindings do
			if binding.award.id == current.id then
				binding.award.baseClaimed = true
			end
		end
	end
	state.offlinePending, state.offlineSeconds = 0, 0
	return Awards.drainEarned(state)
end
-- Call AFTER ordinary rejoin auto-claim and the unchanged N calculation.
function Awards.freeze(state: State, calculationVersion: string, assisted: number?): Award?
	local record = ensure(state)
	assert(
		not record.current or record.current.baseClaimed,
		"Claim previous offline award before replacing it"
	)
	assert(
		identifier(calculationVersion) and integer(state.offlinePending, coinLimit),
		"Invalid computed offline award"
	)
	if state.offlinePending == 0 then
		record.current = nil
		return nil
	end
	assert(integer(assisted or 0, state.offlinePending), "Invalid offline source labels")
	assert(record.serial < Awards.creditLimit, "Offline award identity capacity")
	record.serial += 1
	local frozen: Award = {
		id = "offline:" .. tostring(record.serial),
		normal = state.offlinePending,
		assisted = assisted or 0,
		calculationVersion = calculationVersion,
		baseClaimed = false,
	}
	record.current = frozen
	return frozen
end
-- Candidate protocol: an identity is NEVER reused for another award on this account.
-- Thus delivery order cannot turn an old/extra charged receipt into a newer return.
function Awards.reserve(state: State, productId: number): (boolean, string)
	local record = ensure(state)
	local current = record.current
	if not integer(productId, Awards.creditLimit) or productId == 0 then
		return false, "InvalidProduct"
	end
	if
		not current
		or current.baseClaimed
		or current.normal == 0
		or current.normal ~= state.offlinePending
	then
		return false, "NoAward"
	end
	local key = tostring(productId)
	if record.active then
		local binding = record.bindings[record.active]
		return binding.award.id == current.id and record.active == key, "ReservationRetained"
	end
	if record.bindings[key] then
		return false, "ProductIdentityAlreadyBound"
	end
	if
		count(record.bindings) >= Awards.maxBindings
		or count(record.receipts) + count(record.exceptions) >= Awards.maxReceipts
	then
		return false, "Capacity"
	end
	if record.assistedCredit > Awards.creditLimit - 2 * current.normal then
		return false, "CreditCapacity"
	end
	record.bindings[key] = { award = table.clone(current), productId = productId }
	record.active = key
	return true, "Reserved"
end
-- Receipt marker, base claim, purchased extra and credit share the PROFILE write.
-- Caller must persist before acknowledging, and retain the exact snapshot on lost replies.
function Awards.fulfill(state: State, productId: number, receiptId: string): (boolean, string)
	local record = ensure(state)
	if
		not identifier(receiptId)
		or not integer(productId, Awards.creditLimit)
		or productId == 0
	then
		return false, "InvalidReceipt"
	end
	local key = tostring(productId)
	if record.receipts[receiptId] then
		return record.receipts[receiptId] == key, "Duplicate"
	end
	if record.exceptions[receiptId] then
		return false, "ChargedReceiptNeedsRecovery"
	end
	if count(record.receipts) + count(record.exceptions) >= Awards.maxReceipts then
		return false, "RecoveryCapacity"
	end
	local binding = record.bindings[key]
	if not binding or binding.receiptId then
		record.exceptions[receiptId] = productId
		return false, "ChargedReceiptNeedsRecovery"
	end
	local frozen = binding.award
	local base = if frozen.baseClaimed then 0 else frozen.normal
	local baseAssisted = if frozen.baseClaimed then 0 else frozen.assisted
	if
		record.assistedCredit > Awards.creditLimit - frozen.normal - baseAssisted
		or record.earnedCredit > Awards.creditLimit - (base - baseAssisted)
	then
		return false, "CreditCapacity"
	end
	record.earnedCredit += base - baseAssisted
	record.assistedCredit += frozen.normal + baseAssisted
	frozen.baseClaimed = true
	local current = record.current
	if current and current.id == frozen.id then
		current.baseClaimed = true
		state.offlinePending, state.offlineSeconds = 0, 0
	end
	binding.receiptId, record.receipts[receiptId], record.active = receiptId, key, nil
	Awards.drainEarned(state)
	return true, "Fulfilled"
end
return Awards
