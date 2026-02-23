# claw-gets-shit-done

Fork-style OpenClaw integration of `gsd-build/get-shit-done`.

## Structure

- `upstream/` - mirrored upstream snapshot (commands/workflows/templates/bin)
- `local/` - OpenClaw-only overrides and adapters
- `bin/gsd-tools` - stable wrapper to upstream deterministic CLI
- `SKILL.md` - `/gsd` entrypoint for OpenClaw skill commands

## Update Strategy

1. Pull latest upstream snapshot with `scripts/sync-claw-gsd.sh`.
2. Keep OpenClaw-specific behavior in `local/` to reduce merge pain.
3. Re-test key flows (`new-project`, `plan-phase`, `execute-phase`, `verify-work`).
