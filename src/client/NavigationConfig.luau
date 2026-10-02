--!strict
-- The five dock destinations, in dock order, and their glossy icon art.
local Assets = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)
local NavigationAssetIds = require(game:GetService("ReplicatedStorage").Shared.NavigationAssetIds)
local Config = {}

export type Item = { id: string, label: string, assetKey: string }

local items: { Item } = {
	{ id = "Collection", label = "Collection", assetKey = "Navigation.Collection" },
	{ id = "Display", label = "Display", assetKey = "Navigation.Display" },
	{ id = "Shop", label = "Shop", assetKey = "Navigation.Shop" },
	{ id = "Goals", label = "Goals", assetKey = "Navigation.Goals" },
	{ id = "Shelves", label = "Shelves", assetKey = "Navigation.Shelves" },
}

local pages: { string } = {}
local byId: { [string]: Item } = {}
for _, item in items do
	table.insert(pages, item.id)
	byId[item.id] = item
	table.freeze(item)
end

Config.items = table.freeze(items)
Config.pages = table.freeze(pages)

-- Empty when the art is not uploaded yet; callers then show the label alone.
function Config.image(id: string): string
	local item = byId[id]
	return if item then NavigationAssetIds.resolve(id, Assets.resolve(item.assetKey)) else ""
end

return Config
