--!strict
local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.NavigationConfig)
local Scope = require(script.Parent.UIScope)
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)

local NavigationButton = {}

export type Button = {
	button: TextButton,
	layout: (boolean, number, number) -> (),
	setSelected: (boolean) -> (),
	setBadge: (string?) -> (),
}

local LAVENDER = Color3.fromRGB(246, 242, 250)
local LAVENDER_ACTIVE = Color3.fromRGB(234, 225, 244)
local WARM = Color3.fromRGB(255, 247, 229)
local WARM_ACTIVE = Color3.fromRGB(255, 237, 198)
local GOLD_INK = Color3.fromRGB(124, 83, 38)

function NavigationButton.create(
	parent: Instance,
	item: Config.Item,
	image: string,
	scope: Scope.Scope,
	effects: () -> boolean,
	choose: (string) -> ()
): Button
	local button = Instance.new("TextButton")
	button.Name = "Nav" .. item.id
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.ClipsDescendants = false
	button.LayoutOrder = 0
	button.Text = ""
	button.ZIndex = 8
	button.Parent = parent
	button:SetAttribute("NavigationLabel", item.label)

	local buttonScale = Instance.new("UIScale")
	buttonScale.Parent = button

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = Theme.shadow
	shadow.BackgroundTransparency = 0.86
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 7
	shadow.Parent = button
	W.corner(shadow, 18)

	local face = Instance.new("Frame")
	face.Name = "Surface"
	face.BackgroundColor3 = if item.warm then WARM else LAVENDER
	face.BackgroundTransparency = if item.warm then 0.16 else 0.27
	face.BorderSizePixel = 0
	face.ClipsDescendants = false
	face.Size = UDim2.fromScale(1, 1)
	face.ZIndex = 8
	face.Parent = button
	W.corner(face, 18)
	local stroke = W.outline(face, if item.warm then Theme.gold else Theme.primary, 0.72)
	stroke.Thickness = 1.25

	local accent = Instance.new("Frame")
	accent.Name = "ActiveAccent"
	accent.BackgroundColor3 = if item.warm then Theme.gold else Theme.primary
	accent.BackgroundTransparency = 1
	accent.BorderSizePixel = 0
	accent.ZIndex = 9
	accent.Parent = face
	W.corner(accent, 3)

	local iconStage = Instance.new("Frame")
	iconStage.Name = "IconStage"
	iconStage.AnchorPoint = Vector2.new(0.5, 0)
	iconStage.BackgroundTransparency = 1
	iconStage.ClipsDescendants = false
	iconStage.ZIndex = 9
	iconStage.Parent = face
	local motionScale = Instance.new("UIScale")
	motionScale.Parent = iconStage

	local artwork = Instance.new("Frame")
	artwork.Name = "Artwork"
	artwork.AnchorPoint = Vector2.new(0.5, 0.5)
	artwork.BackgroundTransparency = 1
	artwork.ClipsDescendants = false
	artwork.Position = UDim2.fromScale(0.5, 0.5)
	artwork.Size = UDim2.fromScale(1, 1)
	artwork.ZIndex = 9
	artwork.Parent = iconStage
	local artScale = Instance.new("UIScale")
	artScale.Scale = item.iconScale
	artScale.Parent = artwork

	local iconShadow = Instance.new("ImageLabel")
	iconShadow.Name = "IconShadow"
	iconShadow.BackgroundTransparency = 1
	iconShadow.Image = image
	iconShadow.ImageColor3 = Theme.shadow
	iconShadow.ImageTransparency = 0.73
	iconShadow.Position = UDim2.fromOffset(2, 3)
	iconShadow.ScaleType = Enum.ScaleType.Fit
	iconShadow.Size = UDim2.fromScale(1, 1)
	iconShadow.ZIndex = 9
	iconShadow.Parent = artwork

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = image
	icon.ImageTransparency = 0
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromScale(1, 1)
	icon.Visible = true
	icon.ZIndex = 10
	icon.Parent = artwork

	local label = W.label(face, item.label, 20, 12)
	label.Name = "Label"
	label.Font = Theme.heading
	label.TextColor3 = Theme.ink
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 10

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.BackgroundColor3 = Theme.gold
	badge.BorderSizePixel = 0
	badge.Visible = false
	badge.ZIndex = 12
	badge.Parent = face
	W.corner(badge, 9)
	local badgeStroke = W.outline(badge, Theme.card, 0.08)
	badgeStroke.Thickness = 2
	local badgeText = W.label(badge, "", 16, 10)
	badgeText.Font = Theme.heading
	badgeText.Size = UDim2.fromScale(1, 1)
	badgeText.TextColor3 = GOLD_INK
	badgeText.TextXAlignment = Enum.TextXAlignment.Center
	badgeText.TextYAlignment = Enum.TextYAlignment.Center
	badgeText.ZIndex = 13

	local hovered = false
	local pressed = false
	local selected = false
	local badgeValue: string? = nil
	local desktop = true
	local itemWidth = 114
	local iconY = 2
	local activeTweens: { Tween } = {}

	local function cancelTweens()
		for _, tween in activeTweens do
			tween:Cancel()
		end
		table.clear(activeTweens)
	end

	local function animate(object: Instance, goals: { [string]: unknown }, duration: number)
		local tween = TweenService:Create(
			object,
			TweenInfo.new(
				if effects() then duration else 0,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			goals
		)
		table.insert(activeTweens, tween)
		tween:Play()
	end

	local function paint()
		cancelTweens()
		local emphasized = hovered or selected
		local lift = if pressed then 0 elseif hovered then -4 elseif selected then -2 else 0
		local iconZoom = if pressed
			then 0.95
			elseif hovered then 1.06
			elseif selected then 1.025
			else 1
		local surface = if item.warm
			then (if emphasized then WARM_ACTIVE else WARM)
			else (if emphasized then LAVENDER_ACTIVE else LAVENDER)
		local surfaceTransparency = if selected
			then 0.04
			elseif hovered then 0.1
			elseif item.warm then 0.16
			else 0.27

		animate(
			buttonScale,
			{ Scale = if pressed then 0.975 else 1 },
			if pressed then 0.07 else 0.14
		)
		animate(
			iconStage,
			{ Position = UDim2.fromOffset(math.floor(itemWidth / 2), iconY + lift) },
			0.16
		)
		animate(motionScale, { Scale = iconZoom }, if pressed then 0.07 else 0.16)
		animate(
			face,
			{ BackgroundColor3 = surface, BackgroundTransparency = surfaceTransparency },
			0.16
		)
		animate(
			shadow,
			{ BackgroundTransparency = if hovered then 0.76 elseif selected then 0.8 else 0.86 },
			0.16
		)
		animate(
			stroke,
			{ Transparency = if selected then 0.24 elseif hovered then 0.39 else 0.72 },
			0.16
		)
		animate(accent, { BackgroundTransparency = if selected then 0.05 else 1 }, 0.16)
		animate(
			iconShadow,
			{ ImageTransparency = if hovered then 0.58 elseif selected then 0.64 else 0.73 },
			0.16
		)
		animate(label, {
			TextColor3 = if item.warm and emphasized then GOLD_INK else Theme.ink,
			TextTransparency = if emphasized then 0 else 0.12,
		}, 0.16)
	end

	local function setHovered(value: boolean)
		hovered = value
		if not value then
			pressed = false
		end
		paint()
	end

	scope.connect(button.MouseEnter, function()
		setHovered(true)
	end)
	scope.connect(button.MouseLeave, function()
		setHovered(false)
	end)
	scope.connect(button.SelectionGained, function()
		setHovered(true)
	end)
	scope.connect(button.SelectionLost, function()
		setHovered(false)
	end)
	scope.connect(button.MouseButton1Down, function()
		pressed = true
		paint()
	end)
	scope.connect(button.MouseButton1Up, function()
		pressed = false
		paint()
	end)
	scope.connect(button.Activated, function()
		pressed = false
		paint()
		choose(item.id)
	end)
	scope.add(cancelTweens)

	return {
		button = button,
		layout = function(nextDesktop: boolean, width: number, height: number)
			desktop = nextDesktop
			itemWidth = width
			button.Size = UDim2.fromOffset(width, height)
			local iconSize = if desktop
				then math.min(74, height - 24)
				else math.min(46, height - 19)
			iconY = (if desktop then 2 else 1) + item.iconYOffset
			iconStage.Position = UDim2.fromOffset(math.floor(width / 2), iconY)
			iconStage.Size = UDim2.fromOffset(iconSize, iconSize)
			label.Position = UDim2.fromOffset(2, height - 22)
			label.Size = UDim2.fromOffset(width - 4, 19)
			label.TextSize = if desktop then 12 else 10
			accent.AnchorPoint = if desktop then Vector2.new(0, 0.5) else Vector2.new(0.5, 1)
			accent.Position = if desktop then UDim2.fromScale(0, 0.5) else UDim2.fromScale(0.5, 1)
			accent.Size = if desktop then UDim2.fromOffset(4, 28) else UDim2.fromOffset(28, 4)
			badge.Position =
				UDim2.fromOffset(math.floor(width / 2 + iconSize * 0.34), math.max(8, iconY + 8))
			paint()
		end,
		setSelected = function(value: boolean)
			if selected == value then
				return
			end
			selected = value
			paint()
		end,
		setBadge = function(value: string?)
			if badgeValue == value then
				return
			end
			badgeValue = value
			badge.Visible = value ~= nil
			badgeText.Text = value or ""
			badgeText.Visible = value ~= nil and value ~= ""
			badge.Size =
				UDim2.fromOffset(if value == "" then 12 else 18, if value == "" then 12 else 18)
		end,
	}
end

return NavigationButton
