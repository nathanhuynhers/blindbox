--!strict
-- A presentation clock only: no transaction, inventory or random-roll behavior.
local OpeningState = {}
export type Phase =
	"Enter"
	| "Anticipation"
	| "Shake"
	| "Await"
	| "Open"
	| "Silhouette"
	| "Reveal"
	| "Result"
	| "Closing"
	| "Done"
export type Timing = {
	anticipation: number,
	shake: number,
	opening: number,
	silhouette: number,
	reveal: number,
}
export type State = { phase: Phase, elapsed: number, reduced: boolean, timing: Timing }

local nextPhase: { [Phase]: Phase } = {
	Enter = "Anticipation",
	Anticipation = "Shake",
	Shake = "Await",
	Open = "Silhouette",
	Silhouette = "Reveal",
	Reveal = "Result",
	Closing = "Done",
}

function OpeningState.create(timing: Timing, reduced: boolean, direct: boolean): State
	return {
		phase = if direct then "Silhouette" else "Enter",
		elapsed = 0,
		reduced = reduced,
		timing = timing,
	}
end

function OpeningState.duration(state: State): number
	local phase = state.phase
	if phase == "Enter" then
		return if state.reduced then 0.2 else 0.55
	end
	if phase == "Anticipation" then
		return if state.reduced then 0.25 else state.timing.anticipation
	end
	if phase == "Shake" then
		return if state.reduced then 0.15 else state.timing.shake
	end
	if phase == "Open" then
		return if state.reduced then 0.2 else state.timing.opening
	end
	if phase == "Silhouette" then
		return if state.reduced then 0.2 else state.timing.silhouette
	end
	if phase == "Reveal" then
		return if state.reduced then 0.2 else state.timing.reveal
	end
	if phase == "Closing" then
		return if state.reduced then 0.15 else 0.25
	end
	return math.huge
end

function OpeningState.progress(state: State): number
	return math.clamp(state.elapsed / OpeningState.duration(state), 0, 1)
end

function OpeningState.advance(state: State, delta: number): boolean
	if state.phase == "Done" then
		return false
	end
	state.elapsed += math.max(0, delta)
	local following: Phase? = nextPhase[state.phase]
	if following and state.elapsed >= OpeningState.duration(state) then
		state.phase = following
		state.elapsed = 0
		return true
	end
	return false
end

function OpeningState.skip(state: State): boolean
	if
		state.phase == "Enter"
		or state.phase == "Result"
		or state.phase == "Closing"
		or state.phase == "Done"
	then
		return false
	end
	state.phase = "Result"
	state.elapsed = 0
	return true
end

function OpeningState.activate(state: State): boolean
	if state.phase == "Await" then
		state.phase = "Open"
	elseif state.phase == "Result" and state.elapsed >= 0.35 then
		state.phase = "Closing"
	else
		return false
	end
	state.elapsed = 0
	return true
end

function OpeningState.animated(state: State): boolean
	return state.phase ~= "Await"
		and state.phase ~= "Done"
		and (state.phase ~= "Result" or state.elapsed < 0.35)
end

function OpeningState.cancel(state: State)
	state.phase = "Done"
	state.elapsed = 0
end

return OpeningState
