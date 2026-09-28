--!strict
local Config = {}

export type Item = {
	id: string,
	label: string,
	assetKey: string,
	iconScale: number,
	iconYOffset: number,
	warm: boolean,
}

export type Geometry = {
	x: number,
	y: number,
	width: number,
	height: number,
	itemWidth: number,
	itemHeight: number,
	gap: number,
}

local items: { Item } = {
	{
		id = "Collection",
		label = "Collection",
		assetKey = "Navigation.Collection",
		iconScale = 0.93,
		iconYOffset = 0,
		warm = false,
	},
	{
		id = "Display",
		label = "Display",
		assetKey = "Navigation.Display",
		iconScale = 1,
		iconYOffset = -1,
		warm = false,
	},
	{
		id = "Shop",
		label = "Shop",
		assetKey = "Navigation.Shop",
		iconScale = 0.88,
		iconYOffset = 0,
		warm = true,
	},
	{
		id = "Goals",
		label = "Goals",
		assetKey = "Navigation.Goals",
		iconScale = 0.94,
		iconYOffset = 0,
		warm = false,
	},
	{
		id = "Shelves",
		label = "Shelves",
		assetKey = "Navigation.Shelves",
		iconScale = 0.9,
		iconYOffset = 0,
		warm = false,
	},
}

local pages: { string } = {}
for _, item in items do
	table.insert(pages, item.id)
	table.freeze(item)
end

Config.items = table.freeze(items)
Config.pages = table.freeze(pages)

function Config.layout(width: number, height: number, desktop: boolean): Geometry
	if desktop then
		local gap = 5
		local outerHeight = math.min(544, math.max(470, height - 16))
		local itemHeight = math.floor((outerHeight - 16 - gap * 4) / 5)
		local railHeight = itemHeight * 5 + gap * 4 + 16
		return {
			x = 10,
			y = math.floor((height - railHeight) / 2),
			width = 132,
			height = railHeight,
			itemWidth = 114,
			itemHeight = itemHeight,
			gap = gap,
		}
	end

	local railWidth = math.min(520, math.max(300, width - 16))
	return {
		x = math.floor((width - railWidth) / 2),
		y = height - 86,
		width = railWidth,
		height = 78,
		itemWidth = math.floor((railWidth - 12) / 5),
		itemHeight = 68,
		gap = 0,
	}
end

return Config
