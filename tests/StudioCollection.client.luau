--!strict
-- Read-only: paste in Studio's CLIENT Command Bar with Collection open. No remotes/grants.
-- Checks the list, filter counts, grid identity/reuse and the detail panel against Catalog.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
assert(RunService:IsStudio(), "Studio-only Collection check")
local gui = Players.LocalPlayer.PlayerGui:WaitForChild("PocketGrove") :: ScreenGui
local host = gui:WaitForChild("SafeArea"):WaitForChild("Stage"):WaitForChild("Screens"):WaitForChild("CollectionPresentation") :: Frame
assert(host.Visible, "Open Collection first")
local root = host:WaitForChild("Collection") :: Frame
RunService.Heartbeat:Wait()
local function find(name: string): Instance
	return assert(root:FindFirstChild(name, true), "Missing " .. name)
end
assert(not root:FindFirstChild("PhysicalBook", true), "The physical book must be gone")
local selected = root:GetAttribute("CollectionId")
local filter = tostring(root:GetAttribute("Filter"))
assert(typeof(selected) == "string" and Catalog.collectionIds[selected], "No collection selected")
assert(filter == "all" or filter == "found" or filter == "missing", "Unknown filter")
for _, collection in Catalog.collections do
	local item = find("Collection_" .. collection.id)
	assert(item:GetAttribute("Selected") == (collection.id == selected), "List selection is stale")
	local name = item:GetAttribute("AccessibleName")
	assert(typeof(name) == "string" and string.find(name, collection.name, 1, true), "Accessible name")
end
local expected = 0
for _, figure in Catalog.figures do
	if figure.collection == selected then
		expected += 1
	end
end
local grid = find("FigureGrid") :: ScrollingFrame
local visible, discovered = 0, 0
for _, child in grid:GetChildren() do
	if child:IsA("TextButton") and child.Visible then
		visible += 1
		local id = child:GetAttribute("FigureId")
		assert(typeof(id) == "string" and Catalog.byId[id], "Card without a catalog figure")
		assert(Catalog.byId[id].collection == selected, "Card from another collection")
		local known = child:GetAttribute("Discovered") == true
		discovered += if known then 1 else 0
		local name = (child:FindFirstChild("Name", true) :: TextLabel).Text
		assert(known or name == "???", "Undiscovered cards are anonymous")
		assert(not known or name == Catalog.byId[id].name, "Discovered card name")
		if filter == "found" then
			assert(known, "Found filter shows only discoveries")
		elseif filter == "missing" then
			assert(not known, "Missing filter shows only undiscovered")
		end
	end
end
if filter == "all" then
	assert(visible == expected, "All shows every figure in the collection")
end
local chip = find("Filter_" .. filter) :: TextButton
assert(chip:GetAttribute("Selected") == true, "Selected filter chip is highlighted")
local figure = root:GetAttribute("FigureId")
if typeof(figure) == "string" then
	local details = find("FigureDetails") :: Frame
	assert(details.Visible, "Detail panel visible for the selected figure")
	local card = grid:FindFirstChild(figure) :: TextButton?
	assert(card and card:GetAttribute("Selected") == true, "Selected card highlighted")
	local action = (find("FigureAction"):FindFirstChild("Label", true) :: TextLabel).Text
	assert(
		action == "Put on Display"
			or string.find(action, "^Put in slot ")
			or action == "On your Display · View"
			or string.find(action, "^Find it in "),
		"Detail action copy: " .. action
	)
	local rarity = find("RarityPill"):FindFirstChild("Text") :: TextLabel
	assert(rarity.Text == string.upper(Catalog.byId[figure].rarity), "Rarity pill")
end
print(
	string.format(
		"PASS: %s · %s · %d cards (%d discovered) · detail %s",
		selected,
		filter,
		visible,
		discovered,
		tostring(figure)
	)
)
