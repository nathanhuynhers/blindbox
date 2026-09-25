--!strict
local Scope = require(script.Parent.UIScope)
local Assets = require(script.Parent.CollectionAssets)
local Art = require(script.Parent.CollectionArt)
local Style = require(script.Parent.CollectionStyle)
local W = require(script.Parent.Widgets)
local Layout = require(script.Parent.CollectionLayout)
local Skin = {}
-- Pure decorative construction. Page content is a sibling and survives uploaded skin replacement.
function Skin.create(parent: Instance, scope: Scope.Scope)
	local root = W.frame(parent, "PhysicalBook")
	local slot = Assets.mount(root, "BookSkin", scope)
	local halves: { { root: Frame, cover: Frame, paper: Frame, shade: UIGradient, edges: { Frame } } } =
		{}
	for side = 1, 2 do
		local half = W.frame(slot.native, if side == 1 then "LeftVolume" else "RightVolume")
		half.Rotation = if side == 1 then 0.7 else -0.7
		for layer = 1, 3 do
			local shadow = W.frame(half, "SoftShadow", Color3.fromRGB(32, 25, 34))
			shadow.Position = UDim2.fromOffset(-layer * 2, 6 + layer * 3)
			shadow.Size = UDim2.new(1, layer * 4, 1, 0)
			shadow.BackgroundTransparency = 0.88
			W.corner(shadow, 20 + layer * 2)
		end
		local cover = W.frame(half, "Cover", Color3.new(1, 1, 1))
		cover.Position = UDim2.fromOffset(-6, 1)
		cover.Size = UDim2.new(1, 12, 1, 9)
		W.corner(cover, 18)
		W.outline(cover, Color3.fromRGB(227, 186, 138), 0.2).Thickness = 2
		local edges: { Frame } = {}
		for layer = 1, 5 do
			local edge = W.frame(half, "PageLayer" .. layer, Color3.new(1, 1, 1))
			edge.Position = UDim2.fromOffset(0, 12 - layer * 2)
			edge.Size = UDim2.new(1, 0, 1, -4)
			W.corner(edge, 14)
			W.outline(edge, Color3.fromRGB(177, 142, 106), 0.6)
			edges[layer] = edge
		end
		local paper = W.frame(half, "Paper", Color3.new(1, 1, 1))
		paper.Size = UDim2.new(1, 0, 1, -7)
		W.corner(paper, 14)
		local shade = W.gradient(paper, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0)
		local margin = W.frame(paper, "PrintedBorder")
		margin.Position = UDim2.fromOffset(9, 9)
		margin.Size = UDim2.new(1, -18, 1, -18)
		W.corner(margin, 12)
		W.outline(margin, Color3.fromRGB(198, 164, 117), 0.72)
		halves[side] = { root = half, cover = cover, paper = paper, shade = shade, edges = edges }
	end
	local crease = W.frame(slot.native, "DeepFold", Color3.new(1, 1, 1))
	crease.Position = UDim2.new(0.5, -20, 0, 9)
	crease.Size = UDim2.new(0, 40, 1, -24)
	local fold = W.gradient(crease, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0)
	local stitch = W.frame(crease, "Stitch", Color3.fromRGB(130, 97, 61))
	stitch.Position = UDim2.new(0.5, -1, 0, 0)
	stitch.Size = UDim2.new(0, 2, 1, 0)
	stitch.BackgroundTransparency = 0.55
	local ornaments = W.frame(slot.native, "BookOrnaments")
	local cornerSlots: { Assets.Slot } = {}
	for index = 1, 4 do
		local corner = Assets.mount(ornaments, "Corner" .. index, scope)
		corner.root.Size = UDim2.fromOffset(Layout.cornerSize, Layout.cornerSize)
		corner.root.AnchorPoint =
			Vector2.new(if index % 2 == 0 then 1 else 0, if index > 2 then 1 else 0)
		corner.root.Position = UDim2.new(
			if index % 2 == 0 then 1 else 0,
			0,
			if index > 2 then 1 else 0,
			if index > 2 then 5 else Layout.cornerTop
		)
		corner.root.Rotation = if index > 2 then 180 else 0
		cornerSlots[index] = corner
	end
	local collection = ""
	local spread = true
	local function paint()
		local style = Style.get(collection)
		local assets = Assets.get(collection)
		slot.set(if spread then assets.spread else assets.page)
		for side, half in halves do
			half.root.Visible = spread or side == 1
			half.root.Position = UDim2.new(if spread then (side - 1) * 0.5 else 0, 8, 0, 8)
			half.root.Size = UDim2.new(if spread then 0.5 else 1, -16, 1, -30)
			half.cover.BackgroundColor3 = style.cover
			for index, edge in half.edges do
				edge.BackgroundColor3 = style.page:Lerp(style.trim, (6 - index) * 0.09)
			end
			local edgeColor = style.page:Lerp(style.trim, 0.3)
			local inner = style.page:Lerp(style.cover, 0.14)
			half.shade.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, if side == 1 then edgeColor else inner),
				ColorSequenceKeypoint.new(0.14, style.page),
				ColorSequenceKeypoint.new(0.7, style.page),
				ColorSequenceKeypoint.new(1, if side == 1 then inner else edgeColor),
			})
		end
		crease.Visible = spread
		fold.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, style.page:Lerp(style.cover, 0.04)),
			ColorSequenceKeypoint.new(0.45, style.page:Lerp(style.cover, 0.4)),
			ColorSequenceKeypoint.new(0.5, style.cover:Lerp(style.page, 0.2)),
			ColorSequenceKeypoint.new(0.58, style.page:Lerp(style.cover, 0.15)),
			ColorSequenceKeypoint.new(1, style.page),
		})
		for _, corner in cornerSlots do
			corner.set(assets.corner)
		end
	end
	return {
		root = root,
		set = function(id: string, twoPages: boolean)
			if collection ~= id then
				collection = id
				for _, corner in cornerSlots do
					corner.native:ClearAllChildren()
					Art.corner(corner.native, id)
				end
			end
			spread = twoPages
			paint()
		end,
	}
end
return Skin
