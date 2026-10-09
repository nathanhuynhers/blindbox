--!strict
-- Chunky outlined button with a hard shadow. Pressing drops the face onto its shadow.
-- Disabled buttons look disabled and keep their detail line to explain why.
local TweenService = game:GetService("TweenService")
local Style = require(script.Parent.UIStyle)
local Scope = require(script.Parent.UIScope)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Sfx = require(script.Parent.Sfx)
local Button = {}

export type Variant = "gold" | "violet" | "mint" | "white" | "raised" | "ink" | "ghost" | "selected"
type Paint = { fill: Color3, text: Color3, outline: Color3, shadow: boolean, transparent: boolean? }
local paints: { [string]: Paint } = {
	gold = { fill = Style.gold, text = Style.ink, outline = Style.ink, shadow = true },
	violet = { fill = Style.violet, text = Style.white, outline = Style.ink, shadow = true },
	mint = { fill = Style.mint, text = Style.mintInk, outline = Style.ink, shadow = true },
	white = { fill = Style.white, text = Style.ink, outline = Style.ink, shadow = false },
	raised = { fill = Style.white, text = Style.ink, outline = Style.ink, shadow = true },
	ink = { fill = Style.ink, text = Style.white, outline = Style.ink, shadow = false },
	selected = { fill = Style.ink, text = Style.white, outline = Style.ink, shadow = false },
	ghost = {
		fill = Style.white,
		text = Style.ink,
		outline = Style.ink,
		shadow = false,
		transparent = true,
	},
}

export type Options = {
	variant: Variant,
	text: string,
	size: number?,
	radius: number?,
	drop: number?,
	outline: number?,
	outlineColor: Color3?,
	shadowColor: Color3?,
	detail: string?,
	price: boolean?,
	icon: string?,
	font: Font?,
	silent: boolean?, -- The owner plays its own sound (Reveal choices close the opening).
}
export type Button = {
	button: TextButton,
	face: Frame,
	label: TextLabel,
	detail: TextLabel,
	price: TextLabel?,
	set: (text: string, enabled: boolean, detail: string?) -> (),
	variant: (Variant) -> (),
	setPrice: (string) -> (),
	enabled: () -> boolean,
}

function Button.create(
	parent: Instance,
	name: string,
	options: Options,
	scope: Scope.Scope,
	effects: () -> boolean,
	callback: () -> ()
): Button
	local drop = options.drop or Style.shadow
	local radius = options.radius or 16
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(160, Style.target)
	button.Parent = parent
	local shadow = Kit.frame(button, "Shadow", options.shadowColor or Style.ink)
	shadow.Position = UDim2.fromOffset(0, drop)
	shadow.ZIndex = 1
	Kit.corner(shadow, radius)
	local face = Kit.frame(button, "Face", Style.white)
	face.ZIndex = 2
	Kit.corner(face, radius)
	local stroke = Kit.stroke(face, Style.ink, options.outline or Style.outline)
	local stack = Kit.frame(face, "Content")
	local stackList = Kit.list(stack, Enum.FillDirection.Vertical, 0, Enum.VerticalAlignment.Center)
	stackList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local row = Kit.frame(stack, "Row")
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.fromOffset(0, 0)
	row.LayoutOrder = 1
	local rowList = Kit.list(row, Enum.FillDirection.Horizontal, 8, Enum.VerticalAlignment.Center)
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	if options.icon then
		local icon =
			Icons.create(row, options.icon, Style.ink, math.floor((options.size or 18) * 1.1))
		icon.LayoutOrder = 0
	end
	local size = options.size or 18
	local label = Kit.text(row, "Label", options.text, size, options.font or Style.display())
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, math.ceil(size * 1.2))
	label.TextTruncate = Enum.TextTruncate.None
	label.LayoutOrder = 1
	local price: TextLabel? = nil
	if options.price then
		local pill = Kit.frame(row, "PriceGroup", Style.white)
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.fromOffset(0, math.ceil(size * 1.5))
		pill.LayoutOrder = 2
		Kit.corner(pill, 12)
		Kit.stroke(pill, Style.ink, Style.outlineSmall)
		Kit.padding(pill, 0, 10, 0, 8)
		Kit.list(pill, Enum.FillDirection.Horizontal, 5, Enum.VerticalAlignment.Center)
		local coin = Icons.create(pill, "Coin", Style.ink, math.floor(size * 0.95))
		coin.Name = "CoinsIcon"
		coin.LayoutOrder = 1
		local amount = Kit.text(pill, "Price", "", math.floor(size * 0.85), Style.display())
		amount.AutomaticSize = Enum.AutomaticSize.X
		amount.Size = UDim2.fromScale(0, 1)
		amount.TextTruncate = Enum.TextTruncate.None
		amount.LayoutOrder = 2
		price = amount
	end
	local detail =
		Kit.text(stack, "Detail", options.detail or "", 13, Style.body(Enum.FontWeight.ExtraBold))
	detail.AutomaticSize = Enum.AutomaticSize.X
	detail.Size = UDim2.fromOffset(0, 17)
	detail.TextTruncate = Enum.TextTruncate.None
	detail.LayoutOrder = 2
	detail.Visible = (options.detail or "") ~= ""
	local variant: Variant = options.variant
	local enabled, pressed = true, false
	local tween: Tween? = nil
	local function paint()
		local scheme = paints[variant]
		local live = enabled
		face.BackgroundColor3 = if live then scheme.fill else Style.disabledFill
		face.BackgroundTransparency = if scheme.transparent and live then 1 else 0
		stroke.Color = if live then options.outlineColor or scheme.outline else Style.disabledBorder
		stroke.Transparency = if scheme.transparent and live then 1 else 0
		label.TextColor3 = if live then scheme.text else Style.muted
		detail.TextColor3 = if not live
			then Style.muted
			elseif variant == "violet" then Style.revealText
			else scheme.text
		shadow.Visible = scheme.shadow and live and not pressed and drop > 0
		button.Selectable = live
	end
	local function move(down: boolean)
		pressed = down
		local goal = UDim2.fromOffset(0, if down and paints[variant].shadow then drop else 0)
		if tween then
			tween:Cancel()
			tween = nil
		end
		if effects() then
			local nextTween = TweenService:Create(
				face,
				TweenInfo.new(0.06, Enum.EasingStyle.Quad),
				{ Position = goal }
			)
			tween = nextTween
			nextTween:Play()
		else
			face.Position = goal
		end
		paint()
	end
	scope.connect(button.MouseButton1Down, function()
		if enabled then
			move(true)
		end
	end)
	scope.connect(button.MouseButton1Up, function()
		move(false)
	end)
	scope.connect(button.MouseLeave, function()
		if pressed then
			move(false)
		end
	end)
	scope.connect(button.Activated, function()
		if enabled then
			callback()
			if not options.silent then
				Sfx.play("click") -- After the callback, so a navigation sound wins.
			end
		else
			Sfx.play("denied")
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
		face = face,
		label = label,
		detail = detail,
		price = price,
		set = function(text: string, allowed: boolean, line: string?)
			label.Text = text
			detail.Text = line or ""
			detail.Visible = detail.Text ~= ""
			if enabled ~= allowed then
				enabled = allowed
				if not allowed and pressed then
					move(false)
				end
			end
			button:SetAttribute("Enabled", allowed)
			paint()
		end,
		variant = function(value: Variant)
			variant = value
			paint()
		end,
		setPrice = function(value: string)
			if price then
				price.Text = value
			end
		end,
		enabled = function()
			return enabled
		end,
	}
end

return Button
