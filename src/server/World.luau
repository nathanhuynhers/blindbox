--!strict
local Config = require(script.Parent.PlotConfig)
local Geometry = require(script.Parent.PlotGeometry)
local PlotFixture = require(script.Parent.PlotFixture)
local World = {}
function World.create(): Folder
	local root = Instance.new("Folder")
	root.Name = "MainWorld"
	local rows = math.ceil(Config.maxPlots / Config.columns)
	Geometry.part(
		root,
		"SharedGround",
		Vector3.new(
			Config.columns * (Config.width + Config.gap) + 40,
			1,
			rows * (Config.depth + Config.gap) + 40
		),
		Vector3.new(0, 0, 0),
		Color3.fromRGB(166, 174, 184)
	)
	for index = 1, Config.maxPlots do
		PlotFixture.createPlatform(root, Geometry.origin(index), index)
	end
	root.Parent = workspace
	return root
end
return World
