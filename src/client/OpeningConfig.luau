--!strict
local OpeningState = require(script.Parent.OpeningState)
local Config = {}
export type Profile = {
	tint: Color3,
	accent: Color3,
	timing: OpeningState.Timing,
	shake: number,
	particles: number,
	rings: number,
	sound: string,
}
export type Packaging = { base: Color3, lid: Color3, ribbon: Color3, ink: Color3 }

-- Presentation only. A future rarity is another profile; no controller branches or odds here.
Config.rarities = {
	Common = {
		tint = Color3.fromRGB(192, 227, 216),
		accent = Color3.fromRGB(245, 246, 224),
		timing = {
			anticipation = 0.32,
			shake = 0.65,
			opening = 0.48,
			silhouette = 0.32,
			reveal = 0.5,
		},
		shake = 0.065,
		particles = 8,
		rings = 1,
		sound = "",
	},
	Uncommon = {
		tint = Color3.fromRGB(178, 166, 255),
		accent = Color3.fromRGB(232, 218, 255),
		timing = {
			anticipation = 0.42,
			shake = 0.8,
			opening = 0.52,
			silhouette = 0.45,
			reveal = 0.6,
		},
		shake = 0.09,
		particles = 14,
		rings = 2,
		sound = "",
	},
	Rare = {
		tint = Color3.fromRGB(255, 204, 104),
		accent = Color3.fromRGB(255, 242, 199),
		timing = { anticipation = 0.58, shake = 1, opening = 0.6, silhouette = 0.65, reveal = 0.7 },
		shake = 0.12,
		particles = 22,
		rings = 3,
		sound = "",
	},
} :: { [string]: Profile }

Config.packaging = {
	grove = {
		base = Color3.fromRGB(218, 229, 192),
		lid = Color3.fromRGB(65, 108, 82),
		ribbon = Color3.fromRGB(245, 218, 150),
		ink = Color3.fromRGB(73, 121, 84),
	},
	tide = {
		base = Color3.fromRGB(194, 225, 234),
		lid = Color3.fromRGB(48, 105, 132),
		ribbon = Color3.fromRGB(242, 186, 164),
		ink = Color3.fromRGB(71, 146, 166),
	},
} :: { [string]: Packaging }

-- Insert original/licensed rbxassetid:// IDs. Empty IDs are intentionally silent.
Config.sounds = { entrance = "", shake = "", open = "", buildup = "", impact = "", discovery = "" }
Config.volume = 0.45

function Config.profile(rarity: string): Profile
	return Config.rarities[rarity] or Config.rarities.Common
end

return Config
