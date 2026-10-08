--!strict
local Config = {
	visibleShelfUnits = 3,
	startingShelfUnits = 3,
	rowsPerShelfUnit = 3,
	slotsPerRow = 3,
	maxShelfUnits = 100,
	showcaseStepSeconds = 7,
	showcaseBrowseIdleSeconds = 10,
	showcaseEditorIdleSeconds = 3,
}
function Config.slotId(row: number, slot: number): string
	return string.format("row:%d/slot:%d", row, slot)
end
function Config.parseSlot(id: string): (number?, number?)
	if #id > 64 then
		return nil, nil
	end
	local r, s = string.match(id, "^row:([1-9]%d*)/slot:([1-9]%d*)$")
	local row, slot = tonumber(r), tonumber(s)
	if not row or not slot or row > 1000000 or slot > 1000000 then
		return nil, nil
	end
	return row, slot
end
function Config.visible(id: string): boolean
	local row, slot = Config.parseSlot(id)
	return row ~= nil
		and slot ~= nil
		and row <= Config.rowsPerShelfUnit
		and slot <= Config.slotsPerRow
end
function Config.slots(): { string }
	local result: { string } = {}
	for row = 1, Config.rowsPerShelfUnit do
		for slot = 1, Config.slotsPerRow do
			table.insert(result, Config.slotId(row, slot))
		end
	end
	return result
end
-- Runtime-only renderer key; never persisted or accepted as an edit target.
function Config.renderSlot(position: number, slotId: string): string
	return string.format("viewport:%d/%s", position, slotId)
end
return table.freeze(Config)
