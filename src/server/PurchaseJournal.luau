--!strict
-- Presentation obligation only. Receipt/entitlement/grant authority remains with P02.
-- Separate keys in the existing purchase store preserve the version-1 receipt aggregate.
local Ledger = require(script.Parent.PurchaseLedger)
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
export type Pending = {
	id: string,
	product: string,
	platformId: number,
	kind: Types.PlatformKind,
	baseline: number,
}
export type Record = { version: number, pending: Pending? }
local Journal = {}
function Journal.decode(raw: unknown): Record?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	for key in value do
		if key ~= "version" and key ~= "pending" then
			return nil
		end
	end
	if value.version ~= 1 then
		return nil
	end
	if value.pending == nil then
		return { version = 1 }
	end
	if typeof(value.pending) ~= "table" then
		return nil
	end
	local pending = value.pending :: { [string]: unknown }
	for key in pending do
		if
			key ~= "id"
			and key ~= "product"
			and key ~= "platformId"
			and key ~= "kind"
			and key ~= "baseline"
		then
			return nil
		end
	end
	if
		typeof(pending.id) ~= "string"
		or #pending.id < 1
		or #pending.id > 64
		or typeof(pending.product) ~= "string"
		or #pending.product < 1
		or #pending.product > 64
		or typeof(pending.platformId) ~= "number"
		or pending.platformId < 1
		or pending.platformId > 9007199254740990
		or pending.platformId % 1 ~= 0
		or (pending.kind ~= "Pass" and pending.kind ~= "DeveloperProduct")
		or typeof(pending.baseline) ~= "number"
		or pending.baseline < 0
		or pending.baseline > Ledger.maxEntries
		or pending.baseline % 1 ~= 0
	then
		return nil
	end
	return {
		version = 1,
		pending = {
			id = pending.id,
			product = pending.product,
			platformId = pending.platformId,
			kind = pending.kind,
			baseline = pending.baseline,
		},
	}
end
local function change(
	update: Ledger.Update,
	userId: number,
	transform: (Record) -> Record?
): Record?
	local ok, raw = pcall(update, "Prompt_" .. tostring(userId), function(value: unknown): unknown
		local record = if value == nil then { version = 1 } else Journal.decode(value)
		return if record then transform(record) else nil
	end)
	return if ok then Journal.decode(raw) else nil
end
function Journal.load(update: Ledger.Update, userId: number): Record?
	return change(update, userId, function(record)
		return record
	end)
end
function Journal.begin(update: Ledger.Update, userId: number, pending: Pending): Record?
	if not Journal.decode({ version = 1, pending = pending }) then
		return nil
	end
	local record = change(update, userId, function(value)
		if value.pending then
			return nil
		end
		return { version = 1, pending = table.clone(pending) }
	end)
	return if record and record.pending and record.pending.id == pending.id then record else nil
end
function Journal.resolve(update: Ledger.Update, userId: number, id: string): Record?
	local record = change(update, userId, function(value)
		if value.pending and value.pending.id ~= id then
			return nil
		end
		return { version = 1 }
	end)
	return if record and not record.pending then record else nil
end
return Journal
