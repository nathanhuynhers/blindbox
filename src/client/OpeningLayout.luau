--!strict
-- The camera and overlay must use the same device-safe rectangle, including its padding.
local Layout = {}

function Layout.compact(width: number, height: number): boolean
	return height - 32 < 468 and width - 40 > height - 32
end

function Layout.cameraShift(width: number, height: number, distance: number, fov: number): number
	-- The camera faces +Z, so its screen-right vector points toward world -X.
	-- Translate camera AND aim together to place the toy at the left quarter of the safe area.
	local center = 20 + (width - 40) * 0.24
	return -(0.5 - center / width) * 2 * distance * math.tan(math.rad(fov / 2)) * width / height
end

return Layout
