--!strict
-- Runs real allocator, world, plot and targeted renderer; engine properties/signals are shimmed.
local Engine = require("./PlotEngine")
local Slots = require("./PlotSlots")
local Config = require("./PlotConfig")
local Geometry = require("./PlotGeometry")
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
check(plot.model:GetAttribute("OwnerId") == 1 and other.model:GetAttribute("OwnerId") == 100, "world ownership independent of slot assignment")
local unitCount = 0
for _, child in plot.model:GetChildren() do
	check(not string.find(child.Name, "Wall") and not string.find(child.Name, "Entrance"), "open plot without wall or access entrance")
	if string.find(child.Name, "ShelfUnit_") then unitCount += 1 end
end
check(unitCount == 3, "three permanent physical shelf units")
for unit = 1, 3 do
	local shelf = plot.model:FindFirstChild("ShelfUnit_" .. unit); assert(shelf)
	for row = 1, 3 do
		local board = shelf:FindFirstChild("Row_" .. row); assert(board)
		check(board.Position.X == plot.origin.X + 40 and board.Size.Z == 18 and board.Size.X == 5, "shelf boards lie left of the entrance's +Z facing direction")
		for slot = 1, 3 do
			local key = string.format("unit:%d/row:%d/slot:%d", unit, row, slot)
			local anchor = plot.shelves.anchors[key]; assert(anchor)
			check(close(anchor.LookVector.X, -1) and close(anchor.LookVector.Z, 0), "stable shelf anchors face -X into plot")
			check(anchor.Position.X == plot.origin.X + 40, "every shelf figure stays on left collection installation")
		end
	end
end
local anchorCount = 0; for _ in plot.shelves.anchors do anchorCount += 1 end
check(anchorCount == 27, "27 configured cosmetic anchors")
Plot.render(plot, state)
local initialModel = plot.model
local initialStand = plot.displayStand
local initialPad = plot.pads[1]
local firstFigure, thirdFigure = plot.display.models["1"], plot.display.models["3"]
local created = Engine.figureCreates
for capacity = 3, 6 do
	state.display.unlocked = capacity
	if capacity > 3 then state.display.slots[capacity] = "" end
	local profileBefore = Profile.encode(state)
	Plot.render(plot, state)
	check(same(Profile.encode(state), profileBefore), "layout never mutates persisted state")
	check(Rules.rate(state) == 14.5, "unchanged Display income across capacity layout")
	check(#plot.pads == capacity and count(plot.display.anchors) == capacity and #plot.slotLabels == capacity, "exact unlocked pad/label/anchor count at capacity " .. capacity)
	check(plot.model == initialModel and plot.displayStand == initialStand and plot.pads[1] == initialPad, "growth reuses plot, stand and existing pads")
	check(plot.displayStand.Size.X == 14 + (capacity - 1)*12 and plot.displayStand.Size.Y == 3 and plot.displayStand.Size.Z == 12, "cohesive stand width and substantial supporting volume")
	check(plot.displayStand.Position.X == plot.origin.X and plot.displayStand.Position.Z == plot.origin.Z + 36, "stand centered at back")
	local sum = 0
	for slot = 1, capacity do
		local anchor = plot.display.anchors[tostring(slot)].Position
		local pad = plot.pads[slot]
		sum += anchor.X - plot.origin.X
		check(anchor.X - plot.origin.X == (slot - (capacity+1)/2)*12 and anchor.Z == plot.origin.Z + 36 and anchor.Y == plot.origin.Y + 5, "centered one-row anchor spacing")
		check(pad.Position.X == anchor.X and pad.Position.Y == anchor.Y-1 and pad.Position.Z == anchor.Z and pad.Transparency == 0, "unlocked geometry aligns with figure anchor")
	end
	check(close(sum, 0), "visible row centered at capacity " .. capacity)
	for slot = capacity + 1, 6 do
		check(plot.model:FindFirstChild("DisplaySlot_" .. slot) == nil and plot.display.anchors[tostring(slot)] == nil and plot.slotLabels[slot] == nil, "locked slots have no physical geometry/labels/anchors")
	end
	check(plot.display.models["1"] == firstFigure and plot.display.models["3"] == thirdFigure and Engine.figureCreates == created, "unchanged Display models reused while recentering")
	for _, slot in {1,3} do
		local figure = plot.display.models[tostring(slot)]
		local anchor = plot.display.anchors[tostring(slot)].Position
		check(figure:GetAttribute("SlotId") == tostring(slot) and close(figure.Position.X, anchor.X) and close(figure.Position.Y, anchor.Y+1) and close(figure.Position.Z, anchor.Z), "logical slot identity and relative pivot remain correct")
	end
end
move(owner, plot, 0,4,28)
check(Plot.nearDisplay(plot, owner), "Display edit proximity follows back focal structure")
move(owner, plot, 0,4,-14)
check(not Plot.nearDisplay(plot, owner), "old front Display location no longer grants editing proximity")
for _, slot in shelfSlots do state.shelves.pages[1].placements[slot] = "grove.star" end
Plot.render(plot, state)
local before = Engine.figureCreates
check(#plot.shelves.parent:GetChildren() == 27, "visible page renders 27 figures")
local unchangedModel = plot.shelves.models[shelfSlots[2]]
Plot.render(plot, state)
check(Engine.figureCreates == before, "unchanged snapshot never clones figures")
state.discovered["tide.pearl"] = true; state.shelves.pages[1].placements[shelfSlots[1]] = "tide.pearl"
Plot.render(plot, state)
check(Engine.figureCreates == before + 1 and plot.shelves.models[shelfSlots[2]] == unchangedModel, "single edit touches one figure only")
table.insert(state.shelves.pages, { id = "page:2", placements = { [shelfSlots[1]] = "tide.pearl" }, customization = {} })
local children = #plot.model:GetChildren()
local retainedShelfFigure = plot.shelves.models[shelfSlots[1]]
move(guest, plot, 32,4,0)
check(Plot.contains(plot, guest), "guest may walk into open plot without membership")
local guestAccess = Plot.access(plot, guest)
check(not Shelves.mutate(state, { action = "ShelfRemove", id = "x", revision = state.revision, pageId = "page:1", pageRevision = 0, shelfSlotId = shelfSlots[1] }, guestAccess, 0), "visitor cannot edit owner shelves")
check(not Plot.nearDisplay(plot, guest), "visitor cannot edit host Display")
move(guest, plot, 0,4,36)
check(not Plot.nearDisplay(plot, guest), "visitor remains denied even beside host Display")
move(owner, plot, -45,4,-40)
check(not Plot.access(plot, owner).near and Plot.canNavigate(plot, owner), "across-plot viewing range does not grant edit access")
check(not Shelves.mutate(state, {action="ShelfRemove", id="far", revision=state.revision, pageId="page:1", pageRevision=0, shelfSlotId=shelfSlots[1]}, Plot.access(plot, owner), 0), "owner cannot edit shelves from long viewing distance")
move(owner, plot, 30,4,-4)
check(Plot.access(plot, owner).near, "owner can still edit close to relocated shelves")
Plot.bind(plot, function(actor, direction) Plot.turn(plot, actor, state, direction, Engine.clock) end)
local previous = plot.hitboxes[1]:FindFirstChildOfClass("ClickDetector")
local nextPage = plot.hitboxes[2]:FindFirstChildOfClass("ClickDetector")
assert(previous and nextPage)
for index, hitbox in plot.hitboxes do
	local arrow = plot.arrows[index]
	check(hitbox.Transparency == 1 and not hitbox.CanCollide and not hitbox.CanTouch and hitbox.CanQuery, "transparent nonblocking target is queryable")
	check(hitbox.Size.Y > arrow.Size.Y and hitbox.Size.Z > arrow.Size.Z and arrow.Size.Y == 6, "generous hitbox surrounds larger visible control")
	check(hitbox:FindFirstChildOfClass("ClickDetector").MaxActivationDistance == 160, "mouse/touch activation spans a whole plot")
end
for _, node in Engine.nodes do check(node.ClassName ~= "ProximityPrompt", "no proximity prompt exists") end
local coins, revision = state.coins, state.revision
local savedBeforeTurns = Profile.encode(state)
move(owner, plot, -45,4,-40)
Engine.clock = 1; nextPage.MouseClick:fire(owner)
check(plot.view.index == 2, "owner click from normal long viewing distance turns shared page")
check(plot.view.index == 2 and plot.model:GetAttribute("VisibleShelfPage") == "page:2", "all viewers share one runtime page")
check(state.coins == coins and state.revision == revision and other.view.index == 1, "carousel changes no progression or other plot")
check(#plot.model:GetChildren() == children and #plot.shelves.parent:GetChildren() == 1, "page switch reuses physical shelf units")
check(plot.shelves.models[shelfSlots[1]] == retainedShelfFigure, "unchanged shelf figure is reused across page turn")
move(guest, plot, -48,4,40)
Engine.clock = 1.49; nextPage.MouseClick:fire(guest)
check(plot.view.index == 2, "visitor click shares existing half-second cooldown")
Engine.clock = 1.5; nextPage.MouseClick:fire(guest)
check(plot.view.index == 1, "visitor long-range click wraps forward at cooldown boundary")
Engine.clock = 2; previous.MouseClick:fire(guest)
check(plot.view.index == 2, "visitor click wraps backward")
check(same(Profile.encode(state), savedBeforeTurns), "clicking only changes runtime visibility, not shelf persistence or progression")
local beforeRejected = plot.view.revision
for _, coords in { {59,4,0}, {0,4,57}, {0,21,0}, {500,4,500} } do
	move(guest, plot, coords[1],coords[2],coords[3]); Engine.clock += 1
	nextPage.MouseClick:fire(guest)
	check(plot.view.revision == beforeRejected, "out-of-area or elevated forged click denied on server")
end
move(guest, plot, 58,4,0); Engine.clock += 1
nextPage.MouseClick:fire(guest)
check(plot.view.index == 1, "small eight-stud perimeter margin allows nearby viewing")
for _, direction in {0,2,math.huge,0/0} do check(not Plot.turn(plot, guest, state, direction, 100), "invalid carousel direction rejected") end
local humanoid = guest.Character:FindFirstChildOfClass("Humanoid")
humanoid.Health = 0
check(not Plot.turn(plot, guest, state, 1, 100), "dead actor cannot turn pages")
humanoid.Health = 100
local character = guest.Character; guest.Character = nil
check(not Plot.turn(plot, guest, state, 1, 100), "missing character cannot turn pages")
guest.Character = character
guest.Character:PivotTo(other.spawn)
check(not Plot.turn(plot, guest, state, 1, 4), "distant page turn rejected")
local snapshot = Shelves.publicView(state.shelves, plot.view)
check(snapshot.coins == nil and snapshot.owned == nil and snapshot.discovered == nil, "shelf projection excludes private data")
local encoded = Profile.encode(state)
check(encoded.plotIndex == nil and encoded.visiblePage == nil and encoded.shelves.visiblePage == nil, "plot allocation and carousel state never persisted")
local restored = Profile.decode(encoded, 100); assert(restored)
local staleDetector, staleHitbox = previous, plot.hitboxes[1]
Plot.destroy(plot); Slots.release(allocator, owner.UserId)
check(not plot.active and plot.model.Parent == nil and #plot.connections == 0, "departing owner content and connections cleaned")
local newIndex = Slots.claim(allocator, 200); check(newIndex == 1, "new join reclaims same physical slot")
local newOwner = Engine.player(200); local replacement = Plot.create(newOwner, newIndex)
Plot.render(replacement, restored)
check(replacement.view.index == 1 and replacement.shelves.ids[shelfSlots[1]] == "tide.pearl", "saved shelf placements render independently of runtime allocation")
staleDetector.MouseClick:fire(newOwner)
check(replacement.view.index == 1 and staleDetector.dead and staleHitbox.dead and staleHitbox.Parent == nil, "stale detector and hitbox destroyed, cannot mutate replacement plot")
move(newOwner, replacement, 0,4,0)
local parent = replacement.model.Parent; replacement.model.Parent = nil
check(not Plot.turn(replacement, newOwner, restored, 1, 100), "detached runtime plot cannot be navigated")
replacement.model.Parent = parent
move(guest, other, 0,4,0)
check(not Plot.turn(other, guest, otherState, 1, 100) and other.view.revision == 0, "single-page arrows are inactive")
Plot.render(other, otherState)
check(#other.shelves.parent:GetChildren() == 0 and otherState.coins == 450, "other owner's state stays isolated")
Plot.destroy(other); Plot.destroy(replacement); world:Destroy()
check(Engine.connections == 0, "no owned connections remain")
print(string.format("PASS: %d plot allocation/geometry/render/lifecycle checks (engine shim)", checks))
