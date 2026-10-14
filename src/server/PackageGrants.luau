--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local PurchaseTypes = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Ledger = require(script.Parent.PurchaseLedger)
local Config = require(script.Parent.PurchaseConfig)
local OfflineAwards = require(script.Parent.OfflineAwards)
local starterToken: PurchaseTypes.TokenId = "Coins2_15"
local Grants = { creditLimit = 9007199254740990, maxMarkers = Ledger.maxEntries }
local amounts: { [string]: number } = {
	pack_small = 15000,
	pack_medium = 60000,
	pack_large = 240000,
	pack_huge = 1200000,
	starter = 7500,
}
local function integer(value: unknown, maximum: number): boolean
	return typeof(value) == "number" and value >= 0 and value <= maximum and value % 1 == 0
end
function Grants.supports(key: string): boolean
	return amounts[key] ~= nil or key == "vip"
end
function Grants.empty(): Types.PackageRecord
	return { assistedCredit = 0, deliveries = {} }
end
local function validEntry(id: string, entry: Ledger.Entry): boolean
	local starter = entry.product == "starter"
	for token, amount in entry.grant.tokens do
		if not starter or token ~= "Coins2_15" or amount ~= 1 then
			return false
		end
	end
	return amounts[entry.product] ~= nil
		and entry.grant.coins == amounts[entry.product]
		and entry.kind == (if starter then "Pass" else "DeveloperProduct")
		and (not starter or id == "pass:" .. tostring(entry.platformId))
		and (starter or (#id > 8 and string.sub(id, 1, 8) == "receipt:"))
		and (not starter or entry.grant.tokens[starterToken] == 1)
end
function Grants.promote(state: Types.State)
	if not state.offlineData then
		state.offlineData = OfflineAwards.empty()
		OfflineAwards.freeze(state, "legacy-package-checkpoint")
	end
	state.schemaVersion = math.max(18, state.schemaVersion)
end
function Grants.decode(raw: unknown): Types.PackageRecord?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	for key in value do
		if key ~= "assistedCredit" and key ~= "deliveries" and key ~= "starterClaim" then
			return nil
		end
	end
	if not integer(value.assistedCredit, Grants.creditLimit) then
		return nil
	end
	local ledger = Ledger.decode({ version = 1, entries = value.deliveries })
	if not ledger then
		return nil
	end
	local starter: string? = nil
	local promised = 0
	for id, entry in ledger.entries do
		if not validEntry(id, entry) then
			return nil
		end
		promised += entry.grant.coins
		if entry.product == "starter" then
			if starter then
				return nil
			end
			starter = id
		end
	end
	-- There is no credit transfer in this schema. Never decode erased paid value.
	local credit = value.assistedCredit :: number
	if value.starterClaim ~= starter or credit < promised or (credit - promised) % 500 ~= 0 then
		return nil
	end
	return {
		assistedCredit = value.assistedCredit :: number,
		deliveries = ledger.entries,
		starterClaim = starter,
	}
end
function Grants.copy(record: Types.PackageRecord): Types.PackageRecord
	local decoded = Grants.decode(record)
	assert(decoded, "Invalid paid package aggregate")
	return decoded
end
function Grants.capacity(state: Types.State, product: Config.Product): boolean
	local grant = product.grant
	if not grant or not amounts[product.key] then
		return product.key == "vip"
	end
	local record = state.packages
	if product.key == "starter" and record and record.starterClaim then
		return false
	end
	local markers = 0
	if record then
		for _ in record.deliveries do
			markers += 1
		end
	end
	return markers < Grants.maxMarkers
		and (if record then record.assistedCredit else 0) <= Grants.creditLimit - grant.coins
		and (product.key ~= "starter" or (state.boosts.tokens[starterToken] or 0) < 1000000)
end
-- All preflight precedes mutation. The caller commits this aggregate with P04 tokens.
-- Assisted Coins NEVER enter the unlabelled wallet, including overflow or restricted recovery.
function Grants.deliver(state: Types.State, id: string, entry: Ledger.Entry): (boolean, string)
	local decoded = Ledger.decode({ version = 1, entries = { [id] = entry } })
	if not decoded or not validEntry(id, entry) then
		return false, "UnsupportedGrant"
	end
	local record = state.packages or Grants.empty()
	local prior = record.deliveries[id]
	if prior then
		return prior.product == entry.product
			and prior.platformId == entry.platformId
			and prior.kind == entry.kind
			and prior.grant.coins == entry.grant.coins,
			"Replay"
	end
	if entry.product == "starter" and record.starterClaim then
		return false, "AlreadyClaimed"
	end
	local count = 0
	for _ in record.deliveries do
		count += 1
	end
	if
		count >= Grants.maxMarkers
		or record.assistedCredit > Grants.creditLimit - entry.grant.coins
		or (entry.product == "starter" and (state.boosts.tokens[starterToken] or 0) >= 1000000)
	then
		return false, "Capacity"
	end
	record.assistedCredit += entry.grant.coins
	record.deliveries[id] = decoded.entries[id]
	if entry.product == "starter" then
		record.starterClaim = id
		state.boosts.tokens[starterToken] = (state.boosts.tokens[starterToken] or 0) + 1
	end
	state.packages = record
	return true, "CreditReserved"
end
function Grants.dailyCapacity(state: Types.State): boolean
	return not state.vipOwned
		or (if state.packages then state.packages.assistedCredit else 0)
			<= Grants.creditLimit - 500
end
function Grants.daily(state: Types.State)
	if not state.vipOwned then
		return
	end
	assert(Grants.dailyCapacity(state), "VIP credit capacity")
	local record = state.packages or Grants.empty()
	record.assistedCredit += 500
	state.packages = record
	Grants.promote(state)
end
-- Owner-only view. A paused save cannot turn an in-memory marker into confirmed fulfillment.
function Grants.view(
	state: Types.State,
	key: string,
	confirmed: boolean,
	eligible: boolean,
	day: number?
): PurchaseTypes.PackageState
	local coins, tokens = 0, 0
	if confirmed and state.packages then
		for _, entry in state.packages.deliveries do
			if entry.product == key then
				coins += entry.grant.coins
				tokens += entry.grant.tokens[starterToken] or 0
			end
		end
	end
	return {
		eligible = eligible,
		eligibilityReason = if eligible then "Available" else "ValidationPending",
		confirmed = confirmed,
		claimed = key == "starter"
			and confirmed
			and state.packages ~= nil
			and state.packages.starterClaim ~= nil,
		coins = amounts[key],
		token = if key == "starter" then "Coins2_15" else nil,
		tokenSeconds = if key == "starter" then Config.tokenBenefits.Coins2_15.seconds else nil,
		vipFactor = if key == "vip" then 1.1 else nil,
		dailyCoins = if key == "vip" then 500 else nil,
		dailyClaimed = if key == "vip" and day then state.lastDailyDay >= day else nil,
		dailySupplementAvailable = if key == "vip" and day
			then confirmed and state.vipOwned and state.lastDailyDay < day
			else nil,
		appliedVipFactor = state.earningFactors.vipFactor,
		fulfilledCoins = coins,
		fulfilledTokens = tokens,
		assistedCredit = if confirmed and state.packages
			then state.packages.assistedCredit - (if state.lineage
				then state.lineage.packageTransferred
				else 0)
			else 0,
		walletCredited = if confirmed and state.lineage
			then state.lineage.packageTransferred
			else 0,
		creditUsable = confirmed and state.lineage ~= nil and state.paidBoostsAllowed,
	}
end
return table.freeze(Grants)
