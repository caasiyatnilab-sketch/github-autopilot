#!/bin/bash
# 📦 Auto Updater (Enhanced)
# Checks, updates, fixes dependencies — auto-PR with changes
set -uo pipefail
trap 'record_result "auto-updater" "error" "script exited with error" 2>/dev/null || true' ERR
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"

REPORT="auto-updater-report.md"
log INFO "📦 Auto Updater starting..."

REPO=$(get_repo)
UPDATED=0
FIXES=""

if [ ! -f "package.json" ]; then
  cat > "$REPORT" << 'REOF'
# 📦 Auto Update Report
ℹ️ No package.json found. Nothing to update.
---
_Automated by Auto Updater 📦_
REOF
record_result "auto-updater" "success" "completed" 2>/dev/null || true
  cat "$REPORT"
  exit 0
fi

# 1. Check outdated packages
log INFO "Checking outdated packages..."
OUTDATED=$(npm outdated --json 2>/dev/null || echo "{}")
COUNT=$(echo "$OUTDATED" | jq 'length' 2>/dev/null || echo "0")
log INFO "  Found $COUNT outdated packages"

# 2. Update packages
if [ "$COUNT" -gt 0 ]; then
  log INFO "Running npm update..."
  npm update 2>/dev/null && UPDATED=1 && FIXES="${FIXES}npm-update " || true
fi

# 3. Security audit fix
log INFO "Running security audit..."
AUDIT=$(npm audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{"critical":0,"high":0}}}')
CRIT=$(echo "$AUDIT" | jq '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo "0")
HIGH=$(echo "$AUDIT" | jq '.metadata.vulnerabilities.high // 0' 2>/dev/null || echo "0")

if [ "$CRIT" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
  log INFO "Fixing vulnerabilities..."
  npm audit fix 2>/dev/null && UPDATED=1 && FIXES="${FIXES}audit-fix " || true
  # Force fix if needed
  [ "$CRIT" -gt 0 ] && npm audit fix --force 2>/dev/null && FIXES="${FIXES}force-fix " || true
fi

# 4. Update package-lock
if [ -f "package-lock.json" ]; then
  npm install --package-lock-only 2>/dev/null || true
fi

# 5. Check for deprecated packages
DEPRECATED=$(npm ls 2>&1 | grep -c "deprecated" || echo "0")
log INFO "  Deprecated packages: $DEPRECATED"

# 6. Generate outdated table
OUTDATED_TABLE=$(echo "$OUTDATED" | jq -r 'to_entries[] | "| \(.key) | \(.value.current) | \(.value.wanted) | \(.value.latest) |"' 2>/dev/null || echo "| All up to date ✅ | - | - | - |")

# Generate report
cat > "$REPORT" << REOF
# 📦 Auto Update Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repo:** $REPO

## Outdated Packages: $COUNT
| Package | Current | Wanted | Latest |
|---------|---------|--------|--------|
$OUTDATED_TABLE

## Security Audit
- Critical: $CRIT
- High: $HIGH
- Deprecated: $DEPRECATED

## Fixes Applied
${FIXES:-None needed ✅}

## Status
$(if [ "$UPDATED" -eq 1 ]; then echo "✅ Updates applied. Auto-PR will be created."; else echo "✅ Everything up to date."; fi)

---
_Automated by Auto Updater 📦_
REOF

record_result "auto-updater" "success" "completed" 2>/dev/null || true
cat "$REPORT"
notify "Auto Updater" "Checked $COUNT packages. Fixes: ${FIXES:-none}"
exit 0
