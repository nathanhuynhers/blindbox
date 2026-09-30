--!strict
local Box = require(game:GetService("ReplicatedStorage").Shared.BlindBoxModel)
local Source = {}
-- Shared by construction and importer regression fixtures. No loading, yields or mutation.
function Source.resolve(folder: Instance?): (Model?, string)
	if not folder then
		return nil, "ProductionModels has not replicated"
	end
	local candidate = folder:FindFirstChild("BlindBoxBase")
	if not candidate or not candidate:IsA("Model") then
		return nil,
			tostring(
				folder:GetAttribute("BlindBoxBaseReason")
					or folder:GetAttribute("BlindBoxBaseStatus")
					or "Missing template"
			)
	end
	local expected = candidate:GetAttribute("ExpectedPartCount")
	local count = 0
	for _, part in candidate:GetDescendants() do
		if part:IsA("BasePart") then
			count += 1
		end
	end
	if typeof(expected) ~= "number" or count < expected then
		return nil, "Incomplete replicated geometry"
	end
	local surfaces, reason = Box.surfaces(candidate)
	if not surfaces then
		return nil, reason
	end
	return candidate, ""
end
return Source
