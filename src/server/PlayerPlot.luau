--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local DisplayFixture = require(script.Parent.DisplayFixture)
local ShelfConfig = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Geometry = require(script.Parent.PlotGeometry)
local Config = require(script.Parent.PlotConfig)
local Shelves = require(script.Parent.Shelves)
local FigureSlots = require(script.Parent.FigureSlots)
local Rules = require(script.Parent.Rules)
export type Plot = {
	model: Model,
	ownerId: number,
	index: number,
	origin: Vector3,
	spawn: CFrame,
	active: boolean,
	view: Shelves.View,
	display: FigureSlots.Render,
	shelves: FigureSlots.Render,
	physicalShelves: { Model },
	carouselLabel: TextLabel,
	fixture: DisplayFixture.Render,
	displayCapacity: number,
	connections: { RBXScriptConnection },
	arrows: { Part },
	hitboxes: { Part },
}
local PlayerPlot = {}
local navigationMargin = 8
local navigationDistance = 160
local root = Instance.new("Folder")
root.Name = "PlayerPlots"
root.Parent = workspace
local function cleanup(plot: Plot)
	plot.active = false
	for _, connection in plot.connections do
		connection:Disconnect()
	end
	table.clear(plot.connections)
end
function PlayerPlot.create(player: Player, index: number): Plot
	local origin = Geometry.origin(index)
	local model = Instance.new("Model")
	model.Name = tostring(player.UserId)
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("PlotSlot", index)
	local sign = Geometry.part(
		model,
		"OwnerSign",
		Vector3.new(16, 3, 1),
		origin + Vector3.new(0, 3, -43),
		Color3.fromRGB(68, 83, 100)
	)
	Geometry.label(sign, player.DisplayName .. "'s Plot", 140)
	local fixture = DisplayFixture.create(model, origin)
	local shelfAnchors: { [string]: CFrame } = {}
	local physicalShelves: { Model } = {}
	for unit = 1, ShelfConfig.visibleShelfUnits do
		local shelf = Instance.new("Model")
		shelf.Name = "ShelfPosition_" .. unit
		physicalShelves[unit] = shelf
		shelf.Parent = model
		local center = Geometry.shelfOffset(
			unit,
			ShelfConfig.rowsPerShelfUnit,
			(ShelfConfig.slotsPerRow + 1) / 2
		)
		local width, height = ShelfConfig.slotsPerRow * 5 + 3, ShelfConfig.rowsPerShelfUnit * 5
		for _, direction in { -1, 1 } do
			Geometry.part(
				shelf,
				"Support",
				Vector3.new(5, height, 0.6),
				origin + Vector3.new(center.X, height / 2, center.Z + direction * width / 2),
				Color3.fromRGB(108, 119, 131)
			)
		end
		for row = 1, ShelfConfig.rowsPerShelfUnit do
			local offset = Geometry.shelfOffset(unit, row, (ShelfConfig.slotsPerRow + 1) / 2)
			Geometry.part(
				shelf,
				"Row_" .. row,
				Vector3.new(5, 0.5, width),
				origin + offset - Vector3.new(0, 0.25, 0),
				Color3.fromRGB(179, 188, 198)
			)
			for slot = 1, ShelfConfig.slotsPerRow do
				local id = ShelfConfig.renderSlot(unit, ShelfConfig.slotId(row, slot))
				shelfAnchors[id] = Geometry.shelfAnchor(origin, unit, row, slot)
			end
		end
	end
	local labelPart = Geometry.part(
		model,
		"ShelfCarouselSign",
		Vector3.new(1.5, 3, 14),
		origin + Vector3.new(Geometry.shelfX, 18, -4),
		Color3.fromRGB(68, 83, 100)
	)
	local arrows: { Part } = {}
	local hitboxes: { Part } = {}
	for _, direction in { -1, 1 } do
		local arrow = Geometry.part(
			model,
			if direction == -1 then "PreviousShelves" else "NextShelves",
			Vector3.new(1.5, 6, 10),
			origin + Vector3.new(Geometry.shelfX, 18, -4 + direction * 24),
			Color3.fromRGB(68, 83, 100)
		)
		arrow.CanCollide = false
		Geometry.label(
			arrow,
			if direction == -1 then "< Previous shelves" else "Next shelves >",
			160
		)
		table.insert(arrows, arrow)
		local hitbox = Geometry.part(
			model,
			arrow.Name .. "Hitbox",
			Vector3.new(4, 10, 16),
			arrow.Position,
			arrow.Color
		)
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.CanTouch = false
		hitbox.CanQuery = true
		table.insert(hitboxes, hitbox)
	end
	local plot: Plot = {
		model = model,
		ownerId = player.UserId,
		index = index,
		origin = origin,
		spawn = CFrame.lookAt(origin + Vector3.new(0, 4, -33), origin + Vector3.new(0, 4, 0)),
		active = true,
		view = Shelves.newView(),
		display = FigureSlots.new(model, "DisplayFigures", {}, DisplayFixture.style.figureScale),
		shelves = FigureSlots.new(model, "ShelfFigures", shelfAnchors),
		physicalShelves = physicalShelves,
		fixture = fixture,
		displayCapacity = 0,
		carouselLabel = Geometry.label(labelPart, "", 160),
		connections = {},
		arrows = arrows,
		hitboxes = hitboxes,
	}
	table.insert(
		plot.connections,
		model.Destroying:Connect(function()
			cleanup(plot)
		end)
	)
	model.Parent = root
	return plot
end
local function position(player: Player): Vector3?
	local character = player.Character
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return if part
			and part:IsA("BasePart")
			and humanoid
			and humanoid.Health > 0
		then part.Position
		else nil
end
function PlayerPlot.contains(plot: Plot, player: Player): boolean
	local pos = position(player)
	if not plot.active or not plot.model.Parent or not pos then
		return false
	end
	local delta = pos - plot.origin
	return math.abs(delta.X) <= Config.width / 2
		and math.abs(delta.Z) <= Config.depth / 2
		and math.abs(delta.Y) <= 20
end
function PlayerPlot.nearDisplay(plot: Plot, player: Player): boolean
	local pos = position(player)
	return plot.ownerId == player.UserId
		and pos ~= nil
		and PlayerPlot.contains(plot, player)
		and math.abs(pos.Z - (plot.origin.Z + Geometry.displayZ)) <= 15
end
function PlayerPlot.access(plot: Plot, player: Player): Shelves.Access
	local pos = position(player)
	return {
		actorId = player.UserId,
		ownerId = plot.ownerId,
		view = plot.view,
		near = pos ~= nil and PlayerPlot.contains(plot, player) and math.abs(
			pos.X - (plot.origin.X + Geometry.shelfX)
		) <= 16,
	}
end
-- Public viewing has a plot-sized range, separate from the narrow shelf editing band.
function PlayerPlot.canNavigate(plot: Plot, actor: Player): boolean
	local pos = position(actor)
	if not plot.active or plot.model.Parent ~= root or not pos then
		return false
	end
	local delta = pos - plot.origin
	return math.abs(delta.X) <= Config.width / 2 + navigationMargin
		and math.abs(delta.Z) <= Config.depth / 2 + navigationMargin
		and math.abs(delta.Y) <= 20
end
local function layoutDisplay(plot: Plot, capacity: number)
	if plot.displayCapacity == capacity then
		return
	end
	DisplayFixture.resize(plot.fixture, capacity)
	FigureSlots.setAnchors(plot.display, DisplayFixture.anchors(plot.origin, capacity))
	plot.displayCapacity = capacity
end
function PlayerPlot.render(plot: Plot, state: Types.State)
	if not plot.active then
		return
	end
	local placements: { [string]: string } = {}
	layoutDisplay(plot, state.display.unlocked)
	for slot = 1, state.display.unlocked do
		local id = state.display.slots[slot] or ""
		placements[tostring(slot)] = id
	end
	FigureSlots.render(plot.display, placements)
	local visible = Shelves.publicView(state.shelves, plot.view)
	local shelfPlacements: { [string]: string } = {}
	local indices: { string } = {}
	for viewportPosition, unit in visible.visible do
		plot.physicalShelves[viewportPosition]:SetAttribute("ShelfId", unit.id)
		table.insert(indices, tostring(unit.index))
		for slot, figure in unit.placements do
			shelfPlacements[ShelfConfig.renderSlot(viewportPosition, slot)] = figure
		end
	end
	FigureSlots.render(plot.shelves, shelfPlacements)
	for index, hitbox in plot.hitboxes do
		local detector = hitbox:FindFirstChildOfClass("ClickDetector")
		if detector then
			detector.MaxActivationDistance = if visible.canNavigate then navigationDistance else 0
		end
		plot.arrows[index].Transparency = if visible.canNavigate then 0 else 0.55
	end
	DisplayFixture.setRate(plot.fixture, Rules.rate(state))
	plot.carouselLabel.Text = string.format(
		"Viewing shelves %s of %d\nCosmetic figures - 0 Coins",
		table.concat(indices, ", "),
		visible.ownedCount
	)
	plot.model:SetAttribute("ShelfCarouselRevision", visible.carouselRevision)
end
function PlayerPlot.turn(
	plot: Plot,
	actor: Player,
	state: Types.State,
	direction: number,
	now: number
): boolean
	if not PlayerPlot.canNavigate(plot, actor) then
		return false
	end
	if not Shelves.turn(state.shelves, plot.view, direction, now) then
		return false
	end
	PlayerPlot.render(plot, state)
	return true
end
function PlayerPlot.bind(plot: Plot, onTurn: (Player, number) -> ())
	for index, hitbox in plot.hitboxes do
		local detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = 0 -- Enabled by the next render only when more than three shelves are owned.
		detector.Parent = hitbox
		table.insert(
			plot.connections,
			detector.MouseClick:Connect(function(actor: Player)
				if
					hitbox.Parent == plot.model
					and detector.Parent == hitbox
					and PlayerPlot.canNavigate(plot, actor)
				then
					onTurn(actor, if index == 1 then -1 else 1)
				end
			end)
		)
	end
end
function PlayerPlot.destroy(plot: Plot)
	cleanup(plot)
	plot.model:Destroy()
end
return PlayerPlot
