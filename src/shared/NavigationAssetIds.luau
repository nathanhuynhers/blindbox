--!strict
-- Paste the five Roblox Image asset IDs here after Creator Hub or Studio finishes
-- importing and moderating the PNGs. Use digits only; do not add rbxassetid://.
-- Empty strings are intentional and never resolve to placeholder artwork.
local ids: { [string]: string } = {
	Collection = "85346109397714",
	Display = "75697262694573",
	Shop = "87174083809871",
	Goals = "103904988883870",aaaaaa
	Shelves = "105035552322317",
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
