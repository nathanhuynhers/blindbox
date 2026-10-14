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
local Deals = require(script.Parent.Deals)
local CoinModifiers = require(script.Parent.CoinModifiers)
local Boosts = require(script.Parent.Boosts)
local PackageGrants = require(script.Parent.PackageGrants)
local OfflineAwards = require(script.Parent.OfflineAwards)
local OfflineCredits = require(script.Parent.OfflineCredits)
local LuckModifiers = require(script.Parent.LuckModifiers)
local BoostTypes = require(game:GetService("ReplicatedStorage").Shared.BoostTypes)
local Lineage = require(script.Parent.PaidLineage)
local Rules = {
	rates = CollectionEconomy.rates,
	odds = CollectionEconomy.odds({}),
	prices = CollectionEconomy.prices,
	-- Numeric guard for the lifetime box counter; presentation-only (leaderboard), never a reward.
	boxesOpenedLimit = 1000000000,
}
function Rules.new(now: number): Types.State
	return {
		schemaVersion = 14,
		earningFactors = CoinModifiers.free(),
		convenience = { autoCollect = false, movement = false },
		boosts = Boosts.empty(),
		luckModifiers = LuckModifiers.free(),
		paidBoostsAllowed = false,
		vipOwned = false,
		vipAllowed = false,
		boostClockValid = false,
		boostCommitPending = false,
		offlineCommitPending = false,
		boostWall = 0,
		boostTime = now,
		coinModifiers = {
			verifiedTier = 1,
			appliedTier = 1,
			ownershipFresh = false,
			reason = "ValidationPending",
		},
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
		deals = { window = -1, bought = table.create(Economy.deals.stalls, 0) },
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
	return Rules.baseRate(state) * CoinModifiers.factor(Rules.earningFactors(state), "Display")
end
function Rules.baseRate(state: Types.State): number
	return subtotal(state) + Rules.bonus(state)
end
function Rules.settle(state: Types.State, now: number)
	local elapsed = math.max(0, now - state.time)
	local first = state.boostWall + math.max(0, state.time - state.boostTime)
	state.time = math.max(state.time, now)
	local earnedRates = Lineage.earnedRates(state)
	local inputs = table.clone(state.earningFactors)
	inputs.timedCoinFactor = 1
	local eligible = state.paidBoostsAllowed
		and state.boostClockValid
		and not state.boostCommitPending
	local weighted = elapsed
		+ (if eligible then Boosts.overlap(state.boosts.coin, first, first + elapsed) else 0)
	local multiplier = (if Rules.bonus(state) > 0 then 1 + Economy.setBonus else 1)
		* CoinModifiers.factor(inputs, "Display")
	for _, id in state.display.slots do
		if id ~= "" then
			local oldBank = state.earnings[id] or 0
			state.earnings[id] = math.min(
				Economy.coinLimit,
				oldBank + weighted * Rules.figureRate(state, id) * multiplier
			)
			Lineage.recordAccrual(
				state,
				id,
				oldBank,
				state.earnings[id],
				elapsed * (earnedRates[id] or 0)
			)
		end
	end
end
function Rules.boostNow(state: Types.State): number
	return state.boostWall + math.max(0, state.time - state.boostTime)
end
function Rules.earningFactors(state: Types.State): Types.EarningFactors
	local inputs = table.clone(state.earningFactors)
	inputs.timedCoinFactor = if state.paidBoostsAllowed
			and state.boostClockValid
			and not state.boostCommitPending
		then Boosts.active(state.boosts.coin, Rules.boostNow(state))
		else 1
	return inputs
end
function Rules.luck(state: Types.State): number
	if not state.paidBoostsAllowed or not state.boostClockValid or state.boostCommitPending then
		return 1
	end
	return math.max(
		state.luckModifiers.permanent,
		Boosts.active(state.boosts.luck, Rules.boostNow(state))
	)
end
function Rules.boostView(state: Types.State): BoostTypes.View
	local wall = Rules.boostNow(state)
	local coin, luck = state.boosts.coin, state.boosts.luck
	return {
		tokens = table.clone(state.boosts.tokens),
		coin = if coin then table.clone(coin) else nil,
		luck = if luck then table.clone(luck) else nil,
		coinRemaining = if coin then math.max(0, coin.expires - wall) else 0,
		activationReasons = Boosts.activationReasons(
			state.boosts,
			math.floor(wall),
			state.luckModifiers.verifiedPermanent
		),
		luckRemaining = if luck then math.max(0, luck.expires - wall) else 0,
		coinFactor = Rules.earningFactors(state).timedCoinFactor,
		luckWeight = Rules.luck(state),
		clockValid = state.boostClockValid,
		paidAllowed = state.paidBoostsAllowed,
		redundantLuck = state.luckModifiers.verifiedPermanent >= 2
			and Boosts.active(luck, wall) == 2,
	}
end
-- Server UTC observation. Rollback suppresses paid effects before any unscheduled settlement;
-- projected wall time never decreases, and no token gets extra duration from a clock reversal.
function Rules.syncBoosts(
	state: Types.State,
	view: BoostTypes.LuckView,
	allowed: boolean,
	wall: number,
	now: number
): boolean
	local previousValid = state.boostClockValid
	local valid = wall > 0
		and wall <= 100000000000
		and wall % 1 == 0
		and wall >= state.boosts.lastClock
	if not valid then
		state.boostClockValid = false
	end
	Rules.settle(state, now)
	local projected = Rules.boostNow(state)
	local changed = state.paidBoostsAllowed ~= allowed
		or state.luckModifiers.permanent ~= view.permanent
		or state.luckModifiers.verifiedPermanent ~= view.verifiedPermanent
		or previousValid ~= valid
	state.boostClockValid = valid
	state.paidBoostsAllowed = allowed
	state.luckModifiers = table.clone(view)
	if valid then
		state.boostWall = math.max(projected, wall)
		state.boostTime = state.time
		if state.schemaVersion >= 16 then
			state.boosts.lastClock = math.max(state.boosts.lastClock, math.floor(state.boostWall))
		end
	end
	if changed then
		state.revision += 1
	end
	return changed
end
-- Non-yielding server boundary. P02 verification must complete before calling this;
-- lifecycle/policy checks belong to the caller. Banks are settled using the OLD inputs.
function Rules.setCoinModifiers(
	state: Types.State,
	view: Types.CoinModifierView,
	now: number
): boolean
	assert(
		CoinModifiers.validTier(view.appliedTier)
			and CoinModifiers.validTier(view.verifiedTier)
			and view.appliedTier <= view.verifiedTier,
		"Invalid Coin tier"
	)
	local changed = state.earningFactors.permanentTier ~= view.appliedTier
	if changed then
		Rules.settle(state, now)
		state.earningFactors.permanentTier = view.appliedTier
		if view.appliedTier > 1 then
			state.schemaVersion = math.max(state.schemaVersion, 15)
		end
		state.revision += 1
	end
	state.coinModifiers = table.clone(view)
	return changed
end
-- Verified VIP applies once. Settle the old rate before any ownership/policy change.
function Rules.setVip(state: Types.State, owned: boolean, allowed: boolean, now: number): boolean
	local applied = owned and allowed
	local factor = if applied then 1.1 else 1
	local changed = state.vipOwned ~= owned or state.vipAllowed ~= applied
	if changed then
		Rules.settle(state, now)
		state.vipOwned, state.vipAllowed = owned, applied
		state.earningFactors.vipFactor = factor
		if applied then
			state.schemaVersion = math.max(16, state.schemaVersion)
		end
		state.revision += 1
	end
	return changed
end
-- P05's validated owner adapter owns readiness/entitlement checks. Preferences alone grant nothing.
function Rules.setConveniencePreference(state: Types.State, key: string, enabled: boolean): boolean
	if key == "auto_collect" then
		if state.convenience.autoCollect == enabled then
			return true
		end
		state.convenience.autoCollect = enabled
	elseif key == "movement" then
		if state.convenience.movement == enabled then
			return true
		end
		state.convenience.movement = enabled
	else
		return false
	end
	state.schemaVersion = math.max(state.schemaVersion, 15)
	state.revision += 1
	return true
end
-- Server-only bank transfer; callers validate authorization and own revision/quest updates.
local function transferBank(state: Types.State, id: string): number
	return Lineage.transferBank(state, id)
end
-- P05 receives this server-only helper; it validates occupied/unlocked ownership, serializes
-- after settlement and owns one revision. It must never call Rules.collect to skip the lesson.
Rules.transferBank = transferBank
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
-- Modern awards retain overflow/source labels and reservation claim status.
-- Legacy pending keeps the existing free claim/cap behavior until its join calculation.
function Rules.claimOffline(state: Types.State): number
	if state.offlineData then
		OfflineCredits.markBaseClaimed(
			state,
			if state.offlineData.current then state.offlineData.current.id else nil
		)
		return OfflineAwards.claim(state)
	end
	local amount = math.min(state.offlinePending, Economy.coinLimit - state.coins)
	Lineage.creditEarned(state, amount)
	state.offlinePending, state.offlineSeconds = 0, 0
	return amount
end
-- On join (wall = UTC os.time()): auto-claim what the previous visit left unclaimed, then award
-- this absence at the saved Display's rate. Nothing changes a Display while its owner is away.
function Rules.offline(state: Types.State, wall: number, paidEffectsAllowed: boolean?)
	Rules.claimOffline(state)
	local validWall = wall > 0 and wall <= 100000000000 and wall % 1 == 0
	local away = if validWall then math.min(wall - state.lastSeen, Economy.offlineMaxSeconds) else 0
	-- Unknown last save (0) or a clock behind it awards nothing.
	if
		state.lastSeen > 0
		and away >= Economy.offlineMinSeconds
		and wall >= state.boosts.lastClock
	then
		local inputs = CoinModifiers.free()
		local overlap = 0
		if paidEffectsAllowed == true and state.earningInputs then
			inputs.permanentTier = state.earningInputs.permanentTier
			inputs.vipFactor = state.earningInputs.vipFactor or 1
			overlap =
				Boosts.overlap(state.earningInputs.timedCoin, state.lastSeen, state.lastSeen + away)
		end
		-- One final floor. P04 must integrate approved timer overlap over this capped interval
		-- before rounding, not substitute the timer's current/join-time factor.
		state.offlinePending = math.floor(
			math.min(
				Economy.coinLimit,
				(away + overlap)
					* Rules.baseRate(state)
					* CoinModifiers.factor(inputs, "OfflineDisplay")
					* Economy.offlineRate
			)
		)
		state.offlineSeconds = if state.offlinePending > 0 then away else 0
	end
	-- P04 computed and floored N above. Never rerun its formula when claiming/doubling.
	if state.offlinePending > 0 or state.offlineData then
		local earned = 0
		for _, rate in Lineage.earnedRates(state) do
			earned += rate
		end
		local assisted = if state.lineage
			then state.offlinePending - math.min(
				state.offlinePending,
				math.floor(away * earned * Economy.offlineRate)
			)
			else 0
		OfflineAwards.freeze(state, "display-boost-overlap-v1", assisted)
		state.schemaVersion = math.max(17, state.schemaVersion)
	end
	if validWall then
		state.lastSeen = if state.schemaVersion >= 16
			then math.max(state.lastSeen, wall, state.boosts.lastClock)
			else wall
	end
	-- Lease acquisition re-encodes before this calculation. Preserve its saved checkpoint
	-- until now; subsequent live saves checkpoint current verified/applied inputs instead.
	state.earningInputs = nil
	-- Restored active timers continue in UTC; ownership/policy must be reconciled separately.
	state.boostWall = math.max(if validWall then wall else state.lastSeen, state.boosts.lastClock)
	state.boostTime = state.time
	state.boostClockValid = validWall and wall >= state.boosts.lastClock
end
-- Highest-income loadout for the unlocked slots and its Rules.rate. Income is the subtotal,
-- times (1 + setBonus) once any collection shows three distinct figures, so an optimum is either
-- the top figures overall or, for one collection, its top three plus the best of the rest
-- (exchange argument; tests check it against brute force). Ties keep rate, then catalog order.
function Rules.best(state: Types.State): ({ string }, number)
	local count = math.min(state.display.unlocked, DisplayConfig.maxSlots)
	local ranked: { string } = {}
	local order: { [string]: number } = {}
	local rate: { [string]: number } = {}
	for index, figure in Catalog.figures do
		if (state.owned[figure.id] or 0) > 0 and Rules.rates[figure.id] then
			table.insert(ranked, figure.id)
			order[figure.id], rate[figure.id] = index, Rules.figureRate(state, figure.id)
		end
	end
	table.sort(ranked, function(a, b)
		if rate[a] ~= rate[b] then
			return rate[a] > rate[b]
		end
		return order[a] < order[b]
	end)
	local function fill(picked: { string }): { string }
		for _, id in ranked do
			if #picked >= count then
				break
			end
			if not table.find(picked, id) then
				table.insert(picked, id)
			end
		end
		return picked
	end
	local candidates = { fill({}) }
	if count >= 3 then
		for _, collection in Catalog.collections do
			local trio: { string } = {}
			for _, id in ranked do
				if #trio < 3 and Catalog.byId[id].collection == collection.id then
					table.insert(trio, id)
				end
			end
			if #trio == 3 then
				table.insert(candidates, fill(trio))
			end
		end
	end
	local saved = state.display.slots
	local best, total = candidates[1], -1
	for _, candidate in candidates do
		state.display.slots = candidate
		local income = Rules.rate(state)
		-- Relative tolerance: equal sets summed in another order are not an improvement.
		if income > total * (1 + 1e-9) then
			best, total = candidate, income
		end
	end
	state.display.slots = saved
	return best, total
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
		minimum,
		nil,
		if state then Rules.luck(state) else 1
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
-- Shared by normal openings and administrative grants. Callers preflight the whole batch.
function Rules.grantFigure(state: Types.State, id: string, quantity: number, assisted: boolean?)
	Lineage.grantFigure(state, id, quantity, assisted == true)
end
-- Server callers supply validated integers. Reject before settling, never clamp an admin request.
function Rules.adminCoins(
	state: Types.State,
	mode: string,
	amount: number,
	now: number
): (boolean, string)
	local balance = if mode == "GrantCoins"
		then state.coins + amount
		elseif mode == "RemoveCoins" then state.coins - amount
		else amount
	if balance < 0 or balance > Economy.coinLimit then
		return false, "Balance would exceed wallet bounds."
	end
	Rules.settle(state, now)
	if state.lineage then
		state.lineage.earnedCoins = if balance >= state.coins
			then state.lineage.earnedCoins + balance - state.coins
			else math.min(state.lineage.earnedCoins, balance)
	end
	state.coins = balance
	state.revision += 1
	return true, "Coin balance updated."
end
function Rules.adminFigures(
	state: Types.State,
	ids: { string },
	quantity: number,
	remove: boolean,
	now: number
): (boolean, string)
	local banks = 0
	local elapsed = math.max(0, now - state.time)
	local bonus = (if Rules.bonus(state) > 0 then 1 + Economy.setBonus else 1)
		* CoinModifiers.factor(state.earningFactors, "Display")
	for _, id in ids do
		local owned = state.owned[id] or 0
		if
			not Catalog.byId[id]
			or (remove and owned < quantity)
			or (not remove and owned > Economy.copyLimit - quantity)
		then
			return false, "Inventory quantity would exceed bounds."
		end
		if remove and owned == quantity then
			local accrued = if table.find(state.display.slots, id)
				then elapsed * Rules.figureRate(state, id) * bonus
				else 0
			banks += math.floor(math.min(Economy.coinLimit, (state.earnings[id] or 0) + accrued))
		end
	end
	if banks > Economy.coinLimit - state.coins then
		return false, "Spend Coins first so final-copy banks can be collected safely."
	end
	Rules.settle(state, now) -- settle the old duplicate rates and Display bonus first
	for _, id in ids do
		if remove then
			local remaining = (state.owned[id] or 0) - quantity
			if state.lineage then
				local earned = math.min(state.lineage.earnedOwned[id] or 0, remaining)
				if earned > 0 then
					state.lineage.earnedOwned[id] = earned
				else
					state.lineage.earnedOwned[id] = nil
				end
			end
			if remaining > 0 then
				state.owned[id] = remaining
			else
				state.owned[id] = nil
			end
			if remaining == 0 then
				transferBank(state, id)
				-- Schema requires earnings to reference owned IDs. Confirmed final-copy removal
				-- collects every whole Coin and forfeits only the sub-Coin remainder.
				state.earnings[id] = nil
				if state.lineage then
					state.lineage.earnedBanks[id] = nil
				end
				for slot, placed in state.display.slots do
					if placed == id then
						state.display.slots[slot] = ""
					end
				end
			end
		else
			Rules.grantFigure(state, id, quantity)
		end
	end
	-- Permanent discoveries, Shelf rewards, goal high-water marks and earnings are retained.
	Shelves.reconcile(state.shelves, state.owned, state.discovered)
	if state.shelves.legacyOverflow then
		for _, entry in state.shelves.legacyOverflow do
			for slot, id in entry.placements do
				if not state.owned[id] then
					entry.placements[slot] = nil
				end
			end
		end
	end
	Rules.grantShelves(state)
	state.revision += 1
	return true, if remove then "Figures removed; placements reconciled." else "Figures granted."
end
-- Coming-soon collections were briefly sold by mistake. Each box gave exactly one copy, so every
-- owned copy refunds one box price; copies, discoveries and pity for the collection are removed.
-- Idempotent (nothing is left to refund afterwards), and inert once a collection is released.
function Rules.refundComingSoon(state: Types.State, now: number): number
	local refund = 0
	local earnedRefund = 0
	for _, figure in Catalog.figures do
		local copies = state.owned[figure.id]
		if copies and Catalog.comingSoon[figure.collection] then
			local earnedCopies = if state.lineage
				then state.lineage.earnedOwned[figure.id] or 0
				else copies
			if Rules.adminFigures(state, { figure.id }, copies, true, now) then
				refund += copies * Rules.prices[figure.collection]
				earnedRefund += earnedCopies * Rules.prices[figure.collection]
				state.discovered[figure.id] = nil
			end
		end
	end
	for id, soon in Catalog.comingSoon do
		local config = Economy.collections[id]
		if soon and config then
			state.pityByGroup[config.group] = nil
		end
	end
	-- Refunds retain the removed copies' source, including migrated earned-only profiles.
	local earned = math.min(earnedRefund, Economy.coinLimit - state.coins)
	Lineage.creditEarned(state, earned)
	local assistedRoom = if state.lineage
		then Lineage.creditLimit
			- state.lineage.assistedReserve
			- (state.coins - state.lineage.earnedCoins)
		else Economy.coinLimit - state.coins
	state.coins += math.min(refund - earnedRefund, Economy.coinLimit - state.coins, assistedRoom)
	return refund
end
function Rules.adminPity(
	state: Types.State,
	collection: string,
	rarity: string,
	amount: number
): (boolean, string)
	local config = Economy.collections[collection]
	if not config or not config.pity then
		return false, "This box has no pity counters."
	end
	if rarity ~= "Legendary" and rarity ~= "Mythical" then
		return false, "Unknown pity counter."
	end
	if amount < 0 or amount > Economy.counterLimit or amount % 1 ~= 0 then
		return false, "Invalid pity progress."
	end
	local pity: Types.Pity = state.pityByGroup[config.group]
		or { legendaryDryRolls = 0, mythicalDryRolls = 0 }
	if rarity == "Legendary" then
		pity.legendaryDryRolls = amount
	else
		pity.mythicalDryRolls = amount
	end
	state.pityByGroup[config.group] = pity
	state.revision += 1
	return true, "Pity counter updated."
end
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
export type RollOverride = (collection: string, value: number) -> string?
local function open(
	state: Types.State,
	collection: string,
	count: number,
	rolls: { number },
	floor: Rarity.Id?,
	override: RollOverride?,
	assisted: boolean?
): ({ string }, number)
	local figures: { string } = {}
	local fresh = 0
	local rank = if floor then table.find(Rarity.order, floor) or 1 else 1
	local reached = floor == nil
	for index = 1, count do
		local forced = if override then override(collection, rolls[index]) else nil
		local id = forced
			or Rules.roll(
				rolls[index],
				collection,
				state,
				if index == count and not reached then floor else nil
			)
		reached = reached or (table.find(Rarity.order, Catalog.byId[id].rarity) or 0) >= rank
		if not state.discovered[id] then
			fresh += 1
		end
		Rules.grantFigure(state, id, 1, assisted == true or Rules.luck(state) > 1)
		CollectionEconomy.advance(state.pityByGroup, collection, id)
		figures[index] = id
	end
	-- Counted in the same atomic grant as the box's figures.
	state.boxesOpened = math.min(Rules.boxesOpenedLimit, state.boxesOpened + count)
	Rules.grantShelves(state)
	return figures, fresh
end
-- Buy, Daily, Deal and one-box Login days use the first roll; BuyTen needs ten. `window` is the
-- current plaza deal window (Deals.window); without it every Deal is refused as stale.
function Rules.mutate(
	state: Types.State,
	intent: Types.Intent,
	roll: number | { number },
	day: number?,
	now: number?,
	window: number?,
	override: RollOverride?
): (boolean, string, string?, { string }?)
	local action, id = intent.action, intent.figure or ""
	local rolls = if type(roll) == "number" then { roll } else roll
	local today = day or 0
	-- Place and EquipBest must pass every check before settlement or any gameplay mutation.
	if action ~= "Place" and action ~= "EquipBest" then
		Rules.refreshDay(state, today)
	end
	if action == "Collect" then
		local ok, message = Rules.collect(state, intent.slot or 0, id)
		return ok, message, if ok then id else nil
	elseif action == "Buy" or action == "Daily" or action == "BuyTen" or action == "Deal" then
		local count = if action == "BuyTen" then 10 else 1
		local collection = intent.choice or Economy.dailyCollection
		local stall = intent.slot or 0
		if action == "Deal" then
			-- The server re-derives this window's offer and price; the client named only the stall.
			if window == nil or intent.window ~= window then
				return false, "That deal just changed. Take a look at the new one!", nil
			end
			Deals.refresh(state, window)
			collection = Deals.offers(window)[stall] or ""
		end
		local normal = Rules.prices[collection]
		if not normal then
			return false, "Unknown collection.", nil
		end
		if Catalog.comingSoon[collection] then
			return false, "This collection is coming soon.", nil
		end
		local price = if action == "Deal" then Deals.price(normal) else normal
		if action == "Deal" and Deals.left(state, stall) < 1 then
			return false, "Sold out for you this hour.", nil
		end
		if action == "Daily" then
			if collection ~= Economy.dailyCollection then
				return false, "Your daily free box is a Starter box.", nil
			end
			if state.lastDailyDay >= today then
				return false, "Come back after the next daily reset.", nil
			end
			if not PackageGrants.dailyCapacity(state) then
				return false, "Your daily reward is waiting for purchase credit space.", nil
			end
		elseif Lineage.spendable(state) < price * count then
			return false, "Not enough Coins yet.", nil
		end
		local allowed, refusal = canOpen(state, collection, count, rolls)
		if not allowed then
			return false, refusal, nil
		end
		Rules.settle(state, now or state.time)
		local assisted = action ~= "Daily" and Lineage.assistedSpend(state, price * count)
		local figures, fresh = open(state, collection, count, rolls, nil, override, assisted)
		id = figures[1]
		if action == "Daily" then
			state.lastDailyDay = today
			PackageGrants.daily(state)
		else
			Lineage.spend(state, price * count)
		end
		if action == "Deal" then
			state.deals.bought[stall] = (state.deals.bought[stall] or 0) + 1
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
			Rules.settle(state, now or state.time)
			figures = open(state, boxes.collection, boxes.count, rolls)
		end
		Lineage.creditEarned(state, reward.coins)
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
		Rules.settle(state, now or state.time)
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
		if Lineage.spendable(state) < cost then
			return false, string.format("You need %d Coins for the next slot.", cost), nil
		end
		local assisted = Lineage.spend(state, cost)
		if state.lineage and not assisted then
			state.lineage.earnedSlots += 1
		end
		state.display.unlocked += 1
		state.display.slots[state.display.unlocked] = ""
	elseif action == "BuyShelf" then
		local price = Rules.shelfPrice(state)
		if price == 0 then
			return false, "Max shelves reached.", nil
		end
		if Lineage.spendable(state) < price then
			return false, "Not enough Coins yet.", nil
		end
		Lineage.spend(state, price)
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
		Lineage.creditEarned(state, Economy.goalReward)
	elseif action == "EquipBest" then
		local best, income = Rules.best(state)
		if income <= Rules.rate(state) * (1 + 1e-9) then
			-- Already optimal: a successful no-op with no settlement, swap or revision.
			return true, "Already your best Display.", nil
		end
		local slots = state.display.slots
		local keep: { [string]: boolean } = {}
		local incoming: { string } = {}
		for _, figure in best do
			keep[figure] = true
			if not table.find(slots, figure) then
				table.insert(incoming, figure)
			end
		end
		Rules.refreshDay(state, today)
		Rules.settle(state, now or state.time)
		-- Kept figures stay in their slots; each replaced figure is collected like a Place swap.
		for slot = 1, state.display.unlocked do
			local outgoing = slots[slot]
			if #incoming > 0 and not keep[outgoing] then
				if outgoing ~= "" then
					transferBank(state, outgoing)
				end
				slots[slot] = table.remove(incoming, 1) :: string
			end
		end
		if state.step == Tutorial.display then
			state.step = Tutorial.collect
		end
		Rules.refreshDay(state, today)
		state.revision += 1
		return true, "Best Display equipped.", nil
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
			Rules.settle(state, now or state.time)
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
