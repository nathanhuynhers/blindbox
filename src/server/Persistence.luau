--!strict
-- UpdateAsync is injected only for deterministic storage fault tests. No alternate game backend.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Profile = require(script.Parent.Profile)
local Rules = require(script.Parent.Rules)
export type Record = {
	data: Types.Profile,
	token: string,
	expires: number,
	generation: number,
	writer: string,
}
export type Update = (string, (unknown) -> unknown) -> unknown
export type Handle = { key: string, token: string, generation: number }
local Persistence = { leaseSeconds = 120, safeSeconds = 85, saveSeconds = 30 }
local function record(raw: unknown): Record?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	local keys = 0
	for key in value do
		keys += 1
		if
			keys > 5
			or (
				key ~= "data"
				and key ~= "token"
				and key ~= "writer"
				and key ~= "expires"
				and key ~= "generation"
			)
		then
			return nil
		end
	end
	if
		typeof(value.writer) ~= "string"
		or #value.writer > 128
		or typeof(value.token) ~= "string"
		or #value.token > 128
		or typeof(value.expires) ~= "number"
		or value.expires % 1 ~= 0
		or value.expires < 0
		or value.expires >= math.huge
		or typeof(value.generation) ~= "number"
		or value.generation < 0
		or value.generation % 1 ~= 0
		or value.generation > 9007199254740990
	then
		return nil
	end
	local decoded = Profile.decode(value.data, 0)
	if not decoded then
		return nil
	end
	return {
		data = Profile.encode(decoded),
		token = value.token,
		writer = value.writer,
		expires = value.expires,
		generation = value.generation,
	}
end
function Persistence.load(
	update: Update,
	key: string,
	token: string,
	wall: number,
	now: number
): (Handle?, Types.State?, string)
	local reason = "Storage unavailable. Your saved progress has not been replaced."
	local ok, result = pcall(update, key, function(raw: unknown): unknown
		local old: Record? = nil
		if raw ~= nil then
			old = record(raw)
			if not old then
				reason = "Saved data needs recovery; no changes made."
				return nil
			end
			if old.token ~= "" and old.token ~= token and old.expires > wall then
				reason = "Your showroom is open in another server. Please rejoin shortly."
				return nil
			end
		end
		local data = if old then old.data else Profile.encode(Rules.new(now))
		return {
			data = data,
			writer = token,
			token = token,
			expires = wall + Persistence.leaseSeconds,
			generation = if old then old.generation else 0,
		}
	end)
	if not ok then
		return nil, nil, reason
	end
	local loaded = record(result)
	if not loaded or loaded.token ~= token then
		return nil, nil, reason
	end
	local state = Profile.decode(loaded.data, now)
	return { key = key, token = token, generation = loaded.generation }, state, "Saved"
end
function Persistence.save(
	update: Update,
	handle: Handle,
	data: Types.Profile,
	wall: number,
	release: boolean
): (boolean, string)
	if not Profile.decode(data, 0) then
		return false, "Refusing invalid profile snapshot."
	end
	local nextGeneration = handle.generation + 1
	local reason = "Saving unavailable; progress is paused while reconnecting."
	local ok, result = pcall(update, handle.key, function(raw: unknown): unknown
		local old = record(raw)
		if not old then
			reason = "Saved data became incompatible; write blocked."
			return nil
		end
		-- Retry an uncertain committed save without rewriting an older snapshot.
		if
			old.generation == nextGeneration
			and old.writer == handle.token
			and old.token == (if release then "" else handle.token)
		then
			if not release then
				if old.expires <= wall then
					reason = "Session ownership expired; write blocked."
					return nil
				end
				old.expires = wall + Persistence.leaseSeconds
			end
			return old
		end
		if
			old.token ~= handle.token
			or old.expires <= wall
			or old.generation ~= handle.generation
		then
			reason = "Session ownership lost; write blocked."
			return nil
		end
		return {
			data = data,
			writer = handle.token,
			token = if release then "" else handle.token,
			expires = if release then 0 else wall + Persistence.leaseSeconds,
			generation = nextGeneration,
		}
	end)
	if not ok then
		return false, reason
	end
	local saved = record(result)
	if
		not saved
		or saved.writer ~= handle.token
		or saved.generation ~= nextGeneration
		or saved.token ~= (if release then "" else handle.token)
	then
		return false, reason
	end
	handle.generation = nextGeneration
	return true, "Saved"
end
return Persistence
