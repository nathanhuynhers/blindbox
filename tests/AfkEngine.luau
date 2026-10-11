--!strict
-- Engine boundaries only: real storage, persistence, idle clock, controller and UI run unchanged.
local UI = require("./UIEngine")
local E = { now = 0, epoch = 1000000, database = {}, writes = 0, before = 0, after = 0, ids = 0 }
E.Enum = UI.Enum
E.os = {
	clock = function()
		return E.now
	end,
	time = function()
		return math.floor(E.epoch + E.now)
	end,
}
E.warn = function(...) end
E.task = {
	spawn = function(work, ...)
		work(...)
	end,
	wait = function(seconds)
		E.now += seconds
		if E.onWait then
			E.onWait()
		end
	end,
}
local store = {}
function store:UpdateAsync(key, transform)
	E.writes += 1
	if E.onUpdate then
		E.onUpdate()
	end
	if E.before > 0 then
		E.before -= 1
		error("failure before commit")
	end
	transform(E.database[key]) -- Roblox may re-run transforms.
	local result = transform(E.database[key])
	if result then
		E.database[key] = result
	end
	if E.after > 0 then
		E.after -= 1
		error("response lost after commit")
	end
	return result
end
E.store = store
UI.services.DataStoreService = {
	GetDataStore = function()
		return store
	end,
}
UI.services.HttpService = {
	GenerateGUID = function()
		E.ids += 1
		return "test-token-" .. E.ids
	end,
}
UI.services.RunService = {
	IsStudio = function()
		return false
	end,
	Heartbeat = UI.signal(),
}
UI.services.ServerScriptService = UI.Instance.new("ServerScriptService")
local input = UI.services.UserInputService
input.InputBegan, input.WindowFocused = UI.signal(), UI.signal()
local player = UI.services.Players.LocalPlayer
player.Idled, player.CharacterAdded, player.CharacterRemoving =
	UI.signal(), UI.signal(), UI.signal()
UI.services.TeleportService = {
	SetTeleportGui = function(_, gui)
		E.loading = gui
	end,
	GetArrivingTeleportGui = function()
		return E.arriving
	end,
	GetLocalPlayerTeleportData = function()
		return E.arrivalData
	end,
}
-- Add Clone to the existing UI shim; properties/connections stay engine boundaries.
local make = UI.Instance.new
function UI.Instance.new(class)
	local node = make(class)
	function node:Clone()
		local copy = UI.Instance.new(self.ClassName)
		for key, value in rawget(self, "__props") do
			if key ~= "Parent" and key ~= "Destroying" and type(value) ~= "function" then
				copy[key] = value
			end
		end
		for _, child in self:GetChildren() do
			child:Clone().Parent = copy
		end
		return copy
	end
	return node
end
E.game, E.ui = UI.game, UI
return E
