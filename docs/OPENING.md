# Blind-box opening presentation

Implemented client candidate; **Studio visual, input and device acceptance remains pending**.
No server code, remote contracts, catalog, economy values or persistent fields changed.

## Sequence and controls

Buy and Daily use the same collection-specific opening: the normal interface gives way to a
dim full-screen stage, a Grove or Tide box settles in with a small bounce/turn, pauses, and
shakes with increasing intensity. **Tap to open** appears once ready. Tap the box or the large
button; the lid lifts, a soft halo and small particle burst accompany the silhouette, then the
actual figure settles into view. Continue remains available until pressed; there is no auto-dismiss.

Skip becomes available when anticipation starts (after the 0.55-second entrance). It goes
straight to the confirmed figure, preserving NEW/quantity feedback. A short 0.35-second result
guard prevents that same click from also dismissing it. Gamepad A opens/continues, B or X skips;
A also activates a selected Skip button. Enter activates the selected/default action. The main
button and Skip have 52–54px and 48px heights respectively. Short landscape screens place the
figure beside the controls; portrait screens stack them. The camera fits the viewport aspect.

Scrap redemption uses the silhouette/figure spotlight directly, because the figure was chosen.
Opening or skipping never sends a grant, charge or confirmation to the server.

| Rarity | Presentation | Entrance through reveal, excluding player's wait |
| --- | --- | --- |
| Common | Soft mint halo, one ring, eight small sparks, light shake | 2.82s |
| Uncommon | Lavender lighting, two rings, fourteen sparks, fuller shake/pop | 3.34s |
| Rare | Gold halo visible before the figure, three fine rings, twenty-two sparks, longer silhouette beat | 4.08s |

There are no full-screen white flashes or world-camera changes. Reduced motion removes the
shaking, entrance travel, camera-distance animation, figure pop, badge tilt and particles. It
uses short fades/static poses, with the same rarity colors/rings, name and discovery information.
Its timed sequence takes about 1.2 seconds before Continue. The setting is captured from the
existing Shop motion toggle when each presentation starts.

## Ownership and lifecycle

`init.client.luau` retains the authoritative snapshot from before the request, including across
retries and passive snapshot updates. On a matching successful reply, `OpeningResult` packages
the confirmed figure, NEW flag from prior discovery history, and quantity from the reply's
snapshot. It never parses message text or maintains another inventory. Previously discovered
figures remain duplicates even if their old copies were recycled. NEW gets a small cream badge;
duplicates say their owned quantity and “Another for your collection.”

The controller only presents that immutable result. The existing one-pending-request mechanism
rejects repeated reply IDs at the acknowledgement boundary, and client actions are blocked during
an opening. A controller also rejects concurrent sessions and its most recent presented ID.
Respawn, cancellation, GUI destruction and client teardown remove the presentation and restore
UI/input selection. A reply still pending during respawn is processed normally when it arrives.
The granted figure remains in the authoritative inventory even if presentation fails or is closed.

The controller owns a render connection only during timed phases and the brief result guard;
waiting for Open/Continue has no animation loop. Each session owns its GUI, local models,
bounded spark frames, sound instances, input bindings and event connections. No delayed tasks,
workspace camera modifications or new dependencies are used.

## Module and asset boundaries

- `OpeningResult`: read-only snapshot-to-presentation adapter at the acknowledgement boundary.
- `OpeningState`: deterministic phases, timing, skip/continue guards and cancellation.
- `OpeningController`: session, input, sound cue timing and teardown.
- `OpeningView`: responsive UI, viewport, halo, silhouette and animated poses.
- `OpeningBox`: original procedural carton/lid, leaf/seed Grove motifs and shell/bubble Tide motifs.
- `OpeningConfig`: presentation timings, rarity profiles, packaging palettes and audio IDs.
- `OpeningAudio`: bounded, non-looping local sounds; missing IDs are silent and never block.

Replace `OpeningBox.create(parent, collection)` with production art behind the same
`{ model, pose(CFrame, lidLift) }` interface. Keep the carton centered on the origin, roughly
3.2 × 3.2 × 2.7 studs, with an independently lifted lid; all created objects must descend from
the supplied model/scene. The shared existing procedural figures are reused unchanged.
Neither packaging nor figures use downloaded branded art.

All sound IDs are currently **empty**. Add original/licensed `rbxassetid://` IDs to
`OpeningConfig.sounds` for entrance, shake, open, buildup, impact and discovery. Each rarity's
`sound` supplies its additional reveal cue. Keep them short: at most eight one-shots can be
created per opening and all stop at teardown. No audio is required for sequencing. Add a future
rarity profile to the config to customize timing/color/effects without controller branches;
unknown rarities fall back to Common. No Secret figures or rarity odds were added.

## Studio acceptance checklist

Start Play from the rebuilt place or current Rojo sync. Watch **client and server Output**.
For deterministic visual coverage, finish any pending purchase/opening, then paste
`tests/StudioOpening.client.luau` into the **client Command Bar**. Its small fixture launcher
previews both collections, all three rarities, NEW, five-owned duplicates and redemption.
These are explicitly visual fixtures: they send no remotes and grant/spend nothing. Exit the
preview before testing actual acquisitions. It is not mapped into the shipped game.

- **Common/Uncommon/Rare:** preview both collections, opening each by tapping the box and then
  the button. Compare subtle mint, richer lavender and pre-reveal gold; confirm all twelve
  figures' framing through real acquisitions or by changing the fixture's catalog ID. Lid,
  silhouette and final figure should read clearly without clipping or harsh flashes.
- **NEW/duplicate:** preview both. Then buy/claim in unsaved preview; compare the actual result
  with Collection, repeat a figure and check quantity increases exactly once. Redeem an
  undiscovered figure and confirm the direct spotlight, not a sealed mystery box.
- **Rapid input/skip:** spam purchase, tap/open, Skip and Continue. Skip during anticipation,
  shaking, lid lift, silhouette and reveal. Only one result appears, skipped figures stay owned,
  and the result never disappears on the same click. Wait at both prompts for 15 seconds.
- **Reduced motion:** toggle the real Shop setting, then acquire a box; also toggle it in the
  fixture launcher. Check each rarity: no shake/travel/particles, with rarity and NEW still clear.
- **Repeated openings:** run the launcher's 20-interruption lifecycle check, then manually
  complete/skip 20 openings. After closing, `PlayerGui.BlindboxOpening`,
  `SoundService.OpeningSounds` and the two `BlindboxOpening*` context action bindings must be gone.
  Watch for Output errors, accumulating instances or input that stays blocked.
- **Devices/input:** use Device Emulator phone portrait and landscape (including a small
  568 × 320 landscape viewport), tablet and desktop. Resize while waiting and revealing. Check
  safe-area margins, readable name/quantity, unclipped figures and reachable Skip/Continue.
  Test mouse, touch, gamepad A/B/X and selection changes; movement/menu selection returns afterward.
- **Respawn/interruption:** reset the character during shake, silhouette and final result;
  confirm normal UI returns and the granted item remains. During a fixture, destroy only its
  `BlindboxOpening` ScreenGui in client Explorer and confirm cleanup. Exit the fixture afterward.
- **Real delayed replies/multiplayer:** use Studio network emulation to delay a real acquisition
  beyond the existing three-second retry. Reset during that wait as well. One grant and at most
  one reveal should result; an older/unmatched reply must not replace a newer result. In a
  two-client test, only the purchasing player's UI changes; both inventories stay authoritative.

The automated suite exercises the real state machine and result adapter, not engine rendering.
The fixture launcher and checklist have **not** been run by the coding agent.
