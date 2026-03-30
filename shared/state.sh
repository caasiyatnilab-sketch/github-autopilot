#!/bin/bash
# ═══════════════════════════════════════════════════════
# Shared State Manager — Bot-to-Bot Communication
# All bots read/write to this shared JSON state
# Enables: cross-bot data sharing, coordination, self-healing
# ═══════════════════════════════════════════════════════

STATE_DIR="${GITHUB_WORKSPACE:-.}/.github"
STATE_FILE="$STATE_DIR/bot-state.json"
LOCK_DIR="/tmp/autopilot-locks"

mkdir -p "$STATE_DIR" "$LOCK_DIR"

# ─── Initialize State ────────────────────────────────────
init_state() {
  if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" << 'EOF'
{
  "version": 1,
  "api_keys": {},
  "active_projects": [],
  "bot_health": {},
  "bot_results": {},
  "shared_data": {},
  "upgrades_needed": [],
  "deployments": [],
  "scraping_targets": [],
  "last_sync": "never",
  "auto_deploy": true,
  "self_evolve": true,
  "evolution_log": []
}
EOF
  fi
}

# ─── Read/Write State (thread-safe) ─────────────────────
_state_lock() {
  local lock_file="$LOCK_DIR/state.lock"
  local max_wait=10
  local waited=0
  while [ -f "$lock_file" ] && [ $waited -lt $max_wait ]; do
    sleep 0.5
    waited=$((waited + 1))
  done
  echo $$ > "$lock_file"
}

_state_unlock() {
  rm -f "$LOCK_DIR/state.lock"
}

# Get a value from state: state_get ".api_keys.groq.status"
state_get() {
  init_state
  local key="$1"
  local default="${2:-}"
  local val
  val=$(jq -r "$key // empty" "$STATE_FILE" 2>/dev/null)
  [ -z "$val" ] || [ "$val" = "null" ] && echo "$default" || echo "$val"
}

# Set a value in state: state_set ".api_keys.groq.status" "active"
state_set() {
  init_state
  _state_lock
  local key="$1"
  local value="$2"
  python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)

keys = '$key'.split('.')
obj = data
for k in keys[:-1]:
    if k.startswith('[') and k.endswith(']'):
        idx = int(k[1:-1])
        obj = obj[idx]
    else:
        obj = obj.setdefault(k, {})

last = keys[-1]
if last.startswith('[') and last.endswith(']'):
    obj[int(last[1:-1])] = '$value'
else:
    try:
        obj[last] = json.loads('$value')
    except:
        obj[last] = '$value'

with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
  _state_unlock
}

# Append to an array in state: state_append ".bot_results.scraper" '{"status":"ok"}'
state_append() {
  init_state
  _state_lock
  local key="$1"
  local value="$2"
  python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)

keys = '$key'.split('.')
obj = data
for k in keys[:-1]:
    obj = obj.setdefault(k, {})

last = keys[-1]
if last not in obj or not isinstance(obj[last], list):
    obj[last] = []
obj[last].append(json.loads('$value'))

# Keep only last 50 entries per key
if len(obj[last]) > 50:
    obj[last] = obj[last][-50:]

with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
  _state_unlock
}

# ─── Bot Result Recording ────────────────────────────────
# record_result "scraper" "success" "Found 15 APIs"
record_result() {
  local bot="$1"
  local status="$2"
  local message="${3:-}"
  local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  state_append ".bot_results" "{\"bot\":\"$bot\",\"status\":\"$status\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}"
  state_set ".bot_health.$bot" "{\"status\":\"$status\",\"last_run\":\"$timestamp\"}"
}

# ─── Cross-Bot Data Sharing ──────────────────────────────
# share_data "key_hunter" "apis" '["groq","openrouter"]'
share_data() {
  local namespace="$1"
  local key="$2"
  local value="$3"
  state_set ".shared_data.$namespace.$key" "$value"
}

# get_shared_data "key_hunter" "apis"
get_shared_data() {
  local namespace="$1"
  local key="$2"
  state_get ".shared_data.$namespace.$key"
}

# ─── Evolution Tracking ──────────────────────────────────
log_evolution() {
  local change="$1"
  local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  state_append ".evolution_log" "{\"change\":\"$change\",\"timestamp\":\"$timestamp\"}"
}

get_evolution_log() {
  state_get ".evolution_log" "[]"
}

# ─── Deployment Tracking ─────────────────────────────────
record_deployment() {
  local project="$1"
  local platform="$2"
  local url="$3"
  local status="${4:-success}"
  local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  state_append ".deployments" "{\"project\":\"$project\",\"platform\":\"$platform\",\"url\":\"$url\",\"status\":\"$status\",\"timestamp\":\"$timestamp\"}"
}

# ─── API Key Management ──────────────────────────────────
register_api_key() {
  local provider="$1"
  local type="${2:-ai}"
  local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  state_set ".api_keys.$provider" "{\"status\":\"active\",\"type\":\"$type\",\"registered\":\"$timestamp\",\"auto_rotate\":true}"
}

mark_key_dead() {
  local provider="$1"
  local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  state_set ".api_keys.$provider.status" "dead"
  state_set ".api_keys.$provider.dead_since" "$timestamp"
}

get_active_keys() {
  state_get ".api_keys" "{}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
active = [k for k, v in data.items() if isinstance(v, dict) and v.get('status') == 'active']
print(','.join(active))
" 2>/dev/null || echo ""
}

# Auto-init on source
init_state
