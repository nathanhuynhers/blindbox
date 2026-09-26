--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Box = require(ReplicatedStorage.Shared.BlindBoxModel)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Skin = require(script.Parent.BlindBoxSkin)
local Scope = require(script.Parent.UIScope)
local W = require(script.Parent.Widgets)
local Preview = {}
export type Preview = { root: Frame, set: (string) -> () }

function Preview.create(parent: Instance, scope: Scope.Scope): Preview
	local root = W.frame(parent, "BlindBoxPreview")
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ProductViewport"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(195, 189, 179)
	viewport.LightColor = Color3.fromRGB(255, 246, 229)
	viewport.Visible = false
	viewport.Parent = root
	local world = Instance.new("WorldModel")
	world.Name = "Scene"
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local fallback = W.frame(root, "Fallback")
	local fallbackLabel = W.label(fallback, "Loading product...", 48, 15)
	fallbackLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	fallbackLabel.Position = UDim2.fromScale(0.5, 0.5)
	fallbackLabel.Size = UDim2.new(1, -32, 0, 48)
	fallbackLabel.TextXAlignment = Enum.TextXAlignment.Center
	fallbackLabel.TextColor3 = Color3.fromRGB(121, 102, 87)
	-- SurfaceGui is not a viewport branding surface. Project live text onto the name plate
	-- for this fixed product shot, avoiding per-collection name textures or mesh changes.
	local title = W.label(root, "", 28, 18)
	title.Name = "ProjectedCollectionName"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(255, 249, 238)
	title.TextScaled = true
	title.Visible = false
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize = 8, 22
	limit.Parent = title
	local model: Model? = nil
	local surfaces: Box.Surfaces? = nil
	local selected = ""
	local destroyed = false
	local generation = 0
	local loading: thread? = nil
	local deadline: thread? = nil

	local function state(status: string, detail: string?)
		root:SetAttribute("PreviewStatus", status)
		root:SetAttribute("PreviewReason", detail or "")
		viewport.Visible = status == "Ready"
		fallback.Visible = not viewport.Visible
		title.Visible = viewport.Visible
		fallbackLabel.Text = if status == "Loading"
			then "Loading product..."
			else "Product preview unavailable"
	end

	local function fit()
		local current, bound = model, surfaces
		if not current or not bound then
			return
		end
		local right, up, front = Box.axes(bound)
		local bounds, size = current:GetBoundingBox()
		local target = bounds.Position
		local direction = (front * 1.6 + right * 0.95 + up * 0.8).Unit
		local view = CFrame.lookAt(target, target - direction, up)
		local aspect =
			math.max(0.15, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
		local tangent = math.tan(math.rad(camera.FieldOfView / 2))
		local distance = 0
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local point = view:PointToObjectSpace(
						bounds:PointToWorldSpace(size * Vector3.new(x, y, z))
					)
					distance = math.max(
						distance,
						point.Z + math.abs(point.X) / (tangent * aspect),
						point.Z + math.abs(point.Y) / tangent
					)
				end
			end
		end
		-- Preserve bounds fitting and camera angle while increasing visual scale by 6.9%.
		camera.CFrame = CFrame.lookAt(target + direction * distance * 1.02, target, up)
		camera.Focus = CFrame.new(target)
		viewport.LightDirection = -(front * 1.4 - right * 0.6 + up * 1.8).Unit
		local plate = bound.CollectionNamePlate[1]
		local function project(point: Vector3): Vector2
			local p = camera.CFrame:PointToObjectSpace(point)
			return Vector2.new(
				(0.5 + p.X / (-p.Z * tangent * aspect * 2)) * viewport.AbsoluteSize.X,
				(0.5 - p.Y / (-p.Z * tangent * 2)) * viewport.AbsoluteSize.Y
			)
		end
		local function extent(axis: Vector3): number
			local a = plate.CFrame:VectorToObjectSpace(axis)
			return math.abs(a.X) * plate.Size.X
				+ math.abs(a.Y) * plate.Size.Y
				+ math.abs(a.Z) * plate.Size.Z
		end
		local width, height = extent(right) * 0.84, extent(up) * 0.68
		local origin = plate.Position + front * extent(front) * 0.52
		local center = project(origin)
		local edge = project(origin + right * width / 2) - project(origin - right * width / 2)
		local vertical = project(origin + up * height / 2) - project(origin - up * height / 2)
		title.Position = UDim2.fromOffset(center.X, center.Y)
		title.Size = UDim2.fromOffset(edge.Magnitude, vertical.Magnitude)
		local angle = math.deg(math.atan2(edge.Y, edge.X))
		title.Rotation = if angle > 90
			then angle - 180
			elseif angle < -90 then angle + 180
			else angle
	end

	local function theme()
		local current, bound = model, surfaces
		if not current or not bound or selected == "" then
			return
		end
		generation += 1
		local token = generation
		if loading and coroutine.status(loading) ~= "dead" then
			task.cancel(loading)
		end
		if deadline and coroutine.status(deadline) ~= "dead" then
			task.cancel(deadline)
		end
		local assets = Skin.apply(current, bound, selected)
		for _, child in current:GetDescendants() do
			if child:IsA("MeshPart") then
				table.insert(assets, child)
			end
		end
		for _, collection in Catalog.collections do
			if collection.id == selected then
				title.Text = collection.name
			end
		end
		state("Loading")
		fit()
		deadline = task.delay(30, function()
			if destroyed or token ~= generation then
				return
			end
			generation += 1
			if loading and coroutine.status(loading) ~= "dead" then
				task.cancel(loading)
			end
			state("Failed", "Timed out loading product mesh or artwork; check Studio Output")
		end)
		loading = task.defer(function()
			local failed = false
			local ok = pcall(function()
				ContentProvider:PreloadAsync(assets, function(_, status)
					if status ~= Enum.AssetFetchStatus.Success then
						failed = true
					end
				end)
			end)
			if destroyed or token ~= generation then
				return
			end
			if deadline and coroutine.status(deadline) ~= "dead" then
				task.cancel(deadline)
			end
			state(
				if ok and not failed then "Ready" else "Failed",
				if ok and not failed
					then ""
					else "Mesh or artwork failed to load; check Studio Output and asset access"
			)
		end)
	end

	local function inspectFolder(folder: Instance)
		if destroyed or model then
			return
		end
		local template = folder:FindFirstChild("BlindBoxBase")
		if not template or not template:IsA("Model") then
			state(
				if folder:GetAttribute("BlindBoxBaseStatus") == "Loading"
					then "Loading"
					else "Unavailable",
				tostring(folder:GetAttribute("BlindBoxBaseReason") or "Model template is not ready")
			)
			return
		end
		-- A replicated Model may arrive before its parts; descendants/status events retry it.
		local expected = template:GetAttribute("ExpectedPartCount")
		local count = 0
		for _, child in template:GetDescendants() do
			if child:IsA("BasePart") then
				count += 1
			end
		end
		if typeof(expected) ~= "number" or count < expected then
			state("Loading", "Waiting for replicated model geometry")
			return
		end
		local bound, reason = Box.surfaces(template)
		if not bound then
			state("Loading", reason)
			return
		end
		local clone = template:Clone()
		clone.Name = "ProductModel"
		local resolved, cloneReason = Box.surfaces(clone)
		if not resolved then
			clone:Destroy()
			state("Invalid", cloneReason)
			return
		end
		model, surfaces = clone, resolved
		clone.Parent = world
		theme()
	end
	local watched: Instance? = nil
	local function watch(folder: Instance)
		if watched == folder then
			return
		end
		watched = folder
		scope.connect(folder.DescendantAdded, function()
			inspectFolder(folder)
		end)
		scope.connect(folder:GetAttributeChangedSignal("BlindBoxBaseStatus"), function()
			inspectFolder(folder)
		end)
		inspectFolder(folder)
	end
	scope.connect(ReplicatedStorage.ChildAdded, function(value: unknown)
		if typeof(value) == "Instance" and value.Name == "ProductionModels" then
			watch(value)
		end
	end)
	local folder = ReplicatedStorage:FindFirstChild("ProductionModels")
	state("Loading")
	if folder then
		watch(folder)
	end
	-- Replication may deliver attributes after DescendantAdded; retry only during startup.
	local awaiting = task.defer(function()
		for _ = 1, 30 do
			if destroyed or model then
				return
			end
			local currentFolder = ReplicatedStorage:FindFirstChild("ProductionModels")
			if currentFolder then
				watch(currentFolder)
				inspectFolder(currentFolder)
			end
			task.wait(1)
		end
		if not model and root:GetAttribute("PreviewStatus") == "Loading" then
			state("Failed", "Timed out waiting for complete replicated production geometry")
		end
	end)
	scope.connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), fit)
	scope.add(function()
		destroyed = true
		if coroutine.status(awaiting) ~= "dead" then
			task.cancel(awaiting)
		end
		generation += 1
		if loading and coroutine.status(loading) ~= "dead" then
			task.cancel(loading)
		end
		if deadline and coroutine.status(deadline) ~= "dead" then
			task.cancel(deadline)
		end
		root:Destroy()
	end)
	return {
		root = root,
		set = function(id: string)
			if id == selected then
				return
			end
			selected = id
			root:SetAttribute("CollectionId", id)
			theme()
		end,
	}
end
return Preview
