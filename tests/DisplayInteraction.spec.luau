--!strict
-- Actual client prompt routing with engine signals/geometry shimmed, not native input simulation.
local Engine = require("./PlotEngine")
local Plot = require("./PlayerPlot")
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local Interaction = require("./DisplayInteraction")
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local owner, guest = Engine.player(11), Engine.player(22)
Engine.services.Players.LocalPlayer = owner
local prompts = Engine.services.ProximityPromptService
local input = Engine.services.UserInputService
local opened = 0
local shelvesOpened = 0
local shopOpened = 0
local control = Interaction.create(function()
	opened += 1
end, function()
	shelvesOpened += 1
end, function()
	shopOpened += 1
end)
local plot = Plot.create(owner, 1)
local session = Transactions.new(0)
local state = session.state
for slot, id in { "grove.pebble", "grove.sprout" } do
	state.owned[id], state.discovered[id], state.display.slots[slot] = 1, true, id
end
state.earnings["grove.pebble"], state.earnings["grove.sprout"] = 12.75, 19.5
local requests = 0
Plot.bindCollectors(plot, function(actor, slot, id)
	check(actor == owner, "collector resolves to owning actor")
	requests += 1
	Transactions.process(session, {
		action = "Collect",
		id = "physical:" .. requests,
		revision = state.revision,
		slot = slot,
		figure = id,
	}, 0, true, 0, 0, nil, true)
end, function()
	return state
end)
Plot.render(plot, state)
local fixture = plot.fixture.model
local target = fixture:FindFirstChild("ManageDisplay")
local prompt = target:FindFirstChildOfClass("ProximityPrompt")
local shelfTarget = plot.collection.model:FindFirstChild("ManageShelves")
local shelfPrompt = shelfTarget:FindFirstChildOfClass("ProximityPrompt")
local shopTarget = plot.shop.model:FindFirstChild("OpenShop")
local shopPrompt = shopTarget:FindFirstChildOfClass("ProximityPrompt")
control.update()
check(
	shopPrompt.Name == "OpenShopPrompt"
		and shopPrompt.KeyboardKeyCode == Engine.Enum.KeyCode.E
		and shopPrompt.ActionText == "Open Shop"
		and shopPrompt.ObjectText == "Peeka's Box Shop"
		and shopPrompt.MaxActivationDistance == 12
		and shopPrompt.HoldDuration == 0
		and shopPrompt.RequiresLineOfSight == false
		and shopPrompt.Enabled,
	"E · Open Shop matches the Display and Shelves prompts"
)
check(
	shopTarget.Transparency == 1 and not shopTarget.CanCollide and not shopTarget.CanQuery,
	"Shop prompt anchor is invisible and nonblocking"
)
check(
	prompt.KeyboardKeyCode == Engine.Enum.KeyCode.E and prompt.ActionText == "Manage Display",
	"E clearly manages Display"
)
check(
	shelfPrompt.KeyboardKeyCode == Engine.Enum.KeyCode.E
		and shelfPrompt.ActionText == "Manage Shelves",
	"E clearly manages Shelves"
)
local sign = fixture:FindFirstChild("CollectSignFace"):FindFirstChild("CollectSign")
local instruction = sign:FindFirstChild("Instruction")
check(
	string.find(instruction.Text, "Step on a Plate or Click its Figure", 1, true)
		and not sign.Active,
	"desktop instruction plaque is noninteractive"
)
input.LastInputTypeChanged:fire(Engine.Enum.UserInputType.Touch)
check(string.find(instruction.Text, "Step on a Plate or Tap its Figure", 1, true), "touch wording")
input.LastInputTypeChanged:fire(Engine.Enum.UserInputType.MouseMovement)
check(
	string.find(instruction.Text, "Click its Figure", 1, true),
	"hybrid device returns to mouse wording"
)
control.update(12345)
input.LastInputTypeChanged:fire(Engine.Enum.UserInputType.Touch)
check(
	string.find(instruction.Text, "Tap its Figure · 12.3K Coins Ready", 1, true),
	"plaque keeps the owner's Display total across input changes"
)
input.LastInputTypeChanged:fire(Engine.Enum.UserInputType.MouseMovement)
owner.Character:PivotTo(target.CFrame)
prompts.PromptShown:fire(prompt)
prompts.PromptTriggered:fire(prompt, owner)
check(opened == 1, "nearby owner opens management")
prompts.PromptTriggered:fire(prompt, guest)
check(opened == 1, "another actor triggering the prompt cannot open the local UI")
owner.Character:PivotTo(shelfTarget.CFrame)
prompts.PromptShown:fire(shelfPrompt)
prompts.PromptTriggered:fire(shelfPrompt, owner)
check(shelvesOpened == 1, "nearby owner opens Shelves management")
prompts.PromptTriggered:fire(shelfPrompt, guest)
check(shelvesOpened == 1, "another actor cannot open the local Shelves UI")
owner.Character:PivotTo(shopTarget.CFrame)
prompts.PromptShown:fire(shopPrompt)
check(shopPrompt.Enabled, "the owner keeps their own Shop prompt")
prompts.PromptTriggered:fire(shopPrompt, owner)
check(shopOpened == 1 and opened == 1 and shelvesOpened == 1, "nearby owner opens only the Shop")
prompts.PromptTriggered:fire(shopPrompt, guest)
check(shopOpened == 1, "another actor cannot open the local Shop")
owner.Character:PivotTo(shopTarget.CFrame + Engine.Vector3.new(12.01, 0, 0))
prompts.PromptTriggered:fire(shopPrompt, owner)
check(shopOpened == 1, "far Shop trigger ignored")
owner.Character:PivotTo(shopTarget.CFrame + Engine.Vector3.new(12, 0, 0))
prompts.PromptTriggered:fire(shopPrompt, owner)
check(shopOpened == 2, "inclusive Shop prompt distance boundary")
check(state.coins == 4500 and requests == 0, "management never invokes economy collection")
local collector = plot.collectors[2]
local click = collector:FindFirstChildOfClass("ClickDetector")
owner.Character:PivotTo(collector.CFrame)
click.MouseClick:fire(owner)
check(
	state.coins == 4519
		and state.earnings["grove.pebble"] == 12.75
		and state.earnings["grove.sprout"] == 0.5
		and opened == 1,
	"middle-figure click/tap transfers only its bank and never opens Display management"
)
for _ = 1, 100 do
	click.MouseClick:fire(owner)
end
check(
	state.coins == 4519 and #session.receipts == 4,
	"rapid duplicate activations cannot double-pay and receipts are rate bounded"
)
guest.Character:PivotTo(collector.CFrame)
local accepted = requests
click.MouseClick:fire(guest)
check(requests == accepted, "non-owner rejected before transaction")
owner.Character:PivotTo(collector.CFrame + Engine.Vector3.new(0, 0, 13))
click.MouseClick:fire(owner)
check(requests == accepted, "far collection rejected before transaction")
local parent = collector.Parent
collector.Parent = fixture
owner.Character:PivotTo(collector.CFrame)
click.MouseClick:fire(owner)
check(requests == accepted, "detached collector ancestry rejected")
collector.Parent = parent
check(not pcall(Plot.bindCollectors, plot, function() end), "duplicate collector binding rejected")
owner.Character:PivotTo(target.CFrame + Engine.Vector3.new(0, 0, 12.01))
prompts.PromptTriggered:fire(prompt, owner)
check(opened == 1, "far trigger ignored")
owner.Character:PivotTo(target.CFrame + Engine.Vector3.new(0, 0, 12))
prompts.PromptTriggered:fire(prompt, owner)
check(opened == 2, "inclusive prompt distance boundary")
owner.Character:FindFirstChildOfClass("Humanoid").Health = 0
prompts.PromptTriggered:fire(prompt, owner)
check(opened == 2, "dead character cannot open")
owner.Character = Engine.player(33).Character
owner.Character:PivotTo(target.CFrame)
prompts.PromptTriggered:fire(prompt, owner)
check(opened == 3, "respawn uses the new character without rebinding")
owner.Character:PivotTo(shopTarget.CFrame)
prompts.PromptTriggered:fire(shopPrompt, owner)
check(shopOpened == 3, "respawned owner opens the Shop without rebinding")
owner.Character:FindFirstChildOfClass("Humanoid").Health = 0
prompts.PromptTriggered:fire(shopPrompt, owner)
check(shopOpened == 3, "dead character cannot open the Shop")
owner.Character = Engine.player(34).Character
local other = Plot.create(guest, 2)
local otherTarget = other.fixture.model:FindFirstChild("ManageDisplay")
local otherPrompt = otherTarget:FindFirstChildOfClass("ProximityPrompt")
owner.Character:PivotTo(otherTarget.CFrame)
prompts.PromptShown:fire(otherPrompt)
prompts.PromptTriggered:fire(otherPrompt, owner)
check(not otherPrompt.Enabled and opened == 3, "guest prompt hidden and cannot route management")
local otherShelfTarget = other.collection.model:FindFirstChild("ManageShelves")
local otherShelfPrompt = otherShelfTarget:FindFirstChildOfClass("ProximityPrompt")
owner.Character:PivotTo(otherShelfTarget.CFrame)
prompts.PromptShown:fire(otherShelfPrompt)
prompts.PromptTriggered:fire(otherShelfPrompt, owner)
check(
	not otherShelfPrompt.Enabled and shelvesOpened == 1,
	"guest Shelves prompt is hidden and cannot route management"
)
local otherShopTarget = other.shop.model:FindFirstChild("OpenShop")
local otherShopPrompt = otherShopTarget:FindFirstChildOfClass("ProximityPrompt")
owner.Character:PivotTo(otherShopTarget.CFrame)
prompts.PromptShown:fire(otherShopPrompt)
prompts.PromptTriggered:fire(otherShopPrompt, owner)
check(
	not otherShopPrompt.Enabled and shopOpened == 3,
	"visitors see no Shop prompt on another plot and cannot open the Shop there"
)
control.update()
check(not otherShopPrompt.Enabled, "snapshot refresh never re-enables another plot's Shop prompt")
local liveConnections = Engine.connections
for _ = 1, 40 do
	Plot.render(plot, Rules.new(0))
	control.update()
end
check(Engine.connections == liveConnections, "snapshots and plot renders never bind more input")
local promptCount = 0
for _, instance in plot.model:GetDescendants() do
	if instance:IsA("ProximityPrompt") then
		promptCount += 1
	end
end
check(promptCount == 3, "one Display, one Shelves and one Shop prompt remain after rerenders")
Plot.destroy(plot)
prompts.PromptTriggered:fire(prompt, owner)
check(opened == 3, "destroyed plot prompt cannot reopen")
owner.Character:PivotTo(shopTarget.CFrame)
prompts.PromptTriggered:fire(shopPrompt, owner)
check(shopOpened == 3, "torn-down plot Shop prompt cannot reopen")
local replacement = Plot.create(owner, 1)
control.update()
local replacementTarget = replacement.fixture.model:FindFirstChild("ManageDisplay")
owner.Character:PivotTo(replacementTarget.CFrame)
prompts.PromptTriggered:fire(replacementTarget:FindFirstChildOfClass("ProximityPrompt"), owner)
check(opened == 4, "replacement plot uses the same one listener")
local replacementShelfTarget = replacement.collection.model:FindFirstChild("ManageShelves")
owner.Character:PivotTo(replacementShelfTarget.CFrame)
prompts.PromptTriggered:fire(replacementShelfTarget:FindFirstChildOfClass("ProximityPrompt"), owner)
check(shelvesOpened == 2, "replacement Shelves use the same one listener")
local replacementShopTarget = replacement.shop.model:FindFirstChild("OpenShop")
local replacementShopPrompt = replacementShopTarget:FindFirstChildOfClass("ProximityPrompt")
replacementShopPrompt.Enabled = false -- Hidden before ownership replicated.
control.update()
check(replacementShopPrompt.Enabled, "snapshot refresh recovers the owner's replacement Shop prompt")
owner.Character:PivotTo(replacementShopTarget.CFrame)
prompts.PromptTriggered:fire(replacementShopPrompt, owner)
check(shopOpened == 4, "replacement Shop uses the same one listener")
control.destroy()
prompts.PromptTriggered:fire(replacementTarget:FindFirstChildOfClass("ProximityPrompt"), owner)
check(opened == 4, "client teardown disconnects prompt routing")
prompts.PromptTriggered:fire(replacementShelfTarget:FindFirstChildOfClass("ProximityPrompt"), owner)
check(shelvesOpened == 2, "client teardown disconnects Shelves prompt routing")
prompts.PromptTriggered:fire(replacementShopPrompt, owner)
check(shopOpened == 4, "client teardown disconnects Shop prompt routing")
input.TouchEnabled, input.MouseEnabled = true, false
local mobile = Interaction.create(function() end)
local mobileText = replacement.fixture.model
	:FindFirstChild("CollectSignFace")
	:FindFirstChild("CollectSign")
	:FindFirstChild("Instruction")
check(
	string.find(mobileText.Text, "Step on a Plate or Tap its Figure", 1, true),
	"touch-only initial device wording"
)
mobile.destroy()
Plot.destroy(replacement)
Plot.destroy(other)
check(Engine.connections == 0, "all plot and client connections released")
print("PASS: " .. checks .. " Display interaction checks (engine shim)")
