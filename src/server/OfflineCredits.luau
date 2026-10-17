--!strict
local Currency = require(game:GetService("ReplicatedStorage").Shared.Currency)
-- Receipts grant fungible credits. Only an explicit owner request selects/redeems a return.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Offline = require(game:GetService("ReplicatedStorage").Shared.OfflineTypes)
local Awards = require(script.Parent.OfflineAwards)
local Packages = require(script.Parent.PackageGrants)
local Credits = { maxReceipts = 2048, maxReturns = 256 }
local function integer(value: unknown, maximum: number): boolean
	return typeof(value) == "number" and value >= 0 and value <= maximum and value % 1 == 0
end
local function identifier(value: unknown): boolean
	return typeof(value) == "string"
		and #value > 0
		and #value <= 128
		and string.match(value, "^[%w_:%-]+$") ~= nil
end
local function count(values: { [string]: unknown }): number
	local total = 0
	for _ in values do
		total += 1
	end
	return total
end
function Credits.empty(): Offline.CreditRecord
	return { version = 1, receipts = {}, returns = {}, redemptions = {} }
end
local function legacyBound(data: Offline.Record, id: string): boolean
	for _, binding in data.bindings do
		if binding.award.id == id then
			return true
		end
	end
	return false
end
function Credits.decode(raw: unknown, data: Offline.Record): Offline.CreditRecord?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	for key in value do
		if not table.find({ "version", "receipts", "returns", "redemptions", "selected" }, key) then
			return nil
		end
	end
	if
		value.version ~= 1
		or typeof(value.receipts) ~= "table"
		or typeof(value.returns) ~= "table"
		or typeof(value.redemptions) ~= "table"
	then
		return nil
	end
	local record = Credits.empty()
	for id, product in value.receipts :: { [string]: unknown } do
		if
			not identifier(id)
			or not integer(product, Awards.creditLimit)
			or product == 0
			or data.receipts[id]
			or data.exceptions[id]
		then
			return nil
		end
		record.receipts[id] = product :: number
	end
	for id, entry in value.returns :: { [string]: unknown } do
		if typeof(entry) ~= "table" or not identifier(id) or legacyBound(data, id) then
			return nil
		end
		local item = entry :: { [string]: unknown }
		for key in item do
			if
				not table.find(
					{ "id", "normal", "assisted", "calculationVersion", "baseClaimed" },
					key
				)
			then
				return nil
			end
		end
		local serial = tonumber(string.match(id, "^offline:(%d+)$") or "")
		if
			not serial
			or serial < 1
			or serial > data.serial
			or id ~= "offline:" .. tostring(serial)
			or item.id ~= id
			or not integer(item.normal, Currency.limit)
			or item.normal == 0
			or not integer(item.assisted, item.normal :: number)
			or not identifier(item.calculationVersion)
			or typeof(item.baseClaimed) ~= "boolean"
		then
			return nil
		end
		local current = data.current
		if current and current.id == id then
			if
				current.normal ~= item.normal
				or current.assisted ~= item.assisted
				or current.calculationVersion ~= item.calculationVersion
				or current.baseClaimed ~= item.baseClaimed
			then
				return nil
			end
		elseif not item.baseClaimed then
			return nil
		end
		record.returns[id] = {
			id = id,
			normal = item.normal :: number,
			assisted = item.assisted :: number,
			calculationVersion = item.calculationVersion :: string,
			baseClaimed = item.baseClaimed :: boolean,
		}
	end
	local used: { [string]: boolean } = {}
	for id, receipt in value.redemptions :: { [string]: unknown } do
		local frozen = record.returns[id]
		if
			typeof(receipt) ~= "string"
			or not record.receipts[receipt]
			or used[receipt]
			or not frozen
			or not frozen.baseClaimed
		then
			return nil
		end
		used[receipt], record.redemptions[id] = true, receipt
	end
	if value.selected ~= nil then
		if
			typeof(value.selected) ~= "string"
			or not record.returns[value.selected]
			or record.redemptions[value.selected]
		then
			return nil
		end
		record.selected = value.selected
	end
	if
		count(record.receipts) > Credits.maxReceipts
		or count(record.returns) > Credits.maxReturns
	then
		return nil
	end
	return record
end
function Credits.copy(record: Offline.CreditRecord, data: Offline.Record): Offline.CreditRecord
	local copy = Credits.decode(record, data)
	assert(copy, "Invalid offline credit aggregate")
	return copy
end
function Credits.available(record: Offline.CreditRecord?): number
	return if record then count(record.receipts) - count(record.redemptions) else 0
end
function Credits.purchaseCapacity(state: Types.State): boolean
	local record = state.offlineCredits
	return not record or count(record.receipts) < Credits.maxReceipts
end
function Credits.promote(state: Types.State): Offline.CreditRecord
	if not state.offlineData then
		state.offlineData = Awards.empty()
		if state.offlinePending > 0 then
			Awards.freeze(state, "legacy_v1")
		end
	end
	state.packages = state.packages or Packages.empty()
	state.schemaVersion = math.max(19, state.schemaVersion)
	state.offlineCredits = state.offlineCredits or Credits.empty()
	return state.offlineCredits :: Offline.CreditRecord
end
function Credits.grant(
	state: Types.State,
	productId: number,
	receiptId: string
): (boolean, string, boolean)
	if
		not integer(productId, Awards.creditLimit)
		or productId == 0
		or not identifier(receiptId)
	then
		return false, "InvalidReceipt", false
	end
	local record, data = state.offlineCredits, state.offlineData
	if
		data
		and (
			data.receipts[receiptId]
			or data.exceptions[receiptId]
			or data.bindings[tostring(productId)]
		)
	then
		return false, "HistoricalIdentity", false
	end
	if record and record.receipts[receiptId] then
		return record.receipts[receiptId] == productId, "Replay", false
	end
	if record and count(record.receipts) >= Credits.maxReceipts then
		return false, "Capacity", false
	end
	local target = Credits.promote(state)
	target.receipts[receiptId] = productId
	return true, "CreditSaved", true
end
function Credits.select(state: Types.State, id: string): (boolean, string, boolean)
	local data, record = state.offlineData, state.offlineCredits
	if not data or not identifier(id) or legacyBound(data, id) then
		return false, "NoAward", false
	end
	if record and record.redemptions[id] then
		return false, "AlreadyRedeemed", false
	end
	local frozen = if record then record.returns[id] else nil
	local current = data.current
	if
		not frozen
		and (
			not current
			or current.id ~= id
			or current.baseClaimed
			or state.offlinePending ~= current.normal
		)
	then
		return false, "NoAward", false
	end
	if record and record.selected == id then
		return true, "Selected", false
	end
	if not frozen and record and count(record.returns) >= Credits.maxReturns then
		return false, "Capacity", false
	end
	local target = Credits.promote(state)
	target.returns[id] = frozen or table.clone(current :: Offline.Award)
	target.selected = id
	return true, "Selected", true
end
function Credits.markBaseClaimed(state: Types.State, id: string?)
	local record = state.offlineCredits
	if record and id and record.returns[id] then
		record.returns[id].baseClaimed = true
	end
end
function Credits.redeem(state: Types.State, id: string): (boolean, string, boolean)
	local record, data = state.offlineCredits, state.offlineData
	if record and record.redemptions[id] then
		return true, "Replay", false
	end
	if not data or Credits.available(record) <= 0 then
		return false, "NoCredit", false
	end
	local frozen = if record then record.returns[id] else nil
	local current = data.current
	if not frozen then
		if
			not current
			or current.id ~= id
			or current.baseClaimed
			or legacyBound(data, id)
			or state.offlinePending ~= current.normal
		then
			return false, "NoAward", false
		end
		frozen = current
	end
	if not frozen then
		return false, "NoAward", false
	end
	if legacyBound(data, id) then
		return false, "HistoricalAward", false
	end
	local base = if frozen.baseClaimed then 0 else frozen.normal
	local assisted = if frozen.baseClaimed then 0 else frozen.assisted
	if
		data.assistedCredit > Awards.creditLimit - frozen.normal - assisted
		or data.earnedCredit > Awards.creditLimit - (base - assisted)
	then
		return false, "Capacity", false
	end
	-- Select only after every capacity check; rejection preserves both the token and the award.
	local ok, reason = Credits.select(state, id)
	if not ok then
		return false, reason, false
	end
	local target = state.offlineCredits :: Offline.CreditRecord
	local redeemed = target.returns[id]
	local used: { [string]: boolean } = {}
	for _, receipt in target.redemptions do
		used[receipt] = true
	end
	local keys: { string } = {}
	for receipt in target.receipts do
		if not used[receipt] then
			table.insert(keys, receipt)
		end
	end
	table.sort(keys)
	data.earnedCredit += base - assisted
	data.assistedCredit += redeemed.normal + assisted
	redeemed.baseClaimed = true
	if current and current.id == id then
		current.baseClaimed = true
		state.offlinePending, state.offlineSeconds = 0, 0
	end
	target.redemptions[id], target.selected = keys[1], nil
	Awards.drainEarned(state)
	return true, "Redeemed", true
end
function Credits.view(state: Types.State, confirmed: boolean, allowed: boolean): Offline.View
	local view = Awards.view(state, confirmed)
	local record = state.offlineCredits
	local selected = if record and record.selected then record.returns[record.selected] else nil
	view.creditFlow = true
	view.credits = if confirmed then Credits.available(record) else 0
	view.selectedAwardId = if selected then selected.id else nil
	view.selectedNormal = if selected then selected.normal else nil
	view.selectedBaseClaimed = if selected then selected.baseClaimed else nil
	view.redeemAllowed = confirmed and allowed and not view.recoveryRequired
	if record and view.awardId and record.redemptions[view.awardId] and confirmed then
		view.fulfilled = true
	end
	return view
end
return Credits
