--!strict
-- Capacity is sequential for now; each extra slot has its own acquisition policy.
-- Only slot 4 has an implemented legacy purchase. No price is inferred for 5/6.
return table.freeze({
	defaultSlots = 3,
	maxSlots = 6,
	unlockMethods = table.freeze({ [4] = "LegacyCoins", [5] = "Unassigned", [6] = "Unassigned" }),
})
