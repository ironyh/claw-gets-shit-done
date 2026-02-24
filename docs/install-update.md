# Install And Update

## Install From Repo URL

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ironyh/claw-gets-shit-done/main/scripts/bootstrap-install.sh)
```

## Typical Install (Home Profile)

```bash
./install.sh --profile home --restart-gateway
./doctor.sh
```

## Interactive Wizards

`./install.sh --interactive` now includes:
- bootstrap wizard (existing/brownfield/empty/greenfield)
- Discord wiring wizard (delivery target, forum target, slash authorization mode)

## Full Loop Setup Example

```bash
./install.sh \
  --profile home \
  --preset generic \
  --project-root /path/to/project \
  --enable-ralphclaw \
  --enable-autoclaw \
  --enable-ralphclaw-watchdog \
  --enable-loop-kpi \
  --enable-gsd-bridge \
  --enable-forum-daily-council \
  --enable-forum-weekly-council \
  --discord-forum-target <forum_channel_id> \
  --discord-slash-allow-from "*" \
  --loop-channel discord \
  --loop-target <target_id>
```

## GSD Bootstrap (Brownfield vs Greenfield)

In interactive walkthrough, CGSD first detects project state and then asks how bootstrap should run.
You can override this explicitly with `--gsd-bootstrap <mode>`.

Modes:
- `auto` (default)
- `skip`
- `new-project`
- `new-project-auto`
- `map-then-new-project`

After install, CGSD prints recommended first GSD command based on detected state:

- Existing GSD project (`.planning/PROJECT.md`): skip bootstrap
- Brownfield (existing code without map): `/gsd-map-codebase` then `/gsd-new-project`
- Empty project directory: `/gsd-new-project`
- Greenfield: `/gsd-new-project`
- Greenfield with `PROJECT_IDEA.md`/`IDEA.md`/`PRD.md`: `/gsd-new-project --auto @<file>`

## Deterministic GSD Bridge

Manual run:

```bash
./scripts/gsd-loop-bridge.sh --project-root /path/to/project
```

Concurrency note:
- Bridge now uses a non-blocking shared lock (`.openclaw/locks/loop-worker.lock` by default).
- If lock is busy (RalphClaw/AutoClaw already writing), bridge skips that cycle instead of colliding on LOOP files.

Install-time cron:

```bash
./install.sh --enable-gsd-bridge --gsd-bridge-cron "*/10 * * * *" --project-root /path/to/project
```

## Update

Normal path:

```bash
./update.sh
```

Behavior:

- fetch + fast-forward update (branch refs)
- detached checkout (tag/sha refs)
- reinstall + doctor check
- reuses last saved install args from `~/.openclaw/cgsd-install-state.json` if no extra args are supplied

## Update With Explicit Install Args

```bash
./update.sh -- --profile workspace --workspace-root /path/to/workspace --openclaw-dir ~/.openclaw
```

## Useful Update Switches

- `--allow-dirty`: allow update when tracked files are modified
- `--no-saved-state`: ignore saved install args and use current/default installer behavior
- `--ref <branch|tag|sha>`: pin update source
