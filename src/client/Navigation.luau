--!strict
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)
local Icons = require(script.Parent.UIIcons)
local Navigation = {}
Navigation.pages = { "Collection", "Display", "Shop", "Goals", "Visits" }
local labels = {
	Collection = "Collection",
	Display = "Room",
	Shop = "Shop",
	Goals = "Goals",
	Visits = "Social",
}
function Navigation.create(parent: Instance, ctx: Context.Context, choose: (string) -> ())
	local root = W.frame(parent, "Navigation")
	root.ZIndex = 6
	local desktop = true
	local active: string? = nil
	local actions: { [string]: W.Action } = {}
	local icons: { [string]: Frame } = {}
	local captions: { [string]: TextLabel } = {}
	local hovered: { [string]: boolean } = {}
	local function paint()
		for id, action in actions do
			local selected = id == active
			local expanded = selected or hovered[id] == true
			action.set("", true, selected)
			action.button.Size = if desktop
				then UDim2.fromOffset(if expanded then 126 else 52, 52)
				else UDim2.new(0.2, -6, 1, 0)
			local icon = icons[id]
			icon.Position = if desktop then UDim2.fromOffset(14, 14) else UDim2.new(0.5, -12, 0, 5)
			local caption = captions[id]
			caption.Visible = not desktop or expanded
			caption.Position = if desktop then UDim2.fromOffset(46, 0) else UDim2.new(0, 0, 1, -20)
			caption.Size = if desktop then UDim2.new(1, -48, 1, 0) else UDim2.new(1, 0, 0, 18)
			caption.TextSize = if desktop then 12 else 10
			caption.TextXAlignment = if desktop
				then Enum.TextXAlignment.Left
				else Enum.TextXAlignment.Center
			caption.TextColor3 = if selected then Theme.card else Theme.ink
			for _, object in icon:GetChildren() do
				if object:IsA("Frame") then
					object.BackgroundColor3 = if selected then Theme.card else Theme.ink
				end
			end
		end
	end
	for _, id in Navigation.pages do
		local action = W.action(root, "", ctx.scope, ctx.effects, function()
			choose(id)
		end, true)
		action.button.Name = "Nav" .. id
		actions[id] = action
		icons[id] = Icons.create(action.button, id, Theme.ink)
		captions[id] = W.label(action.button, labels[id], 20, 12)
		local function enter()
			hovered[id] = true
			paint()
		end
		local function leave()
			hovered[id] = false
			paint()
		end
		ctx.scope.connect(action.button.MouseEnter, enter)
		ctx.scope.connect(action.button.MouseLeave, leave)
		ctx.scope.connect(action.button.SelectionGained, enter)
		ctx.scope.connect(action.button.SelectionLost, leave)
	end
	local dot = W.frame(actions.Goals.button, "DailyReady", Theme.gold)
	dot.Size = UDim2.fromOffset(8, 8)
	dot.Position = UDim2.fromOffset(36, 7)
	W.corner(dot, 5)
	return {
		root = root,
		actions = actions,
		layout = function(size: Vector2, rail: boolean)
			desktop = rail
			root.AnchorPoint = if desktop then Vector2.new(0, 0.5) else Vector2.new(0.5, 1)
			root.Position = if desktop then UDim2.new(0, 12, 0.5, 12) else UDim2.new(0.5, 0, 1, -10)
			root.Size = if desktop
				then UDim2.fromOffset(128, 308)
				else UDim2.fromOffset(math.min(390, size.X - 20), 54)
			for index, id in Navigation.pages do
				actions[id].button.Position = if desktop
					then UDim2.fromOffset(0, (index - 1) * 62)
					else UDim2.new((index - 1) / 5, 3, 0, 0)
			end
			paint()
		end,
		set = function(page: string?, daily: boolean)
			active = page
			dot.Visible = daily
			paint()
		end,
	}
end
return Navigation
