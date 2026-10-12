--!strict
local Storage = require(script.Parent.Storage)
local Config = require(script.Parent.PurchaseConfig)
local Modifiers = require(script.Parent.CoinModifiers)
local Rules = require(script.Parent.Rules)
local Runtime = {}
-- Bounded synchronous work; no new tasks/listeners. P02 owns refresh and teardown.
function Runtime.sync(
	storage: Storage.Session,
	products: { Config.Product },
	ownership: Modifiers.Ownership,
	allowed: boolean,
	now: number
): boolean
	if
		storage.closed
		or storage.transferring
		or not storage.ready
		or storage.busy
		or storage.pendingSave
		or storage.pendingRelease
		or now >= storage.safeUntil
	then
		return false
	end
	return Rules.setCoinModifiers(
		storage.state,
		Modifiers.resolve(products, ownership, allowed),
		now
	)
end
return Runtime
