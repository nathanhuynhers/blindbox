--!strict
-- Capacity is sequential for now; each extra slot has its own acquisition policy.
-- Coin prices stay server-only; slots unlock in order.
return table.freeze({
	defaultSlots = 3,
	maxSlots = 6,
	unlockMethods = table.freeze({ [4] = "Coins", [5] = "Coins", [6] = "Coins" }),
})
