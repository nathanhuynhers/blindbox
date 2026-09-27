--!strict
local Config = require(script.Parent.PlotConfig)
local Geometry = require(script.Parent.PlotGeometry)
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
		local pad = Geometry.part(
			root,
			"PlotSlot_" .. index,
			Vector3.new(Config.width, 0.5, Config.depth),
			Geometry.origin(index) - Vector3.new(0, 0.25, 0),
			Color3.fromRGB(221, 224, 228)
		)
		pad:SetAttribute("PlotSlot", index)
	end
	root.Parent = workspace
	return root
end
return World
