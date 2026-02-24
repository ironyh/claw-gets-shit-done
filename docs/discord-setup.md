# Discord Setup

This page covers channel targeting, forum targets, and slash authorization.

## Required Inputs

- delivery target: `--loop-target <id>`
- forum target (optional but recommended): `--discord-forum-target <forum_channel_id>`
- slash sender gate: `--discord-slash-allow-from <id|*>`

## Recommended Baseline

```bash
./install.sh \
  --profile home \
  --preset generic \
  --project-root /path/to/project \
  --enable-ralphclaw \
  --enable-autoclaw \
  --loop-channel discord \
  --loop-target <delivery_id> \
  --discord-forum-target <forum_channel_id> \
  --discord-slash-allow-from "*"
```

Then harden later by replacing `*` with explicit Discord user ids.

## What Installer Writes

- patches `channels.discord.allowFrom` in `openclaw.json` when configured
- writes plugin local config:
  - `~/.openclaw/extensions/gsd-command-aliases/config.local.json`
  - keys: `discordForumTarget`, `loopInboxFile`, `loopQueueFile` (when applicable)

## Validate

```bash
./doctor.sh
openclaw gateway health
openclaw plugins list --json | jq '.plugins[] | select(.id=="gsd-command-aliases")'
```

Test slash:
- run `/gsd-progress` in the intended Discord channel/thread

Test forum epic flow:
- run `/gsd-new-epic` and verify thread creation in configured forum target

## Common Failure Patterns

1. `This command requires authorization`
- missing/incorrect `channels.discord.allowFrom`
- fix: reinstall with `--discord-slash-allow-from "*"` or explicit ids

2. Forum thread not created
- missing `discordForumTarget` in plugin local config
- fix: set `--discord-forum-target` and rerun install/update

3. No announcements
- wrong `--loop-target` or missing bot permission in target channel/thread
