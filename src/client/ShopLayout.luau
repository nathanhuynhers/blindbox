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
	local sidebarWidth = if compact then 0 else math.clamp(math.floor(width * 0.15), 156, 188)
	local sidebarHeight = if compact then 64 else height - inset * 2
	local contentX = if compact then inset else sidebarWidth + inset * 2
	local contentY = if compact then sidebarHeight + inset else inset
	local contentWidth = math.max(1, width - contentX - inset)
	local contentHeight = math.max(1, height - contentY - inset)
	local carouselHeight = if compact then 216 else math.clamp(math.floor(height * 0.33), 190, 250)
	local detailY = carouselHeight + 12
	local detailWidth = contentWidth
	local sideBySide = contentWidth >= 720 and contentHeight >= 500
	local heroWidth = if sideBySide then math.floor(detailWidth * 0.36) else detailWidth
	local heroHeight = if sideBySide then math.max(374, contentHeight - detailY) else 310
	local infoX = if sideBySide then heroWidth + 12 else 0
	local infoY = if sideBySide then detailY else detailY + heroHeight + 12
	local infoWidth = if sideBySide then detailWidth - infoX else detailWidth
	local infoHeight = if infoWidth < 480
		then 526
		else math.max(374, if sideBySide then heroHeight else 0)
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

function Layout.figureSize(width: number, count: number): number
	return math.clamp(math.floor((width - math.max(0, count - 1) * 8) / math.max(1, count)), 36, 78)
end

return Layout
