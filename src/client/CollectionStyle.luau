--!strict
-- Collection art direction only. No prices, rates, odds or ownership live here.
local Style = {}
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
export type Style = {
	page: Color3,
	wash: Color3,
	cover: Color3,
	ink: Color3,
	accent: Color3,
	trim: Color3,
	motif: string,
}
local neutral: Style = {
	page = Color3.fromRGB(250, 249, 246),
	wash = Color3.fromRGB(233, 228, 243),
	cover = Color3.fromRGB(103, 92, 129),
	ink = Color3.fromRGB(49, 44, 62),
	accent = Color3.fromRGB(94, 83, 130),
	trim = Color3.fromRGB(204, 184, 142),
	motif = "spark",
}
Style.collections = {
	grove = {
		page = Color3.fromRGB(255, 246, 224),
		wash = Color3.fromRGB(224, 231, 193),
		cover = Color3.fromRGB(115, 86, 57),
		ink = Color3.fromRGB(74, 57, 41),
		accent = Color3.fromRGB(92, 122, 63),
		trim = Color3.fromRGB(207, 166, 98),
		motif = "leaf",
	},
	tide = {
		page = Color3.fromRGB(241, 251, 255),
		wash = Color3.fromRGB(188, 221, 242),
		cover = Color3.fromRGB(72, 110, 153),
		ink = Color3.fromRGB(44, 74, 106),
		accent = Color3.fromRGB(70, 113, 164),
		trim = Color3.fromRGB(234, 166, 158),
		motif = "shell",
	},
	concept = {
		page = Color3.fromRGB(250, 248, 232),
		wash = Color3.fromRGB(245, 245, 220),
		cover = Color3.fromRGB(139, 105, 20),
		ink = Color3.fromRGB(47, 47, 47),
		accent = Color3.fromRGB(212, 165, 32),
		trim = Color3.fromRGB(192, 167, 109),
		motif = "spark",
	},
} :: { [string]: Style }
function Style.get(id: string): Style
	return Style.collections[id] or neutral
end
Style.rarities = {} :: { [string]: Color3 }
for _, id in Rarity.order do
	Style.rarities[id] = Rarity.get(id).tint
end
function Style.rarity(name: string): Color3
	return Rarity.get(name).tint
end
return Style
