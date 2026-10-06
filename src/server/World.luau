--!strict
-- Blindbox Town static world: grass island, plaza, eight entry paths, Market Street, decorated
-- gaps between plots, the outer hedge/tree edge and invisible boundary walls. Built once per server.
local Config = require(script.Parent.PlotConfig)
local Geometry = require(script.Parent.PlotGeometry)
local Layout = require(script.Parent.TownLayout)
local LeaderboardBoard = require(script.Parent.LeaderboardBoard)
local NightLights = require(script.Parent.NightLights)
local PlazaFixture = require(script.Parent.PlazaFixture)
local PlotFixture = require(script.Parent.PlotFixture)
local TownPlacements = require(script.Parent.TownPlacements)
local TownProps = require(script.Parent.TownProps)
local Style = require(script.Parent.TownStyle)
local World = {}

local colors, materials = Style.colors, Style.materials
local groundTop = Layout.groundTop

export type Built = {
	root: Folder,
	board: LeaderboardBoard.Board,
	spawn: SpawnLocation,
	lights: { NightLights.Entry },
}

local function folder(parent: Instance, name: string): Folder
	local object = Instance.new("Folder")
	object.Name = name
	object.Parent = parent
	return object
end

local function createGround(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Ground"
	local ground, soil = Layout.ground, Layout.soil
	TownProps.cylinder(
		model,
		"Grass",
		2 * ground.radius,
		ground.thickness,
		CFrame.new(0, groundTop - ground.thickness, 0),
		colors.grass,
		materials.grass
	)
	TownProps.cylinder(
		model,
		"StoneCurb",
		2 * ground.curbRadius,
		ground.curbDepth,
		CFrame.new(0, groundTop - 0.05 - ground.curbDepth, 0),
		colors.stone,
		materials.stone
	)
	TownProps.cylinder(
		model,
		"Soil",
		2 * soil.radius,
		soil.thickness,
		CFrame.new(0, soil.top - soil.thickness, 0),
		colors.soil,
		materials.grass
	)
	model.Parent = parent
end

-- An existing Studio place may still contain a Baseplate; keep it only as a hidden failsafe floor.
local function hideLegacyBaseplate()
	local instance = workspace:FindFirstChild("Baseplate")
	if not instance or not instance:IsA("BasePart") then
		return
	end
	local baseplate = instance :: BasePart
	baseplate.Transparency = 1
	baseplate.Material = Enum.Material.SmoothPlastic
	baseplate.CanCollide = true
	baseplate.CanTouch = false
	baseplate.CanQuery = false
	baseplate.Position = Vector3.new(
		baseplate.Position.X,
		Layout.soil.top - Layout.soil.thickness - 4 - baseplate.Size.Y / 2,
		baseplate.Position.Z
	)
end

local function createPath(parent: Instance, index: number, lights: { NightLights.Entry })
	local path = Layout.path
	local startRadius = Config.plazaRadius - Config.pathOverlap
	local endRadius = Config.plotRadius - Config.depth / 2 + Config.pathOverlap
	local length = endRadius - startRadius
	local transform = Geometry.radialTransform(index, (startRadius + endRadius) / 2, groundTop)
	local model = Instance.new("Model")
	model.Name = "Path_" .. index
	model:SetAttribute("PlotSlot", index)
	-- 0.01 below the plot floor so the overlapping path end never z-fights with it.
	local height = Config.walkingY - 0.01 - groundTop
	TownProps.part(
		model,
		"WalkingSurface",
		Vector3.new(Config.pathWidth, height, length),
		transform * CFrame.new(0, height / 2, 0),
		colors.path,
		materials.path
	)
	local trimHeight = height + path.trimTopOffset
	for _, side in { -1, 1 } do
		TownProps.part(
			model,
			if side == -1 then "LeftOakTrim" else "RightOakTrim",
			Vector3.new(path.trimWidth, trimHeight, length),
			transform
				* CFrame.new(side * (Config.pathWidth / 2 + path.trimWidth / 2), trimHeight / 2, 0),
			colors.oak,
			materials.wood
		)
	end
	local lateral = Config.pathWidth / 2
		+ path.trimWidth
		+ path.bollardGap
		+ TownProps.style.bollard.width / 2
	for pair, radius in path.bollardRadii do
		local at = Geometry.radialTransform(index, radius, groundTop)
		for _, side in { -1, 1 } do
			local _, entry = TownProps.bollard(
				model,
				string.format("Bollard_%d_%s", pair, if side == -1 then "Left" else "Right"),
				at * CFrame.new(side * lateral, 0, 0)
			)
			table.insert(lights, entry)
		end
	end
	model.Parent = parent
end

-- Market Street: a polygonal cobbled ring over a slightly wider, lower curb ring. Segment centers
-- sit on path axes; alternate segments are staggered vertically so overlapping joints never z-fight.
local function createStreet(parent: Instance, lights: { NightLights.Entry })
	local street = Layout.street
	local model = Instance.new("Model")
	model.Name = "MarketStreet"
	local step = 360 / street.segments
	local half = math.tan(math.pi / street.segments)
	for segment = 1, street.segments do
		local degrees = (segment - 1) * step
		local raise = if segment % 2 == 0 then street.stagger else 0
		for _, layer in
			{
				{
					name = "Curb",
					width = street.curbWidth,
					top = street.curbTop,
					color = colors.curb,
					material = materials.stone,
				},
				{
					name = "Cobbles",
					width = street.width,
					top = street.top,
					color = colors.street,
					material = materials.street,
				},
			}
		do
			local top = layer.top + raise
			local length = 2 * (street.radius + layer.width / 2) * half + 0.05
			TownProps.part(
				model,
				layer.name .. "_" .. segment,
				Vector3.new(length, top - groundTop, layer.width),
				Geometry.polarTransform(degrees, street.radius, groundTop + (top - groundTop) / 2),
				layer.color,
				layer.material
			)
		end
	end
	for gap = 1, Config.maxPlots do
		for side, radius in street.lanternRadii do
			local _, entry = TownProps.lantern(
				model,
				string.format("Lantern_%d_%d", gap, side),
				Geometry.polarTransform(PlazaFixture.gapDegrees(gap), radius, groundTop)
			)
			table.insert(lights, entry)
		end
	end
	model.Parent = parent
end

-- Gaps alternate giant gift-box stacks and statue gardens, framed by trees and a flower bed.
local function createGaps(parent: Instance)
	local gaps = Layout.gaps
	for gap = 1, Config.maxPlots do
		local degrees = PlazaFixture.gapDegrees(gap)
		local model = Instance.new("Model")
		model.Name = "Gap_" .. gap
		TownProps.townTree(
			model,
			"InnerTree",
			Geometry.polarTransform(degrees, gaps.innerTreeRadius, groundTop),
			7,
			gap % 2 == 0,
			"street",
			gap
		)
		TownProps.flowerBed(
			model,
			"FlowerBed",
			Geometry.polarTransform(degrees, gaps.flowerBedRadius, groundTop),
			gaps.flowerBedDiameter,
			gap
		)
		local feature = Geometry.polarTransform(degrees, gaps.featureRadius, groundTop)
		if gap % 2 == 1 then
			TownProps.boxStack(model, "GiftBoxStack", feature, 1, gap)
		else
			local statue = TownProps.statue(model, "Statue", feature, TownProps.pastel(gap))
			TownPlacements.add(
				TownProps.statueModels[gap // 2],
				feature,
				TownProps.statueWidth,
				"width",
				statue
			)
			TownProps.statueGarden(model, "StatueGarden", feature, gap)
		end
		for side, offset in { -gaps.framingTreeOffset, gaps.framingTreeOffset } do
			TownProps.townTree(
				model,
				"FramingTree_" .. side,
				Geometry.polarTransform(degrees + offset, gaps.framingTreeRadius, groundTop),
				11,
				side == 1,
				"frame",
				100 + gap * 2 + side
			)
		end
		model.Parent = parent
	end
end

local function createEdge(parent: Instance)
	local edge = Layout.edge
	local model = Instance.new("Model")
	model.Name = "GardenEdge"
	for index = 1, Config.maxPlots do
		local degrees = Geometry.slotDegrees(index)
		TownProps.smallStack(
			model,
			"PlotBoxStack_" .. index,
			Geometry.polarTransform(degrees, edge.plotStackRadius, groundTop),
			index + 2
		)
		for side, offset in edge.treeOffsets do
			TownProps.townTree(
				model,
				string.format("EdgeTree_%d_%d", index, side),
				Geometry.polarTransform(degrees + offset, edge.treeRadius, groundTop),
				if side == 3 then 15 else 12,
				(index + side) % 2 == 0,
				"edge",
				200 + index * 3 + side
			)
		end
	end
	local hedgeLength = 2
			* (edge.hedgeRadius + edge.hedgeThickness / 2)
			* math.tan(math.pi / edge.hedgeSegments)
		+ 0.1
	for segment = 1, edge.hedgeSegments do
		TownProps.part(
			model,
			"Hedge_" .. segment,
			Vector3.new(hedgeLength, edge.hedgeHeight, edge.hedgeThickness),
			Geometry.polarTransform(
				(segment - 1) * 360 / edge.hedgeSegments,
				edge.hedgeRadius,
				groundTop + edge.hedgeHeight / 2
			),
			colors.hedge,
			materials.foliage
		)
	end
	-- Invisible walls just behind the hedge keep players on the island.
	local wallLength = 2 * (edge.wallRadius + 1) * math.tan(math.pi / edge.wallSegments) + 0.2
	for segment = 1, edge.wallSegments do
		local wall = TownProps.part(
			model,
			"BoundaryWall_" .. segment,
			Vector3.new(wallLength, edge.wallHeight, 2),
			Geometry.polarTransform(
				(segment - 1) * 360 / edge.wallSegments,
				edge.wallRadius,
				groundTop + edge.wallHeight / 2
			),
			colors.hedge,
			Enum.Material.SmoothPlastic
		)
		wall.Transparency = 1
		wall.CastShadow = false
	end
	model.Parent = parent
end

function World.create(): Built
	local root = Instance.new("Folder")
	root.Name = "MainWorld"
	TownPlacements.clear()
	-- Rojo preserves this loose import in older places; it is not a collectible template.
	for _, instance in workspace:GetChildren() do
		if instance.Name == "EXPORT_PebblePip" and instance:IsA("Model") then
			instance:Destroy()
		end
	end
	hideLegacyBaseplate()
	createGround(root)
	local plaza = PlazaFixture.create(root)
	local lights = table.clone(plaza.lights)
	local paths = folder(root, "Paths")
	local plots = folder(root, "PlotSlots")
	for index = 1, Config.maxPlots do
		createPath(paths, index, lights)
		PlotFixture.createPlatform(plots, Geometry.transform(index), index)
	end
	createStreet(root, lights)
	createGaps(folder(root, "Gaps"))
	createEdge(root)
	root.Parent = workspace
	return { root = root, board = plaza.board, spawn = plaza.spawn, lights = lights }
end

return World
