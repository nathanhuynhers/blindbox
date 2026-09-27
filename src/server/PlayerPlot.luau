--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
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
	pads: { Part },
	slotLabels: { TextLabel },
	pageLabel: TextLabel,
	displayLabel: TextLabel,
	displayStand: Part,
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
	local displaySign = Geometry.part(
		model,
		"DisplayArea",
		Vector3.new(14, 1, 1),
		origin + Vector3.new(0, 3, Geometry.displayZ - 8),
		Color3.fromRGB(68, 83, 100)
	)
	local displayLabel = Geometry.label(displaySign, "Display", 140)
	local displayStand = Geometry.part(
		model,
		"DisplayStand",
		Vector3.new(Geometry.displayWidth(DisplayConfig.defaultSlots), 3, 12),
		origin + Vector3.new(0, 1.5, Geometry.displayZ),
		Color3.fromRGB(116, 135, 151)
	)
	local shelfAnchors: { [string]: CFrame } = {}
	for unit = 1, ShelfConfig.shelfUnitsPerPage do
		local shelf = Instance.new("Model")
		shelf.Name = "ShelfUnit_" .. unit
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
				local id = ShelfConfig.slotId(unit, row, slot)
				shelfAnchors[id] = Geometry.shelfAnchor(origin, unit, row, slot)
			end
		end
	end
	local labelPart = Geometry.part(
		model,
		"ShelfPageSign",
		Vector3.new(1.5, 3, 14),
		origin + Vector3.new(Geometry.shelfX, 18, -4),
		Color3.fromRGB(68, 83, 100)
	)
	local arrows: { Part } = {}
	local hitboxes: { Part } = {}
	for _, direction in { -1, 1 } do
		local arrow = Geometry.part(
			model,
			if direction == -1 then "PreviousPage" else "NextPage",
			Vector3.new(1.5, 6, 10),
			origin + Vector3.new(Geometry.shelfX, 18, -4 + direction * 24),
			Color3.fromRGB(68, 83, 100)
		)
		arrow.CanCollide = false
		Geometry.label(arrow, if direction == -1 then "< Previous page" else "Next page >", 160)
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
		display = FigureSlots.new(model, "DisplayFigures", {}),
		shelves = FigureSlots.new(model, "ShelfFigures", shelfAnchors),
		pads = {},
		slotLabels = {},
		displayLabel = displayLabel,
		displayStand = displayStand,
		displayCapacity = 0,
		pageLabel = Geometry.label(labelPart, "", 160),
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
	for slot = #plot.pads, capacity + 1, -1 do
		plot.pads[slot]:Destroy()
		plot.pads[slot] = nil
		plot.slotLabels[slot] = nil
	end
	local anchors: { [string]: CFrame } = {}
	for slot = 1, capacity do
		local offset = Geometry.displayOffset(slot, capacity)
		local pad: Part? = plot.pads[slot]
		if not pad then
			local newPad = Geometry.part(
				plot.model,
				"DisplaySlot_" .. slot,
				Vector3.new(10, 2, 10),
				plot.origin + offset - Vector3.new(0, 1, 0),
				Color3.fromRGB(149, 167, 182)
			)
			plot.pads[slot] = newPad
			plot.slotLabels[slot] = Geometry.label(newPad, "", 70)
		else
			pad.Position = plot.origin + offset - Vector3.new(0, 1, 0)
		end
		anchors[tostring(slot)] = CFrame.new(plot.origin + offset)
	end
	FigureSlots.setAnchors(plot.display, anchors)
	plot.displayStand.Size = Vector3.new(Geometry.displayWidth(capacity), 3, 12)
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
		plot.slotLabels[slot].Text = "Display "
			.. slot
			.. (if id ~= "" then " - " .. (Rules.rates[id] or 0) .. " Coins/sec" else " - Empty")
	end
	FigureSlots.render(plot.display, placements)
	FigureSlots.render(plot.shelves, state.shelves.pages[plot.view.index].placements)
	plot.displayLabel.Text = "Display - " .. Rules.rate(state) .. " Coins/sec"
	plot.pageLabel.Text = string.format(
		"Shelves - Page %d / %d\nCosmetic figures - 0 Coins",
		plot.view.index,
		#state.shelves.pages
	)
	plot.model:SetAttribute("VisibleShelfPage", state.shelves.pages[plot.view.index].id)
end
function PlayerPlot.turn(
	plot: Plot,
	actor: Player,
	state: Types.State,
	direction: number,
	now: number
): boolean
	if not PlayerPlot.canNavigate(plot, actor) or #state.shelves.pages <= 1 then
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
		detector.MaxActivationDistance = navigationDistance
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
