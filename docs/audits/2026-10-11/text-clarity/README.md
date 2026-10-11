# Text clarity verification

Status: **blur mechanism reproduced and fixed; desktop screen-text sweeps completed;
full player/device acceptance remains incomplete**.

The user reported text/figure blur at automatic or lower graphics quality and supplied
Sunbeam Sprite / Moon Moth reveal screenshots, including a report from a 2560×1440 display.
The reveal's former full-screen CanvasGroup flattened its native labels into a texture limited
by the client's graphics quality. RevealCard now uses a Frame with individual property fading;
OpeningView retains the existing fade timing. Roblox documents this CanvasGroup behavior in
[the engine reference](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup).

## Verified from source

- No production source creates a CanvasGroup, BlurEffect or DepthOfFieldEffect.
- HUD balances, income, Daily/Home captions, Dock captions, goal tracking and settings use
  native TextLabels/TextButtons inside Frames.
- Collection, Shop, Display, Shelves, Goals and Daily Login use native labels. Figure and
  box previews are separate ViewportFrames, rather than containers for the menu text.
- Reveal, Open 10 summary, notifications, Welcome Quest/reward, offline earnings and deal
  popups use native screen UI. Responsive TextScaled constraints and small captions still
  require actual rendering checks; native labels alone do not prove readability.
- World signs use SurfaceGuis with finite canvas sizes, and owner/earnings/tutorial labels
  use BillboardGuis. They require checks at normal interaction distance, camera angles and
  both daytime/nighttime. Their quality cannot be certified from source values.
- The reveal fade regression covers full/partial fades, snapshot refresh without compounded
  opacity, transparent label backgrounds and responsive reparenting. The standalone suite,
  StyLua, Selene, targeted Luau Language Server diagnostics and Rojo build passed after the fix.
  Those checks do not render Roblox UI.

## Native Studio verification actually run

Opened the ignored local build `build/text-clarity.rbxlx` directly and ran it through
Studio MCP. Presentation fixtures used the production UI modules, no-op action callbacks
and a temporary snapshot; they did not buy boxes, grant Coins or mutate player profiles.

- At an effective 1920×1080 viewport, a temporary recreation of the former CanvasGroup
  visibly blurred the reveal badge/title/button. Returning those same elements to the
  fixed Frame rendered sharp text. This was a native comparison, not an image edit.
- Swept Studio engine levels **01–21** with `RenderSettings.EnableFRM = false` and
  `EditQualityLevel` set/read back at each step. Roblox documents this fixed Studio
  quality control in [RenderSettings](https://create.roblox.com/docs/reference/engine/classes/RenderSettings).
- Completed 21 captures each for Reveal, HUD, Settings, Collection, Shop, Display,
  Shelves, Open 10 summary and Welcome reward at 1920×1080. Reveal, Settings, Shop,
  Display, Shelves, summary and Welcome reward captures were byte-identical throughout
  their respective sweeps. HUD/Collection whole-image comparisons differed after the
  temporary MCP click indicator disappeared; text remained sharp in inspected captures.
  Whole-image equality is corroborating evidence within this capture path, not proof
  of the graphics behavior of a different renderer or device.
- The initial production HUD/Welcome Quest was also captured with Automatic graphics.
- At effective 2560×1440, inspected Reveal, Collection, Shop, Display, Shelves, Goals,
  Daily Login, summary, Welcome reward, offline earnings, deal popup and Settings.
  Text was legible in returned captures; MCP resampled these to **1920×1080 JPEGs**,
  confirmed from image headers. They are not original-pixel 1440p acceptance evidence.
- A visible Collection text-fit query reported no overflowing text. After the later
  simulator failure, a separate query found no text-fit failures in the actual
  706×579 HUD GUI; that was not the requested phone resolution and does not sign it off.
- Captures omitted the 3D world and ViewportFrame figures, although native inspection
  found loaded, opaque figure parts and preview cameras. Neither figure sharpness nor
  SurfaceGui/BillboardGui appearance can be signed off from those images.
- The offline earnings sweep stalled around engine level 10. Further captures stalled;
  restarting Play and reopening the build left `Camera.ViewportSize` at **1×1** even
  when the simulator reported 800×360. The remaining full sweeps were not completed.
- `SavedQualityLevel` changes were rejected with insufficient permissions, and MCP
  virtual input rejected Escape because it is a protected CoreGui action. These tests
  therefore did **not** exercise the published player's manual graphics slider 1–10.
- Console reported leaderboard DataStore requests failing in the local build and the
  rejected quality-setting attempt. No UI script error was observed in the completed sweeps.
- Both test sessions were stopped. Automatic rendering (`EnableFRM = true`,
  `EditQualityLevel = Automatic`), FitToWindow scaling and the default viewport were restored.

## Remaining acceptance matrix

Run every row at player graphics levels **1–10 and Automatic**, using actual effective GUI
sizes **1280×720, 1920×1080, 2560×1440**, plus phone landscape/portrait sizes supported by the game.
Record the observed quality setting and effective viewport; Automatic is device/load-dependent
and is not equivalent to one fixed manual level. Studio's engine levels 1–21 are a separate
range; record them separately if used. Do not claim that a Studio-only sweep proves every
physical device or the published Roblox player's rendering.

| Surface | Required states | Visual result |
| --- | --- | --- |
| World HUD / Dock | Small/large balance, income, Daily badge, Home caption, goal ready/incomplete | Desktop Studio sweep done; other states/devices/player slider pending |
| Settings | Motion, music/effects labels and values | Desktop Studio sweep done; devices/player slider pending |
| Collection | All/found/missing, owned counts, long names, detail stats, scrolled final row | Initial collection Studio sweep done; other states/devices/player slider pending |
| Shop | All collections, title, price/shortfall, odds/pity, free box, contents | Initial collection Studio sweep done; other states/devices/player slider pending |
| Display | Empty/filled/locked slots, earnings, picker, long figure names | Mixed slot states Studio sweep done; other states/devices/player slider pending |
| Shelves | Filled/empty spots, picker, shelf navigation, footer | Empty shelves and owned picker Studio sweep done; other states/devices/player slider pending |
| Goals / Daily Login | Ready/claimed, countdown, all day rewards | Inspected in resized desktop captures; full sweeps pending |
| Reveal | NEW/duplicate, compact/desktop, mid-fade/settled, batch Next/Skip | Settled NEW desktop Studio sweep done; other states/devices/player slider pending |
| Open 10 summary | Repeated figures, NEW tags, discovery progress, Done | Desktop Studio sweep done; devices/player slider pending |
| Notifications / Welcome Quest | Wrapped messages, error/success, guided step and skip | Initial quest HUD inspected; remaining states/sweeps pending |
| Welcome reward / Offline earnings / Deals | Amounts, guarantees, prices, small supporting text | Welcome Studio sweep done; offline/deal full sweeps pending |
| World labels | Display/Shelves/owner/shop/stall/leaderboard labels and earnings; day/night | Pending: omitted from capture output |

Accept only after inspecting captures at their original pixel size: readable glyph edges,
supporting text, no clipping/truncation that hides essential values, and no new blur when
lowering quality while holding the device, viewport and UI state constant. Image icons and
3D figures are separate from native text and must not be counted as text passing/failing.

The completed desktop captures support the CanvasGroup fix and the inspected screen text.
They do not justify a blanket claim that every HUD, figure, graphics-slider level and
physical device is blur-free. Resume remaining rendering checks when MCP provides a real
viewport/capture again; retain the distinction between Studio evidence and player acceptance.
