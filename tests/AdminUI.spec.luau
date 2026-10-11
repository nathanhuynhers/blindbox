--!strict
-- Real dashboard and server service on the existing engine double. Does not render text/layout.
local Engine = require("./UIEngine")
local Rules = require("./Rules")
local Config = require("./AdminConfig")
local Service = require("./AdminService")
local Catalog = require("./Catalog")
local players, input = Engine.services.Players, Engine.services.UserInputService
players.LocalPlayer.UserId = Config.ownerUserId
players.PlayerRemoving = Engine.signal()
players.GetUserThumbnailAsync = function() return "test-thumbnail", true end
input.GetFocusedTextBox = function() return nil end
local Console = require("./AdminConsole")
local now = 0
local state = Rules.new(now)
local online = true
local service = Service.create({
	now = function() return now end, wall = function() return 1000 end,
	token = function() return string.rep("a", 36) end,
	random = function() return 0 end,
	players = function()
		return if online then { { userId = Config.ownerUserId, username = "Owner", displayName = "Owner", plot = 1, ready = true } } else {}
	end,
	target = function(id)
		return if online and id == Config.ownerUserId then { state = state, plot = 1, ready = true, saveStatus = "Preview", persistent = false, transferring = false } else nil
	end,
	changed = function() end, teleport = function() return true, "Teleported" end,
	kick = function() return true, "Kicked" end, log = function() end,
})
local loseReply = false
local remote = { InvokeServer = function(_, raw)
	now += 1
	local reply = service.receive(Config.ownerUserId, raw)
	if loseReply then loseReply = false; error("reply lost after server commit") end
	return reply
end }
local focus = false
local blocked = false
local baseline = Engine.connections
local controller = Console.create(remote, function() return not blocked end, function(value) focus = value end)
local root = Engine.find(Engine.playerGui, "BlindBoxAdmin")
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local function button(prefix: string, ancestor)
	for _, object in (ancestor or root):GetDescendants() do
		if object.ClassName == "TextButton" and string.sub(object.Text, 1, #prefix) == prefix then return object end
	end
	error("Missing button: " .. prefix)
end
local function click(prefix: string, ancestor) Engine.click(button(prefix, ancestor)) end
local function hasText(fragment: string)
	for _, object in root:GetDescendants() do if object.Text and string.find(object.Text, fragment, 1, true) then return true end end
	return false
end
blocked = true
Engine.bound.BlindBoxAdminToggle(nil, Engine.Enum.UserInputState.Begin)
check(not focus, "opening pipeline blocks console focus")
blocked = false
Engine.bound.BlindBoxAdminToggle(nil, Engine.Enum.UserInputState.Begin)
check(focus and root.ResetOnSpawn == false, "authorized F2 opens retained dashboard")
check(hasText("Coin") and hasText("Player inspector"), "self inspector loaded from authoritative reply")
click("Economy")
check(hasText("Currency management") and hasText("Lifetime earnings history is not stored"), "economy data and honest history")
local coins = state.coins
click("Grant Coins")
check(state.coins == coins + 1000 and hasText(tostring(state.coins)), "Coin grant confirmed and UI refreshed")
loseReply = true
click("Grant Coins")
check(state.coins == coins + 2000 and hasText("Retry interrupted request"), "lost acknowledgement blocks new mutations")
click("Retry interrupted")
check(state.coins == coins + 2000 and hasText(tostring(state.coins)), "exact retry redraws confirmed data without a duplicate grant")
click("Set balance")
check(root:FindFirstChild("Confirmation") ~= nil and state.coins == coins + 2000, "risky action waits for dialog")
Engine.bound.BlindBoxAdminClose(nil, Engine.Enum.UserInputState.Begin)
check(root:FindFirstChild("Confirmation") == nil and focus, "Escape dismisses dialog first")
click("Figures")
click("Grant figure")
check(state.owned[Catalog.figures[1].id] == 1 and hasText("Owned: 1"), "figure grant uses server and redraws inventory")
click("Remove figure")
check(state.owned[Catalog.figures[1].id] == 1 and root:FindFirstChild("Confirmation") ~= nil, "removal requires confirmation")
click("Confirm action", root:FindFirstChild("Confirmation"))
check(state.owned[Catalog.figures[1].id] == nil and hasText("Owned: 0"), "confirmed removal reflects authoritative state")
click("Grant entire")
click("Confirm action", root:FindFirstChild("Confirmation"))
check(state.shelfRewards.grove == true, "bulk grant retains completion pipeline")
local search
for _, object in root:GetDescendants() do if object.ClassName == "TextBox" and object.PlaceholderText == "Search figure name or ID" then search = object end end
check(search ~= nil, "figure search exists")
local connectionCount = Engine.connections
for i = 1, 25 do search.Text = if i % 2 == 0 then "" else "pebble" end
search.Text = ""
check(Engine.connections == connectionCount, "search rebuild disconnects row handlers")
search.Text = "no-matches-abc"
check(hasText("No figures match"), "empty filtered state")
click("Boxes")
check(hasText("Blind-box debugging") and hasText("Effective"), "box configuration and effective odds")
click("Force next rarity")
click("Confirm action", root:FindFirstChild("Confirmation"))
check(hasText("ACTIVE"), "active scoped override displayed")
click("Clear active")
check(hasText("No active override"), "override manually cleared")
local beforeCoins, beforeBoxes = state.coins, state.boxesOpened
click("Simulate")
check(state.coins == beforeCoins and state.boxesOpened == beforeBoxes and hasText("Common:"), "dry run displays results without persistent mutations")
click("Box / collection")
click("Box / collection")
check(hasText("Boost after"), "pity configuration derived for high-tier box")
click("Set pity progress")
click("Confirm action", root:FindFirstChild("Confirmation"))
check(state.pityByGroup.concept.legendaryDryRolls == 0, "pity control reaches actual service")
local connectedCount = Engine.connections
for _ = 1, 10 do
	for _, id in { "Players", "Economy", "Figures", "Boxes" } do click(id) end
end
check(Engine.connections == connectedCount, "navigation does not accumulate connections")
local panel = Engine.find(root, "Overlay"):FindFirstChildOfClass("Frame")
for _, size in { { X = 1920, Y = 1080 }, { X = 1280, Y = 720 }, { X = 667, Y = 375 }, { X = 812, Y = 375 } } do
	panel.AbsoluteSize = size
	local body = Engine.find(root, "Content")
	check(body.Size.X.Scale == 1 and body.Size.Y.Offset < 0, "responsive scroll sizing branch")
end
Engine.bound.BlindBoxAdminClose(nil, Engine.Enum.UserInputState.Begin)
check(not focus, "Escape closes and restores gameplay focus")
controller.destroy()
check(Engine.connections == baseline and Engine.playerGui:FindFirstChild("BlindBoxAdmin") == nil and Engine.bound.BlindBoxAdminToggle == nil, "dashboard teardown removes GUI, bindings and connections")
local denied = Console.create({ InvokeServer = function() return { ok = false, message = "Unauthorized" } end }, function() return true end, function() error("unauthorized focus") end)
check(Engine.playerGui:FindFirstChild("BlindBoxAdmin") == nil and Engine.connections == baseline, "unauthorized players get no GUI or input handlers")
denied.destroy()
print(`PASS: {checks} admin UI interaction/lifecycle assertions (engine double; visual acceptance pending)`)
