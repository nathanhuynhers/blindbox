--!strict
-- First-session hints over the existing loop: free box -> Display -> collect -> Shelves -> buy.
-- Session-only presentation: it reads snapshots and the open page, never sends intents, and
-- never blocks input. Players who already own a figure never see it.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Tweens = game:GetService("TweenService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Layout = require(script.Parent.UILayout)
local Scope = require(script.Parent.UIScope)
local Onboarding = {}

export type Step = "shop" | "display" | "collect" | "shelves" | "again" | "done"
export type Progress = { step: Step, mark: number }
export type Onboarding = {
	update: (Types.Snapshot, string?) -> (),
	layout: (Layout.Frame, boolean) -> (),
	skip: () -> (),
	step: () -> Step,
}

local function copies(state: Types.Snapshot): number
	local total = 0
	for _, count in state.owned do
		total += count
	end
	return total
end

local function displayedSlot(state: Types.Snapshot): number?
	for slot = 1, state.unlocked do
		local id = state.slots[slot]
		if id and id ~= "" then
			return slot
		end
	end
	return nil
end

-- Pure step machine. `page` is the open screen (nil when none). `mark` holds the step's baseline.
function Onboarding.advance(progress: Progress?, state: Types.Snapshot, page: string?): Progress
	if not progress then
		return { step = if copies(state) > 0 then "done" else "shop", mark = 0 }
	end
	local step: Step, mark = progress.step, progress.mark
	while true do
		local before = step
		if step == "shop" and copies(state) > 0 then
			step = "display"
		elseif step == "display" and displayedSlot(state) then
			step, mark = "collect", state.coins
		elseif step == "collect" and state.coins > mark then
			step = "shelves"
		elseif step == "shelves" and page == "Shelves" then
			step = "again"
		elseif step == "again" and page == "Shop" then
			step = "done"
		end
		if step == before then
			return { step = step, mark = mark }
		end
	end
end

local function touch(): boolean
	return Input.TouchEnabled and not Input.MouseEnabled
end

local function hint(step: Step, page: string?): string
	if step == "shop" then
		return if page == "Shop"
			then "Claim your free box!"
			else "This plot is yours! Grab a free box in the Shop"
	elseif step == "display" then
		return "Put your figure on Display to earn Coins"
	elseif step == "collect" then
		return (if touch() then "Tap" else "Click")
			.. " your figure on the Display to collect Coins"
	elseif step == "shelves" then
		return "Show off your collection on your Shelves"
	end
	return "Open another box to grow your collection!"
end

local function ownCollector(slot: number): BasePart?
	local plots = workspace:FindFirstChild("PlayerPlots")
	local plot = if plots then plots:FindFirstChild(tostring(Players.LocalPlayer.UserId)) else nil
	local folder = if plot and plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId
		then plot:FindFirstChild("FigureCollectors")
		else nil
	local target = if folder then folder:FindFirstChild(tostring(slot)) else nil
	return if target and target:IsA("BasePart") then target else nil
end

local function bob(object: GuiObject, from: UDim2, to: UDim2)
	object.Position = from
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	Tweens:Create(object, info, { Position = to }):Play()
end

-- A downward pointer drawn with frames: stem plus a rotated-square head.
local function pointer(parent: Instance, name: string, width: number): Frame
	local root = Kit.frame(parent, name)
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Size = UDim2.fromOffset(width, width * 1.4)
	local stem = Kit.frame(root, "Stem", Style.gold)
	stem.AnchorPoint = Vector2.new(0.5, 0)
	stem.Position = UDim2.fromScale(0.5, 0)
	stem.Size = UDim2.fromScale(0.36, 0.6)
	Kit.stroke(stem, Style.ink, Style.outlineSmall)
	local head = Kit.frame(root, "Head", Style.gold)
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.Position = UDim2.fromScale(0.5, 0.62)
	head.Size = UDim2.fromOffset(width * 0.7, width * 0.7)
	head.Rotation = 45
	Kit.stroke(head, Style.ink, Style.outlineSmall)
	return root
end

function Onboarding.create(
	stage: Instance,
	scope: Scope.Scope,
	tiles: { [string]: TextButton },
	hosts: { [string]: Frame }
): Onboarding
	local progress: Progress? = nil
	local page: string? = nil
	local hideCard = false
	local card = Kit.card(stage, "Onboarding", Style.white, 16, 4)
	card.root.ZIndex = 40
	card.root.Visible = false
	card.stroke.Color = Style.violet
	local text = Kit.text(card.face, "Hint", "", 18, Style.display())
	text.TextWrapped = true
	text.TextTruncate = Enum.TextTruncate.None
	local skipButton = Instance.new("TextButton")
	skipButton.Name = "SkipTutorial"
	skipButton.AnchorPoint = Vector2.new(1, 0.5)
	skipButton.BackgroundColor3 = Style.surface2
	skipButton.FontFace = Style.display()
	skipButton.TextColor3 = Style.muted
	skipButton.TextSize = 15
	skipButton.Text = "Skip"
	skipButton.Parent = card.face
	Kit.corner(skipButton, 10)

	-- Ring + pointer re-parented onto whichever GUI element the step points at.
	local ring = Instance.new("Frame")
	ring.Name = "OnboardingRing"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, 14, 1, 14)
	ring.ZIndex = 5
	ring.Interactable = false
	Kit.corner(ring, 24)
	Kit.stroke(ring, Style.violet, 4)
	bob(pointer(ring, "Pointer", 28), UDim2.new(0.5, 0, 0, -10), UDim2.new(0.5, 0, 0, -22))

	-- World pointer above the first displayed figure's collector (owner-only, local).
	local world = Instance.new("BillboardGui")
	world.Name = "OnboardingCollect"
	world.Size = UDim2.fromOffset(60, 110)
	world.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0)
	world.AlwaysOnTop = true
	world.LightInfluence = 0
	world.ResetOnSpawn = false
	world.Enabled = false
	bob(pointer(world, "Pointer", 44), UDim2.new(0.5, 0, 1, -14), UDim2.fromScale(0.5, 1))
	world.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	scope.add(function()
		ring:Destroy()
		world:Destroy()
		card.root:Destroy()
	end)

	local function target(step: Step, state: Types.Snapshot): GuiObject?
		if step == "shop" and page == "Shop" then
			local daily = hosts.Shop:FindFirstChild("DailyBox", true)
			return if daily and daily:IsA("GuiObject") and state.dailyReady then daily else nil
		end
		local id = if step == "shop" or step == "again"
			then "Shop"
			elseif step == "display" then "Display"
			elseif step == "shelves" then "Shelves"
			else nil
		return if id and page ~= id then tiles[id] else nil
	end

	local function render(state: Types.Snapshot?)
		local step: Step = if progress then progress.step else "done"
		local active = step ~= "done" and state ~= nil
		card.root.Visible = active and not hideCard
		local gui = if active and state then target(step, state) else nil
		ring.Parent = gui
		local slot = if active and step == "collect" and state then displayedSlot(state) else nil
		local collector = if slot then ownCollector(slot) else nil
		if collector then
			world.Adornee = collector -- A lost target just disables the pointer below.
		end
		world.Enabled = collector ~= nil
		if active then
			text.Text = hint(step, page)
		end
	end

	local last: Types.Snapshot? = nil
	local function skip()
		progress = { step = "done", mark = 0 }
		render(last)
	end
	scope.connect(skipButton.Activated, skip)

	return {
		update = function(state: Types.Snapshot, open: string?)
			last, page = state, open
			if state.ready then
				progress = Onboarding.advance(progress, state, open)
			end
			render(state)
		end,
		layout = function(geometry: Layout.Frame, opened: boolean)
			-- Phone sheets cover the top band; the ring still guides inside the open screen.
			hideCard = geometry.phone and opened
			local width = math.min(480, geometry.width - 32)
			local height = geometry.hud.height
			local y = if geometry.phone then geometry.hud.y + height + 8 else geometry.hud.y
			Kit.rect(card.root, math.floor((geometry.width - width) / 2), y, width, height)
			Kit.rect(text, 14, 0, width - 100, height)
			text.TextSize = if geometry.phone then 15 else 18
			skipButton.Position = UDim2.new(1, -8, 0.5, 0)
			skipButton.Size = UDim2.fromOffset(68, height - 16)
			render(last)
		end,
		skip = skip,
		step = function()
			return if progress then progress.step else "done"
		end,
	}
end

return Onboarding
