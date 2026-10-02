--!strict
return table.freeze({
	-- Enable only in a privately published Studio test place with API services enabled.
	studioPersistence = false,
	-- Authorized economy reset: old stores are never read or overwritten.
	studioStore = "BlindBox_Economy2_Studio",
	liveStore = "BlindBox_Economy2_Live",
})
