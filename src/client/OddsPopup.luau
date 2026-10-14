--!strict
-- Owner-only itemized probabilities, refreshed from the authoritative snapshot.
local Players = game:GetService("Players")
local Actions = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Kit = require(script.Parent.UIKit)
local Style = require(script.Parent.UIStyle)
local Button = require(script.Parent.UIButton)
local Scope = require(script.Parent.UIScope)
local State = require(script.Parent.UIState)
local Popup = {}
export type Controller = {
	show: (string) -> (),
	update: (Types.Snapshot) -> (),
	close: () -> (),
	destroy: () -> (),
}
function Popup.create(effects: () -> boolean): Controller
	local snapshot: Types.Snapshot? = nil
	local finish: (() -> ())? = nil
	local render: (() -> ())? = nil
	local function close()
		local done = finish
		finish, render = nil, nil
		if done then
			done()
		end
	end
	local function show(collection: string)
		close()
		if not snapshot or not Catalog.collectionIds[collection] then
			return
		end
		local scope = Scope.create()
		local gui = Instance.new("ScreenGui")
		gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "BoxOdds", false, 110
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local backdrop = Instance.new("TextButton")
		backdrop.Name, backdrop.Text, backdrop.AutoButtonColor = "Backdrop", "", false
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.BackgroundColor3, backdrop.BackgroundTransparency =
			Style.dim, Style.dimTransparency
		backdrop.BorderSizePixel, backdrop.Selectable, backdrop.Modal = 0, false, true
		backdrop.Parent = gui
		scope.connect(backdrop.Activated, close)
		local card = Kit.card(gui, "Card", Style.surface, 20, 5)
		local title = Kit.text(
			card.face,
			"Title",
			State.collectionName(collection) .. " box odds",
			22,
			Style.display()
		)
		local note = Kit.text(
			card.face,
			"Note",
			"Current Luck and pity included. Chances update after each opening.",
			13,
			Style.body(),
			Style.muted
		)
		note.TextWrapped, note.TextTruncate = true, Enum.TextTruncate.None
		local list = Kit.canvas(card.face, "Outcomes")
		local rows: { TextLabel } = {}
		for _, id in State.members(collection) do
			local row = Kit.text(list, id, "", 16, Style.body(Enum.FontWeight.Bold))
			row.TextTruncate, row.TextWrapped = Enum.TextTruncate.None, true
			table.insert(rows, row)
		end
		local done = Button.create(
			card.face,
			"Close",
			{ text = "Done", variant = "white", size = 18 },
			scope,
			effects,
			close
		)
		local function draw()
			local state = snapshot
			if not state then
				return
			end
			for index, id in State.members(collection) do
				-- Keep enough significant digits to disclose tiny, nonzero probabilities.
				rows[index].Text = Catalog.byId[id].name
					.. " — "
					.. string.format("%.7g%%", State.figureOdds(state, id))
			end
		end
		local function layout()
			local size = gui.AbsoluteSize
			local width, height = math.min(620, size.X - 24), math.min(520, size.Y - 24)
			Kit.rect(card.root, (size.X - width) / 2, (size.Y - height - 5) / 2, width, height)
			Kit.rect(title, 16, 12, width - 32, 28)
			Kit.rect(note, 16, 44, width - 32, 36)
			Kit.rect(list, 16, 86, width - 32, height - 158)
			for index, row in rows do
				Kit.rect(row, 0, (index - 1) * 44, width - 48, 44)
			end
			list.CanvasSize = UDim2.fromOffset(0, #rows * 44)
			Kit.rect(done.button, 16, height - 60, width - 32, 44)
		end
		scope.connect(gui:GetPropertyChangedSignal("AbsoluteSize"), layout)
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		layout()
		draw()
		local previous = GuiService.SelectedObject
		if string.find(Input:GetLastInputType().Name, "Gamepad", 1, true) then
			GuiService.SelectedObject = done.button
		end
		Actions:BindActionAtPriority("BoxOddsBack", function(_, state)
			if state == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, 4000, Enum.KeyCode.ButtonB)
		render = draw
		finish = function()
			Actions:UnbindAction("BoxOddsBack")
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = if previous and previous.Parent then previous else nil
			end
			scope.destroy()
			gui:Destroy()
		end
	end
	return {
		show = show,
		update = function(state)
			snapshot = state
			if render then
				render()
			end
		end,
		close = close,
		destroy = close,
	}
end
return Popup
