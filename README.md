![RalphClaw](ralphClaw.png)

# OpenClaw GSD Suite

Packaged GSD workflow for OpenClaw with:

- `skills/claw-gets-shit-done` (upstream-synced GSD wrapper)
- `plugins/gsd-command-aliases` (`/gsd-add-todo`, `/gsd-plan-phase`, etc.)
- `install.sh`, `update.sh`, `doctor.sh`, `uninstall.sh`

This bundle is built to handle different OpenClaw setups (home dirs, workspace installs, custom paths).

## Quick Links

- Install CGSD: [`docs/install-update.md`](docs/install-update.md)
- Update CGSD: [`docs/install-update.md#update`](docs/install-update.md#update)
- Discord settings (channels, forum target, slash allowFrom): [`docs/configuration.md#delivery`](docs/configuration.md#delivery)
- Discord forum flow (epics/discuss/council): [`docs/discord-forum-flow.md`](docs/discord-forum-flow.md)
- Commands and aliases (`/gsd:*`, `/gsd-*`): [`docs/command-reference.md`](docs/command-reference.md)
- Operations and troubleshooting: [`docs/operations.md`](docs/operations.md)
- Full documentation index: [`docs/index.md`](docs/index.md)
- Online docs: `https://ironyh.github.io/claw-gets-shit-done/`

## Documentation

- Online docs: `https://ironyh.github.io/claw-gets-shit-done/`
- Local docs index: `docs/index.md`
- Install/update guide: `docs/install-update.md`
- Configuration reference: `docs/configuration.md`
- Command reference: `docs/command-reference.md`
- Architecture: `docs/architecture.md`
- Discord forum flow: `docs/discord-forum-flow.md`
- Operations/troubleshooting: `docs/operations.md`
- Build/release guide: `docs/build-release.md`
- FAQ: `docs/faq.md`
- Documentation skill (for bots/contributors): `skills/cgsd-docs/SKILL.md`

Local searchable preview:

```bash
pip install -r requirements-docs.txt
mkdocs serve
```

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
- In guided mode, installer detects project state (`existing`, `brownfield`, `empty`, `greenfield`) and asks for bootstrap strategy when relevant.

Non-interactive example:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ironyh/claw-gets-shit-done/main/scripts/bootstrap-install.sh) -- \
  --profile home --no-interactive --force \
  --preset generic \
  --project-root /path/to/project \
  --enable-ralphclaw --ralphclaw-multi-agent --ralphclaw-subagents-parallel 3 \
  --enable-autoclaw --enable-ralphclaw-watchdog --enable-loop-kpi \
  --loop-channel discord --loop-target <target_id>
```

Agent operators: see `AGENT-INSTALL.md`.

## Update (manual, one command)

No auto-update is required. Use:

```bash
./update.sh
```

What it does:
- verifies clean working tree (unless `--allow-dirty`)
- updates to branch/tag/sha (`--ref`)
- uses fast-forward pull for branches, detached checkout for tag/sha
- re-runs installer (`install.sh --force --restart-gateway`)
- runs `doctor.sh`

Default behavior:
- if no extra installer flags are passed, `update.sh` reuses the last saved install args from:
  - `~/.openclaw/cgsd-install-state.json` (or `CGSD_INSTALL_STATE_FILE`)
- this lets you use plain `./update.sh` for normal updates

If you use non-default install paths, pass install args after `--`:

```bash
./update.sh -- --profile workspace --workspace-root /path/to/workspace --openclaw-dir ~/.openclaw
```

Pinned update examples:

```bash
# update to a tag (detached checkout)
./update.sh --ref v0.1.0

# update to a commit (detached checkout)
./update.sh --ref <commit_sha>

# ignore saved state and use installer defaults/current env
./update.sh --no-saved-state
```

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
If Discord is used, add --discord-slash-allow-from "*".
Then follow installer bootstrap hint:
- brownfield: /gsd-map-codebase -> /gsd-new-project
- empty project: /gsd-new-project
- greenfield: /gsd-new-project
After install run doctor + gateway health and report results.
```

If user wants full autonomous setup, use:

```text
Install CGSD from https://github.com/ironyh/claw-gets-shit-done with:
--profile home --no-interactive --force
--preset generic
--project-root /path/to/project
--enable-ralphclaw --ralphclaw-multi-agent --ralphclaw-subagents-parallel 3
--enable-autoclaw --enable-ralphclaw-watchdog --enable-loop-kpi
--enable-forum-daily-council --enable-forum-weekly-council
--loop-channel discord --loop-target <target_id>
--discord-slash-allow-from "*"
Then run doctor + gateway health.
```

## Architecture: How It Fits Together

This suite combines three layers with a strict control order:

1. `GSD` (workflow system)
- Provides the execution framework and slash commands (`/gsd:*`).
- Defines planning, execution, and verification discipline.
- Is the source of truth for what should be worked on next.

2. `AutoClaw` (discovery/extension loop)
- Finds and shapes valuable next work only within GSD discipline.
- Writes structured proposals into the shared inbox/queue contract with explicit `gsd_action`.

3. `RalphClaw` (execution loop)
- Pulls from the shared queue and ships one bounded increment per run.
- Executes only GSD-aligned items, verifies changes, and updates status/blockers.

Role/persona councils are advisory. They challenge assumptions, assess risk, and answer scoped questions, but they do not bypass GSD or queue-based execution.

### Data Contract (shared memory between loops)

- Inbox file: `PROJECT_ROOT/.openclaw/LOOP-INBOX.md` (default)
- Queue file: `PROJECT_ROOT/.openclaw/LOOP-QUEUE.md` (default)
- KPI file: `PROJECT_ROOT/.openclaw/LOOP-KPI-WEEKLY.md` (default)

Flow:
- `GSD context -> AutoClaw proposal (with gsd_action) -> LOOP-INBOX.md -> LOOP-QUEUE.md -> RalphClaw execution -> verify -> status update`

### Loop Responsibilities

- `AutoClaw`:
  - reads existing GSD plan/progress first
  - discovers high-impact opportunities
  - defines acceptance criteria + `gsd_action`
  - hands off ready tasks in a structured format

- `RalphClaw`:
  - starts from GSD progress/state, then queue
  - picks highest-impact unblocked GSD-aligned task
  - executes one atomic step
  - verifies (`test/lint/build/smoke`)
  - if verify fails: requeues item (never `done` on red verify)
  - writes result or blocker/unblock action + recommended next GSD action
  - can optionally orchestrate sub-agents in parallel for complex tasks

- `RalphClaw Watchdog`:
  - detects repeated stale loop summaries
  - rotates/recovers stuck loop behavior

- `Loop KPI Weekly`:
  - generates a weekly report from queue + git signal
  - tracks delivery/blocked/test-health trends

- `GSD Bridge`:
  - runs deterministic sync from GSD `.planning` todos into `LOOP-INBOX` + `LOOP-QUEUE`
  - keeps queue seeded from existing GSD artifacts (no duplicate planning system)
  - uses idempotent IDs (`GSD-TODO-*`) so repeat runs do not duplicate entries

### Forum Flow v2 (Daily + Weekly)

- `Forum Council Daily`:
  - enforces intake card per active thread
  - treats each forum thread as one epic (`epic_id`)
  - prioritizes user-originated input first (bugs/requests/pain reports)
  - runs timeboxed role discussion (input, challenge, converge)
  - requires explicit decision gate: `promote_to_queue | need_more_data | reject` + `gsd_action`
  - promotes only concrete, testable items to `LOOP-QUEUE` as tasks under that epic
- `Forum Council Weekly`:
  - reviews 7-day thread outcomes, blockers, delivery signals
  - reviews epic health (`open|active|blocked|done`)
  - reviews user-signal trends and repeated pain points
  - sets next-week priorities and risk mitigations
  - keeps queue focused on measurable outcomes
  - keeps role output advisory and GSD/queue output executable

Epic model:
- 1 forum thread = 1 epic (default).
- `LOOP-QUEUE` contains executable tasks linked by `epic_id`, not whole epics.
- This keeps planning/discussion in epic scope while execution remains small and verifiable.

Role ping guardrails (in council prompts):
- allowed: `needs_input_from:<role> reason:"..."`
- summary required before ping
- max 2 role-to-role pings per role/thread per daily run

## What You Get

- Canonical GSD commands:
  - `/gsd <command> [args]`
  - `/gsd:<command> [args]`
- Hyphen aliases for better slash UX:
  - `/gsd-add-todo`, `/gsd-check-todos`, `/gsd-new-epic`, `/gsd-progress`, `/gsd-discuss-phase`, `/gsd-plan-phase`, `/gsd-execute-phase`, `/gsd-verify-work`, `/gsd-resume-work`, `/gsd-new-project`

Todo intake behavior:
- `/gsd-add-todo` writes the todo in `.planning/todos/pending` and (default) syncs one loop intake item immediately.
- `/gsd-new-epic` creates epic intake in loop files and can create a Discord forum thread when configured.

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
  --preset generic \
  --project-root /path/to/project \
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

Optional plugin behavior config (`config.local.json` in plugin folder):
- `autoQueueTodo`: auto-sync `/gsd-add-todo` into LOOP files (default `true`)
- `autoThreadOnNewEpic`: allow `/gsd-new-epic` to attempt forum thread create (default `true`)
- `discordForumTarget`: forum channel target for thread creation
- `discordAccountId`: optional Discord account id for thread creation
- `loopInboxFile` / `loopQueueFile`: override LOOP artifact paths

Installer shortcut:
- `--discord-forum-target <id>` writes `discordForumTarget` into plugin local config automatically.
- `--discord-slash-allow-from <id|*>` patches `channels.discord.allowFrom` (default `*`) to prevent slash-command auth gating.
- If omitted, installer attempts best-effort autodetect from existing config and Discord group directory.

Brownfield bootstrap:
- Installer now detects project state and prints first-step guidance based on GSD init context:
  - Existing GSD project (`.planning/PROJECT.md`): skip bootstrap
  - Brownfield detected: run `/gsd-map-codebase` then `/gsd-new-project`
  - Empty project directory: run `/gsd-new-project`
  - Greenfield: run `/gsd-new-project` (or `--auto @PROJECT_IDEA.md` when present)
- Optional override: `--gsd-bootstrap auto|skip|new-project|new-project-auto|map-then-new-project`

## Autonomous Feature Extension (Optional)

Installer can also configure cron workers for autonomous execution:

- `RalphClaw` (default schedule: `*/15 * * * *`) for continuous one-step progress
- `AutoClaw` (default schedule: `0 */3 * * *`) for autonomous feature extension
- `RalphClaw Watchdog` (default: every 20 min) for stale-loop recovery
- `Loop KPI Weekly` (default: Mondays 08:00) for delivery/blocker reporting
- `GSD Bridge` (default: every 10 min) for deterministic GSD->LOOP sync
- `Forum Council Daily` (default: `15 9,17 * * *`) for discussion triage + decision gate
- `Forum Council Weekly` (default: `0 9 * * 1`) for strategic alignment

Project scoping rules:
- Loop workers require explicit `--project-root <path>`.
- Cron jobs are namespaced per project: `Kai RalphClaw [<project-key>]`, etc.
- `project-key` is derived from project root basename by default; override with `--project-key <slug>`.
- Loop workers use a shared lock file (default: `<project-root>/.openclaw/locks/loop-worker.lock`) to avoid overlapping runs.

Cron frequency is configurable:
- `--ralphclaw-cron "<expr>"` (default: `*/15 * * * *`)
- `--autoclaw-cron "<expr>"` (default: `0 */3 * * *`)
- `--loop-kpi-cron "<expr>"` (default: `0 8 * * 1`)
- `--gsd-bridge-cron "<expr>"` (default: `*/10 * * * *`)
- `--forum-daily-cron "<expr>"` (default: `15 9,17 * * *`)
- `--forum-weekly-cron "<expr>"` (default: `0 9 * * 1`)

Interactive:

```bash
./install.sh --interactive
```

Advanced flags:

```bash
./install.sh \
  --preset generic \
  --project-root /path/to/workspace-or-project \
  --project-key my-project \
  --enable-ralphclaw \
  --enable-autoclaw \
  --enable-ralphclaw-watchdog \
  --enable-loop-kpi \
  --enable-gsd-bridge \
  --enable-forum-daily-council \
  --enable-forum-weekly-council \
  --ralphclaw-multi-agent \
  --ralphclaw-subagents-parallel 3 \
  --loop-model kimi-coding/k2p5 \
  --loop-agent main \
  --loop-tz Europe/Stockholm \
  --loop-max-files 12 \
  --loop-lock-file /path/to/workspace-or-project/.openclaw/locks/loop-worker.lock \
  --gsd-bootstrap auto \
  --ralphclaw-cron "*/15 * * * *" \
  --autoclaw-cron "0 */3 * * *" \
  --loop-kpi-cron "0 8 * * 1" \
  --gsd-bridge-cron "*/10 * * * *" \
  --forum-daily-cron "15 9,17 * * *" \
  --forum-weekly-cron "0 9 * * 1" \
  --discord-forum-target <forum_channel_id> \
  --discord-slash-allow-from "*" \
  --discord-text-channel <channel_id>
```

Discord forum thread delivery:

```bash
./install.sh \
  --project-root /path/to/project \
  --preset generic \
  --enable-ralphclaw \
  --enable-autoclaw \
  --discord-forum-thread <forum_thread_id>
```

Useful defaults:
- `--preset generic`
- `--profile home`
- `--ralphclaw-subagents-parallel 2`

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
- Forum channel (for `/gsd-new-epic` thread creation): `--discord-forum-target <forum_channel_id>`
- Slash auth allowlist entry: `--discord-slash-allow-from <discord_user_id|*>`
- Generic form still works: `--loop-channel discord --loop-target <id>`

RalphClaw multi-agent:
- Enable with `--ralphclaw-multi-agent`
- Limit concurrent sub-agents with `--ralphclaw-subagents-parallel <n>`
- Recommended starting value: `2` or `3`

KPI script (manual run):
```bash
./scripts/loop-kpi-report.sh --project-root /path/to/project --days 7
```

GSD bridge script (manual run):
```bash
./scripts/gsd-loop-bridge.sh --project-root /path/to/project
```

## Validate

```bash
./doctor.sh
openclaw gateway health
openclaw plugins list --json | jq '.plugins[] | select(.id=="gsd-command-aliases")'
mkdocs build --strict
```

Docs deployment:
- GitHub Pages is configured via `.github/workflows/docs.yml`.
- On push to `main`, docs are published to `https://ironyh.github.io/claw-gets-shit-done/`.

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
2. Build artifact + checksum:
   - `./build-release.sh`
   - outputs `dist/openclaw-gsd-suite-vX.Y.Z.tar.gz`
   - outputs `dist/openclaw-gsd-suite-vX.Y.Z.tar.gz.sha256`
3. Add release notes:
   - OpenClaw version tested
   - Upstream GSD commit/tag
   - Breaking changes (if any)
4. Smoke test on clean machine with `--profile home` (or run `./scripts/smoke-install.sh`).

## Attribution

This bundle includes upstream `gsd-build/get-shit-done` content under MIT License.
See:

- `skills/claw-gets-shit-done/upstream/LICENSE`
- `NOTICE.md`
