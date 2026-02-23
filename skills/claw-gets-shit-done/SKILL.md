---
name: gsd
version: 0.1.0
description: OpenClaw-native wrapper for Get Shit Done. Use `/gsd <command> ...` or `/gsd:<command> ...` to run structured planning/execution workflows.
metadata: {"openclaw":{"emoji":"🧭","requires":{"bins":["node"]}}}
---

# claw-gets-shit-done

OpenClaw wrapper around upstream **Get Shit Done (GSD)**.

## Command Entry

Use either format:
- `/gsd <command> [args]`
- `/gsd:<command> [args]`

Both map to the same behavior. The first token after `/gsd` is the GSD command name.

Examples:
- `/gsd new-project`
- `/gsd:plan-phase 1`
- `/gsd execute-phase 1`
- `/gsd:add-todo Improve onboarding copy`

## Routing Rules

1. Parse subcommand from user input.
2. Resolve command file at:
   - `skills/claw-gets-shit-done/upstream/commands/gsd/<subcommand>.md`
3. Execute that command's objective/process as the source of truth.
4. When command/workflow needs deterministic state ops, use:
   - `skills/claw-gets-shit-done/bin/gsd-tools ...`
5. Keep all project state in the current repo's `.planning/` folder.

If subcommand is missing or unknown, show available commands from:
- `skills/claw-gets-shit-done/upstream/commands/gsd/`

## Local Fork Policy

- Upstream GSD files live in `upstream/` (mirrored snapshot).
- OpenClaw-specific overrides belong in `local/`.
- Do not edit `upstream/` directly for local behavior changes; put local changes in `local/` and reference them from here.

## Deterministic Helper

Use this wrapper instead of hardcoding paths:

```bash
skills/claw-gets-shit-done/bin/gsd-tools state load
skills/claw-gets-shit-done/bin/gsd-tools roadmap analyze --raw
```

## Upstream Sync

Refresh from upstream with:

```bash
bash scripts/sync-claw-gsd.sh
# or pin a tag/sha
bash scripts/sync-claw-gsd.sh --ref v3.0.0
```

After sync, review local overrides and re-run tests.
