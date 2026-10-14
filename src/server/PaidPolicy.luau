--!strict
export type Status = "Allowed" | "Restricted" | "Unknown"
export type Dependencies = {
	now: () -> number,
	fetch: (number) -> unknown,
	changed: (number) -> (),
}
type Entry =
	{ status: Status, expires: number, retryAt: number, failures: number, working: boolean }
local Policy = {}
function Policy.create(deps: Dependencies)
	local entries: { [number]: Entry } = {}
	local api = {}
	function api.add(userId: number)
		entries[userId] =
			{ status = "Unknown", expires = 0, retryAt = 0, failures = 0, working = false }
	end
	function api.remove(userId: number)
		entries[userId] = nil
	end
	function api.status(userId: number): Status
		local entry = entries[userId]
		return if entry and deps.now() < entry.expires then entry.status else "Unknown"
	end
	function api.refresh(userId: number)
		local entry = entries[userId]
		if not entry or entry.working or deps.now() < entry.retryAt then
			return
		end
		entry.working = true
		if deps.now() >= entry.expires and entry.status ~= "Unknown" then
			entry.status = "Unknown"
			deps.changed(userId)
		end
		local ok, raw = pcall(deps.fetch, userId)
		if entries[userId] ~= entry then
			return
		end
		local restricted: boolean? = nil
		if ok and typeof(raw) == "table" then
			local value = (raw :: { [string]: unknown }).ArePaidRandomItemsRestricted
			if typeof(value) == "boolean" then
				restricted = value
			end
		end
		entry.working = false
		if restricted == nil then
			entry.status, entry.expires = "Unknown", 0
			entry.failures = math.min(6, entry.failures + 1)
			entry.retryAt = deps.now() + math.min(60, 2 ^ entry.failures)
		else
			entry.status = if restricted then "Restricted" else "Allowed"
			entry.failures = 0
			entry.expires = deps.now() + 60
			entry.retryAt = entry.expires
		end
		deps.changed(userId)
	end
	function api.due(): { number }
		local due: { number } = {}
		for userId, entry in entries do
			if not entry.working and deps.now() >= entry.retryAt then
				table.insert(due, userId)
			end
		end
		return due
	end
	function api.destroy()
		table.clear(entries)
	end
	return api
end
return Policy
