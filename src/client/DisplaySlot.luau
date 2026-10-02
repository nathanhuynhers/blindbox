--!strict
-- One Display slot card: filled (figure, name, rate), empty (+ Choose / Choosing…),
-- slot 4 unlock price, or "Coming later" for slots with no unlock yet.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Badge = require(script.Parent.UIBadge)
local Button = require(script.Parent.UIButton)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Preview = require(script.Parent.UIPreview)
local Slot = {}

export type Mode = { target: number?, placing: string? }
export type Slot = {
	button: TextButton,
	size: (width: number, height: number) -> (),
	update: (Types.Snapshot, Mode) -> (),
}

function Slot.create(
	parent: Instance,
	ctx: Context.Context,
	index: number,
	choose: (number) -> ()
): Slot
	local button = Instance.new("TextButton")
	button.Name = "DisplaySlot" .. index
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = Style.white
	button.Parent = parent
	button:SetAttribute("Slot", index)
	Kit.corner(button, 18)
	local stroke = Kit.stroke(button, Style.ink)
	local number = Kit.text(
		button,
		"SlotNumber",
		tostring(index),
		12,
		Style.body(Enum.FontWeight.Heavy),
		Style.muted
	)
	Kit.rect(number, 8, 4, 40, 16)
	local stage = Kit.frame(button, "Portrait")
	local portrait = Preview.create(stage, ctx.scope, true)
	local name = Kit.text(button, "FigureName", "", 15)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local rate = Badge.create(button, "Rate", "", {
		fill = Style.mint,
		color = Style.mintInk,
		height = 26,
		size = 13,
	})
	rate.root.AnchorPoint = Vector2.new(0.5, 0)
	local plus = Kit.frame(button, "Add", Style.violet)
	plus.AnchorPoint = Vector2.new(0.5, 0)
	Kit.round(plus)
	local plusIcon = Icons.create(plus, "Plus", Style.white, 28)
	plusIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	plusIcon.Position = UDim2.fromScale(0.5, 0.5)
	local title = Kit.text(button, "State", "", 17, Style.display(), Style.violetDark)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local hint = Kit.text(button, "Hint", "", 13, Style.body(Enum.FontWeight.Bold), Style.muted)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextWrapped = true
	local lock = Icons.create(button, "Lock", Style.unknownInk, 34)
	lock.AnchorPoint = Vector2.new(0.5, 0)
	local unlock = Button.create(
		button,
		"Unlock",
		{
			variant = "gold",
			text = "Unlock",
			size = 15,
			radius = 14,
			drop = 3,
			price = true,
		},
		ctx.scope,
		ctx.effects,
		function()
			ctx.send("Expand", nil, nil, nil)
		end
	)
	unlock.button.AnchorPoint = Vector2.new(0.5, 0)
	ctx.scope.connect(button.Activated, function()
		choose(index)
	end)
	local width, height = 160, 184
	local function place()
		local compact = height < 170
		local image = if compact then 78 else 112
		Kit.rect(stage, (width - image) / 2, if compact then 14 else 18, image, image)
		local nameY = (if compact then 14 else 18) + image
		Kit.rect(name, 6, nameY, width - 12, 20)
		rate.root.Position = UDim2.new(0.5, 0, 0, nameY + 22)
		plus.Size = UDim2.fromOffset(if compact then 48 else 60, if compact then 48 else 60)
		plus.Position = UDim2.new(0.5, 0, 0, if compact then 26 else 38)
		local below = (if compact then 26 else 38) + (if compact then 48 else 60) + 10
		Kit.rect(title, 6, below, width - 12, 22)
		Kit.rect(hint, 6, below + 22, width - 12, 34)
		lock.Position = UDim2.new(0.5, 0, 0, if compact then 26 else 40)
		unlock.button.Position = UDim2.new(0.5, 0, 0, if compact then 76 else 92)
		unlock.button.Size = UDim2.fromOffset(math.min(width - 16, 140), if compact then 52 else 56)
	end
	return {
		button = button,
		size = function(nextWidth: number, nextHeight: number)
			width, height = nextWidth, nextHeight
			button.Size = UDim2.fromOffset(width, height)
			place()
		end,
		update = function(snapshot: Types.Snapshot, mode: Mode)
			local id = snapshot.slots[index] or ""
			local locked = index > snapshot.unlocked
			local price = if locked then State.unlockPrice(snapshot, index) else nil
			-- Only the next locked slot with an unlock method can be bought.
			local buyable = price ~= nil and index == snapshot.unlocked + 1
			local filled = not locked and id ~= ""
			local targeted = mode.target == index
			local placing = mode.placing ~= nil and not locked
			button:SetAttribute("FigureId", id)
			button:SetAttribute("Locked", locked)
			button:SetAttribute("Targeted", targeted)
			local figure = Catalog.byId[id]
			button.BackgroundColor3 = if locked
				then Style.lockedFill
				elseif targeted or placing then Style.violetWash
				elseif filled and figure then Style.collection(figure.collection).wash
				else Style.white
			stroke.Color = if locked
				then Style.lockedBorder
				elseif targeted or placing then Style.violet
				else Style.ink
			portrait.figure(if filled then id else nil, true)
			stage.Visible = filled
			name.Visible = filled
			rate.root.Visible = filled
			if filled and figure then
				name.Text = figure.name
				-- Banked Coins are collected in the world (click the figure or press E).
				local ready = State.earnings(snapshot, id)
				rate.set(
					State.rate(State.figureRate(snapshot, id))
						.. (if ready > 0 then " · " .. State.compact(ready) .. " ready" else "")
				)
			end
			plus.Visible = not locked and not filled
			lock.Visible = locked
			unlock.button.Visible = buyable
			title.TextColor3 = Style.violetDark
			hint.TextColor3 = Style.muted
			if locked then
				title.Visible = false
				hint.Visible = not buyable
				hint.Text = State.lockedText(snapshot, index)
				if buyable and price then
					unlock.setPrice(State.compact(price))
					local need = State.need(snapshot, price)
					unlock.set("Unlock", ctx.canAct() and need == nil, need)
				end
			elseif placing then
				-- Placing a figure chosen in Collection: every unlocked slot is a target.
				stage.Visible, name.Visible, rate.root.Visible, plus.Visible =
					false, false, false, false
				title.Visible, hint.Visible = true, true
				title.Text = "Place here"
				hint.Text = if filled and figure then "Swaps out " .. figure.name else "Empty slot"
			elseif filled then
				title.Visible, hint.Visible = false, false
			else
				title.Visible, hint.Visible = true, targeted
				title.Text = if targeted then "Choosing…" else "Choose"
				hint.Text = "Pick a figure below"
			end
			button.Selectable = not locked
			button:SetAttribute(
				"AccessibleName",
				"Slot "
					.. index
					.. ": "
					.. (
						if locked
							then (if buyable
								then "locked, unlock available"
								else string.lower(State.lockedText(snapshot, index)))
							elseif figure then figure.name
							else "empty"
					)
			)
		end,
	}
end

return Slot
