--!strict
local Config = require(script.Parent.PlotConfig)
local Geometry = require(script.Parent.PlotGeometry)
local PlotFixture = require(script.Parent.PlotFixture)
local World = {}

World.style = table.freeze({
	foundationDrop = 1.75,
	foundationThickness = 1,
	foundationMargin = 40,
	plazaTrimWidth = 2.5,
	plazaTrimHeight = 0.16,
	plazaTrimTopOffset = 0.01,
	plazaSurfaceHeight = 0.16,
	plazaSurfaceTopOffset = 0.03,
	pathSurfaceHeight = 0.12,
	pathTrimWidth = 0.55,
	pathTrimHeight = 0.1,
	pathTrimTopOffset = -0.02,
	bollardHeight = 3.8,
	bollardWidth = 0.95,
	bollardGap = 0.6,
	bollardBaseHeight = 0.25,
	bollardPostHeight = 2.75,
	bollardLightHeight = 0.65,
	bollardCapHeight = 0.15,
	bollardFractions = table.freeze({ 1 / 3, 2 / 3 }),
	lightBrightness = 0.65,
	lightRange = 11,
	colors = table.freeze({
		foundation = Color3.fromRGB(190, 183, 170),
		ivory = Color3.fromRGB(239, 236, 228),
		oak = Color3.fromRGB(198, 165, 120),
		light = Color3.fromRGB(255, 225, 180),
	}),
})

local style = World.style
local function finish(part: Part, material: Enum.Material): Part
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	return part
end

local function cylinder(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	y: number,
	color: Color3,
	material: Enum.Material
): Part
	local part = Geometry.partAt(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color
	)
	part.Shape = Enum.PartType.Cylinder
	return finish(part, material)
end

local function createWorldFoundation(parent: Instance): Part
	local outermostPlotCorner =
		math.sqrt((Config.plotRadius + Config.depth / 2) ^ 2 + (Config.width / 2) ^ 2)
	local radius = outermostPlotCorner + style.foundationMargin
	local top = Config.walkingY - style.foundationDrop
	return cylinder(
		parent,
		"WorldFoundation",
		2 * radius,
		style.foundationThickness,
		top - style.foundationThickness / 2,
		style.colors.foundation,
		Enum.Material.SmoothPlastic
	)
end

local function hideLegacyBaseplate()
	local instance = workspace:FindFirstChild("Baseplate")
	if not instance or not instance:IsA("BasePart") then
		return
	end
	local baseplate = instance :: BasePart
	local foundationTop = Config.walkingY - style.foundationDrop
	baseplate.Transparency = 1
	baseplate.Material = Enum.Material.SmoothPlastic
	baseplate.CanCollide = true
	baseplate.CanTouch = false
	baseplate.CanQuery = false
	baseplate.Position = Vector3.new(
		baseplate.Position.X,
		foundationTop - 4 - baseplate.Size.Y / 2,
		baseplate.Position.Z
	)
end

local function createPlaza(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "MainPlaza"
	local trimTop = Config.walkingY + style.plazaTrimTopOffset
	local surfaceTop = Config.walkingY + style.plazaSurfaceTopOffset
	cylinder(
		model,
		"OakTrim",
		2 * (Config.plazaRadius + style.plazaTrimWidth),
		style.plazaTrimHeight,
		trimTop - style.plazaTrimHeight / 2,
		style.colors.oak,
		Enum.Material.Wood
	)
	cylinder(
		model,
		"IvorySurface",
		2 * Config.plazaRadius,
		style.plazaSurfaceHeight,
		surfaceTop - style.plazaSurfaceHeight / 2,
		style.colors.ivory,
		Enum.Material.SmoothPlastic
	)
	model.Parent = parent
	return model
end

local function bollardPart(
	parent: Instance,
	transform: CFrame,
	name: string,
	size: Vector3,
	localX: number,
	localZ: number,
	bottom: number,
	color: Color3,
	material: Enum.Material
): Part
	return finish(
		Geometry.partAt(
			parent,
			name,
			size,
			transform * CFrame.new(localX, bottom + size.Y / 2, localZ),
			color
		),
		material
	)
end

local function createBollard(
	parent: Instance,
	transform: CFrame,
	name: string,
	localX: number,
	localZ: number
): Model
	local model = Instance.new("Model")
	model.Name = name
	local bottom = -style.foundationDrop
	bollardPart(
		model,
		transform,
		"Base",
		Vector3.new(0.95, style.bollardBaseHeight, 0.95),
		localX,
		localZ,
		bottom,
		style.colors.ivory,
		Enum.Material.SmoothPlastic
	)
	bottom += style.bollardBaseHeight
	bollardPart(
		model,
		transform,
		"OakPost",
		Vector3.new(0.7, style.bollardPostHeight, 0.7),
		localX,
		localZ,
		bottom,
		style.colors.oak,
		Enum.Material.Wood
	)
	bottom += style.bollardPostHeight
	local lens = bollardPart(
		model,
		transform,
		"WarmLens",
		Vector3.new(0.82, style.bollardLightHeight, 0.82),
		localX,
		localZ,
		bottom,
		style.colors.light,
		Enum.Material.SmoothPlastic
	)
	lens.CanCollide = false
	lens.Transparency = 0.08
	local light = Instance.new("PointLight")
	light.Name = "WarmLight"
	light.Color = style.colors.light
	light.Brightness = style.lightBrightness
	light.Range = style.lightRange
	light.Shadows = false
	light.Parent = lens
	bottom += style.bollardLightHeight
	local cap = bollardPart(
		model,
		transform,
		"Cap",
		Vector3.new(0.95, style.bollardCapHeight, 0.95),
		localX,
		localZ,
		bottom,
		style.colors.ivory,
		Enum.Material.SmoothPlastic
	)
	cap.CanCollide = false
	assert(
		math.abs(bottom + style.bollardCapHeight + style.foundationDrop - style.bollardHeight)
			< 0.0001,
		"Bollard segment heights must equal the configured total height"
	)
	model.Parent = parent
	return model
end

local function createPathLights(parent: Instance, transform: CFrame, length: number)
	local lateral = Config.pathWidth / 2
		+ style.pathTrimWidth
		+ style.bollardGap
		+ style.bollardWidth / 2
	for pair, fraction in style.bollardFractions do
		local localZ = (fraction - 0.5) * length
		for _, side in { -1, 1 } do
			createBollard(
				parent,
				transform,
				string.format("Bollard_%d_%s", pair, if side == -1 then "Left" else "Right"),
				side * lateral,
				localZ
			)
		end
	end
end

local function createPath(parent: Instance, index: number): Model
	local startRadius = Config.plazaRadius - Config.pathOverlap
	local entranceRadius = Config.plotRadius - Config.depth / 2
	local endRadius = entranceRadius + Config.pathOverlap
	local length = endRadius - startRadius
	local centerRadius = (startRadius + endRadius) / 2
	local transform = Geometry.radialTransform(index, centerRadius)
	local model = Instance.new("Model")
	model.Name = "Path_" .. index
	model:SetAttribute("PlotSlot", index)
	finish(
		Geometry.partAt(
			model,
			"WalkingSurface",
			Vector3.new(Config.pathWidth, style.pathSurfaceHeight, length),
			transform * CFrame.new(0, -style.pathSurfaceHeight / 2, 0),
			style.colors.ivory
		),
		Enum.Material.SmoothPlastic
	)
	local trimX = Config.pathWidth / 2 + style.pathTrimWidth / 2
	for _, side in { -1, 1 } do
		finish(
			Geometry.partAt(
				model,
				if side == -1 then "LeftOakTrim" else "RightOakTrim",
				Vector3.new(style.pathTrimWidth, style.pathTrimHeight, length),
				transform
					* CFrame.new(
						side * trimX,
						style.pathTrimTopOffset - style.pathTrimHeight / 2,
						0
					),
				style.colors.oak
			),
			Enum.Material.Wood
		)
	end
	createPathLights(model, transform, length)
	model.Parent = parent
	return model
end

function World.create(): Folder
	local root = Instance.new("Folder")
	root.Name = "MainWorld"
	hideLegacyBaseplate()
	createWorldFoundation(root)
	createPlaza(root)
	for index = 1, Config.maxPlots do
		createPath(root, index)
		PlotFixture.createPlatform(root, Geometry.transform(index), index)
	end
	root.Parent = workspace
	return root
end

return World
