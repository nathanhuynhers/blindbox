--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Rules = require(script.Parent.Rules)
local Economy = require(script.Parent.Economy)
local Profile = {}
local function integer(value: unknown, low: number, high: number): boolean
	return typeof(value) == "number" and value >= low and value <= high and value % 1 == 0
end
function Profile.encode(state: Types.State): Types.Profile
	return {
		schemaVersion = 2,
		coins = state.coins,
		scrap = state.scrap,
		owned = table.clone(state.owned),
		discovered = table.clone(state.discovered),
		slots = table.clone(state.slots),
		step = state.step,
		unlocked = state.unlocked,
		theme = state.theme,
		themes = table.clone(state.themes),
		lastDailyDay = state.lastDailyDay,
		goalDay = state.goalDay,
		goalProgress = state.goalProgress,
		goalClaimed = state.goalClaimed,
	}
end
function Profile.decode(raw: unknown, now: number): Types.State?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: unknown }
	local version = data.schemaVersion
	if version ~= 1 and version ~= 2 then
		return nil
	end
	local fields: { [string]: boolean } = {
		schemaVersion = true,
		coins = true,
		scrap = true,
		owned = true,
		discovered = true,
		slots = true,
		step = true,
	}
	if version == 2 then
		for _, key in
			{
				"unlocked",
				"theme",
				"themes",
				"lastDailyDay",
				"goalDay",
				"goalProgress",
				"goalClaimed",
			}
		do
			fields[key] = true
		end
	end
	local fieldCount = 0
	for key in data do
		fieldCount += 1
		if fieldCount > 14 or not fields[key] then
			return nil
		end
	end
	local state = Rules.new(now)
	if
		not integer(data.coins, 0, Economy.coinLimit)
		or not integer(data.scrap, 0, Economy.scrapLimit)
		or not integer(data.step, 1, 5)
	then
		return nil
	end
	state.coins = data.coins :: number
	state.scrap = data.scrap :: number
	state.step = data.step :: number
	if
		typeof(data.owned) ~= "table"
		or typeof(data.discovered) ~= "table"
		or typeof(data.slots) ~= "table"
	then
		return nil
	end
	local total, keys = 0, 0
	for id, count in data.owned :: { [string]: unknown } do
		keys += 1
		if
			keys > #Catalog.figures
			or typeof(id) ~= "string"
			or not Catalog.byId[id]
			or not integer(count, 1, Economy.capacity)
		then
			return nil
		end
		state.owned[id] = count :: number
		total += count :: number
	end
	if total > Economy.capacity then
		return nil
	end
	keys = 0
	for id, found in data.discovered :: { [string]: unknown } do
		keys += 1
		if
			keys > #Catalog.figures
			or typeof(id) ~= "string"
			or not Catalog.byId[id]
			or found ~= true
		then
			return nil
		end
		state.discovered[id] = true
	end
	for id in state.owned do
		if not state.discovered[id] then
			return nil
		end
	end
	if version == 2 then
		if
			not integer(data.unlocked, 3, 4)
			or typeof(data.theme) ~= "string"
			or not Catalog.themes[data.theme]
			or typeof(data.themes) ~= "table"
		then
			return nil
		end
		state.unlocked = data.unlocked :: number
		state.theme = data.theme
		state.themes = {}
		keys = 0
		for id, owned in data.themes :: { [string]: unknown } do
			keys += 1
			if keys > 3 or typeof(id) ~= "string" or not Catalog.themes[id] or owned ~= true then
				return nil
			end
			state.themes[id] = true
		end
		if not state.themes.grove or not state.themes[state.theme] then
			return nil
		end
		if
			not integer(data.lastDailyDay, -1, 100000000)
			or not integer(data.goalDay, -1, 100000000)
			or not integer(data.goalProgress, 0, 3)
			or typeof(data.goalClaimed) ~= "boolean"
		then
			return nil
		end
		state.lastDailyDay = data.lastDailyDay :: number
		state.goalDay = data.goalDay :: number
		state.goalProgress = data.goalProgress :: number
		state.goalClaimed = data.goalClaimed
		if state.goalClaimed and state.goalProgress < 3 then
			return nil
		end
	end
	state.slots = {}
	keys = 0
	local reservations: { [string]: number } = {}
	for key, id in data.slots :: { [number]: unknown } do
		keys += 1
		if
			not integer(key, 1, state.unlocked)
			or typeof(id) ~= "string"
			or (id ~= "" and not Catalog.byId[id])
		then
			return nil
		end
		state.slots[key] = id
		if id ~= "" then
			reservations[id] = (reservations[id] or 0) + 1
		end
	end
	if keys ~= state.unlocked then
		return nil
	end
	for id, count in reservations do
		if count > (state.owned[id] or 0) then
			return nil
		end
	end
	return state
end
return Profile
