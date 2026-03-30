#!/bin/bash
# 🧬 Self-Evolver Bot
# Analyzes all bots, finds weaknesses, patches them, commits improvements
# Uses AI to review bot scripts and suggest improvements
# Rate-limit aware, caches results, respects free-tier limits
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"

REPORT="self-evolver-report.md"
log INFO "🧬 Self-Evolver starting..."

CHANGES=0
IMPROVEMENTS=""

# ═══════════════════════════════════════════════════════
# 1. Analyze Bot Performance from Shared State
# ═══════════════════════════════════════════════════════
analyze_performance() {
  log INFO "📊 Analyzing bot performance..."

  local failures=0
  local successes=0
  local stale_bots=""

  # Check each bot's last result from shared state
  for bot_dir in bots/*/scripts/*.sh; do
    [ -f "$bot_dir" ] || continue
    local bot_name=$(basename "$bot_dir" .sh)
    local health=$(state_get ".bot_health.$bot_name.status" "unknown")

    case "$health" in
      error|failed)
        failures=$((failures + 1))
        stale_bots="$stale_bots $bot_name"
        log WARN "  ❌ $bot_name: $health"
        ;;
      success|ok)
        successes=$((successes + 1))
        ;;
      *)
        log INFO "  ⚪ $bot_name: no data"
        ;;
    esac
  done

  log INFO "  Results: $successes healthy, $failures failing"

  # If too many failures, trigger self-healing
  if [ "$failures" -gt 3 ]; then
    log WARN "  🚨 $failures bots failing — triggering self-healing"
    attempt_healing "$stale_bots"
  fi
}

# ═══════════════════════════════════════════════════════
# 2. Self-Healing — Fix Broken Bots
# ═══════════════════════════════════════════════════════
attempt_healing() {
  local broken_bots="$1"

  for bot in $broken_bots; do
    local script="bots/$bot/scripts/$bot.sh"
    [ -f "$script" ] || continue

    log INFO "  🔧 Attempting to fix: $bot"

    # Check for common issues
    local fixed=false

    # Issue 1: Missing shebang
    if ! head -1 "$script" | grep -q "^#!/"; then
      sed -i '1i#!/bin/bash' "$script"
      IMPROVEMENTS="$IMPROVEMENTS\n- Fixed missing shebang in $bot"
      CHANGES=$((CHANGES + 1))
      fixed=true
    fi

    # Issue 2: Missing set flags
    if ! grep -q "set -" "$script" | head -2; then
      sed -i '2a set -uo pipefail' "$script"
      IMPROVEMENTS="$IMPROVEMENTS\n- Added error handling to $bot"
      CHANGES=$((CHANGES + 1))
      fixed=true
    fi

    # Issue 3: Missing utils source
    if ! grep -q "source.*utils.sh" "$script"; then
      sed -i '/^set -/a source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"' "$script"
      IMPROVEMENTS="$IMPROVEMENTS\n- Added utils source to $bot"
      CHANGES=$((CHANGES + 1))
      fixed=true
    fi

    if [ "$fixed" = true ]; then
      log_evolution "Auto-fixed $bot: missing boilerplate"
      log INFO "  ✅ Fixed $bot"
    fi
  done
}

# ═══════════════════════════════════════════════════════
# 3. AI-Powered Code Review (rate-limit aware)
# ═══════════════════════════════════════════════════════
ai_review_bots() {
  # Only run AI review if we have keys and haven't reviewed recently
  local last_review=$(state_get ".shared_data.evolver.last_ai_review" "never")
  local now=$(date -u '+%Y-%m-%d')

  # Cache: only review once per day to save API calls
  [ "$last_review" = "$now" ] && log INFO "  📋 AI review already done today (cached)" && return 0

  if ! has_ai_provider; then
    log INFO "  ⚪ No AI provider configured — skipping AI review"
    return 0
  fi

  log INFO "  🤖 Running AI code review..."

  # Pick one random bot to review (round-robin to spread API usage)
  local bot_to_review=""
  local review_count=$(state_get ".shared_data.evolver.review_index" "0")
  local all_bots=()
  for bot_dir in bots/*/scripts/*.sh; do
    [ -f "$bot_dir" ] && all_bots+=("$(basename "$bot_dir" .sh)")
  done

  if [ ${#all_bots[@]} -gt 0 ]; then
    local idx=$((review_count % ${#all_bots[@]}))
    bot_to_review="${all_bots[$idx]}"
    state_set ".shared_data.evolver.review_index" "$((review_count + 1))"
  fi

  [ -z "$bot_to_review" ] && return 0

  local script="bots/$bot_to_review/scripts/$bot_to_review.sh"
  [ -f "$script" ] || return 0

  # Read only first 100 lines to save tokens
  local code_snippet=$(head -100 "$script")

  local review=$(ai_smart "Review this bash script for bugs, security issues, or improvements. Output ONLY 2-3 specific actionable suggestions (no code): $code_snippet" "code" 2>/dev/null || echo "")

  if [ -n "$review" ] && [ ${#review} -gt 20 ]; then
    IMPROVEMENTS="$IMPROVEMENTS\n- 🤖 AI review of $bot_to_review: $review"
    share_data "evolver" "last_ai_review" "$now"
    log_evolution "AI reviewed $bot_to_review"
    log INFO "  ✅ AI review complete for $bot_to_review"
  fi
}

# ═══════════════════════════════════════════════════════
# 4. Dependency & Config Upgrades
# ═══════════════════════════════════════════════════════
check_upgrades() {
  log INFO "🔍 Checking for improvements..."

  # Check if ai-engine.sh has the latest version
  if grep -q "ai_smart.*openrouter/free" shared/ai-engine.sh 2>/dev/null; then
    IMPROVEMENTS="$IMPROVEMENTS\n- ⚠️ ai-engine.sh uses invalid model ID 'openrouter/free' — needs update"
    CHANGES=$((CHANGES + 1))
  fi

  # Check if state.sh is sourced by bots
  local bots_without_state=0
  for bot_dir in bots/*/scripts/*.sh; do
    [ -f "$bot_dir" ] || continue
    if ! grep -q "source.*state.sh" "$bot_dir" 2>/dev/null; then
      bots_without_state=$((bots_without_state + 1))
    fi
  done

  if [ "$bots_without_state" -gt 5 ]; then
    IMPROVEMENTS="$IMPROVEMENTS\n- 📡 $bots_without_state bots not using shared state — cross-bot coordination limited"
  fi

  # Check for unused workflow files
  local wf_count=$(ls .github/workflows/*.yml 2>/dev/null | wc -l || echo "0")
  local bot_count=$(ls bots/*/scripts/*.sh 2>/dev/null | wc -l || echo "0")
  if [ "$wf_count" -gt "$((bot_count + 5))" ]; then
    IMPROVEMENTS="$IMPROVEMENTS\n- 🧹 $wf_count workflows for $bot_count bots — consider consolidating"
  fi
}

# ═══════════════════════════════════════════════════════
# 5. Evolution Commit — Push improvements
# ═══════════════════════════════════════════════════════
commit_evolution() {
  if [ "$CHANGES" -gt 0 ]; then
    log INFO "💾 Committing $CHANGES improvements..."
    git add -A
    git commit -m "🧬 Self-Evolver: $CHANGES automated improvements

$(echo -e "$IMPROVEMENTS")

Auto-generated by Self-Evolver Bot" 2>/dev/null && log INFO "  ✅ Changes committed" || log WARN "  Nothing to commit"
  fi
}

# ═══════════════════════════════════════════════════════
# Run
# ═══════════════════════════════════════════════════════
analyze_performance
ai_review_bots
check_upgrades
commit_evolution

# Generate report
python3 -c "
lines = '''# 🧬 Self-Evolver Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Changes Made:** $CHANGES

## Improvements
$(echo -e "$IMPROVEMENTS" | head -20 || echo '- No improvements needed today')

## Bot Health Summary
$(state_get '.bot_health' '{}' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(f\"- **{k}**: {v.get(\"status\",\"unknown\")}\") for k,v in d.items()]' 2>/dev/null || echo '- No health data available')

## Evolution Log (Last 5)
$(state_get '.evolution_log' '[]' 2>/dev/null | python3 -c 'import json,sys; log=json.load(sys.stdin); [print(f\"- {e.get(\"timestamp\",\"?\")} — {e.get(\"change\",\"?\")}\") for e in log[-5:]]' 2>/dev/null || echo '- No history yet')

---
_Automated by Self-Evolver Bot 🧬_
'''
with open('$REPORT', 'w') as f:
    f.write(lines)
" 2>/dev/null

cat "$REPORT"
record_result "self-evolver" "success" "$CHANGES improvements"
log INFO "🧬 Self-Evolver done. $CHANGES changes."
