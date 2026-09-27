--!strict
-- Replaceable primitive presentation; access/ownership lives in GalleryRuntime.
local FigureModel = require(game:GetService("ReplicatedStorage").Shared.FigureModel)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShowroomConfig)
local Template = {}
export type Space = {
	model: Model,
	spawn: CFrame,
	origin: Vector3,
	figures: Folder,
	anchors: { [string]: CFrame },
	signature: string,
}
function Template.part(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Position = position
	part.Size = size
	part.Color = color
	part.Parent = parent
	return part
end
function Template.label(part: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 54)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 70
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(35, 42, 48)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.TextSize = 16
	label.TextWrapped = true
	label.Parent = gui
end
function Template.portal(
	parent: Instance,
	name: string,
	position: Vector3,
	text: string
): (Part, ProximityPrompt)
	local part =
		Template.part(parent, name, position, Vector3.new(5, 6, 1), Color3.fromRGB(85, 120, 142))
	Template.label(part, text)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = text
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return part, prompt
end
function Template.create(
	parent: Instance,
	name: string,
	origin: Vector3,
	ownerId: number,
	room: Types.Showroom?
): Space
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("OwnerId", ownerId)
	local width, depth = if room then 48 else 42, if room then 40 else 64
	Template.part(
		model,
		"Floor",
		origin,
		Vector3.new(width, 1, depth),
		Color3.fromRGB(218, 222, 225)
	)
	for _, x in { -width / 2, width / 2 } do
		Template.part(
			model,
			"Wall",
			origin + Vector3.new(x, 6, 0),
			Vector3.new(1, 12, depth),
			Color3.fromRGB(130, 144, 151)
		)
	end
	for _, z in { -depth / 2, depth / 2 } do
		Template.part(
			model,
			"Wall",
			origin + Vector3.new(0, 6, z),
			Vector3.new(width, 12, 1),
			Color3.fromRGB(130, 144, 151)
		)
	end
	local figures = Instance.new("Folder")
	figures.Name = "Figures"
	figures.Parent = model
	local anchors: { [string]: CFrame } = {}
	if room then
		model:SetAttribute("RoomId", room.roomId)
		model:SetAttribute("SourceCollectionId", room.sourceCollectionId)
		local hooks = Instance.new("Folder")
		hooks.Name = "CustomizationHooks"
		hooks.Parent = model
		for _, category in Config.customizationCategories do
			local hook = Instance.new("Folder")
			hook.Name = category
			hook.Parent = hooks
		end
		for index, id in Config.anchors do
			local position = origin
				+ Vector3.new(((index - 1) % 3 - 1) * 12, 2, math.floor((index - 1) / 3) * 9 - 4)
			local pedestal = Template.part(
				model,
				id,
				position,
				Vector3.new(4, 3, 4),
				Color3.fromRGB(185, 192, 199)
			)
			pedestal:SetAttribute("AnchorId", id)
			Template.label(pedestal, "Anchor " .. index)
			anchors[id] = CFrame.new(position + Vector3.new(0, 1.5, 0))
		end
	end
	model.Parent = parent
	return {
		model = model,
		origin = origin,
		spawn = CFrame.new(origin + Vector3.new(0, 4, -depth / 2 + 8)),
		figures = figures,
		anchors = anchors,
		signature = "",
	}
end
function Template.render(space: Space, room: Types.Showroom)
	local parts = { room.theme }
	for _, id in Config.anchors do
		table.insert(parts, room.placements[id] or "")
	end
	local signature = table.concat(parts, "|")
	if signature == space.signature then
		return
	end
	space.signature = signature
	local palette = Catalog.themes[room.theme]
	for _, child in space.model:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "Wall" then
				child.Color = palette.wall
			elseif child.Name == "Floor" then
				child.Color = palette.floor
			end
		end
	end
	space.model:SetAttribute("Theme", room.theme)
	space.figures:ClearAllChildren()
	for anchor, id in room.placements do
		local ok, model = pcall(FigureModel.create, id, space.anchors[anchor])
		if ok then
			model.Parent = space.figures
		else
			local placeholder = Template.part(
				space.figures,
				"FigurePlaceholder",
				space.anchors[anchor].Position + Vector3.new(0, 1, 0),
				Vector3.new(2, 2, 2),
				Catalog.byId[id].color
			)
			placeholder.CanCollide = false
			Template.label(placeholder, Catalog.byId[id].name)
			warn("Showroom figure rendering failed", id, model)
		end
	end
end
return Template
