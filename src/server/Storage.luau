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
		},
			""
	end
	local token = HttpService:GenerateGUID(false)
	local reason = "Could not load your showroom. Please rejoin."
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
			return {
				state = state,
				handle = handle,
				ready = true,
				status = "Saved",
				safeUntil = started + Persistence.safeSeconds,
				nextSave = os.clock() + Persistence.saveSeconds,
				busy = false,
				closed = false,
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
	local handle = session.handle
	if not handle then
		return true
	end
	session.busy = true
	if session.ready then
		Rules.settle(session.state, os.clock())
	end
	local snapshot = Profile.encode(session.state)
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
		-- Do not award time spent paused after a failed save.
		if not session.ready then
			session.state.time = os.clock()
		end
		session.ready = not session.closed and os.clock() < session.safeUntil
		session.status = if session.ready then "Saved" else "Saving paused. Rejoin to reconnect."
	end
	session.nextSave = os.clock() + (if saved then Persistence.saveSeconds else 5)
	session.busy = false
	return saved
end
function Storage.step(session: Session, now: number)
	if session.closed then
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
	return Storage.flush(session, true)
end
return Storage
