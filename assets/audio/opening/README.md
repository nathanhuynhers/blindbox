# Porcelain & Starlight

An original 48-cue sound pack created for `nathanhuynhers/blindbox` at the user's
explicit request on 2026-10-01. All sounds were synthesized for this project;
no third-party recordings, samples, melodies, instrument libraries or audio
dependencies were used. Authorship source: [deterministic generator](../../../tools/audio/build.py).

The pack uses small ceramic resonances, warm filtered air and soft harmonic
textures. Common is a simple, pleasant confirmation; Uncommon adds harmony;
Rare broadens the chime; Legendary has a grounded, separately articulated
double pulse. Mythical uses an inward gesture, suspended pearl and inharmonic
bloom with a resolving reveal. Its identity comes from composition and silence.
Critical sound information is centered; stereo adds modest width.

**Delivered:** all 48 original WAVs uploaded to the configured Roblox user
`103346374`, with all 48 reported **Approved** by Roblox's asset metadata API.
The exact check time and IDs are in [roblox_status.json](roblox_status.json).
Upload receipts, owner and source hashes are in [uploads.json](../../uploads.json)
under `Audio.Opening.*`. The pack's source paths, durations and hashes are in
[pack.json](pack.json). Production `OpeningAudioConfig` resolves these IDs through
the generated shared `AssetIds` module. Sounds preload when the opening controller
is created, before the first opening, without delaying gameplay.

Open [listen.html](listen.html) to compare full openings for all five rarities,
including reduced motion, or play individual cues. Preview audio follows the
production state machine, cue sequence and mixer at 240 Hz. It includes a 0.7s
Tap to Open wait, a new-discovery accent, and a 1.2s result hold. Preview WAVs
are local review artifacts; only the 48 source cues were uploaded.

All masters are stereo 16-bit PCM WAV at 48 kHz. The offline audit checks
headroom, mono retention, DC, silent one-shot endpoints and loop seam continuity.
The ten combined mixes peak between -11.74 and -10.74 dBFS, with no clipping;
mono loss is at most 0.06 dB. Measurements are in [quality.json](quality.json).
Roblox transcoding, in-experience asset permissions and device listening still
require a Studio playtest; this delivery does not claim one was performed.

Rebuild/review from the repository root using Python's standard library:

```powershell
python tools/audio/build.py
python tests/run.py build/tools/luau/luau.exe
python tools/audio/preview.py build/tools/luau/luau.exe
python tools/audio/upload.py
```

The last command validates all files offline. Explicit `--upload` uses the existing
credential-safe, resumable asset pipeline and skips unchanged uploads. It refuses
to replace changed assets implicitly. `python tools/audio/status.py` performs an
authenticated read-only moderation check. Never put credentials in this folder.

For playback, sync the current source through Rojo and start a fresh Studio Play
session. No manual recording, upload or ID entry is needed. Keep these restricted
assets under their existing owner; a differently owned experience needs an explicit
experience permission grant. See the [Studio listening procedure](../../../docs/OPENING.md#audio-review-procedure).
