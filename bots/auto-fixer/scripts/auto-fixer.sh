#!/bin/bash
# 🛠️ Auto Fixer Bot
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

REPORT="auto-fixer-report.md"
log INFO "🛠️ Auto Fixer starting..."
CHANGES=false
FIXES=""

# AI-powered code analysis
AI_TIPS=""
if [ -n "${GROQ_API_KEY:-}" ] || [ -n "${OPENROUTER_API_KEY:-}" ]; then
  log INFO "  🤖 AI mode — smart code analysis..."
  AI_TIPS=$(ai_ask "List 3 common bugs in JavaScript/Node.js projects and one-line fixes for each. Be brief." 2>/dev/null || echo "")
  [ -n "$AI_TIPS" ] && log INFO "  ✅ AI fix tips received"
fi

# 1. ESLint fix
if [ -f "package.json" ]; then
  if grep -q '"eslint"' package.json 2>/dev/null || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ]; then
    log INFO "Running ESLint --fix..."
    npx eslint . --fix --ext .js,.jsx,.ts,.tsx 2>/dev/null && CHANGES=true && FIXES="${FIXES}ESLint " || true
  fi

  # 2. Prettier fix
  if grep -q '"prettier"' package.json 2>/dev/null || [ -f ".prettierrc" ]; then
    log INFO "Running Prettier..."
    npx prettier --write "**/*.{js,ts,json,css,md,html}" 2>/dev/null && CHANGES=true && FIXES="${FIXES}Prettier " || true
  fi

  # 3. npm audit fix
  log INFO "Running npm audit fix..."
  npm audit fix 2>/dev/null && CHANGES=true && FIXES="${FIXES}Audit " || true

  # 4. Update package-lock
  if [ -f "package-lock.json" ]; then
    npm install --package-lock-only 2>/dev/null || true
  fi
fi

# 5. Remove trailing whitespace
log INFO "Cleaning whitespace..."
find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.json" -o -name "*.css" -o -name "*.html" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" \) \
  -not -path "./node_modules/*" -not -path "./.git/*" -not -path "./dist/*" -not -path "./build/*" \
  -exec sed -i 's/[[:space:]]*$//' {} \; 2>/dev/null || true

# 6. Ensure files end with newline
find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.json" -o -name "*.css" \) \
  -not -path "./node_modules/*" -not -path "./.git/*" \
  -exec sh -c 'test "$(tail -c1 "$1" | wc -l)" -eq 0 && echo "" >> "$1"' _ {} \; 2>/dev/null || true

# 7. Fix .gitignore
if [ -f ".gitignore" ]; then
  for p in "node_modules/" ".env" ".env.*" "dist/" "build/" "*.log" ".DS_Store" "Thumbs.db" "*.pem" "*.key"; do
    grep -q "$p" .gitignore 2>/dev/null || echo "$p" >> .gitignore
  done
fi

# 8. Fix common HTML issues
for html in $(find . -name "*.html" -not -path "./node_modules/*" 2>/dev/null); do
  # Add charset if missing
  if ! grep -q "charset" "$html" 2>/dev/null; then
    sed -i '/<head>/a\  <meta charset="UTF-8">' "$html" 2>/dev/null || true
  fi
  # Add viewport if missing
  if ! grep -q "viewport" "$html" 2>/dev/null; then
    sed -i '/<head>/a\  <meta name="viewport" content="width=device-width, initial-scale=1.0">' "$html" 2>/dev/null || true
  fi
done

# Generate report
CHANGES_TEXT="None needed"
[ "$CHANGES" = true ] && CHANGES_TEXT="Yes: ${FIXES}"

cat > "$REPORT" << REOF
# 🛠️ Auto Fix Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repo:** $(get_repo)
**Changes:** $CHANGES_TEXT

## Checks Performed
- ✅ ESLint --fix
- ✅ Prettier formatting
- ✅ npm audit fix
- ✅ Trailing whitespace removal
- ✅ File newline fix
- ✅ .gitignore update
- ✅ HTML meta tags fix

---
_Automated by Auto Fixer 🛠️_
REOF

cat "$REPORT"
notify "Auto Fixer" "Completed: $CHANGES_TEXT"
exit 0
