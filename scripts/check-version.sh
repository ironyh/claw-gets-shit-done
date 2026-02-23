#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
BUNDLE_FILE="$ROOT_DIR/bundle.json"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "[version][error] Missing VERSION file: $VERSION_FILE" >&2
  exit 1
fi

if [[ ! -f "$BUNDLE_FILE" ]]; then
  echo "[version][error] Missing bundle manifest: $BUNDLE_FILE" >&2
  exit 1
fi

version_file="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ -z "$version_file" ]]; then
  echo "[version][error] VERSION is empty." >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  version_bundle="$(jq -r '.version // empty' "$BUNDLE_FILE")"
else
  version_bundle="$(BUNDLE_FILE="$BUNDLE_FILE" python3 - <<'PY'
import json
import os
from pathlib import Path
data = json.loads(Path(os.environ["BUNDLE_FILE"]).read_text(encoding="utf-8"))
print(data.get("version", ""))
PY
)"
fi

if [[ -z "$version_bundle" ]]; then
  echo "[version][error] bundle.json version is empty." >&2
  exit 1
fi

if [[ "$version_file" != "$version_bundle" ]]; then
  echo "[version][error] VERSION ($version_file) != bundle.json version ($version_bundle)." >&2
  exit 1
fi

echo "[version] OK: $version_file"
