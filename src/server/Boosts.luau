--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.BoostTypes)
local PurchaseTypes = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Config = require(script.Parent.PurchaseConfig)
local Ledger = require(script.Parent.PurchaseLedger)
local Boosts = { effectsValidated = true, maxRemaining = 86400, maxMarkers = Ledger.maxEntries }
local function integer(value: unknown, maximum: number): boolean
	return typeof(value) == "number" and value >= 0 and value <= maximum and value % 1 == 0
end
function Boosts.identifier(value: unknown): boolean
	return typeof(value) == "string"
		and #value > 0
		and #value <= 160
		and string.match(value, "^[%w_:%-]+$") ~= nil
end
local function fields(value: { [string]: unknown }, keys: { string }): boolean
	for key in value do
		if not table.find(keys, key) then
			return false
		end
	end
	return true
end
function Boosts.empty(): Types.Record
	return { lastClock = 0, tokens = {}, deliveries = {}, activations = {} }
end
function Boosts.timer(raw: unknown, coin: boolean): Types.Timer?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	if
		not fields(value, { "strength", "started", "expires" })
		or (value.strength ~= 2 and (coin or value.strength ~= 4))
		or not integer(value.started, 100000000000)
		or value.started == 0
		or not integer(value.expires, 100000000000)
		or (value.expires :: number) <= (value.started :: number)
	then
		return nil
	end
	return {
		strength = value.strength :: number,
		started = value.started :: number,
		expires = value.expires :: number,
	}
end
function Boosts.copy(record: Types.Record): Types.Record
	local result = Boosts.empty()
	result.lastClock, result.tokens = record.lastClock, table.clone(record.tokens)
	result.coin = if record.coin then table.clone(record.coin) else nil
	result.luck = if record.luck then table.clone(record.luck) else nil
	for id, value in record.deliveries do
		result.deliveries[id] = table.clone(value)
	end
	for id, value in record.activations do
		result.activations[id] = table.clone(value)
	end
	return result
end
function Boosts.decode(raw: unknown): Types.Record?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	if
		not fields(value, { "lastClock", "tokens", "coin", "luck", "deliveries", "activations" })
		or not integer(value.lastClock, 100000000000)
		or typeof(value.tokens) ~= "table"
		or typeof(value.deliveries) ~= "table"
		or typeof(value.activations) ~= "table"
	then
		return nil
	end
	local result = Boosts.empty()
	result.lastClock = value.lastClock :: number
	for key, amount in value.tokens :: { [string]: unknown } do
		if
			not Config.tokenBenefits[key :: PurchaseTypes.TokenId]
			or not integer(amount, 1000000)
			or amount == 0
		then
			return nil
		end
		result.tokens[key :: PurchaseTypes.TokenId] = amount :: number
	end
	for _, name in { "coin", "luck" } do
		local rawTimer = value[name]
		if rawTimer ~= nil then
			local timer = Boosts.timer(rawTimer, name == "coin")
			if
				not timer
				or timer.started > result.lastClock
				or timer.expires > result.lastClock + Boosts.maxRemaining
			then
				return nil
			end
			if name == "coin" then
				result.coin = timer
			else
				result.luck = timer
			end
		end
	end
	local count = 0
	for id, rawEntry in value.deliveries :: { [string]: unknown } do
		count += 1
		if
			count > Boosts.maxMarkers
			or not Boosts.identifier(id)
			or typeof(rawEntry) ~= "table"
		then
			return nil
		end
		local entry = rawEntry :: { [string]: unknown }
		if
			not fields(entry, { "product", "platformId", "token", "count" })
			or not Boosts.identifier(entry.product)
			or not integer(entry.platformId, 9007199254740990)
			or entry.platformId == 0
			or typeof(entry.token) ~= "string"
			or not Config.tokenBenefits[entry.token :: PurchaseTypes.TokenId]
			or not integer(entry.count, 1000000)
			or entry.count == 0
		then
			return nil
		end
		result.deliveries[id] = {
			product = entry.product :: string,
			platformId = entry.platformId :: number,
			token = entry.token :: PurchaseTypes.TokenId,
			count = entry.count :: number,
		}
	end
	count = 0
	for id, rawEntry in value.activations :: { [string]: unknown } do
		count += 1
		if
			count > Boosts.maxMarkers
			or not Boosts.identifier(id)
			or typeof(rawEntry) ~= "table"
		then
			return nil
		end
		local entry = rawEntry :: { [string]: unknown }
		if
			not fields(entry, { "token", "coinExpiry", "luckExpiry" })
			or typeof(entry.token) ~= "string"
			or not Config.tokenBenefits[entry.token :: PurchaseTypes.TokenId]
			or not integer(entry.coinExpiry, 100000000000)
			or not integer(entry.luckExpiry, 100000000000)
		then
			return nil
		end
		local benefit = Config.tokenBenefits[entry.token :: PurchaseTypes.TokenId]
		if
			(benefit.coins == 2) ~= (entry.coinExpiry ~= 0)
			or (benefit.luck > 1) ~= (entry.luckExpiry ~= 0)
		then
			return nil
		end
		result.activations[id] = {
			token = entry.token :: PurchaseTypes.TokenId,
			coinExpiry = entry.coinExpiry :: number,
			luckExpiry = entry.luckExpiry :: number,
		}
	end
	return result
end
local function count(map: { [string]: unknown }): number
	local total = 0
	for _ in map do
		total += 1
	end
	return total
end
-- P02 ledger entry is server-only. Tokens and durable receipt marker share one profile write.
function Boosts.deliver(
	record: Types.Record,
	receiptId: string,
	entry: Ledger.Entry
): (boolean, string)
	local grant = Ledger.grant(entry.grant)
	if
		not Boosts.identifier(receiptId)
		or not grant
		or grant.coins ~= 0
		or entry.kind ~= "DeveloperProduct"
		or not Boosts.identifier(entry.product)
		or not integer(entry.platformId, 9007199254740990)
		or entry.platformId == 0
	then
		return false, "UnsupportedGrant"
	end
	local token, amount = next(grant.tokens)
	if token == nil or next(grant.tokens, token) ~= nil then
		return false, "UnsupportedGrant"
	end
	local tokenId: PurchaseTypes.TokenId = token :: PurchaseTypes.TokenId
	local previous = record.deliveries[receiptId]
	if previous then
		return previous.product == entry.product
			and previous.platformId == entry.platformId
			and previous.token == token
			and previous.count == amount,
			"Replay"
	end
	if
		count(record.deliveries) >= Boosts.maxMarkers
		or (record.tokens[tokenId] or 0) > 1000000 - amount
	then
		return false, "Capacity"
	end
	record.tokens[tokenId] = (record.tokens[tokenId] or 0) + amount
	record.deliveries[receiptId] =
		{ product = entry.product, platformId = entry.platformId, token = tokenId, count = amount }
	return true, "Delivered"
end
function Boosts.active(timer: Types.Timer?, wall: number): number
	return if timer and wall >= timer.started and wall < timer.expires then timer.strength else 1
end
function Boosts.overlap(timer: Types.Timer?, first: number, last: number): number
	return if timer
		then math.max(0, math.min(last, timer.expires) - math.max(first, timer.started))
		else 0
end
-- Caller owns durable commit and readiness. All preflight precedes either timer mutation.
local function plan(
	record: Types.Record,
	token: PurchaseTypes.TokenId,
	wall: number,
	permanent: number,
	atCapacity: boolean
): (string, Types.Timer?, Types.Timer?)
	if not integer(wall, 100000000000) or wall == 0 or wall < record.lastClock then
		return "ClockUnavailable", nil, nil
	end
	local benefit = Config.tokenBenefits[token]
	if not benefit or (record.tokens[token] or 0) < 1 then
		return "NoToken", nil, nil
	end
	if atCapacity then
		return "Capacity", nil, nil
	end
	if benefit.luck == 2 and permanent >= 2 then
		return "RedundantLuck", nil, nil
	end
	local function extended(timer: Types.Timer?, strength: number): Types.Timer?
		local active = Boosts.active(timer, wall)
		if active > 1 and active ~= strength then
			return nil
		end
		local expires = (if active > 1 and timer then timer.expires else wall) + benefit.seconds
		if expires - wall > Boosts.maxRemaining or expires > 100000000000 then
			return nil
		end
		return {
			strength = strength,
			started = if active > 1 and timer then timer.started else wall,
			expires = expires,
		}
	end
	local coin = if benefit.coins > 1 then extended(record.coin, benefit.coins) else nil
	local luck = if benefit.luck > 1 then extended(record.luck, benefit.luck) else nil
	if (benefit.coins > 1 and not coin) or (benefit.luck > 1 and not luck) then
		return "IncompatibleOrQueued", nil, nil
	end
	return "Ready", coin, luck
end
function Boosts.activationReasons(
	record: Types.Record,
	wall: number,
	permanent: number
): { [PurchaseTypes.TokenId]: string }
	local reasons: { [PurchaseTypes.TokenId]: string } = {}
	local full = count(record.activations) >= Boosts.maxMarkers
	for token in record.tokens do
		local id: PurchaseTypes.TokenId = token :: PurchaseTypes.TokenId
		reasons[id] = (plan(record, id, wall, permanent, full))
	end
	return reasons
end
function Boosts.activate(
	record: Types.Record,
	request: Types.Request,
	wall: number,
	permanent: number
): (boolean, string)
	local previous = record.activations[request.id]
	if previous then
		return previous.token == request.token, "Replay"
	end
	local reason, coin, luck =
		plan(record, request.token, wall, permanent, count(record.activations) >= Boosts.maxMarkers)
	if reason ~= "Ready" then
		return false, reason
	end
	if coin then
		record.coin = coin
	end
	if luck then
		record.luck = luck
	end
	local remaining = (record.tokens[request.token] or 0) - 1
	if remaining > 0 then
		record.tokens[request.token] = remaining
	else
		record.tokens[request.token] = nil
	end
	record.lastClock = wall
	record.activations[request.id] = {
		token = request.token,
		coinExpiry = if coin then coin.expires else 0,
		luckExpiry = if luck then luck.expires else 0,
	}
	return true, "Activated"
end
return table.freeze(Boosts)
