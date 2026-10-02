--!strict
-- Pure sizing policy. Desktop lays out the 1280x720 reference in design units and scales up
-- with one UIScale; phone landscape uses its own sheet layout at scale 1.
local Layout = {}
export type Rect = { x: number, y: number, width: number, height: number }
export type Topbar = { left: number, right: number }
export type Dock = Rect & {
	item: number,
	itemHeight: number,
	gap: number,
	icon: number,
	label: number,
}
export type Frame = {
	scale: number,
	width: number,
	height: number,
	phone: boolean,
	hud: Rect,
	gear: Rect,
	tracker: Rect,
	dock: Dock,
	panel: Rect,
	header: number,
	dockWhileOpen: boolean,
}

Layout.reference = { width = 1280, height = 720 }

function Layout.phone(width: number, height: number): boolean
	return height < 560 or width < 900
end

function Layout.scale(width: number, height: number): number
	if Layout.phone(width, height) then
		return 1
	end
	return math.clamp(math.min(width / 1280, height / 720), 1, 2)
end

local function dock(width: number, height: number, phone: boolean): Dock
	local item, itemHeight, gap =
		if phone then 68 else 100, if phone then 70 else 94, if phone then 8 else 12
	local total = item * 5 + gap * 4
	return {
		x = math.floor((width - total) / 2),
		y = height - (if phone then 10 else 20) - itemHeight,
		width = total,
		height = itemHeight,
		item = item,
		itemHeight = itemHeight,
		gap = gap,
		icon = if phone then 40 else 58,
		label = if phone then 12 else 15,
	}
end

-- `topbar` is the free span between Roblox's own top-bar buttons, in pixels of the safe area.
function Layout.frame(pixelWidth: number, pixelHeight: number, topbar: Topbar): Frame
	local phone = Layout.phone(pixelWidth, pixelHeight)
	local scale = Layout.scale(pixelWidth, pixelHeight)
	local width, height = pixelWidth / scale, pixelHeight / scale
	local left, right = topbar.left / scale, math.min(width, topbar.right / scale)
	local bar = dock(width, height, phone)
	if phone then
		local hudX = math.max(8, left + 8)
		local sheetX = if width - hudX - 8 >= 600 then hudX else 8
		return {
			scale = scale,
			width = width,
			height = height,
			phone = true,
			hud = { x = hudX, y = 8, width = 0, height = 44 },
			gear = { x = right - 10 - 44, y = 8, width = 44, height = 44 },
			tracker = { x = right - 10 - 44 - 8, y = 8, width = 0, height = 44 },
			dock = bar,
			panel = { x = sheetX, y = 6, width = width - sheetX - 8, height = height - 14 },
			header = 56,
			dockWhileOpen = false,
		}
	end
	local margin = math.clamp(width * 0.05, 16, 64)
	local top, bottom = 84, bar.y - 14
	local panelWidth = math.min(1280, width - margin * 2)
	local panelHeight = math.min(640, bottom - top)
	return {
		scale = scale,
		width = width,
		height = height,
		phone = false,
		hud = { x = math.max(16, left + 10), y = 14, width = 0, height = 52 },
		gear = { x = right - 20 - 52, y = 18, width = 52, height = 52 },
		tracker = { x = right - 20 - 270, y = 82, width = 270, height = 0 },
		dock = bar,
		panel = {
			x = math.floor((width - panelWidth) / 2),
			y = top + math.floor((bottom - top - panelHeight) / 2),
			width = panelWidth,
			height = panelHeight,
		},
		header = 76,
		dockWhileOpen = true,
	}
end

-- Column widths for a three-pane body (list | main | side). The main pane absorbs the rest.
function Layout.panes(
	width: number,
	list: number,
	side: number,
	minimum: number
): (number, number, number)
	local main = width - list - side
	if main < minimum then
		-- Shrink the side pane (never below `minimum`) before squeezing the main pane.
		side = math.max(minimum, side - (minimum - main))
		main = width - list - side
	end
	return list, math.max(0, main), side
end

return Layout
