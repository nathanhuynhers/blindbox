--!strict
-- One toast at a time for server replies and status. Errors stay a little longer.
local Scope = require(script.Parent.UIScope)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Layout = require(script.Parent.UILayout)
local Notifications = {}
export type Notifications = {
	root: Frame,
	show: (string, string?) -> (),
	-- `at` places the toast from its height at a width; it may narrow it to keep off the HUD.
	place: (width: number, at: (measure: (width: number) -> number) -> Layout.Rect) -> (),
}
function Notifications.create(parent: Instance, scope: Scope.Scope): Notifications
	local card = Kit.card(parent, "Notification", Style.white, 16, 4)
	local root = card.root
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
	-- One row per line (plus wrapping estimate); the toast never clips its message.
	local function measure(across: number): number
		local lines = 0
		for line in string.gmatch(last .. "\n", "([^\n]*)\n") do
			lines += math.max(1, math.ceil(#line * 8.5 / math.max(1, across - 32)))
		end
		return 32 + 20 * math.clamp(lines, 1, 5)
	end
	local at: ((number) -> number) -> Layout.Rect = function(heightAt)
		return { x = 0, y = 0, width = width, height = heightAt(width) }
	end
	local function fit()
		local rect = at(measure)
		Kit.rect(root, rect.x, rect.y, rect.width, rect.height)
	end
	local function cancel()
		if timer then
			task.cancel(timer)
			timer = nil
		end
	end
	scope.add(cancel)
	return {
		root = root,
		place = function(nextWidth: number, nextAt: ((number) -> number) -> Layout.Rect)
			width = math.max(200, math.floor(nextWidth))
			at = nextAt
			fit()
		end,
		show = function(message: string, kind: string?)
			if last == message and root.Visible then
				return
			end
			cancel()
			last = message
			text.Text = message
			fit()
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
