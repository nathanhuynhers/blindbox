--!strict
-- Upgrade Station: a candy-violet upgrade kiosk on the Shop's (-X) side of each active plot,
-- between the Shop and the entrance arch. A plinth with a gold trim carries a pink cabinet
-- framed by two violet pillars with thin pink neon strips, a glowing screen showing the
-- upgrade icons, a sloped arcade console and an "UPGRADES" marquee. Native parts carry the
-- shape; SurfaceGuis paint the detail, so it stays a dozen parts and adds no lights. Its
-- owner-only E prompt opens the client's Robux Store on Upgrades; there is no purchase,
-- pricing or remote here. No capsule dome, crank or reels, so it never reads as a paid
-- random machine.
local Geometry = require(script.Parent.PlotGeometry)

local Station = {}
Station.palette = table.freeze({
	body = Color3.fromRGB(255, 179, 209), -- candy pink
	stripe = Color3.fromRGB(255, 141, 192),
	marquee = Color3.fromRGB(155, 130, 255), -- candy violet
	plinth = Color3.fromRGB(120, 92, 214),
	gold = Color3.fromRGB(255, 200, 61),
	cream = Color3.fromRGB(255, 246, 218),
	ink = Color3.fromRGB(43, 31, 74),
	white = Color3.fromRGB(255, 255, 255),
	green = Color3.fromRGB(44, 191, 94),
	neon = Color3.fromRGB(255, 120, 200),
	screen = Color3.fromRGB(64, 44, 120),
	screenGlow = Color3.fromRGB(96, 66, 176),
	bulbOff = Color3.fromRGB(255, 246, 221),
	bulbOn = Color3.fromRGB(255, 214, 140),
})
-- Plot-local footprint centre on the Shop's side (-X), between the Shop (Z -3 .. 16) and the
-- entrance arch, clear of the spawn pad and the arch path. The front (-Z of the station frame)
-- looks at the plot centre, so the same plot-relative layout holds for every plot.
Station.position = Vector3.new(-40, 0, -17)
Station.center = Vector3.new(0, 0, 0)
Station.body = table.freeze({ width = 6.2, height = 7.6, depth = 4.4, base = 1.05 })
Station.prompt = table.freeze({ front = 5.5, y = 0.45, range = 12 })
-- Screen art: the uploaded Display / 2x Coins / Lucky Charm icons (see StoreCatalog.images).
Station.screenIcons = table.freeze({ "75697262694573", "83150095344645", "132802379968289" })
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
	return transform * CFrame.lookAt(Station.position, Station.center)
end

local function piece(
	parent: Instance,
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	solid: boolean?,
	class: string?
): BasePart
	local part: BasePart
	if class == "WedgePart" then
		part = Instance.new("WedgePart")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.CFrame = at
		part.Color = color
		part.Parent = parent
	else
		part = Geometry.partAt(parent, name, size, at, color)
	end
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.CanCollide = solid ~= false
	part.CanQuery = solid ~= false
	return part
end

local function surface(
	part: BasePart,
	name: string,
	face: Enum.NormalId,
	density: number?
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = density or pixels
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
	round: number?,
	density: number?
): Frame
	local scale = density or pixels
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.Position = UDim2.fromOffset(x * scale, y * scale)
	frame.Size = UDim2.fromOffset(width * scale, height * scale)
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

local function outline(object: GuiObject, thickness: number, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or palette.ink
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
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

local function gradient(object: GuiObject, top: Color3, bottom: Color3)
	local made = Instance.new("UIGradient")
	made.Rotation = 90
	made.Color = ColorSequence.new(top, bottom)
	made.Parent = object
end

-- Screen: three upgrade icon tiles over "POWER UPS!" and an "OPEN STORE" pill.
local function screen(part: BasePart, width: number, height: number): (SurfaceGui, Frame)
	local density = 48
	local gui = surface(part, "Screen", Enum.NormalId.Front, density)
	local fill =
		rect(gui, "Glass", 0.15, 0.15, width - 0.3, height - 0.3, palette.screen, 0.08, density)
	gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(200, 170, 255))
	outline(fill, 4, palette.neon)
	local heading = rect(fill, "Heading", 0.3, 0.12, width - 0.9, 0.6, palette.screen, nil, density)
	heading.BackgroundTransparency = 1
	local title = text(heading, "Title", "POWER UPS!")
	title.TextColor3 = palette.gold
	local count = #Station.screenIcons
	local tile = 1.2
	local gap = (width - 0.3 - count * tile) / (count + 1)
	for index, id in Station.screenIcons do
		local x = gap + (index - 1) * (tile + gap)
		local cell = rect(fill, "Tile" .. index, x, 0.85, tile, tile, palette.cream, 0.22, density)
		outline(cell, 3)
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = "rbxassetid://" .. id
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Size = UDim2.fromScale(0.9, 0.9)
		icon.Position = UDim2.fromScale(0.05, 0.05)
		icon.Parent = cell
	end
	local pill =
		rect(fill, "OpenPill", 1.1, height - 0.95, width - 2.5, 0.5, palette.neon, 0.5, density)
	outline(pill, 3)
	text(pill, "Label", "OPEN STORE")
	return gui, fill
end

-- Console slope: three arcade buttons and a coin slot. A WedgePart's Top canvas is the
-- projected slope turned 90 degrees (canvas X runs along the part's depth, Y along its width),
-- so the row of buttons is laid out down the canvas.
local function console(part: BasePart)
	local gui = surface(part, "Console", Enum.NormalId.Top)
	local across, along = part.Size.Z, part.Size.X
	local plate = rect(gui, "Plate", 0.1, 0.15, across - 0.2, along - 0.3, palette.cream, 0.2)
	outline(plate, 3)
	local cap = math.min(0.95, across - 0.6)
	for index, color in { palette.neon, palette.gold, palette.green } do
		local y = 0.35 + (index - 1) * 1.25
		local button = rect(plate, "Button", (across - 0.2 - cap) / 2, y, cap, cap, color, 0.5)
		outline(button, 3)
		rect(button, "Shine", 0.18, 0.14, 0.3, 0.2, palette.white, 0.5)
	end
	local slot =
		rect(plate, "CoinSlot", (across - 1) / 2, along - 1.75, 0.8, 1.2, palette.white, 0.3)
	outline(slot, 3)
	rect(slot, "Opening", 0.32, 0.25, 0.16, 0.7, palette.ink, 0.5)
end

-- Counter front: a gold "LEVEL UP!" plate.
local function counterFront(part: BasePart, width: number, height: number)
	local gui = surface(part, "CounterFront", Enum.NormalId.Front)
	local plate = rect(gui, "Plate", 0.5, 0.4, width - 1, height - 0.8, palette.gold, 0.3)
	outline(plate, 3)
	text(plate, "Label", "LEVEL UP!")
end

-- Marquee: "UPGRADES" between two rows of bulbs on a pink-to-violet sign.
local function marquee(part: BasePart, width: number, height: number): (SurfaceGui, { Frame })
	local gui = surface(part, "Marquee", Enum.NormalId.Front)
	local back = rect(gui, "Back", 0, 0, width, height, palette.white)
	back.BackgroundTransparency = 0
	gradient(back, palette.stripe, palette.marquee)
	local label = Instance.new("Frame")
	label.Name = "Sign"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(0, 0.45 * pixels)
	label.Size = UDim2.fromOffset(width * pixels, (height - 0.9) * pixels)
	label.Parent = gui
	text(label, "Title", "UPGRADES")
	local bulbs = {}
	for index = 0, 8 do
		local x = 0.35 + index * (width - 0.7) / 8
		for _, y in { 0.1, height - 0.4 } do
			table.insert(bulbs, rect(gui, "Bulb", x - 0.15, y, 0.3, 0.3, palette.bulbOff, 0.5))
		end
	end
	return gui, bulbs
end

-- Soft vertical stripes on the cabinet sides.
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
	-- Cabinet sits slightly back so the console and counter fit on the plinth in front.
	local back = 0.4
	local front = back - depth / 2
	parts.Base = piece(
		model,
		"Base",
		Vector3.new(8.4, 0.8, 7.6),
		at * CFrame.new(0, 0.4, -0.2),
		palette.plinth
	)
	parts.BaseTrim = piece(
		model,
		"BaseTrim",
		Vector3.new(8.6, base - 0.8, 7.8),
		at * CFrame.new(0, 0.8 + (base - 0.8) / 2, -0.2),
		palette.gold
	)
	parts.Body = piece(
		model,
		"Body",
		Vector3.new(width, height, depth),
		at * CFrame.new(0, base + height / 2, back),
		palette.body
	)
	sides(parts.Body)
	-- Waist-high counter with a sloped console on top, in front of the cabinet.
	local counterHeight, counterDepth, slopeHeight = 2.4, 1.8, 1
	parts.Counter = piece(
		model,
		"Counter",
		Vector3.new(5.6, counterHeight, counterDepth),
		at * CFrame.new(0, base + counterHeight / 2, front - counterDepth / 2),
		palette.marquee
	)
	counterFront(parts.Counter, 5.6, counterHeight)
	parts.Console = piece(
		model,
		"Console",
		Vector3.new(5.6, slopeHeight, counterDepth),
		at * CFrame.new(0, base + counterHeight + slopeHeight / 2, front - counterDepth / 2),
		palette.cream,
		true,
		"WedgePart"
	)
	console(parts.Console)
	-- Screen bezel above the console.
	local screenWidth, screenHeight = 5, 3.2
	parts.Screen = piece(
		model,
		"Screen",
		Vector3.new(screenWidth, screenHeight, 0.35),
		at
			* CFrame.new(
				0,
				base + counterHeight + slopeHeight + 0.2 + screenHeight / 2,
				front - 0.175
			),
		palette.ink
	)
	local window, windowFill = screen(parts.Screen, screenWidth, screenHeight)
	-- Violet pillars at the front corners, each with a thin pink neon strip.
	local pillarHeight = height + 0.6
	for side, sign in { Left = -1, Right = 1 } do
		local x = sign * (width / 2 + 0.55)
		local pillar = piece(
			model,
			"Pillar" .. side,
			Vector3.new(pillarHeight, 1.2, 1.2),
			at
				* CFrame.new(x, base + pillarHeight / 2, front + 0.3)
				* CFrame.Angles(0, 0, math.pi / 2),
			palette.marquee
		)
		local round = pillar :: Part
		round.Shape = Enum.PartType.Cylinder
		parts["Pillar" .. side] = pillar
		local strip = piece(
			model,
			"Neon" .. side,
			Vector3.new(0.22, pillarHeight - 1.2, 0.14),
			at * CFrame.new(x, base + pillarHeight / 2, front + 0.3 - 0.63),
			palette.neon,
			false
		)
		strip.Material = Enum.Material.Neon
		strip.CastShadow = false
		parts["Neon" .. side] = strip
	end
	local marqueeWidth, marqueeHeight = width + 2.6, 2.4
	parts.Marquee = piece(
		model,
		"Marquee",
		Vector3.new(marqueeWidth, marqueeHeight, 1.8),
		at * CFrame.new(0, base + height + marqueeHeight / 2, front + 0.6),
		palette.marquee
	)
	local sign, bulbs = marquee(parts.Marquee, marqueeWidth, marqueeHeight)
	local topper = piece(
		model,
		"Topper",
		Vector3.new(1.4, 1.4, 1.4),
		at * CFrame.new(0, base + height + marqueeHeight + 0.55, front + 0.6),
		palette.gold,
		false
	)
	local ball = topper :: Part
	ball.Shape = Enum.PartType.Ball
	parts.Topper = topper
	-- Low, centred prompt anchor in front of the kiosk, like the Shop and Display prompts.
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

-- Screen and marquee glow with the plot's night controller; unlit SurfaceGuis and two small
-- neon strips, no Light instances, so the shared night-light budget is unchanged.
function Station.setNight(render: Render, enabled: boolean)
	render.window.LightInfluence = if enabled then 0 else 1
	render.sign.LightInfluence = if enabled then 0 else 1
	render.windowFill.BackgroundColor3 = if enabled then palette.screenGlow else palette.screen
	for _, bulb in render.bulbs do
		bulb.BackgroundColor3 = if enabled then palette.bulbOn else palette.bulbOff
	end
	render.model:SetAttribute("Night", enabled)
end

return Station
