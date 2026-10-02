--!strict
-- Picker drawer under the Display slots: owned figures not already displayed, best earners
-- first (top one tagged BEST). Filled slots offer Remove; Cancel closes the drawer.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Tile = require(script.Parent.FigureTile)
local Picker = {}

export type Callbacks = {
	pick: (string) -> (),
	remove: () -> (),
	cancel: () -> (),
	browse: () -> (),
}
export type Picker = {
	root: Frame,
	size: (width: number, height: number, phone: boolean) -> (),
	update: (Types.Snapshot, target: number?, placing: string?) -> (),
	first: () -> GuiObject?,
}

local function small(
	parent: Instance,
	name: string,
	text: string,
	ctx: Context.Context,
	callback: () -> ()
): Button.Button
	return Button.create(parent, name, {
		variant = "white",
		text = text,
		size = 14,
		radius = 12,
		drop = 0,
		outline = Style.outlineSmall,
		font = Style.body(Enum.FontWeight.ExtraBold),
	}, ctx.scope, ctx.effects, callback)
end

function Picker.create(parent: Instance, ctx: Context.Context, callbacks: Callbacks): Picker
	local root = Kit.frame(parent, "Picker", Style.surface2)
	Kit.corner(root, 18)
	Kit.stroke(root, Style.track, Style.outlineSmall)
	local title = Kit.text(root, "Title", "", 19, Style.display())
	local sort = Kit.text(root, "Sort", "Best earners first", 13, nil, Style.muted)
	sort.TextXAlignment = Enum.TextXAlignment.Right
	local browse = small(root, "Browse", "Browse Collection", ctx, callbacks.browse)
	local remove = small(root, "Remove", "Remove", ctx, callbacks.remove)
	local cancel = small(root, "Cancel", "Cancel", ctx, callbacks.cancel)
	local layout = Kit.grid(root, 10)
	local grid = Kit.scroll(root, "Choices", ctx.scope, layout, 2, ctx.scale)
	local empty = Kit.text(root, "Empty", "", 15, nil, Style.muted)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.TextWrapped = true
	local shop = Button.create(
		root,
		"VisitShop",
		{
			variant = "gold",
			text = "Visit the Shop",
			size = 17,
			radius = 14,
			drop = 3,
		},
		ctx.scope,
		ctx.effects,
		function()
			ctx.navigate("Shop")
		end
	)
	local tiles: { Tile.Tile } = {}
	local width, height, phone = 0, 0, false
	local cell = 120
	local function tile(index: number): Tile.Tile
		local existing = tiles[index]
		if existing then
			return existing
		end
		-- The pool grows to the largest list seen (bounded by the catalog) and is reused.
		local created = Tile.create(grid, ctx, "pick", callbacks.pick)
		created.button.LayoutOrder = index
		created.size(cell, if phone then 64 else 72)
		tiles[index] = created
		return created
	end
	local function arrange()
		local pad = 14
		local inner = width - pad * 2
		Kit.rect(title, pad, 6, inner - 348, 26)
		Kit.rect(sort, pad, 32, inner - 348, 16)
		sort.TextXAlignment = Enum.TextXAlignment.Left
		local x = pad + inner
		x -= 84
		Kit.rect(cancel.button, x, 4, 84, 44)
		x -= 94
		Kit.rect(remove.button, x, 4, 86, 44)
		x -= 158
		Kit.rect(browse.button, x, 4, 150, 44)
		Kit.rect(grid, pad - 2, 56, inner + 4, height - 60)
		local columns = if phone then 4 else 6
		cell = State.cells(inner - 14, columns, 10)
		local tileHeight = if phone then 64 else 72
		layout.CellSize = UDim2.fromOffset(cell, tileHeight)
		for _, item in tiles do
			item.size(cell, tileHeight)
		end
		Kit.rect(empty, pad, 60, inner, 40)
		shop.button.AnchorPoint = Vector2.new(0.5, 0)
		shop.button.Position = UDim2.new(0.5, 0, 0, 104)
		shop.button.Size = UDim2.fromOffset(200, 48)
	end
	return {
		root = root,
		size = function(nextWidth: number, nextHeight: number, nextPhone: boolean)
			width, height, phone = nextWidth, nextHeight, nextPhone
			arrange()
		end,
		update = function(snapshot: Types.Snapshot, target: number?, placing: string?)
			local picks = if target then State.picker(snapshot) else {}
			local filled = if target then snapshot.slots[target] or "" else ""
			sort.Visible = target ~= nil and #picks > 0
			browse.button.Visible = target ~= nil
			remove.button.Visible = target ~= nil and filled ~= ""
			cancel.button.Visible = target ~= nil or placing ~= nil
			grid.Visible = target ~= nil
			browse.set("Browse Collection", true)
			remove.set("Remove", ctx.canAct())
			cancel.set("Cancel", true)
			if placing then
				title.Text = "Placing "
					.. Catalog.byId[placing].name
					.. ": tap a slot to put it there"
			elseif target and filled ~= "" then
				title.Text = "Slot " .. target .. ": swap " .. Catalog.byId[filled].name .. " for"
			elseif target then
				title.Text = "Choose a figure for slot " .. target
			else
				title.Text = "Tap a slot to choose or change its figure"
			end
			empty.Visible = target ~= nil and #picks == 0
			shop.button.Visible = empty.Visible
			empty.Text = "No other figures to place yet. Open a box to find more."
			for index = 1, math.max(#picks, #tiles) do
				local pick = picks[index]
				if pick then
					tile(index).set(pick.id, {
						discovered = true,
						sub = State.rate(pick.rate),
						subColor = Style.mintText,
						best = index == 1,
						selected = index == 1,
						enabled = ctx.canAct(),
					})
				elseif tiles[index] then
					tiles[index].set(nil, { discovered = false })
				end
			end
		end,
		first = function()
			local first = tiles[1]
			return if first and first.button.Visible then first.button else nil
		end,
	}
end

return Picker
