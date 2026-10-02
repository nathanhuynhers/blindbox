--!strict
-- One toast at a time for server replies and status. Errors stay a little longer.
local Scope = require(script.Parent.UIScope)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Notifications = {}
export type Notifications = {
	root: Frame,
	show: (string, string?) -> (),
	place: (x: number, bottom: number, width: number) -> (),
}
function Notifications.create(parent: Instance, scope: Scope.Scope): Notifications
	local card = Kit.card(parent, "Notification", Style.white, 16, 4)
	local root = card.root
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.ZIndex = 60
	root.Visible = false
	Kit.padding(card.face, 8, 16, 8, 16)
	local text = Kit.text(card.face, "Message", "", 16)
	text.Size = UDim2.fromScale(1, 1)
	text.TextWrapped = true
	text.TextTruncate = Enum.TextTruncate.None
	text.TextXAlignment = Enum.TextXAlignment.Center
	local timer: thread? = nil
	local last = ""
	local width = 480
	local function cancel()
		if timer then
			task.cancel(timer)
			timer = nil
		end
	end
	scope.add(cancel)
	return {
		root = root,
		place = function(x: number, bottom: number, nextWidth: number)
			root.Position = UDim2.fromOffset(x, bottom)
			width = math.max(200, math.floor(nextWidth))
			root.Size = UDim2.fromOffset(width, root.Size.Y.Offset)
		end,
		show = function(message: string, kind: string?)
			if last == message and root.Visible then
				return
			end
			cancel()
			last = message
			text.Text = message
			-- Two lines for status text or long replies; the toast never clips its message.
			local wraps = string.find(message, "\n", 1, true) ~= nil or #message * 8.5 > width - 32
			local lines = if wraps then 2 else 1
			root.Size = UDim2.fromOffset(width, if lines == 2 then 72 else 52)
			text.TextColor3 = if kind == "error" then Style.alert else Style.ink
			card.face.BackgroundColor3 = if kind == "success" then Style.mint else Style.white
			card.stroke.Color = if kind == "error" then Style.alert else Style.ink
			root.Visible = true
			timer = task.delay(if kind == "error" then 7 else 4, function()
				timer = nil
				root.Visible = false
			end)
		end,
	}
end
return Notifications
