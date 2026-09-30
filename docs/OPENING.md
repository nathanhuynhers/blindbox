# Blind-box cinematic opening

Implemented cinematic lifecycle correction. Automated checks now execute the actual cinematic,
box, skin, figure appearance, effects and audio against engine primitives.
**Native Studio visual, input, performance and multiplayer acceptance is still pending.**
No server, economy, catalog, inventory, persistence, purchase contract or generated asset ID changed.

## Ownership and architecture

The existing Buy/Daily acknowledgement already spent/granted on the server. `OpeningResult`
continues to hand over frozen `requestId`, `figureId`, `isNew`, `quantity` and `direct`
metadata from the request baseline and confirmed snapshot. Discovery is not inferred from
current quantity. The cinematic never rolls, sends a remote, charges or grants.

| Module | Responsibility |
| --- | --- |
| OpeningController | One session, bounded replay cache, inputs, phase/audio coordination, errors, UI/movement focus and teardown |
| OpeningState | Deterministic clock, phase transitions, Await activation, Skip, Continue guard, cancellation |
| OpeningConfig | Rarity timings/intensity, collection presentation, camera/effect limits, sound slots and future tease beats |
| OpeningCinematic | Local stage, model placement, curved flight, camera choreography and figure presentation |
| OpeningCamera | Captures/restores camera type, subject, CFrame, Focus and FOV; detects camera replacement/destruction |
| OpeningEffects | Real inward particles, orbit beams, comet trail/aura/light, impact rings, halo, dust and local post effects |
| OpeningBox / OpeningBoxSource | Production clone validation, normalization, semantic animation handles, bounded content loading and fallback selection |
| OpeningFallbackBox | Existing procedural emergency carton |
| OpeningFigure | Existing FigureModel factory, normalized awarded model and reversible silhouette treatment on its own instance |
| OpeningView | Safe-area UI only: transition curtain, Tap to Open, Skip, result name/rarity/NEW/quantity, Continue |
| OpeningAudio | Bounded local cues/loops, charge pitch, expiry and stopping |
| OpeningScope | Idempotent reverse-order cleanup; one cleanup failure cannot prevent the rest |

The main presentation is no longer a ViewportFrame. Every stage object is made by the local
client under `Workspace.BlindboxCinematic`, at the configured isolated origin (0, 10000, 0).
It contains a dark compact studio enclosure, a porcelain plinth and three studio lights.
The character stays in the real world. Presentation parts are anchored, noncolliding,
nontouching and nonqueryable. Other clients receive no cinematic instances.

Only the purchasing player's gameplay UI is suppressed through the existing `openingFocus`
callback. ContextActionService sinks movement/jump, clears current movement and owns opening
inputs. No character anchoring, server teleport, PlayerModule replacement or world Lighting
property mutation is introduced.

## Sequence and pacing

| Phase | Behavior |
| --- | --- |
| Enter | 0.22s dark transition; camera takeover occurs at its opaque midpoint |
| Arrival | 0.50s rise with a restrained overshoot, gentle turn and collection-colored motes |
| Anticipation | Floating package and a slow camera push; collection identity only |
| Charge | Particles emit inward from a sphere; five shrinking orbit paths feed beams into the lid seam; FOV tightens |
| Shake | Small bounded rotational impulses increase; seam light builds |
| Await | Indefinite Tap to Open; no automatic opening and no rarity color |
| Break | Immediate prompt removal/click cue, 3% compression, seam pulse, independent backward rotating lid launch |
| Flight | Neutral comet launches; camera follows a cubic Bezier ascent with widening FOV |
| RarityTease | Mint, lavender or gold colors the comet/trail before identity; short apex hold, curved descent and tightening FOV |
| Impact | Local sparks, expanding beam rings, short bloom and restrained camera impulse |
| Silhouette | Flight debris clears; actual awarded figure appears dark against a rarity halo |
| Reveal | Colors restore, small upward settle, restrained rotation and camera push; result details fade in |
| Result | Calm figure idle, low ambient particles, correct metadata and indefinite Continue |
| Closing / Done | 0.22s dark transition; camera restores at opaque midpoint, then the session releases everything |

The lid cap, top panel and top trim travel together; the lid is not immediately destroyed.
Crack/lid/launch audio markers start at 0.08/0.16/0.20s after activation. No full-screen white flash,
giant rarity lettering or rainbow burst is used.

| Profile | Timed opening, excluding Await/Result/Closing | Silhouette | Peak flight FOV | Impact rings |
| --- | --- | --- | --- | --- |
| Common | 3.99s | 0.35s | 61 | 1 |
| Uncommon | 4.57s | 0.48s | 64 | 2 |
| Rare | 5.21s | 0.65s | 67 | 3 |

These are configured clock durations; real frame scheduling can add a small amount. On a stalled
frame the clock visits each phase instead of skipping interaction/visual beats. Timers accept
finite nonnegative deltas only. Await and Result never time out. Normal mode keeps a single
render connection for floating/figure idle; reduced mode releases it at both prompts once
the result guard expires.

Redeem still shows the chosen figure directly: Enter -> Silhouette -> Reveal -> Result.
It receives the same safe camera transition, restoration and authoritative metadata.

## Production box and collection appearance

The preferred source remains `Models.BlindBoxBase`, uploaded asset **79870100381887**, from
`assets/models/blind-box/blind_box_base.glb`. The existing server `ModelAssets` abstraction
publishes a sanitized template to `ReplicatedStorage.ProductionModels.BlindBoxBase`.
The opening clones that template; it does not download/insert another model or build a replacement.

`OpeningBoxSource` requires the expected replicated part count and validates the existing
`BlindBoxModel.surfaces` semantic contract: BoxBody, the three PatternPanels, EmblemBadge,
CollectionNamePlate, the three FrameTrims, LidCap and BottomCap. Both named MeshParts and
Models containing MeshParts are supported. `BlindBox_Root` is the canonical animation frame;
an importer wrapper is normalized into this frame using semantic front/up directions, so a
changed or missing imported pivot/root name does not break the package.

The imported primary pivot is cleared on the clone. Cached part transforms drive whole-box
motion. A local invisible `LidAnimationPivot` establishes the rear lid hinge independently
of its mesh pivot. TopPatternPanel, TopFrameTrim and optional TopBadgeMount follow LidCap.
CollectionNamePlate uses a SurfaceGui that follows the physical plate.

`BlindBoxSkin` reuses the existing Shop palette, panel textures and canonical emblem.
`OpeningConfig.collection(id)` reads names from Catalog and packaging from ShopTheme, adding
only an accent/motif/optional ambience. Grove uses leaf-like specks; Tide uses slowly rising
soft motes. Neither collection changes the rarity profile or selects a different physical GLB.

Missing/incomplete/invalid templates produce a useful warning and select the existing emergency
carton. If complete production geometry arrives during the dark entrance, it replaces fallback
before box arrival. Once arrival starts there is no late upgrade pop. Mesh content is prepared
asynchronously; delivery failure or the five-second deadline switches to emergency geometry,
keeping the wrapper pose/visibility. Tasks, timeout and replication listener belong to the box
scope, which the session owns and retires when the box portion ends.
Missing panel art simply retains the applied material/palette. Missing sounds remain silent.

`OpeningFigure` uses `FigureModel.create(result.figureId)`, exactly the same factory as the
Collection and Display. The newly prepared Pebble Pip GLB has not been adopted into that factory;
this feature does not silently replace its representation. Silhouette treatment hides mesh
textures, SurfaceAppearance and decals on the private figure instance, then restores them.
Shared templates and catalog records are never mutated.

## Camera and effect lifecycle

Camera ownership is registered before stage construction. Enter takes the current camera with
`CameraType.Scriptable` only behind the curtain. Normal Continue restores its saved type,
subject, CFrame, Focus and FOV behind the closing curtain. A missing old subject falls back to
the local character's current Humanoid. A different camera supplied by another local system is
respected; the original camera is restored without forcing CurrentCamera back to it.

Cancellation, Skip-to-result followed by Continue, GUI destruction/removal/disable, character
removal/addition, Humanoid death, camera replacement/destruction/type interruption, stage
destruction, construction/render/input errors and controller teardown all converge on the same
cleanup scope. Calling cleanup twice is safe. One failing destructor is logged while remaining
cleanup still runs. The granted item remains owned even when presentation fails.

BloomEffect and ColorCorrectionEffect live only under the local camera. No Lighting service
properties are edited. Real ParticleEmitters use built-in Roblox particle textures; Beams,
Trails, lights and a small neon comet provide depth without physics. Effects are preallocated;
no parts/emitters/tweens/tasks are created per render frame. Bursts cap at 32 particles, rings
at four, orbit motes at five. Touch devices reduce emission to 55%, with fewer ring segments.
Transient families are destroyed at their retirement boundaries below; disabling an emitter
alone does not clear already emitted particles or trail history.

### Lifecycle audit and guarantees

The old implementation created one Bloom and one ColorCorrection per session, assigned their
values directly, and destroyed them during session cleanup. It had no cinematic TweenService
calls, incrementing brightness/exposure, or global Lighting mutations. The audit did **not**
establish accumulating Bloom instances or progressive brightness between sessions.

It did establish these defects:

- The completed `OpeningPackage` was reparented into `HiddenCinematicAssets` **under the
  ScreenGui**, retaining all geometry, its enabled `CollectionName` SurfaceGui/TextLabel and
  live loading callbacks. This was not box retirement or safe storage for world-space GUI.
  A regression run against the pre-fix modules fails the whole-package/nameplate retirement
  assertion. Both collections use the same path; no collection string is special-cased.
- Charge/flight emitters were disabled without clearing their live particles/trail segments
  on all transitions. `clear()` omitted the halo ring and post-effect reset. Old phase resources
  remained allocated until the session ended. Loader fallback could still replace the hidden
  box after its presentation ended.
- Three range-32 studio PointLights stayed at 3 + 1.4 + 1.4 brightness throughout the opening,
  including Result. Seam light (up to 1.8 plus the Break pulse) and a brightness-2 comet were
  added on top. The result inherited the generic half-profile Bloom instead of a result target.
  This is overlapping illumination, not evidence of an unbounded accumulator. GPU overexposure
  and final color readability still require the native visual comparison below.

`OpeningScope` is the authoritative, reverse-order, fault-isolated, idempotent session cleanup.
It owns the stage, detached storage, box child scope, effect hierarchy/post effects, camera,
audio, UI and connection/input release. Hidden assets are now outside the DataModel and
explicitly destroyed; they are never stored under PlayerGui.

| Resource family | Retirement |
| --- | --- |
| Complete box wrapper: all semantic parts, nameplate, artwork, lid pivot and dynamic descendants | `retireBoxPresentation()` at RarityTease, after lid travel through Flight; immediately on Skip/result/direct spotlight or session cleanup |
| Box loading/deadline/replication listener | Same box scope; invalidate generation/closed flag, cancel tasks and disconnect listener before destroying the wrapper |
| BoxEffects: seam light, charge/collection particles, gathering geometry/beams | Flight, or any jump beyond it |
| FlightEffects: comet, light, aura, sparks, attachments and trail | Impact, or any jump beyond it |
| ImpactEffects: burst and expanding rings | Silhouette, or any jump beyond it |
| RevealEffects: reveal sparkle mount/emitter | Result, or any jump beyond it |
| ResultEffects: quiet dust, halo and halo ring; three studio lights; awarded figure | Closing curtain disables illumination/VFX; session cleanup destroys them |
| OpeningBloom / OpeningGrade | Exactly one named pair under the captured Camera; reset at phase entry, explicit phase targets, disabled behind Closing curtain, destroyed on cleanup |

Each phase entry clears live particle/trail history and disables the previous visual state before
applying its new targets. `OpeningConfig.lightState` bounds combined studio/seam/comet brightness
to 1.8, with a 1.4 studio baseline and range 18; accent lights consume that budget rather than
stacking onto full studio illumination. Positions, light colors, relative key/fill/rim weights,
camera path, lid/figure animation and rarity profiles are preserved. Impact Bloom decays; the
silhouette/result use an explicit 0.15 profile multiplier instead of inheriting impact state.
These are deterministic safety baselines, not a claim of finished artistic tuning.

No shared Lighting property is changed, so existing ExposureCompensation, Brightness, Ambient,
OutdoorAmbient and external post effects require no hardcoded restoration. The fixture checks
their original values and child counts. The camera restores its captured state on all exit paths.

There are **zero cinematic tweens or Tween.Completed listeners**. Pose, camera and light targets
are computed by the existing single render loop. No tasks or instances are created per frame.
Monotonic phase entry rejects duplicate/obsolete phase callbacks; draws/cues must match the
active phase. Box tasks test their generation before and after yielding. Scope guards and
session-identity checks prevent queued old signals from changing or closing a successor.
Skip retires transient resources and shows the already-awarded result; Continue/cancel/respawn,
GUI destruction and teardown all release the session. Reduced motion uses the same ownership.

The implementation follows Roblox's [camera ownership API](https://create.roblox.com/docs/reference/engine/classes/Camera),
[particle emitter API](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) and
[beam API](https://create.roblox.com/docs/reference/engine/classes/Beam); these engine rules do
not constitute a native visual playtest.

## Input, Skip and reduced motion

Mouse/touch can activate the box hit target or primary button. Enter/Space activate the selected
or default control; gamepad A opens/continues, B/X skips. When Await begins, gamepad selection
moves to Open. After that, explicit user navigation to Skip is respected. Gamepad button
activation is owned by the action binding, preventing duplicate GuiButton activation.

Skip appears after Enter + Arrival (0.72s). It stops active audio and clears transient VFX, then
jumps directly to the same result. The result guard lasts 0.35s, preventing the triggering input
from also dismissing it. Skip does not restore gameplay camera immediately: it keeps the clean
figure presentation and Continue flow. No additional server request or award occurs.

Reduced motion is captured from the existing Shop preference at session start. It removes
box shake, camera impulses/chase/FOV pumping, entrance travel and figure pop/rotation/float.
The camera stays fixed; a short vertical energy/tint presentation retains rarity-before-identity.
It uses 25% effect density (combined with the touch multiplier), one impact ring, shortened
timings and color fades. Common takes 2.33s and the other profiles 2.38s excluding user waits
and Closing. It does not skip the reveal or discard metadata.

## Audio slots

All sound IDs currently remain empty. Insert original/licensed `rbxassetid://` IDs into
`OpeningConfig.sounds`:

- entrance; ambience / ambienceGrove / ambienceTide
- charge; shake; click; crack; lid; launch; flight
- rarityCommon; rarityUncommon; rarityRare
- impact; silhouette; reveal; discovery; close

Collection ambience, charge and flight can loop only while their phase group is active.
Await, Break, Impact, Silhouette, Skip and teardown stop temporary layers. Charge pitch rises
with progress. Playback is capped at eight concurrent sounds with an eight-second hard lifetime.
The controller emits the reveal/NEW cues at most once per session, including Skip during Reveal.
Sound loading never drives or blocks the clock.

## Extending the presentation

**Another collection:** register its normal Catalog entry and ShopTheme packaging (emblem,
pattern, primary/secondary/wash/trim/ink); optionally add a motif/ambience entry to
`OpeningConfig.collectionEffects`. Unspecified motifs use neutral motes. The cinematic,
camera paths, box structure and rarity profiles need no collection branches.

**Another rarity:** add a named `OpeningConfig.rarities` profile with timings, tint/accent/glow,
shake frequency/amplitude, camera impulse/peak FOV, particles/multiplier, ring count, trail width,
bloom and tease beats. Unknown names safely use Common. This is presentation extensibility,
not authorization to add catalog drops or odds.

`tease` is an ordered list with normalized `at` times starting at zero, `color`,
`secondary`, `cue`, and optional `quiet`, `freeze`, `shatter` flags. A future profile
can start gold, enter a quiet frozen beat, then burst into its final color with a new sting.
`teaseMotion` excludes frozen intervals from path progress, so freezing does not jump backward;
`teaseHold` controls the apex hold. Set the profile's final tint/accent to its final reveal palette,
include a nonfrozen section, keep beat times ascending below 1, and add the requested sound keys.
No Secret profile or fake Secret drop ships in this change.

**Upgraded box artwork:** replace the GLB under the same semantic key using the existing
[asset pipeline](ASSET_PIPELINE.md). Preserve semantic surfaces and sane geometry bounds; panel
textures/emblems can be replaced independently through existing manifest keys. Test imported
orientation and lid semantics in Studio. Animation does not depend on authored mesh pivot
placement or a per-collection GLB. No new asset uploads are needed for this pass.

## Studio fixture and acceptance

After current Rojo sync or opening the rebuilt place, start Play and paste
`tests/StudioOpening.client.luau` into the **client Command Bar**. It asserts Studio context,
is not included in the production Rojo mapping, sends no remotes and grants/spends nothing.

The scrolling launcher provides all six collection/rarity combinations, a NEW/duplicate toggle,
reduced motion, a catalog-ID input for every existing figure, redemption, and an automatic Skip
test that cycles through every skippable phase. Choose Skip mode before launching. The native
lifecycle check interrupts 20 sessions **after camera takeover**, including GUI destruction,
and asserts camera type/FOV, stage, post effects, sounds and input cleanup. Exit restores the
previous main-UI enabled state and cancels owned fixture tasks.

For the repeated-opening regression, start a clean Studio Play session, switch the Command Bar
to **Client**, and paste `tests/StudioOpening.client.luau`. Leave Skip at **Manual**, then click
**10-opening regression: manually Open / Continue each**. The sequence is Tide Common (Coral
Cuddle) twice, Grove Uncommon, Tide Rare, Grove Common, Grove Rare, Tide Uncommon, Grove Uncommon,
Tide Rare, Tide Common. Use Tap to Open and Continue for each; the next starts automatically.
Leave Result visible for 15 seconds on openings 1 and 10. Compare package artwork, figure colors,
plinth and background; neither result may contain collection packaging text.

Output prints Arrival/Result resource counts and checks each completed opening returns to zero
temporary stages, post effects, lights, emitters, beams, trails, boxes, figures and render bindings.
Result expects three studio lights, two post effects, no package or trail. Tweens are always zero
because the cinematic has none. Arrival light/post/stage counts must match across all ten.
`BlindboxOpening.RenderConnections` reports the controller's one render subscription (zero when
reduced motion sleeps). These are fixture-only diagnostics, not production logging. The loop
allows up to three minutes per opening; interruption reports a failure and cancels cleanly.
Repeat with Reduced motion ON and with automatic Skip enabled; also run the existing 20-session
interruption check. Reset or replace the camera separately, then restart the fixture.

Manual acceptance still required:

1. Compare all six collection/rarity combinations. Confirm production box mesh/art delivery,
   front/nameplate orientation, all lid pieces moving together, inward charge, a readable comet,
   rarity before identity, a dark silhouette and a calm final figure.
2. Preview each actual catalog ID, NEW and five-owned duplicates. Inspect figure bounds and
   material restoration. Compare a real acquisition with Collection to confirm one grant/quantity.
3. Exercise automatic Skip at every phase, rapid clicks, held keys, gamepad selection and Continue.
   Leave Await and Result open for at least 15s. Inspect Output and instance counts.
4. Resize between desktop, tablet, portrait phone and 568x320 landscape during animation and
   Result. Check safe-area controls, framing, name/rarity/quantity and touch movement suppression.
5. Test reduced motion on every rarity: static camera, readable shorter tint reveal, no shake.
6. Run the native interruption check. Reset/die during flight and Result; remove/disable the GUI,
   delete the stage, or replace the camera locally. Confirm normal controls/UI/camera return.
7. In an unsaved client session temporarily hide the replicated production template and launch
   another fixture, then restore it. Verify fallback warning, usable lid/open/Skip, and no state
   mutation. Review Output for permission/moderation or texture delivery failures.
8. In a two-client Studio session, purchase on one client. Only that client should see the stage
   or camera/UI changes. With delayed/retried replies, verify a single grant and presentation.
9. On a normal mobile device, inspect frame rate and effect density; tune camera motion, quiet
   intervals, lighting, surface branding and original audio by human visual/listening judgment.

## Automated verification

Run pinned `rokit install`, `wally install`, `stylua src`, `stylua --check src`, `selene src`,
the Luau Language Server with Roblox definitions/sourcemap, and
`rojo build default.project.json -o RobloxWorkspace.rbxlx`.

`python tests/run.py build/tools/luau/luau.exe` preserves the prior domain/UI suites and exercises
all opening transitions, activation/Skip guards, confirmed result preservation, direct acquisition,
reduced timings, configuration availability, generic future tease hooks, production semantic
lookup/fallback, and actual controller/camera lifecycle under engine doubles. Construction and
render faults verify cleanup; the native fixture is the separate engine acceptance gate.

`python -m unittest discover -s tests -p test_asset_pipeline.py -v` exercises the offline asset
pipeline. `python scripts/upload_assets.py blind_box_base --dry-run` validates the production GLB
and required nodes without uploading. Automated success is not evidence of Studio rendering,
asset delivery, audio quality or multiplayer playtesting.

Validation recorded for this pass: all standalone Luau suites passed, including 2,911 opening
state/result/config checks, 532 controller/camera lifecycle checks, five production source/fallback
checks and the four existing semantic fixtures. All 21 offline Python asset tests passed.
StyLua source/changed-test checks, Selene source/changed-test lint (zero diagnostics using its cached
Roblox API), Luau Language Server source analysis, Rojo 7.7.0 sourcemap/build and Git whitespace
checks passed. The blind-box dry run validated 15 GLB nodes and 204,492 bytes; asset-ID regeneration
left mappings unchanged. No live upload or Studio playtest was performed.

Lifecycle correction validation: the original 532 controller/camera and 2,911 state/result checks
still pass. `OpeningResources.spec.luau` adds real-module resource regression coverage: ten full
normal and ten reduced openings; per-phase Skip/cancel; production nameplate and dynamic-descendant
retirement; stale phase draws/cues; old signals/tasks forced into a successor; asset failure and
fallback upgrade; direct redemption; GUI/respawn interruption; held Result and Continue cleanup.
Only engine primitives and the figure asset factory are doubled; Roblox rendering is not.
The pre-fix modules fail the nameplate-retirement assertion. Full standalone Luau suites, all 21
Python asset tests, pinned formatting/lint, source Luau LSP analysis, Rojo sourcemap/build and the
15-node blind-box dry run pass. Selene uses the existing cached Roblox API when refresh fails;
LSP's standalone watcher-registration warning does not report a source diagnostic.
Analyzing the unmapped Studio fixture directly still reports its pre-existing unsupported
`PlayerScripts:WaitForChild(...)` require path; it must resolve against the live client in Studio.
No native Studio playtest or visual acceptance is claimed for this correction.
