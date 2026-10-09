--!strict
-- Paste the navigation Roblox Image asset IDs here after Creator Hub or Studio finishes
-- importing and moderating the PNGs. Use digits only; do not add rbxassetid://.
-- Empty strings fall back to the asset pipeline's generated ID (AssetIds), and never to
-- placeholder artwork. Daily and Home (HUD) were uploaded through that pipeline.
local ids: { [string]: string } = {
	Collection = "85346109397714",
	Display = "75697262694573",
	Shop = "87174083809871",
	Goals = "103904988883870",
	Shelves = "105035552322317",
	Daily = "",
	Home = "",
}

local NavigationAssetIds = { ids = ids }

function NavigationAssetIds.resolve(name: string, generated: string): string
	local id = ids[name]
	if id and string.match(id, "^[1-9]%d*$") then
		return "rbxassetid://" .. id
	end
	return generated
end

return NavigationAssetIds
