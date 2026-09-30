--!strict
local FigureModel = require(game:GetService("ReplicatedStorage").Shared.FigureModel)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Geometry = require(script.Parent.PlotGeometry)
export type Render = {
	parent: Folder,
	anchors: { [string]: CFrame },
	ids: { [string]: string? },
	models: { [string]: Instance },
	variants: { [string]: string },
	standingScale: number?,
}
local FigureSlots = {}
function FigureSlots.new(
	parent: Instance,
	name: string,
	anchors: { [string]: CFrame },
	standingScale: number?
): Render
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return {
		parent = folder,
		anchors = anchors,
		ids = {},
		models = {},
		variants = {},
		standingScale = standingScale,
	}
end
-- Move retained figures with their logical anchors, preserving each model's pivot offset.
function FigureSlots.setAnchors(render: Render, anchors: { [string]: CFrame })
	for slot, previous in render.anchors do
		local anchor = anchors[slot]
		local object = render.models[slot]
		if not anchor then
			if object then
				object:Destroy()
			end
			render.models[slot] = nil
			render.ids[slot] = nil
			render.variants[slot] = nil
		elseif object and anchor ~= previous then
			local delta = anchor * previous:Inverse()
			if object:IsA("Model") then
				object:PivotTo(delta * object:GetPivot())
			elseif object:IsA("BasePart") then
				object.CFrame = delta * object.CFrame
			end
		end
	end
	render.anchors = anchors
end
function FigureSlots.render(render: Render, placements: { [string]: string })
	for slot, anchor in render.anchors do
		local id: string? = placements[slot]
		if id == "" then
			id = nil
		end
		local old = render.models[slot]
		-- Rebuild when a production template replaces the placeholder for this figure.
		local variant = if id then FigureModel.variant(id) else nil
		if
			id == render.ids[slot]
			and variant == render.variants[slot]
			and (not id or (old and old.Parent == render.parent))
		then
			continue
		end
		if old then
			old:Destroy()
			render.models[slot] = nil
		end
		render.ids[slot] = id
		render.variants[slot] = variant
		if id then
			local ok, model = pcall(FigureModel.create, id, anchor)
			local object: Instance
			if ok then
				-- Optional presentation scale and bottom alignment to the counter/shelf surface.
				if render.standingScale then
					model:ScaleTo(model:GetScale() * render.standingScale)
					local bounds, size = model:GetBoundingBox()
					local lift = anchor.Position.Y - (bounds.Position.Y - size.Y / 2)
					model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
				end
				object = model
			else
				local placeholder = Geometry.part(
					render.parent,
					"FigurePlaceholder",
					Vector3.new(2, 2, 2),
					anchor.Position + Vector3.new(0, 1, 0),
					Catalog.byId[id].color
				)
				placeholder.CanCollide = false
				Geometry.label(placeholder, Catalog.byId[id].name, 35)
				object = placeholder
				warn("Figure render failed; keeping saved placement", id, model)
			end
			object:SetAttribute("FigureId", id)
			object:SetAttribute("SlotId", slot)
			object.Parent = render.parent
			render.models[slot] = object
		end
	end
end
return FigureSlots
