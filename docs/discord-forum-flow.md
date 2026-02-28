# Discord Forum Flow

## Default Model

- One forum thread is treated as one epic.
- New tasks within that epic should reuse the same `epic_thread`.
- Daily council triages thread input and decides:
  - `promote_to_queue`
  - `need_more_data`
  - `reject`
- Promoted items must include `gsd_action`.

## GSD-Equivalent Flow

Use this mapping when you want forum/council work to follow the same structure as GSD:

1. Intake
- Capture thread input into inbox/backlog artifacts.
- Create a decision record with `Decision: pending`.

2. Discuss
- Run discussion/council and force an explicit decision:
  - `promote_to_queue`
  - `need_more_data`
  - `reject`
- Set the corresponding `gsd_action` (`/gsd-discuss-phase`, `/gsd-plan-phase`, `/gsd-add-todo`, or `none`).

3. Plan
- For `promote_to_queue`, convert to executable queue task with acceptance criteria.

4. Execute
- RalphClaw executes one bounded task from queue.

5. Verify
- Queue item must pass verify gate (`verify_status: passed`) or be re-queued.

6. Control
- Track planned vs achieved outcomes in a decision control report.
- A promoted decision is not complete until verification evidence is recorded.

## Epic Mapping

- Epic id default: `EPIC-<thread_id>`
- Queue items are tasks under that epic, not whole epics.
- Queue tasks must keep acceptance criteria and owner.
- `/gsd-new-epic` reuses current thread when run inside a forum thread.
- `/gsd-add-todo` in a forum thread inherits epic mapping from that thread.

## Decision Tracking Contract

For each discussed epic/task, keep explicit fields:

- `decision`: `pending|promote_to_queue|need_more_data|reject`
- `decision_rationale`
- `gsd_action`
- `queue_status`
- `verify_status`: `pending|passed|failed`
- `verify_evidence`
- `owner`
- `last_updated`

This keeps discuss outputs auditable and measurable instead of implicit in chat text.

## Role Behavior

- Roles/personas are advisory only.
- They can challenge assumptions and ask scoped follow-up questions.
- They do not bypass GSD or queue-based execution.

## Recommended Delivery Setup

- Use a dedicated forum channel per project.
- Use a dedicated text channel per project for control commands and worker summaries.
- Route job output with `--discord-forum-thread <thread_id>` or channel target.
- Keep one project key per project to avoid cron naming collisions.
- Map Discord channel/thread -> project key in activity registry (auto-managed by installer) so `/gsd-project-mode this ...` resolves correctly.
