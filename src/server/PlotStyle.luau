--!strict
-- The single plot accent. Every plot reads its accent through `PlotStyle.accent`, so a future
-- per-player customization system can override one plot without touching the fixtures.
local PlotStyle = {}

PlotStyle.DefaultAccent = Color3.fromRGB(240, 143, 176) -- #F08FB0 pastel pink

-- `ownerId` is nil for unowned static geometry. No customization exists yet.
function PlotStyle.accent(_ownerId: number?): Color3
	return PlotStyle.DefaultAccent
end

return PlotStyle
