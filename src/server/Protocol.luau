--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Protocol = {}
function Protocol.parse(raw: unknown): Types.Intent?
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: unknown }
	local count = 0
	for key in data do
		count += 1
		if
			count > 6
			or (
				key ~= "action"
				and key ~= "id"
				and key ~= "revision"
				and key ~= "figure"
				and key ~= "slot"
				and key ~= "choice"
			)
		then
			return nil
		end
	end
	local action, id, revision = data.action, data.id, data.revision
	if typeof(action) ~= "string" or typeof(id) ~= "string" or #id < 1 or #id > 64 then
		return nil
	end
	if
		typeof(revision) ~= "number"
		or revision < 0
		or revision > 9007199254740991
		or revision % 1 ~= 0
	then
		return nil
	end
	if
		action ~= "Buy"
		and action ~= "Place"
		and action ~= "Remove"
		and action ~= "Recycle"
		and action ~= "Redeem"
		and action ~= "Daily"
		and action ~= "Goal"
		and action ~= "Expand"
		and action ~= "Theme"
	then
		return nil
	end
	local needsFigure = action == "Place" or action == "Recycle" or action == "Redeem"
	local needsSlot = action == "Place" or action == "Remove"
	local figure, slot = data.figure, data.slot
	if needsFigure then
		if typeof(figure) ~= "string" or #figure > 64 or not Catalog.byId[figure] then
			return nil
		end
	elseif figure ~= nil then
		return nil
	end
	if needsSlot then
		if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > 4 then
			return nil
		end
	elseif slot ~= nil then
		return nil
	end
	local choice = data.choice
	if action == "Buy" or action == "Daily" then
		if choice ~= nil and (typeof(choice) ~= "string" or not Catalog.collectionIds[choice]) then
			return nil
		end
	elseif action == "Theme" then
		if typeof(choice) ~= "string" or not Catalog.themes[choice] then
			return nil
		end
	elseif choice ~= nil then
		return nil
	end
	local intent: Types.Intent = {
		action = action,
		choice = if typeof(choice) == "string" then choice else nil,
		id = id,
		revision = revision,
		figure = if typeof(figure) == "string" then figure else nil,
		slot = if typeof(slot) == "number" then slot else nil,
	}
	return intent
end
function Protocol.same(a: Types.Intent, b: Types.Intent): boolean
	return a.action == b.action
		and a.revision == b.revision
		and a.figure == b.figure
		and a.slot == b.slot
		and a.choice == b.choice
end
return Protocol
