--!strict
local Currency = require(game:GetService("ReplicatedStorage").Shared.Currency)
-- Receipt and reserved reward are ONE UpdateAsync value. No wallet mutation here.
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
export type Entry = {
	product: string,
	platformId: number,
	kind: Types.PlatformKind,
	grant: Types.Grant,
}
export type Record = { version: number, entries: { [string]: Entry } }
export type Receipt = { purchaseId: string, userId: number, productId: number }
export type Update = (string, (unknown) -> unknown) -> unknown
local Ledger = { maxEntries = 2048 }
local tokenIds: { [string]: boolean } = {
	Coins2_15 = true,
	Coins2_30 = true,
	Coins2_60 = true,
	Luck2_30 = true,
	Luck4_30 = true,
	Combo2_30 = true,
}
local function integer(value: unknown, maximum: number): boolean
	return typeof(value) == "number" and value >= 0 and value <= maximum and value % 1 == 0
end
local function identifier(value: unknown): boolean
	return typeof(value) == "string"
		and #value > 0
		and #value <= 160
		and string.match(value, "^[%w_:%-]+$") ~= nil
end
local function fields(value: { [string]: unknown }, allowed: { [string]: boolean }): boolean
	for key in value do
		if not allowed[key] then
			return false
		end
	end
	return true
end
function Ledger.grant(raw: unknown): Types.Grant?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	if
		not fields(value, { coins = true, tokens = true })
		or not integer(value.coins, Currency.limit)
		or typeof(value.tokens) ~= "table"
	then
		return nil
	end
	local tokens: { [Types.TokenId]: number } = {}
	for key, count in value.tokens :: { [string]: unknown } do
		if not tokenIds[key] or not integer(count, 1000000) or count == 0 then
			return nil
		end
		tokens[key :: Types.TokenId] = count :: number
	end
	return { coins = value.coins :: number, tokens = tokens }
end
function Ledger.empty(): Record
	return { version = 1, entries = {} }
end
function Ledger.decode(raw: unknown): Record?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	if
		not fields(value, { version = true, entries = true })
		or value.version ~= 1
		or typeof(value.entries) ~= "table"
	then
		return nil
	end
	local result = Ledger.empty()
	local count = 0
	local coins = 0
	for id, rawEntry in value.entries :: { [string]: unknown } do
		count += 1
		if count > Ledger.maxEntries or not identifier(id) or typeof(rawEntry) ~= "table" then
			return nil
		end
		local entry = rawEntry :: { [string]: unknown }
		local grant = Ledger.grant(entry.grant)
		if
			not fields(entry, { product = true, platformId = true, kind = true, grant = true })
			or not identifier(entry.product)
			or not integer(entry.platformId, 9007199254740990)
			or entry.platformId == 0
			or (entry.kind ~= "Pass" and entry.kind ~= "DeveloperProduct")
			or not grant
		then
			return nil
		end
		if grant.coins > Currency.creditLimit - coins then
			return nil
		end
		coins += grant.coins
		result.entries[id] = {
			product = entry.product :: string,
			platformId = entry.platformId :: number,
			kind = entry.kind,
			grant = grant,
		}
	end
	return result
end
function Ledger.receipt(raw: unknown): Receipt?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	if
		not identifier(value.PurchaseId)
		or #(value.PurchaseId :: string) > 128
		or not integer(value.PlayerId, 9007199254740990)
		or value.PlayerId == 0
		or not integer(value.ProductId, 9007199254740990)
		or value.ProductId == 0
	then
		return nil
	end
	return {
		purchaseId = value.PurchaseId :: string,
		userId = value.PlayerId :: number,
		productId = value.ProductId :: number,
	}
end
local function key(userId: number): string
	assert(integer(userId, 9007199254740990) and userId > 0, "Invalid purchase owner")
	return "Player_" .. tostring(userId)
end
function Ledger.load(update: Update, userId: number): Record?
	local ok, result = pcall(update, key(userId), function(raw: unknown): unknown
		if raw == nil then
			return Ledger.empty()
		end
		return Ledger.decode(raw)
	end)
	return if ok then Ledger.decode(result) else nil
end
function Ledger.commit(update: Update, userId: number, receiptId: string, entry: Entry): Record?
	-- Validate server adapter inputs too; never let invalid grants create poisoned data.
	if
		not identifier(receiptId)
		or not Ledger.decode({ version = 1, entries = { [receiptId] = entry } })
	then
		return nil
	end
	local ok, result = pcall(update, key(userId), function(raw: unknown): unknown
		local record = if raw == nil then Ledger.empty() else Ledger.decode(raw)
		if not record then
			return nil
		end -- Preserve corrupt/newer records; no default reset.
		local prior = record.entries[receiptId]
		if prior then
			if
				prior.product ~= entry.product
				or prior.platformId ~= entry.platformId
				or prior.kind ~= entry.kind
			then
				return nil
			end
			return record -- Replays recover the original promise, never recompute it.
		end
		local count, coins = 0, 0
		for _, pending in record.entries do
			count += 1
			coins += pending.grant.coins
		end
		if count >= Ledger.maxEntries or entry.grant.coins > Currency.creditLimit - coins then
			return nil
		end -- Never evict a paid marker or persist an unsafe cumulative promise.
		record.entries[receiptId] = {
			product = entry.product,
			platformId = entry.platformId,
			kind = entry.kind,
			grant = Ledger.grant(entry.grant) :: Types.Grant,
		}
		return record
	end)
	local saved = if ok then Ledger.decode(result) else nil
	local marker = if saved then saved.entries[receiptId] else nil
	if
		not marker
		or marker.product ~= entry.product
		or marker.platformId ~= entry.platformId
		or marker.kind ~= entry.kind
	then
		return nil
	end
	return saved
end
function Ledger.summary(record: Record): (Types.Grant, number, { [string]: boolean })
	local total: Types.Grant = { coins = 0, tokens = {} }
	local count = 0
	local products: { [string]: boolean } = {}
	for _, entry in record.entries do
		count += 1
		products[entry.product] = true
		assert(
			entry.grant.coins <= Currency.creditLimit - total.coins,
			"Unsafe reserved Coin total"
		)
		total.coins += entry.grant.coins
		for token, amount in entry.grant.tokens do
			local id: Types.TokenId = token :: Types.TokenId
			total.tokens[id] = (total.tokens[id] or 0) + amount
		end
	end
	return total, count, products
end
return Ledger
