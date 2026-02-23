# GSD Command Aliases (OpenClaw Plugin)

Hyphen-style aliases for GSD commands:

- `/gsd-add-todo`
- `/gsd-check-todos`
- `/gsd-new-epic`
- `/gsd-progress`
- `/gsd-discuss-phase`
- `/gsd-plan-phase`
- `/gsd-execute-phase`
- `/gsd-verify-work`
- `/gsd-resume-work`
- `/gsd-new-project`

## Runtime path resolution

The plugin resolves `gsd-tools` from (in order):

1. `GSD_TOOLS_PATH`
2. Plugin config `gsdToolsPath`
3. `<workspace>/skills/claw-gets-shit-done/bin/gsd-tools`
4. `$CODEX_HOME/skills/claw-gets-shit-done/bin/gsd-tools`
5. `~/.codex/skills/claw-gets-shit-done/bin/gsd-tools`

Workspace candidates include command context (`ctx.cwd`/`ctx.workingDirectory`), plugin config `workspaceDir`, env (`GSD_WORKSPACE_DIR`, `OPENCLAW_WORKSPACE`), `process.cwd()`, plugin-source root, and `~/.openclaw/workspace`.

## Optional plugin config

`openclaw.plugin.json` supports:

- `workspaceDir`: explicit workspace root
- `gsdToolsPath`: explicit gsd-tools binary path
- `loopInboxFile`: override LOOP inbox path
- `loopQueueFile`: override LOOP queue path
- `defaultEpicId`: default epic id for todo intake sync
- `defaultEpicTitle`: default epic title for todo intake sync
- `autoQueueTodo`: `true|false` (default `true`) to sync `/gsd-add-todo` directly into LOOP files
- `autoThreadOnNewEpic`: `true|false` (default `true`) for `/gsd-new-epic` forum thread creation attempt
- `discordForumTarget`: Discord forum channel target used by `/gsd-new-epic`
- `discordAccountId`: optional channel account id for thread create command

## Deterministic behavior

- `/gsd-add-todo` writes `.planning/todos/pending/*.md` and (by default) enqueues one loop intake item immediately.
- `/gsd-new-epic` creates an epic intake in LOOP files and attempts Discord forum thread creation when configured.
