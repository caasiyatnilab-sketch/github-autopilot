#!/bin/bash
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
ACTION="${1:-all}"; REPORT="issue-pr-manager-report.md"

label_issue() {
  local num="${GITHUB_EVENT_ISSUE_NUMBER:-}"; [ -z "$num" ] && return 0
  local title="${GITHUB_EVENT_ISSUE_TITLE:-}"
  local labels=""
  echo "$title" | grep -qiE "bug|error|crash|fix" && labels="bug"
  echo "$title" | grep -qiE "feature|request|add|enhance" && labels="${labels:+$labels,}enhancement"
  echo "$title" | grep -qiE "security|vuln" && labels="${labels:+$labels,}security"
  echo "$title" | grep -qiE "doc|readme" && labels="${labels:+$labels,}documentation"
  [ -n "$labels" ] && { IFS=',' read -ra arr <<< "$labels"; for l in "${arr[@]}"; do gh label create "$l" --force 2>/dev/null || true; done; gh issue edit "$num" --add-label "$labels" 2>/dev/null; }
}

stale_cleanup() {
  gh label create "stale" --color "ededed" --force 2>/dev/null || true
  CUTOFF=$(date -d '-30 days' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -v-30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  [ -z "$CUTOFF" ] && return 0
  gh issue list --state open --limit 100 --json number,updatedAt --jq ".[] | select(.updatedAt < \"$CUTOFF\") | .number" 2>/dev/null | while read -r n; do
    gh issue edit "$n" --add-label "stale" 2>/dev/null || true
    gh issue comment "$n" --body "🕐 Inactive for 30 days. Comment to keep open." 2>/dev/null || true
  done
}

case "$ACTION" in
  label) label_issue ;;
  stale) stale_cleanup ;;
  *) label_issue; stale_cleanup ;;
esac

python3 -c "
lines = '''# 🏷️ Issue & PR Manager Report
**Repo:** $(get_repo) | **Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Action:** $ACTION
✅ Completed'''
open('$REPORT', 'w').write(lines)
"
cat "$REPORT"
