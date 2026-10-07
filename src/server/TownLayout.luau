--!strict
-- Blindbox Town layout. Every radius is measured from the plaza center; angles are relative to
-- plot slot 1. Gaps sit halfway between neighboring plot axes. Plot geometry stays in PlotConfig.
local Config = require(script.Parent.PlotConfig)

local groundTop = Config.walkingY - 0.5
local gapAngle = 180 / Config.maxPlots

return table.freeze({
	-- Grass top. Plot platforms (0.5 studs thick) rest on it; paths and plaza fill down to it.
	groundTop = groundTop,
	gapAngle = gapAngle,
	ground = table.freeze({ radius = 276, thickness = 2, curbRadius = 279, curbDepth = 4 }),
	soil = table.freeze({ radius = 283, top = groundTop - 4, thickness = 3 }),
	plaza = table.freeze({
		trimWidth = 2.5,
		trimTop = Config.walkingY + 0.01,
		surfaceTop = Config.walkingY + 0.03,
		inlayOuter = 27,
		inlayInner = 25,
		-- Gap contents clockwise from the gap after plot slot 1. Path mouths stay open.
		gaps = table.freeze({
			"Bench",
			"Planter",
			"Bench",
			"Planter",
			"Bench",
			"Planter",
			"Leaderboard",
			"Planter",
		}),
		furnitureRadius = 44,
		leaderboardRadius = 45,
		-- Flush pre-assignment spawn beside the leaderboard, on plot slot 8's path axis.
		spawnSlot = Config.maxPlots,
		spawnRadius = 31,
		spawnSize = 7,
	}),
	landmark = table.freeze({
		baseRadius = 16,
		baseHeight = 1.2,
		body = Vector3.new(18, 16, 18),
		lidHeight = 3,
		lidOverhang = 1.2,
		lidOpenDegrees = 24,
		lidLift = 1.6,
		ribbonWidth = 2.6,
	}),
	path = table.freeze({
		trimWidth = 0.55,
		trimTopOffset = -0.02,
		bollardRadii = table.freeze({ 62, 116 }),
		bollardGap = 0.6,
	}),
	street = table.freeze({
		radius = 99,
		width = 14,
		curbWidth = 16,
		segments = 32,
		top = Config.walkingY + 0.04,
		curbTop = Config.walkingY + 0.02,
		-- Alternate segments are raised by this much so overlapping joints never z-fight.
		stagger = 0.005,
		lanternRadii = table.freeze({ 88.5, 109.5 }),
	}),
	gaps = table.freeze({
		innerTreeRadius = 122,
		flowerBedRadius = 146,
		flowerBedDiameter = 8,
		featureRadius = 196,
		framingTreeRadius = 212,
		framingTreeOffset = 4.5,
	}),
	edge = table.freeze({
		plotStackRadius = 238,
		treeRadius = 250,
		treeOffsets = table.freeze({ -7.5, 7.5, gapAngle }),
		hedgeRadius = 264,
		hedgeSegments = 48,
		hedgeHeight = 4.5,
		hedgeThickness = 4,
		wallRadius = 268,
		wallSegments = 32,
		wallHeight = 60,
	}),
	-- Measured totals are asserted by the plot spec; these are the ceilings.
	-- Six collection plates add twelve parts per active plot; world/light budgets are unchanged.
	-- The plot Shop adds 19 kiosk parts and an 8-part Peeka stand-in: 180 measured with click
	-- targets (was 153). The uploaded shopkeeper replacing the stand-in is mesh geometry, excluded
	-- like figures; the Shop adds no lights.
	budgets = table.freeze({ worldParts = 1100, plotRuntimeParts = 184, nightLights = 64 }),
})
