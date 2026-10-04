--!strict
-- Open 10 results: every figure from the batch at once, after the last reveal or Skip.
-- Presentation only; the snapshot that arrived with the reply already holds the figures.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local Tile = require(script.Parent.FigureTile)
local Scope = require(script.Parent.UIScope)
local Context = require(script.Parent.UIContext)
local Summary = {}
export type Item = { figureId: string, isNew: boolean }
export type Summary = {
	show: ({ Item }) -> (),
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
		show = function(items)
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
				if #items == 10 then "Open 10 results" else string.format("Your %d figures", #items),
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
				local card = math.min(
					150,
					(math.min(width, 900) - pad * 2 - gap * (columns - 1)) / columns,
					((height - top - bottom - gap * (rows - 1)) / rows) / 1.3
				)
				local gridWidth = card * columns + gap * (columns - 1)
				local gridHeight = card * 1.3 * rows + gap * (rows - 1)
				local y = math.max(top, (height - gridHeight - bottom + top) / 2)
				Kit.rect(title, pad, y - 52, width - pad * 2, 40)
				for index, tile in tiles do
					local column, line = (index - 1) % columns, (index - 1) // columns
					tile.size(card, card * 1.3)
					tile.button.Position = UDim2.fromOffset(
						(width - gridWidth) / 2 + column * (card + gap),
						y + line * (card * 1.3 + gap)
					)
				end
				Kit.rect(done.button, (width - 220) / 2, y + gridHeight + 20, 220, 56)
			end
			scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), layout)
			gui.Parent = playerGui
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
