# OpenClaw GSD Suite

Packaged GSD workflow for OpenClaw with:

- `skills/claw-gets-shit-done` (upstream-synced GSD wrapper)
- `plugins/gsd-command-aliases` (`/gsd-add-todo`, `/gsd-plan-phase`, etc.)
- `install.sh`, `doctor.sh`, `uninstall.sh`

This bundle is built to handle different OpenClaw setups (home dirs, workspace installs, custom paths).

## Install From Repo URL (Agent-Friendly)

If users only provide this GitHub repo URL, OpenClaw can still install automatically.

One-liner bootstrap:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ironyh/claw-gets-shit-done/main/scripts/bootstrap-install.sh)
```

Behavior:
- If run in a TTY with no flags, it launches `./install.sh --interactive`.
- If flags are passed, it runs non-interactive with those flags.
- It only asks for missing required inputs (for example project root for loops, delivery target, or desired sub-agent parallelism).

Non-interactive example:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ironyh/claw-gets-shit-done/main/scripts/bootstrap-install.sh) -- \
  --profile home --no-interactive --force \
  --preset badgeid \
  --project-root /home/irony/code/id-koll-nurrse \
  --enable-ralphclaw --ralphclaw-multi-agent --ralphclaw-subagents-parallel 3 \
  --enable-autoclaw --enable-ralphclaw-watchdog --enable-loop-kpi \
  --loop-channel discord --loop-target <target_id>
```

Agent operators: see `AGENT-INSTALL.md`.

## Instructions For Other ClawBots

Use this exact instruction in OpenClaw when a user points to this repo:

```text
Install CGSD from https://github.com/ironyh/claw-gets-shit-done.
Use scripts/bootstrap-install.sh.
If required inputs are missing, ask only these:
1) project root (if loop workers are enabled)
2) loop target id
3) ralphclaw sub-agent parallelism
Otherwise run non-interactive install with sensible defaults:
--profile home --no-interactive --force --preset generic
Enable RalphClaw + AutoClaw + watchdog.
After install run doctor + gateway health and report results.
```

If user wants full autonomous setup, use:

```text
Install CGSD from https://github.com/ironyh/claw-gets-shit-done with:
--profile home --no-interactive --force
--preset badgeid
--project-root /path/to/project
--enable-ralphclaw --ralphclaw-multi-agent --ralphclaw-subagents-parallel 3
--enable-autoclaw --enable-ralphclaw-watchdog --enable-loop-kpi
--loop-channel discord --loop-target <target_id>
Then run doctor + gateway health.
```

## Architecture: How It Fits Together

This suite combines three layers:

1. `GSD` (workflow system)
- Provides the execution framework and slash commands (`/gsd:*`).
- Defines planning, execution, verification discipline.

2. `AutoClaw` (discovery/extension loop)
- Finds and shapes valuable next work (features, quality, reliability).
- Writes structured proposals into the shared inbox/queue contract.

3. `RalphClaw` (execution loop)
- Pulls from the shared queue and ships one bounded increment per run.
- Verifies changes and updates status/blockers.

### Data Contract (shared memory between loops)

- Inbox file: `PROJECT_ROOT/.openclaw/LOOP-INBOX.md` (default)
- Queue file: `PROJECT_ROOT/.openclaw/LOOP-QUEUE.md` (default)
- KPI file: `PROJECT_ROOT/.openclaw/LOOP-KPI-WEEKLY.md` (default)

Flow:
- `AutoClaw -> LOOP-INBOX.md -> LOOP-QUEUE.md -> RalphClaw execution -> verification -> status update`

### Loop Responsibilities

- `AutoClaw`:
  - discovers high-impact opportunities
  - defines acceptance criteria
  - hands off ready tasks in a structured format

- `RalphClaw`:
  - picks highest-impact unblocked task
  - executes one atomic step
  - verifies (`test/lint/build/smoke`)
  - writes result or blocker/unblock action
  - can optionally orchestrate sub-agents in parallel for complex tasks

- `RalphClaw Watchdog`:
  - detects repeated stale loop summaries
  - rotates/recovers stuck loop behavior

- `Loop KPI Weekly`:
  - generates a weekly report from queue + git signal
  - tracks delivery/blocked/test-health trends

## What You Get

- Canonical GSD commands:
  - `/gsd <command> [args]`
  - `/gsd:<command> [args]`
- Hyphen aliases for better slash UX:
  - `/gsd-add-todo`, `/gsd-check-todos`, `/gsd-progress`, `/gsd-discuss-phase`, `/gsd-plan-phase`, `/gsd-execute-phase`, `/gsd-verify-work`, `/gsd-resume-work`, `/gsd-new-project`

## Install Profiles

### Interactive installer (recommended)

Guided mode autodetects likely OpenClaw/Codex/workspace paths and lets you confirm before install:

```bash
cd openclaw-gsd-suite
./install.sh --interactive
```

If you run `./install.sh` with no options in a TTY, it now asks whether to start guided mode.

### 1) Home Profile (most users)

Uses:

- OpenClaw config: `~/.openclaw/openclaw.json`
- Plugin path: `~/.openclaw/extensions/gsd-command-aliases`
- Skill path: `${CODEX_HOME:-~/.codex}/skills/claw-gets-shit-done`

```bash
cd openclaw-gsd-suite
./install.sh --profile home --restart-gateway
./doctor.sh
```

Enable autonomous loops during install:

```bash
./install.sh --profile home \
  --preset badgeid \
  --enable-ralphclaw \
  --enable-autoclaw \
  --enable-ralphclaw-watchdog \
  --enable-loop-kpi \
  --ralphclaw-multi-agent \
  --ralphclaw-subagents-parallel 3 \
  --discord-text-channel <discord_channel_id>
```

### 2) Workspace Profile (repo-centric setups)

Installs both skill and plugin into a workspace root:

```bash
cd openclaw-gsd-suite
./install.sh --profile workspace --workspace-root /path/to/workspace --openclaw-dir ~/.openclaw --restart-gateway
./doctor.sh --openclaw-dir ~/.openclaw --skill-dir /path/to/workspace/skills --plugin-path /path/to/workspace/plugins/gsd-command-aliases
```

### 3) Custom Profile (fully explicit paths)

```bash
cd openclaw-gsd-suite
./install.sh \
  --profile custom \
  --skill-dir /opt/openclaw/skills \
  --plugin-path /opt/openclaw/plugins/gsd-command-aliases \
  --openclaw-dir /opt/openclaw/.openclaw \
  --config /opt/openclaw/.openclaw/openclaw.json \
  --restart-gateway
```

## Non-Standard Runtime Paths

If OpenClaw runs from a service user or unusual working directory, set one of these:

```bash
export GSD_WORKSPACE_DIR=/path/to/project
# or
export GSD_TOOLS_PATH=/path/to/skills/claw-gets-shit-done/bin/gsd-tools
```

The alias plugin now resolves `gsd-tools` from multiple candidate locations and supports these env overrides.

## Autonomous Feature Extension (Optional)

Installer can also configure cron workers for autonomous execution:

- `RalphClaw` (default schedule: `*/15 * * * *`) for continuous one-step progress
- `AutoClaw` (default schedule: `0 */3 * * *`) for autonomous feature extension
- `RalphClaw Watchdog` (default: every 20 min) for stale-loop recovery
- `Loop KPI Weekly` (default: Mondays 08:00) for delivery/blocker reporting

Project scoping rules:
- Loop workers require explicit `--project-root <path>` (or a preset that resolves one).
- Cron jobs are namespaced per project: `Kai RalphClaw [<project-key>]`, etc.
- `project-key` is derived from project root basename by default; override with `--project-key <slug>`.
- Loop workers use a shared lock file (default: `<project-root>/.openclaw/locks/loop-worker.lock`) to avoid overlapping runs.

Cron frequency is configurable:
- `--ralphclaw-cron "<expr>"` (default: `*/15 * * * *`)
- `--autoclaw-cron "<expr>"` (default: `0 */3 * * *`)
- `--loop-kpi-cron "<expr>"` (default: `0 8 * * 1`)

Interactive:

```bash
./install.sh --interactive
```

Advanced flags:

```bash
./install.sh \
  --preset badgeid \
  --project-root /path/to/workspace-or-project \
  --project-key badgeid \
  --enable-ralphclaw \
  --enable-autoclaw \
  --enable-ralphclaw-watchdog \
  --enable-loop-kpi \
  --ralphclaw-multi-agent \
  --ralphclaw-subagents-parallel 3 \
  --loop-model kimi-coding/k2p5 \
  --loop-agent main \
  --loop-tz Europe/Stockholm \
  --loop-max-files 12 \
  --loop-lock-file /path/to/workspace-or-project/.openclaw/locks/loop-worker.lock \
  --ralphclaw-cron "*/15 * * * *" \
  --autoclaw-cron "0 */3 * * *" \
  --loop-kpi-cron "0 8 * * 1" \
  --discord-text-channel <channel_id>
```

Discord forum thread delivery:

```bash
./install.sh \
  --project-root /path/to/project \
  --preset badgeid \
  --enable-ralphclaw \
  --enable-autoclaw \
  --discord-forum-thread <forum_thread_id>
```

Legacy aliases supported:
- `--enable-autoloop` (same as `--enable-ralphclaw`)
- `--enable-autoloop-watchdog` (same as `--enable-ralphclaw-watchdog`)
- `--autoloop-cron` (same as `--ralphclaw-cron`)
- `--enable-clawloop` (same as `--enable-autoclaw`)
- `--clawloop-cron` (same as `--autoclaw-cron`)

Useful defaults:
- `--preset badgeid` (pre-fills project paths + Stockholm timezone + known Discord target)
- `--preset nurrse` (pre-fills project root + Stockholm timezone)

Delivery guardrail:
- Loop jobs require `--loop-target` when delivery channel is set.
- Use `--allow-no-loop-delivery` only if silent execution is intentional.

Multi-project setup:
- Run installer once per project with different `--project-root`.
- Use distinct Discord targets per project.
- Optional: set explicit `--project-key` per project for stable cron naming.

Discord delivery shortcuts:
- Text channel: `--discord-text-channel <channel_id>`
- Forum thread: `--discord-forum-thread <thread_id>`
- Generic form still works: `--loop-channel discord --loop-target <id>`

RalphClaw multi-agent:
- Enable with `--ralphclaw-multi-agent`
- Limit concurrent sub-agents with `--ralphclaw-subagents-parallel <n>`
- Recommended starting value: `2` or `3`

KPI script (manual run):
```bash
./scripts/loop-kpi-report.sh --project-root /path/to/project --days 7
```

## Validate

```bash
./doctor.sh
openclaw gateway health
openclaw plugins list --json | jq '.plugins[] | select(.id=="gsd-command-aliases")'
```

## Uninstall

`uninstall.sh` is non-destructive; it moves files to timestamped backup paths and patches `openclaw.json`.

```bash
./uninstall.sh
```

## Update Upstream GSD

```bash
./scripts/sync-claw-gsd.sh
# or pin
./scripts/sync-claw-gsd.sh --ref v3.0.0
```

## Publish Checklist

1. Tag release (`vX.Y.Z`).
2. Include this folder as release artifact or separate repo root.
3. Add release notes:
   - OpenClaw version tested
   - Upstream GSD commit/tag
   - Breaking changes (if any)
4. Smoke test on clean machine with `--profile home`.

## Attribution

This bundle includes upstream `gsd-build/get-shit-done` content under MIT License.
See:

- `skills/claw-gets-shit-done/upstream/LICENSE`
- `NOTICE.md`
