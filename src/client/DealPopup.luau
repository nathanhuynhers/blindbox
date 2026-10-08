--!strict
-- "Hourly Deal" popup opened by E at a plaza pop-up stall. Presentation only: Buy sends the Deal
-- intent with the stall and the window on screen, and the server re-prices and decides. The
-- card follows each snapshot, so a window rollover while it is open swaps in the new deal.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Actions = game:GetService("ContextActionService")
local Input = game:GetService("UserInputService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local Icons = require(script.Parent.UIIcons)
local Scope = require(script.Parent.UIScope)
local State = require(script.Parent.UIState)
local Preview = require(script.Parent.BlindBoxPreview)
local Sfx = require(script.Parent.Sfx)
local Popup = {}
Popup.stalls = table.freeze({
	{ name = "Mint", body = Color3.fromRGB(205, 238, 219), stripe = Color3.fromRGB(143, 211, 176) },
	{ name = "Sky", body = Color3.fromRGB(211, 234, 247), stripe = Color3.fromRGB(142, 200, 232) },
	{
		name = "Butter",
		body = Color3.fromRGB(252, 235, 184),
		stripe = Color3.fromRGB(242, 207, 107),
	},
})
local sticker = Color3.fromRGB(242, 141, 178)

export type Controller = {
	show: (stall: number) -> (),
	update: (Types.Snapshot) -> (),
	-- The client's one in-flight request started or finished.
	pending: (boolean) -> (),
	isOpen: () -> boolean,
	close: () -> (),
	destroy: () -> (),
}

function Popup.create(
	effects: () -> boolean,
	buy: (stall: number, window: number) -> ()
): Controller
	local snapshot: Types.Snapshot? = nil
	local busy = false
	local finish: (() -> ())? = nil
	local render: (() -> ())? = nil
	local function close()
		local done = finish
		finish, render = nil, nil
		if done then
			done()
		end
	end
	local function show(stall: number)
		close()
		local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local theme = Popup.stalls[stall]
		if not playerGui or not theme or not snapshot then
			return
		end
		local scope = Scope.create()
		local buying = false
		local gui = Instance.new("ScreenGui")
		gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "DealPopup", false, 90
		gui.ZIndexBehavior, gui.ScreenInsets =
			Enum.ZIndexBehavior.Sibling, Enum.ScreenInsets.CoreUISafeInsets
		local backdrop = Instance.new("TextButton")
		backdrop.Name, backdrop.Text, backdrop.AutoButtonColor = "Backdrop", "", false
		backdrop.BorderSizePixel, backdrop.Selectable, backdrop.Modal = 0, false, true
		backdrop.BackgroundColor3, backdrop.BackgroundTransparency =
			Style.dim, Style.dimTransparency
		backdrop.Position, backdrop.Size = UDim2.fromOffset(-100, -100), UDim2.new(1, 200, 1, 200)
		backdrop.Parent = gui
		scope.connect(backdrop.Activated, close)
		local card = Kit.card(gui, "Card", Style.surface, 28, 8)
		local face = card.face

		-- Header: mini stall, title and stall name, countdown chip, Close.
		local header = Kit.frame(face, "Header")
		local divider = Kit.frame(face, "Divider", Style.divider)
		local icon = Kit.frame(header, "StallIcon", theme.body)
		Kit.corner(icon, 14)
		Kit.stroke(icon, Style.ink, Style.outlineSmall)
		local awning = Kit.frame(icon, "Awning", theme.stripe)
		awning.Position, awning.Size = UDim2.fromScale(0.1, 0.14), UDim2.fromScale(0.8, 0.3)
		Kit.corner(awning, 6)
		local tiny = Kit.frame(icon, "Box", Style.white)
		tiny.Position, tiny.Size = UDim2.fromScale(0.32, 0.5), UDim2.fromScale(0.36, 0.34)
		Kit.corner(tiny, 4)
		Kit.stroke(tiny, Style.ink, 1.5)
		local title = Kit.text(header, "Title", "Hourly Deal", 28, Style.display())
		local subtitle = Kit.text(
			header,
			"Subtitle",
			`Peeka's Pop-up · {theme.name} stall`,
			14,
			Style.body(Enum.FontWeight.Bold),
			Style.muted
		)
		local chip = Kit.text(header, "Countdown", "", 13, Style.body(Enum.FontWeight.ExtraBold))
		chip.BackgroundTransparency = 0
		chip.TextXAlignment = Enum.TextXAlignment.Center
		chip.TextTruncate = Enum.TextTruncate.None
		Kit.round(chip)
		local closeButton = Instance.new("TextButton")
		closeButton.Name, closeButton.Text, closeButton.AutoButtonColor = "Close", "", false
		closeButton.BackgroundColor3, closeButton.BorderSizePixel = Style.ink, 0
		closeButton.Parent = header
		Kit.round(closeButton)
		local cross = Icons.create(closeButton, "Close", Style.white, 20)
		cross.AnchorPoint, cross.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		scope.connect(closeButton.Activated, function()
			close()
		end)

		-- Body: the box well with its discount sticker, then the deal details.
		local well = Kit.frame(face, "BoxWell", Style.surface2)
		Kit.corner(well, 20)
		Kit.stroke(well, Style.ink, Style.outlineSmall)
		local preview = Preview.create(well, scope)
		local discount = Kit.text(well, "Discount", "", 16, Style.display(), Style.white)
		discount.BackgroundTransparency, discount.BackgroundColor3 = 0, sticker
		discount.TextXAlignment = Enum.TextXAlignment.Center
		discount.Rotation, discount.ZIndex = -12, 5
		Kit.round(discount)
		Kit.stroke(discount, Style.ink, Style.outline)
		local details = Kit.frame(face, "Details")
		local collectionChip =
			Kit.text(details, "Collection", "", 13, Style.body(Enum.FontWeight.ExtraBold))
		collectionChip.BackgroundTransparency = 0
		collectionChip.AutomaticSize = Enum.AutomaticSize.X
		collectionChip.TextTruncate = Enum.TextTruncate.None
		Kit.padding(collectionChip, 0, 10, 0, 10)
		Kit.round(collectionChip)
		local name = Kit.text(details, "BoxName", "", 24, Style.display())
		local prices = Kit.frame(details, "Prices")
		Kit.list(prices, Enum.FillDirection.Horizontal, 10, Enum.VerticalAlignment.Center)
		local old = Kit.text(prices, "OldPrice", "", 16, Style.body(), Style.muted)
		old.RichText, old.AutomaticSize = true, Enum.AutomaticSize.X
		old.Size = UDim2.fromScale(0, 1)
		old.TextTruncate = Enum.TextTruncate.None
		old.LayoutOrder = 1
		local coin = Icons.create(prices, "Coin", Style.gold, 26)
		coin.LayoutOrder = 2
		local new = Kit.text(prices, "DealPrice", "", 34, Style.display())
		new.AutomaticSize, new.TextTruncate = Enum.AutomaticSize.X, Enum.TextTruncate.None
		new.Size = UDim2.fromScale(0, 1)
		new.LayoutOrder = 3
		local stockRow = Kit.frame(details, "Stock")
		Kit.list(stockRow, Enum.FillDirection.Horizontal, 6, Enum.VerticalAlignment.Center)
		local pips: { Frame } = {}
		local stockText = Kit.text(stockRow, "StockText", "", 14)
		stockText.AutomaticSize, stockText.TextTruncate =
			Enum.AutomaticSize.X, Enum.TextTruncate.None
		stockText.Size = UDim2.fromScale(0, 1)
		stockText.LayoutOrder = 100
		local note = Kit.text(
			details,
			"Note",
			"Same deal on every server this hour.",
			13,
			Style.body(Enum.FontWeight.Bold),
			Style.muted
		)
		local buyButton: Button.Button
		buyButton = Button.create(
			face,
			"BuyDeal",
			{
				variant = "gold",
				text = "",
				size = 22,
				radius = 16,
				drop = 4,
				icon = "Coin",
				silent = true,
			},
			scope,
			effects,
			function()
				local state = snapshot
				local deal = if state
					then State.deal(state, stall, workspace:GetServerTimeNow())
					else nil
				if deal and deal.canBuy and not busy and state and state.ready then
					buying = true
					Sfx.play("click")
					buy(stall, deal.window)
					if render then
						render()
					end
				end
			end
		)

		local compact = false
		local function layout()
			local size = gui.AbsoluteSize
			local width = math.min(600, size.X - 32)
			compact = size.Y < 460 or width < 520
			local head = if compact then 60 else 76
			local pad = if compact then 14 else 20
			local wellSize = if compact then 132 else 190
			local buttonHeight = if compact then 52 else 60
			local height = head + pad + wellSize + pad + buttonHeight + pad
			card.root.Size = UDim2.fromOffset(width, height)
			card.root.Position =
				UDim2.fromOffset((size.X - width) / 2, math.max(8, (size.Y - height) / 2))
			Kit.rect(header, 0, 0, width, head)
			Kit.rect(divider, 0, head, width, 2)
			local iconSize = if compact then 40 else 52
			Kit.rect(icon, 16, (head - iconSize) / 2, iconSize, iconSize)
			local closeSize = if compact then 44 else 48
			Kit.rect(
				closeButton,
				width - 14 - closeSize,
				(head - closeSize) / 2,
				closeSize,
				closeSize
			)
			local chipWidth = if compact then 132 else 150
			Kit.rect(chip, width - 24 - closeSize - chipWidth, (head - 30) / 2, chipWidth, 30)
			local textX = 16 + iconSize + 12
			local textWidth = width - textX - 32 - closeSize - chipWidth
			title.TextSize, subtitle.TextSize =
				if compact then 22 else 28, if compact then 12 else 14
			Kit.rect(
				title,
				textX,
				head / 2 - (if compact then 24 else 30),
				textWidth,
				if compact then 26 else 32
			)
			Kit.rect(subtitle, textX, head / 2 + 2, textWidth, 18)
			Kit.rect(well, pad, head + pad, wellSize, wellSize)
			local sticky = if compact then 44 else 56
			Kit.rect(discount, -10, -10, sticky, sticky)
			discount.TextSize = if compact then 13 else 16
			local detailX = pad + wellSize + pad
			Kit.rect(details, detailX, head + pad, width - detailX - pad, wellSize)
			local scale = if compact then 0.78 else 1
			local rows: { GuiObject } = { collectionChip, name, prices, stockRow, note }
			local heights = { 26, 30, 40, 22, 18 }
			local gap = (wellSize - (26 + 30 + 40 + 22 + 18) * scale) / 4
			local y = 0
			for index, object in rows do
				local rowHeight = heights[index] * scale
				object.Position = UDim2.fromOffset(0, y)
				object.Size = if object == collectionChip
					then UDim2.fromOffset(0, rowHeight)
					else UDim2.new(1, 0, 0, rowHeight)
				y += rowHeight + gap
			end
			name.TextSize, new.TextSize = math.floor(24 * scale), math.floor(34 * scale)
			old.TextSize, stockText.TextSize = math.floor(16 * scale), math.floor(14 * scale)
			collectionChip.TextSize, note.TextSize = math.floor(13 * scale), math.floor(13 * scale)
			coin.Size = UDim2.fromOffset(math.floor(26 * scale), math.floor(26 * scale))
			Kit.rect(
				buyButton.button,
				pad,
				head + pad + wellSize + pad,
				width - 2 * pad,
				buttonHeight
			)
		end

		local shownWindow: number? = nil
		local function draw()
			local state = snapshot
			local deal = if state
				then State.deal(state, stall, workspace:GetServerTimeNow())
				else nil
			if not state or not deal then
				return
			end
			local accent = Style.collection(deal.collection)
			if shownWindow ~= deal.window then
				shownWindow = deal.window
				preview.set(deal.collection)
			end
			well.BackgroundColor3 = accent.wash
			discount.Text = `-{deal.percent}%`
			discount.Visible = deal.percent > 0
			collectionChip.Text = deal.name
			collectionChip.BackgroundColor3, collectionChip.TextColor3 = accent.wash, accent.ink
			name.Text = `{deal.name} Box`
			old.Text = `<s>{State.number(deal.price)}</s>`
			new.Text = State.number(deal.deal)
			while #pips < deal.stock do
				local pip = Kit.frame(stockRow, "Pip", Style.white)
				pip.Size = UDim2.fromOffset(18, 16)
				pip.LayoutOrder = #pips + 1
				Kit.corner(pip, 3)
				Kit.stroke(pip, Style.ink, Style.outlineSmall)
				table.insert(pips, pip)
			end
			for index, pip in pips do
				local full = index <= deal.left
				pip.Visible = index <= deal.stock
				pip.BackgroundColor3 = if full then theme.stripe else Style.white
				local line = pip:FindFirstChildOfClass("UIStroke")
				if line then
					line.Color = if full then Style.ink else Style.disabledBorder
				end
			end
			stockText.Text = if deal.left == 0
				then "Sold out for you this hour"
				else `{deal.left} of {deal.stock} left for you`
			local soon = deal.status == "soon" or deal.status == "restocking"
			chip.Text = `{deal.clockLabel} {deal.clock}`
			chip.BackgroundColor3 = if soon then Style.readyWash else Style.mint
			chip.TextColor3 = if soon then Style.readyInk else Style.mintText
			local enabled = deal.canBuy and not busy and state.ready
			buyButton.set(if buying and busy then "Buying…" else deal.button, enabled)
			-- Gamepad: never leave the selection on a button that just became unavailable.
			if GuiService.SelectedObject == buyButton.button and not enabled then
				GuiService.SelectedObject = closeButton
			end
		end

		scope.connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function()
			layout()
			draw()
		end)
		gui.Parent = playerGui
		layout()
		draw()
		-- Gamepad only: mouse and touch players should not see a selection ring.
		if string.find(Input:GetLastInputType().Name, "Gamepad", 1, true) then
			GuiService.SelectedObject = if buyButton.enabled()
				then buyButton.button
				else closeButton
		end
		Sfx.play("open")
		local ticker = task.spawn(function()
			while true do
				task.wait(0.5)
				draw()
			end
		end)
		scope.add(function()
			task.cancel(ticker)
		end)
		Actions:BindActionAtPriority("DealPopupBack", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.ButtonB)
		render = function()
			if not busy then
				buying = false
			end
			draw()
		end
		finish = function()
			Actions:UnbindAction("DealPopupBack")
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
			scope.destroy()
			gui:Destroy()
			Sfx.play("close")
		end
	end
	return {
		show = show,
		update = function(state: Types.Snapshot)
			snapshot = state
			if render then
				render()
			end
		end,
		pending = function(value: boolean)
			busy = value
			if render then
				render()
			end
		end,
		isOpen = function()
			return finish ~= nil
		end,
		close = close,
		destroy = close,
	}
end

return Popup
