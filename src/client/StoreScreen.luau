--!strict
-- Robux Store (docs/ui-redesign/MONETIZATION_STORE.md): candy tabs, product cards, the Coin
-- Multiplier tier panel and a product sheet. P02 owns all native prompts and grants.
local GuiService = game:GetService("GuiService")
local FigureCatalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local State = require(script.Parent.UIState)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Badge = require(script.Parent.UIBadge)
local Button = require(script.Parent.UIButton)
local TweenService = game:GetService("TweenService")
local Context = require(script.Parent.UIContext)
local Shell = require(script.Parent.ScreenShell)
local Scope = require(script.Parent.UIScope)
local Catalog = require(script.Parent.StoreCatalog)
local Presentation = require(script.Parent.StorePresentation)
local Perks = require(script.Parent.StorePerks)
local PerkControls = require(script.Parent.StorePerkControls)
local Sfx = require(script.Parent.Sfx)
local Store = {}

local soon = "Coming soon"
local elsewhere = "On welcome back"

-- White text with a plum outline: the store's display type.
local function outlined(label: TextLabel, thickness: number)
	label.TextColor3 = Style.white
	local stroke = Instance.new("UIStroke")
	stroke.Color = Style.ink
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
end

-- Evenly spaced colours; rotation 90 runs top to bottom, 0 left to right.
local function gradient(object: GuiObject, rotation: number, colors: { Color3 }): UIGradient
	local sequence = {}
	for index, color in colors do
		table.insert(sequence, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	local made = Instance.new("UIGradient")
	made.Rotation = rotation
	made.Color = ColorSequence.new(sequence)
	made.Parent = object
	return made
end

local function button(parent: Instance, name: string, accessible: string): TextButton
	local made = Instance.new("TextButton")
	made.Name = name
	made.Text = ""
	made.AutoButtonColor = false
	made.BackgroundTransparency = 1
	made.BorderSizePixel = 0
	made:SetAttribute("AccessibleName", accessible)
	made.Parent = parent
	return made
end

-- Product art: the uploaded custom icon, else a frame-drawn icon or a stroked glyph.
type Art = { root: Frame, size: (number) -> () }
local function art(parent: Instance, product: Catalog.Product): Art
	local root = Kit.frame(parent, "Art")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	local icon: GuiObject? = nil
	local glyph: TextLabel? = nil
	local disc: Frame? = nil
	if product.image then
		local made = Instance.new("ImageLabel")
		made.Name = "Icon"
		made.BackgroundTransparency = 1
		made.Image = "rbxassetid://" .. product.image
		made.ScaleType = Enum.ScaleType.Fit
		made.AnchorPoint = Vector2.new(0.5, 0.5)
		made.Position = UDim2.fromScale(0.5, 0.5)
		made.Parent = root
		icon = made
		if product.tile then
			-- Full-bleed square art: an app-icon tile with rounded corners and the ink outline.
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.18, 0)
			corner.Parent = made
			Kit.stroke(made, Style.ink)
		end
		if product.badge then
			local round = Kit.frame(root, "Badge", Style.violet)
			round.AnchorPoint = Vector2.new(1, 1)
			round.Position = UDim2.fromScale(1.04, 1.04)
			round.Size = UDim2.fromScale(0.42, 0.42)
			round.ZIndex = 2
			Kit.round(round)
			Kit.stroke(round, Style.ink, Style.outlineSmall)
			local number = Kit.text(round, "Number", product.badge, 20, Style.display())
			number.Size = UDim2.fromScale(1, 1)
			number.TextXAlignment = Enum.TextXAlignment.Center
			number.TextScaled = true
			number.ZIndex = 3
			outlined(number, 2)
			disc = round
		end
	elseif product.icon then
		local made = Icons.create(root, product.icon, product.tint or Style.ink, 64)
		made.AnchorPoint = Vector2.new(0.5, 0.5)
		made.Position = UDim2.fromScale(0.5, 0.5)
		icon = made
	else
		local made = Kit.text(root, "Glyph", product.glyph or "?", 40, Style.display())
		made.Size = UDim2.fromScale(1, 1)
		made.TextXAlignment = Enum.TextXAlignment.Center
		made.TextTruncate = Enum.TextTruncate.None
		outlined(made, 3)
		glyph = made
	end
	return {
		root = root,
		size = function(size: number)
			root.Size = UDim2.fromOffset(size, size)
			if icon then
				icon.Size = UDim2.fromOffset(size, size)
			end
			if glyph then
				glyph.TextSize = math.floor(size * 0.62)
			end
			if disc then
				disc.Visible = size >= 40
			end
		end,
	}
end

-- "Coming soon" (or "On welcome back") in the slot a price button will take.
type Stamp = { root: Frame, label: TextLabel }
-- A buyable price reads as a live candy-green button; anything else stays a muted stamp.
local function live(target: Stamp, buyable: boolean)
	target.root.BackgroundColor3 = if buyable then Style.mint else Style.disabledFill
	target.label.TextColor3 = if buyable then Style.mintInk else Style.muted
end
local function stamp(parent: Instance, text: string): Stamp
	local root = Kit.frame(parent, "Stamp", Style.disabledFill)
	Kit.corner(root, 14)
	Kit.stroke(root, Style.disabledBorder, Style.outlineSmall)
	local label = Kit.text(root, "Text", text, 16, Style.display(), Style.muted)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize = 12, 20
	limit.Parent = label
	return { root = root, label = label }
end

type Card = {
	benefit: TextLabel,
	root: TextButton,
	key: string,
	footer: Stamp,
	name: TextLabel,
	layout: (width: number, height: number, phone: boolean) -> (),
}

-- Ordinary card: coloured top (a hard gradient stop on the face), art, name, benefit, stamp.
local function card(
	parent: Instance,
	instanceName: string,
	product: Catalog.Product,
	scope: Scope.Scope,
	open: () -> ()
): Card
	local root = button(parent, instanceName, product.name .. " details")
	local shadow = Kit.frame(root, "Shadow", Style.ink)
	Kit.corner(shadow, 22)
	local face = Kit.frame(root, "Face", Style.white)
	Kit.corner(face, 22)
	Kit.stroke(face, Style.ink)
	local fill = gradient(face, 90, { product.top, Style.white })
	local divider = Kit.frame(face, "Divider", Style.ink)
	local picture = art(face, product)
	local name = Kit.text(face, "Name", product.name, 19, Style.display())
	name.TextWrapped, name.TextTruncate = true, Enum.TextTruncate.None
	name.TextScaled = true
	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MinTextSize, nameSize.MaxTextSize = 14, 19
	nameSize.Parent = name
	local benefit = Kit.text(
		face,
		"Benefit",
		product.benefit,
		13,
		Style.body(Enum.FontWeight.ExtraBold),
		Style.muted
	)
	benefit.TextWrapped = true
	benefit.TextYAlignment = Enum.TextYAlignment.Top
	local footer = stamp(face, if product.elsewhere then elsewhere else soon)
	if product.ribbon then
		local ribbon = Badge.create(root, "Ribbon", product.ribbon, {
			fill = Style.red,
			color = Style.white,
			height = 24,
			size = 12,
			outline = Style.ink,
			font = Style.display(),
		})
		ribbon.root.Position = UDim2.fromOffset(-6, 10)
		ribbon.root.ZIndex = 3
	end
	scope.connect(root.Activated, open)
	return {
		root = root,
		key = product.key,
		footer = footer,
		name = name,
		benefit = benefit,
		layout = function(width: number, height: number, phone: boolean)
			Kit.rect(shadow, 0, 6, width, height)
			Kit.rect(face, 0, 0, width, height)
			local top = if phone then 82 else 108
			-- The face gradient carries the coloured top: product colours, then a hard stop to white.
			local stop = math.clamp(top / height, 0.05, 0.9)
			fill.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, product.top),
				ColorSequenceKeypoint.new(stop - 0.001, product.bottom),
				ColorSequenceKeypoint.new(stop, Style.white),
				ColorSequenceKeypoint.new(1, Style.white),
			})
			Kit.rect(divider, 0, top - 1, width, 3)
			local size = if product.tile
				then (if phone then 64 else 84)
				else (if phone then 52 else 68)
			picture.size(size)
			picture.root.Position = UDim2.fromOffset(width / 2, top / 2)
			name.TextSize = if phone then 17 else 19
			nameSize.MaxTextSize = name.TextSize
			Kit.rect(name, 12, top + 8, width - 24, 44)
			Kit.rect(benefit, 12, top + 54, width - 24, 44)
			Kit.rect(footer.root, 10, height - 54, width - 20, 44)
		end,
	}
end

-- Wide Starter banner: art left, title and benefit, stamp right.
local function hero(
	parent: Instance,
	product: Catalog.Product,
	scope: Scope.Scope,
	open: () -> ()
): Card
	local root = button(parent, "Hero_" .. product.key, product.name .. " details")
	local shadow = Kit.frame(root, "Shadow", Style.ink)
	Kit.corner(shadow, 24)
	local face = Kit.frame(root, "Face", Style.white)
	Kit.corner(face, 24)
	Kit.stroke(face, Style.ink)
	gradient(face, 0, { Style.candyPink, Style.candyPinkLight, product.bottom })
	local picture = art(face, product)
	local title = Kit.text(face, "Title", product.name, 30, Style.display())
	title.TextWrapped, title.TextTruncate = true, Enum.TextTruncate.None
	title.TextScaled = true
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MinTextSize, titleSize.MaxTextSize = 18, 30
	titleSize.Parent = title
	outlined(title, 3)
	local benefit =
		Kit.text(face, "Benefit", product.benefit, 15, Style.body(Enum.FontWeight.Heavy))
	benefit.TextWrapped = true
	local footer = stamp(face, soon)
	local ribbon = Badge.create(root, "Ribbon", product.ribbon or "", {
		fill = Style.red,
		color = Style.white,
		height = 24,
		size = 12,
		outline = Style.ink,
		font = Style.display(),
	})
	ribbon.root.Position = UDim2.fromOffset(-6, 10)
	ribbon.root.ZIndex = 3
	ribbon.root.Visible = product.ribbon ~= nil
	scope.connect(root.Activated, open)
	return {
		root = root,
		key = product.key,
		footer = footer,
		name = title,
		benefit = benefit,
		layout = function(width: number, height: number, phone: boolean)
			Kit.rect(shadow, 0, 6, width, height)
			Kit.rect(face, 0, 0, width, height)
			local size = if phone then 72 else 104
			picture.size(size)
			picture.root.Position = UDim2.fromOffset(16 + size / 2, height / 2)
			local stampWidth = if phone then 130 else 190
			local textX = 32 + size
			local textWidth = math.max(60, width - textX - stampWidth - 28)
			title.TextSize = if phone then 22 else 30
			titleSize.MaxTextSize = title.TextSize
			Kit.rect(
				title,
				textX,
				height / 2 - (if phone then 30 else 38),
				textWidth,
				if phone then 44 else 48
			)
			Kit.rect(benefit, textX, height / 2 + 20, textWidth, 40)
			benefit.TextSize = if phone then 13 else 15
			Kit.rect(footer.root, width - stampWidth - 16, (height - 48) / 2, stampWidth, 48)
		end,
	}
end

-- Coin Multiplier: three medals on a gold panel. Highest owned tier wins; they never stack.
local medals = {
	{ Style.hex(0xF2C9A0), Style.hex(0xD9925E) },
	{ Style.hex(0xF3F6FB), Style.hex(0xB7C2D6) },
	{ Style.hex(0xFFE38F), Style.gold },
}
type Tiers = {
	root: Frame,
	refresh: (Presentation.Input) -> (),
	layout: (width: number, phone: boolean) -> number,
}
local function tiers(
	parent: Instance,
	keys: { string },
	scope: Scope.Scope,
	open: (string) -> ()
): Tiers
	local root = Kit.frame(parent, "CoinTiers")
	local shadow = Kit.frame(root, "Shadow", Style.ink)
	Kit.corner(shadow, 24)
	local face = Kit.frame(root, "Face", Style.white)
	Kit.corner(face, 24)
	Kit.stroke(face, Style.ink)
	gradient(face, 90, { Style.goldWash, Style.hex(0xFFE3B0) })
	local title = Kit.text(face, "Title", "Coin Multiplier", 24, Style.display())
	outlined(title, 3)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.TextTruncate = Enum.TextTruncate.None
	local hint = Kit.text(
		face,
		"Hint",
		"Only your highest tier counts",
		14,
		Style.body(Enum.FontWeight.ExtraBold),
		Style.muted
	)
	type Tier = {
		key: string,
		root: TextButton,
		shadow: Frame,
		face: Frame,
		medal: Frame,
		glyph: TextLabel,
		caption: TextLabel,
		footer: Stamp,
	}
	local made: { Tier } = {}
	for index, key in keys do
		local product = Catalog.products[key]
		local tier = button(face, "Tier_" .. key, product.name .. " details")
		local tierShadow = Kit.frame(tier, "Shadow", Style.ink)
		Kit.corner(tierShadow, 18)
		local tierFace = Kit.frame(tier, "Face", Style.white)
		Kit.corner(tierFace, 18)
		Kit.stroke(tierFace, Style.ink)
		local medal = Kit.frame(tierFace, "Medal", Style.white)
		if product.tile then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.18, 0)
			corner.Parent = medal
		else
			Kit.round(medal)
		end
		Kit.stroke(medal, Style.ink)
		local colors = medals[index] or medals[#medals]
		gradient(medal, 90, colors)
		local glyph = Kit.text(medal, "Glyph", product.glyph or "", 24, Style.display())
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.TextXAlignment = Enum.TextXAlignment.Center
		outlined(glyph, 2.5)
		if product.image then
			-- The tier's own uploaded icon replaces the text medal glyph.
			local image = Instance.new("ImageLabel")
			image.Name = "Icon"
			image.BackgroundTransparency = 1
			image.Image = "rbxassetid://" .. product.image
			image.ScaleType = Enum.ScaleType.Fit
			image.Size = UDim2.fromScale(1, 1)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.18, 0)
			corner.Parent = image
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.Parent = medal
			glyph.Visible = false
		end
		local caption = Kit.text(
			tierFace,
			"Caption",
			"Display Coins",
			13,
			Style.body(Enum.FontWeight.ExtraBold),
			Style.muted
		)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		scope.connect(tier.Activated, function()
			open(key)
		end)
		table.insert(made, {
			key = key,
			root = tier,
			shadow = tierShadow,
			face = tierFace,
			medal = medal,
			glyph = glyph,
			caption = caption,
			footer = stamp(tierFace, soon),
		})
	end
	return {
		root = root,
		refresh = function(input: Presentation.Input)
			for _, tier in made do
				local view = Presentation.view(input, tier.key)
				tier.footer.label.Text = view.stamp
				live(tier.footer, Presentation.offer(input, tier.key).buyAllowed == true)
				tier.footer.label.TextScaled = true
				tier.footer.label.TextWrapped = true
				tier.root.Visible = not Presentation.offer(input, tier.key).hidden
			end
		end,
		layout = function(width: number, phone: boolean): number
			local pad = if phone then 10 else 14
			local tierHeight = if phone then 132 else 156
			local height = pad + 34 + tierHeight + pad + 8
			root.Size = UDim2.fromOffset(width, height)
			Kit.rect(shadow, 0, 6, width, height)
			Kit.rect(face, 0, 0, width, height)
			title.TextSize = if phone then 20 else 24
			Kit.rect(title, pad + 4, pad, 0, 30)
			-- Right-aligned on the title row, clear of the ~190px title.
			Kit.rect(hint, pad + 190, pad, width - pad * 2 - 194, 30)
			local gap = if phone then 8 else 12
			local count = 0
			for _, tier in made do
				if tier.root.Visible then
					count += 1
				end
			end
			local tierWidth = (width - pad * 2 - gap * (count - 1)) / math.max(1, count)
			local medalSize = if phone then 50 else 72
			local visibleIndex = 0
			for _, tier in made do
				if not tier.root.Visible then
					continue
				end
				local x = pad + visibleIndex * (tierWidth + gap)
				visibleIndex += 1
				Kit.rect(tier.root, x, pad + 34, tierWidth, tierHeight)
				Kit.rect(tier.shadow, 0, 4, tierWidth, tierHeight)
				Kit.rect(tier.face, 0, 0, tierWidth, tierHeight)
				Kit.rect(tier.medal, (tierWidth - medalSize) / 2, 8, medalSize, medalSize)
				tier.glyph.TextSize = if phone then 19 else 24
				Kit.rect(tier.caption, 4, 12 + medalSize, tierWidth - 8, 18)
				Kit.rect(tier.footer.root, 8, tierHeight - 52, tierWidth - 16, 44)
			end
			return height
		end,
	}
end

-- Hover lift for pointer users: a small UIScale grow, skipped when Motion is off.
local function hover(target: GuiButton, scope: Scope.Scope, effects: () -> boolean)
	local scale = Instance.new("UIScale")
	scale.Parent = target
	local tween: Tween? = nil
	local function to(value: number)
		if tween then
			tween:Cancel()
		end
		if not effects() then
			scale.Scale = 1
			return
		end
		local made = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			Scale = value,
		})
		tween = made
		made:Play()
	end
	scope.connect(target.MouseEnter, function()
		to(1.03)
	end)
	scope.connect(target.MouseLeave, function()
		to(1)
	end)
	scope.add(function()
		if tween then
			tween:Cancel()
		end
	end)
end

-- Display Slots: Coin slot 4 beside the Robux slot passes, each with its currency chip. A saved
-- slot shows Unlocked however it was opened (Coins, a pass or a legacy unlock); the server
-- enforces order, price and ownership either way.
type Slots = {
	root: Frame,
	refresh: (Presentation.Input, Types.Snapshot?) -> (),
	layout: (width: number, phone: boolean) -> number,
}
local function slots(
	parent: Instance,
	keys: { string },
	ctx: Context.Context,
	open: (string) -> ()
): Slots
	local root = Kit.frame(parent, "DisplaySlots")
	local shadow = Kit.frame(root, "Shadow", Style.ink)
	Kit.corner(shadow, 24)
	local face = Kit.frame(root, "Face", Style.white)
	Kit.corner(face, 24)
	Kit.stroke(face, Style.ink)
	gradient(face, 90, { Style.hex(0xF1ECFF), Style.hex(0xDCD2FF) })
	local title = Kit.text(face, "Title", "Display Slots", 24, Style.display())
	outlined(title, 3)
	local hint = Kit.text(
		face,
		"Hint",
		"More slots, more earning figures",
		14,
		Style.body(Enum.FontWeight.ExtraBold),
		Style.muted
	)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	type Tile = {
		slot: number,
		key: string?,
		root: Frame,
		shadow: Frame,
		face: Frame,
		picture: Art,
		chip: Badge.Badge,
		action: Button.Button,
		done: Stamp,
		note: TextLabel,
	}
	local made: { Tile } = {}
	local products = { Catalog.coinSlot }
	for _, key in keys do
		table.insert(products, Catalog.products[key])
	end
	for index, product in products do
		local slot = 3 + index
		local coin = product == Catalog.coinSlot
		local key = if coin then nil else product.key
		local tile = Kit.frame(face, "Slot" .. slot)
		local tileShadow = Kit.frame(tile, "Shadow", Style.ink)
		Kit.corner(tileShadow, 18)
		local tileFace = Kit.frame(tile, "Face", Style.white)
		Kit.corner(tileFace, 18)
		Kit.stroke(tileFace, Style.ink)
		gradient(tileFace, 90, { product.top, Style.white, Style.white })
		local chip = Badge.create(tileFace, "Currency", if coin then "COINS" else "ROBUX PASS", {
			fill = if coin then Style.gold else Style.hex(0x2CBF5E),
			color = if coin then Style.ink else Style.white,
			height = 22,
			size = 12,
			outline = Style.ink,
			font = Style.display(),
			icon = if coin then "Coin" else nil,
		})
		chip.root.AnchorPoint = Vector2.new(0.5, 0)
		local action = Button.create(
			tileFace,
			"Action",
			{
				variant = if coin then "gold" else "mint",
				text = "Unlock",
				size = 16,
				radius = 14,
				drop = 3,
				price = coin,
			},
			ctx.scope,
			ctx.effects,
			function()
				if key then
					open(key)
				elseif ctx.canAct() then
					ctx.send("Expand", nil, nil, nil)
				end
			end
		)
		action.button.AnchorPoint = Vector2.new(0.5, 0)
		local done = stamp(tileFace, "UNLOCKED")
		done.root.Name = "UnlockedStamp"
		done.root.BackgroundColor3 = Style.mint
		done.label.TextColor3 = Style.mintInk
		local note =
			Kit.text(tileFace, "Note", "", 12, Style.body(Enum.FontWeight.ExtraBold), Style.muted)
		note.TextXAlignment = Enum.TextXAlignment.Center
		note.TextWrapped = true
		table.insert(made, {
			slot = slot,
			key = key,
			root = tile,
			shadow = tileShadow,
			face = tileFace,
			picture = art(tileFace, product),
			chip = chip,
			action = action,
			done = done,
			note = note,
		})
	end
	return {
		root = root,
		refresh = function(input: Presentation.Input, snapshot: Types.Snapshot?)
			for _, tile in made do
				local unlocked = if snapshot then snapshot.unlocked else 0
				local owned = snapshot ~= nil and unlocked >= tile.slot
				tile.done.root.Visible = owned
				tile.action.button.Visible = not owned
				tile.root:SetAttribute("Unlocked", owned)
				if owned then
					tile.note.Text = "Yours to keep"
				elseif not snapshot then
					tile.action.set("Unlock", false)
					tile.note.Text = "Loading…"
				elseif unlocked < tile.slot - 1 then
					tile.action.set(`Slot {tile.slot - 1} first`, false)
					tile.note.Text = `Unlock Display slot {tile.slot - 1} first`
				elseif tile.key then
					local view = Presentation.view(input, tile.key)
					local offer = Presentation.offer(input, tile.key)
					tile.action.set(view.stamp, offer.buyAllowed == true and ctx.commerce ~= nil)
					tile.note.Text = "Permanent · bought once"
				else
					local price = snapshot.expansionCost
					local need = State.need(snapshot, price)
					tile.action.setPrice(State.compact(price))
					tile.action.set("Unlock", need == nil and ctx.canAct())
					tile.note.Text = need or "Paid with Coins you earn"
				end
			end
		end,
		layout = function(width: number, phone: boolean): number
			local pad = if phone then 10 else 14
			local tileHeight = if phone then 172 else 198
			local height = pad + 34 + tileHeight + pad + 8
			root.Size = UDim2.fromOffset(width, height)
			Kit.rect(shadow, 0, 6, width, height)
			Kit.rect(face, 0, 0, width, height)
			title.TextSize = if phone then 20 else 24
			Kit.rect(title, pad + 4, pad, 200, 30)
			Kit.rect(hint, pad + 200, pad, width - pad * 2 - 204, 30)
			hint.Visible = width >= 460
			local gap = if phone then 8 else 12
			local tileWidth = (width - pad * 2 - gap * (#made - 1)) / #made
			local artSize = if phone then 54 else 68
			local buttonHeight = if phone then 44 else 48
			for index, tile in made do
				local x = pad + (index - 1) * (tileWidth + gap)
				Kit.rect(tile.root, x, pad + 34, tileWidth, tileHeight)
				Kit.rect(tile.shadow, 0, 4, tileWidth, tileHeight)
				Kit.rect(tile.face, 0, 0, tileWidth, tileHeight)
				tile.picture.size(artSize)
				tile.picture.root.Position = UDim2.fromOffset(tileWidth / 2, 8 + artSize / 2)
				tile.chip.root.Position = UDim2.new(0.5, 0, 0, 12 + artSize)
				local buttonY = tileHeight - buttonHeight - 26
				tile.action.button.Position = UDim2.new(0.5, 0, 0, buttonY)
				tile.action.button.Size = UDim2.fromOffset(tileWidth - 16, buttonHeight)
				tile.action.stack(tileWidth < 150)
				Kit.rect(tile.done.root, 8, buttonY, tileWidth - 16, buttonHeight)
				Kit.rect(tile.note, 6, tileHeight - 24, tileWidth - 12, 18)
			end
			return height
		end,
	}
end

-- Product sheet: art column, benefits and rules, and the (not yet live) purchase footer.
type Sheet = {
	root: Frame,
	open: (string) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	refresh: () -> (),
	reconcile: () -> (),
	layout: (width: number, height: number, phone: boolean) -> (),
}
local function sheet(parent: Instance, ctx: Context.Context, input: () -> Presentation.Input): Sheet
	local root = Kit.frame(parent, "ProductSheet")
	root.ZIndex = 5
	root.Visible = false
	local backdrop = button(root, "SheetBackdrop", "Back to the Store")
	backdrop.BackgroundColor3 = Style.dim
	backdrop.BackgroundTransparency = 0.55
	backdrop.Selectable = false
	backdrop.Size = UDim2.fromScale(1, 1)
	local panel = Kit.card(root, "SheetPanel", Style.surface, 24, 8, 4)
	local side = Kit.frame(panel.face, "SheetArt", Style.white)
	local sideCorner = Kit.corner(side, 22)
	local sideFill = gradient(side, 90, { Style.white, Style.white })
	-- The art column's inner edge is square: a filler with the same vertical gradient.
	local sideSquare = Kit.frame(side, "SheetArtSquare", Style.white)
	local squareFill = gradient(sideSquare, 90, { Style.white, Style.white })
	local sideEdge = Kit.frame(panel.face, "SheetArtEdge", Style.ink)
	local artHolder = Kit.frame(side, "ArtHolder")
	artHolder.ZIndex = 2
	local title = Kit.text(panel.face, "SheetTitle", "", 28, Style.display())
	local close = button(panel.face, "SheetClose", "Back to the Store")
	close.BackgroundColor3 = Style.red
	close.BackgroundTransparency = 0
	Kit.round(close)
	Kit.stroke(close, Style.ink)
	local closeIcon = Icons.create(close, "Close", Style.white, 16)
	closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	closeIcon.Position = UDim2.fromScale(0.5, 0.5)
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	local body = Kit.scroll(panel.face, "SheetBody", ctx.scope, list, 2, ctx.scale)
	body.Selectable = false
	local footer = Kit.frame(panel.face, "SheetFooter", Style.white)
	local footerLine = Kit.frame(footer, "Line", Style.divider)
	local footerStamp = stamp(footer, soon)
	local purchase = button(footerStamp.root, "Purchase", "Confirm purchase in Roblox")
	purchase.Size = UDim2.fromScale(1, 1)
	local footerNote =
		Kit.text(footer, "Note", "", 13, Style.body(Enum.FontWeight.ExtraBold), Style.muted)
	footerNote.TextWrapped = true
	local rows: { Instance } = {}
	local picture: Art? = nil
	local shown = false
	local current: Catalog.Product? = nil
	local returnFocus: GuiObject? = nil
	local duration = 30
	local controlStamp = ""
	local function controlSignature(): string
		if not current then
			return ""
		end
		local value = input()
		local offer = Presentation.offer(value, current.key, duration)
		local parts = {
			current.key,
			tostring(duration),
			offer.availability,
			offer.outcome,
			tostring(offer.buyAllowed),
			tostring(offer.toggle),
			offer.benefit or "",
			value.modifiers or "",
		}
		for _, token in value.tokens do
			if token.product == current.key then
				table.insert(parts, `{token.key}:{token.count}:{token.activation}`)
			end
		end
		if current.key == "autoOpen" and value.automation then
			table.insert(
				parts,
				`{value.automation.status}:{value.automation.completed}:{value.automation.reason}`
			)
		end
		if
			current.key == "luck"
			or current.key == "boostLuck2"
			or current.key == "boostLuck4"
			or current.key == "boostCombo"
		then
			for _, figure in FigureCatalog.figures do
				table.insert(parts, tostring(if value.odds then value.odds[figure.id] else nil))
			end
		end
		return table.concat(parts, "|")
	end
	local controls = Scope.create()
	ctx.scope.add(function()
		controls.destroy()
	end)
	local width, height, phone = 0, 0, false
	local function row(text: string, icon: string, order: number, color: Color3)
		local line = Kit.frame(body, "Row")
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.Size = UDim2.new(1, -8, 0, 0)
		line.LayoutOrder = order
		local mark = Icons.create(line, icon, color, 16)
		mark.Position = UDim2.fromOffset(0, 2)
		local label = Kit.text(line, "Text", text, 14, Style.body(Enum.FontWeight.ExtraBold))
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, -24, 0, 0)
		label.Position = UDim2.fromOffset(24, 0)
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		label.TextYAlignment = Enum.TextYAlignment.Top
		table.insert(rows, line)
	end
	local function heading(text: string, order: number)
		local label =
			Kit.text(body, "Heading", text, 12, Style.body(Enum.FontWeight.Heavy), Style.muted)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -8, 0, 22)
		table.insert(rows, label)
	end
	local function paragraph(text: string, order: number)
		local label = Kit.text(body, "Benefit", text, 15, Style.body(Enum.FontWeight.Heavy))
		label.LayoutOrder = order
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, -8, 0, 0)
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		table.insert(rows, label)
	end
	local function arrange()
		local product = current
		if not product or width <= 0 then
			return
		end
		Kit.rect(root, 0, 0, width, height)
		local panelWidth = if phone then width - 8 else math.min(760, width - 60)
		local panelHeight = if phone then height - 8 else math.min(height - 36, 400)
		Kit.rect(
			panel.root,
			(width - panelWidth) / 2,
			(height - panelHeight) / 2,
			panelWidth,
			panelHeight
		)
		Kit.rect(panel.face, 0, 0, panelWidth, panelHeight)
		Kit.rect(panel.shadow, 0, 8, panelWidth, panelHeight)
		panel.shadow.Visible = not phone
		panel.radius(if phone then 18 else 24)
		sideCorner.CornerRadius = UDim.new(0, if phone then 16 else 22)
		local sideWidth = if phone then 132 else 230
		Kit.rect(side, 0, 0, sideWidth, panelHeight)
		Kit.rect(sideSquare, sideWidth - 30, 0, 30, panelHeight)
		Kit.rect(sideEdge, sideWidth, 0, 4, panelHeight)
		local size = if phone then 72 else 120
		Kit.rect(artHolder, 0, 0, sideWidth, panelHeight)
		if picture then
			picture.size(size)
			picture.root.Position = UDim2.fromOffset(sideWidth / 2, panelHeight / 2)
		end
		local x = sideWidth + 4 + 16
		local innerWidth = panelWidth - x - 16
		Kit.rect(close, panelWidth - 16 - 44, 12, 44, 44)
		title.TextSize = if phone then 22 else 28
		Kit.rect(title, x, 12, innerWidth - 52, 44)
		local footerHeight = if phone then 68 else 96
		Kit.rect(
			footer,
			sideWidth + 4,
			panelHeight - footerHeight,
			panelWidth - sideWidth - 4,
			footerHeight
		)
		Kit.rect(footerLine, 0, 0, panelWidth - sideWidth - 4, 3)
		local stampHeight = if phone then 44 else 52
		Kit.rect(footerStamp.root, 16, 12, innerWidth, stampHeight)
		footerStamp.label.TextSize = if phone then 17 else 20
		Kit.rect(footerNote, 16, 14 + stampHeight, innerWidth, footerHeight - stampHeight - 16)
		footerNote.Visible = not phone
		Kit.rect(body, x - 2, 60, innerWidth + 4, panelHeight - 60 - footerHeight)
	end
	local function hide()
		if not shown then
			return
		end
		shown = false
		root.Visible = false
		if returnFocus and returnFocus.Parent then
			GuiService.SelectedObject = returnFocus
		end
		if picture then
			picture.root:Destroy()
			picture = nil
		end
		for _, made in rows do
			made:Destroy()
		end
		table.clear(rows)
		controls.destroy()
		controls = Scope.create()
	end
	ctx.scope.connect(backdrop.Activated, hide)
	ctx.scope.connect(close.Activated, function()
		hide()
		Sfx.play("close")
	end)
	local function refresh()
		if not shown or not current then
			return
		end
		local view = Presentation.view(input(), current.key, duration)
		footerStamp.label.Text = view.stamp
		footerStamp.label.TextScaled, footerStamp.label.TextWrapped = true, true
		local offer = Presentation.offer(input(), current.key, duration)
		purchase.Active = offer.buyAllowed == true and ctx.commerce ~= nil
		purchase.Selectable = purchase.Active
		footerStamp.root.BackgroundColor3 = if purchase.Active
			then Style.mint
			else Style.disabledFill
		footerNote.Text = if input().fixture
			then "PREVIEW ONLY · Buying disabled"
			else "Prices come from Roblox · Native confirmation required"
		local status = body:FindFirstChild("PresentationStatus") :: TextLabel?
		if status then
			status.Text = view.note
		end
		local promise = body:FindFirstChild("ProductPromise") :: TextLabel?
		if promise then
			promise.Text = current.kind .. " · " .. (offer.benefit or current.benefit)
		end
	end
	local view: Sheet
	ctx.scope.connect(purchase.Activated, function()
		if
			current
			and ctx.commerce
			and Presentation.offer(input(), current.key, duration).buyAllowed
		then
			ctx.commerce.purchase(current.key, duration)
		end
	end)
	view = {
		root = root,
		refresh = refresh,
		reconcile = function()
			if not shown or not current then
				return
			end
			if controlStamp == controlSignature() then
				refresh()
				return
			end
			local key = current.key
			local offset, priorReturn = body.CanvasPosition, returnFocus
			local selected = GuiService.SelectedObject
			local name = if selected and selected:IsDescendantOf(root) then selected.Name else nil
			view.open(key)
			returnFocus, body.CanvasPosition = priorReturn, offset
			if name then
				local target = root:FindFirstChild(name, true)
				if target and target:IsA("GuiObject") and target.Selectable then
					GuiService.SelectedObject = target
				end
			end
		end,
		isOpen = function()
			return shown
		end,
		open = function(key: string)
			hide()
			returnFocus = GuiService.SelectedObject
			local product = Catalog.products[key]
			current = product
			shown = true
			root.Visible = true
			title.Text = product.name
			title.TextWrapped, title.TextTruncate = true, Enum.TextTruncate.None
			sideFill.Color = ColorSequence.new(product.top, product.bottom)
			squareFill.Color = ColorSequence.new(product.top, product.bottom)
			picture = art(artHolder, product)
			local order = 0
			local function nextOrder(): number
				order += 1
				return order
			end
			paragraph(
				product.kind
					.. " · "
					.. (Presentation.offer(input(), key, duration).benefit or product.benefit),
				nextOrder()
			)
			rows[#rows].Name = "ProductPromise"
			paragraph(Presentation.view(input(), key, duration).note, nextOrder())
			rows[#rows].Name = "PresentationStatus"
			if ctx.commerce and Presentation.view(input(), key, duration).pending then
				local recovery = button(body, "CheckPurchase", "Check purchase recovery")
				recovery.Text, recovery.FontFace, recovery.TextSize =
					"Check again", Style.display(), 16
				recovery.BackgroundTransparency, recovery.BackgroundColor3 = 0, Style.white
				recovery.Size, recovery.LayoutOrder = UDim2.new(1, -8, 0, 44), nextOrder()
				Kit.corner(recovery, 12)
				Kit.stroke(recovery, Style.ink, Style.outlineSmall)
				table.insert(rows, recovery)
				controls.connect(recovery.Activated, function()
					if ctx.commerce then
						ctx.commerce.refresh()
					end
				end)
			end
			if key == "boostCoins" then
				heading("CHOOSE TOKEN LENGTH", nextOrder())
				local lengths = Kit.frame(body, "Lengths")
				lengths.Size = UDim2.new(1, -8, 0, 44)
				lengths.LayoutOrder = nextOrder()
				table.insert(rows, lengths)
				local chips: { TextButton } = {}
				for index, minutes in { 15, 30, 60 } do
					local chip =
						button(lengths, "Length" .. minutes, `Preview {minutes} minute token`)
					chip.Text, chip.FontFace, chip.TextSize = `{minutes} min`, Style.display(), 16
					chip.Size = UDim2.new(1 / 3, -6, 0, 44)
					chip.Position = UDim2.fromScale((index - 1) / 3, 0)
					chip.BackgroundTransparency = 0
					Kit.corner(chip, 10)
					Kit.stroke(chip, Style.ink, Style.outlineSmall)
					table.insert(chips, chip)
					local function paint()
						for position, target in chips do
							target.BackgroundColor3 = if ({ 15, 30, 60 })[position]
									== duration
								then Style.violetWash
								else Style.white
							target:SetAttribute("Selected", ({ 15, 30, 60 })[position] == duration)
						end
					end
					controls.connect(chip.Activated, function()
						duration = minutes
						paint()
						refresh()
					end)
					paint()
				end
			end
			if
				key == "luck"
				or key == "boostLuck2"
				or key == "boostLuck4"
				or key == "boostCombo"
			then
				local projected = input().luckOfferOdds
				local proposed = if projected
					then projected[if key == "boostLuck4" then 4 else 2]
					else nil
				local base, odds = input().baseOdds, input().odds
				heading("YOUR NEXT BOX · BASE / CURRENT / WITH THIS LUCK", nextOrder())
				if base and odds and proposed then
					for _, collection in FigureCatalog.collections do
						paragraph(collection.name, nextOrder())
						for _, figure in FigureCatalog.figures do
							if figure.collection == collection.id then
								paragraph(
									`{figure.name}: {State.percent(base[figure.id] or 0)} / {State.percent(
										odds[figure.id] or 0
									)} / {State.percent(proposed[figure.id] or 0)}`,
									nextOrder()
								)
							end
						end
					end
				else
					paragraph(
						"Your exact itemized odds are unavailable. This Luck offer cannot be purchased yet.",
						nextOrder()
					)
				end
			end
			heading("YOU GET", nextOrder())
			local promise = Presentation.offer(input(), key, duration).benefit
			local promised: { string } = if promise then { promise } else product.gets
			for _, text in promised do
				row(text, "Check", nextOrder(), Style.mintText)
			end
			heading("GOOD TO KNOW", nextOrder())
			for _, text in product.rules do
				row(text, "Star", nextOrder(), Style.candyPink)
			end
			if
				key == "luck"
				or key == "boostLuck2"
				or key == "boostLuck4"
				or key == "boostCombo"
			then
				heading("ODDS WITH LUCK · NO-PITY EXAMPLES", nextOrder())
				for _, text in Catalog.luckExamples do
					paragraph(text, nextOrder())
				end
				paragraph(
					"These are specification examples, not your current odds. Your itemized odds above come from the server. Luck changes weights, never guarantees; pity and reward floors still apply. Each box in a batch updates pity.",
					nextOrder()
				)
			end
			if
				key == "boostCoins"
				or key == "boostLuck2"
				or key == "boostLuck4"
				or key == "boostCombo"
			then
				heading("ACTIVATION", nextOrder())
				paragraph(
					"Activate from My Perks after confirmed delivery. The timer continues while you're offline. Same boosts add time, not strength. Different Luck strengths cannot overlap. Redundant or incompatible tokens are kept; confirm activation to start a timer.",
					nextOrder()
				)
			end
			if key == "autoOpen" then
				heading("AUTO OPEN", nextOrder())
				local auto = input().automation
				paragraph(
					if auto
						then `{auto.status} · {auto.collection}\nHow many: {auto.count} (1–100) · Completed: {auto.completed}\nKeep a reserve: {auto.reserve} Coins\nSpends up to {auto.spend} Coins. {auto.reason or ""}`
						else "Choose a collection in the Coin Shop, 1–100 boxes (default 10), and an optional Coin reserve.",
					nextOrder()
				)
				paragraph(
					"Choose your collection, budget and reserve in the Coin Shop. Stops when requested, finished, unaffordable or leaving. No further Coins are spent after stopping; select Start to resume. Open 10 and Skip stay free.",
					nextOrder()
				)
			end
			local setup = PerkControls.create(
				body,
				controls,
				ctx.effects,
				input(),
				key,
				ctx.commerce,
				function()
					ctx.navigate("Shop", { automation = true })
				end
			)
			if setup then
				setup.LayoutOrder = nextOrder()
				table.insert(rows, setup)
			end
			footerStamp.label.Text = if product.elsewhere then elsewhere else soon
			footerNote.Text = if product.elsewhere
				then "Shown when you come back with offline Coins. Claim always stays free."
				else "Buying isn't switched on yet. Prices will come from Roblox."
			arrange()
			refresh()
			controlStamp = controlSignature()
			GuiService.SelectedObject = close
			body.CanvasPosition = Vector2.new(0, 0)
		end,
		close = hide,
		layout = function(nextWidth: number, nextHeight: number, nextPhone: boolean)
			width, height, phone = nextWidth, nextHeight, nextPhone
			arrange()
		end,
	}
	return view
end

-- Candy "STORE" chip for another screen's header (the Coin Shop): its only Robux element.
function Store.chip(parent: Instance, ctx: Context.Context): TextButton
	local chip = button(parent, "StoreChip", "Open the Robux Store")
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, Style.target)
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = Style.white
	Kit.round(chip)
	Kit.stroke(chip, Style.ink)
	gradient(chip, 45, { Style.candyPinkLight, Style.candyPink, Style.candyViolet })
	Kit.padding(chip, 0, 14, 0, 8)
	Kit.list(chip, Enum.FillDirection.Horizontal, 6, Enum.VerticalAlignment.Center)
	local icon = Icons.create(chip, "Gift", Style.gold, 26)
	icon.LayoutOrder = 1
	local label = Kit.text(chip, "Label", "STORE", 17, Style.display())
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 24)
	label.TextTruncate = Enum.TextTruncate.None
	label.LayoutOrder = 2
	outlined(label, 2.5)
	ctx.scope.connect(chip.Activated, function()
		ctx.navigate("Store", { tab = "featured" })
	end)
	return chip
end

export type PresentationScreen =
	Context.Screen
	& { present: (Presentation.Input) -> (), tick: (number) -> () }
function Store.create(parent: Instance, ctx: Context.Context): PresentationScreen
	local input = Presentation.empty()
	local observedNow = input.now
	local shell = Shell.create(parent, ctx, {
		id = "Store",
		title = "STORE",
		subtitle = "Treats for Robux · Boxes are in the Shop for Coins",
	})
	local root, body = shell.root, shell.body
	-- Candy header: a horizontal gradient behind the shell's own title, chips and Close.
	local header = shell.header
	local headerFill = Kit.frame(header, "HeaderFill", Style.white)
	headerFill.ZIndex = 0
	local headerCorner = Kit.corner(headerFill, 28)
	local headerColors = { Style.candyViolet, Style.candyPink, Style.candyPeach }
	gradient(headerFill, 0, headerColors)
	local headerSquare = Kit.frame(headerFill, "HeaderSquare", Style.white)
	gradient(headerSquare, 0, headerColors)
	outlined(shell.title, 3)
	shell.subtitle.TextColor3 = Style.white
	local subtitleStroke = Instance.new("UIStroke")
	subtitleStroke.Color = Style.ink
	subtitleStroke.Thickness = 1.5
	subtitleStroke.Parent = shell.subtitle
	shell.close.BackgroundColor3 = Style.red
	Kit.stroke(shell.close, Style.ink)
	local coinShop = button(shell.chips, "CoinShopChip", "Open the Coin Shop")
	coinShop.AutomaticSize = Enum.AutomaticSize.X
	coinShop.Size = UDim2.fromOffset(0, 44)
	coinShop.BackgroundTransparency = 0
	coinShop.BackgroundColor3 = Style.white
	coinShop.LayoutOrder = 1
	Kit.round(coinShop)
	Kit.stroke(coinShop, Style.ink)
	Kit.padding(coinShop, 0, 14, 0, 10)
	Kit.list(coinShop, Enum.FillDirection.Horizontal, 6, Enum.VerticalAlignment.Center)
	local coinIcon = Icons.create(coinShop, "Coin", Style.ink, 22)
	coinIcon.LayoutOrder = 1
	local coinLabel = Kit.text(coinShop, "Label", "Coin Shop", 16, Style.display())
	coinLabel.AutomaticSize = Enum.AutomaticSize.X
	coinLabel.Size = UDim2.fromOffset(0, 22)
	coinLabel.TextTruncate = Enum.TextTruncate.None
	coinLabel.LayoutOrder = 2
	ctx.scope.connect(coinShop.Activated, function()
		ctx.navigate("Shop")
	end)

	local ground = Kit.frame(body, "StoreGround", Style.storeGround)
	ground.ZIndex = 0
	-- Tabs column
	local tabsRoot = Kit.frame(body, "StoreTabs")
	type TabButton = {
		info: Catalog.TabInfo,
		root: TextButton,
		halo: Frame,
		shadow: Frame,
		face: Frame,
		well: Frame,
		icon: GuiObject,
		label: TextLabel,
	}
	local tabs: { TabButton } = {}
	local tokenBadge: Badge.Badge? = nil
	local current: Catalog.Tab = "featured"
	local pick: (Catalog.Tab) -> () = function() end
	for _, info in Catalog.tabs do
		local tab = button(tabsRoot, "StoreTab_" .. info.id, info.name)
		local halo = Kit.frame(tab, "Halo", Style.white)
		Kit.corner(halo, 22)
		local shadow = Kit.frame(tab, "Shadow", Style.ink)
		Kit.corner(shadow, 18)
		local face = Kit.frame(tab, "Face", Style.white)
		Kit.corner(face, 18)
		Kit.stroke(face, Style.ink)
		gradient(face, 90, { info.top, info.bottom })
		local well = Kit.frame(face, "Well", Style.white)
		Kit.round(well)
		local wellStroke = Kit.stroke(well, Style.ink, Style.outlineSmall)
		-- Tab art carries its own white sticker border, so it needs no disc behind it.
		local icon: GuiObject
		if info.image then
			well.BackgroundTransparency = 1
			wellStroke.Enabled = false
			local art = Instance.new("ImageLabel")
			art.Name = "Icon"
			art.BackgroundTransparency = 1
			art.Image = "rbxassetid://" .. info.image
			art.ScaleType = Enum.ScaleType.Fit
			art.ZIndex = 2
			art.Parent = well
			icon = art
		else
			-- No art (My Perks): a bold white glyph on a disc in the tab's own colour.
			well.BackgroundColor3 = info.bottom
			icon = Icons.create(well, info.icon, Style.white, 28)
		end
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		local label = Kit.text(face, "Label", info.name, 18, Style.display())
		if info.id == "perks" then
			local made = Badge.create(
				tab,
				"UnusedTokens",
				"0",
				{ fill = Style.mint, color = Style.mintInk, height = 22, size = 12 }
			)
			made.root.AnchorPoint, made.root.Position = Vector2.new(1, 0), UDim2.new(1, 4, 0, -4)
			made.root.ZIndex, made.root.Visible = 3, false
			tokenBadge = made
		end
		outlined(label, 2.5)
		ctx.scope.connect(tab.Activated, function()
			if current ~= info.id then
				Sfx.play("tab")
			end
			pick(info.id)
		end)
		table.insert(tabs, {
			info = info,
			root = tab,
			halo = halo,
			shadow = shadow,
			face = face,
			well = well,
			icon = icon,
			label = label,
		})
	end

	-- Content
	local content = Kit.canvas(body, "StoreContent")
	local sheetView = sheet(body, ctx, function()
		return input
	end)
	local function open(key: string)
		if
			ctx.commerce
			and (key == "pouch" or key == "stack" or key == "sack" or key == "chest" or key == "slot5" or key == "slot6")
			and Presentation.offer(input, key).buyAllowed
		then
			ctx.commerce.purchase(key, nil)
			return
		end
		sheetView.open(key)
		Sfx.play("open")
	end
	local perks = Perks.create(content, ctx.scope, open)
	local activeStrip = button(content, "ActiveBoosts", "View active boosts in My Perks")
	activeStrip.BackgroundTransparency, activeStrip.BackgroundColor3 = 0, Style.mint
	activeStrip.Text, activeStrip.FontFace, activeStrip.TextSize =
		"Boosts running → My Perks", Style.display(), 16
	Kit.corner(activeStrip, 12)
	Kit.stroke(activeStrip, Style.ink, Style.outlineSmall)
	ctx.scope.connect(activeStrip.Activated, function()
		pick("perks")
	end)
	local notice = Kit.frame(content, "OpeningSoon", Style.white)
	Kit.corner(notice, 16)
	Kit.stroke(notice, Style.ink, Style.outlineSmall)
	gradient(notice, 0, { Style.white, Style.candyPinkLight })
	local noticeIcon = Icons.create(notice, "Star", Style.candyPink, 22)
	noticeIcon.Position = UDim2.fromOffset(12, 11)
	local noticeText = Kit.text(
		notice,
		"Text",
		"Opening soon! Look around; buying isn't switched on yet.",
		14,
		Style.body(Enum.FontWeight.Heavy)
	)
	noticeText.Position = UDim2.fromOffset(42, 0)
	noticeText.TextWrapped, noticeText.TextTruncate = true, Enum.TextTruncate.None
	local heading = Kit.text(content, "SectionTitle", "", 22, Style.display())
	outlined(heading, 2.5)
	local footnote = Kit.text(
		content,
		"Footnote",
		"Packs don't change box odds, and Coin multipliers don't apply to them.",
		13,
		Style.body(Enum.FontWeight.ExtraBold),
		Style.muted
	)
	footnote.TextWrapped = true
	local empty = Kit.frame(content, "PerksEmpty")
	local emptyIcon = Icons.create(empty, "Gift", Style.candyPink, 64)
	emptyIcon.AnchorPoint = Vector2.new(0.5, 0)
	emptyIcon.Position = UDim2.new(0.5, 0, 0, 10)
	local emptyText = Kit.text(
		empty,
		"Text",
		"Nothing here yet. Anything you buy shows up here, with its timers and switches.",
		15,
		Style.body(Enum.FontWeight.Heavy),
		Style.muted
	)
	emptyText.TextWrapped = true
	emptyText.TextXAlignment = Enum.TextXAlignment.Center
	emptyText.Position = UDim2.fromOffset(0, 84)
	emptyText.Size = UDim2.new(1, 0, 0, 44)

	type TabContent = {
		hero: Card?,
		slots: Slots?,
		tiers: Tiers?,
		cards: { Card },
		title: string,
	}
	local gameplay: Types.Snapshot? = nil
	local titles: { [string]: string } = {
		featured = "Featured",
		upgrades = "Helpers & Luck",
		boosts = "Boosts · buy now, activate when you're ready",
		coins = "Coin packs",
		perks = "My Perks",
	}
	local views: { [string]: TabContent } = {}
	for _, info in Catalog.tabs do
		local section = Catalog.sections[info.id]
		local view: TabContent = { cards = {}, title = titles[info.id] or info.name }
		if section.hero then
			local key = section.hero
			view.hero = hero(content, Catalog.products[key], ctx.scope, function()
				open(key)
			end)
		end
		if section.slots then
			view.slots = slots(content, section.slots, ctx, open)
		end
		if section.tiers then
			view.tiers = tiers(content, section.tiers, ctx.scope, open)
		end
		for _, key in section.cards do
			table.insert(
				view.cards,
				-- Featured repeats products from other tabs, so its copies get their own names.
				card(
					content,
					(if info.id == "featured" then "Featured_" else "Card_") .. key,
					Catalog.products[key],
					ctx.scope,
					function()
						open(key)
					end
				)
			)
			hover(view.cards[#view.cards].root, ctx.scope, ctx.effects)
		end
		views[info.id] = view
	end

	local width, height, phone = 0, 0, false
	local function arrange()
		if width <= 0 then
			return
		end
		Kit.rect(ground, 0, 0, width, height)
		local icons = phone or width < 1000
		local tabWidth = if icons then (if phone then 78 else 92) else 208
		Kit.rect(tabsRoot, 0, 0, tabWidth, height)
		local tabHeight = if icons then 50 else 58
		local tabGap = if icons then 6 else 10
		local inset = if icons then 8 else 12
		for index, tab in tabs do
			local on = tab.info.id == current
			local x = inset + (if on then (if icons then 4 else 6) else 0)
			local y = (if icons then 10 else 12) + (index - 1) * (tabHeight + tabGap)
			local tabW = tabWidth - inset * 2
			Kit.rect(tab.root, x, y, tabW, tabHeight)
			Kit.rect(tab.halo, -4, -4, tabW + 8, tabHeight + 8)
			tab.halo.Visible = on
			Kit.rect(tab.shadow, 0, 4, tabW, tabHeight)
			Kit.rect(tab.face, 0, 0, tabW, tabHeight)
			tab.root:SetAttribute("Selected", on)
			tab.label.Text = if icons then tab.info.short else tab.info.name
			if icons then
				Kit.rect(tab.well, (tabW - 28) / 2, 4, 28, 28)
				local art = if tab.info.image then 34 else 18
				tab.icon.Size = UDim2.fromOffset(art, art)
				tab.label.TextSize = 11
				tab.label.TextXAlignment = Enum.TextXAlignment.Center
				Kit.rect(tab.label, 2, tabHeight - 18, tabW - 4, 14)
			else
				Kit.rect(tab.well, 10, (tabHeight - 40) / 2, 40, 40)
				local art = if tab.info.image then 46 else 24
				tab.icon.Size = UDim2.fromOffset(art, art)
				tab.label.TextSize = 18
				tab.label.TextXAlignment = Enum.TextXAlignment.Left
				Kit.rect(tab.label, 62, 0, tabW - 68, tabHeight)
			end
		end
		local contentWidth = width - tabWidth
		Kit.rect(content, tabWidth, 0, contentWidth, height)
		local pad = if phone then 10 else 16
		local inner = contentWidth - pad * 2 - 6
		local y = pad
		Kit.rect(notice, pad, y, inner, 44)
		Kit.rect(noticeText, 42, 0, inner - 52, 44)
		noticeText.TextSize = if phone then 13 else 14
		y += 44 + 14
		local activeCount = 0
		for _, timer in input.timers do
			if timer.endsAt > observedNow then
				activeCount += 1
			end
		end
		activeStrip.Visible = current == "boosts" and activeCount > 0
		if activeStrip.Visible then
			activeStrip.Text = `{activeCount} boosts running → My Perks`
			Kit.rect(activeStrip, pad, y, inner, 44)
			y += 56
		end
		for id, view in views do
			local visible = id == current
			if view.hero then
				view.hero.root.Visible = visible
			end
			if view.slots then
				view.slots.root.Visible = visible
			end
			if view.tiers then
				view.tiers.root.Visible = visible
			end
			for _, made in view.cards do
				made.root.Visible = visible
			end
		end
		local view = views[current]
		if view.hero then
			if not Presentation.offer(input, view.hero.key).hidden then
				local heroHeight = if phone then 132 else 164
				Kit.rect(view.hero.root, pad, y, inner, heroHeight)
				view.hero.layout(inner, heroHeight, phone)
				y += heroHeight + 6 + 16
			end
		end
		if view.slots then
			view.slots.root.Position = UDim2.fromOffset(pad, y)
			y += view.slots.layout(inner, phone) + 6 + 16
		end
		if view.tiers then
			view.tiers.root.Position = UDim2.fromOffset(pad, y)
			y += view.tiers.layout(inner, phone) + 6 + 16
		end
		heading.Text = view.title
		heading.TextSize = if phone then 18 else 22
		Kit.rect(heading, pad + 2, y, inner, 28)
		y += 28 + 8
		local gap = if phone then 10 else 14
		local minimum = if phone then 160 else 190
		local columns = math.clamp(math.floor((inner + gap) / (minimum + gap)), 1, 4)
		local cardWidth = math.floor((inner - gap * (columns - 1)) / columns)
		local cardHeight = if phone then 258 else 284
		local count = 0
		for _, made in view.cards do
			if Presentation.offer(input, made.key).hidden then
				made.root.Visible = false
				continue
			end
			local column = count % columns
			local line = count // columns
			count += 1
			Kit.rect(
				made.root,
				pad + column * (cardWidth + gap),
				y + line * (cardHeight + gap + 6),
				cardWidth,
				cardHeight
			)
			made.layout(cardWidth, cardHeight, phone)
		end
		local lines = math.ceil(count / columns)
		if lines > 0 then
			y += lines * (cardHeight + 6) + (lines - 1) * gap + 12
		end
		footnote.Visible = current == "coins"
		if footnote.Visible then
			Kit.rect(footnote, pad + 2, y, inner, 40)
			y += 40
		end
		perks.root.Visible = current == "perks"
		if perks.root.Visible then
			perks.root.Position = UDim2.fromOffset(pad, y)
			y += perks.layout(inner, phone)
		end
		empty.Visible = current == "perks" and perks.empty()
		emptyText.Text = if input.ownershipReady
			then "No perks yet. Confirmed purchases, tokens and timers will appear here."
			else "Your perks aren't connected yet. Ownership, tokens and timers will appear after verification."
		if empty.Visible then
			Kit.rect(empty, pad, y, inner, 140)
			y += 140
		end
		Kit.fit(content, y + pad, height)
		for _, section in views do
			local banner = section.hero
			if banner then
				banner.root.Visible = section == view
					and not Presentation.offer(input, banner.key).hidden
			end
		end
		sheetView.layout(width, height, phone)
	end
	pick = function(id: Catalog.Tab)
		sheetView.close()
		current = id
		content.CanvasPosition = Vector2.new(0, 0)
		arrange()
	end

	local visible = false
	local signature = ""
	local dirty = true
	local function refresh()
		local unused = 0
		for _, token in input.tokens do
			unused += token.count
		end
		if tokenBadge then
			tokenBadge.label.Text = tostring(unused)
			tokenBadge.root.Visible = unused > 0
		end
		noticeText.Text = if input.fixture
			then "PREVIEW ONLY · Illustrative prices · No purchases or rewards"
			else input.modifiers or "Checking your Store offers…"
		for _, view in views do
			local cards = table.clone(view.cards)
			if view.hero then
				table.insert(cards, view.hero)
			end
			for _, made in cards do
				made.footer.label.Text = Presentation.view(input, made.key).stamp
				live(made.footer, Presentation.offer(input, made.key).buyAllowed == true)
				made.footer.label.TextScaled, made.footer.label.TextWrapped = true, true
				made.name.Text = Catalog.products[made.key].name
					.. (if input.longLabels then " · Collector presentation preview" else "")
				made.benefit.Text = Presentation.offer(input, made.key).benefit
					or Catalog.products[made.key].benefit
			end
			if view.tiers then
				view.tiers.refresh(input)
			end
			if view.slots then
				view.slots.refresh(input, gameplay)
			end
		end
		sheetView.refresh()
	end
	local screen: PresentationScreen = {
		root = root :: GuiObject,
		present = function(nextInput: Presentation.Input)
			local nextSignature = Presentation.signature(nextInput)
			dirty = dirty or signature ~= nextSignature
			signature = nextSignature
			input = nextInput
			if not visible or not dirty then
				return
			end
			observedNow = input.now
			dirty = false
			perks.update(input)
			sheetView.reconcile()
			refresh()
			arrange()
		end,
		tick = function(now: number)
			if visible then
				local before, after = 0, 0
				for _, timer in input.timers do
					if timer.endsAt > observedNow then
						before += 1
					end
					if timer.endsAt > now then
						after += 1
					end
				end
				observedNow = now
				if before ~= after then
					arrange()
				end
				perks.tick(now)
			end
		end,
		update = function(snapshot: Types.Snapshot)
			shell.update(snapshot)
			gameplay = snapshot
			local view = views.upgrades
			if visible and view and view.slots then
				view.slots.refresh(input, snapshot)
			end
		end,
		layout = function(nextWidth: number, nextHeight: number, nextPhone: boolean)
			width, height = shell.layout(nextWidth, nextHeight, nextPhone)
			phone = nextPhone
			local headerHeight = if phone then 56 else 76
			headerCorner.CornerRadius = UDim.new(0, if phone then 22 else 28)
			Kit.rect(headerFill, 0, 0, nextWidth, headerHeight)
			Kit.rect(headerSquare, 0, headerHeight / 2, nextWidth, headerHeight / 2)
			coinShop.Visible = not phone
			arrange()
		end,
		back = function(): boolean
			if sheetView.isOpen() then
				sheetView.close()
				return true
			end
			return false
		end,
		route = function(route: Context.Route?)
			if route and route.tab then
				pick(Catalog.tab(route.tab))
			end
		end,
		shown = function(value: boolean)
			visible = value
			if value then
				observedNow = input.now
				if dirty then
					dirty = false
					perks.update(input)
					arrange()
				end
				if ctx.commerce then
					ctx.commerce.refresh()
				end
				refresh()
				perks.tick(input.now)
			end
			if not value then
				sheetView.close()
			end
		end,
		cycle = function(step: number)
			local index = 1
			for position, tab in tabs do
				if tab.info.id == current then
					index = position
				end
			end
			pick(tabs[(index - 1 + step) % #tabs + 1].info.id)
			Sfx.play("tab")
		end,
	}
	return screen
end

return Store
