--!strict
local E = require("./UIEngine")
local Client = require("./ConvenienceClient")
local Controls = require("./ConvenienceControls")
local Scope = require("./UIScope")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local calls, serial = {}, 0
local client = Client.create({
	id = function()
		serial += 1
		return "control:" .. serial
	end,
	send = function(request)
		table.insert(calls, request)
	end,
})
local function snapshot(sequence)
	return {
		sequence = sequence,
		open = {
			running = false,
			phase = "Idle",
			collection = "grove",
			limit = 10,
			reserve = 0,
			completed = 0,
			spent = 0,
			reason = "Idle",
		},
		openAllowed = true,
		collectEnabled = false,
		collectAllowed = true,
		collectReason = "Off",
		movementEnabled = false,
		movementAllowed = true,
		speed = 36,
	}
end
client.start("grove", 10, 0)
check(#calls == 0, "no spending before server state")
check(client.receive(snapshot(2)) and not client.receive(snapshot(1)), "owner snapshot ordering")
client.start("grove", 10, 1234)
client.stop()
check(
	calls[1].action == "Start"
		and calls[1].reserve == 1234
		and calls[2].action == "Stop"
		and calls[2].serial > calls[1].serial,
	"ordered Start/Stop"
)
client.beforeHandoff()
local before = #calls
client.start("grove", 1, 0)
client.collect(true)
client.movement(true)
check(#calls == before, "handoff guards every activating control")
client.ready()
check(calls[#calls].action == "State", "recovery requests state only")
local root = E.Instance.new("Frame")
local baseline = E.connections
local scope = Scope.create()
local panel = Controls.create(
	root,
	scope,
	function()
		return false
	end,
	client,
	function()
		return { id = "grove", name = "Pocket Grove", price = 1500 }
	end
)
for _, size in { { 1920, 1080 }, { 1280, 720 }, { 667, 375 }, { 812, 375 } } do
	panel.layout(size[1] / 2, size[2] - 90)
	check(panel.root.CanvasSize.Y.Offset >= 462, "explicit scroll height retains final control")
	for _, name in
		{ "RunLimit", "CoinReserve", "StartAutoOpen", "StopAutoOpen", "AutoCollect", "MovementSpeed" }
	do
		local control = panel.root:FindFirstChild(name)
		check(control ~= nil and control.Size.Y.Offset >= 44, "minimum target for " .. name)
	end
end
local count, reserve =
	panel.root:FindFirstChild("RunLimit"), panel.root:FindFirstChild("CoinReserve")
count.Text = "2"
reserve.Text = "500"
panel.update()
check(
	string.find(panel.root:FindFirstChild("MaximumCost").Text, "3000", 1, true) ~= nil,
	"maximum spend shown before Start"
)
before = #calls
panel.root:FindFirstChild("StartAutoOpen").Activated:Fire()
check(
	#calls == before + 1 and calls[#calls].limit == 2 and calls[#calls].reserve == 500,
	"controls submit chosen run settings"
)
count.Text = "nan"
panel.update()
before = #calls
panel.root:FindFirstChild("StartAutoOpen").Activated:Fire()
check(#calls == before, "invalid numeric input disables Start")
panel.root:FindFirstChild("StopAutoOpen").Activated:Fire()
check(calls[#calls].action == "Stop", "Stop always reachable")
panel.root:FindFirstChild("AutoCollect").Activated:Fire()
check(calls[#calls].action == "AutoCollect", "opt-in requests authority")
panel.root:FindFirstChild("MovementSpeed").Activated:Fire()
check(calls[#calls].action == "Movement", "speed selector requests authority")
scope.destroy()
scope.destroy()
check(E.connections == baseline, "control handlers released")
client.destroy()
before = #calls
client.start("grove", 1, 0)
client.ready()
client.presented("late")
check(#calls == before and not client.receive(snapshot(3)), "destroyed client cannot revive")
print(
	`PASS: {checks} convenience client/control checks (UI doubles; no native layout/input claims)`
)
