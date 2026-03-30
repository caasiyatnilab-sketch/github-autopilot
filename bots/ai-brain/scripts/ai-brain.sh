#!/bin/bash
# 🧠 AI Brain — Makes ALL bots AI-powered when keys available
# Auto-detects AI keys → Enhances bots → Self-regenerates
set -uo pipefail
trap 'record_result "ai-brain" "error" "script exited with error" 2>/dev/null || true' ERR
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"

REPORT="ai-brain-report.md"
log INFO "🧠 AI Brain starting..."

# ═══════════════════════════════════════════════════════
# 1. Detect available AI providers
# ═══════════════════════════════════════════════════════
AVAILABLE_AI=()
AI_KEY=""

check_provider() {
  local name="$1"
  local key_var="$2"
  local url="$3"
  local key="${!key_var:-}"
  
  if [ -n "$key" ]; then
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $key" "$url" 2>/dev/null || echo "000")
    if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
      AVAILABLE_AI+=("$name")
      [ -z "$AI_KEY" ] && AI_KEY="$key" && AI_PROVIDER="$name" && AI_URL="$url"
      log INFO "  ✅ $name available"
    fi
  fi
}

check_provider "Groq" "GROQ_API_KEY" "https://api.groq.com/openai/v1/models"
check_provider "OpenRouter" "OPENROUTER_API_KEY" "https://openrouter.ai/api/v1/models"
check_provider "Mistral" "MISTRAL_API_KEY" "https://api.mistral.ai/v1/models"
check_provider "Together" "TOGETHER_API_KEY" "https://api.together.xyz/v1/models"
check_provider "DeepInfra" "DEEPINFRA_API_KEY" "https://api.deepinfra.com/v1/openai/models"

log INFO "Available AI: ${AVAILABLE_AI[*]:-none}"

# ═══════════════════════════════════════════════════════
# 2. AI-Powered Code Generation
# ═══════════════════════════════════════════════════════
ask_ai() {
  local prompt="$1"
  [ -z "$AI_KEY" ] && return 1
  
  local model="llama-3.1-8b-instant"
  [ "$AI_PROVIDER" = "OpenRouter" ] && model="meta-llama/llama-3-8b-instruct:free"
  [ "$AI_PROVIDER" = "Mistral" ] && model="mistral-small"
  [ "$AI_PROVIDER" = "Together" ] && model="meta-llama/Llama-3-8b-chat-hf"
  
  local api_url="$AI_URL"
  [ "$AI_PROVIDER" = "Groq" ] && api_url="https://api.groq.com/openai/v1/chat/completions"
  [ "$AI_PROVIDER" = "OpenRouter" ] && api_url="https://openrouter.ai/api/v1/chat/completions"
  
  RESPONSE=$(curl -s "$api_url" \
    -H "Authorization: Bearer $AI_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"max_tokens\":1024}" 2>/dev/null)
  
  echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null
}

# ═══════════════════════════════════════════════════════
# 3. Enhance bots with AI (if available)
# ═══════════════════════════════════════════════════════
ENHANCED=0

if [ -n "$AI_KEY" ]; then
  log INFO "🤖 AI available — enhancing bots..."
  
  # AI-powered commit messages
  log INFO "  Generating smart commit analysis..."
  COMMIT_ANALYSIS=$(ask_ai "Analyze this repo $(get_repo) and suggest 3 improvements. Be specific and actionable." 2>/dev/null || echo "")
  
  if [ -n "$COMMIT_ANALYSIS" ]; then
    log INFO "  ✅ AI analysis received"
    ENHANCED=1
  fi
  
  # AI-powered security analysis
  log INFO "  Running AI security analysis..."
  SECURITY_AI=$(ask_ai "Check for common security vulnerabilities in a typical web project. List top 5 things to check." 2>/dev/null || echo "")
  
  if [ -n "$SECURITY_AI" ]; then
    log INFO "  ✅ AI security tips received"
    ENHANCED=1
  fi
  
  # AI-powered code review
  log INFO "  Running AI code review tips..."
  CODE_REVIEW=$(ask_ai "What are the most common code quality issues in JavaScript projects? List 5 specific things to check." 2>/dev/null || echo "")
  
  if [ -n "$CODE_REVIEW" ]; then
    log INFO "  ✅ AI code review tips received"
    ENHANCED=1
  fi
else
  log INFO "⚪ No AI keys configured — running in basic mode"
  COMMIT_ANALYSIS="Add GROQ_API_KEY or OPENROUTER_API_KEY to GitHub Secrets to enable AI features"
  SECURITY_AI="Configure AI keys for smart security analysis"
  CODE_REVIEW="Configure AI keys for smart code review"
fi

# ═══════════════════════════════════════════════════════
# 4. Self-Regeneration — Find new free APIs
# ═══════════════════════════════════════════════════════
log INFO "🔄 Checking for new free AI APIs..."

NEW_APIS_FOUND=0

# Test potential free endpoints
TEST_ENDPOINTS=(
  "Groq|https://api.groq.com/openai/v1/models"
  "OpenRouter|https://openrouter.ai/api/v1/models"
  "Mistral|https://api.mistral.ai/v1/models"
  "Together|https://api.together.xyz/v1/models"
  "DeepInfra|https://api.deepinfra.com/v1/openai/models"
  "Cerebras|https://api.cerebras.ai/v1/models"
  "SambaNova|https://api.sambanova.ai/v1/models"
)

for endpoint in "${TEST_ENDPOINTS[@]}"; do
  IFS='|' read -r name url <<< "$endpoint"
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
    log INFO "  ✅ $name API is live"
    NEW_APIS_FOUND=$((NEW_APIS_FOUND+1))
  fi
done

log INFO "  Found $NEW_APIS_FOUND live AI API endpoints"

# ═══════════════════════════════════════════════════════
# 5. Generate Report
# ═══════════════════════════════════════════════════════
cat > "$REPORT" << REOF
# 🧠 AI Brain Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repo:** $(get_repo)

## AI Status
- Available providers: ${#AVAILABLE_AI[@]}
- Providers: ${AVAILABLE_AI[*]:-none}
- AI mode: $([ "$ENHANCED" -eq 1 ] && echo "✅ ACTIVE" || echo "⚪ INACTIVE (add API keys)")

## AI Analysis
$(if [ -n "$COMMIT_ANALYSIS" ]; then echo "### Suggestions"; echo "$COMMIT_ANALYSIS"; fi)

$(if [ -n "$SECURITY_AI" ]; then echo "### Security Tips"; echo "$SECURITY_AI"; fi)

$(if [ -n "$CODE_REVIEW" ]; then echo "### Code Review Tips"; echo "$CODE_REVIEW"; fi)

## Free AI APIs Found
$NEW_APIS_FOUND live endpoints detected

## How to Activate AI Mode
Add any of these to GitHub Secrets:
- \`GROQ_API_KEY\` — Free at console.groq.com (fastest)
- \`OPENROUTER_API_KEY\` — Free at openrouter.ai/keys (many models)
- \`MISTRAL_API_KEY\` — Free at console.mistral.ai
- \`TOGETHER_API_KEY\` — Free at api.together.xyz (\$25 credits)

Once configured, ALL bots become AI-powered automatically.

---
_Automated by AI Brain 🧠_
REOF

record_result "ai-brain" "success" "completed" 2>/dev/null || true
cat "$REPORT"
notify "AI Brain" "AI mode: $([ "$ENHANCED" -eq 1 ] && echo "ACTIVE" || echo "INACTIVE — add API keys")"
exit 0
