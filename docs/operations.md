# Operations

## Quick Health Checks

```bash
./doctor.sh
openclaw gateway health
openclaw cron list --all --json | jq '.jobs[] | {name: .name, cron: .schedule.expr}'
cat /path/to/project/.openclaw/LOOP-MODEL-HEALTH.md
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

5. Wrong model/provider used in runs
- Run deterministic model report and inspect fallback column:
  - `./scripts/model-health-report.sh --project-root /path/to/project --project-key <slug>`
- If fallback is frequent, verify auth profile availability for the configured provider/model.

## Deterministic GSD Bridge

Run once:

```bash
./scripts/gsd-loop-bridge.sh --project-root /path/to/project
```

Expected output includes:
- `discovered`
- `added`
- `skipped_existing`

## Deterministic Model Health

Run once:

```bash
./scripts/model-health-report.sh --project-root /path/to/project --project-key my-project
```

Expected report includes:
- jobs inspected
- fallback/mismatch count
- latest failed runs
- recommended actions

## Project Activity Controls

Inspect from chat:

- `/gsd-project-mode status`
- `/gsd-project-mode check all`

Set intensity:

- `/gsd-project-mode high`
- `/gsd-project-mode <project-key> medium`
- `/gsd-project-mode set all off`

Bind channel/thread context to a project:

- `/gsd-project-bind <project-key>`
- `/gsd-project-bind show`

## TODO Intake Policy

When a new todo is added with `/gsd-add-todo`:

1. Save todo under `.planning/todos/pending`.
2. Sync one intake item into `LOOP-INBOX` + `LOOP-QUEUE` (idempotent `GSD-TODO-*` id).
3. Queue item starts as:
- `status: ready`
- `verify_status: pending`
- `priority: P1` (default; councils/loop can promote/demote)
4. RalphClaw executes one bounded step and must pass verify gate.

## Discuss-To-Verify Control

To match GSD discipline, do not stop at "discussion completed". Track decision lifecycle:

1. Decision captured
- Record explicit decision state:
  - `pending`
  - `promote_to_queue`
  - `need_more_data`
  - `reject`

2. Queue linkage
- If promoted, record queue linkage + `gsd_action`.
- Keep acceptance criteria on the queue task.

3. Verification gate
- Mark verify outcome explicitly:
  - `verify_status: passed|failed|pending`
- Add evidence (test output, build result, PR/commit reference).

4. Control review
- Maintain a periodic control report:
  - decisions needing outcome
  - promoted-but-not-verified
  - verification failures

Rule:
- Promoted work is not "done" until verify passes with evidence.
