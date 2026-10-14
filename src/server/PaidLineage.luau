--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(script.Parent.Economy)
local Collection = require(script.Parent.CollectionEconomy)
local Lineage = { creditLimit = 9007199254740990 }
export type Wallet = { coins: number, lineage: Types.LineageRecord? }
local function integer(value: unknown, maximum: number): boolean
	return typeof(value) == "number" and value >= 0 and value <= maximum and value % 1 == 0
end
function Lineage.promote(state: Types.State): Types.LineageRecord
	if state.lineage then
		return state.lineage
	end
	assert(
		state.packages and state.offlineData and state.offlineCredits,
		"Initialize credit aggregates before lineage"
	)
	-- Earlier released builds never made protected paid credit spendable. Legacy
	-- wallet, copies, banks and slots therefore retain their earned classification.
	local record: Types.LineageRecord = {
		version = 1,
		earnedCoins = state.coins,
		earnedOwned = table.clone(state.owned),
		earnedBanks = table.clone(state.earnings),
		earnedSlots = state.display.unlocked,
		assistedReserve = 0,
		packageTransferred = 0,
		offlineTransferred = 0,
	}
	state.lineage = record
	state.schemaVersion = 20
	return record
end
function Lineage.decode(raw: unknown, state: Types.State): Types.LineageRecord?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	for key in value do
		if
			not table.find({
				"version",
				"earnedCoins",
				"earnedOwned",
				"earnedBanks",
				"earnedSlots",
				"assistedReserve",
				"packageTransferred",
				"offlineTransferred",
			}, key)
		then
			return nil
		end
	end
	if
		value.version ~= 1
		or not integer(value.earnedCoins, state.coins)
		or not integer(value.earnedSlots, state.display.unlocked)
		or (value.earnedSlots :: number) < 3
		or not integer(value.assistedReserve, Lineage.creditLimit)
		or not integer(
			value.packageTransferred,
			if state.packages then state.packages.assistedCredit else 0
		)
		or not integer(
			value.offlineTransferred,
			if state.offlineData then state.offlineData.assistedCredit else 0
		)
		or typeof(value.earnedOwned) ~= "table"
		or typeof(value.earnedBanks) ~= "table"
		or value.assistedReserve :: number
			> Lineage.creditLimit - (state.coins - (value.earnedCoins :: number))
	then
		return nil
	end
	local owned: { [string]: number } = {}
	for id, amount in value.earnedOwned :: { [string]: unknown } do
		if not Catalog.byId[id] or not integer(amount, state.owned[id] or 0) or amount == 0 then
			return nil
		end
		owned[id] = amount :: number
	end
	local banks: { [string]: number } = {}
	for id, amount in value.earnedBanks :: { [string]: unknown } do
		if
			not state.owned[id]
			or typeof(amount) ~= "number"
			or amount < 0
			or amount > (state.earnings[id] or 0)
			or amount ~= amount
		then
			return nil
		end
		banks[id] = amount
	end
	return {
		version = 1,
		earnedCoins = value.earnedCoins :: number,
		earnedOwned = owned,
		earnedBanks = banks,
		earnedSlots = value.earnedSlots :: number,
		assistedReserve = value.assistedReserve :: number,
		packageTransferred = value.packageTransferred :: number,
		offlineTransferred = value.offlineTransferred :: number,
	}
end
function Lineage.copy(state: Types.State): Types.LineageRecord
	local record = Lineage.decode(state.lineage, state)
	assert(record, "Invalid earned/assisted aggregate")
	return record
end
function Lineage.creditEarned(state: Wallet, amount: number)
	assert(integer(amount, Config.coinLimit - state.coins), "Earned wallet capacity")
	state.coins += amount
	if state.lineage then
		state.lineage.earnedCoins += amount
	end
end
function Lineage.spendable(state: Types.State): number
	return if state.lineage and not state.paidBoostsAllowed
		then state.lineage.earnedCoins
		else state.coins
end
function Lineage.assistedSpend(state: Types.State, amount: number): boolean
	return state.lineage ~= nil and amount > state.lineage.earnedCoins
end
function Lineage.spend(state: Types.State, amount: number): boolean
	assert(integer(amount, Lineage.spendable(state)), "Unapproved Coin spending")
	local assisted = Lineage.assistedSpend(state, amount)
	if state.lineage then
		state.lineage.earnedCoins -= math.min(state.lineage.earnedCoins, amount)
	end
	state.coins -= amount
	return assisted
end
function Lineage.suspend(state: Types.State): boolean
	local record = state.lineage
	if not record then
		return false
	end
	local assisted = state.coins - record.earnedCoins
	if assisted == 0 then
		return false
	end
	assert(record.assistedReserve <= Lineage.creditLimit - assisted, "Assisted reserve capacity")
	record.assistedReserve += assisted
	state.coins = record.earnedCoins
	return true
end
-- Original package/offline credit is a cumulative promise. Separate transferred
-- counters prevent a rejoin, replay or policy change from crediting it again.
function Lineage.drain(state: Types.State, allowed: boolean): number
	local record = state.lineage
	if not record or not allowed then
		return 0
	end
	local room = Config.coinLimit - state.coins
	local moved = 0
	local reserve = math.min(room, record.assistedReserve)
	record.assistedReserve -= reserve
	state.coins += reserve
	moved += reserve
	room -= reserve
	room = math.min(
		room,
		Lineage.creditLimit - record.assistedReserve - (state.coins - record.earnedCoins)
	)
	if state.packages then
		local amount = math.min(room, state.packages.assistedCredit - record.packageTransferred)
		record.packageTransferred += amount
		state.coins += amount
		moved += amount
		room -= amount
	end
	if state.offlineData then
		local amount = math.min(room, state.offlineData.assistedCredit - record.offlineTransferred)
		record.offlineTransferred += amount
		state.coins += amount
		moved += amount
	end
	return moved
end
function Lineage.earnedRates(state: Types.State): { [string]: number }
	local record = state.lineage
	local owned = if record then record.earnedOwned else state.owned
	local slots = if record then record.earnedSlots else state.display.unlocked
	local rates: { [string]: number } = {}
	local collections: { [string]: number } = {}
	for slot, id in state.display.slots do
		if slot <= slots and id ~= "" and (owned[id] or 0) > 0 then
			rates[id] = Collection.rates[id] * Collection.multiplier(id, owned[id])
			local collection = Catalog.byId[id].collection
			collections[collection] = (collections[collection] or 0) + 1
		end
	end
	local factor = 1
	for _, count in collections do
		if count >= 3 then
			factor += Config.setBonus
			break
		end
	end
	for id, rate in rates do
		rates[id] = rate * factor
	end
	return rates
end
function Lineage.recordAccrual(
	state: Types.State,
	id: string,
	oldBank: number,
	newBank: number,
	earned: number
)
	local record = state.lineage
	if record then
		record.earnedBanks[id] =
			math.min(newBank, (record.earnedBanks[id] or 0) + math.min(earned, newBank - oldBank))
	end
end
function Lineage.transferBank(state: Types.State, id: string): number
	local bank = state.earnings[id] or 0
	local record = state.lineage
	local room = Config.coinLimit - state.coins
	local earned = if record then record.earnedBanks[id] or 0 else bank
	local earnedPart = math.min(math.floor(earned), room)
	local assistedPart = if record and state.paidBoostsAllowed
		then math.min(
			math.floor(bank - earned),
			room - earnedPart,
			Lineage.creditLimit - record.assistedReserve - (state.coins - record.earnedCoins)
		)
		else 0
	local amount = earnedPart + assistedPart
	if amount > 0 then
		state.earnings[id] = bank - amount
		state.coins += amount
		if record then
			record.earnedBanks[id] = earned - earnedPart
			record.earnedCoins += earnedPart
		end
	end
	return amount
end
function Lineage.grantFigure(state: Types.State, id: string, quantity: number, assisted: boolean)
	state.owned[id] = (state.owned[id] or 0) + quantity
	state.discovered[id] = true
	if state.lineage and not assisted then
		state.lineage.earnedOwned[id] = (state.lineage.earnedOwned[id] or 0) + quantity
	end
end
return table.freeze(Lineage)
