# Configuration

## Core Paths

- `--openclaw-dir`: OpenClaw runtime root (`~/.openclaw` by default)
- `--config`: explicit `openclaw.json` path
- `--skill-dir`: where `claw-gets-shit-done` skill is installed
- `--plugin-path`: where `gsd-command-aliases` plugin is installed

## Loop/Autonomy Flags

- `--enable-ralphclaw`
- `--enable-autoclaw`
- `--enable-ralphclaw-watchdog`
- `--enable-loop-kpi`
- `--enable-gsd-bridge`
- `--enable-forum-daily-council`
- `--enable-forum-weekly-council`

## Scheduling

- `--ralphclaw-cron "*/15 * * * *"`
- `--autoclaw-cron "0 */3 * * *"`
- `--loop-kpi-cron "0 8 * * 1"`
- `--gsd-bridge-cron "*/10 * * * *"`
- `--forum-daily-cron "15 9,17 * * *"`
- `--forum-weekly-cron "0 9 * * 1"`

## Project Scoping

- `--project-root <path>` is required when autonomous jobs are enabled.
- `--project-key <slug>` overrides job namespace labels.
- `--loop-inbox-file`, `--loop-queue-file`, `--loop-kpi-file` override default artifact paths.
- `--gsd-bootstrap <mode>` controls bootstrap hint behavior:
  - `auto` (detect existing/brownfield/empty/greenfield)
  - `skip`
  - `new-project`
  - `new-project-auto`
  - `map-then-new-project`

## Delivery

- `--loop-channel <name>`
- `--loop-target <id>`
- `--discord-text-channel <id>`
- `--discord-forum-thread <id>`
- `--discord-forum-target <id>` (installer writes plugin local config `config.local.json`)
- `--discord-slash-allow-from <id|*>` (installer patches `channels.discord.allowFrom`, default `*`)
- If omitted, installer tries best-effort autodetect.
- `--allow-no-loop-delivery` for silent execution.

## Runtime Env Overrides

- `GSD_WORKSPACE_DIR=/path/to/project`
- `GSD_TOOLS_PATH=/path/to/skills/claw-gets-shit-done/bin/gsd-tools`

## Plugin Runtime Overrides

OpenClaw builds with strict config schemas may reject custom plugin keys in `openclaw.json`.
Use plugin-local config instead:

- `~/.openclaw/extensions/gsd-command-aliases/config.local.json`

Supported keys:

- `workspaceDir`
- `gsdToolsPath`
- `loopInboxFile`
- `loopQueueFile`
- `defaultEpicId`
- `defaultEpicTitle`
- `autoQueueTodo` (default `true`)
- `autoThreadOnNewEpic` (default `true`)
- `discordForumTarget`
- `discordAccountId`
