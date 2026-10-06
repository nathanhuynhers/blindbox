--!strict
-- Deterministic engine boundaries; real CoinBurst and DisplayEarnings run unchanged.
local E = require("./OpeningVisualEngine")
local UI = require("./UIEngine")
for key, value in UI.Enum do
	if not E.Enum[key] then
		E.Enum[key] = value
	end
end
for _, key in
	{
		"FillDirection",
		"HorizontalAlignment",
		"VerticalAlignment",
		"SortOrder",
		"AutomaticSize",
		"EasingDirection",
	}
do
	E.Enum[key] = UI.Enum[key]
end
E.now = 100
E.os = {
	clock = function()
		return E.now
	end,
}
E.task = UI.task
E.Style = {
	gold = E.Color3.new(1, 1, 0),
	ink = E.Color3.new(0, 0, 0),
	display = function()
		return {}
	end,
}
E.Icons = {
	create = function(parent)
		local icon = E.Instance.new("Frame")
		icon.Parent = parent
		return icon
	end,
}
E.Sfx = UI.Sfx
E.UDim = UI.UDim
E.UDim2 = UI.UDim2
E.workspace = E.Instance.new("Folder")
E.services.TweenService = {
	Create = function(_, _, info, _)
		local tween = { Completed = E.signal(), cancelled = false }
		local timer = nil
		tween.Play = function()
			timer = UI.task.delay(info.Time, function()
				timer = nil
				tween.Completed:Fire()
			end)
		end
		tween.Cancel = function()
			tween.cancelled = true
			if timer then
				UI.task.cancel(timer)
				timer = nil
			end
		end
		return tween
	end,
}
E.methods.WaitForChild = E.methods.FindFirstChild
E.humanoid.Health = 100
local root = E.Instance.new("Part")
local mt = getmetatable(root)
local assign = mt.__newindex
mt.__newindex = function(self, key, value)
	assign(self, key, value)
	if key == "CFrame" then
		self.props.Position = value.Position
	end
end
root.Name, root.Parent = "HumanoidRootPart", E.player.Character
root.Position = E.Vector3.new(0, 0, 0)
local plots = E.Instance.new("Folder")
plots.Name, plots.Parent = "PlayerPlots", E.workspace
E.player.UserId = 42
local plot = E.Instance.new("Folder")
plot.Name, plot.Parent = "42", plots
plot:SetAttribute("OwnerId", 42)
local targets = E.Instance.new("Folder")
targets.Name, targets.Parent = "FigureCollectors", plot
E.clicks = {}
for i = 1, 3 do
	local target = E.Instance.new("Part")
	target.Name, target.Parent = tostring(i), targets
	target.Position = E.Vector3.new(7 + i, 0, 0)
	local click = E.Instance.new("ClickDetector")
	click.MouseClick = E.signal()
	click.Parent = target
	E.clicks[i] = click.MouseClick
end
function E.step(seconds)
	E.now += seconds
	E.heartbeat:Fire(0)
end
-- Move the existing visible Coins inside the actual impact radius; no fake impact callback.
function E.land(count)
	local folder = E.workspace:FindFirstChild("CoinBursts")
	local moved = 0
	if folder then
		for _, coin in folder:GetChildren() do
			if coin.Name == "Coin" and moved < count then
				coin.Position = root.Position
				moved += 1
			end
		end
	end
	E.step(0)
	return moved
end
function E.flush()
	UI.advance(5)
end
return E
