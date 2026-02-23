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

## Intake Semantics

### `/gsd-add-todo`

1. Writes todo under `.planning/todos/pending`.
2. If `autoQueueTodo=true` (default), syncs one idempotent item to:
   - `LOOP-INBOX.md`
   - `LOOP-QUEUE.md`
3. Queue item starts with:
   - `status: ready`
   - `verify_status: pending`
   - `priority: P1`

### `/gsd-new-epic`

1. Creates epic intake metadata in loop docs.
2. If forum integration is configured, can auto-create a Discord forum thread.
3. Epic id defaults to `EPIC-<thread_or_generated_id>`.

## Related Config Keys

In `openclaw.json`:

- `plugins.entries.gsd-command-aliases.autoQueueTodo`
- `plugins.entries.gsd-command-aliases.autoThreadOnNewEpic`
- `plugins.entries.gsd-command-aliases.discordForumTarget`
- `plugins.entries.gsd-command-aliases.workspaceDir`
- `plugins.entries.gsd-command-aliases.gsdToolsPath`
