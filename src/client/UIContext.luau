--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Scope = require(script.Parent.UIScope)
-- Optional destination details when one screen opens another.
-- `tab` picks the Robux Store tab (StoreCatalog.Tab).
export type Route = {
	collection: string?,
	figure: string?,
	slot: number?,
	placing: string?,
	tab: string?,
}
export type Context = {
	scope: Scope.Scope,
	effects: () -> boolean,
	-- Design units per screen pixel ratio (desktop UIScale); 1 on phone.
	scale: () -> number,
	snapshot: () -> Types.Snapshot?,
	canAct: () -> boolean,
	-- action, figure, slot, choice, volume (SetVolume only)
	send: (string, string?, number?, string?, number?) -> (),
	navigate: (string, Route?) -> (),
	close: () -> (),
	message: (string) -> (),
}
export type Screen = {
	root: GuiObject,
	update: (Types.Snapshot) -> (),
	layout: (width: number, height: number, phone: boolean) -> (),
	back: (() -> boolean)?,
	route: ((Route?) -> ())?,
	shown: ((boolean) -> ())?,
	-- Gamepad L1/R1 inside a screen with its own tabs (the Robux Store); else dock pages.
	cycle: ((number) -> ())?,
}
return {}
