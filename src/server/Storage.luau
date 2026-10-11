--!strict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Settings = require(script.Parent.Settings)
local Persistence = require(script.Parent.Persistence)
local Profile = require(script.Parent.Profile)
local Rules = require(script.Parent.Rules)
export type Session = {
	state: Types.State,
	handle: Persistence.Handle?,
	ready: boolean,
	status: string,
	safeUntil: number,
	nextSave: number,
	busy: boolean,
	closed: boolean,
	transferring: boolean,
	released: boolean,
	pendingSave: Types.Profile?,
	pendingRelease: Types.Profile?,
}
local Storage = {}
local studioPersistence = Settings.studioPersistence
	or game:GetService("ServerScriptService"):GetAttribute("StudioPersistenceTest") == true
local preview = RunService:IsStudio() and not studioPersistence
local store: GlobalDataStore? = nil
if not preview then
	store = DataStoreService:GetDataStore(
		if RunService:IsStudio() then Settings.studioStore else Settings.liveStore
	)
end
local function update(key: string, transform: (unknown) -> unknown): unknown
	assert(store, "Persistent storage is not enabled")
	return store:UpdateAsync(key, function(raw: unknown)
		return transform(raw)
	end)
end
function Storage.open(userId: number): (Session?, string)
	local started = os.clock()
	if preview then
		return {
			state = Rules.new(started),
			handle = nil,
			ready = true,
			status = "Studio preview - not saved",
			safeUntil = math.huge,
			nextSave = math.huge,
			busy = false,
			closed = false,
			transferring = false,
			released = false,
			pendingSave = nil,
			pendingRelease = nil,
		},
			""
	end
	local token = HttpService:GenerateGUID(false)
	local reason = "Could not load your progress. Please rejoin."
	for attempt = 1, 4 do
		started = os.clock()
		local handle, state, message =
			Persistence.load(update, "Player_" .. userId, token, os.time(), started)
		if handle and state then
			if os.clock() - started >= Persistence.safeSeconds then
				Persistence.save(update, handle, Profile.encode(state), os.time(), true)
				return nil, "Loading took too long. Please rejoin; your data is protected."
			end
			state.time = os.clock()
			-- The lease guarantees one server per profile, so this runs once per join.
			Rules.offline(state, os.time())
			return {
				state = state,
				handle = handle,
				ready = true,
				status = "Saved",
				safeUntil = started + Persistence.safeSeconds,
				nextSave = os.clock() + Persistence.saveSeconds,
				busy = false,
				closed = false,
				transferring = false,
				released = false,
				pendingSave = nil,
				pendingRelease = nil,
			},
				""
		end
		reason = message
		if attempt < 4 then
			task.wait(attempt)
		end
	end
	warn("Profile load blocked", userId, reason)
	return nil, reason
end
function Storage.flush(session: Session, release: boolean): boolean
	if session.busy then
		return false
	end
	-- Confirm the previous autosave's generation with its original snapshot before a
	-- final write changes release mode. A committed save may have lost every reply.
	if release and session.pendingSave and not Storage.flush(session, false) then
		return false
	end
	local handle = session.handle
	if not handle then
		return true
	end
	session.busy = true
	if session.ready then
		Rules.settle(session.state, os.clock())
	end
	if not session.pendingRelease and not session.pendingSave then
		session.state.lastSeen = os.time()
		if release then
			session.pendingRelease = Profile.encode(session.state)
		end
	end
	local snapshot: Types.Profile = session.pendingRelease
		or session.pendingSave
		or Profile.encode(session.state)
	if not release then
		session.pendingSave = snapshot
	end
	session.status = "Saving..."
	local saved = false
	for attempt = 1, 3 do
		local started = os.clock()
		local ok, message = Persistence.save(update, handle, snapshot, os.time(), release)
		if ok then
			session.safeUntil = started + Persistence.safeSeconds
			saved = true
			break
		end
		if session.ready then
			warn("Profile autosave paused", handle.key, message)
		end
		session.status = message
		session.ready = false
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	if saved then
		if release then
			session.released = true
		else
			session.pendingSave = nil
		end
		-- Do not award time spent paused after a failed save.
		if not session.ready and not session.transferring then
			session.state.time = os.clock()
		end
		session.ready = not session.closed
			and not session.transferring
			and os.clock() < session.safeUntil
		session.status = if session.transferring
			then "Moving to a new server..."
			elseif session.ready then "Saved"
			else "Saving paused. Rejoin to reconnect."
	end
	session.nextSave = os.clock() + (if saved then Persistence.saveSeconds else 5)
	session.busy = false
	return saved
end
function Storage.step(session: Session, now: number)
	if session.closed or session.transferring then
		return
	end
	if now >= session.safeUntil then
		session.ready = false
		session.status = "Connection to saved progress expired. Please rejoin."
	end
	if now >= session.nextSave and not session.busy then
		-- flush sets busy before its first yield; at most one write per profile.
		task.spawn(Storage.flush, session, false)
	end
end
function Storage.prepareTeleport(session: Session): boolean
	if
		session.closed
		or session.transferring
		or not session.handle
		or not session.ready
		or os.clock() >= session.safeUntil
	then
		return false
	end
	-- This barrier is set before yielding. All authoritative action paths check it.
	session.transferring = true
	local deadline = os.clock() + 10
	while session.busy and not session.closed and os.clock() < deadline do
		task.wait(0.1)
	end
	if session.closed or session.busy or not session.ready or os.clock() >= session.safeUntil then
		return false
	end
	Rules.settle(session.state, os.clock())
	session.ready = false
	return Storage.flush(session, true)
end
function Storage.recoverTeleport(session: Session): boolean
	if session.closed then
		return false
	end
	if not session.transferring then
		return session.ready
	end
	if session.busy then
		-- Never race an unresolved autosave or handoff write with a reclaim.
		local deadline = os.clock() + 10
		while session.busy and not session.closed and os.clock() < deadline do
			task.wait(0.1)
		end
	end
	if session.closed or session.busy then
		return false
	end
	local handle = session.handle
	if not handle then
		return false
	end
	session.busy = true
	local resumed = false
	for attempt = 1, 3 do
		local started = os.clock()
		local ok, message = Persistence.resume(update, handle, os.time())
		session.status = message
		if ok then
			session.safeUntil = started + Persistence.safeSeconds
			resumed = true
			break
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	if resumed then
		-- No offline award in the source. Resume active banks from the frozen boundary,
		-- then advance lastSeen on the next normal save. Nothing was paid twice.
		if session.pendingRelease then
			Rules.settle(session.state, os.clock())
		else
			session.state.time = os.clock()
		end
		-- Reclaim reconciles retained/committed ownership. The next save must encode
		-- current memory, not replay an autosave from before the handoff barrier.
		session.transferring, session.released, session.pendingRelease, session.pendingSave =
			false, false, nil, nil
		session.ready = not session.closed and os.clock() < session.safeUntil
		session.nextSave = os.clock() -- Persist any catch-up income promptly.
	end
	session.busy = false
	return resumed
end
function Storage.close(session: Session): boolean
	if session.closed then
		return false
	end
	session.closed = true
	if session.ready then
		Rules.settle(session.state, os.clock())
	end
	session.ready = false
	local deadline = os.clock() + 20
	while session.busy and os.clock() < deadline do
		task.wait(0.1)
	end
	if session.busy then
		return false
	end
	if session.released then
		-- The immutable handoff checkpoint is already saved and unlocked. A departed
		-- source must never write over the destination's newly acquired generation.
		return true
	end
	return Storage.flush(session, true)
end
return Storage
