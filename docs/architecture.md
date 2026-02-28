# Architecture

## Control Plane: GSD-first

CGSD is intentionally opinionated:

1. GSD is source of truth for planning and verification.
2. Queue execution is bounded and deterministic.
3. Role/persona councils are advisory, never authoritative.

## Components

1. `skills/claw-gets-shit-done`
- Upstream workflow skill and `gsd-tools`.

2. `plugins/gsd-command-aliases`
- Slash command aliases and bridge helpers.
- Includes `/gsd-project-mode` for per-project activity control.

3. Loop workers
- `RalphClaw`: executes queue tasks.
- `AutoClaw`: discovers/prioritizes candidate work.
- `Watchdog`: detects stale loop behavior.
- `KPI`: periodic health/output report.

4. Bridge
- `scripts/gsd-loop-bridge.sh` syncs `.planning` todos into loop files.
- Uses idempotent IDs (`GSD-TODO-*`) to prevent duplicate intake.

5. Project activity registry
- Default file: `~/.openclaw/cgsd-project-activity.json`
- Stores per-project cron job IDs and mode profiles (`off|medium|high`).
- Maintains channel/thread -> project mapping for chat-driven controls.

## Data Flow

1. User or agent creates/updates GSD state (`.planning`).
2. Bridge or command alias maps items into:
- `.openclaw/LOOP-INBOX.md`
- `.openclaw/LOOP-QUEUE.md`
3. RalphClaw picks one ready item, executes bounded change.
4. Verify gate runs (`test/lint/build/smoke` as applicable).
5. On pass: mark progress and next step.
6. On fail: requeue with blocker and unblock action.

## Discord Forum Mapping

- One thread maps to one epic (`epic_id`).
- Queue contains executable tasks under the epic.
- Daily/weekly councils discuss risk and priority; decisions still materialize as queue+GSD actions.

## Failure Boundaries

- Missing delivery target: install fails unless `--allow-no-loop-delivery`.
- Missing `gsd-tools`: doctor warns; bridge skips safely.
- Duplicate cron/plugin entries: installer dedupe logic cleans known duplicates.
