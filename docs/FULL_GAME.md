# Full-game implementation scope

The user playtested and accepted the MVP on 2026-09-23, reported truncated collection scrolling,
and authorized autonomous development of the full game. This supersedes separate coding
approvals between roadmap milestones. It does not claim prior detailed tests were performed.

Build the roadmap's complete non-monetized feature set: reliable saving, one fourth-slot
expansion, two original six-figure collections, a modest themed-display bonus, collection
plaques, room palettes, one daily free box, one daily display goal, same-server visits and
public display inspection, and an accessible tabbed UI with reliable collection scrolling.
Keep quantity stacks, automatic online income, chosen-figure Scrap redemption, and original
procedural assets. Do not add frameworks, trading, paid items, offline income or public deployment.

Implementation decisions: native DataStoreService with UpdateAsync session leases; separate
Studio/live store names. Studio is explicitly labeled unsaved preview unless a server-only
configuration enables isolated persistence testing. Live servers require successful persistent
loads. Failed loads never create playable default profiles. Tune costs in server config.

The user need only step in for Roblox account/Studio setup, runtime testing unavailable to the
agent, or release authorization. Code completion is distinct from validated launch readiness.

This file records the already implemented candidate scope. Newer product direction separates the
earning **Display** from non-economic **Showrooms** and targets three-to-six Display slots; see
[Display and Showrooms](DISPLAY_AND_SHOWROOMS.md). That direction does not retroactively make the
six-slot Display, Showroom Gallery, or customizable rooms part of this implementation result.

## Implementation result

The candidate implements the scope above: twelve figures, two boxes, persistent profiles,
four-slot progression, three palettes, two completion plaques, UTC daily box/display rewards,
automatic income, themed bonus, inspected same-server visits, original room/garden geometry,
and tabbed UI with explicit scroll sizing. Its implemented "room" is the legacy economic
Display/main plot, not the future Showroom system. No frameworks or Wally dependencies were added.
Automated tests pass; [operations](OPERATIONS.md) lists the unrun native storage, mobile,
multiplayer, performance and recovery checks required before release. Nothing is published.
