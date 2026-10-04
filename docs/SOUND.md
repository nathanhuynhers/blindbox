# Game soundpack

Status: **implemented on `feat/soundpack` (backlog item 15).** Every asset ID was verified in
Studio on 2026-10-03: it is Audio, it is owned by Roblox, ProSoundEffects or APMOfficial, its
preload succeeded and it has a nonzero length. **Nobody has listened to it yet.** The agent cannot
hear audio, so the listening and mix pass below is still open. Music (item 16) is out of scope.

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
  - **Groups:** `SoundService.Master` containing UI (0.6), SFX (0.8) and Reveal (1.0). Master is
    0.8 and also carries the mute.
  - **Pooling:** a sound's voices are reused. When every voice is busy, the next one in turn
    retriggers instead of stacking.
  - **Rate limits:** a per-name cooldown, plus one UI sound per gesture (a 40 ms UI-group window).
    The second sound in that window is dropped.
  - **Pitch:** small random variation on sounds that repeat.
  - **Preload:** each sound's first voice is created at startup and preloaded in the background.
    It stays resident, which keeps the asset loaded.
  - **Mute:** a session-only switch.
  - **Teardown:** `Sfx.destroy()` runs when the client script is destroyed.
- **Box opening:** the existing `OpeningAudio` engine keeps its phase-locked timing. Its slots now
  come from `SoundManifest.opening` (14 of 48 are filled; the rest stay silent). Its Sounds join
  the Reveal group, so the Sound switch covers them. Its preload keeps one resident Sound per ID
  for the controller's lifetime. The close sound is the Sfx `close`, played when the session
  enters Closing, because the opening's own cues must end inside its 0.11 s exit curtain.
- Sounds are presentation only. Server-confirmed sounds play from the client's existing reply and
  snapshot handling. No remotes, server code or data schema changed.

Two Roblox behaviours shaped this design (measured in Studio):

- `ContentProvider:PreloadAsync` reports audio **ID strings** as Failure. Preload Sound instances
  instead.
- A new Sound is ready instantly only while another live Sound holds the same asset. A cold load
  took about 0.1 s, longer than the opening's 75 ms one-shot tolerance.

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
- **A saved volume setting:** the Sound switch is session-only. Saving it would need a schema
  change, which wasn't authorized.
- **Background music:** that's backlog item 16.

## Checks

Automated: `tests/Sfx.spec.luau` covers the manifest data, placeholders, voice caps and
retriggering, cooldowns, the UI gap, groups, mute, preload and teardown.
`tests/OpeningAudio.spec.luau` checks that the slots come only from the manifest, that the
rejected pack stays disconnected, the Reveal group, the resident cache and the ceilings.
`tests/Screens.spec.luau` covers open, tab, close, click, denied and the Sound switch.

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

1. **Listening pass**, on headphones, speakers and a phone at a fixed volume. Check every row
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
