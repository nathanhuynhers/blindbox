# Player walkthrough and observations

Build: master / 4b50fb76debb34507e0bc6a6b242a26d501412be, isolated unsaved Studio place. See [REPORT](REPORT.md) and [COVERAGE](COVERAGE.md).

## Natural fresh-player journey

The required progression was completed before any developer grant or tutorial bypass. Inputs were the Studio tool's native pointer/keyboard path; no action callbacks or gameplay remotes were called manually during this journey. The initial device was iPhone 7 landscape, effective 666×374, UIScale1. This was emulated touch presentation, not a physical phone.

The timestamp origin was an audit observer installed after initial load/HUD inspection, not the network join. Tool round trips, screenshots and inspection pauses are included. These values are reproducible event evidence, **not an uncoached onboarding-speed benchmark**. The exact initial load duration and the separate first box-tap timestamp were not instrumented.

| Milestone | Seconds after observer start | Observed authoritative result |
| --- | --- | --- |
| Initial observed ready state | 0.50 | 4,500 Coins, empty inventory/Display, Welcome step1 |
| First Welcome opening acknowledged | 1.85 | Moon Moth, Uncommon, ×1; step2; Coins unchanged |
| First Display placement | 49.80 | Moon Moth in slot1; step3; rate10.9546166/s |
| First native world collection | 98.96 | +538 Coins; wallet5,038; step4 |
| Next paid opening acknowledged | 114.78 | Grove cost1,500; wallet3,538; Sunbeam Sprite, Rare; step5 |
| Welcome x10 acknowledged | 159.38 | Exactly10 figures; step6; wallet unchanged |
| Optional Shelf placement completed | 276.79 | Mallow Cap on Shelf4 top-left spot; step7 |
| Day1 login claim | 332.99 | +500 once under double click; wallet4,038 |

The paid box was already affordable from the starting wallet; the observed collection taught the banking mechanic and advanced the Quest. It was not the sole source of purchase funding.

### What happened

1. Loaded/spawned on the owner's plot and inspected the HUD, Quest and Shop. “Studio preview - not saved” accurately described the session.
2. Activated the free Welcome Box. The ordinary cinematic awaited Open, revealed Moon Moth and offered Put on Display. The figure was readable and the action worked.
3. Used Put on Display. The Quest advanced only after the confirmed placement.
4. Used ordinary W/A/S/D movement to reach the occupied collection plate. A server-generated collect: receipt transferred538 Coins. The displayed bank and wallet are distinct: displaying earns into the bank, and collecting moves it to Coins.
5. Opened a paid Grove box from Shop. The server charged1,500 once and awarded Sunbeam Sprite. Keep returned to Shop.
6. The Welcome reward popup appeared. Open Welcome x10, followed by native Skip, reached the ten-result summary.
7. The ten awards were Acorn Dot, Sunbeam Sprite, Sprout Scout, Sprout Scout, Sprout Scout, Acorn Dot, Pebble Pip, Sprout Scout, Pebble Pip and Mallow Cap. Only each first new discovery had NEW. Final inventory: Acorn×2, Sprout×4, Pebble×2, Moth×1, Sunbeam×2, Mallow×1 —12 copies, six unique.
8. Grove completed6/6 and awarded Shelf4. The summary showed all ten figures and the completion panel. AQ04 records its truncated names; the batch itself was complete.
9. Done returned to the route, then Shelves was opened. A natural Mallow placement completed the optional tip. One intermediate coordinate targeting attempt selected a different picker row than intended; the actual placed figure was recorded and the Quest completed through a supported action. This was not classified as a game placement bug.
10. Opened Collection, Display, Shelves, Goals, Daily Login and Shop. Day1 claim paid500 once, then became claimed/unavailable until the shown next UTC boundary.

[Journey trace before login](evidence/natural-journey.json) and [full action/reply trace](evidence/final-runtime.json).

### Evidence sequence

- [Fresh Shop](evidence/fresh-shop.jpg)
- [Welcome awaiting Open](evidence/welcome-await.jpg)
- [Moon Moth reveal](evidence/welcome-reveal.jpg)
- [First Display](evidence/welcome-display.jpg)
- [World income view](evidence/first-coins.jpg)
- [Collection success](evidence/collect-success.jpg)
- [Paid result](evidence/paid-result.jpg)
- [Reward popup](evidence/welcome-reward-popup.jpg)
- [Welcome summary](evidence/welcome-ten-summary.jpg)

### Clarity and hesitation

The Quest's target/highlight and actual-action progression provided a workable path without a bypass. Its collect step taught that the Coins pill is not the accumulated figure bank. Keeping Collection (discovery/reference), Display (income) and Shelves (cosmetic copies) distinct was understandable after placement.

Compact Display pricing/bank information looked cramped and overlapped its card boundaries (AQ02). Touch controls covered parts of the menu, with confirmed center-hit obstruction on Shelf Sunbeam Sprite (AQ01). The summary's shortened names required later Collection browsing to identify full names (AQ04). Goals' scrolling short-phone card could make its claim action easy to overlook (DR01).

This is an expert-operated walkthrough with tool pauses and source knowledge. It does not establish what an uncoached new player would do or how long they would hesitate.

The natural path did not include an actual plaza walk, E stall activation, leaderboard reading or another player's plot input. Those remaining interactions are explicitly blocked in COVERAGE rather than implied by source inspection.

## Progressed continuation — clearly labelled fixture funding

Before the grant, native desktop Settings switched Motion to Reduced and both saved volume values to50%; snapshots confirmed them. Native Equip Best filled Moth/Sunbeam/Mallow, total54.655712/s with a4.968701/s set bonus. Its second rapid click returned “Already your best Display.” Native daily goal claim paid1,000 once, bringing the wallet to5,038.

Only then was the Studio-only grant remote used to add20,000,000 Coins. This was unsaved isolated fixture money, not naturally earned progression.

- Sequential native Unlock4/5/6 succeeded at40K/400K/4M. Locked predecessor guidance advanced correctly; six slots ended unlocked.
- A separate collect: receipt for11,195 Coins occurred during expansion. It is kept separate from the unlock charge ledger; wallet deltas alone were not treated as duplicate purchases.
- Two native Shelf-buy clicks were accepted as two distinct valid requests, costing50K and125K. Owned Shelf count became6 and next price312.5K.
- Further native spot/copy-limit/carousel tests stalled. No successful activation is claimed for those late attempts.

[Progressed observations](evidence/progressed.json), [final natural-player state](evidence/final-runtime.json).

## Native multiplayer — synthetic actions in real clients

A native two-client server was launched using StudioTestService.ExecuteMultiplayerTestAsync(2). This used actual engine Players and replication. Its remote requests below were synthetic isolated probes, not player-input acceptance.

Player1 and Player2 received separate plots. Welcome/purchase exact retries awarded once; changed contents reusing a request ID were rejected. Concurrent buys charged1,500 once per player. Player1's volume/inventory mutations did not appear as Player2's private state.

A server teleport fixture moved Player1 into Player2's plot. Place was denied; direct Collect was denied; Home with a foreign identity payload returned Player1 to their own spawn. After returning, owner placement/removal retained the bank, and editor-held Shelf placement/removal succeeded.

A labelled4,500-Coin fixture grant funded three deal purchases. Player1's offer stock fell3→0, the fourth purchase was denied, and the replacement client's stock stayed3. Stock is per player by design.

An actual engine disconnect, induced by a test Kick, removed Player2's plot. AddPlayers(1) created Player3 and reassigned the freed plot slot2. See [multiplayer evidence](evidence/multiplayer.json).

The clients had a1×1 camera viewport, so this test did not close native two-player visual/prompt/input acceptance. The isolated test ended normally.

## Returning-player and interruption boundaries

Real save/rejoin, offline return, migration, reward rollover and saved-volume rejoin were **Blocked**: PlaceId/GameId0, no authorized isolated persistent test store. The fresh restart's default state was expected for unsaved preview and is not reported as data loss. Existing domain suites cover the implemented state/lease/failure rules, with their service doubles clearly identified.

Reset/death mid-purchase/opening/claim, leave mid-transaction, pending failure/lost reply, full-motion rare tours, resize during batch, gamepad switching and focus loss/resume remain blocked by the rendering/input environment. A presentation fixture could not advance beyond Enter with the1×1 viewport; cancelling/destroying it restored camera and removed opening GUI/stage/input resources. That is cleanup evidence, not full cinematic acceptance.

At completion, Play was stopped, the audit place returned to Edit, device simulation was stopped/restored and the user's other Studio instance remained untouched.
