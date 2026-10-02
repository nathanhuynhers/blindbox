--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local DisplayFixture = require(script.Parent.DisplayFixture)
local CollectionFixture = require(script.Parent.CollectionFixture)
local PlotFixture = require(script.Parent.PlotFixture)
local PlotStyle = require(script.Parent.PlotStyle)
local ShelfConfig = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Geometry = require(script.Parent.PlotGeometry)
local Config = require(script.Parent.PlotConfig)
local Shelves = require(script.Parent.Shelves)
local FigureSlots = require(script.Parent.FigureSlots)
local Rules = require(script.Parent.Rules)
export type Plot = {
	model: Model,
	ownerId: number,
	index: number,
	transform: CFrame,
	spawn: CFrame,
	active: boolean,
	view: Shelves.View,
	display: FigureSlots.Render,
	shelves: FigureSlots.Render,
	physicalShelves: { Model },
	collection: CollectionFixture.Render,
	entrance: PlotFixture.Entrance,
	spawnPad: Model,
	fixture: DisplayFixture.Render,
	displayCapacity: number,
	connections: { RBXScriptConnection },
	hitboxes: { Part },
	collectors: { Part },
}
local PlayerPlot = {}
local navigationMargin = 8
local navigationDistance = 160
local root = Instance.new("Folder")
root.Name = "PlayerPlots"
root.Parent = workspace
local function cleanup(plot: Plot)
	plot.active = false
	PlotFixture.releaseEntrance(plot.entrance)
	for _, connection in plot.connections do
		connection:Disconnect()
	end
	table.clear(plot.connections)
end
function PlayerPlot.create(player: Player, index: number): Plot
	local transform = Geometry.transform(index)
	local model = Instance.new("Model")
	model.Name = tostring(player.UserId)
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("PlotSlot", index)
	local accent = PlotStyle.accent(player.UserId)
	local entrance = PlotFixture.createEntrance(model, transform, player.DisplayName, accent)
	local spawnPad = PlotFixture.createSpawnPad(model, transform, accent)
	local fixture = DisplayFixture.create(model, transform, accent)
	local collection = CollectionFixture.create(model, transform, accent)
	local plot: Plot = {
		model = model,
		ownerId = player.UserId,
		index = index,
		transform = transform,
		spawn = PlotFixture.spawnCFrame(transform),
		active = true,
		view = Shelves.newView(),
		display = FigureSlots.new(model, "DisplayFigures", {}, DisplayFixture.style.figureScale),
		shelves = FigureSlots.new(
			model,
			"ShelfFigures",
			collection.anchors,
			CollectionFixture.style.figureScale
		),
		physicalShelves = collection.units,
		fixture = fixture,
		displayCapacity = 0,
		collection = collection,
		entrance = entrance,
		spawnPad = spawnPad,
		connections = {},
		hitboxes = collection.hitboxes,
		collectors = {},
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
	local delta = plot.transform:PointToObjectSpace(pos)
	return math.abs(delta.X) <= Config.width / 2
		and math.abs(delta.Z) <= Config.depth / 2
		and math.abs(delta.Y) <= 20
end
function PlayerPlot.nearDisplay(plot: Plot, player: Player): boolean
	local pos = position(player)
	local localPosition = if pos then plot.transform:PointToObjectSpace(pos) else nil
	return plot.ownerId == player.UserId
		and pos ~= nil
		and PlayerPlot.contains(plot, player)
		and localPosition ~= nil
		and math.abs(localPosition.Z - Geometry.displayZ) <= 15
end
function PlayerPlot.access(plot: Plot, player: Player): Shelves.Access
	local pos = position(player)
	local localPosition = if pos then plot.transform:PointToObjectSpace(pos) else nil
	return {
		actorId = player.UserId,
		ownerId = plot.ownerId,
		view = plot.view,
		near = localPosition ~= nil and PlayerPlot.contains(plot, player) and math.abs(
			localPosition.X - Geometry.shelfX
		) <= 16,
	}
end
-- Public viewing has a plot-sized range, separate from the narrow shelf editing band.
function PlayerPlot.canNavigate(plot: Plot, actor: Player): boolean
	local pos = position(actor)
	if not plot.active or plot.model.Parent ~= root or not pos then
		return false
	end
	local delta = plot.transform:PointToObjectSpace(pos)
	return math.abs(delta.X) <= Config.width / 2 + navigationMargin
		and math.abs(delta.Z) <= Config.depth / 2 + navigationMargin
		and math.abs(delta.Y) <= 20
end
local function layoutDisplay(plot: Plot, capacity: number)
	if plot.displayCapacity == capacity then
		return
	end
	DisplayFixture.resize(plot.fixture, capacity)
	FigureSlots.setAnchors(plot.display, DisplayFixture.anchors(plot.transform, capacity))
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
	for slot, target in plot.collectors do
		local id = state.display.slots[slot] or ""
		local anchor = plot.display.anchors[tostring(slot)]
		if anchor then
			target.CFrame = anchor * CFrame.new(0, 2, 0)
		end
		target:SetAttribute("FigureId", id)
		target.CanQuery = id ~= ""
		local click = target:FindFirstChildOfClass("ClickDetector")
		local prompt = target:FindFirstChildOfClass("ProximityPrompt")
		if click then
			click.MaxActivationDistance = if id ~= "" then 12 else 0
		end
		if prompt then
			prompt.Enabled = id ~= ""
			prompt.ObjectText = if Catalog.byId[id] then Catalog.byId[id].name else "Display"
		end
	end
	local visible = Shelves.publicView(state.shelves, plot.view)
	local shelfPlacements: { [string]: string } = {}
	for viewportPosition, unit in visible.visible do
		plot.physicalShelves[viewportPosition]:SetAttribute("ShelfId", unit.id)
		for slot, figure in unit.placements do
			shelfPlacements[ShelfConfig.renderSlot(viewportPosition, slot)] = figure
		end
	end
	FigureSlots.render(plot.shelves, shelfPlacements)
	for _, hitbox in plot.hitboxes do
		local detector = hitbox:FindFirstChildOfClass("ClickDetector")
		if detector then
			detector.MaxActivationDistance = if visible.canNavigate then navigationDistance else 0
		end
	end
	DisplayFixture.setRate(plot.fixture, Rules.rate(state))
	CollectionFixture.setNavigation(plot.collection, visible.canNavigate)
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
-- Both input routes share the same server-side ownership, live-character and exact-target checks.
function PlayerPlot.bindCollectors(plot: Plot, onCollect: (Player, number, string) -> ())
	assert(#plot.collectors == 0, "Collectors already bound")
	local folder = Instance.new("Folder")
	folder.Name = "FigureCollectors"
	folder.Parent = plot.model
	for slot = 1, DisplayConfig.maxSlots do
		local target = Instance.new("Part")
		target.Name = tostring(slot)
		target.Size = Vector3.new(6, 5, 6)
		target.Transparency = 1
		target.Anchored = true
		target.CanCollide = false
		target.CanTouch = false
		target.CanQuery = false
		target.Parent = folder
		table.insert(plot.collectors, target)
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 0
		click.Parent = target
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Collect Coins"
		prompt:SetAttribute("CollectorOwnerId", plot.ownerId)
		prompt.ObjectText = "Your displayed figure"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 12
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = target
		local function collect(actor: Player)
			local pos = position(actor)
			local id = target:GetAttribute("FigureId")
			if
				plot.active
				and plot.model.Parent == root
				and folder.Parent == plot.model
				and target.Parent == folder
				and click.Parent == target
				and prompt.Parent == target
				and actor.UserId == plot.ownerId
				and pos
				and (pos - target.Position).Magnitude <= 12
				and PlayerPlot.contains(plot, actor)
				and typeof(id) == "string"
				and id ~= ""
			then
				onCollect(actor, slot, id)
			end
		end
		table.insert(plot.connections, click.MouseClick:Connect(collect))
		table.insert(plot.connections, prompt.Triggered:Connect(collect))
	end
end
function PlayerPlot.destroy(plot: Plot)
	cleanup(plot)
	plot.model:Destroy()
end
return PlayerPlot
