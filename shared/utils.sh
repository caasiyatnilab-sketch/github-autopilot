#!/bin/bash
# ═══════════════════════════════════════════════════════
# Shared Utilities for GitHub Autopilot
# ═══════════════════════════════════════════════════════

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# Get repo info
get_repo() {
  echo "${REPO:-$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)}"
}

# Log with timestamp
log() {
  local level="$1"
  shift
  local msg="$*"
  local ts=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
  case "$level" in
    INFO)  echo -e "${GREEN}[INFO]${NC}  $ts $msg" ;;
    WARN)  echo -e "${YELLOW}[WARN]${NC}  $ts $msg" ;;
    ERROR) echo -e "${RED}[ERROR]${NC} $ts $msg" ;;
    DEBUG) echo -e "${CYAN}[DEBUG]${NC} $ts $msg" ;;
  esac
}

# Check if command exists
require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    log ERROR "Required command not found: $cmd"
    return 1
  fi
}

# Rate limit handler
rate_limit_wait() {
  local remaining=$(gh api rate_limit --jq '.rate.remaining' 2>/dev/null || echo "5000")
  if [ "$remaining" -lt 10 ]; then
    local reset=$(gh api rate_limit --jq '.rate.reset' 2>/dev/null || echo "0")
    local now=$(date +%s)
    local wait=$((reset - now + 5))
    if [ "$wait" -gt 0 ] && [ "$wait" -lt 300 ]; then
      log WARN "Rate limit low ($remaining remaining). Waiting ${wait}s..."
      sleep "$wait"
    fi
  fi
}

# Safe gh wrapper with retry
safe_gh() {
  local max_retries=3
  local retry=0
  local result=""

  while [ $retry -lt $max_retries ]; do
    rate_limit_wait
    result=$("$@" 2>&1) && echo "$result" && return 0
    retry=$((retry + 1))
    if echo "$result" | grep -qi "rate limit\|403\|429"; then
      log WARN "Rate limited. Retry $retry/$max_retries..."
      sleep $((retry * 30))
    else
      echo "$result" && return 1
    fi
  done
  log ERROR "Failed after $max_retries retries: $*"
  return 1
}

# Create label if not exists
ensure_label() {
  local name="$1"
  local color="${2:-ededed}"
  local desc="${3:-}"
  gh label create "$name" --color "$color" --description "$desc" --force 2>/dev/null || true
}

# Get config value from .github/autopilot.yml
get_config() {
  local key="$1"
  local default="${2:-}"
  if [ -f ".github/autopilot.yml" ]; then
    python3 -c "
import yaml, sys
with open('.github/autopilot.yml') as f:
    cfg = yaml.safe_load(f)
keys = '$key'.split('.')
val = cfg
for k in keys:
    if isinstance(val, dict) and k in val:
        val = val[k]
    else:
        print('$default')
        sys.exit(0)
print(val if val is not None else '$default')
" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# Lock file to prevent concurrent runs
acquire_lock() {
  local lock_name="$1"
  local lock_file="/tmp/autopilot-${lock_name}.lock"
  if [ -f "$lock_file" ]; then
    local lock_pid=$(cat "$lock_file" 2>/dev/null)
    if kill -0 "$lock_pid" 2>/dev/null; then
      log WARN "Another instance of $lock_name is running (PID $lock_pid)"
      return 1
    fi
    rm -f "$lock_file"
  fi
  echo $$ > "$lock_file"
  trap "rm -f '$lock_file'" EXIT
}

# Send notification
notify() {
  local title="$1"
  local body="$2"
  local webhook="${DISCORD_WEBHOOK:-}"

  if [ -n "$webhook" ]; then
    curl -s -H "Content-Type: application/json" \
      -d "{\"embeds\":[{\"title\":\"$title\",\"description\":\"$body\",\"color\":3447003}]}" \
      "$webhook" >/dev/null 2>&1 || true
  fi
}

# Generate timestamp
now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
today() { date -u '+%Y-%m-%d'; }
