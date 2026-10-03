--!nocheck
-- Exercises the actual server Home authorization against the plot/character engine shim.
local Engine = require("./PlotEngine")
local HomeTeleport = require("./HomeTeleport")

local checks = 0
local function check(condition: boolean, message: string)
	checks += 1
	assert(condition, message)
end

local function plot(ownerId: number, position)
	local model = Engine.Instance.new("Model")
	model.Parent = Engine.workspace
	return {
		active = true,
		model = model,
		ownerId = ownerId,
		spawn = Engine.CFrame.new(position),
	}
end

local owner = Engine.player(101)
owner.Character.Parent = Engine.workspace
local ownPlot = plot(owner.UserId, Engine.Vector3.new(40, 5, -20))
ownPlot.spawn = Engine.CFrame.lookAt(Engine.Vector3.new(40, 5, -20), Engine.Vector3.new(30, 5, -30))
local root = owner.Character:FindFirstChild("HumanoidRootPart")
local landed = nil
function owner.Character:PivotTo(target)
	landed = target
	root.Position = target.Position
end
root.Position = Engine.Vector3.new(0, 3, 0) -- plaza / any other plot is irrelevant to authorization
root.AssemblyLinearVelocity = Engine.Vector3.new(10, 2, -4)
root.AssemblyAngularVelocity = Engine.Vector3.new(0, 6, 0)

local moved, requestedAt = HomeTeleport.request(owner, ownPlot, -math.huge, 10)
check(moved and requestedAt == 10, "valid owner request moves once")
check(
	root.Position.X == 40 and root.Position.Y == 5 and root.Position.Z == -20,
	"uses own plot spawn CFrame"
)
check(landed == ownPlot.spawn, "preserves the spawn CFrame's inward facing")
check(
	root.AssemblyLinearVelocity.Magnitude == 0 and root.AssemblyAngularVelocity.Magnitude == 0,
	"clears velocity"
)

root.Position = Engine.Vector3.new(1, 2, 3)
local repeated, repeatedAt = HomeTeleport.request(owner, ownPlot, requestedAt, 10.5)
check(
	not repeated and repeatedAt == requestedAt and root.Position.X == 1,
	"rapid request is rate bounded"
)

local otherPlot = plot(202, Engine.Vector3.new(-80, 5, 10))
local forged, forgedAt = HomeTeleport.request(owner, otherPlot, requestedAt, 12)
check(not forged and forgedAt == 12 and root.Position.X == 1, "cannot use another owner's plot")

ownPlot.active = false
local inactive = HomeTeleport.request(owner, ownPlot, forgedAt, 14)
check(not inactive, "released plot session is rejected")
ownPlot.active = true
ownPlot.model.Parent = nil
local detachedPlot = HomeTeleport.request(owner, ownPlot, 14, 16)
check(not detachedPlot, "detached plot is rejected")
ownPlot.model.Parent = Engine.workspace

owner.Character:FindFirstChildOfClass("Humanoid").Health = 0
local dead = HomeTeleport.request(owner, ownPlot, 16, 18)
check(not dead, "dead character is rejected")
owner.Character:FindFirstChildOfClass("Humanoid").Health = 100

local character = owner.Character
owner.Character = nil
local missing = HomeTeleport.request(owner, ownPlot, 18, 20)
check(not missing, "missing character is rejected")
owner.Character = character
character.Parent = nil
local detachedCharacter = HomeTeleport.request(owner, ownPlot, 20, 22)
check(not detachedCharacter, "detached character is rejected")
character.Parent = Engine.workspace

local missingRoot = character:FindFirstChild("HumanoidRootPart")
missingRoot.Parent = nil
local withoutRoot = HomeTeleport.request(owner, ownPlot, 22, 24)
check(not withoutRoot, "missing HumanoidRootPart is rejected")

print(string.format("PASS: %d Home teleport authority, cooldown and invalid-state checks", checks))
