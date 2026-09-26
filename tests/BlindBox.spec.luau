--!strict
-- Structural importer fixtures; these do not simulate rendering or asset delivery.
local Box = require("./BlindBoxModel")
local Spec = require("./BlindBoxSpec")
local function node(name, class, children)
	local object = { Name = name, ClassName = class, children = children or {} }
	function object:IsA(kind)
		return self.ClassName == kind or (kind == "BasePart" and self.ClassName == "MeshPart")
	end
	function object:GetDescendants()
		local descendants = {}
		for _, child in self.children do
			table.insert(descendants, child)
			for _, descendant in child:GetDescendants() do
				table.insert(descendants, descendant)
			end
		end
		return descendants
	end
	function object:FindFirstChild(query, recursive)
		for _, child in (if recursive then self:GetDescendants() else self.children) do
			if child.Name == query then
				return child
			end
		end
		return nil
	end
	return object
end
local parts = {}
for _, name in Spec.required do
	table.insert(parts, node(name, "MeshPart"))
end
local model = node("ImporterWrapper", "Model", parts)
local flat = Box.surfaces(model)
assert(
	flat and #flat.FrontPatternPanel == 1,
	"Direct semantic MeshParts must bind without source root name"
)
local front = model:FindFirstChild("FrontPatternPanel", true)
front.ClassName = "Model"
front.children = { node("ImportedMesh", "MeshPart"), node("SecondMaterial", "MeshPart") }
local nested = Box.surfaces(model)
assert(
	nested and #nested.FrontPatternPanel == 2,
	"All geometry in a semantic wrapper must receive skin"
)
front.children = { node("NamedButEmpty", "Folder") }
local invalid, reason = Box.surfaces(model)
assert(
	not invalid and reason == "No geometry for FrontPatternPanel",
	"Empty semantic containers must fail with their exact reason"
)
front.Name = "UnrecognizedPanel"
local missing, missingReason = Box.surfaces(model)
assert(
	not missing and missingReason == "No geometry for FrontPatternPanel",
	"Missing semantics must fail rather than show unbranded geometry"
)
print("PASS: 4 semantic model binding fixtures (no Roblox rendering simulated)")
