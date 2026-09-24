--!strict
return table.freeze({
	-- Enable only in a privately published Studio test place with API services enabled.
	studioPersistence = false,
	studioStore = "PocketGrove_Studio_v1",
	liveStore = "PocketGrove_Live_v1",
	maxRooms = 24,
})
