--!strict
-- Native-part visual treatment for one plot transform and its dynamic owner entrance.
local Config = require(script.Parent.PlotConfig)
local Geometry = require(script.Parent.PlotGeometry)
local Fixture = {}
Fixture.palette = table.freeze({
	ivory = Color3.fromRGB(239, 236, 228),
	oak = Color3.fromRGB(198, 165, 120),
	floor = Color3.fromRGB(226, 203, 169),
	accent = Color3.fromRGB(255, 226, 174),
	charcoal = Color3.fromRGB(48, 46, 43),
	sign = Color3.fromRGB(255, 246, 222),
})
Fixture.style = table.freeze({
	cornerRadius = 6,
	trimInset = 2,
	floorInset = 3,
	baseHeight = 0.22,
	trimHeight = 0.18,
	floorHeight = 0.1,
	accentThickness = 0.07,
	entranceWidth = 22,
	entranceDepth = 4.2,
})
local palette, style = Fixture.palette, Fixture.style
export type Platform = { model: Model, parts: { [string]: Part } }
export type Entrance = { model: Model, parts: { [string]: Part }, label: TextLabel }
local function part(
	parent: Instance,
	transform: CFrame,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local object = Geometry.partAt(parent, name, size, transform * CFrame.new(offset), color)
	object.Material = material
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.CanTouch = false
	return object
end
-- Six overlapping native parts create a reliable rounded rectangle without meshes or unions.
local function roundedBase(model: Model, transform: CFrame, parts: { [string]: Part })
	local radius = style.cornerRadius
	local height = style.baseHeight
	local y = -(style.trimHeight + style.floorHeight + height / 2)
	parts.BaseCenter = part(
		model,
		transform,
		"BaseCenter",
		Vector3.new(Config.width - 2 * radius, height, Config.depth),
		Vector3.new(0, y, 0),
		palette.ivory,
		Enum.Material.SmoothPlastic
	)
	parts.BaseCross = part(
		model,
		transform,
		"BaseCross",
		Vector3.new(Config.width, height, Config.depth - 2 * radius),
		Vector3.new(0, y, 0),
		palette.ivory,
		Enum.Material.SmoothPlastic
	)
	for xIndex, x in { -1, 1 } do
		for zIndex, z in { -1, 1 } do
			local name = string.format("BaseCorner_%d_%d", xIndex, zIndex)
			local at = transform
				* CFrame.new(x * (Config.width / 2 - radius), y, z * (Config.depth / 2 - radius))
				* CFrame.Angles(0, 0, math.rad(90))
			local corner = Geometry.partAt(
				model,
				name,
				Vector3.new(height, 2 * radius, 2 * radius),
				at,
				palette.ivory
			)
			corner.Material = Enum.Material.SmoothPlastic
			corner.TopSurface = Enum.SurfaceType.Smooth
			corner.BottomSurface = Enum.SurfaceType.Smooth
			corner.CanTouch = false
			corner.Shape = Enum.PartType.Cylinder
			parts[name] = corner
		end
	end
end
function Fixture.createPlatform(parent: Instance, transform: CFrame, index: number): Platform
	local model = Instance.new("Model")
	model.Name = "PlotSlot_" .. index
	model:SetAttribute("PlotSlot", index)
	local parts: { [string]: Part } = {}
	roundedBase(model, transform, parts)
	parts.OakTrim = part(
		model,
		transform,
		"OakTrim",
		Vector3.new(
			Config.width - 2 * style.trimInset,
			style.trimHeight,
			Config.depth - 2 * style.trimInset
		),
		Vector3.new(0, -(style.floorHeight + style.trimHeight / 2), 0),
		palette.oak,
		Enum.Material.Wood
	)
	parts.WalkingSurface = part(
		model,
		transform,
		"WalkingSurface",
		Vector3.new(
			Config.width - 2 * style.floorInset,
			style.floorHeight,
			Config.depth - 2 * style.floorInset
		),
		Vector3.new(0, -style.floorHeight / 2, 0),
		palette.floor,
		Enum.Material.WoodPlanks
	)
	local accentY = style.accentThickness / 2
	local insetX = Config.width / 2 - style.floorInset - 0.45
	local insetZ = Config.depth / 2 - style.floorInset - 0.45
	for _, edge in { -1, 1 } do
		local side = part(
			model,
			transform,
			if edge == -1 then "InnerAccentLeft" else "InnerAccentRight",
			Vector3.new(style.accentThickness, style.accentThickness, 2 * insetZ),
			Vector3.new(edge * insetX, accentY, 0),
			palette.accent,
			Enum.Material.SmoothPlastic
		)
		side.CanCollide = false
		parts[side.Name] = side
		local endCap = part(
			model,
			transform,
			if edge == -1 then "InnerAccentFront" else "InnerAccentBack",
			Vector3.new(2 * insetX, style.accentThickness, style.accentThickness),
			Vector3.new(0, accentY, edge * insetZ),
			palette.accent,
			Enum.Material.SmoothPlastic
		)
		endCap.CanCollide = false
		parts[endCap.Name] = endCap
	end
	model.Parent = parent
	return { model = model, parts = parts }
end
function Fixture.createEntrance(parent: Instance, transform: CFrame, displayName: string): Entrance
	local model = Instance.new("Model")
	model.Name = "ShowroomEntrance"
	local parts: { [string]: Part } = {}
	local front = -Config.depth / 2 + style.entranceDepth / 2 + 0.2
	parts.Deck = part(
		model,
		transform,
		"EntranceDeck",
		Vector3.new(style.entranceWidth, 0.15, style.entranceDepth),
		Vector3.new(0, 0.075, front),
		palette.oak,
		Enum.Material.Wood
	)
	parts.Frame = part(
		model,
		transform,
		"PlaqueFrame",
		Vector3.new(17.8, 2.8, 0.55),
		Vector3.new(0, 1.55, -Config.depth / 2 + 0.65),
		palette.oak,
		Enum.Material.Wood
	)
	parts.Face = part(
		model,
		transform,
		"PlaqueFace",
		Vector3.new(17.15, 2.15, 0.12),
		Vector3.new(0, 1.55, -Config.depth / 2 + 0.31),
		palette.sign,
		Enum.Material.SmoothPlastic
	)
	for _, direction in { -1, 1 } do
		local post = part(
			model,
			transform,
			if direction == -1 then "LeftPost" else "RightPost",
			Vector3.new(2.1, 3.2, 2.1),
			Vector3.new(direction * 10, 1.6, -Config.depth / 2 + 1.15),
			palette.oak,
			Enum.Material.Wood
		)
		parts[post.Name] = post
		local cap = part(
			model,
			transform,
			if direction == -1 then "LeftWarmCap" else "RightWarmCap",
			Vector3.new(1.45, 0.55, 1.45),
			Vector3.new(direction * 10, 3.475, -Config.depth / 2 + 1.15),
			palette.accent,
			Enum.Material.SmoothPlastic
		)
		cap.CanCollide = false
		parts[cap.Name] = cap
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ShowroomPlaque"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1000, 150)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0.35
	gui.Parent = parts.Face
	local label = Instance.new("TextLabel")
	label.Name = "OwnerName"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.04, 0.12)
	label.Size = UDim2.fromScale(0.92, 0.76)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = palette.charcoal
	label.TextScaled = true
	label.Text = displayName .. "'s Showroom"
	label.Parent = gui
	model.Parent = parent
	return { model = model, parts = parts, label = label }
end
return Fixture
