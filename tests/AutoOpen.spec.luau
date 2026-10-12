--!strict
local Open = require("./AutoOpen")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local now, serial, calls, deliveries = 0, 0, 0, 0
local reply, lost, throws = nil, false, false
local ctx = {
	ready = true,
	alive = true,
	owned = true,
	fresh = true,
	policyAllowed = true,
	flowActive = true,
	busy = false,
	cooldownReady = true,
	price = 1500,
	spendable = 100000,
}
local ledger = {}
local open = Open.create({
	now = function()
		return now
	end,
	id = function()
		serial += 1
		return "auto:" .. serial
	end,
	context = function(collection)
		return if collection == "grove" then ctx else table.clone(ctx)
	end,
	purchase = function(id, collection, reserve)
		check(collection == "grove" and reserve >= 0, "ordinary chosen collection and reserve only")
		calls += 1
		ctx.spendable -= ctx.price
		ledger[id] = { id = id, ok = true, message = "Bought", figure = "grove.pebble" }
		if throws then
			error("Lost committed reply")
		end
		return if lost then nil else ledger[id]
	end,
	reconcile = function(id)
		return ledger[id]
	end,
	deliver = function(result)
		deliveries += 1
		reply = result
	end,
})
check(
	not open.start("grove", 0, 0)
		and not open.start("grove", 101, 0)
		and not open.start("grove", 10, 0 / 0),
	"bounded run settings"
)
check(open.start("grove", 2, 1000), "explicit start")
check(not open.start("grove", 2, 0), "rapid Start cannot replace run")
open.step()
check(
	calls == 1 and open.busy() and open.view().phase == "Presenting",
	"one purchase held for reveal"
)
now = 20
open.step()
check(calls == 1 and deliveries == 2, "lost delivery retried without purchase")
check(not open.presented("forged"), "wrong completion rejected")
check(open.presented(reply.id), "matching presentation completion")
open.step()
check(
	calls == 2 and not open.view().running and open.view().reason == "Run complete",
	"budget ends precisely"
)
check(not open.start("grove", 1, 0), "cannot start over undismissed committed result")
open.presented(reply.id)
check(open.start("grove", 3, 0), "new explicit run")
open.step()
check(calls == 2, "three second cadence across runs")
now += 3
open.step()
open.stop("Stopped by you")
check(open.busy() and not open.view().running, "Stop keeps committed reveal")
open.presented(reply.id)
now += 30
open.step()
check(calls == 3, "no automatic restart after Stop")
for _, flag in { "ready", "alive", "owned", "fresh", "policyAllowed", "flowActive" } do
	ctx[flag] = true
	check(open.start("grove", 2, 0), "start before guard change")
	ctx[flag] = false
	open.step()
	check(not open.view().running and calls == 3, "stop before spend on " .. flag)
	ctx[flag] = true
end
ctx.spendable = 1499
open.start("grove", 1, 0)
open.step()
check(not open.view().running and calls == 3, "insufficient funds stop")
ctx.spendable = 2000
open.start("grove", 1, 501)
open.step()
check(open.view().reason == "Coin reserve reached", "reserve enforced")
ctx.spendable = 100000
open.step()
check(calls == 3, "new funds never restart")
open.start("grove", 2, 0)
open.collection("tide")
open.step()
check(not open.view().running, "collection change stops")
open.start("grove", 2, 0)
ctx.busy = true
open.step()
check(not open.view().running, "manual workflow conflict stops")
ctx.busy = false
ctx.cooldownReady = false
open.start("grove", 2, 0)
open.step()
check(calls == 3, "ordinary cooldown respected")
ctx.cooldownReady = true
lost = true
open.step()
local id = open.view().requestId
check(calls == 4 and open.view().phase == "Pending", "lost reply holds exact identity")
local committed = ledger[id]
ledger[id] = nil
now += 130
open.step()
check(calls == 4 and not open.view().running and open.busy(), "receipt expiry cannot repurchase")
check(not open.start("grove", 1, 0), "uncertain obligation blocks new run")
ledger[id] = committed
now += 1
open.step()
check(open.view().phase == "Presenting" and calls == 4, "lookup recovers original committed result")
open.presented(id)
lost = false
throws = true
now += 3
open.start("grove", 2, 0)
open.step()
check(not open.view().running and open.busy(), "exception after commit stops spending")
now += 1
open.step()
check(open.view().phase == "Presenting" and calls == 5, "exception reconciles original identity")
open.presented(open.view().requestId)
open.destroy()
open.destroy()
now += 10
open.step()
check(not open.start("grove", 1, 0) and calls == 5, "destroyed loop cannot restart")
print(`PASS: {checks} Auto Open checks (injected purchase adapter)`)
