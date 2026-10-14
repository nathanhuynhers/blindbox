--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local PurchaseTypes = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Config = require(script.Parent.PurchaseConfig)

export type Ownership = (string) -> (PurchaseTypes.Ownership, boolean)
export type Source = "Display" | "OfflineDisplay" | "BankTransfer" | "FixedReward" | "CoinPack"
local Modifiers = {
	-- Paid display effects are validated; current owner policy remains a runtime requirement.
	-- This is NOT a sales switch. Missing configured IDs also disable every tier independently.
	effectsValidated = true,
}
function Modifiers.validTier(value: unknown): boolean
	return value == 1 or value == 2 or value == 4 or value == 8
end
function Modifiers.free(): Types.EarningFactors
	return { permanentTier = 1, vipFactor = 1, timedCoinFactor = 1 }
end
-- Explicit composition boundary for P04/P06. Callers supply verified server inputs;
-- this module owns no token activation, clocks, expiry or VIP ownership rules.
function Modifiers.factor(inputs: Types.EarningFactors, source: Source): number
	assert(Modifiers.validTier(inputs.permanentTier), "Invalid Coin tier")
	assert(inputs.vipFactor == 1 or inputs.vipFactor == 1.1, "Invalid VIP factor")
	assert(inputs.timedCoinFactor == 1 or inputs.timedCoinFactor == 2, "Invalid timed Coin factor")
	if source ~= "Display" and source ~= "OfflineDisplay" then
		return 1
	end
	return inputs.permanentTier * inputs.vipFactor * inputs.timedCoinFactor
end
-- Only P02 supplies ownership. Stale Owned retains its previously verified benefit;
-- Unknown/failure never becomes ownership. Sales availability is independent of owned benefits.
function Modifiers.resolve(
	products: { Config.Product },
	ownership: Ownership,
	allowed: boolean
): Types.CoinModifierView
	local highest, applicable = 1, 1
	local fresh = true
	for _, product in products do
		if product.coinTier and product.kind == "Pass" and Config.configured(product) then
			assert(
				Modifiers.validTier(product.coinTier) and product.coinTier > 1,
				"Invalid configured Coin tier"
			)
			local owned, current = ownership(product.key)
			fresh = fresh and current
			if owned == "Owned" then
				highest = math.max(highest, product.coinTier)
				if product.integrationReady then
					applicable = math.max(applicable, product.coinTier)
				end
			end
		end
	end
	local applied = if allowed then applicable else 1
	return {
		verifiedTier = highest,
		appliedTier = applied,
		ownershipFresh = fresh,
		reason = if not allowed
			then "ValidationPending"
			elseif highest > applicable then "IntegrationPending"
			else "Ready",
	}
end
return table.freeze(Modifiers)
