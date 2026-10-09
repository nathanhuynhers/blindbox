--!strict
-- Real geometry, contact authorization and transactions; signals/physics are shimmed.
local Engine = require("./PlotEngine")
local Plot = require("./PlayerPlot")
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local Economy = require("./Economy")
local Tutorial = require("./Tutorial")
local Geometry = require("./PlotGeometry")
local Fixture = require("./DisplayFixture")
local Layout = require("./TownLayout")
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local owner, visitor = Engine.player(401), Engine.player(402)
local plot = Plot.create(owner, 3)
local session = Transactions.new(0)
local activeSession = session
local ready, safe = true, true
local state = session.state
local ids = {}
local Catalog = require("./Catalog")
for index = 1, 6 do
	ids[index] = Catalog.figures[index].id
end
local requests = 0
Plot.bindCollectors(plot, function(actor, slot, id)
	check(actor == owner, "server contact resolves owner")
	requests += 1
	Transactions.process(session, {
		action = "Collect",
		id = "native:" .. requests,
		revision = state.revision,
		slot = slot,
		figure = id,
	}, 0, true, 0, 0, nil, true)
end, function()
	return if activeSession == session and ready and safe then state else nil
end)
local function root(player)
	return player.Character:FindFirstChild("HumanoidRootPart")
end
local function touch(slot, player)
	local target = plot.fixture.plates[slot].target
	player.Character:PivotTo(target.CFrame + Engine.Vector3.new(0, 3, 0))
	target.Touched:fire(root(player))
end
local function nextContact()
	Engine.clock += 1
	-- Keep economics at fixed time; burst/rate limits are covered by DisplayInteraction/FullGame.
	session.tokens = 4
end
for capacity = 3, 6 do
	state.display.unlocked = capacity
	for slot = 1, capacity do
		state.owned[ids[slot]], state.discovered[ids[slot]] = 1, true
		state.display.slots[slot] = ids[slot]
		state.earnings[ids[slot]] = slot * 10 + 0.75
	end
	Plot.render(plot, state)
	check(#plot.fixture.plates == 6, "exactly six retained slot plates at every capacity")
	local first = plot.fixture.plates[1].target
	local last = plot.fixture.plates[capacity].target
	local left = plot.transform:PointToObjectSpace(first.Position)
	local right = plot.transform:PointToObjectSpace(last.Position)
	check(math.abs(left.X + right.X) < 0.00001, "unlocked plates centered at width " .. capacity)
	for slot, plate in plot.fixture.plates do
		check(
			plate.target.CanTouch and not plate.base.CanTouch,
			"only the six targets keep touch listeners enabled across every slot state"
		)
		local localAt = plot.transform:PointToObjectSpace(plate.target.Position)
		check(
			math.abs(localAt.Z - (Geometry.displayZ + Fixture.plate.frontOffset)) < 0.00001,
			"plot-local plate depth"
		)
		check(
			not plate.target.CanCollide and not plate.base.CanCollide,
			"low inlays never obstruct movement"
		)
		check(
			#plate.model:GetChildren() == 2
				and plate.target:FindFirstChildOfClass("SurfaceGui") ~= nil,
			"two parts and one restrained native cue per plate"
		)
		if slot <= capacity then
			check(
				plate.coin.Visible and plate.cushion.Visible and plate.paws[1].Visible
					and plate.cue.Text == "COLLECT",
				"occupied plate shows its cushion, paws and coin"
			)
			local anchor = plot.display.anchors[tostring(slot)]
			local localAnchor = plot.transform:PointToObjectSpace(anchor.Position)
			check(
				math.abs(localAnchor.X - localAt.X) < 0.00001
					and math.abs(localAnchor.Z - localAt.Z) > 5,
				"each pad aligned under its own figure and clear of counter"
			)
			local before = state.coins
			local otherBanks = table.clone(state.earnings)
			nextContact()
			touch(slot, owner)
			check(
				state.coins == before + slot * 10 and state.earnings[ids[slot]] == 0.75,
				"slot " .. slot .. " transfers only its bank at capacity " .. capacity
			)
			for id, bank in otherBanks do
				if id ~= ids[slot] then
					check(state.earnings[id] == bank, "other banks unchanged")
				end
			end
		else
			local before = requests
			touch(slot, owner)
			check(
				requests == before
					and plate.target.Transparency == 1
					and not plate.cue.Visible
					and not plate.cushion.Visible
					and not plate.paws[1].Visible
					and not plate.coin.Visible,
				"locked plate cannot collect or advertise income"
			)
		end
	end
end
local target = plot.fixture.plates[1].target
local click = plot.collectors[1]:FindFirstChildOfClass("ClickDetector")
state.step = Tutorial.collect
state.earnings[ids[1]] = 100.5
nextContact()
local before, accepted = state.coins, requests
touch(1, visitor)
check(
	requests == accepted and state.coins == before and state.step == Tutorial.collect,
	"visitor changes neither profile nor quest"
)
touch(1, owner)
local foot = Engine.Instance.new("Part")
foot.Parent = owner.Character
for _ = 1, 50 do
	target.Touched:fire(if _ % 2 == 0 then foot else root(owner))
end
check(
	requests == accepted + 1 and state.coins == before + 100 and state.step == Tutorial.buy,
	"body-part spam debounced; only genuine collection advances quest"
)
-- Both native paths share the same non-yielding transaction/bank.
owner.Character:PivotTo(plot.collectors[1].CFrame)
click.MouseClick:fire(owner)
check(
	state.coins == before + 100 and state.earnings[ids[1]] == 0.5,
	"plate then click cannot double-transfer"
)
state.earnings[ids[1]] = 72.25
nextContact()
click.MouseClick:fire(owner)
before = state.coins
touch(1, owner)
check(
	state.coins == before and state.earnings[ids[1]] == 0.25,
	"click then plate cannot double-transfer"
)
state.earnings[ids[1]] = 20.75
state.coins = Economy.coinLimit
state.step = Tutorial.collect
nextContact()
touch(1, owner)
check(
	state.earnings[ids[1]] == 20.75 and state.step == Tutorial.collect,
	"full wallet preserves bank and quest"
)
state.coins -= 3
nextContact()
touch(1, owner)
check(
	state.coins == Economy.coinLimit and state.earnings[ids[1]] == 17.75,
	"nearly full wallet retains overflow and fraction"
)
state.coins = 0
state.step = Tutorial.collect
state.earnings[ids[1]] = 0.9
nextContact()
touch(1, owner)
check(
	state.coins == 0 and state.earnings[ids[1]] == 0.9 and state.step == Tutorial.collect,
	"fraction-only contact is not a genuine quest collection"
)
state.display.slots[1] = ""
Plot.render(plot, state)
accepted = requests
nextContact()
touch(1, owner)
check(
	requests == accepted
		and plot.fixture.plates[1].cue.Text == "—"
		and not plot.fixture.plates[1].coin.Visible
		and plot.fixture.plates[1].paws[1].BackgroundTransparency > 0,
	"empty plate is subdued and inactive"
)
state.display.slots[1] = ids[1]
Plot.render(plot, state)
-- Current state, rather than cached attributes or an old render, selects replacement targets.
local replacement = Catalog.figures[7].id
state.owned[replacement], state.discovered[replacement] = 1, true
state.earnings[ids[1]], state.earnings[replacement] = 99.5, 42.5
state.display.slots[1] = replacement
nextContact()
touch(1, owner)
check(
	state.coins == 42 and state.earnings[ids[1]] == 99.5 and state.earnings[replacement] == 0.5,
	"replacement resolved from current slot even before render"
)
Plot.render(plot, state)
local function rejected(message, mutate, restore)
	nextContact()
	local count, coins = requests, state.coins
	mutate()
	touch(1, owner)
	check(requests == count and state.coins == coins, message)
	restore()
end
rejected("paused storage rejected", function()
	ready = false
end, function()
	ready = true
end)
rejected("expired lease rejected", function()
	safe = false
end, function()
	safe = true
end)
rejected("stale session rejected", function()
	activeSession = Transactions.new(0)
end, function()
	activeSession = session
end)
local humanoid = owner.Character:FindFirstChildOfClass("Humanoid")
rejected("dead character rejected", function()
	humanoid.Health = 0
end, function()
	humanoid.Health = 100
end)
local plotParent, plateParent, fixtureParent =
	plot.model.Parent, target.Parent, plot.fixture.model.Parent
rejected("detached plot root rejected", function()
	plotParent.Parent = nil
end, function()
	plotParent.Parent = Engine.workspace
end)
rejected("removed plot rejected", function()
	plot.model.Parent = nil
end, function()
	plot.model.Parent = plotParent
end)
rejected("invalid plate ancestry rejected", function()
	target.Parent = plot.model
end, function()
	target.Parent = plateParent
end)
rejected("invalid fixture ancestry rejected", function()
	plot.fixture.model.Parent = Engine.workspace
end, function()
	plot.fixture.model.Parent = fixtureParent
end)
local characterParent = owner.Character.Parent
rejected("detached character rejected", function()
	owner.Character.Parent = nil
end, function()
	owner.Character.Parent = characterParent
end)
rejected("departing player rejected", function()
	owner.Parent = nil
end, function()
	owner.Parent = Engine.services.Players
end)
accepted = requests
nextContact()
owner.Character:PivotTo(target.CFrame + Engine.Vector3.new(5, 3, 0))
target.Touched:fire(root(owner))
owner.Character:PivotTo(target.CFrame + Engine.Vector3.new(0, 7, 0))
target.Touched:fire(root(owner))
check(requests == accepted, "physical footprint and vertical proximity required")
local oldRoot = root(owner)
local newCharacter = Engine.player(403).Character
Engine.players[403].Character = nil
owner.Character = newCharacter
accepted = requests
target.Touched:fire(oldRoot)
check(requests == accepted, "old character cannot collect after respawn")
state.earnings[replacement] = 10.5
touch(1, owner)
check(
	requests == accepted + 1 and state.earnings[replacement] == 0.5,
	"new character collects without rebinding"
)
state.earnings[replacement] = 8.5
Engine.clock += Fixture.plate.debounce + 0.01
touch(1, owner)
check(
	state.earnings[replacement] == 0.5,
	"normal consecutive contact accepted after short debounce"
)
local connections = Engine.connections
local parts, lights = 0, 0
for _, object in plot.model:GetDescendants() do
	if object:IsA("BasePart") and object:GetAttribute("FigureId") == nil then
		parts += 1
	end
	if object:IsA("Light") then
		lights += 1
	end
end
check(
	parts <= Layout.budgets.plotRuntimeParts and lights == 12,
	string.format(
		"plates and collectors fit the runtime part budget and add no lights (12 incl. floor fill): %d parts, %d lights",
		parts,
		lights
	)
)
check(
	#plot.fixture.plates * 8 == 48 and (#plot.connections - 1) * 8 == 96,
	"eight plots bound collection to 48 plates and 96 input connections"
)
for _ = 1, 30 do
	Plot.render(plot, state)
end
check(
	Engine.connections == connections and #plot.connections == 13,
	"one destruction and twelve bounded collection connections; renders add none"
)
accepted = requests
Plot.destroy(plot)
target.Touched:fire(root(owner))
click.MouseClick:fire(owner)
check(
	requests == accepted
		and target.dead
		and target.Parent == nil
		and #plot.connections == 0
		and Engine.connections == 0,
	"teardown destroys pads and disconnects all handlers"
)
print("PASS: " .. checks .. " collection plate checks (engine shim)")
