--!strict
-- Read-only CLIENT Command Bar check during Studio Play; no requests or fixture grants.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DisplayConfig = require(Shared:WaitForChild("DisplayConfig"))
local ShelfConfig = require(Shared:WaitForChild("ShelfConfig"))
assert(RunService:IsStudio(), "Run only in Studio")
local player = Players.LocalPlayer
assert(player, "Use the client Command Bar")
local gui = player.PlayerGui:WaitForChild("PocketGrove")
local screens = gui:WaitForChild("SafeArea"):WaitForChild("Screens")
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()
local function find(parent: Instance, name: string): Instance
	local result = parent:FindFirstChild(name, true)
	assert(result, "Missing " .. name)
	return result
end
local function portrait(card: Instance, occupied: boolean)
	local preview = find(card, "Portrait")
	assert(preview:IsA("ViewportFrame"), "Portrait must be a ViewportFrame")
	assert(preview.AbsoluteSize.X > 30 and preview.AbsoluteSize.Y > 30, "Preview collapsed")
	assert(preview.CurrentCamera, "Preview camera missing")
	local model = preview:FindFirstChildOfClass("Model")
	assert((model ~= nil) == occupied, "Preview model disagrees with figure identity")
end
local checked = 0
for _, name in { "Display", "Shelves", "Goals" } do
	local host = screens:WaitForChild(name .. "Presentation")
	if host:IsA("Frame") and host.Visible then
		local root = host:WaitForChild(name)
		local scroll = find(root, "ContentScroll")
		assert(scroll:IsA("ScrollingFrame"), "Measured scroll missing")
		local content = find(scroll, "Content")
		assert(content:IsA("Frame"), "Content root missing")
		assert(scroll.CanvasSize.Y.Offset >= content.Size.Y.Offset + 20, "Canvas truncates content")
		assert(content.AbsoluteSize.X <= scroll.AbsoluteSize.X - 16, "Horizontal content overflow")
		if name == "Display" then
			for slot = 1, DisplayConfig.maxSlots do
				local card = find(root, "DisplaySlot" .. slot)
				assert(card:GetAttribute("Slot") == slot, "Snapshot has not populated Display")
				portrait(
					card,
					card:GetAttribute("FigureId") ~= "" and not card:GetAttribute("Locked")
				)
			end
		elseif name == "Shelves" then
			assert(
				typeof(root:GetAttribute("SelectedShelfId")) == "string",
				"Shelf identity missing"
			)
			for _, slotId in ShelfConfig.slots() do
				local card = find(root, slotId)
				assert(card:GetAttribute("ShelfSlotId") == slotId, "Shelf position mapping differs")
				portrait(card, card:GetAttribute("FigureId") ~= nil)
			end
			local count = 0
			for _, item in root:GetDescendants() do
				if item:IsA("ViewportFrame") then
					count += 1
				end
			end
			assert(count == #ShelfConfig.slots() + 6, "Shelf preview pool unexpectedly grew")
		else
			local card = find(root, "DailyDisplayGoal")
			local state = card:GetAttribute("GoalState")
			assert(
				state == "progress" or state == "ready" or state == "claimed",
				"Goal state missing"
			)
			local claim = find(card, "Claim reward")
			assert(
				claim:IsA("GuiButton") and claim.Visible == (state == "ready"),
				"Claim visibility differs from goal state"
			)
		end
		checked += 1
	end
end
assert(checked == 1, "Open Display, Shelves or Goals before running")
print(
	"PASS: active system-screen structure, canvas and preview models. Visual/input acceptance still requires manual review."
)
