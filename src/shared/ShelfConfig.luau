--!strict
-- Geometry capacity is provisional. Saved logical slot IDs do not depend on coordinates.
local Config = {
	shelfUnitsPerPage = 3,
	rowsPerShelfUnit = 3,
	slotsPerRow = 3,
	pageAcquisition = "Unassigned", -- No price, product or acquisition endpoint yet.
}
function Config.slotId(unit: number, row: number, slot: number): string
	return string.format("unit:%d/row:%d/slot:%d", unit, row, slot)
end
function Config.parseSlot(id: string): (number?, number?, number?)
	if #id > 64 then
		return nil, nil, nil
	end
	local u, r, s = string.match(id, "^unit:([1-9]%d*)/row:([1-9]%d*)/slot:([1-9]%d*)$")
	if not u or not r or not s then
		return nil, nil, nil
	end
	local unit, row, slot = tonumber(u), tonumber(r), tonumber(s)
	if not unit or not row or not slot or unit > 1000000 or row > 1000000 or slot > 1000000 then
		return nil, nil, nil
	end
	return unit, row, slot
end
function Config.visible(id: string): boolean
	local unit, row, slot = Config.parseSlot(id)
	return unit ~= nil
		and row ~= nil
		and slot ~= nil
		and unit <= Config.shelfUnitsPerPage
		and row <= Config.rowsPerShelfUnit
		and slot <= Config.slotsPerRow
end
function Config.slots(): { string }
	local ids: { string } = {}
	for unit = 1, Config.shelfUnitsPerPage do
		for row = 1, Config.rowsPerShelfUnit do
			for slot = 1, Config.slotsPerRow do
				table.insert(ids, Config.slotId(unit, row, slot))
			end
		end
	end
	return ids
end
return table.freeze(Config)
