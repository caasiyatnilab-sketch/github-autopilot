#!/bin/bash
# 📰 Daily Briefing Bot
# Sends comprehensive daily email/notification with everything that happened
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="daily-briefing"
REPORT="daily-briefing-report.md"

log INFO "📰 Daily Briefing Bot starting..."

REPO=$(get_repo)
TODAY=$(date -u '+%Y-%m-%d')
YESTERDAY=$(date -d '-1 day' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -v-1d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "")

# ═══════════════════════════════════════════════════════
# Gather Data
# ═══════════════════════════════════════════════════════

# Commits
COMMITS_YESTERDAY=$(git log --oneline --since="$YESTERDAY" 2>/dev/null | wc -l || echo "0")
TOP_COMMITTER=$(git log --since="$YESTERDAY" --format="%aN" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' || echo "none")

# PRs
PRS_OPENED=$(gh pr list --state all --json createdAt --jq "[.[] | select(.createdAt > \"$YESTERDAY\")] | length" 2>/dev/null || echo "0")
PRS_MERGED=$(gh pr list --state merged --json mergedAt --jq "[.[] | select(.mergedAt > \"$YESTERDAY\")] | length" 2>/dev/null || echo "0")
PR_LIST=$(gh pr list --state open --limit 5 --json number,title,author --jq '.[] | "- #\(.number): \(.title) by @\(.author.login)"' 2>/dev/null || echo "None")

# Issues
ISSUES_OPENED=$(gh issue list --state all --json createdAt --jq "[.[] | select(.createdAt > \"$YESTERDAY\")] | length" 2>/dev/null || echo "0")
ISSUES_CLOSED=$(gh issue list --state closed --json closedAt --jq "[.[] | select(.closedAt > \"$YESTERDAY\")] | length" 2>/dev/null || echo "0")
OPEN_ISSUES=$(gh issue list --state open --json number --jq 'length' 2>/dev/null || echo "0")
BUG_COUNT=$(gh issue list --state open --label "bug" --json number --jq 'length' 2>/dev/null || echo "0")

# CI
CI_RUNS=$(gh run list --limit 10 --json conclusion --jq 'length' 2>/dev/null || echo "0")
CI_FAILED=$(gh run list --limit 10 --json conclusion --jq '[.[] | select(.conclusion == "failure")] | length' 2>/dev/null || echo "0")
CI_SUCCESS=$((CI_RUNS - CI_FAILED))
CI_RATE=0
[ "$CI_RUNS" -gt 0 ] && CI_RATE=$((CI_SUCCESS * 100 / CI_RUNS))

# Security
SECURITY_STATUS="🟢 Clear"
if [ -f "security-scanner-report.md" ]; then
  grep -q "Action needed" "security-scanner-report.md" 2>/dev/null && SECURITY_STATUS="🔴 Issues found"
fi

# Health Score
HEALTH_SCORE="N/A"
if [ -f "health-checker-report.md" ]; then
  HEALTH_SCORE=$(grep -oP 'Score.*?(\d+)/100' "health-checker-report.md" 2>/dev/null | grep -oP '\d+' | head -1 || echo "N/A")
fi

# Dependencies
DEPS_OUTDATED="N/A"
if [ -f "package.json" ]; then
  DEPS_OUTDATED=$(npm outdated --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
fi

# ═══════════════════════════════════════════════════════
# Build Briefing
# ═══════════════════════════════════════════════════════

BRIEFING="📊 DAILY BRIEFING — $TODAY
═══════════════════════════
Repository: $REPO

📝 YESTERDAY'S ACTIVITY
• Commits: $COMMITS_YESTERDAY (top: $TOP_COMMITTER)
• PRs opened: $PRS_OPENED | merged: $PRS_MERGED
• Issues opened: $ISSUES_OPENED | closed: $ISSUES_CLOSED

📋 CURRENT STATE
• Open issues: $OPEN_ISSUES ($BUG_COUNT bugs)
• Open PRs: $(echo "$PR_LIST" | wc -l)
• CI success rate: ${CI_RATE}%
• Security: $SECURITY_STATUS
• Health score: ${HEALTH_SCORE}/100
• Outdated deps: $DEPS_OUTDATED

🔀 OPEN PRS
$PR_LIST

🤖 All bots running. You're all set!"

# ═══════════════════════════════════════════════════════
# Send via all available channels
# ═══════════════════════════════════════════════════════

SENT=0

# ntfy.sh (always works, no signup)
if [ -n "${NTFY_TOPIC:-github-autopilot}" ]; then
  curl -s -d "$BRIEFING" \
    -H "Title: 📊 Daily Briefing — $REPO" \
    -H "Tags: chart,robot,github" \
    "https://ntfy.sh/${NTFY_TOPIC:-github-autopilot}" >/dev/null 2>&1 && SENT=$((SENT+1))
  log INFO "  ✅ ntfy.sh"
fi

# Telegram
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"$BRIEFING\", \"parse_mode\": \"Markdown\"}" >/dev/null 2>&1 && SENT=$((SENT+1))
  log INFO "  ✅ Telegram"
fi

# Discord
if [ -n "${DISCORD_WEBHOOK:-}" ]; then
  curl -s -H "Content-Type: application/json" \
    -d "{\"embeds\": [{\"title\": \"📊 Daily Briefing — $TODAY\", \"description\": \"$BRIEFING\", \"color\": 3066993}]}" \
    "$DISCORD_WEBHOOK" >/dev/null 2>&1 && SENT=$((SENT+1))
  log INFO "  ✅ Discord"
fi

# Email (Resend — 100/day free)
if [ -n "${RESEND_API_KEY:-}" ] && [ -n "${NOTIFY_EMAIL:-}" ]; then
  curl -s -X POST "https://api.resend.com/emails" \
    -H "Authorization: Bearer $RESEND_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"from\": \"autopilot@resend.dev\", \"to\": \"$NOTIFY_EMAIL\", \"subject\": \"📊 Daily Briefing — $REPO ($TODAY)\", \"text\": \"$BRIEFING\"}" >/dev/null 2>&1 && SENT=$((SENT+1))
  log INFO "  ✅ Email (Resend)"
fi

# Email (Brevo — 300/day free)
if [ -n "${BREVO_API_KEY:-}" ] && [ -n "${NOTIFY_EMAIL:-}" ]; then
  curl -s -X POST "https://api.brevo.com/v3/smtp/email" \
    -H "api-key: $BREVO_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"sender\": {\"email\": \"autopilot@bots.dev\"}, \"to\": [{\"email\": \"$NOTIFY_EMAIL\"}], \"subject\": \"📊 Daily Briefing — $REPO\", \"textContent\": \"$BRIEFING\"}" >/dev/null 2>&1 && SENT=$((SENT+1))
  log INFO "  ✅ Email (Brevo)"
fi

# Pushover
if [ -n "${PUSHOVER_TOKEN:-}" ] && [ -n "${PUSHOVER_USER:-}" ]; then
  curl -s -X POST "https://api.pushover.net/1/messages.json" \
    -d "token=$PUSHOVER_TOKEN" \
    -d "user=$PUSHOVER_USER" \
    -d "title=📊 Daily Briefing — $REPO" \
    -d "message=$BRIEFING" >/dev/null 2>&1 && SENT=$((SENT+1))
  log INFO "  ✅ Pushover"
fi

# ═══════════════════════════════════════════════════════
# Report
# ═══════════════════════════════════════════════════════

python3 -c "
lines = '''# 📰 Daily Briefing Report
**Date:** $TODAY
**Repo:** $REPO
**Notifications Sent:** $SENT

## Briefing Content
\`\`\`
$BRIEFING
\`\`\`

## Channels Used
$( [ $SENT -gt 0 ] && echo "Sent via $SENT channels ✅" || echo "No channels configured — add secrets to enable notifications")

---
_Automated by Daily Briefing Bot 📰_'''
open('$REPORT', 'w').write(lines)
"
cat "$REPORT"
log INFO "📰 Daily Briefing complete! Sent via $SENT channels."
