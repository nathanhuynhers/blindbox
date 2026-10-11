--!strict
-- Upgrade Station: a cute candy arcade cabinet in each active plot's front corner, on the Shelves
-- side. Native parts carry the shape; SurfaceGuis paint the marquee, the window with a blind-box
-- buddy, the "POWER-UPS!" plate and a green + button. Its owner-only E prompt opens the client's
-- Robux Store on Upgrades; there is no purchase, pricing or remote here. No capsule dome, crank
-- or reels, so it never reads as a paid random machine.
local Geometry = require(script.Parent.PlotGeometry)

local Station = {}
Station.palette = table.freeze({
	body = Color3.fromRGB(255, 179, 209), -- candy pink
	stripe = Color3.fromRGB(255, 141, 192),
	marquee = Color3.fromRGB(155, 130, 255), -- candy violet
	gold = Color3.fromRGB(255, 200, 61),
	cream = Color3.fromRGB(255, 246, 218),
	oak = Color3.fromRGB(201, 150, 90),
	ink = Color3.fromRGB(43, 31, 74),
	white = Color3.fromRGB(255, 255, 255),
	green = Color3.fromRGB(44, 191, 94),
	blush = Color3.fromRGB(255, 159, 184),
	slot = Color3.fromRGB(236, 229, 246),
	bulbOff = Color3.fromRGB(255, 246, 221),
	bulbOn = Color3.fromRGB(255, 214, 140),
	glow = Color3.fromRGB(255, 231, 189),
})
-- Plot-local footprint centre: front corner on the Shelves (+X) side, behind the arch line and
-- in front of the Shelves (which start near Z -25). The front turns 60 degrees from -Z toward
-- the plot centre, so players walking in through the arch see the marquee.
Station.position = Vector3.new(38, 0, -38)
Station.turn = math.rad(60)
Station.body = table.freeze({ width = 6, height = 8.4, depth = 5, base = 0.8 })
Station.prompt = table.freeze({ front = 5, y = 0.45, range = 12 })
local palette, body = Station.palette, Station.body
local pixels = 24

export type Render = {
	model: Model,
	parts: { [string]: BasePart },
	window: SurfaceGui,
	windowFill: Frame,
	sign: SurfaceGui,
	bulbs: { Frame },
}

-- The station's own frame: origin on the floor at the footprint centre, -Z out of the front.
function Station.frame(transform: CFrame): CFrame
	return transform * CFrame.new(Station.position) * CFrame.Angles(0, Station.turn, 0)
end

local function piece(
	parent: Instance,
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	solid: boolean?
): Part
	local part = Geometry.partAt(parent, name, size, at, color)
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.CanCollide = solid ~= false
	part.CanQuery = solid ~= false
	return part
end

local function surface(part: BasePart, name: string, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.LightInfluence = 1
	gui.Active = false
	gui.Parent = part
	return gui
end

-- Rectangle in studs from the face's top-left corner; `round` 0.5 makes a circle.
local function rect(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3,
	round: number?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.Position = UDim2.fromOffset(x * pixels, y * pixels)
	frame.Size = UDim2.fromOffset(width * pixels, height * pixels)
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

local function outline(object: GuiObject, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = palette.ink
	stroke.Thickness = thickness
	stroke.Parent = object
end

local function text(parent: Instance, name: string, value: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = palette.white
	label.TextScaled = true
	label.Text = value
	outline(label, 3)
	label.Parent = parent
	return label
end

-- Front: a window with the blind-box buddy, the plate, a green + button and a coin slot.
local function front(part: BasePart): (SurfaceGui, Frame)
	local gui = surface(part, "StationFront", Enum.NormalId.Front)
	local window = rect(gui, "Window", 0.8, 0.6, 4.4, 3.4, palette.cream, 0.18)
	outline(window, 4)
	local buddy = rect(window, "Buddy", 1.2, 0.9, 2, 1.9, palette.body, 0.2)
	outline(buddy, 3)
	rect(buddy, "Lid", -0.15, -0.25, 2.3, 0.5, palette.stripe, 0.2)
	for _, x in { 0.45, 1.3 } do
		rect(buddy, "Eye", x, 0.75, 0.25, 0.25, palette.ink, 0.5)
		rect(buddy, "Blush", x - 0.2, 1.1, 0.4, 0.2, palette.blush, 0.5)
	end
	local plate = rect(gui, "Plate", 0.7, 4.4, 4.6, 1.1, palette.gold, 0.3)
	outline(plate, 3)
	text(plate, "Label", "POWER-UPS!")
	local plus = rect(gui, "PlusButton", 0.9, 5.9, 1.8, 1.8, palette.green, 0.5)
	outline(plus, 3)
	rect(plus, "Across", 0.4, 0.75, 1, 0.3, palette.white, 0.5)
	rect(plus, "Down", 0.75, 0.4, 0.3, 1, palette.white, 0.5)
	local slot = rect(gui, "CoinSlot", 3.3, 6.2, 1.8, 1.1, palette.slot, 0.3)
	outline(slot, 3)
	rect(slot, "Opening", 0.3, 0.45, 1.2, 0.2, palette.ink, 0.5)
	return gui, window
end

-- Marquee: "UPGRADES" between two rows of bulbs (front face).
local function marquee(part: BasePart, width: number, height: number): (SurfaceGui, { Frame })
	local gui = surface(part, "Marquee", Enum.NormalId.Front)
	local label = Instance.new("Frame")
	label.Name = "Sign"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(0, 0.45 * pixels)
	label.Size = UDim2.fromOffset(width * pixels, (height - 0.9) * pixels)
	label.Parent = gui
	text(label, "Title", "UPGRADES")
	local bulbs = {}
	for index = 0, 7 do
		local x = 0.35 + index * (width - 0.7) / 7
		for _, y in { 0.1, height - 0.4 } do
			table.insert(bulbs, rect(gui, "Bulb", x - 0.15, y, 0.3, 0.3, palette.bulbOff, 0.5))
		end
	end
	return gui, bulbs
end

-- Soft vertical stripes on the sides.
local function sides(part: BasePart)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = surface(part, "Stripes", face)
		for x = 0.6, body.depth - 0.6, 1.4 do
			rect(gui, "Stripe", x, 0.4, 0.6, body.height - 0.8, palette.stripe, 0.5)
		end
	end
end

function Station.create(parent: Instance, transform: CFrame): Render
	local model = Instance.new("Model")
	model.Name = "UpgradeStation"
	local at = Station.frame(transform)
	local parts: { [string]: BasePart } = {}
	local width, height, depth, base = body.width, body.height, body.depth, body.base
	parts.Base = piece(
		model,
		"Base",
		Vector3.new(width + 1.4, base, depth + 1.2),
		at * CFrame.new(0, base / 2, 0),
		palette.oak
	)
	parts.Base.Material = Enum.Material.Wood
	parts.Body = piece(
		model,
		"Body",
		Vector3.new(width, height, depth),
		at * CFrame.new(0, base + height / 2, 0),
		palette.body
	)
	local window, windowFill = front(parts.Body)
	sides(parts.Body)
	local marqueeHeight = 2.6
	parts.Marquee = piece(
		model,
		"Marquee",
		Vector3.new(width + 1, marqueeHeight, depth + 0.6),
		at * CFrame.new(0, base + height + marqueeHeight / 2, 0),
		palette.marquee
	)
	local sign, bulbs = marquee(parts.Marquee, width + 1, marqueeHeight)
	local topper = piece(
		model,
		"Topper",
		Vector3.new(1.6, 1.6, 1.6),
		at * CFrame.new(0, base + height + marqueeHeight + 0.6, 0),
		palette.gold,
		false
	)
	topper.Shape = Enum.PartType.Ball
	parts.Topper = topper
	-- Low, centred prompt anchor in front of the cabinet, like the Shop and Display prompts.
	local open = piece(
		model,
		"OpenStore",
		Vector3.new(1, 1, 1),
		at * CFrame.new(0, Station.prompt.y, -Station.prompt.front),
		palette.white,
		false
	)
	open.Transparency = 1
	parts.OpenStore = open
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenStorePrompt"
	prompt.ActionText = "Upgrades"
	prompt.ObjectText = "Upgrade Station"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = Station.prompt.range
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = open
	local render: Render = {
		model = model,
		parts = parts,
		window = window,
		windowFill = windowFill,
		sign = sign,
		bulbs = bulbs,
	}
	Station.setNight(render, false)
	model.Parent = parent
	return render
end

-- Window and marquee glow with the plot's night controller; unlit SurfaceGuis, no Light
-- instances, so the shared night-light budget is unchanged.
function Station.setNight(render: Render, enabled: boolean)
	render.window.LightInfluence = if enabled then 0 else 1
	render.sign.LightInfluence = if enabled then 0 else 1
	render.windowFill.BackgroundColor3 = if enabled then palette.glow else palette.cream
	for _, bulb in render.bulbs do
		bulb.BackgroundColor3 = if enabled then palette.bulbOn else palette.bulbOff
	end
	render.model:SetAttribute("Night", enabled)
end

return Station
