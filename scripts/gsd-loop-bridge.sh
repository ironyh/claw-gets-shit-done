#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$PWD"
INBOX_FILE=""
QUEUE_FILE=""
EPIC_ID="EPIC-GSD-BACKLOG"
EPIC_TITLE="GSD Backlog"
EPIC_THREAD=""
MAX_ITEMS=25
GSD_TOOLS_BIN="${GSD_TOOLS_PATH:-}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Deterministic bridge between GSD planning state and LOOP inbox/queue.

Options:
  --project-root <path>   Project root with .planning/ (default: current dir)
  --inbox <path>          LOOP-INBOX markdown file
  --queue <path>          LOOP-QUEUE markdown file
  --epic-id <id>          Epic id for bridged items (default: EPIC-GSD-BACKLOG)
  --epic-title <title>    Epic title for bridged items (default: GSD Backlog)
  --epic-thread <ref>     Optional thread link/id for epic provenance
  --max-items <n>         Max todos to sync per run (default: 25)
  --gsd-tools <path>      Explicit gsd-tools binary path
  -h, --help              Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    --inbox) INBOX_FILE="${2:-}"; shift 2 ;;
    --queue) QUEUE_FILE="${2:-}"; shift 2 ;;
    --epic-id) EPIC_ID="${2:-}"; shift 2 ;;
    --epic-title) EPIC_TITLE="${2:-}"; shift 2 ;;
    --epic-thread) EPIC_THREAD="${2:-}"; shift 2 ;;
    --max-items) MAX_ITEMS="${2:-}"; shift 2 ;;
    --gsd-tools) GSD_TOOLS_BIN="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[gsd-bridge][error] Unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! [[ "$MAX_ITEMS" =~ ^[0-9]+$ ]] || [[ "$MAX_ITEMS" -lt 1 ]]; then
  echo "[gsd-bridge][error] --max-items must be a positive integer" >&2
  exit 1
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "[gsd-bridge][error] project root does not exist: $PROJECT_ROOT" >&2
  exit 1
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

if [[ -z "$INBOX_FILE" ]]; then
  INBOX_FILE="$PROJECT_ROOT/.openclaw/LOOP-INBOX.md"
fi
if [[ -z "$QUEUE_FILE" ]]; then
  QUEUE_FILE="$PROJECT_ROOT/.openclaw/LOOP-QUEUE.md"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

detect_gsd_tools() {
  local candidate
  for candidate in \
    "$GSD_TOOLS_BIN" \
    "$PROJECT_ROOT/skills/claw-gets-shit-done/bin/gsd-tools" \
    "$BUNDLE_DIR/skills/claw-gets-shit-done/bin/gsd-tools" \
    "${CODEX_HOME:-}/skills/claw-gets-shit-done/bin/gsd-tools" \
    "$HOME/.codex/skills/claw-gets-shit-done/bin/gsd-tools"
  do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

if ! GSD_TOOLS_BIN="$(detect_gsd_tools)"; then
  echo "[gsd-bridge][warn] gsd-tools not found; skipping sync." >&2
  exit 0
fi

mkdir -p "$(dirname "$INBOX_FILE")" "$(dirname "$QUEUE_FILE")"
[[ -f "$INBOX_FILE" ]] || printf '# LOOP-INBOX\n\n' > "$INBOX_FILE"
[[ -f "$QUEUE_FILE" ]] || printf '# LOOP-QUEUE\n\n' > "$QUEUE_FILE"

tmp_dir="$(mktemp -d /tmp/gsd-loop-bridge.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

progress_json="$tmp_dir/progress.json"
todos_json="$tmp_dir/todos.json"
rows_tsv="$tmp_dir/rows.tsv"

if ! (cd "$PROJECT_ROOT" && "$GSD_TOOLS_BIN" init progress --raw) > "$progress_json" 2>/dev/null; then
  printf '{"roadmap_exists":false,"current_phase":null}\n' > "$progress_json"
fi
if ! (cd "$PROJECT_ROOT" && "$GSD_TOOLS_BIN" init todos --raw) > "$todos_json" 2>/dev/null; then
  printf '{"count":0,"todos":[]}\n' > "$todos_json"
fi

mapfile -t progress_meta < <(python3 - "$progress_json" <<'PY'
import json
import sys

path = sys.argv[1]
data = {}
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    data = {}

roadmap_exists = bool(data.get("roadmap_exists"))
current_phase = ""
cp = data.get("current_phase")
if isinstance(cp, dict):
    current_phase = str(cp.get("number") or "").strip()

print("1" if roadmap_exists else "0")
print(current_phase)
PY
)

ROADMAP_EXISTS="${progress_meta[0]:-0}"
CURRENT_PHASE="${progress_meta[1]:-}"

python3 - "$todos_json" "$MAX_ITEMS" > "$rows_tsv" <<'PY'
import json
import re
import sys

todos_path = sys.argv[1]
max_items = int(sys.argv[2])

def clean(v: str) -> str:
    return re.sub(r"\s+", " ", (v or "")).strip()

def safe_slug(text: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-").upper()
    return slug or "UNTITLED"

payload = {"todos": []}
try:
    with open(todos_path, "r", encoding="utf-8") as fh:
        payload = json.load(fh)
except Exception:
    payload = {"todos": []}

if not isinstance(payload, dict):
    payload = {"todos": []}

todos = payload.get("todos")
if not isinstance(todos, list):
    todos = []

for todo in todos[:max_items]:
    if not isinstance(todo, dict):
        continue
    file_name = clean(str(todo.get("file") or ""))
    path = clean(str(todo.get("path") or ""))
    title = clean(str(todo.get("title") or "Untitled"))
    area = clean(str(todo.get("area") or "general"))
    created = clean(str(todo.get("created") or ""))
    source = file_name or path or title
    if source.lower().endswith(".md"):
        source = source[:-3]
    item_id = f"GSD-TODO-{safe_slug(source)}"
    fields = [item_id, title, area, path, created]
    print("\t".join(fields))
PY

append_inbox_item() {
  local id="$1" title="$2" area="$3" path="$4" gsd_action="$5" gsd_phase="$6"
  cat >> "$INBOX_FILE" <<EOF

- id: $id
  title: $title
  type: quality
  epic_id: $EPIC_ID
  epic_title: $EPIC_TITLE
  epic_thread: ${EPIC_THREAD:-n/a}
  gsd_action: $gsd_action
  gsd_phase: ${gsd_phase:-}
  impact: medium
  effort: s
  acceptance:
    - [ ] mapped to active GSD phase/todo
    - [ ] verification passes
  next_step: sync from ${path:-.planning/todos/pending}
  owner: ralphclaw
  status: ready
  source_area: ${area:-general}
EOF
}

append_queue_item() {
  local id="$1" title="$2" path="$3" gsd_action="$4" gsd_phase="$5"
  cat >> "$QUEUE_FILE" <<EOF

- id: $id
  title: $title
  source: GSD-TODO
  source_path: ${path:-.planning/todos/pending}
  epic_id: $EPIC_ID
  epic_thread: ${EPIC_THREAD:-n/a}
  gsd_action: $gsd_action
  gsd_phase: ${gsd_phase:-}
  priority: P1
  status: ready
  verify_status: pending
  verify_failures:
  retry_count: 0
  owner: ralphclaw
  blocker:
  unblock_next_step:
EOF
}

DISCOVERED=0
ADDED=0
SKIPPED=0

default_action="/gsd-new-project"
if [[ "$ROADMAP_EXISTS" -eq 1 ]]; then
  default_action="/gsd-resume-work"
fi

while IFS=$'\t' read -r id title area path created; do
  [[ -n "$id" ]] || continue
  DISCOVERED=$((DISCOVERED + 1))

  if grep -Fq -- "- id: $id" "$INBOX_FILE" || grep -Fq -- "- id: $id" "$QUEUE_FILE"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  append_inbox_item "$id" "$title" "$area" "$path" "$default_action" "$CURRENT_PHASE"
  append_queue_item "$id" "$title" "$path" "$default_action" "$CURRENT_PHASE"
  ADDED=$((ADDED + 1))
done < "$rows_tsv"

echo "[gsd-bridge] project=$PROJECT_ROOT"
echo "[gsd-bridge] roadmap_exists=$ROADMAP_EXISTS current_phase=${CURRENT_PHASE:-none}"
echo "[gsd-bridge] discovered=$DISCOVERED added=$ADDED skipped_existing=$SKIPPED"
echo "[gsd-bridge] inbox=$INBOX_FILE queue=$QUEUE_FILE"
