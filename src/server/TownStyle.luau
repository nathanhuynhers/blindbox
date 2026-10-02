--!strict
-- Shared pastel palette and materials for Blindbox Town's static world (not plot fixtures).
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

return table.freeze({
	colors = table.freeze({
		grass = rgb(169, 207, 140),
		stone = rgb(207, 194, 176),
		soil = rgb(110, 84, 68),
		street = rgb(217, 205, 187),
		curb = rgb(189, 175, 156),
		plaza = rgb(244, 237, 226),
		plazaRim = rgb(220, 205, 184),
		path = rgb(241, 230, 211),
		oak = rgb(221, 179, 124),
		oakDark = rgb(185, 138, 87),
		ivory = rgb(252, 249, 243),
		iron = rgb(62, 59, 69),
		pot = rgb(199, 122, 87),
		leaf = rgb(134, 196, 110),
		leafDark = rgb(92, 156, 78),
		hedge = rgb(84, 145, 72),
		blossom = rgb(244, 185, 205),
		blossomDark = rgb(220, 140, 173),
		trunk = rgb(138, 100, 70),
		pink = rgb(238, 143, 181),
		pinkDark = rgb(222, 111, 156),
		ribbon = rgb(255, 241, 204),
		sparkle = rgb(255, 212, 94),
		glow = rgb(255, 236, 190),
		lensOff = rgb(246, 231, 200),
		lensOn = rgb(255, 214, 140),
		light = rgb(255, 214, 150),
		charcoal = rgb(59, 54, 51),
		eye = rgb(43, 37, 35),
		face = rgb(255, 244, 230),
		board = rgb(47, 74, 63),
		gold = rgb(226, 180, 94),
	}),
	-- Pastel collectible colors shared by gift boxes, statues and flowers.
	pastels = table.freeze({
		rgb(244, 169, 196),
		rgb(159, 212, 234),
		rgb(247, 208, 126),
		rgb(187, 169, 236),
		rgb(163, 220, 184),
		rgb(245, 180, 138),
	}),
	materials = table.freeze({
		grass = Enum.Material.Grass,
		stone = Enum.Material.Slate,
		plaza = Enum.Material.Pavement,
		street = Enum.Material.Cobblestone,
		path = Enum.Material.SmoothPlastic,
		wood = Enum.Material.Wood,
		plastic = Enum.Material.SmoothPlastic,
		foliage = Enum.Material.Grass,
		metal = Enum.Material.Metal,
		marble = Enum.Material.Marble,
		glow = Enum.Material.Neon,
	}),
})
