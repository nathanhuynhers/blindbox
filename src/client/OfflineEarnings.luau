--!strict
-- Welcome-back card for offline Display earnings. Claim and tapping outside both send the claim;
-- the server computed the amount and credits it only on that request.
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
			local card = Kit.card(gui, "Card", Style.white, 22, 4)
			local face = card.face
			local coin = Icons.create(face, "Coin", Style.gold, 56)
			local title = Kit.text(face, "Title", "Welcome back!", 30, Style.display())
			local body =
				Kit.text(face, "Away", `Your Display earned while you were away ({away}).`, 18)
			body.TextColor3, body.TextWrapped = Style.muted, true
			body.TextTruncate = Enum.TextTruncate.None
			local amount = Kit.text(face, "Amount", `+{coins} Coins`, 34, Style.display())
			for _, label in { title, body, amount } do
				label.TextXAlignment = Enum.TextXAlignment.Center
			end
			local button = Button.create(face, "Claim", {
				variant = "gold",
				text = "Claim",
				size = 22,
				radius = 18,
				drop = 4,
			}, scope, effects, done)
			local function layout()
				local width = math.min(420, gui.AbsoluteSize.X - 32)
				local height = 290
				card.root.Position = UDim2.fromOffset(
					(gui.AbsoluteSize.X - width) / 2,
					(gui.AbsoluteSize.Y - height) / 2
				)
				card.root.Size = UDim2.fromOffset(width, height)
				Kit.rect(coin, (width - 56) / 2, 18, 56, 56)
				Kit.rect(title, 16, 82, width - 32, 38)
				Kit.rect(body, 16, 122, width - 32, 46)
				Kit.rect(amount, 16, 168, width - 32, 42)
				Kit.rect(button.button, (width - 200) / 2, 218, 200, 56)
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
