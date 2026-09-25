--!strict
local Scope = require(script.Parent.UIScope)
local TextService = game:GetService("TextService")
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)
local Notifications = {}
function Notifications.create(parent: Instance, scope: Scope.Scope)
	local root = W.card(parent, "Notification", 48)
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -82)
	root.Size = UDim2.new(1, -32, 0, 48)
	root.ZIndex = 20
	root.Visible = false
	root.BackgroundTransparency = 0.04
	W.outline(root, Theme.card, 0.2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(540, 180)
	limit.Parent = root
	local text = W.label(root, "", 56, 16)
	W.inset(text, 6, 56)
	text.ZIndex = 21
	text.TextXAlignment = Enum.TextXAlignment.Center
	local timer: thread? = nil
	local last = ""
	local function measure()
		local size = TextService:GetTextSize(
			text.Text,
			text.TextSize,
			text.Font,
			Vector2.new(math.max(80, root.AbsoluteSize.X - 24), 1000)
		)
		local height = math.clamp(size.Y + 20, 48, 180)
		root.Size = UDim2.new(root.Size.X.Scale, root.Size.X.Offset, 0, height)
		W.inset(text, 10, height - 20)
	end
	scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), measure)
	local function cancel()
		if timer then
			task.cancel(timer)
			timer = nil
		end
	end
	scope.add(cancel)
	return {
		root = root,
		show = function(message: string, kind: string?)
			if last == message and root.Visible then
				return
			end
			cancel()
			last = message
			text.Text = message
			measure()
			text.TextColor3 = if kind == "error" then Theme.error else Theme.ink
			root.BackgroundColor3 = if kind == "success" then Theme.soft else Theme.card
			root.Visible = true
			timer = task.delay(if kind == "error" then 7 else 4, function()
				timer = nil
				root.Visible = false
			end)
		end,
	}
end
return Notifications
