--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Economy = require(script.Parent.Economy)
local Rules = {}
local rates: { [string]: number } = {}
local odds: { [string]: number } = {}
local totalWeights: { [string]: number } = {}
for _, collection in Catalog.collections do
	totalWeights[collection.id] = 0
end
for _, value in
	{
		Economy.startingCoins,
		Economy.price,
		Economy.redeemCost,
		Economy.capacity,
		Economy.coinLimit,
		Economy.scrapLimit,
		Economy.expansionCost,
		Economy.themeCost,
		Economy.goalReward,
		Economy.setBonus,
	}
do
	assert(value > 0 and value < math.huge and value % 1 == 0, "Invalid economy bound")
end
local bands: { [string]: { number } } = { Common = { 1, 2 }, Uncommon = { 3, 4 }, Rare = { 6, 8 } }
for _, entry in Economy.entries do
	assert(Catalog.byId[entry.id] and not rates[entry.id], "Invalid economy reference")
	assert(
		entry.rate > 0 and entry.rate < math.huge and entry.weight > 0 and entry.weight < math.huge,
		"Invalid rate/weight"
	)
	local band = bands[Catalog.byId[entry.id].rarity]
	assert(band and entry.rate >= band[1] and entry.rate <= band[2], "Rate outside rarity band")
	rates[entry.id] = entry.rate
	local collection = Catalog.byId[entry.id].collection
	totalWeights[collection] += entry.weight
end
for _, totalWeight in totalWeights do
	assert(totalWeight > 0 and totalWeight < math.huge, "Invalid collection weight total")
end
for _, entry in Economy.entries do
	odds[entry.id] = entry.weight / totalWeights[Catalog.byId[entry.id].collection] * 100
end
for _, figure in Catalog.figures do
	assert(rates[figure.id], "Missing rate")
end
Rules.rates = rates
Rules.odds = odds
function Rules.new(now: number): Types.State
	return {
		schemaVersion = 2,
		unlocked = 3,
		theme = "grove",
		themes = { grove = true },
		lastDailyDay = -1,
		goalDay = -1,
		goalProgress = 0,
		goalClaimed = false,
		coins = Economy.startingCoins,
		scrap = 0,
		owned = {},
		discovered = {},
		slots = { "", "", "" },
		revision = 0,
		fraction = 0,
		time = now,
		step = 1,
	}
end
function Rules.bonus(state: Types.State): number
	local distinct: { [string]: boolean } = {}
	local counts: { [string]: number } = {}
	for _, id in state.slots do
		if id ~= "" and not distinct[id] then
			distinct[id] = true
			local collection = Catalog.byId[id].collection
			counts[collection] = (counts[collection] or 0) + 1
		end
	end
	for _, count in counts do
		if count >= 3 then
			return Economy.setBonus
		end
	end
	return 0
end
function Rules.refreshDay(state: Types.State, day: number)
	if day > state.goalDay then
		state.goalDay = day
		state.goalProgress = 0
		state.goalClaimed = false
	end
	local unique: { [string]: boolean } = {}
	local count = 0
	for _, id in state.slots do
		if id ~= "" and not unique[id] then
			unique[id] = true
			count += 1
		end
	end
	state.goalProgress = math.max(state.goalProgress, math.min(3, count))
end
function Rules.rate(state: Types.State): number
	local rate = 0
	for _, id in state.slots do
		rate += rates[id] or 0
	end
	return rate + Rules.bonus(state)
end
function Rules.settle(state: Types.State, now: number)
	local elapsed = math.max(0, now - state.time)
	state.time = math.max(state.time, now)
	local earned = state.fraction + elapsed * Rules.rate(state)
	local whole = math.floor(earned)
	state.coins = math.min(Economy.coinLimit, state.coins + whole)
	state.fraction = if state.coins == Economy.coinLimit then 0 else earned - whole
	if state.step == 3 and state.coins >= Economy.price then
		state.step = 4
	end
end
function Rules.available(state: Types.State, id: string): number
	local count = state.owned[id] or 0
	for _, placed in state.slots do
		if placed == id then
			count -= 1
		end
	end
	return count
end
function Rules.roll(value: number, collection: string?): string
	assert(value >= 0 and value < 1, "Roll must be in [0, 1)")
	local choice = collection or "grove"
	assert(totalWeights[choice], "Unknown collection")
	local cursor = value * totalWeights[choice]
	for _, entry in Economy.entries do
		if Catalog.byId[entry.id].collection == choice then
			cursor -= entry.weight
			if cursor < 0 then
				return entry.id
			end
		end
	end
	error("Invalid roll weights")
end
function Rules.mutate(
	state: Types.State,
	intent: Types.Intent,
	roll: number,
	day: number?
): (boolean, string, string?)
	local action, id = intent.action, intent.figure or ""
	local today = day or 0
	Rules.refreshDay(state, today)
	if action == "Buy" or action == "Redeem" or action == "Daily" then
		local count = 0
		for _, quantity in state.owned do
			count += quantity
		end
		if count >= Economy.capacity then
			return false,
				string.format("Inventory full (%d). Recycle an extra copy.", Economy.capacity),
				nil
		end
		if action == "Buy" or action == "Daily" then
			if intent.choice and not totalWeights[intent.choice] then
				return false, "Unknown collection.", nil
			end
			if action == "Daily" and state.lastDailyDay >= today then
				return false, "Come back after the next daily reset.", nil
			end
			if action == "Buy" and state.coins < Economy.price then
				return false, "Not enough Coins yet.", nil
			end
			id = Rules.roll(roll, intent.choice)
			if action == "Buy" then
				state.coins -= Economy.price
			else
				state.lastDailyDay = today
			end
		else
			if not rates[id] then
				return false, "Unknown figure.", nil
			end
			if state.scrap < Economy.redeemCost then
				return false, string.format("You need %d Scrap.", Economy.redeemCost), nil
			end
			state.scrap -= Economy.redeemCost
		end
		local isNew = not state.discovered[id]
		state.owned[id] = (state.owned[id] or 0) + 1
		state.discovered[id] = true
		if state.step == 1 then
			state.step = 2
		elseif state.step == 4 and action == "Buy" then
			state.step = 5
		end
		state.revision += 1
		return true, if isNew then "New discovery!" else "Another copy for your collection!", id
	elseif action == "Expand" then
		if state.unlocked >= 4 then
			return false, "Your showroom is fully expanded.", nil
		end
		if state.coins < Economy.expansionCost then
			return false,
				string.format("You need %d Coins for a fourth slot.", Economy.expansionCost),
				nil
		end
		state.coins -= Economy.expansionCost
		state.unlocked = 4
		state.slots[4] = ""
	elseif action == "Theme" then
		local theme = intent.choice or ""
		if not Catalog.themes[theme] then
			return false, "Unknown room palette.", nil
		end
		if state.theme == theme then
			return false, "That palette is already equipped.", nil
		end
		if not state.themes[theme] then
			if state.coins < Economy.themeCost then
				return false,
					string.format("You need %d Coins for this palette.", Economy.themeCost),
					nil
			end
			state.coins -= Economy.themeCost
			state.themes[theme] = true
		end
		state.theme = theme
	elseif action == "Goal" then
		if state.goalClaimed or state.goalProgress < 3 then
			return false, "Display three distinct figures to earn today's reward.", nil
		end
		if state.coins > Economy.coinLimit - Economy.goalReward then
			return false, "Spend Coins before claiming.", nil
		end
		state.goalClaimed = true
		state.coins += Economy.goalReward
	elseif action == "Recycle" then
		if (state.owned[id] or 0) < 2 or Rules.available(state, id) < 1 then
			return false, "Keep one copy; displayed copies cannot be recycled.", nil
		end
		if state.scrap >= Economy.scrapLimit then
			return false, "Scrap safety limit reached.", nil
		end
		state.owned[id] -= 1
		state.scrap += 1
	elseif action == "Place" or action == "Remove" then
		local slot = intent.slot
		if not slot or slot % 1 ~= 0 or slot < 1 or slot > state.unlocked then
			return false, "Unknown shelf slot.", nil
		end
		if action == "Place" then
			if not rates[id] then
				return false, "Unknown figure.", nil
			end
			if state.slots[slot] == id then
				return false, "That figure is already in this slot.", nil
			end
			if Rules.available(state, id) < 1 then
				return false, "No undisplayed copy available.", nil
			end
			state.slots[slot] = id
			if state.step == 2 then
				state.step = 3
			end
		else
			if state.slots[slot] == "" then
				return false, "That slot is empty.", nil
			end
			state.slots[slot] = ""
		end
	else
		return false, "Unknown action.", nil
	end
	Rules.refreshDay(state, today)
	state.revision += 1
	return true, "Showroom updated.", nil
end
return Rules
