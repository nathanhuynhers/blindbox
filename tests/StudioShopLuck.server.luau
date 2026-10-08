--!strict
-- Unmapped Studio fixture for a freshly built, unpublished place only.
-- In Edit, disable ServerScriptService.Server, insert this file as a sibling Script, then Play.
-- In the SERVER Command Bar: ServerStorage.ShopLuckFixture:Invoke("Zero" / "Mid" / "Boosted" /
-- "LegendaryDue" / "MythicalDue" / "BothDue" / "NearDue" / "LegendaryHit" / "MythicalHit").
-- In the CLIENT Command Bar afterwards:
-- ReplicatedStorage.Remotes.RequestState:FireServer(). The ordinary Shop consumes that snapshot.
-- Open Shop and choose Tender Echoes. Stop Play to discard all changes. Never save this fixture.
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
assert(RunService:IsStudio() and game.PlaceId == 0, "Use a fresh local Rojo build")
local server = ServerScriptService:WaitForChild("Server") :: Script
assert(server.Disabled, "Disable Server before installing the preview bootstrap")
local Storage = require(server.Storage)
local Economy = require(server.Economy)
local Rules = require(server.Rules)
local CollectionEconomy = require(server.CollectionEconomy)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local owners: { [number]: Storage.Session } = {}
local original = Storage.open
Storage.open = function(userId: number): (Storage.Session?, string)
	local storage, reason = original(userId)
	if storage then
		assert(storage.handle == nil and storage.status == "Studio preview - not saved", "Preview storage only")
		storage.state.step = 7
		storage.state.coins = 10000000
		owners[userId] = storage
	end
	return storage, reason
end
local control = Instance.new("BindableFunction")
control.Name = "ShopLuckFixture"
control.OnInvoke = function(name: string)
	local player = assert(Players:GetPlayers()[1], "Wait for the local player")
	local state = assert(owners[player.UserId], "Wait for the preview profile").state
	local stages = {
		Zero = {0, 0}, Mid = {20, 150}, Boosted = {90, 780},
		LegendaryDue = {2020, 780}, MythicalDue = {90, 66900}, BothDue = {2020, 66900},
		NearDue = {2018, 0}, BeyondOldCaps = {200, 2000},
	}
	local stage = stages[name]
	if stage then
		state.pityByGroup.echo = {legendaryDryRolls = stage[1], mythicalDryRolls = stage[2]}
		state.revision += 1
	else
		assert(name == "LegendaryHit" or name == "MythicalHit", "Unknown preview state")
		local odds = CollectionEconomy.buckets("echo", state.pityByGroup)
		local roll = if name == "MythicalHit" then 0.999999
			else 1 - (odds.Mythical + odds.Legendary / 2) / 100
		local intent: Types.Intent = {action = "Buy", id = "preview", revision = state.revision, choice = "echo"}
		local ok, reason = Rules.mutate(state, intent, roll, nil, os.clock())
		assert(ok, reason)
	end
	return {progress = CollectionEconomy.pityProgress(state.pityByGroup).echo,
		odds = CollectionEconomy.buckets("echo", state.pityByGroup)}
end
control.Parent = ServerStorage
server.Disabled = false
print("Shop luck fixture ready: server-owned preview states, ordinary private snapshots, no saved data")
