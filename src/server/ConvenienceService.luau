--!strict
-- Callback userId is supplied by the server adapter, never by the request payload.
local Wire = require(game:GetService("ReplicatedStorage").Shared.ConvenienceTypes)
local Open = require(script.Parent.AutoOpen)
local Collect = require(script.Parent.AutoCollect)
local Protocol = require(script.Parent.ConvenienceProtocol)
local Movement = require(script.Parent.PlayerMovement)
local Service = {}
export type Preferences = { autoCollect: boolean, movement: boolean }
export type Owner = {
	open: Open.Controller,
	collect: Collect.Controller,
	binding: Movement.Binding,
	preferences: () -> Preferences,
	-- NON-YIELDING profile mutation, revision/dirty marking owned by shared adapter.
	setPreference: (string, boolean) -> boolean,
	ready: () -> boolean,
	ownership: (string) -> (boolean, boolean),
	openAllowed: () -> boolean,
	collection: ((string) -> ())?, -- shared adapter records active Shop selection/close.
}
export type Dependencies = { now: () -> number, notify: (number, Wire.Snapshot) -> () }
type Entry = {
	owner: Owner,
	sequence: number,
	tokens: number,
	tokenTime: number,
	requests: { [string]: Wire.Request },
	count: number,
	serial: number,
}
export type Controller = {
	add: (number, Owner) -> boolean,
	remove: (number) -> (),
	receive: (number, unknown) -> boolean,
	refresh: (number) -> (),
	step: () -> (),
	beforeHandoff: (number) -> boolean,
	recover: (number) -> (),
	busy: (number) -> boolean,
	destroy: () -> (),
}
function Service.create(deps: Dependencies): Controller
	local entries: { [number]: Entry } = {}
	local active = true
	local function selection(owner: Owner): Movement.Selection
		local owned, fresh = owner.ownership("movement")
		return {
			ready = owner.ready(),
			owned = owned,
			fresh = fresh,
			enabled = owner.preferences().movement,
		}
	end
	local function send(userId: number, entry: Entry)
		local owner, prefs = entry.owner, entry.owner.preferences()
		local owned, fresh = owner.ownership("auto_collect")
		local selected = selection(owner)
		entry.sequence += 1
		deps.notify(userId, {
			sequence = entry.sequence,
			open = owner.open.view(),
			openAllowed = owner.openAllowed(),
			collectEnabled = prefs.autoCollect,
			collectAllowed = owner.ready() and owned and fresh,
			collectReason = owner.collect.reason(),
			movementEnabled = prefs.movement,
			movementAllowed = selected.ready and selected.owned and selected.fresh,
			speed = Movement.resolve(selected),
		})
	end
	local function remove(userId: number)
		local entry = entries[userId]
		if not entry then
			return
		end
		entries[userId] = nil
		entry.owner.open.destroy()
		entry.owner.collect.destroy()
		-- PlayerMovement binding remains owned by existing player lifecycle.
	end
	return {
		add = function(userId, owner)
			if not active or entries[userId] then
				return false
			end
			entries[userId] = {
				owner = owner,
				sequence = 0,
				tokens = 4,
				tokenTime = deps.now(),
				requests = {},
				count = 0,
				serial = 0,
			}
			return true
		end,
		remove = remove,
		refresh = function(userId)
			local entry = entries[userId]
			if entry then
				Movement.update(entry.owner.binding, selection(entry.owner))
				send(userId, entry)
			end
		end,
		receive = function(userId, raw)
			local entry = entries[userId]
			if not active or not entry then
				return false
			end
			local now = deps.now()
			entry.tokens = math.min(4, entry.tokens + math.max(0, now - entry.tokenTime))
			entry.tokenTime = now
			local request = Protocol.parse(raw)
			if request and request.serial <= entry.serial then
				local prior = entry.requests[request.id]
				if prior and Protocol.same(prior, request) and entry.tokens >= 1 then
					entry.tokens -= 1
					send(userId, entry)
					return true
				end
				return false
			end
			-- Always honor a valid Stop, even after rapid controls exhaust the bucket.
			if
				request
				and (
					request.action == "Stop"
					or (request.action == "Collection" and request.collection == "")
				)
			then
				entry.serial = request.serial
				if request.action == "Collection" and entry.owner.collection then
					entry.owner.collection("")
				end
				entry.owner.open.stop(
					if request.action == "Stop" then "Stopped by you" else "Opening flow closed"
				)
				if entry.tokens >= 1 then
					entry.tokens -= 1
					send(userId, entry)
				end
				return true
			end
			if entry.tokens < 1 then
				return false
			end
			entry.tokens -= 1
			if not request then
				return false
			end
			entry.serial = request.serial
			local prior = entry.requests[request.id]
			if prior then
				if not Protocol.same(prior, request) then
					return false
				end
				send(userId, entry)
				return true
			end
			local owner = entry.owner
			if
				request.action == "Start"
				or request.action == "AutoCollect"
				or request.action == "Movement"
			then
				if entry.count >= 256 then
					return false
				end
				-- Retain even rejected starts: replay can never resurrect spending after Stop.
				entry.requests[request.id] = request
				entry.count += 1
			end
			local ok = true
			if request.action == "Start" then
				ok = owner.open.start(
					request.collection :: string,
					request.limit :: number,
					request.reserve :: number
				)
			elseif request.action == "Collection" then
				if owner.collection then
					owner.collection(request.collection :: string)
				end
				owner.open.collection(request.collection :: string)
			elseif request.action == "Presented" then
				ok = owner.open.presented(request.requestId :: string)
			elseif request.action == "AutoCollect" or request.action == "Movement" then
				local key = if request.action == "AutoCollect" then "auto_collect" else "movement"
				local owned, fresh = owner.ownership(key)
				ok = owner.ready() and (request.enabled == false or (owned and fresh))
				if ok then
					ok = owner.setPreference(key, request.enabled :: boolean)
				end
			end
			Movement.update(owner.binding, selection(owner))
			send(userId, entry)
			return ok
		end,
		step = function()
			if not active then
				return
			end
			for userId, entry in entries do
				entry.owner.open.step()
				entry.owner.collect.step()
				Movement.update(entry.owner.binding, selection(entry.owner))
				send(userId, entry)
			end
		end,
		beforeHandoff = function(userId)
			local entry = entries[userId]
			if not entry then
				return true
			end
			entry.owner.open.stop("AFK reconnect")
			if entry.owner.open.busy() then
				return false
			end
			entry.owner.collect.pause()
			return true
		end,
		recover = function(userId)
			local entry = entries[userId]
			if entry and entry.owner.ready() then
				entry.owner.collect.resume()
			end
		end,
		busy = function(userId)
			local entry = entries[userId]
			return entry ~= nil and entry.owner.open.busy()
		end,
		destroy = function()
			active = false
			for userId in entries do
				remove(userId)
			end
		end,
	}
end
return Service
