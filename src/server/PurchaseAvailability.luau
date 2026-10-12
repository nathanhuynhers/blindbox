--!strict
local Config = require(script.Parent.PurchaseConfig)
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Ledger = require(script.Parent.PurchaseLedger)
export type Context = {
	ready: boolean,
	ledgerReady: boolean,
	ledgerCount: number,
	ownership: Types.Ownership,
	fresh: boolean,
	highestCoinTier: number,
	prompt: boolean,
	eligible: boolean,
}
local Availability = {}
function Availability.reason(product: Config.Product, context: Context): string
	if not Config.configured(product) then
		return "Unconfigured"
	end
	if not product.salesEnabled then
		return "SalesDisabled"
	end
	if not product.integrationReady then
		return "IntegrationPending"
	end
	if not context.ready then
		return "ProfileUnavailable"
	end
	if not context.ledgerReady then
		return "StorageUnavailable"
	end
	if context.ledgerCount >= Ledger.maxEntries then
		return "LedgerCapacity"
	end
	if product.permanent then
		if not context.fresh then
			return "OwnershipUnavailable"
		end
		if context.ownership == "Owned" then
			return "Owned"
		end
		if product.coinTier and context.highestCoinTier >= product.coinTier then
			return "Superseded"
		end
	end
	if context.prompt then
		return "PurchasePending"
	end
	if not context.eligible then
		return "EligibilityUnavailable"
	end
	return "Available"
end
return Availability
