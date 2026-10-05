# A04 — Open 10 result navigation verification

Date: 2026-10-04. Disposable unpublished local Studio place, PlaceId/GameId 0,
`studioPersistence = false`. No published place or live data was changed.

The starting checkout already contained the settled-result Skip to results button. This pass
renames it **View all results**, adds explicit directional selection links with Next, makes
the controller's skip input choose the batch summary during a settled Result, and prevents
late skip input from overwriting an accepted Next choice during Closing. B/X use the batch
summary; single pulls retain Keep. Both choices use the existing 0.35-second Result guard.
The summary captures an immutable ordered copy before the presentation queue is consumed.
No price, odds, RNG, grant, persistence or purchase logic changed.

## Automated checks

- Opening state/result: 5,029 assertions, including complete ten-result metadata after first/ninth
  skipping or ordinary completion, repeated figures, prior discoveries and frozen summary items.
- Controller/camera lifecycle: 845 assertions, including guarded summary choice with mouse/touch
  input objects, selected gamepad A, B/X and the skip API, normal/reduced motion, first/ninth results,
  repeated activation, and accepted Next remaining locked during Closing.
- Opening resources: 36,028; flight: 10,152; opening audio: 727 assertions.
- Screen/summary: 212 assertions, including actual PullSummary tiles in order with correct NEW
  labels and phone/desktop selection links and 44-pixel navigation targets.
- Pinned tools provisioned with `rokit install`; empty dependencies resolved with `wally install`.
  Formatting/check, Selene, Luau LSP analysis and Rojo build passed.

## Native states inspected

Real paid Open 10 purchases used the Shop controls, with the existing Studio-only Coin grant
for funding. Ordered replies and before/after snapshots were observed without changing outcomes.

| Case | Observed outcome |
| --- | --- |
| Desktop first settled result, 15 rapid summary clicks | One complete summary, all ten ordered entries and correct NEW labels; exact ten grants and one 15,000-Coin charge. |
| Desktop eight Next clicks, ninth settled result | Next says `1 left`; View all results stays visible/active/selectable. Summary preserves all ten confirmed results. |
| iPhone 7 landscape, 666×374 viewport | Both choices fit beside the figure; first-result summary with ten rapid clicks preserves the complete batch. |
| Samsung Galaxy A06 emulation, 705×338 rendered viewport | Next and summary each measure about 319×44; summary text fits and the buttons do not overlap. Directional selection links connect both choices. |
| Android repeated Next through tenth result | Tenth says See all results; final summary preserves ten ordered figures and NEW marks. |
| Death/respawn then GUI destruction during a batch | Existing recovery resumed confirmed presentations; summary still contained all ten. Repeated with an observer outside PlayerGui to verify exact grants, order, NEW and charge across reset. |
| Native paid single pull | Batch action hidden; original Keep/Display/Open another choices retained. |

Summary assertions also checked removal of the opening GUI and cinematic stage. Play was stopped
and Studio was returned to its default viewport. Native Result, recovered successor Result and
OpenTenResults states were inspected. Mouse clicks under phone emulation are not physical taps.

Console output included the existing local leaderboard DataStore warning, transient Move calls
without a Humanoid during reset, and the isolated locked-Parent cleanup warning during deliberate
GUI destruction. Recovery and resource assertions passed despite those warnings. Some failed
inspection commands also produced AssistantCommand errors; they were corrected and rerun.

## Remaining input acceptance

No physical phone or connected gamepad was available. Actual touch, controller D-pad navigation,
controller A/B/X and physical-device readability remain untested. Engine doubles cover touch
activation and selected gamepad A; native checks verify Selectable and directional selection links.
This scoped single-client test is not multiplayer or persistence acceptance.
