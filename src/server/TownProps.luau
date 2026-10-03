--!strict
-- Native-part builders for Blindbox Town props. Each builder takes a ground-level CFrame whose
-- -Z faces the prop's front and returns a Model. All parts are anchored and never touch-enabled;
-- noncollidable decor is also excluded from spatial queries.
local Geometry = require(script.Parent.PlotGeometry)
local NightLights = require(script.Parent.NightLights)
local TownPlacements = require(script.Parent.TownPlacements)
local Style = require(script.Parent.TownStyle)
local Manifest = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)

local colors, materials = Style.colors, Style.materials
local TownProps = {}

TownProps.style = table.freeze({
	lantern = table.freeze({ height = 13, range = 18, brightness = 1.1 }),
	bollard = table.freeze({ width = 0.95, height = 3.3, range = 11, brightness = 0.65 }),
})

function TownProps.part(
	parent: Instance,
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean?
): Part
	local part = Geometry.partAt(parent, name, size, at, color)
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.CanCollide = collide ~= false
	part.CanQuery = collide ~= false
	return part
end

function TownProps.ball(
	parent: Instance,
	name: string,
	diameter: number,
	at: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean?
): Part
	local part = TownProps.part(
		parent,
		name,
		Vector3.new(diameter, diameter, diameter),
		at,
		color,
		material,
		collide
	)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Upright cylinder whose bottom face is centered on `base`.
function TownProps.cylinder(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	base: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean?
): Part
	local part = TownProps.part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		collide
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function model(parent: Instance, name: string): Model
	local object = Instance.new("Model")
	object.Name = name
	object.Parent = parent
	return object
end

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function TownProps.pastel(index: number): Color3
	return Style.pastels[(index - 1) % #Style.pastels + 1]
end

-- Canopy diameter `size`; trunks collide, canopies do not.
function TownProps.tree(
	parent: Instance,
	name: string,
	base: CFrame,
	size: number,
	blossom: boolean
): Model
	local tree = model(parent, name)
	local trunkHeight = 0.7 * size
	local leaf = if blossom then colors.blossom else colors.leaf
	TownProps.cylinder(
		tree,
		"Trunk",
		math.max(0.8, 0.16 * size),
		trunkHeight + 0.2 * size,
		base,
		colors.trunk,
		materials.wood
	)
	TownProps.ball(
		tree,
		"Canopy",
		size,
		base * CFrame.new(0, trunkHeight + 0.3 * size, 0),
		leaf,
		materials.foliage,
		false
	)
	TownProps.ball(
		tree,
		"CanopyPuff",
		0.62 * size,
		base * CFrame.new(0.28 * size, trunkHeight + 0.62 * size, -0.12 * size),
		lighter(leaf, 0.25),
		materials.foliage,
		false
	)
	return tree
end

-- A cube gift box resting on `base`, wrapped by two crossing ribbon bands.
function TownProps.giftBox(
	parent: Instance,
	name: string,
	base: CFrame,
	size: number,
	color: Color3,
	bow: boolean
): Model
	local box = model(parent, name)
	local center = base * CFrame.new(0, size / 2, 0)
	local ribbon = 0.18 * size
	TownProps.part(box, "Box", Vector3.new(size, size, size), center, color, materials.plastic)
	TownProps.part(
		box,
		"RibbonA",
		Vector3.new(ribbon, size + 0.12, size + 0.12),
		center,
		colors.ribbon,
		materials.plastic,
		false
	)
	TownProps.part(
		box,
		"RibbonB",
		Vector3.new(size + 0.08, size + 0.06, ribbon),
		center,
		colors.ribbon,
		materials.plastic,
		false
	)
	if bow then
		local top = base * CFrame.new(0, size + 0.06, 0)
		for _, side in { -1, 1 } do
			TownProps.part(
				box,
				"BowLoop",
				Vector3.new(0.34 * size, 0.2 * size, 0.9 * ribbon),
				top
					* CFrame.new(side * 0.15 * size, 0.08 * size, 0)
					* CFrame.Angles(0, 0, math.rad(side * 32)),
				colors.ribbon,
				materials.plastic,
				false
			)
		end
		TownProps.part(
			box,
			"BowKnot",
			Vector3.new(1.1 * ribbon, 1.1 * ribbon, 1.1 * ribbon),
			top * CFrame.new(0, 0.05 * size, 0),
			colors.ribbon,
			materials.plastic,
			false
		)
	end
	return box
end

-- Small floating neon diamond.
function TownProps.sparkle(parent: Instance, name: string, at: CFrame, size: number): Part
	return TownProps.part(
		parent,
		name,
		Vector3.new(size, size, size),
		at * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		colors.sparkle,
		materials.glow,
		false
	)
end

-- Giant gift-box stack: three oversized stacked boxes plus one tumbled box beside them.
function TownProps.boxStack(
	parent: Instance,
	name: string,
	base: CFrame,
	scale: number,
	first: number
): Model
	local stack = model(parent, name)
	local s1, s2, s3, s4 = 10 * scale, 7 * scale, 4.6 * scale, 5 * scale
	TownProps.giftBox(
		stack,
		"Bottom",
		base * CFrame.Angles(0, math.rad(8), 0),
		s1,
		TownProps.pastel(first),
		false
	)
	local second = base * CFrame.new(0.8 * scale, s1 + 0.06, -0.6 * scale)
	TownProps.giftBox(
		stack,
		"Middle",
		second * CFrame.Angles(0, math.rad(31), 0),
		s2,
		TownProps.pastel(first + 2),
		false
	)
	local third = base * CFrame.new(0.4 * scale, s1 + s2 + 0.12, -0.3 * scale)
	TownProps.giftBox(
		stack,
		"Top",
		third * CFrame.Angles(0, math.rad(-12), 0),
		s3,
		TownProps.pastel(first + 4),
		true
	)
	-- Resting on one bottom edge, rolled 25 degrees.
	local roll = math.rad(25)
	local lift = s4 / 2 * (math.cos(roll) + math.sin(roll)) - s4 / 2
	TownProps.giftBox(
		stack,
		"Tumbled",
		base
			* CFrame.new(9.5 * scale, 0, 2.5 * scale)
			* CFrame.Angles(0, math.rad(-24), 0)
			* CFrame.new(0, lift + s4 / 2, 0)
			* CFrame.Angles(0, 0, roll)
			* CFrame.new(0, -s4 / 2, 0),
		s4,
		TownProps.pastel(first + 1),
		false
	)
	TownProps.sparkle(
		stack,
		"Sparkle",
		third * CFrame.new(1.6 * scale, s3 + 2.4 * scale, 0),
		0.9 * scale
	)
	return stack
end

-- Small stack used behind each plot: three boxes, no bow.
function TownProps.smallStack(parent: Instance, name: string, base: CFrame, first: number): Model
	local stack = model(parent, name)
	TownProps.giftBox(
		stack,
		"Bottom",
		base * CFrame.Angles(0, math.rad(-6), 0),
		6,
		TownProps.pastel(first),
		false
	)
	TownProps.giftBox(
		stack,
		"Middle",
		base * CFrame.new(0.5, 6.06, 0.3) * CFrame.Angles(0, math.rad(22), 0),
		4.2,
		TownProps.pastel(first + 2),
		false
	)
	TownProps.giftBox(
		stack,
		"Beside",
		base * CFrame.new(5.6, 0, -1.2) * CFrame.Angles(0, math.rad(14), 0),
		2.8,
		TownProps.pastel(first + 4),
		false
	)
	return stack
end

-- Street lantern; its lens and PointLight switch on at dusk.
function TownProps.lantern(parent: Instance, name: string, base: CFrame): (Model, NightLights.Entry)
	local lantern = model(parent, name)
	TownProps.part(
		lantern,
		"Base",
		Vector3.new(1.3, 0.5, 1.3),
		base * CFrame.new(0, 0.25, 0),
		colors.iron,
		materials.metal
	)
	TownProps.part(
		lantern,
		"Post",
		Vector3.new(0.5, 10, 0.5),
		base * CFrame.new(0, 5.5, 0),
		colors.iron,
		materials.metal
	)
	local lens = TownProps.part(
		lantern,
		"Lens",
		Vector3.new(1.6, 2, 1.6),
		base * CFrame.new(0, 11.5, 0),
		colors.lensOff,
		materials.plastic,
		false
	)
	TownProps.part(
		lantern,
		"Cap",
		Vector3.new(2.4, 0.5, 2.4),
		base * CFrame.new(0, 12.75, 0),
		colors.iron,
		materials.metal,
		false
	)
	local light = Instance.new("PointLight")
	light.Name = "LanternLight"
	light.Color = colors.light
	light.Range = TownProps.style.lantern.range
	light.Brightness = TownProps.style.lantern.brightness
	light.Enabled = false
	light.Parent = lens
	return lantern, NightLights.add(light, lens, colors.lensOn)
end

-- Short path bollard, standing on `base` (ground level); its lens glows at night.
function TownProps.bollard(parent: Instance, name: string, base: CFrame): (Model, NightLights.Entry)
	local bollard = model(parent, name)
	local width = TownProps.style.bollard.width
	TownProps.part(
		bollard,
		"Base",
		Vector3.new(width, 0.25, width),
		base * CFrame.new(0, 0.125, 0),
		colors.ivory,
		materials.plastic
	)
	TownProps.part(
		bollard,
		"OakPost",
		Vector3.new(0.7, 2.25, 0.7),
		base * CFrame.new(0, 1.375, 0),
		colors.oak,
		materials.wood
	)
	local lens = TownProps.part(
		bollard,
		"WarmLens",
		Vector3.new(0.82, 0.65, 0.82),
		base * CFrame.new(0, 2.825, 0),
		colors.lensOff,
		materials.plastic,
		false
	)
	TownProps.part(
		bollard,
		"Cap",
		Vector3.new(width, 0.15, width),
		base * CFrame.new(0, 3.225, 0),
		colors.ivory,
		materials.plastic,
		false
	)
	local light = Instance.new("PointLight")
	light.Name = "WarmLight"
	light.Color = colors.light
	light.Range = TownProps.style.bollard.range
	light.Brightness = TownProps.style.bollard.brightness
	light.Enabled = false
	light.Parent = lens
	return bollard, NightLights.add(light, lens, colors.lensOn)
end

-- Bench facing -Z of `base`.
function TownProps.bench(parent: Instance, name: string, base: CFrame): Model
	local bench = model(parent, name)
	for _, side in { -1, 1 } do
		TownProps.part(
			bench,
			"Leg",
			Vector3.new(0.5, 1.5, 2),
			base * CFrame.new(side * 2.8, 0.75, 0),
			colors.iron,
			materials.metal
		)
	end
	TownProps.part(
		bench,
		"Seat",
		Vector3.new(7, 0.35, 2.2),
		base * CFrame.new(0, 1.675, 0),
		colors.oak,
		materials.wood
	)
	TownProps.part(
		bench,
		"Back",
		Vector3.new(7, 1.8, 0.35),
		base * CFrame.new(0, 2.85, 1.05) * CFrame.Angles(math.rad(-10), 0, 0),
		colors.oak,
		materials.wood
	)
	return bench
end

function TownProps.planter(
	parent: Instance,
	name: string,
	base: CFrame,
	blossom: boolean,
	seed: number?
): Model
	local planter = model(parent, name)
	TownProps.part(
		planter,
		"Planter",
		Vector3.new(5, 1.6, 5),
		base * CFrame.new(0, 0.8, 0),
		colors.stone,
		materials.stone
	)
	TownProps.part(
		planter,
		"Soil",
		Vector3.new(4.4, 0.1, 4.4),
		base * CFrame.new(0, 1.62, 0),
		colors.leafDark,
		materials.foliage,
		false
	)
	TownProps.townTree(
		planter,
		"Tree",
		base * CFrame.new(0, 1.6, 0),
		6,
		blossom,
		"planter",
		seed or 0
	)
	return planter
end

function TownProps.flowerBed(
	parent: Instance,
	name: string,
	base: CFrame,
	diameter: number,
	first: number
): Model
	local bed = model(parent, name)
	TownProps.cylinder(bed, "Rim", diameter, 0.4, base, colors.stone, materials.stone)
	TownProps.cylinder(bed, "Bed", diameter - 0.8, 0.5, base, colors.leafDark, materials.foliage)
	local ring = diameter / 2 - 1.4
	for index = 1, 5 do
		local angle = math.rad(index * 72)
		TownProps.ball(
			bed,
			"Flower",
			0.9,
			base * CFrame.new(math.cos(angle) * ring, 0.75, math.sin(angle) * ring),
			TownProps.pastel(first + index),
			materials.plastic,
			false
		)
	end
	return bed
end

-- Giant stylized blind-box figure on a two-tier pedestal, facing -Z of `base`.
function TownProps.statue(parent: Instance, name: string, base: CFrame, color: Color3): Model
	local statue = model(parent, name)
	TownProps.part(
		statue,
		"Pedestal",
		Vector3.new(12, 1.4, 12),
		base * CFrame.new(0, 0.7, 0),
		colors.ivory,
		materials.marble
	)
	TownProps.part(
		statue,
		"PedestalTop",
		Vector3.new(9, 1.2, 9),
		base * CFrame.new(0, 2, 0),
		colors.stone,
		materials.marble
	)
	local feet = base * CFrame.new(0, 2.6, 0)
	local shade = color:Lerp(Color3.new(0, 0, 0), 0.14)
	TownProps.cylinder(statue, "Body", 7, 6.5, feet, shade, materials.plastic)
	for _, side in { -1, 1 } do
		TownProps.ball(
			statue,
			"Arm",
			2.4,
			feet * CFrame.new(side * 3.7, 3.8, -1.2),
			shade,
			materials.plastic
		)
	end
	local head = feet * CFrame.new(0, 10.5, 0)
	TownProps.ball(statue, "Head", 11, head, color, materials.plastic)
	for _, side in { -1, 1 } do
		TownProps.ball(
			statue,
			"Ear",
			3.6,
			head * CFrame.new(side * 3.7, 4.6, 0),
			color,
			materials.plastic
		)
	end
	TownProps.ball(
		statue,
		"Face",
		7,
		head * CFrame.new(0, -0.4, -2.6),
		colors.face,
		materials.plastic
	)
	for _, side in { -1, 1 } do
		TownProps.ball(
			statue,
			"Eye",
			1.1,
			head * CFrame.new(side * 1.3, -0.1, -5.85),
			colors.eye,
			materials.plastic,
			false
		)
	end
	return statue
end

-- Terracotta pot with a rounded shrub, for plot entrances.
function TownProps.pottedPlant(parent: Instance, name: string, base: CFrame): Model
	local plant = model(parent, name)
	TownProps.cylinder(plant, "Pot", 2.8, 2.2, base, colors.pot, materials.plastic)
	TownProps.ball(
		plant,
		"Shrub",
		3.4,
		base * CFrame.new(0, 3.3, 0),
		colors.leaf,
		materials.foliage,
		false
	)
	TownProps.ball(
		plant,
		"Bloom",
		1.6,
		base * CFrame.new(0.6, 4.6, -0.4),
		colors.blossom,
		materials.foliage,
		false
	)
	return plant
end

-- ------------------------------------------------------------------ uploaded-model spots

-- Which uploaded model replaces a part tree at each kind of spot, and how it is sized from the
-- placeholder's canopy diameter: Sakura fits its canopy width, the green trees their height.
TownProps.treeModels = table.freeze({
	planter = table.freeze({ blossom = "Sakura", green = "Topiary" }),
	street = table.freeze({ blossom = "Sakura", green = "Puffball" }),
	frame = table.freeze({ blossom = "Sakura", green = "Puffball" }),
	edge = table.freeze({ blossom = "Sakura", green = "Poplar" }),
}) :: { [string]: { [string]: string } }
local treeFit: { [string]: { fit: TownPlacements.Fit, factor: number } } = {
	Sakura = { fit = "width", factor = 1.25 },
	Puffball = { fit = "height", factor = 1.5 },
	Poplar = { fit = "height", factor = 1.5 },
	Topiary = { fit = "height", factor = 1.0 },
}
TownProps.treeFit = table.freeze(treeFit)
-- Extra size for sakura with open ground around them. Framing sakura stay put (plot edges) and
-- plaza planters stay small (benches).
TownProps.sakuraBoost = table.freeze({ street = 1.6, edge = 1.35 }) :: { [string]: number }
TownProps.statueModels = table.freeze({ "PeekaPeekaboo", "PeekaTada", "PeekaHug", "PeekaNap" })
TownProps.statueWidth = 12

-- Deterministic turn (degrees) and size jitter (0.9-1.1) so neighbouring trees never match.
function TownProps.jitter(seed: number): (number, number)
	local yaw = (seed * 137.508) % 360
	local scale = 0.9 + ((seed * 0.6180339) % 1) * 0.2
	return yaw, scale
end

-- Soft pink disc of fallen petals on the grass under a sakura.
function TownProps.petalCarpet(parent: Instance, name: string, base: CFrame, diameter: number): Part
	local carpet = TownProps.cylinder(
		parent,
		name,
		diameter,
		0.04,
		base * CFrame.new(0, 0.005, 0),
		Color3.fromRGB(246, 201, 216),
		materials.plastic,
		false
	)
	carpet.CastShadow = false
	return carpet
end

-- Invisible volume under a sakura canopy that drops slowly drifting petals.
function TownProps.petalFall(
	parent: Instance,
	name: string,
	at: CFrame,
	width: number,
	height: number
): Part?
	local texture = Manifest.resolve(Manifest.Town.SakuraPetal)
	if texture == "" then
		return nil
	end
	local volume = TownProps.part(
		parent,
		name,
		Vector3.new(width * 0.8, height * 0.22, width * 0.36),
		at * CFrame.new(0, height * 0.62, 0),
		colors.blossom,
		materials.plastic,
		false
	)
	volume.Transparency = 1
	volume.CastShadow = false
	local petals = Instance.new("ParticleEmitter")
	petals.Name = "Petals"
	petals.Texture = texture
	petals.Rate = 2
	petals.Lifetime = NumberRange.new(5, 7)
	petals.Speed = NumberRange.new(0.3, 0.8)
	petals.SpreadAngle = Vector2.new(30, 30)
	petals.EmissionDirection = Enum.NormalId.Bottom
	petals.Acceleration = Vector3.new(0.5, -0.9, 0.2)
	petals.Drag = 0.6
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.Size = NumberSequence.new(0.45)
	petals.Shape = Enum.ParticleEmitterShape.Box
	petals.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	petals.Parent = volume
	return volume
end

-- A part-built placeholder tree that the uploaded model replaces when it loads.
function TownProps.townTree(
	parent: Instance,
	name: string,
	base: CFrame,
	size: number,
	blossom: boolean,
	role: string,
	seed: number
): Model
	local placeholder = TownProps.tree(parent, name, base, size, blossom)
	local kind = TownProps.treeModels[role][if blossom then "blossom" else "green"]
	local fit = TownProps.treeFit[kind]
	local yaw, scale = TownProps.jitter(seed)
	local at = base * CFrame.Angles(0, math.rad(yaw), 0)
	local boost = if kind == "Sakura" then TownProps.sakuraBoost[role] or 1 else 1
	local target = size * fit.factor * boost * scale
	TownPlacements.add(kind, at, target, fit.fit, placeholder)
	if kind == "Sakura" and role ~= "planter" then
		TownProps.petalCarpet(parent, name .. "Petals", base, target * 0.7)
		if role == "frame" then
			TownProps.petalFall(parent, name .. "PetalFall", at, target, target / 1.16)
		end
	end
	return placeholder
end

-- Ring of pastel blooms around a statue pedestal, hiding one warm uplight aimed at the statue.
function TownProps.statueGarden(parent: Instance, name: string, base: CFrame, first: number): Model
	local garden = model(parent, name)
	local ring = TownProps.statueWidth / 2 + 1
	for index = 1, 10 do
		local angle = math.rad(index * 36 + 18)
		TownProps.ball(
			garden,
			"Bloom",
			1.1,
			base * CFrame.new(math.cos(angle) * ring, 0.45, math.sin(angle) * ring),
			TownProps.pastel(first + index),
			materials.plastic,
			false
		)
	end
	local lamp = TownProps.part(
		garden,
		"Uplight",
		Vector3.new(0.6, 0.3, 0.6),
		CFrame.lookAt(
			(base * CFrame.new(0, 0.3, -ring)).Position,
			(base * CFrame.new(0, 9, 0)).Position
		),
		colors.iron,
		materials.metal,
		false
	)
	lamp.Transparency = 1
	local light = Instance.new("SpotLight")
	light.Name = "StatueUplight"
	light.Face = Enum.NormalId.Front
	light.Angle = 55
	light.Range = 22
	light.Brightness = 2
	light.Color = colors.light
	light.Enabled = false
	light.Parent = lamp
	NightLights.add(light, nil, nil)
	return garden
end

return TownProps
