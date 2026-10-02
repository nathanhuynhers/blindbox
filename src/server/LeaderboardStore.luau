--!strict
-- Pure global-leaderboard bookkeeping with injected I/O, so it can be tested without Roblox.
-- Writes are coalesced per (stat, player), skipped when unchanged, gated by request budget and
-- retried with exponential backoff. Reads keep the last good page on any failure.
export type TopEntry = { userId: number, value: number }
export type Io = {
	-- Each may yield or throw; the store wraps every call.
	write: (stat: string, userId: number, value: number) -> (),
	read: (stat: string, count: number) -> { TopEntry },
	budget: (kind: "write" | "read") -> number,
}
export type Options = {
	stats: { string },
	topCount: number,
	readSeconds: number,
	backoffBase: number,
	backoffMax: number,
	writeReserve: number,
	readReserve: number,
	maxPending: number,
	writesPerPump: number,
}
type Pending = { stat: string, userId: number, value: number }
export type Store = {
	io: Io,
	options: Options,
	pending: { [string]: Pending },
	order: { string },
	written: { [string]: number },
	top: { [string]: { TopEntry } },
	loaded: { [string]: boolean },
	writeFailures: number,
	writeBlockedUntil: number,
	readFailures: number,
	nextRead: number,
}

local Store = {}

local function key(stat: string, userId: number): string
	return stat .. ":" .. userId
end

-- Ordered data stores hold integers; anything else is clamped to a safe non-negative integer.
function Store.sanitize(value: number): number
	if value ~= value or value <= 0 then
		return 0
	end
	return math.min(math.floor(value), 2 ^ 53)
end

local function backoff(options: Options, failures: number): number
	return math.min(options.backoffMax, options.backoffBase * 2 ^ math.max(0, failures - 1))
end

function Store.new(io: Io, options: Options): Store
	local store: Store = {
		io = io,
		options = options,
		pending = {},
		order = {},
		written = {},
		top = {},
		loaded = {},
		writeFailures = 0,
		writeBlockedUntil = -math.huge,
		readFailures = 0,
		nextRead = -math.huge,
	}
	for _, stat in options.stats do
		store.top[stat] = {}
		store.loaded[stat] = false
	end
	return store
end

-- Non-yielding. Queues only values that differ from the last confirmed or queued write.
function Store.offer(store: Store, userId: number, values: { [string]: number }): number
	local queued = 0
	for _, stat in store.options.stats do
		local raw = values[stat]
		if raw ~= nil then
			local value = Store.sanitize(raw)
			local id = key(stat, userId)
			local existing = store.pending[id]
			if existing then
				existing.value = value
			elseif store.written[id] ~= value then
				if #store.order >= store.options.maxPending then
					local dropped = table.remove(store.order, 1)
					if dropped then
						store.pending[dropped] = nil
					end
				end
				store.pending[id] = { stat = stat, userId = userId, value = value }
				table.insert(store.order, id)
				queued += 1
			end
		end
	end
	return queued
end

function Store.pendingCount(store: Store): number
	return #store.order
end

-- Performs up to `writesPerPump` writes. Returns the number confirmed.
function Store.pump(store: Store, now: number): number
	if now < store.writeBlockedUntil then
		return 0
	end
	local confirmed = 0
	for _ = 1, store.options.writesPerPump do
		local id = store.order[1]
		if not id then
			break
		end
		local okBudget, budget = pcall(function()
			return store.io.budget("write")
		end)
		if not okBudget or typeof(budget) ~= "number" or budget <= store.options.writeReserve then
			break
		end
		table.remove(store.order, 1)
		local item = store.pending[id]
		store.pending[id] = nil
		if item then
			local ok = pcall(store.io.write, item.stat, item.userId, item.value)
			if ok then
				store.written[id] = item.value
				store.writeFailures = 0
				confirmed += 1
			else
				-- Requeue at the front unless a newer value arrived while the call yielded.
				if not store.pending[id] then
					store.pending[id] = item
					table.insert(store.order, 1, id)
				end
				store.writeFailures += 1
				store.writeBlockedUntil = now + backoff(store.options, store.writeFailures)
				break
			end
		end
	end
	return confirmed
end

local function validEntries(raw: unknown, count: number): { TopEntry }?
	if typeof(raw) ~= "table" then
		return nil
	end
	local entries: { TopEntry } = {}
	for _, entry in raw :: { unknown } do
		if #entries >= count then
			break
		end
		if typeof(entry) == "table" then
			local record = entry :: { [string]: unknown }
			local userId, value = record.userId, record.value
			if
				typeof(userId) == "number"
				and userId % 1 == 0
				and typeof(value) == "number"
				and value == value
				and value >= 0
			then
				table.insert(entries, { userId = userId, value = math.floor(value) })
			end
		end
	end
	return entries
end

-- Reads every stat when due. On any failure the previous page stays and reads back off.
function Store.refresh(store: Store, now: number): boolean
	if now < store.nextRead then
		return false
	end
	local refreshed = true
	for _, stat in store.options.stats do
		local okBudget, budget = pcall(function()
			return store.io.budget("read")
		end)
		if not okBudget or typeof(budget) ~= "number" or budget <= store.options.readReserve then
			refreshed = false
			break
		end
		local ok, result = pcall(store.io.read, stat, store.options.topCount)
		local entries = if ok then validEntries(result, store.options.topCount) else nil
		if entries then
			store.top[stat] = entries
			store.loaded[stat] = true
		else
			refreshed = false
			break
		end
	end
	if refreshed then
		store.readFailures = 0
		store.nextRead = now + store.options.readSeconds
	else
		store.readFailures += 1
		store.nextRead = now + backoff(store.options, store.readFailures)
	end
	return refreshed
end

return Store
