--!strict
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)
local Icons = require(script.Parent.UIIcons)
local Navigation = {}
Navigation.pages = { "Collection", "Display", "Shop", "Goals", "Visits" }
local labels =
	{ Collection = "Book", Display = "Room", Shop = "Shop", Goals = "Goals", Visits = "Visits" }
function Navigation.create(parent: Instance, ctx: Context.Context, choose: (string) -> ())
	local root = Instance.new("ScrollingFrame")
	root.Name = "Navigation"
	root.BackgroundColor3 = Theme.card
	root.BorderSizePixel = 0
	root.ScrollBarThickness = 0
	root.CanvasSize = UDim2.fromOffset(0, 0)
	root.ScrollingDirection = Enum.ScrollingDirection.Y
	root.Parent = parent
	W.corner(root)
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -8)
	root.Size = UDim2.new(1, -16, 0, 64)
	local actions: { [string]: W.Action } = {}
	local icons: { [string]: Frame } = {}
	local labelsById: { [string]: TextLabel } = {}
	for index, id in Navigation.pages do
		local action = W.action(root, "", ctx.scope, ctx.effects, function()
			choose(id)
		end, true)
		action.button.Name = "Nav" .. id
		action.button.LayoutOrder = index
		local icon = Icons.create(action.button, id, Theme.ink)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 5)
		local label = W.label(action.button, labels[id], 20, 13)
		label.Position = UDim2.new(0, 0, 1, -23)
		label.TextXAlignment = Enum.TextXAlignment.Center
		actions[id], icons[id], labelsById[id] = action, icon, label
	end
	local dot = W.frame(actions.Goals.button, "DailyReady", Theme.gold)
	dot.Size = UDim2.fromOffset(10, 10)
	dot.Position = UDim2.new(0.5, 12, 0, 4)
	W.corner(dot, 5)
	return {
		root = root,
		actions = actions,
		layout = function(size: Vector2, rail: boolean)
			root.AnchorPoint = if rail then Vector2.zero else Vector2.new(0.5, 1)
			root.Position = if rail then UDim2.fromOffset(8, 8) else UDim2.new(0.5, 0, 1, -8)
			root.Size = if rail
				then UDim2.new(0, 64, 1, -16)
				else UDim2.fromOffset(math.min(540, size.X - 16), 64)
			for index, id in Navigation.pages do
				local button = actions[id].button
				button.Position = if rail
					then UDim2.fromOffset(4, (index - 1) * math.max(48, (size.Y - 16) / 5) + 2)
					else UDim2.new((index - 1) / 5, 4, 0, 4)
				button.Size = if rail
					then UDim2.new(1, -8, 0, math.max(48, (size.Y - 16) / 5) - 4)
					else UDim2.new(0.2, -8, 1, -8)
			end
			root.ScrollingEnabled = rail
			root.ScrollBarThickness = if rail and size.Y < 256 then 3 else 0
			root.CanvasSize = if rail
				then UDim2.fromOffset(0, math.max(240, size.Y - 16))
				else UDim2.fromOffset(0, 0)
			if not rail then
				root.CanvasPosition = Vector2.zero
			end
		end,
		set = function(page: string?, daily: boolean)
			for id, action in actions do
				local selected = id == page
				action.set("", true, selected)
				labelsById[id].TextColor3 = if selected then Theme.card else Theme.ink
				for _, object in icons[id]:GetChildren() do
					if object:IsA("Frame") then
						object.BackgroundColor3 = if selected then Theme.card else Theme.ink
					end
				end
			end
			dot.Visible = daily
		end,
	}
end
return Navigation
