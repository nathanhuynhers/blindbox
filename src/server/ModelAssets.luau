--!strict
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Manifest = require(ReplicatedStorage.Shared.AssetManifest)
local Box = require(ReplicatedStorage.Shared.BlindBoxModel)

local ModelAssets = {}

local function sanitize(root: Model)
	for _, descendant in root:GetDescendants() do
		if
			descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

function ModelAssets.publish(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ProductionModels"
	folder:SetAttribute("BlindBoxBaseStatus", "Missing")
	folder.Parent = ReplicatedStorage
	local reference = Manifest.resolve(Manifest.Models.BlindBoxBase)
	local rawId = string.match(reference, "^rbxassetid://([1-9]%d*)$")
	local assetId = if rawId then tonumber(rawId) else nil
	if not assetId then
		folder:SetAttribute("BlindBoxBaseReason", "Models.BlindBoxBase has no mapped ID")
		return folder
	end
	folder:SetAttribute("BlindBoxBaseStatus", "Loading")
	task.spawn(function()
		local ok, result = pcall(function(): Model
			return InsertService:LoadAsset(assetId :: number)
		end)
		if not ok then
			if not folder.Parent then
				return
			end
			folder:SetAttribute("BlindBoxBaseReason", tostring(result))
			folder:SetAttribute("BlindBoxBaseStatus", "Failed")
			warn("Blind-box model load failed: " .. tostring(result))
			return
		end
		local loaded = result :: Model
		if not folder.Parent then
			loaded:Destroy()
			return
		end
		local surfaces, reason = Box.surfaces(loaded)
		if not surfaces then
			loaded:Destroy()
			folder:SetAttribute("BlindBoxBaseReason", reason)
			folder:SetAttribute("BlindBoxBaseStatus", "Invalid")
			warn("Blind-box model validation failed: " .. reason)
			return
		end
		sanitize(loaded)
		loaded.Name = "BlindBoxBase"
		loaded:SetAttribute("AssetId", assetId)
		local partCount = 0
		for _, child in loaded:GetDescendants() do
			if child:IsA("BasePart") then
				partCount += 1
			end
		end
		loaded:SetAttribute("ExpectedPartCount", partCount)
		loaded.Parent = folder
		folder:SetAttribute("BlindBoxBaseReason", "")
		folder:SetAttribute("BlindBoxBaseStatus", "Ready")
	end)
	return folder
end

return ModelAssets
