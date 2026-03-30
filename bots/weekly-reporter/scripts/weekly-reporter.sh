#!/bin/bash
set -euo pipefail
trap 'record_result "weekly-reporter" "error" "script exited with error" 2>/dev/null || true' ERR
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"
BOT="weekly-reporter"; REPORT="weekly-reporter-report.md"
log INFO "📊 Weekly Reporter starting..."
WEEK_AGO=$(date -d "-7 days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

COMMITS=$(git log --oneline --since="$WEEK_AGO" 2>/dev/null | wc -l || echo "0")
PRS_OPENED=$(gh pr list --state all --json createdAt --jq "[.[]|select(.createdAt>\"$WEEK_AGO\")]|length" 2>/dev/null || echo "0")
PRS_MERGED=$(gh pr list --state merged --json mergedAt --jq "[.[]|select(.mergedAt>\"$WEEK_AGO\")]|length" 2>/dev/null || echo "0")
ISSUES_OPENED=$(gh issue list --state all --json createdAt --jq "[.[]|select(.createdAt>\"$WEEK_AGO\")]|length" 2>/dev/null || echo "0")
ISSUES_CLOSED=$(gh issue list --state closed --json closedAt --jq "[.[]|select(.closedAt>\"$WEEK_AGO\")]|length" 2>/dev/null || echo "0")
CONTRIBUTORS=$(git log --since="$WEEK_AGO" --format="%aN" 2>/dev/null | sort | uniq -c | sort -rn | head -5 | awk '{printf "- **%s**: %s commits\n", $2, $1}' || echo "No activity")
CI_STATUS=$(gh run list --limit 10 --json name,conclusion --jq '.[]|"- \(.name): \(.conclusion)"' 2>/dev/null || echo "No runs")
OPEN_ISSUES=$(gh issue list --state open --limit 10 --json number,title --jq '.[]|"- #\(.number): \(.title)"' 2>/dev/null || echo "None")
OPEN_PRS=$(gh pr list --state open --limit 10 --json number,title,author --jq '.[]|"- #\(.number): \(.title) by @\(.author.login)"' 2>/dev/null || echo "None")

python3 -c "
lines = '''# 📊 Weekly Report
**Repo:** $(get_repo) | **Week of:** $(date -u '+%Y-%m-%d')

## Activity
- Commits: $COMMITS
- PRs Opened: $PRS_OPENED | Merged: $PRS_MERGED
- Issues Opened: $ISSUES_OPENED | Closed: $ISSUES_CLOSED

## Top Contributors
$CONTRIBUTORS

## CI Status
$CI_STATUS

## Open Issues (Top 10)
$OPEN_ISSUES

## Open PRs
$OPEN_PRS'''
open('$REPORT', 'w').write(lines)
"
record_result "weekly-reporter" "success" "completed" 2>/dev/null || true
cat "$REPORT"

notify "$(basename $BOT_NAME 2>/dev/null || basename $0)" "Bot completed successfully. Check report." 2>/dev/null || true

exit 0
