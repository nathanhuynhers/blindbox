--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Catalog)
local Types = require(Shared.Types)
local FigureModel = require(Shared.FigureModel)
local Scroll = require(script.Parent.Scroll)
local W = require(script.Parent.Widgets)
local Interface = {}
function Interface.create(send: (string, string?, number?, string?) -> (), visit: (number) -> ())
	local connections: { RBXScriptConnection } = {}
	local cleanups: { () -> () } = {}
	local gui = Instance.new("ScreenGui")
	gui.Name = "PocketGrove"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local bounds = Instance.new("Frame")
	bounds.Name = "SafeArea"
	bounds.Size = UDim2.fromScale(1, 1)
	bounds.BackgroundTransparency = 1
	bounds.Parent = gui
	local hud = Instance.new("Frame")
	hud.Name = "Hud"
	hud.BackgroundColor3 = Color3.fromRGB(22, 38, 43)
	hud.Position = UDim2.fromOffset(12, 8)
	hud.Size = UDim2.new(1, -24, 0, 84)
	hud.Parent = bounds
	W.corner(hud, 12)
	local title = W.label(hud, "POCKET GROVE", 24)
	title.Position = UDim2.fromOffset(12, 4)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(250, 220, 154)
	local balance = W.label(hud, "Opening your showroom...", 30)
	balance.TextSize = 14
	balance.Position = UDim2.fromOffset(12, 27)
	balance.Size = UDim2.new(1, -24, 0, 30)
	local save = W.label(hud, "Loading progress", 20)
	save.Position = UDim2.fromOffset(12, 57)
	save.TextSize = 12
	local panel = Instance.new("Frame")
	panel.Name = "Menu"
	panel.Position = UDim2.fromOffset(12, 104)
	panel.BackgroundColor3 = Color3.fromRGB(25, 42, 47)
	panel.Parent = bounds
	W.corner(panel, 12)
	local nav = Instance.new("Frame")
	nav.Size = UDim2.new(1, -16, 0, 48)
	nav.Position = UDim2.fromOffset(8, 8)
	nav.BackgroundTransparency = 1
	nav.Parent = panel
	local pages: { [string]: ScrollingFrame } = {}
	local tabs: { [string]: TextButton } = {}
	local orders: { [Instance]: number } = {}
	local function tab(name: string)
		for key, page in pages do
			page.Visible = key == name
			tabs[key].BackgroundColor3 = if key == name
				then Color3.fromRGB(125, 101, 53)
				else Color3.fromRGB(53, 90, 88)
		end
	end
	local function connect(button: TextButton, callback: () -> ())
		table.insert(connections, button.Activated:Connect(callback))
	end
	for index, name in { "Collection", "Display", "Shop", "Goals", "Visits" } do
		local button = W.button(nav, name)
		button.TextSize = 12
		button.Size = UDim2.new(0.2, -4, 1, 0)
		button.Position = UDim2.fromScale((index - 1) * 0.2, 0)
		tabs[name] = button
		connect(button, function()
			tab(name)
		end)
		local page = Instance.new("ScrollingFrame")
		page.Name = name
		page.Size = UDim2.new(1, -16, 1, -72)
		page.Position = UDim2.fromOffset(8, 64)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 7
		page.Parent = panel
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 12)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = page
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = page
		table.insert(cleanups, Scroll.bind(page, layout, 8))
		pages[name] = page
		orders[page] = 0
	end
	local function label(page: string, text: string, height: number): TextLabel
		local parent = pages[page]
		orders[parent] += 1
		local result = W.label(parent, text, height)
		result.LayoutOrder = orders[parent]
		return result
	end
	local function button(page: string, text: string, callback: () -> ()): TextButton
		local parent = pages[page]
		orders[parent] += 1
		local result = W.button(parent, text)
		result.LayoutOrder = orders[parent]
		connect(result, callback)
		return result
	end
	local toggle = W.button(bounds, "Hide menu")
	toggle.Size = UDim2.fromOffset(116, 32)
	toggle.Position = UDim2.new(1, -136, 0, 12)
	toggle.TextSize = 13
	connect(toggle, function()
		panel.Visible = not panel.Visible
		toggle.Text = if panel.Visible then "Hide menu" else "Show menu"
	end)
	local toast = W.label(bounds, "Open Shop for your first box, or claim a free box in Goals.", 44)
	toast.BackgroundColor3 = Color3.fromRGB(30, 48, 49)
	toast.BackgroundTransparency = 0.1
	toast.Position = UDim2.new(0, 12, 1, -50)
	toast.Size = UDim2.new(1, -24, 0, 42)
	toast.TextSize = 14
	toast.ZIndex = 5
	W.corner(toast, 8)
	local function resize()
		local viewport = bounds.AbsoluteSize
		panel.Size = UDim2.fromOffset(
			math.min(520, math.max(200, viewport.X - 24)),
			math.max(130, viewport.Y - 170)
		)
	end
	table.insert(connections, bounds:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()
	local state: Types.Snapshot? = nil
	local selected = Catalog.figures[1].id
	local collection = "grove"
	local filterOwned = false
	local cards: { [string]: TextButton } = {}
	local cardLabels: { [string]: TextLabel } = {}
	local portraits: { [string]: { [BasePart]: Color3 } } = {}
	local collectionStatus = label("Collection", "Your collection", 36)
	local selectedLabel = label("Collection", "Select a figure to place, recycle, or redeem.", 44)
	local displaySelection = label("Display", "Choose a figure in Collection first.", 44)
	local function selectFigure(id: string)
		selected = id
		local name = Catalog.byId[id].name
		selectedLabel.Text = "Selected: " .. name
		displaySelection.Text = "Place: " .. name
		for key, card in cards do
			card.BackgroundColor3 = if key == id
				then Color3.fromRGB(117, 96, 56)
				else Color3.fromRGB(53, 90, 88)
		end
	end
	local function refreshCards()
		local snapshot = state
		for index, figure in Catalog.figures do
			local owned = if snapshot then snapshot.owned[figure.id] or 0 else 0
			cards[figure.id].Visible = figure.collection == collection
				and (not filterOwned or owned > 0)
			cards[figure.id].LayoutOrder = 100 + index
		end
	end
	for _, definition in Catalog.collections do
		button("Collection", definition.name, function()
			collection = definition.id
			refreshCards()
		end)
	end
	local ownedFilter: TextButton? = nil
	ownedFilter = button("Collection", "Showing all figures", function()
		filterOwned = not filterOwned
		if ownedFilter then
			ownedFilter.Text = if filterOwned
				then "Showing owned figures - tap for all"
				else "Showing all figures"
		end
		refreshCards()
	end)
	button("Collection", "Place selected on display", function()
		tab("Display")
	end)
	button("Collection", "Recycle selected extra for 1 Scrap", function()
		send("Recycle", selected, nil, nil)
	end)
	local redeem = button("Collection", "Redeem selected for 6 Scrap", function()
		send("Redeem", selected, nil, nil)
	end)
	label(
		"Collection",
		"Recycling keeps your last copy and never consumes a displayed copy. Redemption can unlock an undiscovered figure.",
		66
	)
	for _, definition in Catalog.figures do
		local card = button("Collection", "", function()
			selectFigure(definition.id)
		end)
		card.Name = definition.id
		card.Size = UDim2.new(1, 0, 0, 116)
		cards[definition.id] = card
		local text = W.label(card, "", 108)
		text.Size = UDim2.new(1, -96, 1, -8)
		text.Position = UDim2.fromOffset(88, 4)
		text.TextSize = 14
		cardLabels[definition.id] = text
		local model = FigureModel.create(definition.id, CFrame.new())
		local portrait = W.portrait(card, model)
		portrait.Size = UDim2.fromOffset(82, 108)
		local colors: { [BasePart]: Color3 } = {}
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				colors[part] = part.Color
				part.Color = Color3.fromRGB(17, 24, 30)
			end
		end
		portraits[definition.id] = colors
	end
	local prompt = label("Display", "", 54)
	label(
		"Display",
		"Three distinct figures from one collection add +1 Coin/sec. Only displayed copies earn. Edit near your own shelf.",
		70
	)
	local slots: { TextButton } = {}
	local removals: { TextButton } = {}
	for slot = 1, 4 do
		slots[slot] = button("Display", "Slot " .. slot, function()
			if state and slot > state.unlocked then
				tab("Shop")
			else
				send("Place", selected, slot, nil)
			end
		end)
		removals[slot] = button("Display", "Remove slot " .. slot, function()
			send("Remove", nil, slot, nil)
		end)
	end
	button("Display", "Return to my showroom", function()
		visit(0)
	end)
	label("Shop", "Open a box", 32).Font = Enum.Font.GothamBold
	label(
		"Shop",
		"Each box contains one figure. Odds per figure: Common 20% each, Uncommon 15% each, Rare 10%. Duplicates recycle for 1 Scrap.",
		82
	)
	local boxes: { [string]: TextButton } = {}
	for _, definition in Catalog.collections do
		boxes[definition.id] = button("Shop", definition.name .. " box - 150 Coins", function()
			send("Buy", nil, nil, definition.id)
		end)
	end
	local expansion = button("Shop", "Fourth display slot - 4,000 Coins", function()
		send("Expand", nil, nil, nil)
	end)
	label("Shop", "Room palettes - own forever, switch freely", 42)
	local themeButtons: { [string]: TextButton } = {}
	for _, id in { "grove", "dusk", "ocean" } do
		themeButtons[id] = button("Shop", Catalog.themes[id].name, function()
			send("Theme", nil, nil, id)
		end)
	end
	local effects = true
	local effectsButton: TextButton? = nil
	effectsButton = button("Shop", "Motion effects: on", function()
		effects = not effects
		if effectsButton then
			effectsButton.Text = if effects then "Motion effects: on" else "Motion effects: reduced"
		end
	end)
	local dailyStatus = label("Goals", "Daily rewards", 52)
	for _, definition in Catalog.collections do
		button("Goals", "Free daily " .. definition.name .. " box", function()
			send("Daily", nil, nil, definition.id)
		end)
	end
	label("Goals", "Choose one free box per UTC day. No streaks or penalties for missing days.", 52)
	local goal = button("Goals", "Display 3 distinct figures - claim 100 Coins", function()
		send("Goal", nil, nil, nil)
	end)
	local achievements = label("Goals", "Complete a collection to earn its showroom plaque.", 100)
	label("Visits", "Visit this server's showrooms", 36).Font = Enum.Font.GothamBold
	button("Visits", "Return home", function()
		visit(0)
	end)
	label(
		"Visits",
		"Inspect public displays below. Your inventory and Coins stay private; guests cannot change your room.",
		68
	)
	local visitButtons: { TextButton } = {}
	local targets: { number } = {}
	for index = 1, 24 do
		visitButtons[index] = button("Visits", "", function()
			local target = targets[index]
			if target then
				visit(target)
			end
		end)
		visitButtons[index].Size = UDim2.new(1, 0, 0, 100)
		visitButtons[index].Visible = false
	end
	local reveal = Instance.new("TextButton")
	reveal.Size = UDim2.fromScale(0.84, 0.72)
	reveal.Position = UDim2.fromScale(0.08, 0.12)
	reveal.BackgroundColor3 = Color3.fromRGB(26, 42, 53)
	reveal.Text = ""
	reveal.Visible = false
	reveal.ZIndex = 20
	reveal.Parent = bounds
	W.corner(reveal, 18)
	local revealText = W.label(reveal, "", 120)
	revealText.Size = UDim2.fromScale(0.94, 0.4)
	revealText.Position = UDim2.fromScale(0.03, 0.58)
	revealText.TextXAlignment = Enum.TextXAlignment.Center
	revealText.TextSize = 20
	revealText.ZIndex = 22
	local revealed: ViewportFrame? = nil
	local revealUntil = 0
	connect(reveal, function()
		reveal.Visible = false
	end)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DisplayRate"
	billboard.Size = UDim2.fromOffset(250, 48)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Parent = gui
	local rateLabel = W.label(billboard, "", 48)
	rateLabel.BackgroundColor3 = Color3.fromRGB(25, 42, 47)
	rateLabel.BackgroundTransparency = 0.15
	rateLabel.TextXAlignment = Enum.TextXAlignment.Center
	local function update(snapshot: Types.Snapshot)
		state = snapshot
		redeem.Text = "Redeem selected for " .. snapshot.redeemCost .. " Scrap"
		for _, definition in Catalog.collections do
			boxes[definition.id].Text = definition.name .. " box - " .. snapshot.price .. " Coins"
		end
		balance.Text = string.format(
			"%d Coins   |   %d Scrap   |   %g Coins/sec",
			snapshot.coins,
			snapshot.scrap,
			snapshot.rate
		)
		save.Text = snapshot.saveStatus
		if not snapshot.ready then
			toast.Text = snapshot.saveStatus
		end
		local found, total = 0, 0
		local completion: { string } = {}
		for _, definition in Catalog.collections do
			local count = 0
			for _, figure in Catalog.figures do
				if figure.collection == definition.id then
					if snapshot.discovered[figure.id] then
						count += 1
					end
					if definition.id == collection then
						total += 1
						if snapshot.discovered[figure.id] then
							found += 1
						end
					end
				end
			end
			table.insert(
				completion,
				definition.name
					.. ": "
					.. count
					.. " / 6"
					.. (if count == 6 then " - PLAQUE EARNED" else "")
			)
		end
		collectionStatus.Text =
			string.format("Discoveries: %d / %d in this collection", found, total)
		achievements.Text = table.concat(completion, "\n")
		for _, figure in Catalog.figures do
			local id = figure.id
			local owned = snapshot.owned[id] or 0
			local available = owned
			for _, placed in snapshot.slots do
				if placed == id then
					available -= 1
				end
			end
			for part, color in portraits[id] do
				part.Color = if snapshot.discovered[id] then color else Color3.fromRGB(17, 24, 30)
			end
			cardLabels[id].Text = string.format(
				"%s\n%s | %g Coins/sec\nOwned %d / free %d | %g%% odds",
				if snapshot.discovered[id] then figure.name else "Undiscovered",
				figure.rarity,
				snapshot.rates[id],
				owned,
				available,
				snapshot.odds[id]
			)
		end
		refreshCards()
		for slot = 1, 4 do
			local id = snapshot.slots[slot] or ""
			slots[slot].Text = if slot > snapshot.unlocked
				then "Slot 4 locked - unlock in Shop"
				else string.format(
					"Slot %d: %s - place selected",
					slot,
					if id == "" then "Empty" else Catalog.byId[id].name
				)
			removals[slot].Visible = slot <= snapshot.unlocked and id ~= ""
		end
		local prompts = {
			"Open your first box in Shop, or claim a free box in Goals!",
			"Place your new figure in a display slot.",
			"Income is automatic. Fill your other slots!",
			"Use your growing balance for another box.",
			"Collect, upgrade your display, and make this showroom yours.",
		}
		prompt.Text = prompts[snapshot.step]
			.. string.format("\nThemed display bonus: +%g/sec", snapshot.bonus)
		expansion.Text = if snapshot.unlocked == 4
			then "Showroom fully expanded"
			else "Fourth display slot - " .. snapshot.expansionCost .. " Coins"
		for id, buttonObject in themeButtons do
			buttonObject.Text = Catalog.themes[id].name
				.. (
					if snapshot.theme == id
						then " - equipped"
						elseif snapshot.themes[id] then " - equip"
						else " - " .. snapshot.themeCost .. " Coins"
				)
		end
		dailyStatus.Text = if snapshot.dailyReady
			then "Your free daily box is ready!"
			else "Daily box claimed. Resets at 00:00 UTC."
		goal.Text = if snapshot.goalClaimed
			then "Daily display goal claimed"
			else string.format(
				"Display goal %d/3 - claim %d Coins",
				snapshot.goalProgress,
				snapshot.goalReward
			)
		for index, buttonObject in visitButtons do
			local room = snapshot.rooms[index]
			buttonObject.Visible = room ~= nil
			if room then
				targets[index] = room.userId
				local names: { string } = {}
				for _, id in room.slots do
					if id ~= "" then
						table.insert(names, Catalog.byId[id].name)
					end
				end
				buttonObject.Text = room.name
					.. " | "
					.. room.rate
					.. " Coins/sec\n"
					.. (if #names > 0
						then table.concat(names, ", ")
						else "An empty shelf waiting for its first figure")
					.. "\nVisit showroom"
			else
				targets[index] = nil
			end
		end
		local rooms = workspace:FindFirstChild("Showrooms")
		local room = if rooms then rooms:FindFirstChild(tostring(snapshot.visiting)) else nil
		local shelf = if room then room:FindFirstChild("Shelf") else nil
		if shelf and shelf:IsA("BasePart") then
			billboard.Adornee = shelf
			billboard.Enabled = true
		else
			billboard.Enabled = false
		end
		local displayedRate = snapshot.rate
		for _, public in snapshot.rooms do
			if public.userId == snapshot.visiting then
				displayedRate = public.rate
			end
		end
		rateLabel.Text = string.format("Display income: %g Coins/sec", displayedRate)
	end
	tab("Collection")
	selectFigure(selected)
	refreshCards()
	return {
		update = update,
		message = function(text: string)
			toast.Text = text
		end,
		effects = function(): boolean
			return effects
		end,
		reveal = function(id: string, text: string)
			selectFigure(id)
			collection = Catalog.byId[id].collection
			refreshCards()
			if revealed then
				revealed:Destroy()
			end
			revealed = W.portrait(reveal, FigureModel.create(id, CFrame.new()))
			if revealed then
				revealed.Size = UDim2.fromScale(1, 0.62)
				revealed.ZIndex = 21
			end
			local snapshot = state
			revealText.Text = text
				.. "\n"
				.. Catalog.byId[id].name
				.. " - "
				.. Catalog.byId[id].rarity
				.. "\n"
				.. tostring(if snapshot then snapshot.rates[id] else 0)
				.. " Coins/sec\nTap to continue"
			reveal.Visible = true
			revealUntil = os.clock() + (if effects then 3 else 1)
		end,
		tick = function()
			if reveal.Visible and os.clock() >= revealUntil then
				reveal.Visible = false
			end
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			for _, cleanup in cleanups do
				cleanup()
			end
			gui:Destroy()
		end,
	}
end
return Interface
