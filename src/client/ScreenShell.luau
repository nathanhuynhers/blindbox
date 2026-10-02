--!strict
-- Shared screen frame: centred panel on desktop, near-full-screen sheet on phone landscape.
-- Header: nav icon, title, one-line subtitle, optional right-side chips, round ink Close.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Badge = require(script.Parent.UIBadge)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Navigation = require(script.Parent.NavigationConfig)
local Shell = {}

export type Options = { id: string, title: string, subtitle: string, coins: boolean? }
export type Shell = {
	root: Frame,
	body: Frame,
	chips: Frame,
	title: TextLabel,
	subtitle: TextLabel,
	close: TextButton,
	layout: (width: number, height: number, phone: boolean) -> (number, number),
	update: (Types.Snapshot) -> (),
}

function Shell.create(parent: Instance, ctx: Context.Context, options: Options): Shell
	local card = Kit.card(parent, options.id, Style.surface, 28, 8)
	local root, face = card.root, card.face
	root:SetAttribute("Screen", options.id)
	root.Active = true
	face.ClipsDescendants = true
	local header = Kit.frame(face, "Header")
	local icon = Kit.image(header, "ScreenIcon", Navigation.image(options.id))
	local title = Kit.text(header, "Title", options.title, 30, Style.display())
	local subtitle = Kit.text(
		header,
		"Subtitle",
		options.subtitle,
		14,
		Style.body(Enum.FontWeight.Bold),
		Style.muted
	)
	local chips = Kit.frame(header, "Chips")
	chips.AutomaticSize = Enum.AutomaticSize.X
	chips.AnchorPoint = Vector2.new(1, 0.5)
	local chipList =
		Kit.list(chips, Enum.FillDirection.Horizontal, 10, Enum.VerticalAlignment.Center)
	chipList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local coins = Badge.create(chips, "Coins", "", {
		fill = Style.goldWash,
		color = Style.ink,
		height = 40,
		size = 18,
		font = Style.display(),
		icon = "Coin",
	})
	coins.root.LayoutOrder = 100
	coins.root.Visible = false
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = ""
	close.AutoButtonColor = false
	close.BackgroundColor3 = Style.ink
	close.BorderSizePixel = 0
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Parent = header
	close:SetAttribute("AccessibleName", "Close " .. options.title)
	Kit.round(close)
	local closeIcon = Icons.create(close, "Close", Style.white, 18)
	closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	closeIcon.Position = UDim2.fromScale(0.5, 0.5)
	ctx.scope.connect(close.Activated, ctx.close)
	local divider = Kit.frame(face, "Divider", Style.divider)
	local body = Kit.frame(face, "Body")
	body.ClipsDescendants = true
	local width, height, phone = 0, 0, false
	local function place()
		local h = if phone then 56 else 76
		local iconSize = if phone then 40 else 56
		local left = if phone then 12 else 18
		local closeSize = if phone then 44 else 48
		Kit.rect(header, 0, 0, width, h)
		Kit.rect(icon, left, (h - iconSize) / 2, iconSize, iconSize)
		icon.Visible = icon.Image ~= ""
		local textX = left + (if icon.Visible then iconSize + (if phone then 10 else 14) else 0)
		close.Position = UDim2.fromOffset(width - (if phone then 8 else 16), h / 2)
		close.Size = UDim2.fromOffset(closeSize, closeSize)
		chips.Position = UDim2.fromOffset(width - (if phone then 8 else 16) - closeSize - 12, h / 2)
		chips.Size = UDim2.fromOffset(0, h - 12)
		local chipWidth = chips.AbsoluteSize.X / math.max(0.01, ctx.scale())
		local textWidth = math.max(80, width - textX - closeSize - 40 - chipWidth)
		title.TextSize = if phone then 24 else 30
		subtitle.Visible = not phone and subtitle.Text ~= ""
		if subtitle.Visible then
			Kit.rect(title, textX, h / 2 - 22, textWidth, 34)
			Kit.rect(subtitle, textX, h / 2 + 11, textWidth, 18)
		else
			Kit.rect(title, textX, 0, textWidth, h)
		end
		Kit.rect(divider, 0, h, width, 2)
		Kit.rect(body, 0, h + 2, width, math.max(0, height - h - 2))
	end
	ctx.scope.connect(chips:GetPropertyChangedSignal("AbsoluteSize"), place)
	return {
		root = root,
		body = body,
		chips = chips,
		title = title,
		subtitle = subtitle,
		close = close,
		layout = function(nextWidth: number, nextHeight: number, nextPhone: boolean)
			width, height, phone = nextWidth, nextHeight, nextPhone
			card.radius(if phone then 22 else 28)
			card.shadow.Visible = not phone
			place()
			return width, math.max(0, height - (if phone then 58 else 78))
		end,
		update = function(snapshot: Types.Snapshot)
			coins.root.Visible = phone and options.coins ~= false
			coins.set(State.compact(snapshot.coins))
		end,
	}
end

return Shell
