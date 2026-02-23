#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="openclaw-gsd-suite"
VERSION="$(cat "$ROOT_DIR/VERSION")"
OUT_DIR="${ROOT_DIR}/dist"
ARCHIVE="${OUT_DIR}/${NAME}-v${VERSION}.tar.gz"

mkdir -p "$OUT_DIR"

tar \
  --exclude='dist' \
  --exclude='.DS_Store' \
  -C "$(dirname "$ROOT_DIR")" \
  -czf "$ARCHIVE" \
  "$(basename "$ROOT_DIR")"

echo "Built: $ARCHIVE"
