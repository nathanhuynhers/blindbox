# Game soundpack

Status: **implemented on `feat/soundpack` (backlog item 15).** Every asset ID was verified in
Studio on 2026-10-03: it is Audio, it is owned by Roblox, ProSoundEffects or APMOfficial, its
preload succeeded and it has a nonzero length. **Nobody has listened to it yet.** The agent cannot
hear audio, so the listening and mix pass below is still open. Background music (item 16) is in [its own section](#background-music).

## Direction and sourcing

The direction is a polished blind-box collectible: soft, tactile, toy-like. That means gentle
pops, cardboard and paper, a foil tear and lid pop, bright glassy chimes and a sparkle on reveals.
The set avoids harsh, arcade or 8-bit sounds. The user rejected the earlier synthesized opening
pack ([history](OPENING_AUDIO_ASSETS.md)), so every sound now comes from free Creator Store audio
that every experience may use:

- Roblox's own UI set (`Roblox_UI_*`, `RBLX UI *`) for clicks, navigation and feedback.
- Roblox's licensed **Pro Sound Effects** library for foley: box, paper, pops, coins, wood.
- Roblox's licensed **APM Music** library for the two biggest stings.

Store audio that was ripped from commercial games was deliberately skipped.

## Architecture

- `src/client/SoundManifest.luau` is the single source of truth. It holds every ID, its exact
  store title, group, level, speed, pitch variation, cooldown and voice count, plus the IDs for
  the opening's cue slots. To swap a sound, change only this file. An empty `id` is a placeholder
  and plays nothing.
- `src/client/Sfx.luau` exposes `Sfx.play(name)`. It handles:
  - **Groups:** `SoundService.Master` (0.8) containing UI (0.6), SFX (0.8), Reveal (1.0) and
    Music (0.3). The player's volumes scale them: Sound effects scales UI, SFX and Reveal; Music
    scales Music.
  - **Pooling:** a sound's voices are reused. When every voice is busy, the next one in turn
    retriggers instead of stacking.
  - **Rate limits:** a per-name cooldown, plus one UI sound per gesture (a 40 ms UI-group window).
    The second sound in that window is dropped.
  - **Pitch:** small random variation on sounds that repeat.
  - **Preload:** each sound's first voice is created at startup and preloaded in the background.
    It stays resident, which keeps the asset loaded.
  - **Volume:** `Sfx.setVolume("sfx" | "music", 0..1)`, driven by the Settings sliders.
  - **Teardown:** `Sfx.destroy()` runs when the client script is destroyed.
- **Box opening:** the existing `OpeningAudio` engine keeps its phase-locked timing. Its slots now
  come from `SoundManifest.opening` (14 of 48 are filled; the rest stay silent). Its Sounds join
  the Reveal group, so the Sound effects volume covers them. Its preload keeps one resident Sound per ID
  for the controller's lifetime. The close sound is the Sfx `close`, played when the session
  enters Closing, because the opening's own cues must end inside its 0.11 s exit curtain.
- Sounds are presentation only. Server-confirmed sounds play from the client's existing reply and
  snapshot handling. No remotes, server code or data schema changed.

Two Roblox behaviours shaped this design (measured in Studio):

- `ContentProvider:PreloadAsync` reports audio **ID strings** as Failure. Preload Sound instances
  instead.
- A new Sound is ready instantly only while another live Sound holds the same asset. A cold load
  took about 0.1 s, longer than the opening's 75 ms one-shot tolerance.

## Background music

Backlog item 16. `src/client/Music.luau` exposes `Music.play(name)`, `Music.stop(fade?)` and
`Music.playing()`. It plays one looping Sound from `SoundManifest.music`, which is keyed by area
or context. Only `world` exists today.
- **Start:** the first ready snapshot (profile and plot loaded) calls `Music.play("world")` once
  in `init.client.luau`, with a 3 s fade-in. Nothing restarts it; it doesn't depend on the
  character, so respawns are irrelevant.
- **No stacking:** repeating the same name does nothing. A different name fades the old track
  out (`fadeOut`) and fades the new one in.
- **Extension point:** area or special-event music later is one manifest entry plus a
  `Music.play(name)` call where that context starts. There is no area system, playlist or event
  system.
- **Mix:** the track sits in a `Music` SoundGroup (0.3) under Master, scaled by the player's
  Music volume. At 100% the effective level is 0.8 × 0.3 × 0.8 ≈ 0.19, below every SFX group.
- **Loop point:** library cues end in a few seconds of silence, so a track can set `loopEnd`.
  Music applies it as the Sound's `LoopRegion`, looping back to the start once the final note has
  decayed.
- **Failures:** a placeholder or failed asset plays nothing (logged once). The Sound is preloaded
  as an instance.

| Context | Track | ID | Status |
| --- | --- | --- | --- |
| world | "Summer Breakfast" (APM Music, Bouncing Mallets; 110.7 s, loopEnd 107.8 s) | 9042946814 | Verified to load; LoopRegion wrap measured with no silent gap; **not yet heard** |

History: the first pick, Roblox's calm loop (`Roblox_UI_Loop_Calm_Music`), was rejected by the
user as too subdued ("more vibrant and happy and fun, but still calm and chill"). The
replacement was chosen from library descriptions: "light, tropical and laid-back pop melody,
marimba, piano, pizzicati, drums played with brushes and handclaps". In Studio, the final note
decays by 107.6 s and is followed by about 3 s of silence. A `LoopRegion` wrap at 107.8 s returns
to the music within 0.2 s.

Other verified alternatives with measured loop ends are in the manifest comment: "Let It Shine"
(bouncy marimba and vibraphone), "Happy Whistle" (mallets, whistling, laid-back), "Easy Island"
(ukulele, marimba, celesta, gentle ska) and the Light version of Summer Breakfast. To try one,
change `id`/`source`/`loopEnd` for `world` in `SoundManifest.luau`.

Not added (by choice): ducking under the box reveal, fade-out on leave, a playlist.

## Volume settings

The Settings popover has two sliders, **Sound effects** and **Music**. They replaced the earlier
session-only Sound On/Off switch.
- **Input:** drag or tap with 5% snapping, or use gamepad D-pad left/right in 10% steps when a
  slider is selected. Targets are 44 px tall.
- **Apply:** a change applies at once (`Sfx.setVolume`).
- **Save:** releasing the slider sends one `SetVolume` intent (`choice` sfx|music, whole-percent
  `volume` 0..100) through the normal transaction path: validation, revision, receipts, rate
  limit and autosave. If another request is in flight, the save retries on the next snapshot
  until the snapshot confirms the value.
- **Join:** saved values arrive in the snapshot and apply on join. Saving shows no toast.
- **Storage:** profiles store `sfxVolume` and `musicVolume` (schema 12, default 100). Older
  records upgrade at full volume. See [data model](DATA_MODEL.md).

Studio playtest (2026-10-04, single client, Studio preview profile, which isn't saved):
- Dragging Music from 95% to 40% applied at once (Music group 0.30 → 0.12) and saved
  ("Settings saved.", snapshot `music = 40`, revision +1), with no toast.
- Tapping Sound effects at 60% scaled UI 0.60 → 0.36, SFX 0.80 → 0.48 and Reveal 1.0 → 0.60, left
  Music alone, and saved.
- Music at 0% silences its group while the track keeps running.
- Both sliders render inside the popover at 0% and 100%.
- Saving across a rejoin can't be shown in Studio preview. It is covered by
  `tests/AudioSettings.spec.luau`: round trip, upgrades from v6-v11, fail-closed values and the
  transaction path.

Studio single-client playtest of the music engine (2026-10-03, with the first track):
- Exactly one looping `Music_world` Sound plays in Master > Music.
- A respawn kept the same Sound playing on (TimePosition 33.2 → 38.9 s over the 5.8 s respawn):
  no restart, no duplicate.
- A forced wrap at 94 s looped to 0.1 s (`DidLoop` once) and kept playing as one Sound.
- Sound Off (the switch the sliders later replaced) zeroed Master, which silenced the music.
- A placeholder plays nothing and logs nothing. A missing asset only logs a warning.
- The 3 s fade-in had already finished before the first MCP call could run, so it is covered by
  `tests/Music.spec.luau`, not by Studio.

Measured mix with the first track (PlaybackLoudness × group × Master; a proxy, not a listening
result; the new track needs its own mix pass):
- **Music:** average 16, peak 38.
- **SFX peaks:** place 97, revealMythical 95, collect 69, revealCommon 54, coinLand 41,
  revealRare 28, click 22.

Music averages below every effect, but its loud passages reach about the click and revealRare
level. revealRare also measures quieter than revealCommon, which may invert the rarity ladder.
Check both in the mix pass.

## Manifest

All rows are **verified to load; not yet heard**. Volumes are the manifest levels before the
group and Master levels apply.

| Name | Plays when | Source (store title) | ID | Group |
| --- | --- | --- | --- | --- |
| click | Any enabled `UIButton` (after its action) | Roblox_UI_Small_Click | 15675032796 | UI |
| select | Tile, list, slot, Shelf spot, chooser, HUD gear/coins/Home taps | Roblox_UI_Bright_Click | 15675059323 | UI |
| tab | Switching screens | Roblox_UI_Paper_Swipe | 15675037413 | UI |
| open | Opening a screen (dock, E prompt, Y, Daily button); the offline-earnings popup appearing | Roblox_UI_Cute_Pop | 15675055424 | UI |
| close | Closing a screen; the box opening closing | Roblox_UI_Cute_Goodbye | 15675081158 | UI |
| denied | Pressing a disabled button (unaffordable, pending) | RBLX UI Back (SFX), speed 0.8 | 10066914500 | UI |
| error | Server rejected a request or a collect | Roblox_UI_Whistle_Low | 15675062723 | UI |
| collect | Collecting a figure's Coins (predicted click, else confirmed reply) | Coin Throws 4 (SFX) | 9113849910 | SFX |
| coinLand | Each flying coin reaching the player (cooldown 0.07 s, 3 voices) | Synth Sparkle Tone High Pitch Tone Burst Pin (SFX) | 9126075967 | SFX |
| place | Display or Shelf placement confirmed | Wood Impacts Soft Impacts On Temple Blocks 6 (SFX) | 9120917813 | SFX |
| remove | Display or Shelf removal confirmed | Suction Pop 6 (SFX) | 9119669618 | SFX |
| unlock | Display slot or Shelf purchase confirmed | RBLX UI Purchase (SFX) | 10066947742 | SFX |
| goalReady | Daily goal becomes claimable | Synth Sparkle Tone High Pitch Bell Tone Ding (SFX) | 9126073318 | SFX |
| claim | Daily goal, coin-only Daily Login day or offline earnings claimed (box days sound through the opening) | Roblox_UI_Tonal_Stinger | 15675043410 | SFX |
| results | Open 10 results grid appears | Magic Glows Soft Clusters Of Chiming Hits 3 (SFX) | 9116394756 | Reveal |
| complete | Collection completed (new Shelf); waits for the Open 10 grid | Magical Meetup - Tag1 (APM) | 9048764102 | Reveal |

Opening cue slots (timing, ducking and fallbacks stay in `OpeningAudioConfig`/`Sequence`):

| Slot | Moment | Source | ID |
| --- | --- | --- | --- |
| entrance | Box arrives | Roblox_UI_Whoosh_04 | 15675012262 |
| shake | Anticipation rattle ticks | Box Grab Department Store Type 31 (SFX) | 9113564057 |
| click | Tap to Open | Roblox_UI_Bright_Click | 15675059323 |
| crack | Seal breaks (foil/paper tear) | Plastic Sheet Impacts Rips Paper Tears 6 (SFX) | 9117624959 |
| lid | Lid pops off | Suction Pop 2 (SFX) | 9119669295 |
| impact (all `impactX` fall back) | Figure lands | Wood Impacts Soft Impacts On Temple Blocks 1 (SFX) | 9120917438 |
| rarityLegendary | Legendary tease pulse | Magic Glows Soft Clusters Of Chiming Hits 4 (SFX) | 9116395089 |
| rarityMythical | Mythical bloom | Magical Exit Sparkling Pass Bys Clinking Chi (SFX) | 9125635442 |
| revealCommon | Small plink | Synth Sparkle Tone High Pitch Tone Burst Pin (SFX) | 9126076030 |
| revealUncommon | Brighter ding | Synth Sparkle Tone High Pitch Bell Tone Ding (SFX) | 9126073001 |
| revealRare | Richer chime cluster | Magic Glows Soft Clusters Of Chiming Hits 2 (SFX) | 9116394876 |
| revealLegendary | Bells-and-strings hit | Magical Meetup - Hit2 (APM) | 9048764475 |
| revealMythical | Fuller bells tag with a tail | Magical Meetup - Tag2 (APM) | 9048764286 |
| discovery | NEW sparkle (first discovery only) | Magic Twirling Small High Pitch Spinning Chi (SFX) | 9125644310 |

The reveal levels climb from 0.5 (Common) to 0.75 (Mythical), and the ceilings grow from 0.8 s
to 5 s. Closing and Skip still cut them.

## Deliberately not added

- **Income ticks:** Coins bank silently on each figure, and the wallet only changes when you
  collect, so there's no tick to sound. Collect and the per-coin landing cover it.
- **Hover sounds:** these would spam, and touch devices have no hover.
- **Per-step daily goal progress:** progress only changes on a Place, which already sounds.

## Checks

Automated: `tests/Sfx.spec.luau` covers the manifest data, placeholders, voice caps and
retriggering, cooldowns, the UI gap, groups, mute, preload and teardown.
`tests/OpeningAudio.spec.luau` checks that the slots come only from the manifest, that the
rejected pack stays disconnected, the Reveal group, the resident cache and the ceilings.
`tests/Screens.spec.luau` covers open, tab, close, click, denied and the volume sliders.

The Studio single-client playtest on 2026-10-03 confirmed in the client's output log:

- Screen open, tab and close, one sound each.
- Denied on a disabled unlock, with nothing sent.
- Select taps.
- A real free box and a bought box: click, crack, lid, impact, revealCommon and the NEW
  discovery, in order on the cinematic clock; then Put on Display and Keep, each with close.
- Display and Shelf place.
- Slot-4 unlock.
- Daily goal ready, then claim.
- Open 10 Skip, with close and results.
- Collection complete.
- Sound Off sets Master to 0 and nothing plays; Sound On restores it.
- No console warnings or errors.

The automated checks and the playtest above don't establish what anything sounds like. Still open:

1. **Listening pass**, on headphones, speakers and a phone at a fixed volume. For music, check
   that the vibe fits Blindbox Town (cozy, warm, playful, unhurried), that the loop seam is
   clean, and that the music sits under the reveal stings and coins. Adjust `groups.Music` if not. Check every row
   above. Swap any ID you dislike in `SoundManifest.luau`.
2. **Rarity ladder:** run `tests/StudioOpening.client.luau` → *Compare all five tiers*. Check
   that the five reveals climb clearly, and that Legendary's and Mythical's tease and reveal line
   up with the visuals. The MCP could not press Tap to Open for a fixture-driven opening.
3. **Coin collect:** click or tap a displayed figure. Listen for the collect and the coin
   landings, and check they stay a sparkle trail rather than a buzz. MCP clicks cannot reach
   world ClickDetectors, so this hook was not exercised in Studio.
4. **Mix pass:** check that the reveal stings sit above the UI, that the Mythical tail is not too
   long, that quick screen switching never piles up, and that Open 10 stays calm.
5. **Server rejection** (`error`) and **remove** were not triggered in Studio.
6. **Two clients:** sounds are local, so one player's actions must stay silent for others.
