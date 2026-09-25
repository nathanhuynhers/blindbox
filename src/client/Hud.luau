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
				State.number(snapshot.coins) .. " Coins  ·  " .. snapshot.rate .. " Coins/sec"
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
	local scrap = W.action(root, "", ctx.scope, ctx.effects, function()
		local snapshot = ctx.snapshot()
		if snapshot then
			ctx.message(State.number(snapshot.scrap) .. " Scrap · Pick a figure to redeem")
		end
		ctx.navigate("Collection")
	end, true)
	scrap.button.Name = "Scrap"
	scrap.button.Position = UDim2.fromOffset(158, 0)
	scrap.button.Size = UDim2.fromOffset(88, 48)
	local scrapIcon = Icons.create(scrap.button, "Scrap", Theme.primary)
	scrapIcon.Position = UDim2.fromOffset(8, 14)
	scrapIcon.Size = UDim2.fromOffset(20, 20)
	local scraps = W.label(scrap.button, "...", 44, 15)
	scraps.Position = UDim2.fromOffset(34, 2)
	scraps.Size = UDim2.new(1, -40, 0, 44)
	local status = W.action(root, "...", ctx.scope, ctx.effects, function()
		local snapshot = ctx.snapshot()
		if snapshot then
			ctx.message(snapshot.saveStatus)
		end
	end, true)
	status.button.Name = "SaveStatus"
	status.button.Size = UDim2.fromOffset(88, 44)
	status.button.Position = UDim2.new(1, -88, 0, 2)
	local function resize()
		local width = math.min(150, math.max(100, root.AbsoluteSize.X - 170))
		coins.button.Size = UDim2.fromOffset(width, 48)
		scrap.button.Position = UDim2.fromOffset(width + 8, 0)
		scrap.button.Size = UDim2.fromOffset(76, 48)
		status.button.Position = UDim2.new(1, -78, 0, 2)
		status.button.Size = UDim2.fromOffset(78, 44)
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()
	return {
		root = root,
		update = function(snapshot: Types.Snapshot)
			amount.Text = State.compact(snapshot.coins)
			scraps.Text = State.compact(snapshot.scrap)
			local raw = string.lower(snapshot.saveStatus)
			status.set(
				if not snapshot.ready
					then "Paused"
					elseif string.find(raw, "preview", 1, true) then "Unsaved"
					elseif string.find(raw, "saved", 1, true) then "Saved"
					else "Saving",
				true
			)
			status.button.TextColor3 = if not snapshot.ready then Theme.error else Theme.muted
		end,
	}
end
return Hud
