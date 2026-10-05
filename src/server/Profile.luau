--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Rules = require(script.Parent.Rules)
local Economy = require(script.Parent.Economy)
local CollectionEconomy = require(script.Parent.CollectionEconomy)
local Shelves = require(script.Parent.Shelves)
local Tutorial = require(game:GetService("ReplicatedStorage").Shared.Tutorial)
local Profile = {}
local function integer(value: unknown, low: number, high: number): boolean
	return typeof(value) == "number" and value >= low and value <= high and value % 1 == 0
end
local function fields(value: { [string]: unknown }, allowed: { string }): boolean
	for key in value do
		if not table.find(allowed, key) then
			return false
		end
	end
	return true
end
function Profile.encode(state: Types.State): Types.Profile
	local pity: { [string]: Types.Pity } = {}
	for group, counters in state.pityByGroup do
		pity[group] = table.clone(counters)
	end
	return {
		schemaVersion = 13,
		coins = state.coins,
		earnings = table.clone(state.earnings),
		pityByGroup = pity,
		owned = table.clone(state.owned),
		discovered = table.clone(state.discovered),
		display = { unlocked = state.display.unlocked, slots = table.clone(state.display.slots) },
		shelves = Shelves.copy(state.shelves),
		step = state.step,
		tutorialHidden = state.tutorialHidden,
		lastDailyDay = state.lastDailyDay,
		lastLoginDay = state.lastLoginDay,
		loginStreak = state.loginStreak,
		goalDay = state.goalDay,
		goalProgress = state.goalProgress,
		goalClaimed = state.goalClaimed,
		boxesOpened = state.boxesOpened,
		shelfRewards = table.clone(state.shelfRewards),
		lastSeen = state.lastSeen,
		offlinePending = state.offlinePending,
		sfxVolume = state.sfxVolume,
		musicVolume = state.musicVolume,
	}
end
function Profile.decode(raw: unknown, now: number): Types.State?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: unknown }
	-- The user requested a fresh economy. A new store isolates old schemas;
	-- unexpected old/corrupt data in this store fails closed instead of resetting.
	if
		(
			data.schemaVersion ~= 6
			and data.schemaVersion ~= 7
			and data.schemaVersion ~= 8
			and data.schemaVersion ~= 9
			and data.schemaVersion ~= 10
			and data.schemaVersion ~= 11
			and data.schemaVersion ~= 12
			and data.schemaVersion ~= 13
		)
		or not fields(data, {
			"schemaVersion",
			"coins",
			"earnings",
			"owned",
			"discovered",
			"display",
			"shelves",
			"step",
			"tutorialHidden",
			"lastDailyDay",
			"lastLoginDay",
			"loginStreak",
			"goalDay",
			"goalProgress",
			"goalClaimed",
			"pityByGroup",
			"boxesOpened",
			"shelfRewards",
			"lastSeen",
			"offlinePending",
			"sfxVolume",
			"musicVolume",
		})
	then
		return nil
	end
	if
		not integer(data.coins, 0, Economy.coinLimit)
		or not integer(data.step, 1, if data.schemaVersion == 13 then Tutorial.done else 5)
		or typeof(data.owned) ~= "table"
		or typeof(data.discovered) ~= "table"
		or typeof(data.pityByGroup) ~= "table"
		or typeof(data.display) ~= "table"
	then
		return nil
	end
	local state = Rules.new(now)
	state.coins, state.step = data.coins :: number, data.step :: number
	for id, count in data.owned :: { [string]: unknown } do
		if
			typeof(id) ~= "string"
			or not Catalog.byId[id]
			or not integer(count, 1, Economy.copyLimit)
		then
			return nil
		end
		state.owned[id] = count :: number
	end
	for id, found in data.discovered :: { [string]: unknown } do
		if typeof(id) ~= "string" or not Catalog.byId[id] or found ~= true then
			return nil
		end
		state.discovered[id] = true
	end
	for id in state.owned do
		if not state.discovered[id] then
			return nil
		end
	end
	if data.schemaVersion == 6 then
		if data.earnings ~= nil then
			return nil
		end
	else
		if typeof(data.earnings) ~= "table" then
			return nil
		end
		for id, value in data.earnings :: { [string]: unknown } do
			if
				typeof(id) ~= "string"
				or not state.owned[id]
				or typeof(value) ~= "number"
				or not (value >= 0 and value <= Economy.coinLimit)
			then
				return nil
			end
			state.earnings[id] = value
		end
	end
	for group, rawCounters in data.pityByGroup :: { [string]: unknown } do
		if
			typeof(group) ~= "string"
			or not CollectionEconomy.groups[group]
			or typeof(rawCounters) ~= "table"
		then
			return nil
		end
		local counters = rawCounters :: { [string]: unknown }
		if
			not fields(counters, { "legendaryDryRolls", "mythicalDryRolls" })
			or not integer(counters.legendaryDryRolls, 0, Economy.counterLimit)
			or not integer(counters.mythicalDryRolls, 0, Economy.counterLimit)
		then
			return nil
		end
		state.pityByGroup[group] = {
			legendaryDryRolls = counters.legendaryDryRolls :: number,
			mythicalDryRolls = counters.mythicalDryRolls :: number,
		}
	end
	local display = data.display :: { [string]: unknown }
	if
		not fields(display, { "unlocked", "slots" })
		or not integer(display.unlocked, DisplayConfig.defaultSlots, DisplayConfig.maxSlots)
		or typeof(display.slots) ~= "table"
	then
		return nil
	end
	state.display = { unlocked = display.unlocked :: number, slots = {} }
	local keys = 0
	local seen: { [string]: boolean } = {}
	for key, id in display.slots :: { [number]: unknown } do
		if
			not integer(key, 1, state.display.unlocked)
			or typeof(id) ~= "string"
			or (id ~= "" and (not state.owned[id] or seen[id]))
		then
			return nil
		end
		keys += 1
		state.display.slots[key] = id
		if id ~= "" then
			seen[id] = true
		end
	end
	if keys ~= state.display.unlocked then
		return nil
	end
	local shelves = Shelves.decode(data.shelves, state.discovered, state.owned)
	if not shelves then
		return nil
	end
	state.shelves = shelves
	if
		not integer(data.lastDailyDay, -1, 100000000)
		or not integer(data.goalDay, -1, 100000000)
		or not integer(data.goalProgress, 0, 3)
		or typeof(data.goalClaimed) ~= "boolean"
	then
		return nil
	end
	state.lastDailyDay, state.goalDay = data.lastDailyDay :: number, data.goalDay :: number
	state.goalProgress, state.goalClaimed = data.goalProgress :: number, data.goalClaimed
	if state.goalClaimed and state.goalProgress < 3 then
		return nil
	end
	-- v6/v7 predate the counter: those players start at 0 (Rules.new default). v8+ requires it.
	if (data.schemaVersion :: number) >= 8 then
		if not integer(data.boxesOpened, 0, Rules.boxesOpenedLimit) then
			return nil
		end
		state.boxesOpened = data.boxesOpened :: number
	elseif data.boxesOpened ~= nil then
		return nil
	end
	-- v6-v8 predate Shelf rewards; v9+ requires the map.
	if (data.schemaVersion :: number) >= 9 then
		if typeof(data.shelfRewards) ~= "table" then
			return nil
		end
		for id, granted in data.shelfRewards :: { [string]: unknown } do
			if typeof(id) ~= "string" or not Catalog.collectionIds[id] or granted ~= true then
				return nil
			end
			state.shelfRewards[id] = true
		end
	elseif data.shelfRewards ~= nil then
		return nil
	end
	-- v6-v9 predate offline earnings: lastSeen 0 (unknown) awards nothing on the first v10+ join.
	if (data.schemaVersion :: number) >= 10 then
		if
			not integer(data.lastSeen, 0, 100000000000)
			or not integer(data.offlinePending, 0, Economy.coinLimit)
		then
			return nil
		end
		state.lastSeen, state.offlinePending =
			data.lastSeen :: number, data.offlinePending :: number
	elseif data.lastSeen ~= nil or data.offlinePending ~= nil then
		return nil
	end
	-- v6-v10 predate the login streak (Rules.new: never claimed). v11+ requires a consistent pair.
	if (data.schemaVersion :: number) >= 11 then
		if
			not integer(data.lastLoginDay, -1, 100000000)
			or not integer(data.loginStreak, 0, 100000000)
			or (data.lastLoginDay == -1) ~= (data.loginStreak == 0)
		then
			return nil
		end
		state.lastLoginDay, state.loginStreak =
			data.lastLoginDay :: number, data.loginStreak :: number
	elseif data.lastLoginDay ~= nil or data.loginStreak ~= nil then
		return nil
	end
	-- v6-v11 predate audio settings (Rules.new: full volume). v12+ requires both percentages.
	if (data.schemaVersion :: number) >= 12 then
		if not integer(data.sfxVolume, 0, 100) or not integer(data.musicVolume, 0, 100) then
			return nil
		end
		state.sfxVolume, state.musicVolume = data.sfxVolume :: number, data.musicVolume :: number
	elseif data.sfxVolume ~= nil or data.musicVolume ~= nil then
		return nil
	end
	-- v13 saves the Welcome Quest stage and skip choice. Older stages meant something else and
	-- there was no Welcome reward, so an upgraded profile that never opened a box starts the
	-- quest and any other upgraded profile is treated as finished (no Welcome rewards).
	if data.schemaVersion == 13 then
		if typeof(data.tutorialHidden) ~= "boolean" then
			return nil
		end
		state.tutorialHidden = data.tutorialHidden :: boolean
	elseif data.tutorialHidden ~= nil then
		return nil
	else
		state.step = if state.boxesOpened == 0 and next(state.owned) == nil
			then Tutorial.welcome
			else Tutorial.done
	end
	-- Idempotent: also grants collections completed before Shelf rewards existed.
	Rules.grantShelves(state)
	return state
end
return Profile
