--!strict
-- I/O is injected so the actual handoff state machine can be fault-tested without teleports.
local Config = require(game:GetService("ReplicatedStorage").Shared.AfkConfig)
local Idle = require(game:GetService("ReplicatedStorage").Shared.AfkIdle)
type Phase =
	"idle"
	| "offer"
	| "preparing"
	| "confirm"
	| "teleporting"
	| "retry"
	| "aborting"
	| "recovering"
type Entry = {
	lastActivity: number,
	idleSince: number?,
	lastIdle: number,
	lastReport: number,
	phase: Phase,
	token: string,
	call: number,
	deadline: number,
	exhausted: boolean,
	inFlight: boolean,
	flightDeadline: number,
	prepared: boolean,
}
export type Dependencies = {
	now: () -> number,
	token: () -> string,
	spawn: (() -> ()) -> (),
	available: (Player) -> boolean,
	prepare: (Player) -> boolean,
	recover: (Player) -> boolean,
	teleport: (Player, string, number) -> (),
	notify: (Player, string, string) -> (),
	log: (Player, string) -> (),
}
export type Controller = {
	add: (Player) -> (),
	remove: (Player) -> (),
	activity: (Player) -> (),
	receive: (Player, unknown) -> (),
	failed: (Player, string, number) -> (),
	step: () -> (),
	destroy: () -> (),
}
local Reconnect = {}
local function currentPhase(entry: Entry): Phase
	-- Async callbacks may change this while another callback is yielded.
	return entry.phase
end
local function packet(raw: unknown): (string?, number?, string?)
	if typeof(raw) ~= "table" then
		return nil, nil, nil
	end
	local value = raw :: { [string]: unknown }
	local count = 0
	for key in value do
		count += 1
		if count > 3 or (key ~= "action" and key ~= "idle" and key ~= "token") then
			return nil, nil, nil
		end
	end
	local action, idle, token = value.action, value.idle, value.token
	if action == "Active" and count == 1 then
		return action, nil, nil
	end
	if action == "Busy" and count == 2 and typeof(token) == "string" and #token <= 64 then
		return action, nil, token
	end
	if
		(action ~= "Idle" and action ~= "Confirm")
		or typeof(idle) ~= "number"
		or idle ~= idle
		or idle < 0
		or idle > Config.idleLimitSeconds
	then
		return nil, nil, nil
	end
	if action == "Idle" and count == 2 then
		return action, idle, nil
	elseif action == "Confirm" and count == 3 and typeof(token) == "string" and #token <= 64 then
		return action, idle, token
	end
	return nil, nil, nil
end
function Reconnect.create(deps: Dependencies): Controller
	local entries: { [Player]: Entry } = {}
	local function current(player: Player, entry: Entry): boolean
		return entries[player] == entry
	end
	local function eligible(entry: Entry): boolean
		local now = deps.now()
		return entry.idleSince ~= nil
			and now - entry.idleSince >= Idle.threshold()
			and now - entry.lastActivity >= Idle.threshold()
			and now - entry.lastIdle <= Config.idleFreshSeconds
	end
	local function recover(player: Player, entry: Entry)
		if entry.inFlight or entry.phase == "recovering" then
			return
		end
		if not entry.prepared then
			entry.phase = "idle"
			return
		end
		entry.phase, entry.inFlight = "recovering", true
		deps.spawn(function()
			local ok, resumed = pcall(deps.recover, player)
			if not current(player, entry) then
				return
			end
			entry.inFlight, entry.prepared, entry.phase = false, false, "idle"
			if not ok or not resumed then
				deps.log(player, "Profile recovery unavailable; gameplay remains paused.")
			end
		end)
	end
	local function abort(player: Player, entry: Entry, failed: boolean)
		if entry.phase == "idle" or entry.phase == "recovering" or entry.phase == "aborting" then
			return
		end
		entry.phase = "aborting"
		entry.exhausted = entry.exhausted or failed
		deps.notify(player, if failed then "Failed" else "Cancelled", entry.token)
		recover(player, entry)
	end
	local function challenge(player: Player, entry: Entry, phase: Phase)
		entry.phase, entry.deadline = phase, deps.now() + Config.confirmSeconds
		-- New token for every confirmation invalidates delayed acknowledgements.
		entry.token = deps.token()
		deps.notify(player, "Check", entry.token)
	end
	local function failure(player: Player, entry: Entry)
		if entry.phase ~= "teleporting" then
			return
		end
		if entry.call > Config.maxRetries or not eligible(entry) then
			abort(player, entry, true)
		else
			entry.phase = "retry"
			entry.deadline = deps.now() + (Config.retryDelays[entry.call] or 8)
		end
	end
	local function activity(player: Player)
		local entry = entries[player]
		if not entry then
			return
		end
		entry.lastActivity, entry.idleSince, entry.lastIdle = deps.now(), nil, -math.huge
		entry.exhausted = false
		abort(player, entry, false)
	end
	return {
		add = function(player)
			if not entries[player] then
				entries[player] = {
					lastActivity = deps.now(),
					idleSince = nil,
					lastIdle = -math.huge,
					lastReport = -math.huge,
					phase = "idle",
					token = "",
					call = 0,
					deadline = 0,
					exhausted = false,
					inFlight = false,
					flightDeadline = 0,
					prepared = false,
				}
			end
		end,
		remove = function(player)
			-- Yielding I/O may finish, but its result can no longer start a teleport or recovery.
			entries[player] = nil
		end,
		activity = activity,
		receive = function(player, raw)
			local entry = entries[player]
			if not entry or not Config.enabled then
				return
			end
			local action, duration, token = packet(raw)
			if action == "Active" then
				activity(player)
				return
			end
			local now = deps.now()
			if action == "Busy" and token == entry.token then
				-- A live animation/request is activity; retry only after a new idle interval.
				activity(player)
				return
			end
			if not duration then
				return
			end
			if action == "Idle" then
				if now - entry.lastReport < Config.reportSeconds - 1 then
					return
				end
				entry.lastReport = now
				entry.lastIdle = now
				if not entry.idleSince then
					-- Backdate only the first detection delay, never an arbitrary client duration.
					entry.idleSince = math.max(
						entry.lastActivity,
						now - math.min(duration, Config.initialIdleCreditSeconds)
					)
				end
				if
					entry.phase == "idle"
					and not entry.exhausted
					and eligible(entry)
					and deps.available(player)
				then
					entry.call = 0
					challenge(player, entry, "offer")
				end
				return
			end
			if
				action ~= "Confirm"
				or token ~= entry.token
				or now > entry.deadline
				or (entry.phase ~= "offer" and entry.phase ~= "confirm")
			then
				return
			end
			if duration < Idle.threshold() or not eligible(entry) then
				activity(player)
				return
			end
			if entry.phase == "offer" then
				if not deps.available(player) then
					abort(player, entry, true)
					return
				end
				entry.phase, entry.inFlight, entry.prepared = "preparing", true, true
				entry.deadline = now + Config.prepareSeconds
				entry.flightDeadline = entry.deadline
				deps.notify(player, "Begin", entry.token)
				deps.spawn(function()
					local ok, saved = pcall(deps.prepare, player)
					if not current(player, entry) then
						return
					end
					entry.inFlight = false
					if currentPhase(entry) == "aborting" then
						recover(player, entry)
					elseif not ok or not saved then
						deps.log(player, "Profile handoff save failed; teleport blocked.")
						abort(player, entry, true)
					elseif not eligible(entry) or deps.now() > entry.deadline then
						abort(player, entry, true)
					else
						challenge(player, entry, "confirm")
					end
				end)
			else
				entry.call += 1
				entry.phase, entry.inFlight = "teleporting", true
				entry.deadline = now + Config.initializationSeconds
				entry.flightDeadline = entry.deadline
				local attemptToken, call = entry.token, entry.call
				deps.notify(player, "Depart", attemptToken)
				deps.spawn(function()
					-- Check again inside the spawned task, immediately before the yielding API.
					if not current(player, entry) then
						return
					end
					if currentPhase(entry) ~= "teleporting" or not eligible(entry) then
						entry.inFlight = false
						abort(player, entry, false)
						recover(player, entry)
						return
					end
					local ok = pcall(deps.teleport, player, attemptToken, call)
					if not current(player, entry) then
						return
					end
					entry.inFlight = false
					if currentPhase(entry) == "aborting" then
						recover(player, entry)
					elseif not ok then
						deps.log(player, "TeleportAsync failed.")
						failure(player, entry)
					end
				end)
			end
		end,
		failed = function(player, token, call)
			local entry = entries[player]
			if
				entry
				and entry.phase == "teleporting"
				and entry.token == token
				and entry.call == call
			then
				deps.log(player, "TeleportInitFailed.")
				failure(player, entry)
			end
		end,
		step = function()
			for player, entry in entries do
				if
					entry.phase == "idle"
					or entry.phase == "recovering"
					or entry.phase == "aborting"
				then
					continue
				end
				if entry.inFlight and deps.now() >= entry.flightDeadline then
					deps.log(
						player,
						"Reconnect I/O timed out; waiting for its result before recovery."
					)
					abort(player, entry, true)
				elseif not eligible(entry) then
					entry.exhausted = true
					abort(player, entry, false)
				elseif
					entry.phase == "retry"
					and deps.now() >= entry.deadline
					and not entry.inFlight
				then
					challenge(player, entry, "confirm")
				elseif entry.phase ~= "retry" and deps.now() >= entry.deadline then
					-- A timeout does not prove the API stopped. Never issue overlapping retries.
					deps.log(player, "Reconnect initialization timed out.")
					abort(player, entry, true)
				end
			end
		end,
		destroy = function()
			table.clear(entries)
		end,
	}
end
return Reconnect
