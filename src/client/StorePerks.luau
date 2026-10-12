--!strict
local Kit = require(script.Parent.UIKit)
local Style = require(script.Parent.UIStyle)
local Scope = require(script.Parent.UIScope)
local Catalog = require(script.Parent.StoreCatalog)
local Presentation = require(script.Parent.StorePresentation)
local GuiService = game:GetService("GuiService")
local Perks = {}
export type Panel = {
	root: Frame,
	update: (Presentation.Input) -> (),
	tick: (number) -> (),
	layout: (number, boolean) -> number,
	empty: () -> boolean,
}
type Row = {
	root: Frame,
	title: TextLabel,
	note: TextLabel,
	action: TextButton,
	bar: Frame?,
	timer: Presentation.Timer?,
}

function Perks.create(parent: Instance, owner: Scope.Scope, open: (string) -> ()): Panel
	local root = Kit.frame(parent, "PerksSections")
	local scope = Scope.create()
	owner.add(function()
		scope.destroy()
	end)
	local rows: { Row } = {}
	local labels: { TextLabel } = {}
	local entries: { GuiObject } = {}
	local width, phone = 0, false
	local function heading(text: string)
		local label = Kit.text(root, "PerksHeading", text, 18, Style.display())
		table.insert(labels, label)
		table.insert(entries, label)
	end
	local function row(name: string, title: string, note: string, action: string, key: string): Row
		local frame = Kit.frame(root, name, Style.white)
		Kit.corner(frame, 16)
		Kit.stroke(frame, Style.ink, Style.outlineSmall)
		local caption = Kit.text(frame, "Title", title, 17, Style.display())
		caption.TextWrapped, caption.TextTruncate = true, Enum.TextTruncate.None
		local detail =
			Kit.text(frame, "Status", note, 14, Style.body(Enum.FontWeight.ExtraBold), Style.muted)
		detail.TextWrapped, detail.TextTruncate = true, Enum.TextTruncate.None
		detail.TextYAlignment = Enum.TextYAlignment.Top
		local button = Instance.new("TextButton")
		button.Name, button.Text, button.AutoButtonColor = "Details", action, false
		button.FontFace, button.TextSize = Style.display(), 16
		button.BackgroundColor3, button.TextColor3, button.BorderSizePixel =
			Style.violet, Style.white, 0
		button:SetAttribute("AccessibleName", title .. " details")
		button.Parent = frame
		Kit.corner(button, 12)
		Kit.stroke(button, Style.ink, Style.outlineSmall)
		scope.connect(button.Activated, function()
			open(key)
		end)
		local made: Row = { root = frame, title = caption, note = detail, action = button }
		table.insert(rows, made)
		table.insert(entries, frame)
		return made
	end
	local function arrange(): number
		local y = 0
		for _, entry in entries do
			local height = if entry:IsA("TextLabel") then 32 else 210
			Kit.rect(entry, 0, y, width, height)
			y += height + 12
		end
		for _, made in rows do
			Kit.rect(made.title, 12, 8, width - 24, 44)
			Kit.rect(made.note, 12, 54, width - 24, 90)
			Kit.rect(made.action, 12, 154, math.max(44, width - 24), 44)
			made.title.TextSize = if phone then 16 else 18
			if made.bar then
				Kit.rect(made.bar, 12, 147, width - 24, 4)
			end
		end
		root.Size = UDim2.fromOffset(width, y)
		return y
	end
	local function tick(now: number)
		for _, made in rows do
			local timer = made.timer
			if timer then
				made.note.Text = Presentation.remaining(timer, now)
					.. " · Ends "
					.. timer.endText
					.. "\nWall time continues offline."
					.. (if timer.suppressed then " Effect unavailable for your account." else "")
				if made.bar then
					local fraction = math.clamp(
						(timer.endsAt - now) / math.max(1, timer.endsAt - timer.startsAt),
						0,
						1
					)
					made.bar.Size = UDim2.fromOffset((width - 24) * fraction, 4)
				end
			end
		end
	end
	return {
		root = root,
		empty = function()
			return #rows == 0
		end,
		tick = tick,
		layout = function(nextWidth: number, nextPhone: boolean): number
			width, phone = nextWidth, nextPhone
			return arrange()
		end,
		update = function(input: Presentation.Input)
			local selected = GuiService.SelectedObject
			local restore = if selected
					and selected:IsDescendantOf(root)
					and selected.Parent
				then selected.Parent.Name
				else nil
			scope.destroy()
			scope = Scope.create()
			for _, entry in entries do
				entry:Destroy()
			end
			table.clear(rows)
			table.clear(labels)
			table.clear(entries)
			if #input.timers > 0 then
				heading("Active now")
				for _, timer in input.timers do
					local made =
						row("Timer_" .. timer.key, timer.label, "", "Timer details", timer.key)
					made.timer = timer
					made.bar = Kit.frame(made.root, "TimerBar", Style.mint)
				end
			end
			if #input.tokens > 0 then
				heading("Ready to activate")
				for _, token in input.tokens do
					local product = Catalog.products[token.product]
					row(
						"Token_" .. token.key,
						`{product.name} · ×{token.count} · {token.minutes} min`,
						token.activation
							.. "\nConfirm activation to start its clock; the timer continues offline.",
						"Activation details",
						token.product
					)
				end
			end
			local arriving = false
			for key in Catalog.products do
				if Presentation.view(input, key).pending then
					if not arriving then
						heading("Arriving")
						arriving = true
					end
					local view = Presentation.view(input, key)
					row(
						"Arriving_" .. key,
						Catalog.products[key].name .. " · " .. view.stamp,
						"Confirmation pending. Don't purchase again to retry. You can keep playing.",
						"Recovery details",
						key
					)
				end
			end
			local owned = false
			for _, tab in { "featured", "upgrades" } do
				local section = Catalog.sections[Catalog.tab(tab)]
				local keys = table.clone(section.cards)
				if section.hero then
					table.insert(keys, section.hero)
				end
				if section.tiers then
					for _, key in section.tiers do
						table.insert(keys, key)
					end
				end
				for _, key in keys do
					local offer = Presentation.offer(input, key)
					if
						(offer.availability ~= "owned" and offer.availability ~= "claimed")
						or root:FindFirstChild("Owned_" .. key)
					then
						continue
					end
					if not owned then
						heading("Owned")
						owned = true
					end
					local note = Presentation.view(input, key).note
					if key == "autoOpen" and input.automation then
						local auto = input.automation
						note =
							`{auto.status} · {auto.collection} · {auto.completed}/{auto.count}\nReserve {auto.reserve} Coins · spends up to {auto.spend} Coins. {auto.reason or ""}`
					elseif key == "autoCollect" then
						note ..= " Collects once per second. Pauses for the Welcome collecting lesson and wallet/storage limits."
					elseif key == "speed" then
						note ..= " Selected speed: " .. (if offer.toggle then "48" else "36")
					end
					row(
						"Owned_" .. key,
						Catalog.products[key].name .. " · " .. Presentation.view(input, key).stamp,
						note,
						if key == "autoOpen" then "Set up" else "Settings & details",
						key
					)
				end
			end
			arrange()
			tick(input.now)
			if restore and root.Visible then
				local replacement = root:FindFirstChild(restore)
				local action = if replacement then replacement:FindFirstChild("Details") else nil
				if action and action:IsA("GuiButton") then
					GuiService.SelectedObject = action
				end
			end
		end,
	}
end

return Perks
