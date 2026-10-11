--!strict
return table.freeze({
	enabled = true,
	idleSeconds = 18.5 * 60,
	-- The earlier of idleSeconds and Roblox's idle limit minus this margin.
	idleLimitSeconds = 20 * 60,
	safetyMarginSeconds = 90,
	initialIdleCreditSeconds = 120,
	idleFreshSeconds = 45,
	reportSeconds = 15,
	confirmSeconds = 5,
	prepareSeconds = 15,
	initializationSeconds = 20,
	maxRetries = 2,
	retryDelays = table.freeze({ 3, 8 }),
	debug = false,
})
