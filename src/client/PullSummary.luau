--!strict
-- Open 10 results: every figure from the batch at once, after the last reveal or Skip, beside
-- the collection's discovery progress (found figures, grey silhouettes for the missing ones).
-- Presentation only; the snapshot that arrived with the reply already holds the figures.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local Tile = require(script.Parent.FigureTile)
local Scope = require(script.Parent.UIScope)
local Context = require(script.Parent.UIContext)
local State = require(script.Parent.UIState)
local Progress = require(script.Parent.UIProgress)
local Sfx = require(script.Parent.Sfx)
local Summary = {}
export type Item = { figureId: string, isNew: boolean }
export type Summary = {
	-- With a snapshot, the batch's collection progress shows beside the grid.
	show: ({ Item }, Types.Snapshot?, string?) -> (),
	isOpen: () -> boolean,
	destroy: () -> (),
}

function Summary.create(focus: (boolean) -> (), effects: () -> boolean): Summary
	local open: (() -> ())? = nil
	local function close()
		local finish = open
		open = nil
		if finish then
			finish()
		end
	end
	return {
		isOpen = function()
			return open ~= nil
		end,
		show = function(items, snapshot, heading)
			close()
			local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if not playerGui or #items == 0 then
				return
			end
			local scope = Scope.create()
			-- Tiles only use the scope; the summary never navigates or sends intents.
			local ctx: Context.Context = {
				scope = scope,
				effects = effects,
				scale = function()
					return 1
				end,
				snapshot = function()
					return nil
				end,
				canAct = function()
					return false
				end,
				send = function() end,
				navigate = function() end,
				close = close,
				message = function() end,
			}
			local gui = Instance.new("ScreenGui")
			gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "OpenTenResults", false, 100
			gui.ZIndexBehavior, gui.ScreenInsets =
				Enum.ZIndexBehavior.Sibling, Enum.ScreenInsets.DeviceSafeInsets
			local backdrop = Instance.new("TextButton")
			backdrop.Name, backdrop.Text, backdrop.AutoButtonColor = "Backdrop", "", false
			backdrop.BorderSizePixel, backdrop.Selectable, backdrop.Modal = 0, false, true
			backdrop.BackgroundColor3, backdrop.BackgroundTransparency = Style.revealGround, 0.08
			-- Cover the device insets too so the world never shows at the edges.
			backdrop.Position, backdrop.Size =
				UDim2.fromOffset(-100, -100), UDim2.new(1, 200, 1, 200)
			backdrop.Parent = gui
			local root = Kit.frame(gui, "Results")
			-- Multi-box Daily Login rewards reuse this grid with fewer figures.
			local title = Kit.text(
				root,
				"Title",
				heading
					or if #items == 10
						then "Open 10 results"
						else string.format("Your %d figures", #items),
				30,
				Style.display(),
				Style.white
			)
			title.TextXAlignment = Enum.TextXAlignment.Center
			local tiles: { Tile.Tile } = {}
			for index, item in items do
				local figure = Catalog.byId[item.figureId]
				local tile = Tile.create(root, ctx, "card", function() end)
				tile.button.LayoutOrder = index
				tile.set(item.figureId, {
					discovered = true,
					sub = if item.isNew then "NEW! · " .. figure.rarity else figure.rarity,
					subColor = if item.isNew then Style.violet else Style.muted,
				})
				tiles[index] = tile
			end
			-- Collection progress: what this batch completed and what is still out there.
			local collection = Catalog.byId[items[1].figureId].collection
			local members = State.members(collection)
			local panel = Kit.frame(root, "CollectionProgress", Style.revealChip)
			panel.Visible = snapshot ~= nil
			Kit.corner(panel, 18)
			local panelName = Kit.text(
				panel,
				"Collection",
				string.upper(State.collectionName(collection)),
				15,
				Style.body(Enum.FontWeight.ExtraBold),
				Style.revealText
			)
			local found, total = 0, #members
			if snapshot then
				found, total = State.completion(snapshot, collection)
			end
			local count = Kit.text(
				panel,
				"Discovered",
				string.format("%d / %d DISCOVERED", found, total),
				24,
				Style.display(),
				Style.white
			)
			local bar = Progress.bar(panel, "Bar", 10, Style.gold)
			bar.set(found, total)
			local left = total - found
			local nudge = Kit.text(
				panel,
				"Nudge",
				if left == 0
					then "Collection complete!"
					else string.format("%d more to find. Keep opening!", left),
				14,
				Style.body(Enum.FontWeight.Bold),
				Style.revealText
			)
			for _, label in { panelName, count, nudge } do
				label.TextXAlignment = Enum.TextXAlignment.Center
			end
			local discoveries: { Tile.Tile } = {}
			for index, id in members do
				local tile = Tile.create(panel, ctx, "tile", function() end)
				tile.button.LayoutOrder = index
				tile.set(id, {
					discovered = snapshot ~= nil and snapshot.discovered[id] == true,
					silhouette = true,
					enabled = false,
				})
				discoveries[index] = tile
			end
			local done = Button.create(root, "Done", {
				variant = "gold",
				text = "Done",
				size = 22,
				radius = 18,
				drop = 4,
			}, scope, effects, close)
			local function layout()
				local width, height = root.AbsoluteSize.X, root.AbsoluteSize.Y
				local columns = math.min(5, #tiles)
				local rows = math.ceil(#tiles / columns)
				local gap, pad, top, bottom = 12, 16, 64, 84
				-- The progress panel takes a right-hand column; the grid centres in the rest.
				local side = if panel.Visible then math.clamp(width * 0.27, 200, 300) else 0
				local area = width - (if panel.Visible then side + pad + gap else 0)
				local card = math.min(
					150,
					(math.min(area, 900) - pad * 2 - gap * (columns - 1)) / columns,
					((height - top - bottom - gap * (rows - 1)) / rows) / 1.3
				)
				local gridWidth = card * columns + gap * (columns - 1)
				local gridHeight = card * 1.3 * rows + gap * (rows - 1)
				local y = math.max(top, (height - gridHeight - bottom + top) / 2)
				-- Grid and panel centre together as one group.
				local group = gridWidth + (if panel.Visible then gap + side else 0)
				local x = math.max(pad, (width - group) / 2)
				Kit.rect(title, pad, y - 52, width - pad * 2, 40)
				for index, tile in tiles do
					local column, line = (index - 1) % columns, (index - 1) // columns
					tile.size(card, card * 1.3)
					tile.button.Position =
						UDim2.fromOffset(x + column * (card + gap), y + line * (card * 1.3 + gap))
				end
				Kit.rect(done.button, x + (gridWidth - 220) / 2, y + gridHeight + 20, 220, 56)
				if panel.Visible then
					local inner = side - 24
					local perRow = if #discoveries > 9 then 5 elseif #discoveries > 6 then 4 else 3
					local cellGap = 6
					local lines = math.ceil(#discoveries / perRow)
					-- Short (phone) screens tighten the header so the silhouettes stay legible.
					local short = height < 420
					local header = if short then 86 else 104
					local room = gridHeight - header - 12
					local cell = math.max(
						24,
						math.min(
							64,
							(inner - cellGap * (perRow - 1)) / perRow,
							(room - cellGap * (lines - 1)) / lines
						)
					)
					local panelHeight = header + lines * cell + (lines - 1) * cellGap + 12
					Kit.rect(panel, x + gridWidth + gap, y, side, panelHeight)
					Kit.rect(panelName, 12, if short then 6 else 10, inner, 20)
					Kit.rect(count, 12, if short then 24 else 30, inner, 30)
					count.TextSize = if short then 20 else 24
					Kit.rect(bar.root, 12, if short then 54 else 64, inner, 10)
					Kit.rect(nudge, 12, if short then 64 else 78, inner, 20)
					local rowWidth = perRow * cell + (perRow - 1) * cellGap
					for index, tile in discoveries do
						local column, line = (index - 1) % perRow, (index - 1) // perRow
						tile.size(cell, cell)
						tile.button.Position = UDim2.fromOffset(
							12 + (inner - rowWidth) / 2 + column * (cell + cellGap),
							header + line * (cell + cellGap)
						)
					end
				end
			end
			scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), layout)
			gui.Parent = playerGui
			Sfx.play("results")
			layout()
			focus(true)
			GuiService.SelectedObject = done.button
			open = function()
				if GuiService.SelectedObject == done.button then
					GuiService.SelectedObject = nil
				end
				scope.destroy()
				gui:Destroy()
				focus(false)
			end
		end,
		destroy = close,
	}
end

return Summary
