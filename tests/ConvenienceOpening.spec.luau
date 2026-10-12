--!strict
local E = require("./OpeningEngine")
local Opening = require("./OpeningController")
local Client = require("./ConvenienceClient")
local Presentation = require("./ConveniencePresentation")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local calls, choices, completion = {}, 0, nil
local client = Client.create({
	id = function()
		return "ack" .. #calls
	end,
	send = function(value)
		table.insert(calls, value)
	end,
})
local bridge
local opening = Opening.create(function() end, function() end, function()
	choices += 1
end, function(id, finished)
	completion = { id, finished }
	if bridge then
		bridge.completed(id, finished)
	end
end)
bridge = Presentation.create(client, opening)
local function view(sequence, id, running, reason)
	return {
		sequence = sequence,
		open = {
			running = running,
			phase = "Presenting",
			collection = "grove",
			limit = 1,
			reserve = 0,
			completed = 1,
			spent = 1500,
			reason = reason,
			requestId = id,
		},
		openAllowed = true,
		collectEnabled = false,
		collectAllowed = true,
		collectReason = "Off",
		movementEnabled = false,
		movementAllowed = true,
		speed = 48,
	}
end
local function result(id)
	return { requestId = id, figureId = "grove.pebble", isNew = false, quantity = 1, direct = false }
end
E.humanoid.WalkSpeed = 48
local baseline = E.connections
client.receive(view(1, "auto:1", false, "Run complete"))
check(opening.present(result("auto:1"), false), "ordinary single presentation")
for _ = 1, 10 do
	opening.advanceAutomatic("auto:1")
end
check(E.state.phase == "Enter", "automation cannot skip timed phases")
local now = 0
for _ = 1, 500 do
	now += 0.05
	bridge.step(now)
	E.render:Fire(0.05)
	if not opening.isActive() then
		break
	end
end
bridge.step(now + 1)
check(
	not opening.isActive() and completion[2] and choices == 0,
	"last box completes through Keep without purchase choice"
)
check(
	calls[#calls].action == "Presented" and calls[#calls].requestId == "auto:1",
	"full teardown acknowledged"
)
check(E.humanoid.WalkSpeed == 48, "opening teardown preserves resolved 48")
local before = #calls
bridge.step(now + 1.1)
check(#calls == before, "ack retry bounded")
bridge.step(now + 2.1)
check(#calls == before + 1, "lost ack retries matching identity")
client.receive(view(2, "auto:2", true, "Running"))
check(opening.present(result("auto:2"), true), "next isolated single")
while E.state.phase ~= "Await" do
	E.render:Fire(0.1)
end
opening.advanceAutomatic("foreign")
check(E.state.phase == "Await", "foreign identity cannot auto-activate")
client.receive(view(3, "auto:2", false, "Stopped by you"))
bridge.step(now + 3)
check(E.state.phase == "Await", "Stop leaves committed presentation under user control")
opening.cancel()
bridge.step(now + 4)
check(
	calls[#calls - 1].action == "Stop" and calls[#calls].action == "Presented",
	"cancel stops before releasing workflow"
)
check(completion[2] == false, "cancel distinguished from genuine completion")
-- Completion before a state event is reconciled once its matching snapshot arrives.
bridge.completed("auto:3", true)
client.receive(view(4, "auto:3", true, "Running"))
bridge.step(now + 6)
check(calls[#calls].requestId == "auto:3", "completion/snapshot race recovered")
opening.destroy()
check(E.connections == baseline - 2, "opening signals cleaned")
client.destroy()
print(`PASS: {checks} automation/opening lifecycle checks (actual controller, engine doubles)`)
