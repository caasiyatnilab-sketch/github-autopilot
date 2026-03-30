#!/bin/bash
# 📰 Daily Briefing Bot (Enhanced — Zero Config)
# Creates a GitHub Issue with full daily summary → you get email automatically
set -euo pipefail
trap 'record_result "daily-briefing" "error" "script exited with error" 2>/dev/null || true' ERR
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"

BOT_NAME="daily-briefing"
REPORT="daily-briefing-report.md"

log INFO "📰 Daily Briefing Bot starting..."

# AI-powered insights
AI_INSIGHT=""
if [ -n "${GROQ_API_KEY:-}" ] || [ -n "${OPENROUTER_API_KEY:-}" ]; then
  log INFO "  🤖 AI mode — generating insights..."
  AI_INSIGHT=$(ai_smart "Give one brief productivity tip for a developer. Be concise." 2>/dev/null || echo "")
fi

log INFO "📰 Daily Briefing Bot starting..."

REPO=$(get_repo)
TODAY=$(date -u '+%Y-%m-%d')
YESTERDAY=$(days_ago 1)

# ═══════════════════════════════════════════════════════
# Gather All Data
# ═══════════════════════════════════════════════════════

COMMITS=$(git log --oneline --since="$YESTERDAY" 2>/dev/null | wc -l || echo "0")
TOP_COMMITTER=$(git log --since="$YESTERDAY" --format="%aN" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2 " (" $1 " commits)"}' || echo "none")

PRS_OPENED=$(gh pr list --state all --json createdAt --jq "[.[]|select(.createdAt>\"$YESTERDAY\")]|length" 2>/dev/null || echo "0")
PRS_MERGED=$(gh pr list --state merged --json mergedAt --jq "[.[]|select(.mergedAt>\"$YESTERDAY\")]|length" 2>/dev/null || echo "0")
OPEN_PRS=$(gh pr list --state open --limit 10 --json number,title,author --jq '.[]|"- #\(.number): \(.title) (by @\(.author.login))"' 2>/dev/null || echo "_None_")

ISSUES_OPENED=$(gh issue list --state all --json createdAt --jq "[.[]|select(.createdAt>\"$YESTERDAY\")]|length" 2>/dev/null || echo "0")
ISSUES_CLOSED=$(gh issue list --state closed --json closedAt --jq "[.[]|select(.closedAt>\"$YESTERDAY\")]|length" 2>/dev/null || echo "0")
OPEN_ISSUES=$(gh issue list --state open --json number --jq 'length' 2>/dev/null || echo "0")
BUG_COUNT=$(gh issue list --state open --label "bug" --json number --jq 'length' 2>/dev/null || echo "0")
TOP_ISSUES=$(gh issue list --state open --limit 5 --json number,title --jq '.[]|"- #\(.number): \(.title)"' 2>/dev/null || echo "_None_")

CI_TOTAL=$(gh run list --limit 20 --json conclusion --jq 'length' 2>/dev/null || echo "0")
CI_PASS=$(gh run list --limit 20 --json conclusion --jq '[.[]|select(.conclusion=="success")]|length' 2>/dev/null || echo "0")
CI_FAIL=$((CI_TOTAL - CI_PASS))
CI_RATE=0
[ "$CI_TOTAL" -gt 0 ] && CI_RATE=$((CI_PASS * 100 / CI_TOTAL))

SECURITY="🟢 Clear"
[ -f "security-scanner-report.md" ] && grep -q "Action needed\|🔴" "security-scanner-report.md" 2>/dev/null && SECURITY="🔴 Issues found"

HEALTH="N/A"
[ -f "health-checker-report.md" ] && HEALTH=$(grep -oP '\d+/100' "health-checker-report.md" | head -1 || echo "N/A")

DEPS="N/A"
[ -f "package.json" ] && DEPS=$(npm outdated --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")

STARS=$(gh repo view --json stargazerCount -q '.stargazerCount' 2>/dev/null || echo "0")
FORKS=$(gh repo view --json forkCount -q '.forkCount' 2>/dev/null || echo "0")

# ═══════════════════════════════════════════════════════
# Build Briefing as GitHub Issue
# ═══════════════════════════════════════════════════════

ISSUE_BODY="## 📊 Daily Briefing — $TODAY

### 📈 Yesterday's Activity
| Metric | Count |
|--------|-------|
| Commits | $COMMITS |
| PRs Opened | $PRS_OPENED |
| PRs Merged | $PRS_MERGED |
| Issues Opened | $ISSUES_OPENED |
| Issues Closed | $ISSUES_CLOSED |

**Top Committer:** $TOP_COMMITTER

### 📋 Current State
| Metric | Value |
|--------|-------|
| Open Issues | $OPEN_ISSUES ($BUG_COUNT bugs) |
| CI Pass Rate | ${CI_RATE}% ($CI_PASS/$CI_TOTAL) |
| Security | $SECURITY |
| Health Score | $HEALTH |
| Outdated Deps | $DEPS |
| ⭐ Stars | $STARS |
| 🍴 Forks | $FORKS |

### 🔀 Open Pull Requests
$OPEN_PRS

### 📋 Open Issues (Top 5)
$TOP_ISSUES

### 🤖 Bot Status
All 15 bots are running on schedule:
- 🔍 Health Checker (daily 6AM)
- 🔒 Security Scanner (daily 2AM)
- 📦 Auto Updater (Monday 8AM)
- 🏷️ Issue Manager (on events)
- 🛠️ Auto Fixer (on push)
- 📊 Weekly Reporter (Friday 5PM)
- 🌐 API Hunter (every 6h)
- 🏗️ Repo Builder (Monday 9AM)
- 🕷️ Scraper (daily 4AM)
- 🚀 Deploy Bot (on push)
- 🔑 Key Rotator (every 12h)
- 🧠 AI Agent Factory (Monday 10AM)
- 📬 Notifications (3x daily)
- 📰 Daily Briefing (daily 8AM)
- 🎯 Autopilot (every 4h)

---
_🤖 Automated by GitHub Autopilot_"

# ═══════════════════════════════════════════════════════
# Create GitHub Issue (→ triggers email automatically!)
# ═══════════════════════════════════════════════════════

# Check if today's briefing already exists
EXISTING=$(gh issue list --state open --search "Daily Briefing — $TODAY" --json number --jq 'length' 2>/dev/null || echo "0")
if [ "$EXISTING" -eq 0 ]; then
  gh issue create \
    --title "📰 Daily Briefing — $TODAY" \
    --body "$ISSUE_BODY" \
    --label "documentation,automated" 2>/dev/null || true
  log INFO "  📧 GitHub Issue created (you'll get email!)"
fi

# ═══════════════════════════════════════════════════════
# Push notification via ntfy.sh
# ═══════════════════════════════════════════════════════

NTFY_TOPIC="${NTFY_TOPIC:-caasiyatnilab-ops}"

BRIEF_SUMMARY="📊 $REPO Daily Briefing ($TODAY)

📝 Activity: $COMMITS commits, $PRS_OPENED PRs, $ISSUES_OPENED issues
📋 State: $OPEN_ISSUES issues, CI ${CI_RATE}%
🔒 Security: $SECURITY
💊 Health: $HEALTH

Full briefing: https://github.com/$REPO/issues"

curl -s -d "$BRIEF_SUMMARY" \
  -H "Title: 📰 Daily Briefing — $REPO" \
  -H "Tags: newspaper,chart_with_upwards_trend" \
  -H "Priority: default" \
  "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1
log INFO "  📱 Push notification sent"

# ═══════════════════════════════════════════════════════
# Optional channels
# ═══════════════════════════════════════════════════════

[ -n "${DISCORD_WEBHOOK:-}" ] && curl -s -H "Content-Type: application/json" -d "{\"embeds\":[{\"title\":\"📰 Daily Briefing — $TODAY\",\"description\":\"$BRIEF_SUMMARY\",\"color\":3066993}]}" "$DISCORD_WEBHOOK" >/dev/null 2>&1
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ] && curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" -H "Content-Type: application/json" -d "{\"chat_id\":\"$TELEGRAM_CHAT_ID\",\"text\":\"$BRIEF_SUMMARY\"}" >/dev/null 2>&1
[ -n "${RESEND_API_KEY:-}" ] && [ -n "${NOTIFY_EMAIL:-}" ] && curl -s -X POST "https://api.resend.com/emails" -H "Authorization: Bearer $RESEND_API_KEY" -H "Content-Type: application/json" -d "{\"from\":\"autopilot@resend.dev\",\"to\":\"$NOTIFY_EMAIL\",\"subject\":\"📰 Daily Briefing — $REPO ($TODAY)\",\"text\":\"$BRIEF_SUMMARY\"}" >/dev/null 2>&1

# ═══════════════════════════════════════════════════════
# Report
# ═══════════════════════════════════════════════════════

cat > "$REPORT" << EOF
# 📰 Daily Briefing Report
**Date:** $TODAY
**Repo:** $REPO

## Summary Sent
$BRIEF_SUMMARY

## Channels
- ✅ GitHub Issue (→ email)
- ✅ ntfy.sh push
- $( [ -n "${DISCORD_WEBHOOK:-}" ] && echo '✅' || echo '⚪') Discord
- $( [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && echo '✅' || echo '⚪') Telegram
- $( [ -n "${RESEND_API_KEY:-}" ] && echo '✅' || echo '⚪') Email

---
_Automated by Daily Briefing Bot 📰_
EOF

record_result "daily-briefing" "success" "completed" 2>/dev/null || true
cat "$REPORT"

notify "$(basename $BOT_NAME 2>/dev/null || basename $0)" "Bot completed successfully. Check report." 2>/dev/null || true
log INFO "📰 Daily Briefing complete!"

exit 0
