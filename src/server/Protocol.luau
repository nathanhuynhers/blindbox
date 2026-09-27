--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local ShowroomConfig = require(game:GetService("ReplicatedStorage").Shared.ShowroomConfig)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
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
			count > 9
			or (
				key ~= "action"
				and key ~= "id"
				and key ~= "revision"
				and key ~= "figure"
				and key ~= "slot"
				and key ~= "choice"
				and key ~= "roomId"
				and key ~= "anchorId"
				and key ~= "runtimeId"
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
		and action ~= "ShowroomPlace"
		and action ~= "ShowroomRemove"
		and action ~= "ShowroomTheme"
	then
		return nil
	end
	local isShowroom = action == "ShowroomPlace"
		or action == "ShowroomRemove"
		or action == "ShowroomTheme"
	local roomId, anchorId, runtimeId = data.roomId, data.anchorId, data.runtimeId
	if isShowroom then
		if
			typeof(roomId) ~= "string"
			or #roomId < 1
			or #roomId > 96
			or typeof(runtimeId) ~= "string"
			or #runtimeId < 1
			or #runtimeId > 64
		then
			return nil
		end
		if action ~= "ShowroomTheme" then
			if typeof(anchorId) ~= "string" or not table.find(ShowroomConfig.anchors, anchorId) then
				return nil
			end
		elseif anchorId ~= nil then
			return nil
		end
	elseif roomId ~= nil or anchorId ~= nil or runtimeId ~= nil then
		return nil
	end
	local needsFigure = action == "Place"
		or action == "Recycle"
		or action == "Redeem"
		or action == "ShowroomPlace"
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
		if
			typeof(slot) ~= "number"
			or slot % 1 ~= 0
			or slot < 1
			or slot > DisplayConfig.maxSlots
		then
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
	elseif action == "ShowroomTheme" then
		if typeof(choice) ~= "string" or not Catalog.themes[choice] then
			return nil
		end
	elseif choice ~= nil then
		return nil
	end
	local intent: Types.Intent = {
		roomId = if typeof(roomId) == "string" then roomId else nil,
		anchorId = if typeof(anchorId) == "string" then anchorId else nil,
		runtimeId = if typeof(runtimeId) == "string" then runtimeId else nil,
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
		and a.roomId == b.roomId
		and a.anchorId == b.anchorId
		and a.runtimeId == b.runtimeId
end
return Protocol
