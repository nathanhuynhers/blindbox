--!strict
-- One session controller for Store and offline purchases. Only P02 launches native prompts.
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Client = {}
export type Dependencies = {
	now: () -> number,
	id: () -> string,
	send: (Types.Request) -> (),
	canPrompt: () -> boolean,
	price: (Types.ProductState) -> string?,
	changed: () -> (),
}
export type State = { outcome: string, reason: string? }
function Client.create(deps: Dependencies)
	local active = true
	local snapshot: Types.Snapshot? = nil
	local pending: Types.Request? = nil
	local sentAt, refreshedAt = -math.huge, -math.huge
	local states: { [string]: State } = {}
	local baseline: { [string]: number } = {}
	local function product(key: string): Types.ProductState?
		if snapshot then
			for _, item in snapshot.products do
				if item.key == key then
					return item
				end
			end
		end
		return nil
	end
	local function busy(): boolean
		if pending or (snapshot and snapshot.promptProduct) then
			return true
		end
		for _, state in states do
			if
				state.outcome == "verifying"
				or state.outcome == "saving"
				or state.outcome == "recovering"
			then
				return true
			end
		end
		return false
	end
	local api = {}
	function api.view(): Types.Snapshot?
		return snapshot
	end
	api.product, api.busy = product, busy
	function api.state(key: string): State?
		return states[key]
	end
	function api.canPurchase(key: string): boolean
		local item = product(key)
		return active
			and not busy()
			and deps.canPrompt()
			and snapshot ~= nil
			and snapshot.ready
			and item ~= nil
			and item.available
			and deps.price(item) ~= nil
	end
	function api.submit(request: Types.Request): boolean
		if pending and pending.id == request.id then
			deps.send(pending)
			return true
		end
		local key = request.product
		if request.action ~= "Purchase" or not key then
			return false
		end
		if not api.canPurchase(key) then
			return false
		end
		pending, sentAt = request, deps.now()
		local item = product(key)
		baseline[key] = if item then item.confirmedDeliveries or 0 else 0
		states[key] = { outcome = "prompting" }
		deps.changed()
		deps.send(request)
		return true
	end
	function api.purchase(key: string): boolean
		return api.submit({ id = deps.id(), action = "Purchase", product = key })
	end
	function api.receive(value: Types.Snapshot, result: Types.Result?): boolean
		if not active or (snapshot and value.sequence <= snapshot.sequence) then
			return false
		end
		snapshot = value
		local matched = pending ~= nil and result ~= nil and result.id == pending.id
		if matched then
			pending = nil
		end
		-- A server-observed terminal/fulfillment event can arrive before a lost
		-- authorization reply. It must restore cancellation actions immediately.
		if
			pending
			and result
			and result.product == pending.product
			and result.status ~= "Rejected"
			and result.status ~= "PromptOpened"
		then
			pending = nil
		end
		if result and result.product then
			local key = result.product
			local outcome = if states[key] then states[key].outcome else "idle"
			if result.status == "PromptOpened" then
				-- An exact-id retry can return an old authorization with a current snapshot.
				outcome = if value.promptProduct == key then "prompting" else outcome
			elseif result.status == "AwaitingReceipt" or result.status == "Reserved" then
				outcome = if outcome == "granted" and value.promptProduct ~= key
					then "granted"
					else "saving"
			elseif result.status == "Recovering" then
				outcome = "recovering"
			elseif result.status == "Verified" then
				outcome = "granted"
			elseif result.status == "Cancelled" then
				outcome = "cancelled"
			elseif result.status == "Rejected" and matched then
				outcome = "idle"
			end
			states[key] = { outcome = outcome, reason = result.reason }
		end
		for _, item in value.products do
			local prior = states[item.key]
			if item.fulfillment == "Recovering" or item.fulfillment == "Reserved" then
				states[item.key] = { outcome = "recovering" }
			elseif
				(item.ownership == "Owned" and item.ownershipFresh and item.key ~= "starter")
				or (item.package and item.package.claimed)
				or (
					prior
					and prior.outcome == "recovering"
					and item.fulfillment == "None"
					and value.ledgerStatus == "Ready"
					and baseline[item.key] == nil
				)
			then
				states[item.key] = { outcome = "idle" }
			elseif
				item.fulfillment == "None"
				and baseline[item.key] ~= nil
				and (item.confirmedDeliveries or 0) > baseline[item.key]
			then
				states[item.key] = { outcome = "granted" }
			elseif
				prior
				and prior.outcome == "prompting"
				and value.promptProduct ~= item.key
				and not pending
			then
				states[item.key] =
					{ outcome = if item.kind == "Pass" then "verifying" else "recovering" }
			elseif prior and prior.outcome == "verifying" and item.ownershipFresh then
				states[item.key] = { outcome = "cancelled" }
			end
		end
		deps.changed()
		return true
	end
	function api.refresh()
		if active and deps.now() - refreshedAt >= 10 then
			refreshedAt = deps.now()
			for key, state in states do
				if state.outcome == "granted" then
					states[key] = { outcome = "idle" }
				end
			end
			deps.changed()
			deps.send({ id = deps.id(), action = "Refresh" })
		end
	end
	function api.step()
		if active and pending and deps.now() - sentAt >= 2 then
			sentAt = deps.now()
			deps.send(pending)
		end
	end
	function api.destroy()
		active = false
	end
	return api
end
export type Controller = typeof(Client.create({} :: Dependencies))
return Client
