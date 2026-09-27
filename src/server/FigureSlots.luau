--!strict
local FigureModel = require(game:GetService("ReplicatedStorage").Shared.FigureModel)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Geometry = require(script.Parent.PlotGeometry)
export type Render = {
	parent: Folder,
	anchors: { [string]: CFrame },
	ids: { [string]: string? },
	models: { [string]: Instance },
}
local FigureSlots = {}
function FigureSlots.new(parent: Instance, name: string, anchors: { [string]: CFrame }): Render
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return { parent = folder, anchors = anchors, ids = {}, models = {} }
end
function FigureSlots.render(render: Render, placements: { [string]: string })
	for slot, anchor in render.anchors do
		local id: string? = placements[slot]
		if id == "" then
			id = nil
		end
		local old = render.models[slot]
		if id == render.ids[slot] and (not id or (old and old.Parent == render.parent)) then
			continue
		end
		if old then
			old:Destroy()
			render.models[slot] = nil
		end
		render.ids[slot] = id
		if id then
			local ok, model = pcall(FigureModel.create, id, anchor)
			local object: Instance
			if ok then
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
