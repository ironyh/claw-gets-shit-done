# GSD Settings

Keep GSD as the control plane and source of truth.

## Bootstrap Modes

Installer flag:
- `--gsd-bootstrap auto|skip|new-project|new-project-auto|map-then-new-project`

Auto behavior:
- existing `.planning/PROJECT.md`: skip
- brownfield: map then new project
- empty project: new project
- greenfield with idea file: new project auto

## Runtime Resolution

If your workspace layout is non-standard:

- `GSD_WORKSPACE_DIR=/path/to/project`
- `GSD_TOOLS_PATH=/path/to/skills/claw-gets-shit-done/bin/gsd-tools`

## Alias Plugin Behavior

Plugin local config:
- `~/.openclaw/extensions/gsd-command-aliases/config.local.json`

Useful keys:
- `autoQueueTodo` (default `true`)
- `autoThreadOnNewEpic` (default `true`)
- `discordForumTarget`
- `loopInboxFile`
- `loopQueueFile`
- `workspaceDir`
- `gsdToolsPath`

## GSD + Queue Discipline

Required pattern:
1. discuss/plan in GSD
2. promote to queue with explicit `gsd_action`
3. execute one bounded step
4. verify gate must pass before done

If verify fails:
- return task to queue as `ready`
- set `verify_status: failed`
- increment retry count
- set explicit next verify action

## Brownfield Note

For existing codebases, run:
1. `/gsd-map-codebase`
2. `/gsd-new-project`

Do not skip mapping unless you intentionally accept lower context quality.
