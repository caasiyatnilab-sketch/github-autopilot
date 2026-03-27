#!/bin/bash
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
BOT="security-scanner"; REPORT="security-scanner-report.md"
log INFO "🔒 Security Scanner starting..."
VULNS=0; CRIT=0; HIGH=0; MOD=0; SECRETS_FOUND=0

if [ -f "package.json" ]; then
  AUDIT=$(npm audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{"critical":0,"high":0,"moderate":0}}}')
  CRIT=$(echo "$AUDIT" | jq '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo "0")
  HIGH=$(echo "$AUDIT" | jq '.metadata.vulnerabilities.high // 0' 2>/dev/null || echo "0")
  MOD=$(echo "$AUDIT" | jq '.metadata.vulnerabilities.moderate // 0' 2>/dev/null || echo "0")
  VULNS=$((CRIT + HIGH))
fi

for pat in 'AKIA[0-9A-Z]{16}' 'sk-[a-zA-Z0-9]{48}' 'ghp_[a-zA-Z0-9]{36}' 'npm_[A-Za-z0-9]{36}'; do
  grep -rqEi "$pat" --include="*.{js,ts,py,json,yml,yaml,env}" . 2>/dev/null && SECRETS_FOUND=1 && break
done
[ "$SECRETS_FOUND" -eq 1 ] && VULNS=$((VULNS+1))

SECRETS_MSG="✅ No secrets detected"
[ "$SECRETS_FOUND" -eq 1 ] && SECRETS_MSG="⚠️ Potential secrets found in code!"
STATUS_MSG="🟢 All clear"
[ "$VULNS" -gt 0 ] && STATUS_MSG="🔴 Action needed"

python3 -c "
lines = '''# 🔒 Security Scan Report
**Repo:** $(get_repo) | **Date:** $(date -u '+%Y-%m-%d %H:%M UTC')

## Vulnerabilities
- Critical: $CRIT | High: $HIGH | Moderate: $MOD

## Secrets
$SECRETS_MSG

## Status
$STATUS_MSG'''
open('$REPORT', 'w').write(lines)
"
cat "$REPORT"

notify "$(basename $BOT_NAME 2>/dev/null || basename $0)" "Bot completed successfully. Check report." 2>/dev/null || true
[ "$VULNS" -gt 0 ] && exit 1 || exit 0
