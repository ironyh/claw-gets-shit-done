# GSD Command Aliases (OpenClaw Plugin)

Hyphen-style aliases for GSD commands:

- `/gsd-add-todo`
- `/gsd-check-todos`
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
