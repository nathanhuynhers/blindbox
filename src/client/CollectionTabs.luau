--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local State = require(script.Parent.UIState)
local Style = require(script.Parent.CollectionStyle)
local Assets = require(script.Parent.CollectionAssets)
local Art = require(script.Parent.CollectionArt)
local Scroll = require(script.Parent.Scroll)
local W = require(script.Parent.Widgets)
local Tabs = {}
function Tabs.create(parent: Instance, ctx: Context.Context, choose: (string) -> ())
	local root = Instance.new("ScrollingFrame")
	root.Name = "CollectionTabs"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ScrollBarThickness = 2
	root.ScrollBarImageColor3 = Color3.fromRGB(181, 157, 125)
	root.Parent = parent
	local list = W.list(root, 8)
	ctx.scope.add(Scroll.bind(root, list, 0))
	local tabs: {
		[string]: {
			action: W.Action,
			row: Frame,
			caption: TextLabel,
			progress: TextLabel,
			emblem: Frame,
			face: Frame,
		},
	} =
		{}
	local compact = false
	local active = Catalog.collections[1].id
	local function layout()
		for id, tab in tabs do
			local selected = id == active
			tab.row.Size = UDim2.new(1, 0, 0, if compact then 72 else 88)
			tab.action.button.Position = UDim2.fromOffset(if selected then 0 else 6, 0)
			tab.action.button.Size = UDim2.new(1, if selected then 0 else -6, 1, -3)
			tab.caption.Visible = not compact
			tab.emblem.Position = if compact
				then UDim2.new(0.5, -16, 0, 7)
				else UDim2.fromOffset(10, 10)
			tab.emblem.Size = UDim2.fromOffset(32, 32)
			tab.progress.Position = if compact
				then UDim2.fromOffset(0, 43)
				else UDim2.fromOffset(10, 58)
			tab.progress.Size = UDim2.new(1, if compact then -2 else -18, 0, 22)
			tab.progress.TextXAlignment = if compact
				then Enum.TextXAlignment.Center
				else Enum.TextXAlignment.Left
			tab.face.BackgroundTransparency = if selected then 0 else 0.1
			tab.action.set("", true, selected)
		end
	end
	for order, definition in Catalog.collections do
		local style = Style.get(definition.id)
		local row = W.frame(root, "Index" .. definition.id)
		row.LayoutOrder = order
		local action = W.action(row, "", ctx.scope, ctx.effects, function()
			choose(definition.id)
		end, true)
		action.button.Name = "Tab" .. definition.id
		action.button:SetAttribute("Quiet", true)
		local slot = Assets.mount(action.button, "IndexSkin", ctx.scope)
		local face = W.frame(slot.native, "PaperTab", style.page)
		W.corner(face, 9)
		W.gradient(face, Color3.new(1, 1, 1), style.wash, 80)
		W.outline(face, style.trim, 0.25).Thickness = 2
		slot.set(Assets.get(definition.id).tab)
		local emblem = Assets.mount(action.button, "EmblemSlot", ctx.scope)
		Art.emblem(emblem.native, definition.id)
		emblem.set(Assets.get(definition.id).emblem)
		local caption = W.label(action.button, definition.name, 44, 15)
		caption.Position = UDim2.fromOffset(46, 6)
		caption.Size = UDim2.new(1, -52, 0, 48)
		caption.Font = Enum.Font.FredokaOne
		caption.TextColor3 = style.ink
		local progress = W.label(action.button, "", 22, 13)
		progress.TextColor3 = style.ink
		tabs[definition.id] = {
			action = action,
			row = row,
			caption = caption,
			progress = progress,
			emblem = emblem.root,
			face = face,
		}
	end
	return {
		root = root,
		layout = function(narrow: boolean)
			compact = narrow
			layout()
		end,
		focus = function()
			W.focus(tabs[active].action.button)
		end,
		update = function(snapshot: Types.Snapshot, collection: string)
			active = collection
			for id, tab in tabs do
				local found, total = State.completion(snapshot, id)
				tab.progress.Text = string.format("%d / %d", found, total)
				tab.action.button:SetAttribute("Selected", collection == id)
			end
			layout()
		end,
	}
end
return Tabs
