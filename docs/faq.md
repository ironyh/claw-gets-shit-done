# FAQ

## Why does docs deploy fail with `configure-pages` Not Found?

GitHub Pages must be enabled in repo settings and set to use GitHub Actions as source.

Path: `Settings -> Pages -> Build and deployment -> Source: GitHub Actions`

## How do I get searchable docs locally?

```bash
pip install -r requirements-docs.txt
mkdocs serve
```

Then open `http://127.0.0.1:8000` and use the built-in search box.

## Does `./update.sh` remember previous install flags?

Yes. By default it reuses args from:

- `~/.openclaw/cgsd-install-state.json`

Use `./update.sh --no-saved-state` to ignore saved args.

## Why are no loop messages appearing in Discord?

Most common causes:

1. Missing or wrong `--loop-target`.
2. Bot lacks channel/thread permissions.
3. You intentionally enabled silent mode via `--allow-no-loop-delivery`.

Run:

```bash
./doctor.sh
openclaw cron list --all
```

## Can I run multiple projects on one machine?

Yes. Use distinct `--project-root` and `--project-key` per project to avoid cron name collisions.

## Do councils replace GSD commands?

No. Councils are discussion/risk review. Execution stays in GSD + queue flow.
