--!strict
-- Central plaza: paved floor, the giant opening blind box, pop-up stalls, planters, the physical
-- leaderboard and the flush pre-assignment spawn. Every path mouth stays clear.
local Config = require(script.Parent.PlotConfig)
local Geometry = require(script.Parent.PlotGeometry)
local Layout = require(script.Parent.TownLayout)
local LeaderboardBoard = require(script.Parent.LeaderboardBoard)
local NightLights = require(script.Parent.NightLights)
local TownProps = require(script.Parent.TownProps)
local Style = require(script.Parent.TownStyle)

local colors, materials = Style.colors, Style.materials
local plaza, landmark = Layout.plaza, Layout.landmark
local Plaza = {}

export type Built = {
	model: Model,
	board: LeaderboardBoard.Board,
	spawn: SpawnLocation,
	lights: { NightLights.Entry },
}

local function disc(
	model: Model,
	name: string,
	radius: number,
	top: number,
	bottom: number,
	color: Color3,
	material: Enum.Material
): Part
	return TownProps.cylinder(
		model,
		name,
		2 * radius,
		top - bottom,
		CFrame.new(0, bottom, 0),
		color,
		material
	)
end

function Plaza.gapDegrees(gap: number): number
	return (gap - 1) * 360 / Config.maxPlots + Layout.gapAngle
end

local function questionMarks(body: Part)
	for _, face in
		{ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
	do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "QuestionMark"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		-- TextScaled caps glyphs at 100 px, so a small canvas lets the mark fill the face.
		gui.CanvasSize = Vector2.new(124, 110)
		gui.LightInfluence = 0.4
		gui.Parent = body
		local mark = Instance.new("TextLabel")
		mark.Name = "Mark"
		mark.BackgroundTransparency = 1
		mark.Position = UDim2.fromScale(0.15, 0.08)
		mark.Size = UDim2.fromScale(0.7, 0.84)
		mark.Font = Enum.Font.FredokaOne
		mark.Text = "?"
		mark.TextScaled = true
		mark.TextColor3 = Color3.new(1, 1, 1)
		mark.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = colors.pinkDark
		stroke.Thickness = 2.5
		stroke.Parent = mark
	end
end

-- Pastel pink box with "?" sides and a ribboned lid popping open on its back hinge.
local function giantBox(model: Model, ground: CFrame): NightLights.Entry
	local box = Instance.new("Model")
	box.Name = "GiantBlindBox"
	box.Parent = model
	TownProps.cylinder(
		box,
		"WoodenBase",
		2 * landmark.baseRadius,
		landmark.baseHeight,
		ground,
		colors.oak,
		materials.wood
	)
	TownProps.cylinder(
		box,
		"BaseInset",
		2 * (landmark.baseRadius - 1.2),
		landmark.baseHeight + 0.15,
		ground,
		colors.oakDark,
		materials.wood
	)
	local floor = ground * CFrame.new(0, landmark.baseHeight + 0.15, 0)
	local size = landmark.body
	local body = TownProps.part(
		box,
		"Body",
		size,
		floor * CFrame.new(0, size.Y / 2, 0),
		colors.pink,
		materials.plastic
	)
	questionMarks(body)
	local rim = floor * CFrame.new(0, size.Y, 0)
	local glow = TownProps.part(
		box,
		"InnerGlow",
		Vector3.new(size.X - 1.2, 0.1, size.Z - 1.2),
		rim * CFrame.new(0, 0.05, 0),
		colors.glow,
		materials.glow,
		false
	)
	local light = Instance.new("PointLight")
	light.Name = "BoxGlow"
	light.Color = colors.light
	light.Range = 24
	light.Brightness = 1.5
	light.Enabled = false
	light.Parent = glow
	-- Hinged on the back (+Z) top edge, front tipped up and lifted as if popping open.
	local lidSize = Vector3.new(
		size.X + 2 * landmark.lidOverhang,
		landmark.lidHeight,
		size.Z + 2 * landmark.lidOverhang
	)
	local lid = rim
		* CFrame.new(0, landmark.lidLift, size.Z / 2)
		* CFrame.Angles(math.rad(landmark.lidOpenDegrees), 0, 0)
		* CFrame.new(0, landmark.lidHeight / 2, -size.Z / 2)
	TownProps.part(box, "Lid", lidSize, lid, colors.pinkDark, materials.plastic)
	local ribbon = landmark.ribbonWidth
	TownProps.part(
		box,
		"LidRibbonA",
		Vector3.new(ribbon, lidSize.Y + 0.1, lidSize.Z + 0.2),
		lid,
		colors.ribbon,
		materials.plastic,
		false
	)
	TownProps.part(
		box,
		"LidRibbonB",
		Vector3.new(lidSize.X + 0.2, lidSize.Y + 0.06, ribbon),
		lid,
		colors.ribbon,
		materials.plastic,
		false
	)
	local bowBase = lid * CFrame.new(0, lidSize.Y / 2, 0)
	for _, side in { -1, 1 } do
		TownProps.part(
			box,
			"BowLoop",
			Vector3.new(3.8, 2.2, 2.4),
			bowBase * CFrame.new(side * 1.9, 0.9, 0) * CFrame.Angles(0, 0, math.rad(side * 30)),
			colors.ribbon,
			materials.plastic,
			false
		)
	end
	TownProps.part(
		box,
		"BowKnot",
		Vector3.new(2.2, 2.2, 2.2),
		bowBase * CFrame.new(0, 0.7, 0),
		colors.ribbon,
		materials.plastic,
		false
	)
	for index, sparkle in
		{
			{ at = Vector3.new(3, 5, -4), size = 1 },
			{ at = Vector3.new(-4.5, 3.5, -6), size = 0.8 },
			{ at = Vector3.new(7, 13, -12), size = 1.4 },
			{ at = Vector3.new(-8, 11, -13), size = 1.1 },
		}
	do
		TownProps.sparkle(box, "Sparkle_" .. index, rim * CFrame.new(sparkle.at), sparkle.size)
	end
	return NightLights.add(light, nil, nil)
end

local function spawnPad(model: Model, top: number): SpawnLocation
	local at =
		Geometry.polarTransform(Geometry.slotDegrees(plaza.spawnSlot), plaza.spawnRadius, top)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(plaza.spawnSize, 0.1, plaza.spawnSize)
	spawn.CFrame = at * CFrame.new(0, -0.03, 0)
	spawn.Color = colors.ribbon
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	-- This noncolliding marker routes spawns; the continuous plaza paving owns the surface.
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.Parent = model
	return spawn
end

function Plaza.create(parent: Instance): Built
	local model = Instance.new("Model")
	model.Name = "MainPlaza"
	local bottom = Layout.groundTop
	disc(
		model,
		"PlazaTrim",
		Config.plazaRadius + plaza.trimWidth,
		plaza.trimTop,
		bottom,
		colors.plazaRim,
		materials.stone
	)
	disc(
		model,
		"PlazaSurface",
		Config.plazaRadius,
		plaza.surfaceTop,
		bottom,
		colors.plaza,
		materials.plaza
	)
	disc(
		model,
		"InlayRing",
		plaza.inlayOuter,
		plaza.surfaceTop + 0.015,
		bottom,
		colors.plazaRim,
		materials.stone
	)
	disc(
		model,
		"InlayCenter",
		plaza.inlayInner,
		plaza.surfaceTop + 0.02,
		bottom,
		colors.plaza,
		materials.plaza
	)
	local top = plaza.surfaceTop + 0.02
	local lights = { giantBox(model, CFrame.new(0, top, 0)) }
	local board: LeaderboardBoard.Board? = nil
	local stalls = 0
	for gap, kind in plaza.gaps do
		local degrees = Plaza.gapDegrees(gap)
		if kind == "Stall" then
			stalls += 1
			local theme = Style.stalls[stalls]
			local _, entries = TownProps.stall(
				model,
				"Stall_" .. stalls,
				Geometry.polarTransform(degrees, plaza.furnitureRadius, plaza.surfaceTop),
				theme.body,
				theme.stripe
			)
			table.move(entries, 1, #entries, #lights + 1, lights)
		elseif kind == "Planter" then
			TownProps.planter(
				model,
				"Planter_" .. gap,
				Geometry.polarTransform(degrees, plaza.furnitureRadius, plaza.surfaceTop),
				gap % 4 == 0,
				300 + gap
			)
		elseif kind == "Leaderboard" then
			board = LeaderboardBoard.create(
				model,
				Geometry.polarTransform(degrees, plaza.leaderboardRadius, plaza.surfaceTop)
			)
		end
	end
	assert(board, "Plaza layout must place the leaderboard")
	local spawn = spawnPad(model, plaza.surfaceTop)
	model.Parent = parent
	return { model = model, board = board, spawn = spawn, lights = lights }
end

return Plaza
