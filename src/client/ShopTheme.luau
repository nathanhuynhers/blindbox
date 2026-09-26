--!strict
local Manifest = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)

local ShopTheme = {}
export type Theme = {
	collectionId: string,
	emblemKey: string,
	patternKey: string,
	primary: Color3,
	secondary: Color3,
	wash: Color3,
	ink: Color3,
	trim: Color3,
}

local neutral: Theme = {
	collectionId = "",
	emblemKey = "",
	patternKey = "",
	primary = Color3.fromRGB(151, 126, 91),
	secondary = Color3.fromRGB(224, 198, 146),
	wash = Color3.fromRGB(248, 241, 225),
	ink = Color3.fromRGB(67, 50, 37),
	trim = Color3.fromRGB(205, 160, 88),
}

ShopTheme.collections = {
	grove = {
		collectionId = "grove",
		emblemKey = Manifest.Collection.PocketGrove.Emblem,
		patternKey = Manifest.Collection.PocketGrove.ShopPattern,
		primary = Color3.fromRGB(100, 132, 75),
		secondary = Color3.fromRGB(217, 196, 135),
		wash = Color3.fromRGB(238, 239, 207),
		ink = Color3.fromRGB(67, 73, 45),
		trim = Color3.fromRGB(203, 161, 86),
	},
	tide = {
		collectionId = "tide",
		emblemKey = Manifest.Collection.TidepoolTales.Emblem,
		patternKey = Manifest.Collection.TidepoolTales.ShopPattern,
		primary = Color3.fromRGB(65, 161, 190),
		secondary = Color3.fromRGB(238, 158, 146),
		wash = Color3.fromRGB(218, 240, 241),
		ink = Color3.fromRGB(42, 80, 99),
		trim = Color3.fromRGB(220, 180, 116),
	},
} :: { [string]: Theme }

function ShopTheme.get(collectionId: string): Theme
	return ShopTheme.collections[collectionId] or neutral
end

return ShopTheme
