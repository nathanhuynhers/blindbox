--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local ShelfConfig = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
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
				and key ~= "shelfId"
				and key ~= "shelfSlotId"
				and key ~= "carouselRevision"
				and key ~= "volume"
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
		and action ~= "BuyTen"
		and action ~= "Collect"
		and action ~= "Place"
		and action ~= "Remove"
		and action ~= "Daily"
		and action ~= "Login"
		and action ~= "Goal"
		and action ~= "ClaimOffline"
		and action ~= "Expand"
		and action ~= "BuyShelf"
		and action ~= "ShelfPlace"
		and action ~= "ShelfRemove"
		and action ~= "ShelfNext"
		and action ~= "ShelfPrevious"
		and action ~= "SetVolume"
	then
		return nil
	end
	local isShelf = action == "ShelfPlace"
		or action == "ShelfRemove"
		or action == "ShelfNext"
		or action == "ShelfPrevious"
	local shelfId, shelfSlotId, carouselRevision =
		data.shelfId, data.shelfSlotId, data.carouselRevision
	if isShelf then
		if
			typeof(carouselRevision) ~= "number"
			or carouselRevision < 0
			or carouselRevision > 9007199254740991
			or carouselRevision % 1 ~= 0
		then
			return nil
		end
		if action == "ShelfPlace" or action == "ShelfRemove" then
			if
				typeof(shelfId) ~= "string"
				or #shelfId > 64
				or not string.match(shelfId, "^shelf:[%w_-]+$")
				or typeof(shelfSlotId) ~= "string"
				or not ShelfConfig.visible(shelfSlotId)
			then
				return nil
			end
		elseif shelfSlotId ~= nil or shelfId ~= nil then
			return nil
		end
	elseif shelfId ~= nil or shelfSlotId ~= nil or carouselRevision ~= nil then
		return nil
	end
	local needsFigure = action == "Collect" or action == "Place" or action == "ShelfPlace"
	local needsSlot = action == "Collect" or action == "Place" or action == "Remove"
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
	local choice, volume = data.choice, data.volume
	if action == "SetVolume" then
		if
			(choice ~= "sfx" and choice ~= "music")
			or typeof(volume) ~= "number"
			or volume % 1 ~= 0
			or volume < 0
			or volume > 100
		then
			return nil
		end
	elseif volume ~= nil then
		return nil
	elseif action == "Buy" or action == "BuyTen" or action == "Daily" then
		if choice ~= nil and (typeof(choice) ~= "string" or not Catalog.collectionIds[choice]) then
			return nil
		end
	elseif choice ~= nil then
		return nil
	end
	local intent: Types.Intent = {
		shelfId = if typeof(shelfId) == "string" then shelfId else nil,
		shelfSlotId = if typeof(shelfSlotId) == "string" then shelfSlotId else nil,
		carouselRevision = if typeof(carouselRevision) == "number" then carouselRevision else nil,
		action = action,
		choice = if typeof(choice) == "string" then choice else nil,
		id = id,
		revision = revision,
		figure = if typeof(figure) == "string" then figure else nil,
		slot = if typeof(slot) == "number" then slot else nil,
		volume = if typeof(volume) == "number" then volume else nil,
	}
	return intent
end
function Protocol.same(a: Types.Intent, b: Types.Intent): boolean
	return a.action == b.action
		and a.revision == b.revision
		and a.figure == b.figure
		and a.slot == b.slot
		and a.choice == b.choice
		and a.shelfId == b.shelfId
		and a.shelfSlotId == b.shelfSlotId
		and a.carouselRevision == b.carouselRevision
		and a.volume == b.volume
end
return Protocol
