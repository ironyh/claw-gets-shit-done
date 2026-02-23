#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE="${CGSD_REMOTE:-origin}"
REF="${CGSD_REF:-main}"
RESTART_GATEWAY=1
DRY_RUN=0
FORCE_INSTALL=1
ALLOW_DIRTY=0
USE_SAVED_STATE=1

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options] [-- <extra install.sh args>]

Update CGSD from git and reinstall with one command.

Options:
  --remote <name>         Git remote (default: origin)
  --ref <branch|tag|sha>  Git ref to update to (default: main)
  --allow-dirty           Allow update with local uncommitted changes
  --no-saved-state        Do not reuse saved install args from prior install
  --no-restart-gateway    Do not restart gateway after reinstall
  --no-force              Do not pass --force to install.sh
  --dry-run               Print actions only
  -h, --help              Show help

Examples:
  ./update.sh
  ./update.sh --ref main
  ./update.sh --no-saved-state
  ./update.sh -- --profile workspace --workspace-root /path/to/workspace --openclaw-dir ~/.openclaw
USAGE
}

print_cmd() {
  printf '[dry-run]'
  while [[ $# -gt 0 ]]; do
    printf ' %q' "$1"
    shift
  done
  printf '\n'
}

run_or_print() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_cmd "$@"
  else
    "$@"
  fi
}

is_branch_ref() {
  local ref="$1"
  git -C "$ROOT_DIR" show-ref --verify --quiet "refs/remotes/$REMOTE/$ref" || \
    git -C "$ROOT_DIR" show-ref --verify --quiet "refs/heads/$ref"
}

is_tag_ref() {
  local ref="$1"
  git -C "$ROOT_DIR" show-ref --verify --quiet "refs/tags/$ref"
}

resolve_ref_commit() {
  local ref="$1"
  git -C "$ROOT_DIR" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null
}

checkout_detached_ref() {
  local ref="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_cmd git -C "$ROOT_DIR" checkout --detach "$ref"
    return 0
  fi
  git -C "$ROOT_DIR" checkout --detach "$ref"
}

find_state_file() {
  local -a candidates=()
  if [[ -n "${CGSD_INSTALL_STATE_FILE:-}" ]]; then
    candidates+=("$CGSD_INSTALL_STATE_FILE")
  else
    candidates+=(
      "$HOME/.openclaw/cgsd-install-state.json"
      "$HOME/.config/openclaw/cgsd-install-state.json"
    )
  fi

  local candidate=""
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

load_saved_install_args() {
  [[ "${#EXTRA_INSTALL_ARGS[@]}" -eq 0 ]] || return 0
  [[ "$USE_SAVED_STATE" -eq 1 ]] || return 0

  local state_file=""
  state_file="$(find_state_file || true)"
  if [[ -z "$state_file" ]]; then
    echo "[update] No saved install state found; using installer defaults."
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "[update][warn] python3 missing; cannot load saved install args from $state_file"
    return 0
  fi

  local -a loaded=()
  if ! mapfile -d '' -t loaded < <(python3 - "$state_file" <<'PY'
import json
import sys
from pathlib import Path

state_file = Path(sys.argv[1])
data = json.loads(state_file.read_text(encoding="utf-8"))
args = data.get("installArgs", [])
if not isinstance(args, list):
    raise SystemExit(2)
for arg in args:
    if not isinstance(arg, str):
        raise SystemExit(3)
    sys.stdout.write(arg)
    sys.stdout.write("\0")
PY
  ); then
    echo "[update][warn] Failed to parse saved install args: $state_file"
    return 0
  fi

  if [[ "${#loaded[@]}" -gt 0 ]]; then
    EXTRA_INSTALL_ARGS=("${loaded[@]}")
    echo "[update] Loaded saved install args from: $state_file"
  fi
}

EXTRA_INSTALL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) REMOTE="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    --no-saved-state) USE_SAVED_STATE=0; shift ;;
    --no-restart-gateway) RESTART_GATEWAY=0; shift ;;
    --no-force) FORCE_INSTALL=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --)
      shift
      EXTRA_INSTALL_ARGS=("$@")
      break
      ;;
    *)
      echo "[update][error] Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "[update][error] git is required but not installed." >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR/.git" ]]; then
  echo "[update][error] $ROOT_DIR is not a git repository." >&2
  exit 1
fi

if [[ "$ALLOW_DIRTY" -eq 0 ]]; then
  if [[ -n "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=no)" ]]; then
    echo "[update][error] Working tree has tracked modifications. Commit/stash first, or pass --allow-dirty." >&2
    exit 1
  fi
fi

echo "[update] Fetching latest from $REMOTE ..."
run_or_print git -C "$ROOT_DIR" fetch --tags "$REMOTE"

if is_branch_ref "$REF"; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_cmd git -C "$ROOT_DIR" checkout "$REF"
  else
    CURRENT_REF="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ "$CURRENT_REF" != "$REF" ]]; then
      if git -C "$ROOT_DIR" show-ref --verify --quiet "refs/heads/$REF"; then
        git -C "$ROOT_DIR" checkout "$REF"
      else
        git -C "$ROOT_DIR" checkout -B "$REF" "$REMOTE/$REF"
      fi
    fi
  fi

  echo "[update] Pulling $REMOTE/$REF ..."
  run_or_print git -C "$ROOT_DIR" pull --ff-only "$REMOTE" "$REF"
else
  if ! resolve_ref_commit "$REF"; then
    echo "[update] Ref $REF not local; fetching it explicitly ..."
    run_or_print git -C "$ROOT_DIR" fetch "$REMOTE" "$REF"
  fi

  if ! resolve_ref_commit "$REF"; then
    echo "[update][error] Unable to resolve ref to a commit: $REF" >&2
    exit 1
  fi

  if is_tag_ref "$REF"; then
    echo "[update] Checking out tag in detached mode: $REF"
  else
    echo "[update] Checking out commit-like ref in detached mode: $REF"
  fi
  checkout_detached_ref "$REF"
fi

load_saved_install_args

INSTALL_ARGS=()
if [[ "$FORCE_INSTALL" -eq 1 ]]; then
  INSTALL_ARGS+=(--force)
fi
if [[ "$RESTART_GATEWAY" -eq 1 ]]; then
  INSTALL_ARGS+=(--restart-gateway)
fi
if [[ "${#EXTRA_INSTALL_ARGS[@]}" -gt 0 ]]; then
  INSTALL_ARGS+=("${EXTRA_INSTALL_ARGS[@]}")
fi

echo "[update] Reinstalling CGSD ..."
run_or_print "$ROOT_DIR/install.sh" "${INSTALL_ARGS[@]}"

echo "[update] Running doctor checks ..."
run_or_print "$ROOT_DIR/doctor.sh"

echo "[update] Done."
