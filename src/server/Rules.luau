--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local ShelfConfig = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local LoginRewards = require(game:GetService("ReplicatedStorage").Shared.LoginRewards)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Tutorial = require(game:GetService("ReplicatedStorage").Shared.Tutorial)
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
		schemaVersion = 13,
		display = { unlocked = DisplayConfig.defaultSlots, slots = { "", "", "" } },
		shelves = Shelves.new(),
		pityByGroup = {},
		lastDailyDay = -1,
		lastLoginDay = -1,
		loginStreak = 0,
		goalDay = -1,
		goalProgress = 0,
		goalClaimed = false,
		boxesOpened = 0,
		shelfRewards = {},
		lastSeen = 0,
		offlinePending = 0,
		offlineSeconds = 0,
		sfxVolume = 100,
		musicVolume = 100,
		coins = Economy.startingCoins,
		owned = {},
		discovered = {},
		revision = 0,
		earnings = {},
		time = now,
		step = Tutorial.welcome,
		tutorialHidden = false,
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
-- Server-only bank transfer; callers validate authorization and own revision/quest updates.
local function transferBank(state: Types.State, id: string): number
	local bank = state.earnings[id] or 0
	local amount = math.min(math.floor(bank), Economy.coinLimit - state.coins)
	if amount > 0 then
		state.earnings[id] = bank - amount
		state.coins += amount
	end
	return amount
end
function Rules.collect(state: Types.State, slot: number, id: string): (boolean, string)
	if id == "" or state.display.slots[slot] ~= id or not state.owned[id] then
		return false, "That figure is no longer displayed."
	end
	local amount = transferBank(state, id)
	if amount <= 0 then
		return false,
			if state.coins == Economy.coinLimit
				then "Spend Coins before collecting."
				else "No whole Coins ready yet."
	end
	state.revision += 1
	-- Only a real Display collection teaches this step; other Coin rewards never advance it.
	if state.step == Tutorial.collect then
		state.step = Tutorial.buy
	end
	return true, string.format("Collected %d Coins!", amount)
end
-- Moves pending offline Coins to the wallet; anything past the Coin limit is dropped.
function Rules.claimOffline(state: Types.State): number
	local amount = math.min(state.offlinePending, Economy.coinLimit - state.coins)
	state.coins += amount
	state.offlinePending, state.offlineSeconds = 0, 0
	return amount
end
-- On join (wall = UTC os.time()): auto-claim what the previous visit left unclaimed, then award
-- this absence at the saved Display's rate. Nothing changes a Display while its owner is away.
function Rules.offline(state: Types.State, wall: number)
	Rules.claimOffline(state)
	local away = math.min(wall - state.lastSeen, Economy.offlineMaxSeconds)
	-- Unknown last save (0) or a clock behind it awards nothing.
	if state.lastSeen > 0 and away >= Economy.offlineMinSeconds then
		state.offlinePending =
			math.floor(math.min(Economy.coinLimit, away * Rules.rate(state) * Economy.offlineRate))
		state.offlineSeconds = if state.offlinePending > 0 then away else 0
	end
	state.lastSeen = wall
end
-- Available earning placement, not the quantity of spare copies.
function Rules.available(state: Types.State, id: string): number
	if (state.owned[id] or 0) == 0 or table.find(state.display.slots, id) then
		return 0
	end
	return 1
end
function Rules.roll(
	value: number,
	collection: string?,
	state: Types.State?,
	minimum: Rarity.Id?
): string
	return CollectionEconomy.roll(
		value,
		collection or Economy.dailyCollection,
		if state then state.pityByGroup else {},
		minimum
	)
end
function Rules.expansionCost(state: Types.State): number
	return Economy.expansionCosts[state.display.unlocked + 1] or 0
end
function Rules.shelfPrice(state: Types.State): number
	local units = #state.shelves.units
	if units >= ShelfConfig.maxShelfUnits then
		return 0
	end
	local free = 0
	for _ in state.shelfRewards do
		free += 1
	end
	local bought = math.max(0, units - ShelfConfig.startingShelfUnits - free)
	return math.floor(Economy.shelfPrice * Economy.shelfGrowth ^ bought)
end
-- First completion (every figure discovered) of each collection grants one free Shelf Unit.
function Rules.grantShelves(state: Types.State): number
	local granted = 0
	for _, collection in Catalog.collections do
		if not state.shelfRewards[collection.id] then
			local complete = true
			for _, figure in Catalog.figures do
				if figure.collection == collection.id and not state.discovered[figure.id] then
					complete = false
					break
				end
			end
			if complete and Shelves.add(state.shelves) then
				state.shelfRewards[collection.id] = true
				granted += 1
			end
		end
	end
	return granted
end
-- Streak a claim on `day` belongs to: the current streak once claimed today, the next one
-- after a claim yesterday, otherwise Day 1 again.
function Rules.loginStreak(state: Types.State, day: number): number
	if state.lastLoginDay >= day then
		return state.loginStreak
	end
	return if state.lastLoginDay == day - 1 then state.loginStreak + 1 else 1
end
-- Every check that can refuse opening `count` boxes; run before any mutation.
local function canOpen(
	state: Types.State,
	collection: string,
	count: number,
	rolls: { number }
): (boolean, string)
	if #rolls < count then
		return false, "Try again."
	end
	-- Validate the whole pool for every box before rolling. Safety limits never reroll a result.
	for _, figure in Catalog.figures do
		if
			figure.collection == collection
			and (state.owned[figure.id] or 0) > Economy.copyLimit - count
		then
			return false, "Collection quantity safety limit reached."
		end
	end
	return true, ""
end
-- Cannot fail once canOpen passed, so a multi-box grant is all-or-nothing. With `floor`, the
-- last box is rolled at that minimum rarity only when no earlier box reached it.
local function open(
	state: Types.State,
	collection: string,
	count: number,
	rolls: { number },
	floor: Rarity.Id?
): ({ string }, number)
	local figures: { string } = {}
	local fresh = 0
	local rank = if floor then table.find(Rarity.order, floor) or 1 else 1
	local reached = floor == nil
	for index = 1, count do
		local id = Rules.roll(
			rolls[index],
			collection,
			state,
			if index == count and not reached then floor else nil
		)
		reached = reached or (table.find(Rarity.order, Catalog.byId[id].rarity) or 0) >= rank
		if not state.discovered[id] then
			fresh += 1
		end
		state.owned[id] = (state.owned[id] or 0) + 1
		state.discovered[id] = true
		CollectionEconomy.advance(state.pityByGroup, collection, id)
		figures[index] = id
	end
	-- Counted in the same atomic grant as the box's figures.
	state.boxesOpened = math.min(Rules.boxesOpenedLimit, state.boxesOpened + count)
	Rules.grantShelves(state)
	return figures, fresh
end
-- Buy, Daily and one-box Login days use the first roll; BuyTen needs ten.
function Rules.mutate(
	state: Types.State,
	intent: Types.Intent,
	roll: number | { number },
	day: number?,
	now: number?
): (boolean, string, string?, { string }?)
	local action, id = intent.action, intent.figure or ""
	local rolls = if type(roll) == "number" then { roll } else roll
	local today = day or 0
	-- Place must pass every check before settlement or any gameplay mutation.
	if action ~= "Place" then
		Rules.refreshDay(state, today)
	end
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
		local allowed, refusal = canOpen(state, collection, count, rolls)
		if not allowed then
			return false, refusal, nil
		end
		local figures, fresh = open(state, collection, count, rolls)
		id = figures[1]
		if action == "Daily" then
			state.lastDailyDay = today
		else
			state.coins -= price * count
		end
		-- Spending Coins on a box is the last Welcome Quest action; it unlocks the free x10.
		if state.step == Tutorial.buy and action ~= "Daily" then
			state.step = Tutorial.reward
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
	elseif action == "Login" then
		-- `>=` also refuses while the server clock reads earlier than the last claim.
		if state.lastLoginDay >= today then
			return false, "Come back after the next daily reset.", nil
		end
		local streak = Rules.loginStreak(state, today)
		local reward = LoginRewards.reward(streak)
		if state.coins > Economy.coinLimit - reward.coins then
			return false, "Spend Coins before claiming.", nil
		end
		local boxes = reward.boxes
		local figures: { string } = {}
		if boxes then
			local allowed, refusal = canOpen(state, boxes.collection, boxes.count, rolls)
			if not allowed then
				return false, refusal, nil
			end
			figures = open(state, boxes.collection, boxes.count, rolls)
		end
		state.coins += reward.coins
		state.lastLoginDay, state.loginStreak = today, streak
		state.revision += 1
		local message = string.format("Day %d reward claimed!", LoginRewards.day(streak))
		if #figures > 1 then
			return true, message, nil, figures
		end
		return true, message, figures[1]
	elseif action == "Welcome" or action == "WelcomeTen" then
		-- One-time rewards: the saved stage is both the claim marker and the grant.
		local ten = action == "WelcomeTen"
		if state.step ~= (if ten then Tutorial.reward else Tutorial.welcome) then
			return false,
				if ten then "Finish the Welcome Quest first." else "Welcome Box already opened.",
				nil
		end
		local welcome = Economy.welcome
		local count = if ten then 10 else 1
		local allowed, refusal = canOpen(state, welcome.collection, count, rolls)
		if not allowed then
			return false, refusal, nil
		end
		local figures = open(
			state,
			welcome.collection,
			count,
			rolls,
			(if ten then welcome.ten else welcome.box) :: Rarity.Id
		)
		state.step = if ten then Tutorial.shelves else Tutorial.display
		state.revision += 1
		if ten then
			return true, "Welcome x10 opened!", nil, figures
		end
		return true, "Welcome Box opened!", figures[1]
	elseif action == "SkipTutorial" then
		if state.tutorialHidden or state.step >= Tutorial.done then
			return false, "Nothing to skip.", nil
		end
		state.tutorialHidden = true
		state.revision += 1
		return true, "Tutorial skipped.", nil
	elseif action == "ClaimOffline" then
		if state.offlinePending <= 0 then
			return false, "No offline Coins to claim.", nil
		end
		local amount = Rules.claimOffline(state)
		state.revision += 1
		return true, string.format("Claimed %d offline Coins!", amount), nil
	elseif action == "SetVolume" then
		-- Presentation preference only; Protocol already bounded choice and volume.
		if intent.choice == "music" then
			state.musicVolume = intent.volume or state.musicVolume
		else
			state.sfxVolume = intent.volume or state.sfxVolume
		end
		state.revision += 1
		return true, "Settings saved.", nil
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
	elseif action == "BuyShelf" then
		local price = Rules.shelfPrice(state)
		if price == 0 then
			return false, "Max shelves reached.", nil
		end
		if state.coins < price then
			return false, "Not enough Coins yet.", nil
		end
		state.coins -= price
		Shelves.add(state.shelves)
		state.revision += 1
		return true, "New Shelf unlocked!", nil
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
			Rules.refreshDay(state, today)
			Rules.settle(state, now or state.time)
			local outgoing = state.display.slots[slot]
			if outgoing ~= "" then
				-- Collect under the old loadout; overflow/fractions stay recoverable by ID.
				-- This is part of Place, not a genuine Welcome Quest collection.
				transferBank(state, outgoing)
			end
			state.display.slots[slot] = id
			if state.step == Tutorial.display then
				state.step = Tutorial.collect
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
