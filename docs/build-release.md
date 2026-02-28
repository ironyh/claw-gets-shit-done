# Build And Release

## Version Guard

Before build/release, version consistency is enforced:

- `VERSION`
- `bundle.json.version`

Validation script:

```bash
./scripts/check-version.sh
```

## Build Artifact

```bash
./build-release.sh
```

Outputs:

- `dist/openclaw-gsd-suite-vX.Y.Z.tar.gz`
- `dist/openclaw-gsd-suite-vX.Y.Z.tar.gz.sha256`

## CI Coverage

Main CI (`.github/workflows/ci.yml`) checks:

- bash syntax for core scripts + `scripts/*.sh`
- shellcheck linting
- version guard
- smoke install/uninstall flow
- project activity registry smoke flow
- docs build (`mkdocs build --strict`)

GitHub Pages publish workflow:
- `.github/workflows/docs.yml`
- builds docs from `docs/` + `mkdocs.yml`
- deploys to `https://ironyh.github.io/claw-gets-shit-done/` on `main`

## Recommended Release Sequence

1. update docs and changelog notes
2. bump `VERSION` and `bundle.json`
3. run `./scripts/check-version.sh`
4. run `./scripts/smoke-install.sh`
5. run `./scripts/smoke-project-activity.sh`
6. run `./build-release.sh`
7. verify checksum file in `dist/`
8. tag and publish release
