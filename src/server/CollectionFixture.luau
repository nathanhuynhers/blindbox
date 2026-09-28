--!strict
-- Physical presentation only. Persistent Shelf Units and carousel decisions belong to Shelves.
local Config = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Geometry = require(script.Parent.PlotGeometry)
local Fixture = {}
Fixture.palette = table.freeze({
	ivory = Color3.fromRGB(242, 235, 220),
	oak = Color3.fromRGB(198, 165, 120),
	panel = Color3.fromRGB(235, 225, 204),
	charcoal = Color3.fromRGB(48, 46, 43),
	recess = Color3.fromRGB(171, 143, 106),
	sign = Color3.fromRGB(255, 246, 222),
	diffuser = Color3.fromRGB(255, 237, 199),
	light = Color3.fromRGB(255, 227, 180),
	muted = Color3.fromRGB(163, 146, 122),
})
Fixture.style = table.freeze({ depth = 5, post = 0.55, board = 0.3, figureScale = 1 })
local palette, style = Fixture.palette, Fixture.style
export type Control = { panel: Part, accents: { Part } }
export type Render = {
	model: Model,
	units: { Model },
	anchors: { [string]: CFrame },
	hitboxes: { Part },
	controls: { Control },
	header: TextLabel,
	navigation: boolean?,
}
local function piece(
	parent: Instance,
	transform: CFrame,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	wood: boolean?
): Part
	local part = Geometry.partAt(parent, name, size, transform * CFrame.new(offset), color)
	part.Material = if wood then Enum.Material.Wood else Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	-- Controls are reached through their dedicated hitboxes, never decorative trim.
	part.CanQuery = false
	return part
end
local function control(
	model: Model,
	parent: Instance,
	transform: CFrame,
	direction: number,
	span: number
): (Control, Part)
	local x = Geometry.shelfX
	local z = Geometry.shelfCenterZ + direction * (span / 2 + 2.1)
	local name = if direction == -1 then "Previous" else "Next"
	piece(
		model,
		transform,
		name .. "Plinth",
		Vector3.new(4.5, 0.65, 4.2),
		Vector3.new(x, 0.325, z),
		palette.charcoal
	)
	piece(
		model,
		transform,
		name .. "Wing",
		Vector3.new(4.7, 10.7, 4.2),
		Vector3.new(x, 6, z),
		palette.ivory
	)
	piece(
		model,
		transform,
		name .. "Cap",
		Vector3.new(5, 0.45, 4.3),
		Vector3.new(x, 11.575, z),
		palette.ivory
	)
	local panel = piece(
		model,
		transform,
		name .. "OakPanel",
		Vector3.new(0.25, 6.8, 3.8),
		Vector3.new(x - 2.48, 7.1, z),
		palette.oak,
		true
	)
	local accents: { Part } = {}
	for _, edge in { -1, 1 } do
		local trim = piece(
			model,
			transform,
			name .. "WarmTrim",
			Vector3.new(0.1, 0.1, 3.8),
			Vector3.new(x - 2.63, 7.1 + edge * 3.45, z),
			palette.diffuser
		)
		trim.CanCollide = false
		table.insert(accents, trim)
	end
	local edge = piece(
		model,
		transform,
		name .. "OuterTrim",
		Vector3.new(0.1, 6.8, 0.1),
		Vector3.new(x - 2.63, 7.1, z + direction * 1.85),
		palette.diffuser
	)
	edge.CanCollide = false
	table.insert(accents, edge)
	-- Two solid beveled-looking bars form a spatial chevron; no text glyph or uploaded icon.
	for _, half in { -1, 1 } do
		local bar = piece(
			model,
			transform,
			name .. "Chevron",
			Vector3.new(0.18, 2.7, 0.65),
			Vector3.new(x - 2.72, 7.1 + half * 0.85, z),
			palette.diffuser
		)
		bar.CFrame *= CFrame.Angles(math.rad(-direction * half * 45), 0, 0)
		bar.CanCollide = false
		table.insert(accents, bar)
	end
	-- Kept under the plot root so the existing server-bound ancestry guard stays unchanged.
	local hitbox = Geometry.partAt(
		parent,
		name .. "ShelvesHitbox",
		Vector3.new(5, 10, 7),
		transform * CFrame.new(x - 2.7, 7.1, z),
		palette.ivory
	)
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	return { panel = panel, accents = accents }, hitbox
end
function Fixture.setNavigation(render: Render, enabled: boolean)
	if render.navigation == enabled then
		return
	end
	render.navigation = enabled
	for _, button in render.controls do
		for _, accent in button.accents do
			accent.Color = if enabled then palette.diffuser else palette.muted
		end
	end
end
function Fixture.create(parent: Instance, transform: CFrame): Render
	local model = Instance.new("Model")
	model.Name = "CollectionFixture"
	local units: { Model } = {}
	local anchors: { [string]: CFrame } = {}
	local pitch = Geometry.shelfUnitPitch
	local span = Config.visibleShelfUnits * pitch
	local top = Geometry.shelfBaseY + Config.rowsPerShelfUnit * Geometry.shelfRowSpacing
	local x, z = Geometry.shelfX, Geometry.shelfCenterZ
	for position = 1, Config.visibleShelfUnits do
		local unit = Instance.new("Model")
		unit.Name = "ShelfPosition_" .. position
		unit.Parent = model
		units[position] = unit
		local center = Geometry.shelfOffset(position, 1, (Config.slotsPerRow + 1) / 2).Z
		piece(
			unit,
			transform,
			"Plinth",
			Vector3.new(4.7, 0.65, pitch - 0.06),
			Vector3.new(x + 0.1, 0.325, center),
			palette.charcoal
		)
		piece(
			unit,
			transform,
			"Base",
			Vector3.new(style.depth, Geometry.shelfBaseY - style.board - 0.65, pitch - 0.06),
			Vector3.new(x, (Geometry.shelfBaseY - style.board + 0.65) / 2, center),
			palette.ivory
		)
		piece(
			unit,
			transform,
			"RecessedBack",
			Vector3.new(0.3, top - 0.65, pitch - 2 * style.post),
			Vector3.new(x + 2.25, (top + 0.65) / 2, center),
			palette.panel
		)
		for _, side in { -1, 1 } do
			piece(
				unit,
				transform,
				"OakUpright",
				Vector3.new(4.9, top - 0.65, style.post),
				Vector3.new(x, (top + 0.65) / 2, center + side * (pitch - style.post) / 2),
				palette.oak,
				true
			)
		end
		for row = 1, Config.rowsPerShelfUnit do
			local height = Geometry.shelfOffset(position, row, 1).Y
			piece(
				unit,
				transform,
				"Row_" .. row,
				Vector3.new(style.depth, style.board, pitch - 2 * style.post),
				Vector3.new(x, height - style.board / 2, center),
				palette.ivory
			)
			local diffuser = piece(
				unit,
				transform,
				"RowLight_" .. row,
				Vector3.new(0.45, 0.1, pitch - 2 * style.post - 0.4),
				Vector3.new(
					x - 1.95,
					height + Geometry.shelfRowSpacing - style.board - 0.08,
					center
				),
				palette.diffuser
			)
			diffuser.CanCollide = false
			local light = Instance.new("SurfaceLight")
			light.Name = "WarmWash"
			light.Face = Enum.NormalId.Bottom
			light.Color = palette.light
			light.Brightness = 0.35
			light.Range = 5
			light.Angle = 110
			light.Shadows = false
			light.Parent = diffuser
			for slot = 1, Config.slotsPerRow do
				anchors[Config.renderSlot(position, Config.slotId(row, slot))] =
					Geometry.shelfAnchor(transform, position, row, slot)
			end
		end
	end
	piece(
		model,
		transform,
		"ContinuousCanopy",
		Vector3.new(5.2, 0.7, span + 0.4),
		Vector3.new(x, top + 0.05, z),
		palette.ivory
	)
	piece(
		model,
		transform,
		"OakCrown",
		Vector3.new(4.8, 0.2, span),
		Vector3.new(x + 0.1, top + 0.5, z),
		palette.oak,
		true
	)
	piece(
		model,
		transform,
		"HeaderFrame",
		Vector3.new(0.65, 2.6, 15.8),
		Vector3.new(x - 2, top + 1.55, z),
		palette.oak,
		true
	)
	piece(
		model,
		transform,
		"HeaderRecess",
		Vector3.new(0.12, 2.13, 15.33),
		Vector3.new(x - 2.36, top + 1.55, z),
		palette.recess
	)
	local face = piece(
		model,
		transform,
		"HeaderFace",
		Vector3.new(0.1, 1.95, 15.15),
		Vector3.new(x - 2.48, top + 1.55, z),
		palette.sign
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CollectionSign"
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1200, 160)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0.35
	gui.Parent = face
	local header = Instance.new("TextLabel")
	header.Name = "Title"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromScale(0.04, 0.12)
	header.Size = UDim2.fromScale(0.92, 0.76)
	header.Font = Enum.Font.GothamBlack
	header.TextColor3 = palette.charcoal
	header.TextScaled = true
	header.Text = "COLLECTION"
	header.Parent = gui
	local controls: { Control } = {}
	local hitboxes: { Part } = {}
	for _, direction in { -1, 1 } do
		local button, hitbox = control(model, parent, transform, direction, span)
		table.insert(controls, button)
		table.insert(hitboxes, hitbox)
	end
	local render: Render = {
		model = model,
		units = units,
		anchors = anchors,
		controls = controls,
		hitboxes = hitboxes,
		header = header,
		navigation = nil,
	}
	Fixture.setNavigation(render, false)
	model.Parent = parent
	return render
end
return Fixture
