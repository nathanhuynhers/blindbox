--!strict
local E = require("./AfkEngine")
local Client = require("./AfkClient")
local Notice = require("./AfkNotice")
local UI = E.ui
local player = UI.services.Players.LocalPlayer
local input = UI.services.UserInputService
local heartbeat = UI.services.RunService.Heartbeat
local checks = 0
local function check(value, text)
	checks += 1
	assert(value, text)
end
local remote = { OnClientEvent = UI.signal(), sent = {} }
function remote:FireServer(raw)
	table.insert(self.sent, raw)
end
local messages = {}
local busy = false
local baseline = UI.connections
local c = Client.create(remote, function()
	return busy
end, function(text)
	table.insert(messages, text)
end)
E.now = 120
player.Idled:Fire(120)
heartbeat:Fire(1)
check(remote.sent[#remote.sent].idle == 120, "reports supported engine idle duration")
for at = 150, 1110, 30 do
	E.now = at
	player.Idled:Fire(at)
	heartbeat:Fire(1)
end
remote.OnClientEvent:Fire("Check", "offer")
check(
	c.blocked() and remote.sent[#remote.sent].action == "Confirm",
	"eligible client blocks new requests before confirming"
)
remote.OnClientEvent:Fire("Begin", "offer")
check(
	E.loading ~= nil and UI.playerGui:FindFirstChild("AfkReconnectLoading") ~= nil,
	"actual reconnect owns a loading screen using existing UI tokens"
)
input.InputBegan:Fire()
check(
	not c.blocked() and E.loading == nil and remote.sent[#remote.sent].action == "Active",
	"menu/chat/touch input cancels and restores UI"
)
remote.OnClientEvent:Fire("Depart", "old")
check(E.loading == nil, "delayed departure notice cannot override renewed activity")
E.now += 1110
player.Idled:Fire(1110)
heartbeat:Fire(1)
busy = true
remote.OnClientEvent:Fire("Check", "busy")
check(
	remote.sent[#remote.sent].action == "Busy" and not c.blocked(),
	"opening or pending request declines reconnect"
)
busy = false
remote.OnClientEvent:Fire("Check", "retry")
remote.OnClientEvent:Fire("Begin", "retry")
remote.OnClientEvent:Fire("Depart", "retry")
remote.OnClientEvent:Fire("Failed", "retry")
check(
	not c.blocked() and E.loading == nil and #messages == 1,
	"failure restores normal UI and gives one useful notice"
)
local sent = #remote.sent
E.now += 15
player.Idled:Fire(1125)
heartbeat:Fire(1)
check(#remote.sent == sent, "failed idle cycle stops requesting hops")
input.WindowFocused:Fire()
check(remote.sent[#remote.sent].action == "Active", "window focus counts as renewed activity")
E.now += 1110
player.Idled:Fire(1110)
heartbeat:Fire(1)
remote.OnClientEvent:Fire("Check", "respawn")
remote.OnClientEvent:Fire("Begin", "respawn")
player.CharacterRemoving:Fire()
check(not c.blocked() and E.loading == nil, "respawn cancels pending reconnect")
E.now += 1110
player.Idled:Fire(1110)
heartbeat:Fire(1)
remote.OnClientEvent:Fire("Check", "stale")
E.now += 46
heartbeat:Fire(1)
check(not c.blocked(), "missing Idled events cancel instead of extrapolating forever")
E.arrivalData = nil
c.ready()
check(#messages == 1, "normal joins have no reconnect welcome")
c.destroy()
check(
	UI.connections == baseline and E.loading == nil,
	"all client listeners and UI disconnect on destroy"
)
for cycle = 1, 25 do
	E.now = 0
	local owned = Client.create(remote, function()
		return false
	end, function(text)
		table.insert(messages, text)
	end)
	E.now = 1110
	player.Idled:Fire(1110)
	remote.OnClientEvent:Fire("Check", "cycle")
	remote.OnClientEvent:Fire("Begin", "cycle")
	owned.destroy()
	check(
		UI.connections == baseline and E.loading == nil,
		"repeated creation and cleanup leaks no connections"
	)
end
E.arrivalData = { afkReconnect = true }
c = Client.create(remote, function()
	return false
end, function(text)
	table.insert(messages, text)
end)
c.ready()
c.ready()
check(#messages == 2, "reconnect arrival welcome shows once after normal session readiness")
c.destroy()
-- Responsive component geometry checks use the real notice, not a substitute view.
for _, width in { 320, 390, 768, 1280 } do
	UI.screen.X = width
	local view = Notice.create()
	view.show(false)
	local gui = UI.playerGui:FindFirstChild("AfkReconnectLoading")
	local card = gui:FindFirstChild("Reconnect", true)
	check(card.Size.X.Offset <= width - 32, "notice fits device-safe width")
	view.destroy()
end
check(UI.connections == baseline, "notification resize listeners cleaned up")
print(string.format("PASS: %d AFK input, loading UI, arrival and teardown checks", checks))
