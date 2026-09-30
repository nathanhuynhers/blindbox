--!strict
-- Public identity only. Drop weights and earning rates remain server-owned per figure.
local Rarity = {}
export type Id = "Common" | "Uncommon" | "Rare" | "Legendary" | "Mythical"
export type Definition = {
	tint: Color3,
	accent: Color3,
	highlight: Color3,
	ink: Color3,
	onTint: Color3,
}
local order: { Id } = { "Common", "Uncommon", "Rare", "Legendary", "Mythical" }
Rarity.order = table.freeze(order)
Rarity.definitions = {
	Common = {
		tint = Color3.fromRGB(185, 222, 204),
		accent = Color3.fromRGB(251, 239, 207),
		highlight = Color3.fromRGB(251, 239, 207),
		ink = Color3.fromRGB(49, 105, 78),
		onTint = Color3.fromRGB(39, 77, 58),
	},
	Uncommon = {
		tint = Color3.fromRGB(184, 164, 214),
		accent = Color3.fromRGB(239, 220, 244),
		highlight = Color3.fromRGB(239, 220, 244),
		ink = Color3.fromRGB(104, 71, 144),
		onTint = Color3.fromRGB(60, 40, 84),
	},
	Rare = {
		tint = Color3.fromRGB(231, 182, 86),
		accent = Color3.fromRGB(255, 232, 180),
		highlight = Color3.fromRGB(255, 232, 180),
		ink = Color3.fromRGB(126, 85, 22),
		onTint = Color3.fromRGB(76, 48, 15),
	},
	Legendary = {
		tint = Color3.fromRGB(169, 55, 76),
		accent = Color3.fromRGB(255, 198, 119),
		highlight = Color3.fromRGB(244, 132, 91),
		ink = Color3.fromRGB(150, 45, 65),
		onTint = Color3.fromRGB(255, 241, 213),
	},
	Mythical = {
		tint = Color3.fromRGB(164, 77, 180),
		accent = Color3.fromRGB(248, 232, 250),
		highlight = Color3.fromRGB(151, 223, 231),
		ink = Color3.fromRGB(130, 52, 146),
		onTint = Color3.fromRGB(252, 242, 255),
	},
} :: { [Id]: Definition }
local ranks: { [string]: number } = {}
for index, id in order do
	ranks[id] = index
end
for _, definition in Rarity.definitions do
	table.freeze(definition)
end
table.freeze(Rarity.definitions)
function Rarity.parse(value: unknown): Id?
	if type(value) == "string" and ranks[value] then
		return value :: Id
	end
	return nil
end
function Rarity.isValid(value: unknown): boolean
	return Rarity.parse(value) ~= nil
end
function Rarity.rank(id: string): number
	local rank = ranks[id]
	assert(rank, "Invalid rarity: " .. id)
	return rank
end
function Rarity.less(a: string, b: string): boolean
	return Rarity.rank(a) < Rarity.rank(b)
end
-- Safe presentation fallback is distinct from strict catalog/override validation.
function Rarity.get(value: string): Definition
	local id: Id = Rarity.parse(value) or "Common"
	return Rarity.definitions[id]
end
return table.freeze(Rarity)
