--!strict
-- End-of-opening Reveal card over the kept cinematic: NEW badge (first discovery only), name +
-- rarity pill, earning/chance/progress chips (a duplicate's chip names its rate gain), owned
-- count for duplicates, and the choices Put on Display (or Swap) / Open another / Keep it in
-- my Collection. Open 10 steps add a stable Skip to results beside Next figure.
-- The opening controller owns input; this module only renders and exposes the buttons.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Style = require(script.Parent.UIStyle)
local Scope = require(script.Parent.UIScope)
local Kit = require(script.Parent.UIKit)
local Badge = require(script.Parent.UIBadge)
local Button = require(script.Parent.UIButton)
local State = require(script.Parent.UIState)
local Card = {}

export type Card = {
	root: CanvasGroup,
	choices: { [string]: TextButton },
	first: () -> TextButton,
	set: (State.Reveal?) -> (),
	layout: (compact: boolean) -> (),
}

function Card.create(
	parent: Instance,
	scope: Scope.Scope,
	figureId: string,
	isNew: boolean,
	quantity: number,
	effects: () -> boolean,
	rarity: string?
): Card
	local figure = Catalog.byId[figureId]
	local root = Instance.new("CanvasGroup")
	root.Name = "Result"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 5
	root.Parent = parent
	local new = Badge.create(root, "NewBadge", "NEW FIGURE!", {
		fill = Style.gold,
		color = Style.ink,
		height = 40,
		size = 20,
		font = Style.display(),
		outline = Style.white,
		thickness = 3,
	})
	new.root.AnchorPoint = Vector2.new(0.5, 0)
	new.root.Visible = isNew
	local block = Kit.frame(root, "Details")
	local titleRow = Kit.frame(block, "TitleRow")
	titleRow.AutomaticSize = Enum.AutomaticSize.X
	titleRow.AnchorPoint = Vector2.new(0.5, 0)
	Kit.list(titleRow, Enum.FillDirection.Horizontal, 12, Enum.VerticalAlignment.Center)
	local name = Kit.text(titleRow, "FigureName", figure.name, 44, Style.display(), Style.white)
	-- Width follows the text (no scale width) so the rarity pill sits right beside the name.
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Size = UDim2.fromScale(0, 1)
	name.TextTruncate = Enum.TextTruncate.None
	name.LayoutOrder = 1
	local pill = Badge.rarity(titleRow, 30, 14, Style.white)
	pill.root.LayoutOrder = 2
	-- Studio presentation previews may override the tier; production passes the figure's own.
	pill.rarity(rarity or figure.rarity)
	local chips = Kit.frame(block, "Chips")
	chips.AutomaticSize = Enum.AutomaticSize.X
	chips.AnchorPoint = Vector2.new(0.5, 0)
	local chipList =
		Kit.list(chips, Enum.FillDirection.Horizontal, 10, Enum.VerticalAlignment.Center)
	chipList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function chip(id: string, order: number, mint: boolean): Badge.Badge
		local made = Badge.create(chips, id, "", {
			fill = if mint then Style.mint else Style.revealChip,
			color = if mint then Style.mintInk else Style.revealText,
			height = 34,
			size = 15,
			font = Style.body(Enum.FontWeight.ExtraBold),
		})
		made.root.LayoutOrder = order
		return made
	end
	local earns = chip("Earns", 1, true)
	local chance = chip("Chance", 2, false)
	local progress = chip("Progress", 3, false)
	local owned = chip("Owned", 4, false)
	owned.set("You own ×" .. quantity)
	owned.root.Visible = not isNew and quantity > 1
	local function none() end
	local display = Button.create(block, "PutOnDisplay", {
		variant = "violet",
		text = "Put on Display",
		size = 22,
		radius = 20,
		drop = 5,
		outlineColor = Style.white,
		shadowColor = Style.revealShadow,
		detail = "",
		silent = true,
	}, scope, effects, none)
	local another = Button.create(block, "OpenAnother", {
		variant = "gold",
		text = "Open another",
		size = 22,
		radius = 20,
		drop = 5,
		outlineColor = Style.white,
		shadowColor = Style.revealShadow,
		price = true,
		silent = true,
	}, scope, effects, none)
	local keep = Instance.new("TextButton")
	keep.Name = "KeepInCollection"
	keep.AutoButtonColor = false
	keep.BackgroundTransparency = 1
	keep.FontFace = Style.body(Enum.FontWeight.ExtraBold)
	keep.TextSize = 16
	keep.TextColor3 = Style.revealText
	keep.Text = "Keep it in my Collection"
	keep.AnchorPoint = Vector2.new(0.5, 0)
	keep.Parent = block
	local skip = Instance.new("TextButton")
	skip.Name = "SkipToResults"
	skip.AutoButtonColor = false
	skip.BackgroundColor3 = Style.revealChip
	skip.FontFace = Style.body(Enum.FontWeight.ExtraBold)
	skip.TextSize = 16
	skip.TextColor3 = Style.white
	skip.AnchorPoint = Vector2.new(0.5, 0)
	skip.Visible = false
	skip.Parent = block
	Kit.corner(skip, 14)
	local compact = false
	local model: State.Reveal? = nil
	local function place()
		local showDisplay = display.button.Visible
		local showAnother = another.button.Visible
		if compact then
			-- Phone landscape: a right-hand column beside the figure (the camera shifts left).
			block.AnchorPoint = Vector2.new(0.5, 1)
			block.Position = UDim2.new(0.77, 0, 1, -12)
			block.Size = UDim2.fromScale(0.44, 0)
			new.root.Parent = block
			new.root.Position = UDim2.new(0.5, 0, 0, -42)
			new.root.Size = UDim2.fromOffset(0, 34)
			new.label.TextSize = 16
			name.TextSize = 28
			titleRow.Size = UDim2.fromOffset(0, 36)
			chipList.FillDirection = Enum.FillDirection.Vertical
			chipList.Padding = UDim.new(0, 6)
			for _, item in { earns, chance, progress, owned } do
				item.root.Size = UDim2.fromOffset(0, 28)
				item.label.TextSize = 13
			end
			-- Short screens drop the chance chip (the Shop lists odds) to keep the toy clear.
			chance.root.Visible = false
			local chipCount = if owned.root.Visible then 3 else 2
			local chipHeight = chipCount * 28 + (chipCount - 1) * 6
			local y = 0
			titleRow.Position = UDim2.new(0.5, 0, 0, y)
			y += 44
			chips.Position = UDim2.new(0.5, 0, 0, y)
			chips.Size = UDim2.fromOffset(0, chipHeight)
			y += chipHeight + 12
			for _, item in { display, another } do
				if item.button.Visible then
					item.button.AnchorPoint = Vector2.new(0.5, 0)
					item.button.Position = UDim2.new(0.5, 0, 0, y)
					item.button.Size = UDim2.new(1, 0, 0, 56)
					y += 64
				end
			end
			local rowHeight = if skip.Visible then 36 else 44
			keep.Position = UDim2.new(0.5, 0, 0, y)
			keep.Size = UDim2.new(1, 0, 0, rowHeight)
			y += rowHeight
			if skip.Visible then
				skip.Position = UDim2.new(0.5, 0, 0, y)
				skip.Size = UDim2.new(1, 0, 0, 40)
				y += 44
			end
			block.Size = UDim2.new(0.44, 0, 0, y)
		else
			chance.root.Visible = model ~= nil
			block.AnchorPoint = Vector2.new(0.5, 1)
			block.Position = UDim2.new(0.5, 0, 1, -16)
			new.root.Parent = block
			new.root.Position = UDim2.new(0.5, 0, 0, -52)
			new.root.Size = UDim2.fromOffset(0, 40)
			new.label.TextSize = 20
			name.TextSize = 44
			titleRow.Size = UDim2.fromOffset(0, 48)
			chipList.FillDirection = Enum.FillDirection.Horizontal
			chipList.Padding = UDim.new(0, 10)
			for _, item in { earns, chance, progress, owned } do
				item.root.Size = UDim2.fromOffset(0, 34)
				item.label.TextSize = 15
			end
			titleRow.Position = UDim2.fromScale(0.5, 0)
			chips.Position = UDim2.new(0.5, 0, 0, 58)
			chips.Size = UDim2.fromOffset(0, 34)
			local widths = (if showDisplay then 300 else 0) + (if showAnother then 260 else 0)
			local gap = if showDisplay and showAnother then 14 else 0
			local x = -(widths + gap) / 2
			if showDisplay then
				display.button.AnchorPoint = Vector2.new(0, 0)
				display.button.Position = UDim2.new(0.5, x, 0, 116)
				display.button.Size = UDim2.fromOffset(300, 66)
				x += 300 + gap
			end
			if showAnother then
				another.button.AnchorPoint = Vector2.new(0, 0)
				another.button.Position = UDim2.new(0.5, x, 0, 116)
				another.button.Size = UDim2.fromOffset(260, 66)
			end
			local keepY = if showDisplay or showAnother then 194 else 116
			keep.Size = UDim2.fromOffset(if skip.Visible then 240 else 320, 44)
			keep.Position = UDim2.new(0.5, if skip.Visible then -126 else 0, 0, keepY)
			skip.Size = UDim2.fromOffset(220, 44)
			skip.Position = UDim2.new(0.5, 124, 0, keepY)
			block.Size = UDim2.new(1, 0, 0, keepY + 44)
		end
	end
	local function set(next: State.Reveal?)
		model = next
		local reveal = model
		display.button.Visible = reveal ~= nil and reveal.place ~= nil
		another.button.Visible = reveal ~= nil and reveal.next == nil and not reveal.guided
		earns.root.Visible = reveal ~= nil
		chance.root.Visible = reveal ~= nil
		progress.root.Visible = reveal ~= nil
		skip.Visible = reveal ~= nil and reveal.skip ~= nil
		skip.Text = if reveal and reveal.skip then reveal.skip .. "  ›" else ""
		keep.Text = if reveal and reveal.next
			then reveal.next
			elseif reveal then "Keep it in my Collection"
			else "Continue"
		if reveal then
			earns.set(reveal.earns)
			chance.set(reveal.chance)
			progress.set(reveal.progress)
			display.set(reveal.placeLabel, true, reveal.placeDetail)
			another.setPrice(State.compact(reveal.another.price))
			another.set("Open another", reveal.another.need == nil, reveal.another.need)
		end
		place()
	end
	set(nil)
	return {
		root = root,
		choices = { display = display.button, another = another.button, keep = keep, skip = skip },
		first = function()
			local reveal = model
			if reveal and reveal.place then
				return display.button
			elseif
				reveal
				and reveal.next == nil
				and not reveal.guided
				and reveal.another.need == nil
			then
				return another.button
			end
			return keep
		end,
		set = set,
		layout = function(value: boolean)
			compact = value
			place()
		end,
	}
end

return Card
