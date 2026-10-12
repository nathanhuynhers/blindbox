# Store presentation handoff — 2026-10-11

**Implemented; native visual/device verification pending. Buying remains disabled.**
This extends the approved P07 shell. It does not approve D2, D3, MN-22 pricing, platform IDs,
purchase wiring or release. The parallel purchase task continues to own authoritative contracts.
No server/shared source, init, Protocol, persistence, global snapshot, routing/context interface,
purchase dispatcher or place configuration was changed.

## Boundary and integration

`src/client/StorePresentation.luau` is a **provisional presentation interface**, not a backend
contract. No purchase contract was present in this checkout when inspected. Screens do not read
purchase fields from the global gameplay snapshot. `StoreScreen.create(parent, ctx)` keeps its
existing call signature and returns the normal Screen plus `present(input)` and `tick(now)`.
The current Interface continues to use the existing shell and entry points; it supplies no Store
purchase data. Default cards remain Coming soon. Fixture data lives under `tests`, outside Rojo.

During the merge into master, P02 commit `7c2c41f` became available. Its implemented wire
contract is [PurchaseTypes](../../src/shared/PurchaseTypes.luau), documented in
[Purchase foundation](../PURCHASE_FOUNDATION.md#ui-integration-contract). This merge keeps both
tasks intact and does not connect purchases. Use that existing contract for the later boundary;
do not introduce a competing purchase remote or modify the global gameplay snapshot.

P02's `PurchaseState` event supplies owner-only sequenced snapshots and optional results.
Subscribe before requesting State; discard older sequence values within a connection. Project
`products[].available/reason`, `ownership/ownershipFresh`, `fulfillment`, `ready`, `ledgerStatus`
and `promptProduct` into presentation readiness, loading, availability and prompt states. Use
the P02-to-P07 product-key mapping in its integration table, including the three separate Coin
boost variants. Price lookup uses configured platform identity and the viewing player's runtime
metadata, never P02's planning defaults. The configured catalog remains off sale with nil IDs.

`PromptOpened` maps to prompting; `AwaitingReceipt` remains pending; `Recovering` remains
recovery. **Reserved is saved value awaiting gameplay integration, not delivered Coins, an
activated perk or a completed offline claim.** Keep it in Arriving and use explicit delivery-
pending copy when wiring the adapter. Aggregate reserved tokens are not yet activatable tokens.
Owned plus fresh confirms platform ownership; it does not prove a Starter bundle's gameplay
delivery. Rejected or Cancelled must not imply “weren't charged” without a confirmed no-purchase
result. P02 does not yet expose active timers, settings, automation jobs, policy-specific
eligibility, gameplay delivery acknowledgement or a configured offline offer; those inputs and
the final adapter subscription remain outstanding. Its `OfflineAward` is a future server input,
not a client purchase payload.

The later integrator should project the backend's public contract into these client types
in one focused boundary, rather than making the backend adopt these provisional names:

| Presentation input | Required authoritative source / meaning |
| --- | --- |
| `offers[key]` | Stable public catalog key mapped to the existing StoreCatalog keys. Availability, configuration/hidden flag, eligibility reason, verified ownership/Starter durable claim, superseding Coin tier and selected setting. Ownership loading and price loading are independent. Never infer ownership from prompt completion. |
| `priceText`, `priceLoading` | Localized, full platform Robux metadata for the viewing player; no hardcoded catalog fallback. The current production renderer suppresses prices while buying is disabled; illustrative prices render only with the fixture preview banner. Offline price remains TBD. |
| `coinDurations[15/30/60]` | Separate verified offer/state/price for each Coin token duration. Selected length must map to the correct backend product key before any later prompt. No product IDs live in the presentation catalog. |
| `outcome` | Idle, prompting, verifying ownership, saving fulfillment, recovering, granted, cancelled or failed. Confirmation must survive screen closure/reopen. Charged/unresolved delivery remains saving/recovering; only an explicit platform no-purchase result allows `noChargeConfirmed` and the “weren't charged” copy. |
| `promptActive` | Global single-prompt lock, including prompts outside the current tab. Opening focus and existing gameplay pending locks must also gate future intents. |
| `ownershipReady` | Confirmed initial entitlement reconciliation. An empty verified perk list is distinct from ownership not yet connected. |
| `tokens[]` | Stable token row key, public product key, unused count, duration, authoritative activation eligibility/status explanation. Backend must decide redundancy, incompatible Luck, duration ceiling/queue and atomic combo eligibility; client never consumes a token. |
| `timers[]` | Public product key, label, absolute UTC start/end, formatted absolute end time and suppression state. Display countdown interpolates a supplied server clock observation; it is not effect authority. Future adapter calls `tick` at a bounded cadence only while shown, rebasing on authoritative updates/reconnect. |
| `automation` | Verified status, selected collection, target/completed count, reserve, projected spend, optional current box price and pause/stop reason. Server owns the actual job, affordability, policy, cadence and stop acknowledgement. |
| `OfflineInput` | Exact frozen base N, exact doubled 2N, actual free claim amount/clipping, eligibility, outcome and confirmed no-charge result. Strings are already formatted; the popup never parses UI text or computes gameplay rewards. |

Expected backend notifications are catalog/metadata readiness, entitlement/policy refresh,
prompt lifecycle, verified ownership, durable fulfillment/recovery, boost inventory/activation/
expiry, automation status and offline award/claim/bonus updates. These are semantic events,
**not new Protocol names**. Associate progress with stable product/operation identity and
monotonic revision/generation; ignore stale replies and preserve unresolved deliveries across
navigation. My Perks Arriving must reconcile from durable state, not a client purchase history.

Future integration still needs a verified offline **award identity**, reservation/claim status,
exact numeric N/2N and wallet fit, separate from its formatted display strings. Bind a paid
intent to that reserved award, never the newest popup. Late receipt after free Claim must
show the extra-N arrival toast. Granted paid claim should show the confirmed 2N success and
close the popup; fixtures leave success visible for review. No permanent offline entitlement
exists. Production currently has no eligible paid offer, so Double & Claim is hidden; the normal
free callback and outside-tap claim remain functioning. The isolated fixture shows N and 2N
side by side with Price TBD and the disabled paid control.

Final wiring is deliberately outstanding: prompt authorization and platform prompt, metadata
refresh/retry, durable result subscriptions, real boost activation, entitlement setting changes,
Coin Shop Auto Open setup/start/Stop and persistent status, active HUD boost chip, offline paid
reservation/fulfillment, focus restoration after the native prompt, and verified player-specific
itemized before/after Luck odds. Luck sheets show the exact labeled **no-pity specification
examples**, never fabricated player odds. D2 behavior remains unresolved; no display example
enables a paid action. Coin-tier sheets disclose full-price upgrades/no credit when a verified
lower tier is supplied. No discount/value ribbons are invented.

All production purchase and activation/settings controls stay disabled. `StorePerkControls`
only enables local demonstration controls on a fixture input: count is bounded 1–100, count ×
fixture box price updates the cost display, reserve uses the supplied fixture amount, Start/Stop
changes a local label, switches change a local label, and activation confirms a preview without
consuming tokens or starting effects. `ctx.send` and MarketplaceService are never called.

## Isolated fixture workflow

`tests/StoreFixtures.luau` supplies 24 presentation cases, D1 illustrative prices, a seven-digit
price stress case, long names, a **test-only** hidden subset, mixed My Perks, and eight offline
outcomes. Uniform states across products are stress cases, not permission to treat consumables
as passes. Fixtures never change production ownership, Coins, rewards, odds, timers or outcomes.
The hidden subset demonstrates reflow and does not approve D3.

For a private Studio session synced to this worktree:

1. During Play, add a temporary ModuleScript named `StoreFixtures` under your local
   `PlayerScripts.Client`, paste `tests/StoreFixtures.luau` into it. Its relative require resolves
   the client presentation module. Do not add it to Rojo or save it into a release place.
2. Paste `tests/StudioStore.client.luau` into the **client Command Bar**. It creates a separate
   `StorePresentationFixture` ScreenGui, never sends requests and owns its listeners/timer.
3. State arrows cycle all cases. Browse all five tabs and open each product detail. In Perks,
   inspect timers, tokens, Arriving, Auto Open setup and settings. F7 cycles the offline popup,
   including locked states; F8 hides/shows the toolbar for screenshots; F9 removes the fixture,
   popup, bindings, timer and connections. Motion starts OFF and can be switched on.
4. Use actual Device Emulator D1 1920×1080, D2 1280×720, M1 667×375 landscape and an M2 notch
   phone in landscape. Record actual **safe** size/preset from Output, including the inset.
   The phone toolbar overlays the header for debugging; hide it with F8 before acceptance.
5. Run `tests/StudioStoreCheck.client.luau` at representative states and scroll endpoints.
   It checks text fitting, selectable 44px targets and reachability; independently inspect
   contrast, composition, complete messages, full localized prices and every final row.
   Check mouse/keyboard, simulated touch, gamepad A/B/L1/R1 and visible focus/auto-scroll.
   Fixture bindings are separate from the real Interface; repeat real navigation/input checks
   with the existing `StudioUI` checklist after removing the fixture.
6. Reopen/change state/resize 30 times; check growth and teardown. Screenshots must name the
   actual viewport, state and date. Emulation is not a physical phone pass.

The fixture has one one-second timer, cancelled on teardown; the production Store has no new
background loop. `tick` ignores hidden screens. Sheet state reconciliation preserves the open
product, length and scroll offset and replaces its owned controls so old availability cannot
remain interactive. Dynamic listeners use child UIScopes and are disconnected on replacement.

## Verification evidence

Affected gates: UI/layout/input/lifecycle plus presentation-only offline states. Backend,
persistence, monetary fulfillment and release checks are outside this change's ownership.

| Check | Status | Evidence / limitation |
| --- | --- | --- |
| Pinned `rokit install`; `wally install` | PASS | Successful after allowing tool caches outside the worktree; zero dependencies retained. |
| Store presentation fixtures | PASS | 499 assertions: state/price separation, no requests/grants, duration selection, bounded setup/cost, hidden reflow, timers, offline locks/free Claim and teardown. Engine double does not render. |
| Existing Screens / UI / Scroll specs | PASS | 2,345 / 1,291 / 6 checks: free flows, navigation, device geometry and lifecycle regression. Geometry in a double is not native visual acceptance. |
| Merged purchase foundation regression | PASS | 105 `Purchases.spec` assertions after the clean merge; both suites retained in `tests/run.py`. This is isolated foundation evidence, not a real purchase. |
| `stylua src`; `stylua --check src` | PASS | Final source formatting check returned success. |
| `selene src` | PASS | 0 errors, 0 warnings, 0 parse errors; API-cache access required outside the sandbox. |
| `rojo build default.project.json -o RobloxWorkspace.rbxlx` | PASS | Pinned Rojo build succeeded; generated output remains ignored. |
| Luau Language Server diagnostics | PASS | `luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions=…/globalTypes.PluginSecurity.d.luau` on all six changed/new client modules: no type diagnostics. |
| `git diff --check` | PASS | No whitespace errors. No backend/shared/init changes. |
| D1 desktop 1920×1080 | NOT RUN | Studio MCP inventory returned zero connected sessions. Native fixture/capture pending. |
| D2 compact desktop 1280×720 | NOT RUN | Same; inspect card/detail/perk layouts, large prices and last rows. |
| M1 small landscape phone 667×375 | NOT RUN | Same; inspect 44px controls, full status text, scrolling, focus and reduced motion. |
| M2 inset landscape phone | NOT RUN | Same; actual preset/safe size must be recorded. |
| T1 landscape tablet | NOT RUN | Useful regression for tab/content changes; actual tablet preset pending. |
| Mouse/touch/gamepad native input; screenshots | NOT RUN | No native session available. No screenshots or visual approval claimed. |
| Physical phone | NOT RUN | Owner/device pass still required before release. |
| Real purchases, receipt replay, fulfillment, migrations, multi-client authority | N/A | No paid wiring, backend logic or authoritative contract changed. Fixture success is not purchase proof. |
| Publish / production mutation | N/A | Not authorized or attempted. |

Release impact: no publication or production data changes. Buying stays disabled. Complete the
native matrix and wire the final approved backend contract in a separate integration task.

FAIL: none remaining in the final checks. Initial lint/type issues were corrected and rerun.
The automated command was
`python tests/run.py C:/Users/natha/Documents/RobloxWorkspace/build/tools/luau/luau.exe StorePresentation.spec Screens.spec UI.spec Scroll.spec Purchases.spec`.
No broader economy/persistence suite or real-purchase test was claimed. No new native visual
evidence exists for these states; the supplied Studio fixture/check scripts are unrun tools.
