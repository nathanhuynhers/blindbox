--!strict
local Currency = require(game:GetService("ReplicatedStorage").Shared.Currency)
local Wire = require(game:GetService("ReplicatedStorage").Shared.ConvenienceTypes)
local Protocol = {}
local function integer(value: unknown, low: number, high: number): boolean
	return typeof(value) == "number"
		and value == value
		and value >= low
		and value <= high
		and value % 1 == 0
end
local function identifier(value: unknown): boolean
	return typeof(value) == "string" and #value >= 1 and #value <= 64
end
function Protocol.parse(raw: unknown): Wire.Request?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	if not identifier(value.id) or not integer(value.serial, 1, 1e9) then
		return nil
	end
	local action = value.action
	local allowed: { [string]: boolean } = { id = true, serial = true, action = true }
	if action == "Start" then
		allowed.collection, allowed.limit, allowed.reserve = true, true, true
		if
			not identifier(value.collection)
			or not integer(value.limit, 1, 100)
			or not integer(value.reserve, 0, Currency.limit)
		then
			return nil
		end
	elseif action == "Collection" then
		allowed.collection = true
		if typeof(value.collection) ~= "string" or #value.collection > 64 then
			return nil
		end
	elseif action == "Presented" then
		allowed.requestId = true
		if not identifier(value.requestId) then
			return nil
		end
	elseif action == "AutoCollect" or action == "Movement" then
		allowed.enabled = true
		if typeof(value.enabled) ~= "boolean" then
			return nil
		end
	elseif action ~= "Stop" and action ~= "State" then
		return nil
	end
	local count = 0
	for key in value do
		count += 1
		if count > 6 or not allowed[key] then
			return nil
		end
	end
	return {
		id = value.id :: string,
		serial = value.serial :: number,
		action = action :: Wire.Action,
		collection = value.collection :: string?,
		limit = value.limit :: number?,
		reserve = value.reserve :: number?,
		requestId = value.requestId :: string?,
		enabled = value.enabled :: boolean?,
	}
end
function Protocol.same(a: Wire.Request, b: Wire.Request): boolean
	return a.serial == b.serial
		and a.action == b.action
		and a.collection == b.collection
		and a.limit == b.limit
		and a.reserve == b.reserve
		and a.requestId == b.requestId
		and a.enabled == b.enabled
end
return Protocol
