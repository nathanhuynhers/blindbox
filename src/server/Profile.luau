--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Rules = require(script.Parent.Rules)
local Economy = require(script.Parent.Economy)
local Shelves = require(script.Parent.Shelves)
local Legacy = require(script.Parent.LegacyCosmetics)
local LegacyShelfPages = require(script.Parent.LegacyShelfPages)
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
	return {
		schemaVersion = 6,
		coins = state.coins,
		scrap = state.scrap,
		owned = table.clone(state.owned),
		discovered = table.clone(state.discovered),
		display = { unlocked = state.display.unlocked, slots = table.clone(state.display.slots) },
		shelves = Shelves.copy(state.shelves),
		step = state.step,
		lastDailyDay = state.lastDailyDay,
		goalDay = state.goalDay,
		goalProgress = state.goalProgress,
		goalClaimed = state.goalClaimed,
		boxesOpened = state.boxesOpened,
	}
end
function Profile.decode(raw: unknown, now: number): Types.State?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: unknown }
	local version = data.schemaVersion
	if
		typeof(version) ~= "number"
		or (
			version ~= 1
			and version ~= 2
			and version ~= 3
			and version ~= 4
			and version ~= 5
			and version ~= 6
		)
	then
		return nil
	end
	local allowed = { "schemaVersion", "coins", "scrap", "owned", "discovered", "step" }
	if version >= 3 then
		table.insert(allowed, "display")
		table.insert(allowed, if version >= 4 then "shelves" else "showrooms")
	else
		table.insert(allowed, "slots")
		if version == 2 then
			for _, key in { "unlocked", "theme", "themes" } do
				table.insert(allowed, key)
			end
		end
	end
	if version ~= 1 then
		for _, key in { "lastDailyDay", "goalDay", "goalProgress", "goalClaimed" } do
			table.insert(allowed, key)
		end
	end
	if version >= 6 then
		table.insert(allowed, "boxesOpened")
	end
	if
		not fields(data, allowed)
		or not integer(data.coins, 0, Economy.coinLimit)
		or not integer(data.scrap, 0, Economy.scrapLimit)
		or not integer(data.step, 1, 5)
		or typeof(data.owned) ~= "table"
		or typeof(data.discovered) ~= "table"
	then
		return nil
	end
	local state = Rules.new(now)
	state.coins = data.coins :: number
	state.scrap = data.scrap :: number
	state.step = data.step :: number
	local total = 0
	for id, count in data.owned :: { [string]: unknown } do
		if
			typeof(id) ~= "string"
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
	local display: { [string]: unknown }
	if version >= 3 then
		if typeof(data.display) ~= "table" then
			return nil
		end
		display = data.display :: { [string]: unknown }
		if not fields(display, { "unlocked", "slots" }) then
			return nil
		end
	else
		display = { unlocked = if version == 1 then 3 else data.unlocked, slots = data.slots }
		if version == 2 and not Legacy.validPalettes(data.theme, data.themes) then
			return nil
		end
	end
	if
		not integer(
			display.unlocked,
			DisplayConfig.defaultSlots,
			if version >= 3 then DisplayConfig.maxSlots else (if version == 1 then 3 else 4)
		) or typeof(display.slots) ~= "table"
	then
		return nil
	end
	state.display = { unlocked = display.unlocked :: number, slots = {} }
	local keys = 0
	local reservations: { [string]: number } = {}
	for key, id in display.slots :: { [number]: unknown } do
		if
			not integer(key, 1, state.display.unlocked)
			or typeof(id) ~= "string"
			or (id ~= "" and not Catalog.byId[id])
		then
			return nil
		end
		keys += 1
		state.display.slots[key] = id
		if id ~= "" then
			reservations[id] = (reservations[id] or 0) + 1
		end
	end
	if keys ~= state.display.unlocked then
		return nil
	end
	for id, count in reservations do
		if count > (state.owned[id] or 0) then
			return nil
		end
	end
	local shelves = if version >= 5
		then Shelves.decode(data.shelves, state.discovered)
		elseif version == 4 then LegacyShelfPages.migrate(data.shelves, state.discovered)
		elseif version == 3 then Legacy.migrate(data.showrooms, state.discovered)
		else Shelves.new()
	if not shelves then
		return nil
	end
	state.shelves = shelves
	if version ~= 1 then
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
	-- v1-v5 predate the counter: migrated players start at 0 (Rules.new default).
	if version >= 6 then
		if not integer(data.boxesOpened, 0, Rules.boxesOpenedLimit) then
			return nil
		end
		state.boxesOpened = data.boxesOpened :: number
	end
	return state
end
return Profile
