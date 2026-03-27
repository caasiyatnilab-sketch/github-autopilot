#!/bin/bash
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
BOT="auto-updater"; REPORT="auto-updater-report.md"
log INFO "📦 Auto Updater starting..."

if [ ! -f "package.json" ]; then echo "No package.json found."; exit 0; fi

OUTDATED=$(npm outdated --json 2>/dev/null || echo "{}")
COUNT=$(echo "$OUTDATED" | jq 'length' 2>/dev/null || echo "0")

ACTIONS="No updates needed"
if [ "$COUNT" -gt 0 ]; then
  npm update 2>/dev/null || true
  npm audit fix 2>/dev/null || true
  ACTIONS="- npm update applied\n- npm audit fix applied"
fi

PKG_LIST=$(echo "$OUTDATED" | jq -r 'to_entries[] | "- \(.key): \(.value.current) → \(.value.latest)"' 2>/dev/null || echo "All up to date ✅")

python3 -c "
lines = '''# 📦 Auto Update Report
**Repo:** $(get_repo) | **Date:** $(date -u '+%Y-%m-%d %H:%M UTC')

## Outdated Packages: $COUNT
$PKG_LIST

## Actions Taken
$ACTIONS'''
open('$REPORT', 'w').write(lines)
"
cat "$REPORT"

notify "$(basename $BOT_NAME 2>/dev/null || basename $0)" "Bot completed successfully. Check report." 2>/dev/null || true
