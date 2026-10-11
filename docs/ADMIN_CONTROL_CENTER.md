# Admin Control Center v1

Implemented; native runtime and visual/device verification pending. No live place was published
and no production profiles were edited as part of implementation.

## Access and configuration

`src/server/AdminConfig.luau` configures the explicit owner UserId **103346374**. Change
`ownerUserId` to another positive integer to change ownership, or `0` to disable access.
Creator identity, usernames, display names, group membership and Studio mode grant no permission.
All current commands require Owner. The registry carries a required permission and the resolver
has Owner/Developer/Moderator ranks for future explicitly assigned identities; no other identity
currently receives a role. The config and execution code remain in ServerScriptService.

After the owner's profile loads, **F2** or the **Admin · F2** button opens the console. Escape or
gamepad B dismisses a confirmation first, then closes the console. Close restores the normal UI.
Opening is deferred during a pending gameplay request, cinematic, reward popup or AFK handoff.
The retained GUI survives respawn; its owning client cleans up bindings/connections on destruction.
Other players receive neither the GUI nor its input handlers. They can still discover the remote;
server authentication is the security boundary.

Limits in AdminConfig: 100,000,000 Coins per change, confirmation from 1,000,000 Coins,
1–100 copies per figure grant/removal, 1–1,000 simulation rolls, five-minute overrides,
200 session audit entries. Wallet bounds continue to come from Economy. Set Balance accepts a
valid wallet balance but also limits the absolute change. The request bucket allows four calls
initially and refills at two per second, including reads, bootstrap calls, malformed requests and
retries. Unauthorized spam is denied immediately and audited once per connection.

## Available actions

| Section | Working controls |
| --- | --- |
| Players | Search current server players by username/display name/UserId; select yourself or another player; inspect and refresh; teleport to a living target using the existing HomeTeleport path; confirmed kick with optional bounded reason |
| Economy | Inspect Coins, Display income/set bonus, offline pending Coins and boxes opened; grant, remove, set balance; view recent selected-player admin entries from this server session |
| Figures | Search the actual catalog; filter collection, rarity and owned-only; inspect counts, Display/Shelf reservations; grant/remove quantity; confirmed one-copy grant of an entire collection |
| Boxes | Browse collections/prices/members; exact base and next ordinary effective rarity probabilities; inspect independent pity counters/curves/guarantees; set one counter or reset both; force next rarity/figure; clear override; bounded dry run |

The player inspector also shows profile revision, persistent/preview status, current save status,
plot, Display banks/slots, Shelf Unit count, discoveries, Welcome Quest stage, login streak and
daily Display progress. It does not expose persistence lock tokens or invent earnings histories.
Catalog figures have model assets but no image-icon field; v1 presents searchable text metadata
and real player avatar thumbnails without creating a duplicate image catalog.

Confirmation is mandatory server-side for kicks, collection grants, removals, multi-copy grants,
pity changes and overrides, and for large Coin changes. Confirmations capture target and revision;
concurrent gameplay invalidates the request and returns an updated inspector. Closing a dialog
does not execute it. Requests in progress disable controls; interruptions offer exact-request retry.
Displayed balances/inventory are updated from server replies, never optimistically.

## Architecture and integrity constraints

- `AdminProtocol` is the bounded payload/action/permission registry. `AdminService` supplies its
  handlers, response projections, rate bucket, session sequence watermark, audit and scoped overrides.
  The bootstrap resolves callback Player.UserId and current same-server sessions, not client identities.
- The game already owns its economy, quantities, discovery history and rolls in `Rules`, its
  probability/weight/pity logic in `CollectionEconomy`, and its live session lifecycle in the server
  bootstrap. Admin calls extend those mutation paths; there is no second data store or rolling engine.
- `Storage` remains the only profile writer. Every mutation requires a loaded, ready, unclosed,
  non-transferring session and an unexpired safe lease. The callback does not yield between target
  resolution, preflight, mutation and replay commit. Departure and shutdown cannot interleave in that
  interval. Normal autosave/final-save protections and failure pauses remain intact.
- A server-generated per-connection token and increasing sequence protect requests. The latest
  exact retry returns its receipt; reusing its sequence with different contents or any older sequence
  is rejected. The watermark has no time-based eviction. Bootstrap never resets it. Tokens/receipts
  are session-only; this is not durable cross-server command idempotency. Reconnect creates a new
  admin session, so inspect confirmed state before manually repeating an interrupted operation.
- Inventory bulk grants preflight every member before changing any. Normal openings and admin
  grants share `Rules.grantFigure`, discovery updates and first-completion Shelf rewards. They do
  not fake quest actions, increment boxes opened or advance pity for a direct inventory grant.
- Income settles at the old duplicate rate/Display bonus before quantity changes. Partial removals
  keep the unique Display slot and use existing stable Shelf reconciliation to trim excess copies.
  Final-copy removal clears Display, active Shelves and dormant legacy references, retaining permanent
  discoveries and earned Shelf rewards. Schema 14 requires banks to reference owned IDs: all whole
  Coins transfer to the wallet, the fraction below one Coin is forfeited with an explicit dialog warning,
  and insufficient wallet room rejects the entire removal before settlement/mutation.
- No schema, namespace or migration changed. Existing mixed-version writers still understand the
  resulting ordinary profile. Like gameplay mutations, an acknowledged admin change is **not** an
  immediate durable-save guarantee; server failure before the next successful save can lose it.
  No separate DataStore writes race the session owner.
- Audit entries contain UTC timestamp, actor/target IDs, action, requested values/identifiers,
  result and reason. Successful mutations, refusals and override consumption are captured. The
  200-entry ring and structured server Output logs are **nonpersistent**, not permanent audit history.
  Rate-limit refusals are not individually logged to avoid spam. Logging/presentation failure cannot
  rerun or interrupt a committed reward transaction.

## Overrides and simulation

One runtime override is keyed to a target UserId and collection, replaces any previous override for
that target, expires after five minutes and is cleared on departure. It is neither replicated to
ordinary players nor saved. Only the actual `Rules.open` call after successful **Buy / BuyTen /
Daily / Deal** preflight consumes it; a BuyTen changes only its first eligible roll. Invalid/stale/
replayed/insufficient-funds/quantity-limit requests and other players/collections cannot consume it.
Welcome Quest and Login reward openings deliberately exclude overrides to preserve reward-specific
rarity floors. Override consumption retains the normal price, copy limit, grant, box counter,
independent pity advancement and progression pipeline. A forced rarity uses the game's actual
within-rarity figure weights; a forced figure must belong to that collection.

Effective probabilities describe the next **ordinary** opening, using `CollectionEconomy.buckets`
including pity budget sharing and simultaneous-guarantee priority. Active overrides are displayed
separately. Each Legendary/Mythical counter resets on a drop of that exact rarity; setting progress
uses the existing integer bound 0..Economy.counterLimit, which can exceed the guarantee threshold.
Collections sharing a pity group share edits. Starter collections have no pity controls.

Dry runs use `CollectionEconomy.roll` and `advance` on a deep copy of the selected player's current
pity and a separate Random stream. They evolve simulated pity after each roll, exclude admin overrides and touch no wallet,
inventory, banks, discovery/progression or saved counters. Counts are bounded to 1,000; the service
reports rarity counts, not an assertion that empirical counts equal theoretical probabilities.

## Verification and remaining acceptance

Source manifest:

| Created | Purpose |
| --- | --- |
| `src/server/AdminConfig.luau` | Owner identity and configurable limits |
| `src/server/AdminProtocol.luau` | Registry, permission resolution and payload validation |
| `src/server/AdminService.luau` | Command handlers, session receipts, inspectors, audit and simulation |
| `src/server/AdminOverrides.luau` | Temporary per-player/box override lifecycle |
| `src/shared/AdminTypes.luau` | Explicit request/response and presentation types, no permissions/state authority |
| `src/client/AdminClient.luau` | Serialized requests and exact interruption retries |
| `src/client/AdminConsole.luau` | Four-section dashboard, dialogs, search, inputs and lifecycle |
| `tests/Admin.spec.luau`, `tests/AdminClient.spec.luau`, `tests/AdminUI.spec.luau`, `tests/AdminDisabled.spec.luau` | Targeted service, transport, UI and invalid-owner coverage |
| `docs/ADMIN_CONTROL_CENTER.md` | Configuration, architectural constraints and acceptance checklist |

Modified: `src/server/init.server.luau` and `src/client/init.client.luau` wire lifecycle/remotes/focus;
`Rules.luau`, `Transactions.luau` and `CollectionEconomy.luau` reuse mutations and expose the controlled
roll injection; `tests/run.py` and `tests/UIEngine.luau` extend the existing harness;
`tests/StudioOpening.client.luau` removes reliance on the arbitrary-player Studio grant;
`docs/ARCHITECTURE.md` links the security/session integration. The dependency set remains empty.

Affected gates: UI/navigation, server authentication/remotes, economy/inventory/progression,
opening probability/pity and Display/Shelf references. Persistence regression gates apply because
existing protected sessions are mutated, although there is no schema/storage algorithm change.

- **PASS:** pinned `rokit install`, `wally install`, formatting, Selene (0 errors/warnings), Rojo build,
  and Luau Language Server diagnostics with the local Roblox definitions and generated sourcemap.
- **PASS:** `tests/Admin.spec.luau` security/service/pipeline assertions;
  `AdminClient.spec` authorization, exact retry and interruption tests; `AdminUI.spec`
  real-component interaction/lifecycle assertions using the repository engine double. Runner output
  is the authoritative executed count.
- **PASS:** actual resolver/service fixtures deny all access with `ownerUserId = 0` and an invalid
  nonnumeric owner configuration; no target/authority callback is reached.
- **PASS:** the existing full Luau regression suite and 18 invalid-configuration startup fixtures,
  including gameplay, opening, pity, inventory/Shelves, profile/save failures, plots and UI suites.
- **NOT RUN:** native Studio Play, actual multi-client remotes/replication, isolated saved-profile
  rejoin, visual acceptance, physical input and device testing. No Studio MCP instance was connected.
- **N/A:** new figure assets, upload/reference-sheet gates, schema migration and live release.

Run locally with an existing compatible Luau executable:

```powershell
python tests/run.py path/to/luau.exe Admin.spec AdminClient.spec AdminUI.spec AdminDisabled.spec
python tests/run.py path/to/luau.exe
stylua --check src
selene src
rojo build default.project.json -o RobloxWorkspace.rbxlx
```

Native acceptance checklist (isolated Studio preview/test store, never live fixtures):

1. Log in as configured owner; check F2, entry button, Escape/B, focus restoration, all four sections,
   refresh/error/loading/empty states, searching/filtering, final scroll row and repeated reopen/respawn.
   Emulated test users must remain unauthorized; never add a Studio bypass to obtain a pass.
2. Use an unauthorized second client to call `Admin:InvokeServer("Connect")`, then submit forged
   commands (including copied token). Confirm denial, no GUI and unchanged target wallet/inventory/pity.
   For owner probes, retry exact requests and change their contents/sequence; verify no duplicate rewards.
3. Confirm grant/remove/set bounds, large-change dialogs, bulk inventory grants and copy-limit refusal.
   Remove displayed/shelved copies, inspect stable surviving placements, bank transfer, fraction warning,
   full-wallet refusal, progression and another client's updated physical figures.
4. Test both pity counters including guarantee/simultaneous priority. Arm a figure and rarity override;
   try a failed purchase, another box/player, BuyTen, a retry, five-minute expiry, manual clear and leave.
   Confirm exactly one eligible paid/daily/deal roll consumes it and subsequent rolls use ordinary logic.
5. Run dry simulations with active overrides; verify no player fields change. Disconnect a target before
   confirming an action, and test paused storage/handoff/shutdown refusal. Check kick uses the normal save.
6. In the **isolated Studio persistence store**, grant/remove, await a successful normal save, rejoin and
   verify quantities, placements, bank balances, discoveries and rewards. Review native storage failures
   without editing real profiles. Return to ordinary buy/earn/collect/Display/Shelves flows afterward.
7. Apply [device matrix](qa/DEVICE_TEST_MATRIX.md): 1920×1080, 1280×720, 667×375 landscape and an inset
   landscape phone preset. Inspect long names, 12-digit balances, wrap/scroll/confirmation reachability,
   readable text, 44px targets, mouse/keyboard, simulated touch and gamepad focus. Physical phone remains
   a separate pending check. Engine-double sizing tests are not screenshots or aesthetic acceptance.

Next improvements after acceptance: durable audit storage with retention controls, scoped explicit
Developer/Moderator identities, paginated inspection for very large legacy inventories, and request
metrics. Offline edits, bans, role-management UI, cross-server operations and live-event tabs are outside v1.
