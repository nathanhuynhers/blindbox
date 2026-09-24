--!strict
local Types = require(script.Parent.Types)
local figures: { Types.Figure } = {
	{
		id = "grove.pebble",
		name = "Pebble Pip",
		collection = "grove",
		rarity = "Common",
		color = Color3.fromRGB(156, 190, 177),
		shape = "round",
	},
	{
		id = "grove.sprout",
		name = "Sprout Scout",
		collection = "grove",
		rarity = "Common",
		color = Color3.fromRGB(124, 211, 126),
		shape = "sprout",
	},
	{
		id = "grove.acorn",
		name = "Acorn Dot",
		collection = "grove",
		rarity = "Common",
		color = Color3.fromRGB(219, 164, 104),
		shape = "acorn",
	},
	{
		id = "grove.mushroom",
		name = "Mallow Cap",
		collection = "grove",
		rarity = "Uncommon",
		color = Color3.fromRGB(242, 142, 166),
		shape = "mushroom",
	},
	{
		id = "grove.moth",
		name = "Moon Moth",
		collection = "grove",
		rarity = "Uncommon",
		color = Color3.fromRGB(157, 159, 241),
		shape = "wings",
	},
	{
		id = "grove.star",
		name = "Sunbeam Sprite",
		collection = "grove",
		rarity = "Rare",
		color = Color3.fromRGB(255, 212, 102),
		shape = "crown",
	},
	{
		id = "tide.bubble",
		name = "Bubble Bean",
		collection = "tide",
		rarity = "Common",
		color = Color3.fromRGB(103, 204, 221),
		shape = "round",
	},
	{
		id = "tide.coral",
		name = "Coral Cuddle",
		collection = "tide",
		rarity = "Common",
		color = Color3.fromRGB(249, 149, 127),
		shape = "coral",
	},
	{
		id = "tide.shell",
		name = "Shell Scribe",
		collection = "tide",
		rarity = "Common",
		color = Color3.fromRGB(228, 204, 246),
		shape = "shell",
	},
	{
		id = "tide.jelly",
		name = "Jelly Jive",
		collection = "tide",
		rarity = "Uncommon",
		color = Color3.fromRGB(121, 179, 241),
		shape = "jelly",
	},
	{
		id = "tide.ray",
		name = "Ripple Ray",
		collection = "tide",
		rarity = "Uncommon",
		color = Color3.fromRGB(132, 224, 201),
		shape = "wings",
	},
	{
		id = "tide.pearl",
		name = "Pearl Regent",
		collection = "tide",
		rarity = "Rare",
		color = Color3.fromRGB(255, 232, 204),
		shape = "pearl",
	},
}
local byId: { [string]: Types.Figure } = {}
for _, figure in figures do
	assert(not byId[figure.id], "Duplicate catalog ID")
	byId[figure.id] = figure
	table.freeze(figure)
end
local collections = {
	{
		id = "grove",
		name = "Pocket Grove",
		description = "Little woodland wonders",
		color = Color3.fromRGB(134, 204, 165),
	},
	{
		id = "tide",
		name = "Tidepool Tales",
		description = "Treasures from a tiny ocean",
		color = Color3.fromRGB(116, 195, 234),
	},
}
local collectionIds: { [string]: boolean } = {}
for _, collection in collections do
	assert(not collectionIds[collection.id], "Duplicate collection ID")
	collectionIds[collection.id] = true
end
for _, figure in figures do
	assert(collectionIds[figure.collection], "Missing collection")
end
local themes: { [string]: { name: string, wall: Color3, floor: Color3, accent: Color3 } } = {
	grove = {
		name = "Woodland",
		wall = Color3.fromRGB(79, 124, 112),
		floor = Color3.fromRGB(226, 220, 201),
		accent = Color3.fromRGB(237, 199, 128),
	},
	dusk = {
		name = "Evening Lilac",
		wall = Color3.fromRGB(100, 92, 139),
		floor = Color3.fromRGB(218, 211, 228),
		accent = Color3.fromRGB(242, 171, 194),
	},
	ocean = {
		name = "Ocean Glass",
		wall = Color3.fromRGB(64, 127, 160),
		floor = Color3.fromRGB(213, 231, 232),
		accent = Color3.fromRGB(132, 230, 214),
	},
}
return table.freeze({
	figures = table.freeze(figures),
	byId = table.freeze(byId),
	collections = collections,
	collectionIds = collectionIds,
	themes = themes,
})
