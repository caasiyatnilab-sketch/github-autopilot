#!/bin/bash
# 🎓 Bot Trainer
# Reads all bot reports, scores each bot, generates improvement plans
# Uses AI to analyze patterns and write training patches
# Tracks improvement over time in shared state
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"

REPORT="bot-trainer-report.md"
BOT_NAME="bot-trainer"
log INFO "🎓 Bot Trainer starting..."

IMPROVEMENTS=0
TRAINING_LOG=""

# ═══════════════════════════════════════════════════════
# 1. Score Every Bot
# ═══════════════════════════════════════════════════════
score_bots() {
  log INFO "📊 Scoring all bots..."

  python3 << 'PYEOF'
import os, json, glob, subprocess

bots_dir = "bots"
results = []

for bot_name in sorted(os.listdir(bots_dir)):
    script = os.path.join(bots_dir, bot_name, "scripts", f"{bot_name}.sh")
    if not os.path.exists(script):
        continue

    score = 100
    issues = []
    strengths = []

    with open(script) as f:
        content = f.read()
        lines = content.split("\n")

    # ── Structure checks ──
    if not lines[0].startswith("#!"):
        score -= 10; issues.append("Missing shebang")
    else:
        strengths.append("Has shebang")

    if "set -" not in content:
        score -= 10; issues.append("No error handling (set -e/u/o)")
    else:
        strengths.append("Error handling enabled")

    if "source" not in content or "utils.sh" not in content:
        score -= 10; issues.append("Not using shared utils")
    else:
        strengths.append("Uses shared utils")

    if "state.sh" not in content:
        score -= 5; issues.append("Not using shared state (no cross-bot coordination)")
    else:
        strengths.append("Uses shared state")

    if "record_result" not in content:
        score -= 5; issues.append("No health reporting")
    else:
        strengths.append("Reports health status")

    # ── AI usage ──
    ai_funcs = ["ai_smart", "ai_ask", "ai_code", "ai_review", "_call_ollama", "_call_openrouter"]
    uses_ai = any(f in content for f in ai_funcs)
    if uses_ai:
        strengths.append("AI-powered")

    # ── Report generation ──
    report_file = f"{bot_name}-report.md"
    has_report = os.path.exists(report_file)
    if has_report:
        report_size = os.path.getsize(report_file)
        if report_size > 100:
            strengths.append(f"Generates reports ({report_size}B)")
        else:
            score -= 5; issues.append("Report exists but is too small (<100B)")
    else:
        score -= 10; issues.append("No report file generated")

    # ── Robustness ──
    if "trap " in content:
        strengths.append("Has cleanup traps")
    if "retry" in content.lower() or "backoff" in content.lower():
        strengths.append("Has retry logic")
    if "log " in content:
        strengths.append("Has logging")

    # ── Code quality ──
    line_count = len(lines)
    if line_count > 500:
        score -= 5; issues.append(f"Very long script ({line_count} lines) — consider modularizing")
    if line_count < 20:
        score -= 10; issues.append(f"Very short script ({line_count} lines) — may be a stub")

    # ── Hardcoded values ──
    import re
    hardcoded_keys = re.findall(r'(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,})', content)
    if hardcoded_keys:
        score -= 20; issues.append(f"⚠️ HARDCODED API KEY FOUND — security risk!")

    score = max(0, min(100, score))

    results.append({
        "name": bot_name,
        "score": score,
        "ai": uses_ai,
        "has_report": has_report,
        "lines": line_count,
        "issues": issues,
        "strengths": strengths,
    })

# Print results
print("| Bot | Score | AI | Report | Lines |")
print("|-----|-------|----|----|-------|")
for r in sorted(results, key=lambda x: x["score"]):
    ai = "🤖" if r["ai"] else "⚙️"
    report = "📄" if r["has_report"] else "❌"
    grade = "🟢" if r["score"] >= 80 else "🟡" if r["score"] >= 60 else "🔴"
    print(f"| {grade} {r['name']} | {r['score']}/100 | {ai} | {report} | {r['lines']} |")

print("\n── Bots Needing Attention ──")
for r in sorted(results, key=lambda x: x["score"]):
    if r["score"] < 80 and r["issues"]:
        print(f"\n**{r['name']}** ({r['score']}/100):")
        for issue in r["issues"]:
            print(f"  ❌ {issue}")

print("\n── Top Performers ──")
for r in sorted(results, key=lambda x: -x["score"])[:5]:
    print(f"  🏆 {r['name']} ({r['score']}/100): {', '.join(r['strengths'][:3])}")

# Save scores to shared state
try:
    state_file = ".github/bot-state.json"
    with open(state_file) as f:
        state = json.load(f)
    state["bot_scores"] = {r["name"]: r["score"] for r in results}
    state["last_training"] = subprocess.check_output(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"]).decode().strip()
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
except:
    pass

# Output issues for bash to process
print("\n__ISSUES_START__")
for r in results:
    if r["issues"]:
        for issue in r["issues"]:
            print(f"{r['name']}|{issue}")
print("__ISSUES_END__")
PYEOF
}

# ═══════════════════════════════════════════════════════
# 2. Auto-Train: Fix Common Issues
# ═══════════════════════════════════════════════════════
auto_train() {
  log INFO "🔧 Auto-training bots..."

  for bot_dir in bots/*/; do
    bot_name=$(basename "$bot_dir")
    script="bots/$bot_name/scripts/$bot_name.sh"
    [ -f "$script" ] || continue

    local trained=false

    # Train 1: Add report generation if missing
    if [ ! -f "${bot_name}-report.md" ] && ! grep -q "REPORT=" "$script"; then
      sed -i "/^source.*utils.sh/a REPORT=\"${bot_name}-report.md\"" "$script"
      TRAINING_LOG="$TRAINING_LOG\n- 📄 Added report generation to $bot_name"
      IMPROVEMENTS=$((IMPROVEMENTS + 1))
      trained=true
    fi

    # Train 2: Add logging if missing
    if ! grep -q "log INFO" "$script"; then
      sed -i "/^source.*utils.sh/a log INFO \"$bot_name starting...\"" "$script"
      TRAINING_LOG="$TRAINING_LOG\n- 📝 Added startup logging to $bot_name"
      IMPROVEMENTS=$((IMPROVEMENTS + 1))
      trained=true
    fi

    # Train 3: Add cleanup trap if missing
    if ! grep -q "trap " "$script"; then
      local bot_var=$(grep -o 'BOT="[^"]*"' "$script" | head -1 | cut -d'"' -f2)
      [ -z "$bot_var" ] && bot_var="$bot_name"
      sed -i "/^set -/a trap 'log WARN \"$bot_name interrupted\"; exit 1' INT TERM" "$script"
      TRAINING_LOG="$TRAINING_LOG\n- 🛡️ Added interrupt trap to $bot_name"
      IMPROVEMENTS=$((IMPROVEMENTS + 1))
      trained=true
    fi

    if [ "$trained" = true ]; then
      log_evolution "Trained $bot_name: added missing boilerplate"
    fi
  done
}

# ═══════════════════════════════════════════════════════
# 3. AI Training (rate-limited: 1 bot per run)
# ═══════════════════════════════════════════════════════
ai_train() {
  if ! has_ai_provider; then
    log INFO "  ⚪ No AI — skipping AI training"
    return 0
  fi

  # Check cache
  local last_train=$(state_get ".shared_data.trainer.last_ai_train" "never")
  local today=$(date -u '+%Y-%m-%d')
  [ "$last_train" = "$today" ] && log INFO "  📋 AI training already done today" && return 0

  log INFO "  🤖 Running AI training session..."

  # Pick lowest-scoring bot
  local worst_bot=$(state_get ".bot_scores" "{}" | python3 -c "
import json, sys
scores = json.load(sys.stdin)
if scores:
    worst = min(scores, key=scores.get)
    print(worst)
" 2>/dev/null)

  [ -z "$worst_bot" ] && return 0

  local script="bots/$worst_bot/scripts/$worst_bot.sh"
  [ -f "$script" ] || return 0

  local code_snippet=$(head -80 "$script")
  local suggestion=$(ai_smart "You are a bash code trainer. This bot script has issues. Give 2 specific improvements with exact code snippets to add. Bot name: $worst_bot. Code: $code_snippet" "code" 2>/dev/null || echo "")

  if [ -n "$suggestion" ] && [ ${#suggestion} -gt 30 ]; then
    TRAINING_LOG="$TRAINING_LOG\n- 🤖 AI training for **$worst_bot**: $(echo "$suggestion" | head -3)"
    share_data "trainer" "last_ai_train" "$today"
    log_evolution "AI trained $worst_bot"
    log INFO "  ✅ AI training complete for $worst_bot"
  fi
}

# ═══════════════════════════════════════════════════════
# 4. Generate Training Report
# ═══════════════════════════════════════════════════════
generate_report() {
  local scores_output
  scores_output=$(score_bots 2>&1)

  cat > "$REPORT" << REPORT_EOF
# 🎓 Bot Trainer Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Improvements Made:** $IMPROVEMENTS

## Bot Scoreboard
$scores_output

## Training Applied
$(echo -e "$TRAINING_LOG" | head -20 || echo "- No training needed today")

## Improvement Trends
$(state_get '.evolution_log' '[]' | python3 -c "
import json, sys
log = json.load(sys.stdin)
training = [e for e in log if 'Trained' in e.get('change','')]
if training:
    for e in training[-5:]:
        print(f\"- {e['timestamp']}: {e['change']}\")
else:
    print('- No training history yet')
" 2>/dev/null || echo "- No history")

## Recommendations
$(echo "$scores_output" | grep -A1 "Bots Needing Attention" | tail -1 || echo "- All bots performing well")

---
_Automated by Bot Trainer 🎓_
REPORT_EOF
}

# ═══════════════════════════════════════════════════════
# Run
# ═══════════════════════════════════════════════════════
score_bots
auto_train
ai_train
generate_report

cat "$REPORT"
record_result "$BOT_NAME" "success" "$IMPROVEMENTS training improvements"
log INFO "🎓 Bot Trainer done. $IMPROVEMENTS improvements."
