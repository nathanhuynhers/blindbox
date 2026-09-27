--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Shelves = {}
export type View = { index: number, revision: number, lastTurn: number }
export type Access = { actorId: number, ownerId: number, near: boolean, view: View }
function Shelves.new(): Types.Shelves
	return { pages = { { id = "page:1", placements = {}, customization = {} } } }
end
function Shelves.newView(): View
	return { index = 1, revision = 0, lastTurn = -math.huge }
end
function Shelves.copy(shelves: Types.Shelves): Types.Shelves
	local pages: { Types.ShelfPage } = {}
	for _, page in shelves.pages do
		table.insert(pages, {
			id = page.id,
			placements = table.clone(page.placements),
			customization = table.clone(page.customization),
		})
	end
	return { pages = pages }
end
local function fields(value: unknown, allowed: { string }): boolean
	if typeof(value) ~= "table" then
		return false
	end
	for key in value :: { [string]: unknown } do
		if not table.find(allowed, key) then
			return false
		end
	end
	return true
end
function Shelves.decode(raw: unknown, discovered: { [string]: boolean }): Types.Shelves?
	if not fields(raw, { "pages" }) then
		return nil
	end
	local data = raw :: { [string]: unknown }
	if typeof(data.pages) ~= "table" then
		return nil
	end
	local pages = data.pages :: { [number]: unknown }
	local count = 0
	for key in pages do
		if typeof(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return nil
		end
		count += 1
	end
	if count == 0 then
		return nil
	end
	local result: Types.Shelves = { pages = {} }
	local ids: { [string]: boolean } = {}
	for index = 1, count do
		local rawPage = pages[index]
		if not fields(rawPage, { "id", "placements", "customization" }) then
			return nil
		end
		local page = rawPage :: { [string]: unknown }
		if
			typeof(page.id) ~= "string"
			or #page.id > 64
			or not string.match(page.id, "^page:[%w_-]+$")
			or ids[page.id]
			or typeof(page.placements) ~= "table"
			or typeof(page.customization) ~= "table"
			or next(page.customization :: {}) ~= nil
		then
			return nil
		end
		ids[page.id] = true
		local placements: { [string]: string } = {}
		for slot, figure in page.placements :: { [string]: unknown } do
			-- Validate structural IDs, not current geometry capacity. Shrinking a layout never erases saved placements.
			if
				typeof(slot) ~= "string"
				or not Config.parseSlot(slot)
				or typeof(figure) ~= "string"
				or not Catalog.byId[figure]
				or not discovered[figure]
			then
				return nil
			end
			placements[slot] = figure
		end
		table.insert(result.pages, { id = page.id, placements = placements, customization = {} })
	end
	return result
end
function Shelves.publicView(shelves: Types.Shelves, view: View): Types.ShelfView
	local page = shelves.pages[view.index]
	local placements: { [string]: string } = {}
	for _, slot in Config.slots() do
		placements[slot] = page.placements[slot]
	end
	return {
		pageId = page.id,
		pageIndex = view.index,
		pageCount = #shelves.pages,
		pageRevision = view.revision,
		placements = placements,
	}
end
function Shelves.turn(shelves: Types.Shelves, view: View, direction: number, now: number): boolean
	if (direction ~= -1 and direction ~= 1) or now - view.lastTurn < 0.5 then
		return false
	end
	view.lastTurn = now
	view.index = (view.index - 1 + direction) % #shelves.pages + 1
	view.revision += 1
	return true
end
function Shelves.mutate(
	state: Types.State,
	intent: Types.Intent,
	access: Access?,
	now: number
): (boolean, string, string?)
	if not access or access.actorId ~= access.ownerId or not access.near then
		return false, "Walk to your own shelves to edit.", nil
	end
	local page = state.shelves.pages[access.view.index]
	if
		intent.pageId ~= page.id
		or intent.pageRevision ~= access.view.revision
		or intent.revision ~= state.revision
	then
		return false, "The shelf page changed. Try again.", nil
	end
	if intent.action == "ShelfNext" or intent.action == "ShelfPrevious" then
		local ok = Shelves.turn(
			state.shelves,
			access.view,
			if intent.action == "ShelfNext" then 1 else -1,
			now
		)
		return ok, if ok then "Shelf page changed." else "Please wait before turning again.", nil
	end
	local slot = intent.shelfSlotId or ""
	if not Config.visible(slot) then
		return false, "Unknown shelf slot.", nil
	end
	if intent.action == "ShelfPlace" then
		local figure = intent.figure or ""
		if not Catalog.byId[figure] or not state.discovered[figure] then
			return false, "Discover that figure first.", nil
		end
		page.placements[slot] = figure
	elseif intent.action == "ShelfRemove" then
		page.placements[slot] = nil
	else
		return false, "Unknown shelf action.", nil
	end
	state.revision += 1
	return true, "Shelves updated.", nil
end
return Shelves
