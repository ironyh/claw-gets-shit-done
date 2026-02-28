# Loop Settings

Tune autonomous behavior without breaking delivery discipline.

## Core Flags

- `--enable-ralphclaw`
- `--enable-autoclaw`
- `--enable-ralphclaw-watchdog`
- `--enable-loop-kpi`
- `--enable-model-health`
- `--enable-gsd-bridge`
- `--enable-forum-daily-council`
- `--enable-forum-weekly-council`

## Cadence Tuning

- `--ralphclaw-cron`: execution frequency
- `--autoclaw-cron`: discovery/proposal frequency
- `--model-health-cron`: model routing audit frequency
- `--gsd-bridge-cron`: sync cadence
- `--forum-daily-cron`, `--forum-weekly-cron`: discussion cadence

Recommended defaults:
- RalphClaw every 5-15 minutes
- AutoClaw every 1-3 hours
- GSD bridge every 5-15 minutes

## Safety and Scope Controls

- `--loop-max-files <n>`: cap blast radius per run
- `--loop-lock-file <path>`: prevent overlapping runs
- `--project-root <path>`: required when loops are enabled
- `--project-key <slug>`: isolate cron job names per project
- `--model-health-file <path>`: where routing/fallback report is written

## Delivery Controls

- `--loop-channel <name>`
- `--loop-target <id>`
- `--allow-no-loop-delivery` for silent mode

## Multi-Sub-Agent Mode (RalphClaw)

- `--ralphclaw-multi-agent`
- `--ralphclaw-subagents-parallel <n>`

Guideline:
- keep `2-3` in most setups
- raise only when tasks are independent and verification is strong

## Preset Examples

Balanced:

```bash
./install.sh \
  --enable-ralphclaw \
  --enable-autoclaw \
  --ralphclaw-cron "*/10 * * * *" \
  --autoclaw-cron "0 */2 * * *"
```

Aggressive:

```bash
./install.sh \
  --enable-ralphclaw \
  --enable-autoclaw \
  --ralphclaw-cron "*/5 * * * *" \
  --autoclaw-cron "0 * * * *" \
  --loop-max-files 10
```

Stable/Low-noise:

```bash
./install.sh \
  --enable-ralphclaw \
  --enable-autoclaw \
  --ralphclaw-cron "*/15 * * * *" \
  --autoclaw-cron "0 */3 * * *" \
  --loop-max-files 8
```

## Model Routing Visibility

Enable the built-in deterministic reporter to surface fallback/mismatch instead of guessing from chat output:

```bash
./install.sh --enable-model-health --model-health-cron "0 */6 * * *"
```

Manual report:

```bash
./scripts/model-health-report.sh --project-root /path/to/project --project-key my-project
```

Output includes:
- configured model per job
- actual provider/model from latest cron run
- fallback/mismatch detection
- latest failure signal

Recommended baseline:
- Keep one primary model (`--loop-model provider/model`) for all loop jobs.
- Keep periodic model health enabled (every 3-6h).
- If fallback appears repeatedly, fix provider auth/availability before tuning prompts.

## Per-Project Activity Control

CGSD installer now maintains a registry (default: `~/.openclaw/cgsd-project-activity.json`) used by:

- `/gsd-project-mode status|check`
- `/gsd-project-mode off|medium|high`

Recommended architecture:

- one Discord text channel per project
- one forum channel per project
- one epic per forum thread (`EPIC-<thread_id>`)
- use `/gsd-project-mode` in each project channel for local intensity control

Registry path override:

```bash
./install.sh --project-activity-registry /custom/path/cgsd-project-activity.json
```
