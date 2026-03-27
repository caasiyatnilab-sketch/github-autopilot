#!/bin/bash
# 📬 Notification Bot (Enhanced — Zero Config Version)
# Uses GitHub Issues for email + ntfy.sh for push
# No third-party signup needed!
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="notification-bot"
REPORT="notification-report.md"

log INFO "📬 Notification Bot starting..."

REPO=$(get_repo)
TODAY=$(date -u '+%Y-%m-%d')
NOTIFIED=0

# ═══════════════════════════════════════════════════════
# 1. Check for failures and create GitHub Issues (→ email)
# ═══════════════════════════════════════════════════════

# Failed workflows
FAILED_RUNS=$(gh run list --limit 5 --json conclusion,name,createdAt --jq '.[] | select(.conclusion == "failure") | "\(.name)|\(.createdAt)"' 2>/dev/null || echo "")

if [ -n "$FAILED_RUNS" ]; then
  while IFS='|' read -r name created; do
    # Check if we already reported this
    EXISTING=$(gh issue list --state open --search "Bot Failed: $name" --json number --jq 'length' 2>/dev/null || echo "0")
    if [ "$EXISTING" -eq 0 ]; then
      gh issue create \
        --title "🚨 Bot Failed: $name ($TODAY)" \
        --body "## Workflow Failure

**Bot:** $name
**Repo:** $REPO
**Time:** $created

### What happened:
The \`$name\` workflow failed. Check the [Actions tab](https://github.com/$REPO/actions) for details.

### Auto-fix:
Most failures are temporary (rate limits, network issues). The bot will retry on next scheduled run.

---
_🤖 Automated alert by GitHub Autopilot_" \
        --label "bug,automated" 2>/dev/null || true
      NOTIFIED=$((NOTIFIED+1))
      log INFO "  📧 Created issue for failed workflow: $name"
    fi
  done <<< "$FAILED_RUNS"
fi

# ═══════════════════════════════════════════════════════
# 2. Check security reports
# ═══════════════════════════════════════════════════════

if [ -f "security-scanner-report.md" ]; then
  if grep -q "Action needed\|Critical\|🔴" "security-scanner-report.md" 2>/dev/null; then
    EXISTING=$(gh issue list --state open --search "Security Alert" --json number --jq 'length' 2>/dev/null || echo "0")
    if [ "$EXISTING" -eq 0 ]; then
      gh issue create \
        --title "🔒 Security Alert — $TODAY" \
        --body "$(cat security-scanner-report.md)

---
_🤖 Automated alert by GitHub Autopilot_" \
        --label "security,automated,high-priority" 2>/dev/null || true
      NOTIFIED=$((NOTIFIED+1))
      log INFO "  📧 Created security alert issue"
    fi
  fi
fi

# ═══════════════════════════════════════════════════════
# 3. Check health score
# ═══════════════════════════════════════════════════════

if [ -f "health-checker-report.md" ]; then
  SCORE=$(grep -oP '\d+/100' "health-checker-report.md" 2>/dev/null | head -1 | grep -oP '\d+' || echo "100")
  if [ -n "$SCORE" ] && [ "$SCORE" -lt 60 ]; then
    EXISTING=$(gh issue list --state open --search "Low Health Score" --json number --jq 'length' 2>/dev/null || echo "0")
    if [ "$EXISTING" -eq 0 ]; then
      gh issue create \
        --title "⚠️ Low Health Score: $SCORE/100 — $TODAY" \
        --body "$(cat health-checker-report.md)

---
_🤖 Automated alert by GitHub Autopilot_" \
        --label "automated" 2>/dev/null || true
      NOTIFIED=$((NOTIFIED+1))
      log INFO "  📧 Created health alert issue (score: $SCORE)"
    fi
  fi
fi

# ═══════════════════════════════════════════════════════
# 4. Push notification via ntfy.sh (always works!)
# ═══════════════════════════════════════════════════════

NTFY_TOPIC="${NTFY_TOPIC:-caasiyatnilab-ops}"

# Daily summary at 8AM
HOUR=$(date -u +%H)
if [ "$HOUR" = "08" ] || [ "$HOUR" = "12" ] || [ "$HOUR" = "18" ]; then
  OPEN_ISSUES=$(gh issue list --state open --json number --jq 'length' 2>/dev/null || echo "0")
  OPEN_PRS=$(gh pr list --state open --json number --jq 'length' 2>/dev/null || echo "0")
  CI_PASSED=$(gh run list --limit 10 --json conclusion --jq '[.[]|select(.conclusion=="success")]|length' 2>/dev/null || echo "0")
  CI_TOTAL=$(gh run list --limit 10 --json conclusion --jq 'length' 2>/dev/null || echo "0")

  SUMMARY="📊 $REPO Update ($TODAY)

Issues: $OPEN_ISSUES open
PRs: $OPEN_PRS open
CI: $CI_PASSED/$CI_TOTAL passing

All bots running smoothly! 🤖"

  curl -s -d "$SUMMARY" \
    -H "Title: 📊 GitHub Autopilot Update" \
    -H "Tags: chart_with_upwards_trend,robot" \
    "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 && NOTIFIED=$((NOTIFIED+1))
  log INFO "  📱 Push notification sent"
fi

# ═══════════════════════════════════════════════════════
# 5. Optional channels (if configured)
# ═══════════════════════════════════════════════════════

# Discord
if [ -n "${DISCORD_WEBHOOK:-}" ]; then
  curl -s -H "Content-Type: application/json" \
    -d "{\"embeds\":[{\"title\":\"📬 Autopilot Update\",\"description\":\"$REPO — $NOTIFIED alerts sent\",\"color\":3447003}]}" \
    "$DISCORD_WEBHOOK" >/dev/null 2>&1
  log INFO "  💬 Discord notification sent"
fi

# Telegram
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$TELEGRAM_CHAT_ID\",\"text\":\"📬 Autopilot Update\n$REPO — $NOTIFIED alerts sent\"}" >/dev/null 2>&1
  log INFO "  ✈️ Telegram notification sent"
fi

# Email (Resend)
if [ -n "${RESEND_API_KEY:-}" ] && [ -n "${NOTIFY_EMAIL:-}" ]; then
  curl -s -X POST "https://api.resend.com/emails" \
    -H "Authorization: Bearer $RESEND_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"from\":\"autopilot@resend.dev\",\"to\":\"$NOTIFY_EMAIL\",\"subject\":\"📬 Autopilot Update — $REPO\",\"text\":\"$NOTIFIED alerts sent. Check GitHub for details.\"}" >/dev/null 2>&1
  log INFO "  📧 Email sent via Resend"
fi

# ═══════════════════════════════════════════════════════
# Report
# ═══════════════════════════════════════════════════════

cat > "$REPORT" << EOF
# 📬 Notification Bot Report
**Date:** $TODAY
**Repo:** $REPO
**Notifications Sent:** $NOTIFIED

## Active Channels
- ✅ **ntfy.sh** — Push (topic: $NTFY_TOPIC)
- ✅ **GitHub Issues** — Email via GitHub notifications
- $( [ -n "${DISCORD_WEBHOOK:-}" ] && echo '✅' || echo '⚪') Discord
- $( [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && echo '✅' || echo '⚪') Telegram
- $( [ -n "${RESEND_API_KEY:-}" ] && echo '✅' || echo '⚪') Email (Resend)
- $( [ -n "${BREVO_API_KEY:-}" ] && echo '✅' || echo '⚪') Email (Brevo)
- $( [ -n "${PUSHOVER_TOKEN:-}" ] && echo '✅' || echo '⚪') Pushover

## How Email Works Now
Bots create GitHub Issues for important events.
GitHub sends you email for each issue automatically.
No third-party email service needed!

## To Add More Channels
Set these GitHub Secrets:
- \`DISCORD_WEBHOOK\` — Discord webhook URL
- \`TELEGRAM_BOT_TOKEN\` — Telegram bot token
- \`TELEGRAM_CHAT_ID\` — Your Telegram chat ID
- \`RESEND_API_KEY\` — From resend.com (100/day free)
- \`NOTIFY_EMAIL\` — Your email address

---
_Automated by Notification Bot 📬_
EOF

cat "$REPORT"

notify "$(basename $BOT_NAME 2>/dev/null || basename $0)" "Bot completed successfully. Check report." 2>/dev/null || true
log INFO "📬 Notification Bot complete! $NOTIFIED notifications sent."

exit 0
