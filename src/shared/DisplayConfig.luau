--!strict
-- Capacity is sequential for now; each extra slot has its own acquisition policy.
-- Coin prices stay server-only; slots unlock in order.
return table.freeze({
	defaultSlots = 3,
	maxSlots = 6,
	collectDistance = 20, -- Figure tap/click range; floor plates still require physical contact.
	unlockMethods = table.freeze({ [4] = "Coins", [5] = "Coins", [6] = "Coins" }),
})
