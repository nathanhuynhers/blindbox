--!strict
local Engine = require("./GalleryEngine")
local Gallery = require("./GalleryRuntime")
local Rules = require("./Rules")
local Catalog = require("./Catalog")
local Showrooms = require("./Showrooms")
local checks = 0
local function check(value: boolean, message: string) assert(value, message); checks += 1 end
local states, players, entrances = {}, {}, {}
for id = 1, 4 do
	states[id] = Rules.new(0); players[id] = Engine.player(id)
	for _, figure in Catalog.figures do states[id].discovered[figure.id] = true end
	Showrooms.sync(states[id])
	entrances[id] = Engine.Template.part(Engine.workspace, "PlotEntrance" .. id, Engine.Vector3.new(id * 38, 0, 0))
end
for index = 1, 9 do
	local id = "custom:test_" .. index
	states[3].showrooms.rooms[id] = { roomId = id, sourceType = "Custom", theme = "grove", placements = {}, customization = {} }
end
local returned = {}
local controller = Gallery.create(function(id) return states[id] end, function(player) returned[player.UserId] = true end)
for id, player in players do controller.register(player, entrances[id]) end
local function active(name)
	local root = Engine.workspace:FindFirstChild("GalleryRuntimes"); assert(root)
	return root:FindFirstChild(name)
end
local function door(owner, roomId)
	local hall = active("Gallery_" .. owner); assert(hall)
	local folder = hall:FindFirstChild("Entrances"); assert(folder)
	for _, part in folder:GetChildren() do if part:GetAttribute("RoomId") == roomId then return part end end
	error("Missing room door")
end
check(active("Gallery_1") == nil, "no permanent Gallery allocation")
Engine.trigger(entrances[1], players[2])
local view = controller.view(players[2]); assert(view)
check(view.ownerId == 1 and not view.canEdit and #view.rooms == 2, "visitor authorized through owner entrance")
check(active("Showroom_1_collection:grove") == nil, "room not instantiated until entry")
local staleDoor = door(1, "collection:grove")
local stalePrompt = staleDoor:FindFirstChildOfClass("ProximityPrompt"); assert(stalePrompt)
Engine.trigger(staleDoor, players[4])
check(controller.view(players[4]) == nil, "being near another runtime door does not authorize access")
Engine.trigger(staleDoor, players[2])
view = controller.view(players[2]); assert(view and view.room)
check(view.roomId == "collection:grove" and view.room.roomId == "collection:grove", "visitor can enter owned room")
check(view.coins == nil and view.owned == nil and view.discovered == nil and view.palettes == nil, "public view contains no private profile")
check(view.room.coins == nil and view.room.inventory == nil, "room projection allowlist")
Engine.trigger(entrances[1], players[1])
Engine.trigger(door(1, "collection:grove"), players[1])
local ownerView = controller.view(players[1]); assert(ownerView)
check(ownerView.canEdit and ownerView.runtimeId == view.runtimeId, "owner and visitor share runtime with separate permissions")
local access = controller.access(players[2]); assert(access)
check(access.actorId == 2 and access.ownerId == 1, "edit context derives actor and owner server-side")
check(not Showrooms.edit(states[2], { action = "ShowroomRemove", id = "x", revision = 0, runtimeId = access.runtimeId, roomId = "collection:grove", anchorId = "figure_1" }, access), "controller visitor context cannot edit")
Engine.trigger(entrances[3], players[3])
local firstHall, otherHall = active("Gallery_1"), active("Gallery_3"); assert(firstHall and otherHall)
check(controller.view(players[3]).runtimeId ~= view.runtimeId, "simultaneous owners have distinct generations")
check(#controller.view(players[3]).rooms == 6, "large room ownership has bounded visible hall")
local pagePortal = otherHall:FindFirstChild("Entrances"):FindFirstChild("HallPage"); assert(pagePortal)
Engine.trigger(pagePortal, players[3])
local nextView = controller.view(players[3]); assert(nextView)
check(#nextView.rooms == 5 and nextView.rooms[1].roomId ~= "collection:grove", "physical paging exposes rooms beyond first six")
Engine.trigger(door(3, nextView.rooms[1].roomId), players[3])
check(controller.view(players[3]).room.sourceType == "Custom", "reusable runtime supports custom room identities")
controller.leave(players[1])
check(active("Showroom_1_collection:grove") ~= nil, "room retained for remaining visitor")
local room = active("Showroom_1_collection:grove"); assert(room)
local exit = room:FindFirstChild("GalleryExit"); assert(exit)
Engine.trigger(exit, players[2])
check(active("Showroom_1_collection:grove") == nil and controller.view(players[2]).roomId == nil, "last room exit destroys room and returns to hall")
Engine.trigger(door(1, "collection:grove"), players[2])
local reRoom = active("Showroom_1_collection:grove"); assert(reRoom)
check(reRoom ~= room, "room lazily recreated")
check(controller.access(players[2]).runtimeId ~= access.runtimeId, "room recreation invalidates old edit token even within same Gallery")
reRoom:Destroy()
check(controller.view(players[2]).roomId == nil and controller.access(players[2]) == nil, "destroyed room ejects members safely")
controller.leave(players[2])
check(active("Gallery_1") == nil and controller.view(players[2]) == nil, "last Gallery participant cleanup")
local previousId = view.runtimeId
Engine.trigger(entrances[1], players[2])
check(controller.view(players[2]).runtimeId ~= previousId, "recreated Gallery has fresh identity")
stalePrompt.Triggered:fire(players[2])
check(controller.view(players[2]).roomId == nil, "destroyed old prompt cannot change recreated runtime")
Engine.trigger(entrances[1], players[4])
controller.remove(players[1]); states[1] = nil
check(returned[2] and returned[4] and not active("Gallery_1"), "owner departure returns multiple visitors and destroys space")
check(controller.view(players[2]) == nil and controller.view(players[4]) == nil, "owner departure clears memberships")
check(active("Gallery_3") == otherHall, "other owner unaffected")
otherHall:Destroy()
check(returned[3] and controller.view(players[3]) == nil, "external Gallery destruction returns participant")
Engine.trigger(entrances[3], players[3]); controller.leave(players[3])
check(controller.view(players[3]) == nil and not active("Gallery_3"), "character-reset leave path clears membership")
controller.remove(players[2]); controller.remove(players[3]); controller.remove(players[4]); controller.destroy()
check(Engine.connections == 0, "all controller/entrance/room connections disconnected")
print(string.format("PASS: %d Gallery controller checks (engine boundaries shimmed)", checks))
