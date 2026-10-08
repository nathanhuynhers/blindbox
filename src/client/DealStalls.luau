--!strict
-- Presentation only: fills each plaza pop-up stall's blank deal slots for this player. The offered
-- box sits on the cake stand, the hanging tag shows old/new price, the cart's pips show this
-- player's own stock and the clock tag counts down from workspace:GetServerTimeNow(). Every edit
-- is local and never replicates. One half-second loop refreshes text; nothing runs per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tweens = game:GetService("TweenService")
local Types = require(ReplicatedStorage.Shared.Types)
local BoxModel = require(ReplicatedStorage.Shared.BlindBoxModel)
local Skin = require(script.Parent.BlindBoxSkin)
local Source = require(script.Parent.OpeningBoxSource)
local Fallback = require(script.Parent.OpeningFallbackBox)
local Scope = require(script.Parent.UIScope)
local Style = require(script.Parent.UIStyle)
local State = require(script.Parent.UIState)
local Stalls = {}
Stalls.style = table.freeze({
	boxHeight = 1.6,
	dimmed = 0.55,
	pink = Color3.fromRGB(242, 141, 178),
	berry = Color3.fromRGB(163, 40, 90),
	brown = Color3.fromRGB(107, 74, 62),
	ivory = Color3.fromRGB(252, 249, 243),
	soon = Color3.fromRGB(255, 231, 168),
	-- Pip fill per stall (the canopy stripe), empty pips stay ivory.
	pips = {
		Color3.fromRGB(143, 211, 176),
		Color3.fromRGB(142, 200, 232),
		Color3.fromRGB(242, 207, 107),
	},
})
local style = Stalls.style

type Stall = {
	model: Model,
	index: number,
	root: Folder,
	box: Model?,
	boxKey: string,
	boxParts: { BasePart },
	tag: { old: TextLabel, new: TextLabel, card: Frame },
	overlay: { sold: Frame, new: Frame, sticker: TextLabel },
	pips: { row: Frame, frames: { Frame }, label: TextLabel },
	clock: { label: TextLabel, time: TextLabel, backing: Frame },
	sparkle: ParticleEmitter,
	status: string,
	-- The Peeka last made sleepy; the uploaded model may replace the placeholder at any time.
	peeka: Instance?,
	sleepy: boolean,
	eyes: { [BasePart]: Vector3 },
}

local function part(parent: Instance, name: string, size: Vector3, at: CFrame): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = at
	object.Anchored = true
	object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
	object.CastShadow = false
	object.Material = Enum.Material.SmoothPlastic
	object.Parent = parent
	return object
end

local function surface(parent: BasePart, name: string, pixels: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.LightInfluence = 0.4
	gui.Parent = parent
	return gui
end

local function frame(
	parent: Instance,
	name: string,
	color: Color3,
	position: UDim2,
	size: UDim2,
	radius: number?
): Frame
	local object = Instance.new("Frame")
	object.Name = name
	object.BorderSizePixel = 0
	object.BackgroundColor3 = color
	object.Position, object.Size = position, size
	object.Parent = parent
	if radius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius)
		corner.Parent = object
	end
	return object
end

local function text(
	parent: Instance,
	name: string,
	value: string,
	color: Color3,
	position: UDim2,
	size: UDim2,
	display: boolean?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position, label.Size = position, size
	label.FontFace = if display then Style.display() else Style.body(Enum.FontWeight.ExtraBold)
	label.TextScaled = true
	label.TextColor3 = color
	label.RichText = true
	label.Text = value
	label.Parent = parent
	return label
end

local function stroke(object: GuiObject, color: Color3, thickness: number)
	local line = Instance.new("UIStroke")
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Color, line.Thickness = color, thickness
	line.Parent = object
end

local function attachment(model: Model, name: string): Attachment?
	local counter = model:FindFirstChild("Counter")
	local found = if counter then counter:FindFirstChild(name) else nil
	return if found and found:IsA("Attachment") then found else nil
end

local function build(model: Model, index: number): Stall?
	local boxAnchor = attachment(model, "BoxAnchor")
	local tagAnchor = attachment(model, "PriceTagAnchor")
	local body = model:FindFirstChild("Body")
	local pipGui = if body then body:FindFirstChild("StockPips") else nil
	local strip = if pipGui then pipGui:FindFirstChild("Strip") else nil
	local clockTag = model:FindFirstChild("ClockTag")
	local face = if clockTag then clockTag:FindFirstChild("ClockFace") else nil
	if
		not boxAnchor
		or not tagAnchor
		or not pipGui
		or not pipGui:IsA("SurfaceGui")
		or not strip
		or not strip:IsA("Frame")
		or not face
		or not face:IsA("SurfaceGui")
	then
		return nil
	end
	local root = Instance.new("Folder")
	root.Name = "DealDisplay"
	root.Parent = model

	-- Hanging price tag beside the box: old price struck through, deal price with a coin.
	local tagPart = part(
		root,
		"PriceTag",
		Vector3.new(1.7, 1.1, 0.06),
		tagAnchor.WorldCFrame * CFrame.Angles(0, 0, math.rad(-6))
	)
	tagPart.Transparency = 1
	local tagGui = surface(tagPart, "Price", 120)
	local card = frame(
		tagGui,
		"Card",
		style.ivory,
		UDim2.fromScale(0.04, 0.06),
		UDim2.fromScale(0.92, 0.88),
		18
	)
	stroke(card, style.brown, 5)
	frame(card, "Hole", style.brown, UDim2.new(0.5, -7, 0, 8), UDim2.fromOffset(14, 14), 7)
	local old = text(
		card,
		"OldPrice",
		"",
		Style.muted,
		UDim2.fromScale(0.12, 0.2),
		UDim2.fromScale(0.76, 0.24)
	)
	local coin =
		frame(card, "Coin", Style.gold, UDim2.fromScale(0.08, 0.52), UDim2.fromScale(0.2, 0.32), 99)
	stroke(coin, Style.coinRing, 4)
	local new = text(
		card,
		"DealPrice",
		"",
		Style.ink,
		UDim2.fromScale(0.3, 0.46),
		UDim2.fromScale(0.64, 0.44),
		true
	)

	-- A transparent panel just in front of the box carries the discount sticker, the NEW! sticker
	-- and the Sold out banner, so none of them needs geometry of its own.
	local overlayPart = part(
		root,
		"Stickers",
		Vector3.new(3, 2, 0.05),
		boxAnchor.WorldCFrame * CFrame.new(0, 0.85, -0.95)
	)
	overlayPart.Transparency = 1
	local overlayGui = surface(overlayPart, "Stickers", 100)
	local sticker = text(
		overlayGui,
		"Discount",
		"",
		Style.white,
		UDim2.fromScale(0.08, 0.04),
		UDim2.fromScale(0.2, 0.3),
		true
	)
	sticker.BackgroundTransparency = 0
	sticker.BackgroundColor3 = style.pink
	sticker.Rotation = -12
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = sticker
	stroke(sticker, Style.ink, 5)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.22, 0), UDim.new(0.22, 0)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0)
	padding.Parent = sticker
	local newSticker = frame(
		overlayGui,
		"New",
		Style.gold,
		UDim2.fromScale(0.68, 0.02),
		UDim2.fromScale(0.26, 0.2),
		14
	)
	newSticker.Rotation = 10
	stroke(newSticker, Style.ink, 5)
	text(
		newSticker,
		"Label",
		"NEW!",
		Style.ink,
		UDim2.fromScale(0.1, 0.12),
		UDim2.fromScale(0.8, 0.76),
		true
	)
	local sold = frame(
		overlayGui,
		"SoldOut",
		Style.white,
		UDim2.fromScale(0.12, 0.4),
		UDim2.fromScale(0.76, 0.26),
		16
	)
	sold.Rotation = -8
	stroke(sold, style.berry, 6)
	text(
		sold,
		"Label",
		"Sold out",
		style.berry,
		UDim2.fromScale(0.08, 0.14),
		UDim2.fromScale(0.84, 0.72),
		true
	)

	-- Stock pips: this player's remaining boxes over a short line, between the wheel caps and
	-- under the "Hourly Deal" plaque.
	strip.Position, strip.Size = UDim2.fromScale(0.335, 0.5), UDim2.fromScale(0.33, 0.44)
	pipGui.PixelsPerStud = 80
	local row = Instance.new("Frame")
	row.Name = "Pips"
	row.BackgroundTransparency = 1
	row.Position, row.Size = UDim2.fromScale(0, 0.04), UDim2.fromScale(1, 0.42)
	row.Parent = strip
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 10)
	list.Parent = row
	local pipLabel =
		text(strip, "Stock", "", Style.ink, UDim2.fromScale(0, 0.52), UDim2.fromScale(1, 0.4))

	-- Clock tag: label and mm:ss beside the painted dial; a gold backing when refresh is near.
	face.PixelsPerStud = 100
	local backing = frame(
		face,
		"Soon",
		style.soon,
		UDim2.fromScale(0.44, 0.08),
		UDim2.fromScale(0.54, 0.84),
		10
	)
	backing.ZIndex = 0
	local clockLabel = text(
		face,
		"Label",
		"",
		style.ivory,
		UDim2.fromScale(0.47, 0.12),
		UDim2.fromScale(0.48, 0.3)
	)
	local clockTime = text(
		face,
		"Time",
		"",
		style.ivory,
		UDim2.fromScale(0.47, 0.42),
		UDim2.fromScale(0.48, 0.48),
		true
	)

	local sparkleAt = Instance.new("Attachment")
	sparkleAt.Name = "Sparkles"
	sparkleAt.Parent = boxAnchor.Parent
	sparkleAt.CFrame = boxAnchor.CFrame * CFrame.new(0, 0.9, 0)
	local sparkle = Instance.new("ParticleEmitter") -- Default built-in sparkle texture.
	sparkle.Name = "DealSparkle"
	sparkle.Rate = 0.8
	sparkle.Lifetime = NumberRange.new(0.6, 1.1)
	sparkle.Speed = NumberRange.new(0.4, 1)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 0.6
	sparkle.Color = ColorSequence.new(Style.gold)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Parent = sparkleAt
	root.Destroying:Connect(function()
		sparkleAt:Destroy()
	end)

	return {
		model = model,
		index = index,
		root = root,
		box = nil,
		boxKey = "",
		boxParts = {},
		tag = { old = old, new = new, card = card },
		overlay = { sold = sold, new = newSticker, sticker = sticker },
		pips = { row = row, frames = {}, label = pipLabel },
		clock = { label = clockLabel, time = clockTime, backing = backing },
		sparkle = sparkle,
		status = "",
		peeka = nil,
		sleepy = false,
		eyes = {},
	}
end

-- The real production box skinned for the collection, else the native collection-tinted box.
local function placeBox(entry: Stall, collection: string)
	local anchor = attachment(entry.model, "BoxAnchor")
	if not anchor then
		return
	end
	local template = Source.resolve(ReplicatedStorage:FindFirstChild("ProductionModels"))
	local key = collection .. (if template then ":production" else ":fallback")
	if entry.boxKey == key and entry.box and entry.box.Parent then
		return
	end
	if entry.box then
		entry.box:Destroy()
	end
	local model: Model
	if template then
		model = template:Clone()
		local surfaces = BoxModel.surfaces(model)
		if surfaces then
			Skin.apply(model, surfaces, collection)
			local _, up, front = BoxModel.axes(surfaces)
			local origin = BoxModel.center(surfaces.BoxBody)
			model.PrimaryPart = nil
			model.WorldPivot = CFrame.lookAt(origin, origin + front, up)
		end
	else
		model = Fallback.create(entry.root, collection).model
	end
	model.Name = "DealBox"
	model:PivotTo(CFrame.new())
	local bounds, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * style.boxHeight / math.max(0.01, size.Y))
	bounds, size = model:GetBoundingBox()
	local bottom = bounds.Position.Y - size.Y / 2
	model:PivotTo(anchor.WorldCFrame * CFrame.new(0, -bottom, 0))
	entry.boxParts = {}
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery =
				true, false, false, false
			table.insert(entry.boxParts, child)
		end
	end
	model.Parent = entry.root
	entry.box, entry.boxKey = model, key
end

-- Sleepy: the uploaded Peeka's open eyes squash to closed lines and their shine hides.
local function setSleepy(entry: Stall, sleepy: boolean)
	local peeka = entry.model:FindFirstChild("Peeka")
	if peeka ~= entry.peeka then
		entry.peeka, entry.sleepy = peeka, false
		table.clear(entry.eyes)
	end
	if entry.sleepy == sleepy or not peeka then
		return
	end
	entry.sleepy = sleepy
	for _, child in peeka:GetDescendants() do
		if child:IsA("BasePart") then
			if string.sub(child.Name, -9) == "_EyeShine" then
				child.LocalTransparencyModifier = if sleepy then 1 else 0
			elseif string.sub(child.Name, -5) == "_Eyes" then
				local rest = entry.eyes[child] or child.Size
				entry.eyes[child] = rest
				-- Squash along whichever local axis points up in the world.
				local cf = child.CFrame
				local x, y, z =
					math.abs(cf.RightVector.Y), math.abs(cf.UpVector.Y), math.abs(cf.LookVector.Y)
				local scale = if y >= x and y >= z
					then Vector3.new(1, 0.22, 1)
					elseif x >= z then Vector3.new(0.22, 1, 1)
					else Vector3.new(1, 1, 0.22)
				child.Size = if sleepy then rest * scale else rest
			end
		end
	end
end

local function render(entry: Stall, deal: State.Deal?, effects: boolean)
	if not deal then
		return
	end
	placeBox(entry, deal.collection)
	local sold = deal.status == "soldout"
	for _, child in entry.boxParts do
		child.LocalTransparencyModifier = if sold then style.dimmed else 0
	end
	entry.tag.old.Text = `<s>{State.compact(deal.price)}</s>`
	entry.tag.new.Text = State.compact(deal.deal)
	entry.tag.card.Visible = not sold
	entry.overlay.sticker.Text = `-{deal.percent}%`
	entry.overlay.sticker.Visible = not sold and deal.percent > 0
	entry.overlay.sold.Visible = sold
	entry.overlay.new.Visible = deal.status == "fresh"
	entry.sparkle.Enabled = effects and (deal.status == "available" or deal.status == "fresh")
	local frames = entry.pips.frames
	while #frames < deal.stock do
		local pip =
			frame(entry.pips.row, "Pip", style.ivory, UDim2.new(), UDim2.new(0, 40, 1, 0), 7)
		pip.LayoutOrder = #frames + 1
		stroke(pip, style.brown, 4)
		table.insert(frames, pip)
	end
	for index, pip in frames do
		pip.Visible = index <= deal.stock
		pip.BackgroundColor3 = if index <= deal.left
			then style.pips[entry.index] or Style.violet
			else style.ivory
		pip.BackgroundTransparency = if index <= deal.left then 0 else 0.25
	end
	entry.pips.label.Text = deal.stockText
	entry.pips.label.TextColor3 = if deal.left == 1
		then style.berry
		elseif sold then Style.muted
		else Style.ink
	local soon = deal.status == "soon"
	entry.clock.label.Text = deal.clockLabel
	entry.clock.time.Text = deal.clock
	entry.clock.backing.Visible = soon
	entry.clock.label.TextColor3 = if soon then Style.ink else style.ivory
	entry.clock.time.TextColor3 = if soon then Style.ink else style.ivory
	setSleepy(entry, sold)
	entry.status = deal.status
end

-- A small "just restocked" moment: Peeka hops twice and a sparkle burst pops from the box.
local function celebrate(entry: Stall, scope: Scope.Scope)
	local peeka = entry.model:FindFirstChild("Peeka")
	if peeka and peeka:IsA("Model") then
		local rest = peeka:GetPivot()
		local lift = Instance.new("NumberValue")
		scope.connect(lift.Changed, function()
			if peeka.Parent then
				peeka:PivotTo(rest * CFrame.new(0, lift.Value, 0))
			end
		end)
		local hop = Tweens:Create(
			lift,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 3, true),
			{ Value = 0.45 }
		)
		scope.connect(hop.Completed, function()
			if peeka.Parent then
				peeka:PivotTo(rest)
			end
			lift:Destroy()
		end)
		hop:Play()
	end
	entry.sparkle:Emit(14)
end

export type Controller = { update: (Types.Snapshot) -> (), destroy: () -> () }

function Stalls.create(effects: () -> boolean): Controller
	local scope = Scope.create()
	local snapshot: Types.Snapshot? = nil
	local entries: { [number]: Stall } = {}
	local seenWindow: number? = nil
	local function stallModels(): { [number]: Model }
		local found: { [number]: Model } = {}
		local world = workspace:FindFirstChild("MainWorld")
		local plaza = if world then world:FindFirstChild("MainPlaza") else nil
		if plaza then
			for _, child in plaza:GetChildren() do
				local index = child:GetAttribute("DealStall")
				if child:IsA("Model") and typeof(index) == "number" then
					found[index] = child
				end
			end
		end
		return found
	end
	local function refresh()
		local state = snapshot
		if not state then
			return
		end
		local now = workspace:GetServerTimeNow()
		for index, model in stallModels() do
			local existing = entries[index]
			if existing and existing.model ~= model then
				existing.root:Destroy()
				entries[index] = nil
			end
			local entry: Stall? = entries[index] or build(model, index)
			if entry then
				entries[index] = entry
				render(entry, State.deal(state, index, now), effects())
			end
		end
	end
	local loop = task.spawn(function()
		while true do
			refresh()
			task.wait(0.5)
		end
	end)
	scope.add(function()
		task.cancel(loop)
		for _, entry in entries do
			setSleepy(entry, false)
			entry.root:Destroy()
		end
	end)
	return {
		update = function(state: Types.Snapshot)
			local previous = seenWindow
			snapshot = state
			seenWindow = state.deals.window
			refresh()
			if previous and previous ~= state.deals.window and effects() then
				for _, entry in entries do
					celebrate(entry, scope)
				end
			end
		end,
		destroy = scope.destroy,
	}
end

return Stalls
