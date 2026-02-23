# Proposals

## Next Improvements

1. Add optional command-level bridge: create forum epic from a GSD command.
2. Add queue aging policy (`stale_after_hours`) with automatic de-prioritization.
3. Add deterministic export of queue metrics grouped by `epic_id`.
4. Add optional back-sync from queue completion to `.planning` TODO completion.
5. Add validation command to enforce required fields in LOOP docs.

## Release Readiness Checklist

1. `bash -n install.sh update.sh doctor.sh uninstall.sh scripts/*.sh`
2. `shellcheck install.sh update.sh doctor.sh uninstall.sh scripts/*.sh`
3. `./scripts/smoke-install.sh`
4. `mkdocs build --strict`
