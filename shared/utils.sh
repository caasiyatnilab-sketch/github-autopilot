#!/bin/bash
# ═══════════════════════════════════════════════════════
# Shared Utilities for GitHub Autopilot (Enhanced v2)
# ═══════════════════════════════════════════════════════

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export BOLD='\033[1m'
export NC='\033[0m'

# Get repo info
get_repo() {
  echo "${REPO:-$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)}"
}

get_repo_owner() {
  echo "$(get_repo)" | cut -d'/' -f1
}

get_repo_name() {
  echo "$(get_repo)" | cut -d'/' -f2
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
    OK)    echo -e "${GREEN}[OK]${NC}    $ts $msg" ;;
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

# Rate limit handler with exponential backoff
rate_limit_wait() {
  local remaining=$(gh api rate_limit --jq '.rate.remaining' 2>/dev/null || echo "5000")
  if [ "$remaining" -lt 10 ]; then
    local reset=$(gh api rate_limit --jq '.rate.reset' 2>/dev/null || echo "0")
    local now=$(date +%s)
    local wait=$((reset - now + 5))
    if [ "$wait" -gt 0 ] && [ "$wait" -lt 600 ]; then
      log WARN "Rate limit low ($remaining remaining). Waiting ${wait}s..."
      sleep "$wait"
    fi
  fi
}

# Safe gh wrapper with retry and backoff
safe_gh() {
  local max_retries=3
  local retry=0
  local result=""
  local delay=5

  while [ $retry -lt $max_retries ]; do
    rate_limit_wait
    result=$("$@" 2>&1) && echo "$result" && return 0
    retry=$((retry + 1))
    if echo "$result" | grep -qi "rate limit\|403\|429\|secondary rate"; then
      log WARN "Rate limited. Retry $retry/$max_retries in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))
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

# Send notification (backward compatible)
notify() {
  local title="$1"
  local body="$2"

  # ntfy.sh (always available)
  local topic="${NTFY_TOPIC:-github-autopilot}"
  curl -s -d "$body" \
    -H "Title: $title" \
    -H "Tags: robot,github" \
    "https://ntfy.sh/$topic" >/dev/null 2>&1 || true

  # Discord webhook
  if [ -n "${DISCORD_WEBHOOK:-}" ]; then
    curl -s -H "Content-Type: application/json" \
      -d "{\"embeds\":[{\"title\":\"$title\",\"description\":\"$body\",\"color\":3447003}]}" \
      "$DISCORD_WEBHOOK" >/dev/null 2>&1 || true
  fi

  # Slack webhook
  if [ -n "${SLACK_WEBHOOK:-}" ]; then
    curl -s -H "Content-Type: application/json" \
      -d "{\"text\":\"*$title*\n$body\"}" \
      "$SLACK_WEBHOOK" >/dev/null 2>&1 || true
  fi

  # Telegram
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\":\"$TELEGRAM_CHAT_ID\",\"text\":\"*$title*\n$body\",\"parse_mode\":\"Markdown\"}" >/dev/null 2>&1 || true
  fi
}

# Send email notification
notify_email() {
  local subject="$1"
  local body="$2"
  local to="${NOTIFY_EMAIL:-}"

  [ -z "$to" ] && return 0

  # Resend (100/day free)
  if [ -n "${RESEND_API_KEY:-}" ]; then
    curl -s -X POST "https://api.resend.com/emails" \
      -H "Authorization: Bearer $RESEND_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"from\":\"autopilot@resend.dev\",\"to\":\"$to\",\"subject\":\"$subject\",\"text\":\"$body\"}" >/dev/null 2>&1 || true
  fi

  # Brevo (300/day free)
  if [ -n "${BREVO_API_KEY:-}" ]; then
    curl -s -X POST "https://api.brevo.com/v3/smtp/email" \
      -H "api-key: $BREVO_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"sender\":{\"email\":\"autopilot@bots.dev\"},\"to\":[{\"email\":\"$to\"}],\"subject\":\"$subject\",\"textContent\":\"$body\"}" >/dev/null 2>&1 || true
  fi
}

# Timestamp helpers
now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
today() { date -u '+%Y-%m-%d'; }
yesterday() { date -d '-1 day' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -v-1d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo ""; }
days_ago() { date -d "-${1} days" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -v-${1}d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo ""; }

# File helpers
file_exists() { [ -f "$1" ]; }
dir_exists() { [ -d "$1" ]; }
file_size() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo "0"; }
file_lines() { wc -l < "$1" 2>/dev/null || echo "0"; }

# String helpers
contains() { echo "$1" | grep -qi "$2"; }
starts_with() { [[ "$1" == "$2"* ]]; }
lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }
upper() { echo "$1" | tr '[:lower:]' '[:upper:]'; }
trim() { echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

# JSON helpers
json_get() {
  local file="$1"
  local key="$2"
  jq -r "$key" "$file" 2>/dev/null || echo ""
}

json_set() {
  local file="$1"
  local key="$2"
  local value="$3"
  python3 -c "
import json
with open('$file') as f: data = json.load(f)
keys = '$key'.split('.')
obj = data
for k in keys[:-1]:
    obj = obj.setdefault(k, {})
obj[keys[-1]] = '$value'
with open('$file', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null
}

# HTTP helpers
http_get() {
  curl -sL "$1" 2>/dev/null
}

http_status() {
  curl -s -o /dev/null -w "%{http_code}" "$1" 2>/dev/null || echo "000"
}

http_json() {
  curl -sL "$1" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "{}"
}

# GitHub helpers
gh_repo_exists() {
  gh repo view "$1" >/dev/null 2>&1
}

gh_create_repo() {
  local name="$1"
  local desc="${2:-}"
  local private="${3:-false}"
  local vis="--public"
  [ "$private" = "true" ] && vis="--private"
  gh repo create "$name" $vis -d "$desc" 2>/dev/null
}

# Success/Error helpers
success() { log OK "$*"; }
fail() { log ERROR "$*"; exit 1; }
warn() { log WARN "$*"; }
info() { log INFO "$*"; }

# ═══════════════════════════════════════════════════════
# Freemium API Key Pool Manager
# ═══════════════════════════════════════════════════════

# Get first available API key from a list of env vars
get_available_key() {
  local keys=("$@")
  for key_var in "${keys[@]}"; do
    if [ -n "${!key_var:-}" ]; then
      echo "${!key_var}"
      return 0
    fi
  done
  return 1
}

# Check if any AI provider is configured
has_ai_provider() {
  for var in GROQ_API_KEY TOGETHER_API_KEY OPENROUTER_API_KEY MISTRAL_API_KEY DEEPINFRA_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY; do
    [ -n "${!var:-}" ] && return 0
  done
  return 1
}

# Get list of configured AI providers
get_configured_providers() {
  local providers=()
  [ -n "${GROQ_API_KEY:-}" ] && providers+=("groq")
  [ -n "${TOGETHER_API_KEY:-}" ] && providers+=("together")
  [ -n "${OPENROUTER_API_KEY:-}" ] && providers+=("openrouter")
  [ -n "${MISTRAL_API_KEY:-}" ] && providers+=("mistral")
  [ -n "${DEEPINFRA_API_KEY:-}" ] && providers+=("deepinfra")
  [ -n "${OPENAI_API_KEY:-}" ] && providers+=("openai")
  [ -n "${ANTHROPIC_API_KEY:-}" ] && providers+=("anthropic")
  echo "${providers[@]}"
}

# ═══════════════════════════════════════════════════════
# AI Helper — auto-switches between free providers
# ═══════════════════════════════════════════════════════
ai_ask() {
  local prompt="$1"
  local model="${2:-}"
  
  # Try Groq first (fastest, 30 req/min free)
  if [ -n "${GROQ_API_KEY:-}" ]; then
    RESULT=$(curl -s "https://api.groq.com/openai/v1/chat/completions" \
      -H "Authorization: Bearer $GROQ_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${model:-llama-3.1-8b-instant}\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"max_tokens\":2048}" 2>/dev/null)
    REPLY=$(echo "$RESULT" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    [ -n "$REPLY" ] && echo "$REPLY" && return 0
  fi
  
  # Fallback: OpenRouter (free tier, many models)
  if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    RESULT=$(curl -s "https://openrouter.ai/api/v1/chat/completions" \
      -H "Authorization: Bearer $OPENROUTER_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${model:-meta-llama/llama-3.1-8b-instruct:free}\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"max_tokens\":2048}" 2>/dev/null)
    REPLY=$(echo "$RESULT" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    [ -n "$REPLY" ] && echo "$REPLY" && return 0
  fi
  
  # Fallback: Mistral
  if [ -n "${MISTRAL_API_KEY:-}" ]; then
    RESULT=$(curl -s "https://api.mistral.ai/v1/chat/completions" \
      -H "Authorization: Bearer $MISTRAL_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${model:-mistral-small}\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"max_tokens\":2048}" 2>/dev/null)
    REPLY=$(echo "$RESULT" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    [ -n "$REPLY" ] && echo "$REPLY" && return 0
  fi
  
  # Fallback: Together
  if [ -n "${TOGETHER_API_KEY:-}" ]; then
    RESULT=$(curl -s "https://api.together.xyz/v1/chat/completions" \
      -H "Authorization: Bearer $TOGETHER_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${model:-meta-llama/Llama-3-8b-chat-hf}\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"max_tokens\":2048}" 2>/dev/null)
    REPLY=$(echo "$RESULT" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    [ -n "$REPLY" ] && echo "$REPLY" && return 0
  fi
  
  return 1
}

ai_code() {
  ai_ask "You are a senior full-stack developer. Generate complete, production-ready code for: $1. Output ONLY code, no explanations." "llama-3.3-70b-versatile"
}

ai_review() {
  ai_ask "Review this code for bugs, security issues, and improvements. Be specific: $1" "llama-3.3-70b-versatile"
}
