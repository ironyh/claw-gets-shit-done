# Operations

## Quick Health Checks

```bash
./doctor.sh
openclaw gateway health
openclaw cron list --all --json | jq '.jobs[] | {name: .name, cron: .schedule.expr}'
```

## Common Issues

1. Missing `gsd-tools`
- Set `GSD_TOOLS_PATH` or `GSD_WORKSPACE_DIR`.

2. No loop announcements
- Verify `--loop-channel` and `--loop-target` are set.
- If intentionally silent, use `--allow-no-loop-delivery`.

3. Duplicate cron jobs
- Re-run install without `--no-dedupe-crons`.

4. Queue not progressing
- Check watchdog job and delivery channel permissions.
- Verify the queue has `status: ready` items.

## Deterministic GSD Bridge

Run once:

```bash
./scripts/gsd-loop-bridge.sh --project-root /path/to/project
```

Expected output includes:
- `discovered`
- `added`
- `skipped_existing`

## TODO Intake Policy

When a new todo is added with `/gsd-add-todo`:

1. Save todo under `.planning/todos/pending`.
2. Sync one intake item into `LOOP-INBOX` + `LOOP-QUEUE` (idempotent `GSD-TODO-*` id).
3. Queue item starts as:
- `status: ready`
- `verify_status: pending`
- `priority: P1` (default; councils/loop can promote/demote)
4. RalphClaw executes one bounded step and must pass verify gate.
