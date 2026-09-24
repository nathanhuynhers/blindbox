--!strict
local Catalog = require(script.Parent.Catalog)
local FigureModel = {}
function FigureModel.create(id: string, at: CFrame): Model
	local definition = Catalog.byId[id]
	local model = Instance.new("Model")
	model.Name = definition.name
	local function ball(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Size = size
		part.Color = color
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CFrame = at * CFrame.new(offset)
		part.Parent = model
		return part
	end
	model.PrimaryPart =
		ball("Body", Vector3.new(1.8, 1.8, 1.5), Vector3.new(0, 1, 0), definition.color)
	for _, x in { -0.34, 0.34 } do
		ball(
			"Eye",
			Vector3.new(0.18, 0.23, 0.12),
			Vector3.new(x, 1.15, -0.72),
			Color3.fromRGB(32, 38, 48)
		)
	end
	ball(
		"Smile",
		Vector3.new(0.32, 0.09, 0.12),
		Vector3.new(0, 0.84, -0.75),
		Color3.fromRGB(80, 57, 57)
	)
	for _, x in { -0.6, 0.6 } do
		ball(
			"Cheek",
			Vector3.new(0.23, 0.12, 0.1),
			Vector3.new(x, 0.96, -0.63),
			Color3.fromRGB(246, 175, 174)
		)
	end
	local shape = definition.shape
	if shape == "coral" then
		for x = -1, 1 do
			ball(
				"CoralTip",
				Vector3.new(0.5, 1.2 - math.abs(x) * 0.3, 0.5),
				Vector3.new(x * 0.6, 2, 0),
				definition.color
			)
		end
	elseif shape == "shell" then
		for x = -2, 2 do
			ball(
				"ShellRidge",
				Vector3.new(0.35, 1.5, 0.5),
				Vector3.new(x * 0.36, 1.7 - math.abs(x) * 0.12, 0.3),
				Color3.fromRGB(182, 153, 218)
			)
		end
	elseif shape == "jelly" then
		ball(
			"JellyDome",
			Vector3.new(2.4, 1.2, 1.9),
			Vector3.new(0, 1.8, 0),
			Color3.fromRGB(174, 211, 255)
		)
		for x = -1, 1 do
			ball(
				"Tentacle",
				Vector3.new(0.25, 0.8, 0.3),
				Vector3.new(x * 0.5, 0.2, 0),
				definition.color
			)
		end
	elseif shape == "pearl" then
		for x = -2, 2 do
			ball(
				"PearlCrown",
				Vector3.new(0.3, 0.6, 0.3),
				Vector3.new(x * 0.3, 2 - math.abs(x) * 0.1, 0),
				Color3.fromRGB(244, 190, 76)
			)
		end
		ball(
			"Pearl",
			Vector3.new(0.6, 0.6, 0.6),
			Vector3.new(0, 2.4, 0),
			Color3.fromRGB(230, 251, 255)
		)
	elseif shape == "sprout" then
		for _, x in { -0.35, 0.35 } do
			ball(
				"Leaf",
				Vector3.new(0.85, 0.3, 0.5),
				Vector3.new(x, 2, 0),
				Color3.fromRGB(57, 128, 85)
			)
		end
	elseif shape == "acorn" or shape == "mushroom" then
		ball(
			"Cap",
			Vector3.new(if shape == "mushroom" then 2.6 else 2, 0.85, 1.9),
			Vector3.new(0, 1.8, 0),
			if shape == "mushroom"
				then Color3.fromRGB(183, 70, 112)
				else Color3.fromRGB(125, 86, 60)
		)
	elseif shape == "wings" then
		for _, x in { -1, 1 } do
			ball(
				"Wing",
				Vector3.new(1.2, 1.9, 0.4),
				Vector3.new(x, 1.1, 0.3),
				Color3.fromRGB(214, 201, 255)
			)
		end
	elseif shape == "crown" then
		for x = -1, 1 do
			ball(
				"SunRay",
				Vector3.new(0.4, 1, 0.5),
				Vector3.new(x * 0.55, 2, 0),
				Color3.fromRGB(255, 170, 60)
			)
		end
	end
	return model
end
return FigureModel
