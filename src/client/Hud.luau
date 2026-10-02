--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local State = require(script.Parent.UIState)
local Icons = require(script.Parent.UIIcons)
local W = require(script.Parent.Widgets)
local Hud = {}
function Hud.create(parent: Instance, ctx: Context.Context)
	local root = W.frame(parent, "Hud")
	root.Size = UDim2.new(1, -24, 0, 58)
	root.Position = UDim2.fromOffset(12, 10)
	local coins = W.action(root, "", ctx.scope, ctx.effects, function()
		local snapshot = ctx.snapshot()
		if snapshot then
			ctx.message(
				State.number(snapshot.coins)
					.. " Coins  /  "
					.. snapshot.rate
					.. " Coins/sec"
					.. (
						if not snapshot.ready
								or string.find(
									string.lower(snapshot.saveStatus),
									"preview",
									1,
									true
								)
							then "\n" .. snapshot.saveStatus
							else ""
					)
			)
		end
	end, true)
	coins.button.Name = "Coins"
	coins.button.Size = UDim2.fromOffset(150, 48)
	local icon = Icons.create(coins.button, "Coins", Theme.gold)
	icon.Position = UDim2.fromOffset(10, 12)
	local amount = W.label(coins.button, "...", 44, 16)
	amount.Position = UDim2.fromOffset(40, 2)
	amount.Size = UDim2.new(1, -46, 0, 44)
	local function resize()
		coins.button.Size = UDim2.fromOffset(math.min(190, math.max(100, root.AbsoluteSize.X)), 48)
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()
	return {
		root = root,
		update = function(snapshot: Types.Snapshot)
			amount.Text = State.compact(snapshot.coins)
		end,
	}
end
return Hud
