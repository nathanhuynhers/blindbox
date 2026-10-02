--!strict
return table.freeze({
	-- Enable only in a privately published Studio test place with API services enabled.
	studioPersistence = false,
	studioStore = "PocketGrove_Studio_v1",
	liveStore = "PocketGrove_Live_v1",
	-- Global leaderboard OrderedDataStores; the scope is the stat key (figures, rate, boxes).
	studioLeaderboard = "BlindboxTown_Studio_Leaderboard_v1",
	liveLeaderboard = "BlindboxTown_Live_Leaderboard_v1",
})
