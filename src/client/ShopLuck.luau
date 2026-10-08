--!strict
-- Compact owner-only luck keeps the ordinary odds rows intact. Full means capped chance,
-- never a guaranteed pull. Tweens belong to the screen and replace prior work on refresh.
local TweenService = game:GetService("TweenService")
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Luck = {}
type Meter = {
	root: Frame,
	name: TextLabel,
	status: TextLabel,
	odds: TextLabel,
	track: Frame,
	fill: Frame,
	glow: UIStroke,
	tweens: { Tween },
	fraction: number,
	raised: boolean,
}
export type View = {
	root: Frame,
	update: (Types.Snapshot, string) -> (),
	layout: (number, boolean) -> number,
}
function Luck.create(parent: Instance, ctx: Context.Context): View
	local root = Kit.frame(parent, "LuckProgress", Style.surface2)
	local ancestor: Instance? = parent
	while ancestor and not ancestor:IsA("ScreenGui") do
		ancestor = ancestor.Parent
	end
	local gui = ancestor :: ScreenGui?
	root.Visible = false
	Kit.corner(root, 14)
	local title = Kit.text(root, "LuckTitle", "Luck building", 15, Style.display())
	local note =
		Kit.text(root, "LuckNote", "Higher chances, never guaranteed", 12, nil, Style.muted)
	note.TextWrapped = true
	note.TextTruncate = Enum.TextTruncate.None
	local meters: { Meter } = {}
	for _, rarity in { "Legendary", "Mythical" } do
		local palette = Rarity.get(rarity)
		local card = Kit.frame(root, "Luck" .. rarity)
		local name = Kit.text(card, "Rarity", rarity, 13, nil, palette.ink)
		local status = Kit.text(card, "Status", "", 12, nil, Style.muted)
		status.TextXAlignment = Enum.TextXAlignment.Right
		local odds =
			Kit.text(card, "LuckOdds", "", 12, Style.body(Enum.FontWeight.Bold), Style.muted)
		local track = Kit.frame(card, "LuckTrack", Style.track)
		track.ClipsDescendants = true
		Kit.round(track)
		local fill = Kit.frame(track, "LuckFill", palette.tint)
		fill.Size = UDim2.fromScale(0, 1)
		Kit.round(fill)
		local glow = Kit.stroke(track, palette.highlight, 2)
		glow.Transparency = 1
		table.insert(meters, {
			root = card,
			name = name,
			status = status,
			odds = odds,
			track = track,
			fill = fill,
			glow = glow,
			tweens = {},
			fraction = 0,
			raised = false,
		})
	end
	local function stop(meter: Meter)
		for _, tween in meter.tweens do
			tween:Cancel()
		end
		table.clear(meter.tweens)
		meter.glow.Transparency = 1
	end
	local function present(meter: Meter, animate: boolean)
		stop(meter)
		local target = UDim2.fromScale(meter.fraction, 1)
		if animate and ctx.effects() then
			local tween = TweenService:Create(
				meter.fill,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Size = target }
			)
			table.insert(meter.tweens, tween)
			if meter.raised then
				meter.glow.Transparency = 0.15
				local glint =
					TweenService:Create(meter.glow, TweenInfo.new(0.9), { Transparency = 1 })
				table.insert(meter.tweens, glint)
				glint:Play()
			end
			tween:Play()
		else
			meter.fill.Size = target
		end
		meter.raised = false
	end
	if gui then
		local screenGui = gui
		-- Opening hides the main GUI immediately after its confirmed reply. Finish the soft
		-- luck/reset moment when it returns, rather than spending that moment behind the reveal.
		ctx.scope.connect(screenGui:GetPropertyChangedSignal("Enabled"), function()
			for _, meter in meters do
				if not screenGui.Enabled then
					meter.raised = meter.raised or meter.glow.Transparency < 1
					stop(meter)
				elseif
					root.Visible and (meter.raised or meter.fill.Size.X.Scale ~= meter.fraction)
				then
					present(meter, true)
				end
			end
		end)
	end
	ctx.scope.add(function()
		for _, meter in meters do
			stop(meter)
		end
	end)
	local selected: string? = nil
	return {
		root = root,
		update = function(snapshot, collection)
			local rows = State.luck(snapshot, collection)
			root.Visible = #rows == 2
			for index, meter in meters do
				local row = rows[index]
				if not row then
					stop(meter)
					meter.raised = false
					continue
				end
				local previous = meter.root:GetAttribute("Fraction")
				local previousChance = meter.root:GetAttribute("Chance")
				local same = selected == collection
				local changed = not same or previous ~= row.fraction or previousChance ~= row.chance
				meter.fraction = row.fraction
				if not same then
					meter.raised = false
				end
				if
					same
					and typeof(previousChance) == "number"
					and row.chance > previousChance + 1e-6
				then
					meter.raised = true
				end
				meter.status.Text = row.status
				meter.status.TextColor3 = if row.boosted
					then Rarity.get(row.rarity).ink
					else Style.muted
				meter.odds.Text = row.odds
				meter.root:SetAttribute("Fraction", row.fraction)
				meter.root:SetAttribute("Chance", row.chance)
				meter.root:SetAttribute("Boosted", row.boosted)
				-- Static metadata also conveys the meter to accessibility/testing tools.
				meter.root:SetAttribute(
					"AccessibleName",
					row.rarity .. " · " .. row.status .. " · " .. row.odds
				)
				if changed or not ctx.effects() then
					if gui and not gui.Enabled then
						stop(meter)
					else
						present(meter, same)
					end
				end
			end
			selected = collection
		end,
		layout = function(width, phone)
			local pad = 10
			local inner = width - 2 * pad
			Kit.rect(title, pad, 7, inner, 20)
			title.TextSize = if phone then 14 else 15
			for index, meter in meters do
				Kit.rect(meter.root, pad, 32 + (index - 1) * 53, inner, 47)
				Kit.rect(meter.name, 0, 0, inner - 76, 18)
				Kit.rect(meter.status, inner - 76, 0, 76, 18)
				Kit.rect(meter.track, 0, 22, inner, 6)
				Kit.rect(meter.odds, 0, 30, inner, 17)
			end
			Kit.rect(note, pad, 139, inner, 30)
			note.TextSize = if width < 250 then 11 else 12
			return if root.Visible then 176 else 0
		end,
	}
end
return Luck
