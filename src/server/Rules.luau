--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Economy = require(script.Parent.Economy)
local CollectionEconomy = require(script.Parent.CollectionEconomy)
local Shelves = require(script.Parent.Shelves)
local Rules = {
	rates = CollectionEconomy.rates,
	odds = CollectionEconomy.odds({}),
	prices = CollectionEconomy.prices,
	-- Numeric guard for the lifetime box counter; presentation-only (leaderboard), never a reward.
	boxesOpenedLimit = 1000000000,
}
function Rules.new(now: number): Types.State
	return {
		schemaVersion = 8,
		display = { unlocked = DisplayConfig.defaultSlots, slots = { "", "", "" } },
		shelves = Shelves.new(),
		pityByGroup = {},
		lastDailyDay = -1,
		goalDay = -1,
		goalProgress = 0,
		goalClaimed = false,
		boxesOpened = 0,
		coins = Economy.startingCoins,
		owned = {},
		discovered = {},
		revision = 0,
		earnings = {},
		time = now,
		step = 1,
	}
end
function Rules.figureRate(state: Types.State, id: string): number
	local base = Rules.rates[id]
	return if base then base * CollectionEconomy.multiplier(id, state.owned[id] or 0) else 0
end
local function subtotal(state: Types.State): number
	local rate = 0
	for _, id in state.display.slots do
		rate += Rules.figureRate(state, id)
	end
	return rate
end
function Rules.bonus(state: Types.State): number
	local distinct: { [string]: boolean } = {}
	local counts: { [string]: number } = {}
	for _, id in state.display.slots do
		if id ~= "" and not distinct[id] then
			distinct[id] = true
			local collection = Catalog.byId[id].collection
			counts[collection] = (counts[collection] or 0) + 1
		end
	end
	for _, count in counts do
		if count >= 3 then
			return subtotal(state) * Economy.setBonus
		end
	end
	return 0
end
function Rules.refreshDay(state: Types.State, day: number)
	if day > state.goalDay then
		state.goalDay, state.goalProgress, state.goalClaimed = day, 0, false
	end
	local unique: { [string]: boolean } = {}
	local count = 0
	for _, id in state.display.slots do
		if id ~= "" and not unique[id] then
			unique[id] = true
			count += 1
		end
	end
	state.goalProgress = math.max(state.goalProgress, math.min(3, count))
end
function Rules.rate(state: Types.State): number
	return subtotal(state) + Rules.bonus(state)
end
function Rules.settle(state: Types.State, now: number)
	local elapsed = math.max(0, now - state.time)
	state.time = math.max(state.time, now)
	local multiplier = if Rules.bonus(state) > 0 then 1 + Economy.setBonus else 1
	for _, id in state.display.slots do
		if id ~= "" then
			state.earnings[id] = math.min(
				Economy.coinLimit,
				(state.earnings[id] or 0) + elapsed * Rules.figureRate(state, id) * multiplier
			)
		end
	end
end
-- Server-only transfer primitive, also reusable by a future authorized auto-collect service.
function Rules.collect(state: Types.State, slot: number, id: string): (boolean, string)
	if id == "" or state.display.slots[slot] ~= id or not state.owned[id] then
		return false, "That figure is no longer displayed."
	end
	local bank = state.earnings[id] or 0
	local amount = math.min(math.floor(bank), Economy.coinLimit - state.coins)
	if amount <= 0 then
		return false,
			if state.coins == Economy.coinLimit
				then "Spend Coins before collecting."
				else "No whole Coins ready yet."
	end
	state.earnings[id] = bank - amount
	state.coins += amount
	state.revision += 1
	if state.step == 3 and state.coins >= Rules.prices[Economy.dailyCollection] then
		state.step = 4
	end
	return true, string.format("Collected %d Coins!", amount)
end
-- Available earning placement, not the quantity of spare copies.
function Rules.available(state: Types.State, id: string): number
	if (state.owned[id] or 0) == 0 or table.find(state.display.slots, id) then
		return 0
	end
	return 1
end
function Rules.roll(value: number, collection: string?, state: Types.State?): string
	return CollectionEconomy.roll(
		value,
		collection or Economy.dailyCollection,
		if state then state.pityByGroup else {}
	)
end
function Rules.expansionCost(state: Types.State): number
	return Economy.expansionCosts[state.display.unlocked + 1] or 0
end
-- Buy and Daily use the first roll; BuyTen needs ten.
function Rules.mutate(
	state: Types.State,
	intent: Types.Intent,
	roll: number | { number },
	day: number?
): (boolean, string, string?, { string }?)
	local action, id = intent.action, intent.figure or ""
	local rolls = if type(roll) == "number" then { roll } else roll
	local today = day or 0
	Rules.refreshDay(state, today)
	if action == "Collect" then
		local ok, message = Rules.collect(state, intent.slot or 0, id)
		return ok, message, if ok then id else nil
	elseif action == "Buy" or action == "Daily" or action == "BuyTen" then
		local count = if action == "BuyTen" then 10 else 1
		local collection = intent.choice or Economy.dailyCollection
		local price = Rules.prices[collection]
		if not price then
			return false, "Unknown collection.", nil
		end
		if action == "Daily" then
			if collection ~= Economy.dailyCollection then
				return false, "Your daily free box is a Starter box.", nil
			end
			if state.lastDailyDay >= today then
				return false, "Come back after the next daily reset.", nil
			end
		elseif state.coins < price * count then
			return false, "Not enough Coins yet.", nil
		end
		if #rolls < count then
			return false, "Try again.", nil
		end
		-- Validate the whole pool for every box before rolling. Safety limits never reroll a result.
		for _, figure in Catalog.figures do
			if
				figure.collection == collection
				and (state.owned[figure.id] or 0) > Economy.copyLimit - count
			then
				return false, "Collection quantity safety limit reached.", nil
			end
		end
		-- All checks are above and nothing below can fail, so a multi-box grant is all-or-nothing.
		local figures: { string } = {}
		local fresh = 0
		for index = 1, count do
			id = Rules.roll(rolls[index], collection, state)
			if not state.discovered[id] then
				fresh += 1
			end
			state.owned[id] = (state.owned[id] or 0) + 1
			state.discovered[id] = true
			CollectionEconomy.advance(state.pityByGroup, collection, id)
			figures[index] = id
		end
		if action == "Daily" then
			state.lastDailyDay = today
		else
			state.coins -= price * count
		end
		-- Counted in the same atomic grant as the box's figures.
		state.boxesOpened = math.min(Rules.boxesOpenedLimit, state.boxesOpened + count)
		if state.step == 1 then
			state.step = 2
		elseif state.step == 4 and action ~= "Daily" then
			state.step = 5
		end
		state.revision += 1
		if count > 1 then
			return true,
				if fresh > 0
					then string.format(
						"%d new discover%s!",
						fresh,
						if fresh == 1 then "y" else "ies"
					)
					else "Duplicate bonuses increased!",
				nil,
				figures
		end
		return true, if fresh > 0 then "New discovery!" else "Duplicate bonus increased!", id
	elseif action == "Expand" then
		local cost = Rules.expansionCost(state)
		if cost == 0 or state.display.unlocked >= DisplayConfig.maxSlots then
			return false, "All Display slots are unlocked.", nil
		end
		if state.coins < cost then
			return false, string.format("You need %d Coins for the next slot.", cost), nil
		end
		state.coins -= cost
		state.display.unlocked += 1
		state.display.slots[state.display.unlocked] = ""
	elseif action == "Goal" then
		if state.goalClaimed or state.goalProgress < 3 then
			return false, "Display three distinct figures to earn today's reward.", nil
		end
		if state.coins > Economy.coinLimit - Economy.goalReward then
			return false, "Spend Coins before claiming.", nil
		end
		state.goalClaimed = true
		state.coins += Economy.goalReward
	elseif action == "Place" or action == "Remove" then
		local slot = intent.slot
		if
			not slot
			or slot % 1 ~= 0
			or slot < 1
			or slot > state.display.unlocked
			or slot > DisplayConfig.maxSlots
		then
			return false, "Unknown or locked Display slot.", nil
		end
		if action == "Place" then
			if not Rules.rates[id] then
				return false, "Unknown figure.", nil
			end
			if Rules.available(state, id) == 0 then
				return false, "Own this figure and display it only once.", nil
			end
			state.display.slots[slot] = id
			if state.step == 2 then
				state.step = 3
			end
		else
			if state.display.slots[slot] == "" then
				return false, "That slot is empty.", nil
			end
			state.display.slots[slot] = ""
		end
	else
		return false, "Unknown action.", nil
	end
	Rules.refreshDay(state, today)
	state.revision += 1
	return true, "Display updated.", nil
end
return Rules
