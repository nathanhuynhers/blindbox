--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)
local Shelves = {}
function Shelves.create(parent: Instance, ctx: Context.Context): Context.Screen
	local root = W.frame(parent, "Shelves", Theme.paper)
	W.corner(root, 16)
	local content = W.scroll(root, "ShelfEditor", ctx.scope)
	local title = W.title(content, "My Shelves", 38)
	title.LayoutOrder = 1
	local status = W.label(content, "", 62, 15)
	status.LayoutOrder = 2
	local navigation = W.tiles(content, ctx.scope, 140, 2, 44)
	navigation.LayoutOrder = 3
	local previous = W.action(navigation, "< Previous shelves", ctx.scope, ctx.effects, function()
		ctx.send("ShelfPrevious", nil, nil, nil)
	end, true)
	local nextShelves = W.action(navigation, "Next shelves >", ctx.scope, ctx.effects, function()
		ctx.send("ShelfNext", nil, nil, nil)
	end, true)
	previous.button.LayoutOrder = 1
	nextShelves.button.LayoutOrder = 2
	local selected = 1
	local selectedShelfId = ""
	local unitChoices = W.tiles(content, ctx.scope, 140, 3, 44)
	unitChoices.LayoutOrder = 4
	local unitActions: { W.Action } = {}
	local selection = W.label(content, "", 42, 15)
	selection.LayoutOrder = 5
	local slots = W.tiles(content, ctx.scope, 155, 3, 68)
	slots.LayoutOrder = 6
	local slotIds = Config.slots()
	local actions: { W.Action } = {}
	local update: (Types.Snapshot) -> () = function() end
	for position = 1, Config.visibleShelfUnits do
		local action = W.action(unitChoices, "", ctx.scope, ctx.effects, function()
			local snapshot = ctx.snapshot()
			local unit = if snapshot then snapshot.shelves.visible[position] else nil
			if snapshot and unit then
				selectedShelfId = unit.id
				update(snapshot)
			end
		end, true)
		action.button.LayoutOrder = position
		unitActions[position] = action
	end
	for index in slotIds do
		local action = W.action(slots, "", ctx.scope, ctx.effects, function()
			selected = index
			local snapshot = ctx.snapshot()
			if snapshot then
				update(snapshot)
			end
		end, true)
		action.button.LayoutOrder = index
		actions[index] = action
	end
	local remove = W.action(content, "Remove selected figure", ctx.scope, ctx.effects, function()
		ctx.send("ShelfRemove", nil, selected, selectedShelfId)
	end, true)
	remove.button.LayoutOrder = 7
	local heading = W.label(content, "Choose a discovered figure to place or replace", 38, 15)
	heading.LayoutOrder = 8
	local figures = W.tiles(content, ctx.scope, 155, 3, 48)
	figures.LayoutOrder = 9
	local picks: { [string]: W.Action } = {}
	for index, figure in Catalog.figures do
		local action = W.action(figures, figure.name, ctx.scope, ctx.effects, function()
			ctx.send("ShelfPlace", figure.id, selected, selectedShelfId)
		end, true)
		action.button.LayoutOrder = index
		picks[figure.id] = action
	end
	update = function(snapshot)
		local shelf = snapshot.shelves
		local selectedUnit = shelf.visible[1]
		local indices: { string } = {}
		for _, unit in shelf.visible do
			table.insert(indices, tostring(unit.index))
			if unit.id == selectedShelfId then
				selectedUnit = unit
			end
		end
		selectedShelfId = selectedUnit.id
		for position, action in unitActions do
			local unit = shelf.visible[position]
			action.set("Shelf " .. unit.index, ctx.canAct(), unit.id == selectedShelfId)
		end
		status.Text = string.format(
			"Viewing shelves %s of %d - cosmetic figures earn 0 Coins\nWalk to your shelves to edit. Everyone sees the same shelves.",
			table.concat(indices, ", "),
			shelf.ownedCount
		)
		selection.Text = "Selected shelf " .. selectedUnit.index .. " / " .. slotIds[selected]
		previous.set("< Previous shelves", ctx.canAct() and shelf.canNavigate)
		nextShelves.set("Next shelves >", ctx.canAct() and shelf.canNavigate)
		for index, action in actions do
			local slotId = slotIds[index]
			local id = selectedUnit.placements[slotId]
			local row, slot = Config.parseSlot(slotId)
			action.set(
				string.format(
					"Row %d / Slot %d\n%s",
					row or 0,
					slot or 0,
					if id then Catalog.byId[id].name else "Empty"
				),
				ctx.canAct(),
				selected == index
			)
		end
		remove.set(
			"Remove selected figure",
			ctx.canAct() and selectedUnit.placements[slotIds[selected]] ~= nil
		)
		for id, action in picks do
			action.button.Visible = snapshot.discovered[id] == true
			action.set(Catalog.byId[id].name, ctx.canAct() and snapshot.discovered[id] == true)
		end
	end
	return { root = root, update = update }
end
return Shelves
