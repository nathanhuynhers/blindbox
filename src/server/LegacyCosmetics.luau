--!strict
-- Decode-only v1-v3 compatibility. No room runtime, ownership grants or active cosmetic system.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Shelves = require(script.Parent.Shelves)
local Legacy = {}
local palettes: { [string]: boolean } = { grove = true, dusk = true, ocean = true }
local roomCollections: { [string]: string } =
	{ ["collection:grove"] = "grove", ["collection:tide"] = "tide" }
local function fields(value: unknown, allowed: { string }): boolean
	if typeof(value) ~= "table" then
		return false
	end
	for key in value :: { [string]: unknown } do
		if not table.find(allowed, key) then
			return false
		end
	end
	return true
end
function Legacy.validPalettes(palette: unknown, owned: unknown): boolean
	if typeof(palette) ~= "string" or not palettes[palette] or typeof(owned) ~= "table" then
		return false
	end
	local values = owned :: { [string]: unknown }
	for id, value in values do
		if not palettes[id] or value ~= true then
			return false
		end
	end
	return values.grove == true and values[palette] == true
end
function Legacy.migrate(raw: unknown, discovered: { [string]: boolean }): Types.Shelves?
	if not fields(raw, { "rooms", "palette", "palettes" }) then
		return nil
	end
	local data = raw :: { [string]: unknown }
	if not Legacy.validPalettes(data.palette, data.palettes) or typeof(data.rooms) ~= "table" then
		return nil
	end
	local ownedPalettes = data.palettes :: { [string]: unknown }
	local rooms = data.rooms :: { [string]: unknown }
	local ids: { string } = {}
	for id in rooms do
		if typeof(id) ~= "string" or #id > 96 then
			return nil
		end
		table.insert(ids, id)
	end
	table.sort(ids)
	local references: { string } = {}
	for _, id in ids do
		local rawRoom = rooms[id]
		if
			not fields(rawRoom, {
				"roomId",
				"sourceType",
				"sourceCollectionId",
				"theme",
				"placements",
				"customization",
			})
		then
			return nil
		end
		local room = rawRoom :: { [string]: unknown }
		if
			room.roomId ~= id
			or typeof(room.theme) ~= "string"
			or ownedPalettes[room.theme] ~= true
			or typeof(room.placements) ~= "table"
			or typeof(room.customization) ~= "table"
			or next(room.customization :: {}) ~= nil
		then
			return nil
		end
		if room.sourceType == "Collection" then
			if not roomCollections[id] or roomCollections[id] ~= room.sourceCollectionId then
				return nil
			end
			for _, figure in Catalog.figures do
				if figure.collection == room.sourceCollectionId and not discovered[figure.id] then
					return nil
				end
			end
		elseif room.sourceType == "Custom" then
			if room.sourceCollectionId ~= nil or not string.match(id, "^custom:[%w_-]+$") then
				return nil
			end
		else
			return nil
		end
		local placements = room.placements :: { [string]: unknown }
		for anchor, figure in placements do
			if
				typeof(anchor) ~= "string"
				or not string.match(anchor, "^figure_[1-6]$")
				or typeof(figure) ~= "string"
				or not Catalog.byId[figure]
				or not discovered[figure]
			then
				return nil
			end
		end
		for anchor = 1, 6 do
			local figure = placements["figure_" .. anchor]
			if typeof(figure) == "string" then
				table.insert(references, figure)
			end
		end
	end
	local result = Shelves.new()
	for index, figure in references do
		-- Frozen migration layout: later visual/config changes cannot change conversion results.
		local pageIndex = math.floor((index - 1) / 27) + 1
		local offset = (index - 1) % 27
		local slotId = string.format(
			"unit:%d/row:%d/slot:%d",
			math.floor(offset / 9) + 1,
			math.floor(offset / 3) % 3 + 1,
			offset % 3 + 1
		)
		if not result.pages[pageIndex] then
			result.pages[pageIndex] =
				{ id = "page:" .. pageIndex, placements = {}, customization = {} }
		end
		result.pages[pageIndex].placements[slotId] = figure
	end
	-- Themes/ownership have no shelf equivalent. Only validated figure references are converted.
	return result
end
return Legacy
