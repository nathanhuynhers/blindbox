--!strict
local Style = require(script.Parent.CollectionStyle)
local W = require(script.Parent.Widgets)
local Art = {}
-- Original native ornament, rendered only in collection-owned surfaces. Reused on theme changes.
function Art.create(parent: Instance)
	local root = W.frame(parent, "CollectionArt")
	root.ClipsDescendants = true
	local wash = W.frame(root, "Wash", Color3.new(1, 1, 1))
	local gradient = W.gradient(wash, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 55)
	W.corner(wash, 12)
	local motifs: { { [string]: Frame } } = {}
	for corner = 1, 2 do
		local ornament = W.frame(root, "Corner")
		ornament.Size = UDim2.fromOffset(90, 90)
		ornament.AnchorPoint =
			Vector2.new(if corner == 1 then 0 else 1, if corner == 1 then 0 else 1)
		ornament.Position =
			UDim2.fromScale(if corner == 1 then 0 else 1, if corner == 1 then 0 else 1)
		ornament.Rotation = if corner == 1 then 0 else 180
		local leaf = W.frame(ornament, "Leaves")
		for i = 1, 5 do
			local part = W.frame(leaf, "Leaf", Color3.new(1, 1, 1))
			part.Size = UDim2.fromOffset(15, 30)
			part.Position = UDim2.fromOffset(6 + i * 11, 2 + i * 5)
			part.Rotation = -40 + i * 12
			part.BackgroundTransparency = 0.63
			W.corner(part, 16)
		end
		local shell = W.frame(ornament, "Shell")
		for i = 1, 5 do
			local ray = W.frame(shell, "Fan", Color3.new(1, 1, 1))
			ray.Size = UDim2.fromOffset(9, 39)
			ray.AnchorPoint = Vector2.new(0.5, 1)
			ray.Position = UDim2.fromOffset(34, 46)
			ray.Rotation = (i - 3) * 25
			ray.BackgroundTransparency = 0.45
			W.corner(ray, 8)
		end
		for i = 1, 3 do
			local bubble = W.frame(shell, "Bubble")
			bubble.Size = UDim2.fromOffset(6 + i * 5, 6 + i * 5)
			bubble.Position = UDim2.fromOffset(50 + i * 5, 9 + i * 16)
			W.corner(bubble, 20)
			W.outline(bubble, Color3.new(1, 1, 1), 0.2)
		end
		local spark = W.frame(ornament, "Spark", Color3.new(1, 1, 1))
		spark.Size = UDim2.fromOffset(14, 14)
		spark.Position = UDim2.fromOffset(20, 20)
		spark.Rotation = 45
		motifs[corner] = { leaf = leaf, shell = shell, spark = spark }
	end
	return {
		root = root,
		set = function(id: string)
			local style = Style.get(id)
			gradient.Color = ColorSequence.new(style.page, style.wash)
			for _, group in motifs do
				for name, object in group do
					object.Visible = name == style.motif
					for _, part in object:GetChildren() do
						if part:IsA("Frame") then
							part.BackgroundColor3 = if name == "shell"
								then style.trim
								else style.accent
						end
					end
				end
			end
		end,
	}
end
-- Richer book ornaments are separate from create(), which is also used by the unchanged Shop.
function Art.emblem(parent: Instance, collection: string): Frame
	local style = Style.get(collection)
	local root = W.frame(parent, "Emblem")
	local function shape(
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		angle: number
	): Frame
		local part = W.frame(root, "Petal", color)
		part.Position = UDim2.fromScale(x, y)
		part.Size = UDim2.fromScale(w, h)
		part.Rotation = angle
		W.corner(part, 30)
		W.gradient(part, Color3.new(1, 1, 1), Color3.fromRGB(155, 168, 143), 100)
		return part
	end
	if style.motif == "leaf" then
		shape(0.47, 0.3, 0.06, 0.65, style.cover, 8)
		for side = -1, 1, 2 do
			local leaf =
				shape(if side < 0 then 0.08 else 0.49, 0.1, 0.36, 0.64, style.accent, side * 32)
			local vein = W.frame(leaf, "Vein", style.page)
			vein.Position = UDim2.fromScale(0.48, 0.12)
			vein.Size = UDim2.fromScale(0.035, 0.74)
			vein.BackgroundTransparency = 0.4
		end
	elseif style.motif == "shell" then
		for index = -2, 2 do
			local rib = shape(
				0.4 + index * 0.105,
				0.15 + math.abs(index) * 0.04,
				0.19,
				0.64,
				style.accent,
				index * 22
			)
			W.outline(rib, style.page, 0.35)
		end
		shape(0.32, 0.75, 0.4, 0.13, style.trim, 0)
	else
		local spark = shape(0.25, 0.25, 0.5, 0.5, style.accent, 45)
		spark.Name = "CollectionMark"
	end
	return root
end
function Art.corner(parent: Instance, collection: string): Frame
	local style = Style.get(collection)
	local root = W.frame(parent, "CornerFlourish")
	local function ellipse(
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		angle: number
	): Frame
		local part = W.frame(root, "Ornament", color)
		part.Position = UDim2.fromScale(x, y)
		part.Size = UDim2.fromScale(w, h)
		part.Rotation = angle
		W.corner(part, 100)
		return part
	end
	if style.motif == "leaf" then
		for index = 1, 7 do
			local t = index / 8
			local leaf = ellipse(
				0.05 + t * 0.63,
				0.53 - math.sin(t * math.pi) * 0.32,
				0.15,
				0.31,
				style.accent,
				-50 + t * 115
			)
			W.gradient(leaf, Color3.fromRGB(226, 239, 143), Color3.fromRGB(66, 107, 54), 35)
			local vein = W.frame(leaf, "Vein", style.page)
			vein.Position = UDim2.fromScale(0.48, 0.1)
			vein.Size = UDim2.fromScale(0.035, 0.8)
			vein.BackgroundTransparency = 0.55
		end
		for flower = 1, 2 do
			local cx, cy = if flower == 1 then 0.27 else 0.62, if flower == 1 then 0.56 else 0.46
			for petal = 1, 5 do
				local angle = petal * math.pi * 2 / 5
				ellipse(
					cx + math.cos(angle) * 0.07,
					cy + math.sin(angle) * 0.07,
					0.12,
					0.15,
					Color3.fromRGB(255, 247, 215),
					math.deg(angle)
				)
			end
			ellipse(cx + 0.025, cy + 0.035, 0.08, 0.08, style.trim, 0)
		end
	elseif style.motif == "shell" then
		for branch = 1, 5 do
			local stem = ellipse(
				0.12 + branch * 0.08,
				0.38 - branch * 0.045,
				0.07,
				0.44,
				style.trim,
				(branch - 3) * 22
			)
			W.gradient(stem, Color3.new(1, 1, 1), Color3.fromRGB(226, 128, 164), 90)
		end
		local shell = Art.emblem(root, collection)
		shell.Position = UDim2.fromScale(0.48, 0.4)
		shell.Size = UDim2.fromScale(0.38, 0.38)
		for index = 1, 5 do
			local size = 0.06 + (index % 3) * 0.035
			local bubble =
				ellipse(0.12 + index * 0.14, 0.15 + (index % 2) * 0.11, size, size, style.wash, 0)
			bubble.BackgroundTransparency = 0.35
			W.outline(bubble, Color3.new(1, 1, 1), 0.05)
		end
	else
		local emblem = Art.emblem(root, collection)
		emblem.Position = UDim2.fromScale(0.2, 0.2)
		emblem.Size = UDim2.fromScale(0.45, 0.45)
	end
	return root
end
return Art
