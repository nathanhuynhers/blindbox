--!strict
-- Production figure models by catalog ID. Public data only: semantic asset keys and the
-- authored geometry each loaded model is validated against (see ModelAssets).
export type Entry = {
	key: string, -- AssetManifest semantic key resolved through AssetIds
	root: string, -- GLB root node name; parts are named <root>_<Part>
	face: string, -- part whose position marks the figure's front
	parts: number, -- MeshParts in the authored GLB
	size: Vector3, -- authored width, height, depth in studs (Roblox axes)
	glass: { string }?, -- parts presented as see-through
}

local FigureAssets = {}

-- One uniform presentation scale keeps the collection's relative sizes intact.
FigureAssets.scale = 0.8
FigureAssets.glassTransparency = 0.55

FigureAssets.byId = table.freeze({
	["tide.bubble"] = {
		key = "Models.TidepoolTales.BubbleBean",
		root = "BubbleBean",
		face = "BubbleBean_Eyes",
		parts = 10,
		size = Vector3.new(2.2324, 3.0856, 1.7409),
		glass = { "BubbleBean_BubbleCap" },
	},
	["tide.coral"] = {
		key = "Models.TidepoolTales.CoralCuddle",
		root = "CoralCuddle",
		face = "CoralCuddle_Eyes",
		parts = 11,
		size = Vector3.new(2.3644, 3.0269, 1.8726),
	},
	["tide.shell"] = {
		key = "Models.TidepoolTales.ShellScribe",
		root = "ShellScribe",
		face = "ShellScribe_Eyes",
		parts = 15,
		size = Vector3.new(2.2333, 2.9547, 1.9162),
	},
	["tide.jelly"] = {
		key = "Models.TidepoolTales.JellyJive",
		root = "JellyJive",
		face = "JellyJive_Eyes",
		parts = 8,
		size = Vector3.new(2.4824, 2.2207, 1.983),
	},
	["tide.ray"] = {
		key = "Models.TidepoolTales.RippleRay",
		root = "RippleRay",
		face = "RippleRay_Eyes",
		parts = 12,
		size = Vector3.new(3.8904, 1.977, 2.22),
	},
	["tide.pearl"] = {
		key = "Models.TidepoolTales.PearlRegent",
		root = "PearlRegent",
		face = "PearlRegent_Eyes",
		parts = 10,
		size = Vector3.new(3.2522, 3.3811, 2.3799),
	},
} :: { [string]: Entry })

return table.freeze(FigureAssets)
