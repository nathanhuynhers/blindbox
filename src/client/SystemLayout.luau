--!strict
-- Measured content canvases. Short screens scroll; previews and targets never scale to fit height.
local Layout = {}
function Layout.grid(width: number, minimum: number, maximum: number): (number, number)
	local columns = math.clamp(math.floor((width + 12) / (minimum + 12)), 1, maximum)
	return columns, math.floor((width - (columns - 1) * 12) / columns)
end
function Layout.display(width: number, count: number, placing: boolean)
	local columns, cell =
		Layout.grid(width, 190, if width >= 1200 then count else math.min(3, count))
	local header = if width < 560 then 278 else 186
	local placementHeight = if width < 420 then 132 else 84
	local top = header + (if placing then placementHeight + 24 else 16)
	return {
		columns = columns,
		cell = cell,
		header = header,
		placementHeight = placementHeight,
		top = top,
		card = 324,
		height = top + math.ceil(count / columns) * 336,
	}
end
function Layout.shelves(width: number, rows: number, slotsPerRow: number)
	local wide = width >= 800
	local shelfWidth = if wide then math.floor(width * 0.53) else width
	local slotWidth = (shelfWidth - 40 - (slotsPerRow - 1) * 8) / slotsPerRow
	local slotHeight = math.clamp(math.floor(slotWidth * 1.13), 100, 150)
	local shelfHeight = 72 + rows * (slotHeight + 18)
	local pickerX = if wide then shelfWidth + 20 else 0
	local pickerY = if wide then 176 else 176 + shelfHeight + 20
	local pickerWidth = if wide then width - pickerX else width
	local columns, cell = Layout.grid(pickerWidth - 24, 104, 3)
	local pickerHeight = 162 + math.ceil(6 / columns) * 144 + 60
	return {
		wide = wide,
		shelfWidth = shelfWidth,
		slotWidth = slotWidth,
		slotHeight = slotHeight,
		shelfHeight = shelfHeight,
		pickerX = pickerX,
		pickerY = pickerY,
		pickerWidth = pickerWidth,
		columns = columns,
		cell = cell,
		pickerHeight = pickerHeight,
		height = math.max(176 + shelfHeight, pickerY + pickerHeight) + 16,
	}
end
function Layout.goals(width: number, collections: number, dailyChoices: number?)
	local wide = width >= 720
	local cardWidth = if wide then math.floor((width - 16) / 2) else width
	local dailyHeight = 144 + (dailyChoices or collections) * 68
	local heroHeight = math.max(304, dailyHeight)
	local freeY = if wide then 110 else 110 + 304 + 16
	local progressY = if wide then 110 + heroHeight + 24 else freeY + dailyHeight + 24
	local columns, cell = Layout.grid(width, 260, 3)
	return {
		wide = wide,
		cardWidth = cardWidth,
		heroHeight = if wide then heroHeight else 304,
		freeY = freeY,
		freeHeight = if wide then heroHeight else dailyHeight,
		progressY = progressY,
		columns = columns,
		cell = cell,
		height = progressY + 48 + math.ceil(collections / columns) * 142 + 16,
	}
end
return Layout
