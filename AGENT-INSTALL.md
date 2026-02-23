# Agent Install Instructions (OpenClaw)

Use this when a user says: "Install CGSD from this repo."

## Goal

Install Claw GSD Suite from this repository with minimal user friction:
- auto-run installer
- ask only for missing required inputs
- default to interactive mode if context is missing

## Fast Path

If you have enough context:

```bash
./install.sh --profile home --no-interactive --force \
  --preset badgeid \
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
1. `loop target id` (required when loop channel is set)
2. `ralphclaw sub-agent parallelism` (if multi-agent enabled and user did not specify)

Suggested defaults:
- `--preset generic`
- `--profile home`
- `--ralphclaw-subagents-parallel 2`

If delivery target is intentionally unknown, use:

```bash
--allow-no-loop-delivery
```

## Zero-Context Fallback

Run interactive installer:

```bash
./install.sh --interactive
```

This prompts for only what is needed and supports mixed OpenClaw install layouts.
