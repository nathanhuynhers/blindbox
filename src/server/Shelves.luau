--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Shelves = {}
-- Decoder resource guards, NOT product progression limits. Review storage before raising.
Shelves.decodeLimits = table.freeze({ units = 10000, placements = 20000 })
export type View = { startIndex: number, revision: number, lastTurn: number }
export type Access = { actorId: number, ownerId: number, near: boolean, view: View }
function Shelves.new(): Types.Shelves
	local units: { Types.ShelfUnit } = {}
	for index = 1, Config.startingShelfUnits do
		table.insert(units, { id = "shelf:" .. index, placements = {}, customization = {} })
	end
	return { units = units }
end
function Shelves.newView(): View
	return { startIndex = 1, revision = 0, lastTurn = -math.huge }
end
function Shelves.copy(shelves: Types.Shelves): Types.Shelves
	local result: Types.Shelves = { units = {} }
	for _, unit in shelves.units do
		table.insert(result.units, {
			id = unit.id,
			placements = table.clone(unit.placements),
			customization = table.clone(unit.customization),
		})
	end
	if shelves.legacyOverflow then
		local overflow: { Types.LegacyShelfOverflow } = {}
		for _, entry in shelves.legacyOverflow do
			table.insert(overflow, {
				sourceId = entry.sourceId,
				logicalUnit = entry.logicalUnit,
				placements = table.clone(entry.placements),
			})
		end
		result.legacyOverflow = overflow
	end
	return result
end
function Shelves.fields(raw: unknown, allowed: { string }): boolean
	if typeof(raw) ~= "table" then
		return false
	end
	for key in raw :: { [string]: unknown } do
		if not table.find(allowed, key) then
			return false
		end
	end
	return true
end
function Shelves.arrayCount(raw: unknown, minimum: number, maximum: number): number?
	if typeof(raw) ~= "table" then
		return nil
	end
	local values = raw :: { [number]: unknown }
	local count = 0
	for key in values do
		count += 1
		if
			count > maximum
			or typeof(key) ~= "number"
			or key < 1
			or key > maximum
			or key % 1 ~= 0
		then
			return nil
		end
	end
	if count < minimum then
		return nil
	end
	for index = 1, count do
		if values[index] == nil then
			return nil
		end
	end
	return count
end

local function orderedSlots(placements: { [string]: string }): { string }
	local slots: { string } = {}
	for slot in placements do
		table.insert(slots, slot)
	end
	table.sort(slots, function(a, b)
		local aRow, aSlot = Config.parseSlot(a)
		local bRow, bSlot = Config.parseSlot(b)
		if aRow ~= bRow then
			return (aRow or math.huge) < (bRow or math.huge)
		end
		if aSlot ~= bSlot then
			return (aSlot or math.huge) < (bSlot or math.huge)
		end
		return a < b
	end)
	return slots
end

function Shelves.placementCounts(shelves: Types.Shelves): { [string]: number }
	local counts: { [string]: number } = {}
	for _, unit in shelves.units do
		for _, figure in unit.placements do
			counts[figure] = (counts[figure] or 0) + 1
		end
	end
	return counts
end

function Shelves.availability(
	shelves: Types.Shelves,
	owned: { [string]: number }
): { [string]: number }
	local counts = Shelves.placementCounts(shelves)
	local available: { [string]: number } = {}
	for _, figure in Catalog.figures do
		available[figure.id] = math.max(0, (owned[figure.id] or 0) - (counts[figure.id] or 0))
	end
	return available
end

-- Canonical repair order is unit order, then numeric row/slot order. Earliest copies survive.
function Shelves.reconcile(
	shelves: Types.Shelves,
	owned: { [string]: number },
	discovered: { [string]: boolean }?
): boolean
	local kept: { [string]: number } = {}
	local changed = false
	for _, unit in shelves.units do
		for _, slot in orderedSlots(unit.placements) do
			local figure = unit.placements[slot]
			local limit = owned[figure] or 0
			local count = kept[figure] or 0
			if limit <= count or (discovered ~= nil and not discovered[figure]) then
				unit.placements[slot] = nil
				changed = true
			else
				kept[figure] = count + 1
			end
		end
	end
	return changed
end

function Shelves.decode(
	raw: unknown,
	discovered: { [string]: boolean },
	owned: { [string]: number }
): Types.Shelves?
	if not Shelves.fields(raw, { "units", "legacyOverflow" }) then
		return nil
	end
	local data = raw :: { [string]: unknown }
	local count =
		Shelves.arrayCount(data.units, Config.startingShelfUnits, Shelves.decodeLimits.units)
	if not count then
		return nil
	end
	local result: Types.Shelves = { units = {} }
	local ids: { [string]: boolean } = {}
	local placementsRead = 0
	local function placements(rawPlacements: unknown): { [string]: string }?
		if typeof(rawPlacements) ~= "table" then
			return nil
		end
		local values: { [string]: string } = {}
		for slot, figure in rawPlacements :: { [string]: unknown } do
			placementsRead += 1
			if
				placementsRead > Shelves.decodeLimits.placements
				or typeof(slot) ~= "string"
				or not Config.parseSlot(slot)
				or typeof(figure) ~= "string"
				or not Catalog.byId[figure]
			then
				return nil
			end
			values[slot] = figure
		end
		return values
	end
	for index = 1, count do
		local rawUnit = (data.units :: { unknown })[index]
		if not Shelves.fields(rawUnit, { "id", "placements", "customization" }) then
			return nil
		end
		local unit = rawUnit :: { [string]: unknown }
		if
			typeof(unit.id) ~= "string"
			or #unit.id > 64
			or not string.match(unit.id, "^shelf:[%w_-]+$")
			or ids[unit.id]
			or typeof(unit.customization) ~= "table"
			or next(unit.customization :: {}) ~= nil
		then
			return nil
		end
		ids[unit.id] = true
		local decoded = placements(unit.placements)
		if not decoded then
			return nil
		end
		table.insert(result.units, { id = unit.id, placements = decoded, customization = {} })
	end
	if data.legacyOverflow ~= nil then
		local overflowCount = Shelves.arrayCount(data.legacyOverflow, 1, Shelves.decodeLimits.units)
		if not overflowCount then
			return nil
		end
		local overflow: { Types.LegacyShelfOverflow } = {}
		local keys: { [string]: boolean } = {}
		for index = 1, overflowCount do
			local rawEntry = (data.legacyOverflow :: { unknown })[index]
			if not Shelves.fields(rawEntry, { "sourceId", "logicalUnit", "placements" }) then
				return nil
			end
			local entry = rawEntry :: { [string]: unknown }
			-- sourceId is the retired v4 identifier, retained solely for lossless recovery.
			if
				typeof(entry.sourceId) ~= "string"
				or #entry.sourceId > 64
				or not string.match(entry.sourceId, "^page:[%w_-]+$")
				or typeof(entry.logicalUnit) ~= "number"
				or entry.logicalUnit <= 3
				or entry.logicalUnit > 1000000
				or entry.logicalUnit % 1 ~= 0
			then
				return nil
			end
			local key = entry.sourceId .. "/" .. entry.logicalUnit
			if keys[key] then
				return nil
			end
			keys[key] = true
			local decoded = placements(entry.placements)
			if not decoded or next(decoded) == nil then
				return nil
			end
			table.insert(
				overflow,
				{ sourceId = entry.sourceId, logicalUnit = entry.logicalUnit, placements = decoded }
			)
		end
		result.legacyOverflow = overflow
	end
	Shelves.reconcile(result, owned, discovered)
	return result
end
function Shelves.visibleIndices(shelves: Types.Shelves, view: View): { number }
	local count = #shelves.units
	local start = if count <= Config.visibleShelfUnits then 1 else view.startIndex
	local indices: { number } = {}
	for position = 1, math.min(count, Config.visibleShelfUnits) do
		table.insert(indices, (start + position - 2) % count + 1)
	end
	return indices
end
function Shelves.publicView(shelves: Types.Shelves, view: View): Types.ShelfView
	local visible: { Types.VisibleShelf } = {}
	for _, index in Shelves.visibleIndices(shelves, view) do
		local unit = shelves.units[index]
		local placements: { [string]: string } = {}
		for _, slot in Config.slots() do
			placements[slot] = unit.placements[slot]
		end
		table.insert(visible, { id = unit.id, index = index, placements = placements })
	end
	return {
		ownedCount = #shelves.units,
		visible = visible,
		carouselRevision = view.revision,
		canNavigate = #shelves.units > Config.visibleShelfUnits,
	}
end
function Shelves.turn(shelves: Types.Shelves, view: View, direction: number, now: number): boolean
	if #shelves.units <= Config.visibleShelfUnits then
		view.startIndex = 1
		return false
	end
	if (direction ~= -1 and direction ~= 1) or now - view.lastTurn < 0.5 then
		return false
	end
	view.startIndex = (view.startIndex - 1 + direction) % #shelves.units + 1
	view.revision += 1
	view.lastTurn = now
	return true
end
function Shelves.mutate(
	state: Types.State,
	intent: Types.Intent,
	access: Access?,
	now: number
): (boolean, string, string?)
	if not access or access.actorId ~= access.ownerId or not access.near then
		return false, "Walk to your own shelves to edit.", nil
	end
	if intent.carouselRevision ~= access.view.revision or intent.revision ~= state.revision then
		return false, "The visible shelves changed. Try again.", nil
	end
	if intent.action == "ShelfNext" or intent.action == "ShelfPrevious" then
		local ok = Shelves.turn(
			state.shelves,
			access.view,
			if intent.action == "ShelfNext" then 1 else -1,
			now
		)
		return ok, if ok then "Viewing next shelves." else "No turn available yet.", nil
	end
	local target: Types.ShelfUnit? = nil
	for _, index in Shelves.visibleIndices(state.shelves, access.view) do
		local unit = state.shelves.units[index]
		if unit.id == intent.shelfId then
			target = unit
			break
		end
	end
	if not target then
		return false, "Select one of your visible shelves.", nil
	end
	local slot = intent.shelfSlotId or ""
	if not Config.visible(slot) then
		return false, "Unknown shelf slot.", nil
	end
	if intent.action == "ShelfPlace" then
		local figure = intent.figure or ""
		if not Catalog.byId[figure] or not state.discovered[figure] then
			return false, "Discover that figure first.", nil
		end
		if (state.owned[figure] or 0) <= 0 then
			return false, "You do not own that figure.", nil
		end
		if target.placements[slot] ~= figure then
			local available = Shelves.availability(state.shelves, state.owned)
			if (available[figure] or 0) <= 0 then
				return false, "All owned copies are already on your Shelves.", nil
			end
		end
		target.placements[slot] = figure
	elseif intent.action == "ShelfRemove" then
		target.placements[slot] = nil
	else
		return false, "Unknown shelf action.", nil
	end
	state.revision += 1
	return true, "Shelf updated.", nil
end
return Shelves
