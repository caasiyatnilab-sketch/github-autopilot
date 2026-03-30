#!/bin/bash
# ═══════════════════════════════════════════════════════
# AI Engine v4 — Universal Provider Support
# Auto-detects: Groq, OpenRouter, Together, Mistral,
#   DeepInfra, HuggingFace, OpenAI, Anthropic
# Tries all available providers, free models first
# ═══════════════════════════════════════════════════════

# ─── Provider Definitions ────────────────────────────────
# Each provider: API URL | default model | auth header format

_call_groq() {
  local prompt="$1" model="${2:-llama-3.1-8b-instant}"
  [ -z "${GROQ_API_KEY:-}" ] && return 1
  local result
  result=$(curl -s --max-time 15 "https://api.groq.com/openai/v1/chat/completions" \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$( echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],\"max_tokens\":2048}" 2>/dev/null)
  local reply
  reply=$(echo "$result" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  [ -n "$reply" ] && echo "$reply" && return 0
  return 1
}

_call_openrouter() {
  local prompt="$1" model="${2:-nvidia/nemotron-3-super-120b-a12b:free}"
  [ -z "${OPENROUTER_API_KEY:-}" ] && return 1
  local result
  result=$(curl -s --max-time 20 "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],\"max_tokens\":2048}" 2>/dev/null)
  # Handle models that put output in reasoning field
  local reply
  reply=$(echo "$result" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  if [ -z "$reply" ]; then
    reply=$(echo "$result" | jq -r '.choices[0].message.reasoning // empty' 2>/dev/null)
  fi
  [ -n "$reply" ] && echo "$reply" && return 0
  return 1
}

_call_together() {
  local prompt="$1" model="${2:-meta-llama/Llama-3-8b-chat-hf}"
  [ -z "${TOGETHER_API_KEY:-}" ] && return 1
  local result
  result=$(curl -s --max-time 20 "https://api.together.xyz/v1/chat/completions" \
    -H "Authorization: Bearer $TOGETHER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],\"max_tokens\":2048}" 2>/dev/null)
  local reply
  reply=$(echo "$result" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  [ -n "$reply" ] && echo "$reply" && return 0
  return 1
}

_call_mistral() {
  local prompt="$1" model="${2:-mistral-small-latest}"
  [ -z "${MISTRAL_API_KEY:-}" ] && return 1
  local result
  result=$(curl -s --max-time 20 "https://api.mistral.ai/v1/chat/completions" \
    -H "Authorization: Bearer $MISTRAL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],\"max_tokens\":2048}" 2>/dev/null)
  local reply
  reply=$(echo "$result" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  [ -n "$reply" ] && echo "$reply" && return 0
  return 1
}

_call_deepinfra() {
  local prompt="$1" model="${2:-meta-llama/Meta-Llama-3-8B-Instruct}"
  [ -z "${DEEPINFRA_API_KEY:-}" ] && return 1
  local result
  result=$(curl -s --max-time 20 "https://api.deepinfra.com/v1/openai/chat/completions" \
    -H "Authorization: Bearer $DEEPINFRA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],\"max_tokens\":2048}" 2>/dev/null)
  local reply
  reply=$(echo "$result" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  [ -n "$reply" ] && echo "$reply" && return 0
  return 1
}

_call_huggingface() {
  local prompt="$1" model="${2:-meta-llama/Llama-3.1-8B-Instruct}"
  [ -z "${HF_TOKEN:-}" ] && return 1
  local result
  result=$(curl -s --max-time 30 "https://router.huggingface.co/v1/chat/completions" \
    -H "Authorization: Bearer $HF_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],\"max_tokens\":2048}" 2>/dev/null)
  local reply
  reply=$(echo "$result" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  [ -n "$reply" ] && echo "$reply" && return 0
  return 1
}

_call_ollama() {
  local prompt="$1" model="${2:-gemma3:4b}"
  [ -z "${OLLAMA_API_KEY:-}" ] && return 1
  local result
  result=$(curl -s --max-time 30 "https://ollama.com/api/chat" \
    -H "Authorization: Bearer $OLLAMA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],\"stream\":false}" 2>/dev/null)
  local reply
  reply=$(echo "$result" | jq -r '.message.content // empty' 2>/dev/null)
  [ -n "$reply" ] && echo "$reply" && return 0
  return 1
}

_call_openai() {
  local prompt="$1" model="${2:-gpt-4o-mini}"
  [ -z "${OPENAI_API_KEY:-}" ] && return 1
  local result
  result=$(curl -s --max-time 30 "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],\"max_tokens\":2048}" 2>/dev/null)
  local reply
  reply=$(echo "$result" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  [ -n "$reply" ] && echo "$reply" && return 0
  return 1
}

# ─── Smart AI Call ────────────────────────────────────────
# Tries all available providers in priority order
# Usage: ai_smart "prompt" [task_type]
ai_smart() {
  local prompt="$1"
  local task_type="${2:-general}"

  # Code-heavy tasks → try best models first
  case "$task_type" in
    code|review|security|creative)
      _call_ollama "$prompt" "qwen3-coder-next" && return 0
      _call_ollama "$prompt" "glm-5" && return 0
      _call_groq "$prompt" "llama-3.3-70b-versatile" && return 0
      _call_openrouter "$prompt" "nvidia/nemotron-3-super-120b-a12b:free" && return 0
      _call_openrouter "$prompt" "qwen/qwen3-next-80b-a3b-instruct:free" && return 0
      ;;
  esac

  # Fast tasks → try fastest providers first
  _call_ollama "$prompt" "gemma3:4b" && return 0
  _call_groq "$prompt" "llama-3.1-8b-instant" && return 0
  _call_openrouter "$prompt" "nvidia/nemotron-3-super-120b-a12b:free" && return 0
  _call_openrouter "$prompt" "stepfun/step-3.5-flash:free" && return 0
  _call_openrouter "$prompt" "arcee-ai/trinity-mini:free" && return 0

  # Fallback to other providers
  _call_ollama "$prompt" "ministral-3:3b" && return 0
  _call_together "$prompt" && return 0
  _call_mistral "$prompt" && return 0
  _call_deepinfra "$prompt" && return 0
  _call_huggingface "$prompt" && return 0
  _call_openai "$prompt" && return 0

  echo "[AI] All providers failed or unavailable" >&2
  return 1
}

# ─── Generic AI Ask (backward compat) ────────────────────
ai_ask() {
  local prompt="$1"
  local model="${2:-}"
  # If a specific model is given, try to find which provider it belongs to
  if [ -n "$model" ]; then
    case "$model" in
      llama-*|mixtral-*)  _call_groq "$prompt" "$model" && return 0 ;;
      *:free)             _call_openrouter "$prompt" "$model" && return 0 ;;
      mistral-*|open-mistral-*) _call_mistral "$prompt" "$model" && return 0 ;;
      gpt-*)              _call_openai "$prompt" "$model" && return 0 ;;
    esac
  fi
  # No model specified → use smart routing
  ai_smart "$prompt" "general"
}

# ─── Specialized Functions ────────────────────────────────
ai_analyze_code()     { ai_smart "Analyze this code for bugs, security issues, and improvements. Be specific and actionable: $1" "code"; }
ai_fix_code()         { ai_smart "Fix this code. Output ONLY the fixed code, no explanations: $1" "code"; }
ai_review_security()  { ai_smart "Review for security vulnerabilities. List specific issues with severity (Critical/High/Medium/Low): $1" "security"; }
ai_suggest_project()  { ai_smart "Suggest a unique, useful web app project idea. Include tech stack and key features. Be creative and specific." "creative"; }
ai_generate_code()    { ai_smart "Generate complete, production-ready code for: $1. Output ONLY code." "code"; }
ai_analyze_data()     { ai_smart "Analyze this data and provide key insights, trends, and recommendations: $1" "analysis"; }
ai_write_report()     { ai_smart "Write a professional report summary for: $1" "general"; }
ai_decide()           { ai_smart "Answer with ONLY yes or no: $1" "general"; }
ai_prioritize()       { ai_smart "Rank these by priority (1=highest): $1. Output only the rankings." "analysis"; }
ai_translate()        { ai_smart "Translate to Filipino: $1" "general"; }
ai_code()             { ai_smart "You are a senior full-stack developer. Generate complete, production-ready code for: $1. Output ONLY code, no explanations." "code"; }
ai_review()           { ai_smart "Review this code for bugs, security issues, and improvements. Be specific: $1" "review"; }

# ─── Provider Health Check ────────────────────────────────
ai_health_check() {
  echo "🤖 AI Provider Status:"
  [ -n "${OLLAMA_API_KEY:-}" ]        && echo "  ✅ Ollama Cloud (glm-5, qwen3-coder, gemma3, 35+ models)" || echo "  ⬜ Ollama Cloud"
  [ -n "${GROQ_API_KEY:-}" ]         && echo "  ✅ Groq (llama-3.1-8b-instant, llama-3.3-70b)" || echo "  ⬜ Groq"
  [ -n "${OPENROUTER_API_KEY:-}" ]   && echo "  ✅ OpenRouter (24 free models)"              || echo "  ⬜ OpenRouter"
  [ -n "${TOGETHER_API_KEY:-}" ]     && echo "  ✅ Together (Llama, Mistral)"                || echo "  ⬜ Together"
  [ -n "${MISTRAL_API_KEY:-}" ]      && echo "  ✅ Mistral (mistral-small, mistral-medium)"  || echo "  ⬜ Mistral"
  [ -n "${DEEPINFRA_API_KEY:-}" ]    && echo "  ✅ DeepInfra (Llama, Mixtral)"               || echo "  ⬜ DeepInfra"
  [ -n "${HF_TOKEN:-}" ]             && echo "  ✅ HuggingFace (free Inference API)"         || echo "  ⬜ HuggingFace"
  [ -n "${OPENAI_API_KEY:-}" ]       && echo "  ✅ OpenAI (gpt-4o, gpt-4o-mini)"             || echo "  ⬜ OpenAI"
  [ -n "${ANTHROPIC_API_KEY:-}" ]    && echo "  ✅ Anthropic (claude)"                       || echo "  ⬜ Anthropic"
}
