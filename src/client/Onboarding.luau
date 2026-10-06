--!strict
-- Welcome Quest guidance over the real first loop: Welcome Box -> Display -> collect -> buy a
-- box -> free x10, then an optional Shelves tip. The server owns progress (snapshot.step) and
-- advances it only from the action each stage teaches, so wallet changes, screen visits and
-- other rewards never complete a step. This module only picks the one control to point at and
-- the words to say. It never sends gameplay intents or blocks input; Skip (tapped twice) asks
-- the server to hide guidance for good, and the rewards stay claimable from the Shop.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Tweens = game:GetService("TweenService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local ShelfConfig = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Tutorial = require(game:GetService("ReplicatedStorage").Shared.Tutorial)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Layout = require(script.Parent.UILayout)
local Scope = require(script.Parent.UIScope)
local State = require(script.Parent.UIState)
local Sfx = require(script.Parent.Sfx)
local Onboarding = {}

-- Dock tiles by page id, or one control inside the open screen.
export type Target =
	"Shop"
	| "Display"
	| "Shelves"
	| "WelcomeGift"
	| "BuyBox"
	| "Pick"
	| "Spot"
	| "Close"
export type Guide = {
	step: number,
	text: string,
	target: Target?,
	-- Short call to action pinned on an in-screen target (and all a phone sheet shows).
	badge: string?,
	-- Pick: the figure to put on Display. Spot: the empty Shelf spot to tap.
	figure: string?,
	spot: number?,
	-- Point at the displayed figure in the world.
	world: boolean,
}
export type Onboarding = {
	update: (Types.Snapshot, string?, boolean) -> (),
	layout: (Layout.Frame, boolean) -> (),
	guide: () -> Guide?,
}
local docked: { [string]: boolean } = { Shop = true, Display = true, Shelves = true }
local questSteps = Tutorial.buy -- Welcome Box, Display, collect, buy.

local function displayedSlot(state: Types.Snapshot): number?
	for slot = 1, state.unlocked do
		local id = state.slots[slot]
		if id and id ~= "" then
			return slot
		end
	end
	return nil
end

-- The best-earning owned figure that is not on Display yet.
local function unplaced(state: Types.Snapshot): string?
	local best: string?, rate = nil, -1
	for id in state.owned do
		local value = State.figureRate(state, id)
		if
			not table.find(state.slots, id)
			and (value > rate or (value == rate and id < (best or id)))
		then
			best, rate = id, value
		end
	end
	return best
end

local function cheapest(state: Types.Snapshot): number
	local price = math.huge
	for _, collection in Catalog.collections do
		local value = State.price(state, collection.id)
		if value > 0 then
			price = math.min(price, value)
		end
	end
	return price
end

local function emptySpot(state: Types.Snapshot): number
	local unit = state.shelves.visible[1]
	for index, key in ShelfConfig.slots() do
		if not unit or not unit.placements[key] then
			return index
		end
	end
	return 1
end

-- Pure: what the quest says and points at for this snapshot and open page (nil: no guidance).
function Onboarding.guide(state: Types.Snapshot, page: string?, touch: boolean): Guide?
	local step = state.step
	if not state.ready or state.tutorialHidden or step >= Tutorial.done then
		return nil
	end
	local function make(text: string, target: Target?, badge: string?): Guide
		return { step = step, text = text, target = target, badge = badge, world = false }
	end
	local displayed = displayedSlot(state) ~= nil
	if step == Tutorial.welcome then
		return if page == "Shop"
			then make("Open your free Welcome Box!", "WelcomeGift", "FREE!")
			else make("This plot is yours! Open your free Welcome Box", "Shop")
	elseif step == Tutorial.display or (step == Tutorial.collect and not displayed) then
		if page == "Display" then
			local guide = make("Pick your figure to put it on Display", "Pick", "Display it!")
			guide.figure = unplaced(state)
			if not guide.figure then
				guide.target, guide.badge = nil, nil
			end
			return guide
		end
		return make("Put your figure on Display to earn Coins", "Display")
	elseif step == Tutorial.collect or (step == Tutorial.buy and state.coins < cheapest(state)) then
		local verb = if touch then "Tap" else "Click"
		local guide = if step == Tutorial.collect
			then make(
				"Step on its plate or " .. verb .. " your figure to collect its Coins!",
				if page then "Close" else nil,
				"Close"
			)
			else make(
				"Collect more Coins from your Display",
				if page then "Close" else nil,
				"Close"
			)
		guide.world = displayed
		return guide
	elseif step == Tutorial.buy then
		return if page == "Shop"
			then make("Spend your Coins: open another box!", "BuyBox", "Use your Coins!")
			else make("Figures earn Coins. Coins open more boxes!", "Shop")
	elseif step == Tutorial.reward then
		return if page == "Shop"
			then make("Open your FREE ×10!", "WelcomeGift", "FREE ×10!")
			else make("Quest complete! Your FREE ×10 is in the Shop", "Shop")
	end
	-- Optional tip after the x10: done once a figure is actually placed on a Shelf.
	if page == "Shelves" then
		local guide = make("Tap a spot, then pick a figure to show off", "Spot", "Pick a spot!")
		guide.spot = emptySpot(state)
		return guide
	end
	return make("Show off your favorites on your Shelves!", "Shelves")
end

local function touch(): boolean
	return Input.TouchEnabled and not Input.MouseEnabled
end

local function ownPlot(): Instance?
	local plots = workspace:FindFirstChild("PlayerPlots")
	local plot = if plots then plots:FindFirstChild(tostring(Players.LocalPlayer.UserId)) else nil
	return if plot and plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then plot else nil
end

local function ownCollector(plot: Instance, slot: number): BasePart?
	local folder = plot:FindFirstChild("FigureCollectors")
	local target = if folder then folder:FindFirstChild(tostring(slot)) else nil
	return if target and target:IsA("BasePart") then target else nil
end

local function ownFigure(plot: Instance, slot: number): Instance?
	local folder = plot:FindFirstChild("DisplayFigures")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		-- FigureSlots tags Display figures with their slot key as a string.
		if tostring(child:GetAttribute("SlotId")) == tostring(slot) then
			return child
		end
	end
	return nil
end

local function loop(object: Instance, seconds: number, goal: { [string]: any })
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	Tweens:Create(object, info, goal):Play()
end

-- A chunky downward arrow (rounded stem + chevron head) in the game's sticker style. Each
-- layer repeats the same three rounded bars: a hard drop shadow, an ink copy drawn larger as
-- the outline, then the gold fill, so the strokes join without seams.
local function pointer(parent: Instance, name: string, width: number): Frame
	local root = Kit.frame(parent, name)
	root.AnchorPoint = Vector2.new(0.5, 1)
	local height = math.floor(width * 1.3)
	root.Size = UDim2.fromOffset(width, height)
	root.Interactable = false
	local thick = math.floor(width * 0.3)
	local edge = math.max(Style.outlineSmall, math.floor(width * 0.07))
	local joint = height - thick / 2 - edge - 3 -- leaves room for the shadow below the tip
	local top = thick / 2 + edge
	local reach = (width / 2 - thick / 2 - edge) / math.cos(math.pi / 4) -- arm length
	local lift = reach * math.cos(math.pi / 4) / 2
	local bars = {
		{ x = width / 2, y = (top + joint) / 2, length = joint - top, rotation = 90 },
		{ x = width / 2 - lift, y = joint - lift, length = reach, rotation = 45 },
		{ x = width / 2 + lift, y = joint - lift, length = reach, rotation = -45 },
	}
	local layers = {
		{ name = "Shadow", color = Style.ink, grow = edge, drop = 3 },
		{ name = "Outline", color = Style.ink, grow = edge, drop = 0 },
		{ name = "Fill", color = Style.gold, grow = 0, drop = 0 },
	}
	for z, layer in layers do
		for _, bar in bars do
			local piece = Kit.frame(root, layer.name, layer.color)
			piece.AnchorPoint = Vector2.new(0.5, 0.5)
			piece.Position = UDim2.fromOffset(bar.x, bar.y + layer.drop)
			piece.Size =
				UDim2.fromOffset(bar.length + thick + layer.grow * 2, thick + layer.grow * 2)
			piece.Rotation = bar.rotation
			piece.ZIndex = z
			Kit.round(piece)
		end
	end
	return root
end

function Onboarding.create(
	stage: Instance,
	scope: Scope.Scope,
	tiles: { [string]: TextButton },
	hosts: { [string]: Frame },
	send: (string) -> ()
): Onboarding
	local current: Guide? = nil
	local page: string? = nil
	local focused = false
	local hideCard, dockHidden = false, false
	local last: Types.Snapshot? = nil
	local shownStep: number? = nil

	-- Quest card: caption + progress pips, the one current action, the x10 reward, Skip.
	local card = Kit.card(stage, "Onboarding", Style.white, 16, 4)
	card.root.ZIndex = 40
	card.root.Visible = false
	card.stroke.Color = Style.gold
	local pop = Instance.new("UIScale")
	pop.Parent = card.root
	local caption =
		Kit.text(card.face, "Caption", "", 12, Style.body(Enum.FontWeight.ExtraBold), Style.violet)
	local pips: { Frame } = {}
	for index = 1, questSteps do
		local pip = Kit.frame(card.face, "Pip" .. index, Style.track)
		Kit.round(pip)
		pips[index] = pip
	end
	local text = Kit.text(card.face, "Hint", "", 17, Style.display())
	text.TextWrapped = true
	text.TextTruncate = Enum.TextTruncate.None
	local reward = Kit.frame(card.face, "Reward", Style.gold)
	Kit.round(reward)
	Kit.stroke(reward, Style.ink, Style.outlineSmall)
	local rewardIcon = Icons.create(reward, "Gift", Style.ink, 16)
	local rewardText =
		Kit.text(reward, "RewardText", "FREE ×10", 13, Style.body(Enum.FontWeight.ExtraBold))
	local skipButton = Instance.new("TextButton")
	skipButton.Name = "SkipTutorial"
	skipButton.BackgroundColor3 = Style.surface2
	skipButton.FontFace = Style.display()
	skipButton.TextColor3 = Style.muted
	skipButton.TextSize = 15
	skipButton.Text = "Skip"
	skipButton.Parent = card.face
	Kit.corner(skipButton, 10)

	-- Pulsing gold ring re-parented onto the one control the step is about. Dock tiles get a
	-- bobbing pointer above while no screen is open; controls inside a screen get a badge on their own corner instead,
	-- so nothing floats over a neighbouring button.
	local ring = Instance.new("Frame")
	ring.Name = "OnboardingRing"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, 12, 1, 12)
	ring.ZIndex = 5
	ring.Interactable = false
	Kit.corner(ring, 22)
	local ringStroke = Kit.stroke(ring, Style.gold, 4)
	loop(ring, 0.6, { Size = UDim2.new(1, 22, 1, 22) })
	loop(ringStroke, 0.6, { Transparency = 0.5 })
	local arrow = pointer(ring, "Pointer", 36)
	arrow.Position = UDim2.new(0.5, 0, 0, -10)
	loop(arrow, 0.5, { Position = UDim2.new(0.5, 0, 0, -22) })
	local badge = Kit.frame(ring, "Callout", Style.gold)
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, -8, 0, 4)
	badge.Size = UDim2.fromOffset(0, 26)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.ZIndex = 6
	Kit.round(badge)
	Kit.stroke(badge, Style.ink, Style.outlineSmall)
	Kit.padding(badge, 0, 10, 0, 10)
	local badgeText = Kit.text(badge, "Text", "", 14, Style.display())
	badgeText.AutomaticSize = Enum.AutomaticSize.X
	badgeText.Size = UDim2.fromScale(0, 1)
	badgeText.ZIndex = 7

	-- World pointer and glow on the displayed figure (owner-only, local).
	local world = Instance.new("BillboardGui")
	world.Name = "OnboardingCollect"
	world.Size = UDim2.fromOffset(160, 120)
	-- Just above the figure's coin counter (DisplayEarnings sits at 3.9 studs).
	world.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	world.AlwaysOnTop = true
	world.LightInfluence = 0
	world.ResetOnSpawn = false
	world.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	world.Enabled = false
	local worldArrow = pointer(world, "Pointer", 44)
	worldArrow.Position = UDim2.new(0.5, 0, 1, -14)
	loop(worldArrow, 0.5, { Position = UDim2.fromScale(0.5, 1) })
	local worldText = Kit.text(world, "TapLabel", "", 22, Style.display(), Style.white)
	worldText.TextXAlignment = Enum.TextXAlignment.Center
	Kit.rect(worldText, 0, 0, 160, 30)
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness = Style.ink, 2
	outline.Parent = worldText
	world.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local glow: Highlight? = nil
	local function highlight(model: Instance?)
		local existing = glow
		if existing and (existing.Adornee ~= model or existing.Parent == nil) then
			existing:Destroy()
			glow = nil
		end
		if model and not glow then
			local made = Instance.new("Highlight")
			made.Name = "OnboardingGlow"
			made.FillColor, made.FillTransparency = Style.gold, 0.8
			made.OutlineColor, made.OutlineTransparency = Style.gold, 0
			made.DepthMode = Enum.HighlightDepthMode.Occluded
			made.Adornee = model
			made.Parent = model
			glow = made
		end
	end

	local armed: thread? = nil
	local skipped, skipSent = false, -math.huge
	scope.add(function()
		if armed then
			task.cancel(armed)
		end
		highlight(nil)
		ring:Destroy()
		world:Destroy()
		card.root:Destroy()
	end)

	local function closeButton(open: string?): GuiObject?
		local host = if open then hosts[open] else nil
		local close = if host then host:FindFirstChild("Close", true) else nil
		return if close and close:IsA("GuiObject") then close else nil
	end
	local function find(host: Frame?, name: string?): GuiObject?
		local found = if host and name then host:FindFirstChild(name, true) else nil
		return if found and found:IsA("GuiObject") and found.Visible then found else nil
	end
	-- The control the guide points at right now, and the badge to pin on it.
	local function resolve(guide: Guide): (GuiObject?, string?)
		local target = guide.target
		if not target then
			return nil, nil
		elseif docked[target] then
			if page == target then
				return nil, nil
			elseif page and dockHidden then
				-- A phone sheet covers the dock: the next step starts by closing it.
				return closeButton(page), "Close"
			end
			return tiles[target], nil
		elseif target == "Close" then
			return closeButton(page), guide.badge
		elseif target == "Pick" then
			return find(hosts.Display, guide.figure), guide.badge
		elseif target == "Spot" then
			return find(hosts.Shelves, "Spot" .. (guide.spot or 1)), guide.badge
		end
		return find(hosts.Shop, target), guide.badge
	end

	local function render()
		local guide = if skipped then nil else current
		local active = guide ~= nil and not focused
		card.root.Visible = active and not hideCard
		local target, label = nil, nil
		if active and guide then
			target, label = resolve(guide)
			local step = guide.step
			local quest = step <= questSteps
			caption.Text = if quest
				then "WELCOME QUEST"
				elseif step == Tutorial.reward then "WELCOME QUEST COMPLETE!"
				else "TIP"
			for index, pip in pips do
				pip.Visible = step <= Tutorial.reward
				pip.BackgroundColor3 = if index < step
					then Style.mint
					elseif index == step then Style.gold
					else Style.track
			end
			reward.Visible = quest
			text.Text = guide.text
		end
		ring.Parent = target
		-- An open desktop panel ends just above the dock, so the arrow would cover its buttons.
		arrow.Visible = target ~= nil and label == nil and page == nil
		badge.Visible = label ~= nil
		badgeText.Text = label or ""
		local plot = if active and guide and guide.world and page == nil then ownPlot() else nil
		local slot = if plot and last then displayedSlot(last) else nil
		local collector = if plot and slot then ownCollector(plot, slot) else nil
		if collector then
			world.Adornee = collector -- A lost target just disables the pointer below.
		end
		world.Enabled = collector ~= nil
		worldText.Text = "Step on its plate!"
		highlight(if collector and plot and slot then ownFigure(plot, slot) else nil)
	end

	local function skip()
		if armed then
			-- Second tap inside the window: hide guidance now; the server makes it stick.
			task.cancel(armed)
			armed = nil
			skipped = true
			skipSent = os.clock()
			send("SkipTutorial")
			render()
			return
		end
		skipButton.Text = "Sure?"
		armed = task.delay(3, function()
			armed = nil
			skipButton.Text = "Skip"
		end)
	end
	scope.connect(skipButton.Activated, skip)

	return {
		guide = function()
			return if skipped then nil else current
		end,
		update = function(state: Types.Snapshot, open: string?, isFocused: boolean)
			last, page, focused = state, open, isFocused
			current = Onboarding.guide(state, open, touch())
			-- A completed step gets a little chime and card pop as the next one appears.
			local step = if current then current.step else nil
			if step and shownStep and step > shownStep and not skipped then
				Sfx.play("goalReady")
				pop.Scale = 1.08
				Tweens:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
			shownStep = step or shownStep
			-- Retry an unconfirmed skip (a request may have been dropped while busy).
			if
				skipped
				and state.ready
				and not state.tutorialHidden
				and state.step < Tutorial.done
				and os.clock() - skipSent > 3
			then
				skipSent = os.clock()
				send("SkipTutorial")
			end
			render()
		end,
		layout = function(geometry: Layout.Frame, opened: boolean)
			-- Phone sheets cover the top band; the ring and its badge guide inside the screen.
			hideCard = geometry.phone and opened
			dockHidden = opened and not geometry.dockWhileOpen
			local width = math.min(500, geometry.width - 32)
			local height = if geometry.phone then 56 else 64
			local y = if geometry.phone
				then geometry.hud.y + geometry.hud.height + 8
				else geometry.hud.y
			Kit.rect(card.root, math.floor((geometry.width - width) / 2), y, width, height)
			Kit.rect(caption, 14, 6, 112, 16)
			for index, pip in pips do
				Kit.rect(pip, 128 + (index - 1) * 14, 9, 10, 10)
			end
			local skipWidth, rewardWidth = 64, 100
			Kit.rect(skipButton, width - skipWidth - 8, (height - 44) / 2, skipWidth, 44)
			Kit.rect(
				reward,
				width - skipWidth - rewardWidth - 16,
				(height - 30) / 2,
				rewardWidth,
				30
			)
			Kit.rect(rewardIcon, 8, 7, 16, 16)
			Kit.rect(rewardText, 28, 0, rewardWidth - 34, 30)
			Kit.rect(text, 14, 22, width - 14 - skipWidth - rewardWidth - 28, height - 26)
			text.TextSize = if geometry.phone then 15 else 17
			render()
		end,
	}
end

return Onboarding
