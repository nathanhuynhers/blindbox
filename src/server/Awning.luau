--!strict
-- Striped fabric awning of native parts. `back` is the center of the awning's raised back edge:
-- its X runs along the width and its -Z points toward the lower front overhang.
local Geometry = require(script.Parent.PlotGeometry)

local Awning = {}
Awning.style = table.freeze({
	stripeWidth = 2.4,
	thickness = 0.2,
	valanceHeight = 1.4,
	valanceThickness = 0.12,
	ivory = Color3.fromRGB(252, 249, 243),
})
local style = Awning.style
-- Warm string lights draped under the hem. Bulbs are painted on an invisible strip and glow only
-- at night through unlit SurfaceGuis (the Shop's bulb treatment): no Light instances, no Neon.
Awning.bulbs = table.freeze({
	off = Color3.fromRGB(255, 246, 221),
	on = Color3.fromRGB(255, 214, 140),
	wire = Color3.fromRGB(107, 74, 62),
	pitch = 1.5,
	perSwag = 3,
	sag = 0.45,
	size = 0.3,
	halo = 0.75,
})
local bulbs = Awning.bulbs
local pixels = 24

local function piece(parent: Instance, name: string, size: Vector3, at: CFrame, color: Color3): Part
	local part = Geometry.partAt(parent, name, size, at, color)
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Odd stripe count so both ends are accent-colored.
function Awning.stripes(width: number): number
	local count = math.max(3, math.floor(width / style.stripeWidth + 0.5))
	return if count % 2 == 0 then count + 1 else count
end

-- Two ivory backing parts, one accent part per accent stripe on the slope and the valance, and
-- the invisible string-light strip.
function Awning.partCount(width: number): number
	return 3 + 2 * math.ceil(Awning.stripes(width) / 2)
end

local function surface(part: BasePart, name: string, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.Active = false
	gui.Parent = part
	return gui
end

-- Circle (or rotated bar when `rotation` is given) centred at x, y studs from the top-left corner.
local function dot(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3,
	rotation: number?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset(x * pixels, y * pixels)
	frame.Size = UDim2.fromOffset(width * pixels, height * pixels)
	if rotation then
		frame.Rotation = rotation
	else
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

-- Paints one row of bulbs (`StringLights`, toggled by `setLit`) at the given face positions.
function Awning.paintBulbs(part: BasePart, face: Enum.NormalId, points: { Vector2 }): SurfaceGui
	local gui = surface(part, "StringLights", face)
	for _, point in points do
		dot(gui, "Halo", point.X, point.Y, bulbs.halo, bulbs.halo, bulbs.on).BackgroundTransparency =
			0.65
	end
	for _, point in points do
		dot(gui, "Bulb", point.X, point.Y, bulbs.size, bulbs.size, bulbs.off)
	end
	return gui
end

-- Swags pinned every `perSwag` bulbs, with a lit wire so it reads as a string by day too.
local function stringLights(parent: Instance, front: CFrame, width: number)
	local swags = math.max(2, math.floor(width / (bulbs.pitch * bulbs.perSwag) + 0.5))
	local height = bulbs.sag + bulbs.halo + 0.2
	local strip = piece(
		parent,
		"StringLights",
		Vector3.new(width, height, 0.05),
		front * CFrame.new(0, -style.valanceHeight / 2 - height / 2 + 0.15, -0.1),
		style.ivory
	)
	strip.Transparency = 1
	local swag = width / swags
	local function y(t: number): number
		return 0.1 + 4 * bulbs.sag * t * (1 - t)
	end
	local wire = surface(strip, "StringWire", Enum.NormalId.Front)
	local points = {}
	for index = 0, swags - 1 do
		for segment = 1, 6 do
			local t0, t1 = (segment - 1) / 6, segment / 6
			local dx, dy = swag / 6, y(t1) - y(t0)
			dot(
				wire,
				"Wire",
				swag * (index + (t0 + t1) / 2),
				(y(t0) + y(t1)) / 2,
				math.sqrt(dx * dx + dy * dy) + 0.02,
				0.05,
				bulbs.wire,
				math.deg(math.atan2(dy, dx))
			)
		end
		for bulb = 1, bulbs.perSwag do
			local t = (bulb - 0.5) / bulbs.perSwag
			table.insert(points, Vector2.new(swag * (index + t), y(t)))
		end
	end
	Awning.paintBulbs(strip, Enum.NormalId.Front, points)
end

-- Called only when the day/night state changes or a lit awning is rebuilt; bounded and idempotent.
function Awning.setLit(root: Instance, on: boolean)
	for _, gui in root:GetDescendants() do
		if gui:IsA("SurfaceGui") and gui.Name == "StringLights" then
			gui.LightInfluence = if on then 0 else 1
			for _, frame in gui:GetChildren() do
				if frame:IsA("Frame") then
					if frame.Name == "Halo" then
						frame.Visible = on
					else
						frame.BackgroundColor3 = if on then bulbs.on else bulbs.off
					end
				end
			end
		end
	end
end

function Awning.build(
	parent: Instance,
	name: string,
	back: CFrame,
	width: number,
	depth: number,
	rise: number,
	accent: Color3
): Model
	local awning = Instance.new("Model")
	awning.Name = name
	local length = math.sqrt(depth * depth + rise * rise)
	local slope = back
		* CFrame.new(0, -rise / 2, -depth / 2)
		* CFrame.Angles(-math.atan2(rise, depth), 0, 0)
	local front = back * CFrame.new(0, -rise - style.valanceHeight / 2, -depth)
	piece(awning, "Canopy", Vector3.new(width, style.thickness, length), slope, style.ivory)
	piece(
		awning,
		"Valance",
		Vector3.new(width, style.valanceHeight, style.valanceThickness),
		front,
		style.ivory
	)
	local count = Awning.stripes(width)
	local stripe = width / count
	for index = 1, count, 2 do
		local x = -width / 2 + stripe * (index - 0.5)
		piece(
			awning,
			"Stripe",
			Vector3.new(stripe, style.thickness + 0.02, length + 0.02),
			slope * CFrame.new(x, 0, 0),
			accent
		)
		piece(
			awning,
			"ValanceStripe",
			Vector3.new(stripe, style.valanceHeight + 0.02, style.valanceThickness + 0.02),
			front * CFrame.new(x, 0, 0),
			accent
		)
	end
	stringLights(awning, front, width)
	Awning.setLit(awning, false)
	awning.Parent = parent
	return awning
end

return Awning
