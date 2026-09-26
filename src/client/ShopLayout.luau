--!strict
local Layout = {}
export type Geometry = {
	compact: boolean,
	sidebarWidth: number,
	sidebarHeight: number,
	contentX: number,
	contentY: number,
	contentWidth: number,
	contentHeight: number,
	carouselHeight: number,
	detailY: number,
	detailWidth: number,
	heroWidth: number,
	heroHeight: number,
	infoX: number,
	infoY: number,
	infoWidth: number,
	infoHeight: number,
	canvasHeight: number,
}

function Layout.calculate(width: number, height: number): Geometry
	local compact = width < 760 or height < 460
	local inset = 12
	local sidebarWidth = if compact then 0 else math.clamp(math.floor(width * 0.16), 166, 206)
	local sidebarHeight = if compact then 64 else height - inset * 2
	local contentX = if compact then inset else sidebarWidth + inset * 2
	local contentY = if compact then sidebarHeight + inset else inset
	local contentWidth = math.max(1, width - contentX - inset)
	local contentHeight = math.max(1, height - contentY - inset)
	local carouselHeight = 180
	local detailY = carouselHeight + 12
	local detailWidth = contentWidth
	local sideBySide = contentWidth >= 760 and contentHeight >= 480
	local heroWidth = if sideBySide then math.floor(detailWidth * 0.37) else detailWidth
	local heroHeight = if sideBySide then math.clamp(contentHeight - detailY, 400, 448) else 340
	local infoX = if sideBySide then heroWidth + 12 else 0
	local infoY = if sideBySide then detailY else detailY + heroHeight + 12
	local infoWidth = if sideBySide then detailWidth - infoX else detailWidth
	local infoHeight =
		math.max(Layout.details(infoWidth).height, if sideBySide then heroHeight else 0)
	local canvasHeight = math.max(contentHeight, infoY + infoHeight)
	return {
		compact = compact,
		sidebarWidth = sidebarWidth,
		sidebarHeight = sidebarHeight,
		contentX = contentX,
		contentY = contentY,
		contentWidth = contentWidth,
		contentHeight = contentHeight,
		carouselHeight = carouselHeight,
		detailY = detailY,
		detailWidth = detailWidth,
		heroWidth = heroWidth,
		heroHeight = heroHeight,
		infoX = infoX,
		infoY = infoY,
		infoWidth = infoWidth,
		infoHeight = infoHeight,
		canvasHeight = canvasHeight,
	}
end

function Layout.details(width: number)
	local narrow = width < 480
	local wide = width >= 640
	local inner = math.max(1, width - 40)
	local figuresWidth = if wide then math.floor(inner * 0.64) - 10 else inner
	return {
		wide = wide,
		narrow = narrow,
		height = if narrow then 560 elseif wide then 400 else 416,
		figuresX = 20,
		figuresY = 132,
		figuresWidth = figuresWidth,
		figuresHeight = if wide then 134 else 112,
		oddsX = if wide then figuresWidth + 40 else 20,
		oddsY = if wide then 132 else 250,
		oddsWidth = if wide
			then inner - figuresWidth - 20
			elseif narrow then inner
			else math.floor(inner * 0.43),
		purchaseX = if wide or narrow then 20 else math.floor(inner * 0.43) + 38,
		purchaseY = if wide then 290 elseif narrow then 398 else 250,
		purchaseWidth = if wide or narrow then inner else inner - math.floor(inner * 0.43) - 18,
		purchaseHeight = if wide then 104 else 148,
	}
end

function Layout.figureSize(width: number, count: number): number
	return math.clamp(math.floor((width - math.max(0, count - 1) * 8) / math.max(1, count)), 36, 78)
end

return Layout
