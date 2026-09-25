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
return Art
