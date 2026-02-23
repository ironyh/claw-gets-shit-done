#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${ROOT_DIR}/skills/claw-gets-shit-done/upstream"
META_FILE="${ROOT_DIR}/skills/claw-gets-shit-done/UPSTREAM.md"
UPSTREAM_URL="https://github.com/gsd-build/get-shit-done.git"
REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      REF="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash scripts/sync-claw-gsd.sh [--ref <tag-or-sha>]" >&2
      exit 1
      ;;
  esac
done

TMP_DIR="$(mktemp -d /tmp/claw-gsd-sync.XXXXXX)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "[claw-gsd] Cloning upstream into ${TMP_DIR}"
git clone --depth 1 "${UPSTREAM_URL}" "${TMP_DIR}/repo" >/dev/null

if [[ -n "${REF}" ]]; then
  echo "[claw-gsd] Checking out ${REF}"
  git -C "${TMP_DIR}/repo" fetch --depth 1 origin "${REF}" >/dev/null 2>&1 || true
  git -C "${TMP_DIR}/repo" -c advice.detachedHead=false checkout -q "${REF}"
fi

COMMIT_SHA="$(git -C "${TMP_DIR}/repo" rev-parse HEAD)"
SYNCED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "${DEST_DIR}"
rsync -a --delete \
  --exclude '.git' \
  --exclude 'node_modules' \
  "${TMP_DIR}/repo/" "${DEST_DIR}/"

cat > "${META_FILE}" <<META
# Upstream Source

- Repo: https://github.com/gsd-build/get-shit-done
- Synced commit: ${COMMIT_SHA}
- Synced at: ${SYNCED_AT}
- Sync command: \`bash scripts/sync-claw-gsd.sh [--ref <tag-or-sha>]\`
META

echo "[claw-gsd] Synced ${COMMIT_SHA}"
echo "[claw-gsd] Updated ${DEST_DIR}"
