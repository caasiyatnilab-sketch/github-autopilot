#!/bin/bash
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
BOT="health-checker"; REPORT="health-checker-report.md"
log INFO "🔍 Health Checker starting..."
SCORE=100; ISSUES=()

for branch in main master; do
  PROTECTED=$(gh api "repos/$(get_repo)/branches/$branch" --jq '.protected' 2>/dev/null || echo "skip")
  [ "$PROTECTED" = "true" ] && continue
  [ "$PROTECTED" = "skip" ] && continue
  SCORE=$((SCORE-15)); ISSUES+=("$branch not protected")
done

RUNS=$(gh run list --limit 20 --json conclusion 2>/dev/null || echo "[]")
FAILED=$(echo "$RUNS" | jq '[.[]|select(.conclusion=="failure")]|length' 2>/dev/null || echo "0")
TOTAL=$(echo "$RUNS" | jq 'length' 2>/dev/null || echo "0")
[ "$TOTAL" -gt 0 ] && [ "$((FAILED*100/TOTAL))" -gt 30 ] && { SCORE=$((SCORE-15)); ISSUES+=("CI failure rate high"); }

for f in README.md .gitignore LICENSE; do
  [ ! -f "$f" ] && { SCORE=$((SCORE-5)); ISSUES+=("Missing $f"); }
done

OPEN_ISSUES=$(gh issue list --state open --json number --jq 'length' 2>/dev/null || echo "0")
OPEN_PRS=$(gh pr list --state open --json number --jq 'length' 2>/dev/null || echo "0")
[ "$OPEN_ISSUES" -gt 20 ] && { SCORE=$((SCORE-5)); ISSUES+=("$OPEN_ISSUES open issues"); }

[ "$SCORE" -ge 90 ] && EMOJI="🟢" || [ "$SCORE" -ge 70 ] && EMOJI="🟡" || [ "$SCORE" -ge 50 ] && EMOJI="🟠" || EMOJI="🔴"

ISSUE_LIST=""
for i in "${ISSUES[@]}"; do ISSUE_LIST="$ISSUE_LIST\n- ⚠️ $i"; done
[ -z "$ISSUE_LIST" ] && ISSUE_LIST="None ✅"

python3 -c "
lines = '''# 🔍 Health Check Report
**Repo:** $(get_repo) | **Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Score:** $EMOJI $SCORE/100

## Metrics
- CI Runs: $TOTAL total, $FAILED failed
- Open Issues: $OPEN_ISSUES | Open PRs: $OPEN_PRS

## Issues Found
${ISSUE_LIST}'''
open('$REPORT', 'w').write(lines)
"
cat "$REPORT"
[ "$SCORE" -lt 50 ] && exit 1 || exit 0
