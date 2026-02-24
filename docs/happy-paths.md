# Happy Paths

Use these as default, low-friction setups.

## 1) Local Project, No Discord

Use this when you want GSD + local loops only.

```bash
./install.sh \
  --profile home \
  --preset generic \
  --project-root /path/to/project \
  --enable-ralphclaw \
  --enable-autoclaw \
  --allow-no-loop-delivery \
  --restart-gateway
./doctor.sh
```

Expected:
- GSD skill and alias plugin installed
- RalphClaw + AutoClaw cron jobs created
- no Discord delivery dependency

## 2) Discord Forum-Driven Project

Use this when each epic should map to forum discussions and queue decisions.

```bash
./install.sh \
  --profile home \
  --preset generic \
  --project-root /path/to/project \
  --enable-ralphclaw \
  --enable-autoclaw \
  --enable-ralphclaw-watchdog \
  --enable-gsd-bridge \
  --enable-forum-daily-council \
  --enable-forum-weekly-council \
  --loop-channel discord \
  --loop-target <delivery_channel_or_thread_id> \
  --discord-forum-target <forum_channel_id> \
  --discord-slash-allow-from "*"
```

Expected:
- slash aliases work in allowed Discord channels
- forum thread intake and council jobs feed queue decisions
- queue execution and verification stay GSD-first

## 3) Brownfield Bootstrap

Use this for existing codebases.

```bash
./install.sh --interactive
```

When prompted for bootstrap mode, select:
- `map-then-new-project` (recommended for brownfield)

Then run:
1. `/gsd-map-codebase`
2. `/gsd-new-project`

## 4) Update Existing Installation

```bash
./update.sh
```

If gateway restart is noisy on your machine:

```bash
./update.sh --no-restart-gateway
openclaw gateway health
```
