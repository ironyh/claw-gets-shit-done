# Loop Settings

Tune autonomous behavior without breaking delivery discipline.

## Core Flags

- `--enable-ralphclaw`
- `--enable-autoclaw`
- `--enable-ralphclaw-watchdog`
- `--enable-loop-kpi`
- `--enable-gsd-bridge`
- `--enable-forum-daily-council`
- `--enable-forum-weekly-council`

## Cadence Tuning

- `--ralphclaw-cron`: execution frequency
- `--autoclaw-cron`: discovery/proposal frequency
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
