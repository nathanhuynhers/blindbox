--!strict
-- Welcome Quest stages, saved as the profile's `step` (schema 13). Only the server advances
-- them, and only from the action each one teaches; clients read them to choose guidance.
local Tutorial = {
	welcome = 1, -- open the free Welcome Box
	display = 2, -- put a figure on Display
	collect = 3, -- collect Display income from a figure
	buy = 4, -- open a box with Coins
	reward = 5, -- quest complete: the free Welcome x10 is waiting
	shelves = 6, -- optional tip: place a figure on a Shelf
	done = 7,
}
-- The mandatory loop (Welcome Box through the paid box) whose guidance should own attention.
function Tutorial.guiding(step: number, hidden: boolean): boolean
	return not hidden and step < Tutorial.reward
end
return table.freeze(Tutorial)
