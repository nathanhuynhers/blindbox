--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local State = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Icons = require(script.Parent.UIIcons)
local Preview = require(script.Parent.UIPreview)
local Display = {}
function Display.create(parent: Instance, ctx: Context.Context)
	local root = W.frame(parent, "Display", Theme.paper)
	root.BackgroundTransparency = 0.08
	W.corner(root, 16)
	W.outline(root, Theme.card, 0.2)
	local page = W.scroll(root, "ShelfControls", ctx.scope)
	page.Position = UDim2.fromOffset(0, 80)
	page.Size = UDim2.new(1, 0, 1, -80)
	local selected: string? = nil
	local summary = W.frame(root, "DisplaySummary")
	summary.Size = UDim2.new(1, 0, 0, 80)
	local income = W.title(summary, "", 34)
	W.inset(income, 8, 30)
	income.TextSize = 21
	local bonus = W.label(summary, "", 32, 15)
	W.inset(bonus, 40, 34)
	bonus.TextSize = 12

	local choice = W.action(page, "", ctx.scope, ctx.effects, function()
		selected = nil
	end, true)
	choice.button.LayoutOrder = 2
	choice.button.Visible = false
	local tiles = W.tiles(page, ctx.scope, 126, 3, 210)
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
	for slot = 1, 6 do
		local card = W.card(tiles, "Slot" .. slot, 210)
		card.LayoutOrder = slot
		local label = W.label(card, "Slot " .. slot, 26, 14)
		W.inset(label, 4, 26)
		local portrait = Preview.create(card, ctx.scope)
		portrait.frame.Position = UDim2.fromOffset(6, 20)
		portrait.frame.Size = UDim2.new(1, -12, 0, 68)
		local placeholder = Icons.create(card, "Display", Theme.muted)
		placeholder.Position = UDim2.new(0.5, -22, 0, 34)
		placeholder.Size = UDim2.fromOffset(44, 44)
		local lock = Icons.create(card, "Lock", Theme.muted)
		lock.Position = placeholder.Position
		lock.Size = placeholder.Size
		local name = W.label(card, "", 38, 14)
		W.inset(name, 88, 26)
		name.TextSize = 12
		name.TextXAlignment = Enum.TextXAlignment.Center
		local action = W.action(card, "Choose", ctx.scope, ctx.effects, function()
			local snapshot = ctx.snapshot()
			if not snapshot then
				return
			end
			if slot == 4 and slot > snapshot.unlocked then
				ctx.send("Expand", nil, nil, nil)
			elseif selected then
				ctx.send("Place", selected, slot, nil)
			else
				ctx.pick(slot)
			end
		end)
		W.inset(action.button, 118, 44)
		local remove = W.action(card, "Remove", ctx.scope, ctx.effects, function()
			ctx.send("Remove", nil, slot, nil)
		end, true)
		W.inset(remove.button, 164, 44)
		remove.button:SetAttribute("Quiet", true)
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
	local home = W.action(page, "Return to my plot", ctx.scope, ctx.effects, function()
		ctx.visit(0)
	end, true)
	home.button.LayoutOrder = 4
	local function update(snapshot: Types.Snapshot)
		income.Text = "My Display"
		bonus.Text = string.format(
			"%g Coins/sec\n%s",
			snapshot.rate,
			if snapshot.bonus > 0
				then string.format("Set bonus +%g/sec", snapshot.bonus)
				else string.format("Matching set %d/3 (+1/sec)", State.bonusProgress(snapshot))
		)
		choice.button.Visible = selected ~= nil
		if selected then
			choice.set("Placing " .. Catalog.byId[selected].name .. "  ·  Cancel", true)
		end
		for slot, card in slots do
			local id = snapshot.slots[slot] or ""
			local locked = slot > snapshot.unlocked
			card.label.Text = if locked then "Extra slot" else "Slot " .. slot
			card.root.BackgroundColor3 = if locked then Theme.soft else Theme.card
			card.portrait.figure(if id == "" then nil else id, true)
			card.placeholder.Visible = id == "" and not locked
			card.lock.Visible = locked
			card.name.Text = if locked
				then (if slot == 4
					then State.number(snapshot.expansionCost) .. " Coins"
					else "Unlock method TBD")
				elseif id ~= "" then Catalog.byId[id].name .. " - " .. tostring(
					snapshot.rates[id]
				) .. "/sec"
				else "Choose a figure"
			if locked then
				card.action.set(
					if slot == 4 then "Unlock slot" else "Locked",
					ctx.canAct() and slot == 4 and snapshot.coins >= snapshot.expansionCost
				)
			elseif selected then
				local _, free = State.copies(snapshot, selected)
				card.action.set(
					if selected == id then "Displayed here" else "Place here",
					ctx.canAct() and free > 0 and selected ~= id
				)
			else
				card.action.set(if id == "" then "Choose" else "Change", ctx.canAct())
			end
			card.remove.button.Visible = not locked and id ~= ""
			card.remove.set("Remove", ctx.canAct())
		end
	end
	ctx.scope.connect(choice.button.Activated, function()
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
	end)
	return {
		root = root,
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
return Display
