--!strict
local World = {}
function World.create(): Folder
	local root = Instance.new("Folder")
	root.Name = "ShowroomGardens"
	local function part(name: string, position: Vector3, size: Vector3, color: Color3): Part
		local object = Instance.new("Part")
		object.Name = name
		object.Anchored = true
		object.Position = position
		object.Size = size
		object.Color = color
		object.Parent = root
		return object
	end
	part(
		"GardenGround",
		Vector3.new(0, 0.1, 45),
		Vector3.new(250, 0.2, 230),
		Color3.fromRGB(113, 153, 109)
	)
	for row = 0, 3 do
		part(
			"Promenade",
			Vector3.new(0, 0.35, row * 38 - 20),
			Vector3.new(228, 0.5, 10),
			Color3.fromRGB(207, 204, 185)
		)
	end
	for _, x in { -114, 114 } do
		part(
			"Walkway",
			Vector3.new(x, 0.35, 40),
			Vector3.new(8, 0.5, 145),
			Color3.fromRGB(207, 204, 185)
		)
		for z = -30, 130, 40 do
			part(
				"TreeTrunk",
				Vector3.new(x + (if x < 0 then -8 else 8), 3, z),
				Vector3.new(1.3, 6, 1.3),
				Color3.fromRGB(127, 92, 66)
			)
			local canopy = part(
				"TreeCanopy",
				Vector3.new(x + (if x < 0 then -8 else 8), 7, z),
				Vector3.new(7, 7, 7),
				Color3.fromRGB(78, 125, 91)
			)
			canopy.Shape = Enum.PartType.Ball
		end
	end
	part(
		"WelcomePlaza",
		Vector3.new(0, 0.5, -44),
		Vector3.new(72, 1, 30),
		Color3.fromRGB(224, 214, 186)
	)
	local fountain = part(
		"Fountain",
		Vector3.new(0, 1.4, -44),
		Vector3.new(10, 2, 10),
		Color3.fromRGB(122, 175, 179)
	)
	fountain.Shape = Enum.PartType.Cylinder
	fountain.Orientation = Vector3.new(0, 0, 90)
	fountain.Size = Vector3.new(2, 10, 10)
	local gem = part(
		"GroveHeart",
		Vector3.new(0, 4.5, -44),
		Vector3.new(3, 4, 3),
		Color3.fromRGB(251, 211, 128)
	)
	gem.Shape = Enum.PartType.Ball
	gem.Material = Enum.Material.Neon
	local sign = part(
		"WelcomeSign",
		Vector3.new(0, 5, -59),
		Vector3.new(30, 6, 0.6),
		Color3.fromRGB(37, 67, 64)
	)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.Parent = sign
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 232, 183)
	title.Text = "POCKET GROVE\nA little collection. A place of your own."
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = surface
	root.Parent = workspace
	return root
end
return World
