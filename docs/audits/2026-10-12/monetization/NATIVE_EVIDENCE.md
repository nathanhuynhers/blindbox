# Native evidence — 2026-10-12

Local RobloxWorkspace.rbxlx; PlaceId0, GameId0, studioPersistence=false; no production profile or real purchase fixture. Studio connection579b111f-cb77-473f-b4b9-f494d1082fd6. Read-only initial check confirmed purchase fence source. Final StoreScreen and Interface were copied exactly from repository source into the unsaved local place; no place published or saved through Studio.

Store matrix: tests/StudioStore.client.luau + StoreFixtures installed temporarily. A temporary BindableFunction selected each of24 fixture states and five tabs. tests/StudioStoreCheck.client.luau ran after two native Heartbeats at both CanvasPosition endpoints. **240 PASS cases per viewport**, no remaining assertions failed:

| Preset | Actual camera viewport | Status |
| --- | --- | --- |
| HD1080 |1919×1079|PASS|
| HD720 |1279×720|PASS|
| iPhone7 landscape |666×374|PASS|
| iPhone17 Pro landscape |750×381|PASS|

This is native layout/text/target/scroll reachability with mocked state. It is not a native Marketplace or DataStore purchase test, physical touch or full visual approval of every state. Motion OFF was used. Screenshots sampled desktop Store and landscape-phone Store; all480 product-state views were not visually reviewed individually.

Long-label fixtures failed before the title constraints: ordinary cards at desktop/phone; Starter hero at compact desktop. Corrected card titles use min14/max19 (phone max17), Starter title min18/max30 (phone max22), preserving fixed space for benefits and controls. All native matrix cases passed after those changes.

Native scroll units: at UIScale1.498611, CanvasPosition293.580566 pixels, absolute canvas920 and window626.419434 pixels. Card logicalY296 rendered to443.169445; absolute card offset149.59 + CanvasPosition293.58 =443.17. Scaling CanvasPosition again caused false unreachable assertions. Corrected checker uses pixel units.

Production Store opened using native mouse input through HUD StoreButton and Upgrades tab. Selecting Card_doubleClaim programmatically reproduces the actual GuiService selection observer:
- Before: top430.080566, bottom855.686127, window626.419434; selected card not fully visible.
- After: top196.080505, bottom621.686066, window626.419434; fully visible. CanvasPosition795.533447; free WalkSpeed36.
- Simulated ButtonR1 native input switched fixture Featured→Upgrades (selected attribute verified). This is virtual gamepad input, not a physical controller.
- Forty available Coins→Perks→available Coins cycles:736 descendants before/after, stable. This proves fixture instance-count stability only; native connection count was not measured.

Offline popup visual matrix remains NOT RUN: the first attempted control export did not replace the existing fixture, so its apparent successes did not test the popup and were discarded. A restart/retry stalled while starting Play and was terminated. Do not count those calls as popup acceptance. Existing standalone OfflineDoubleClient suite is separately PASS.

Native two-client same-server tests, native service purchases/persistence, real prompts/focus return, opening Stop/automation/paid effects, physical devices and all popup states remain NOT RUN.

Cleanup PASS: confirmed Edit mode; temporary StoreFixtures ModuleScript removed; StopSimulationAsync succeeded and Studio reset to default viewport. Local verification edits were not saved/published.
