--!strict
-- Placeholder capacity/layout, not a final product limit. Persist stable anchor IDs.
return table.freeze({
	anchors = table.freeze({
		"figure_1",
		"figure_2",
		"figure_3",
		"figure_4",
		"figure_5",
		"figure_6",
	}),
	roomsPerHall = 6,
	customizationCategories = table.freeze({
		"wall",
		"floor",
		"lighting",
		"shelves",
		"pedestals",
		"furniture",
		"decorations",
		"effects",
	}),
})
