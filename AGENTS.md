# Engineering instructions

## Before changing code

- Inspect the existing architecture, source files, Rojo mappings, and tool configuration first.
- Keep changes focused on the request. Avoid unrelated modifications and preserve user work.
- Preserve the pinned Rojo 7.7.0 setup and existing project properties unless a task requires a change.
- Do not introduce frameworks or dependencies without a concrete justification and user authorization.
- Do not implement gameplay as part of tooling or environment maintenance.

## Luau and architecture

- Use strict Luau: begin every source file with `--!strict`. Prefer explicit types at module and remote boundaries; do not silence errors with broad `any` casts.
- Prefer small, focused modules with clear responsibilities. Avoid unnecessary abstractions and giant manager classes.
- Respect replication boundaries: `src/server` is server-only, `src/client` runs on clients, and `src/shared` is replicated and readable by clients.
- Never put secrets, authoritative state, or server-only implementation in shared/client code or ReplicatedStorage.
- Preserve Rojo's current instance structure: `init.server.luau` makes Server a Script; `init.client.luau` makes Client a LocalScript. Adding directories or renaming init files can change instance classes and require paths.
- Wally's shared Packages directory maps to ReplicatedStorage.Packages. If server dependencies are approved later, map ServerPackages into a server-only service, never ReplicatedStorage.

## Security and authority

- Treat clients as untrusted. The server owns authoritative gameplay state, including currency, inventory, progression, damage, rewards, purchases, cooldowns, and persistent data.
- Validate all remote requests server-side: types, finite numeric values, bounds, payload size, instance ancestry, ownership, permissions, current state, distance where relevant, and rate limits/cooldowns.
- Use the Player supplied by Roblox's remote callback as the caller identity. Never trust a client-supplied identity, price, reward, damage amount, or purchase confirmation.
- Clients request actions; the server decides whether they are valid and computes results. Client checks are only for responsiveness and presentation.

## Performance and lifecycle

- Avoid unnecessary per-frame work, repeated expensive lookups, and network traffic. Prefer events and bounded work; send only data that recipients need.
- Disconnect Roblox connections, cancel owned tasks, and destroy owned instances when their lifetime ends. Make ownership and teardown clear for player, character, UI, and temporary systems.
- Handle failures explicitly at external-service and persistence boundaries. Do not hide failures or overwrite valid data with fallback defaults after a failed load.

## Tooling and verification

- Use the versions pinned in `rokit.toml`; run `rokit install` to provision them. Do not upgrade tools incidentally.
- Run `wally install` before building or serving to resolve dependencies. Preserve the explicit Folder and optional Packages path so zero-dependency builds work. Keep dependencies empty until additions are authorized. Commit `wally.lock`; never hand-edit it or generated package code.
- Format with `stylua src`; verify with `stylua --check src`.
- Lint with `selene src`; preserve Roblox standard-library support in `selene.toml`.
- Verify mappings with `rojo build default.project.json -o RobloxWorkspace.rbxlx`.
- Keep generated packages, sourcemaps, Selene API cache, and build output out of version control.
- Formatting, linting, and building do not prove type correctness or runtime behavior. Check Luau Language Server diagnostics and use Studio playtests for behavioral changes, including multi-client tests for replication/remotes.
- Report what changed, checks actually run, and any remaining manual checks. Never claim a Studio playtest was run unless it was.
