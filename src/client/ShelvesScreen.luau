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
	local page = W.scroll(root, "ShelfEditor", ctx.scope)
	local title = W.title(page, "My Shelves", 38)
	title.LayoutOrder = 1
	local status = W.label(page, "", 62, 15)
	status.LayoutOrder = 2
	local navigation = W.tiles(page, ctx.scope, 140, 2, 44)
	navigation.LayoutOrder = 3
	local previous = W.action(navigation, "< Previous page", ctx.scope, ctx.effects, function()
		ctx.send("ShelfPrevious", nil, nil, nil)
	end, true)
	local nextPage = W.action(navigation, "Next page >", ctx.scope, ctx.effects, function()
		ctx.send("ShelfNext", nil, nil, nil)
	end, true)
	previous.button.LayoutOrder = 1
	nextPage.button.LayoutOrder = 2
	local selected = 1
	local selection = W.label(page, "", 42, 15)
	selection.LayoutOrder = 4
	local slots = W.tiles(page, ctx.scope, 155, 3, 68)
	slots.LayoutOrder = 5
	local slotIds = Config.slots()
	local actions: { W.Action } = {}
	local update: (Types.Snapshot) -> () = function() end
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
	local remove = W.action(page, "Remove selected figure", ctx.scope, ctx.effects, function()
		ctx.send("ShelfRemove", nil, selected, nil)
	end, true)
	remove.button.LayoutOrder = 6
	local heading = W.label(page, "Choose a discovered figure to place or replace", 38, 15)
	heading.LayoutOrder = 7
	local figures = W.tiles(page, ctx.scope, 155, 3, 48)
	figures.LayoutOrder = 8
	local picks: { [string]: W.Action } = {}
	for index, figure in Catalog.figures do
		local action = W.action(figures, figure.name, ctx.scope, ctx.effects, function()
			ctx.send("ShelfPlace", figure.id, selected, nil)
		end, true)
		action.button.LayoutOrder = index
		picks[figure.id] = action
	end
	update = function(snapshot)
		local shelf = snapshot.shelves
		status.Text = string.format(
			"Page %d / %d - cosmetic figures earn 0 Coins\nWalk to your shelves to edit. Everyone sees the same page.",
			shelf.pageIndex,
			shelf.pageCount
		)
		selection.Text = "Selected: " .. slotIds[selected]
		previous.set("< Previous page", ctx.canAct() and shelf.pageCount > 1)
		nextPage.set("Next page >", ctx.canAct() and shelf.pageCount > 1)
		for index, action in actions do
			local slotId = slotIds[index]
			local id = shelf.placements[slotId]
			local unit, row, slot = Config.parseSlot(slotId)
			action.set(
				string.format(
					"Unit %d / Row %d / Slot %d\n%s",
					unit or 0,
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
			ctx.canAct() and shelf.placements[slotIds[selected]] ~= nil
		)
		for id, action in picks do
			action.button.Visible = snapshot.discovered[id] == true
			action.set(Catalog.byId[id].name, ctx.canAct() and snapshot.discovered[id] == true)
		end
	end
	return { root = root, update = update }
end
return Shelves
