---
name: cgsd-docs
description: Use when creating or updating documentation for Claw Gets Shit Done (CGSD), including install/update docs, Discord forum flow, GSD bridge behavior, and operational runbooks.
---

# CGSD Documentation Skill

## When to use
- Updating `README.md` and `docs/*.md` for CGSD behavior changes.
- Documenting new flags, cron jobs, loop behavior, and Discord flow.
- Writing release-ready docs for install, update, operations, and troubleshooting.

## Source of truth order
1. `install.sh`, `update.sh`, `doctor.sh`, `uninstall.sh`
2. `plugins/gsd-command-aliases/index.js`
3. `scripts/*.sh`
4. `README.md`, then `docs/*.md`

Never document behavior that is not implemented in code.

## Required docs touchpoints
For any user-facing behavior change, update:
- `README.md` (quick-start + links)
- `docs/configuration.md` (flags/config keys/defaults)
- `docs/operations.md` (runtime behavior + troubleshooting)
- `docs/command-reference.md` (if command surface changed)

If Discord intake/council/queue flow changes, also update:
- `docs/discord-forum-flow.md`
- `docs/architecture.md`

## Writing style
- Keep sections short and task-first.
- Use executable examples only.
- Prefer one behavior per heading.
- Keep terms consistent:
  - `AutoClaw` = discovery
  - `RalphClaw` = execution loop
  - `GSD Bridge` = deterministic todo sync
  - `Forum Council` = advisory discuss layer

## Validation before shipping
1. Run docs build:
   - `mkdocs build --strict`
2. Verify all referenced files/commands exist.
3. Ensure README links point to actual `docs/*.md` files.
4. If flags changed, verify defaults in docs match script defaults.
