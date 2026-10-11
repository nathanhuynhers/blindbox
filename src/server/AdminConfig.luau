--!strict
-- Server-only. Explicit identity; no creator/group/Studio fallback.
return table.freeze({
	ownerUserId = 103346374,
	transactionLimit = 100000000,
	largeChange = 1000000,
	quantityLimit = 100,
	simulationLimit = 1000,
	overrideSeconds = 300,
	auditLimit = 200,
})
