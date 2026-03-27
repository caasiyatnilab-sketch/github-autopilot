#!/bin/bash
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
BOT="auto-fixer"; REPORT="auto-fixer-report.md"
log INFO "🛠️ Auto Fixer starting..."
CHANGES=false; FIXES=""

if [ -f "package.json" ]; then
  grep -q '"eslint"' package.json 2>/dev/null && npx eslint . --fix --ext .js,.jsx,.ts,.tsx 2>/dev/null && { CHANGES=true; FIXES="ESLint "; }
  grep -q '"prettier"' package.json 2>/dev/null && npx prettier --write "**/*.{js,ts,json,css,md}" 2>/dev/null && { CHANGES=true; FIXES="${FIXES}Prettier "; }
  npm audit fix 2>/dev/null && { CHANGES=true; FIXES="${FIXES}npm-audit "; }
fi

find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.json" \) -not -path "./node_modules/*" -exec sed -i 's/[[:space:]]*$//' {} \; 2>/dev/null

if [ -f ".gitignore" ]; then
  for p in node_modules/ .env dist/ "*.log" .DS_Store; do grep -q "$p" .gitignore 2>/dev/null || echo "$p" >> .gitignore; done
fi

CHANGES_TEXT="None needed"
[ "$CHANGES" = true ] && CHANGES_TEXT="Yes — ${FIXES}"

python3 -c "
lines = '''# 🛠️ Auto Fix Report
**Repo:** $(get_repo) | **Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Changes:** $CHANGES_TEXT'''
open('$REPORT', 'w').write(lines)
"
cat "$REPORT"
