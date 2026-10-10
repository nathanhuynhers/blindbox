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
			-- Sequential coin expansion: unlocked slots form a prefix, only the next locked slot
			-- offers Unlock, and each later one points at its predecessor. Nothing is "Coming later".
			local unlocked = 0
			for slot = 1, DisplayConfig.maxSlots do
				local card = find(root, "DisplaySlot" .. slot)
				local locked = card:GetAttribute("Locked") == true
				portrait(card, card:GetAttribute("FigureId") ~= "" and not locked)
				local unlock = (find(card, "Unlock") :: GuiObject).Visible
				local hint = find(card, "Hint") :: TextLabel
				assert(
					DisplayConfig.unlockMethods[slot] == nil or DisplayConfig.unlockMethods[slot] == "Coins",
					"Unknown unlock method for slot " .. slot
				)
				if not locked then
					assert(unlocked == slot - 1, "Unlocked slots must be a prefix: slot " .. slot)
					unlocked = slot
					assert(not unlock, "Unlocked slot " .. slot .. " shows Unlock")
				elseif slot == unlocked + 1 and DisplayConfig.unlockMethods[slot] == "Coins" then
					assert(unlock, "Next locked slot " .. slot .. " must offer Unlock")
				else
					assert(not unlock, "Only the next locked slot offers Unlock, not " .. slot)
					assert(
						hint.Visible and hint.Text == "Unlock slot " .. (slot - 1) .. " first",
						"Later locked slot " .. slot .. " must point at its predecessor: " .. hint.Text
					)
				end
				assert(not hint.Visible or hint.Text ~= "Coming later", "No Coming later slots")
			end
			print(string.format("Display: %d of %d slots unlocked in order", unlocked, DisplayConfig.maxSlots))
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
