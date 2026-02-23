# Discord Forum Flow

## Default Model

- One forum thread is treated as one epic.
- Daily council triages thread input and decides:
  - `promote_to_queue`
  - `need_more_data`
  - `reject`
- Promoted items must include `gsd_action`.

## Epic Mapping

- Epic id default: `EPIC-<thread_id>`
- Queue items are tasks under that epic, not whole epics.
- Queue tasks must keep acceptance criteria and owner.

## Role Behavior

- Roles/personas are advisory only.
- They can challenge assumptions and ask scoped follow-up questions.
- They do not bypass GSD or queue-based execution.

## Recommended Delivery Setup

- Use a dedicated forum channel per project.
- Route job output with `--discord-forum-thread <thread_id>` or channel target.
- Keep one project key per project to avoid cron naming collisions.
