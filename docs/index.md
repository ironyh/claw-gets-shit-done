# CGSD Documentation

Claw Gets Shit Done (CGSD) is an OpenClaw bundle that combines:

- GSD workflow (`skills/claw-gets-shit-done`)
- command aliases (`plugins/gsd-command-aliases`)
- operational scripts (`install.sh`, `update.sh`, `doctor.sh`, `uninstall.sh`)
- optional autonomous loop workers (RalphClaw, AutoClaw, Watchdog, KPI, Forum Councils)

## Execution Model (GSD-first)

- GSD is the control plane and source of truth for planning/execution/verification.
- AutoClaw can propose work, but each promoted item must include `gsd_action`.
- RalphClaw executes only queue items aligned with GSD state.
- Role/persona councils are advisory only: they discuss risk/tradeoffs and answer scoped questions, but do not bypass queue + GSD flow.

## What This Site Covers

- full install and update lifecycle
- build and release process
- installer/runtime configuration
- command and alias reference
- system architecture and data flow
- Discord forum discussion flow (daily + weekly councils)
- operational troubleshooting
- concrete proposal backlog for next improvements

## Quick Links

- Install and update: [Install & Update](install-update.md)
- Build process: [Build & Release](build-release.md)
- Flags and defaults: [Configuration](configuration.md)
- Command map: [Command Reference](command-reference.md)
- System model: [Architecture](architecture.md)
- Forum governance: [Discord Forum Flow](discord-forum-flow.md)
- Improvement ideas: [Proposals](proposals.md)
- Runtime troubleshooting: [Operations](operations.md)
- Common issues: [FAQ](faq.md)
- Published docs: <https://ironyh.github.io/claw-gets-shit-done/>

## Search

Search is built into the docs site (`plugins: search` in `mkdocs.yml`).
Use it to jump directly to flags, commands, and troubleshooting entries.

## Source of Truth

- Installer behavior: `install.sh`
- Update behavior: `update.sh`
- Package metadata: `bundle.json`, `VERSION`
- CI checks: `.github/workflows/ci.yml`
- Docs deploy: `.github/workflows/docs.yml`
