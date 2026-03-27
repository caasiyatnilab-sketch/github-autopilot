#!/bin/bash
# 📬 Notification Bot
# Sends updates via Email, Telegram, Discord, Slack, SMS (all freemium)
# No intervention needed — works automatically
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="notification-bot"
REPORT="notification-report.md"

log INFO "📬 Notification Bot starting..."

# ═══════════════════════════════════════════════════════
# Message Templates
# ═══════════════════════════════════════════════════════

format_message() {
  local type="$1"
  local title="$2"
  local body="$3"
  local channel="$4"

  case "$channel" in
    email)
      cat << EOF
Subject: [$type] $title

$body

---
Sent by GitHub Autopilot 🤖
$(date -u '+%Y-%m-%d %H:%M UTC')
EOF
      ;;
    discord|slack)
      cat << EOF
{
  "embeds": [{
    "title": "[$type] $title",
    "description": "$body",
    "color": 3447003,
    "footer": { "text": "🤖 GitHub Autopilot | $(date -u '+%Y-%m-%d %H:%M UTC')" }
  }]
}
EOF
      ;;
    telegram)
      echo "[$type] *$title*

$body

🤖 _GitHub Autopilot_"
      ;;
    *)
      echo "[$type] $title — $body"
      ;;
  esac
}

# ═══════════════════════════════════════════════════════
# Email via free services
# ═══════════════════════════════════════════════════════

send_email_resend() {
  local to="$1"
  local subject="$2"
  local body="$3"
  local api_key="${RESEND_API_KEY:-}"

  if [ -z "$api_key" ]; then
    log WARN "RESEND_API_KEY not set — skipping email"
    return 1
  fi

  curl -s -X POST "https://api.resend.com/emails" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d "{
      \"from\": \"autopilot@resend.dev\",
      \"to\": \"$to\",
      \"subject\": \"$subject\",
      \"text\": \"$body\"
    }" >/dev/null 2>&1

  log INFO "  ✅ Email sent via Resend to $to"
}

send_email_brevo() {
  local to="$1"
  local subject="$2"
  local body="$3"
  local api_key="${BREVO_API_KEY:-}"

  if [ -z "$api_key" ]; then
    log WARN "BREVO_API_KEY not set — skipping email"
    return 1
  fi

  curl -s -X POST "https://api.brevo.com/v3/smtp/email" \
    -H "api-key: $api_key" \
    -H "Content-Type: application/json" \
    -d "{
      \"sender\": {\"email\": \"autopilot@bots.dev\", \"name\": \"GitHub Autopilot\"},
      \"to\": [{\"email\": \"$to\"}],
      \"subject\": \"$subject\",
      \"textContent\": \"$body\"
    }" >/dev/null 2>&1

  log INFO "  ✅ Email sent via Brevo to $to"
}

send_email_mailgun() {
  local to="$1"
  local subject="$2"
  local body="$3"
  local api_key="${MAILGUN_API_KEY:-}"
  local domain="${MAILGUN_DOMAIN:-sandbox.mailgun.org}"

  if [ -z "$api_key" ]; then
    log WARN "MAILGUN_API_KEY not set — skipping"
    return 1
  fi

  curl -s -u "api:$api_key" \
    "https://api.mailgun.net/v3/$domain/messages" \
    -F from="autopilot@$domain" \
    -F to="$to" \
    -F subject="$subject" \
    -F text="$body" >/dev/null 2>&1

  log INFO "  ✅ Email sent via Mailgun to $to"
}

# ═══════════════════════════════════════════════════════
# Telegram Bot
# ═══════════════════════════════════════════════════════

send_telegram() {
  local chat_id="$1"
  local message="$2"
  local bot_token="${TELEGRAM_BOT_TOKEN:-}"

  if [ -z "$bot_token" ]; then
    log WARN "TELEGRAM_BOT_TOKEN not set — skipping"
    return 1
  fi

  # Escape markdown
  message=$(echo "$message" | sed 's/"/\\"/g')

  curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
      \"chat_id\": \"$chat_id\",
      \"text\": \"$message\",
      \"parse_mode\": \"Markdown\"
    }" >/dev/null 2>&1

  log INFO "  ✅ Telegram message sent to $chat_id"
}

# ═══════════════════════════════════════════════════════
# Discord Webhook
# ═══════════════════════════════════════════════════════

send_discord() {
  local webhook="$1"
  local title="$2"
  local body="$3"

  if [ -z "$webhook" ]; then
    log WARN "DISCORD_WEBHOOK not set — skipping"
    return 1
  fi

  curl -s -H "Content-Type: application/json" \
    -d "{
      \"embeds\": [{
        \"title\": \"$title\",
        \"description\": \"$body\",
        \"color\": 3447003,
        \"footer\": { \"text\": \"🤖 GitHub Autopilot\" }
      }]
    }" "$webhook" >/dev/null 2>&1

  log INFO "  ✅ Discord message sent"
}

# ═══════════════════════════════════════════════════════
# Slack Webhook
# ═══════════════════════════════════════════════════════

send_slack() {
  local webhook="$1"
  local title="$2"
  local body="$3"

  if [ -z "$webhook" ]; then
    log WARN "SLACK_WEBHOOK not set — skipping"
    return 1
  fi

  curl -s -H "Content-Type: application/json" \
    -d "{
      \"blocks\": [
        {\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"$title\"}},
        {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"$body\"}},
        {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"🤖 _GitHub Autopilot_\"}]}
      ]
    }" "$webhook" >/dev/null 2>&1

  log INFO "  ✅ Slack message sent"
}

# ═══════════════════════════════════════════════════════
# Pushover (Push Notifications to Phone)
# ═══════════════════════════════════════════════════════

send_pushover() {
  local title="$1"
  local message="$2"
  local token="${PUSHOVER_TOKEN:-}"
  local user="${PUSHOVER_USER:-}"

  if [ -z "$token" ] || [ -z "$user" ]; then
    log WARN "PUSHOVER_TOKEN/USER not set — skipping"
    return 1
  fi

  curl -s -X POST "https://api.pushover.net/1/messages.json" \
    -d "token=$token" \
    -d "user=$user" \
    -d "title=$title" \
    -d "message=$message" \
    -d "priority=0" >/dev/null 2>&1

  log INFO "  ✅ Push notification sent via Pushover"
}

# ═══════════════════════════════════════════════════════
# Ntfy.sh (Free, No Signup Push Notifications)
# ═══════════════════════════════════════════════════════

send_ntfy() {
  local topic="${NTFY_TOPIC:-github-autopilot}"
  local title="$1"
  local message="$2"

  curl -s -d "$message" \
    -H "Title: $title" \
    -H "Tags: robot,github" \
    "https://ntfy.sh/$topic" >/dev/null 2>&1

  log INFO "  ✅ Push notification sent via ntfy.sh (topic: $topic)"
}

# ═══════════════════════════════════════════════════════
# Unified Send — picks available channels
# ═══════════════════════════════════════════════════════

send_notification() {
  local type="$1"
  local title="$2"
  local body="$3"

  SENT=0

  # Discord
  if [ -n "${DISCORD_WEBHOOK:-}" ]; then
    send_discord "$DISCORD_WEBHOOK" "[$type] $title" "$body" && SENT=$((SENT+1))
  fi

  # Slack
  if [ -n "${SLACK_WEBHOOK:-}" ]; then
    send_slack "$SLACK_WEBHOOK" "[$type] $title" "$body" && SENT=$((SENT+1))
  fi

  # Telegram
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    send_telegram "$TELEGRAM_CHAT_ID" "[$type] $title — $body" && SENT=$((SENT+1))
  fi

  # Email (Resend — 100 emails/day free)
  if [ -n "${RESEND_API_KEY:-}" ] && [ -n "${NOTIFY_EMAIL:-}" ]; then
    send_email_resend "$NOTIFY_EMAIL" "[$type] $title" "$body" && SENT=$((SENT+1))
  fi

  # Email (Brevo — 300 emails/day free)
  if [ -n "${BREVO_API_KEY:-}" ] && [ -n "${NOTIFY_EMAIL:-}" ]; then
    send_email_brevo "$NOTIFY_EMAIL" "[$type] $title" "$body" && SENT=$((SENT+1))
  fi

  # Pushover (phone push)
  if [ -n "${PUSHOVER_TOKEN:-}" ]; then
    send_pushover "[$type] $title" "$body" && SENT=$((SENT+1))
  fi

  # Ntfy.sh (free, no signup — always works!)
  send_ntfy "[$type] $title" "$body" && SENT=$((SENT+1))

  log INFO "📬 Notification sent via $SENT channel(s)"
}

# ═══════════════════════════════════════════════════════
# Main — Check bot reports and notify
# ═══════════════════════════════════════════════════════

log INFO "Scanning bot reports for notifications..."

NOTIFIED=0

# Check for failed workflows
FAILED_RUNS=$(gh run list --limit 5 --json conclusion,name --jq '.[] | select(.conclusion == "failure") | .name' 2>/dev/null || echo "")
if [ -n "$FAILED_RUNS" ]; then
  while IFS= read -r run; do
    send_notification "FAILURE" "Bot Failed: $run" "Workflow '$run' failed in $(get_repo). Check GitHub Actions for details."
    NOTIFIED=$((NOTIFIED+1))
  done <<< "$FAILED_RUNS"
fi

# Check for security alerts
if [ -f "security-scanner-report.md" ]; then
  if grep -q "Action needed" "security-scanner-report.md" 2>/dev/null; then
    send_notification "SECURITY" "Security Alert" "Security vulnerabilities detected in $(get_repo). Check security-scanner-report.md"
    NOTIFIED=$((NOTIFIED+1))
  fi
fi

# Check for health issues
if [ -f "health-checker-report.md" ]; then
  SCORE=$(grep -oP 'Score.*?(\d+)/100' "health-checker-report.md" | grep -oP '\d+' | head -1 || echo "100")
  if [ -n "$SCORE" ] && [ "$SCORE" -lt 70 ]; then
    send_notification "HEALTH" "Low Health Score: $SCORE/100" "Repo $(get_repo) health score dropped to $SCORE/100. Check health-checker-report.md"
    NOTIFIED=$((NOTIFIED+1))
  fi
fi

# Daily summary (once per day)
HOUR=$(date -u +%H)
if [ "$HOUR" = "08" ]; then
  OPEN_ISSUES=$(gh issue list --state open --json number --jq 'length' 2>/dev/null || echo "0")
  OPEN_PRS=$(gh pr list --state open --json number --jq 'length' 2>/dev/null || echo "0")
  send_notification "DAILY" "Daily Summary" "Repo $(get_repo): $OPEN_ISSUES open issues, $OPEN_PRS open PRs. All bots running smoothly."
  NOTIFIED=$((NOTIFIED+1))
fi

# Generate report
python3 -c "
lines = '''# 📬 Notification Bot Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Notifications Sent:** $NOTIFIED

## Available Channels
- ✅ **ntfy.sh** — Free push (always available, no signup)
- $( [ -n \"\${DISCORD_WEBHOOK:-}\" ] && echo '✅' || echo '⚪') **Discord** — via webhook
- $( [ -n \"\${SLACK_WEBHOOK:-}\" ] && echo '✅' || echo '⚪') **Slack** — via webhook
- $( [ -n \"\${TELEGRAM_BOT_TOKEN:-}\" ] && echo '✅' || echo '⚪') **Telegram** — via bot
- $( [ -n \"\${RESEND_API_KEY:-}\" ] && echo '✅' || echo '⚪') **Email (Resend)** — 100/day free
- $( [ -n \"\${BREVO_API_KEY:-}\" ] && echo '✅' || echo '⚪') **Email (Brevo)** — 300/day free
- $( [ -n \"\${PUSHOVER_TOKEN:-}\" ] && echo '✅' || echo '⚪') **Pushover** — phone push
- $( [ -n \"\${MAILGUN_API_KEY:-}\" ] && echo '✅' || echo '⚪') **Email (Mailgun)** — free tier

## Setup Guide

### Free Push (No Signup Needed)
\`\`\`bash
# Subscribe to your topic at ntfy.sh or in the ntfy app
# Topic: github-autopilot (or set NTFY_TOPIC)
\`\`\`

### Telegram (Free)
1. Message @BotFather on Telegram
2. Create a bot: \`/newbot\`
3. Get your bot token
4. Get your chat ID (message @userinfobot)
5. Add secrets: \`TELEGRAM_BOT_TOKEN\`, \`TELEGRAM_CHAT_ID\`

### Email via Resend (Free 100/day)
1. Sign up at https://resend.com
2. Get API key
3. Add secret: \`RESEND_API_KEY\`
4. Add secret: \`NOTIFY_EMAIL\`

### Email via Brevo (Free 300/day)
1. Sign up at https://brevo.com
2. Get API key from SMTP settings
3. Add secret: \`BREVO_API_KEY\`

### Discord (Free)
1. Server Settings → Integrations → Webhooks
2. Create webhook, copy URL
3. Add secret: \`DISCORD_WEBHOOK\`

### Slack (Free)
1. Create app at api.slack.com
2. Add Incoming Webhooks
3. Add secret: \`SLACK_WEBHOOK\`

---
_Automated by Notification Bot 📬_'''
open('$REPORT', 'w').write(lines)
"
cat "$REPORT"
log INFO "📬 Notification Bot complete! Sent $NOTIFIED notifications."
