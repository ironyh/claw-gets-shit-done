#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$PWD"
PROJECT_KEY=""
OUT_FILE=""
MAX_JOBS=30

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Generate deterministic model-health report for CGSD loop cron jobs.

Options:
  --project-root <path>   Project root (default: current directory)
  --project-key <slug>    Project key used in cron names (required)
  --out <path>            Output markdown path (default: <project>/.openclaw/LOOP-MODEL-HEALTH.md)
  --max-jobs <n>          Max matching jobs to inspect (default: 30)
  -h, --help              Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    --project-key) PROJECT_KEY="${2:-}"; shift 2 ;;
    --out) OUT_FILE="${2:-}"; shift 2 ;;
    --max-jobs) MAX_JOBS="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[model-health][error] Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROJECT_KEY" ]]; then
  echo "[model-health][error] --project-key is required" >&2
  exit 1
fi

if ! [[ "$MAX_JOBS" =~ ^[0-9]+$ ]] || [[ "$MAX_JOBS" -lt 1 ]]; then
  echo "[model-health][error] --max-jobs must be a positive integer" >&2
  exit 1
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "[model-health][error] project root does not exist: $PROJECT_ROOT" >&2
  exit 1
fi

if ! command -v openclaw >/dev/null 2>&1; then
  echo "[model-health][error] openclaw CLI not found" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[model-health][error] jq not found" >&2
  exit 1
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
if [[ -z "$OUT_FILE" ]]; then
  OUT_FILE="$PROJECT_ROOT/.openclaw/LOOP-MODEL-HEALTH.md"
fi
mkdir -p "$(dirname "$OUT_FILE")"

cleanup_json() {
  sed '/^\[plugins\]/d'
}

extract_json_payload() {
  python3 -c '
import json
import re
import sys

raw = sys.stdin.read()
if not raw:
    raise SystemExit(1)

# Strip ANSI escapes so box-drawing/colored status lines do not break parsing.
raw = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", raw)
raw = raw.strip()
if not raw:
    raise SystemExit(1)

decoder = json.JSONDecoder()

def try_decode(text: str):
    try:
        obj = json.loads(text)
    except Exception:
        return None
    return obj

obj = try_decode(raw)
if obj is not None:
    print(json.dumps(obj))
    raise SystemExit(0)

for idx, ch in enumerate(raw):
    if ch not in "[{":
        continue
    fragment = raw[idx:]
    try:
        candidate, consumed = decoder.raw_decode(fragment)
    except Exception:
        continue
    tail = fragment[consumed:].strip()
    # Prefer full-tail parses, but allow short noisy suffixes.
    if not tail or len(tail) <= 12:
        print(json.dumps(candidate))
        raise SystemExit(0)

raise SystemExit(1)
'
}

to_local_time() {
  local ms="${1:-0}"
  if [[ -z "$ms" || "$ms" == "0" || "$ms" == "null" ]]; then
    printf 'never'
    return 0
  fi
  date -d "@$((ms/1000))" +"%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || printf '%s' "$ms"
}

escape_md() {
  printf '%s' "${1:-}" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^\s+//; s/\s+$//; s/\|/\\|/g'
}

detect_fallback() {
  local configured="${1:-}"
  local actual_provider="${2:-}"
  local actual_model="${3:-}"

  if [[ -z "$actual_model" ]]; then
    printf 'unknown'
    return 0
  fi

  local cfg_provider=""
  local cfg_model="$configured"
  if [[ "$configured" == */* ]]; then
    cfg_provider="${configured%%/*}"
    cfg_model="${configured#*/}"
  fi

  local cfg_leaf="${cfg_model##*/}"
  local actual_leaf="${actual_model##*/}"

  if [[ -n "$cfg_provider" && "${cfg_provider,,}" != "${actual_provider,,}" ]]; then
    printf 'yes'
    return 0
  fi

  if [[ "${cfg_model,,}" == "${actual_model,,}" || "${cfg_leaf,,}" == "${actual_leaf,,}" ]]; then
    printf 'no'
  else
    printf 'yes'
  fi
}

cron_raw="$(openclaw cron list --json 2>/dev/null || true)"
cron_json="$(printf '%s\n' "$cron_raw" | cleanup_json | extract_json_payload || true)"
if [[ -z "$cron_json" ]]; then
  echo "[model-health][error] failed to read JSON from 'openclaw cron list --json'" >&2
  echo "[model-health][hint] run 'openclaw doctor --fix' if gateway config is invalid" >&2
  exit 1
fi

job_filter="[$PROJECT_KEY]"
jobs_tsv="$(printf '%s' "$cron_json" | jq -r --arg key "$job_filter" --argjson max_jobs "$MAX_JOBS" '
  (.jobs // [])
  | map(select((.name // "") | contains($key)))
  | .[:$max_jobs]
  | .[]
  | [
      (.id // ""),
      (.name // ""),
      (.payload.model // ""),
      (.schedule.expr // ""),
      (.state.lastStatus // "")
    ]
  | @tsv
')"

generated_at="$(date -Iseconds)"

if [[ -z "$jobs_tsv" ]]; then
  cat > "$OUT_FILE" <<EOF
# Loop Model Health

Generated: $generated_at  
Project key: $PROJECT_KEY  
Project root: $PROJECT_ROOT

No matching cron jobs found for name pattern: \`[$PROJECT_KEY]\`.

Checks:
- Verify install used \`--project-key $PROJECT_KEY\`
- Verify loop jobs are enabled and created
EOF
  echo "[model-health] wrote $OUT_FILE"
  exit 0
fi

total_jobs=0
jobs_with_history=0
fallback_count=0
failed_count=0
no_history_count=0

table_lines=()

while IFS=$'\t' read -r job_id job_name configured_model schedule_expr state_last_status; do
  [[ -n "$job_id" ]] || continue
  total_jobs=$((total_jobs + 1))

  runs_raw="$(openclaw cron runs --id "$job_id" --limit 1 2>/dev/null || true)"
  runs_json="$(printf '%s\n' "$runs_raw" | cleanup_json | extract_json_payload || true)"

  actual_model=""
  actual_provider=""
  run_status="no-runs"
  run_at_ms="0"
  duration_ms=""
  if [[ -n "$runs_json" ]]; then
    actual_model="$(printf '%s' "$runs_json" | jq -r '.entries[0].model // empty' 2>/dev/null || true)"
    actual_provider="$(printf '%s' "$runs_json" | jq -r '.entries[0].provider // empty' 2>/dev/null || true)"
    run_status="$(printf '%s' "$runs_json" | jq -r '.entries[0].status // "no-runs"' 2>/dev/null || printf 'no-runs')"
    run_at_ms="$(printf '%s' "$runs_json" | jq -r '.entries[0].runAtMs // 0' 2>/dev/null || printf '0')"
    duration_ms="$(printf '%s' "$runs_json" | jq -r '.entries[0].durationMs // empty' 2>/dev/null || true)"
  fi

  fallback_used="$(detect_fallback "$configured_model" "$actual_provider" "$actual_model")"
  if [[ "$run_status" == "no-runs" || -z "$actual_model" ]]; then
    no_history_count=$((no_history_count + 1))
  else
    jobs_with_history=$((jobs_with_history + 1))
  fi
  if [[ "$fallback_used" == "yes" ]]; then
    fallback_count=$((fallback_count + 1))
  fi
  if [[ "$run_status" != "ok" && "$run_status" != "no-runs" ]]; then
    failed_count=$((failed_count + 1))
  fi

  actual_cell="n/a"
  if [[ -n "$actual_model" ]]; then
    actual_cell="${actual_provider:-unknown}/${actual_model}"
  fi

  note=""
  if [[ "$run_status" == "no-runs" ]]; then
    note="no run history yet"
  elif [[ "$fallback_used" == "yes" ]]; then
    note="configured != actual (likely fallback or routing)"
  elif [[ "$fallback_used" == "unknown" ]]; then
    note="insufficient data"
  else
    note="configured model used"
  fi
  if [[ -n "$duration_ms" ]]; then
    note="$note; duration=${duration_ms}ms"
  fi

  table_lines+=("| $(escape_md "$job_name") | $(escape_md "$configured_model") | $(escape_md "$actual_cell") | $fallback_used | $run_status | $(to_local_time "$run_at_ms") | $(escape_md "$note") |")
done <<< "$jobs_tsv"

{
  cat <<EOF
# Loop Model Health

Generated: $generated_at  
Project key: $PROJECT_KEY  
Project root: $PROJECT_ROOT

## Summary
- Jobs inspected: $total_jobs
- Jobs with run history: $jobs_with_history
- Fallback/mismatch detected: $fallback_count
- Failed runs (latest): $failed_count
- Jobs without runs yet: $no_history_count

## Job Trace
| Job | Configured model | Actual model (latest) | Fallback | Last status | Last run | Notes |
|---|---|---|---|---|---|---|
EOF
  for line in "${table_lines[@]}"; do
    printf '%s\n' "$line"
  done

  cat <<EOF

## Recommended Actions
EOF

  if [[ "$fallback_count" -gt 0 ]]; then
    cat <<EOF
- Fallback detected in one or more jobs: check provider auth/cooldown/availability.
- Verify configured model is actually routable in this environment.
EOF
  fi
  if [[ "$failed_count" -gt 0 ]]; then
    cat <<EOF
- One or more latest runs failed: inspect with \`openclaw cron runs --id <job_id> --limit 5\`.
EOF
  fi
  if [[ "$no_history_count" -gt 0 ]]; then
    cat <<EOF
- Some jobs have no run history yet: trigger manually with \`openclaw cron run <job_id>\`.
EOF
  fi
  if [[ "$fallback_count" -eq 0 && "$failed_count" -eq 0 && "$no_history_count" -eq 0 ]]; then
    cat <<EOF
- Model routing looks healthy for current loop jobs.
EOF
  fi
} > "$OUT_FILE"

echo "[model-health] wrote $OUT_FILE"
