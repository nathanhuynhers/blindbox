--!strict
-- Peeka's Box Shop: a kiosk shaped like Peeka's pink polka-dot "?" box on the open side of every
-- active plot, opposite the Shelves. Native parts carry the shape; SurfaceGuis paint the dots,
-- stripes, shelves of mini boxes and signs, so the kiosk stays a handful of parts. Its E prompt
-- only opens the existing Shop screen on the owner's client; there is no shop logic here.
local Awning = require(script.Parent.Awning)
local Geometry = require(script.Parent.PlotGeometry)
local TownProps = require(script.Parent.TownProps)

local Shop = {}
Shop.palette = table.freeze({
	box = Color3.fromRGB(242, 141, 178), -- #F28DB2, Peeka's box
	lid = Color3.fromRGB(247, 168, 196),
	dot = Color3.fromRGB(255, 247, 250),
	gold = Color3.fromRGB(245, 192, 74),
	ivory = Color3.fromRGB(252, 249, 243),
	cream = Color3.fromRGB(255, 246, 222),
	oak = Color3.fromRGB(198, 165, 120),
	line = Color3.fromRGB(107, 74, 62),
	charcoal = Color3.fromRGB(59, 54, 51),
	board = Color3.fromRGB(47, 74, 63),
	interior = Color3.fromRGB(253, 240, 244),
	interiorNight = Color3.fromRGB(255, 231, 189),
	bulbOff = Color3.fromRGB(255, 246, 221),
	bulbOn = Color3.fromRGB(255, 214, 140),
	plush = Color3.fromRGB(255, 246, 232),
	eye = Color3.fromRGB(43, 37, 35),
})
-- Plot-local centre of the footprint (Shelves are at +X, the spawn pad at -18/-28, the Display
-- spans |X| <= 30 at Z >= 31). The window faces +X, toward the plot centre.
Shop.position = Vector3.new(-38, 0, 6)
Shop.body = table.freeze({ width = 12, height = 11, depth = 11, wall = 2 })
Shop.window = table.freeze({ bottom = 3.8, top = 8.6, back = 1.5 })
Shop.prompt = table.freeze({ front = 8.6, y = 0.45, range = 12 })
-- Peeka stands waist-deep behind the counter; the uploaded model is fitted to this height.
Shop.shopkeeper = table.freeze({ kind = "PeekaShopkeeper", height = 4.8, base = 2.6, z = -2.4 })
local palette, body, window = Shop.palette, Shop.body, Shop.window
local pixels = 24
-- Painted dots stay below the gold rim band that wraps the top of the box.
local rim = 1.2
local function belowRim(_x: number, y: number): boolean
	return y > rim
end

export type Render = {
	model: Model,
	parts: { [string]: BasePart },
	keeper: Model,
	keeperAt: CFrame,
	window: SurfaceGui,
	windowFill: Frame,
	ceiling: SurfaceGui,
	bulbs: SurfaceGui,
	bulbFrames: { Frame },
	halos: { Frame },
}

-- The kiosk's own frame: origin on the floor at the footprint centre, -Z out of the window.
function Shop.frame(transform: CFrame): CFrame
	return transform * CFrame.new(Shop.position) * CFrame.Angles(0, -math.pi / 2, 0)
end

local function piece(
	parent: Instance,
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): Part
	local part = Geometry.partAt(parent, name, size, at, color)
	part.Material = material or Enum.Material.SmoothPlastic
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

-- Rectangle measured in studs from the face's top-left corner; `round` 0.5 makes a circle.
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

local function text(parent: Instance, name: string, value: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = value
	label.Parent = parent
	return label
end

-- Staggered polka dots over a `width` x `height` face, skipping anything `keep` rejects.
local function dots(
	gui: SurfaceGui,
	width: number,
	height: number,
	keep: ((number, number) -> boolean)?
)
	local spacing, size = 2.4, 0.75
	local row = 0
	for y = spacing / 2, height, spacing * 0.8 do
		local shift = if row % 2 == 0 then 0 else spacing / 2
		for x = spacing / 4 + shift, width, spacing do
			if not keep or keep(x, y) then
				rect(gui, "Dot", x - size / 2, y - size / 2, size, size, palette.dot, 0.5)
			end
		end
		row += 1
	end
end

-- Side walls: dots around a big white outlined "?".
local function questionSide(part: BasePart, face: Enum.NormalId)
	local gui = surface(part, "QuestionSide", face)
	local side, height = body.depth, body.height
	dots(gui, side, height, function(x, y)
		return y > rim and (math.abs(x - side / 2) > 3.4 or math.abs(y - height / 2 - 0.4) > 4.2)
	end)
	-- TextScaled stops at 100 px, so the "?" gets a coarse canvas of its own to fill the side.
	local markGui = surface(part, "QuestionMark", face)
	markGui.PixelsPerStud = 9
	local mark = text(markGui, "Question", "?", palette.dot)
	mark.Size = UDim2.fromScale(0.9, 0.9)
	mark.Position = UDim2.fromScale(0.05, 0.1)
	local outline = Instance.new("UIStroke")
	outline.Color = palette.line
	outline.Thickness = 2
	outline.Parent = mark
end

-- Shelves of mini boxes in the collection pastels, seen through the window behind Peeka.
local function windowShelves(part: BasePart): (SurfaceGui, Frame)
	local gui = surface(part, "WindowShelves", Enum.NormalId.Front)
	local width = body.width - 2 * body.wall
	local fill = rect(gui, "Interior", 0, 0, width, body.height, palette.interior)
	local count = 0
	for _, shelfY in { 5.2, 7.0 } do
		local top = body.height - shelfY
		rect(fill, "Board", 0, top, width, 0.2, palette.oak)
		for x = 0.35, width - 0.8, 1.05 do
			count += 1
			local color = TownProps.pastel(count)
			local box = rect(fill, "MiniBox", x, top - 0.8, 0.8, 0.8, color, 0.12)
			rect(box, "Lid", 0, 0, 0.8, 0.22, color:Lerp(palette.dot, 0.45), 0.2)
		end
	end
	return gui, fill
end

local function plaque(part: BasePart)
	local gui = surface(part, "ShopPlaque", Enum.NormalId.Front)
	local width = body.width - 2 * body.wall
	local height = window.bottom - 0.4
	dots(gui, width, height, function(_x, y)
		return y < 0.9 or y > 2.5
	end)
	local card = rect(gui, "Plaque", 0.6, 0.95, width - 1.2, 1.5, palette.cream, 0.3)
	local edge = Instance.new("UIStroke")
	edge.Color = palette.oak
	edge.Thickness = 3
	edge.Parent = card
	local label = text(card, "Title", "Peeka's Box Shop", palette.charcoal)
	label.Size = UDim2.fromScale(0.9, 0.78)
	label.Position = UDim2.fromScale(0.05, 0.11)
end

local function chalkboard(part: BasePart, size: Vector3)
	local gui = surface(part, "Chalkboard", Enum.NormalId.Front)
	local inset = 0.22
	local slate = rect(
		gui,
		"Slate",
		inset,
		inset,
		size.X - 2 * inset,
		size.Y - 2 * inset,
		palette.board,
		0.06
	)
	local open = text(slate, "Open", "OPEN", palette.cream)
	open.Size = UDim2.fromScale(0.84, 0.36)
	open.Position = UDim2.fromScale(0.08, 0.12)
	local hint = text(slate, "Hint", "press E", palette.gold)
	hint.Size = UDim2.fromScale(0.7, 0.22)
	hint.Position = UDim2.fromScale(0.15, 0.6)
end

-- Pink/ivory stripes on an awning face, `count` odd so both edges are pink.
local function stripes(gui: SurfaceGui, width: number, height: number, count: number)
	local stripe = width / count
	for index = 1, count, 2 do
		rect(gui, "Stripe", stripe * (index - 1), 0, stripe, height, palette.box)
	end
end

-- Valance: striped band, scalloped hem and a string of bulbs, all painted on one invisible part.
local function valance(
	part: BasePart,
	width: number,
	count: number
): (SurfaceGui, { Frame }, { Frame })
	local band = 0.9
	local gui = surface(part, "Valance", Enum.NormalId.Front)
	local scallops = count * 2 - 1
	local pitch = width / scallops
	for index = 1, scallops do
		local color = if index % 2 == 1 then palette.box else palette.ivory
		rect(gui, "Scallop", pitch * (index - 1), band - pitch / 2, pitch, pitch, color, 0.5)
	end
	rect(gui, "Band", 0, 0, width, band, palette.ivory)
	stripes(gui, width, band, count)
	local lights = surface(part, "Bulbs", Enum.NormalId.Front)
	local bulbs, halos = {}, {}
	for index = 1, scallops do
		local x = pitch * (index - 0.5)
		local y = band + pitch / 2 + 0.3
		local halo = rect(lights, "Halo", x - 0.35, y - 0.35, 0.7, 0.7, palette.bulbOn, 0.5)
		halo.BackgroundTransparency = 0.6
		halo.Visible = false
		table.insert(halos, halo)
		table.insert(
			bulbs,
			rect(lights, "Bulb", x - 0.16, y - 0.16, 0.32, 0.32, palette.bulbOff, 0.5)
		)
	end
	return lights, bulbs, halos
end

-- A tasteful part-built Peeka used until (or unless) the uploaded shopkeeper model loads. It
-- keeps the uploaded model's part names, so the client's bob, wave and sleepy eyes work on both.
local function standIn(parent: Instance, at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Shopkeeper"
	local function ball(name: string, diameter: number, offset: CFrame, color: Color3): Part
		local part =
			piece(model, name, Vector3.new(diameter, diameter, diameter), at * offset, color)
		part.Shape = Enum.PartType.Ball
		return part
	end
	ball("PeekaShopkeeper_Body", 2.6, CFrame.new(0, 1.2, 0), palette.plush)
	ball("PeekaShopkeeper_Head", 2.6, CFrame.new(0, 2.9, 0), palette.plush)
	piece(
		model,
		"PeekaShopkeeper_Lid",
		Vector3.new(2.1, 0.5, 2.1),
		at * CFrame.new(0.15, 4.3, 0.1) * CFrame.Angles(0, 0, math.rad(-10)),
		palette.box
	)
	ball("PeekaShopkeeper_RightArm", 0.9, CFrame.new(1.25, 1.6, -0.75), palette.plush)
	for _, x in { -0.45, 0.45 } do
		piece(
			model,
			"PeekaShopkeeper_EyesClosed",
			Vector3.new(0.4, 0.08, 0.1),
			at * CFrame.new(x, 2.98, -1.18),
			palette.eye
		)
		ball("PeekaShopkeeper_Eyes", 0.36, CFrame.new(x, 3, -1.2), palette.eye)
	end
	model.WorldPivot = at
	-- Pivot-space shoulder for the wave; the uploaded model derives it from its own scale.
	model:SetAttribute("Shoulder", Vector3.new(0.9, 1.75, -0.4))
	model.Parent = parent
	return model
end

function Shop.create(parent: Instance, transform: CFrame): Render
	local model = Instance.new("Model")
	model.Name = "ShopFixture"
	local at = Shop.frame(transform)
	local parts: { [string]: BasePart } = {}
	local width, height, depth, wall = body.width, body.height, body.depth, body.wall
	local inner = width - 2 * wall
	local front = -depth / 2
	for _, side in { -1, 1 } do
		local name = if side == -1 then "EntranceWall" else "DisplayWall"
		local part = piece(
			model,
			name,
			Vector3.new(wall, height, depth),
			at * CFrame.new(side * (width - wall) / 2, height / 2, 0),
			palette.box
		)
		parts[name] = part
		questionSide(part, if side == -1 then Enum.NormalId.Left else Enum.NormalId.Right)
		dots(surface(part, "Dots", Enum.NormalId.Front), wall, height, belowRim)
	end
	local backDepth = depth / 2 - window.back
	parts.BackWall = piece(
		model,
		"BackWall",
		Vector3.new(inner, height, backDepth),
		at * CFrame.new(0, height / 2, window.back + backDepth / 2),
		palette.box
	)
	dots(surface(parts.BackWall, "Dots", Enum.NormalId.Back), inner, height, belowRim)
	local headerHeight = height - window.top
	parts.Header = piece(
		model,
		"Header",
		Vector3.new(inner, headerHeight, depth - backDepth),
		at * CFrame.new(0, window.top + headerHeight / 2, front + (depth - backDepth) / 2),
		palette.box
	)
	local counterHeight = window.bottom - 0.4
	parts.CounterFront = piece(
		model,
		"CounterFront",
		Vector3.new(inner, counterHeight, 1.5),
		at * CFrame.new(0, counterHeight / 2, front + 0.75),
		palette.box
	)
	plaque(parts.CounterFront)
	parts.Counter = piece(
		model,
		"Counter",
		Vector3.new(inner + 1.2, 0.4, 3),
		at * CFrame.new(0, window.bottom - 0.2, front - 0.1),
		palette.oak,
		Enum.Material.Wood
	)
	local bell = piece(
		model,
		"Bell",
		Vector3.new(0.7, 0.7, 0.7),
		at * CFrame.new(2.8, window.bottom + 0.1, front - 0.6),
		palette.gold,
		Enum.Material.Metal,
		false
	)
	bell.Shape = Enum.PartType.Ball
	parts.Bell = bell
	parts.GoldRim = piece(
		model,
		"GoldRim",
		Vector3.new(width + 0.3, 0.8, depth + 0.3),
		at * CFrame.new(0, height - 0.4, 0),
		palette.gold
	)
	-- The lid rests on one edge, tipped like Peeka's hat, with the big gold bow on top.
	local lidAt = at
		* CFrame.new(0.5, height + 0.95, 0.2)
		* CFrame.Angles(math.rad(-3), 0, math.rad(-7))
	parts.Lid = piece(model, "Lid", Vector3.new(width + 1, 1.4, depth + 1), lidAt, palette.lid)
	local bowAt = lidAt * CFrame.new(0, 0.9, 0)
	for _, side in { -1, 1 } do
		local loop = piece(
			model,
			if side == -1 then "BowLoopLeft" else "BowLoopRight",
			Vector3.new(0.6, 3.2, 3.2),
			bowAt
				* CFrame.new(side * 1.5, 1, 0)
				* CFrame.Angles(0, 0, side * math.rad(-20))
				* CFrame.Angles(0, side * math.rad(35), 0)
				* CFrame.Angles(0, math.pi / 2, 0),
			palette.gold,
			nil,
			false
		)
		loop.Shape = Enum.PartType.Cylinder
		parts[loop.Name] = loop
	end
	local knot = piece(
		model,
		"BowKnot",
		Vector3.new(1.3, 1.3, 1.3),
		bowAt * CFrame.new(0, 0.55, 0),
		palette.gold,
		nil,
		false
	)
	knot.Shape = Enum.PartType.Ball
	parts.BowKnot = knot
	-- Striped awning over the window: one slab and one painted valance.
	local awningWidth, awningDepth, rise = width - 1.6, 3.2, 1
	local count = Awning.stripes(awningWidth)
	local back = at * CFrame.new(0, height - 0.95, front)
	local length = math.sqrt(awningDepth * awningDepth + rise * rise)
	parts.Awning = piece(
		model,
		"Awning",
		Vector3.new(awningWidth, 0.2, length),
		back
			* CFrame.new(0, -rise / 2, -awningDepth / 2)
			* CFrame.Angles(-math.atan2(rise, awningDepth), 0, 0),
		palette.ivory,
		nil,
		false
	)
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		stripes(surface(parts.Awning, "Stripes", face), awningWidth, length, count)
	end
	local valanceHeight = 2.1
	parts.Valance = piece(
		model,
		"Valance",
		Vector3.new(awningWidth, valanceHeight, 0.1),
		back * CFrame.new(0, -rise - valanceHeight / 2, -awningDepth),
		palette.ivory,
		nil,
		false
	)
	parts.Valance.Transparency = 1
	local bulbs, bulbFrames, halos = valance(parts.Valance, awningWidth, count)
	local shelves, fill = windowShelves(parts.BackWall)
	local ceiling = surface(parts.Header, "CeilingGlow", Enum.NormalId.Bottom)
	ceiling.LightInfluence = 0
	ceiling.Enabled = false
	rect(ceiling, "Glow", 0, 0, inner, depth - backDepth, palette.interiorNight).BackgroundTransparency =
		0.35
	TownProps.pottedPlant(model, "Planter", at * CFrame.new(width / 2 + 1.8, 0, front + 2))
	local boardSize = Vector3.new(2.8, 3.6, 0.3)
	parts.Chalkboard = piece(
		model,
		"Chalkboard",
		boardSize,
		at
			* CFrame.new(-width / 2 - 1.9, 1.75, front - 0.6)
			* CFrame.Angles(math.rad(10), math.rad(-25), 0),
		palette.oak,
		Enum.Material.Wood
	)
	chalkboard(parts.Chalkboard, boardSize)
	-- Low, centered prompt anchor in front of the counter, like the Display and Shelves prompts.
	local open = piece(
		model,
		"OpenShop",
		Vector3.new(1, 1, 1),
		at * CFrame.new(0, Shop.prompt.y, -Shop.prompt.front),
		palette.ivory,
		nil,
		false
	)
	open.Transparency = 1
	parts.OpenShop = open
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShopPrompt"
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = "Peeka's Box Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = Shop.prompt.range
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = open
	local keeperAt = at * CFrame.new(0, Shop.shopkeeper.base, Shop.shopkeeper.z)
	local render: Render = {
		model = model,
		parts = parts,
		keeper = standIn(model, keeperAt),
		keeperAt = keeperAt,
		window = shelves,
		windowFill = fill,
		ceiling = ceiling,
		bulbs = bulbs,
		bulbFrames = bulbFrames,
		halos = halos,
	}
	Shop.setNight(render, false)
	model.Parent = parent
	return render
end

-- Window glow and bulbs follow the plot's existing night controller; no Light instances are
-- added, so the shared NightLights budget is unchanged. Clients read `Night` for sleepy Peeka.
function Shop.setNight(render: Render, enabled: boolean)
	render.window.LightInfluence = if enabled then 0 else 1
	render.windowFill.BackgroundColor3 = if enabled then palette.interiorNight else palette.interior
	render.ceiling.Enabled = enabled
	render.bulbs.LightInfluence = if enabled then 0 else 1
	for _, bulb in render.bulbFrames do
		bulb.BackgroundColor3 = if enabled then palette.bulbOn else palette.bulbOff
	end
	for _, halo in render.halos do
		halo.Visible = enabled
	end
	render.model:SetAttribute("Night", enabled)
end

return Shop
