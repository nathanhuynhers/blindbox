--!strict
-- Native-part visual treatment for one plot transform and its dynamic owner entrance.
local Config = require(script.Parent.PlotConfig)
local Geometry = require(script.Parent.PlotGeometry)
local NightLights = require(script.Parent.NightLights)
local PlotStyle = require(script.Parent.PlotStyle)
local TownProps = require(script.Parent.TownProps)
local Fixture = {}
Fixture.palette = table.freeze({
	ivory = Color3.fromRGB(239, 236, 228),
	oak = Color3.fromRGB(198, 165, 120),
	floor = Color3.fromRGB(226, 203, 169),
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
Fixture.arch = table.freeze({
	z = -45.5,
	postX = 11.2,
	post = 1.4,
	postHeight = 14,
	beamHeight = 0.9,
	signBottom = 9.5,
	frameHeight = 4.2,
	deckHeight = 0.12,
	plantX = 15.5,
	lampOn = Color3.fromRGB(255, 214, 140),
})
-- Plot-local spawn pad on the open center/right floor (local -X is the right side from the entrance).
Fixture.spawnPad = table.freeze({ position = Vector3.new(-18, 0, -28), diameter = 9, height = 4 })
local palette, style = Fixture.palette, Fixture.style
export type Platform = { model: Model, parts: { [string]: Part } }
export type Entrance = {
	model: Model,
	parts: { [string]: Part },
	label: TextLabel,
	labels: { TextLabel },
	lights: { NightLights.Entry },
}
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
			PlotStyle.accent(nil),
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
			PlotStyle.accent(nil),
			Enum.Material.SmoothPlastic
		)
		endCap.CanCollide = false
		parts[endCap.Name] = endCap
	end
	-- Static potted plants flank every entrance, outside the arch posts and the path width.
	for _, side in { -1, 1 } do
		TownProps.pottedPlant(
			model,
			if side == -1 then "LeftPlanter" else "RightPlanter",
			transform * CFrame.new(side * Fixture.arch.plantX, 0, Fixture.arch.z)
		)
	end
	model.Parent = parent
	return { model = model, parts = parts }
end
-- Walk-through entrance arch. The posts stand outside the 16-stud path and the sign's underside
-- sits `signBottom` studs above the walking surface, so nothing in the doorway can be bumped into.
function Fixture.createEntrance(
	parent: Instance,
	transform: CFrame,
	displayName: string,
	accent: Color3?
): Entrance
	local model = Instance.new("Model")
	model.Name = "ShowroomEntrance"
	local parts: { [string]: Part } = {}
	local color = accent or PlotStyle.DefaultAccent
	local arch = Fixture.arch
	local z = arch.z
	parts.Deck = part(
		model,
		transform,
		"EntranceDeck",
		Vector3.new(style.entranceWidth, arch.deckHeight, style.entranceDepth),
		Vector3.new(0, arch.deckHeight / 2, z),
		palette.oak,
		Enum.Material.Wood
	)
	local signY = arch.signBottom + arch.frameHeight / 2
	for _, direction in { -1, 1 } do
		local prefix = if direction == -1 then "Left" else "Right"
		local x = direction * arch.postX
		local footing = part(
			model,
			transform,
			prefix .. "Footing",
			Vector3.new(2.2, 0.6, 2.2),
			Vector3.new(x, 0.3, z),
			palette.ivory,
			Enum.Material.SmoothPlastic
		)
		parts[footing.Name] = footing
		local post = part(
			model,
			transform,
			prefix .. "Post",
			Vector3.new(arch.post, arch.postHeight, arch.post),
			Vector3.new(x, arch.postHeight / 2, z),
			palette.oak,
			Enum.Material.Wood
		)
		parts[post.Name] = post
		local lamp = part(
			model,
			transform,
			prefix .. "Lamp",
			Vector3.new(1, 1, 1),
			Vector3.new(x, arch.postHeight + arch.beamHeight + 0.3, z),
			palette.sign,
			Enum.Material.SmoothPlastic
		)
		lamp.CanCollide = false
		lamp.CanQuery = false
		parts[lamp.Name] = lamp
	end
	parts.Beam = part(
		model,
		transform,
		"AccentBeam",
		Vector3.new(2 * arch.postX + arch.post + 1.2, arch.beamHeight, 1.8),
		Vector3.new(0, arch.postHeight + arch.beamHeight / 2 - 0.2, z),
		color,
		Enum.Material.SmoothPlastic
	)
	parts.Frame = part(
		model,
		transform,
		"SignFrame",
		Vector3.new(2 * arch.postX - arch.post, arch.frameHeight, 0.9),
		Vector3.new(0, signY, z),
		palette.oak,
		Enum.Material.Wood
	)
	parts.Face = part(
		model,
		transform,
		"SignFace",
		Vector3.new(2 * arch.postX - arch.post - 1, arch.frameHeight - 0.8, 1),
		Vector3.new(0, signY, z),
		palette.sign,
		Enum.Material.SmoothPlastic
	)
	for _, piece in parts do
		piece.CanTouch = false
	end
	local labels: { TextLabel } = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = if face == Enum.NormalId.Front then "ShowroomPlaque" else "ShowroomPlaqueInside"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(1000, 170)
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0.35
		gui.Parent = parts.Face
		local label = Instance.new("TextLabel")
		label.Name = "OwnerName"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04, 0.12)
		label.Size = UDim2.fromScale(0.92, 0.76)
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = palette.charcoal
		label.TextScaled = true
		label.Text = displayName .. "'s Showroom"
		label.Parent = gui
		table.insert(labels, label)
	end
	-- One sign glow plus the two post lamps, switched with the town's other dusk lights.
	local glow = Instance.new("SurfaceLight")
	glow.Name = "SignGlow"
	glow.Face = Enum.NormalId.Front
	glow.Color = Color3.fromRGB(255, 222, 170)
	glow.Brightness = 1.4
	glow.Range = 12
	glow.Angle = 100
	glow.Enabled = false
	glow.Parent = parts.Face
	local lights = {
		NightLights.add(glow, nil, nil),
		NightLights.add(nil, parts.LeftLamp, arch.lampOn),
		NightLights.add(nil, parts.RightLamp, arch.lampOn),
	}
	model.Parent = parent
	return { model = model, parts = parts, label = labels[1], labels = labels, lights = lights }
end

-- Flush, noncolliding spawn pad on the open center/right floor, clear of the arch and fixtures.
function Fixture.createSpawnPad(parent: Instance, transform: CFrame, accent: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "SpawnPad"
	local pad = Fixture.spawnPad
	local center = transform * CFrame.new(pad.position.X, 0, pad.position.Z)
	for index, ring in
		{
			{ diameter = pad.diameter, color = accent or PlotStyle.DefaultAccent },
			{ diameter = pad.diameter * 0.72, color = palette.sign },
			{ diameter = pad.diameter * 0.28, color = accent or PlotStyle.DefaultAccent },
		}
	do
		local height = 0.04 + 0.01 * index
		local disc = Geometry.partAt(
			model,
			"Ring_" .. index,
			Vector3.new(height, ring.diameter, ring.diameter),
			center * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			ring.color
		)
		disc.Shape = Enum.PartType.Cylinder
		disc.Material = Enum.Material.SmoothPlastic
		disc.CanCollide = false
		disc.CanQuery = false
		disc.CanTouch = false
	end
	model.Parent = parent
	return model
end

function Fixture.spawnCFrame(transform: CFrame): CFrame
	local at = Fixture.spawnPad.position
	return transform
		* CFrame.lookAt(
			Vector3.new(at.X, Fixture.spawnPad.height, at.Z),
			Vector3.new(0, Fixture.spawnPad.height, Geometry.displayZ)
		)
end

function Fixture.releaseEntrance(entrance: Entrance)
	for _, entry in entrance.lights do
		NightLights.release(entry)
	end
end
return Fixture
