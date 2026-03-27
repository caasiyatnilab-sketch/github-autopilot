#!/bin/bash
# 🎯 Autopilot — Master Orchestrator
# Coordinates all bots, monitors health, ensures nothing breaks
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="autopilot"
REPORT="autopilot-report.md"
acquire_lock "$BOT_NAME" || exit 0

log INFO "🎯 Autopilot orchestrator starting..."

# ═══════════════════════════════════════════════════════
# Bot Health Check
# ═══════════════════════════════════════════════════════
check_bot_health() {
  local bot="$1"
  local script="$2"

  if [ ! -f "$script" ]; then
    echo "❌ $bot — script missing"
    return 1
  fi

  if ! bash -n "$script" 2>/dev/null; then
    echo "❌ $bot — syntax error"
    return 1
  fi

  echo "✅ $bot — healthy"
  return 0
}

# ═══════════════════════════════════════════════════════
# Repository Overview
# ═══════════════════════════════════════════════════════
repo_overview() {
  local repos
  repos=$(gh repo list --limit 50 --json name,primaryLanguage,stargazerCount,isPrivate,updatedAt \
    --jq '.[] | "\(.name)\t\(.primaryLanguage.name // "n/a")\t⭐\(.stargazerCount)\t\(.updatedAt | split("T")[0])"' 2>/dev/null || echo "Could not list repos")

  echo "$repos"
}

# ═══════════════════════════════════════════════════════
# System Health
# ═══════════════════════════════════════════════════════
system_health() {
  local issues=()
  local successes=()

  # Check GitHub API
  local rate=$(gh api rate_limit --jq '.rate.remaining' 2>/dev/null || echo "0")
  if [ "$rate" -gt 100 ]; then
    successes+=("GitHub API: $rate requests remaining")
  elif [ "$rate" -gt 0 ]; then
    issues+=("GitHub API: Only $rate requests remaining — consider slowing down")
  else
    issues+=("GitHub API: Rate limited!")
  fi

  # Check secrets
  local secrets_list=$(gh secret list 2>/dev/null || echo "")
  if [ -n "$secrets_list" ]; then
    successes+=("GitHub Secrets configured")
  else
    issues+=("No GitHub Secrets configured — add API keys for full functionality")
  fi

  # Check Actions
  local recent_runs=$(gh run list --limit 5 --json conclusion --jq '[.[] | select(.conclusion == "failure")] | length' 2>/dev/null || echo "0")
  if [ "$recent_runs" -eq 0 ]; then
    successes+=("Recent Actions: all passing")
  else
    issues+=("Recent Actions: $recent_runs failures in last 5 runs")
  fi

  # Return results
  for s in "${successes[@]}"; do echo "SUCCESS:$s"; done
  for i in "${issues[@]}"; do echo "ISSUE:$i"; done
}

# ═══════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════

echo "# 🎯 Autopilot Status Report" > "$REPORT"
echo "" >> "$REPORT"
echo "**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')" >> "$REPORT"
echo "**Repo:** $(get_repo)" >> "$REPORT"
echo "" >> "$REPORT"

# Bot health
echo "## 🤖 Bot Health" >> "$REPORT"
echo "" >> "$REPORT"

BOTS_HEALTHY=0
BOTS_TOTAL=0

for bot_dir in bots/*/; do
  bot_name=$(basename "$bot_dir")
  script="$bot_dir/scripts/${bot_name}.sh"

  BOTS_TOTAL=$((BOTS_TOTAL + 1))
  result=$(check_bot_health "$bot_name" "$script" 2>&1)
  echo "- $result" >> "$REPORT"

  if echo "$result" | grep -q "✅"; then
    BOTS_HEALTHY=$((BOTS_HEALTHY + 1))
  fi
done
echo "" >> "$REPORT"

# System health
echo "## 💚 System Health" >> "$REPORT"
echo "" >> "$REPORT"

while IFS= read -r line; do
  if echo "$line" | grep -q "^SUCCESS:"; then
    echo "- ✅ $(echo "$line" | cut -d: -f2-)" >> "$REPORT"
  elif echo "$line" | grep -q "^ISSUE:"; then
    echo "- ⚠️ $(echo "$line" | cut -d: -f2-)" >> "$REPORT"
  fi
done < <(system_health)
echo "" >> "$REPORT"

# Repository overview
echo "## 📂 Your Repositories" >> "$REPORT"
echo "" >> "$REPORT"
echo '```' >> "$REPORT"
repo_overview >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# Recommendations
echo "## 💡 Recommendations" >> "$REPORT"
echo "" >> "$REPORT"

if [ "$BOTS_HEALTHY" -lt "$BOTS_TOTAL" ]; then
  echo "- Some bots need attention. Run individual bot scripts to diagnose." >> "$REPORT"
fi

echo "- Schedule: All bots run automatically via GitHub Actions" >> "$REPORT"
echo "- Manual: Run any bot with \`gh workflow run <bot-name>.yml\`" >> "$REPORT"
echo "- Config: Edit \`.github/autopilot.yml\` to customize" >> "$REPORT"
echo "" >> "$REPORT"

echo "---" >> "$REPORT"
echo "" >> "$REPORT"
echo "**Bot Health: $BOTS_HEALTHY/$BOTS_TOTAL healthy**" >> "$REPORT"
echo "" >> "$REPORT"
echo "_Automated by Autopilot 🎯_" >> "$REPORT"

cat "$REPORT"
log INFO "🎯 Autopilot complete! $BOTS_HEALTHY/$BOTS_TOTAL bots healthy."
