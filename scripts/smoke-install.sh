#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/cgsd-smoke.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

OPENCLAW_DIR="$TMP_DIR/.openclaw"
SKILL_DIR="$TMP_DIR/skills"
PLUGIN_PATH="$OPENCLAW_DIR/extensions/gsd-command-aliases"
CONFIG_PATH="$OPENCLAW_DIR/openclaw.json"
BIN_DIR="$TMP_DIR/bin"

mkdir -p "$OPENCLAW_DIR" "$SKILL_DIR" "$BIN_DIR"

cat > "$CONFIG_PATH" <<'JSON'
{
  "plugins": {
    "load": {
      "paths": []
    },
    "entries": {},
    "installs": {}
  }
}
JSON

cat > "$BIN_DIR/openclaw" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "gateway" && "${2:-}" == "health" ]]; then
  exit 0
fi
if [[ "${1:-}" == "gateway" && "${2:-}" == "restart" ]]; then
  exit 0
fi
if [[ "${1:-}" == "plugins" && "${2:-}" == "list" ]]; then
  printf '{"plugins":[]}\n'
  exit 0
fi
exit 0
SH
chmod +x "$BIN_DIR/openclaw"

export PATH="$BIN_DIR:$PATH"

echo "[smoke] install"
"$ROOT_DIR/install.sh" \
  --profile home \
  --force \
  --openclaw-dir "$OPENCLAW_DIR" \
  --skill-dir "$SKILL_DIR" \
  --plugin-path "$PLUGIN_PATH" \
  --config "$CONFIG_PATH"

echo "[smoke] doctor"
"$ROOT_DIR/doctor.sh" \
  --openclaw-dir "$OPENCLAW_DIR" \
  --skill-dir "$SKILL_DIR" \
  --plugin-path "$PLUGIN_PATH" \
  --config "$CONFIG_PATH"

echo "[smoke] uninstall"
"$ROOT_DIR/uninstall.sh" \
  --openclaw-dir "$OPENCLAW_DIR" \
  --skill-dir "$SKILL_DIR" \
  --plugin-path "$PLUGIN_PATH" \
  --config "$CONFIG_PATH"

if [[ -d "$SKILL_DIR/claw-gets-shit-done" ]]; then
  echo "[smoke][error] Skill path still exists after uninstall." >&2
  exit 1
fi

if [[ -d "$PLUGIN_PATH" ]]; then
  echo "[smoke][error] Plugin path still exists after uninstall." >&2
  exit 1
fi

if ! compgen -G "$SKILL_DIR/claw-gets-shit-done.removed.*" >/dev/null; then
  echo "[smoke][error] Missing skill backup artifact." >&2
  exit 1
fi

if ! compgen -G "$PLUGIN_PATH.removed.*" >/dev/null; then
  echo "[smoke][error] Missing plugin backup artifact." >&2
  exit 1
fi

echo "[smoke] OK"
