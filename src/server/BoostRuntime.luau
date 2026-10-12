--!strict
local Storage = require(script.Parent.Storage)
local Rules = require(script.Parent.Rules)
local Config = require(script.Parent.PurchaseConfig)
local Ledger = require(script.Parent.PurchaseLedger)
local Boosts = require(script.Parent.Boosts)
local Luck = require(script.Parent.LuckModifiers)
local Protocol = require(script.Parent.BoostProtocol)
local CoinModifiers = require(script.Parent.CoinModifiers)
local BoostTypes = require(game:GetService("ReplicatedStorage").Shared.BoostTypes)
local Runtime = {}
export type Commit = (Storage.Session, boolean) -> boolean
export type Eligibility = {
	policy: "Allowed" | "Restricted" | "Unknown",
	lineageValidated: boolean,
	disclosureReady: boolean,
}
function Runtime.allowed(eligibility: Eligibility): boolean
	return Boosts.effectsValidated
		and eligibility.policy == "Allowed"
		and eligibility.lineageValidated
		and eligibility.disclosureReady
end
function Runtime.ready(storage: Storage.Session, now: number): boolean
	return not storage.closed
		and not storage.transferring
		and storage.ready
		and not storage.busy
		and storage.pendingSave == nil
		and storage.pendingRelease == nil
		and not storage.state.boostCommitPending
		and now < storage.safeUntil
end
function Runtime.sync(
	storage: Storage.Session,
	products: { Config.Product },
	ownership: CoinModifiers.Ownership,
	eligibility: Eligibility,
	wall: number,
	now: number
): boolean
	if not Runtime.ready(storage, now) then
		return false
	end
	local allowed = Runtime.allowed(eligibility)
	return Rules.syncBoosts(
		storage.state,
		Luck.resolve(products, ownership, allowed),
		allowed,
		wall,
		now
	)
end
-- Only P02's committed immutable ledger entries enter here. No policy gate can discard a
-- charged token; restrictions affect activation/use. A mixed Starter grant needs its owner.
function Runtime.fulfill(
	storage: Storage.Session,
	receiptId: string,
	entry: Ledger.Entry,
	now: number,
	commit: Commit?
): boolean
	if not storage.handle or not Runtime.ready(storage, now) then
		return false
	end
	local state = storage.state
	local ok, reason = Boosts.deliver(state.boosts, receiptId, entry)
	if not ok then
		return false
	end
	if reason == "Replay" then
		return true
	end
	Rules.settle(state, now)
	state.schemaVersion = math.max(16, state.schemaVersion)
	state.revision += 1
	state.boostCommitPending, storage.ready = true, false
	-- Storage.flush locks before yielding and preserves its exact pending snapshot on failure.
	return (commit or Storage.flush)(storage, false)
end
function Runtime.activate(
	storage: Storage.Session,
	raw: unknown,
	eligibility: Eligibility,
	wall: number,
	now: number,
	commit: Commit?
): BoostTypes.Result?
	local request = Protocol.parse(raw)
	if not request then
		return nil
	end
	local function result(ok: boolean, reason: string): BoostTypes.Result
		return { id = request.id, ok = ok, reason = reason }
	end
	if not storage.handle or not Runtime.ready(storage, now) then
		return result(false, "SavingUnavailable")
	end
	local state = storage.state
	local previous = state.boosts.activations[request.id]
	if previous then
		return result(previous.token == request.token, "Replay")
	end
	if request.revision ~= state.revision then
		return result(false, "StaleState")
	end
	if not Runtime.allowed(eligibility) or not state.paidBoostsAllowed then
		return result(false, "PolicyValidationPending")
	end
	-- Activation always observes UTC again; a caller cannot supply an old accepted timestamp.
	Rules.syncBoosts(state, state.luckModifiers, state.paidBoostsAllowed, wall, now)
	if not state.boostClockValid then
		return result(false, "ClockUnavailable")
	end
	local ok, reason = Boosts.activate(
		state.boosts,
		request,
		math.floor(Rules.boostNow(state)),
		state.luckModifiers.verifiedPermanent
	)
	if not ok then
		return result(false, reason)
	end
	state.schemaVersion = math.max(16, state.schemaVersion)
	state.revision += 1
	state.boostCommitPending, storage.ready = true, false
	local saved = (commit or Storage.flush)(storage, false)
	return result(saved, if saved then "Activated" else "SavingUnavailable")
end
return Runtime
