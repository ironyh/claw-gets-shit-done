#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="openclaw-gsd-suite"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
OUT_DIR="${ROOT_DIR}/dist"
ARCHIVE="${OUT_DIR}/${NAME}-v${VERSION}.tar.gz"
CHECKSUM="${ARCHIVE}.sha256"

"$ROOT_DIR/scripts/check-version.sh"

mkdir -p "$OUT_DIR"
rm -f "$ARCHIVE" "$CHECKSUM"

tar \
  --exclude-vcs \
  --exclude='dist' \
  --exclude='.DS_Store' \
  --exclude='*.swp' \
  --exclude='*.tmp' \
  -C "$(dirname "$ROOT_DIR")" \
  -czf "$ARCHIVE" \
  "$(basename "$ROOT_DIR")"

(cd "$OUT_DIR" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")")

echo "Built: $ARCHIVE"
echo "SHA256: $CHECKSUM"
