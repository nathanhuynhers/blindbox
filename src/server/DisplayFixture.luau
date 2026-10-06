--!strict
-- Native-part interpretation of the supplied oak/ivory collectible-store concept board.
local Display = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Geometry = require(script.Parent.PlotGeometry)
local Awning = require(script.Parent.Awning)
local PlotStyle = require(script.Parent.PlotStyle)
local Fixture = {}
Fixture.style =
	table.freeze({ spacing = 8, sideMargin = 6, counterY = 3, figureScale = 2, title = "DISPLAY" })
Fixture.lighting = table.freeze({ dayBrightness = 0.65, nightBrightness = 1.25 })
Fixture.management = table.freeze({ x = 0, y = 0.45, frontOffset = -7 })
-- Striped awning above the sign: raised back edge behind the panel, lower front over the counter.
-- The valance bottom (frontY - 1.4) stays above the sign top (Y=13.3) so the sign stays readable.
Fixture.awning =
	table.freeze({ backY = 17.6, backZ = 4.2, depth = 8.6, rise = 2.6, overhang = 0.5 })
local ivory = Color3.fromRGB(242, 235, 220)
local oak = Color3.fromRGB(198, 165, 120)
local warmPanel = Color3.fromRGB(235, 225, 204)
local charcoal = Color3.fromRGB(48, 46, 43)
local coinGold = Color3.fromRGB(220, 162, 44)
-- Low-profile floor inlays, clear of the counter front and the walking/expansion space.
Fixture.plate = table.freeze({ width = 5.8, depth = 3.8, frontOffset = -7.5, debounce = 0.35 })
export type Plate = { model: Model, base: Part, target: Part, cue: TextLabel }
type Piece = {
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	wood: boolean?,
	inset: number?,
	edge: number?,
}
-- inset pieces span the fixture; edge pieces follow its ends. Everything else stays centered.
local pieces: { Piece } = {
	{
		name = "RecessedPlinth",
		size = Vector3.new(1, 0.45, 7.5),
		offset = Vector3.new(0, 0.225, 0),
		color = charcoal,
		inset = 1,
	},
	{
		name = "OakBase",
		size = Vector3.new(1, 1.7, 8),
		offset = Vector3.new(0, 1.3, 0),
		color = oak,
		wood = true,
		inset = 0.4,
	},
	{
		name = "Counter",
		size = Vector3.new(1, 0.85, 8.5),
		offset = Vector3.new(0, 2.575, 0),
		color = ivory,
		inset = 0,
	},
	{
		name = "BackPanel",
		size = Vector3.new(1, 7.3, 0.6),
		offset = Vector3.new(0, 6.65, 3.45),
		color = warmPanel,
		inset = 2,
	},
	{
		name = "LeftSupport",
		size = Vector3.new(0.9, 7.3, 2),
		offset = Vector3.new(0, 6.65, 2.6),
		color = oak,
		wood = true,
		edge = -1,
	},
	{
		name = "RightSupport",
		size = Vector3.new(0.9, 7.3, 2),
		offset = Vector3.new(0, 6.65, 2.6),
		color = oak,
		wood = true,
		edge = 1,
	},
	{
		name = "LeftInnerTrim",
		size = Vector3.new(0.22, 7.3, 0.22),
		offset = Vector3.new(0.56, 6.65, 1.6),
		color = ivory,
		edge = -1,
	},
	{
		name = "RightInnerTrim",
		size = Vector3.new(0.22, 7.3, 0.22),
		offset = Vector3.new(-0.56, 6.65, 1.6),
		color = ivory,
		edge = 1,
	},
	{
		name = "TopFascia",
		size = Vector3.new(1, 0.9, 6.8),
		offset = Vector3.new(0, 10.55, 0.9),
		color = ivory,
		inset = -0.5,
	},
	{
		name = "OakCrown",
		size = Vector3.new(1, 0.24, 5.8),
		offset = Vector3.new(0, 11.12, 1.1),
		color = oak,
		wood = true,
		inset = 1.2,
	},
	{
		name = "WarmDiffuser",
		size = Vector3.new(1, 0.12, 0.65),
		offset = Vector3.new(0, 10.04, -1.6),
		color = Color3.fromRGB(255, 237, 199),
		inset = 3,
	},
	{
		name = "LeftAwningPost",
		size = Vector3.new(0.5, 6.8, 0.5),
		offset = Vector3.new(0, 13.7, 3),
		color = oak,
		wood = true,
		edge = -1,
	},
	{
		name = "RightAwningPost",
		size = Vector3.new(0.5, 6.8, 0.5),
		offset = Vector3.new(0, 13.7, 3),
		color = oak,
		wood = true,
		edge = 1,
	},
	{
		name = "SignFrame",
		size = Vector3.new(13.6, 3.6, 0.65),
		offset = Vector3.new(0, 11.5, -2.35),
		color = oak,
		wood = true,
	},
	{
		name = "SignRecess",
		size = Vector3.new(12.95, 2.95, 0.12),
		offset = Vector3.new(0, 11.5, -2.72),
		color = Color3.fromRGB(171, 143, 106),
	},
	{
		name = "SignFace",
		size = Vector3.new(12.65, 2.65, 0.12),
		offset = Vector3.new(0, 11.5, -2.81),
		color = Color3.fromRGB(255, 246, 222),
	},
	{
		name = "CollectSignFrame",
		size = Vector3.new(16, 1.5, 0.24),
		offset = Vector3.new(0, 1.25, -4.05),
		color = oak,
		wood = true,
	},
	{
		name = "CollectSignFace",
		size = Vector3.new(15.5, 1.1, 0.12),
		offset = Vector3.new(0, 1.25, -4.24),
		color = ivory,
	},
}
export type Render = {
	model: Model,
	transform: CFrame,
	parts: { [string]: Part },
	rate: TextLabel,
	capacity: number,
	accent: Color3,
	awning: Model?,
	light: SurfaceLight,
	plates: { Plate },
}
local function createPlate(parent: Instance, slot: number): Plate
	local model = Instance.new("Model")
	model.Name = "CollectionPlate" .. slot
	model:SetAttribute("SlotId", slot)
	model.Parent = parent
	local base = Geometry.partAt(
		model,
		"OakRim",
		Vector3.new(Fixture.plate.width, 0.12, Fixture.plate.depth),
		CFrame.new(),
		oak
	)
	local target = Geometry.partAt(
		model,
		"Step",
		Vector3.new(Fixture.plate.width - 0.4, 0.08, Fixture.plate.depth - 0.4),
		CFrame.new(),
		ivory
	)
	for _, part in { base, target } do
		part.Material = if part == base then Enum.Material.Wood else Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
	-- Keep the six listeners alive across empty/locked/occupied transitions. Roblox disconnects
	-- Touched when CanTouch becomes false; server slot validation controls eligibility instead.
	target.CanTouch = true
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CollectionCue"
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(460, 260)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0.35
	gui.Active = false
	gui.Parent = target
	local cue = Instance.new("TextLabel")
	cue.Name = "Cue"
	cue.Size = UDim2.fromScale(1, 1)
	cue.BackgroundTransparency = 1
	cue.Font = Enum.Font.GothamBold
	cue.TextSize = 34
	cue.TextColor3 = charcoal
	cue.Text = "—"
	cue.Parent = gui
	return { model = model, base = base, target = target, cue = cue }
end
function Fixture.setPlates(render: Render, slots: { string })
	for slot, plate in render.plates do
		local unlocked = slot <= render.capacity
		local active = unlocked and (slots[slot] or "") ~= ""
		plate.base.Transparency = if unlocked then 0 else 1
		plate.target.Transparency = if unlocked then 0 else 1
		plate.target.Color = if active then ivory:Lerp(render.accent, 0.18) else warmPanel
		plate.cue.Visible = unlocked
		plate.cue.Text = if active then "●  COLLECT" else "—"
		plate.cue.TextColor3 = if active then coinGold else oak
	end
end
function Fixture.width(capacity: number): number
	assert(
		capacity >= Display.defaultSlots and capacity <= Display.maxSlots and capacity % 1 == 0,
		"Invalid Display capacity"
	)
	return (capacity - 1) * Fixture.style.spacing + 2 * Fixture.style.sideMargin
end
function Fixture.anchors(transform: CFrame, capacity: number): { [string]: CFrame }
	Fixture.width(capacity)
	local anchors: { [string]: CFrame } = {}
	for slot = 1, capacity do
		anchors[tostring(slot)] = transform
			* CFrame.new(
				(slot - (capacity + 1) / 2) * Fixture.style.spacing,
				Fixture.style.counterY,
				Geometry.displayZ
			)
	end
	return anchors
end
function Fixture.resize(render: Render, capacity: number)
	if render.capacity == capacity then
		return
	end
	local width = Fixture.width(capacity)
	for _, piece in pieces do
		local part = render.parts[piece.name]
		part.Size = Vector3.new(
			if piece.inset then width - piece.inset else piece.size.X,
			piece.size.Y,
			piece.size.Z
		)
		part.CFrame = render.transform
			* CFrame.new(
				if piece.edge
					then piece.edge * (width / 2 - 1.1) + piece.offset.X
					else piece.offset.X,
				piece.offset.Y,
				Geometry.displayZ + piece.offset.Z
			)
	end
	if render.awning then
		render.awning:Destroy()
	end
	local awning = Fixture.awning
	render.awning = Awning.build(
		render.model,
		"Awning",
		render.transform * CFrame.new(0, awning.backY, Geometry.displayZ + awning.backZ),
		width + 2 * awning.overhang,
		awning.depth,
		awning.rise,
		render.accent
	)
	local manage = render.parts.ManageDisplay
	manage.CFrame = render.transform
		* CFrame.new(
			Fixture.management.x,
			Fixture.management.y,
			Geometry.displayZ + Fixture.management.frontOffset
		)
	render.capacity = capacity
	for slot, plate in render.plates do
		local at = render.transform
			* CFrame.new(
				(slot - (capacity + 1) / 2) * Fixture.style.spacing,
				0,
				Geometry.displayZ + Fixture.plate.frontOffset
			)
		plate.base.CFrame = at * CFrame.new(0, 0.06, 0)
		plate.target.CFrame = at * CFrame.new(0, 0.16, 0)
	end
end
function Fixture.create(parent: Instance, transform: CFrame, accent: Color3?): Render
	local model = Instance.new("Model")
	model.Name = "DisplayFixture"
	local parts: { [string]: Part } = {}
	for _, piece in pieces do
		local part = Geometry.partAt(model, piece.name, piece.size, transform, piece.color)
		part.Material = if piece.wood then Enum.Material.Wood else Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanTouch = false
		parts[piece.name] = part
	end
	local light = Instance.new("SurfaceLight")
	light.Name = "WarmWash"
	light.Face = Enum.NormalId.Bottom
	light.Color = Color3.fromRGB(255, 227, 180)
	light.Brightness = Fixture.lighting.dayBrightness
	light.Range = 12
	light.Angle = 110
	light.Shadows = false
	light.Parent = parts.WarmDiffuser
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DisplaySign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1000, 210)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0.35
	gui.Parent = parts.SignFace
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.92, 0.6)
	title.Position = UDim2.fromScale(0.04, 0.04)
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = charcoal
	title.TextScaled = true
	title.Text = Fixture.style.title
	title.Parent = gui
	local rate = Instance.new("TextLabel")
	rate.Name = "Income"
	rate.BackgroundTransparency = 1
	rate.Size = UDim2.fromScale(0.68, 0.28)
	rate.Position = UDim2.fromScale(0.18, 0.67)
	rate.Font = Enum.Font.GothamMedium
	rate.TextColor3 = charcoal
	rate.TextScaled = true
	rate.Text = "0 Coins/sec"
	rate.Parent = gui
	local coin = Instance.new("TextLabel")
	coin.Name = "Coin"
	coin.BackgroundTransparency = 1
	coin.Size = UDim2.fromScale(0.065, 0.28)
	coin.Position = UDim2.fromScale(0.105, 0.67)
	coin.Text = "●"
	coin.TextScaled = true
	coin.TextColor3 = coinGold
	coin.Parent = gui
	-- A non-interactive plaque on the counter front, away from the figure click targets.
	local instructions = Instance.new("SurfaceGui")
	instructions.Name = "CollectSign"
	instructions.Face = Enum.NormalId.Front
	instructions.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	instructions.CanvasSize = Vector2.new(1000, 72)
	instructions.AlwaysOnTop = false
	instructions.LightInfluence = 0.35
	instructions.Active = false
	instructions.Parent = parts.CollectSignFace
	local instruction = Instance.new("TextLabel")
	instruction.Name = "Instruction"
	instruction.BackgroundTransparency = 1
	instruction.Size = UDim2.fromScale(0.94, 0.88)
	instruction.Position = UDim2.fromScale(0.03, 0.06)
	instruction.Font = Enum.Font.GothamBold
	instruction.TextColor3 = charcoal
	instruction.TextScaled = true
	instruction.Text = "Step on a Plate or Click / Tap its Figure to Collect"
	instruction.Parent = instructions
	-- Keep the native management prompt centered near the floor so its large card stays below figures.
	-- resize() preserves that position at every supported Display capacity.
	local manage = Geometry.partAt(model, "ManageDisplay", Vector3.new(1, 1, 1), transform, ivory)
	manage.Transparency = 1
	manage.CanCollide = false
	manage.CanTouch = false
	manage.CanQuery = false
	parts.ManageDisplay = manage
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ManageDisplayPrompt"
	prompt.ActionText = "Manage Display"
	prompt.ObjectText = "Display"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = manage
	local render: Render = {
		model = model,
		transform = transform,
		parts = parts,
		rate = rate,
		capacity = 0,
		accent = accent or PlotStyle.DefaultAccent,
		awning = nil,
		light = light,
		plates = {},
	}
	for slot = 1, Display.maxSlots do
		table.insert(render.plates, createPlate(model, slot))
	end
	Fixture.resize(render, Display.defaultSlots)
	Fixture.setPlates(render, {})
	model.Parent = parent
	return render
end
function Fixture.setNight(render: Render, enabled: boolean)
	render.light.Brightness = if enabled
		then Fixture.lighting.nightBrightness
		else Fixture.lighting.dayBrightness
end
function Fixture.setRate(render: Render, rate: number)
	local text = string.format("%g Coins/sec", rate)
	if render.rate.Text ~= text then
		render.rate.Text = text
	end
end
return Fixture
