#!/bin/bash
# ═══════════════════════════════════════════════════════
# AI Engine v3 — 3 Providers, 100+ Models, Auto-Switch
# Every bot uses this for intelligent decisions
# ═══════════════════════════════════════════════════════

# Smart AI call — picks best model for the task
ai_smart() {
  local prompt="$1"
  local task_type="${2:-general}"
  local model=""
  local api_url=""
  local key=""
  
  # Pick best model based on task
  case "$task_type" in
    code)     model="llama-3.3-70b-versatile" ;;  # Best for code
    review)   model="llama-3.3-70b-versatile" ;;  # Best for review
    security) model="llama-3.3-70b-versatile" ;;  # Best for security
    analysis) model="llama-3.1-8b-instant" ;;     # Fast for analysis
    general)  model="llama-3.1-8b-instant" ;;     # Fast for general
    creative) model="llama-3.3-70b-versatile" ;;  # Best for creative
    *)        model="llama-3.1-8b-instant" ;;
  esac
  
  # Try Groq first
  if [ -n "${GROQ_API_KEY:-}" ]; then
    RESULT=$(curl -s --max-time 10 "https://api.groq.com/openai/v1/chat/completions" \
      -H "Authorization: Bearer $GROQ_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"max_tokens\":2048}" 2>/dev/null)
    REPLY=$(echo "$RESULT" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    [ -n "$REPLY" ] && echo "$REPLY" && return 0
  fi
  
  # Try OpenRouter
  if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    RESULT=$(curl -s --max-time 15 "https://openrouter.ai/api/v1/chat/completions" \
      -H "Authorization: Bearer $OPENROUTER_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"openrouter/free\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"max_tokens\":2048}" 2>/dev/null)
    REPLY=$(echo "$RESULT" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    [ -n "$REPLY" ] && echo "$REPLY" && return 0
  fi
  
  # Try HuggingFace
  if [ -n "${HF_TOKEN:-}" ]; then
    RESULT=$(curl -s --max-time 20 "https://router.huggingface.co/v1/chat/completions" \
      -H "Authorization: Bearer $HF_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"Qwen/Qwen3.5-27B\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"max_tokens\":2048}" 2>/dev/null)
    REPLY=$(echo "$RESULT" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    [ -n "$REPLY" ] && echo "$REPLY" && return 0
  fi
  
  return 1
}

# Specialized AI functions for each bot type
ai_analyze_code() { ai_smart "Analyze this code for bugs, security issues, and improvements. Be specific and actionable: $1" "code"; }
ai_fix_code() { ai_smart "Fix this code. Output ONLY the fixed code, no explanations: $1" "code"; }
ai_review_security() { ai_smart "Review for security vulnerabilities. List specific issues with severity (Critical/High/Medium/Low): $1" "security"; }
ai_suggest_project() { ai_smart "Suggest a unique, useful web app project idea. Include tech stack and key features. Be creative and specific." "creative"; }
ai_generate_code() { ai_smart "Generate complete, production-ready code for: $1. Output ONLY code." "code"; }
ai_analyze_data() { ai_smart "Analyze this data and provide key insights, trends, and recommendations: $1" "analysis"; }
ai_write_report() { ai_smart "Write a professional report summary for: $1" "general"; }
ai_decide() { ai_smart "Answer with ONLY yes or no: $1" "general"; }
ai_prioritize() { ai_smart "Rank these by priority (1=highest): $1. Output only the rankings." "analysis"; }
ai_translate() { ai_smart "Translate to Filipino: $1" "general"; }
