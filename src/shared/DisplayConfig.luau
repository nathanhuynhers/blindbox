--!strict
-- Capacity is sequential for now; each extra slot has its own acquisition policy.
-- Coin prices stay server-only; slots unlock in order.
return table.freeze({
	defaultSlots = 3,
	maxSlots = 6,
	collectDistance = 20, -- Figure tap/click range; floor plates still require physical contact.
	unlockMethods = table.freeze({ [4] = "Coins", [5] = "Pass", [6] = "Pass" }),
	-- Purchase keys of the permanent slot passes. A pass applies only after the slot before it
	-- is unlocked; saved slots (including legacy coin-bought 5 and 6) are never taken away.
	unlockPasses = table.freeze({ [5] = "display_5", [6] = "display_6" }),
})
