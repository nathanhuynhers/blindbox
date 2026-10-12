--!strict
local Results = require("./ConvenienceResults")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local shown, applied, errors, ready = {}, 0, 0, false
local queue = Results.create({
	applySnapshot = function()
		applied += 1
	end,
	present = function(result, before, after)
		if not ready then
			return false
		end
		table.insert(shown, result)
		return true
	end,
	error = function()
		errors += 1
	end,
})
local delivery = {
	request = { id = "auto:1", action = "Buy", revision = 0, choice = "grove" },
	before = { owned = {}, discovered = {} },
	after = { owned = { ["grove.pebble"] = 1 }, discovered = { ["grove.pebble"] = true } },
	reply = { id = "auto:1", ok = true, message = "Bought", figure = "grove.pebble" },
}
queue.receive(delivery)
queue.step()
check(queue.busy() and #shown == 0, "committed result waits for presentation availability")
queue.receive(delivery)
check(applied == 2, "lost delivery uses same baseline/result")
ready = true
queue.step()
check(
	not queue.busy() and #shown == 1 and shown[1].isNew,
	"original first-discovery baseline retained"
)
queue.receive(delivery)
queue.step()
check(#shown == 1 and applied == 2, "redelivery never replays reveal")
local duplicate = table.clone(delivery)
duplicate.request = table.clone(delivery.request)
duplicate.request.id = "auto:2"
duplicate.reply = table.clone(delivery.reply)
duplicate.reply.id = "auto:2"
duplicate.before = delivery.after
duplicate.after = { owned = { ["grove.pebble"] = 2 }, discovered = { ["grove.pebble"] = true } }
queue.receive(duplicate)
queue.step()
check(
	#shown == 2 and not shown[2].isNew and shown[2].quantity == 2,
	"duplicate uses frozen confirmed outcome"
)
local invalid = table.clone(duplicate)
invalid.request = table.clone(duplicate.request)
invalid.request.id = "auto:3"
invalid.reply = table.clone(duplicate.reply)
invalid.reply.id = "auto:3"
invalid.reply.figure = "unknown"
queue.receive(invalid)
queue.step()
check(errors == 1 and not queue.busy(), "invalid result fails visibly without another purchase")
invalid.reply.ok = false
invalid.request.id = "auto:4"
invalid.reply.id = "auto:4"
queue.receive(invalid)
check(errors == 2, "purchase error delivered once")
queue.receive(invalid)
check(errors == 2, "purchase error replay ignored")
queue.destroy()
queue.receive(delivery)
queue.step()
check(#shown == 2 and not queue.busy(), "teardown clears queue and ignores late events")
print(`PASS: {checks} confirmed automatic result delivery checks (actual OpeningResult adapter)`)
