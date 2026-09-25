--!strict
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local Scope = require(script.Parent.UIScope)
local Scroll = require(script.Parent.Scroll)
local State = require(script.Parent.UIState)
local W = {}
export type Action = { button: TextButton, set: (string, boolean, boolean?) -> () }
function W.focus(object: GuiObject)
	if string.find(Input:GetLastInputType().Name, "Gamepad", 1, true) then
		GuiService.SelectedObject = object
	end
end
function W.corner(object: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.radius)
	corner.Parent = object
end
function W.frame(parent: Instance, name: string, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color or Theme.card
	frame.BackgroundTransparency = if color then 0 else 1
	frame.Parent = parent
	return frame
end
function W.card(parent: Instance, name: string, height: number): Frame
	local card = W.frame(parent, name, Theme.card)
	card.Size = UDim2.new(1, -4, 0, height)
	W.corner(card)
	return card
end
function W.label(parent: Instance, text: string, height: number, size: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.TextColor3 = Theme.ink
	label.TextSize = size or 16
	label.Font = Theme.font
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end
function W.title(parent: Instance, text: string, height: number): TextLabel
	local label = W.label(parent, text, height, 26)
	label.Font = Theme.heading
	return label
end
function W.inset(object: GuiObject, y: number, height: number)
	object.Position = UDim2.fromOffset(Theme.padding, y)
	object.Size = UDim2.new(1, -Theme.padding * 2, 0, height)
end
function W.padding(parent: Instance, amount: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount + 4)
	padding.Parent = parent
end
function W.list(parent: Instance, gap: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or Theme.gap)
	layout.Parent = parent
	return layout
end
function W.scroll(parent: Instance, name: string, scope: Scope.Scope): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Theme.primary
	frame.CanvasSize = UDim2.fromOffset(0, 0)
	frame.SelectionGroup = true
	frame.Parent = parent
	W.padding(frame, Theme.padding)
	scope.add(Scroll.bind(frame, W.list(frame), Theme.padding))
	return frame
end
function W.grid(
	parent: ScrollingFrame,
	scope: Scope.Scope,
	minimum: number,
	maximum: number,
	height: number
): UIGridLayout
	local old = parent:FindFirstChildOfClass("UIListLayout")
	assert(not old, "Use a separate scrolling frame for a grid")
	W.padding(parent, Theme.padding)
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(Theme.gap, Theme.gap)
	layout.Parent = parent
	local function resize()
		local columns, width = State.grid(parent.AbsoluteSize.X, minimum, maximum)
		layout.FillDirectionMaxCells = columns
		layout.CellSize = UDim2.fromOffset(width, height)
	end
	scope.connect(parent:GetPropertyChangedSignal("AbsoluteSize"), resize)
	scope.add(Scroll.bind(parent, layout, Theme.padding))
	resize()
	return layout
end
function W.progress(parent: Instance): (number, number) -> ()
	local track = W.frame(parent, "Progress", Theme.disabled)
	track.Size = UDim2.new(1, 0, 0, 10)
	W.corner(track, 5)
	local fill = W.frame(track, "Fill", Theme.primary)
	W.corner(fill, 5)
	return function(count: number, total: number)
		fill.Size = UDim2.fromScale(if total > 0 then math.clamp(count / total, 0, 1) else 0, 1)
		fill.Visible = count > 0
	end
end
function W.tiles(
	parent: Instance,
	scope: Scope.Scope,
	minimum: number,
	maximum: number,
	height: number
): Frame
	local root = W.frame(parent, "Tiles")
	root.Size = UDim2.new(1, -4, 0, height)
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(Theme.gap, Theme.gap)
	layout.Parent = root
	local function resize()
		local columns, width = State.grid(root.AbsoluteSize.X + 32, minimum, maximum)
		layout.FillDirectionMaxCells = columns
		layout.CellSize = UDim2.fromOffset(width, height)
		root.Size = UDim2.new(1, -4, 0, math.ceil(layout.AbsoluteContentSize.Y))
	end
	scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	scope.connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), resize)
	resize()
	return root
end
function W.action(
	parent: Instance,
	text: string,
	scope: Scope.Scope,
	effects: () -> boolean,
	callback: () -> (),
	subtle: boolean?
): Action
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, Theme.target)
	button.Name = text
	button.Text = text
	button.Font = Theme.font
	button.TextSize = 15
	button.TextWrapped = true
	button.AutoButtonColor = false
	button.Parent = parent
	W.corner(button, 14)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.primary
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local enabled, selected, hovered = true, false, false
	local tween: Tween? = nil
	local function paint()
		button.BackgroundColor3 = if not enabled
			then Theme.disabled
			elseif selected or not subtle then Theme.primary
			else Theme.soft
		button.TextColor3 = if enabled and (selected or not subtle) then Theme.card else Theme.ink
		button.BackgroundTransparency = if hovered and enabled then 0.13 else 0
		stroke.Transparency = if selected or hovered then 0.2 else 1
	end
	local function animate(value: number)
		if tween then
			tween:Cancel()
		end
		if effects() then
			local nextTween = TweenService:Create(
				scale,
				TweenInfo.new(Theme.transition, Enum.EasingStyle.Quad),
				{ Scale = value }
			)
			tween = nextTween
			nextTween:Play()
		else
			scale.Scale = 1
		end
	end
	scope.connect(button.MouseEnter, function()
		hovered = true
		paint()
	end)
	scope.connect(button.MouseLeave, function()
		hovered = false
		paint()
		animate(1)
	end)
	scope.connect(button.SelectionGained, function()
		hovered = true
		paint()
	end)
	scope.connect(button.SelectionLost, function()
		hovered = false
		paint()
		animate(1)
	end)
	scope.connect(button.MouseButton1Down, function()
		if enabled then
			animate(0.97)
		end
	end)
	scope.connect(button.MouseButton1Up, function()
		animate(1)
	end)
	scope.connect(button.Activated, function()
		if enabled then
			animate(1)
			callback()
		end
	end)
	scope.add(function()
		if tween then
			tween:Cancel()
		end
	end)
	paint()
	return {
		button = button,
		set = function(value: string, allowed: boolean, active: boolean?)
			button.Text = value
			enabled, selected = allowed, active == true
			button.Selectable = allowed
			button:SetAttribute("Enabled", allowed)
			paint()
		end,
	}
end
return W
