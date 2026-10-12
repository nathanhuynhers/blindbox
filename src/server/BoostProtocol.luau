--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.BoostTypes)
local PurchaseTypes = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Config = require(script.Parent.PurchaseConfig)
local Boosts = require(script.Parent.Boosts)
local Protocol = {}
function Protocol.parse(raw: unknown): Types.Request?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	for key in value do
		if key ~= "id" and key ~= "token" and key ~= "revision" then
			return nil
		end
	end
	if
		not Boosts.identifier(value.id)
		or #(value.id :: string) > 80
		or typeof(value.token) ~= "string"
		or not Config.tokenBenefits[value.token :: PurchaseTypes.TokenId]
		or typeof(value.revision) ~= "number"
		or value.revision < 0
		or value.revision > 9007199254740990
		or value.revision % 1 ~= 0
	then
		return nil
	end
	return {
		id = value.id :: string,
		token = value.token :: PurchaseTypes.TokenId,
		revision = value.revision,
	}
end
return Protocol
