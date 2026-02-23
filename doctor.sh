#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw}"
SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
PLUGIN_PATH=""
CONFIG_PATH=""
PLUGIN_SET=0
CONFIG_SET=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Validate OpenClaw GSD suite installation.

Options:
  --openclaw-dir <path>  OpenClaw home dir (default: ~/.openclaw)
  --skill-dir <path>     Skill parent dir (default: ~/.codex/skills)
  --plugin-path <path>   Plugin install path
  --config <path>        openclaw.json path
  -h, --help             Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openclaw-dir) OPENCLAW_DIR="${2:-}"; shift 2 ;;
    --skill-dir) SKILL_DIR="${2:-}"; shift 2 ;;
    --plugin-path) PLUGIN_PATH="${2:-}"; PLUGIN_SET=1; shift 2 ;;
    --config) CONFIG_PATH="${2:-}"; CONFIG_SET=1; shift 2 ;;
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
GSD_TOOLS="$SKILL_PATH/bin/gsd-tools"

ok=0
warn=0

check_ok() {
  printf '[OK] %s\n' "$1"
  ok=$((ok + 1))
}

check_warn() {
  printf '[WARN] %s\n' "$1"
  warn=$((warn + 1))
}

[[ -d "$SKILL_PATH" ]] && check_ok "Skill installed: $SKILL_PATH" || check_warn "Missing skill: $SKILL_PATH"
[[ -x "$GSD_TOOLS" ]] && check_ok "gsd-tools executable: $GSD_TOOLS" || check_warn "Missing gsd-tools executable: $GSD_TOOLS"
[[ -d "$PLUGIN_PATH" ]] && check_ok "Plugin installed: $PLUGIN_PATH" || check_warn "Missing plugin: $PLUGIN_PATH"

if [[ -f "$CONFIG_PATH" ]] && command -v jq >/dev/null 2>&1; then
  in_paths="$(jq -r --arg p "$PLUGIN_PATH" '((.plugins.load.paths // []) | index($p)) != null' "$CONFIG_PATH" 2>/dev/null || echo false)"
  enabled="$(jq -r '.plugins.entries["gsd-command-aliases"].enabled // false' "$CONFIG_PATH" 2>/dev/null || echo false)"
  [[ "$in_paths" == "true" ]] && check_ok "Plugin load path configured" || check_warn "Plugin path not found in config load.paths"
  [[ "$enabled" == "true" ]] && check_ok "Plugin enabled in config" || check_warn "Plugin not enabled in config"
else
  check_warn "Cannot validate config (missing jq or config file): $CONFIG_PATH"
fi

if command -v openclaw >/dev/null 2>&1; then
  if openclaw gateway health >/dev/null 2>&1; then
    check_ok "openclaw gateway health OK"
  else
    check_warn "openclaw gateway health failed"
  fi
else
  check_warn "openclaw CLI not found in PATH"
fi

printf '\nSummary: %d ok, %d warnings\n' "$ok" "$warn"
if [[ "$warn" -gt 0 ]]; then
  exit 2
fi
