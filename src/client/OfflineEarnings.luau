--!strict
-- Welcome-back card for offline Display earnings, in the Store's candy style. Claim and tapping
-- outside both send the claim; the server computed the amount and credits it only on that
-- request. Double & Claim (MN-22) joins Claim here once purchases exist; Claim stays free.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local Icons = require(script.Parent.UIIcons)
local Scope = require(script.Parent.UIScope)
local Offline = {}
export type Popup = {
	show: (coins: string, away: string) -> (),
	isOpen: () -> boolean,
	destroy: () -> (),
}

function Offline.create(effects: () -> boolean, claim: () -> ()): Popup
	local open: (() -> ())? = nil
	local function close()
		local finish = open
		open = nil
		if finish then
			finish()
		end
	end
	local function done()
		close()
		claim()
	end
	return {
		isOpen = function()
			return open ~= nil
		end,
		show = function(coins, away)
			close()
			local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if not playerGui then
				return
			end
			local scope = Scope.create()
			local gui = Instance.new("ScreenGui")
			gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "OfflineEarnings", false, 100
			gui.ZIndexBehavior, gui.ScreenInsets =
				Enum.ZIndexBehavior.Sibling, Enum.ScreenInsets.DeviceSafeInsets
			local backdrop = Instance.new("TextButton")
			backdrop.Name, backdrop.Text, backdrop.AutoButtonColor = "Backdrop", "", false
			backdrop.BorderSizePixel, backdrop.Selectable, backdrop.Modal = 0, false, true
			backdrop.BackgroundColor3, backdrop.BackgroundTransparency =
				Style.dim, Style.dimTransparency
			backdrop.Position, backdrop.Size =
				UDim2.fromOffset(-100, -100), UDim2.new(1, 200, 1, 200)
			backdrop.Parent = gui
			scope.connect(backdrop.Activated, done)
			local card = Kit.card(gui, "Card", Style.surface, 26, 6, 4)
			local face = card.face
			-- Candy header band: rounded top with a square filler, one horizontal gradient.
			local band = Kit.frame(face, "Band", Style.white)
			Kit.corner(band, 24)
			local bandSquare = Kit.frame(band, "BandSquare", Style.white)
			for _, part in { band, bandSquare } do
				local fill = Instance.new("UIGradient")
				fill.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Style.candyViolet),
					ColorSequenceKeypoint.new(0.55, Style.hex(0xC9B9FF)),
					ColorSequenceKeypoint.new(1, Style.hex(0xFFE38F)),
				})
				fill.Parent = part
			end
			local bandLine = Kit.frame(face, "BandLine", Style.ink)
			local coin = Icons.create(face, "Coin", Style.gold, 44)
			local title = Kit.text(face, "Title", "Welcome back!", 30, Style.display(), Style.white)
			local titleStroke = Instance.new("UIStroke")
			titleStroke.Color = Style.ink
			titleStroke.Thickness = 3
			titleStroke.Parent = title
			local body = Kit.text(
				face,
				"Away",
				`Your Display earned {coins} Coins while you were away ({away}).`,
				17
			)
			body.TextColor3, body.TextWrapped = Style.muted, true
			body.TextTruncate = Enum.TextTruncate.None
			body.TextXAlignment = Enum.TextXAlignment.Center
			local button = Button.create(face, "Claim", {
				variant = "gold",
				text = "Claim",
				size = 22,
				radius = 18,
				drop = 4,
				price = true,
			}, scope, effects, done)
			button.setPrice(coins)
			local free =
				Kit.text(face, "Free", "Free", 13, Style.body(Enum.FontWeight.Heavy), Style.muted)
			free.TextXAlignment = Enum.TextXAlignment.Center
			local function layout()
				local width = math.min(440, gui.AbsoluteSize.X - 32)
				local height = math.min(266, gui.AbsoluteSize.Y - 16)
				card.root.Position = UDim2.fromOffset(
					(gui.AbsoluteSize.X - width) / 2,
					(gui.AbsoluteSize.Y - height) / 2
				)
				card.root.Size = UDim2.fromOffset(width, height)
				Kit.rect(band, 0, 0, width, 66)
				Kit.rect(bandSquare, 0, 33, width, 33)
				Kit.rect(bandLine, 0, 66, width, 3)
				Kit.rect(coin, 18, 11, 44, 44)
				Kit.rect(title, 72, 0, width - 88, 66)
				Kit.rect(body, 16, 80, width - 32, 46)
				local buttonWidth = math.min(280, width - 32)
				Kit.rect(button.button, (width - buttonWidth) / 2, height - 98, buttonWidth, 60)
				Kit.rect(free, 16, height - 30, width - 32, 18)
			end
			scope.connect(gui:GetPropertyChangedSignal("AbsoluteSize"), layout)
			gui.Parent = playerGui
			layout()
			GuiService.SelectedObject = button.button
			open = function()
				if GuiService.SelectedObject == button.button then
					GuiService.SelectedObject = nil
				end
				scope.destroy()
				gui:Destroy()
			end
		end,
		destroy = close,
	}
end

return Offline
