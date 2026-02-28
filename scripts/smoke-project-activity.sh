#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/cgsd-project-activity.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

OPENCLAW_DIR="$TMP_DIR/.openclaw"
SKILL_DIR="$TMP_DIR/skills"
PLUGIN_PATH="$OPENCLAW_DIR/extensions/gsd-command-aliases"
CONFIG_PATH="$OPENCLAW_DIR/openclaw.json"
PROJECT_ROOT="$TMP_DIR/project"
BIN_DIR="$TMP_DIR/bin"
STATE_FILE="$TMP_DIR/cron-state.json"
REGISTRY_PATH="$OPENCLAW_DIR/cgsd-project-activity.json"

mkdir -p "$OPENCLAW_DIR" "$SKILL_DIR" "$PROJECT_ROOT/.openclaw" "$BIN_DIR"

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

cat > "$STATE_FILE" <<'JSON'
{
  "jobs": [],
  "nextId": 1
}
JSON

cat > "$BIN_DIR/openclaw" <<EOF
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$STATE_FILE"

python_cmd() {
  python3 - "\$@"
}

if [[ "\${1:-}" == "gateway" && "\${2:-}" == "health" ]]; then
  exit 0
fi
if [[ "\${1:-}" == "gateway" && "\${2:-}" == "restart" ]]; then
  exit 0
fi
if [[ "\${1:-}" == "plugins" && "\${2:-}" == "list" ]]; then
  printf '{"plugins":[{"id":"gsd-command-aliases"}]}\n'
  exit 0
fi
if [[ "\${1:-}" == "directory" && "\${2:-}" == "groups" && "\${3:-}" == "list" ]]; then
  printf '{"groups":[]}\n'
  exit 0
fi

if [[ "\${1:-}" == "cron" && "\${2:-}" == "list" ]]; then
  python_cmd <<'PY'
import json
import pathlib

state = json.loads(pathlib.Path("$STATE_FILE").read_text(encoding="utf-8"))
print(json.dumps({"jobs": state.get("jobs", [])}))
PY
  exit 0
fi

if [[ "\${1:-}" == "cron" && "\${2:-}" == "add" ]]; then
  shift 2
  name=""
  cron=""
  model=""
  while [[ \$# -gt 0 ]]; do
    case "\$1" in
      --name) name="\${2:-}"; shift 2 ;;
      --cron) cron="\${2:-}"; shift 2 ;;
      --model) model="\${2:-}"; shift 2 ;;
      --json|--announce|--best-effort-deliver|--enable|--session) shift ;;
      --tz|--agent|--thinking|--timeout-seconds|--message|--channel|--to) shift 2 ;;
      *) shift ;;
    esac
  done
  python_cmd "\$name" "\$cron" "\$model" <<'PY'
import json
import pathlib
import sys
import time

name, cron, model = sys.argv[1], sys.argv[2], sys.argv[3]
path = pathlib.Path("$STATE_FILE")
state = json.loads(path.read_text(encoding="utf-8"))
next_id = int(state.get("nextId", 1))
job_id = f"job-{next_id}"
job = {
    "id": job_id,
    "name": name,
    "enabled": True,
    "createdAtMs": int(time.time() * 1000),
    "schedule": {"expr": cron},
    "payload": {"model": model},
    "state": {"lastStatus": "ok"},
}
jobs = list(state.get("jobs", []))
jobs.append(job)
state["jobs"] = jobs
state["nextId"] = next_id + 1
path.write_text(json.dumps(state), encoding="utf-8")
print(json.dumps({"id": job_id}))
PY
  exit 0
fi

if [[ "\${1:-}" == "cron" && "\${2:-}" == "edit" ]]; then
  job_id="\${3:-}"
  shift 3
  cron=""
  name=""
  model=""
  enable_set=0
  while [[ \$# -gt 0 ]]; do
    case "\$1" in
      --cron) cron="\${2:-}"; shift 2 ;;
      --name) name="\${2:-}"; shift 2 ;;
      --model) model="\${2:-}"; shift 2 ;;
      --enable) enable_set=1; shift ;;
      --announce|--best-effort-deliver|--json|--session) shift ;;
      --tz|--agent|--thinking|--timeout-seconds|--message|--channel|--to) shift 2 ;;
      *) shift ;;
    esac
  done
  python_cmd "\$job_id" "\$name" "\$cron" "\$model" "\$enable_set" <<'PY'
import json
import pathlib
import sys

job_id, name, cron, model, enable_set = sys.argv[1:6]
path = pathlib.Path("$STATE_FILE")
state = json.loads(path.read_text(encoding="utf-8"))
jobs = state.get("jobs", [])
for job in jobs:
    if str(job.get("id")) != job_id:
        continue
    if name:
        job["name"] = name
    if cron:
        job.setdefault("schedule", {})["expr"] = cron
    if model:
        job.setdefault("payload", {})["model"] = model
    if enable_set == "1":
        job["enabled"] = True
state["jobs"] = jobs
path.write_text(json.dumps(state), encoding="utf-8")
PY
  exit 0
fi

if [[ "\${1:-}" == "cron" && "\${2:-}" == "enable" ]]; then
  job_id="\${3:-}"
  python_cmd "\$job_id" <<'PY'
import json
import pathlib
import sys

job_id = sys.argv[1]
path = pathlib.Path("$STATE_FILE")
state = json.loads(path.read_text(encoding="utf-8"))
for job in state.get("jobs", []):
    if str(job.get("id")) == job_id:
        job["enabled"] = True
path.write_text(json.dumps(state), encoding="utf-8")
PY
  exit 0
fi

if [[ "\${1:-}" == "cron" && "\${2:-}" == "disable" ]]; then
  job_id="\${3:-}"
  python_cmd "\$job_id" <<'PY'
import json
import pathlib
import sys

job_id = sys.argv[1]
path = pathlib.Path("$STATE_FILE")
state = json.loads(path.read_text(encoding="utf-8"))
for job in state.get("jobs", []):
    if str(job.get("id")) == job_id:
        job["enabled"] = False
path.write_text(json.dumps(state), encoding="utf-8")
PY
  exit 0
fi

if [[ "\${1:-}" == "cron" && "\${2:-}" == "rm" ]]; then
  job_id="\${3:-}"
  python_cmd "\$job_id" <<'PY'
import json
import pathlib
import sys

job_id = sys.argv[1]
path = pathlib.Path("$STATE_FILE")
state = json.loads(path.read_text(encoding="utf-8"))
state["jobs"] = [j for j in state.get("jobs", []) if str(j.get("id")) != job_id]
path.write_text(json.dumps(state), encoding="utf-8")
PY
  exit 0
fi

echo "unsupported openclaw command: \$*" >&2
exit 1
EOF
chmod +x "$BIN_DIR/openclaw"

export PATH="$BIN_DIR:$PATH"

run_install() {
  "$ROOT_DIR/install.sh" \
    --profile home \
    --force \
    --openclaw-dir "$OPENCLAW_DIR" \
    --skill-dir "$SKILL_DIR" \
    --plugin-path "$PLUGIN_PATH" \
    --config "$CONFIG_PATH" \
    --project-root "$PROJECT_ROOT" \
    --project-key "badgeid" \
    --loop-channel "discord" \
    --loop-target "1473511020998820002" \
    --discord-forum-target "1473509506515337347" \
    --enable-ralphclaw \
    --enable-autoclaw \
    --enable-ralphclaw-watchdog \
    --enable-loop-kpi \
    --enable-model-health \
    --enable-gsd-bridge \
    --enable-forum-daily-council \
    --enable-forum-weekly-council \
    "$@"
}

echo "[smoke] initial install"
run_install

echo "[smoke] verify registry + config"
python3 - "$REGISTRY_PATH" "$PLUGIN_PATH/config.local.json" <<'PY'
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
local_cfg_path = pathlib.Path(sys.argv[2])

assert registry_path.exists(), f"missing registry: {registry_path}"
assert local_cfg_path.exists(), f"missing plugin config: {local_cfg_path}"

registry = json.loads(registry_path.read_text(encoding="utf-8"))
projects = registry.get("projects", {})
assert "badgeid" in projects, "badgeid project missing in registry"
project = projects["badgeid"]
jobs = project.get("jobs", [])
assert len(jobs) == 8, f"expected 8 jobs, got {len(jobs)}"
assert project.get("currentMode") == "high", "default currentMode should be high"

for job in jobs:
    modes = job.get("modes", {})
    assert "off" in modes and "medium" in modes and "high" in modes, f"modes missing for job {job.get('name')}"

mapping = registry.get("channelProjectMap", {})
assert mapping.get("1473511020998820002") == "badgeid", "delivery target mapping missing"
assert mapping.get("1473509506515337347") == "badgeid", "forum target mapping missing"

cfg = json.loads(local_cfg_path.read_text(encoding="utf-8"))
assert cfg.get("defaultProjectKey") == "badgeid", "defaultProjectKey not written"
assert cfg.get("projectActivityRegistry"), "projectActivityRegistry not written"
PY

echo "[smoke] re-install with changed ralph cron"
run_install --ralphclaw-cron "*/11 * * * *"

echo "[smoke] verify no duplicate jobs + updated registry specs"
python3 - "$STATE_FILE" "$REGISTRY_PATH" <<'PY'
import json
import pathlib
import sys

state = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))

jobs = state.get("jobs", [])
assert len(jobs) == 8, f"expected stable 8 jobs after re-install, got {len(jobs)}"

job_by_name = {j.get("name"): j for j in jobs}
ralph_runtime = job_by_name.get("Kai RalphClaw [badgeid]")
assert ralph_runtime, "runtime ralph job missing"
assert ralph_runtime.get("schedule", {}).get("expr") == "*/11 * * * *", "runtime ralph cron not updated"

project = registry.get("projects", {}).get("badgeid", {})
registry_jobs = {j.get("key"): j for j in project.get("jobs", [])}
ralph_registry = registry_jobs.get("ralphclaw")
assert ralph_registry, "registry ralphclaw entry missing"
modes = ralph_registry.get("modes", {})
assert modes.get("high", {}).get("cron") == "*/11 * * * *", "registry high cron not updated"
assert modes.get("medium", {}).get("cron") == "*/15 * * * *", "registry medium cron unexpected"
PY

echo "[smoke] OK"
