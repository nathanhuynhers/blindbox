--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Protocol = {}
function Protocol.parse(raw: unknown): Types.Request?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	local count = 0
	for key in value do
		count += 1
		if count > 3 or (key ~= "id" and key ~= "action" and key ~= "product") then
			return nil
		end
	end
	if typeof(value.id) ~= "string" or #value.id < 1 or #value.id > 64 then
		return nil
	end
	local action = value.action
	if action ~= "State" and action ~= "Refresh" and action ~= "Purchase" then
		return nil
	end
	local product = value.product
	if action == "Purchase" then
		if typeof(product) ~= "string" or #product < 1 or #product > 64 then
			return nil
		end
	elseif product ~= nil then
		return nil
	end
	return { id = value.id, action = action, product = product :: string? }
end
return Protocol
