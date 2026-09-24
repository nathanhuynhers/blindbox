--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local FigureModel = require(Shared.FigureModel)
local Types = require(Shared.Types)
local Catalog = require(Shared.Catalog)
export type Room = {
	model: Model,
	shelf: Vector3,
	spawn: CFrame,
	anchors: { CFrame },
	displays: Folder,
	index: number,
	signature: string,
}
local Rooms = {}
local occupied: { [number]: boolean } = {}
local root = Instance.new("Folder")
root.Name = "Showrooms"
root.Parent = workspace
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.Position = position
	result.Anchored = true
	result.Color = color
	result.Parent = parent
	return result
end
function Rooms.create(player: Player): Room
	local index = 1
	while occupied[index] do
		index += 1
	end
	occupied[index] = true
	local origin = Vector3.new(((index - 1) % 6) * 38 - 95, 0, math.floor((index - 1) / 6) * 38)
	local model = Instance.new("Model")
	model.Name = tostring(player.UserId)
	model:SetAttribute("OwnerId", player.UserId)
	part(
		model,
		"Floor",
		Vector3.new(30, 1, 28),
		origin + Vector3.new(0, 0.5, 0),
		Color3.fromRGB(225, 223, 212)
	)
	part(
		model,
		"BackWall",
		Vector3.new(30, 12, 1),
		origin + Vector3.new(0, 6, 13.5),
		Color3.fromRGB(83, 121, 116)
	)
	part(
		model,
		"LeftWall",
		Vector3.new(1, 12, 28),
		origin + Vector3.new(-15, 6, 0),
		Color3.fromRGB(105, 144, 137)
	)
	part(
		model,
		"RightWall",
		Vector3.new(1, 12, 28),
		origin + Vector3.new(15, 6, 0),
		Color3.fromRGB(105, 144, 137)
	)
	local shelf = origin + Vector3.new(0, 3, 8)
	part(model, "Shelf", Vector3.new(26, 1, 5), shelf, Color3.fromRGB(146, 102, 72))
	local sign = part(
		model,
		"Sign",
		Vector3.new(22, 3, 0.3),
		origin + Vector3.new(0, 9, 12.8),
		Color3.fromRGB(38, 62, 65)
	)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.Parent = sign
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 235, 201)
	light.Brightness = 1.5
	light.Range = 30
	light.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 235, 191)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = player.DisplayName .. "'s Pocket Grove"
	label.Parent = surface
	part(
		model,
		"Rug",
		Vector3.new(19, 0.06, 12),
		origin + Vector3.new(0, 1.04, -1),
		Color3.fromRGB(186, 169, 136)
	)
	for _, x in { -13, 13 } do
		part(
			model,
			"Column",
			Vector3.new(0.7, 10, 0.7),
			origin + Vector3.new(x, 6, -12),
			Color3.fromRGB(245, 216, 161)
		)
		part(
			model,
			"Planter",
			Vector3.new(2, 1.5, 2),
			origin + Vector3.new(x, 1.75, 9),
			Color3.fromRGB(167, 113, 79)
		)
		local plant = part(
			model,
			"Plant",
			Vector3.new(2.7, 3, 2.7),
			origin + Vector3.new(x, 3.5, 9),
			Color3.fromRGB(110, 166, 110)
		)
		plant.Shape = Enum.PartType.Ball
	end
	part(
		model,
		"Cornice",
		Vector3.new(30, 0.5, 28),
		origin + Vector3.new(0, 12.1, 0),
		Color3.fromRGB(230, 219, 197)
	).Transparency =
		0.35
	local anchors: { CFrame } = {}
	for slot = 1, 4 do
		local position = shelf + Vector3.new((slot - 2.5) * 6, 0.7, 0)
		part(
			model,
			"Slot" .. slot,
			Vector3.new(4, 0.4, 3.5),
			position,
			Color3.fromRGB(250, 229, 188)
		)
		anchors[slot] = CFrame.new(position + Vector3.new(0, 0.2, 0))
	end
	local displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = model
	local spawn = CFrame.lookAt(origin + Vector3.new(0, 4, -3), shelf)
	model:SetAttribute("VisitorOrigin", origin)
	model.Parent = root
	return {
		model = model,
		shelf = shelf,
		spawn = spawn,
		anchors = anchors,
		displays = displays,
		index = index,
		signature = "",
	}
end
function Rooms.render(room: Room, state: Types.State)
	local completed: { string } = {}
	for _, collection in Catalog.collections do
		local complete = true
		for _, figure in Catalog.figures do
			if figure.collection == collection.id and not state.discovered[figure.id] then
				complete = false
			end
		end
		if complete then
			table.insert(completed, collection.name)
		end
	end
	local signature = table.concat(state.slots, "|")
		.. state.theme
		.. tostring(state.unlocked)
		.. table.concat(completed, "|")
	if signature == room.signature then
		return
	end
	room.signature = signature
	local palette = Catalog.themes[state.theme]
	for _, child in room.model:GetChildren() do
		if child:IsA("BasePart") then
			if string.find(child.Name, "Wall") then
				child.Color = palette.wall
			elseif child.Name == "Floor" then
				child.Color = palette.floor
			elseif
				child.Name == "Rug"
				or child.Name == "Column"
				or string.find(child.Name, "Slot")
			then
				child.Color = palette.accent
			end
		end
	end
	room.displays:ClearAllChildren()
	if state.unlocked < 4 then
		local locked = part(
			room.displays,
			"LockedSlot",
			Vector3.new(3, 1.3, 2),
			room.anchors[4].Position + Vector3.new(0, 0.7, 0),
			Color3.fromRGB(90, 94, 98)
		)
		local sign = Instance.new("BillboardGui")
		sign.Size = UDim2.fromOffset(140, 38)
		sign.StudsOffset = Vector3.new(0, 1.2, 0)
		sign.MaxDistance = 35
		sign.Parent = locked
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Text = "Expand in the Shop"
		text.TextSize = 14
		text.Parent = sign
	end
	for index, title in completed do
		local plaque = part(
			room.displays,
			"CompletionPlaque",
			Vector3.new(8, 1.3, 0.2),
			room.shelf + Vector3.new((index - 1.5) * 10, 3.7, 4.8),
			Color3.fromRGB(217, 170, 79)
		)
		local surface = Instance.new("SurfaceGui")
		surface.Parent = plaque
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = title .. " - COMPLETE"
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.Parent = surface
	end
	for slot, id in state.slots do
		if id ~= "" then
			local ok, model = pcall(FigureModel.create, id, room.anchors[slot])
			if ok then
				model:SetAttribute("FigureId", id)
				model.Parent = room.displays
			else
				warn(
					"Figure rendering failed; retaining inventory and showing a placeholder",
					id,
					model
				)
				local fallback = part(
					room.displays,
					"FigurePlaceholder",
					Vector3.new(2, 2, 2),
					room.anchors[slot].Position + Vector3.new(0, 1, 0),
					Color3.fromRGB(220, 180, 100)
				)
				fallback.CanCollide = false
				fallback:SetAttribute("FigureId", id)
			end
		end
	end
end
function Rooms.near(room: Room, player: Player): boolean
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return rootPart ~= nil
		and rootPart:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and (rootPart.Position - room.shelf).Magnitude <= 20
end
function Rooms.destroy(room: Room)
	occupied[room.index] = nil
	room.model:Destroy()
end
return Rooms
