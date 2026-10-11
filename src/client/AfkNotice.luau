--!strict
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Scope = require(script.Parent.UIScope)
local Notice = {}
export type View = { show: (boolean) -> (), destroy: () -> () }
function Notice.create(): View
	local scope = Scope.create()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AfkReconnectLoading"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 120
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	local dim = Kit.frame(gui, "Transition", Style.dim)
	dim.BackgroundTransparency = Style.dimTransparency
	local card = Kit.card(dim, "Reconnect", Style.surface, 20, 5)
	local title =
		Kit.text(card.face, "Title", "Keeping Your Collection Growing!", 24, Style.display())
	local body = Kit.text(
		card.face,
		"Body",
		"You've been away for a while. Moving you to a new server so you can keep collecting!",
		17,
		nil,
		Style.muted
	)
	local status = Kit.text(card.face, "Status", "Saving your collection...", 16, nil, Style.violet)
	for _, label in { title, body, status } do
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		label.TextXAlignment = Enum.TextXAlignment.Center
	end
	local function layout()
		local width = math.max(180, math.min(440, gui.AbsoluteSize.X - 32))
		card.root.Size = UDim2.fromOffset(width, 220)
		card.root.Position = UDim2.new(0.5, -width / 2, 0.5, -110)
		Kit.rect(title, 20, 20, width - 40, 66)
		Kit.rect(body, 20, 92, width - 40, 74)
		Kit.rect(status, 20, 177, width - 40, 26)
	end
	scope.connect(gui:GetPropertyChangedSignal("AbsoluteSize"), layout)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	layout()
	local loading: ScreenGui? = nil
	local function clearLoading()
		if loading then
			loading:Destroy()
			loading = nil
		end
		-- Reset the teleport GUI even if the next teleport belongs to another feature.
		-- Cleanup must finish even if the service rejects resetting its GUI.
		pcall(function()
			TeleportService:SetTeleportGui(nil)
		end)
	end
	return {
		show = function(departing)
			gui.Enabled = true
			status.Text = if departing
				then "Finding your next server..."
				else "Saving your collection..."
			clearLoading()
			loading = gui:Clone()
			local ok = pcall(function()
				TeleportService:SetTeleportGui(loading)
			end)
			if not ok then
				warn("AFK custom loading screen unavailable; using Roblox's loading screen.")
			end
		end,
		destroy = function()
			clearLoading()
			scope.destroy()
			gui:Destroy()
		end,
	}
end
return Notice
