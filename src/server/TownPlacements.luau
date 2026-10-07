--!strict
-- Registry of town spots that show an uploaded model once it loads. Until then each spot keeps
-- its native-part placeholder; a ready template replaces every placeholder of its kind.
export type Fit = "width" | "height"
export type Placement = {
	kind: string,
	at: CFrame,
	size: number,
	fit: Fit,
	placeholder: Instance?,
	model: Model?,
}

local TownPlacements = {}

local placements: { Placement } = {}
-- Ready templates, so spots added later (plot Shops) swap at once.
local templates: { [string]: Model } = {}

-- `at` is the ground point and facing; `size` is the target width or height in studs.
function TownPlacements.add(
	kind: string,
	at: CFrame,
	size: number,
	fit: Fit,
	placeholder: Instance?
): Placement
	assert(size > 0 and size < math.huge, "Placement size must be positive")
	local placement: Placement = {
		kind = kind,
		at = at,
		size = size,
		fit = fit,
		placeholder = placeholder,
		model = nil,
	}
	table.insert(placements, placement)
	local template = templates[kind]
	if template then
		TownPlacements.swap(kind, template)
	end
	return placement
end

-- Owners of temporary spots (a plot's Shop) forget theirs on teardown; instances are untouched.
function TownPlacements.remove(placement: Placement)
	local index = table.find(placements, placement)
	if index then
		table.remove(placements, index)
	end
end

function TownPlacements.list(kind: string?): { Placement }
	local found = {}
	for _, placement in placements do
		if kind == nil or placement.kind == kind then
			table.insert(found, placement)
		end
	end
	return found
end

-- Templates carry NaturalWidth/NaturalHeight attributes and a pivot at the centre of their base.
function TownPlacements.swap(kind: string, template: Model): number
	local width = template:GetAttribute("NaturalWidth")
	local height = template:GetAttribute("NaturalHeight")
	if typeof(width) ~= "number" or typeof(height) ~= "number" or width <= 0 or height <= 0 then
		return 0
	end
	templates[kind] = template
	local swapped = 0
	for _, placement in placements do
		if placement.kind == kind and placement.model == nil then
			local placeholder = placement.placeholder
			local parent = if placeholder then placeholder.Parent else nil
			if placeholder and parent then
				local clone = template:Clone()
				local natural = if placement.fit == "width" then width else height
				clone:ScaleTo(template:GetScale() * placement.size / natural)
				clone:PivotTo(placement.at)
				clone.Name = placeholder.Name
				clone.Parent = parent
				placeholder:Destroy()
				placement.placeholder = nil
				placement.model = clone
				swapped += 1
			end
		end
	end
	return swapped
end

-- World teardown or tests: forget every spot without touching instances.
function TownPlacements.clear()
	table.clear(placements)
	table.clear(templates)
end

return TownPlacements
