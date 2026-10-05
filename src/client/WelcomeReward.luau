--!strict
-- Welcome Quest finale: a short celebration whose dominant action opens the free x10 now.
-- Presentation only; Open sends the WelcomeTen request and the server decides. Later just
-- closes it (the Shop keeps the x10 button and the quest card keeps pointing at it).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Tweens = game:GetService("TweenService")
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local Icons = require(script.Parent.UIIcons)
local Scope = require(script.Parent.UIScope)
local Sfx = require(script.Parent.Sfx)
local Reward = {}
export type Popup = {
	show: () -> (),
	isOpen: () -> boolean,
	destroy: () -> (),
}

local confetti = { Style.gold, Style.violet, Style.mint, Color3.fromRGB(255, 140, 170) }

function Reward.create(effects: () -> boolean, open: () -> ()): Popup
	local finish: (() -> ())? = nil
	local function close()
		local done = finish
		finish = nil
		if done then
			done()
		end
	end
	return {
		isOpen = function()
			return finish ~= nil
		end,
		show = function()
			close()
			local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if not playerGui then
				return
			end
			local scope = Scope.create()
			local gui = Instance.new("ScreenGui")
			gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "WelcomeReward", false, 100
			gui.ZIndexBehavior, gui.ScreenInsets =
				Enum.ZIndexBehavior.Sibling, Enum.ScreenInsets.DeviceSafeInsets
			-- The backdrop blocks the world but never dismisses: Later is a deliberate choice.
			local backdrop = Instance.new("TextButton")
			backdrop.Name, backdrop.Text, backdrop.AutoButtonColor = "Backdrop", "", false
			backdrop.BorderSizePixel, backdrop.Selectable, backdrop.Modal = 0, false, true
			backdrop.BackgroundColor3, backdrop.BackgroundTransparency = Style.revealGround, 0.2
			backdrop.Position, backdrop.Size =
				UDim2.fromOffset(-100, -100), UDim2.new(1, 200, 1, 200)
			backdrop.Parent = gui
			local card = Kit.card(gui, "Card", Style.white, 24, 4)
			local face = card.face
			local pop = Instance.new("UIScale")
			pop.Parent = card.root
			local kicker = Kit.text(
				face,
				"Kicker",
				"WELCOME QUEST COMPLETE!",
				16,
				Style.body(Enum.FontWeight.ExtraBold),
				Style.violet
			)
			local gift = Icons.create(face, "Gift", Style.gold, 64)
			local title = Kit.text(face, "Title", "FREE Pocket Grove ×10", 30, Style.display())
			local body = Kit.text(face, "Guarantee", "A Rare is guaranteed inside!", 17)
			body.TextColor3 = Style.muted
			for _, label in { kicker, title, body } do
				label.TextXAlignment = Enum.TextXAlignment.Center
			end
			local openButton = Button.create(
				face,
				"OpenWelcomeTen",
				{
					variant = "gold",
					text = "OPEN 10 NOW",
					size = 24,
					radius = 20,
					drop = 5,
					icon = "Gift",
				},
				scope,
				effects,
				function()
					close()
					open()
				end
			)
			local later = Instance.new("TextButton")
			later.Name = "Later"
			later.AutoButtonColor = false
			later.BackgroundTransparency = 1
			later.FontFace = Style.body(Enum.FontWeight.Bold)
			later.TextSize = 15
			later.TextColor3 = Style.muted
			later.Text = "Later"
			later.Parent = face
			scope.connect(later.Activated, close)
			local function layout()
				local width = math.min(440, gui.AbsoluteSize.X - 32)
				local height = math.min(300, gui.AbsoluteSize.Y - 16)
				local short = height < 300
				card.root.Position = UDim2.fromOffset(
					(gui.AbsoluteSize.X - width) / 2,
					(gui.AbsoluteSize.Y - height) / 2
				)
				card.root.Size = UDim2.fromOffset(width, height)
				local icon = if short then 48 else 64
				Kit.rect(kicker, 16, 14, width - 32, 22)
				Kit.rect(gift, (width - icon) / 2, 40, icon, icon)
				local y = 40 + icon + 6
				Kit.rect(title, 16, y, width - 32, 36)
				Kit.rect(body, 16, y + 36, width - 32, 24)
				-- Keep the primary action and Later at full touch size, packed from the bottom.
				Kit.rect(later, (width - 140) / 2, height - 48, 140, 44)
				Kit.rect(openButton.button, (width - 300) / 2, height - 48 - 66, 300, 62)
			end
			scope.connect(gui:GetPropertyChangedSignal("AbsoluteSize"), layout)
			gui.Parent = playerGui
			layout()
			Sfx.play("complete")
			GuiService.SelectedObject = openButton.button
			if effects() then
				pop.Scale = 0.6
				Tweens:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				gift.Rotation = -12
				local wiggle = Tweens:Create(
					gift,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Rotation = 12 }
				)
				wiggle:Play()
				scope.add(function()
					wiggle:Cancel()
				end)
				-- A short confetti burst behind the card; every piece is owned by the popup.
				for index = 1, 18 do
					local piece = Kit.frame(gui, "Confetti", confetti[index % #confetti + 1])
					piece.AnchorPoint = Vector2.new(0.5, 0.5)
					piece.Size = UDim2.fromOffset(10, 6)
					piece.Position = UDim2.fromScale(0.5, 0.45)
					piece.ZIndex = 0
					local angle = index / 18 * math.pi * 2
					Tweens:Create(piece, TweenInfo.new(0.9, Enum.EasingStyle.Quart), {
						Position = UDim2.new(
							0.5,
							math.cos(angle) * 260,
							0.45,
							math.sin(angle) * 170
						),
						Rotation = 360 + index * 20,
						BackgroundTransparency = 1,
					}):Play()
				end
			end
			finish = function()
				if GuiService.SelectedObject == openButton.button then
					GuiService.SelectedObject = nil
				end
				scope.destroy()
				gui:Destroy()
			end
		end,
		destroy = close,
	}
end

return Reward
