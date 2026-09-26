--!strict
-- Public asset IDs only. Uploading registers artwork; UI adoption is a separate explicit change.
local Ids = require(script.Parent.AssetIds)
local Manifest = {}
export type CollectionKeys = {
	Emblem: string,
	ShopPattern: string,
	CornerTopLeft: string,
	CornerTopRight: string,
	CornerBottomLeft: string,
	CornerBottomRight: string,
}

function Manifest.resolve(key: string): string
	local id = Ids[key]
	return if id and string.match(id, "^[1-9]%d*$") then "rbxassetid://" .. id else ""
end

Manifest.Collection = {
	BookOpen = "Collection.BookOpen",
	PocketGrove = {
		Emblem = "Collection.PocketGrove.Emblem",
		ShopPattern = "Collection.PocketGrove.ShopPattern",
		CornerTopLeft = "Collection.PocketGrove.CornerTopLeft",
		CornerTopRight = "Collection.PocketGrove.CornerTopRight",
		CornerBottomLeft = "Collection.PocketGrove.CornerBottomLeft",
		CornerBottomRight = "Collection.PocketGrove.CornerBottomRight",
	},
	TidepoolTales = {
		Emblem = "Collection.TidepoolTales.Emblem",
		ShopPattern = "Collection.TidepoolTales.ShopPattern",
		CornerTopLeft = "Collection.TidepoolTales.CornerTopLeft",
		CornerTopRight = "Collection.TidepoolTales.CornerTopRight",
		CornerBottomLeft = "Collection.TidepoolTales.CornerBottomLeft",
		CornerBottomRight = "Collection.TidepoolTales.CornerBottomRight",
	},
}
Manifest.Global = { IconCollection = "Global.IconCollection" }
Manifest.Models = { BlindBoxBase = "Models.BlindBoxBase" }

return Manifest
