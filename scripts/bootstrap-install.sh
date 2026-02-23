#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${CGSD_REPO_URL:-https://github.com/ironyh/claw-gets-shit-done.git}"
REF="${CGSD_REF:-main}"
KEEP_WORKDIR="${CGSD_KEEP_WORKDIR:-0}"
WORKDIR="$(mktemp -d /tmp/cgsd-bootstrap.XXXXXX)"

cleanup() {
  if [[ "$KEEP_WORKDIR" == "1" ]]; then
    echo "[bootstrap] Keeping workdir: $WORKDIR"
    return 0
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

if ! command -v git >/dev/null 2>&1; then
  echo "[bootstrap][error] git is required but not installed." >&2
  exit 1
fi

echo "[bootstrap] Cloning $REPO_URL@$REF ..."
git clone --depth 1 --branch "$REF" "$REPO_URL" "$WORKDIR/repo" >/dev/null
cd "$WORKDIR/repo"

if [[ $# -eq 0 ]]; then
  if [[ -t 0 ]]; then
    echo "[bootstrap] No installer flags supplied. Starting interactive install."
    exec ./install.sh --interactive
  fi
  echo "[bootstrap][error] Non-interactive shell with no installer flags." >&2
  echo "[bootstrap][hint] Pass install flags, e.g. --profile home --no-interactive --force" >&2
  exit 1
fi

echo "[bootstrap] Running installer with provided flags..."
exec ./install.sh "$@"
