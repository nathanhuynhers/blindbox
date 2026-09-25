--!strict
local Layout = {}
export type Rect = { x: number, y: number, width: number, height: number }
-- Pure sizing policy; desktop rail is reserved independently of which presentation is open.
function Layout.desktop(width: number, height: number, touch: boolean): boolean
	return width >= 900 and height >= 500 and not (touch and width < 1100)
end
function Layout.screen(id: string, width: number, height: number, desktop: boolean): Rect
	local left, right = if desktop then 144 else 12, 12
	local top, bottom =
		if height < 420 then 58 else 76, if height < 420 then 12 elseif desktop then 20 else 76
	local availableWidth = math.max(1, width - left - right)
	local availableHeight = math.max(1, height - top - bottom)
	local maxWidth = if id == "Collection"
		then 1120
		elseif id == "Shop" then 920
		elseif id == "Goals" then 620
		elseif id == "Visits" then 780
		else 740
	local maxHeight = if id == "Collection"
		then 660
		elseif id == "Shop" then 690
		elseif id == "Goals" then 430
		elseif id == "Visits" then 450
		else 330
	local w, h = math.min(availableWidth, maxWidth), math.min(availableHeight, maxHeight)
	return {
		x = left + (availableWidth - w) * (if id == "Goals" then 1 else 0.5),
		y = top + (availableHeight - h) * (if id == "Display" then 1 else 0.5),
		width = w,
		height = h,
	}
end
return Layout
