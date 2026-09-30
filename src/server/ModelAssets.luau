--!strict
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Manifest = require(ReplicatedStorage.Shared.AssetManifest)
local Box = require(ReplicatedStorage.Shared.BlindBoxModel)
local FigureAssets = require(ReplicatedStorage.Shared.FigureAssets)

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

local function mappedId(key: string): number?
	local rawId = string.match(Manifest.resolve(key), "^rbxassetid://([1-9]%d*)$")
	return if rawId then tonumber(rawId) else nil
end

local function countParts(root: Instance): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

-- Normalize an imported figure: eyes toward -Z, uniform collection scale, pivot at the
-- centre of its base at the origin. Proportions are checked against the authored figure so a
-- partial import or a different up-axis fails visibly instead of rendering sideways.
local function prepareFigure(loaded: Model, entry: FigureAssets.Entry): string?
	local count = countParts(loaded)
	if count ~= entry.parts then
		return `expected {entry.parts} parts, found {count}`
	end
	local face = loaded:FindFirstChild(entry.face, true)
	if not face or not face:IsA("BasePart") then
		return "missing " .. entry.face
	end
	local bounds = loaded:GetBoundingBox()
	local look = face.Position - bounds.Position
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 1e-3 then
		return "cannot determine facing"
	end
	loaded.WorldPivot = CFrame.lookAt(bounds.Position, bounds.Position + look.Unit)
	loaded:PivotTo(CFrame.new(bounds.Position))
	local _, size = loaded:GetBoundingBox()
	local expected = entry.size
	for axis, pair in { X = { size.X, expected.X }, Z = { size.Z, expected.Z } } do
		local got, want = pair[1] / size.Y, pair[2] / expected.Y
		if not (math.abs(got - want) <= want * 0.2) then
			return `proportions differ on {axis}: {got} vs {want}`
		end
	end
	loaded:ScaleTo(loaded:GetScale() * expected.Y * FigureAssets.scale / size.Y)
	local scaledBounds, scaledSize = loaded:GetBoundingBox()
	loaded.WorldPivot = CFrame.new(scaledBounds.Position - Vector3.new(0, scaledSize.Y / 2, 0))
	loaded:PivotTo(CFrame.new())
	for _, name in entry.glass do
		local part = loaded:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			part.Transparency = FigureAssets.glassTransparency
			part.CastShadow = false
		end
	end
	return nil
end

-- Figure templates live in ProductionModels.Figures, one Model per catalog ID. FigureModel
-- clones a template once its replicated part count matches; until then it builds the
-- procedural placeholder. FigureRevision increments whenever a template becomes ready.
local function publishFigures(folder: Folder)
	local figures = Instance.new("Folder")
	figures.Name = "Figures"
	figures.Parent = folder
	folder:SetAttribute("FigureRevision", 0)
	for id, entry in FigureAssets.byId do
		local statusName = entry.root .. "Status"
		local assetId = mappedId(entry.key)
		if not assetId then
			figures:SetAttribute(statusName, "Missing")
			continue
		end
		figures:SetAttribute(statusName, "Loading")
		task.spawn(function()
			local ok, result = pcall(function(): Model
				return InsertService:LoadAsset(assetId :: number)
			end)
			if not figures.Parent then
				if ok then
					(result :: Model):Destroy()
				end
				return
			end
			if not ok then
				figures:SetAttribute(entry.root .. "Reason", tostring(result))
				figures:SetAttribute(statusName, "Failed")
				warn("Figure model load failed", id, result)
				return
			end
			local loaded = result :: Model
			local reason = prepareFigure(loaded, entry)
			if reason then
				loaded:Destroy()
				figures:SetAttribute(entry.root .. "Reason", reason)
				figures:SetAttribute(statusName, "Invalid")
				warn("Figure model validation failed", id, reason)
				return
			end
			sanitize(loaded)
			loaded.Name = id
			loaded:SetAttribute("AssetId", assetId)
			loaded:SetAttribute("ExpectedPartCount", entry.parts)
			loaded.Parent = figures
			figures:SetAttribute(statusName, "Ready")
			folder:SetAttribute(
				"FigureRevision",
				(folder:GetAttribute("FigureRevision") :: number) + 1
			)
		end)
	end
end

function ModelAssets.publish(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ProductionModels"
	folder:SetAttribute("BlindBoxBaseStatus", "Missing")
	folder.Parent = ReplicatedStorage
	publishFigures(folder)
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
