--!strict
-- Book-specific geometry. Values are in safe-area pixels; typography never scales below legibility.
local Layout = {}
Layout.gridGap = 12
Layout.gridPadding = 10
Layout.gridRightPaddingExtra = 4
Layout.cornerSize = 110
Layout.cornerTop = -10
Layout.contentGap = 12
Layout.arrowSize = 44
Layout.arrowGap = 6
Layout.heroInset = 20
Layout.columnGap = 16
Layout.thumbnailWidth = 44
Layout.thumbnailGap = 6
Layout.filterWidth = 92
function Layout.header(width: number, inset: number, spread: boolean)
	local cornerRight = Layout.cornerSize - inset + Layout.contentGap
	local belowCorner = Layout.cornerSize + Layout.cornerTop - inset + Layout.contentGap
	local compact = width < 360
	local x = if compact then 8 else cornerRight
	local right = if compact then 8 elseif spread then 0 else cornerRight
	local y = if compact then belowCorner else 4
	return {
		x = x,
		y = y,
		width = math.max(1, width - x - right),
		progressY = y + 40,
		filterY = y + 36,
		filterX = width - right - Layout.filterWidth,
		height = y + 92,
	}
end
function Layout.book(width: number, height: number)
	local spread = width >= 940 and height >= 460
	local tabs = if spread then 126 elseif width >= 600 then 106 else 48
	local inset = if spread then 26 else 16
	local bookWidth = math.max(1, width - tabs)
	local pageWidth =
		math.max(1, if spread then (bookWidth - 2 * inset - 28) / 2 else bookWidth - 2 * inset)
	local pageHeight = math.max(1, height - 2 * inset - 14)
	return {
		spread = spread,
		tabs = tabs,
		inset = inset,
		bookWidth = bookWidth,
		pageWidth = pageWidth,
		pageHeight = pageHeight,
		header = Layout.header(pageWidth, inset, spread).height,
	}
end
function Layout.grid(width: number, height: number, spread: boolean): (number, number, number)
	local scrollGutter = if spread then 0 else 6
	local available =
		math.max(1, width - 2 * Layout.gridPadding - Layout.gridRightPaddingExtra - scrollGutter)
	local columns = if spread then 3 else math.clamp(math.floor((available + 10) / 124), 1, 3)
	local cellWidth = math.floor((available - (columns - 1) * Layout.gridGap) / columns)
	local fitTwoRows = math.floor((height - 2 * Layout.gridPadding - Layout.gridGap) / 2)
	local cellHeight = if spread
		then math.clamp(fitTwoRows, 158, 300)
		else math.clamp(cellWidth * 1.35, 160, 240)
	return columns, cellWidth, cellHeight
end
function Layout.detail(width: number, height: number, pageInset: number?)
	local sideBySide = width >= 430 and height >= 440
	local thumbnails = width >= 350 and height >= 400
	local footer = if thumbnails then 64 else 0
	local heroWidth =
		math.max(1, math.floor((width - Layout.heroInset - Layout.columnGap - 16) * 0.56))
	return {
		sideBySide = sideBySide,
		thumbnails = thumbnails,
		footer = footer,
		heroX = Layout.heroInset,
		heroWidth = heroWidth,
		infoX = Layout.heroInset + heroWidth + Layout.columnGap,
		infoTop = Layout.cornerSize + Layout.cornerTop - (pageInset or 26) + Layout.contentGap,
		hero = if sideBySide
			then math.max(200, height - footer - 16)
			else math.clamp(height * 0.48, 190, 340),
	}
end
function Layout.strip(
	width: number,
	heroX: number,
	heroWidth: number,
	count: number
): (number, number)
	local extent = count * Layout.thumbnailWidth + math.max(0, count - 1) * Layout.thumbnailGap
	local center = if extent + 8 <= heroWidth then heroX + heroWidth / 2 else width / 2
	return center, extent
end
return Layout
