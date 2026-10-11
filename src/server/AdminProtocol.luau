--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.AdminTypes)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Economy = require(script.Parent.Economy)
local Config = require(script.Parent.AdminConfig)
local Protocol = {}
export type Command = { permission: string, mutation: boolean, fields: { string } }
-- The allowlist is also the command registry's security contract. No client-selected methods.
local commands: { [string]: Command } = {
	Inspect = { permission = "Owner", mutation = false, fields = { "target" } },
	GrantCoins = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "amount", "confirmed" },
	},
	RemoveCoins = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "amount", "confirmed" },
	},
	SetBalance = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "amount", "confirmed" },
	},
	GrantFigure = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "figure", "quantity", "confirmed" },
	},
	RemoveFigure = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "figure", "quantity", "confirmed" },
	},
	GrantCollection = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "collection", "confirmed" },
	},
	SetPity = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "collection", "rarity", "amount", "confirmed" },
	},
	ResetPity = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "collection", "confirmed" },
	},
	ForceRarity = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "collection", "rarity", "confirmed" },
	},
	ForceFigure = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "collection", "figure", "confirmed" },
	},
	ClearOverride = { permission = "Owner", mutation = true, fields = { "target", "revision" } },
	Simulate = {
		permission = "Owner",
		mutation = false,
		fields = { "target", "collection", "amount" },
	},
	Teleport = { permission = "Owner", mutation = true, fields = { "target", "revision" } },
	Kick = {
		permission = "Owner",
		mutation = true,
		fields = { "target", "revision", "reason", "confirmed" },
	},
}
Protocol.commands = table.freeze(commands)
function Protocol.integer(value: unknown, minimum: number, maximum: number): boolean
	return typeof(value) == "number"
		and value == value
		and value >= minimum
		and value <= maximum
		and value % 1 == 0
end
function Protocol.allowed(userId: number, permission: string): boolean
	-- Future explicit role assignments can resolve into these ranks. No automatic elevation.
	local ranks = { Owner = 3, Developer = 2, Moderator = 1 }
	local rank = if Protocol.integer(Config.ownerUserId, 1, 9007199254740991)
			and userId == Config.ownerUserId
		then 3
		else 0
	return ranks[permission] ~= nil and rank >= ranks[permission]
end
function Protocol.parse(raw: unknown): Types.Request?
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	if typeof(value.action) ~= "string" then
		return nil
	end
	local command: Command? = Protocol.commands[value.action]
	if not command then
		return nil
	end
	local count = 0
	for key in value do
		count += 1
		if
			count > 11
			or (
				key ~= "action"
				and key ~= "token"
				and key ~= "sequence"
				and not table.find(command.fields, key)
			)
		then
			return nil
		end
	end
	if
		typeof(value.token) ~= "string"
		or #value.token ~= 36
		or not Protocol.integer(value.sequence, 1, 9007199254740991)
	then
		return nil
	end
	if not Protocol.integer(value.target, 1, 9007199254740991) then
		return nil
	end
	if command.mutation and not Protocol.integer(value.revision, 0, 9007199254740991) then
		return nil
	end
	if value.confirmed ~= nil and typeof(value.confirmed) ~= "boolean" then
		return nil
	end
	if
		table.find(command.fields, "figure")
		and (
			typeof(value.figure) ~= "string"
			or #value.figure > 64
			or not Catalog.byId[value.figure]
		)
	then
		return nil
	end
	if
		table.find(command.fields, "collection")
		and (
			typeof(value.collection) ~= "string"
			or #value.collection > 64
			or not Catalog.collectionIds[value.collection]
		)
	then
		return nil
	end
	if
		table.find(command.fields, "rarity")
		and (typeof(value.rarity) ~= "string" or not Rarity.isValid(value.rarity))
	then
		return nil
	end
	if
		table.find(command.fields, "quantity")
		and not Protocol.integer(value.quantity, 1, Config.quantityLimit)
	then
		return nil
	end
	if table.find(command.fields, "amount") then
		local maximum = if value.action == "SetPity"
			then Economy.counterLimit
			elseif value.action == "Simulate" then Config.simulationLimit
			elseif value.action == "SetBalance" then Economy.coinLimit
			else Config.transactionLimit
		local minimum = if value.action == "SetBalance" or value.action == "SetPity" then 0 else 1
		if not Protocol.integer(value.amount, minimum, maximum) then
			return nil
		end
	end
	if
		value.reason ~= nil
		and (
			typeof(value.reason) ~= "string"
			or #value.reason > 160
			or string.find(value.reason, "%c")
		)
	then
		return nil
	end
	return {
		token = value.token :: string,
		sequence = value.sequence :: number,
		action = value.action :: string,
		target = value.target :: number,
		revision = value.revision :: number?,
		amount = value.amount :: number?,
		quantity = value.quantity :: number?,
		figure = value.figure :: string?,
		collection = value.collection :: string?,
		rarity = value.rarity :: string?,
		reason = value.reason :: string?,
		confirmed = value.confirmed :: boolean?,
	}
end
function Protocol.same(a: Types.Request, b: Types.Request): boolean
	return a.action == b.action
		and a.target == b.target
		and a.revision == b.revision
		and a.amount == b.amount
		and a.quantity == b.quantity
		and a.figure == b.figure
		and a.collection == b.collection
		and a.rarity == b.rarity
		and a.reason == b.reason
		and a.confirmed == b.confirmed
		and a.token == b.token
		and a.sequence == b.sequence
end
return Protocol
