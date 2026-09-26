--!strict
local Spec = {}

Spec.required = {
	"BoxBody",
	"FrontPatternPanel",
	"SidePatternPanel",
	"TopPatternPanel",
	"EmblemBadge",
	"CollectionNamePlate",
	"FrontFrameTrim",
	"SideFrameTrim",
	"TopFrameTrim",
	"LidCap",
	"BottomCap",
}

Spec.patternSurfaces = { "FrontPatternPanel", "SidePatternPanel", "TopPatternPanel" }
Spec.trimSurfaces = {
	"FrontFrameTrim",
	"SideFrameTrim",
	"TopFrameTrim",
	"TopBadgeMount",
	"UpperTrimBand",
	"FrontSeam",
}

function Spec.missing(present: { [string]: boolean }): { string }
	local missing = {}
	for _, name in Spec.required do
		if not present[name] then
			table.insert(missing, name)
		end
	end
	return missing
end

return Spec
