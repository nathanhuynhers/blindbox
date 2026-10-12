--!strict
local Config = require(script.Parent.PurchaseConfig)
local Grants = require(script.Parent.PackageGrants)
local Storage = require(script.Parent.Storage)
local Rules = require(script.Parent.Rules)
local Ledger = require(script.Parent.PurchaseLedger)
local CoinModifiers = require(script.Parent.CoinModifiers)
local BoostRuntime = require(script.Parent.BoostRuntime)
local Runtime = {}
-- D2 requires a validated downstream earned/assisted path. It is not integrated yet.
local paidPathValidated = false
function Runtime.reason(storage: Storage.Session, product: Config.Product, now: number): string
	if not storage.handle or not BoostRuntime.ready(storage, now) then
		return "ProfileUnavailable"
	end
	if
		product.key == "starter"
		and storage.state.packages
		and storage.state.packages.starterClaim
	then
		return "AlreadyClaimed"
	end
	if not Grants.capacity(storage.state, product) then
		return "CapacityUnavailable"
	end
	if not paidPathValidated or not CoinModifiers.effectsValidated then
		return "ValidationPending"
	end
	return if Grants.supports(product.key) then "Available" else "UnsupportedProduct"
end
function Runtime.eligible(storage: Storage.Session, product: Config.Product, now: number): boolean
	return Runtime.reason(storage, product, now) == "Available"
end
function Runtime.fulfill(
	storage: Storage.Session,
	id: string,
	entry: Ledger.Entry,
	now: number,
	commit: BoostRuntime.Commit?
): boolean
	if not storage.handle or not BoostRuntime.ready(storage, now) then
		return false
	end
	local ok, reason = Grants.deliver(storage.state, id, entry)
	if not ok then
		return false
	end
	if reason == "Replay" then
		return true
	end
	Rules.settle(storage.state, now)
	Grants.promote(storage.state)
	storage.state.revision += 1
	storage.state.boostCommitPending, storage.ready = true, false
	return (commit or Storage.flush)(storage, false)
end
-- Called only after a successful existing Daily mutation added VIP's supplement.
-- Persist box, UTC marker and fixed credit before sending a successful acknowledgement.
function Runtime.commitDaily(
	storage: Storage.Session,
	now: number,
	commit: BoostRuntime.Commit?
): boolean
	if not storage.handle or not BoostRuntime.ready(storage, now) then
		return false
	end
	storage.state.boostCommitPending, storage.ready = true, false
	return (commit or Storage.flush)(storage, false)
end
function Runtime.sync(
	storage: Storage.Session,
	products: { Config.Product },
	ownership: CoinModifiers.Ownership,
	allowed: boolean,
	now: number
): boolean
	if not BoostRuntime.ready(storage, now) then
		return false
	end
	local owned = false
	for _, product in products do
		if
			product.key == "vip"
			and product.kind == "Pass"
			and Config.configured(product)
			and product.integrationReady
		then
			local status = ownership(product.key)
			owned = status == "Owned"
		end
	end
	return Rules.setVip(storage.state, owned, allowed, now)
end
return Runtime
