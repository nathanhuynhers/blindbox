--!strict
-- Runs real allocator, world, plot and targeted renderer; engine properties/signals are shimmed.
local Engine = require("./PlotEngine")
local Slots = require("./PlotSlots")
local Config = require("./PlotConfig")
local Geometry = require("./PlotGeometry")
local Fixture = require("./DisplayFixture")
local CollectionFixture = require("./CollectionFixture")
local PlotFixture = require("./PlotFixture")
local World = require("./World")
local Layout = require("./TownLayout")
local TownStyle = require("./TownStyle")
local TownProps = require("./TownProps")
local NightLights = require("./NightLights")
local PlotStyle = require("./PlotStyle")
local LeaderboardBoard = require("./LeaderboardBoard")
local Awning = require("./Awning")
local Plot = require("./PlayerPlot")
local Rules = require("./Rules")
local Profile = require("./Profile")
local Shelves = require("./Shelves")
local ShelfConfig = require("./ShelfConfig")
local function close(a, b)
	return math.abs(a - b) < 0.00001
end
local function move(player, plot, x, y, z)
	player.Character:PivotTo(plot.transform * Engine.CFrame.new(x, y, z))
end
local function dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
local function radius(position)
	return math.sqrt(position.X ^ 2 + position.Z ^ 2)
end
local function localPosition(transform, position)
	return transform:PointToObjectSpace(position)
end
local function count(map)
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end
local function same(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end
local checks = 0
local function check(value: boolean, message: string)
	assert(value, message)
	checks += 1
end
local allocator = Slots.new(Config.maxPlots)
local legacyBaseplate = Engine.Instance.new("Part")
legacyBaseplate.Name = "Baseplate"
legacyBaseplate.Size = Engine.Vector3.new(512, 20, 512)
legacyBaseplate.Position = Engine.Vector3.new(0, -10, 0)
legacyBaseplate.Parent = Engine.workspace
local built = World.create()
local world = built.root
local groundTop = Layout.groundTop
local function descendantParts(parent)
	local found = {}
	for _, node in parent:GetDescendants() do
		if node.ClassName == "Part" or node.ClassName == "SpawnLocation" then
			table.insert(found, node)
		end
	end
	return found
end
-- World-space corners of a part's oriented box.
local function corners(part)
	local list = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(
					list,
					part.CFrame:PointToWorldSpace(
						Engine.Vector3.new(x * part.Size.X / 2, y * part.Size.Y / 2, z * part.Size.Z / 2)
					)
				)
			end
		end
	end
	return list
end
local function insideAnyPlot(point)
	for index = 1, Config.maxPlots do
		local at = Geometry.transform(index):PointToObjectSpace(point)
		if math.abs(at.X) < Config.width / 2 and math.abs(at.Z) < Config.depth / 2 then
			return true
		end
	end
	return false
end
-- The walking corridor of every path, from the plaza center out to its plot entrance.
local function inPathCorridor(point, outer)
	for index = 1, Config.maxPlots do
		local axis = Geometry.radialTransform(index, 10, 0)
		local outward = -axis.LookVector
		local along = dot(point, outward)
		local lateral = math.abs(dot(point, axis.RightVector))
		if along > 0 and along < outer and lateral < Config.pathWidth / 2 then
			return true
		end
	end
	return false
end
check(Config.maxPlots == 8, "one server has exactly eight canonical plot slots")
local groups = {}
for _, child in world:GetChildren() do
	groups[child.Name] = child
end
for _, name in { "Ground", "MainPlaza", "Paths", "PlotSlots", "MarketStreet", "Gaps", "GardenEdge" } do
	check(groups[name] ~= nil, "world contains its " .. name .. " group")
end
check(#world:GetChildren() == 7, "world contains only the seven town groups")
check(world:FindFirstChild("WorldFoundation") == nil, "old recessed foundation is replaced by grass")
local worldParts = descendantParts(world)
check(
	#worldParts <= Layout.budgets.worldParts,
	string.format("static world stays within its part budget: %d", #worldParts)
)
print(string.format("World static parts: %d / %d", #worldParts, Layout.budgets.worldParts))
for _, part in worldParts do
	check(part.Anchored and part.CanTouch == false, "every world part is anchored and never touch-enabled")
	check(part.CanCollide or not part.CanQuery, "noncollidable decor is excluded from spatial queries")
end
for _, node in world:GetDescendants() do
	check(
		node.ClassName ~= "MeshPart" and node.ClassName ~= "UnionOperation" and node.ClassName ~= "Decal",
		"town uses native parts only"
	)
	check(
		not string.find(node.Name, "Store")
			and not string.find(node.Name, "Shop")
			and not string.find(node.Name, "House")
			and not string.find(node.Name, "Machine"),
		"no stores, townhouses, shops or box machines"
	)
end

-- Ground: grass island with a stone edge; platforms rest on the grass.
local ground = groups.Ground
local grass = ground:FindFirstChild("Grass")
local curb = ground:FindFirstChild("StoneCurb")
assert(grass and curb)
check(
	grass.Shape == "Cylinder"
		and grass.Material == "Grass"
		and close(grass.Position.Y + grass.Size.X / 2, groundTop)
		and close(grass.Size.Y, 2 * Layout.ground.radius),
	"grass top is the town ground plane"
)
check(
	curb.Size.Y > grass.Size.Y and curb.Position.Y + curb.Size.X / 2 < groundTop,
	"a stone curb edge rings the grass just below its surface"
)
check(
	Layout.ground.radius > Layout.edge.wallRadius + 1,
	"the grass extends beyond the boundary walls"
)
check(
	legacyBaseplate.Transparency == 1
		and legacyBaseplate.CanCollide
		and not legacyBaseplate.CanTouch
		and not legacyBaseplate.CanQuery
		and legacyBaseplate.Position.Y + legacyBaseplate.Size.Y / 2
			< Layout.soil.top - Layout.soil.thickness,
	"legacy Baseplate is hidden beneath the island"
)

-- Plaza: paved floor, the giant blind box, benches, planters, leaderboard and spawn.
local plaza = groups.MainPlaza
local plazaSurface = plaza:FindFirstChild("PlazaSurface")
local plazaTrim = plaza:FindFirstChild("PlazaTrim")
assert(plazaSurface and plazaTrim)
local plazaTop = plazaSurface.Position.Y + plazaSurface.Size.X / 2
local trimTop = plazaTrim.Position.Y + plazaTrim.Size.X / 2
check(
	close(plazaTop, Layout.plaza.surfaceTop)
		and close(trimTop, Layout.plaza.trimTop)
		and plazaTop > trimTop
		and plazaSurface.Material == "Pavement"
		and close(plazaSurface.Size.Y, 2 * Config.plazaRadius),
	"paved 100-stud plaza with a distinct trim plane"
)
check(
	close(plazaSurface.Position.Y - plazaSurface.Size.X / 2, groundTop),
	"plaza fills down to the grass"
)
local box = plaza:FindFirstChild("GiantBlindBox")
assert(box)
local body = box:FindFirstChild("Body")
local lid = box:FindFirstChild("Lid")
assert(body and lid)
local marks = 0
for _, gui in body:GetChildren() do
	if gui.ClassName == "SurfaceGui" then
		marks += 1
		check(gui:FindFirstChild("Mark").Text == "?", "giant box sides carry a question mark")
	end
end
check(marks == 4, "all four box sides show a question mark")
check(
	body.Color == TownStyle.colors.pink and body.Size.X == 18 and body.Size.Y == 16,
	"pastel pink giant box body"
)
local bodyTop = body.Position.Y + body.Size.Y / 2
check(
	lid.CFrame.LookVector.Y > 0.3 and lid.CFrame.LookVector.Y < 0.5,
	"lid is tilted open toward the front"
)
check(
	lid.Position.Y - lid.Size.Y / 2 > bodyTop,
	"lid is lifted as if popping open"
)
check(lid:FindFirstChild("Ribbon") == nil and box:FindFirstChild("LidRibbonA") ~= nil, "ribboned lid")
local sparkles = 0
for _, part in box:GetChildren() do
	if string.find(part.Name, "Sparkle") then
		sparkles += 1
		check(part.Material == "Neon" and not part.CanCollide, "noncolliding glowing sparkle accent")
	end
end
check(sparkles >= 3, "a few sparkle accents")
local furniture = { Bench = 0, Planter = 0 }
for _, child in plaza:GetChildren() do
	local kind = string.match(child.Name, "^(%a+)_%d+$")
	if kind == "Bench" or kind == "Planter" then
		furniture[kind] += 1
	end
end
check(furniture.Bench == 3 and furniture.Planter == 4, "three benches and four planters")
for _, part in descendantParts(plaza) do
	local planar = math.sqrt(part.Position.X ^ 2 + part.Position.Z ^ 2)
	if planar > Layout.landmark.baseRadius + 2 and part.ClassName == "Part" then
		for _, corner in corners(part) do
			check(
				not inPathCorridor(corner, Config.plazaRadius + 1),
				"plaza furniture and the leaderboard keep every path mouth clear: " .. part.Name
			)
		end
	end
end
local spawnLocations = {}
for _, node in Engine.nodes do
	if node.ClassName == "SpawnLocation" and not node.dead then
		table.insert(spawnLocations, node)
	end
end
check(#spawnLocations == 1 and spawnLocations[1] == built.spawn, "one plaza SpawnLocation")
local spawn = built.spawn
check(
	spawn.Neutral and spawn.Duration == 0 and spawn.Enabled and not spawn.CanCollide,
	"plaza spawn is a neutral flush pad without a force field"
)
check(
	radius(spawn.Position) < Config.plazaRadius - Layout.plaza.spawnSize
		and radius(spawn.Position) > Layout.landmark.baseRadius + Layout.plaza.spawnSize
		and math.abs(spawn.Position.Y + spawn.Size.Y / 2 - plazaTop) < 0.05,
	"plaza spawn sits flush on open paving clear of the giant box"
)

-- Leaderboard: two-sided, self-lit, between two path mouths.
local board = built.board
check(board.model.Parent == plaza and #board.faces == 2, "two-sided physical leaderboard on the plaza")
check(
	dot(board.panel.CFrame.LookVector, (Engine.Vector3.new(0, 0, 0) - board.panel.Position).Unit) > 0.95,
	"the front face looks toward the plaza center"
)
local faceNames = {}
for _, gui in board.panel:GetChildren() do
	if gui.ClassName == "SurfaceGui" then
		faceNames[gui.Face] = true
		check(gui.LightInfluence == 0 and not gui.AlwaysOnTop, "board stays readable at night")
	end
end
check(faceNames.Front and faceNames.Back, "SurfaceGuis on both board faces")
for _, face in board.faces do
	check(#face.rows == 5 and #face.dots == 3, "five rows and three page dots per face")
end
LeaderboardBoard.show(board, 2, "TOP COINS / SEC", { { name = "Ava", value = "12.5/s" } }, "All servers")
for _, face in board.faces do
	check(
		face.title.Text == "TOP COINS / SEC"
			and face.rows[1].name.Text == "Ava"
			and face.rows[1].value.Text == "12.5/s"
			and face.rows[2].name.Text == "—"
			and face.rows[5].value.Text == ""
			and face.status.Text == "All servers"
			and face.dots[2].BackgroundColor3 == TownStyle.colors.gold
			and face.dots[1].BackgroundColor3 ~= TownStyle.colors.gold,
		"both faces render the same page with placeholders for missing rows"
	)
end

-- Paths: radial, resting on the grass, just below the plot floor; four night bollards each.
local entranceRadius = Config.plotRadius - Config.depth / 2
local expectedPathLength = entranceRadius + Config.pathOverlap - (Config.plazaRadius - Config.pathOverlap)
local street = Layout.street
local bollards = 0
for index = 1, Config.maxPlots do
	local path = groups.Paths:FindFirstChild("Path_" .. index)
	assert(path)
	local surface = path:FindFirstChild("WalkingSurface")
	assert(surface)
	check(
		path:GetAttribute("PlotSlot") == index
			and surface.Size.X == Config.pathWidth
			and close(surface.Size.Z, expectedPathLength)
			and close(surface.Position.Y + surface.Size.Y / 2, Config.walkingY - 0.01)
			and close(surface.Position.Y - surface.Size.Y / 2, groundTop),
		"path keeps its width/length, rests on grass and sits just under the plot floor"
	)
	check(
		dot(surface.CFrame.LookVector, Engine.Vector3.new(-surface.Position.X, 0, -surface.Position.Z)) > 0,
		"every path points radially toward the plaza"
	)
	for pair, ring in Layout.path.bollardRadii do
		for _, sideName in { "Left", "Right" } do
			local bollard = path:FindFirstChild(string.format("Bollard_%d_%s", pair, sideName))
			assert(bollard)
			local lens = bollard:FindFirstChild("WarmLens")
			local light = lens:FindFirstChildOfClass("PointLight")
			assert(light)
			local at = Geometry.radialTransform(index, 1, 0):PointToObjectSpace(bollard:FindFirstChild("Base").Position)
			check(
				math.abs(at.X) - TownProps.style.bollard.width / 2 > Config.pathWidth / 2 + Layout.path.trimWidth,
				"bollards stand outside the walking width"
			)
			check(
				math.abs(at.Z + 1 - ring) < 0.001
					and math.abs(ring - street.radius) > street.curbWidth / 2 + 1,
				"bollards stay off Market Street"
			)
			check(not light.Shadows and light.Enabled == NightLights.isOn(), "bollard light follows the night state")
			bollards += 1
		end
	end
end
check(bollards == 32, "four bollards on each of the eight paths")

-- Market Street: cobbled ring crossing every path, with lanterns on both sides between paths.
local market = groups.MarketStreet
local cobbles, curbs, lanterns = 0, 0, 0
local pathTop = Config.walkingY - 0.01
for _, child in market:GetChildren() do
	local kind, number = string.match(child.Name, "^(%a+)_(%d+)$")
	if kind == "Cobbles" or kind == "Curb" then
		local width = if kind == "Cobbles" then street.width else street.curbWidth
		local top = child.Position.Y + child.Size.Y / 2
		local expected = (if kind == "Cobbles" then street.top else street.curbTop)
			+ (if tonumber(number) % 2 == 0 then street.stagger else 0)
		check(
			close(radius(child.Position), street.radius)
				and child.Size.Z == width
				and close(top, expected)
				and top > pathTop
				and close(child.Position.Y - child.Size.Y / 2, groundTop),
			"street segments ring the plaza above the paths and rest on grass"
		)
		check(
			child.Size.X / 2 >= (street.radius + width / 2) * math.tan(math.pi / street.segments),
			"segments overlap so the ring has no gaps"
		)
		check(child.Material == (if kind == "Cobbles" then "Cobblestone" else "Slate"), "cobbles over a stone curb")
		if kind == "Cobbles" then
			cobbles += 1
		else
			curbs += 1
		end
	elseif string.find(child.Name, "^Lantern_") then
		lanterns += 1
		local lens = child:FindFirstChild("Lens")
		check(lens:FindFirstChildOfClass("PointLight") ~= nil, "every lantern carries one light")
		local ring = radius(child:FindFirstChild("Post").Position)
		check(
			math.abs(ring - street.radius) > street.curbWidth / 2 + 0.5,
			"lanterns stand on the sidewalks beside the street"
		)
		for _, corner in corners(child:FindFirstChild("Base")) do
			check(not inPathCorridor(corner, entranceRadius), "lanterns stand between paths")
		end
	end
end
check(cobbles == street.segments and curbs == street.segments, "complete cobble and curb rings")
check(lanterns == 2 * Config.maxPlots, "two lanterns in every gap between paths")
check(
	street.radius - street.curbWidth / 2 > Config.plazaRadius + Layout.plaza.trimWidth
		and street.radius + street.curbWidth / 2 < entranceRadius,
	"Market Street lies between the plaza and the plot entrances"
)

-- Gaps and edge decor never intrude on plots, paths or the street.
local stacks, statues = 0, 0
for gap = 1, Config.maxPlots do
	local model = groups.Gaps:FindFirstChild("Gap_" .. gap)
	assert(model)
	local stack, statue = model:FindFirstChild("GiftBoxStack"), model:FindFirstChild("Statue")
	if gap % 2 == 1 then
		assert(stack)
		stacks += 1
		local boxes = 0
		for _, child in stack:GetChildren() do
			if child:FindFirstChild("Box") then
				boxes += 1
			end
		end
		check(boxes == 4 and stack:FindFirstChild("Tumbled") ~= nil, "three stacked boxes plus one tumbled box")
		check(stack:FindFirstChild("Top"):FindFirstChild("BowKnot") ~= nil, "the top box has a ribbon bow")
	else
		assert(statue)
		statues += 1
		check(statue:FindFirstChild("Head") ~= nil and statue:FindFirstChild("Pedestal") ~= nil, "figure on a pedestal")
	end
end
check(stacks == 4 and statues == 4, "gaps alternate gift-box stacks and statue gardens")
for _, group in { groups.Gaps, groups.GardenEdge } do
	for _, part in descendantParts(group) do
		if not string.find(part.Name, "^BoundaryWall") then
			for _, corner in corners(part) do
				check(not insideAnyPlot(corner), "decor stays outside every plot: " .. part.Name)
				check(not inPathCorridor(corner, entranceRadius + 1), "decor stays off every path: " .. part.Name)
				check(
					math.abs(radius(corner) - street.radius) > street.curbWidth / 2,
					"decor stays off Market Street: " .. part.Name
				)
			end
		end
	end
end
local edge = groups.GardenEdge
local hedges, walls, edgeTrees, plotStacks = 0, 0, 0, 0
for _, child in edge:GetChildren() do
	if string.find(child.Name, "^Hedge_") then
		hedges += 1
		check(
			child.Material == "Grass"
				and child.CanCollide
				and child.Size.X / 2
					>= (Layout.edge.hedgeRadius + Layout.edge.hedgeThickness / 2) * math.tan(math.pi / Layout.edge.hedgeSegments),
			"continuous colliding hedge ring"
		)
	elseif string.find(child.Name, "^BoundaryWall_") then
		walls += 1
		check(
			child.Transparency == 1
				and child.CanCollide
				and radius(child.Position) > Layout.edge.hedgeRadius + Layout.edge.hedgeThickness / 2
				and child.Size.Y >= 50
				and child.Size.X / 2
					>= (Layout.edge.wallRadius + 1) * math.tan(math.pi / Layout.edge.wallSegments),
			"tall invisible boundary walls close the ring behind the hedge"
		)
	elseif string.find(child.Name, "^EdgeTree_") then
		edgeTrees += 1
		check(radius(child:FindFirstChild("Trunk").Position) < Layout.edge.hedgeRadius, "tree line in front of the hedge")
	elseif string.find(child.Name, "^PlotBoxStack_") then
		plotStacks += 1
	end
end
check(hedges == Layout.edge.hedgeSegments and walls == Layout.edge.wallSegments, "complete hedge and wall rings")
check(edgeTrees == 3 * Config.maxPlots and plotStacks == Config.maxPlots, "tree line and one box stack behind each plot")

-- Night lights stay inside the budget and switch lens glow with the lights.
local staticLights = NightLights.lightCount()
check(
	staticLights == 32 + 2 * Config.maxPlots + 1 and staticLights + Config.maxPlots <= NightLights.budget,
	string.format("static night lights %d leave room for eight arch glows within %d", staticLights, NightLights.budget)
)
print(string.format("Static night lights: %d (+1 per active plot) / %d", staticLights, NightLights.budget))
local sampleBollard = groups.Paths:FindFirstChild("Path_1"):FindFirstChild("Bollard_1_Left")
local sampleLens = sampleBollard:FindFirstChild("WarmLens")
local dayColor = sampleLens.Color
NightLights.set(true)
check(
	sampleLens.Material == "Neon" and sampleLens:FindFirstChildOfClass("PointLight").Enabled and NightLights.isOn(),
	"dusk turns lights and lens glows on"
)
NightLights.set(false)
check(
	sampleLens.Material == "SmoothPlastic"
		and sampleLens.Color == dayColor
		and not sampleLens:FindFirstChildOfClass("PointLight").Enabled,
	"dawn restores daytime lenses and switches lights off"
)

-- Fixed plot platforms with potted plants outside the arch posts.
local platformParts = 0
for index = 1, Config.maxPlots do
	local platform = groups.PlotSlots:FindFirstChild("PlotSlot_" .. index)
	assert(platform)
	local transform = Geometry.transform(index)
	local floor = platform:FindFirstChild("WalkingSurface")
	local trim = platform:FindFirstChild("OakTrim")
	local base = platform:FindFirstChild("BaseCenter")
	assert(floor and trim and base)
	check(platform:GetAttribute("PlotSlot") == index, "every fixed slot owns one indexed platform model")
	check(
		floor.Material == "WoodPlanks" and floor.Color == PlotFixture.palette.floor,
		"quiet pale wood walking surface"
	)
	check(close(radius(transform.Position), Config.plotRadius), "plot centers stay on the 170-stud ring")
	check(
		dot(transform.LookVector, Engine.Vector3.new(-transform.Position.X, 0, -transform.Position.Z)) > 0,
		"plot local -Z faces the central plaza"
	)
	check(close(floor.Position.Y + floor.Size.Y / 2, transform.Position.Y), "floor keeps the anchor plane")
	check(
		close(trim.Position.Y + trim.Size.Y / 2, floor.Position.Y - floor.Size.Y / 2)
			and close(base.Position.Y + base.Size.Y / 2, trim.Position.Y - trim.Size.Y / 2),
		"layered platform without gaps"
	)
	check(close(base.Position.Y - base.Size.Y / 2, groundTop), "platform rests on the grass")
	local pieces = descendantParts(platform)
	check(#pieces == 18, "twelve platform parts plus two three-part potted plants")
	platformParts += #pieces
	for _, piece in pieces do
		local at = localPosition(transform, piece.Position)
		check(
			piece.Shape == "Cylinder" or piece.Shape == "Ball" or math.abs(at.X) + piece.Size.X / 2 <= Config.width / 2,
			"platform piece remains in plot-local width"
		)
		check(math.abs(at.Z) <= Config.depth / 2, "platform piece remains in plot-local depth")
	end
	for _, name in { "InnerAccentLeft", "InnerAccentRight", "InnerAccentFront", "InnerAccentBack" } do
		local accent = platform:FindFirstChild(name)
		check(
			not accent.CanCollide and accent.Color == PlotStyle.DefaultAccent,
			"inner accent uses the single default plot accent"
		)
	end
	for _, name in { "LeftPlanter", "RightPlanter" } do
		local pot = platform:FindFirstChild(name):FindFirstChild("Pot")
		local at = localPosition(transform, pot.Position)
		check(
			math.abs(at.X) - pot.Size.Y / 2 > PlotFixture.arch.postX + PlotFixture.arch.post / 2
				and math.abs(at.X) - pot.Size.Y / 2 > Config.pathWidth / 2
				and at.Z < -40,
			"potted plants flank the entrance outside the arch posts"
		)
	end
end
check(platformParts == 144, "eight fixed platforms use a bounded 144 native parts")
local used = {}
for id = 1, Config.maxPlots do
	local index = Slots.claim(allocator, id)
	assert(index)
	check(not used[index], "unique allocation")
	used[index] = true
end
check(
	Slots.claim(allocator, 100) == nil and Slots.claim(allocator, 1) == nil,
	"ninth player and duplicate in-flight owner are rejected"
)
Slots.release(allocator, 2)
check(Slots.claim(allocator, 100) == 2, "released slot is reusable")
local function projectionRadius(transform, axis)
	return Config.width / 2 * math.abs(dot(transform.RightVector, axis))
		+ Config.depth / 2 * math.abs(dot(transform.LookVector, axis))
end
for a = 1, Config.maxPlots do
	for b = a + 1, Config.maxPlots do
		local first, second = Geometry.transform(a), Geometry.transform(b)
		local delta = second.Position - first.Position
		local separated = false
		for _, axis in
			{ first.RightVector, first.LookVector, second.RightVector, second.LookVector }
		do
			if
				math.abs(dot(delta, axis))
				>= projectionRadius(first, axis) + projectionRadius(second, axis)
			then
				separated = true
			end
		end
		check(separated, "rotated neighboring plot footprints never overlap")
	end
end
local owner, guest = Engine.player(1), Engine.player(100)
local plot, other = Plot.create(owner, 1), Plot.create(guest, 2)
for index = 3, Config.maxPlots do
	local actor = Engine.player(index)
	local lightsBefore = NightLights.lightCount()
	local radialPlot = Plot.create(actor, index)
	check(NightLights.lightCount() == lightsBefore + 1, "an active plot adds exactly one arch glow")
	local radialState = Rules.new(0)
	Plot.render(radialPlot, radialState)
	local spawnAt = localPosition(radialPlot.transform, radialPlot.spawn.Position)
	local displayAt = localPosition(radialPlot.transform, radialPlot.fixture.parts.Counter.Position)
	local entranceAt = localPosition(radialPlot.transform, radialPlot.entrance.parts.Face.Position)
	local shelfAnchor = radialPlot.shelves.anchors["viewport:1/row:1/slot:1"]
	assert(shelfAnchor)
	check(
		close(spawnAt.X, PlotFixture.spawnPad.position.X)
			and close(spawnAt.Z, PlotFixture.spawnPad.position.Z)
			and close(spawnAt.Y, PlotFixture.spawnPad.height),
		"spawn sits above the flush spawn pad of radial plot " .. index
	)
	check(
		dot(radialPlot.spawn.LookVector, radialPlot.transform.LookVector) < 0,
		"players spawn facing into their plot, toward the Display"
	)
	check(
		close(displayAt.X, 0) and close(displayAt.Z, Geometry.displayZ),
		string.format(
			"Display remains at the outward rear of radial plot %d: %.3f, %.3f",
			index,
			displayAt.X,
			displayAt.Z
		)
	)
	check(
		close(entranceAt.X, 0) and entranceAt.Z < -40,
		"entrance remains on the inward edge of radial plot " .. index
	)
	check(
		close(localPosition(radialPlot.transform, shelfAnchor.Position).X, Geometry.shelfX),
		"Collection remains at its plot-local side on radial plot " .. index
	)
	check(
		#radialPlot.physicalShelves == 3
			and #radialPlot.collection.controls == 2
			and count(radialPlot.display.anchors) == 3,
		"Display and shelf carousel fixture systems initialize on radial plot " .. index
	)
	move(actor, radialPlot, 0, 4, 0)
	check(
		Plot.contains(radialPlot, actor),
		"plot-local interaction bounds operate on radial plot " .. index
	)
	local largest = Rules.new(0)
	largest.display.unlocked = 6
	largest.display.slots = { "", "", "", "", "", "" }
	Plot.render(radialPlot, largest)
	local runtimeParts = 0
	for _, part in descendantParts(radialPlot.model) do
		if not part:GetAttribute("SlotId") and part.Parent and not part.Parent:GetAttribute("SlotId") then
			runtimeParts += 1
		end
	end
	check(
		runtimeParts <= Layout.budgets.plotRuntimeParts,
		string.format("active plot fixtures stay within budget: %d", runtimeParts)
	)
	if index == 3 then
		print(string.format("Active plot runtime parts at 6 Display slots: %d / %d", runtimeParts, Layout.budgets.plotRuntimeParts))
	end
	Plot.destroy(radialPlot)
	check(NightLights.lightCount() == lightsBefore, "plot release returns its arch glow to the budget")
	Plot.destroy(radialPlot)
	check(NightLights.lightCount() == lightsBefore, "release is idempotent")
end
local state = Rules.new(0)
state.discovered["grove.star"] = true
state.owned["grove.star"] = 1
state.display.slots[1] = "grove.star"
state.discovered["tide.pearl"] = true
state.owned["tide.pearl"] = 1
state.display.slots[3] = "tide.pearl"
local otherState = Rules.new(0)
local shelfSlots = ShelfConfig.slots()
local firstAnchor = ShelfConfig.renderSlot(1, shelfSlots[1])
local secondAnchor = ShelfConfig.renderSlot(1, shelfSlots[2])
check(
	plot.model:GetAttribute("OwnerId") == 1 and other.model:GetAttribute("OwnerId") == 100,
	"world ownership independent of slot assignment"
)
local entrance = plot.entrance
check(#entrance.labels == 2, "the arch sign reads on both sides")
for _, label in entrance.labels do
	check(label.Text == "Player 1's Showroom", "arch sign uses DisplayName and Showroom terminology")
end
local faces = {}
for _, gui in entrance.parts.Face:GetChildren() do
	if gui.ClassName == "SurfaceGui" then
		faces[gui.Face] = true
		check(not gui.AlwaysOnTop, "integrated physical sign, not a floating billboard")
	end
end
check(faces.Front and faces.Back, "sign SurfaceGuis face the plaza and the plot")
check(
	entrance.parts.Face.Material == "SmoothPlastic" and entrance.parts.Frame.Material == "Wood",
	"warm white sign face and oak frame"
)
check(entrance.parts.Beam.Color == PlotStyle.DefaultAccent, "arch beam uses the plot accent")
local signBottom = localPosition(plot.transform, entrance.parts.Frame.Position).Y - entrance.parts.Frame.Size.Y / 2
check(signBottom >= 9, string.format("arch sign clears the walkway by %.1f studs", signBottom))
for _, name in { "LeftPost", "RightPost" } do
	local post = entrance.parts[name]
	local at = localPosition(plot.transform, post.Position)
	check(
		math.abs(at.X) - post.Size.X / 2 > Config.pathWidth / 2,
		"arch posts stand outside the path width"
	)
end
for _, piece in descendantParts(entrance.model) do
	local at = localPosition(plot.transform, piece.Position)
	local bottom = at.Y - piece.Size.Y / 2
	check(
		math.abs(at.X) + piece.Size.X / 2 <= Config.width / 2
			and math.abs(at.Z) + piece.Size.Z / 2 <= Config.depth / 2
			and at.Z + piece.Size.Z / 2 < -40,
		"arch stays on the inward plot edge, clear of fixtures"
	)
	if math.abs(at.X) - piece.Size.X / 2 < Config.pathWidth / 2 then
		check(
			bottom >= 9 or (piece == entrance.parts.Deck and piece.Size.Y <= 0.15),
			"nothing in the doorway sits below the arch clearance: " .. piece.Name
		)
	end
end
check(#descendantParts(entrance.model) == 10, "ten-part entrance arch")
check(#entrance.lights == 3 and entrance.lights[1].light ~= nil, "one sign glow plus two lamp lenses")
local pad = plot.spawnPad
for _, ring in descendantParts(pad) do
	local at = localPosition(plot.transform, ring.Position)
	check(
		not ring.CanCollide and not ring.CanQuery and at.Y + ring.Size.X / 2 <= 0.08,
		"spawn pad is flush and noncolliding"
	)
	check(
		math.abs(at.X) - ring.Size.Y / 2 > PlotFixture.arch.postX
			and at.X + ring.Size.Y / 2 < 0
			and at.Z - ring.Size.Y / 2 > PlotFixture.arch.z + 2
			and at.Z + ring.Size.Y / 2 < Geometry.displayZ - 10,
		"spawn pad sits on the open right floor, behind the arch and clear of the Display"
	)
end
check(descendantParts(pad)[1].Color == PlotStyle.DefaultAccent, "spawn pad uses the plot accent")
local unitCount = 0
for _, child in plot.collection.model:GetChildren() do
	check(
		not string.find(child.Name, "Wall") and not string.find(child.Name, "Entrance"),
		"open plot without wall or access entrance"
	)
	if string.find(child.Name, "ShelfPosition_") then
		unitCount += 1
	end
end
check(unitCount == 3, "three permanent physical shelf units")
for unit = 1, 3 do
	local shelf = plot.physicalShelves[unit]
	assert(shelf)
	for row = 1, 3 do
		local board = shelf:FindFirstChild("Row_" .. row)
		assert(board)
		local boardAt = localPosition(plot.transform, board.Position)
		check(
			close(boardAt.X, 40)
				and close(board.Size.Z, Geometry.shelfUnitPitch - 2 * CollectionFixture.style.post)
				and board.Size.X == 5,
			"shelf boards retain their plot-local Collection position"
		)
		for slot = 1, 3 do
			local key = ShelfConfig.renderSlot(unit, ShelfConfig.slotId(row, slot))
			local anchor = plot.shelves.anchors[key]
			assert(anchor)
			check(
				close(dot(anchor.LookVector, plot.transform.RightVector), -1),
				"stable shelf anchors face plot-local -X"
			)
			check(
				close(localPosition(plot.transform, anchor.Position).X, 40),
				"every shelf figure stays on its Collection installation"
			)
		end
	end
end
local anchorCount = 0
for _ in plot.shelves.anchors do
	anchorCount += 1
end
check(anchorCount == 27, "27 configured cosmetic anchors")
local collection = plot.collection
local headerFace = collection.model:FindFirstChild("HeaderFace")
assert(headerFace)
local collectionSign = headerFace:FindFirstChildOfClass("SurfaceGui")
assert(collectionSign)
check(
	collectionSign.Face == "Left"
		and not collectionSign.AlwaysOnTop
		and collection.header.Text == "COLLECTION",
	"permanent physical COLLECTION sign faces the central plot"
)
check(
	collection.header.Font == "GothamBlack" and collectionSign.LightInfluence == 0.35,
	"header shares the Display's readable understated sign treatment"
)
check(
	collection.model:FindFirstChild("ContinuousCanopy").Size.Z > 3 * Geometry.shelfUnitPitch,
	"continuous canopy joins the three distinct bays"
)
local function descendants(parent)
	local found = {}
	for _, child in parent:GetChildren() do
		table.insert(found, child)
		for _, nested in descendants(child) do
			table.insert(found, nested)
		end
	end
	return found
end
local fixtureNodes = descendants(collection.model)
local worldText, lights, parts = 0, 0, 0
for _, node in fixtureNodes do
	if node.ClassName == "TextLabel" then
		worldText += 1
		check(
			node.Text == "COLLECTION",
			"no physical index, zero-Coin copy or Previous/Next text remains"
		)
	end
	check(
		node.ClassName ~= "BillboardGui"
			and node.ClassName ~= "MeshPart"
			and node.ClassName ~= "ProximityPrompt",
		"Collection uses physical native geometry without floating labels or prompts"
	)
	if node.ClassName == "Part" then
		parts += 1
		for _, corner in corners(node) do
			local at = localPosition(plot.transform, corner)
			check(
				math.abs(at.X) < Config.width / 2 and math.abs(at.Z) < Config.depth / 2,
				"every Collection part including chevrons and awning stays within rotated plot bounds"
			)
		end
		check(
			node.Material == "Wood" or node.Material == "SmoothPlastic" or node.Material == "Fabric",
			"warm native wood/plastic/fabric only, no neon"
		)
	elseif node.ClassName == "SurfaceLight" then
		lights += 1
		check(
			node.Face == "Bottom"
				and node.Range == 5
				and node.Brightness == 0.35
				and not node.Shadows,
			"short subtle downward row washes have no shadows"
		)
	end
end
check(
	worldText == 1
		and lights == 9
		and parts == 58 + Awning.partCount(3 * Geometry.shelfUnitPitch + CollectionFixture.awning.endMargin),
	"one title, nine bounded row washes and fixed native-part budget"
)
for position, unit in plot.physicalShelves do
	local rows, anchors = 0, 0
	for _, child in unit:GetChildren() do
		if string.match(child.Name, "^Row_%d+$") then
			rows += 1
		end
	end
	for row = 1, 3 do
		local board = unit:FindFirstChild("Row_" .. row)
		local boardAt = localPosition(plot.transform, board.Position)
		for slot = 1, 3 do
			local anchor = plot.shelves.anchors[ShelfConfig.renderSlot(
				position,
				ShelfConfig.slotId(row, slot)
			)]
			local anchorAt = localPosition(plot.transform, anchor.Position)
			anchors += 1
			check(
				close(anchor.Position.Y, board.Position.Y + board.Size.Y / 2),
				"each anchor lies on its own board's top surface"
			)
			check(
				math.abs(anchorAt.Z - boardAt.Z) + 1.6 < board.Size.Z / 2,
				"even the widest current 3.2-stud figure fits between oak posts"
			)
		end
	end
	check(
		rows == 3 and anchors == 9,
		"each physical unit has exactly three rows and nine local anchors"
	)
end
for _, button in collection.controls do
	for _, accent in button.accents do
		check(
			accent.Color == CollectionFixture.palette.muted,
			"new three-unit fixture starts with muted controls"
		)
	end
end
Plot.render(plot, state)
local initialModel = plot.model
local initialFixture = plot.fixture.model
local initialCounter = plot.fixture.parts.Counter
local initialBack = plot.fixture.parts.BackPanel
local initialSign = plot.fixture.parts.SignFace
local initialShelves = plot.physicalShelves[1]
local initialShelfAnchor = plot.shelves.anchors[firstAnchor]
local fixtureCount = #initialFixture:GetChildren()
local sign = initialSign:FindFirstChildOfClass("SurfaceGui")
assert(sign)
check(
	sign.Face == "Front" and not sign.AlwaysOnTop and sign:FindFirstChild("Title").Text == "DISPLAY",
	"sign is an integrated front SurfaceGui with dark DISPLAY title"
)
local light = plot.fixture.parts.WarmDiffuser:FindFirstChildOfClass("SurfaceLight")
assert(light)
check(
	light.Face == "Bottom"
		and light.Brightness == 0.65
		and light.Color[1] > light.Color[3]
		and not light.Shadows,
	"one subtle downward warm wash, no shadow-heavy effect"
)
check(
	plot.fixture.parts.OakBase.Material == "Wood" and initialCounter.Material == "SmoothPlastic",
	"light wood base and smooth ivory counter"
)
check(
	plot.fixture.parts.RecessedPlinth.Size.Z < initialCounter.Size.Z,
	"charcoal plinth is recessed under shelf"
)
check(
	close(
		plot.fixture.parts.OakBase.Position.Y + plot.fixture.parts.OakBase.Size.Y / 2,
		initialCounter.Position.Y - initialCounter.Size.Y / 2
	),
	"wood and counter layers meet without floating gap"
)
local firstFigure, thirdFigure = plot.display.models["1"], plot.display.models["3"]
local created = Engine.figureCreates
for capacity = 3, 6 do
	state.display.unlocked = capacity
	if capacity > 3 then
		state.display.slots[capacity] = ""
	end
	local profileBefore = Profile.encode(state)
	Plot.render(plot, state)
	check(same(Profile.encode(state), profileBefore), "layout never mutates persisted state")
	check(Rules.rate(state) == 14.5, "unchanged Display income across capacity layout")
	check(
		count(plot.display.anchors) == capacity,
		"exact unlocked figure positions at capacity " .. capacity
	)
	check(
		plot.model == initialModel
			and plot.fixture.model == initialFixture
			and plot.fixture.parts.Counter == initialCounter
			and plot.fixture.parts.BackPanel == initialBack,
		"growth reuses plot and continuous fixture pieces"
	)
	local width = 12 + (capacity - 1) * 8
	check(
		initialCounter.Size.X == width
			and initialCounter.Size.Z == 8.5
			and initialBack.Size.X == width - 2,
		"counter and broad continuous back widen coherently"
	)
	check(
		plot.fixture.parts.OakBase.Size.X == width - 0.4
			and plot.fixture.parts.RecessedPlinth.Size.X == width - 1
			and plot.fixture.parts.TopFascia.Size.X == width + 0.5,
		"base, plinth and canopy widen together"
	)
	local counterAt = localPosition(plot.transform, initialCounter.Position)
	local signAt = localPosition(plot.transform, initialSign.Position)
	check(
		close(counterAt.X, 0) and close(counterAt.Z, 36),
		"fixture stays centered at the plot-local rear"
	)
	check(
		initialSign == plot.fixture.parts.SignFace
			and close(signAt.X, 0)
			and initialSign.Size.X == 12.65,
		"physical sign stays centered with fixed readable proportions"
	)
	check(
		#initialFixture:GetChildren() == fixtureCount,
		"capacity does not append pads, sections or extra lights"
	)
	check(
		plot.physicalShelves[1] == initialShelves
			and plot.shelves.anchors[firstAnchor] == initialShelfAnchor,
		"Display resize leaves shelves and their anchors untouched"
	)
	for _, piece in descendantParts(initialFixture) do
		for _, corner in corners(piece) do
			local at = localPosition(plot.transform, corner)
			check(
				math.abs(at.X) < Config.width / 2 and math.abs(at.Z) < Config.depth / 2,
				"every fixture piece including the awning stays inside rotated plot footprint"
			)
		end
	end
	local awning = plot.fixture.awning
	assert(awning)
	local canopy = awning:FindFirstChild("Canopy")
	local valance = awning:FindFirstChild("Valance")
	check(
		awning.Parent == initialFixture
			and close(canopy.Size.X, width + 2 * Fixture.awning.overhang)
			and #descendantParts(awning) == Awning.partCount(width + 2 * Fixture.awning.overhang),
		"one striped awning spans the Display at every capacity"
	)
	check(
		localPosition(plot.transform, valance.Position).Y - valance.Size.Y / 2
			> localPosition(plot.transform, initialSign.Position).Y + initialSign.Size.Y / 2,
		"awning valance stays above the DISPLAY sign"
	)
	local stripes = 0
	for _, stripe in awning:GetChildren() do
		if stripe.Name == "Stripe" then
			stripes += 1
			check(stripe.Color == PlotStyle.DefaultAccent and not stripe.CanCollide, "accent stripes")
		end
	end
	check(stripes == math.ceil(Awning.stripes(width + 2 * Fixture.awning.overhang) / 2), "alternating stripes")
	check(
		plot.fixture.rate.Text == "14.5 Coins/sec",
		"sign reads server-computed Display rate including fractions"
	)
	local sum = 0
	for slot = 1, capacity do
		local anchor = plot.display.anchors[tostring(slot)].Position
		local anchorAt = localPosition(plot.transform, anchor)
		sum += anchorAt.X
		check(
			close(anchorAt.X, (slot - (capacity + 1) / 2) * 8) and close(anchorAt.Z, 36),
			"centered plot-local one-row spacing at every capacity"
		)
		check(
			anchor.Y == initialCounter.Position.Y + initialCounter.Size.Y / 2,
			"every anchor sits on continuous counter top"
		)
		check(
			plot.model:FindFirstChild("DisplaySlot_" .. slot) == nil,
			"even active slots have no separate pedestal geometry"
		)
	end
	check(close(sum, 0), "visible row centered at capacity " .. capacity)
	for slot = capacity + 1, 6 do
		check(
			plot.model:FindFirstChild("DisplaySlot_" .. slot) == nil
				and plot.display.anchors[tostring(slot)] == nil,
			"locked slots have no physical geometry/labels/anchors"
		)
	end
	check(
		plot.display.models["1"] == firstFigure
			and plot.display.models["3"] == thirdFigure
			and Engine.figureCreates == created,
		"unchanged Display models reused while recentering"
	)
	for _, slot in { 1, 3 } do
		local figure = plot.display.models[tostring(slot)]
		local anchor = plot.display.anchors[tostring(slot)].Position
		local bounds, size = figure:GetBoundingBox()
		check(
			figure:GetAttribute("SlotId") == tostring(slot)
				and close(figure.Position.X, anchor.X)
				and close(bounds.Position.Y - size.Y / 2, anchor.Y)
				and close(figure.Position.Z, anchor.Z),
			"logical slot identity preserved and feet remain on counter"
		)
		check(
			figure:GetScale() == 2,
			"Display-only figure presentation is scaled once, without compounding"
		)
	end
end
Fixture.setRate(plot.fixture, 2)
check(plot.fixture.rate.Text == "2 Coins/sec", "reference sign wording at matching actual income")
Plot.render(plot, state)
check(
	plot.fixture.rate.Text == "14.5 Coins/sec",
	"live render restores authoritative income, not a hard-coded concept price"
)
for _, node in Engine.nodes do
	if node.Parent == initialFixture or node.Parent == initialCounter then
		check(
			node.ClassName ~= "BillboardGui" and node.ClassName ~= "MeshPart",
			"fixture has no floating HUD or custom mesh"
		)
	end
end
move(owner, plot, 0, 4, 28)
check(Plot.nearDisplay(plot, owner), "Display edit proximity follows back focal structure")
move(owner, plot, 0, 4, -14)
check(
	not Plot.nearDisplay(plot, owner),
	"old front Display location no longer grants editing proximity"
)
for _, unit in state.shelves.units do
	for _, slot in shelfSlots do
		unit.placements[slot] = "grove.star"
	end
end
Plot.render(plot, state)
local before = Engine.figureCreates
check(#plot.shelves.parent:GetChildren() == 27, "three visible units render 27 figures")
check(plot.shelves.models[firstAnchor]:GetScale() == 1, "shelf figure scale remains unchanged")
for key, model in plot.shelves.models do
	local bounds, size = model:GetBoundingBox()
	check(
		close(bounds.Position.Y - size.Y / 2, plot.shelves.anchors[key].Position.Y)
			and model:GetScale() == 1,
		"all 27 figures stand on boards without changing shelf scale"
	)
end
local unchangedModel = plot.shelves.models[secondAnchor]
Plot.render(plot, state)
check(Engine.figureCreates == before, "unchanged snapshot never clones figures")
state.discovered["tide.pearl"] = true
state.shelves.units[1].placements[shelfSlots[1]] = "tide.pearl"
Plot.render(plot, state)
check(
	Engine.figureCreates == before + 1 and plot.shelves.models[secondAnchor] == unchangedModel,
	"single edit touches one figure only"
)
local pearls = 0
for _, render in { plot.display, plot.shelves } do
	for _, id in render.ids do
		if id == "tide.pearl" then
			pearls += 1
		end
	end
end
Engine.figureVariants["tide.pearl"] = "production"
Plot.render(plot, state)
check(
	pearls > 0
		and Engine.figureCreates == before + 1 + pearls
		and plot.shelves.models[secondAnchor] == unchangedModel,
	"a ready production template rebuilds only the figures that use it"
)
Plot.render(plot, state)
check(
	Engine.figureCreates == before + 1 + pearls,
	"production figures persist across unchanged snapshots"
)
Engine.figureVariants["tide.pearl"] = nil
Plot.render(plot, state)
for index = 4, 5 do
	table.insert(state.shelves.units, {
		id = "shelf:" .. index,
		placements = { [shelfSlots[1]] = "tide.pearl" },
		customization = {},
	})
end
Plot.render(plot, state)
check(#plot.shelves.parent:GetChildren() == 27, "hidden units create no figures")
for _, button in collection.controls do
	for _, accent in button.accents do
		check(
			accent.Color == CollectionFixture.palette.diffuser,
			"more than three owned units enables warm chevrons and trim"
		)
	end
end
local children = #plot.model:GetChildren()
local retainedShelfFigure = plot.shelves.models[secondAnchor]
move(guest, plot, 32, 4, 0)
check(Plot.contains(plot, guest), "guest may walk into open plot without membership")
local guestAccess = Plot.access(plot, guest)
check(not Shelves.mutate(state, {
	action = "ShelfRemove",
	id = "x",
	revision = state.revision,
	shelfId = "shelf:1",
	carouselRevision = 0,
	shelfSlotId = shelfSlots[1],
}, guestAccess, 0), "visitor cannot edit owner shelves")
check(not Plot.nearDisplay(plot, guest), "visitor cannot edit host Display")
move(guest, plot, 0, 4, 36)
check(not Plot.nearDisplay(plot, guest), "visitor remains denied even beside host Display")
move(owner, plot, -45, 4, -40)
check(
	not Plot.access(plot, owner).near and Plot.canNavigate(plot, owner),
	"across-plot viewing range does not grant edit access"
)
check(not Shelves.mutate(state, {
	action = "ShelfRemove",
	id = "far",
	revision = state.revision,
	shelfId = "shelf:1",
	carouselRevision = 0,
	shelfSlotId = shelfSlots[1],
}, Plot.access(plot, owner), 0), "owner cannot edit shelves from long viewing distance")
move(owner, plot, 30, 4, -4)
check(Plot.access(plot, owner).near, "owner can still edit close to relocated shelves")
Plot.bind(plot, function(actor, direction)
	Plot.turn(plot, actor, state, direction, Engine.clock)
end)
Plot.render(plot, state)
local previous = plot.hitboxes[1]:FindFirstChildOfClass("ClickDetector")
local nextControl = plot.hitboxes[2]:FindFirstChildOfClass("ClickDetector")
assert(previous and nextControl)
for index, hitbox in plot.hitboxes do
	local arrow = plot.collection.controls[index].panel
	check(
		hitbox.Transparency == 1
			and not hitbox.CanCollide
			and not hitbox.CanTouch
			and hitbox.CanQuery,
		"transparent nonblocking target is queryable"
	)
	check(
		hitbox.Size.Y > arrow.Size.Y and hitbox.Size.Z > arrow.Size.Z and arrow.Size.Y == 6.8,
		"generous hitbox surrounds larger visible control"
	)
	check(
		hitbox:FindFirstChildOfClass("ClickDetector").MaxActivationDistance == 160,
		"mouse/touch activation spans a whole plot"
	)
end
for _, node in Engine.nodes do
	check(node.ClassName ~= "ProximityPrompt", "no proximity prompt exists")
end
local coins, revision = state.coins, state.revision
local savedBeforeTurns = Profile.encode(state)
move(owner, plot, -45, 4, -40)
Engine.clock = 1
nextControl.MouseClick:fire(owner)
check(
	plot.view.startIndex == 2,
	"owner click from normal long viewing distance advances shared viewport one unit"
)
check(
	plot.view.startIndex == 2
		and plot.physicalShelves[1]:GetAttribute("ShelfId") == "shelf:2"
		and plot.physicalShelves[3]:GetAttribute("ShelfId") == "shelf:4",
	"all viewers share the 2,3,4 viewport"
)
check(
	state.coins == coins and state.revision == revision and other.view.startIndex == 1,
	"carousel changes no progression or other plot"
)
check(
	#plot.model:GetChildren() == children and #plot.shelves.parent:GetChildren() == 19,
	"one-unit slide reuses three physical structures"
)
check(
	plot.shelves.models[secondAnchor] == retainedShelfFigure,
	"matching figure is reused at its physical position across viewport turn"
)
move(guest, plot, -48, 4, 40)
Engine.clock = 1.49
nextControl.MouseClick:fire(guest)
check(plot.view.startIndex == 2, "visitor click shares existing half-second cooldown")
Engine.clock = 1.5
nextControl.MouseClick:fire(guest)
check(plot.view.startIndex == 3, "visitor long-range click advances one at cooldown boundary")
Engine.clock = 2
previous.MouseClick:fire(guest)
check(plot.view.startIndex == 2, "visitor click moves back one unit")
check(
	same(Profile.encode(state), savedBeforeTurns),
	"clicking only changes runtime visibility, not shelf persistence or progression"
)
check(
	collection.header.Text == "COLLECTION" and #descendants(collection.model) == #fixtureNodes,
	"turning retains static header, furniture, trim and lighting"
)
local beforeRejected = plot.view.revision
for _, coords in { { 59, 4, 0 }, { 0, 4, 57 }, { 0, 21, 0 }, { 500, 4, 500 } } do
	move(guest, plot, coords[1], coords[2], coords[3])
	Engine.clock += 1
	nextControl.MouseClick:fire(guest)
	check(
		plot.view.revision == beforeRejected,
		"out-of-area or elevated forged click denied on server"
	)
end
move(guest, plot, 58, 4, 0)
Engine.clock += 1
nextControl.MouseClick:fire(guest)
check(plot.view.startIndex == 3, "small eight-stud perimeter margin allows nearby viewing")
for step = 1, 5 do
	Engine.clock += 1
	nextControl.MouseClick:fire(guest)
	local visibleUnits = Shelves.publicView(state.shelves, plot.view).visible
	for position, unit in visibleUnits do
		check(
			plot.physicalShelves[position]:GetAttribute("ShelfId") == unit.id,
			"each physical position tracks the current persistent unit ID"
		)
		for _, localSlot in shelfSlots do
			local expected = state.shelves.units[unit.index].placements[localSlot]
			local rendered = plot.shelves.ids[ShelfConfig.renderSlot(position, localSlot)]
			check(
				rendered == expected,
				"all placements follow their persistent shelf through every physical position and wrap"
			)
		end
	end
end
for _, direction in { 0, 2, math.huge, 0 / 0 } do
	check(not Plot.turn(plot, guest, state, direction, 100), "invalid carousel direction rejected")
end
local humanoid = guest.Character:FindFirstChildOfClass("Humanoid")
humanoid.Health = 0
check(not Plot.turn(plot, guest, state, 1, 100), "dead actor cannot rotate shelves")
humanoid.Health = 100
local character = guest.Character
guest.Character = nil
check(not Plot.turn(plot, guest, state, 1, 100), "missing character cannot rotate shelves")
guest.Character = character
guest.Character:PivotTo(other.spawn)
check(not Plot.turn(plot, guest, state, 1, 4), "distant shelf rotation rejected")
local snapshot = Shelves.publicView(state.shelves, plot.view)
check(
	snapshot.coins == nil and snapshot.owned == nil and snapshot.discovered == nil,
	"shelf projection excludes private data"
)
local encoded = Profile.encode(state)
check(
	encoded.plotIndex == nil and encoded.startIndex == nil and encoded.shelves.startIndex == nil,
	"plot allocation and carousel state never persisted"
)
local restored = Profile.decode(encoded, 100)
assert(restored)
local staleDetector, staleHitbox = previous, plot.hitboxes[1]
Plot.destroy(plot)
Slots.release(allocator, owner.UserId)
check(
	not plot.active and plot.model.Parent == nil and #plot.connections == 0,
	"departing owner content and connections cleaned"
)
local newIndex = Slots.claim(allocator, 200)
check(newIndex == 1, "new join reclaims same physical slot")
local newOwner = Engine.player(200)
local replacement = Plot.create(newOwner, newIndex)
Plot.render(replacement, restored)
check(
	replacement.view.startIndex == 1 and replacement.shelves.ids[firstAnchor] == "tide.pearl",
	"saved shelf placements render independently of runtime allocation"
)
staleDetector.MouseClick:fire(newOwner)
check(
	replacement.view.startIndex == 1
		and staleDetector.dead
		and staleHitbox.dead
		and staleHitbox.Parent == nil,
	"stale detector and hitbox destroyed, cannot mutate replacement plot"
)
move(newOwner, replacement, 0, 4, 0)
local parent = replacement.model.Parent
replacement.model.Parent = nil
check(
	not Plot.turn(replacement, newOwner, restored, 1, 100),
	"detached runtime plot cannot be navigated"
)
replacement.model.Parent = parent
move(guest, other, 0, 4, 0)
check(
	not Plot.turn(other, guest, otherState, 1, 100) and other.view.revision == 0,
	"three-unit arrows are inactive"
)
Plot.bind(other, function(actor, direction)
	Plot.turn(other, actor, otherState, direction, Engine.clock)
end)
Plot.render(other, otherState)
for _, target in other.hitboxes do
	check(
		target:FindFirstChildOfClass("ClickDetector").MaxActivationDistance == 0,
		"three owned units disable physical navigation"
	)
end
for index = 6, 250 do
	table.insert(
		restored.shelves.units,
		{ id = "shelf:" .. index, placements = {}, customization = {} }
	)
end
local structureCount = #replacement.model:GetChildren()
Plot.render(replacement, restored)
check(
	#replacement.model:GetChildren() == structureCount
		and #descendants(replacement.collection.model) == #fixtureNodes
		and #replacement.shelves.parent:GetChildren() == 27,
	"250 owned units still render three structures and at most 27 figures"
)
check(
	#other.shelves.parent:GetChildren() == 0 and otherState.coins == 450,
	"other owner's state stays isolated"
)
Plot.destroy(other)
Plot.destroy(replacement)
world:Destroy()
check(Engine.connections == 0, "no owned connections remain")
print(
	string.format("PASS: %d plot allocation/geometry/render/lifecycle checks (engine shim)", checks)
)
