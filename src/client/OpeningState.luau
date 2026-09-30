--!strict
-- A presentation clock only. No rolls, spends, grants or server calls.
local State = {}
export type Phase =
	"Enter"
	| "Arrival"
	| "Anticipation"
	| "Charge"
	| "Shake"
	| "Await"
	| "Break"
	| "Flight"
	| "RarityTease"
	| "Impact"
	| "Silhouette"
	| "Reveal"
	| "Result"
	| "Closing"
	| "Done"
export type Timing = {
	anticipation: number,
	charge: number,
	shake: number,
	opening: number,
	flight: number,
	rarityTease: number,
	rarityReduced: number?,
	impact: number,
	silhouette: number,
	reveal: number,
}
export type State = {
	phase: Phase,
	elapsed: number,
	reduced: boolean,
	timing: Timing,
	durations: { [Phase]: number },
	direct: boolean,
	skipped: boolean,
}
State.transition = 0.22
State.arrival = 0.5
State.resultGuard = 0.35
local phaseOrder: { [Phase]: number } = {}
for index, phase in
	{
		"Enter",
		"Arrival",
		"Anticipation",
		"Charge",
		"Shake",
		"Await",
		"Break",
		"Flight",
		"RarityTease",
		"Impact",
		"Silhouette",
		"Reveal",
		"Result",
		"Closing",
		"Done",
	}
do
	phaseOrder[phase :: Phase] = index
end
function State.isForward(previous: Phase?, nextPhase: Phase): boolean
	return previous == nil or phaseOrder[nextPhase] > phaseOrder[previous]
end
local following: { [Phase]: Phase } = {
	Enter = "Arrival",
	Arrival = "Anticipation",
	Anticipation = "Charge",
	Charge = "Shake",
	Shake = "Await",
	Break = "Flight",
	Flight = "RarityTease",
	RarityTease = "Impact",
	Impact = "Silhouette",
	Silhouette = "Reveal",
	Reveal = "Result",
	Closing = "Done",
}
local reducedCaps: { [Phase]: number } = {
	Arrival = 0.2,
	Anticipation = 0.12,
	Charge = 0.22,
	Shake = 0.12,
	Break = 0.2,
	Flight = 0.18,
	RarityTease = 0.3,
	Impact = 0.3,
	Reveal = 0.28,
}
function State.create(timing: Timing, reduced: boolean, direct: boolean): State
	return {
		phase = "Enter",
		elapsed = 0,
		reduced = reduced,
		timing = timing,
		durations = {
			Enter = State.transition,
			Closing = State.transition,
			Arrival = State.arrival,
			Anticipation = timing.anticipation,
			Charge = timing.charge,
			Shake = timing.shake,
			Break = timing.opening,
			Flight = timing.flight,
			RarityTease = timing.rarityTease,
			Impact = timing.impact,
			Silhouette = timing.silhouette,
			Reveal = timing.reveal,
		},
		direct = direct,
		skipped = false,
	}
end
function State.duration(state: State): number
	local phase: Phase = state.phase
	local duration = state.durations[phase] or math.huge
	if state.reduced and phase == "RarityTease" and state.timing.rarityReduced then
		return math.min(duration, state.timing.rarityReduced)
	end
	return if state.reduced and reducedCaps[phase]
		then math.min(duration, reducedCaps[phase])
		else duration
end
function State.progress(state: State): number
	return math.clamp(state.elapsed / State.duration(state), 0, 1)
end
function State.advance(state: State, delta: number): boolean
	if state.phase == "Done" or delta ~= delta or math.abs(delta) == math.huge then
		return false
	end
	state.elapsed += math.max(0, delta)
	local nextPhase: Phase? = following[state.phase]
	if nextPhase and state.elapsed >= State.duration(state) then
		-- Visit every phase after stalled frames; never skip a cue or the interaction gate.
		state.phase = if state.direct and state.phase == "Enter" then "Silhouette" else nextPhase
		state.elapsed = 0
		return true
	end
	return false
end
function State.canSkip(state: State): boolean
	return state.phase ~= "Enter"
		and state.phase ~= "Arrival"
		and state.phase ~= "Result"
		and state.phase ~= "Closing"
		and state.phase ~= "Done"
end
function State.skip(state: State): boolean
	if not State.canSkip(state) then
		return false
	end
	state.phase, state.elapsed, state.skipped = "Result", 0, true
	return true
end
function State.activate(state: State): boolean
	if state.phase == "Await" then
		state.phase = "Break"
	elseif state.phase == "Result" and state.elapsed >= State.resultGuard then
		state.phase = "Closing"
	else
		return false
	end
	state.elapsed = 0
	return true
end
function State.animated(state: State): boolean
	-- One bounded loop for floating/idle; reduced motion sleeps at the interaction gates.
	return state.phase ~= "Done"
		and (
			not state.reduced
			or (
				state.phase ~= "Await"
				and (state.phase ~= "Result" or state.elapsed < State.resultGuard)
			)
		)
end
function State.cancel(state: State)
	state.phase, state.elapsed = "Done", 0
end
return State
