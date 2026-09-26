--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local W = require(script.Parent.Widgets)
local Style = require(script.Parent.CollectionStyle)
local Assets = require(script.Parent.CollectionAssets)
local Art = require(script.Parent.CollectionArt)
local Controls = require(script.Parent.CollectionControls)
local Preview = require(script.Parent.UIPreview)
local Card = {}
export type Card = { root: TextButton, update: (Types.Snapshot, boolean?) -> () }
function Card.create(parent: Instance, id: string, ctx: Context.Context, thumbnail: boolean?): Card
	local definition = Catalog.byId[id]
	local style = Style.get(definition.collection)
	local assets = Assets.get(definition.collection)
	local action = W.action(parent, "", ctx.scope, ctx.effects, function()
		ctx.inspect(id)
	end, true)
	local root = action.button
	root.Name = id
	root:SetAttribute("Quiet", true)
	local slot = Assets.mount(root, "PortraitMount", ctx.scope)
	local paper = W.frame(slot.native, "MountPaper", style.page)
	W.corner(paper, 10)
	W.gradient(paper, Color3.new(1, 1, 1), Color3.fromRGB(227, 214, 194), 90)
	W.outline(paper, style.trim, 0.35)
	local well = W.frame(slot.native, "PortraitWell", style.wash)
	well.Position = UDim2.fromOffset(6, 6)
	well.Size = UDim2.new(1, -12, 1, if thumbnail then -12 else -56)
	W.corner(well, 8)
	W.gradient(well, style.page, style.wash, 60)
	W.outline(well, style.cover, 0.8)
	local preview = Preview.create(root, ctx.scope, true)
	preview.frame.Position = UDim2.fromOffset(7, 7)
	preview.frame.Size = UDim2.new(1, -14, 1, if thumbnail then -14 else -58)
	local question = W.label(root, "?", 44, if thumbnail then 22 else 38)
	question.AnchorPoint = Vector2.new(0.5, 0.5)
	question.Position = UDim2.fromScale(0.5, if thumbnail then 0.5 else 0.4)
	question.Size = UDim2.fromOffset(44, 44)
	question.TextXAlignment = Enum.TextXAlignment.Center
	question.Font = Enum.Font.FredokaOne
	question.TextColor3 = style.page
	question.TextStrokeColor3 = style.cover
	question.TextStrokeTransparency = 0.5
	local name = W.label(root, "", 24, 13)
	name.Position = UDim2.new(0, 3, 1, -49)
	name.Size = UDim2.new(1, -6, 0, 24)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextColor3 = style.ink
	name.Font = Enum.Font.FredokaOne
	local badge = Controls.badge(root, ctx)
	badge.root.AnchorPoint = Vector2.new(0.5, 1)
	badge.root.Position = UDim2.new(0.5, 0, 1, -4)
	badge.root.Size = UDim2.new(1, -14, 0, 19)
	badge.set(definition.rarity)
	if not thumbnail then
		local ornament = Art.emblem(slot.native, definition.collection)
		ornament.Size = UDim2.fromOffset(24, 24)
		ornament.Position = UDim2.fromOffset(0, 0)
	end
	local highlight = W.frame(root, "SelectionGlow")
	highlight.BackgroundColor3 = style.accent
	highlight.BackgroundTransparency = 0.92
	W.corner(highlight, 11)
	local border = W.outline(highlight, style.accent, 0.08)
	border.Thickness = 2
	local glow = W.outline(highlight, style.trim, 0.55)
	glow.Thickness = 4
	highlight.Visible = false
	return {
		root = root,
		update = function(snapshot: Types.Snapshot, selected: boolean?)
			local discovered = snapshot.discovered[id] == true
			preview.figure(id, discovered)
			question.Visible = not discovered
			name.Visible = not thumbnail and discovered
			name.Text = if discovered then definition.name else ""
			badge.root.Visible = not thumbnail and discovered
			highlight.Visible = selected == true
			local image = if not discovered
				then assets.cardLocked
				elseif selected then assets.cardSelected
				else assets.card
			slot.set(if image.id ~= "" then image else assets.card)
			root:SetAttribute("Discovered", discovered)
			root:SetAttribute("Owned", snapshot.owned[id] or 0)
			root:SetAttribute("Selected", selected == true)
		end,
	}
end
return Card
