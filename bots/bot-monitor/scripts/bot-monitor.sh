#!/bin/bash
set -euo pipefail
trap 'record_result "bot-monitor" "error" "script exited with error" 2>/dev/null || true' ERR
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"
BOT="bot-monitor"; REPORT="bot-monitor-report.md"
REPO="$(get_repo)"
log INFO "🤖 Bot Monitor starting..."

# List of all bots to monitor
BOTS=(
  "health-checker"
  "security-scanner" 
  "auto-updater"
  "issue-pr-manager"
  "auto-fixer"
  "weekly-reporter"
  "api-hunter"
  "repo-builder"
  "scraper-bot"
  "deploy-bot"
  "mega-deploy"
  "copilot-rotator"
  "ai-agent-factory"
  "ai-agent-pro"
  "notification-bot"
  "daily-briefing"
  "autopilot"
  "creator-bot"
  "bot-brain"
  "free-api-hunter"
  "project-creator"
  "qa-bot"
)

# Get workflow runs for all bots
log INFO "Fetching workflow runs for ${#BOTS[@]} bots..."
MONITOR_DATA=""

for bot in "${BOTS[@]}"; do
  # Get recent runs (last 5) for this bot
  RUNS_JSON=$(gh run list --repo "$REPO" --limit 5 --json name,conclusion,createdAt,url,databaseId --jq --raw-output "
    .[] | select(.name | test(\"${bot}\", \"i\")) | 
    {name: .name, conclusion: .conclusion, createdAt: .createdAt, url: .url, id: .databaseId}
  " 2>/dev/null || echo "[]")
  
  # Parse the JSON to get stats
  if [ "$RUNS_JSON" != "[]" ] && [ -n "$RUNS_JSON" ]; then
    TOTAL=$(echo "$RUNS_JSON" | jq 'length' 2>/dev/null || echo "0")
    SUCCESS=$(echo "$RUNS_JSON" | jq '[.[] | select(.conclusion == "success")] | length' 2>/dev/null || echo "0")
    FAILURE=$(echo "$RUNS_JSON" | jq '[.[] | select(.conclusion == "failure")] | length' 2>/dev/null || echo "0")
    CANCELLED=$(echo "$RUNS_JSON" | jq '[.[] | select(.conclusion == "cancelled")] | length' 2>/dev/null || echo "0")
    
    # Get latest run info
    LATEST=$(echo "$RUNS_JSON" | jq '.[0]' 2>/dev/null || echo 'null')
    LATEST_STATUS=$(echo "$LATEST" | jq -r '.conclusion // "unknown"' 2>/dev/null || echo "unknown")
    LATEST_TIME=$(echo "$LATEST" | jq -r '.createdAt // ""' 2>/dev/null || echo "")
    LATEST_ID=$(echo "$LATEST" | jq -r '.id // ""' 2>/dev/null || echo "")
    
    # Calculate success rate
    if [ "$TOTAL" -gt 0 ]; then
      SUCCESS_RATE=$((SUCCESS * 100 / TOTAL))
    else
      SUCCESS_RATE=0
    fi
    
    # Determine status emoji
    if [ "$LATEST_STATUS" = "success" ]; then
      STATUS_EMOJI="✅"
    elif [ "$LATEST_STATUS" = "failure" ]; then
      STATUS_EMOJI="❌"
    elif [ "$LATEST_STATUS" = "cancelled" ]; then
      STATUS_EMOJI="⏸️"
    else
      STATUS_EMOJI="❓"
    fi
    
    # Add to monitor data
    MONITOR_DATA="$MONITOR_DATA
| $bot | $STATUS_EMOJI $LATEST_STATUS | $SUCCESS_RATE% | $SUCCESS/$TOTAL | $(time_ago "$LATEST_TIME") |"
  else
    # No runs found
    MONITOR_DATA="$MONITOR_DATA
| $bot | ⚪ unknown | 0% | 0/0 | Never |"
  fi
done

# Generate report
cat > "$REPORT" << EOF
# 🤖 Bot Monitor Report
**Generated:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repository:** $REPO

## 📊 Bot Performance Overview

| Bot | Status | Success Rate | Runs (S/T) | Last Run |
|-----|--------|--------------|------------|----------|
$MONITOR_DATA

## 📈 Summary Statistics
EOF

# Calculate overall stats
TOTAL_BOTS=${#BOTS[@]}
ACTIVE_BOTS=0
HEALTHY_BOTS=0

# Re-parse for summary
for bot in "${BOTS[@]}"; do
  RUNS_JSON=$(gh run list --repo "$REPO" --limit 5 --json name,conclusion --jq --raw-output "
    .[] | select(.name | test(\"${bot}\", \"i\")) | 
    {name: .name, conclusion: .conclusion}
  " 2>/dev/null || echo "[]")
  
  if [ "$RUNS_JSON" != "[]" ] && [ -n "$RUNS_JSON" ]; then
    TOTAL=$(echo "$RUNS_JSON" | jq 'length' 2>/dev/null || echo "0")
    if [ "$TOTAL" -gt 0 ]; then
      ACTIVE_BOTS=$((ACTIVE_BOTS + 1))
      SUCCESS=$(echo "$RUNS_JSON" | jq '[.[] | select(.conclusion == "success")] | length' 2>/dev/null || echo "0")
      SUCCESS_RATE=$((SUCCESS * 100 / TOTAL))
      if [ "$SUCCESS_RATE" -ge 80 ]; then
        HEALTHY_BOTS=$((HEALTHY_BOTS + 1))
      fi
    fi
  fi
done

INACTIVE_BOTS=$((TOTAL_BOTS - ACTIVE_BOTS))
UNHEALTHY_BOTS=$((ACTIVE_BOTS - HEALTHY_BOTS))

cat >> "$REPORT" << EOF

- **Total Bots Monitored:** $TOTAL_BOTS
- **Active Bots (with runs):** $ACTIVE_BOTS
- **Healthy Bots (≥80% success):** $HEALTHY_BOTS
- **Unhealthy Bots (<80% success):** $UNHEALTHY_BOTS
- **Inactive Bots (no runs):** $INACTIVE_BOTS

## 🚨 Alerts & Recommendations
EOF

# Check for issues
if [ "$UNHEALTHY_BOTS" -gt 0 ]; then
  echo "- ⚠️ **$UNHEALTHY_BOTS bot(s) have success rate below 80%** - Consider investigating failures" >> "$REPORT"
fi

if [ "$INACTIVE_BOTS" -gt 0 ]; then
  echo "- ℹ️ **$INACTIVE_BOTS bot(s) have no recent runs** - May be scheduled for specific times or manually triggered" >> "$REPORT"
fi

# Check for recently failed bots
FAILED_BOTS=""
for bot in "${BOTS[@]}"; do
  LATEST_STATUS=$(gh run list --repo "$REPO" --limit 1 --json name,conclusion --jq --raw-output "
    .[] | select(.name | test(\"${bot}\", \"i\")) | .conclusion
  " 2>/dev/null || echo "unknown")
  
  if [ "$LATEST_STATUS" = "failure" ]; then
    FAILED_BOTS="$FAILED_BOTS $bot"
  fi
done

if [ -n "$FAILED_BOTS" ]; then
  echo "- ❌ **Recently failed bots:**$FAILED_BOTS" >> "$REPORT"
  echo "  - Consider checking logs and fixing issues" >> "$REPORT"
fi

# Add AI-powered insights
log INFO "Generating AI-powered insights..."
AI_INSIGHTS=$(ai_smart "Based on the bot performance data, provide 3 specific actionable recommendations to improve overall bot reliability and performance. Focus on patterns, common failure points, and optimization opportunities." "analysis" 2>/dev/null || echo "")

if [ -n "$AI_INSIGHTS" ]; then
  echo "" >> "$REPORT"
  echo "## 💡 AI-Powered Insights" >> "$REPORT"
  echo "$AI_INSIGHTS" >> "$REPORT"
fi

# Final summary
echo "" >> "$REPORT"
echo "## 📋 Next Steps" >> "$REPORT"
echo "1. Review any failed or unhealthy bots" >> "$REPORT"
echo "2. Consider adding auto-retry mechanisms for flaky bots" >> "$REPORT"
echo "3. Monitor trends over time to detect degradation early" >> "$REPORT"
echo "4. Share this report with team stakeholders" >> "$REPORT"

record_result "bot-monitor" "success" "completed" 2>/dev/null || true
cat "$REPORT"

# Determine if we should alert on degradation
DEGRADATION_THRESHOLD=50  # Alert if more than 50% of active bots are unhealthy
if [ "$ACTIVE_BOTS" -gt 0 ]; then
  UNHEALTHY_PERCENT=$((UNHEALTHY_BOTS * 100 / ACTIVE_BOTS))
  if [ "$UNHEALTHY_PERCENT" -ge "$DEGRADATION_THRESHOLD" ]; then
    echo "BOT_DEGRADATION=true" >> "$GITHUB_ENV"
    log WARN "Bot degradation detected: $UNHEALTHY_PERCENT% of active bots unhealthy"
  else
    log INFO "Bot health OK: $UNHEALTHY_PERCENT% of active bots unhealthy"
  fi
else
  log INFO "No active bot runs to evaluate"
fi

notify "$BOT" "Bot Monitor completed. $HEALTHY_BOTS/$ACTIVE_BOTS bots healthy." 2>/dev/null || true
log INFO "🤖 Bot Monitor completed successfully"
exit 0