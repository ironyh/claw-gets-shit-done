#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIG_ARGC=$#
PROFILE="home"
MODE="copy"
DRY_RUN=0
FORCE=0
RESTART_GATEWAY=0
INTERACTIVE=0
ENABLE_AUTOLOOP=0
ENABLE_CLAWLOOP=0
ENABLE_AUTOLOOP_WATCHDOG=0
ENABLE_LOOP_KPI=0
ENABLE_FORUM_DAILY_COUNCIL=0
ENABLE_FORUM_WEEKLY_COUNCIL=0
ALLOW_NO_LOOP_DELIVERY=0
DEDUPE_CRON_JOBS=1
DEDUPE_PLUGIN_PATHS=1
OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw}"
WORKSPACE_ROOT=""
SKILL_DIR=""
PLUGIN_PATH=""
CONFIG_PATH=""
PRESET="${PRESET:-generic}"
PROJECT_ROOT_FROM_ENV=0
if [[ -n "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT_FROM_ENV=1
fi
PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
PROJECT_KEY="${PROJECT_KEY:-}"
LOOP_CHANNEL="${LOOP_CHANNEL:-discord}"
LOOP_TARGET="${LOOP_TARGET:-}"
LOOP_AGENT="${LOOP_AGENT:-main}"
LOOP_MODEL="${LOOP_MODEL:-kimi-coding/k2p5}"
LOOP_TZ="${LOOP_TZ:-UTC}"
LOOP_MAX_FILES="${LOOP_MAX_FILES:-12}"
ENABLE_RALPHCLAW_MULTI_AGENT=0
RALPHCLAW_SUBAGENTS_PARALLEL="${RALPHCLAW_SUBAGENTS_PARALLEL:-2}"
AUTOLOOP_CRON="${AUTOLOOP_CRON:-*/15 * * * *}"
AUTOLOOP_THINKING="${AUTOLOOP_THINKING:-high}"
AUTOLOOP_TIMEOUT_SECONDS="${AUTOLOOP_TIMEOUT_SECONDS:-900}"
CLAWLOOP_CRON="${CLAWLOOP_CRON:-0 */3 * * *}"
CLAWLOOP_THINKING="${CLAWLOOP_THINKING:-high}"
CLAWLOOP_TIMEOUT_SECONDS="${CLAWLOOP_TIMEOUT_SECONDS:-1800}"
LOOP_KPI_CRON="${LOOP_KPI_CRON:-0 8 * * 1}"
FORUM_DAILY_CRON="${FORUM_DAILY_CRON:-15 9,17 * * *}"
FORUM_WEEKLY_CRON="${FORUM_WEEKLY_CRON:-0 9 * * 1}"
LOOP_INBOX_FILE="${LOOP_INBOX_FILE:-}"
LOOP_QUEUE_FILE="${LOOP_QUEUE_FILE:-}"
LOOP_KPI_FILE="${LOOP_KPI_FILE:-}"
LOOP_LOCK_FILE="${LOOP_LOCK_FILE:-}"
PROJECT_ROOT_SET=0
PROJECT_KEY_SET=0
PROJECT_ROOT_CONFIRMED="$PROJECT_ROOT_FROM_ENV"
LOOP_TARGET_SET=0
LOOP_TZ_SET=0
LOOP_INBOX_FILE_SET=0
LOOP_QUEUE_FILE_SET=0
LOOP_KPI_FILE_SET=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Install OpenClaw GSD suite (skill + alias plugin).

Options:
  --profile <home|workspace|custom>  Install profile (default: home)
  --mode <copy|symlink>              Install mode (default: copy)
  --interactive                      Guided install with path autodetect + prompts
  --no-interactive                   Disable guided mode even if no options are passed
  --workspace-root <path>            Workspace root (used by workspace profile)
  --openclaw-dir <path>              OpenClaw home dir (default: ~/.openclaw)
  --preset <generic>                 Apply neutral defaults (no project-specific paths)
  --skill-dir <path>                 Explicit skill parent directory
  --plugin-path <path>               Explicit plugin install path (full path incl plugin folder)
  --config <path>                    Explicit openclaw.json path
  --enable-ralphclaw                 Configure RalphClaw cron job
  --enable-autoclaw                  Configure AutoClaw cron job (feature extension)
  --enable-ralphclaw-watchdog        Configure RalphClaw watchdog cron job
  --enable-forum-daily-council       Configure daily forum discussion council
  --enable-forum-weekly-council      Configure weekly forum strategy council
  --project-root <path>              Root scanned by loop workers (default: current dir)
  --project-key <slug>               Stable project key for namespaced loop cron jobs
  --loop-channel <name>              Delivery channel for loop updates (e.g., discord)
  --loop-target <id>                 Delivery target id (channel/thread/user id)
  --discord-text-channel <id>        Shortcut: --loop-channel discord --loop-target <id>
  --discord-forum-thread <id>        Shortcut: --loop-channel discord --loop-target <thread_id>
  --loop-agent <id>                  Agent id for loop jobs (default: main)
  --loop-model <id>                  Model id for loop jobs (default: kimi-coding/k2p5)
  --loop-tz <iana_tz>                Timezone for loop jobs (default: UTC)
  --loop-max-files <n>               Max files changed per loop run (default: 12)
  --ralphclaw-multi-agent            Enable RalphClaw sub-agent orchestration
  --ralphclaw-subagents-parallel <n> Max concurrent RalphClaw sub-agents (default: 2)
  --allow-no-loop-delivery           Allow loop jobs without delivery target
  --enable-loop-kpi                  Configure weekly KPI/report cron job
  --loop-kpi-cron <expr>             Cron expression for KPI report (default: 0 8 * * 1)
  --forum-daily-cron <expr>          Cron expression for daily forum council (default: 15 9,17 * * *)
  --forum-weekly-cron <expr>         Cron expression for weekly forum council (default: 0 9 * * 1)
  --loop-inbox-file <path>           Shared proposal inbox (AutoClaw writes here)
  --loop-queue-file <path>           Shared execution queue (RalphClaw reads here)
  --loop-kpi-file <path>             KPI markdown output path
  --loop-lock-file <path>            Shared lock file to prevent overlapping loop runs
  --no-dedupe-crons                  Do not remove duplicate cron jobs with same name
  --no-dedupe-plugin-paths           Do not prune duplicate plugin paths for same plugin id
  --ralphclaw-cron <expr>            Cron expression for RalphClaw (default: */15 * * * *)
  --autoclaw-cron <expr>             Cron expression for AutoClaw (default: 0 */3 * * *)
  --force                            Replace existing installs (backed up with timestamp)
  --restart-gateway                  Restart gateway after config patch
  --dry-run                          Print planned actions only
  -h, --help                         Show help

Examples:
  ./install.sh --interactive
  ./install.sh --profile home
  ./install.sh --profile workspace --workspace-root /srv/openclaw/workspace
  ./install.sh --profile custom --skill-dir /opt/openclaw/skills --plugin-path /opt/openclaw/plugins/gsd-command-aliases
  ./install.sh --preset generic --project-root /path/to/project --profile home --enable-ralphclaw --enable-autoclaw --enable-loop-kpi --loop-channel discord --loop-target 1234567890
  ./install.sh --project-root /path/to/project --project-key my-project --enable-ralphclaw --discord-forum-thread 123456789012345678
USAGE
}

log() { printf '[install] %s\n' "$*"; }
warn() { printf '[install][warn] %s\n' "$*" >&2; }
fail() { printf '[install][error] %s\n' "$*" >&2; exit 1; }

unique_lines() {
  awk 'NF && !seen[$0]++'
}

emit_parent_dirs() {
  local d="$PWD"
  while :; do
    printf '%s\n' "$d"
    [[ "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
}

detect_openclaw_dir_candidates() {
  {
    [[ -n "${OPENCLAW_DIR:-}" ]] && printf '%s\n' "$OPENCLAW_DIR"
    printf '%s\n' "$HOME/.openclaw"
    printf '%s\n' "$HOME/.config/openclaw"
    while IFS= read -r d; do
      [[ -d "$d/.openclaw" ]] && printf '%s\n' "$d/.openclaw"
      [[ -f "$d/openclaw.json" ]] && printf '%s\n' "$d"
    done < <(emit_parent_dirs)
  } | unique_lines
}

detect_config_candidates() {
  local openclaw_dir="${1:-}"
  {
    [[ -n "${CONFIG_PATH:-}" ]] && printf '%s\n' "$CONFIG_PATH"
    [[ -n "$openclaw_dir" ]] && printf '%s\n' "$openclaw_dir/openclaw.json"
    printf '%s\n' "$HOME/.openclaw/openclaw.json"
    while IFS= read -r d; do
      [[ -f "$d/openclaw.json" ]] && printf '%s\n' "$d/openclaw.json"
      [[ -f "$d/.openclaw/openclaw.json" ]] && printf '%s\n' "$d/.openclaw/openclaw.json"
    done < <(emit_parent_dirs)
  } | unique_lines
}

detect_workspace_candidates() {
  {
    [[ -n "${WORKSPACE_ROOT:-}" ]] && printf '%s\n' "$WORKSPACE_ROOT"
    printf '%s\n' "$PWD"
    printf '%s\n' "$HOME/.openclaw/workspace"
    while IFS= read -r d; do
      if [[ -d "$d/.git" || -d "$d/skills" || -d "$d/plugins" || -f "$d/openclaw.json" || -d "$d/.openclaw" ]]; then
        printf '%s\n' "$d"
      fi
    done < <(emit_parent_dirs)
  } | unique_lines
}

detect_skill_dir_candidates() {
  local workspace_root="${1:-}"
  local openclaw_dir="${2:-}"
  {
    [[ -n "${SKILL_DIR:-}" ]] && printf '%s\n' "$SKILL_DIR"
    [[ -n "${CODEX_HOME:-}" ]] && printf '%s\n' "${CODEX_HOME}/skills"
    printf '%s\n' "$HOME/.codex/skills"
    [[ -n "$workspace_root" ]] && printf '%s\n' "$workspace_root/skills"
    [[ -n "$openclaw_dir" ]] && printf '%s\n' "$openclaw_dir/skills"
    while IFS= read -r d; do
      [[ -d "$d/skills" ]] && printf '%s\n' "$d/skills"
    done < <(emit_parent_dirs)
  } | unique_lines
}

detect_plugin_path_candidates() {
  local workspace_root="${1:-}"
  local openclaw_dir="${2:-}"
  {
    [[ -n "${PLUGIN_PATH:-}" ]] && printf '%s\n' "$PLUGIN_PATH"
    [[ -n "$openclaw_dir" ]] && printf '%s\n' "$openclaw_dir/extensions/gsd-command-aliases"
    [[ -n "$workspace_root" ]] && printf '%s\n' "$workspace_root/plugins/gsd-command-aliases"
    while IFS= read -r d; do
      [[ -d "$d/plugins/gsd-command-aliases" ]] && printf '%s\n' "$d/plugins/gsd-command-aliases"
    done < <(emit_parent_dirs)
  } | unique_lines
}

prompt_choice() {
  local var_name="$1"
  local label="$2"
  local default="$3"
  shift 3
  local -a choices=("$@")
  local i input selected

  printf '\n%s\n' "$label"
  for i in "${!choices[@]}"; do
    printf '  %d) %s%s\n' "$((i + 1))" "${choices[$i]}" "$([[ "${choices[$i]}" == "$default" ]] && printf ' [default]')"
  done
  printf 'Select [default: %s]: ' "$default"
  read -r input

  if [[ -z "$input" ]]; then
    selected="$default"
  elif [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#choices[@]} )); then
    selected="${choices[$((input - 1))]}"
  else
    selected="$input"
  fi

  printf -v "$var_name" '%s' "$selected"
}

prompt_yes_no() {
  local var_name="$1"
  local label="$2"
  local default_num="$3"
  local input normalized result

  if [[ "$default_num" -eq 1 ]]; then
    printf '%s [Y/n]: ' "$label"
  else
    printf '%s [y/N]: ' "$label"
  fi
  read -r input

  normalized="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$normalized" ]]; then
    result="$default_num"
  elif [[ "$normalized" == "y" || "$normalized" == "yes" ]]; then
    result=1
  else
    result=0
  fi

  printf -v "$var_name" '%s' "$result"
}

prompt_value() {
  local var_name="$1"
  local label="$2"
  local default="$3"
  local input

  printf '%s [default: %s]: ' "$label" "$default"
  read -r input
  if [[ -z "$input" ]]; then
    input="$default"
  fi
  printf -v "$var_name" '%s' "$input"
}

prompt_path_choice() {
  local var_name="$1"
  local label="$2"
  local default="$3"
  shift 3
  local -a raw_candidates=("$@")
  local -a options=()
  local candidate exists_tag input selected i

  if [[ -n "$default" ]]; then
    options+=("$default")
  fi

  for candidate in "${raw_candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    local duplicate=0
    for selected in "${options[@]}"; do
      if [[ "$selected" == "$candidate" ]]; then
        duplicate=1
        break
      fi
    done
    [[ "$duplicate" -eq 1 ]] && continue
    options+=("$candidate")
  done

  printf '\n%s\n' "$label"
  for i in "${!options[@]}"; do
    if [[ -e "${options[$i]}" || -L "${options[$i]}" ]]; then
      exists_tag="exists"
    else
      exists_tag="new"
    fi
    printf '  %d) %s [%s]%s\n' \
      "$((i + 1))" \
      "${options[$i]}" \
      "$exists_tag" \
      "$([[ "${options[$i]}" == "$default" ]] && printf ' [default]')"
  done
  printf '  m) Manual path\n'
  printf 'Select number / m / path [default: %s]: ' "$default"
  read -r input

  if [[ -z "$input" ]]; then
    selected="$default"
  elif [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#options[@]} )); then
    selected="${options[$((input - 1))]}"
  elif [[ "$input" == "m" || "$input" == "M" ]]; then
    printf 'Enter path [default: %s]: ' "$default"
    read -r selected
    [[ -z "$selected" ]] && selected="$default"
  else
    selected="$input"
  fi

  printf -v "$var_name" '%s' "$selected"
}

detect_local_tz() {
  local tz=""
  if command -v timedatectl >/dev/null 2>&1; then
    tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  fi
  if [[ -z "$tz" && -f /etc/timezone ]]; then
    tz="$(tr -d '\n' </etc/timezone 2>/dev/null || true)"
  fi
  if [[ -z "$tz" ]]; then
    tz="UTC"
  fi
  printf '%s' "$tz"
}

derive_project_key() {
  local raw="${1:-}"
  local normalized=""

  if [[ -z "$raw" ]]; then
    raw="$(basename "${PROJECT_ROOT:-project}")"
  fi

  normalized="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$normalized" ]]; then
    normalized="project"
  fi
  printf '%s' "$normalized"
}

resolve_loop_project_identity() {
  PROJECT_KEY="$(derive_project_key "${PROJECT_KEY:-}")"
  if [[ -z "$LOOP_LOCK_FILE" ]]; then
    LOOP_LOCK_FILE="$PROJECT_ROOT/.openclaw/locks/loop-worker.lock"
  fi
}

resolve_default_loop_files() {
  if [[ -z "$LOOP_INBOX_FILE" ]]; then
    LOOP_INBOX_FILE="$PROJECT_ROOT/.openclaw/LOOP-INBOX.md"
  fi
  if [[ -z "$LOOP_QUEUE_FILE" ]]; then
    LOOP_QUEUE_FILE="$PROJECT_ROOT/.openclaw/LOOP-QUEUE.md"
  fi
  if [[ -z "$LOOP_KPI_FILE" ]]; then
    LOOP_KPI_FILE="$PROJECT_ROOT/.openclaw/LOOP-KPI-WEEKLY.md"
  fi
}

validate_loop_project_scope() {
  local loops_enabled=0
  if [[ "$ENABLE_AUTOLOOP" -eq 1 || "$ENABLE_CLAWLOOP" -eq 1 || "$ENABLE_AUTOLOOP_WATCHDOG" -eq 1 || "$ENABLE_LOOP_KPI" -eq 1 || "$ENABLE_FORUM_DAILY_COUNCIL" -eq 1 || "$ENABLE_FORUM_WEEKLY_COUNCIL" -eq 1 ]]; then
    loops_enabled=1
  fi
  [[ "$loops_enabled" -eq 1 ]] || return 0

  if [[ "$PROJECT_ROOT_CONFIRMED" -ne 1 ]]; then
    fail "Loop workers require explicit project scope. Set --project-root <path>."
  fi
  [[ -n "$PROJECT_ROOT" ]] || fail "Loop workers require --project-root."
  [[ -d "$PROJECT_ROOT" ]] || fail "Project root does not exist: $PROJECT_ROOT"
  PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
}

ensure_loop_handoff_files() {
  resolve_loop_project_identity
  resolve_default_loop_files
  ensure_parent "$LOOP_INBOX_FILE"
  ensure_parent "$LOOP_QUEUE_FILE"
  ensure_parent "$LOOP_KPI_FILE"
  ensure_parent "$LOOP_LOCK_FILE"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_cmd touch "$LOOP_INBOX_FILE"
    print_cmd touch "$LOOP_QUEUE_FILE"
    print_cmd touch "$LOOP_KPI_FILE"
    print_cmd touch "$LOOP_LOCK_FILE"
    return 0
  fi

  if [[ ! -f "$LOOP_INBOX_FILE" ]]; then
    cat > "$LOOP_INBOX_FILE" <<EOF
# LOOP-INBOX

AutoClaw proposal inbox.

Template:
- id: AUTOCLAW-YYYYMMDD-HHMM
- title:
- type: feature|quality|research|tech-debt
- impact: high|medium|low
- effort: s|m|l
- acceptance:
  - [ ] criterion 1
- next_step:
- owner: ralphclaw
- status: ready
EOF
  fi

  if [[ ! -f "$LOOP_QUEUE_FILE" ]]; then
    cat > "$LOOP_QUEUE_FILE" <<EOF
# LOOP-QUEUE

RalphClaw execution queue.

Template:
- id:
- title:
- source: LOOP-INBOX
- priority: P0|P1|P2
- status: ready|in_progress|blocked|done
- owner: ralphclaw
- blocker:
- unblock_next_step:
EOF
  fi

  if [[ ! -f "$LOOP_KPI_FILE" ]]; then
    cat > "$LOOP_KPI_FILE" <<EOF
# LOOP KPI WEEKLY

Generated by scripts/loop-kpi-report.sh
EOF
  fi

  if [[ ! -f "$LOOP_LOCK_FILE" ]]; then
    : > "$LOOP_LOCK_FILE"
  fi
}

apply_preset_defaults() {
  case "$PRESET" in
    ""|generic)
      ;;
    *)
      fail "Invalid preset: $PRESET (supported: generic)"
      ;;
  esac
}

validate_loop_delivery() {
  local loops_enabled=0
  if [[ "$ENABLE_AUTOLOOP" -eq 1 || "$ENABLE_CLAWLOOP" -eq 1 || "$ENABLE_AUTOLOOP_WATCHDOG" -eq 1 || "$ENABLE_LOOP_KPI" -eq 1 || "$ENABLE_FORUM_DAILY_COUNCIL" -eq 1 || "$ENABLE_FORUM_WEEKLY_COUNCIL" -eq 1 ]]; then
    loops_enabled=1
  fi
  [[ "$loops_enabled" -eq 1 ]] || return 0

  if [[ -n "$LOOP_TARGET" && -z "$LOOP_CHANNEL" ]]; then
    fail "Loop delivery target set without channel. Provide --loop-channel or clear --loop-target."
  fi

  if [[ -n "$LOOP_CHANNEL" && -z "$LOOP_TARGET" && "$ALLOW_NO_LOOP_DELIVERY" -eq 0 ]]; then
    fail "Loop delivery target missing. Set --loop-target or use --allow-no-loop-delivery."
  fi
}

print_cmd() {
  printf '[dry-run]'
  while [[ $# -gt 0 ]]; do
    printf ' %q' "$1"
    shift
  done
  printf '\n'
}

fetch_cron_jobs_json() {
  local out="" attempt=1
  while [[ "$attempt" -le 3 ]]; do
    out="$(openclaw cron list --all --json 2>/dev/null || true)"
    if [[ -n "$out" ]] && printf '%s' "$out" | python3 -c '
import json, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if isinstance(payload, dict) and isinstance(payload.get("jobs"), list) else 1)
' >/dev/null 2>&1; then
      printf '%s' "$out"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  return 1
}

resolve_cron_ids_by_name() {
  local job_name="$1"
  local jobs_json=""
  jobs_json="$(fetch_cron_jobs_json || true)"
  [[ -n "$jobs_json" ]] || return 1

  printf '%s' "$jobs_json" | python3 -c '
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
jobs = data.get("jobs", [])
same = [j for j in jobs if j.get("name") == name and j.get("id")]
if same:
    same.sort(key=lambda j: j.get("createdAtMs", 0))
    for job in same:
        print(job["id"])
    raise SystemExit(0)
raise SystemExit(1)
' "$job_name"
}

upsert_loop_cron_job() {
  local job_name="$1"
  local cron_expr="$2"
  local job_message="$3"
  local thinking="$4"
  local timeout_seconds="$5"

  if ! command -v openclaw >/dev/null 2>&1; then
    warn "openclaw CLI not found; skipping loop setup: $job_name"
    return 0
  fi

  local -a base_args=(
    --name "$job_name"
    --cron "$cron_expr"
    --tz "$LOOP_TZ"
    --agent "$LOOP_AGENT"
    --session isolated
    --model "$LOOP_MODEL"
    --thinking "$thinking"
    --timeout-seconds "$timeout_seconds"
    --message "$job_message"
  )
  local -a delivery_args=()
  if [[ -n "$LOOP_CHANNEL" && -n "$LOOP_TARGET" ]]; then
    delivery_args=(--announce --channel "$LOOP_CHANNEL" --to "$LOOP_TARGET" --best-effort-deliver)
  else
    warn "Loop delivery not configured; cron will run without announcements."
  fi

  local existing_id=""
  local -a existing_ids=()
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mapfile -t existing_ids < <(resolve_cron_ids_by_name "$job_name" || true)
    if [[ "${#existing_ids[@]}" -gt 0 ]]; then
      existing_id="${existing_ids[0]}"
    fi
    if [[ "${#existing_ids[@]}" -gt 1 && "$DEDUPE_CRON_JOBS" -eq 1 ]]; then
      local dup_id
      for dup_id in "${existing_ids[@]:1}"; do
        log "Removing duplicate cron for '$job_name': $dup_id"
        openclaw cron disable "$dup_id" >/dev/null 2>&1 || true
        openclaw cron rm "$dup_id" >/dev/null 2>&1 || true
      done
    fi
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_cmd openclaw cron upsert "(simulated)" "${base_args[@]}" "${delivery_args[@]}"
    if [[ "$DEDUPE_CRON_JOBS" -eq 1 ]]; then
      print_cmd "# duplicate cron cleanup enabled for job: $job_name"
    fi
    return 0
  fi

  if [[ -n "$existing_id" ]]; then
    log "Updating loop cron: $job_name ($existing_id)"
    openclaw cron edit "$existing_id" "${base_args[@]}" "${delivery_args[@]}"
  else
    log "Creating loop cron: $job_name"
    openclaw cron add "${base_args[@]}" "${delivery_args[@]}" --json >/dev/null
  fi
}

build_ralphclaw_message() {
  local multi_agent_block=""
  if [[ "$ENABLE_RALPHCLAW_MULTI_AGENT" -eq 1 ]]; then
    multi_agent_block="$(cat <<EOF

Multi-sub-agent mode (enabled):
- Max concurrent sub-agents: $RALPHCLAW_SUBAGENTS_PARALLEL
- Use sub-agents only when task complexity justifies delegation.
- Split work into independent sub-tasks and run at most $RALPHCLAW_SUBAGENTS_PARALLEL simultaneously.
- Recommended role mix: programmer, QA, designer (when UI), analyst (when metrics/data needed).
- Integrate all outputs in main RalphClaw session, run verification, then write one consolidated status update.
- If a sub-agent fails or times out, continue with remaining sub-agents and complete with best reversible next step.
EOF
)"
  fi

  cat <<EOF
RALPHCLAW MODE (cross-project autonomous execution)

Workspace root:
- $PROJECT_ROOT
Project key:
- $PROJECT_KEY
Queue files:
- Inbox: $LOOP_INBOX_FILE
- Execution queue: $LOOP_QUEUE_FILE
Worker lock file:
- $LOOP_LOCK_FILE

Mission:
Ship one meaningful, reversible step per run across active projects.

Run protocol:
1) Acquire non-blocking lock on $LOOP_LOCK_FILE before any work.
   - If lock is already held: report "SKIP_LOCK_HELD" and exit quickly.
2) Read $LOOP_QUEUE_FILE first, then $LOOP_INBOX_FILE, then project context docs.
3) Pick ONE highest-impact unblocked task.
4) Execute one atomic step (8-20 min).
5) Run relevant verification (tests/lint/build/smoke).
6) Write result + next step to memory and queue docs.
7) Report concise summary with changed files and verification.

If blocked:
- Document exact blocker + unblock action in $LOOP_QUEUE_FILE:
  - status: blocked
  - owner: ralphclaw
  - blocker:
  - unblock_next_step:
- Continue with next reversible candidate in same run.

If no queued tasks:
- Improve test coverage, reliability, docs/runbooks, or monitoring.
- Deliver one concrete artifact every run.

Safety rails:
- Max changed files this run: $LOOP_MAX_FILES
- If scope exceeds limit, split and queue the remainder.
- No deploy commands unless task explicitly requests deploy and verification is green.
$multi_agent_block
EOF
}

build_autoclaw_message() {
  cat <<EOF
AUTOCLAW MODE (autonomous feature extension)

Primary project root:
- $PROJECT_ROOT
Project key:
- $PROJECT_KEY
Handoff files:
- Proposal inbox: $LOOP_INBOX_FILE
- Execution queue: $LOOP_QUEUE_FILE
Worker lock file:
- $LOOP_LOCK_FILE

Mission:
Continuously extend product value using GSD-style execution.

Run protocol:
1) Acquire non-blocking lock on $LOOP_LOCK_FILE before any work.
   - If lock is already held: report "SKIP_LOCK_HELD" and exit quickly.
2) Scan roadmap/backlog/docs (ROADMAP, TODO, IDEAS, issues, TODO/FIXME).
3) Select ONE feature extension or quality enhancement with highest impact.
4) Define acceptance criteria and smallest next increment.
5) Append proposal to $LOOP_INBOX_FILE using this contract:
   - id: AUTOCLAW-YYYYMMDD-HHMM
   - title:
   - type: feature|quality|research|tech-debt
   - impact: high|medium|low
   - effort: s|m|l
   - acceptance: checklist
   - next_step:
   - owner: ralphclaw
   - status: ready
6) Promote highest-impact ready item into $LOOP_QUEUE_FILE with priority (P0/P1/P2).
7) Implement one bounded increment end-to-end.
8) Run verification and document outcome + next increment.

Rules:
- Prefer reversible changes.
- Avoid destructive operations.
- Max changed files this run: $LOOP_MAX_FILES
- If proposal cannot be implemented now, still ship structured handoff entry.
- Execute -> report (no permission-seeking unless irreversible).
EOF
}

build_loop_kpi_message() {
  cat <<EOF
WEEKLY LOOP KPI REPORT

Project key: $PROJECT_KEY

Run deterministic report script:
bash $BUNDLE_DIR/scripts/loop-kpi-report.sh \
  --project-root "$PROJECT_ROOT" \
  --days 7 \
  --inbox "$LOOP_INBOX_FILE" \
  --queue "$LOOP_QUEUE_FILE" \
  --out "$LOOP_KPI_FILE"

Then post concise summary:
- completed items
- blocked items
- test/qa signal
- top 3 next priorities
EOF
}

build_forum_daily_council_message() {
  cat <<EOF
FORUM FLOW V2 - DAILY COUNCIL

Project root:
- $PROJECT_ROOT
Project key:
- $PROJECT_KEY
Queue files:
- Inbox: $LOOP_INBOX_FILE
- Queue: $LOOP_QUEUE_FILE

Mission:
Turn forum discussions into clear daily decisions with minimal noise.

Protocol:
1) Review active discussion threads and today's new entries.
2) Prioritize user-originated input first:
   - direct user feedback
   - bug reports
   - feature requests
   - friction/pain reports from production usage
   Mark each as: severity + frequency + affected user segment.
3) For each active thread, enforce an intake card:
   - problem
   - user impact
   - acceptance criteria
   - owner
4) Run timeboxed role discussion in up to 3 rounds:
   - Round 1: input (VD, Backend, QA; include UI-UX/SEO-SEM when relevant)
   - Round 2: challenge (role-to-role questions)
   - Round 3: converge (final recommendation)
   User input must be explicitly addressed in this discussion before decision.
5) Role ping guardrails:
   - roles may request input from another role with:
     needs_input_from:<role> reason:"..."
   - summary required before ping
   - max 2 role-to-role pings per role per thread per daily run
6) Decision gate (required per thread):
   - promote_to_queue | need_more_data | reject
   Include: "user_signal_handled: yes|no" (must be yes for user-originated threads).
7) If decision is promote_to_queue:
   - append/update one queue item in $LOOP_QUEUE_FILE
   - include source thread link/id and acceptance checklist
8) If decision is need_more_data:
   - list exact missing data and owner
   - schedule next review in daily council
9) If thread is stale (>24h without decision):
   - mark stale
   - add escalation note to $LOOP_INBOX_FILE
10) Post concise summary:
   - threads reviewed
   - promoted
   - need_more_data
   - rejected
   - stale/escalated

Rules:
- Keep discussion objective and evidence-driven.
- No decision without explicit acceptance criteria.
- Prefer one promotable, reversible item over broad planning.
EOF
}

build_forum_weekly_council_message() {
  cat <<EOF
FORUM FLOW V2 - WEEKLY COUNCIL

Project root:
- $PROJECT_ROOT
Project key:
- $PROJECT_KEY
Queue files:
- Inbox: $LOOP_INBOX_FILE
- Queue: $LOOP_QUEUE_FILE
- KPI: $LOOP_KPI_FILE

Mission:
Run strategic weekly review across forum discussions and delivery outcomes.

Protocol:
1) Review last 7 days:
   - forum decisions
   - queue throughput
   - blocked items
   - test/quality signals
   - user signal trends (top requests, top pain points, repeated failures)
2) Build weekly consensus summary with roles:
   - VD
   - Backend
   - QA
   - plus UI-UX/SEO-SEM/DevOps/Security when needed
3) Consolidate into:
   - top 3 priorities for next 7 days
   - top 3 risks + mitigation owners
   - top 3 experiments (reversible)
4) Ensure decision statuses are explicit:
   - promote_to_queue | need_more_data | reject
5) Promote only concrete, testable items to $LOOP_QUEUE_FILE.
6) Write weekly planning notes to $LOOP_INBOX_FILE.
7) Post final summary:
   - what changed this week
   - what gets prioritized next week
   - what is intentionally deferred
   - which user signals were accepted, deferred, or rejected (with rationale)

Rules:
- Prefer fewer high-confidence priorities over long lists.
- Every promoted item must include owner + acceptance criteria.
- Keep decisions aligned with measurable outcomes.
EOF
}

configure_autonomous_loops() {
  resolve_loop_project_identity
  local ralphclaw_job_name="Kai RalphClaw [$PROJECT_KEY]"
  local autoclaw_job_name="Kai AutoClaw [$PROJECT_KEY]"
  local watchdog_job_name="Kai RalphClaw Watchdog [$PROJECT_KEY]"
  local kpi_job_name="Kai Loop KPI Weekly [$PROJECT_KEY]"
  local forum_daily_job_name="Kai Forum Council Daily [$PROJECT_KEY]"
  local forum_weekly_job_name="Kai Forum Council Weekly [$PROJECT_KEY]"

  if [[ "$ENABLE_AUTOLOOP" -eq 1 ]]; then
    upsert_loop_cron_job \
      "$ralphclaw_job_name" \
      "$AUTOLOOP_CRON" \
      "$(build_ralphclaw_message)" \
      "$AUTOLOOP_THINKING" \
      "$AUTOLOOP_TIMEOUT_SECONDS"
  fi

  if [[ "$ENABLE_CLAWLOOP" -eq 1 ]]; then
    upsert_loop_cron_job \
      "$autoclaw_job_name" \
      "$CLAWLOOP_CRON" \
      "$(build_autoclaw_message)" \
      "$CLAWLOOP_THINKING" \
      "$CLAWLOOP_TIMEOUT_SECONDS"
  fi

  if [[ "$ENABLE_AUTOLOOP_WATCHDOG" -eq 1 ]]; then
    upsert_loop_cron_job \
      "$watchdog_job_name" \
      "*/20 * * * *" \
      "Run watchdog checks for RalphClaw stalled summaries; rotate session if stale pattern repeats." \
      "low" \
      "300"
  fi

  if [[ "$ENABLE_LOOP_KPI" -eq 1 ]]; then
    upsert_loop_cron_job \
      "$kpi_job_name" \
      "$LOOP_KPI_CRON" \
      "$(build_loop_kpi_message)" \
      "low" \
      "600"
  fi

  if [[ "$ENABLE_FORUM_DAILY_COUNCIL" -eq 1 ]]; then
    upsert_loop_cron_job \
      "$forum_daily_job_name" \
      "$FORUM_DAILY_CRON" \
      "$(build_forum_daily_council_message)" \
      "medium" \
      "1200"
  fi

  if [[ "$ENABLE_FORUM_WEEKLY_COUNCIL" -eq 1 ]]; then
    upsert_loop_cron_job \
      "$forum_weekly_job_name" \
      "$FORUM_WEEKLY_CRON" \
      "$(build_forum_weekly_council_message)" \
      "medium" \
      "1800"
  fi
}

run_interactive_wizard() {
  [[ -t 0 ]] || fail "--interactive requires a TTY"

  log "Interactive installer started"
  log "Autodetecting likely OpenClaw/Codex/workspace paths from current machine"

  if [[ -z "${LOOP_TZ:-}" || "$LOOP_TZ" == "UTC" ]]; then
    LOOP_TZ="$(detect_local_tz)"
  fi

  prompt_choice PRESET "Project preset" "${PRESET:-generic}" "generic"
  apply_preset_defaults

  prompt_choice PROFILE "Install profile" "$PROFILE" "home" "workspace" "custom"
  prompt_choice MODE "Install mode" "$MODE" "copy" "symlink"

  local -a openclaw_candidates config_candidates workspace_candidates skill_candidates plugin_candidates
  mapfile -t openclaw_candidates < <(detect_openclaw_dir_candidates)
  prompt_path_choice OPENCLAW_DIR "OpenClaw home directory" "${OPENCLAW_DIR:-$HOME/.openclaw}" "${openclaw_candidates[@]}"

  mapfile -t config_candidates < <(detect_config_candidates "$OPENCLAW_DIR")
  prompt_path_choice CONFIG_PATH "OpenClaw config path" "${CONFIG_PATH:-$OPENCLAW_DIR/openclaw.json}" "${config_candidates[@]}"

  case "$PROFILE" in
    home)
      mapfile -t skill_candidates < <(detect_skill_dir_candidates "" "$OPENCLAW_DIR")
      prompt_path_choice SKILL_DIR "Skill parent directory" "${SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills}" "${skill_candidates[@]}"

      mapfile -t plugin_candidates < <(detect_plugin_path_candidates "" "$OPENCLAW_DIR")
      prompt_path_choice PLUGIN_PATH "Plugin install path (full gsd-command-aliases path)" "${PLUGIN_PATH:-$OPENCLAW_DIR/extensions/gsd-command-aliases}" "${plugin_candidates[@]}"
      ;;
    workspace)
      mapfile -t workspace_candidates < <(detect_workspace_candidates)
      prompt_path_choice WORKSPACE_ROOT "Workspace root" "${WORKSPACE_ROOT:-$PWD}" "${workspace_candidates[@]}"

      mapfile -t skill_candidates < <(detect_skill_dir_candidates "$WORKSPACE_ROOT" "$OPENCLAW_DIR")
      prompt_path_choice SKILL_DIR "Skill parent directory" "${SKILL_DIR:-$WORKSPACE_ROOT/skills}" "${skill_candidates[@]}"

      mapfile -t plugin_candidates < <(detect_plugin_path_candidates "$WORKSPACE_ROOT" "$OPENCLAW_DIR")
      prompt_path_choice PLUGIN_PATH "Plugin install path (full gsd-command-aliases path)" "${PLUGIN_PATH:-$WORKSPACE_ROOT/plugins/gsd-command-aliases}" "${plugin_candidates[@]}"
      ;;
    custom)
      mapfile -t skill_candidates < <(detect_skill_dir_candidates "$WORKSPACE_ROOT" "$OPENCLAW_DIR")
      prompt_path_choice SKILL_DIR "Skill parent directory" "${SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills}" "${skill_candidates[@]}"

      mapfile -t plugin_candidates < <(detect_plugin_path_candidates "$WORKSPACE_ROOT" "$OPENCLAW_DIR")
      prompt_path_choice PLUGIN_PATH "Plugin install path (full gsd-command-aliases path)" "${PLUGIN_PATH:-$OPENCLAW_DIR/extensions/gsd-command-aliases}" "${plugin_candidates[@]}"
      ;;
    *)
      fail "Invalid profile: $PROFILE"
      ;;
  esac

  prompt_yes_no FORCE "Replace existing install destinations if needed? (--force)" "$FORCE"
  prompt_yes_no RESTART_GATEWAY "Restart OpenClaw gateway after install? (--restart-gateway)" "$RESTART_GATEWAY"
  prompt_yes_no DRY_RUN "Run in dry-run mode? (--dry-run)" "$DRY_RUN"

  local enable_loops=0
  prompt_yes_no enable_loops "Enable autonomous loop workers (RalphClaw/AutoClaw)?" 0
  if [[ "$enable_loops" -eq 1 ]]; then
    local loop_mode="both"
    prompt_choice loop_mode "Loop mode" "both" "ralphclaw" "autoclaw" "both"
    case "$loop_mode" in
      ralphclaw|autoloop)
        ENABLE_AUTOLOOP=1
        ENABLE_CLAWLOOP=0
        ;;
      autoclaw)
        ENABLE_AUTOLOOP=0
        ENABLE_CLAWLOOP=1
        ;;
      both)
        ENABLE_AUTOLOOP=1
        ENABLE_CLAWLOOP=1
        ;;
      *)
        fail "Invalid loop mode: $loop_mode"
        ;;
    esac

    mapfile -t workspace_candidates < <(detect_workspace_candidates)
    prompt_path_choice PROJECT_ROOT "Loop project/workspace root" "${PROJECT_ROOT:-${WORKSPACE_ROOT:-$PWD}}" "${workspace_candidates[@]}"
    PROJECT_ROOT_CONFIRMED=1
    resolve_loop_project_identity
    prompt_value PROJECT_KEY "Loop project key (for namespaced cron job names)" "$PROJECT_KEY"
    PROJECT_KEY_SET=1
    resolve_loop_project_identity
    resolve_default_loop_files
    prompt_value LOOP_INBOX_FILE "Loop inbox file (AutoClaw proposals)" "$LOOP_INBOX_FILE"
    prompt_value LOOP_QUEUE_FILE "Loop queue file (RalphClaw execution)" "$LOOP_QUEUE_FILE"
    prompt_value LOOP_KPI_FILE "Loop KPI output file" "$LOOP_KPI_FILE"
    prompt_value LOOP_LOCK_FILE "Loop worker lock file (prevents overlapping runs)" "$LOOP_LOCK_FILE"
    prompt_value LOOP_MODEL "Loop model id" "$LOOP_MODEL"
    prompt_value LOOP_AGENT "Loop agent id" "$LOOP_AGENT"
    prompt_value LOOP_TZ "Loop timezone (IANA, e.g. Europe/Stockholm)" "$LOOP_TZ"
    prompt_value LOOP_MAX_FILES "Max files changed per run" "$LOOP_MAX_FILES"
    if [[ "$ENABLE_AUTOLOOP" -eq 1 ]]; then
      prompt_yes_no ENABLE_RALPHCLAW_MULTI_AGENT "Enable RalphClaw multi-sub-agent mode?" "$ENABLE_RALPHCLAW_MULTI_AGENT"
      if [[ "$ENABLE_RALPHCLAW_MULTI_AGENT" -eq 1 ]]; then
        prompt_value RALPHCLAW_SUBAGENTS_PARALLEL "Max concurrent RalphClaw sub-agents" "$RALPHCLAW_SUBAGENTS_PARALLEL"
      fi
    fi
    prompt_value LOOP_CHANNEL "Loop delivery channel (blank for no announcements)" "$LOOP_CHANNEL"
    if [[ -n "$LOOP_CHANNEL" ]]; then
      if [[ "$LOOP_CHANNEL" == "discord" ]]; then
        local discord_target_mode="text-channel"
        prompt_choice discord_target_mode "Discord target type" "$discord_target_mode" "text-channel" "forum-thread"
        if [[ "$discord_target_mode" == "forum-thread" ]]; then
          prompt_value LOOP_TARGET "Discord forum thread id" "${LOOP_TARGET:-}"
        else
          prompt_value LOOP_TARGET "Discord text channel id" "${LOOP_TARGET:-}"
        fi
      else
        prompt_value LOOP_TARGET "Loop delivery target id" "${LOOP_TARGET:-}"
      fi
      if [[ -z "$LOOP_TARGET" ]]; then
        prompt_yes_no ALLOW_NO_LOOP_DELIVERY "No delivery target set. Continue without announcements?" 0
      fi
    else
      ALLOW_NO_LOOP_DELIVERY=1
    fi
    if [[ "$ENABLE_AUTOLOOP" -eq 1 ]]; then
      prompt_value AUTOLOOP_CRON "RalphClaw schedule (cron expr)" "$AUTOLOOP_CRON"
      prompt_yes_no ENABLE_AUTOLOOP_WATCHDOG "Enable RalphClaw watchdog?" 1
    fi
    if [[ "$ENABLE_CLAWLOOP" -eq 1 ]]; then
      prompt_value CLAWLOOP_CRON "AutoClaw schedule (cron expr)" "$CLAWLOOP_CRON"
    fi
    prompt_yes_no ENABLE_LOOP_KPI "Enable weekly loop KPI report job?" "$ENABLE_LOOP_KPI"
    if [[ "$ENABLE_LOOP_KPI" -eq 1 ]]; then
      prompt_value LOOP_KPI_CRON "Weekly KPI cron expression" "$LOOP_KPI_CRON"
    fi
    prompt_yes_no ENABLE_FORUM_DAILY_COUNCIL "Enable daily forum council?" "$ENABLE_FORUM_DAILY_COUNCIL"
    if [[ "$ENABLE_FORUM_DAILY_COUNCIL" -eq 1 ]]; then
      prompt_value FORUM_DAILY_CRON "Daily forum council cron expression" "$FORUM_DAILY_CRON"
    fi
    prompt_yes_no ENABLE_FORUM_WEEKLY_COUNCIL "Enable weekly forum council?" "$ENABLE_FORUM_WEEKLY_COUNCIL"
    if [[ "$ENABLE_FORUM_WEEKLY_COUNCIL" -eq 1 ]]; then
      prompt_value FORUM_WEEKLY_CRON "Weekly forum council cron expression" "$FORUM_WEEKLY_CRON"
    fi
  fi

  cat <<SUMMARY

[install] Interactive summary
  preset: $PRESET
  profile: $PROFILE
  mode: $MODE
  openclaw dir: $OPENCLAW_DIR
  config: ${CONFIG_PATH:-$OPENCLAW_DIR/openclaw.json}
  skill dir: $SKILL_DIR
  plugin path: $PLUGIN_PATH
  force: $FORCE
  restart gateway: $RESTART_GATEWAY
  dry-run: $DRY_RUN
  enable ralphclaw: $ENABLE_AUTOLOOP
  enable autoclaw: $ENABLE_CLAWLOOP
  enable ralphclaw watchdog: $ENABLE_AUTOLOOP_WATCHDOG
  loop project root: $PROJECT_ROOT
  loop project key: $PROJECT_KEY
  loop channel: ${LOOP_CHANNEL:-<none>}
  loop target: ${LOOP_TARGET:-<none>}
  loop lock file: ${LOOP_LOCK_FILE:-<auto>}
  allow no loop delivery: $ALLOW_NO_LOOP_DELIVERY
  loop max files: $LOOP_MAX_FILES
  ralphclaw multi-agent: $ENABLE_RALPHCLAW_MULTI_AGENT
  ralphclaw subagents parallel: $RALPHCLAW_SUBAGENTS_PARALLEL
  enable loop kpi: $ENABLE_LOOP_KPI
  loop kpi cron: $LOOP_KPI_CRON
  enable forum daily council: $ENABLE_FORUM_DAILY_COUNCIL
  forum daily cron: $FORUM_DAILY_CRON
  enable forum weekly council: $ENABLE_FORUM_WEEKLY_COUNCIL
  forum weekly cron: $FORUM_WEEKLY_CRON
  loop inbox file: ${LOOP_INBOX_FILE:-<auto>}
  loop queue file: ${LOOP_QUEUE_FILE:-<auto>}
  loop kpi file: ${LOOP_KPI_FILE:-<auto>}
SUMMARY

  local proceed=1
  prompt_yes_no proceed "Proceed with this installation?" 1
  [[ "$proceed" -eq 1 ]] || fail "Installation cancelled by user"
}

backup_path() {
  local target="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  printf '%s.bak.%s' "$target" "$ts"
}

run_or_echo() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_cmd "$@"
  else
    "$@"
  fi
}

ensure_parent() {
  local p="$1"
  run_or_echo mkdir -p "$(dirname "$p")"
}

install_tree() {
  local src="$1"
  local dest="$2"

  [[ -d "$src" ]] || fail "Source missing: $src"
  ensure_parent "$dest"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      local backup
      backup="$(backup_path "$dest")"
      log "Backing up existing path: $dest -> $backup"
      run_or_echo mv "$dest" "$backup"
    else
      fail "Destination exists: $dest (use --force to replace)"
    fi
  fi

  if [[ "$MODE" == "symlink" ]]; then
    log "Symlink install: $dest -> $src"
    run_or_echo ln -s "$src" "$dest"
    return 0
  fi

  log "Copy install: $src -> $dest"
  run_or_echo mkdir -p "$dest"
  run_or_echo rsync -a --delete "$src/" "$dest/"
}

patch_openclaw_config() {
  local cfg="$1"
  local plugin_path="$2"
  local plugin_dir_name=""
  plugin_dir_name="$(basename "$plugin_path")"

  if [[ ! -f "$cfg" ]]; then
    warn "Config not found, skipping auto patch: $cfg"
    return 0
  fi

  command -v jq >/dev/null 2>&1 || {
    warn "jq not found, skipping config patch"
    return 0
  }

  local backup tmp
  backup="$(backup_path "$cfg")"
  tmp="${cfg}.tmp"

  log "Backing up config: $cfg -> $backup"
  run_or_echo cp "$cfg" "$backup"

  local installed_at
  installed_at="$(date -Iseconds)"

  log "Patching OpenClaw config with plugin path and enabled entry"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] jq patch on %s\n' "$cfg"
    return 0
  fi

  jq \
    --arg plugin_path "$plugin_path" \
    --arg plugin_dir_name "$plugin_dir_name" \
    --argjson dedupe_plugin_paths "$DEDUPE_PLUGIN_PATHS" \
    --arg installed_at "$installed_at" \
    '
      .plugins = (.plugins // {}) |
      .plugins.load = (.plugins.load // {}) |
      .plugins.load.paths = (
        (.plugins.load.paths // [])
        | if $dedupe_plugin_paths == 1 then
            map(
              select(
                . == $plugin_path
                or (
                  . != $plugin_path
                  and ((endswith("/" + $plugin_dir_name) or endswith("\\" + $plugin_dir_name)) | not)
                )
              )
            )
          else .
          end
        | . + [$plugin_path]
        | unique
      ) |
      .plugins.entries = (.plugins.entries // {}) |
      .plugins.entries["gsd-command-aliases"] = ((.plugins.entries["gsd-command-aliases"] // {}) + {enabled: true}) |
      .plugins.installs = (.plugins.installs // {}) |
      .plugins.installs["gsd-command-aliases"] = {
        source: "path",
        sourcePath: $plugin_path,
        installPath: $plugin_path,
        installedAt: $installed_at
      }
    ' "$cfg" > "$tmp"

  mv "$tmp" "$cfg"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --interactive) INTERACTIVE=1; shift ;;
    --no-interactive) INTERACTIVE=0; shift ;;
    --workspace-root) WORKSPACE_ROOT="${2:-}"; shift 2 ;;
    --openclaw-dir) OPENCLAW_DIR="${2:-}"; shift 2 ;;
    --preset) PRESET="${2:-}"; shift 2 ;;
    --skill-dir) SKILL_DIR="${2:-}"; shift 2 ;;
    --plugin-path) PLUGIN_PATH="${2:-}"; shift 2 ;;
    --config) CONFIG_PATH="${2:-}"; shift 2 ;;
    --enable-ralphclaw) ENABLE_AUTOLOOP=1; shift ;;
    --enable-autoclaw) ENABLE_CLAWLOOP=1; shift ;;
    --enable-ralphclaw-watchdog) ENABLE_AUTOLOOP_WATCHDOG=1; shift ;;
    --enable-forum-daily-council) ENABLE_FORUM_DAILY_COUNCIL=1; shift ;;
    --enable-forum-weekly-council) ENABLE_FORUM_WEEKLY_COUNCIL=1; shift ;;
    --project-root) PROJECT_ROOT="${2:-}"; PROJECT_ROOT_SET=1; PROJECT_ROOT_CONFIRMED=1; shift 2 ;;
    --project-key) PROJECT_KEY="${2:-}"; PROJECT_KEY_SET=1; shift 2 ;;
    --loop-channel) LOOP_CHANNEL="${2:-}"; shift 2 ;;
    --loop-target) LOOP_TARGET="${2:-}"; LOOP_TARGET_SET=1; shift 2 ;;
    --discord-text-channel) LOOP_CHANNEL="discord"; LOOP_TARGET="${2:-}"; LOOP_TARGET_SET=1; shift 2 ;;
    --discord-forum-thread) LOOP_CHANNEL="discord"; LOOP_TARGET="${2:-}"; LOOP_TARGET_SET=1; shift 2 ;;
    --loop-agent) LOOP_AGENT="${2:-}"; shift 2 ;;
    --loop-model) LOOP_MODEL="${2:-}"; shift 2 ;;
    --loop-tz) LOOP_TZ="${2:-}"; LOOP_TZ_SET=1; shift 2 ;;
    --loop-max-files) LOOP_MAX_FILES="${2:-}"; shift 2 ;;
    --ralphclaw-multi-agent) ENABLE_RALPHCLAW_MULTI_AGENT=1; shift ;;
    --ralphclaw-subagents-parallel) RALPHCLAW_SUBAGENTS_PARALLEL="${2:-}"; shift 2 ;;
    --allow-no-loop-delivery) ALLOW_NO_LOOP_DELIVERY=1; shift ;;
    --enable-loop-kpi) ENABLE_LOOP_KPI=1; shift ;;
    --loop-kpi-cron) LOOP_KPI_CRON="${2:-}"; shift 2 ;;
    --forum-daily-cron) FORUM_DAILY_CRON="${2:-}"; shift 2 ;;
    --forum-weekly-cron) FORUM_WEEKLY_CRON="${2:-}"; shift 2 ;;
    --loop-inbox-file) LOOP_INBOX_FILE="${2:-}"; LOOP_INBOX_FILE_SET=1; shift 2 ;;
    --loop-queue-file) LOOP_QUEUE_FILE="${2:-}"; LOOP_QUEUE_FILE_SET=1; shift 2 ;;
    --loop-kpi-file) LOOP_KPI_FILE="${2:-}"; LOOP_KPI_FILE_SET=1; shift 2 ;;
    --loop-lock-file) LOOP_LOCK_FILE="${2:-}"; shift 2 ;;
    --no-dedupe-crons) DEDUPE_CRON_JOBS=0; shift ;;
    --no-dedupe-plugin-paths) DEDUPE_PLUGIN_PATHS=0; shift ;;
    --ralphclaw-cron) AUTOLOOP_CRON="${2:-}"; shift 2 ;;
    --autoclaw-cron) CLAWLOOP_CRON="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --restart-gateway) RESTART_GATEWAY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

apply_preset_defaults

if [[ "$INTERACTIVE" -eq 0 && "$ORIG_ARGC" -eq 0 && -t 0 ]]; then
  local_start_interactive=1
  prompt_yes_no local_start_interactive "No options provided. Start guided install?" 1
  if [[ "$local_start_interactive" -eq 1 ]]; then
    INTERACTIVE=1
  fi
fi

if [[ "$INTERACTIVE" -eq 1 ]]; then
  run_interactive_wizard
fi

if [[ "${LOOP_TZ:-UTC}" == "UTC" ]]; then
  LOOP_TZ="$(detect_local_tz)"
fi

case "$PROFILE" in
  home)
    SKILL_DIR="${SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills}"
    PLUGIN_PATH="${PLUGIN_PATH:-$OPENCLAW_DIR/extensions/gsd-command-aliases}"
    ;;
  workspace)
    WORKSPACE_ROOT="${WORKSPACE_ROOT:-$PWD}"
    SKILL_DIR="${SKILL_DIR:-$WORKSPACE_ROOT/skills}"
    PLUGIN_PATH="${PLUGIN_PATH:-$WORKSPACE_ROOT/plugins/gsd-command-aliases}"
    ;;
  custom)
    [[ -n "$SKILL_DIR" ]] || fail "custom profile requires --skill-dir"
    [[ -n "$PLUGIN_PATH" ]] || fail "custom profile requires --plugin-path"
    ;;
  *)
    fail "Invalid profile: $PROFILE"
    ;;
esac

case "$MODE" in
  copy|symlink) ;;
  *) fail "Invalid mode: $MODE" ;;
esac

if [[ "$ENABLE_AUTOLOOP_WATCHDOG" -eq 1 && "$ENABLE_AUTOLOOP" -eq 0 ]]; then
  warn "RalphClaw watchdog enabled without RalphClaw; watchdog will still be created."
fi

if ! [[ "$LOOP_MAX_FILES" =~ ^[0-9]+$ ]] || [[ "$LOOP_MAX_FILES" -lt 1 ]]; then
  fail "--loop-max-files must be a positive integer"
fi

if ! [[ "$RALPHCLAW_SUBAGENTS_PARALLEL" =~ ^[0-9]+$ ]] || [[ "$RALPHCLAW_SUBAGENTS_PARALLEL" -lt 1 ]]; then
  fail "--ralphclaw-subagents-parallel must be a positive integer"
fi

validate_loop_project_scope
resolve_loop_project_identity
resolve_default_loop_files
validate_loop_delivery

CONFIG_PATH="${CONFIG_PATH:-$OPENCLAW_DIR/openclaw.json}"

SKILL_SRC="$BUNDLE_DIR/skills/claw-gets-shit-done"
PLUGIN_SRC="$BUNDLE_DIR/plugins/gsd-command-aliases"
SKILL_DEST="$SKILL_DIR/claw-gets-shit-done"

log "Profile: $PROFILE"
log "Preset: $PRESET"
log "Mode: $MODE"
log "Skill source: $SKILL_SRC"
log "Skill destination: $SKILL_DEST"
log "Plugin source: $PLUGIN_SRC"
log "Plugin destination: $PLUGIN_PATH"
log "Config path: $CONFIG_PATH"
if [[ "$ENABLE_AUTOLOOP" -eq 1 || "$ENABLE_CLAWLOOP" -eq 1 || "$ENABLE_AUTOLOOP_WATCHDOG" -eq 1 || "$ENABLE_LOOP_KPI" -eq 1 || "$ENABLE_FORUM_DAILY_COUNCIL" -eq 1 || "$ENABLE_FORUM_WEEKLY_COUNCIL" -eq 1 ]]; then
  log "Project root: $PROJECT_ROOT"
  log "Project key: $PROJECT_KEY"
  log "Loop inbox: $LOOP_INBOX_FILE"
  log "Loop queue: $LOOP_QUEUE_FILE"
  log "Loop KPI file: $LOOP_KPI_FILE"
  log "Loop lock file: $LOOP_LOCK_FILE"
  log "RalphClaw multi-agent: $ENABLE_RALPHCLAW_MULTI_AGENT"
  log "RalphClaw subagents parallel: $RALPHCLAW_SUBAGENTS_PARALLEL"
fi

install_tree "$SKILL_SRC" "$SKILL_DEST"
install_tree "$PLUGIN_SRC" "$PLUGIN_PATH"
patch_openclaw_config "$CONFIG_PATH" "$PLUGIN_PATH"

if [[ "$RESTART_GATEWAY" -eq 1 ]]; then
  if command -v openclaw >/dev/null 2>&1; then
    log "Restarting OpenClaw gateway"
    run_or_echo openclaw gateway restart
  else
    warn "openclaw CLI not found; restart gateway manually"
  fi
fi

if [[ "$ENABLE_AUTOLOOP" -eq 1 || "$ENABLE_CLAWLOOP" -eq 1 || "$ENABLE_AUTOLOOP_WATCHDOG" -eq 1 || "$ENABLE_LOOP_KPI" -eq 1 || "$ENABLE_FORUM_DAILY_COUNCIL" -eq 1 || "$ENABLE_FORUM_WEEKLY_COUNCIL" -eq 1 ]]; then
  log "Ensuring loop handoff files"
  ensure_loop_handoff_files
  log "Configuring autonomous loop workers"
  configure_autonomous_loops
fi

cat <<NEXT

Install complete.

Next checks:
  ./doctor.sh --openclaw-dir "$OPENCLAW_DIR" --skill-dir "$SKILL_DIR" --plugin-path "$PLUGIN_PATH"

Recommended commands:
  openclaw gateway health
  openclaw plugins list --json | jq '.plugins[] | select(.id=="gsd-command-aliases")'

If your workspace is non-standard, set one of:
  export GSD_WORKSPACE_DIR=/path/to/project
  export GSD_TOOLS_PATH=/path/to/skills/claw-gets-shit-done/bin/gsd-tools

Loop mode (optional):
  --enable-ralphclaw (default: $AUTOLOOP_CRON)
  --enable-autoclaw (default: $CLAWLOOP_CRON)
  --enable-loop-kpi (default: $LOOP_KPI_CRON)
  --enable-forum-daily-council (default cron: $FORUM_DAILY_CRON)
  --enable-forum-weekly-council (default cron: $FORUM_WEEKLY_CRON)
  --project-root <path> (required when loop workers are enabled)
  --project-key <slug> (optional override; derived from project root by default)
  --preset generic
  --loop-max-files $LOOP_MAX_FILES
  --loop-lock-file $LOOP_LOCK_FILE
  --ralphclaw-multi-agent (parallel: $RALPHCLAW_SUBAGENTS_PARALLEL)
  --ralphclaw-subagents-parallel <n>
  --loop-channel/--loop-target for announcements
  --discord-text-channel <id> or --discord-forum-thread <id> as shortcuts
  --allow-no-loop-delivery (if you intentionally run silently)
NEXT
