# Opening audio delivery checklist

Status: **rejected pack disconnected. 14 slots are now filled with licensed Creator Store audio
from the [game soundpack](SOUND.md); the other 34 are empty and silent.**
The user found the synthesized audio engine-like and noisy. The rejected
[Porcelain & Starlight pack](../assets/audio/opening/README.md) remains archived locally.
The user previously authorized
original sound creation and upload. All sources were synthesized for this project without
third-party samples; Roblox reports all 48 uploads Approved under creator `103346374`.
Source/master paths, hashes and provenance are in the pack manifest; IDs and owner receipts are
in `assets/uploads.json`, with moderation results in the pack's `roblox_status.json`.

`src/client/OpeningAudioConfig.luau` no longer resolves this pack from `Shared.AssetIds`; its
slots come only from `SoundManifest.opening`, and a spec checks that no rejected ID returns.
`OpeningConfig.sounds` aliases those slots for existing tools. Native Studio
playback was not tested by the agent; user listening rejected the pack's quality.
Test-only dummy IDs never leave the standalone engine double.

Deliver consistent headroom, no leading silence on transients, no baked hard pan, no clipped
masters, and restrained high-frequency content. Critical attack/body information must survive
mono phone playback. Avoid sub-bass-only impacts. Keep tails quiet; do not bake the next cue into
a sample. The mixer applies pitch through PlaybackSpeed (duration changes with pitch), so loop
sources should tolerate the documented narrow ranges. Do not normalize every source to maximum
loudness. Compare all five rarities at the same device volume.

Durations below describe source material, not an extension of the cinematic. One-shots have
configured safety ceilings; phase cuts win over source tails. Loop lengths are suggested source
cycle lengths; all loops must be seamless, without a repeating attack. Intensity is relative to
the crack/impact, not a request for mastering gain. All unspecified collection/rarity columns
mean shared. These rows preserve the design brief, not approval of the rejected sources.
Historical source durations and files are in `assets/audio/opening/pack.json`.

| Semantic key | Event and desired character | Source duration | Playback / seamless | Intensity | Rarity / collection | Tail / reverb and delivery constraints |
| --- | --- | --- | --- | --- | --- | --- |
| ambience | Entry, calm magical air, nonmelodic tonal room | 4-8s | Loop / yes | Very low | Shared / neutral incl. Concept | No distinct rhythm; no swelling loud tail |
| ambienceGrove | Entry, light natural breath | 4-8s | Loop / yes | Very low | Shared / Pocket Grove | Optional; falls back to ambience; no literal birdsong foreground |
| ambienceTide | Entry, soft watery pearl air | 4-8s | Loop / yes | Very low | Shared / Tidepool Tales | Optional; falls back to ambience; no obvious repeating splash |
| entrance | Box movement, soft small upward air | 0.2-0.4s | Shot / no | Medium-low | Shared / shared | Short dry finish; omitted in reduced motion |
| settle | Arrival back-ease settles, tiny package contact | 0.08-0.2s | Shot / no | Low | Shared / shared | Dry, no crate thud |
| tension | Anticipation, restrained interior tonal life | 1-3s | Loop / yes | Very low | Shared / shared | Stable; also fallback for await |
| charge | Energy gathering, warm pressure texture | 1-2s | Loop / yes | Low to medium | Shared / shared | No baked long crescendo; code curves volume and speed 0.86-1.16 |
| shake | One soft contained material tick/rattle | 0.04-0.1s | Shot / no | Low | Shared / shared | Dry; deterministic small variations, never a multi-hit roll |
| await | Indefinite Tap to Open, held quiet pressure | 3-6s | Loop / yes | Very low | Shared / shared | No riser; comfortable 30s+; optional tension fallback |
| click | Open press, tactile fingertip acknowledgment | 0.025-0.07s | Shot / no | Medium-low | Shared / shared | Immediate dry onset; no interface beep |
| compression | Inward response before seal release | 0.03-0.06s | Shot / no | Medium-low | Shared / shared | Concise inhalation; no tail over crack |
| crack | Seal breaks under magical pressure | 0.08-0.15s | Shot / no | High | Shared / shared | Crisp midrange with modest body; no glass, wood snap or gunshot |
| lid | LidCap releases upward | 0.08-0.15s | Shot / no | Medium | Shared / shared | Soft packaging/air bridge; subordinate to launch |
| launch | Energy leaves box, transient into rising air | 0.18-0.28s | Shot / no | Medium-high | Shared / shared | Compact energy tail; no explosion |
| flight | Moving tonal energy bed | 1-3s | Loop / yes | Low | Shared / shared | Smooth/no hiss, speed 0.94-1.10; no attack |
| flightAir | Motion/speed air separated from tone | 1-2s | Loop / yes | Very low to low | Shared / shared | Soft band-limited air, speed 0.92-1.12; mono-safe |
| flightMythical | Transformed spectral energy resumes at bloom | 2-4s | Loop / yes | Low | Mythical / shared | Pearlescent moving harmonics, not louder; optional flight fallback |
| acceleration | Transition from launch into travel | 0.1-0.18s | Shot / no | Medium-low | Shared / shared | Brief focus/zip, distinct from launch; omitted in reduced motion |
| rarityTransformation | Shared inward/outward transformation body | 0.12-0.25s | Shot / no | Medium | Common, Uncommon, Rare / shared | Unpitched or harmonically compatible; subordinate to identity cues |
| rarityCommon | Clean small magical confirmation | 0.12-0.25s | Shot / no | Medium | Common / shared | Bright restrained finish; pleasant, never failure-coded |
| rarityUncommon | Richer harmonic confirmation | 0.25-0.4s | Shot / no | Medium | Uncommon / shared | Soft extra harmony, modest shimmer, no hard stereo dependency |
| rarityRare | Premium warm gold-like tonal attention cue | 0.35-0.5s | Shot / no | Medium-high | Rare / shared | Distinct chime body and warm tail, not sharp treble |
| transformLegendary | First crimson/gold power pulse | 0.09-0.15s | Shot / no | High | Legendary / shared | Rich low-mid attack, space before second pulse; shared body fallback |
| legendaryPulse | Second accented visual pulse | 0.16-0.32s | Shot / no | High | Legendary / shared | Separate take/harmonic accent; falls back to first pulse, never a baked double hit |
| rarityLegendary | Radiant harmonic identity under first pulse | 0.35-0.5s | Shot / no | Medium | Legendary / shared | Controlled sparkle, no heroic fanfare, leaves second transient clear |
| mythicalInward | Transformation begins with brief inward compression | 0.025-0.04s | Shot / no | Low-medium | Mythical / shared | Ends before pearl suspension; no reverberant wash across silence |
| mythicalPearl | Suspended pearl at 0.08s | 0.07-0.13s | Shot / no | Low-medium | Mythical / shared | Delicate rounded ping with quiet tail; no piercing bell |
| transformMythical | Bloom at 0.145s, spectral outward swell | 0.4-0.6s | Shot / no | Medium-high | Mythical / shared | Beautiful unfamiliar harmonic body; shared fallback is provisional only |
| rarityMythical | Cyan/violet spectral identity under bloom | 0.5-0.75s | Shot / no | Medium | Mythical / shared | Precious shimmer, subtle low-mid foundation; not Legendary transposed |
| dive | Short descent build to contact | 0.5-1s | Loop / yes | Medium | Shared / shared | Sustained texture, not a baked timed riser; code follows descent 0.88-1.16 |
| impact | Shared compact magical contact body | 0.08-0.25s | Shot / no | High | Shared / shared | Midrange legibility; strongest body in first 0.1s, intentional cut at 0.11s |
| impactCommon | Compact pleasant contact | 0.08-0.25s | Shot / no | High | Common / shared | Optional shared-impact replacement; rounded dry body |
| impactUncommon | Slightly richer contact | 0.08-0.25s | Shot / no | High | Uncommon / shared | Optional replacement; soft harmonic body |
| impactRare | Gold-like premium contact | 0.08-0.25s | Shot / no | High | Rare / shared | Optional replacement; warm core, no essential long tail |
| impactLegendary | Rich layered power contact | 0.08-0.25s | Shot / no | High | Legendary / shared | Dedicated preferred; compact harmonic weight, not bass overload |
| impactMythical | Pearl/spectral contact | 0.08-0.25s | Shot / no | High | Mythical / shared | Dedicated preferred; unusual spectral attack, no explosion |
| postImpactShimmer | Calm boundary, residue bridging into mystery | 0.2-0.45s | Shot / no | Very low | Shared / shared | Delicate short airy tail; never another reward sting |
| silhouette | Held identity tension | 2-4s | Loop / yes | Very low | Shared / shared | Nonmelodic, no premature resolving cadence |
| silhouetteMythical | Faint pearlescent suspended sustain | 2-4s | Loop / yes | Very low | Mythical / shared | Optional silhouette replacement; beautiful, unresolved |
| reveal | Generic resolving collectible accent, fallback | 0.35-0.7s | Shot / no | Medium-high | Shared / shared | Pleasant warm resolution, not another impact |
| revealCommon | Figure identity, short pleasant resolve | 0.2-0.35s | Shot / no | Medium-high | Common / shared | Dry resolve with tiny sparkle |
| revealUncommon | Figure identity, richer resolve | 0.3-0.45s | Shot / no | Medium-high | Uncommon / shared | Additional soft harmony, gentle tail |
| revealRare | Figure identity, premium resolve | 0.4-0.6s | Shot / no | Medium-high | Rare / shared | Warm reward, recognizable final cadence |
| revealLegendary | Figure identity, elegant radiant resolve | 0.45-0.7s | Shot / no | Medium-high | Legendary / shared | Rich, confident; no fanfare or second double pulse |
| revealMythical | Figure identity, beautiful spectral resolve | 0.5-0.75s | Shot / no | Medium-high | Mythical / shared | Unusual precious harmony, not higher pitch/louder Legendary |
| discovery | NEW badge, secondary sparkle | 0.1-0.25s | Shot / no | Low | Shared / shared | Delayed to 55% of reveal; omitted for duplicates |
| result | Indefinite collectible presentation | 4-8s | Loop / yes | Very low | Shared / neutral | Optional ambience fallback; no riser, no repeated reward melody |
| close | Continue, soft confirmation | 0.03-0.09s | Shot / no | Low | Shared / shared | Dry finish inside existing closing curtain |

Optional slots use only explicit approved fallbacks: grove/tide/result -> ambience;
await -> tension; flightMythical -> flight; transformLegendary/transformMythical ->
rarityTransformation; legendaryPulse -> transformLegendary; silhouetteMythical -> silhouette;
impactX -> impact; revealX -> reveal. Unknown keys, invalid IDs and exhausted fallback chains
are silent. Do not use a generic fallback as evidence that the final rarity ladder is complete.
All five rarity identities, the Mythical inward/pearl design, dedicated impacts and all five
reveal resolves now have distinct delivered material. Fallbacks remain resilience behavior.

Source tails cannot bridge the deliberate impact gap: contact fades from 0.11 to 0.135s;
the shimmer begins at 0.17s for Mythical or 0.22s otherwise. Carry the spectral residue in the
post-impact shimmer/silhouette, not a long uncut impact file.

Use the [Studio procedure and acceptance notes](OPENING.md#audio-review-procedure) after
syncing the current code and restarting Play. Only targeted timing/mix/source corrections
should follow human review.
