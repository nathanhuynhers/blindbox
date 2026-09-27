--!strict
-- Functional controls only. The walkable Gallery and its portals provide navigation.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShowroomConfig)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)
local Showroom = {}
function Showroom.create(parent: Instance, ctx: Context.Context): Context.Screen
	local root = W.frame(parent, "GalleryControls", Theme.paper)
	local page = W.scroll(root, "GalleryContent", ctx.scope)
	local title = W.title(page, "Showroom Gallery", 38)
	title.LayoutOrder = 1
	local status = W.label(page, "", 64, 15)
	status.LayoutOrder = 2
	local exit = W.action(page, "Exit to my plot", ctx.scope, ctx.effects, function()
		ctx.visit(0)
	end, true)
	exit.button.LayoutOrder = 3
	local available = W.label(page, "", 96, 15)
	available.LayoutOrder = 4
	local selectedAnchor = 1
	local anchors = W.tiles(page, ctx.scope, 180, 3, 100)
	anchors.LayoutOrder = 5
	local anchorActions: { W.Action } = {}
	local update: (Types.Snapshot) -> () = function() end
	for index in Config.anchors do
		local action = W.action(anchors, "", ctx.scope, ctx.effects, function()
			selectedAnchor = index
			local snapshot = ctx.snapshot()
			if snapshot then
				update(snapshot)
			end
		end, true)
		action.button.LayoutOrder = index
		anchorActions[index] = action
	end
	local remove = W.action(page, "Remove from selected anchor", ctx.scope, ctx.effects, function()
		ctx.send("ShowroomRemove", nil, selectedAnchor, nil)
	end, true)
	remove.button.LayoutOrder = 6
	local choose = W.label(page, "Choose a discovered figure for the selected anchor", 40, 15)
	choose.LayoutOrder = 7
	local figures = W.tiles(page, ctx.scope, 160, 3, 50)
	figures.LayoutOrder = 8
	local figureActions: { [string]: W.Action } = {}
	for index, figure in Catalog.figures do
		local action = W.action(figures, figure.name, ctx.scope, ctx.effects, function()
			ctx.send("ShowroomPlace", figure.id, selectedAnchor, nil)
		end, true)
		action.button.LayoutOrder = index
		figureActions[figure.id] = action
	end
	local palettesTitle = W.label(page, "Owned Showroom palettes", 32, 15)
	palettesTitle.LayoutOrder = 9
	local palettes = W.tiles(page, ctx.scope, 160, 3, 50)
	palettes.LayoutOrder = 10
	local paletteActions: { [string]: W.Action } = {}
	for id, definition in Catalog.themes do
		paletteActions[id] = W.action(palettes, definition.name, ctx.scope, ctx.effects, function()
			ctx.send("ShowroomTheme", nil, nil, id)
		end, true)
	end
	update = function(snapshot)
		local gallery = snapshot.gallery
		root.Visible = gallery ~= nil
		if not gallery then
			return
		end
		local room = gallery.room
		local editable = gallery.canEdit and room ~= nil
		title.Text = gallery.ownerName .. "'s " .. (if room then "Showroom" else "Gallery")
		local roomName = "Custom Showroom"
		if room then
			for _, collection in Catalog.collections do
				if collection.id == room.sourceCollectionId then
					roomName = collection.name .. " Showroom"
				end
			end
		end
		status.Text = if room
			then roomName .. " · " .. (if editable
				then "Owner edit mode"
				else "Visitor · read-only") .. "\nCosmetic figures earn 0 Coins and reserve no copies."
			else "Walk to a room entrance and use its prompt. Close this panel to explore."
		local names: { string } = {}
		for _, item in gallery.rooms do
			table.insert(names, item.name)
		end
		available.Visible = room == nil
		available.Text = if #names == 0
			then "Complete a collection to unlock its Showroom."
			else "Rooms in this hall:\n" .. table.concat(names, "\n")
		anchors.Visible = room ~= nil
		for index, action in anchorActions do
			local id = if room then room.placements[Config.anchors[index]] else nil
			action.set(
				"Anchor " .. index .. "\n" .. (if id then Catalog.byId[id].name else "Empty"),
				editable and ctx.canAct(),
				index == selectedAnchor
			)
		end
		remove.button.Visible = editable
		remove.set(
			"Remove from selected anchor",
			editable
				and ctx.canAct()
				and room ~= nil
				and room.placements[Config.anchors[selectedAnchor]] ~= nil
		)
		choose.Visible = editable
		figures.Visible = editable
		palettesTitle.Visible = editable
		palettes.Visible = editable
		for id, action in figureActions do
			action.button.Visible = snapshot.discovered[id] == true
			action.set(
				Catalog.byId[id].name,
				editable and ctx.canAct() and snapshot.discovered[id] == true
			)
		end
		for id, action in paletteActions do
			action.button.Visible = snapshot.themes[id] == true
			action.set(
				Catalog.themes[id].name,
				editable
					and ctx.canAct()
					and snapshot.themes[id] == true
					and room ~= nil
					and room.theme ~= id,
				room ~= nil and room.theme == id
			)
		end
	end
	return { root = root, update = update }
end
return Showroom
