--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShowroomConfig)
local Showrooms = {}
function Showrooms.sync(state: Types.State)
	for _, collection in Catalog.collections do
		local complete, count = true, 0
		for _, figure in Catalog.figures do
			if figure.collection == collection.id then
				count += 1
				if not state.discovered[figure.id] then
					complete = false
				end
			end
		end
		if complete and count > 0 and not state.showrooms.rooms[collection.showroomId] then
			state.showrooms.rooms[collection.showroomId] = {
				roomId = collection.showroomId,
				sourceType = "Collection",
				sourceCollectionId = collection.id,
				theme = state.showrooms.palette,
				placements = {},
				customization = {},
			}
		end
	end
end
export type Access = { actorId: number, ownerId: number, runtimeId: string, roomId: string? }
function Showrooms.edit(
	state: Types.State,
	intent: Types.Intent,
	access: Access?
): (boolean, string, string?)
	if
		not access
		or access.actorId ~= access.ownerId
		or access.runtimeId ~= intent.runtimeId
		or not access.roomId
		or access.roomId ~= intent.roomId
		or intent.revision ~= state.revision
	then
		return false, "This Showroom is read-only or the visit has ended.", nil
	end
	local room = state.showrooms.rooms[access.roomId]
	if not room then
		return false, "Unknown Showroom.", nil
	end
	if intent.action == "ShowroomTheme" then
		local theme = intent.choice or ""
		if not state.showrooms.palettes[theme] or not Catalog.themes[theme] then
			return false, "That Showroom palette is not owned.", nil
		end
		room.theme = theme
	else
		local anchor = intent.anchorId or ""
		if not Showrooms.anchor(anchor) then
			return false, "Unknown figure anchor.", nil
		end
		if intent.action == "ShowroomPlace" then
			local figure = intent.figure or ""
			if not Catalog.byId[figure] or not state.discovered[figure] then
				return false, "Discover that figure first.", nil
			end
			room.placements[anchor] = figure
		elseif intent.action == "ShowroomRemove" then
			room.placements[anchor] = nil
		else
			return false, "Unknown Showroom action.", nil
		end
	end
	state.revision += 1
	return true, "Showroom updated. Cosmetic figures earn no Coins.", nil
end
function Showrooms.copyRoom(room: Types.Showroom): Types.Showroom
	return {
		roomId = room.roomId,
		sourceType = room.sourceType,
		sourceCollectionId = room.sourceCollectionId,
		theme = room.theme,
		placements = table.clone(room.placements),
		customization = table.clone(room.customization),
	}
end
function Showrooms.copy(value: Types.Showrooms): Types.Showrooms
	local rooms: { [string]: Types.Showroom } = {}
	for id, room in value.rooms do
		rooms[id] = Showrooms.copyRoom(room)
	end
	return { rooms = rooms, palette = value.palette, palettes = table.clone(value.palettes) }
end
function Showrooms.anchor(id: string): boolean
	return table.find(Config.anchors, id) ~= nil
end
function Showrooms.name(room: Types.Showroom): string
	for _, collection in Catalog.collections do
		if collection.id == room.sourceCollectionId then
			return collection.name .. " Showroom"
		end
	end
	return "Custom Showroom"
end
local function fields(value: unknown, allowed: { string }): boolean
	if typeof(value) ~= "table" then
		return false
	end
	for key in value :: { [string]: unknown } do
		if typeof(key) ~= "string" or not table.find(allowed, key) then
			return false
		end
	end
	return true
end
function Showrooms.decode(raw: unknown, discovered: { [string]: boolean }): Types.Showrooms?
	if not fields(raw, { "rooms", "palette", "palettes" }) then
		return nil
	end
	local data = raw :: { [string]: unknown }
	if
		typeof(data.palette) ~= "string"
		or not Catalog.themes[data.palette]
		or typeof(data.palettes) ~= "table"
		or typeof(data.rooms) ~= "table"
	then
		return nil
	end
	local result: Types.Showrooms = { rooms = {}, palette = data.palette, palettes = {} }
	for id, owned in data.palettes :: { [string]: unknown } do
		if typeof(id) ~= "string" or not Catalog.themes[id] or owned ~= true then
			return nil
		end
		result.palettes[id] = true
	end
	if not result.palettes.grove or not result.palettes[result.palette] then
		return nil
	end
	for id, value in data.rooms :: { [string]: unknown } do
		if
			typeof(id) ~= "string"
			or #id > 96
			or not fields(value, {
				"roomId",
				"sourceType",
				"sourceCollectionId",
				"theme",
				"placements",
				"customization",
			})
		then
			return nil
		end
		local room = value :: { [string]: unknown }
		if
			room.roomId ~= id
			or typeof(room.theme) ~= "string"
			or not result.palettes[room.theme]
			or typeof(room.placements) ~= "table"
			or typeof(room.customization) ~= "table"
		then
			return nil
		end
		local collectionId = room.sourceCollectionId
		if room.sourceType == "Collection" then
			local definitionFound = false
			for _, collection in Catalog.collections do
				if collection.id == collectionId and collection.showroomId == id then
					definitionFound = true
				end
			end
			if not definitionFound then
				return nil
			end
			for _, figure in Catalog.figures do
				if figure.collection == collectionId and not discovered[figure.id] then
					return nil
				end
			end
		elseif room.sourceType == "Custom" then
			if collectionId ~= nil or not string.match(id, "^custom:[%w_-]+$") then
				return nil
			end
		else
			return nil
		end
		local decoded: Types.Showroom = {
			roomId = id,
			sourceType = room.sourceType :: string,
			sourceCollectionId = if typeof(collectionId) == "string" then collectionId else nil,
			theme = room.theme,
			placements = {},
			customization = {},
		}
		for anchor, figure in room.placements :: { [string]: unknown } do
			if
				typeof(anchor) ~= "string"
				or not Showrooms.anchor(anchor)
				or typeof(figure) ~= "string"
				or not Catalog.byId[figure]
				or not discovered[figure]
			then
				return nil
			end
			decoded.placements[anchor] = figure
		end
		-- No decor definitions are approved; reject future data instead of erasing it.
		if next(room.customization :: {}) ~= nil then
			return nil
		end
		result.rooms[id] = decoded
	end
	return result
end
return Showrooms
