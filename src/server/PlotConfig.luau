--!strict
-- Fixed per-server radial footprint. Match the experience player limit to maxPlots.
return table.freeze({
	maxPlots = 8,
	width = 100,
	depth = 96,
	walkingY = 1,
	plotRadius = 170,
	plazaRadius = 50,
	pathWidth = 16,
	pathOverlap = 0.75,
})
