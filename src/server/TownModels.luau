--!strict
-- Loads the uploaded town models (sakura, green trees, Peeka statues) as server-only templates.
-- A missing ID or failed load leaves the native-part placeholders in place; nothing else waits.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Manifest = require(ReplicatedStorage.Shared.AssetManifest)

export type Kind = {
	key: string,
	parts: number,
	-- Parts that collide and can be clicked/raycast; every other part is decoration.
	solid: { string } | "all",
	-- Part whose offset from the centre gives the model's front (statues); trees face anywhere.
	face: string?,
	-- Fraction of the model's height buried in the grass, so a rounded base sits flush.
	sink: number?,
}

local TownModels = {}

local kinds: { [string]: Kind } = {
	Sakura = {
		key = Manifest.Town.Sakura,
		parts = 9,
		solid = { "Sakura_Trunk", "Sakura_RootMound" },
		sink = 0.04,
	},
	Puffball = {
		key = Manifest.Town.Puffball,
		parts = 3,
		solid = { "Puffball_Trunk" },
		sink = 0.077,
	},
	Poplar = { key = Manifest.Town.Poplar, parts = 2, solid = { "Poplar_Trunk" }, sink = 0.051 },
	Topiary = { key = Manifest.Town.Topiary, parts = 4, solid = { "Topiary_Stem" }, sink = 0.031 },
	PeekaPeekaboo = {
		key = Manifest.Town.PeekaPeekaboo,
		parts = 17,
		solid = "all",
		face = "PeekaPeekaboo_Eyes",
	},
	PeekaTada = {
		key = Manifest.Town.PeekaTada,
		parts = 17,
		solid = "all",
		face = "PeekaTada_Eyes",
	},
	PeekaHug = { key = Manifest.Town.PeekaHug, parts = 18, solid = "all", face = "PeekaHug_Eyes" },
	PeekaNap = { key = Manifest.Town.PeekaNap, parts = 15, solid = "all", face = "PeekaNap_Eyes" },
}
TownModels.kinds = table.freeze(kinds)

local function assetId(key: string): number?
	local raw = string.match(Manifest.resolve(key), "^rbxassetid://([1-9]%d*)$")
	return if raw then tonumber(raw) else nil
end

local function isSolid(kind: Kind, name: string): boolean
	local solid = kind.solid
	if solid == "all" then
		return true
	end
	return table.find(solid :: { string }, name) ~= nil
end

-- Anchors and strips the import, then sets the pivot to the centre of the model's base (raised by
-- its sink),
-- turned so a statue's face points along the pivot's -Z.
function TownModels.prepare(loaded: Model, kind: Kind): string?
	local count = 0
	for _, descendant in loaded:GetDescendants() do
		if
			descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			count += 1
			local solid = isSolid(kind, descendant.Name)
			descendant.Anchored = true
			descendant.CanCollide = solid
			descendant.CanQuery = solid
			descendant.CanTouch = false
		end
	end
	if count ~= kind.parts then
		return `expected {kind.parts} parts, found {count}`
	end
	local bounds, size = loaded:GetBoundingBox()
	local facing = CFrame.new()
	if kind.face then
		local face = loaded:FindFirstChild(kind.face, true)
		if not face or not face:IsA("BasePart") then
			return "missing " .. kind.face
		end
		local look = face.Position - bounds.Position
		look = Vector3.new(look.X, 0, look.Z)
		if look.Magnitude < 1e-3 then
			return "cannot determine facing"
		end
		facing = CFrame.lookAt(Vector3.zero, look.Unit)
	end
	local base = bounds.Position - Vector3.new(0, size.Y * (0.5 - (kind.sink or 0)), 0)
	loaded.WorldPivot = CFrame.new(base) * facing
	loaded:PivotTo(CFrame.new())
	loaded:SetAttribute("NaturalWidth", math.max(size.X, size.Z))
	loaded:SetAttribute("NaturalHeight", size.Y)
	return nil
end

-- Calls `onReady(kindName, template)` once per model that loads and validates.
function TownModels.start(onReady: (string, Model) -> ()): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TownModels"
	folder.Parent = ServerStorage
	for name, kind in TownModels.kinds do
		local id = assetId(kind.key)
		if not id then
			folder:SetAttribute(name .. "Status", "Missing")
			continue
		end
		folder:SetAttribute(name .. "Status", "Loading")
		task.spawn(function()
			local ok, result = pcall(function(): Model
				return InsertService:LoadAsset(id :: number)
			end)
			if not folder.Parent then
				if ok then
					(result :: Model):Destroy()
				end
				return
			end
			if not ok then
				folder:SetAttribute(name .. "Status", "Failed")
				folder:SetAttribute(name .. "Reason", tostring(result))
				warn("Town model load failed", name, result)
				return
			end
			local loaded = result :: Model
			local reason = TownModels.prepare(loaded, kind)
			if reason then
				loaded:Destroy()
				folder:SetAttribute(name .. "Status", "Invalid")
				folder:SetAttribute(name .. "Reason", reason)
				warn("Town model validation failed", name, reason)
				return
			end
			loaded.Name = name
			loaded:SetAttribute("AssetId", id)
			loaded.Parent = folder
			folder:SetAttribute(name .. "Status", "Ready")
			onReady(name, loaded)
		end)
	end
	return folder
end

return TownModels
