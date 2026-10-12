--!strict
-- Validates platform metadata only; no planning-price fallback.
local Price = {}
function Price.read(raw: unknown): number?
	if typeof(raw) ~= "table" then
		return nil
	end
	local info = raw :: { [string]: unknown }
	local amount = info.PriceInRobux
	if
		info.IsForSale ~= true
		or typeof(amount) ~= "number"
		or amount ~= amount
		or amount < 0
		or amount >= math.huge
		or amount % 1 ~= 0
	then
		return nil
	end
	return amount
end
return Price
