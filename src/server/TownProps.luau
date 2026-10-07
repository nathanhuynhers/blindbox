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
	bow: boolean,
	ribbonColor: Color3?
): Model
	local box = model(parent, name)
	local center = base * CFrame.new(0, size / 2, 0)
	local ribbon = 0.18 * size
	local tie = ribbonColor or colors.ribbon
	TownProps.part(box, "Box", Vector3.new(size, size, size), center, color, materials.plastic)
	TownProps.part(
		box,
		"RibbonA",
		Vector3.new(ribbon, size + 0.12, size + 0.12),
		center,
		tie,
		materials.plastic,
		false
	)
	TownProps.part(
		box,
		"RibbonB",
		Vector3.new(size + 0.08, size + 0.06, ribbon),
		center,
		tie,
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
				tie,
				materials.plastic,
				false
			)
		end
		TownProps.part(
			box,
			"BowKnot",
			Vector3.new(1.1 * ribbon, 1.1 * ribbon, 1.1 * ribbon),
			top * CFrame.new(0, 0.05 * size, 0),
			tie,
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

-- ------------------------------------------------------------------ plaza pop-up stalls

local sideFaces =
	{ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

local function surface(part: BasePart, face: Enum.NormalId, name: string): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part
	return gui
end

local function patch(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	color: Color3,
	round: boolean?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.Position = position
	frame.Size = size
	frame.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
	return frame
end

local function faceWidth(part: BasePart, face: Enum.NormalId): number
	return if face == Enum.NormalId.Left or face == Enum.NormalId.Right
		then part.Size.Z
		else part.Size.X
end

-- Odd count of `band`-wide stripes on the four side faces, accent at both ends; `rings` runs them
-- around the part (candy pole) instead of top to bottom (canopy).
local function stripes(part: BasePart, color: Color3, band: number, rings: boolean)
	for _, face in sideFaces do
		local length = if rings then part.Size.Y else faceWidth(part, face)
		local count = math.max(3, math.floor(length / band / 2) * 2 + 1)
		local gui = surface(part, face, "Stripes")
		for index = 1, count, 2 do
			local from = (index - 1) / count
			if rings then
				patch(gui, "Stripe", UDim2.fromScale(0, from), UDim2.fromScale(1, 1 / count), color)
			else
				patch(gui, "Stripe", UDim2.fromScale(from, 0), UDim2.fromScale(1 / count, 1), color)
			end
		end
	end
end

-- Row of alternating accent/ivory scallops along an invisible hem part's side faces.
local function scallops(hem: BasePart, color: Color3)
	for _, face in sideFaces do
		local count = math.floor(faceWidth(hem, face) / hem.Size.Y)
		local gui = surface(hem, face, "Scallops")
		for index = 1, count do
			patch(
				gui,
				"Scallop",
				UDim2.fromScale((index - 1) / count, 0),
				UDim2.fromScale(1 / count, 1),
				if index % 2 == 1 then color else colors.ivory,
				true
			)
		end
	end
end

-- Rim, cross spokes and hub drawn on both caps of a cylinder wheel.
local function spokes(wheel: BasePart)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = surface(wheel, face, "Spokes")
		local rim = patch(
			gui,
			"Rim",
			UDim2.fromScale(0.14, 0.14),
			UDim2.fromScale(0.72, 0.72),
			colors.oak,
			true
		)
		rim.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = colors.oakDark
		stroke.Thickness = 4
		stroke.Parent = rim
		patch(
			gui,
			"Spoke",
			UDim2.fromScale(0.46, 0.14),
			UDim2.fromScale(0.08, 0.72),
			colors.oakDark
		)
		patch(
			gui,
			"Spoke",
			UDim2.fromScale(0.14, 0.46),
			UDim2.fromScale(0.72, 0.08),
			colors.oakDark
		)
		patch(
			gui,
			"Hub",
			UDim2.fromScale(0.39, 0.39),
			UDim2.fromScale(0.22, 0.22),
			colors.oakDark,
			true
		)
	end
end

local function sign(part: BasePart, text: string)
	local gui = surface(part, Enum.NormalId.Front, "Sign")
	gui.LightInfluence = 0.4
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.06, 0.1)
	label.Size = UDim2.fromScale(0.88, 0.8)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = colors.charcoal
	label.Parent = gui
end

local function anchor(part: BasePart, name: string, offset: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = CFrame.new(offset)
	attachment.Parent = part
end

TownProps.stallCounterTop = 3.8
TownProps.stallPeekaHeight = 3.2

-- Peeka's Pop-up flower cart facing -Z of `base`; the viewer's left is +X. Deal slots stay blank
-- for the stall logic: Counter.BoxAnchor and Counter.PriceTagAnchor (Attachments facing the
-- stall front), Body.StockPips.Strip and ClockTag.ClockFace (SurfaceGuis). Bulbs are lens-only, so
-- they glow at dusk without spending the PointLight budget.
function TownProps.stall(
	parent: Instance,
	name: string,
	base: CFrame,
	body: Color3,
	stripe: Color3
): (Model, { NightLights.Entry })
	local stall = model(parent, name)
	local top = TownProps.stallCounterTop
	local cart = TownProps.part(
		stall,
		"Body",
		Vector3.new(8, 2.8, 4.2),
		base * CFrame.new(0, 2, 0),
		body,
		materials.plastic
	)
	local pips = surface(cart, Enum.NormalId.Front, "StockPips")
	local strip = patch(pips, "Strip", UDim2.fromScale(0.3, 0.52), UDim2.fromScale(0.4, 0.2), body)
	strip.BackgroundTransparency = 1
	-- One cylinder per wheel pair: its caps show front and back, its middle hides under the cart.
	for _, side in { -1, 1 } do
		local wheel = TownProps.part(
			stall,
			"Wheel",
			Vector3.new(4.7, 2.6, 2.6),
			base * CFrame.new(side * 2.65, 1.3, 0) * CFrame.Angles(0, math.rad(90), 0),
			colors.oak,
			materials.wood
		)
		wheel.Shape = Enum.PartType.Cylinder
		spokes(wheel)
	end
	local counter = TownProps.part(
		stall,
		"Counter",
		Vector3.new(9, 0.4, 5),
		base * CFrame.new(0, top - 0.2, 0),
		colors.oak,
		materials.wood
	)
	local plaque = TownProps.part(
		stall,
		"Plaque",
		Vector3.new(3.6, 1.1, 0.12),
		base * CFrame.new(0, 2.7, -2.16),
		colors.ivory,
		materials.plastic,
		false
	)
	sign(plaque, "Hourly Deal")

	-- Peeka peeking from the "?" box; the uploaded stall Peeka replaces this stand-in.
	local feet = base * CFrame.new(2.3, top, -0.4)
	local peeka = model(stall, "Peeka")
	TownProps.part(
		peeka,
		"Box",
		Vector3.new(1.8, 1.5, 1.6),
		feet * CFrame.new(0, 0.75, 0),
		colors.pink,
		materials.plastic
	)
	TownProps.ball(peeka, "Head", 1.5, feet * CFrame.new(0, 1.9, 0), colors.face, materials.plastic)
	TownPlacements.add("PeekaStall", feet, TownProps.stallPeekaHeight, "height", peeka)

	-- Empty cake stand for the offered box, with the price tag hanging to its right.
	TownProps.cylinder(
		stall,
		"CakeStandStem",
		0.35,
		0.8,
		base * CFrame.new(0, top, -0.6),
		colors.ivory,
		materials.plastic
	)
	TownProps.cylinder(
		stall,
		"CakeStand",
		1.8,
		0.14,
		base * CFrame.new(0, top + 0.8, -0.6),
		colors.ivory,
		materials.plastic
	)
	anchor(counter, "BoxAnchor", Vector3.new(0, 1.14, -0.6))
	anchor(counter, "PriceTagAnchor", Vector3.new(-2.3, 1.1, -1.2))

	for _, side in { -1, 1 } do
		local pole = TownProps.part(
			stall,
			"Pole",
			Vector3.new(0.35, 3.9, 0.35),
			base * CFrame.new(side * 3.8, top + 1.95, -0.3),
			colors.ivory,
			materials.plastic
		)
		stripes(pole, stripe, 0.45, true)
	end
	local tag = TownProps.part(
		stall,
		"ClockTag",
		Vector3.new(1.8, 0.9, 0.12),
		base * CFrame.new(4.88, top + 1.3, -0.3) * CFrame.Angles(0, 0, math.rad(4)),
		colors.oak,
		materials.wood,
		false
	)
	local face = surface(tag, Enum.NormalId.Front, "ClockFace")
	local dial = patch(
		face,
		"Dial",
		UDim2.fromScale(0.06, 0.15),
		UDim2.fromScale(0.36, 0.7),
		colors.ivory,
		true
	)
	patch(dial, "Hand", UDim2.fromScale(0.46, 0.18), UDim2.fromScale(0.08, 0.36), colors.charcoal)
	patch(dial, "Hand", UDim2.fromScale(0.5, 0.46), UDim2.fromScale(0.28, 0.08), colors.charcoal)

	-- Canopy: striped skirt, a dome whose lower half hides inside it, and a scalloped hem.
	local skirt = TownProps.part(
		stall,
		"Canopy",
		Vector3.new(9.4, 1.3, 5.4),
		base * CFrame.new(0, 8.25, 0),
		colors.ivory,
		materials.plastic,
		false
	)
	stripes(skirt, stripe, 1.1, false)
	local dome = TownProps.part(
		stall,
		"Dome",
		Vector3.new(8.6, 2.5, 4.8),
		base * CFrame.new(0, 8.9, 0),
		stripe,
		materials.plastic,
		false
	)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = dome
	local hem = TownProps.part(
		stall,
		"Hem",
		Vector3.new(9.5, 0.7, 5.5),
		base * CFrame.new(0, 7.35, 0),
		stripe,
		materials.plastic,
		false
	)
	hem.Transparency = 1
	hem.CastShadow = false
	scallops(hem, stripe)
	local banner = TownProps.part(
		stall,
		"Banner",
		Vector3.new(4.4, 0.75, 0.1),
		base * CFrame.new(0, 9.3, -2.62),
		colors.ivory,
		materials.plastic,
		false
	)
	sign(banner, "Peeka's Pop-up")
	TownProps.giftBox(
		stall,
		"GiftBox",
		base * CFrame.new(0, 10.08, 0) * CFrame.Angles(0, math.rad(12), 0),
		1,
		colors.pink,
		true,
		colors.gold
	)
	local lights = {}
	for index = -2, 2 do
		local bulb = TownProps.ball(
			stall,
			"Bulb",
			0.3,
			base * CFrame.new(index * 1.7, 6.9, -2.78),
			colors.lensOff,
			materials.plastic,
			false
		)
		table.insert(lights, NightLights.add(nil, bulb, colors.lensOn))
	end
	return stall, lights
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
	Puffball = { fit = "height", factor = 2.6 },
	Poplar = { fit = "height", factor = 2.4 },
	Topiary = { fit = "height", factor = 1.4 },
}
TownProps.treeFit = table.freeze(treeFit)
-- Extra size per spot for sakura, sized for regular avatars (about 5 studs tall).
TownProps.sakuraBoost =
	table.freeze({ planter = 1.5, street = 2, frame = 1.6, edge = 2.1 }) :: { [string]: number }
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
	local boost = if kind == "Sakura" then TownProps.sakuraBoost[role] else 1
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
