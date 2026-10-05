--!strict
-- Run in the CLIENT Command Bar on a settled opening result. Never Rojo-mapped.
-- Uses native mesh bounds, camera projection, text fitting and safe-area geometry, not
-- implementation offsets or a UI engine double. Run again after resizing a sleeping result.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
assert(game:GetService("RunService"):IsStudio(), "Studio-only regression check")
local player = Players.LocalPlayer
assert(player, "Run on the client")
local gui = player.PlayerGui:FindFirstChild("BlindboxOpening") :: ScreenGui?
assert(gui and gui:GetAttribute("Phase") == "Result", "Wait for a settled Result")
local camera = workspace.CurrentCamera
assert(camera, "Missing camera")
local stage = workspace:FindFirstChild("BlindboxCinematic")
assert(stage, "Missing stage")
local figure = stage:FindFirstChildWhichIsA("Model")
assert(figure, "Missing catalog figure")
local details = gui:FindFirstChild("Details", true) :: Frame
assert(details, "Missing result controls")
local inset = GuiService:GetGuiInset()
local safeMin = gui.AbsolutePosition + inset
local safeMax = safeMin + gui.AbsoluteSize
local function visible(object: Instance): boolean
	local at: Instance? = object
	while at and at ~= gui do
		if at:IsA("GuiObject") and not at.Visible then
			return false
		end
		at = at.Parent
	end
	return at == gui
end
local function rectangle(object: GuiObject): (Vector2, Vector2)
	local minimum = object.AbsolutePosition + inset
	return minimum, minimum + object.AbsoluteSize
end
local checks = 0
local function check(value: boolean, message: string)
	checks += 1
	assert(value, message)
end
local modelMin, modelMax = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
for _, part in figure:GetDescendants() do
	if not part:IsA("BasePart") or part.Transparency == 1 then
		continue
	end
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2)
				local screen = camera:WorldToViewportPoint(point)
				check(screen.Z > 0, "Figure behind camera")
				modelMin =
					Vector2.new(math.min(modelMin.X, screen.X), math.min(modelMin.Y, screen.Y))
				modelMax =
					Vector2.new(math.max(modelMax.X, screen.X), math.max(modelMax.Y, screen.Y))
			end
		end
	end
end
check(modelMin.X >= safeMin.X and modelMin.Y >= safeMin.Y, "Figure clipped at top/left")
check(modelMax.X <= safeMax.X and modelMax.Y <= safeMax.Y, "Figure clipped at bottom/right")
for _, object in details:GetDescendants() do
	if not object:IsA("GuiObject") or not visible(object) then
		continue
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		local minimum, maximum = rectangle(object)
		check(
			minimum.X >= safeMin.X - 1 and minimum.Y >= safeMin.Y - 1,
			object.Name .. " outside top/left safe area"
		)
		check(
			maximum.X <= safeMax.X + 1 and maximum.Y <= safeMax.Y + 1,
			object.Name .. " outside bottom/right safe area"
		)
		check(object.TextFits, object.Name .. " text does not fit: " .. object.Text)
		check(
			maximum.X <= modelMin.X
				or minimum.X >= modelMax.X
				or maximum.Y <= modelMin.Y
				or minimum.Y >= modelMax.Y,
			object.Name .. " covers the collectible"
		)
		if object:IsA("TextButton") then
			check(
				object.AbsoluteSize.X >= 44 and object.AbsoluteSize.Y >= 44,
				object.Name .. " below touch minimum"
			)
		end
	end
end
-- A right-column result must not paint its scrim across any of the collectible.
local columnMin = rectangle(details)
if columnMin.X > safeMin.X + gui.AbsoluteSize.X * 0.45 then
	local scrim = gui:FindFirstChild("ResultScrim", true) :: Frame
	local scrimMin = rectangle(scrim)
	check(modelMax.X < scrimMin.X, "Compact scrim darkens the collectible")
end
print(
	string.format(
		"PASS: %d native opening bounds/text/projection checks (%s, %s)",
		checks,
		figure.Name,
		tostring(camera.ViewportSize)
	)
)
