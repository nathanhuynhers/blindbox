--!strict
-- Consecutive Daily Login rewards.
-- PLACEHOLDER VALUES: the real rewards are still to be decided. Changing them is a data-only
-- edit of `days` below; the server grant and the client grid both read this table.
--
-- Each entry is one streak day: `coins` (whole Coins, may be 0) and optional `boxes`
-- (`collection` is a Catalog collection id, `count` 1..10, opened on claim). One claim per
-- UTC day; after the last entry the streak loops back to Day 1; a missed UTC day resets it.
local Catalog = require(script.Parent.Catalog)

export type Boxes = { collection: string, count: number }
export type Reward = { coins: number, boxes: Boxes? }

local days: { Reward } = {
	{ coins = 500 },
	{ coins = 1000 },
	{ coins = 0, boxes = { collection = "grove", count = 1 } },
	{ coins = 2500 },
	{ coins = 1000, boxes = { collection = "tide", count = 1 } },
	{ coins = 4000 },
	{ coins = 5000, boxes = { collection = "concept", count = 1 } },
}

for index, reward in days do
	local boxes = reward.boxes
	assert(
		reward.coins >= 0 and reward.coins <= 1000000000 and reward.coins % 1 == 0,
		"Invalid login reward coins on day " .. index
	)
	assert(
		not boxes
			or (
				Catalog.collectionIds[boxes.collection]
				and boxes.count >= 1
				and boxes.count <= 10
				and boxes.count % 1 == 0
			),
		"Invalid login reward boxes on day " .. index
	)
	assert(reward.coins > 0 or boxes, "Empty login reward on day " .. index)
	table.freeze(reward)
	if boxes then
		table.freeze(boxes)
	end
end

local LoginRewards = { days = table.freeze(days) }

-- Position (1..#days) of a streak count (1 or more) in the looping reward cycle.
function LoginRewards.day(streak: number): number
	return (math.max(1, streak) - 1) % #days + 1
end

function LoginRewards.reward(streak: number): Reward
	return days[LoginRewards.day(streak)]
end

return table.freeze(LoginRewards)
