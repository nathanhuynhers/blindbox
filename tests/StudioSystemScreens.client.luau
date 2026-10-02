--!strict
-- Read-only CLIENT Command Bar check during Studio Play; no requests or fixture grants.
-- Open Display, Goals or Shelves first; the script checks whichever is visible.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DisplayConfig = require(Shared:WaitForChild("DisplayConfig"))
local ShelfConfig = require(Shared:WaitForChild("ShelfConfig"))
assert(RunService:IsStudio(), "Run only in Studio")
local gui = Players.LocalPlayer.PlayerGui:WaitForChild("PocketGrove")
local screens = gui:WaitForChild("SafeArea"):WaitForChild("Stage"):WaitForChild("Screens")
RunService.Heartbeat:Wait()
local function find(parent: Instance, name: string): Instance
	return assert(parent:FindFirstChild(name, true), "Missing " .. name)
end
local function portrait(card: Instance, occupied: boolean)
	local preview = card:FindFirstChild("Portrait", true)
	assert(preview, "Portrait slot missing")
	local viewport = if preview:IsA("ViewportFrame") then preview else preview:FindFirstChildOfClass("ViewportFrame")
	assert(viewport, "Portrait must hold a ViewportFrame")
	local model = viewport:FindFirstChildOfClass("Model")
	assert((model ~= nil) == occupied, "Preview model disagrees with figure identity: " .. card.Name)
end
local checked = 0
for _, name in { "Display", "Goals", "Shelves" } do
	local host = screens:WaitForChild(name .. "Presentation") :: Frame
	if host.Visible then
		checked += 1
		local root = host:WaitForChild(name)
		if name == "Display" then
			for slot = 1, DisplayConfig.maxSlots do
				local card = find(root, "DisplaySlot" .. slot)
				local locked = card:GetAttribute("Locked") == true
				portrait(card, card:GetAttribute("FigureId") ~= "" and not locked)
				if slot > 4 then
					assert(locked, "Slots 5-6 stay Coming later")
					assert(not (find(card, "Unlock") :: GuiObject).Visible, "No unlock for 5-6")
				end
			end
			local income = find(root, "Income"):FindFirstChild("Text") :: TextLabel
			assert(string.match(income.Text, "^%+.+ coins/s$"), "Header income chip")
			assert(find(root, "SetBonus"), "Set-bonus banner")
		elseif name == "Goals" then
			local countdown = find(root, "Countdown"):FindFirstChild("Text") :: TextLabel
			assert(
				string.match(countdown.Text, "^New goals in %d+h %d+m$")
					or string.match(countdown.Text, "^New goals in %d+m$")
					or countdown.Text == "New goals in any moment",
				"Countdown from nextDay: " .. countdown.Text
			)
			print("Countdown now: " .. countdown.Text .. " (should change once a minute while open)")
			assert(find(root, "ClaimGoal") and find(root, "OpenFreeBox"), "Goal and free box actions")
		else
			assert(typeof(root:GetAttribute("SelectedShelfId")) == "string", "Shelf selected")
			assert(ShelfConfig.visible(tostring(root:GetAttribute("SelectedSlotId"))), "Spot selected")
			for index = 1, #ShelfConfig.slots() do
				local spot = find(root, "Spot" .. index)
				assert(ShelfConfig.visible(tostring(spot:GetAttribute("ShelfSlotId"))), "Spot id")
				local viewport = spot:FindFirstChildOfClass("ViewportFrame")
				assert(viewport, "Spot portrait")
				local add = spot:FindFirstChild("Add") :: TextLabel
				assert((viewport:FindFirstChildOfClass("Model") ~= nil) ~= add.Visible, "Spot shows a figure or + Add")
			end
		end
	end
end
assert(checked == 1, "Open exactly one of Display, Goals or Shelves first")
print("PASS: system screen hierarchy, portraits and state")
