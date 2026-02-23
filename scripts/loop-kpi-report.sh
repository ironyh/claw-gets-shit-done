#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$PWD"
DAYS=7
INBOX_FILE=""
QUEUE_FILE=""
OUT_FILE=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Generate weekly KPI markdown for RalphClaw/AutoClaw flow.

Options:
  --project-root <path>   Project root (default: current directory)
  --days <n>              Lookback window in days (default: 7)
  --inbox <path>          Loop inbox markdown file
  --queue <path>          Loop queue markdown file
  --out <path>            Output markdown path
  -h, --help              Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    --days) DAYS="${2:-}"; shift 2 ;;
    --inbox) INBOX_FILE="${2:-}"; shift 2 ;;
    --queue) QUEUE_FILE="${2:-}"; shift 2 ;;
    --out) OUT_FILE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[loop-kpi][error] Unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]]; then
  echo "[loop-kpi][error] --days must be a positive integer" >&2
  exit 1
fi

if [[ -z "$INBOX_FILE" ]]; then
  INBOX_FILE="$PROJECT_ROOT/.openclaw/LOOP-INBOX.md"
fi
if [[ -z "$QUEUE_FILE" ]]; then
  QUEUE_FILE="$PROJECT_ROOT/.openclaw/LOOP-QUEUE.md"
fi
if [[ -z "$OUT_FILE" ]]; then
  OUT_FILE="$PROJECT_ROOT/.openclaw/LOOP-KPI-WEEKLY.md"
fi

mkdir -p "$(dirname "$OUT_FILE")"

count_matches() {
  local file="$1"
  local pattern="$2"
  if [[ ! -f "$file" ]]; then
    echo 0
    return 0
  fi
  (rg -n "$pattern" "$file" || true) | wc -l | tr -d ' '
}

GIT_COMMITS=0
GIT_FILES_TOUCHED=0
GIT_TEST_COMMITS=0
GIT_FIX_COMMITS=0

if [[ -d "$PROJECT_ROOT/.git" ]]; then
  GIT_COMMITS="$(git -C "$PROJECT_ROOT" rev-list --count --since="$DAYS days ago" HEAD 2>/dev/null || echo 0)"
  GIT_FILES_TOUCHED="$(
    git -C "$PROJECT_ROOT" log --since="$DAYS days ago" --name-only --pretty=format: 2>/dev/null \
      | (rg -v '^\s*$' || true) | sort -u | wc -l | tr -d ' '
  )"
  GIT_TEST_COMMITS="$(
    git -C "$PROJECT_ROOT" log --since="$DAYS days ago" --pretty=format:%s 2>/dev/null \
      | (rg -i '(test|coverage|qa)' || true) | wc -l | tr -d ' '
  )"
  GIT_FIX_COMMITS="$(
    git -C "$PROJECT_ROOT" log --since="$DAYS days ago" --pretty=format:%s 2>/dev/null \
      | (rg -i '(fix|bug|hotfix|incident|regression)' || true) | wc -l | tr -d ' '
  )"
fi

QUEUE_READY="$(count_matches "$QUEUE_FILE" 'status:\s*ready')"
QUEUE_IN_PROGRESS="$(count_matches "$QUEUE_FILE" 'status:\s*in_progress')"
QUEUE_BLOCKED="$(count_matches "$QUEUE_FILE" 'status:\s*blocked')"
QUEUE_DONE="$(count_matches "$QUEUE_FILE" 'status:\s*done')"
INBOX_READY="$(count_matches "$INBOX_FILE" 'status:\s*ready')"
INBOX_TOTAL="$(count_matches "$INBOX_FILE" '^- id:')"

GENERATED_AT="$(date -Iseconds)"

cat > "$OUT_FILE" <<EOF
# Loop KPI Weekly

Generated: $GENERATED_AT  
Window: last $DAYS days  
Project root: $PROJECT_ROOT

## Delivery Signal
- Commits: $GIT_COMMITS
- Files touched: $GIT_FILES_TOUCHED
- Test/QA commits: $GIT_TEST_COMMITS
- Fix/bug commits: $GIT_FIX_COMMITS

## Queue Health
- Queue ready: $QUEUE_READY
- Queue in progress: $QUEUE_IN_PROGRESS
- Queue blocked: $QUEUE_BLOCKED
- Queue done: $QUEUE_DONE
- Inbox total proposals: $INBOX_TOTAL
- Inbox ready proposals: $INBOX_READY

## Interpretation
- If blocked > done, prioritize unblock work in next cycle.
- If test/qa commits are low, schedule dedicated reliability steps.
- If inbox ready grows faster than queue done, tighten prioritization and batch size.
EOF

echo "[loop-kpi] wrote $OUT_FILE"
