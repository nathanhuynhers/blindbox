# Desktop and mobile UI review

2026-10-09. Repository revision `130f649`; fresh, unpublished Rojo build in Studio.
Inspection only: no gameplay source changes or published assets. Temporary client fixtures
rendered the actual production modules with empty and populated presentation snapshots.
Fixture callbacks recorded **zero gameplay requests**; no progression was granted.

## Confirmed defects

| Priority | Defect | Reproduction / evidence | Recommended change |
| --- | --- | --- | --- |
| P1 | Collection's primary action is unreachable in a short desktop window. The fixed filter row also overlaps the details pane. | Average Laptop preset overridden to 1024×600, effective viewport 1023×599. Open Collection and select an owned figure. `FigureAction` lies at Y=432–488 while the clipping Body ends at Y=401 in native GUI coordinates; there is no details scroller. Missing filter is partly covered by the preview. [Screenshot](small-desktop-collection.jpg). | Make the details pane scrollable or use a compact layout based on available body height. Adapt filter widths and grid columns to available middle-pane width. |
| P2 | Mobile Goals collection names and headings become unreadable. | iPhone 7 landscape (666×374) and Galaxy A06 landscape (705×338). The three-column layout leaves collection names only 20px and 33px wide, respectively. Labels become `P…`, `Ti…`, etc.; the progress heading and free-box heading also truncate. [Screenshot](mobile-goals.jpg). | Use a mobile layout with wider rows or stacked sections; preserve collection names and put status on another line. |
| P2 | Desktop notifications obscure the Coin balance. | Open a desktop screen and show a normal error such as “You must be inside your own plot to edit your Display or Shelves.” The toast occupies the same top band as the balance. Reproduced with the real `Interface` at 1023×599. [Screenshot](desktop-notification.jpg). | Reserve a notification area that does not intersect the HUD, adapting to the toast's actual height. |
| P3 | Android Hourly Deal loses its bottom border and padding. | Galaxy A06 landscape: the popup uses CoreUISafeInsets, giving 705×280 usable space. The fixed card is 600×286 at Y=8, ending at Y=294. Buy ends at Y=280, leaving its outline/drop and card bottom outside the visible region. The main Buy target itself remains reachable. [Screenshot](android-deal.jpg). | Size or scroll the card against its own safe height, retaining space for the button outline and bottom padding. |

## Code locations

- Collection: `src/client/CollectionScreen.luau:147–211`; fixed desktop filter widths at 172,
  preview height at 184, action at 211. `UILayout.luau:30` chooses the desktop branch above
  the phone threshold; its panel height budget is at 83–99.
- Goals: `src/client/GoalsScreen.luau:196–238`; three fixed columns and desktop-style
  name/status reservations remain in the phone layout.
- Notifications: `src/client/Interface.luau:250` anchors desktop toasts above the panel;
  `Notifications.luau` expands their height upward.
- Deal: `src/client/DealPopup.luau:67` selects CoreUISafeInsets; 206 computes a fixed
  card height without limiting it to that safe area.

## Checks actually performed

- Pinned tool provisioning, zero-dependency `wally install`, and Rojo 7.7.0 build completed.
  The generated lockfile line-ending change was restored.
- Native Studio rendering at iPhone 7 and Galaxy A06 landscape sizes, Average Laptop
  (1365×768), HD 720, HD 1080, and a smaller desktop viewport (1023×599).
- **61 main-screen render cases** covering Shop, Collection, Display, Shelves, Goals and
  Daily Login. All five Shop/Collection collections were checked on Android and laptop;
  empty and populated states were checked on iPhone. Smaller desktop and HD presets
  received the six-screen pass. Populated data included all 43 figures and six Display slots.
- Native button dimensions, text fit, ancestor clipping and scroll-canvas reachability
  were inspected. Selectable main-screen controls met the 44px target in checked cases;
  Collection's short-desktop details action is the confirmed reachability exception.
- Android scroll endpoints for Shop product/contents, Collection grid, Shelf cabinet and
  picker, Display picker/body, Goals and Login were checked. On-screen selectable controls
  passed hit-order inspection against the actual PlayerGui, including TouchGui.
- Settings, Welcome Quest reward, offline earnings, Hourly Deal and Open 10 summary were
  rendered. Settings controls fit on Android and laptop. Open 10 retained ten result cards,
  the collection-progress panel and Done at checked desktop and Android sizes.
- Production `tests/StudioUI.client.luau` passed against the original HUD on Android and
  laptop. Pending-state presentation was also checked on the real Interface.
- `tests/StudioOpeningLayout.client.luau` passed **459 native assertions**: Android single
  result and batch result, iPhone batch result, laptop batch result. These covered Pebble
  Pip model projection, text, action bounds and input priority, including Display and Skip.
- Fixture UI and controllers were removed, original UI/device preset restored, and Play stopped.

## Limits and observations

This is Studio presentation and layout verification, not physical-device touch acceptance,
a complete purchase/edit walkthrough, persistence acceptance, multiplayer testing, or an
all-rarity animation certification. Desktop and mobile have no separate source branches;
the same client modules choose their responsive layout.

Some long figure names truncate in compact Display pickers and Open 10 cards; unlike the
Goals defect, these retain portraits and contextual identity. Treat these as polish items.
Subpixel badge widths and the projected box-art labels sometimes report `TextFits=false`;
they were not counted as new defects without a visible usability failure.

Studio's MCP resets camera type when a command changes it. Opening tests were rerun using
a deferred presentation beyond that boundary and then passed. The initial tool-boundary
cancellation is not a production opening defect. The unpublished preview also logged its
existing leaderboard DataStore retry; that is not evidence of a UI failure.
