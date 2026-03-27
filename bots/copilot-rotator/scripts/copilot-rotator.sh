#!/bin/bash
# 🔑 Copilot Rotator Bot
# API key rotation, health checks, free tier monitoring
# Finds and manages freemium API keys for unstoppable AI usage
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="copilot-rotator"
REPORT="copilot-rotator-report.md"

log INFO "🔑 Copilot Rotator starting..."

KEYS_FILE=".github/api-keys-status.json"
mkdir -p .github

if [ ! -f "$KEYS_FILE" ]; then
  cat > "$KEYS_FILE" << 'EOF'
{
  "providers": {},
  "last_check": "never",
  "healthy_count": 0,
  "total_count": 0
}
EOF
fi

# ═══════════════════════════════════════════════════════
# Check API Key Health
# ═══════════════════════════════════════════════════════

check_provider() {
  local name="$1"
  local url="$2"
  local key_var="$3"
  local test_endpoint="$4"

  log INFO "Checking: $name"

  local status="unknown"
  local remaining="N/A"
  local key_exists="false"

  # Check if key exists in env
  if [ -n "${!key_var:-}" ]; then
    key_exists="true"

    # Test the endpoint
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer ${!key_var}" \
      "$test_endpoint" 2>/dev/null || echo "000")

    if [ "$http_code" = "200" ]; then
      status="✅ healthy"
    elif [ "$http_code" = "401" ]; then
      status="❌ invalid key"
    elif [ "$http_code" = "429" ]; then
      status="⚠️ rate limited"
    elif [ "$http_code" = "403" ]; then
      status="⚠️ quota exceeded"
    else
      status="❓ HTTP $http_code"
    fi

    # Check rate limits if available
    case "$name" in
      "GitHub")
        remaining=$(curl -s -H "Authorization: Bearer ${!key_var}" \
          "https://api.github.com/rate_limit" 2>/dev/null | \
          jq -r '.rate.remaining // "N/A"' 2>/dev/null || echo "N/A")
        ;;
      "OpenAI"|"Groq"|"Together"|"OpenRouter"|"Mistral")
        # These return rate limit headers
        local headers=$(curl -sI -H "Authorization: Bearer ${!key_var}" \
          "$test_endpoint" 2>/dev/null || echo "")
        remaining=$(echo "$headers" | grep -i "x-ratelimit-remaining" | awk '{print $2}' | tr -d '\r' || echo "N/A")
        ;;
    esac
  else
    status="⚪ not configured"
  fi

  echo "$name|$status|$remaining|$key_exists"
}

# ═══════════════════════════════════════════════════════
# Discover Free API Keys Available
# ═══════════════════════════════════════════════════════

discover_free_keys() {
  log INFO "Discovering available free API signups..."

  cat << 'EOF'

## 🆓 Free API Keys You Can Get Right Now

### AI Models (No Credit Card Required)
| Provider | Free Tier | Sign Up |
|----------|-----------|---------|
| **Groq** | 30 req/min, LLaMA/Mixtral | https://console.groq.com |
| **Together AI** | $25 free credits | https://api.together.xyz |
| **Hugging Face** | Free inference API | https://huggingface.co/settings/tokens |
| **OpenRouter** | Free tier on many models | https://openrouter.ai/keys |
| **Mistral** | Free tier, Mistral 7B | https://console.mistral.ai |
| **DeepInfra** | Free tier, many models | https://deepinfra.com |
| **Fireworks AI** | Free credits | https://fireworks.ai |
| **Cohere** | Free trial, 100 req/min | https://dashboard.cohere.ai |
| **AIMLAPI** | 200+ models free tier | https://aimlapi.com |
| **Novita AI** | Free tier GPU | https://novita.ai |

### AI Image Generation
| Provider | Free Tier | Sign Up |
|----------|-----------|---------|
| **Stability AI** | Free credits | https://platform.stability.ai |
| **Replicate** | Free tier | https://replicate.com |
| **Leonardo AI** | Free tokens/day | https://leonardo.ai |

### AI Speech & Audio
| Provider | Free Tier | Sign Up |
|----------|-----------|---------|
| **ElevenLabs** | 10k chars/month | https://elevenlabs.io |
| **AssemblyAI** | 5 hrs/month free | https://assemblyai.com |
| **Deepgram** | $200 free credits | https://deepgram.com |

### Useful Tools
| Provider | Free Tier | Sign Up |
|----------|-----------|---------|
| **Supabase** | Free DB + Auth | https://supabase.com |
| **Vercel** | Free hosting | https://vercel.com |
| **Resend** | 100 emails/day | https://resend.com |
| **Uploadthing** | 2GB free | https://uploadthing.com |
| **Clerk** | Free auth | https://clerk.com |

EOF
}

# ═══════════════════════════════════════════════════════
# GitHub Copilot Status
# ═══════════════════════════════════════════════════════

check_copilot() {
  log INFO "Checking GitHub Copilot status..."

  # Check if copilot extension is available
  local copilot_status="unknown"
  local suggestions_remaining="N/A"

  # Check API rate limits
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    local rate=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
      "https://api.github.com/rate_limit" 2>/dev/null)
    local remaining=$(echo "$rate" | jq -r '.rate.remaining // "N/A"' 2>/dev/null || echo "N/A")
    local limit=$(echo "$rate" | jq -r '.rate.limit // "N/A"' 2>/dev/null || echo "N/A")
    log INFO "GitHub API: $remaining/$limit requests remaining"
  fi
}

# ═══════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════

PROVIDERS_RESULTS=()

# Check all configured providers
PROVIDERS_RESULTS+=($(check_provider "GitHub" "https://api.github.com/user" "GITHUB_TOKEN" "https://api.github.com/user"))
PROVIDERS_RESULTS+=($(check_provider "OpenAI" "https://api.openai.com/v1/models" "OPENAI_API_KEY" "https://api.openai.com/v1/models"))
PROVIDERS_RESULTS+=($(check_provider "Groq" "https://api.groq.com/openai/v1/models" "GROQ_API_KEY" "https://api.groq.com/openai/v1/models"))
PROVIDERS_RESULTS+=($(check_provider "Together" "https://api.together.xyz/v1/models" "TOGETHER_API_KEY" "https://api.together.xyz/v1/models"))
PROVIDERS_RESULTS+=($(check_provider "OpenRouter" "https://openrouter.ai/api/v1/models" "OPENROUTER_API_KEY" "https://openrouter.ai/api/v1/models"))
PROVIDERS_RESULTS+=($(check_provider "Mistral" "https://api.mistral.ai/v1/models" "MISTRAL_API_KEY" "https://api.mistral.ai/v1/models"))
PROVIDERS_RESULTS+=($(check_provider "Anthropic" "https://api.anthropic.com/v1/messages" "ANTHROPIC_API_KEY" "https://api.anthropic.com/v1/messages"))

check_copilot

# Generate report
HEALTHY=0
for result in "${PROVIDERS_RESULTS[@]}"; do
  if echo "$result" | grep -q "healthy"; then
    HEALTHY=$((HEALTHY + 1))
  fi
done

cat > "$REPORT" << EOF
# 🔑 Copilot Rotator Report

**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Healthy Keys:** $HEALTHY / ${#PROVIDERS_RESULTS[@]}

## Provider Status

| Provider | Status | Remaining | Configured |
|----------|--------|-----------|------------|
$(for result in "${PROVIDERS_RESULTS[@]}"; do
  IFS='|' read -r name status remaining exists <<< "$result"
  echo "| $name | $status | $remaining | $exists |"
done)

## GitHub Copilot
- API Rate Limit checked ✅
- Use \`gh copilot\` CLI for suggestions

## Recommendations
$(if [ "$HEALTHY" -eq 0 ]; then
  echo "- ⚠️ No API keys configured! Add keys to GitHub Secrets"
  echo "- See the free key list below"
fi)

$(discover_free_keys)

---
_Automated by Copilot Rotator 🔑_
EOF

cat "$REPORT"

notify "$(basename $BOT_NAME 2>/dev/null || basename $0)" "Bot completed successfully. Check report." 2>/dev/null || true
log INFO "🔑 Copilot Rotator complete! $HEALTHY healthy keys."

exit 0
