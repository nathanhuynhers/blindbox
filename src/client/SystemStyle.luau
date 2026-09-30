--!strict
local TweenService = game:GetService("TweenService")
local W = require(script.Parent.Widgets)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local Style = {
	paper = Color3.fromRGB(249, 246, 239),
	card = Color3.fromRGB(255, 253, 248),
	inset = Color3.fromRGB(237, 230, 218),
	oak = Color3.fromRGB(208, 180, 143),
	trim = Color3.fromRGB(169, 140, 106),
	ink = Theme.ink,
	muted = Color3.fromRGB(108, 101, 98),
	accent = Theme.primary,
	selection = Color3.fromRGB(237, 230, 246),
	success = Color3.fromRGB(61, 112, 91),
	successWash = Color3.fromRGB(225, 241, 231),
	gold = Color3.fromRGB(244, 214, 148),
	goldInk = Color3.fromRGB(124, 84, 31),
}
function Style.panel(
	parent: Instance,
	name: string,
	color: Color3,
	radius: number?
): (Frame, UIStroke)
	local frame = W.frame(parent, name, color)
	W.corner(frame, radius or 16)
	local outline = W.outline(frame, Style.trim, 0.75)
	return frame, outline
end
function Style.text(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	strong: boolean?
): TextLabel
	local label = W.label(parent, text, size + 12, size)
	label.Name = name
	label.TextColor3 = if strong then Style.ink else Style.muted
	label.Font = if strong then Enum.Font.GothamBold else Enum.Font.GothamMedium
	return label
end
function Style.rect(object: GuiObject, x: number, y: number, width: number, height: number)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(math.max(1, width), math.max(1, height))
end
function Style.action(
	parent: Instance,
	text: string,
	ctx: Context.Context,
	callback: () -> (),
	quiet: boolean?
): W.Action
	local action = W.action(parent, text, ctx.scope, ctx.effects, callback, quiet)
	action.button:SetAttribute("Accent", Style.accent)
	action.button:SetAttribute("Surface", Style.card)
	if quiet then
		action.button:SetAttribute("RestingStrokeTransparency", 0.7)
	end
	action.button.TextSize = 14
	return action
end
function Style.shell(parent: Instance, name: string, _ctx: Context.Context)
	local root = Style.panel(parent, name, Style.oak, 22)
	local face = Style.panel(root, "IvoryInset", Style.paper, 18)
	face.Position = UDim2.fromOffset(4, 4)
	face.Size = UDim2.new(1, -8, 1, -12)
	W.gradient(face, Style.card, Style.paper, 90)
	local rail = W.frame(root, "WarmEdge", Style.gold)
	rail.Position = UDim2.new(0, 22, 1, -8)
	rail.Size = UDim2.new(1, -44, 0, 2)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ContentScroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(8, 8)
	scroll.Size = UDim2.new(1, -16, 1, -24)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Style.trim
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = root
	local content = W.frame(scroll, "Content")
	content.Position = UDim2.fromOffset(12, 10)
	local function width(): number
		return math.max(240, root.AbsoluteSize.X - 48)
	end
	local function fit(height: number)
		content.Size = UDim2.fromOffset(width(), height)
		scroll.CanvasSize = UDim2.fromOffset(0, height + 20)
	end
	return { root = root, content = content, scroll = scroll, width = width, fit = fit }
end
function Style.header(parent: Instance, title: string, subtitle: string, iconName: string)
	local Icons = require(script.Parent.UIIcons)
	local mark = Style.panel(parent, "HeaderMark", Style.inset, 12)
	Style.rect(mark, 0, 0, 48, 48)
	local icon = Icons.create(mark, iconName, Style.accent)
	Style.rect(icon, 10, 10, 28, 28)
	local heading = Style.text(parent, "Title", title, 27, true)
	heading.Font = Enum.Font.FredokaOne
	heading.Position = UDim2.fromOffset(60, 0)
	heading.Size = UDim2.new(1, -60, 0, 40)
	local caption = Style.text(parent, "Subtitle", subtitle, 14)
	caption.Position = UDim2.fromOffset(0, 54)
	caption.Size = UDim2.new(1, 0, 0, 40)
	return heading
end
function Style.progress(
	parent: Instance,
	ctx: Context.Context,
	color: Color3
): (number, number) -> ()
	local track = Style.panel(parent, "ProgressTrack", Style.inset, 6)
	track.Size = UDim2.fromScale(1, 1)
	local fill = W.frame(track, "Fill", color)
	fill.Size = UDim2.fromScale(0, 1)
	W.corner(fill, 6)
	local value = -1
	local tween: Tween? = nil
	ctx.scope.add(function()
		if tween then
			tween:Cancel()
		end
	end)
	return function(count: number, total: number)
		local ratio = if total > 0 then math.clamp(count / total, 0, 1) else 0
		if value == ratio then
			return
		end
		if tween then
			tween:Cancel()
		end
		local nextSize = UDim2.fromScale(ratio, 1)
		if value >= 0 and ctx.effects() then
			tween = TweenService:Create(fill, TweenInfo.new(0.2), { Size = nextSize })
			assert(tween, "Progress tween was not created")
			tween:Play()
		else
			fill.Size = nextSize
		end
		value = ratio
	end
end
return Style
