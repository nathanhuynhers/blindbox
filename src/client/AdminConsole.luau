--!strict
local Currency = require(game:GetService("ReplicatedStorage").Shared.Currency)
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Actions = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local A = require(game:GetService("ReplicatedStorage").Shared.AdminTypes)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Scope = require(script.Parent.UIScope)
local Client = require(script.Parent.AdminClient)
local Console = {}
export type Controller = { destroy: () -> () }
local palette = {
	back = Color3.fromRGB(17, 20, 28),
	panel = Color3.fromRGB(25, 30, 41),
	field = Color3.fromRGB(35, 42, 56),
	text = Color3.fromRGB(233, 238, 248),
	muted = Color3.fromRGB(157, 169, 191),
	accent = Color3.fromRGB(129, 174, 252),
	danger = Color3.fromRGB(253, 156, 160),
	good = Color3.fromRGB(145, 223, 183),
}
local function round(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end
local function padding(object: GuiObject, value: number)
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft, inset.PaddingRight, inset.PaddingTop, inset.PaddingBottom =
		UDim.new(0, value), UDim.new(0, value), UDim.new(0, value), UDim.new(0, value)
	inset.Parent = object
end
local function stack(object: GuiObject, gap: number)
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder = UDim.new(0, gap), Enum.SortOrder.LayoutOrder
	layout.Parent = object
end
local function text(parent: Instance, value: string, height: number?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Text, label.Font, label.TextSize =
		1, value, Enum.Font.Gotham, 14
	label.TextColor3, label.TextWrapped = color or palette.text, true
	label.TextXAlignment, label.TextYAlignment =
		Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
	label.Size = UDim2.new(1, 0, 0, height or 28)
	if not height then
		label.AutomaticSize = Enum.AutomaticSize.Y
	end
	label.Parent = parent
	return label
end
local function field(parent: Instance, hint: string, value: string): TextBox
	local box = Instance.new("TextBox")
	box.Size, box.BackgroundColor3 = UDim2.new(1, 0, 0, 44), palette.field
	box.TextColor3, box.PlaceholderColor3, box.Font, box.TextSize =
		palette.text, palette.muted, Enum.Font.Gotham, 14
	box.Text, box.PlaceholderText, box.ClearTextOnFocus = value, hint, false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = parent
	round(box, 6)
	padding(box, 10)
	return box
end
local function collectionName(id: string): string
	for _, collection in Catalog.collections do
		if collection.id == id then
			return collection.name
		end
	end
	return id
end
local function finiteInteger(value: string, low: number, high: number): number?
	local number = tonumber(value)
	return if number
			and number == number
			and number >= low
			and number <= high
			and number % 1 == 0
		then number
		else nil
end
function Console.create(
	remote: RemoteFunction,
	canOpen: () -> boolean,
	focus: (boolean) -> ()
): Controller
	local alive, opened, processing = true, false, false
	local scope, pageScope, modalScope = Scope.create(), Scope.create(), Scope.create()
	local gui: ScreenGui? = nil
	local client = Client.create(function(raw)
		return remote:InvokeServer(raw) :: A.Reply
	end)
	local reply: A.Reply = { ok = true, message = "Connect to inspect this server." }
	local inspector: A.Inspector? = nil
	local function playerRows(): { A.PlayerRow }
		local empty: { A.PlayerRow } = {}
		return reply.players or empty
	end
	local function boxRows(): { A.Box }
		local empty: { A.Box } = {}
		return reply.boxes or empty
	end
	local selected = Players.LocalPlayer.UserId
	local section = "Players"
	local collection = Catalog.collections[1].id
	local figureId = Catalog.figures[1].id
	local filterCollection, filterRarity, query = "All", "All", ""
	local playerQuery, ownedOnly = "", false
	local thumbnails: { [number]: string } = {}
	local amountValue, quantityValue, pityValue, simulationValue, reasonValue =
		"1000", "1", "0", "1000", ""
	local pityRarity, forcedRarity = "Legendary", "Rare"
	local body: ScrollingFrame
	local targetLabel: TextLabel
	local status: TextLabel
	local panel: Frame
	local sidebar: Frame
	local nav: { TextButton } = {}
	local previousSelection: GuiObject? = nil
	local modalSelection: GuiObject? = nil
	local render: () -> ()
	local setOpen: (boolean) -> ()
	local run: (A.Request?) -> ()
	local confirm: (string, () -> ()) -> ()
	local function button(
		parent: Instance,
		value: string,
		callback: () -> (),
		danger: boolean?,
		owner: Scope.Scope?
	): TextButton
		local object = Instance.new("TextButton")
		object.Size, object.BackgroundColor3 = UDim2.new(1, 0, 0, 44), palette.field
		object.TextColor3, object.Text, object.Font, object.TextSize =
			if danger then palette.danger else palette.accent, value, Enum.Font.GothamMedium, 14
		object.TextWrapped, object.AutoButtonColor = true, true
		object.Active, object.Selectable = not processing, not processing
		if processing then
			object.TextTransparency = 0.55
		end
		object.Parent = parent
		round(object, 6)
		padding(object, 8)
		local connectionOwner = owner or pageScope
		connectionOwner.connect(object.Activated, function()
			if not processing then
				callback()
			end
		end)
		return object
	end
	local function note(value: string, good: boolean?)
		if not alive or not gui then
			return
		end
		status.Text, status.TextColor3 = value, if good then palette.good else palette.danger
	end
	local function command(action: string): A.Request
		return {
			token = "",
			sequence = 0,
			action = action,
			target = selected,
			revision = if inspector then inspector.revision else nil,
		}
	end
	local function refresh()
		run(command("Inspect"))
	end
	local function closeModal()
		local restore = modalSelection
		modalSelection = nil
		modalScope.destroy()
		modalScope = Scope.create()
		if gui then
			local modal = gui:FindFirstChild("Confirmation")
			if modal then
				modal:Destroy()
			end
		end
		GuiService.SelectedObject = if restore and restore.Parent then restore else nil
	end
	confirm = function(message, callback)
		if not gui then
			return
		end
		local origin = GuiService.SelectedObject
		closeModal()
		modalSelection = origin
		local shade = Instance.new("TextButton")
		shade.Name, shade.Text, shade.AutoButtonColor, shade.Modal = "Confirmation", "", false, true
		shade.BackgroundColor3, shade.BackgroundTransparency, shade.Size =
			Color3.new(), 0.2, UDim2.fromScale(1, 1)
		shade.ZIndex, shade.Parent = 20, gui
		local card = Instance.new("Frame")
		card.AnchorPoint, card.Position, card.Size =
			Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.85, 0.85)
		card.BackgroundColor3, card.ZIndex, card.Parent = palette.panel, 21, shade
		local size = Instance.new("UISizeConstraint")
		size.MaxSize = Vector2.new(500, 380)
		size.Parent = card
		round(card, 10)
		padding(card, 16)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size, scroll.BackgroundTransparency, scroll.ScrollBarThickness =
			UDim2.fromScale(1, 1), 1, 5
		scroll.AutomaticCanvasSize, scroll.CanvasSize, scroll.ZIndex =
			Enum.AutomaticSize.Y, UDim2.new(), 22
		scroll.Parent = card
		stack(scroll, 12)
		padding(scroll, 4)
		text(scroll, "Confirm administrative action", nil, palette.danger).TextSize = 18
		text(scroll, message)
		local accept = button(scroll, "Confirm action", function()
			closeModal()
			callback()
		end, true, modalScope)
		button(scroll, "Cancel", closeModal, false, modalScope)
		for _, child in card:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 23
			end
		end
		GuiService.SelectedObject = accept
	end
	local function sendRisk(request: A.Request, warning: string)
		local targetName = tostring(selected)
		for _, row in playerRows() do
			if row.userId == selected then
				targetName = row.username .. " (" .. selected .. ")"
			end
		end
		confirm(
			`Target: {targetName}\n\n{warning}\n\nThe server will recheck permissions, session readiness and state before executing.`,
			function()
				request.confirmed = true
				run(request)
			end
		)
	end
	run = function(request)
		if processing or not alive then
			return
		end
		processing = true
		closeModal()
		status.Text, status.TextColor3 = "Processing server request…", palette.muted
		render()
		task.spawn(function()
			local recovering = client.uncertain()
			local response = if recovering
				then client.retry()
				elseif request then client.request(request)
				else client.connect()
			if not alive then
				return
			end
			processing = false
			if response.players then
				reply.players = response.players
			end
			if response.boxes then
				reply.boxes = response.boxes
			end
			if response.audit then
				reply.audit = response.audit
			end
			if response.largeChange then
				reply.largeChange = response.largeChange
			end
			if response.transactionLimit then
				reply.transactionLimit = response.transactionLimit
			end
			reply.simulation = response.simulation
			if request or recovering then
				inspector = response.inspector
			end
			note(response.message, response.ok)
			render()
		end)
	end
	local function heading(value: string)
		local label = text(body, value, nil, palette.text)
		label.Font, label.TextSize = Enum.Font.GothamMedium, 18
	end
	local function numeric(
		parent: Instance,
		title: string,
		initial: string,
		changed: (string) -> ()
	): TextBox
		text(parent, title, nil, palette.muted)
		local input = field(parent, title, initial)
		pageScope.connect(input:GetPropertyChangedSignal("Text"), function()
			changed(input.Text)
		end)
		return input
	end
	local function collectionPicker()
		button(body, "Box / collection: " .. collectionName(collection) .. "  ›", function()
			local index = 1
			for i, row in Catalog.collections do
				if row.id == collection then
					index = i
				end
			end
			collection = Catalog.collections[index % #Catalog.collections + 1].id
			render()
		end)
	end
	local function requireInspector(): A.Inspector?
		if not inspector or inspector.userId ~= selected then
			text(
				body,
				"Select a connected player in Players, then refresh their authoritative data.",
				nil,
				palette.muted
			)
			return nil
		end
		if not inspector.ready then
			text(body, "Session is read-only: " .. inspector.saveStatus, nil, palette.danger)
		end
		return inspector
	end
	local function inventoryText(state: A.Inspector, id: string): string
		local shelves = 0
		for _, unit in state.shelves.units do
			for _, placed in unit.placements do
				if placed == id then
					shelves += 1
				end
			end
		end
		return `Owned: {state.owned[id] or 0}  ·  Display: {if table.find(state.display.slots, id)
			then "yes"
			else "no"}  ·  Shelves: {shelves}`
	end
	local function playersPage()
		heading("Connected players")
		local search = field(body, "Search username, display name or UserId", playerQuery)
		local list = Instance.new("Frame")
		list.BackgroundTransparency, list.Size, list.AutomaticSize =
			1, UDim2.fromScale(1, 0), Enum.AutomaticSize.Y
		list.Parent = body
		stack(list, 8)
		local listScope = Scope.create()
		pageScope.add(function()
			listScope.destroy()
		end)
		local function populate()
			listScope.destroy()
			listScope = Scope.create()
			for _, child in list:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local found = 0
			for _, row in playerRows() do
				if
					playerQuery ~= ""
					and not string.find(
						string.lower(row.username .. " " .. row.displayName .. " " .. row.userId),
						string.lower(playerQuery),
						1,
						true
					)
				then
					continue
				end
				found += 1
				local pick = button(
					list,
					`{row.displayName}  @{row.username}\n{row.userId} · Online · {if row.plot
						then "Plot " .. row.plot
						else "Loading plot"}`,
					function()
						selected, inspector = row.userId, nil
						refresh()
					end,
					false,
					listScope
				)
				pick.Size, pick.TextXAlignment = UDim2.new(1, 0, 0, 72), Enum.TextXAlignment.Left
				local inset = pick:FindFirstChildOfClass("UIPadding")
				if inset then
					inset.PaddingLeft = UDim.new(0, 66)
				end
				local avatar = Instance.new("ImageLabel")
				avatar.BackgroundColor3, avatar.Position, avatar.Size =
					palette.panel, UDim2.fromOffset(8, 10), UDim2.fromOffset(48, 48)
				avatar.Parent = pick
				round(avatar, 24)
				if thumbnails[row.userId] then
					avatar.Image = thumbnails[row.userId]
					continue
				end
				task.spawn(function()
					local ok, image = pcall(function()
						return Players:GetUserThumbnailAsync(
							row.userId,
							Enum.ThumbnailType.HeadShot,
							Enum.ThumbnailSize.Size100x100
						)
					end)
					if ok and alive and avatar.Parent then
						thumbnails[row.userId] = image
						avatar.Image = image
					end
				end)
			end
			if found == 0 then
				text(list, "No connected players match this search.", nil, palette.muted)
			end
		end
		pageScope.connect(search:GetPropertyChangedSignal("Text"), function()
			playerQuery = search.Text
			populate()
		end)
		populate()
		local state = requireInspector()
		if not state then
			return
		end
		heading("Player inspector")
		local discovered, copies, unique = 0, 0, 0
		for _ in state.discovered do
			discovered += 1
		end
		for _, count in state.owned do
			unique += 1
			copies += count
		end
		text(
			body,
			`Coins  {state.coins}\nDiscovered  {discovered} / {#Catalog.figures} · Owned  {unique} unique / {copies} copies\nDisplay  {state.display.unlocked} slots · Shelves  {#state.shelves.units} units\nIncome  {string.format(
				"%.2f",
				state.rate
			)} Coins/s · Boxes opened  {state.boxesOpened}`
		)
		text(
			body,
			`Plot {state.plot} · Profile revision {state.revision}\n{state.saveStatus} · {if state.persistent
				then "Persistent session"
				else "Unsaved Studio preview"}\nWelcome Quest stage {state.step} · Login streak {state.loginStreak}\nDaily Display progress {state.goalProgress} / 3 · Pending offline Coins {state.offlinePending}`,
			nil,
			palette.muted
		)
		for slot, id in state.display.slots do
			text(
				body,
				`Display {slot}: {if id == "" then "Empty" else Catalog.byId[id].name} · Bank {state.earnings[id] or 0}`,
				nil,
				palette.muted
			)
		end
		for group, counters in state.pity do
			text(
				body,
				`Pity {group}: Legendary {counters.legendaryDryRolls} · Mythical {counters.mythicalDryRolls}`,
				nil,
				palette.muted
			)
		end
		button(body, "Teleport to selected player", function()
			run(command("Teleport"))
		end)
		numeric(body, "Optional kick reason (160 characters max)", reasonValue, function(value)
			reasonValue = value
		end)
		button(body, "Kick player…", function()
			if #reasonValue > 160 then
				note("Kick reason must be at most 160 characters.")
				return
			end
			local request = command("Kick")
			request.reason = reasonValue
			sendRisk(
				request,
				"This disconnects the player. Their profile follows the normal departure save path."
			)
		end, true)
	end
	local function economyPage()
		heading("Currency management")
		local state = requireInspector()
		if not state then
			return
		end
		text(
			body,
			`Coin balance  {state.coins}\nDisplay income  {string.format("%.2f", state.rate)} Coins/s\nThemed set bonus  {string.format(
				"%.2f",
				state.bonus
			)} Coins/s\nBoxes opened  {state.boxesOpened} · Pending offline Coins  {state.offlinePending}`
		)
		text(
			body,
			"Per-figure duplicate multipliers contribute to Display income. Lifetime earnings history is not stored.",
			nil,
			palette.muted
		)
		numeric(body, "Whole Coins", amountValue, function(value)
			amountValue = value
		end)
		for _, action in { "GrantCoins", "RemoveCoins", "SetBalance" } do
			local title = if action == "GrantCoins"
				then "Grant Coins"
				elseif action == "RemoveCoins" then "Remove Coins"
				else "Set balance"
			button(body, title, function()
				local amount = finiteInteger(
					amountValue,
					if action == "SetBalance" then 0 else 1,
					if action == "SetBalance"
						then Currency.limit
						else reply.transactionLimit or 100000000
				)
				if not amount then
					note("Enter a valid whole Coin amount within the configured bounds.")
					return
				end
				local request = command(action)
				request.amount = amount
				local change = if action == "SetBalance"
					then math.abs(state.coins - amount)
					else amount
				if change >= (reply.largeChange or 1000000) or action == "SetBalance" then
					sendRisk(
						request,
						`{title}: {amount} Coins. This changes the live session wallet.`
					)
				else
					run(request)
				end
			end, action ~= "GrantCoins")
		end
		heading("Session audit · nonpersistent")
		local count = 0
		local rows = reply.audit or {}
		for i = #rows, 1, -1 do
			local row = rows[i]
			if row.target ~= selected then
				continue
			end
			count += 1
			text(
				body,
				`{os.date("!%H:%M:%S", row.timestamp)} UTC · {row.action} · {if row.ok
					then "Success"
					else "Failed"}\n{row.message}{if row.amount
					then " · Amount " .. row.amount
					else ""}`,
				nil,
				if row.ok then palette.muted else palette.danger
			)
			if count == 30 then
				break
			end
		end
		if count == 0 then
			text(
				body,
				"No administrative changes recorded for this player in the current server session.",
				nil,
				palette.muted
			)
		end
	end
	local function figuresPage()
		heading("Collectible management")
		local state = requireInspector()
		if not state then
			return
		end
		collectionPicker()
		button(body, "Grant entire selected collection…", function()
			local request = command("GrantCollection")
			request.collection = collection
			sendRisk(
				request,
				"Grant one copy of every figure in "
					.. collectionName(collection)
					.. ". Discoveries and first-completion Shelf rewards apply."
			)
		end)
		local figure = Catalog.byId[figureId]
		heading(figure.name)
		text(
			body,
			`{figure.rarity} · {collectionName(figure.collection)}\n{figure.id}\n{inventoryText(
				state,
				figure.id
			)}`
		)
		numeric(body, "Copies (1–100)", quantityValue, function(value)
			quantityValue = value
		end)
		for _, action in { "GrantFigure", "RemoveFigure" } do
			button(
				body,
				if action == "GrantFigure" then "Grant figure" else "Remove figure…",
				function()
					local quantity = finiteInteger(quantityValue, 1, 100)
					if not quantity then
						note("Enter a whole quantity from 1 to 100.")
						return
					end
					local request = command(action)
					request.figure, request.quantity = figure.id, quantity
					if action == "RemoveFigure" or quantity > 1 then
						sendRisk(
							request,
							`{action}: {quantity} × {figure.name}.\nRemoval reconciles Display and Shelves. Final-copy removal collects whole banked Coins (wallet room required) and forfeits the fraction below one Coin. Discovery history and earned Shelf rewards remain.`
						)
					else
						run(request)
					end
				end,
				action == "RemoveFigure"
			)
		end
		heading("Figure browser / inventory")
		button(
			body,
			"Collection filter: " .. collectionName(filterCollection) .. "  ›",
			function()
				local ids = { "All" }
				for _, row in Catalog.collections do
					table.insert(ids, row.id)
				end
				filterCollection = ids[(table.find(ids, filterCollection) or 1) % #ids + 1]
				render()
			end
		)
		button(body, "Rarity filter: " .. filterRarity .. "  ›", function()
			local ids: { string } = { "All" }
			for _, id in Rarity.order do
				table.insert(ids, id)
			end
			filterRarity = ids[(table.find(ids, filterRarity) or 1) % #ids + 1]
			render()
		end)
		button(
			body,
			if ownedOnly
				then "Showing owned figures · Show all"
				else "Showing all figures · Show owned",
			function()
				ownedOnly = not ownedOnly
				render()
			end
		)
		local search = field(body, "Search figure name or ID", query)
		local list = Instance.new("Frame")
		list.BackgroundTransparency, list.Size, list.AutomaticSize =
			1, UDim2.fromScale(1, 0), Enum.AutomaticSize.Y
		list.Parent = body
		stack(list, 8)
		local listScope = Scope.create()
		pageScope.add(function()
			listScope.destroy()
		end)
		local function populate()
			listScope.destroy()
			listScope = Scope.create()
			for _, child in list:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local count = 0
			for _, entry in Catalog.figures do
				if filterCollection ~= "All" and entry.collection ~= filterCollection then
					continue
				end
				if filterRarity ~= "All" and entry.rarity ~= filterRarity then
					continue
				end
				if ownedOnly and not state.owned[entry.id] then
					continue
				end
				if
					query ~= ""
					and not string.find(
						string.lower(entry.name .. " " .. entry.id),
						string.lower(query),
						1,
						true
					)
				then
					continue
				end
				count += 1
				local row = button(
					list,
					`{entry.name} · {entry.rarity}\n{collectionName(entry.collection)} · {entry.id}\n{inventoryText(
						state,
						entry.id
					)}`,
					function()
						figureId = entry.id
						render()
						body.CanvasPosition = Vector2.zero
					end,
					false,
					listScope
				)
				row.Size, row.TextXAlignment = UDim2.new(1, 0, 0, 92), Enum.TextXAlignment.Left
			end
			if count == 0 then
				text(list, "No figures match these filters.", nil, palette.muted)
			end
		end
		pageScope.connect(search:GetPropertyChangedSignal("Text"), function()
			query = search.Text
			populate()
		end)
		populate()
	end
	local function boxesPage()
		heading("Blind-box debugging")
		local state = requireInspector()
		if not state then
			return
		end
		collectionPicker()
		local box: A.Box? = nil
		for _, entry in boxRows() do
			if entry.id == collection then
				box = entry
			end
		end
		if not box then
			text(body, "Box configuration unavailable. Refresh to load it.")
			return
		end
		text(
			body,
			`Price {box.price} Coins · Pity group {box.group}\nEffective odds below are the actual next ordinary roll, including independent pity and guarantee priority. No other luck modifiers are implemented. Overrides are shown separately.`
		)
		for _, rarity in Rarity.order do
			if box.base[rarity] then
				text(
					body,
					`{rarity} · Base {string.format("%g", box.base[rarity])}% · Effective {string.format(
						"%g",
						box.effective[rarity] or 0
					)}%`,
					nil,
					palette.muted
				)
			end
		end
		local names = {}
		for _, entry in Catalog.figures do
			if entry.collection == collection then
				table.insert(names, entry.name)
			end
		end
		text(body, "Eligible figures: " .. table.concat(names, ", "), nil, palette.muted)
		heading("Pity inspector")
		if box.pity then
			local counters = state.pity[box.group]
			for _, rarity in { "Legendary", "Mythical" } do
				local curve = box.pity[rarity]
				local dry = if not counters
					then 0
					elseif rarity == "Legendary" then counters.legendaryDryRolls
					else counters.mythicalDryRolls
				text(
					body,
					`{rarity}: {dry} dry rolls · Boost after {curve.start} · +{curve.increment}% per dry roll · Guarantee at {curve.guarantee}`,
					nil,
					palette.muted
				)
			end
			text(
				body,
				"Each counter resets only when that exact rarity drops. Mythical takes priority if both are due. Shared groups share counters.",
				nil,
				palette.muted
			)
			button(body, "Pity counter: " .. pityRarity .. "  ›", function()
				pityRarity = if pityRarity == "Legendary" then "Mythical" else "Legendary"
				render()
			end)
			numeric(body, "Dry-roll progress (0–1,000,000)", pityValue, function(value)
				pityValue = value
			end)
			button(body, "Set pity progress…", function()
				local amount = finiteInteger(pityValue, 0, 1000000)
				if not amount then
					note("Enter a whole pity value from 0 to 1,000,000.")
					return
				end
				local request = command("SetPity")
				request.amount, request.collection, request.rarity = amount, collection, pityRarity
				sendRisk(
					request,
					`Set {pityRarity} dry rolls to {amount} for {collectionName(collection)}.`
				)
			end)
			button(body, "Reset both pity counters…", function()
				local request = command("ResetPity")
				request.collection = collection
				sendRisk(
					request,
					"Reset Legendary and Mythical counters for this box's pity group to zero."
				)
			end, true)
		else
			text(body, "This box has no implemented pity counters.", nil, palette.muted)
		end
		heading("One-opening overrides")
		if state.override then
			text(
				body,
				`ACTIVE · {collectionName(state.override.collection)} · {state.override.figure or state.override.rarity or ""}\nExpires automatically within five minutes; refresh for current status.`,
				nil,
				palette.danger
			)
			button(body, "Clear active override", function()
				run(command("ClearOverride"))
			end, true)
		else
			text(body, "No active override for this player.", nil, palette.muted)
		end
		text(
			body,
			"Applies to the first successful Buy, Open 10, daily Starter or Deal opening of the selected box. Quest/Login rewards are excluded. Normal price, quantity limits and pity updates still apply.",
			nil,
			palette.muted
		)
		button(body, "Force rarity: " .. forcedRarity .. "  ›", function()
			forcedRarity =
				Rarity.order[(table.find(Rarity.order, forcedRarity :: Rarity.Id) or 1) % #Rarity.order + 1]
			render()
		end)
		button(body, "Force next rarity…", function()
			local request = command("ForceRarity")
			request.collection, request.rarity = collection, forcedRarity
			sendRisk(
				request,
				`Force one {forcedRarity} figure from {collectionName(collection)} within five minutes.`
			)
		end)
		text(
			body,
			"Figure selected in Figures: " .. Catalog.byId[figureId].name,
			nil,
			palette.muted
		)
		button(body, "Force next selected figure…", function()
			if Catalog.byId[figureId].collection ~= collection then
				note("Select a figure from this box in Figures first.")
				return
			end
			local request = command("ForceFigure")
			request.collection, request.figure = collection, figureId
			sendRisk(
				request,
				`Force one {Catalog.byId[figureId].name} from this box within five minutes.`
			)
		end)
		heading("Distribution dry run")
		numeric(body, "Simulation rolls (1–1,000)", simulationValue, function(value)
			simulationValue = value
		end)
		button(body, "Simulate without spending or granting", function()
			local count = finiteInteger(simulationValue, 1, 1000)
			if not count then
				note("Enter a whole simulation count from 1 to 1,000.")
				return
			end
			local request = command("Simulate")
			request.collection, request.amount = collection, count
			request.revision = nil
			run(request)
		end)
		if reply.simulation then
			for _, rarity in Rarity.order do
				text(body, `{rarity}: {reply.simulation[rarity] or 0} rolls`, nil, palette.good)
			end
		end
		text(
			body,
			"Uses the actual weighted roll logic with a private copy of current pity, evolving after each simulated roll. It excludes overrides and does not write player state.",
			nil,
			palette.muted
		)
	end
	render = function()
		if not gui or not alive then
			return
		end
		local scroll = body.CanvasPosition
		pageScope.destroy()
		pageScope = Scope.create()
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		targetLabel.Text = "Target: " .. selected
		for _, row in playerRows() do
			if row.userId == selected then
				targetLabel.Text = `Target: @{row.username} · {row.userId}`
			end
		end
		for index, object in nav do
			object.BackgroundColor3 = if ({ "Players", "Economy", "Figures", "Boxes" })[index]
					== section
				then Color3.fromRGB(43, 59, 84)
				else palette.panel
		end
		button(
			body,
			if client.uncertain() then "Retry interrupted request" else "Refresh authoritative data",
			function()
				if client.uncertain() then
					run(nil)
				else
					refresh()
				end
			end
		)
		if client.uncertain() then
			text(
				body,
				"Request outcome is uncertain. Retry uses the exact same sequence so it cannot duplicate a grant.",
				nil,
				palette.danger
			)
			return
		end
		if section == "Players" then
			playersPage()
		elseif section == "Economy" then
			economyPage()
		elseif section == "Figures" then
			figuresPage()
		else
			boxesPage()
		end
		body.CanvasPosition = scroll
	end
	local function destroy()
		if not alive then
			return
		end
		if opened then
			focus(false)
		end
		alive, opened = false, false
		closeModal()
		pageScope.destroy()
		scope.destroy()
		if gui then
			gui:Destroy()
			gui = nil
		end
	end
	task.spawn(function()
		local connected = client.connect()
		for _ = 1, 2 do
			if connected.message ~= "Admin connection unavailable." or not alive then
				break
			end
			task.wait(1)
			if not alive then
				return
			end
			connected = client.connect()
		end
		if not alive or not connected.ok or not connected.token then
			return
		end
		reply = connected
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		if not alive then
			return
		end
		local old = playerGui:FindFirstChild("BlindBoxAdmin")
		if old then
			old:Destroy()
		end
		local root = Instance.new("ScreenGui")
		root.Name, root.ResetOnSpawn, root.DisplayOrder, root.ZIndexBehavior =
			"BlindBoxAdmin", false, 150, Enum.ZIndexBehavior.Sibling
		root.Parent = playerGui
		gui = root
		local entry = button(root, "Admin · F2", function()
			setOpen(not opened)
		end, false, scope)
		-- Clear the existing top-right Daily/Home/Plaza/settings row and phone goal chip.
		entry.AnchorPoint, entry.Position, entry.Size =
			Vector2.new(1, 0.5), UDim2.new(1, -16, 0.5, 0), UDim2.fromOffset(112, 44)
		local shade = Instance.new("TextButton")
		shade.Name, shade.Text, shade.AutoButtonColor, shade.Modal = "Overlay", "", false, true
		shade.BackgroundColor3, shade.BackgroundTransparency, shade.Size, shade.Visible =
			Color3.new(), 0.25, UDim2.fromScale(1, 1), false
		shade.Parent = root
		panel = Instance.new("Frame")
		panel.AnchorPoint, panel.Position, panel.Size =
			Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(1, -24, 1, -24)
		panel.BackgroundColor3, panel.Parent = palette.back, shade
		round(panel, 12)
		local size = Instance.new("UISizeConstraint")
		size.MaxSize = Vector2.new(1120, 840)
		size.Parent = panel
		local title = text(panel, "BLIND BOX  /  ADMIN CONTROL CENTER", 44, palette.text)
		title.Position, title.Size, title.Font =
			UDim2.fromOffset(16, 8), UDim2.new(1, -90, 0, 44), Enum.Font.GothamMedium
		local close = button(panel, "Close", function()
			setOpen(false)
		end, false, scope)
		close.AnchorPoint, close.Position, close.Size =
			Vector2.new(1, 0), UDim2.new(1, -8, 0, 8), UDim2.fromOffset(64, 44)
		targetLabel = text(panel, "", 32, palette.muted)
		targetLabel.Position, targetLabel.Size = UDim2.fromOffset(16, 54), UDim2.new(1, -32, 0, 32)
		status = text(panel, "Owner access · Current server only", 44, palette.muted)
		status.Position, status.Size, status.TextSize =
			UDim2.new(0, 16, 1, -52), UDim2.new(1, -32, 0, 44), 13
		sidebar = Instance.new("Frame")
		sidebar.BackgroundColor3, sidebar.Parent = palette.panel, panel
		round(sidebar, 8)
		for _, id in { "Players", "Economy", "Figures", "Boxes" } do
			table.insert(
				nav,
				button(sidebar, id, function()
					closeModal()
					section = id
					render()
					body.CanvasPosition = Vector2.zero
				end, false, scope)
			)
		end
		body = Instance.new("ScrollingFrame")
		body.Name, body.BackgroundTransparency, body.ScrollBarThickness = "Content", 1, 5
		body.AutomaticCanvasSize, body.CanvasSize, body.ScrollingDirection =
			Enum.AutomaticSize.Y, UDim2.new(), Enum.ScrollingDirection.Y
		body.Parent = panel
		padding(body, 8)
		stack(body, 10)
		local function layout()
			local narrow = panel.AbsoluteSize.X < 760
			if narrow then
				sidebar.Position, sidebar.Size = UDim2.fromOffset(12, 88), UDim2.new(1, -24, 0, 44)
				for index, object in nav do
					object.Position, object.Size =
						UDim2.new((index - 1) / 4, 2, 0, 0), UDim2.new(0.25, -4, 1, 0)
				end
				body.Position, body.Size = UDim2.fromOffset(8, 138), UDim2.new(1, -16, 1, -194)
			else
				sidebar.Position, sidebar.Size =
					UDim2.fromOffset(12, 94), UDim2.new(0, 142, 1, -154)
				for index, object in nav do
					object.Position, object.Size =
						UDim2.fromOffset(6, (index - 1) * 54 + 6), UDim2.new(1, -12, 0, 44)
				end
				body.Position, body.Size = UDim2.fromOffset(164, 88), UDim2.new(1, -176, 1, -144)
			end
		end
		setOpen = function(value)
			if value == opened or (value and (processing or not canOpen())) then
				return
			end
			if value then
				previousSelection = GuiService.SelectedObject
			end
			closeModal()
			local focusedBox = Input:GetFocusedTextBox()
			if focusedBox then
				focusedBox:ReleaseFocus()
			end
			opened, shade.Visible, entry.Visible = value, value, not value
			focus(value)
			if value then
				render()
				GuiService.SelectedObject = nav[1]
				refresh()
			else
				GuiService.SelectedObject = if previousSelection and previousSelection.Parent
					then previousSelection
					else nil
			end
		end
		-- Only consume gameplay shortcuts while this console owns focus. TextBoxes retain typing.
		Actions:BindActionAtPriority(
			"BlindBoxAdminInputs",
			function()
				return if opened
					then Enum.ContextActionResult.Sink
					else Enum.ContextActionResult.Pass
			end,
			false,
			3100,
			Enum.KeyCode.E,
			Enum.KeyCode.ButtonY,
			Enum.KeyCode.ButtonL1,
			Enum.KeyCode.ButtonR1
		)
		Actions:BindActionAtPriority("BlindBoxAdminToggle", function(_, state)
			if state == Enum.UserInputState.Begin and not Input:GetFocusedTextBox() then
				setOpen(not opened)
			end
			return Enum.ContextActionResult.Sink
		end, false, 3100, Enum.KeyCode.F2)
		Actions:BindActionAtPriority("BlindBoxAdminClose", function(_, state)
			if not opened then
				return Enum.ContextActionResult.Pass
			end
			if state == Enum.UserInputState.Begin then
				if root:FindFirstChild("Confirmation") then
					closeModal()
				else
					setOpen(false)
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, 3100, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
		scope.add(function()
			Actions:UnbindAction("BlindBoxAdminToggle")
			Actions:UnbindAction("BlindBoxAdminClose")
			Actions:UnbindAction("BlindBoxAdminInputs")
		end)
		scope.connect(GuiService:GetPropertyChangedSignal("SelectedObject"), function()
			local selectedObject = GuiService.SelectedObject
			if not opened or not selectedObject or not selectedObject:IsDescendantOf(root) then
				return
			end
			local ancestor = selectedObject.Parent
			while ancestor and ancestor ~= root do
				if ancestor:IsA("ScrollingFrame") then
					local top = selectedObject.AbsolutePosition.Y - ancestor.AbsolutePosition.Y
					local bottom = top + selectedObject.AbsoluteSize.Y
					local height = ancestor.AbsoluteWindowSize.Y
					local shift = if top < 4
						then top - 4
						elseif bottom > height - 4 then bottom - height + 4
						else 0
					ancestor.CanvasPosition = Vector2.new(
						0,
						math.clamp(
							ancestor.CanvasPosition.Y + shift,
							0,
							math.max(0, ancestor.AbsoluteCanvasSize.Y - height)
						)
					)
					break
				end
				ancestor = ancestor.Parent
			end
		end)
		scope.connect(panel:GetPropertyChangedSignal("AbsoluteSize"), layout)
		scope.connect(root.Destroying, destroy)
		scope.connect(Players.PlayerRemoving, function(raw: unknown)
			local player = raw :: Player
			if player.UserId == selected then
				inspector = nil
				note("Selected player left the server.")
				if opened then
					render()
				end
			end
		end)
		layout()
		render()
	end)
	return { destroy = destroy }
end
return Console
