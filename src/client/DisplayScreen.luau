--!strict
-- Display: total income chip, set-bonus banner, six slot cards and the picker drawer.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Badge = require(script.Parent.UIBadge)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Shell = require(script.Parent.ScreenShell)
local SlotCard = require(script.Parent.DisplaySlot)
local Picker = require(script.Parent.DisplayPicker)
local Display = {}

function Display.create(parent: Instance, ctx: Context.Context): Context.Screen
	local shell = Shell.create(parent, ctx, {
		id = "Display",
		title = "Display",
		subtitle = "Figures earn coins every second. Click or tap each figure on your plot to collect",
	})
	local root = shell.root
	local income = Badge.create(shell.chips, "Income", "", {
		fill = Style.mint,
		color = Style.mintInk,
		height = 48,
		size = 22,
		font = Style.display(),
		outline = Style.mintFill,
	})
	income.root.LayoutOrder = 1
	local body = Kit.canvas(shell.body, "DisplayBody")
	local banner = Kit.frame(body, "SetBonus", Style.surface2)
	Kit.corner(banner, 12)
	local star = Icons.create(banner, "Star", Style.ink, 18)
	local bannerText = Kit.text(banner, "Text", "", 14)
	local bannerAmount = Kit.text(banner, "Amount", "", 17, Style.display())
	bannerAmount.TextXAlignment = Enum.TextXAlignment.Right
	local target: number? = nil
	local placing: string? = nil
	local refresh: () -> () = function() end
	local slots: { SlotCard.Slot } = {}
	for index = 1, DisplayConfig.maxSlots do
		slots[index] = SlotCard.create(body, ctx, index, function(slot)
			local snapshot = ctx.snapshot()
			if not snapshot or slot > snapshot.unlocked then
				return
			end
			if placing then
				if ctx.canAct() then
					ctx.send("Place", placing, slot, nil)
					placing = nil
				end
			else
				target = if target == slot then nil else slot
			end
			refresh()
		end)
	end
	local picker = Picker.create(body, ctx, {
		pick = function(id)
			local snapshot = ctx.snapshot()
			if not snapshot or not ctx.canAct() then
				return
			end
			local slot = target
			if slot then
				ctx.send("Place", id, slot, nil)
				target = nil
			else
				-- No slot chosen: fill the next empty slot, or pick which slot to swap.
				local empty = State.emptySlots(snapshot)
				if #empty > 0 then
					ctx.send("Place", id, empty[1], nil)
				else
					placing = id
				end
			end
			refresh()
		end,
		remove = function()
			local slot = target
			if slot and ctx.canAct() then
				ctx.send("Remove", nil, slot, nil)
				target = nil
				refresh()
			end
		end,
		cancel = function()
			target, placing = nil, nil
			refresh()
		end,
		browse = function()
			ctx.navigate("Collection", { slot = target })
		end,
	})
	local width, height, phone = 0, 0, false
	local function arrange()
		local pad = if phone then 12 else 20
		local inner = width - pad * 2
		local y = 12
		Kit.rect(banner, pad, y, inner, 40)
		Kit.rect(star, 14, 11, 18, 18)
		Kit.rect(bannerText, 42, 0, inner - 42 - 90, 40)
		Kit.rect(bannerAmount, inner - 100, 0, 86, 40)
		y += 48
		local gap = if phone then 8 else 12
		local cell = State.cells(inner, DisplayConfig.maxSlots, gap)
		local slotHeight = if phone then 150 else 176
		for index, slot in slots do
			slot.size(cell, slotHeight)
			slot.button.Position = UDim2.fromOffset(pad + (index - 1) * (cell + gap), y)
		end
		y += slotHeight + 8
		local drawer = math.max(if phone then 140 else 150, height - y - 12)
		picker.size(inner, drawer, phone)
		Kit.rect(picker.root, pad, y, inner, drawer)
		Kit.fit(body, y + drawer + 12, height)
	end
	local function update(snapshot: Types.Snapshot)
		shell.update(snapshot)
		if target and target > snapshot.unlocked then
			target = nil
		end
		if placing then
			-- Placement finished (or the copy went away): leave placing mode.
			local _, free = State.copies(snapshot, placing)
			if free < 1 or State.displayed(snapshot, placing) then
				placing = nil
			end
		end
		income.set("+" .. State.amount(State.totalRate(snapshot)) .. " coins/s")
		local bonus = State.setBonus(snapshot)
		local name = if bonus.collection then State.collectionName(bonus.collection) else nil
		local accent = Style.collection(bonus.collection or "")
		if bonus.active and name then
			banner.BackgroundColor3 = accent.wash
			bannerText.TextColor3 = accent.ink
			bannerAmount.TextColor3 = accent.ink
			bannerText.Text =
				string.format("%s set bonus is on: 3 different %s figures on Display", name, name)
			bannerAmount.Text = State.rate(bonus.amount)
		else
			banner.BackgroundColor3 = Style.surface2
			bannerText.TextColor3 = Style.ink
			bannerAmount.TextColor3 = Style.muted
			bannerText.Text = if name and bonus.best > 0
				then string.format(
					"Set bonus: show 3 different %s figures at once to earn extra coins",
					name
				)
				else "Set bonus: show 3 different figures from one collection to earn extra coins"
			bannerAmount.Text = string.format("%d / 3", bonus.best)
		end
		root:SetAttribute("Target", target)
		root:SetAttribute("Placing", placing)
		for _, slot in slots do
			slot.update(snapshot, { target = target, placing = placing })
		end
		picker.update(snapshot, target, placing)
	end
	refresh = function()
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
	end
	return {
		root = root,
		update = update,
		layout = function(nextWidth: number, nextHeight: number, nextPhone: boolean)
			phone = nextPhone
			width, height = shell.layout(nextWidth, nextHeight, nextPhone)
			arrange()
			refresh()
		end,
		route = function(route: Context.Route?)
			placing = if route
					and route.placing
					and Catalog.byId[route.placing]
				then route.placing
				else nil
			target = if route and route.slot then route.slot else nil
			refresh()
		end,
		back = function()
			if target or placing then
				target, placing = nil, nil
				refresh()
				return true
			end
			return false
		end,
	}
end

return Display
