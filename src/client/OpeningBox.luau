--!strict
local ContentProvider = game:GetService("ContentProvider")
local Scope = require(script.Parent.OpeningScope)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoxModel = require(ReplicatedStorage.Shared.BlindBoxModel)
local Config = require(script.Parent.OpeningConfig)
local Skin = require(script.Parent.BlindBoxSkin)
local Source = require(script.Parent.OpeningBoxSource)
local Fallback = require(script.Parent.OpeningFallbackBox)
local Box = {}
export type Asset = { model: Model, production: boolean, pose: (CFrame, number, number?) -> () }
type PosePart = { part: BasePart, origin: CFrame, size: Vector3, lid: boolean }

local function build(parent: Instance, collection: string, forceFallback: string?): Asset
	local template, reason = Source.resolve(ReplicatedStorage:FindFirstChild("ProductionModels"))
	if forceFallback then
		template, reason = nil, forceFallback
	end
	if template then
		local clone = template:Clone()
		-- Own the clone before doing anything which may fail.
		clone.Parent = parent
		local ok, asset = pcall(function(): Asset
			local surfaces, issue = BoxModel.surfaces(clone)
			assert(surfaces, issue)
			Skin.apply(clone, surfaces, collection)
			local _, up, front = BoxModel.axes(surfaces)
			local origin = BoxModel.center(surfaces.BoxBody)
			local rootFrame = CFrame.lookAt(origin, origin + front, up)
			assert(rootFrame.X == rootFrame.X, "Degenerate production box axes")
			-- The semantic root defines our animation frame, independent of imported mesh pivots.
			clone.PrimaryPart = nil
			clone.WorldPivot = rootFrame
			clone:PivotTo(CFrame.new())
			local _, size = clone:GetBoundingBox()
			clone:ScaleTo(clone:GetScale() * Config.stage.boxHeight / size.Y)
			local resolved = BoxModel.surfaces(clone)
			assert(resolved, "Lost box semantics during normalization")
			local semanticRoot = clone:FindFirstChild("BlindBox_Root", true)
			local animationRoot = if semanticRoot and semanticRoot:IsA("Model")
				then semanticRoot
				else clone
			-- Some importers flatten the GLB root. The wrapper is the equivalent local root then.
			animationRoot.PrimaryPart = nil
			animationRoot.WorldPivot = CFrame.new()
			local lidSet: { [BasePart]: boolean } = {}
			-- Top panel/trim move with the cap even when imported as sibling semantic nodes.
			for _, name in { "LidCap", "TopPatternPanel", "TopFrameTrim", "TopBadgeMount" } do
				local lidParts: { BasePart } = resolved[name] or {}
				for _, part in lidParts do
					lidSet[part] = true
				end
			end
			local lidCenter = BoxModel.center(resolved.LidCap)
			local hinge = CFrame.new(
				lidCenter + Vector3.new(0, 0, size.Z * Config.stage.boxHeight / size.Y * 0.42)
			)
			local helper = Instance.new("Part")
			helper.Name = "LidAnimationPivot"
			helper.Size = Vector3.new(0.1, 0.1, 0.1)
			helper.Transparency = 1
			helper.CFrame = hinge
			helper.Anchored, helper.CanCollide, helper.CanTouch, helper.CanQuery =
				true, false, false, false
			helper.Parent = animationRoot
			local parts: { PosePart } = {}
			for _, child in clone:GetDescendants() do
				if child:IsA("BasePart") then
					child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery =
						true, false, false, false
					table.insert(parts, {
						part = child,
						origin = child.CFrame,
						size = child.Size,
						lid = lidSet[child] == true,
					})
				end
			end
			-- SurfaceGui works on the real stage, so the collection name follows the actual plate.
			local plate = resolved.CollectionNamePlate[1]
			local labelSurface = Instance.new("SurfaceGui")
			labelSurface.Name = "CollectionName"
			labelSurface.Face = BoxModel.face(plate, Vector3.new(0, 0, -1))
			labelSurface.CanvasSize = Vector2.new(640, 140)
			labelSurface.LightInfluence = 0
			labelSurface.Parent = plate
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Size = UDim2.fromScale(1, 1)
			text.Text = Config.collection(collection).name
			text.Font = Enum.Font.FredokaOne
			text.TextScaled = true
			text.TextColor3 = Config.neutral
			text.Parent = labelSurface
			clone.Name = if animationRoot == clone then "BlindBox_Root" else "ProductionBlindBox"
			clone:SetAttribute("OpeningSource", "Models.BlindBoxBase")
			return {
				model = clone,
				production = true,
				pose = function(at, opening, squeeze)
					local compression = squeeze or 0
					animationRoot:PivotTo(at)
					local lidMotion = CFrame.new(0, opening * opening * 5.5, opening * 2.1)
						* hinge
						* CFrame.Angles(-opening * 1.8, opening * 0.25, opening * 0.14)
						* hinge:Inverse()
					for _, entry in parts do
						local cf = entry.origin
						local compressed = CFrame.new(
							cf.Position * Vector3.new(1, 1 - compression, 1)
						) * cf.Rotation
						entry.part.Size = entry.size * Vector3.new(1, 1 - compression, 1)
						entry.part.CFrame = at
							* (if entry.lid then lidMotion else CFrame.new())
							* compressed
					end
				end,
			}
		end)
		if ok then
			return asset
		end
		reason = tostring(asset)
		clone:Destroy()
	end
	warn("Opening uses emergency procedural box: " .. reason)
	local fallback = Fallback.create(parent, collection)
	fallback.model:SetAttribute("OpeningSource", "EmergencyFallback")
	return {
		model = fallback.model,
		production = false,
		pose = function(at, opening, _compression)
			fallback.pose(at, opening * 4)
		end,
	}
end
-- Cinematics own asynchronous mesh preparation. The stable wrapper keeps pose/visibility intact
-- if replication completes before arrival or asset delivery fails and the emergency carton is needed.
function Box.create(
	parent: Instance,
	collection: string,
	scope: Scope.Scope?,
	allowUpgrade: (() -> boolean)?
): Asset
	if not scope then
		return build(parent, collection)
	end
	local wrapper = Instance.new("Model")
	wrapper.Name, wrapper.Parent = "OpeningPackage", parent
	-- Registered before construction; also owns every later fallback/decoration.
	scope.add(function()
		wrapper:Destroy()
	end)
	local current = build(wrapper, collection)
	wrapper:SetAttribute(
		"OpeningSource",
		if current.production then "Models.BlindBoxBase" else "EmergencyFallback"
	)
	local lastFrame, lastOpening, lastCompression = CFrame.new(), 0, 0
	local closed, generation = false, 0
	local failedProduction = false
	local loading: thread? = nil
	local timeout: thread? = nil
	local asset: Asset = {
		model = wrapper,
		production = current.production,
		pose = function(at, opening, compression)
			if closed then
				return
			end
			lastFrame, lastOpening, lastCompression = at, opening, compression or 0
			current.pose(at, opening, compression)
		end,
	}
	local function cancelThreads()
		for _, thread in { loading, timeout } do
			if thread and thread ~= coroutine.running() and coroutine.status(thread) ~= "dead" then
				task.cancel(thread)
			end
		end
		loading, timeout = nil, nil
	end
	scope.add(function()
		closed = true
		generation += 1
		cancelThreads()
	end)
	local function fallback(reason: string)
		if closed or not current.production then
			return
		end
		generation += 1
		failedProduction = true
		cancelThreads()
		local old = current
		current = build(wrapper, collection, reason)
		asset.production = false
		wrapper:SetAttribute("OpeningSource", "EmergencyFallback")
		current.pose(lastFrame, lastOpening, lastCompression)
		old.model:Destroy()
	end
	local function preload()
		if not current.production then
			return
		end
		generation += 1
		local token = generation
		cancelThreads()
		local meshes: { Instance } = {}
		for _, descendant in current.model:GetDescendants() do
			if descendant:IsA("MeshPart") then
				table.insert(meshes, descendant)
			end
		end
		timeout = task.delay(5, function()
			if not closed and token == generation then
				fallback("Mesh delivery timed out for Models.BlindBoxBase")
			end
		end)
		loading = task.defer(function()
			if closed or token ~= generation then
				return
			end
			local failed = false
			local ok = pcall(function()
				ContentProvider:PreloadAsync(meshes, function(_, status)
					if status ~= Enum.AssetFetchStatus.Success then
						failed = true
					end
				end)
			end)
			if closed or token ~= generation then
				return
			end
			if timeout and coroutine.status(timeout) ~= "dead" then
				task.cancel(timeout)
			end
			timeout = nil
			if not ok or failed then
				fallback(
					"Mesh delivery failed for Models.BlindBoxBase; check asset access in Output"
				)
			end
		end)
	end
	preload()
	local arrived = ReplicatedStorage.DescendantAdded:Connect(function()
		if
			closed
			or failedProduction
			or current.production
			or not allowUpgrade
			or not allowUpgrade()
		then
			return
		end
		local template = Source.resolve(ReplicatedStorage:FindFirstChild("ProductionModels"))
		if not template then
			return
		end
		local nextAsset = build(wrapper, collection)
		if not nextAsset.production then
			nextAsset.model:Destroy()
			return
		end
		current.model:Destroy()
		current = nextAsset
		asset.production = true
		wrapper:SetAttribute("OpeningSource", "Models.BlindBoxBase")
		current.pose(lastFrame, lastOpening, lastCompression)
		preload()
	end)
	scope.add(function()
		arrived:Disconnect()
	end)
	return asset
end
return Box
