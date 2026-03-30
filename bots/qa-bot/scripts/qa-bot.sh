#!/bin/bash
# ✅ QA/QC Bot (Fixed)
set -uo pipefail
trap 'record_result "qa-bot" "error" "script exited with error" 2>/dev/null || true' ERR
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"

REPORT="qa-bot-report.md"
log INFO "✅ QA/QC Bot starting..."

# Check if there are projects to check
if [ ! -d "creations" ] || [ -z "$(ls -A creations/ 2>/dev/null)" ]; then
  log INFO "No projects to check — skipping"
  cat > "$REPORT" << 'REOF'
# ✅ QA/QC Report
ℹ️ No projects to check this run.
---
_Automated by QA/QC Bot ✅_
REOF
record_result "qa-bot" "success" "completed" 2>/dev/null || true
  cat "$REPORT"
  exit 0
fi

PASS=0; FAIL=0; WARN=0

for dir in creations/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  log INFO "Checking: $name"
  
  [ -f "$dir/README.md" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
  [ -f "$dir/LICENSE" ] && PASS=$((PASS+1)) || WARN=$((WARN+1))
  [ -f "$dir/.gitignore" ] && PASS=$((PASS+1)) || WARN=$((WARN+1))
  
  SECRETS=$(grep -rnEi 'sk-[a-zA-Z0-9]{20,}|password\s*[:=]' "$dir" 2>/dev/null | wc -l || echo "0")
  [ "$SECRETS" -eq 0 ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
done

TOTAL=$((PASS + FAIL + WARN))
SCORE=$((PASS * 100 / (TOTAL + 1)))

cat > "$REPORT" << REOF
# ✅ QA/QC Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Score:** $SCORE%
**Pass:** $PASS | **Fail:** $FAIL | **Warn:** $WARN
---
_Automated by QA/QC Bot ✅_
REOF

record_result "qa-bot" "success" "completed" 2>/dev/null || true
cat "$REPORT"
exit 0
