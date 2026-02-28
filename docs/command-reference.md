# Command Reference

## Canonical GSD Commands

Use upstream-compatible forms:

- `/gsd <command> [args]`
- `/gsd:<command> [args]`

Examples:

- `/gsd:add-todo "Fix auth error handling"`
- `/gsd:plan-phase 2`
- `/gsd:verify-work`

## Alias Commands (Plugin)

The `gsd-command-aliases` plugin adds slash-friendly snake/hyphen aliases:

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

## Intake Semantics

### `/gsd-add-todo`

1. Writes todo under `.planning/todos/pending`.
2. If `autoQueueTodo=true` (default), syncs one idempotent item to:
   - `LOOP-INBOX.md`
   - `LOOP-QUEUE.md`
3. If command is run inside a Discord forum thread, todo sync inherits that thread as epic context:
   - `epic_thread` = current thread id
   - `epic_id` = existing epic mapped to that thread (or `EPIC-<thread_id>` if none exists yet)
4. Queue item starts with:
   - `status: ready`
   - `verify_status: pending`
   - `priority: P1`

### `/gsd-new-epic`

1. Creates epic intake metadata in loop docs.
2. If command is run inside an existing Discord forum thread, that thread is reused (no new thread created).
3. If run outside a thread and forum integration is configured, it can auto-create a new Discord forum thread.
4. Epic id defaults to `EPIC-<thread_or_generated_id>`.

### Brownfield Startup

For existing codebases, run:

1. `/gsd-map-codebase`
2. `/gsd-new-project`

For empty project directories:

- `/gsd-new-project`

For greenfield with an idea document, you can use:

- `/gsd-new-project --auto @PROJECT_IDEA.md`

### `/gsd-discuss-phase`

Expected outcome is explicit artifact state, not only chat text:

1. Capture concrete decisions (constraints, tradeoffs, chosen direction).
2. Map decision to next command (`/gsd-plan-phase`, `/gsd-add-todo`, etc.).
3. If integrated with queue/forum flow, update decision fields:
   - `decision`
   - `gsd_action`
   - `verify_status` (later when executed)

## Related Config Keys

In `openclaw.json` (channel auth gate):

- `channels.discord.allowFrom` (must include sender id or `*` for slash/plugin command access)

In plugin local config (`~/.openclaw/extensions/gsd-command-aliases/config.local.json`):

- `autoQueueTodo`
- `autoThreadOnNewEpic`
- `discordForumTarget`
- `workspaceDir`
- `gsdToolsPath`
- `projectActivityRegistry`

## Project Activity Modes

`/gsd-project-mode` controls how active autonomous workers should be per project.

Examples:

- `/gsd-project-mode status`
- `/gsd-project-mode check all`
- `/gsd-project-mode high`
- `/gsd-project-mode badgeid medium`
- `/gsd-project-mode set all off`

Modes:

- `off`: pause registered jobs for selected project(s)
- `medium`: enable jobs with lower cadence profile
- `high`: enable jobs with full cadence profile

### `/gsd-project-bind`

Bind current channel/thread context to a project key:

- `/gsd-project-bind <project>`
- `/gsd-project-bind show`
- `/gsd-project-bind show all`

Use this when `this` resolution is ambiguous across multiple projects.
