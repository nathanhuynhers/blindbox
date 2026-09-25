--!strict
local TweenService = game:GetService("TweenService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local FigureModel = require(game:GetService("ReplicatedStorage").Shared.FigureModel)
local Config = require(script.Parent.OpeningConfig)
local Box = require(script.Parent.OpeningBox)
local OpeningState = require(script.Parent.OpeningState)
local OpeningResult = require(script.Parent.OpeningResult)
local View = {}
export type View = {
	draw: (OpeningState.State, boolean) -> (),
	primary: TextButton,
	hitTarget: TextButton,
	skip: TextButton,
	resized: RBXScriptSignal,
	destroy: () -> (),
}

local function corner(parent: GuiObject, radius: number)
	local shape = Instance.new("UICorner")
	shape.CornerRadius = UDim.new(0, radius)
	shape.Parent = parent
end

local function label(parent: Instance, size: number): TextLabel
	local object = Instance.new("TextLabel")
	object.BackgroundTransparency = 1
	object.TextColor3 = Color3.fromRGB(247, 247, 232)
	object.Font = Enum.Font.GothamMedium
	object.TextScaled = true
	object.TextWrapped = true
	object.Text = ""
	object.ZIndex = 5
	object.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = 10
	limit.Parent = object
	return object
end

local function button(parent: Instance): TextButton
	local object = Instance.new("TextButton")
	object.BackgroundColor3 = Color3.fromRGB(238, 239, 214)
	object.TextColor3 = Color3.fromRGB(29, 56, 53)
	object.Font = Enum.Font.GothamBold
	object.TextSize = 17
	object.AutoButtonColor = true
	object.ZIndex = 8
	object.Parent = parent
	corner(object, 18)
	return object
end

local function ease(progress: number, style: Enum.EasingStyle?): number
	return TweenService:GetValue(
		progress,
		style or Enum.EasingStyle.Cubic,
		Enum.EasingDirection.Out
	)
end

function View.create(
	gui: ScreenGui,
	result: OpeningResult.Result,
	profile: Config.Profile,
	reduced: boolean
): View
	local figure = Catalog.byId[result.figureId]
	local collectionName = figure.collection
	for _, collection in Catalog.collections do
		if collection.id == figure.collection then
			collectionName = collection.name
		end
	end
	local group = Instance.new("CanvasGroup")
	group.Name = "OpeningStage"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundColor3 = Color3.fromRGB(13, 28, 35)
	group.BackgroundTransparency = 0.08
	group.BorderSizePixel = 0
	group.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(120, 165, 158), Color3.fromRGB(65, 82, 125))
	gradient.Rotation = 75
	gradient.Parent = group
	local blocker = Instance.new("TextButton")
	blocker.Name = "InputShield"
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.Modal = true
	blocker.Selectable = false
	blocker.Parent = group
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -40, 1, -32)
	content.Position = UDim2.fromOffset(20, 16)
	content.BackgroundTransparency = 1
	content.Parent = group
	local heading = label(content, 16)
	heading.Text = string.upper(collectionName)
	heading.TextColor3 = Color3.fromRGB(195, 215, 212)
	heading.Size = UDim2.new(1, -112, 0, 32)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	local skip = button(content)
	skip.Name = "Skip"
	skip.Text = "Skip"
	skip.Size = UDim2.fromOffset(100, 48)
	skip.Position = UDim2.new(1, -100, 0, 0)
	skip.BackgroundTransparency = 0.9
	skip.TextColor3 = Color3.fromRGB(229, 234, 231)
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.BackgroundTransparency = 1
	hero.Parent = content
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(0.84, 0.84)
	halo.BackgroundTransparency = 1
	halo.Parent = hero
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = halo
	local glows: { Frame } = {}
	for index = 1, 4 do
		local glow = Instance.new("Frame")
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromScale(1 - index * 0.12, 1 - index * 0.12)
		glow.BackgroundColor3 = profile.tint
		glow.BorderSizePixel = 0
		glow.Parent = halo
		corner(glow, 1000)
		table.insert(glows, glow)
	end
	local rings: { UIStroke } = {}
	for index = 1, profile.rings do
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(0.8 + index * 0.09, 0.8 + index * 0.09)
		ring.BackgroundTransparency = 1
		ring.Parent = halo
		corner(ring, 1000)
		local stroke = Instance.new("UIStroke")
		stroke.Color = profile.tint
		stroke.Thickness = if index == 1 then 2 else 1
		stroke.Parent = ring
		table.insert(rings, stroke)
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Collectible"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(193, 205, 215)
	viewport.LightColor = Color3.fromRGB(255, 240, 212)
	viewport.LightDirection = Vector3.new(-1, -1, -2)
	viewport.ZIndex = 3
	viewport.Parent = hero
	local camera = Instance.new("Camera")
	camera.FieldOfView = 36
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local hitTarget = Instance.new("TextButton")
	hitTarget.Name = "TapBox"
	hitTarget.Size = UDim2.fromScale(1, 1)
	hitTarget.BackgroundTransparency = 1
	hitTarget.Text = ""
	hitTarget.Selectable = false
	hitTarget.ZIndex = 6
	hitTarget.Parent = hero
	local box = Box.create(viewport, figure.collection)
	local model = FigureModel.create(result.figureId, CFrame.new())
	local bounds, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-bounds.Position) * model:GetPivot())
	local figureOrigin = model:GetPivot()
	local colors: { [BasePart]: Color3 } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			colors[descendant] = descendant.Color
		end
	end
	-- Keep both models under an owned folder when hidden, never loose in workspace.
	local hidden = Instance.new("Folder")
	hidden.Name = "HiddenAssets"
	hidden.Parent = gui
	model.Parent = hidden
	local particles: { Frame } = {}
	if not reduced then
		for index = 1, profile.particles do
			local spark = Instance.new("Frame")
			spark.Name = "Spark"
			spark.AnchorPoint = Vector2.new(0.5, 0.5)
			spark.Size =
				UDim2.fromOffset(if index % 3 == 0 then 7 else 4, if index % 3 == 0 then 7 else 4)
			spark.BackgroundColor3 = if index % 2 == 0 then profile.accent else profile.tint
			spark.BorderSizePixel = 0
			spark.Rotation = 45
			spark.Visible = false
			spark.ZIndex = 4
			spark.Parent = halo
			table.insert(particles, spark)
		end
	end
	local info = Instance.new("Frame")
	info.Name = "Result"
	info.BackgroundTransparency = 1
	info.Parent = content
	local badge = label(info, 15)
	badge.Size = UDim2.fromOffset(124, 26)
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromScale(0.5, 0)
	badge.Text = "NEW!"
	badge.Font = Enum.Font.GothamBold
	badge.TextColor3 = Color3.fromRGB(32, 54, 49)
	badge.BackgroundColor3 = profile.accent
	badge.BackgroundTransparency = 0
	corner(badge, 13)
	local name = label(info, 32)
	name.Font = Enum.Font.GothamBold
	name.Position = UDim2.fromOffset(0, 30)
	name.Size = UDim2.new(1, 0, 0, 38)
	local detail = label(info, 16)
	detail.Position = UDim2.fromOffset(0, 72)
	detail.Size = UDim2.new(1, 0, 0, 40)
	detail.TextColor3 = profile.tint
	local primary = button(content)
	primary.Name = "OpenOrContinue"
	local hint = label(content, 13)
	hint.TextColor3 = Color3.fromRGB(185, 200, 202)
	hint.Size = UDim2.new(1, 0, 0, 20)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.fromScale(0.5, 1)
	local function layout()
		local compact = content.AbsoluteSize.Y < 500
			and content.AbsoluteSize.X > content.AbsoluteSize.Y
		hero.Position = if compact then UDim2.fromScale(0, 0.1) else UDim2.fromScale(0.02, 0.09)
		hero.Size = if compact then UDim2.fromScale(0.56, 0.84) else UDim2.fromScale(0.96, 0.5)
		info.Position = if compact then UDim2.fromScale(0.58, 0.23) else UDim2.fromScale(0.04, 0.58)
		info.Size = if compact then UDim2.fromScale(0.4, 0.4) else UDim2.fromScale(0.92, 0.22)
		primary.AnchorPoint = Vector2.new(0.5, 1)
		primary.Position = if compact then UDim2.new(0.78, 0, 1, -28) else UDim2.new(0.5, 0, 1, -30)
		primary.Size = if compact then UDim2.new(0.36, 0, 0, 52) else UDim2.new(0.72, 0, 0, 54)
		hint.Position = UDim2.fromScale(if compact then 0.78 else 0.5, 1)
		hint.Size = UDim2.new(if compact then 0.44 else 1, 0, 0, 20)
	end
	layout()
	local layoutConnection = content:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	local lastPhase: OpeningState.Phase? = nil
	local function draw(state: OpeningState.State, gamepad: boolean)
		local phase: OpeningState.Phase = state.phase
		local progress = OpeningState.progress(state)
		local final = phase == "Reveal" or phase == "Result" or phase == "Closing"
		local showingFigure = final or phase == "Silhouette"
		if phase ~= lastPhase then
			lastPhase = phase
			box.model.Parent = if showingFigure then hidden else viewport
			model.Parent = if showingFigure then viewport else hidden
			for part, color in colors do
				part.Color = if final then color else Color3.fromRGB(18, 31, 42)
			end
			badge.Visible = final and result.isNew
			name.Text = if final
				then figure.name
				elseif phase == "Silhouette" then "A little wonder..."
				else ""
			detail.Text = if final
				then figure.rarity .. (if result.isNew
					then ""
					else "  ·  " .. result.quantity .. " owned\nAnother for your collection")
				else ""
			primary.Visible = phase == "Await" or phase == "Result"
			hitTarget.Visible = phase == "Await"
			skip.Visible = phase ~= "Enter" and phase ~= "Result" and phase ~= "Closing"
		end
		primary.Text = if phase == "Result"
			then (if gamepad then "A  ·  Continue" else "Continue")
			else (if gamepad then "A  ·  Open" else "Tap to open")
		primary.Selectable = phase == "Await" or (phase == "Result" and state.elapsed >= 0.35)
		skip.Text = if gamepad then "B  ·  Skip" else "Skip"
		hint.Text = if phase == "Await"
			then "Your little wonder is ready"
			elseif phase == "Result" then ""
			elseif skip.Visible then (if gamepad then "B to skip" else "Skip anytime")
			else ""
		local emphasis = if phase == "Shake"
			then progress
			elseif phase == "Await" then 1
			elseif showingFigure or phase == "Open" then 1
			else 0.15
		for index, glow in glows do
			glow.BackgroundTransparency = 0.97
				- emphasis * (if reduced then 0.018 else 0.035)
				- index * 0.003
		end
		for _, stroke in rings do
			stroke.Transparency = 0.9 - emphasis * 0.5
		end
		local fade = if phase == "Enter"
			then 1 - math.clamp(progress * 3, 0, 1)
			elseif phase == "Closing" then progress
			else 0
		group.GroupTransparency = fade
		local aspectRatio =
			math.max(0.35, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
		local extent = if showingFigure then math.max(size.X, size.Y, size.Z) * 0.5 else 2.7
		local distance = extent / (math.tan(math.rad(18)) * math.min(1, aspectRatio)) * 1.28
		local enter = if phase == "Enter" and not reduced
			then 1 - ease(progress, Enum.EasingStyle.Back)
			else 0
		local reveal = if phase == "Reveal" and not reduced
			then ease(progress, Enum.EasingStyle.Back)
			else 1
		camera.CFrame =
			CFrame.lookAt(Vector3.new(0, 0.5, -distance * (1 + enter * 0.2)), Vector3.zero)
		if showingFigure then
			model:PivotTo(
				CFrame.new(0, if reduced then 0 else (reveal - 1) * 0.65, 0)
					* CFrame.Angles(0, if reduced then 0 else (reveal - 1) * 0.4, 0)
					* figureOrigin
			)
			viewport.ImageTransparency = if phase == "Reveal" and reduced then 1 - progress else 0
		else
			local shake = if phase == "Shake" and not reduced
				then math.sin(progress * math.pi * 14) * profile.shake * (0.15 + progress * 0.85)
				else 0
			local lift = if phase == "Open"
				then (if reduced then progress * 0.6 else ease(progress) * 3.3)
				else 0
			box.pose(
				CFrame.new(0, -enter * 3, 0)
					* CFrame.Angles(-0.06, 0.24 + enter * 0.6, shake + enter * -0.12),
				lift
			)
			viewport.ImageTransparency = if phase == "Open"
				then math.max(0, (progress - 0.55) / 0.45)
				else 0
		end
		local burst = phase == "Open" or phase == "Silhouette" or phase == "Reveal"
		local burstProgress = if phase == "Open"
			then progress * 0.35
			elseif phase == "Silhouette" then 0.35 + progress * 0.25
			else 0.6 + progress * 0.4
		for index, spark in particles do
			spark.Visible = burst
			if burst then
				local angle = index * math.pi * 2 / #particles + index * 0.27
				local radius = (0.12 + ease(burstProgress) * 0.43) * (0.8 + (index % 3) * 0.1)
				spark.Position =
					UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius)
				spark.BackgroundTransparency = math.clamp((burstProgress - 0.65) / 0.35, 0, 1)
				spark.Rotation = 45 + burstProgress * (if index % 2 == 0 then 65 else -65)
			end
		end
		badge.Rotation = if phase == "Reveal" and not reduced then (1 - ease(progress)) * -8 else 0
	end
	return {
		draw = draw,
		primary = primary,
		hitTarget = hitTarget,
		skip = skip,
		resized = viewport:GetPropertyChangedSignal("AbsoluteSize"),
		destroy = function()
			layoutConnection:Disconnect()
		end,
	}
end

return View
