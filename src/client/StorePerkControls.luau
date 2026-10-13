--!strict
-- Approved controls use the existing dedicated backend paths. Fixtures remain isolated.
local Kit = require(script.Parent.UIKit)
local Style = require(script.Parent.UIStyle)
local Button = require(script.Parent.UIButton)
local Scope = require(script.Parent.UIScope)
local Presentation = require(script.Parent.StorePresentation)
local Catalog = require(script.Parent.StoreCatalog)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Controls = {}

function Controls.create(
	parent: Instance,
	scope: Scope.Scope,
	effects: () -> boolean,
	input: Presentation.Input,
	key: string,
	commerce: Context.Commerce?,
	setup: (() -> ())?
): Frame?
	local auto = key == "autoOpen"
	local toggle = key == "autoCollect" or key == "speed"
	local boost = key == "boostCoins"
		or key == "boostLuck2"
		or key == "boostLuck4"
		or key == "boostCombo"
	if not auto and not toggle and not boost then
		return nil
	end
	local root = Kit.frame(parent, "PerkControls")
	root.Size = UDim2.new(1, -8, 0, if auto then 260 else 158)
	local note =
		Kit.text(root, "SetupStatus", "", 14, Style.body(Enum.FontWeight.ExtraBold), Style.muted)
	note.Size = UDim2.new(1, 0, 0, 66)
	note.TextWrapped, note.TextTruncate = true, Enum.TextTruncate.None
	note.TextYAlignment = Enum.TextYAlignment.Top
	local owned = Presentation.offer(input, key).availability == "owned"
	local allowed = input.fixture and owned and not input.promptActive
	if auto and not input.fixture then
		root.Size = UDim2.new(1, -8, 0, 158)
		note.Text =
			"Choose a collection, box budget (1–100) and Coin reserve in the Coin Shop. Stop remains available during openings."
		local action = Button.create(
			root,
			"AutoSetup",
			{ variant = "violet", text = "Set up in Coin Shop", size = 17 },
			scope,
			effects,
			function()
				if setup then
					setup()
				end
			end
		)
		action.button.Position, action.button.Size = UDim2.fromOffset(0, 74), UDim2.new(1, 0, 0, 44)
		action.set("Set up in Coin Shop", commerce ~= nil)
		return root
	end
	if auto then
		local count = if input.automation then input.automation.count else 10
		local reserve = false
		local running = input.automation ~= nil and input.automation.status == "running"
		local countText = Kit.text(root, "Count", "", 18, Style.display())
		local cost = Kit.text(root, "Spend", "", 13, Style.body(), Style.muted)
		cost.Position, cost.Size = UDim2.fromOffset(0, 228), UDim2.new(1, 0, 0, 32)
		cost.TextWrapped = true
		countText.Position, countText.Size = UDim2.new(0.25, 0, 0, 72), UDim2.new(0.5, 0, 0, 44)
		countText.TextXAlignment = Enum.TextXAlignment.Center
		local function paint()
			countText.Text = tostring(count) .. " boxes"
			local unitPrice = if input.automation then input.automation.boxPrice else nil
			cost.Text = if unitPrice
				then "Spends up to " .. State.number(count * unitPrice) .. " Coins (preview only)."
				else "Choose collection and reserve in the Coin Shop. Cost needs a verified box price."
			note.Text = if running
				then "PREVIEW ONLY · Auto Open running. No Coins are spent or boxes opened."
				else "How many boxes (1–100). Stops on Stop, completion, insufficient Coins or leaving. Start is disabled outside fixtures."
		end
		local minus = Button.create(
			root,
			"CountMinus",
			{ variant = "white", text = "−", size = 20 },
			scope,
			effects,
			function()
				count = math.max(1, count - 1)
				paint()
			end
		)
		local plus = Button.create(
			root,
			"CountPlus",
			{ variant = "white", text = "+", size = 20 },
			scope,
			effects,
			function()
				count = math.min(100, count + 1)
				paint()
			end
		)
		minus.button.Position, minus.button.Size =
			UDim2.fromOffset(0, 72), UDim2.new(0.25, -4, 0, 44)
		plus.button.Position, plus.button.Size =
			UDim2.new(0.75, 4, 0, 72), UDim2.new(0.25, -4, 0, 44)
		minus.set("−", allowed and not running)
		plus.set("+", allowed and not running)
		local keep: Button.Button
		keep = Button.create(
			root,
			"Reserve",
			{ variant = "white", text = "Keep a reserve: OFF", size = 16 },
			scope,
			effects,
			function()
				reserve = not reserve
				keep.set(
					if reserve
						then "Reserve: " .. (if input.automation
							then input.automation.reserve
							else "0") .. " Coins"
						else "Keep a reserve: OFF",
					allowed and not running
				)
			end
		)
		keep.button.Position, keep.button.Size = UDim2.fromOffset(0, 124), UDim2.new(1, 0, 0, 44)
		keep.set("Keep a reserve: OFF", allowed and not running)
		local action: Button.Button
		action = Button.create(
			root,
			"AutoAction",
			{ variant = "violet", text = "Start Auto Open", size = 17 },
			scope,
			effects,
			function()
				running = not running
				action.variant(if running then "ink" else "violet")
				action.set(
					if running then "Stop · Preview" else "Start Auto Open · Preview",
					allowed
				)
				minus.set("−", allowed and not running)
				plus.set("+", allowed and not running)
				keep.set(
					if reserve then "Keep a reserve: ON" else "Keep a reserve: OFF",
					allowed and not running
				)
				paint()
			end
		)
		action.button.Position, action.button.Size =
			UDim2.fromOffset(0, 176), UDim2.new(1, 0, 0, 44)
		action.set(if running then "Stop · Preview" else "Start Auto Open", allowed)
		paint()
	elseif toggle then
		local view = if commerce then commerce.convenience.view() else nil
		allowed = allowed
			or (
				not input.fixture
				and not input.promptActive
				and view ~= nil
				and (
					if key == "speed"
						then view.movementAllowed or view.movementEnabled
						else view.collectAllowed or view.collectEnabled
				)
			)
		local on = Presentation.offer(input, key).toggle == true
		note.Text = if key == "speed"
			then "Choose speed 48 or the free 36. Your confirmed setting appears here."
			else "Collects once per second. Pauses during the Welcome collecting lesson, full wallet and unavailable storage."
		local setting: Button.Button
		setting = Button.create(
			root,
			"Setting",
			{ variant = "violet", text = "", size = 17 },
			scope,
			effects,
			function()
				if not input.fixture and commerce then
					local current = commerce.convenience.view()
					if current then
						if key == "speed" then
							commerce.convenience.movement(not current.movementEnabled)
						else
							commerce.convenience.collect(not current.collectEnabled)
						end
					end
					return
				end
				on = not on
				setting.set(if on then "ON · Preview" else "OFF · Preview", allowed)
			end
		)
		setting.button.Position, setting.button.Size =
			UDim2.fromOffset(0, 74), UDim2.new(1, 0, 0, 44)
		setting.set(if on then "ON" else "OFF", allowed)
	else
		local token: Presentation.Token? = nil
		local tokenIndex = 1
		root.Size = UDim2.new(1, -8, 0, 172)
		note.Size = UDim2.new(1, 0, 0, 104)
		for _, candidate in input.tokens do
			if candidate.product == key and candidate.count > 0 then
				token = candidate
				break
			end
		end
		local confirming = false
		local activation: Button.Button
		activation = Button.create(
			root,
			"Activate",
			{ variant = "violet", text = "Activate", size = 17 },
			scope,
			effects,
			function()
				if confirming then
					if not input.fixture and commerce and token then
						commerce.activate(token.key)
						activation.set("Saving activation…", false)
						return
					end
					note.Text =
						"PREVIEW ONLY · Activation shown. No token was consumed or effect started."
					activation.set("Preview complete", false)
				else
					confirming = true
					note.Text = `Activate {Catalog.products[key].name} for {if token
						then token.minutes
						else 30} minutes? The timer continues while you're offline. Same boosts add time, not strength.`
					activation.set(
						if input.fixture then "Confirm preview activation" else "Confirm activation",
						true
					)
				end
			end
		)
		activation.button.Position, activation.button.Size =
			UDim2.fromOffset(0, 114), UDim2.new(1, 0, 0, 44)
		local ready = (input.fixture or commerce ~= nil)
			and token ~= nil
			and token.activation == "Ready"
			and not input.promptActive
		activation.set("Activate", ready)
		local choices: { Presentation.Token } = {}
		for _, candidate in input.tokens do
			if candidate.product == key and candidate.count > 0 then
				table.insert(choices, candidate)
			end
		end
		if #choices > 1 then
			root.Size = UDim2.new(1, -8, 0, 224)
			local select: Button.Button
			select = Button.create(
				root,
				"ChooseToken",
				{ variant = "white", text = "Choose token length", size = 16 },
				scope,
				effects,
				function()
					tokenIndex = tokenIndex % #choices + 1
					local chosen = choices[tokenIndex]
					token = chosen
					confirming = false
					note.Text =
						`{chosen.minutes} min · {chosen.count} unused · {chosen.activation}`
					activation.set(
						"Activate",
						chosen.activation == "Ready" and not input.promptActive and commerce ~= nil
					)
					select.set(`Selected: {chosen.minutes} min`, true)
				end
			)
			select.button.Position, select.button.Size =
				UDim2.fromOffset(0, 172), UDim2.new(1, 0, 0, 44)
		end
		note.Text = if token
			then token.activation
				.. " · "
				.. token.minutes
				.. " min. "
				.. "Buying grants an unused token; activation starts its wall clock."
			else "No unused token confirmed. Activate after verified delivery; timers continue offline."
	end
	return root
end

return Controls
