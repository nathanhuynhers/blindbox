--!strict
-- Global, presentation-only leaderboard. Scores are written to one OrderedDataStore per stat on a
-- throttled cadence and on leave; the top entries are read every ~90 s. Every DataStore and name
-- call runs on background threads wrapped in pcall, so gameplay never waits on it. Grants nothing.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Board = require(script.Parent.LeaderboardBoard)
local Settings = require(script.Parent.Settings)
local Stats = require(script.Parent.LeaderboardStats)
local Store = require(script.Parent.LeaderboardStore)

local Leaderboard = {}
Leaderboard.config = table.freeze({
	topCount = 5,
	pageSeconds = 8,
	readSeconds = 90,
	writeSeconds = 60,
	tickSeconds = 2,
	backoffBase = 5,
	backoffMax = 120,
	writeReserve = 2,
	readReserve = 1,
	maxPending = 128,
	writesPerPump = 6,
	nameCacheLimit = 256,
})
Leaderboard.stats = Stats.list
Leaderboard.statsOf = Stats.of
Leaderboard.format = Stats.format
local config = Leaderboard.config

local storeName = if RunService:IsStudio()
	then Settings.studioLeaderboard
	else Settings.liveLeaderboard
local ordered: { [string]: OrderedDataStore } = {}
local function orderedStore(stat: string): OrderedDataStore
	local store = ordered[stat]
	if not store then
		store = DataStoreService:GetOrderedDataStore(storeName, stat)
		ordered[stat] = store
	end
	return store
end

local io: Store.Io = {
	write = function(stat: string, userId: number, value: number)
		orderedStore(stat):SetAsync(tostring(userId), value)
	end,
	read = function(stat: string, count: number): { Store.TopEntry }
		local pages = orderedStore(stat):GetSortedAsync(false, count)
		local entries: { Store.TopEntry } = {}
		for _, entry in pages:GetCurrentPage() do
			local userId = tonumber(entry.key)
			if userId and typeof(entry.value) == "number" then
				table.insert(entries, { userId = userId, value = entry.value })
			end
		end
		return entries
	end,
	budget = function(kind: "write" | "read"): number
		return DataStoreService:GetRequestBudgetForRequestType(
			if kind == "write"
				then Enum.DataStoreRequestType.SetIncrementSortedAsync
				else Enum.DataStoreRequestType.GetSortedAsync
		)
	end,
}

type Service = {
	store: Store.Store,
	board: Board.Board,
	page: number,
	lastOffer: { [number]: number },
	names: { [number]: string },
	nameCount: number,
	threads: { thread },
	warned: boolean,
}
local service: Service? = nil

local function resolveNames(current: Service)
	local missing: { number } = {}
	for _, entries in current.store.top do
		for _, entry in entries do
			local player = Players:GetPlayerByUserId(entry.userId)
			if player then
				current.names[entry.userId] = player.DisplayName
			elseif not current.names[entry.userId] and entry.userId > 0 then
				table.insert(missing, entry.userId)
			end
		end
	end
	if #missing == 0 then
		return
	end
	if current.nameCount + #missing > config.nameCacheLimit then
		table.clear(current.names)
		current.nameCount = 0
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and typeof(infos) == "table" then
		for _, info in infos do
			if
				typeof(info) == "table"
				and typeof(info.Id) == "number"
				and typeof(info.DisplayName) == "string"
			then
				current.names[info.Id] = info.DisplayName
				current.nameCount += 1
			end
		end
	end
	for _, userId in missing do
		if not current.names[userId] then
			local found, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if found and typeof(name) == "string" then
				current.names[userId] = name
				current.nameCount += 1
			end
		end
	end
end

local function render(current: Service)
	local stat = Leaderboard.stats[current.page]
	local entries = current.store.top[stat.key]
	local lines: { Board.Line } = {}
	for _, entry in entries do
		table.insert(lines, {
			name = current.names[entry.userId] or "…",
			value = Leaderboard.format(stat.key, entry.value),
		})
	end
	local status = if current.store.loaded[stat.key]
		then (if #entries == 0 then "No scores yet" else "All servers")
		elseif current.store.readFailures > 0 then "Leaderboard unavailable, retrying"
		else "Loading..."
	Board.show(current.board, current.page, stat.title, lines, status)
end

function Leaderboard.start(board: Board.Board)
	assert(service == nil, "Leaderboard already started")
	local current: Service = {
		store = Store.new(io, {
			stats = Stats.keys(),
			topCount = config.topCount,
			readSeconds = config.readSeconds,
			backoffBase = config.backoffBase,
			backoffMax = config.backoffMax,
			writeReserve = config.writeReserve,
			readReserve = config.readReserve,
			maxPending = config.maxPending,
			writesPerPump = config.writesPerPump,
		}),
		board = board,
		page = 1,
		lastOffer = {},
		names = {},
		nameCount = 0,
		threads = {},
		warned = false,
	}
	service = current
	render(current)
	table.insert(
		current.threads,
		task.spawn(function()
			while true do
				task.wait(config.pageSeconds)
				current.page = current.page % #Leaderboard.stats + 1
				render(current)
			end
		end)
	)
	table.insert(
		current.threads,
		task.spawn(function()
			while true do
				local now = os.clock()
				Store.pump(current.store, now)
				local before = current.store.readFailures
				if Store.refresh(current.store, now) then
					resolveNames(current)
					render(current)
				elseif current.store.readFailures ~= before then
					render(current)
				end
				local failing = current.store.writeFailures > 0 or current.store.readFailures > 0
				if failing and not current.warned then
					warn(
						"Leaderboard DataStore requests are failing; showing last good data and retrying."
					)
				end
				current.warned = failing
				task.wait(config.tickSeconds)
			end
		end)
	)
end

-- Called often (every second) from the server clock; offers at most once per `writeSeconds`.
function Leaderboard.observe(userId: number, state: Types.State, now: number)
	local current = service
	if not current then
		return
	end
	local last = current.lastOffer[userId]
	if last and now - last < config.writeSeconds then
		return
	end
	current.lastOffer[userId] = now
	Store.offer(current.store, userId, Leaderboard.statsOf(state))
end

-- Final scores on leave bypass the throttle (unchanged values are still skipped).
function Leaderboard.final(userId: number, state: Types.State)
	local current = service
	if not current then
		return
	end
	current.lastOffer[userId] = nil
	Store.offer(current.store, userId, Leaderboard.statsOf(state))
end

-- Stops the loops and spends at most until `deadline` (os.clock) flushing queued writes.
function Leaderboard.stop(deadline: number)
	local current = service
	if not current then
		return
	end
	service = nil
	for _, thread in current.threads do
		if coroutine.status(thread) ~= "dead" then
			task.cancel(thread)
		end
	end
	while Store.pendingCount(current.store) > 0 and os.clock() < deadline do
		if Store.pump(current.store, os.clock()) == 0 then
			task.wait(0.5)
		end
	end
end

return Leaderboard
