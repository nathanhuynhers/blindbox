--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Scope = require(script.Parent.UIScope)
export type Context = {
	scope: Scope.Scope,
	effects: () -> boolean,
	snapshot: () -> Types.Snapshot?,
	canAct: () -> boolean,
	send: (string, string?, number?, string?) -> (),
	visit: (number) -> (),
	navigate: (string) -> (),
	inspect: (string) -> (),
	place: (string) -> (),
	pick: (number) -> (),
	message: (string) -> (),
}
export type Screen = { root: GuiObject, update: (Types.Snapshot) -> (), back: (() -> boolean)? }
return {}
