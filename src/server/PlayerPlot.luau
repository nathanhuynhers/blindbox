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
	connections: { RBXScriptConnection },
	arrows: { Part },
}
local PlayerPlot = {}
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
	local displayAnchors: { [string]: CFrame } = {}
	local pads: { Part } = {}
	local slotLabels: { TextLabel } = {}
	for slot = 1, DisplayConfig.maxSlots do
		local offset = Geometry.displayOffset(slot)
		local pad = Geometry.part(
			model,
			"DisplaySlot_" .. slot,
			Vector3.new(8, 2, 6),
			origin + offset - Vector3.new(0, 1, 0),
			Color3.fromRGB(149, 167, 182)
		)
		pads[slot] = pad
		slotLabels[slot] = Geometry.label(pad, "", 40)
		displayAnchors[tostring(slot)] = CFrame.new(origin + offset)
	end
	local displaySign = Geometry.part(
		model,
		"DisplayArea",
		Vector3.new(14, 1, 1),
		origin + Vector3.new(0, 1, -21),
		Color3.fromRGB(68, 83, 100)
	)
	local displayLabel = Geometry.label(displaySign, "Display", 55)
	local displayStand = Geometry.part(
		model,
		"DisplayStand",
		Vector3.new(28, 1, 6),
		origin + Vector3.new(-15, 0.5, -14),
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
				Vector3.new(0.6, height, 5),
				origin + Vector3.new(center.X + direction * width / 2, height / 2, center.Z),
				Color3.fromRGB(108, 119, 131)
			)
		end
		for row = 1, ShelfConfig.rowsPerShelfUnit do
			local offset = Geometry.shelfOffset(unit, row, (ShelfConfig.slotsPerRow + 1) / 2)
			Geometry.part(
				shelf,
				"Row_" .. row,
				Vector3.new(width, 0.5, 5),
				origin + offset - Vector3.new(0, 0.25, 0),
				Color3.fromRGB(179, 188, 198)
			)
			for slot = 1, ShelfConfig.slotsPerRow do
				local id = ShelfConfig.slotId(unit, row, slot)
				shelfAnchors[id] = CFrame.new(origin + Geometry.shelfOffset(unit, row, slot))
			end
		end
	end
	local labelPart = Geometry.part(
		model,
		"ShelfPageSign",
		Vector3.new(14, 1, 1),
		origin + Vector3.new(0, 1, 17),
		Color3.fromRGB(68, 83, 100)
	)
	local arrows: { Part } = {}
	for _, direction in { -1, 1 } do
		local arrow = Geometry.part(
			model,
			if direction == -1 then "PreviousPage" else "NextPage",
			Vector3.new(5, 2, 2),
			origin + Vector3.new(direction * 40, 2, 21),
			Color3.fromRGB(68, 83, 100)
		)
		Geometry.label(arrow, if direction == -1 then "< Previous page" else "Next page >", 45)
		table.insert(arrows, arrow)
	end
	local plot: Plot = {
		model = model,
		ownerId = player.UserId,
		index = index,
		origin = origin,
		spawn = CFrame.lookAt(origin + Vector3.new(0, 4, -33), origin + Vector3.new(0, 4, 0)),
		active = true,
		view = Shelves.newView(),
		display = FigureSlots.new(model, "DisplayFigures", displayAnchors),
		shelves = FigureSlots.new(model, "ShelfFigures", shelfAnchors),
		pads = pads,
		slotLabels = slotLabels,
		displayLabel = displayLabel,
		displayStand = displayStand,
		pageLabel = Geometry.label(labelPart, "", 60),
		connections = {},
		arrows = arrows,
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
		and math.abs(pos.Z - (plot.origin.Z - 14)) <= 15
end
function PlayerPlot.access(plot: Plot, player: Player): Shelves.Access
	local pos = position(player)
	return {
		actorId = player.UserId,
		ownerId = plot.ownerId,
		view = plot.view,
		near = pos ~= nil and PlayerPlot.contains(plot, player) and math.abs(
			pos.Z - (plot.origin.Z + 26)
		) <= 16,
	}
end
function PlayerPlot.render(plot: Plot, state: Types.State)
	if not plot.active then
		return
	end
	local placements: { [string]: string } = {}
	local left = Geometry.displayOffset(1).X
	local right = Geometry.displayOffset(state.display.unlocked).X
	plot.displayStand.Size = Vector3.new(right - left + 8, 1, 6)
	plot.displayStand.Position = plot.origin + Vector3.new((left + right) / 2, 0.5, -14)
	for slot, pad in plot.pads do
		local unlocked = slot <= state.display.unlocked
		local id = state.display.slots[slot] or ""
		placements[tostring(slot)] = if unlocked then id else ""
		pad.Transparency = if unlocked then 0 else 0.8
		pad.CanCollide = unlocked
		plot.slotLabels[slot].Text = if unlocked
			then "Display " .. slot .. (if id ~= ""
				then " - " .. (Rules.rates[id] or 0) .. " Coins/sec"
				else " - Empty")
			else "Slot " .. slot .. " - Locked"
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
	if not PlayerPlot.access(plot, actor).near then
		return false
	end
	if not Shelves.turn(state.shelves, plot.view, direction, now) then
		return false
	end
	PlayerPlot.render(plot, state)
	return true
end
function PlayerPlot.bind(plot: Plot, onTurn: (Player, number) -> ())
	for index, arrow in plot.arrows do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = if index == 1 then "Previous" else "Next"
		prompt.ObjectText = "Shared shelf page"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = arrow
		table.insert(
			plot.connections,
			prompt.Triggered:Connect(function(actor: Player)
				local pos = position(actor)
				if
					plot.active
					and arrow.Parent
					and pos
					and (pos - arrow.Position).Magnitude <= 12
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
