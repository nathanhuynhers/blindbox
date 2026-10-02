--!strict
-- The three global leaderboard stats, derived only from authoritative server state.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Rules = require(script.Parent.Rules)

export type Stat = { key: string, title: string }

local Stats = {}

Stats.list = table.freeze({
	table.freeze({ key = "figures", title = "MOST FIGURES" }),
	table.freeze({ key = "rate", title = "TOP COINS / SEC" }),
	table.freeze({ key = "boxes", title = "MOST BOXES OPENED" }),
}) :: { Stat }

function Stats.keys(): { string }
	local keys = {}
	for _, stat in Stats.list do
		table.insert(keys, stat.key)
	end
	return keys
end

-- Coins/sec is stored in hundredths because ordered data stores only hold integers.
function Stats.of(state: Types.State): { [string]: number }
	local figures = 0
	for _ in state.discovered do
		figures += 1
	end
	return {
		figures = figures,
		rate = math.floor(Rules.rate(state) * 100 + 0.5),
		boxes = state.boxesOpened,
	}
end

local function grouped(value: number): string
	local text = tostring(math.floor(value))
	local result = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	return if string.sub(result, 1, 1) == "," then string.sub(result, 2) else result
end

function Stats.format(stat: string, value: number): string
	if stat == "rate" then
		return string.format("%g/s", value / 100)
	end
	return grouped(value)
end

return Stats
