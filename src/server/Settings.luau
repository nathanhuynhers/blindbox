--!strict
return table.freeze({
	-- Enable only in a privately published Studio test place with API services enabled.
	studioPersistence = false,
	-- Authorized economy reset: old stores are never read or overwritten.
	studioStore = "BlindBox_Economy2_Studio",
	liveStore = "BlindBox_Economy2_Live",
	-- Global leaderboard OrderedDataStores; the scope is the stat key (figures, rate, boxes).
	studioLeaderboard = "BlindboxTown_Studio_Leaderboard_v1",
	liveLeaderboard = "BlindboxTown_Live_Leaderboard_v1",
})
