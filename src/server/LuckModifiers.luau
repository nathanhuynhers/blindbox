--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.BoostTypes)
local CoinModifiers = require(script.Parent.CoinModifiers)
local Config = require(script.Parent.PurchaseConfig)
local Luck = {}
function Luck.free(): Types.LuckView
	return {
		verifiedPermanent = 1,
		permanent = 1,
		ownershipFresh = false,
		reason = "ValidationPending",
	}
end
function Luck.resolve(
	products: { Config.Product },
	ownership: CoinModifiers.Ownership,
	allowed: boolean
): Types.LuckView
	local verified, applied, fresh = 1, 1, true
	for _, product in products do
		if product.key == "luck" and product.kind == "Pass" and Config.configured(product) then
			assert(
				product.benefits and product.benefits.luckWeight == 2,
				"Unapproved permanent Luck"
			)
			local owned, current = ownership(product.key)
			fresh = fresh and current
			if owned == "Owned" then
				verified = 2
				if allowed and product.integrationReady then
					applied = 2
				end
			end
		end
	end
	return {
		verifiedPermanent = verified,
		permanent = applied,
		ownershipFresh = fresh,
		reason = if not allowed
			then "ValidationPending"
			elseif verified > applied then "IntegrationPending"
			else "Ready",
	}
end
return table.freeze(Luck)
