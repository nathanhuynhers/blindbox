--!strict
-- CLIENT Command Bar during Play, with Shop open on an eligible collection.
-- Confirms the ordinary private snapshot drives every value, checks native text fitting,
-- and scrolls the odds pane to the meters for a screenshot. Does not buy or seed anything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(Players.LocalPlayer.PlayerScripts.Client.UIState)
assert(RunService:IsStudio(), "Studio-only native Shop check")
local shop = Players.LocalPlayer.PlayerGui.PocketGrove:FindFirstChild("Shop", true) :: Frame
local host = shop.Parent :: Frame
assert(host.Visible, "Open Shop first")
local collection = shop:GetAttribute("SelectedCollection")
assert(typeof(collection) == "string", "Choose a collection")
local seen: Types.Snapshot? = nil
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local connection = (remotes.State :: RemoteEvent).OnClientEvent:Connect(function(snapshot: Types.Snapshot)
	seen = snapshot
end)
local sync = remotes.RequestState :: RemoteEvent
sync:FireServer()
local deadline = os.clock() + 4
while seen == nil and os.clock() < deadline do task.wait(0.1) end
connection:Disconnect()
local snapshot = assert(seen, "No confirmed owner snapshot received")
local rows = State.luck(snapshot, collection)
local panel = shop:FindFirstChild("LuckProgress", true) :: Frame
assert(panel.Visible == (#rows == 2), "Eligibility disagrees with confirmed snapshot")
if not panel.Visible then
	print("PASS: starter collection omits luck presentation")
	return
end
for _, row in rows do
	local meter = panel:FindFirstChild("Luck" .. row.rarity) :: Frame
	assert(meter:GetAttribute("Fraction") == row.fraction, "Meter is not snapshot-confirmed")
	assert(meter:GetAttribute("Chance") == row.chance, "Chance is not snapshot-confirmed")
	assert((meter.LuckOdds :: TextLabel).Text == row.odds, "Current/base odds mismatch")
	assert((meter.Status :: TextLabel).Text == row.status, "State label mismatch")
end
task.wait(0.6)
local contents = shop:FindFirstChild("Contents", true) :: ScrollingFrame
contents.CanvasPosition = Vector2.new(0, math.max(0,
	panel.Position.Y.Offset + panel.Size.Y.Offset - contents.AbsoluteSize.Y + 12))
RunService.Heartbeat:Wait()
for _, object in panel:GetDescendants() do
	if object:IsA("TextLabel") then
		assert(object.TextFits, object.Name .. " is clipped: " .. object.Text)
		assert(object.AbsolutePosition.X >= panel.AbsolutePosition.X, "Label spills left")
		assert(object.AbsolutePosition.X + object.AbsoluteSize.X <= panel.AbsolutePosition.X + panel.AbsoluteSize.X + 1,
			"Label spills right")
	end
end
assert(panel.AbsolutePosition.Y >= contents.AbsolutePosition.Y - 1, "Meters cannot scroll into view")
assert(panel.AbsolutePosition.Y + panel.AbsoluteSize.Y <= contents.AbsolutePosition.Y + contents.AbsoluteSize.Y + 1,
	"Meter/footer cannot scroll into view")
print("PASS: native confirmed Shop luck, text fitting and reachable meters at " .. tostring(workspace.CurrentCamera.ViewportSize))
