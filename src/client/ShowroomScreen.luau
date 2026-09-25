--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local State = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Icons = require(script.Parent.UIIcons)
local Preview = require(script.Parent.UIPreview)
local Showroom = {}
function Showroom.create(parent: Instance, ctx: Context.Context)
	local page = W.scroll(parent, "Display", ctx.scope)
	local selected: string? = nil
	local summary = W.card(page, "DisplaySummary", 120)
	summary.LayoutOrder = 1
	local income = W.title(summary, "", 34)
	W.inset(income, 8, 34)
	local bonus = W.label(summary, "", 32, 15)
	W.inset(bonus, 44, 32)
	local hint = W.label(summary, "Edit near your own shelf", 30, 14)
	W.inset(hint, 82, 30)
	hint.TextColor3 = Theme.muted
	local choice = W.action(page, "", ctx.scope, ctx.effects, function()
		selected = nil
	end, true)
	choice.button.LayoutOrder = 2
	choice.button.Visible = false
	local tiles = W.tiles(page, ctx.scope, 128, 4, 280)
	tiles.LayoutOrder = 3
	local slots: {
		{
			root: Frame,
			portrait: Preview.Preview,
			name: TextLabel,
			label: TextLabel,
			placeholder: Frame,
			lock: Frame,
			action: W.Action,
			remove: W.Action,
		}
	} =
		{}
	for slot = 1, 4 do
		local card = W.card(tiles, "Slot" .. slot, 280)
		card.LayoutOrder = slot
		local label = W.label(card, "Slot " .. slot, 26, 14)
		W.inset(label, 4, 26)
		local portrait = Preview.create(card, ctx.scope)
		portrait.frame.Position = UDim2.fromOffset(6, 30)
		portrait.frame.Size = UDim2.new(1, -12, 0, 108)
		local placeholder = Icons.create(card, "Display", Theme.muted)
		placeholder.Position = UDim2.new(0.5, -22, 0, 60)
		placeholder.Size = UDim2.fromOffset(44, 44)
		local lock = Icons.create(card, "Lock", Theme.muted)
		lock.Position = placeholder.Position
		lock.Size = placeholder.Size
		local name = W.label(card, "", 38, 14)
		W.inset(name, 138, 38)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local action = W.action(card, "Choose", ctx.scope, ctx.effects, function()
			local snapshot = ctx.snapshot()
			if not snapshot then
				return
			end
			if slot > snapshot.unlocked then
				ctx.send("Expand", nil, nil, nil)
			elseif selected then
				ctx.send("Place", selected, slot, nil)
			else
				ctx.pick(slot)
			end
		end)
		W.inset(action.button, 180, 44)
		local remove = W.action(card, "Remove", ctx.scope, ctx.effects, function()
			ctx.send("Remove", nil, slot, nil)
		end, true)
		W.inset(remove.button, 230, 44)
		slots[slot] = {
			root = card,
			portrait = portrait,
			name = name,
			label = label,
			placeholder = placeholder,
			lock = lock,
			action = action,
			remove = remove,
		}
	end
	local home = W.action(page, "Return to my showroom", ctx.scope, ctx.effects, function()
		ctx.visit(0)
	end, true)
	home.button.LayoutOrder = 4
	local paletteTitle = W.title(page, "Make it yours", 40)
	paletteTitle.LayoutOrder = 5
	local palettes = W.tiles(page, ctx.scope, 150, 3, 202)
	palettes.LayoutOrder = 6
	local paletteActions: { [string]: W.Action } = {}
	local themeIds: { string } = {}
	for id in Catalog.themes do
		table.insert(themeIds, id)
	end
	table.sort(themeIds)
	for order, id in themeIds do
		local definition = Catalog.themes[id]
		local card = W.card(palettes, id, 202)
		card.LayoutOrder = order
		local room = W.frame(card, "PalettePreview", definition.wall)
		room.Position = UDim2.fromOffset(8, 8)
		room.Size = UDim2.new(1, -16, 0, 102)
		W.corner(room, 12)
		local floor = W.frame(room, "Floor", definition.floor)
		floor.Position = UDim2.fromScale(0, 0.7)
		floor.Size = UDim2.fromScale(1, 0.3)
		W.corner(floor, 10)
		local shelf = W.frame(room, "Shelf", definition.accent)
		shelf.Position = UDim2.fromScale(0.12, 0.55)
		shelf.Size = UDim2.fromScale(0.76, 0.07)
		for index = 1, 3 do
			local toy = W.frame(room, "Toy", Theme.card)
			toy.Position = UDim2.fromScale(0.16 + (index - 1) * 0.26, 0.28)
			toy.Size = UDim2.fromScale(0.16, 0.24)
			W.corner(toy, 10)
		end
		local name = W.label(card, definition.name, 34, 16)
		W.inset(name, 112, 34)
		local action = W.action(card, "", ctx.scope, ctx.effects, function()
			ctx.send("Theme", nil, nil, id)
		end, true)
		W.inset(action.button, 150, 44)
		paletteActions[id] = action
	end
	local function update(snapshot: Types.Snapshot)
		income.Text = string.format("%g Coins/sec", snapshot.rate)
		bonus.Text = if snapshot.bonus > 0
			then string.format("Set bonus active  ·  +%g/sec", snapshot.bonus)
			else string.format(
				"Set bonus +1/sec  ·  %d / 3 unique",
				State.bonusProgress(snapshot)
			)
		hint.Text = "Match one collection · Edit near your shelf"
		choice.button.Visible = selected ~= nil
		if selected then
			choice.set("Placing " .. Catalog.byId[selected].name .. "  ·  Cancel", true)
		end
		for slot, card in slots do
			local id = snapshot.slots[slot] or ""
			local locked = slot > snapshot.unlocked
			card.label.Text = if locked then "More display space" else "Slot " .. slot
			card.root.BackgroundColor3 = if locked then Theme.soft else Theme.card
			card.portrait.figure(if id == "" then nil else id, true)
			card.placeholder.Visible = id == "" and not locked
			card.lock.Visible = locked
			card.name.Text = if locked
				then State.number(snapshot.expansionCost) .. " Coins"
				elseif id ~= "" then Catalog.byId[id].name
				else "A spot for a little friend"
			if locked then
				card.action.set(
					"Unlock slot",
					ctx.canAct() and snapshot.coins >= snapshot.expansionCost
				)
			elseif selected then
				local _, free = State.copies(snapshot, selected)
				card.action.set(
					if selected == id then "Displayed here" else "Place here",
					ctx.canAct() and free > 0 and selected ~= id
				)
			else
				card.action.set(if id == "" then "Choose figure" else "Change", ctx.canAct())
			end
			card.remove.button.Visible = not locked and id ~= ""
			card.remove.set("Remove", ctx.canAct())
		end
		for id, action in paletteActions do
			local equipped, owned = snapshot.theme == id, snapshot.themes[id] == true
			action.set(
				if equipped
					then "Equipped"
					elseif owned then "Use palette"
					else State.number(snapshot.themeCost) .. " Coins",
				ctx.canAct() and not equipped and (owned or snapshot.coins >= snapshot.themeCost),
				equipped
			)
		end
	end
	ctx.scope.connect(choice.button.Activated, function()
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
	end)
	return {
		root = page,
		update = update,
		select = function(id: string?)
			selected = id
			local snapshot = ctx.snapshot()
			if snapshot then
				update(snapshot)
			end
		end,
	}
end
return Showroom
