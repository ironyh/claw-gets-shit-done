#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw}"
SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
PLUGIN_PATH=""
CONFIG_PATH=""
PLUGIN_SET=0
CONFIG_SET=0
DRY_RUN=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Uninstall OpenClaw GSD suite (non-destructive: moves files to timestamped backups).

Options:
  --openclaw-dir <path>  OpenClaw home dir (default: ~/.openclaw)
  --skill-dir <path>     Skill parent dir (default: ~/.codex/skills)
  --plugin-path <path>   Plugin install path
  --config <path>        openclaw.json path
  --dry-run              Print planned actions only
  -h, --help             Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openclaw-dir) OPENCLAW_DIR="${2:-}"; shift 2 ;;
    --skill-dir) SKILL_DIR="${2:-}"; shift 2 ;;
    --plugin-path) PLUGIN_PATH="${2:-}"; PLUGIN_SET=1; shift 2 ;;
    --config) CONFIG_PATH="${2:-}"; CONFIG_SET=1; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "$PLUGIN_SET" -eq 0 ]]; then
  PLUGIN_PATH="${OPENCLAW_DIR}/extensions/gsd-command-aliases"
fi
if [[ "$CONFIG_SET" -eq 0 ]]; then
  CONFIG_PATH="${OPENCLAW_DIR}/openclaw.json"
fi

SKILL_PATH="$SKILL_DIR/claw-gets-shit-done"

run_or_echo() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] %s\n' "$*"
  else
    eval "$@"
  fi
}

backup_move() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local backup
    backup="${target}.removed.$(date +%Y%m%d-%H%M%S)"
    echo "[uninstall] moving $target -> $backup"
    run_or_echo "mv \"$target\" \"$backup\""
  else
    echo "[uninstall] skip missing: $target"
  fi
}

backup_move "$SKILL_PATH"
backup_move "$PLUGIN_PATH"

if [[ -f "$CONFIG_PATH" ]] && command -v jq >/dev/null 2>&1; then
  tmp="${CONFIG_PATH}.tmp"
  echo "[uninstall] patching config: $CONFIG_PATH"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] jq patch remove gsd-command-aliases"
  else
    cp "$CONFIG_PATH" "${CONFIG_PATH}.bak.$(date +%Y%m%d-%H%M%S)"
    jq --arg p "$PLUGIN_PATH" '
      .plugins.load.paths = ((.plugins.load.paths // []) | map(select(. != $p))) |
      .plugins.entries = (.plugins.entries // {}) |
      del(.plugins.entries["gsd-command-aliases"]) |
      .plugins.installs = (.plugins.installs // {}) |
      del(.plugins.installs["gsd-command-aliases"])
    ' "$CONFIG_PATH" > "$tmp"
    mv "$tmp" "$CONFIG_PATH"
  fi
fi

echo "[uninstall] done"
