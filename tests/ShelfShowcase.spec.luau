--!strict
-- Real shared scheduler step, world render, lifecycle handshake and Transactions;
-- only Instances/players are doubled. The delayed transport is driven explicitly.
local Engine = require("./PlotEngine")
local Plot = require("./PlayerPlot")
local Showcase = require("./ShelfShowcase")
local Editor = require("./ShelfEditor")
local Shelves = require("./Shelves")
local Config = require("./ShelfConfig")
local Transactions = require("./Transactions")
local checks = 0
local function check(value: boolean, message: string)
	assert(value, message)
	checks += 1
end
local owner = Engine.player(1)
local visitor = Engine.player(2)
local plot = Plot.create(owner, 1)
local transaction = Transactions.new(0)
local state = transaction.state
owner.Character:PivotTo(plot.transform * Engine.CFrame.new(0, 3, 0))
visitor.Character:PivotTo(plot.transform * Engine.CFrame.new(0, 3, 0))
Plot.render(plot, state)
-- Zero units (defensive runtime empty fixture), then the normal empty starting trio.
local starting = state.shelves
state.shelves = { units = {} }
check(not Plot.stepShowcase(plot, state, 0), "empty shelves stay still")
state.shelves = starting
check(not Plot.stepShowcase(plot, state, 100), "exactly three empty units stay still")
check(
	plot.showcase.nextStep == nil and plot.view.revision == 0,
	"no scheduled work/revisions for non-overflow"
)
Shelves.add(state.shelves)
Plot.render(plot, state)
check(not Plot.stepShowcase(plot, state, 50), "auto-scroll starts off")
check(not Plot.stepShowcase(plot, state, 99), "off overflow never steps")
check(plot.collection.autoLabel.Text == "AUTO: OFF", "sign shows off by default")
visitor.Character:PivotTo(plot.transform * Engine.CFrame.new(100, 3, 0))
check(not Plot.toggleShowcase(plot, visitor, 99.5), "distant toggle rejected")
visitor.Character:PivotTo(plot.transform * Engine.CFrame.new(0, 3, 0))
check(Plot.toggleShowcase(plot, owner, 99.9), "toggle switches auto on")
check(not Plot.toggleShowcase(plot, visitor, 100), "toggle cooldown bounds repeats")
check(plot.collection.autoLabel.Text == "AUTO: ON", "sign shows on")
check(not Plot.stepShowcase(plot, state, 100), "four units start a full viewing interval")
check(not Plot.stepShowcase(plot, state, 106.9), "slow configurable cadence")
check(Plot.stepShowcase(plot, state, 107), "four units auto advance")
check(plot.view.startIndex == 2 and plot.view.revision == 1, "one unit and one revision per step")
check(
	plot.physicalShelves[1]:GetAttribute("ShelfId") == "shelf:2",
	"auto renders physical unit attributes"
)
check(
	plot.model:GetAttribute("ShelfCarouselRevision") == 1,
	"auto renders shared revision attribute"
)
for step = 2, 4 do
	check(
		Plot.stepShowcase(plot, state, 100 + step * Config.showcaseStepSeconds),
		"four-unit continuous loop"
	)
end
check(plot.view.startIndex == 1, "four units wrap to start")
check(state.revision == 0, "showcase never changes persistent revision")

check(Plot.turn(plot, visitor, state, -1, 129), "visitor arrow still navigates")
check(
	not Plot.turn(plot, owner, state, 1, 129.1),
	"owner arrow retains shared half-second cooldown"
)
check(not Plot.stepShowcase(plot, state, 139), "cooldown arrow press extends manual idle")
check(Plot.stepShowcase(plot, state, 139.1), "resumes after latest ten-second idle")
visitor.Character:PivotTo(plot.transform * Engine.CFrame.new(100, 3, 0))
check(not Plot.turn(plot, visitor, state, 1, 140), "distant visitor arrow rejected")
check(plot.showcase.idleUntil == 139.1, "invalid arrow does not postpone auto")
owner.Character:PivotTo(plot.transform * Engine.CFrame.new(100, 3, 0))
local revision = plot.view.revision
check(not Plot.stepShowcase(plot, state, 147), "no nearby viewers pauses rendering")
check(plot.view.revision == revision, "unseen shelves retain view revision")
owner.Character:PivotTo(plot.transform * Engine.CFrame.new(0, 3, 0))
check(not Plot.stepShowcase(plot, state, 153), "viewer return waits the interval")
check(Plot.stepShowcase(plot, state, 154), "nearby owner resumes showcase")

-- Exact edit/auto race: opening signal is in flight when the timer steps. The
-- client cannot edit until a snapshot acknowledges the hold and current revision.
local signals = {}
local editor = Editor.create(function(isOpen, token)
	table.insert(signals, { isOpen = isOpen, token = token })
end)
editor.shown(true)
check(not editor.ready(), "edits blocked before server acknowledgement")
check(Plot.stepShowcase(plot, state, 161), "timer may step before opening arrives")
local open = signals[1]
check(
	Showcase.editor(plot.showcase, open.isOpen, open.token, 161.1),
	"server acquires owner editor hold"
)
local acknowledgedView = Shelves.publicView(state.shelves, plot.view)
editor.receive(plot.showcase.editorToken)
check(editor.ready(), "ack enables editing with latest view")
state.owned["grove.star"], state.discovered["grove.star"] = 1, true
local intent = {
	id = "edit:auto-race",
	action = "ShelfPlace",
	figure = "grove.star",
	shelfId = acknowledgedView.visible[1].id,
	shelfSlotId = Config.slots()[1],
	carouselRevision = acknowledgedView.carouselRevision,
	revision = state.revision,
}
editor.pending(true)
editor.shown(false)
check(#signals == 1, "closing retains pause while edit is in flight")
check(not Plot.stepShowcase(plot, state, 180), "due auto cannot invalidate in-flight edit")
local reply = Transactions.process(transaction, intent, 180, true, 0, 1, Plot.access(plot, owner))
check(
	reply ~= nil and reply.ok,
	"edit crossing auto deadline succeeds with captured carousel revision"
)
check(
	state.shelves.units[acknowledgedView.visible[1].index].placements[Config.slots()[1]]
		== "grove.star",
	"intended unit edited"
)
check(not Plot.stepShowcase(plot, state, 200), "dropped reply retains hold during recovery")
local retry, changed =
	Transactions.process(transaction, intent, 200, true, 0, 1, Plot.access(plot, owner))
check(retry ~= nil and retry.ok and not changed, "retry recovers same successful receipt")
editor.pending(false)
check(#signals == 2 and not signals[2].isOpen, "only acknowledgement sends close")
check(not Plot.stepShowcase(plot, state, 201), "delayed close transport still holds pause")
check(Showcase.editor(plot.showcase, false, open.token, 202), "close releases server hold")
check(not Plot.stepShowcase(plot, state, 204.9), "short idle after acknowledged close")
check(Plot.stepShowcase(plot, state, 205), "resumes after editor idle")

editor.shown(true)
editor.receive(open.token)
check(not editor.ready(), "reopen ignores old acknowledgement")
check(Showcase.editor(plot.showcase, true, signals[3].token, 206), "reopen acquires new hold")
check(
	not Showcase.editor(plot.showcase, false, open.token, 207),
	"stale close cannot release newer editor"
)
check(not Showcase.editor(plot.showcase, true, 0 / 0, 207), "NaN token rejected")
check(not Showcase.editor(plot.showcase, true, math.huge, 207), "infinite token rejected")
check(not Showcase.editor(plot.showcase, "open", 4, 207), "wrong open type rejected")
check(not Showcase.editor(plot.showcase, true, 3.5, 207), "fractional token rejected")
check(not Showcase.editor(plot.showcase, true, 1000000001, 207), "oversized token rejected")
check(not Plot.stepShowcase(plot, state, 250), "editor stays paused without timeout")
Showcase.browse(plot.showcase, 249)
editor.destroy()
local close = signals[#signals]
Showcase.editor(plot.showcase, close.isOpen, close.token, 250)
check(
	not Plot.stepShowcase(plot, state, 258.9),
	"editor close preserves the longer manual browsing idle"
)
check(Plot.stepShowcase(plot, state, 259), "UI teardown releases idle editor hold")

-- Capacity limit: bounded projection and full cycle, with no persistent mutation.
while #state.shelves.units < Config.maxShelfUnits do
	Shelves.add(state.shelves)
end
local start = plot.view.startIndex
for index = 1, Config.maxShelfUnits do
	check(
		Plot.stepShowcase(plot, state, 259 + index * Config.showcaseStepSeconds),
		"many units continue one step per interval"
	)
	check(
		#Shelves.publicView(state.shelves, plot.view).visible == 3,
		"many units project only three"
	)
end
check(plot.view.startIndex == start, "many units complete full loop")
check(state.revision == 1, "auto leaves edit/profile state unchanged")
check(Plot.toggleShowcase(plot, owner, 2000), "toggle switches auto off")
check(not Plot.stepShowcase(plot, state, 3000), "toggled off never steps")
check(plot.collection.autoLabel.Text == "AUTO: OFF", "sign shows off again")
Plot.destroy(plot)
check(
	not plot.showcase.active and plot.showcase.editorToken == nil and plot.showcase.nextStep == nil,
	"plot teardown clears scheduler state"
)
check(not Plot.stepShowcase(plot, state, 9999), "destroyed plot cannot step")
local replacement = Plot.create(owner, 1)
check(
	replacement.view.revision == 0 and replacement.showcase.editorToken == nil,
	"new plot starts independent view/hold"
)
replacement.ownerId = visitor.UserId
check(
	not Plot.stepShowcase(replacement, state, 9999) and not replacement.showcase.active,
	"ownership change disables old controller"
)
Plot.destroy(replacement)
print(
	"PASS: "
		.. checks
		.. " showcase cadence, pauses, delayed-edit race, projection and teardown checks"
)
