--!strict
local Currency = require(game:GetService("ReplicatedStorage").Shared.Currency)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Wire = require(game:GetService("ReplicatedStorage").Shared.ConvenienceTypes)
local AutoOpen = {}
export type Context = {
	ready: boolean,
	alive: boolean,
	owned: boolean,
	fresh: boolean,
	-- Explicit upstream authorization. Unknown/unapproved policy must resolve false.
	policyAllowed: boolean,
	collectionRefusal: string?,
	flowActive: boolean,
	busy: boolean,
	cooldownReady: boolean,
	price: number?,
	spendable: number,
}
export type Dependencies = {
	now: () -> number,
	id: () -> string,
	context: (string) -> Context,
	-- Both calls are NON-YIELDING. purchase revalidates ordinary Buy and reserve under
	-- the same session lock as Transactions.process. reconcile is lookup-only; NEVER Buy.
	purchase: (string, string, number) -> Types.Reply?,
	reconcile: (string) -> Types.Reply?,
	deliver: (Types.Reply) -> (),
}
export type Controller = {
	start: (string, number, number) -> boolean,
	stop: (string) -> (),
	collection: (string) -> (),
	presented: (string) -> boolean,
	step: () -> (),
	view: () -> Wire.OpenStatus,
	busy: () -> boolean,
	destroy: () -> (),
}
local function integer(value: number, low: number, high: number): boolean
	return value == value and value >= low and value <= high and value % 1 == 0
end
local function refusal(ctx: Context): string?
	if not ctx.ready then
		return "Storage unavailable"
	end
	if not ctx.alive then
		return "Character unavailable"
	end
	if not ctx.owned or not ctx.fresh then
		return "Ownership unconfirmed"
	end
	if not ctx.policyAllowed then
		return "Opening eligibility unconfirmed"
	end
	if ctx.collectionRefusal then
		return ctx.collectionRefusal
	end
	if not ctx.flowActive then
		return "Opening flow closed"
	end
	return nil
end
function AutoOpen.create(deps: Dependencies): Controller
	local status: Wire.OpenStatus = {
		running = false,
		phase = "Idle",
		collection = "",
		limit = 10,
		reserve = 0,
		completed = 0,
		spent = 0,
		reason = "Select Start to begin",
	}
	local alive = true
	local lastStart, pendingAt, pendingPrice = -math.huge, 0, 0
	local lastReconcile = -math.huge
	local delivered: Types.Reply? = nil
	local lastDelivery = -math.huge
	local function stop(reason: string)
		status.running, status.reason = false, reason
		if status.phase == "Ready" then
			status.phase = "Idle"
		end
		-- Pending/Presenting obligations survive Stop, policy changes and storage pauses.
	end
	local function deliver(reply: Types.Reply)
		lastDelivery = deps.now()
		local ok = pcall(function()
			deps.deliver(reply)
			return true
		end)
		if not ok then
			stop("Result delivery recovery pending")
		end
	end
	local function accept(reply: Types.Reply)
		if reply.id ~= status.requestId or status.phase ~= "Pending" then
			return
		end
		if reply.ok then
			status.completed += 1
			status.spent += pendingPrice
			status.phase = "Presenting"
			delivered = reply
			if status.completed >= status.limit then
				stop("Run complete")
			end
		else
			status.phase, status.requestId = "Idle", nil
			stop(reply.message)
		end
		deliver(reply)
	end
	return {
		start = function(collection, limit, reserve)
			if
				not alive
				or status.running
				or status.phase == "Pending"
				or status.phase == "Presenting"
			then
				return false
			end
			if
				#collection < 1
				or #collection > 64
				or not integer(limit, 1, 100)
				or not integer(reserve, 0, Currency.limit)
			then
				return false
			end
			local ctx = deps.context(collection)
			local reason = refusal(ctx)
			if reason or ctx.busy then
				stop(reason or "Another opening is pending")
				return false
			end
			status.collection, status.limit, status.reserve = collection, limit, reserve
			status.completed, status.spent, status.requestId = 0, 0, nil
			status.running, status.phase, status.reason = true, "Ready", "Running"
			return true
		end,
		stop = stop,
		collection = function(collection)
			if collection ~= status.collection then
				stop("Collection changed")
			end
		end,
		presented = function(id)
			if not alive or status.phase ~= "Presenting" or status.requestId ~= id then
				return false
			end
			status.requestId = nil
			delivered = nil
			status.phase = if status.running then "Ready" else "Idle"
			return true
		end,
		step = function()
			if not alive then
				return
			end
			local now = deps.now()
			if status.running then
				local reason = refusal(deps.context(status.collection))
				if reason then
					stop(reason)
				end
			end
			if status.phase == "Pending" then
				if now - pendingAt >= 10 then
					stop("Request recovery pending; select Start after delivery")
				end
				if now - lastReconcile >= 1 then
					lastReconcile = now
					local ok, reply = pcall(deps.reconcile, status.requestId :: string)
					if not ok then
						stop("Request recovery unavailable")
					elseif reply then
						accept(reply)
					end
				end
				return
			end
			-- Lost result events are redelivered, never repurchased. Client's existing
			-- OpeningResult/controller replay guard consumes each identity once.
			if status.phase == "Presenting" and delivered and now - lastDelivery >= 3 then
				deliver(delivered)
			end
			if not status.running or status.phase ~= "Ready" then
				return
			end
			local ctx = deps.context(status.collection)
			local price = ctx.price
			if not price or not integer(price, 1, Currency.limit) then
				stop("Collection unavailable")
				return
			end
			if ctx.busy then
				stop("Another opening is pending")
				return
			end
			if not integer(ctx.spendable, 0, Currency.limit) then
				stop("Spendable balance unavailable")
				return
			end
			if ctx.spendable < price then
				stop("Insufficient spendable Coins")
				return
			end
			if ctx.spendable - price < status.reserve then
				stop("Coin reserve reached")
				return
			end
			if not ctx.cooldownReady or now - lastStart < 3 then
				return
			end
			lastStart, pendingAt, pendingPrice = now, now, price
			status.requestId, status.phase = deps.id(), "Pending"
			local ok, reply =
				pcall(deps.purchase, status.requestId :: string, status.collection, status.reserve)
			if not ok then
				stop("Purchase recovery pending")
			elseif reply then
				accept(reply)
			end
		end,
		view = function()
			return table.clone(status)
		end,
		busy = function()
			return status.phase == "Pending" or status.phase == "Presenting"
		end,
		destroy = function()
			stop("Disconnected")
			alive = false
		end,
	}
end
return AutoOpen
