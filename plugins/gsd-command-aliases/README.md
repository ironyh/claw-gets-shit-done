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
- `/gsd-project-mode`
- `/gsd-project-bind`
- `/cgsd` (control-plane wrapper for project activity settings)
- `/cgsd-panel`, `/cgsd-status`, `/cgsd-check`
- `/cgsd-off`, `/cgsd-medium`, `/cgsd-high`
- `/cgsd-i0`, `/cgsd-i20`, `/cgsd-i40`, `/cgsd-i60`, `/cgsd-i80`, `/cgsd-i100`
- `/badgeid-activity` (legacy alias for badgeid project mode)

## Runtime path resolution

The plugin resolves `gsd-tools` from (in order):

1. `GSD_TOOLS_PATH`
2. Plugin config `gsdToolsPath`
3. `<workspace>/skills/claw-gets-shit-done/bin/gsd-tools`
4. `$CODEX_HOME/skills/claw-gets-shit-done/bin/gsd-tools`
5. `~/.codex/skills/claw-gets-shit-done/bin/gsd-tools`

Workspace candidates include command context (`ctx.cwd`/`ctx.workingDirectory`), plugin config `workspaceDir`, env (`GSD_WORKSPACE_DIR`, `OPENCLAW_WORKSPACE`), `process.cwd()`, plugin-source root, and `~/.openclaw/workspace`.

## Optional plugin config

Use `config.local.json` in the plugin directory (for example `~/.openclaw/extensions/gsd-command-aliases/config.local.json`).
This is preferred over custom keys in `openclaw.json` on strict-schema OpenClaw builds.

Supported keys:

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
- `projectActivityRegistry`: path to project activity registry JSON (default: `~/.openclaw/cgsd-project-activity.json`)
- `defaultProjectKey`: optional default project key for activity control

### Project Activity Control (`/gsd-project-mode`)

Manage per-project worker intensity directly from chat:

- `/gsd-project-mode status [this|<project>|all]`
- `/gsd-project-mode check [this|<project>|all]`
- `/gsd-project-mode set <this|<project>|all> off|medium|high`
- `/gsd-project-mode <off|medium|high> [this|<project>|all]`
- `/gsd-project-mode <project> <off|medium|high>`

Resolution rules:
- `this` resolves project from current Discord channel/thread via registry mapping.
- `all` applies to all registered projects.
- explicit `<project>` targets one project key.

### Project Context Binding (`/gsd-project-bind`)

Bind current channel/thread to a project key so `this` works reliably:

- `/gsd-project-bind <project>`
- `/gsd-project-bind show`
- `/gsd-project-bind show all`

### CGSD Control Plane (`/cgsd`)

Unified Discord-facing control interface (wizard-style command surface):

- `/cgsd`
- `/cgsd panel`
- `/cgsd add-project <project> <path>`
- `/cgsd status [this|<project>|all]`
- `/cgsd check [this|<project>|all]`
- `/cgsd set <this|<project>|all> off|medium|high`
- `/cgsd <off|medium|high> [this|<project>|all]`
- `/cgsd intensity [this|<project>|all] <0-100>`
- `/cgsd bind <project>`
- `/cgsd projects`

Folder binding:
- `/cgsd add-project <project> <path>` writes/updates `projects.<project>.projectRoot` in:
  - `~/.openclaw/cgsd-project-activity.json`
- `/cgsd bind <project>` maps current channel/thread to that project key.

Click-only quick commands (no args):
- `/cgsd-panel`, `/cgsd-status`, `/cgsd-check`
- `/cgsd-off`, `/cgsd-medium`, `/cgsd-high`
- `/cgsd-all-off`, `/cgsd-all-medium`, `/cgsd-all-high`
- `/cgsd-i0`, `/cgsd-i20`, `/cgsd-i40`, `/cgsd-i60`, `/cgsd-i80`, `/cgsd-i100`

Intensity mapping:
- `0-19` -> `off`
- `20-69` -> `medium`
- `70-100` -> `high`

## Discord slash authorization

If Discord replies with `⚠️ This command requires authorization.`, ensure sender auth is allowed:

- `channels.discord.allowFrom` in `~/.openclaw/openclaw.json` must include your Discord user id (or `*`).
- CGSD installer can patch this with: `--discord-slash-allow-from <id|*>`.

## Deterministic behavior

- `/gsd-add-todo` writes `.planning/todos/pending/*.md` and (by default) enqueues one loop intake item immediately.
- `/gsd-new-epic` creates an epic intake in LOOP files and attempts Discord forum thread creation when configured.
- If `/gsd-new-epic` is run inside a Discord forum thread, it reuses that thread (no new thread created).
- If `/gsd-add-todo` is run inside a Discord forum thread, queue items inherit that thread as `epic_thread`.
