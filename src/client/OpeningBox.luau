--!strict
local Config = require(script.Parent.OpeningConfig)
local Box = {}
export type Asset = { model: Model, pose: (CFrame, number) -> () }

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	round: boolean?
): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = at
	object.Color = color
	object.Material = Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	if round then
		object.Shape = Enum.PartType.Ball
	end
	object.Parent = parent
	return object
end

-- Replacement boundary: pose uses an origin-centered box and independent lid lift in studs.
-- All geometry is original, local to the viewport, and owned by the caller's scene.
function Box.create(parent: Instance, collection: string): Asset
	local palette = Config.packaging[collection] or Config.packaging.grove
	local model = Instance.new("Model")
	model.Name = "CollectionBox"
	model.Parent = parent
	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = model
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = model
	part(body, "Carton", Vector3.new(3.2, 3.2, 2.7), CFrame.new(), palette.base)
	part(body, "Foot", Vector3.new(3.28, 0.16, 2.78), CFrame.new(0, -1.55, 0), palette.lid)
	part(body, "Wrap", Vector3.new(0.54, 3.2, 2.73), CFrame.new(0.95, 0, 0), palette.ribbon)
	part(lid, "Cap", Vector3.new(3.38, 0.48, 2.88), CFrame.new(0, 1.58, 0), palette.lid)
	part(lid, "Edge", Vector3.new(3.42, 0.08, 2.92), CFrame.new(0, 1.37, 0), palette.ribbon)
	part(lid, "Wrap", Vector3.new(0.54, 0.5, 2.91), CFrame.new(0.95, 1.6, 0), palette.ribbon)
	part(
		body,
		"Medallion",
		Vector3.new(1.75, 1.75, 0.16),
		CFrame.new(-0.3, 0.05, -1.39),
		palette.lid,
		true
	)
	part(
		body,
		"PaperSeal",
		Vector3.new(1.48, 1.48, 0.16),
		CFrame.new(-0.3, 0.05, -1.47),
		palette.base,
		true
	)
	if collection == "tide" then
		-- A fan-shaped shell emblem and curved bubble bands around the ocean carton.
		for index = -2, 2 do
			part(
				body,
				"ShellPetal",
				Vector3.new(0.25, 0.86, 0.14),
				CFrame.new(-0.3 + index * 0.13, 0.1, -1.57)
					* CFrame.Angles(0, 0, math.rad(-index * 20)),
				palette.ribbon,
				true
			)
		end
		for index = 1, 9 do
			local x = -1.4 + (index - 1) * 0.35
			part(
				body,
				"Bubble",
				Vector3.new(0.18, 0.18, 0.1),
				CFrame.new(x, -0.97 + math.sin(index * 0.9) * 0.18, -1.38),
				palette.ink,
				true
			)
		end
		for index = 1, 5 do
			part(
				body,
				"SidePearl",
				Vector3.new(0.1, 0.22, 0.22),
				CFrame.new(1.63, -0.8 + index * 0.37, 0.4 * math.sin(index)),
				palette.ribbon,
				true
			)
		end
	else
		part(body, "Stem", Vector3.new(0.09, 0.87, 0.1), CFrame.new(-0.3, 0.01, -1.58), palette.ink)
		for index = 1, 4 do
			local side = if index % 2 == 0 then 1 else -1
			part(
				body,
				"Leaf",
				Vector3.new(0.32, 0.55, 0.13),
				CFrame.new(-0.3 + side * 0.19, -0.26 + index * 0.15, -1.59)
					* CFrame.Angles(0, 0, side * -0.7),
				palette.ink,
				true
			)
		end
		for index = 1, 7 do
			part(
				body,
				"Seed",
				Vector3.new(0.13, 0.27, 0.1),
				CFrame.new(-1.35 + (index - 1) * 0.44, -1.05, -1.38) * CFrame.Angles(0, 0, 0.35),
				palette.ink,
				true
			)
		end
		for index = 1, 4 do
			part(
				body,
				"SideLeaf",
				Vector3.new(0.1, 0.5, 0.26),
				CFrame.new(1.63, -1 + index * 0.48, 0.1) * CFrame.Angles(0.45, 0, 0),
				palette.ink,
				true
			)
		end
	end
	local bodyOrigin, lidOrigin = body:GetPivot(), lid:GetPivot()
	return {
		model = model,
		pose = function(at: CFrame, lift: number)
			body:PivotTo(at * bodyOrigin)
			lid:PivotTo(at * CFrame.new(0, lift, 0) * CFrame.Angles(0, 0, lift * 0.12) * lidOrigin)
		end,
	}
end

return Box
