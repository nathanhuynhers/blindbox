--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local DisplayFixture = require(script.Parent.DisplayFixture)
local CollectionFixture = require(script.Parent.CollectionFixture)
local ShopFixture = require(script.Parent.ShopFixture)
local TownPlacements = require(script.Parent.TownPlacements)
local PlotFixture = require(script.Parent.PlotFixture)
local PlotStyle = require(script.Parent.PlotStyle)
local ShelfConfig = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Geometry = require(script.Parent.PlotGeometry)
local Config = require(script.Parent.PlotConfig)
local Shelves = require(script.Parent.Shelves)
local Showcase = require(script.Parent.ShelfShowcase)
local FigureSlots = require(script.Parent.FigureSlots)
local Rules = require(script.Parent.Rules)
local NightLights = require(script.Parent.NightLights)
local Players = game:GetService("Players")
export type Plot = {
	model: Model,
	ownerId: number,
	index: number,
	transform: CFrame,
	spawn: CFrame,
	active: boolean,
	view: Shelves.View,
	showcase: Showcase.Controller,
	display: FigureSlots.Render,
	shelves: FigureSlots.Render,
	physicalShelves: { Model },
	collection: CollectionFixture.Render,
	entrance: PlotFixture.Entrance,
	spawnPad: Model,
	fixture: DisplayFixture.Render,
	shop: ShopFixture.Render,
	-- Swaps the part-built Peeka for the uploaded shopkeeper whenever that model is ready.
	shopkeeper: TownPlacements.Placement,
	displayCapacity: number,
	connections: { RBXScriptConnection },
	hitboxes: { Part },
	collectors: { Part },
	nightLighting: NightLights.Entry?,
}
local PlayerPlot = {}
local navigationMargin = 8
local navigationDistance = 160
local root = Instance.new("Folder")
root.Name = "PlayerPlots"
root.Parent = workspace
local function cleanup(plot: Plot)
	plot.active = false
	Showcase.destroy(plot.showcase)
	if plot.nightLighting then
		NightLights.release(plot.nightLighting)
		plot.nightLighting = nil
	end
	PlotFixture.releaseEntrance(plot.entrance)
	TownPlacements.remove(plot.shopkeeper)
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
	local shop = ShopFixture.create(model, transform)
	local plot: Plot = {
		model = model,
		ownerId = player.UserId,
		index = index,
		transform = transform,
		spawn = PlotFixture.spawnCFrame(transform),
		active = true,
		view = Shelves.newView(),
		showcase = Showcase.new(player.UserId),
		display = FigureSlots.new(model, "DisplayFigures", {}, DisplayFixture.style.figureScale),
		shelves = FigureSlots.new(
			model,
			"ShelfFigures",
			collection.anchors,
			CollectionFixture.style.figureScale
		),
		physicalShelves = collection.units,
		fixture = fixture,
		shop = shop,
		shopkeeper = TownPlacements.add(
			ShopFixture.shopkeeper.kind,
			shop.keeperAt,
			ShopFixture.shopkeeper.height,
			"height",
			shop.keeper
		),
		displayCapacity = 0,
		collection = collection,
		entrance = entrance,
		spawnPad = spawnPad,
		connections = {},
		hitboxes = collection.hitboxes,
		collectors = {},
		nightLighting = nil,
	}
	plot.nightLighting = NightLights.watch(function(enabled)
		DisplayFixture.setNight(fixture, enabled)
		CollectionFixture.setNight(collection, enabled)
		ShopFixture.setNight(shop, enabled)
		PlotFixture.setNight(entrance, enabled)
	end)
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
function PlayerPlot.canManage(plot: Plot, player: Player): boolean
	return plot.ownerId == player.UserId and PlayerPlot.contains(plot, player)
end
function PlayerPlot.access(plot: Plot, player: Player): Shelves.Access
	return {
		actorId = player.UserId,
		ownerId = plot.ownerId,
		view = plot.view,
		insidePlot = PlayerPlot.canManage(plot, player),
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
	DisplayFixture.setPlates(plot.fixture, state.display.slots)
	for slot, target in plot.collectors do
		local id = state.display.slots[slot] or ""
		local anchor = plot.display.anchors[tostring(slot)]
		if anchor then
			target.CFrame = anchor * CFrame.new(0, 2, 0)
		end
		target:SetAttribute("FigureId", id)
		target.CanQuery = id ~= ""
		local click = target:FindFirstChildOfClass("ClickDetector")
		if click then
			click.MaxActivationDistance = if id ~= "" then DisplayConfig.collectDistance else 0
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
-- Both automatic and manual navigation use the same domain turn and renderer.
local function advance(plot: Plot, state: Types.State, direction: number, now: number): boolean
	if not Shelves.turn(state.shelves, plot.view, direction, now) then
		return false
	end
	PlayerPlot.render(plot, state)
	return true
end
function PlayerPlot.stepShowcase(plot: Plot, state: Types.State, now: number): boolean
	if not plot.active or plot.model.Parent ~= root or plot.ownerId ~= plot.showcase.ownerId then
		Showcase.destroy(plot.showcase)
		return false
	end
	if not Showcase.due(plot.showcase, #state.shelves.units, now) then
		return false
	end
	-- Only scan players when a step is due. Use the existing living-player viewing
	-- boundary, and wait a full interval if nobody can see/browse this plot.
	local nearby = false
	for _, player in Players:GetPlayers() do
		if PlayerPlot.canNavigate(plot, player) then
			nearby = true
			break
		end
	end
	Showcase.wait(plot.showcase, now)
	return nearby and advance(plot, state, 1, now)
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
	if direction ~= -1 and direction ~= 1 then
		return false
	end
	-- Even a press inside the shared turn cooldown expresses manual browsing.
	Showcase.browse(plot.showcase, now)
	return advance(plot, state, direction, now)
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
-- ClickDetector.MouseClick handles both desktop clicks and mobile taps, once per activation.
function PlayerPlot.bindCollectors(
	plot: Plot,
	onCollect: (Player, number, string) -> (),
	currentState: () -> Types.State?
)
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
		local function collect(actor: Player)
			local pos = position(actor)
			local id = target:GetAttribute("FigureId")
			local state = currentState()
			if
				plot.active
				and root.Parent == workspace
				and plot.model.Parent == root
				and folder.Parent == plot.model
				and target.Parent == folder
				and click.Parent == target
				and actor.UserId == plot.ownerId
				and pos
				and (pos - target.Position).Magnitude <= DisplayConfig.collectDistance
				and PlayerPlot.contains(plot, actor)
				and typeof(id) == "string"
				and id ~= ""
				and state
				and slot <= state.display.unlocked
				and state.display.slots[slot] == id
			then
				onCollect(actor, slot, id)
			end
		end
		table.insert(plot.connections, click.MouseClick:Connect(collect))
		local plate = plot.fixture.plates[slot]
		-- No character listeners or timers: resolve the current character on every contact.
		-- Retain only its identity and one timestamp per slot; respawn starts a fresh debounce.
		local lastCharacter: Model? = nil
		local lastTouch = -math.huge
		table.insert(
			plot.connections,
			plate.target.Touched:Connect(function(hit: BasePart)
				local character = hit:FindFirstAncestorOfClass("Model")
				local actor = if character then Players:GetPlayerFromCharacter(character) else nil
				local state = currentState()
				local pos = if actor then position(actor) else nil
				if
					not actor
					or not character
					or actor.Character ~= character
					or not pos
					or not state
				then
					return
				end
				local id = state.display.slots[slot]
				local delta = plate.target.CFrame:PointToObjectSpace(pos)
				if
					not (
						plot.active
						and root.Parent == workspace
						and plot.model.Parent == root
						and plot.fixture.model.Parent == plot.model
						and plate.model.Parent == plot.fixture.model
						and plate.target.Parent == plate.model
						and plot.fixture.plates[slot] == plate
						and actor.UserId == plot.ownerId
						and actor.Parent == Players
						and character:IsDescendantOf(workspace)
						and hit:IsDescendantOf(character)
						and slot <= state.display.unlocked
						and id
						and id ~= ""
						and state.owned[id]
						and PlayerPlot.contains(plot, actor)
						and math.abs(delta.X) <= plate.target.Size.X / 2 + 1
						and math.abs(delta.Z) <= plate.target.Size.Z / 2 + 1
						and delta.Y >= -1
						and delta.Y <= 6
					)
				then
					return
				end
				local now = os.clock()
				if
					lastCharacter == character
					and now - lastTouch < DisplayFixture.plate.debounce
				then
					return
				end
				lastCharacter, lastTouch = character, now
				onCollect(actor, slot, id)
			end)
		)
	end
end
function PlayerPlot.destroy(plot: Plot)
	cleanup(plot)
	plot.model:Destroy()
end
return PlayerPlot
