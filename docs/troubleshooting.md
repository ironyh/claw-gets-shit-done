# Troubleshooting

Focused troubleshooting for the most common operational failures.

## 1) `./update.sh` Looks Stuck

Symptom:
- update appears to keep running after restart phase

Check:

```bash
openclaw gateway status --deep
openclaw gateway health
```

If health is OK, gateway is live and update can proceed.

Workaround:

```bash
./update.sh --no-restart-gateway
```

## 2) Gateway Restart Timed Out But Port Is In Use

Symptom:
- restart timeout after 60s
- port already in use by running gateway

Interpretation:
- often a false-negative restart error while service is already healthy

Check:

```bash
openclaw gateway health
```

## 3) `This command requires authorization` in Discord

Cause:
- `channels.discord.allowFrom` missing sender id (or `*`)

Fix:

```bash
./install.sh --discord-slash-allow-from "*"
```

Then tighten to explicit ids when stable.

## 4) Forum Intake Fails

Check deterministic script first:

```bash
bash /home/irony/clawd/scripts/badgeid-forum-bridge.sh
```

If script fails, fix script/parsing before changing Discord auth.

## 5) Duplicate Plugin ID Warning

Symptom:
- duplicate `gsd-command-aliases` plugin id in gateway status output

Fix:
- keep one plugin path and remove duplicate load paths
- rerun installer without `--no-dedupe-plugin-paths`

## 6) Queue Not Progressing

Check:

```bash
openclaw cron list --all --json | jq '.jobs[] | {name: .name, enabled: .enabled, last: .state.lastStatus}'
```

And confirm queue items are actionable:
- `status: ready`
- `verify_status: pending|failed`

Also check for concurrent writers:
- legacy autoloops + CGSD loops running together
- bridge jobs writing LOOP files at the same cadence as loop workers

Prefer one active loop stack per project and shared lock usage.

## 7) No Discord Announcements

Most common:
- wrong `--loop-target`
- bot missing permissions in target channel/thread
- silent mode (`--allow-no-loop-delivery`) intentionally active

## 8) Quick Diagnostics Bundle

```bash
./doctor.sh
openclaw gateway health
openclaw plugins list --json | jq '.plugins[] | select(.id=="gsd-command-aliases")'
openclaw cron list --all --json | jq '.jobs[] | {name: .name, enabled: .enabled, cron: .schedule.expr, last: .state.lastStatus}'
```
