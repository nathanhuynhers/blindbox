--!strict
-- Decode-only retired schema-v4 Shelf Page representation. No active browsing/runtime logic.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Shelves = require(script.Parent.Shelves)
export type Page = {
	id: string,
	placements: { [string]: string },
	customization: { [string]: string },
}
export type Data = { pages: { Page } }
local Legacy = {}
function Legacy.migrate(raw: unknown, discovered: { [string]: boolean }): Types.Shelves?
	if not Shelves.fields(raw, { "pages" }) then
		return nil
	end
	local data = raw :: { [string]: unknown }
	local count = Shelves.arrayCount(data.pages, 1, math.floor(Shelves.decodeLimits.units / 3))
	if not count then
		return nil
	end
	local result: Types.Shelves = { units = {} }
	local ids: { [string]: boolean } = {}
	local overflow: { Types.LegacyShelfOverflow } = {}
	local references = 0
	for index = 1, count do
		local rawPage = (data.pages :: { unknown })[index]
		if not Shelves.fields(rawPage, { "id", "placements", "customization" }) then
			return nil
		end
		local page = rawPage :: { [string]: unknown }
		if
			typeof(page.id) ~= "string"
			or #page.id > 64
			or not string.match(page.id, "^page:[%w_-]+$")
			or ids[page.id]
			or typeof(page.placements) ~= "table"
			or typeof(page.customization) ~= "table"
			or next(page.customization :: {}) ~= nil
		then
			return nil
		end
		ids[page.id] = true
		-- Frozen v4 capacity: every source page grants exactly three units, including empty ones.
		for unit = 1, 3 do
			table.insert(
				result.units,
				{ id = "shelf:" .. ((index - 1) * 3 + unit), placements = {}, customization = {} }
			)
		end
		local hidden: { [number]: { [string]: string } } = {}
		for key, figure in page.placements :: { [string]: unknown } do
			references += 1
			if
				references > Shelves.decodeLimits.placements
				or typeof(key) ~= "string"
				or #key > 64
				or typeof(figure) ~= "string"
				or not Catalog.byId[figure]
				or not discovered[figure]
			then
				return nil
			end
			local u, slotId = string.match(key, "^unit:([1-9]%d*)/(row:[1-9]%d*/slot:[1-9]%d*)$")
			if not u or not slotId then
				return nil
			end
			local unit = tonumber(u)
			if not unit or unit > 1000000 or not Config.parseSlot(slotId) then
				return nil
			end
			if unit <= 3 then
				result.units[(index - 1) * 3 + unit].placements[slotId] = figure
			else
				local entries = hidden[unit] or {}
				entries[slotId] = figure
				hidden[unit] = entries
			end
		end
		local hiddenIds: { number } = {}
		for unit in hidden do
			table.insert(hiddenIds, unit)
		end
		table.sort(hiddenIds)
		for _, unit in hiddenIds do
			if #overflow >= Shelves.decodeLimits.units then
				return nil
			end
			table.insert(
				overflow,
				{ sourceId = page.id, logicalUnit = unit, placements = hidden[unit] }
			)
		end
	end
	if #overflow > 0 then
		result.legacyOverflow = overflow
	end
	return result
end
return Legacy
