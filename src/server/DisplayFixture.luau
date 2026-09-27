--!strict
-- Native-part interpretation of the supplied oak/ivory collectible-store concept board.
local Display = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Geometry = require(script.Parent.PlotGeometry)
local Fixture = {}
Fixture.style =
	table.freeze({ spacing = 8, sideMargin = 6, counterY = 3, figureScale = 2, title = "DISPLAY" })
local ivory = Color3.fromRGB(242, 235, 220)
local oak = Color3.fromRGB(198, 165, 120)
local warmPanel = Color3.fromRGB(235, 225, 204)
local charcoal = Color3.fromRGB(48, 46, 43)
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
}
export type Render = {
	model: Model,
	origin: Vector3,
	parts: { [string]: Part },
	rate: TextLabel,
	capacity: number,
}
function Fixture.width(capacity: number): number
	assert(
		capacity >= Display.defaultSlots and capacity <= Display.maxSlots and capacity % 1 == 0,
		"Invalid Display capacity"
	)
	return (capacity - 1) * Fixture.style.spacing + 2 * Fixture.style.sideMargin
end
function Fixture.anchors(origin: Vector3, capacity: number): { [string]: CFrame }
	Fixture.width(capacity)
	local anchors: { [string]: CFrame } = {}
	for slot = 1, capacity do
		anchors[tostring(slot)] = CFrame.new(
			origin
				+ Vector3.new(
					(slot - (capacity + 1) / 2) * Fixture.style.spacing,
					Fixture.style.counterY,
					Geometry.displayZ
				)
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
		part.Position = render.origin
			+ Vector3.new(
				if piece.edge
					then piece.edge * (width / 2 - 1.1) + piece.offset.X
					else piece.offset.X,
				piece.offset.Y,
				Geometry.displayZ + piece.offset.Z
			)
	end
	render.capacity = capacity
end
function Fixture.create(parent: Instance, origin: Vector3): Render
	local model = Instance.new("Model")
	model.Name = "DisplayFixture"
	local parts: { [string]: Part } = {}
	for _, piece in pieces do
		local part = Geometry.part(model, piece.name, piece.size, origin, piece.color)
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
	light.Brightness = 0.65
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
	coin.TextColor3 = Color3.fromRGB(220, 162, 44)
	coin.Parent = gui
	local render: Render =
		{ model = model, origin = origin, parts = parts, rate = rate, capacity = 0 }
	Fixture.resize(render, Display.defaultSlots)
	model.Parent = parent
	return render
end
function Fixture.setRate(render: Render, rate: number)
	local text = string.format("%g Coins/sec", rate)
	if render.rate.Text ~= text then
		render.rate.Text = text
	end
end
return Fixture
