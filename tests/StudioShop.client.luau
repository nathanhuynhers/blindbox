--!strict
-- Run in the CLIENT Command Bar during Play with the Shop open. Read-only: no purchases.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Assets = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)
local Box = require(game:GetService("ReplicatedStorage").Shared.BlindBoxModel)
local Client = Players.LocalPlayer.PlayerScripts.Client
local Theme = require(Client.ShopTheme)
local UI = require(Client.UIState)
assert(RunService:IsStudio(), "Studio-only Shop check")
local gui = Players.LocalPlayer.PlayerGui:WaitForChild("PocketGrove") :: ScreenGui
local host = gui:WaitForChild("SafeArea"):WaitForChild("Stage"):WaitForChild("Screens"):WaitForChild("ShopPresentation") :: Frame
assert(host.Visible, "Open the Shop first")
local shop = host:WaitForChild("Shop") :: Frame
local function find(name: string): Instance
	return assert(shop:FindFirstChild(name, true), "Missing " .. name)
end
local selected = shop:GetAttribute("SelectedCollection")
assert(typeof(selected) == "string" and Catalog.collectionIds[selected], "No selected collection")
local collectionName = ""
for _, collection in Catalog.collections do
	local item = find("Collection_" .. collection.id) :: TextButton
	assert(item:GetAttribute("Selected") == (collection.id == selected), "List selection is stale")
	local emblem = item:FindFirstChild("Emblem", true) :: ImageLabel
	local mono = item:FindFirstChild("Monogram", true) :: TextLabel
	assert(emblem.Visible ~= mono.Visible, "Emblem art and monogram must be exclusive")
	if collection.id == selected then
		collectionName = collection.name
	end
end
assert((find("BoxTitle") :: TextLabel).Text == collectionName .. " box", "Box title is stale")
local buy = find("BuyBox") :: TextButton
local price = find("PriceGroup")
assert(price:FindFirstChild("CoinsIcon"), "Coins glyph must accompany the price")
local detail = buy:FindFirstChild("Detail", true) :: TextLabel
if buy:GetAttribute("Enabled") == false and detail.Visible then
	assert(string.find(detail.Text, "^Need "), "Disabled buy must explain the shortfall")
end
-- What's inside: one tile per collection member.
local members = UI.members(selected)
local tiles = 0
local contents = find("Contents")
for _, child in contents:GetChildren() do
	if child:IsA("TextButton") and child.Visible then
		tiles += 1
		local id = child:GetAttribute("FigureId")
		assert(typeof(id) == "string" and table.find(members, id), "Tile from another collection")
	end
end
assert(tiles == #members, "What's inside shows every figure exactly once")
local total = 0
for _, child in contents:GetChildren() do
	if string.match(child.Name, "^OddsRow%d$") and (child :: GuiObject).Visible then
		local text = (child:FindFirstChild("Chance") :: TextLabel).Text
		total += tonumber(string.match(text, "^([%d%.]+)%%")) or 0
	end
end
assert(math.abs(total - 100) <= 0.6, "Drop odds rows should total ~100%: " .. total)
-- 3D box preview (kept BlindBoxPreview).
local preview = find("BlindBoxPreview") :: Frame
local viewport = preview:WaitForChild("ProductViewport") :: ViewportFrame
local fallback = preview:WaitForChild("Fallback") :: Frame
local timeout = os.clock() + 35
while preview:GetAttribute("PreviewStatus") == "Loading" and os.clock() < timeout do
	task.wait(0.25)
end
print("Preview:", preview:GetAttribute("PreviewStatus"), preview:GetAttribute("PreviewReason"))
assert(preview:GetAttribute("PreviewStatus") == "Ready", "Production preview failed")
assert(viewport.Visible ~= fallback.Visible, "3D model and fallback must be exclusive")
if viewport.Visible then
	local product = viewport:WaitForChild("Scene"):WaitForChild("ProductModel") :: Model
	local bound, reason = Box.surfaces(product)
	assert(bound, reason)
	assert(product:GetAttribute("CollectionId") == selected, "Product theme is stale")
	local theme = Theme.get(selected)
	local emblem = product:FindFirstChild("CollectionEmblem", true)
	assert(emblem and emblem:IsA("Decal"), "Viewport-compatible emblem missing")
	assert((emblem :: Decal).Texture == Assets.resolve(theme.emblemKey), "3D emblem mismatch")
	local right, up, front = Box.axes(bound)
	local camera = viewport.CurrentCamera :: Camera
	local direction = (camera.CFrame.Position - product:GetBoundingBox().Position).Unit
	assert(
		direction:Dot(right) > 0 and direction:Dot(up) > 0 and direction:Dot(front) > 0,
		"Camera must show front, right and top"
	)
end
print("PASS: Shop list, box, price, contents, odds and 3D preview for " .. selected)
