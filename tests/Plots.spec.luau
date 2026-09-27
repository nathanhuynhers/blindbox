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
local Plot = require("./PlayerPlot")
local Rules = require("./Rules")
local Profile = require("./Profile")
local Shelves = require("./Shelves")
local ShelfConfig = require("./ShelfConfig")
local function close(a, b) return math.abs(a-b) < 0.00001 end
local function move(player, plot, x, y, z)
	player.Character:PivotTo(Engine.CFrame.new(plot.origin + Engine.Vector3.new(x,y,z)))
end
local function count(map) local n = 0; for _ in map do n += 1 end; return n end
local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in a do if not same(value, b[key]) then return false end end
	for key in b do if a[key] == nil then return false end end
	return true
end
local checks = 0
local function check(value: boolean, message: string) assert(value, message); checks += 1 end
local allocator = Slots.new(Config.maxPlots)
local world = World.create()
check(#world:GetChildren() == Config.maxPlots + 1, "exact configured set of plot pads and shared ground")
local platformParts = 0
for index = 1, Config.maxPlots do
	local platform = world:FindFirstChild("PlotSlot_" .. index); assert(platform)
	check(platform.ClassName == "Model" and platform:GetAttribute("PlotSlot") == index, "every fixed slot owns one indexed platform model")
	local floor = platform:FindFirstChild("WalkingSurface"); assert(floor)
	local trim = platform:FindFirstChild("OakTrim"); assert(trim)
	local base = platform:FindFirstChild("BaseCenter"); assert(base)
	check(floor.Material == "WoodPlanks" and floor.Color == PlotFixture.palette.floor, "quiet pale wood walking surface")
	check(trim.Material == "Wood" and trim.Color == PlotFixture.palette.oak, "thin pale-oak perimeter layer")
	check(base.Material == "SmoothPlastic" and base.Color == PlotFixture.palette.ivory, "warm off-white structural base")
	check(close(floor.Position.Y + floor.Size.Y/2, Geometry.origin(index).Y), "new floor preserves the established fixture and anchor plane")
	check(close(trim.Position.Y + trim.Size.Y/2, floor.Position.Y-floor.Size.Y/2), "oak trim meets the walking surface without a gap")
	check(close(base.Position.Y + base.Size.Y/2, trim.Position.Y-trim.Size.Y/2), "off-white base meets the oak trim without a gap")
	check(floor.Size.X == 94 and floor.Size.Z == 90 and trim.Size.X == 96 and trim.Size.Z == 92, "layered insets leave restrained visible borders")
	local pieces = platform:GetChildren()
	check(#pieces == 12, "bounded twelve-part platform construction")
	platformParts += #pieces
	for _, piece in pieces do
		check(math.abs(piece.Position.X-Geometry.origin(index).X)+piece.Size.X/2 <= Config.width/2 or piece.Shape == "Cylinder", "platform piece remains in logical width")
		check(math.abs(piece.Position.Z-Geometry.origin(index).Z)+piece.Size.Z/2 <= Config.depth/2, "platform piece remains in logical depth")
		check(piece.Material ~= "Neon", "plot accent uses color rather than Neon")
	end
	for _, name in {"InnerAccentLeft","InnerAccentRight","InnerAccentFront","InnerAccentBack"} do
		local accent = platform:FindFirstChild(name); assert(accent)
		check(not accent.CanCollide and accent.Material == "SmoothPlastic" and accent.Color == PlotFixture.palette.accent, "subtle noncolliding warm inner accent")
	end
end
check(platformParts == 288, "24 fixed platforms use a bounded 288 native parts")
local used = {}
for id = 1, Config.maxPlots do
	local index = Slots.claim(allocator, id); assert(index)
	check(not used[index], "unique allocation"); used[index] = true
end
check(Slots.claim(allocator, 100) == nil and Slots.claim(allocator, 1) == nil, "full server and duplicate in-flight owner rejected")
Slots.release(allocator, 2)
check(Slots.claim(allocator, 100) == 2, "released slot is reusable")
for a = 1, Config.maxPlots do
	for b = a + 1, Config.maxPlots do
		local p, q = Geometry.origin(a), Geometry.origin(b)
		check(math.abs(p.X-q.X) >= Config.width + Config.gap or math.abs(p.Z-q.Z) >= Config.depth + Config.gap, "plot footprints never overlap")
	end
end
local owner, guest = Engine.player(1), Engine.player(100)
local plot, other = Plot.create(owner, 1), Plot.create(guest, 2)
local state = Rules.new(0); state.discovered["grove.star"] = true
state.owned["grove.star"] = 1; state.display.slots[1] = "grove.star"
state.discovered["tide.pearl"] = true; state.owned["tide.pearl"] = 1; state.display.slots[3] = "tide.pearl"
local otherState = Rules.new(0)
local shelfSlots = ShelfConfig.slots()
local firstAnchor = ShelfConfig.renderSlot(1, shelfSlots[1])
local secondAnchor = ShelfConfig.renderSlot(1, shelfSlots[2])
check(plot.model:GetAttribute("OwnerId") == 1 and other.model:GetAttribute("OwnerId") == 100, "world ownership independent of slot assignment")
local entrance = plot.entrance
local plaqueGui = entrance.parts.Face:FindFirstChildOfClass("SurfaceGui"); assert(plaqueGui)
check(entrance.label.Text == "Player 1's Showroom", "entrance plaque uses DisplayName and Showroom terminology")
check(not string.find(entrance.label.Text, "Collection") and not string.find(entrance.label.Text, "Plot"), "entrance avoids conflicting Collection and placeholder Plot labels")
check(plaqueGui.Face == "Front" and not plaqueGui.AlwaysOnTop and plaqueGui.LightInfluence == 0.35, "integrated physical plaque faces the entrance")
check(entrance.parts.Face.Material == "SmoothPlastic" and entrance.parts.Frame.Material == "Wood", "warm white plaque and pale-oak frame")
check(entrance.parts.Deck.Position.Y-entrance.parts.Deck.Size.Y/2 == plot.origin.Y, "entrance deck meets the walking plane with only a shallow step")
check(#entrance.model:GetChildren() == 7, "entrance uses seven physical pieces and no duplicate billboard")
for _, piece in entrance.model:GetChildren() do
	if piece.ClassName == "Part" then
		check(math.abs(piece.Position.X-plot.origin.X)+piece.Size.X/2 <= Config.width/2 and math.abs(piece.Position.Z-plot.origin.Z)+piece.Size.Z/2 <= Config.depth/2, "entrance treatment remains inside its plot")
		check(piece.Position.Z+piece.Size.Z/2 < plot.origin.Z-40, "entrance pieces stay clear of all Display and Collection expansion areas")
	end
end
local unitCount = 0
for _, child in plot.collection.model:GetChildren() do
	check(not string.find(child.Name, "Wall") and not string.find(child.Name, "Entrance"), "open plot without wall or access entrance")
	if string.find(child.Name, "ShelfPosition_") then unitCount += 1 end
end
check(unitCount == 3, "three permanent physical shelf units")
for unit = 1, 3 do
	local shelf = plot.physicalShelves[unit]; assert(shelf)
	for row = 1, 3 do
		local board = shelf:FindFirstChild("Row_" .. row); assert(board)
		check(board.Position.X == plot.origin.X + 40 and close(board.Size.Z, Geometry.shelfUnitPitch - 2 * CollectionFixture.style.post) and board.Size.X == 5, "shelf boards lie left of the entrance's +Z facing direction")
		for slot = 1, 3 do
			local key = ShelfConfig.renderSlot(unit, ShelfConfig.slotId(row, slot))
			local anchor = plot.shelves.anchors[key]; assert(anchor)
			check(close(anchor.LookVector.X, -1) and close(anchor.LookVector.Z, 0), "stable shelf anchors face -X into plot")
			check(anchor.Position.X == plot.origin.X + 40, "every shelf figure stays on left collection installation")
		end
	end
end
local anchorCount = 0; for _ in plot.shelves.anchors do anchorCount += 1 end
check(anchorCount == 27, "27 configured cosmetic anchors")
local collection = plot.collection
local headerFace = collection.model:FindFirstChild("HeaderFace"); assert(headerFace)
local collectionSign = headerFace:FindFirstChildOfClass("SurfaceGui"); assert(collectionSign)
check(collectionSign.Face == "Left" and not collectionSign.AlwaysOnTop and collection.header.Text == "COLLECTION", "permanent physical COLLECTION sign faces the central plot")
check(collection.header.Font == "GothamBlack" and collectionSign.LightInfluence == 0.35, "header shares the Display's readable understated sign treatment")
check(collection.model:FindFirstChild("ContinuousCanopy").Size.Z > 3 * Geometry.shelfUnitPitch, "continuous canopy joins the three distinct bays")
local function descendants(parent)
	local found = {}
	for _, child in parent:GetChildren() do
		table.insert(found, child)
		for _, nested in descendants(child) do table.insert(found, nested) end
	end
	return found
end
local fixtureNodes = descendants(collection.model)
local worldText, lights, parts = 0, 0, 0
for _, node in fixtureNodes do
	if node.ClassName == "TextLabel" then
		worldText += 1
		check(node.Text == "COLLECTION", "no physical index, zero-Coin copy or Previous/Next text remains")
	end
	check(node.ClassName ~= "BillboardGui" and node.ClassName ~= "MeshPart" and node.ClassName ~= "ProximityPrompt", "Collection uses physical native geometry without floating labels or prompts")
	if node.ClassName == "Part" then
		parts += 1
		local angle = math.rad(if node.Orientation then node.Orientation.X else 0)
		local halfZ = (math.abs(math.sin(angle))*node.Size.Y + math.abs(math.cos(angle))*node.Size.Z)/2
		check(math.abs(node.Position.X-plot.origin.X)+node.Size.X/2 < Config.width/2 and math.abs(node.Position.Z-plot.origin.Z)+halfZ < Config.depth/2, "every Collection part including rotated chevrons stays within plot bounds")
		check(node.Material == "Wood" or node.Material == "SmoothPlastic", "warm native wood/plastic only, no neon")
	elseif node.ClassName == "SurfaceLight" then
		lights += 1
		check(node.Face == "Bottom" and node.Range == 5 and node.Brightness == 0.35 and not node.Shadows, "short subtle downward row washes have no shadows")
	end
end
check(worldText == 1 and lights == 9 and parts == 56, "one title, nine bounded row washes and fixed native-part budget")
for position, unit in plot.physicalShelves do
	local rows, anchors = 0, 0
	for _, child in unit:GetChildren() do if string.match(child.Name, "^Row_%d+$") then rows += 1 end end
	for row = 1, 3 do
		local board = unit:FindFirstChild("Row_" .. row)
		for slot = 1, 3 do
			local anchor = plot.shelves.anchors[ShelfConfig.renderSlot(position, ShelfConfig.slotId(row,slot))]
			anchors += 1
			check(close(anchor.Position.Y, board.Position.Y + board.Size.Y/2), "each anchor lies on its own board's top surface")
			check(math.abs(anchor.Position.Z-board.Position.Z)+1.6 < board.Size.Z/2, "even the widest current 3.2-stud figure fits between oak posts")
		end
	end
	check(rows == 3 and anchors == 9, "each physical unit has exactly three rows and nine local anchors")
end
for _, button in collection.controls do
	for _, accent in button.accents do check(accent.Color == CollectionFixture.palette.muted, "new three-unit fixture starts with muted controls") end
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
local sign = initialSign:FindFirstChildOfClass("SurfaceGui"); assert(sign)
check(sign.Face == "Front" and not sign.AlwaysOnTop and sign:FindFirstChild("Title").Text == "DISPLAY", "sign is an integrated front SurfaceGui with dark DISPLAY title")
local light = plot.fixture.parts.WarmDiffuser:FindFirstChildOfClass("SurfaceLight"); assert(light)
check(light.Face == "Bottom" and light.Brightness == 0.65 and light.Color[1] > light.Color[3] and not light.Shadows, "one subtle downward warm wash, no shadow-heavy effect")
check(plot.fixture.parts.OakBase.Material == "Wood" and initialCounter.Material == "SmoothPlastic", "light wood base and smooth ivory counter")
check(plot.fixture.parts.RecessedPlinth.Size.Z < initialCounter.Size.Z, "charcoal plinth is recessed under shelf")
check(close(plot.fixture.parts.OakBase.Position.Y + plot.fixture.parts.OakBase.Size.Y/2, initialCounter.Position.Y - initialCounter.Size.Y/2), "wood and counter layers meet without floating gap")
local firstFigure, thirdFigure = plot.display.models["1"], plot.display.models["3"]
local created = Engine.figureCreates
for capacity = 3, 6 do
	state.display.unlocked = capacity
	if capacity > 3 then state.display.slots[capacity] = "" end
	local profileBefore = Profile.encode(state)
	Plot.render(plot, state)
	check(same(Profile.encode(state), profileBefore), "layout never mutates persisted state")
	check(Rules.rate(state) == 14.5, "unchanged Display income across capacity layout")
	check(count(plot.display.anchors) == capacity, "exact unlocked figure positions at capacity " .. capacity)
	check(plot.model == initialModel and plot.fixture.model == initialFixture and plot.fixture.parts.Counter == initialCounter and plot.fixture.parts.BackPanel == initialBack, "growth reuses plot and continuous fixture pieces")
	local width = 12 + (capacity - 1)*8
	check(initialCounter.Size.X == width and initialCounter.Size.Z == 8.5 and initialBack.Size.X == width-2, "counter and broad continuous back widen coherently")
	check(plot.fixture.parts.OakBase.Size.X == width-0.4 and plot.fixture.parts.RecessedPlinth.Size.X == width-1 and plot.fixture.parts.TopFascia.Size.X == width+0.5, "base, plinth and canopy widen together")
	check(initialCounter.Position.X == plot.origin.X and initialCounter.Position.Z == plot.origin.Z + 36, "fixture stays centered at the back")
	check(initialSign == plot.fixture.parts.SignFace and initialSign.Position.X == plot.origin.X and initialSign.Size.X == 12.65, "physical sign stays centered with fixed readable proportions")
	check(#initialFixture:GetChildren() == fixtureCount, "capacity does not append pads, sections or extra lights")
	check(plot.physicalShelves[1] == initialShelves and plot.shelves.anchors[firstAnchor] == initialShelfAnchor, "Display resize leaves shelves and their anchors untouched")
	for _, piece in initialFixture:GetChildren() do
		check(math.abs(piece.Position.X-plot.origin.X) + piece.Size.X/2 < Config.width/2 and math.abs(piece.Position.Z-plot.origin.Z) + piece.Size.Z/2 < Config.depth/2, "every fixture piece stays inside plot footprint")
	end
	check(plot.fixture.rate.Text == "14.5 Coins/sec", "sign reads server-computed Display rate including fractions")
	local sum = 0
	for slot = 1, capacity do
		local anchor = plot.display.anchors[tostring(slot)].Position
		sum += anchor.X - plot.origin.X
		check(anchor.X - plot.origin.X == (slot - (capacity+1)/2)*8 and anchor.Z == plot.origin.Z + 36, "centered one-row spacing at every capacity")
		check(anchor.Y == initialCounter.Position.Y + initialCounter.Size.Y/2, "every anchor sits on continuous counter top")
		check(plot.model:FindFirstChild("DisplaySlot_" .. slot) == nil, "even active slots have no separate pedestal geometry")
	end
	check(close(sum, 0), "visible row centered at capacity " .. capacity)
	for slot = capacity + 1, 6 do
		check(plot.model:FindFirstChild("DisplaySlot_" .. slot) == nil and plot.display.anchors[tostring(slot)] == nil, "locked slots have no physical geometry/labels/anchors")
	end
	check(plot.display.models["1"] == firstFigure and plot.display.models["3"] == thirdFigure and Engine.figureCreates == created, "unchanged Display models reused while recentering")
	for _, slot in {1,3} do
		local figure = plot.display.models[tostring(slot)]
		local anchor = plot.display.anchors[tostring(slot)].Position
		local bounds, size = figure:GetBoundingBox()
		check(figure:GetAttribute("SlotId") == tostring(slot) and close(figure.Position.X, anchor.X) and close(bounds.Position.Y-size.Y/2, anchor.Y) and close(figure.Position.Z, anchor.Z), "logical slot identity preserved and feet remain on counter")
		check(figure:GetScale() == 2, "Display-only figure presentation is scaled once, without compounding")
	end
end
Fixture.setRate(plot.fixture, 2)
check(plot.fixture.rate.Text == "2 Coins/sec", "reference sign wording at matching actual income")
Plot.render(plot, state)
check(plot.fixture.rate.Text == "14.5 Coins/sec", "live render restores authoritative income, not a hard-coded concept price")
for _, node in Engine.nodes do
	if node.Parent == initialFixture or node.Parent == initialCounter then
		check(node.ClassName ~= "BillboardGui" and node.ClassName ~= "MeshPart", "fixture has no floating HUD or custom mesh")
	end
end
move(owner, plot, 0,4,28)
check(Plot.nearDisplay(plot, owner), "Display edit proximity follows back focal structure")
move(owner, plot, 0,4,-14)
check(not Plot.nearDisplay(plot, owner), "old front Display location no longer grants editing proximity")
for _, unit in state.shelves.units do
	for _, slot in shelfSlots do unit.placements[slot] = "grove.star" end
end
Plot.render(plot, state)
local before = Engine.figureCreates
check(#plot.shelves.parent:GetChildren() == 27, "three visible units render 27 figures")
check(plot.shelves.models[firstAnchor]:GetScale() == 1, "shelf figure scale remains unchanged")
for key, model in plot.shelves.models do
	local bounds, size = model:GetBoundingBox()
	check(close(bounds.Position.Y-size.Y/2, plot.shelves.anchors[key].Position.Y) and model:GetScale() == 1, "all 27 figures stand on boards without changing shelf scale")
end
local unchangedModel = plot.shelves.models[secondAnchor]
Plot.render(plot, state)
check(Engine.figureCreates == before, "unchanged snapshot never clones figures")
state.discovered["tide.pearl"] = true; state.shelves.units[1].placements[shelfSlots[1]] = "tide.pearl"
Plot.render(plot, state)
check(Engine.figureCreates == before + 1 and plot.shelves.models[secondAnchor] == unchangedModel, "single edit touches one figure only")
for index = 4, 5 do
	table.insert(state.shelves.units, { id = "shelf:" .. index, placements = { [shelfSlots[1]] = "tide.pearl" }, customization = {} })
end
Plot.render(plot, state)
check(#plot.shelves.parent:GetChildren() == 27, "hidden units create no figures")
for _, button in collection.controls do
	for _, accent in button.accents do check(accent.Color == CollectionFixture.palette.diffuser, "more than three owned units enables warm chevrons and trim") end
end
local children = #plot.model:GetChildren()
local retainedShelfFigure = plot.shelves.models[secondAnchor]
move(guest, plot, 32,4,0)
check(Plot.contains(plot, guest), "guest may walk into open plot without membership")
local guestAccess = Plot.access(plot, guest)
check(not Shelves.mutate(state, { action = "ShelfRemove", id = "x", revision = state.revision, shelfId = "shelf:1", carouselRevision = 0, shelfSlotId = shelfSlots[1] }, guestAccess, 0), "visitor cannot edit owner shelves")
check(not Plot.nearDisplay(plot, guest), "visitor cannot edit host Display")
move(guest, plot, 0,4,36)
check(not Plot.nearDisplay(plot, guest), "visitor remains denied even beside host Display")
move(owner, plot, -45,4,-40)
check(not Plot.access(plot, owner).near and Plot.canNavigate(plot, owner), "across-plot viewing range does not grant edit access")
check(not Shelves.mutate(state, {action="ShelfRemove", id="far", revision=state.revision, shelfId="shelf:1", carouselRevision=0, shelfSlotId=shelfSlots[1]}, Plot.access(plot, owner), 0), "owner cannot edit shelves from long viewing distance")
move(owner, plot, 30,4,-4)
check(Plot.access(plot, owner).near, "owner can still edit close to relocated shelves")
Plot.bind(plot, function(actor, direction) Plot.turn(plot, actor, state, direction, Engine.clock) end)
Plot.render(plot, state)
local previous = plot.hitboxes[1]:FindFirstChildOfClass("ClickDetector")
local nextControl = plot.hitboxes[2]:FindFirstChildOfClass("ClickDetector")
assert(previous and nextControl)
for index, hitbox in plot.hitboxes do
	local arrow = plot.collection.controls[index].panel
	check(hitbox.Transparency == 1 and not hitbox.CanCollide and not hitbox.CanTouch and hitbox.CanQuery, "transparent nonblocking target is queryable")
	check(hitbox.Size.Y > arrow.Size.Y and hitbox.Size.Z > arrow.Size.Z and arrow.Size.Y == 6.8, "generous hitbox surrounds larger visible control")
	check(hitbox:FindFirstChildOfClass("ClickDetector").MaxActivationDistance == 160, "mouse/touch activation spans a whole plot")
end
for _, node in Engine.nodes do check(node.ClassName ~= "ProximityPrompt", "no proximity prompt exists") end
local coins, revision = state.coins, state.revision
local savedBeforeTurns = Profile.encode(state)
move(owner, plot, -45,4,-40)
Engine.clock = 1; nextControl.MouseClick:fire(owner)
check(plot.view.startIndex == 2, "owner click from normal long viewing distance advances shared viewport one unit")
check(plot.view.startIndex == 2 and plot.physicalShelves[1]:GetAttribute("ShelfId") == "shelf:2" and plot.physicalShelves[3]:GetAttribute("ShelfId") == "shelf:4", "all viewers share the 2,3,4 viewport")
check(state.coins == coins and state.revision == revision and other.view.startIndex == 1, "carousel changes no progression or other plot")
check(#plot.model:GetChildren() == children and #plot.shelves.parent:GetChildren() == 19, "one-unit slide reuses three physical structures")
check(plot.shelves.models[secondAnchor] == retainedShelfFigure, "matching figure is reused at its physical position across viewport turn")
move(guest, plot, -48,4,40)
Engine.clock = 1.49; nextControl.MouseClick:fire(guest)
check(plot.view.startIndex == 2, "visitor click shares existing half-second cooldown")
Engine.clock = 1.5; nextControl.MouseClick:fire(guest)
check(plot.view.startIndex == 3, "visitor long-range click advances one at cooldown boundary")
Engine.clock = 2; previous.MouseClick:fire(guest)
check(plot.view.startIndex == 2, "visitor click moves back one unit")
check(same(Profile.encode(state), savedBeforeTurns), "clicking only changes runtime visibility, not shelf persistence or progression")
check(collection.header.Text == "COLLECTION" and #descendants(collection.model) == #fixtureNodes, "turning retains static header, furniture, trim and lighting")
local beforeRejected = plot.view.revision
for _, coords in { {59,4,0}, {0,4,57}, {0,21,0}, {500,4,500} } do
	move(guest, plot, coords[1],coords[2],coords[3]); Engine.clock += 1
	nextControl.MouseClick:fire(guest)
	check(plot.view.revision == beforeRejected, "out-of-area or elevated forged click denied on server")
end
move(guest, plot, 58,4,0); Engine.clock += 1
nextControl.MouseClick:fire(guest)
check(plot.view.startIndex == 3, "small eight-stud perimeter margin allows nearby viewing")
for step = 1, 5 do
	Engine.clock += 1
	nextControl.MouseClick:fire(guest)
	local visibleUnits = Shelves.publicView(state.shelves, plot.view).visible
	for position, unit in visibleUnits do
		check(plot.physicalShelves[position]:GetAttribute("ShelfId") == unit.id, "each physical position tracks the current persistent unit ID")
		for _, localSlot in shelfSlots do
			local expected = state.shelves.units[unit.index].placements[localSlot]
			local rendered = plot.shelves.ids[ShelfConfig.renderSlot(position, localSlot)]
			check(rendered == expected, "all placements follow their persistent shelf through every physical position and wrap")
		end
	end
end
for _, direction in {0,2,math.huge,0/0} do check(not Plot.turn(plot, guest, state, direction, 100), "invalid carousel direction rejected") end
local humanoid = guest.Character:FindFirstChildOfClass("Humanoid")
humanoid.Health = 0
check(not Plot.turn(plot, guest, state, 1, 100), "dead actor cannot rotate shelves")
humanoid.Health = 100
local character = guest.Character; guest.Character = nil
check(not Plot.turn(plot, guest, state, 1, 100), "missing character cannot rotate shelves")
guest.Character = character
guest.Character:PivotTo(other.spawn)
check(not Plot.turn(plot, guest, state, 1, 4), "distant shelf rotation rejected")
local snapshot = Shelves.publicView(state.shelves, plot.view)
check(snapshot.coins == nil and snapshot.owned == nil and snapshot.discovered == nil, "shelf projection excludes private data")
local encoded = Profile.encode(state)
check(encoded.plotIndex == nil and encoded.startIndex == nil and encoded.shelves.startIndex == nil, "plot allocation and carousel state never persisted")
local restored = Profile.decode(encoded, 100); assert(restored)
local staleDetector, staleHitbox = previous, plot.hitboxes[1]
Plot.destroy(plot); Slots.release(allocator, owner.UserId)
check(not plot.active and plot.model.Parent == nil and #plot.connections == 0, "departing owner content and connections cleaned")
local newIndex = Slots.claim(allocator, 200); check(newIndex == 1, "new join reclaims same physical slot")
local newOwner = Engine.player(200); local replacement = Plot.create(newOwner, newIndex)
Plot.render(replacement, restored)
check(replacement.view.startIndex == 1 and replacement.shelves.ids[firstAnchor] == "tide.pearl", "saved shelf placements render independently of runtime allocation")
staleDetector.MouseClick:fire(newOwner)
check(replacement.view.startIndex == 1 and staleDetector.dead and staleHitbox.dead and staleHitbox.Parent == nil, "stale detector and hitbox destroyed, cannot mutate replacement plot")
move(newOwner, replacement, 0,4,0)
local parent = replacement.model.Parent; replacement.model.Parent = nil
check(not Plot.turn(replacement, newOwner, restored, 1, 100), "detached runtime plot cannot be navigated")
replacement.model.Parent = parent
move(guest, other, 0,4,0)
check(not Plot.turn(other, guest, otherState, 1, 100) and other.view.revision == 0, "three-unit arrows are inactive")
Plot.bind(other, function(actor, direction) Plot.turn(other, actor, otherState, direction, Engine.clock) end)
Plot.render(other, otherState)
for _, target in other.hitboxes do
	check(target:FindFirstChildOfClass("ClickDetector").MaxActivationDistance == 0, "three owned units disable physical navigation")
end
for index = 6, 250 do table.insert(restored.shelves.units, {id="shelf:" .. index,placements={},customization={}}) end
local structureCount = #replacement.model:GetChildren()
Plot.render(replacement, restored)
check(#replacement.model:GetChildren() == structureCount and #descendants(replacement.collection.model) == #fixtureNodes and #replacement.shelves.parent:GetChildren() == 27, "250 owned units still render three structures and at most 27 figures")
check(#other.shelves.parent:GetChildren() == 0 and otherState.coins == 450, "other owner's state stays isolated")
Plot.destroy(other); Plot.destroy(replacement); world:Destroy()
check(Engine.connections == 0, "no owned connections remain")
print(string.format("PASS: %d plot allocation/geometry/render/lifecycle checks (engine shim)", checks))
