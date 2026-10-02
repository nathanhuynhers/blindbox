# Blind-box cinematic opening

Five standard rarities are supported: **Common < Uncommon < Rare < Legendary < Mythical**.
The five-tier integration preserves the preceding flight polish and cinematic lifecycle
correction. Automated checks execute the actual cinematic,
box, skin, figure appearance, effects and audio against engine primitives.
**Native Studio audiovisual, input, performance and multiplayer acceptance is still pending.**
The synthesized sound pack was rejected after listening and has been disconnected.
All 48 production audio slots are empty, so opening audio is silent;
see [audio architecture](#audio-architecture) and the [delivery checklist](OPENING_AUDIO_ASSETS.md).
The audio delivery changes no figure assignments, rates, weights, inventory, persistence or purchase
contract. Shared rarity validation and server rate validation now support future
high-tier content. See [rarity architecture, audit and future-content procedure](RARITY.md).

## Ownership and architecture

The existing Buy/Daily acknowledgement already spent/granted on the server. `OpeningResult`
continues to hand over frozen `requestId`, `figureId`, `isNew`, `quantity` and `direct`
metadata from the request baseline and confirmed snapshot. Discovery is not inferred from
current quantity. The cinematic never rolls, sends a remote, charges or grants.

| Module | Responsibility |
| --- | --- |
| Shared Rarity | Canonical identities, order, strict validation and public color palette; no economic state |
| OpeningController | One session, bounded replay cache, inputs, phase/audio coordination, errors, UI/movement focus and teardown |
| OpeningState | Deterministic clock, phase transitions, Await activation, Skip, Continue guard, cancellation |
| OpeningConfig | Rarity timings/intensity, collection presentation, shared break markers, camera/effect limits and future tease beats |
| OpeningCinematic | Local stage, model placement, curved flight, camera choreography and figure presentation |
| OpeningFlight | Pure deterministic path, timed rarity transformation, hold/apex/dive and layered color samples |
| OpeningFlightEffects | Preallocated layered comet, curved taper, trailing glints and three depths of atmospheric emitters; owned by FlightEffects |
| OpeningCamera | Captures/restores camera type, subject, CFrame, Focus and FOV; detects camera replacement/destruction |
| OpeningEffects | Real inward particles, orbit beams, comet trail/aura/light, impact rings, halo, dust and local post effects |
| OpeningBox / OpeningBoxSource | Production clone validation, normalization, semantic animation handles, bounded content loading and fallback selection |
| OpeningFallbackBox | Existing procedural emergency carton |
| OpeningFigure | Existing FigureModel factory, normalized awarded model and reversible silhouette treatment on its own instance |
| OpeningView | Safe-area UI only: transition curtain, Tap to Open, Skip, hint; the Result panel is the `RevealCard` (see [ui-redesign/IMPLEMENTATION.md](ui-redesign/IMPLEMENTATION.md)) |
| OpeningAudioConfig | Approved asset slots, seven logical groups, cue gains/priorities/fades, modulation curves and explicit fallbacks |
| OpeningAudioSequence | Phase/marker cue decisions, rarity rhythms, ducking, intentional silence and once-only reveal/NEW |
| OpeningAudio | Session-owned non-positional Sound layers, mix envelopes, load deadlines, bounded voices and teardown |
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
| Break | 0.40s; lid opens, energy gathers/compresses, launches at 0.18s with accelerating travel; camera reacts after another 0.035s |
| Flight | 0.85s neutral ascent; moving camera pursues a readable layered comet, widening FOV and restrained parallax |
| RarityTease | Compression/neutral pulse, staggered core-to-trail-to-spark tint bloom, explicit rarity hold, rounded apex, accelerating dive and late destination ring |
| Impact | 0.38s; flight family retires at contact, short camera/core/ring response, calm from 0.22s (Mythical: 0.17s) |
| Silhouette | Actual awarded figure rises 0.18 studs into a dark, quiet rarity halo (Mythical holds still); no flight or impact resources remain |
| Reveal | Colors restore, small upward settle, restrained rotation and camera push; result details fade in |
| Result | Calm figure idle, low ambient particles; the Reveal card (Put on Display/Swap, Open another, Keep) waits indefinitely. Without a Reveal model (Studio fixture) it shows Continue only |
| Closing / Done | 0.22s dark transition; camera restores at opaque midpoint, then the session releases everything |

The lid cap, top panel and top trim travel together; the lid is not immediately destroyed.
Click is immediate; compression/crack/lid/launch markers are 0.03/0.10/0.12/0.18s after activation.
The seam crack burst now shares the 0.10s audio marker; lid audio shares the actual 0.12s motion
start. These are the only small visual timing corrections in the audio pass. Reduced Break
scales all markers and lid movement by its duration (0.5 at current settings). No full-screen white flash,
giant rarity lettering or rainbow burst is used.

| Profile | Timed opening, excluding Await/Result/Closing | Silhouette | Peak flight FOV | Impact rings |
| --- | --- | --- | --- | --- |
| Common | 5.47s | 0.35s | 61 | 1 |
| Uncommon | 5.97s | 0.48s | 64 | 2 |
| Rare | 6.60s | 0.65s | 67 | 3 |
| Legendary | 6.95s | 0.80s | 67 | 2 |
| Mythical | 7.38s | 0.95s | 68 | 2 |

Rarity transitions take 0.19 / 0.22 / 0.25 / 0.30 / 0.38s, followed by
**0.25 / 0.35 / 0.55 / 0.70 / 0.90s holds**, in canonical order.
The 0.24s apex and 0.62s accelerating dive begin only after recognition. The mint Common has
a restrained taper; lavender Uncommon adds width/aura and secondary glints; gold Rare adds
a larger aura, stronger compression/pulse, transformation ring and camera response. Initial
core, tail, sparks and flight atmosphere are ivory, with no rarity-colored surroundings.
Legendary uses warm crimson with delayed orange-gold highlights, two separated pulses, a gold
inner trail, stronger aura and a crimson/gold layered impact. Its tuning is unchanged by the
Mythical hierarchy pass. Mythical compresses to half size, resolves a pearl core at 0.08s and
suspends surrounding emission/audio until 0.145s. A single pink-violet bloom follows; two thin
rings expand outward with a 0.12s separation. Cyan travels once from core to tail between
0.24s and 0.66s, then remains a faint edge. Body and trail fully resolve by 0.38s; the existing
0.90s recognition hold gives the sweep time to settle. No rainbow cycling, extra Bloom, lights
or particle budget is added. Mythical's direct-light multiplier and shake ceiling are lower
than before; its impact/reveal bursts and residual motes are sparser.

`OpeningConfig.flight` owns the path points, acceleration, launch/camera cue offsets, tail,
streak and impact tuning. Rarity profiles derive their timing from that configuration and own
transition/hold, trail width/length, aura scale, sparkle rate and pulse intensity. Optional
signature parameters own compression, quiet fraction, pulse waves, trail/ring structure,
highlights and camera response. Mythical's optional `signature.spectralTiming` owns pearl,
bloom, sweep, ring and calm markers in seconds. Profile cue keys allow unique transformation, impact and reveal
sounds; all slots are currently empty after rejection of the synthesized pack. The two
flight helpers share those samples with the existing controller, effects and cinematic; the
phase order and authoritative result flow are unchanged.

Camera acquisition has a deliberate short delay and smooth response, followed by positional
pursuit with exponential interpolation, a small off-center aim, restrained roll and 46-to-61/64/67
FOV expansion (68 for Mythical). The rarity hold stabilizes the frame; Legendary/Mythical add
a restrained configured pull and 2/3-degree hold settling. Dive adds up to three degrees before
the late approach settles toward the existing reveal framing. Impact adds a short damped kick
and two-degree FOV response. Mythical instead uses a slight suspense pullback, a deliberate
recognition push-in, no transformation shake, and a single 0.12-stud axial impact response with
1.2-degree FOV narrowing. Pursuit fully settles by its 0.17s calm marker. Portrait framing
retains the existing distance-fit rule.

The energy uses a compact bright core, translucent inner glow, soft world-sized billboard aura,
a seven-segment tapered Beam tail sampled along the curved path, and a native Trail. The sampled
tail retains presence while speed drops at the hold/apex. Six preallocated flank emitters at
three depths provide distant motes, middle streaks and occasional faster foreground streaks.
Their rates fall during the rarity hold and rise during the dive; the center stays clear.
Built-in Roblox textures are used; no image/audio assets or dependencies were added.

Impact cues are contact, camera kick at 0.02s, compact core at 0.03s, rings at 0.05s, sparks at
0.06s, and light/Bloom peak at 0.08s. At 0.22s, transient brightness and particles collapse;
the stage settles to the silhouette light baseline. Only quiet dust, halo and stage remain
for the figure. The silhouette hold completes before colors or result identity are shown.
Mythical uses a compact pearl contact, pink-violet outer expansion and a smaller cyan response
45ms later. All impact aggression ends at 0.17s; its halo fades in through the remaining 0.21s.
A larger pink-violet outline, smaller tilted cyan edge and soft pearl backlight frame the still
0.95s silhouette. Gentle idle motion eases in during Reveal; the figure's true colors remain
hidden until then. These reuse the existing lifecycle-owned ring and halo objects.

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
Trails, lights and the layered energy star provide depth without physics. Effects are preallocated;
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
| FlightEffects: core/inner glow, billboard aura, sampled Beam tail, native Trail, sparks/glints, light, launch/transformation/destination rings and six atmospheric emitter mounts | Impact, or any jump beyond it |
| ImpactEffects: contact pulse, sparks, controlled light and expanding rings | Illumination/particles clear by 0.22s; entire family destroys at Silhouette, or any jump beyond it |
| RevealEffects: reveal sparkle mount/emitter | Result, or any jump beyond it |
| ResultEffects: quiet dust, halo and halo ring; three studio lights; awarded figure | Closing curtain disables illumination/VFX; session cleanup destroys them |
| OpeningBloom / OpeningGrade | Exactly one named pair under the captured Camera; reset at phase entry, explicit phase targets, disabled behind Closing curtain, destroyed on cleanup |

Each phase entry clears live particle/trail history and disables the previous visual state before
applying its new targets. `OpeningConfig.lightState` bounds combined studio/seam/comet/impact
brightness to 1.8, with a 1.4 studio baseline and range 18; accent lights consume that budget
rather than stacking onto full studio illumination. The calm/silhouette studio target is 0.35;
Result returns to the existing 1.4 baseline. Impact Bloom decays; silhouette/result use an
explicit 0.15 profile multiplier instead of inheriting impact state.
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
The camera stays fixed; a short energy/tint presentation retains rarity-before-identity.
It uses 25% effect density (combined with the touch multiplier), distant motes only, no streaks
or long moving tail, one impact ring (Mythical: two faint staggered rings), 0.18s ascent, 0.12s apex and 0.24s descent. Transformation,
rarity recognition and the full rarity-specific silhouette hold remain intact. Common takes
2.99s, Uncommon 3.25s, Rare 3.65s, Legendary 4.00s and Mythical 4.43s excluding user waits and
Closing. Mythical retains the pearl suspension, single bloom, cyan sweep, a compact layered tail
(22% length, 65% width), softened transformation rings and the same spectral halo. Its camera
and FOV stay fixed. It does not skip the reveal or discard metadata.

## Audio architecture

**Opening audio is disabled: all 48 production slots are empty.** The user rejected the
synthesized pack as engine-like and noisy. The files and upload receipts remain as history;
none of those IDs is loaded or played by the opening. The
[Porcelain & Starlight pack](../assets/audio/opening/README.md) includes the source WAVs,
reproducible generator, upload receipts, approved moderation results, measured headroom and
ten full-sequence previews. Native Studio/device listening and rarity prestige acceptance
remain unverified. The per-key brief is in [OPENING_AUDIO_ASSETS.md](OPENING_AUDIO_ASSETS.md).

`OpeningAudioConfig` owns empty asset slots and mix tuning. Its `sounds` table is also exposed as
`OpeningConfig.sounds`. Each cue declares group, volume, PlaybackSpeed, loop, fade-in/out,
one-shot ceiling, priority and optional fallback/progress curve. `OpeningAudioSequence` reads
the existing State/Flight clocks; the controller still owns the session, visuals, inputs and
cancellation. No cue uses task.delay. No dependency or general-purpose audio engine was added.

The seven logical groups are **Ambience, Box, Energy, Rarity, Impact, Reveal and UI**. They are
local gain buses, not global SoundService changes. Sounds belong to the session's
`SoundService.OpeningSounds` folder. They remain non-positional cinematic sounds so camera
motion cannot change critical cue loudness. Stereo sources may preserve modest depth without
hard panning; critical information must work in mono. This follows Roblox's documented
[Sound placement behavior](https://create.roblox.com/docs/sound/objects).
No listener, global reverb, other gameplay sound or audio setting changes.

Master gain is 0.45. Relative gains include crack 0.85, impact 0.82, reveal 0.60, launch 0.62,
lid 0.42, flight tone 0.28, air 0.18 and ambience 0.10. Ambience ducks to 25% for Break;
energy ducks to 42% for transformation, 60% for recognition and 42% at apex, then builds on dive.
High-tier identity cues have comparable gains to lower tiers: composition carries prestige.
At the eight-Sound cap, an equal/higher-priority cue may replace the oldest lowest-priority
voice. Summed linear output gains are capped at 0.8. This is headroom, not a waveform limiter:
actual source mastering and comfortable device loudness still need listening verification.

| Phase / marker | Audio decision |
| --- | --- |
| Enter | Fade in subtle neutral/collection ambience |
| Arrival | Small movement whoosh in normal motion; settle at 58% of the back-ease |
| Anticipation | Mostly ambience; quiet interior tonal tension |
| Charge | Power-curve build: volume 0.25-1 of cue gain; speed 0.86-1.16; tension rises most near the end |
| Shake | Hold charge; ticks follow visual sine extrema, minimum 0.12s apart with deterministic modest pitch/volume variation |
| Await | Fade out charge, stop rattle, sustain quiet pressure/ambience indefinitely |
| Input / Break | Click at 0; compression 0.03s; crack 0.10s; lid 0.12s; launch 0.18s; reduced Break scales all markers |
| Flight | Tonal bed plus softer air, with distinct short acceleration onset |
| Transformation | Unique rarity identity plus shared/dedicated body, with competing energy ducked |
| Recognition / apex | Softer stable flight and another breath at apex; no new aggressive cue |
| Dive | Phase-owned texture follows actual descent progress, ends exactly at contact |
| Impact | Immediately retire every previous voice; compact rarity contact owns the mix |
| Hush | Fade contact from 0.11 to 0.135s, then silence until the calm boundary |
| Calm | Delicate postImpactShimmer at 0.22s, or 0.17s for Mythical |
| Silhouette | Quiet unresolved sustain; optional pearlescent Mythical variant |
| Reveal | Fade silhouette residue; one rarity-specific resolving reward sting as figure colors return |
| NEW | Small discovery accent at 55% reveal, after overlay begins appearing; omitted for duplicates |
| Result | Calm indefinite ambience; short reveal/discovery tails finish within their ceilings |
| Continue | Soft close cue plus 0.10s fade inside the existing 0.22s curtain; no delayed control return |

**Rarity identities.** Common has a pleasant small confirmation and short resolve. Uncommon
adds harmonic richness. Rare uses a warm premium gold-like cue. Each has distinct `rarityX`
and `revealX` slots, not a shared sample transposed. They share a transformation body by
default. All five have optional `impactX` slots with explicit shared fallback.

Legendary's first body/identity cue starts at the first visual pulse onset
(`0.14 * 0.30 = 0.042s`); a separate accented `legendaryPulse` starts at the second
(`0.65 * 0.30 = 0.195s`). Its direction is bold low-mid power, controlled harmonic sparkle
and an elegant final resolve, without fanfare. Timings derive from the visual signature.

Mythical clears flight, acceleration and ambience at transformation entry. A short inward
gesture ends by 0.045s; the suspended pearl sounds at 0.08s. Spectral body/identity and
transformed flight return at 0.145s, using the existing `spectralTiming` and `quietUntil`
markers in both motion modes. Its flight/silhouette may use dedicated spectral loops.
Recognition leaves space for the existing cyan sweep. The resolve is a different identity
from Legendary, with prestige from silence, unfamiliar harmony and beauty. Whether it actually
feels superior remains a human listening acceptance item for the delivered pack.

**Lifetimes and loading.** Loops are phase/session-owned with no eight-second expiry.
One-shots end naturally or at individual ceilings. Unloaded one-shots stay muted and are
discarded after 75ms; failed loop loads after two seconds. A cancellable session preload warms
valid configured IDs, but never blocks the clock or schedules a late cue. Empty/invalid IDs
allocate no Sound. Fallback chains are explicit and bounded; ID syntax establishes neither
rights nor playback permissions. The Studio warm button helps compare cold/warm playback.

One audio Heartbeat exists only while Sounds exist and ages at most eight voices. This clock
is independent of reduced-motion render sleep, so fades, one-shot expiry and failed loads
still clean up during Await/Result. Stable loops survive indefinite holds. No per-frame Sound
allocation; repeated play of an active loop is idempotent. Default loop fades are 0.10s in,
0.07s out. Intentional hush/contact cuts override fades; cancellation is immediate.

**Skip and cancellation.** Skip clears old voices before Result. Reveal and NEW fire at most
once per session; direct-to-Result Skip may pair them with a secondary low NEW gain.
No old transformation/dive/impact marker can fire afterwards. Death, reset, character
removal/addition, GUI removal/disable/destruction, camera interruption, stage destruction,
controller destroy and successor sessions use existing scope teardown. Sound folder,
Heartbeat and preload task all belong to that scope; no independent cue timers survive.

**Reduced motion/mobile.** Reduced motion omits entrance travel, repeated shake and acceleration
transients. Shared crack/lid/launch markers scale with shortened Break; flight/dive stop at their
shortened boundaries. Mythical pearl/bloom and recognition retain their visual timings.
Sources must carry midrange information for phone speakers and avoid harsh high sparkle.
No hard stereo/pan dependency or sub-bass-only critical cue is specified.

### Audio review procedure

1. Sync the delivered audio IDs and code through Rojo, using provenance from
   [the checklist](OPENING_AUDIO_ASSETS.md). Restart Play after edits so cached modules reload.
   Start a fresh Play session; the controller preloads the configured assets automatically.
2. Sync with the pinned Rojo setup or open the rebuilt `RobloxWorkspace.rbxlx`. Start **Play**,
   switch the Command Bar to **Client**, and paste `tests/StudioOpening.client.luau`.
   The fixture sends no remotes, spends nothing and grants no figures.
3. Leave **Skip test: Manual**, **Reduced motion: OFF**, **Result: NEW**, and **Audio diagnostics:
   ON**. Click **Warm configured approved audio (see Output)**; inspect unavailable/permission
   messages. The overlay shows phase, active cue/loop keys, sound/loading counts and summed
   gain. Configured-slot count is not proof of rights or audibility.
4. Click **Compare all five tiers: manually Open / Continue each**. Common, Uncommon, Rare,
   Legendary and Mythical queue with the same existing Pebble Pip model. Manually Open and
   Continue each; compare at fixed device volume and verify the displayed rarity.
5. Hold Await and Result for at least 30 seconds each. No escalating pressure, repeated reward,
   flight/charge residue or loop expiry. Result should settle to only `result` ambience
   (or zero Sounds with missing assets). Continue removes OpeningSounds.
6. Repeat **Compare Rare / Legendary / Mythical**. Match Legendary's two pulses and Mythical's
   inward cut, 0.08s pearl and 0.145s bloom to the visuals. Hear the recognition space, dive,
   contact, actual short hush, shimmer, quiet silhouette and separate identity resolve.
   Common must remain satisfying and NEW must remain secondary.
7. Toggle **Result: duplicate**, then **Reduced motion: ON**, and repeat all five. Duplicates
   omit NEW. Removed motion has no lingering rattle/acceleration; compressed cues remain aligned.
8. Cycle Skip through all phases and Pearl suspension / Spectral sweep / Rarity hold / Dive /
   Impact peak. Repeat Skip inputs. Run **10-opening regression** and **Lifecycle check:
   20 interruptions**; inspect Output and sound counts. Also reset/die, remove the GUI/stage,
   interrupt the camera and restart while sounds are active. Session sounds must disappear.
9. Listen on headphones, speakers, Studio phone emulation and an actual phone. Check mono
   clarity, comfortable sparkle, limited bass/hiss and consistent high-tier peaks. Compare cold
   cache behavior: no obsolete late transients.
10. Exit preview and record approval or targeted source/mix/timing corrections. The next step
    is final human audiovisual review, not another opening-animation system.

These diagnostics/preload controls are fixture-only and never Rojo-mapped. Automated engine
doubles validate sequencing, gain/lifetime bounds and teardown, not Roblox audio delivery,
waveform quality, device loudness or audiovisual perception.

## Extending the presentation

**Another collection:** register its normal Catalog entry and ShopTheme packaging (emblem,
pattern, primary/secondary/wash/trim/ink); optionally add a motif/ambience entry to
`OpeningConfig.collectionEffects`. Unspecified motifs use neutral motes. The cinematic,
camera paths, box structure and rarity profiles need no collection branches.

**Another rarity:** extend the shared `Rarity.Id`, canonical order and palette, then add a complete
`OpeningConfig.rarities` profile including timings, signature parameters and cue keys. See
[future content and rarity extension](RARITY.md#adding-future-content). Unknown presentation names
safely use Common; catalog validation and Studio overrides reject unknown values. This is
presentation extensibility, not authorization to add catalog drops or odds.

`tease` is an ordered list with normalized `at` times starting at zero, `color`,
`secondary`, `cue`, and optional `quiet`, `freeze`, `destabilize`, `shatter` flags. A future profile
can start gold, hold it, cut audio/motion, destabilize the shell, then burst into its final color
with a new sting. Each beat interpolates its palette instead of setting the entire system instantly.
`teaseMotion` excludes frozen intervals from path progress, so freezing does not jump backward;
`teaseHold` controls the apex hold. Set the profile's final tint/accent to its final reveal palette,
include a nonfrozen section, keep beat times ascending below 1, and add the requested sound keys.
An optional `flight.continuation` overrides the five apex/dive control points while retaining
the same landing/impact handoff. Set the total tease duration and normalized beat positions to
leave room for each transformation and recognition hold. No Secret profile, catalog entry or
fake Secret drop ships in this change.

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
test that cycles through every skippable phase, plus **Rarity hold**, **Dive** (90% of tease)
and **Impact peak** (0.08s into impact). Choose Skip mode before launching. Those delayed fixture
checks are bound to that exact opening/phase and canceled on fixture exit. The native
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

## Recording the flight comparison

For the Mythical hierarchy pass, use this focused comparison before the general checks:

1. Sync through Rojo or open the rebuilt `RobloxWorkspace.rbxlx`, start **Play**, switch the
   Command Bar to **Client**, and paste all of `tests/StudioOpening.client.luau`.
2. Leave **Reduced motion: OFF**, **Skip test: Manual**, and **Result: NEW**. Click
   **Compare Rare / Legendary / Mythical: Open / Continue each**. Use Tap to Open and Continue
   for each preview. All three use Pebble Pip, so model differences cannot determine the winner.
3. Record Legendary immediately followed by Mythical at the same viewport/graphics quality.
   Legendary should read as two forceful crimson/gold pulses. Mythical should read as pearl
   suspense, one pink-violet bloom, a traveling cyan accent, sequential outer/inner rings,
   recognition, pearl contact and an earlier quiet silhouette. Reject the pass if Mythical
   still feels weaker, obscures the figure, or only wins through brightness.
4. Run **Compare all five tiers: manually Open / Continue each**. Repeat both comparisons with
   **Reduced motion: ON**; verify the static camera still leaves Mythical's cadence and layers
   recognizable. For Tide context, cycle **Presentation rarity** to Legendary then Mythical
   and use the same **Tidepool Tales / Common** button for both.
5. Select **Presentation rarity: Mythical** and exercise automatic Skip at **Pearl suspension**
   (0.11s), **Spectral sweep** (0.44s), **Impact peak**, and **Silhouette** in both motion modes.
   Result must be correct with no late sting, trail, impact light or transformation ring.
6. Keep the Mythical override and run **10-opening regression: manually Open / Continue each**;
   hold Results 1 and 10 for 15s and compare baseline/resource counts. Repeat in reduced motion,
   then run **Lifecycle check: 20 interruptions AFTER camera takeover**. Exit the preview.

Automated coverage checks cadence, traveling cyan segments, reduced-motion layers, early calm,
audio deferral/Skip, stale draws, bounded allocations and ten openings per high tier/motion mode.
The full Luau runner, pinned StyLua/Selene checks (source and changed tests), Roblox LSP source
analysis, Rojo 7.7.0 build and Git whitespace check passed. Rokit/Wally completed without new
dependencies. The Windows computer-use connection failed with native pipe unavailable
(`os error 2`), preventing playback through this session.
**Native Studio comparison has not been run for this pass; subjective hierarchy acceptance
remains pending.**

For the new five-tier comparison and repeated high-tier/Skip/reduced-motion procedure, follow
[the exact Studio preview steps](RARITY.md#exact-studio-preview-procedure). The following
six-button procedure remains useful for comparing the actual existing catalog content.

1. Sync the current source through Rojo, or open the freshly built `RobloxWorkspace.rbxlx`.
   Start **Play**, choose **Client** in the Command Bar and paste the entire
   `tests/StudioOpening.client.luau` file. It previews existing catalog figures without purchases.
2. Leave **Reduced motion: OFF**, **Result: NEW**, and **Skip test: Manual**. Record the three
   **Pocket Grove / Common**, **Uncommon**, **Rare** buttons in that order. For each, press
   **Tap to Open**, let the whole silhouette hold finish, then **Continue**. Repeat with the
   three **Tidepool Tales** buttons using the same viewport and graphics quality.
3. Pause each recording at launch, neutral pursuit, color bloom, recognition hold, rounded apex,
   accelerating dive, destination approach, impact peak, calm and silhouette. Check that the
   core/aura/taper stay readable; foreground streaks move faster than distant motes; no rarity
   color precedes the transformation; gold has its longer hold; identity remains hidden until
   the silhouette finishes. Impact must lose its light, streaks, trail and burst quickly.
4. Repeat all six with **Reduced motion: ON**. The camera/FOV must stay fixed, the energy stay
   inside the frame, and rarity/shape anticipation remain legible without streaks or impact shake.
5. Switch **Result** to duplicate (5 owned). Cycle **Skip test** through **Flight**, **Rarity
   hold**, **Dive**, **Impact**, and **Impact peak**; launch a preview for each. Each must land
   on the correct result/quantity with no comet, tail, streaks, transient lights or package.
   Repeat with NEW and reduced motion. Restore **Manual** afterward.
6. Run the existing **10-opening regression** and **20 interruptions** buttons as described
   above. Compare opening 1 versus 10, including a 15-second result hold. Record desktop and
   portrait/mobile framing; native rendering, device performance and multiplayer remain manual
   acceptance gates.

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

Original opening implementation validation: all standalone Luau suites passed, including 2,911 opening
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

### Flight polish validation and changed files

The flight polish passes the full standalone Luau runner, including **5,942 flight timing,
curve/palette, recognition hold, impact/silhouette, reduced-motion and VFX ownership checks**;
**580 controller/camera/cue checks**; **13,360 actual-module resource checks**; and the unchanged
2,911 opening state/result assertions. The resource suite covers twenty full normal/reduced
openings, mid-launch/flight/dive/impact Skip, cancellation, stale work, figure material restoration,
bounded lights, no per-frame instance creation and camera restoration. Engine doubles do not
simulate GPU rendering or asset delivery.

Pinned StyLua formatting/checks, Selene (zero errors/warnings, using the cached Roblox API),
Luau Language Server source analysis with Roblox definitions and current sourcemap, Rojo 7.7.0
build and whitespace checks pass. All 21 Python asset-pipeline tests pass. `rokit install
--no-trust-check` and pinned Wally install completed; checks used the existing pinned executables
directly where the sandbox's Rokit command shims could not resolve them. No tool versions,
dependencies, mappings, catalog entries, odds or server behavior changed. Native Studio recording,
device performance, input and multiplayer acceptance are still pending.

Files changed in this pass:

- Added `src/client/OpeningFlight.luau`, `src/client/OpeningFlightEffects.luau`, and
  `tests/OpeningFlight.spec.luau`.
- Updated `src/client/OpeningConfig.luau`, `OpeningCinematic.luau`, `OpeningEffects.luau`,
  `OpeningController.luau`, `OpeningAudio.luau`, and `OpeningState.luau`.
- Updated `tests/Opening.spec.luau`, `OpeningLifecycle.spec.luau`, `OpeningResources.spec.luau`,
  `OpeningVisualEngine.luau`, `StudioOpening.client.luau`, and `run.py`.
- Updated this document with timings, ownership, hooks, validation and the recording procedure.

## Five-rarity integration validation

The full standalone Luau runner passed: 717 canonical rarity/profile/UI/live-economy assertions,
9,998 flight checks, 643 controller/camera checks, 33,740 actual-module resource/phase checks,
4,819 opening state/result checks and all existing gameplay, persistence, UI, asset-manifest,
Shelf Unit and plot suites. Four invalid economy startup fixtures also passed. The forty new
high-tier sessions cover ten Legendary and ten Mythical openings in each motion mode, plus
high-tier mid-transformation/dive/impact Skip. No native rendering is simulated by these tests.

All 21 Python asset-pipeline tests passed. Pinned StyLua source/changed-test formatting checks,
Selene source/changed-test lint (zero errors/warnings with cached Roblox API definitions), source
Luau Language Server analysis with Roblox definitions, Rojo 7.7.0 build and Git whitespace checks
passed. Rokit and Wally installation completed with pinned versions and no new dependencies.
The standalone LSP watcher-registration warning is not a source diagnostic. Two type-only fixes
were needed in concurrently updated model code: optional variant entries in FigureSlots and
explicit numeric comparison pairs in ModelAssets. They do not change model-loading behavior.

Five-tier implementation files (some also contain the preceding flight-polish changes):

- Shared/server: added `src/shared/Rarity.luau`; updated `Types.luau`, `Catalog.luau` and
  `src/server/Rules.luau`. `Economy.luau` content remains unchanged. Type annotations also updated
  in `src/server/FigureSlots.luau` and `ModelAssets.luau` during final validation.
- Presentation: `src/client/OpeningConfig.luau`, `OpeningFlight.luau`,
  `OpeningFlightEffects.luau`, `OpeningCinematic.luau`, `OpeningEffects.luau`,
  `OpeningController.luau` and `OpeningView.luau`. Existing State/Audio lifecycle behavior is
  retained; their preceding flight changes remain in place.
- UI: `src/client/UITheme.luau`, `CollectionStyle.luau`, `CollectionControls.luau`,
  `CollectionAssets.luau`, `ShopState.luau`, `ShopLayout.luau` and `ShopScreen.luau`.
- Tests: added `tests/Rarity.spec.luau`; updated `Opening.spec.luau`, `OpeningEngine.luau`,
  `OpeningLifecycle.spec.luau`, `OpeningResources.spec.luau`, `StudioOpening.client.luau` and
  `run.py`. Prior `OpeningFlight.spec.luau` and `OpeningVisualEngine.luau` regressions remain.
- Documentation: added `docs/RARITY.md`; updated this file, `ARCHITECTURE.md`, `DATA_MODEL.md`,
  `ECONOMY.md`, `GAME_DESIGN.md`, `MVP.md`, `COLLECTION_UI.md` and `SHOP_UI.md`.

Existing figure rarities, rates and weights are protected by golden assertions. No high-tier
content, fake production grant, live odds or sound asset was added. Studio recordings, subjective
hierarchy/contrast review, mobile performance and two-client acceptance remain manual checks;
none was claimed as run. The dedicated audio systems pass is documented above; final human audiovisual review remains.

## Dedicated audio pass verification (2026-10-01)

The new audio suite executes the real mixer, cue sequence, controller and cinematic against
engine primitives with simulated loaded assets. It covers invalid/empty IDs, silent late
loads, loop survival and fades, nonlinear charge, voice/gain limits, fallback selection,
all five rarity cues, Legendary pulses, Mythical hush/pearl/bloom/resume, exact scaled crack
and seam markers, post-impact silence, once-only reveal, NEW/duplicate behavior, Skip,
30-second reduced-motion holds, interruptions, stale callbacks and ten complete openings
per rarity. It does not fetch or approve the test-only dummy asset ID.

The full `python tests/run.py build/tools/luau/luau.exe` suite passed, including opening,
resources, flight, lifecycle, rarity, MVP, full-game/persistence and UI/plot regressions.
Pinned StyLua source/changed-test checks and Selene source/changed-test checks passed with
zero lint diagnostics. Luau Language Server 1.70.1 source analysis passed with Roblox definitions;
the Studio fixture also passed via an ignored analysis copy using static equivalent module
paths (its actual runtime modules live in PlayerScripts). The standalone LSP watcher-registration
notice is not a source diagnostic. Rojo 7.7.0 sourcemap and place build passed, as did Git
whitespace checking and a key-for-key audit of all 48 checklist rows.

`rokit install --no-trust-check` and pinned Wally install completed under approved execution
after sandbox bootstrap/cache access failed. Validation used the existing exact pinned binaries
directly because sandbox Rokit shims could not resolve their storage path. No dependency, tool
version, Rojo property or generated lockfile content changed.

Native Studio playback, device listening, multi-client acceptance and subjective
Legendary/Mythical ranking were **not run**. The subsequent original sound-pack delivery
below completes the previously missing source and upload work.

## Original sound-pack delivery (2026-10-01)

**Rejected and disconnected after user listening.** The delivery details below are historical.
Technical validation and Roblox moderation did not establish acceptable sound quality.

Created and uploaded 48 original stereo PCM WAVs under the configured creator `103346374`;
all 48 are Approved according to Roblox's asset metadata API. Source hashes, owner and asset
IDs are recorded in the existing uploader's receipts. Runtime mappings are populated, and
preloading now starts when the opening controller is created instead of waiting for a box.
Controller teardown cancels pending warmup. Playback still follows the existing phase clock.

The ten offline previews execute the production mix/sequence for every rarity in normal and
reduced motion. They have no clipped samples, a maximum peak of -10.74 dBFS, and at most
0.06 dB mono loss. All 48 masters passed headroom, DC, mono and endpoint/seam checks.
See [pack details and listening previews](../assets/audio/opening/README.md). API moderation
approval is separate from a native Studio playtest and experience permission verification.

Final delivery checks passed: the full Luau regression suite (including 660 audio checks
and every production cue ID), 23 asset-pipeline tests, the 48-key checklist audit,
StyLua, Selene with the cached Roblox API, Luau Language Server source/fixture analysis,
Wally resolution, Rojo 7.7.0 sourcemap/place build, and Git whitespace checking.
