--!strict
-- Captured-session adapter for the existing P05 controllers and ordinary transaction path.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Wire = require(game:GetService("ReplicatedStorage").Shared.ConvenienceTypes)
local Service = require(script.Parent.ConvenienceService)
local Storage = require(script.Parent.Storage)
local Movement = require(script.Parent.PlayerMovement)
local Transactions = require(script.Parent.Transactions)
local Rules = require(script.Parent.Rules)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local CollectionAccess = require(script.Parent.CollectionAccess)
local Open = require(script.Parent.AutoOpen)
local Collect = require(script.Parent.AutoCollect)
export type Dependencies = {
	now: () -> number,
	id: () -> string,
	current: () -> boolean,
	alive: () -> boolean,
	ownership: (string) -> (boolean, boolean),
	purchaseBusy: () -> boolean,
	-- Missing policy/spendable services fail closed. Visible wallet total is not proof.
	policyAllowed: () -> boolean,
	spendable: () -> number?,
	snapshot: () -> Types.Snapshot,
	rolls: () -> { number },
	day: () -> number,
	window: () -> number,
	deliver: (Wire.OpeningDelivery) -> (),
	changed: () -> (),
}
local Owner = {}
function Owner.create(
	storage: Storage.Session,
	transaction: Transactions.Session,
	binding: Movement.Binding,
	deps: Dependencies
): Service.Owner
	local collection = ""
	local delivery: Wire.OpeningDelivery? = nil
	local lastPurchase = -math.huge
	local function ready(): boolean
		return deps.current()
			and storage.handle ~= nil
			and storage.ready
			and not storage.closed
			and not storage.transferring
			and not storage.busy
			and storage.pendingSave == nil
			and storage.pendingRelease == nil
			and deps.now() < storage.safeUntil
	end
	local function context(chosen: string): Open.Context
		local owned, fresh = deps.ownership("auto_open")
		return {
			ready = ready(),
			alive = deps.alive(),
			owned = owned,
			fresh = fresh,
			policyAllowed = deps.policyAllowed(),
			collectionRefusal = if Catalog.comingSoon[chosen]
				then "This collection is coming soon."
				else CollectionAccess.refusal(transaction.state.discovered, chosen),
			flowActive = chosen ~= "" and chosen == collection,
			busy = deps.purchaseBusy(),
			cooldownReady = deps.now() - lastPurchase >= 3,
			price = Rules.prices[chosen],
			spendable = deps.spendable() or -1,
		}
	end
	local open = Open.create({
		now = deps.now,
		id = deps.id,
		context = context,
		purchase = function(id, chosen, reserve)
			local ctx = context(chosen)
			local price = ctx.price
			if
				not ctx.ready
				or not ctx.alive
				or not ctx.owned
				or not ctx.fresh
				or not ctx.policyAllowed
				or ctx.collectionRefusal ~= nil
				or not ctx.flowActive
				or ctx.busy
				or not ctx.cooldownReady
				or not price
				or ctx.spendable - price < reserve
			then
				return nil
			end
			local intent: Types.Intent =
				{ id = id, action = "Buy", choice = chosen, revision = transaction.state.revision }
			local before = deps.snapshot()
			lastPurchase = deps.now()
			local reply, changed = Transactions.process(
				transaction,
				intent,
				deps.now(),
				false,
				deps.rolls(),
				deps.day(),
				nil,
				nil,
				deps.window()
			)
			if reply then
				delivery =
					{ request = intent, before = before, after = deps.snapshot(), reply = reply }
			end
			if changed then
				deps.changed()
			end
			return reply
		end,
		reconcile = function(id)
			-- Retain the one committed result independently of the transient receipt cache.
			if delivery and delivery.reply.id == id then
				return delivery.reply
			end
			return nil
		end,
		deliver = function(reply)
			if delivery and delivery.reply.id == reply.id and deps.current() then
				deps.deliver(delivery)
			end
		end,
	})
	local collect = Collect.create({
		now = deps.now,
		ready = ready,
		ownership = function()
			return deps.ownership("auto_collect")
		end,
		enabled = function()
			return transaction.state.convenience.autoCollect
		end,
		state = function()
			return transaction.state
		end,
		transferBank = Rules.transferBank,
	})
	return {
		open = open,
		collect = collect,
		binding = binding,
		ready = ready,
		ownership = deps.ownership,
		preferences = function()
			return transaction.state.convenience
		end,
		setPreference = function(key, enabled)
			local revision = transaction.state.revision
			local ok = Rules.setConveniencePreference(transaction.state, key, enabled)
			if transaction.state.revision ~= revision then
				deps.changed()
			end
			return ok
		end,
		collection = function(value)
			collection = value
		end,
		openAllowed = function()
			local owned, fresh = deps.ownership("auto_open")
			return ready()
				and owned
				and fresh
				and deps.policyAllowed()
				and not Catalog.comingSoon[collection]
				and CollectionAccess.canBuy(transaction.state.discovered, collection)
				and deps.alive()
				and not deps.purchaseBusy()
		end,
	}
end
return Owner
