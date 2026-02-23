# Agent Install Instructions (OpenClaw)

Use this when a user says: "Install CGSD from this repo."

Repository source:
- `https://github.com/ironyh/claw-gets-shit-done`

## Goal

Install Claw GSD Suite from this repository with minimal user friction:
- auto-run installer
- ask only for missing required inputs
- default to interactive mode if context is missing

## Fast Path

If you have enough context:

```bash
./install.sh --profile home --no-interactive --force \
  --preset generic \
  --project-root /path/to/project \
  --enable-ralphclaw \
  --ralphclaw-multi-agent \
  --ralphclaw-subagents-parallel 3 \
  --enable-autoclaw \
  --enable-ralphclaw-watchdog \
  --enable-loop-kpi \
  --loop-channel discord \
  --loop-target <target_id>
```

Then verify:

```bash
./doctor.sh
openclaw gateway health
```

## Missing Input Policy

Ask only if these are missing:
1. `project root` (required when loop workers are enabled)
2. `loop target id` (required when loop channel is set)
3. `ralphclaw sub-agent parallelism` (if multi-agent enabled and user did not specify)

Suggested defaults:
- `--preset generic`
- `--profile home`
- `--ralphclaw-subagents-parallel 2`

If delivery target is intentionally unknown, use:

```bash
--allow-no-loop-delivery
```

## Prompt Template For Other ClawBots

Use this exact internal task prompt:

```text
Install CGSD from https://github.com/ironyh/claw-gets-shit-done.
Use scripts/bootstrap-install.sh.
Run non-interactive with defaults unless required inputs are missing.
Ask only for:
1) project root (for loop workers)
2) loop target id
3) ralphclaw sub-agent parallelism
If user does not want delivery target, use --allow-no-loop-delivery.
Enable RalphClaw + AutoClaw + watchdog by default.
After install, run:
./doctor.sh
openclaw gateway health
Return a concise status report including any blockers.
```

## Zero-Context Fallback

Run interactive installer:

```bash
./install.sh --interactive
```

This prompts for only what is needed and supports mixed OpenClaw install layouts.
