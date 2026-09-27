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
local otherState = Rules.new(0)
local shelfSlots = ShelfConfig.slots()
check(plot.model:GetAttribute("OwnerId") == 1 and other.model:GetAttribute("OwnerId") == 100, "world ownership independent of slot assignment")
local unitCount = 0
for _, child in plot.model:GetChildren() do
	check(not string.find(child.Name, "Wall") and not string.find(child.Name, "Entrance"), "open plot without wall or access entrance")
	if string.find(child.Name, "ShelfUnit_") then unitCount += 1 end
end
check(unitCount == 3, "three permanent physical shelf units")
local anchorCount = 0; for _ in plot.shelves.anchors do anchorCount += 1 end
check(anchorCount == 27, "27 configured cosmetic anchors")
for slot = 2, 6 do
	local prev, current = plot.display.anchors[tostring(slot-1)].Position, plot.display.anchors[tostring(slot)].Position
	check(current.X > prev.X and current.Y == prev.Y and current.Z == prev.Z, "Display is one horizontal row")
end
Plot.render(plot, state)
local oldWidth = plot.displayStand.Size.X
for capacity = 4, 6 do
	state.display.unlocked = capacity; state.display.slots[capacity] = ""
	Plot.render(plot, state)
	check(plot.displayStand.Size.X > oldWidth and plot.pads[capacity].CanCollide, "Display stand extends horizontally without rebuilding plot")
	oldWidth = plot.displayStand.Size.X
end
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
guest.Character:PivotTo({ Position = plot.origin + Engine.Vector3.new(0,4,26) })
check(Plot.contains(plot, guest), "guest may walk into open plot without membership")
local guestAccess = Plot.access(plot, guest)
check(not Shelves.mutate(state, { action = "ShelfRemove", id = "x", revision = state.revision, pageId = "page:1", pageRevision = 0, shelfSlotId = shelfSlots[1] }, guestAccess, 0), "visitor cannot edit owner shelves")
check(not Plot.nearDisplay(plot, guest), "visitor cannot edit host Display")
local coins, revision = state.coins, state.revision
check(Plot.turn(plot, guest, state, 1, 1), "visitor can turn shared physical carousel")
check(plot.view.index == 2 and plot.model:GetAttribute("VisibleShelfPage") == "page:2", "all viewers share one runtime page")
check(state.coins == coins and state.revision == revision and other.view.index == 1, "carousel changes no progression or other plot")
check(#plot.model:GetChildren() == children and #plot.shelves.parent:GetChildren() == 1, "page switch reuses physical shelf units")
check(Plot.turn(plot, guest, state, 1, 2) and plot.view.index == 1, "forward wrap in live plot")
check(Plot.turn(plot, guest, state, -1, 3) and plot.view.index == 2, "backward wrap in live plot")
guest.Character:PivotTo(other.spawn)
check(not Plot.turn(plot, guest, state, 1, 4), "distant page turn rejected")
local snapshot = Shelves.publicView(state.shelves, plot.view)
check(snapshot.coins == nil and snapshot.owned == nil and snapshot.discovered == nil, "shelf projection excludes private data")
local encoded = Profile.encode(state)
check(encoded.plotIndex == nil and encoded.visiblePage == nil and encoded.shelves.visiblePage == nil, "plot allocation and carousel state never persisted")
local restored = Profile.decode(encoded, 100); assert(restored)
Plot.bind(plot, function(actor, direction) Plot.turn(plot, actor, state, direction, Engine.clock) end)
local stalePrompt = plot.arrows[1]:FindFirstChildOfClass("ProximityPrompt"); assert(stalePrompt)
Plot.destroy(plot); Slots.release(allocator, owner.UserId)
check(not plot.active and plot.model.Parent == nil and #plot.connections == 0, "departing owner content and connections cleaned")
local newIndex = Slots.claim(allocator, 200); check(newIndex == 1, "new join reclaims same physical slot")
local newOwner = Engine.player(200); local replacement = Plot.create(newOwner, newIndex)
Plot.render(replacement, restored)
check(replacement.view.index == 1 and replacement.shelves.ids[shelfSlots[1]] == "tide.pearl", "saved shelf placements render independently of runtime allocation")
stalePrompt.Triggered:fire(newOwner)
check(replacement.view.index == 1, "stale old prompt cannot mutate replacement plot")
Plot.render(other, otherState)
check(#other.shelves.parent:GetChildren() == 0 and otherState.coins == 450, "other owner's state stays isolated")
Plot.destroy(other); Plot.destroy(replacement); world:Destroy()
check(Engine.connections == 0, "no owned connections remain")
print(string.format("PASS: %d plot allocation/geometry/render/lifecycle checks (engine shim)", checks))
