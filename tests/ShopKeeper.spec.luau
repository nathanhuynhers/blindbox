--!strict
-- Real client shopkeeper motion over real plot geometry; frames and the 0.5 s check are driven by hand.
local Engine = require("./PlotEngine")
local Plot = require("./PlayerPlot")
local NightLights = require("./NightLights")
local ShopFixture = require("./ShopFixture")
local ShopKeeper = require("./ShopKeeper")
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local owner, guest = Engine.player(41), Engine.player(42)
Engine.services.Players.LocalPlayer = owner
local stepped = Engine.services.RunService.RenderStepped
local plot, other = Plot.create(owner, 1), Plot.create(guest, 2)
local keeper = plot.shop.keeper
local rest = keeper:GetPivot()
local eyes = {}
for _, part in keeper:GetDescendants() do
	if part.Name == "PeekaShopkeeper_Eyes" then
		table.insert(eyes, part)
	end
end
local function asleep(): boolean
	return eyes[1].Transparency == 1 and eyes[2].Transparency == 1
end
local function stand(target, x, z)
	owner.Character:PivotTo(target.transform * Engine.CFrame.new(x, 3, z))
end
local motion = true
local baseline = Engine.connections
local control = ShopKeeper.create(function()
	return motion
end)
stand(plot, 30, -30)
control.tick()
check(Engine.connections == baseline, "no per-frame step while nobody is near a shopkeeper")
stand(plot, -15.6, 6) -- About 20 studs from Peeka, outside the 12-stud prompt range.
control.tick()
check(Engine.connections == baseline + 1, "one per-frame step while the local player is nearby")
stepped:fire()
local bobbed = keeper:GetPivot()
check(
	math.abs(bobbed.Position.Y - rest.Position.Y) <= ShopKeeper.style.bobHeight + 1e-6,
	"idle bob stays within its height"
)
NightLights.set(true)
control.tick()
check(asleep(), "Peeka dozes at night")
stand(plot, -29.4 + 8, 6) -- Inside the Open Shop range.
control.tick()
check(not asleep(), "Peeka wakes to wave when the owner enters prompt range")
stepped:fire()
control.tick()
check(not asleep(), "the wave plays once and stays awake while it runs")
stand(plot, 30, -30)
control.tick()
check(Engine.connections == baseline, "leaving disconnects the per-frame step")
check(keeper:GetPivot().Position.Y == rest.Position.Y, "leaving restores the replicated pose")
check(asleep(), "far Peeka keeps dozing at night")
motion = false
stand(plot, -29.4 + 8, 6)
control.tick()
check(Engine.connections == baseline, "Motion off: no bob or wave")
check(asleep(), "Motion off: no wave, so Peeka keeps dozing")
motion = true
stand(other, -29.4 + 8, 6)
control.tick()
local otherEyes = other.shop.keeper:FindFirstChild("PeekaShopkeeper_Eyes")
check(otherEyes.Transparency == 1, "a visitor at another plot's Shop gets no wave")
check(Engine.connections == baseline + 1, "visitors still see the idle bob")
owner.Character:FindFirstChildOfClass("Humanoid").Health = 0
control.tick()
check(Engine.connections == baseline, "death stops the animation")
owner.Character = Engine.player(43).Character
stand(plot, -29.4 + 8, 6)
control.tick()
check(Engine.connections == baseline + 1 and not asleep(), "respawned owner gets a fresh wave")
Plot.destroy(plot)
control.tick()
check(Engine.connections <= baseline + 1, "torn-down Shop is forgotten")
control.destroy()
check(otherEyes.Transparency == 0, "client teardown restores the replicated eyes")
NightLights.set(false)
Plot.destroy(other)
check(Engine.connections == 0, "all plot and client connections released")
print("PASS: " .. checks .. " shopkeeper motion checks (engine shim)")
