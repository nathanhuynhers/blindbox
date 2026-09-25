--!strict
local Layout = require("./CollectionLayout")
local Host = require("./UILayout")
local Selection = require("./CollectionSelection")
local Catalog = require("./Catalog")
local Style = require("./CollectionStyle")
local checks = 0
local function check(value: boolean, message: string)
	checks += 1
	assert(value, message)
end
for _, viewport in
	{
		{ 320, 480 },
		{ 390, 800 },
		{ 568, 284 },
		{ 844, 342 },
		{ 1024, 728 },
		{ 1280, 680 },
		{ 1366, 728 },
		{ 1920, 1040 },
	}
do
	local desktop = Host.desktop(viewport[1], viewport[2], false)
	local host = Host.screen("Collection", viewport[1], viewport[2], desktop)
	local book = Layout.book(host.width, host.height)
	check(
		book.pageWidth >= 200 and book.pageHeight >= 160,
		"single page remains usable without scaling fonts"
	)
	check(book.tabs >= 44, "index tabs preserve touch targets")
	check(
		book.tabs + book.inset * 2 + book.pageWidth <= host.width,
		"pages fit next to protruding tabs"
	)
	local gridHeight = book.pageHeight - book.header
	local columns, width, height = Layout.grid(book.pageWidth + 8, gridHeight, book.spread)
	check(
		columns * width + (columns - 1) * Layout.gridGap + Layout.gridPadding * 2
			<= book.pageWidth + 8,
		"portrait mounts fit available page width"
	)
	check(width >= 44 and height >= 158, "portrait slots stay readable and touchable")
	if viewport[1] >= 1280 then
		check(
			book.spread and columns == 3,
			"reference desktop has three portraits across two pages"
		)
		check(
			2 * height + Layout.gridGap + Layout.gridPadding * 2 <= gridHeight,
			"six desktop figures fit in two rows"
		)
		check(book.tabs * 2 < host.width, "physical book dominates its index tabs")
	end
	local detail = Layout.detail(book.pageWidth, book.pageHeight)
	check(detail.hero >= 190, "hero remains larger than its metadata blocks")
	if detail.thumbnails then
		check(6 * 44 + 5 * 6 <= book.pageWidth, "all six thumbnail targets fit")
	end
end
local selected = Selection.create()
check(
	Catalog.byId[selected.figure].collection == selected.collection,
	"initial book selection is valid"
)
for _, collection in Catalog.collections do
	local first = Selection.first(collection.id, nil, false)
	Selection.choose(selected, first)
	local visited: { [string]: boolean } = {}
	for _ = 1, 6 do
		visited[selected.figure] = true
		Selection.step(selected, 1)
	end
	local count = 0
	for _ in visited do
		count += 1
	end
	check(
		count == 6 and selected.figure == first,
		"figure navigation wraps all six without crossing collections"
	)
	Selection.step(selected, -1)
	check(
		Catalog.byId[selected.figure].collection == collection.id,
		"previous wraps inside current collection"
	)
end
Selection.choose(selected, "tide.pearl", true)
Selection.open(selected, false)
check(
	selected.figure == "tide.pearl" and selected.collection == "tide" and selected.inspected,
	"acquisition stays selected and opens the right detail on next entry"
)
Selection.open(selected, false)
check(
	selected.figure == "tide.pearl" and not selected.inspected,
	"ordinary narrow reentry starts at grid without losing highlight"
)
Selection.choose(selected, "grove.mushroom", true)
Selection.open(selected, true)
check(
	not selected.inspected and not selected.acquired,
	"owned slot picker overrides acquired detail mode"
)
local before = selected.figure
Selection.choose(selected, "invalid.figure")
check(selected.figure == before, "invalid selection cannot corrupt book state")
check(
	Style.rarity("Common") ~= Style.rarity("Uncommon")
		and Style.rarity("Uncommon") ~= Style.rarity("Rare"),
	"three explicit Collection badge identities"
)
check(Style.rarities.Secret == nil, "no Secret rarity introduced")
print("PASS: " .. checks .. " physical-book layout and selection checks")
