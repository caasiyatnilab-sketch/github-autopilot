#!/bin/bash
# ✅ QA/QC Bot
# Quality Assurance — checks projects BEFORE they go to GitHub
# Full-stack developer level standards
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

REPORT="qa-bot-report.md"
log INFO "✅ QA/QC Bot starting..."

PASS=0
FAIL=0
WARNINGS=0
CHECKS=""

run_check() {
  local name="$1"
  local result="$2"
  
  if [ "$result" = "pass" ]; then
    PASS=$((PASS+1))
    CHECKS="$CHECKS\n| ✅ | $name | PASS |"
  elif [ "$result" = "fail" ]; then
    FAIL=$((FAIL+1))
    CHECKS="$CHECKS\n| ❌ | $name | FAIL |"
  else
    WARNINGS=$((WARNINGS+1))
    CHECKS="$CHECKS\n| ⚠️ | $name | WARNING |"
  fi
}

# ═══════════════════════════════════════════════════════
# Project Quality Checks
# ═══════════════════════════════════════════════════════

check_project() {
  local dir="$1"
  local name=$(basename "$dir")
  
  log INFO "Checking: $name"
  cd "$dir"
  
  # 1. README exists and has content
  if [ -f "README.md" ]; then
    README_LINES=$(wc -l < README.md)
    [ "$README_LINES" -ge 10 ] && run_check "README.md (≥10 lines)" "pass" || run_check "README.md (too short)" "warn"
  else
    run_check "README.md exists" "fail"
  fi
  
  # 2. LICENSE exists
  [ -f "LICENSE" ] && run_check "LICENSE exists" "pass" || run_check "LICENSE exists" "fail"
  
  # 3. .gitignore exists
  [ -f ".gitignore" ] && run_check ".gitignore exists" "pass" || run_check ".gitignore exists" "fail"
  
  # 4. No exposed secrets
  SECRETS=$(grep -rnEi 'sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|password\s*[:=]' --include="*.{js,ts,json,env}" . 2>/dev/null | grep -v node_modules | grep -v ".example" | wc -l || echo "0")
  [ "$SECRETS" -eq 0 ] && run_check "No exposed secrets" "pass" || run_check "No exposed secrets" "fail"
  
  # 5. Has .env.example (if uses env vars)
  if grep -rq "process.env\|import.meta.env" --include="*.{js,ts}" . 2>/dev/null; then
    [ -f ".env.example" ] && run_check ".env.example exists" "pass" || run_check ".env.example missing" "fail"
  else
    run_check "No env vars needed" "pass"
  fi
  
  # 6. package.json quality (if Node project)
  if [ -f "package.json" ]; then
    # Has name
    jq -e '.name' package.json >/dev/null 2>&1 && run_check "package.json has name" "pass" || run_check "package.json missing name" "fail"
    
    # Has description
    jq -e '.description' package.json >/dev/null 2>&1 && run_check "package.json has description" "pass" || run_check "package.json missing description" "warn"
    
    # Has scripts
    jq -e '.scripts' package.json >/dev/null 2>&1 && run_check "package.json has scripts" "pass" || run_check "package.json missing scripts" "fail"
    
    # Has start script
    jq -e '.scripts.start' package.json >/dev/null 2>&1 && run_check "Has start script" "pass" || run_check "Missing start script" "warn"
    
    # Has test script
    jq -e '.scripts.test' package.json >/dev/null 2>&1 && run_check "Has test script" "pass" || run_check "Missing test script" "warn"
    
    # No deprecated deps
    DEP_COUNT=$(jq '.dependencies // {} | length' package.json 2>/dev/null || echo "0")
    [ "$DEP_COUNT" -gt 0 ] && run_check "Has dependencies ($DEP_COUNT)" "pass" || run_check "No dependencies" "warn"
  fi
  
  # 7. Code quality checks (if JS/TS files exist)
  JS_COUNT=$(find . -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" 2>/dev/null | grep -v node_modules | wc -l || echo "0")
  if [ "$JS_COUNT" -gt 0 ]; then
    # No console.log in production (except logger)
    CONSOLE_COUNT=$(grep -rn "console.log" --include="*.{js,ts,jsx,tsx}" . 2>/dev/null | grep -v node_modules | grep -v "logger" | wc -l || echo "0")
    [ "$CONSOLE_COUNT" -eq 0 ] && run_check "No console.log in code" "pass" || run_check "Has $CONSOLE_COUNT console.log" "warn"
    
    # Has error handling
    TRY_CATCH=$(grep -rn "try\|catch\|\.catch" --include="*.{js,ts}" . 2>/dev/null | grep -v node_modules | wc -l || echo "0")
    [ "$TRY_CATCH" -gt 0 ] && run_check "Has error handling" "pass" || run_check "Missing error handling" "warn"
  fi
  
  # 8. HTML quality (if HTML files exist)
  HTML_COUNT=$(find . -name "*.html" 2>/dev/null | grep -v node_modules | wc -l || echo "0")
  if [ "$HTML_COUNT" -gt 0 ]; then
    for html in $(find . -name "*.html" -not -path "*/node_modules/*" 2>/dev/null | head -5); do
      grep -q "charset" "$html" && run_check "$(basename $html) has charset" "pass" || run_check "$(basename $html) missing charset" "warn"
      grep -q "viewport" "$html" && run_check "$(basename $html) has viewport" "pass" || run_check "$(basename $html) missing viewport" "warn"
    done
  fi
  
  # 9. Docker quality
  if [ -f "Dockerfile" ]; then
    grep -q "FROM" Dockerfile && run_check "Dockerfile valid" "pass" || run_check "Dockerfile invalid" "fail"
    [ -f ".dockerignore" ] && run_check ".dockerignore exists" "pass" || run_check ".dockerignore missing" "warn"
  fi
  
  # 10. API documentation
  if [ -f "package.json" ] && (grep -q "express\|fastify\|koa" package.json 2>/dev/null); then
    [ -f "swagger.json" ] || [ -f "openapi.json" ] || [ -f "api-docs.md" ] && run_check "API docs exist" "pass" || run_check "No API docs" "warn"
  fi
  
  # Score
  TOTAL=$((PASS + FAIL + WARNINGS))
  SCORE=$((PASS * 100 / (TOTAL + 1)))
  
  cd - > /dev/null
  
  echo "$name|$SCORE|$PASS|$FAIL|$WARNINGS"
}

# ═══════════════════════════════════════════════════════
# Check all projects
# ═══════════════════════════════════════════════════════

RESULTS=()

# Check current repo projects
for dir in creations/*/; do
  [ -d "$dir" ] || continue
  RESET_CHECKS=""; PASS=0; FAIL=0; WARNINGS=0
  RESULTS+=("$(check_project "$dir")")
done

# Generate report
cat > "$REPORT" << REOF
# ✅ QA/QC Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repo:** $(get_repo)

## Projects Checked: ${#RESULTS[@]}

$(for r in "${RESULTS[@]}"; do
  IFS='|' read -r name score pass fail warn <<< "$r"
  EMOJI="✅"; [ "$score" -lt 70 ] && EMOJI="⚠️"; [ "$score" -lt 50 ] && EMOJI="❌"
  echo "- $EMOJI **$name**: Score $score% (✅$pass ❌$fail ⚠️$warn)"
done)

## Checks Performed
| Status | Check |
|--------|-------|
$CHECKS

## Standards (Full-Stack Level)
- ✅ README.md with ≥10 lines
- ✅ LICENSE file
- ✅ .gitignore
- ✅ No exposed secrets
- ✅ .env.example (if using env vars)
- ✅ package.json with name, description, scripts
- ✅ Start & test scripts
- ✅ Error handling in code
- ✅ No console.log in production
- ✅ HTML charset & viewport meta
- ✅ Docker config (if applicable)
- ✅ API documentation (if backend)

## Verdict
$(if [ "$FAIL" -eq 0 ]; then echo "✅ ALL PROJECTS PASS QUALITY CHECK"; elif [ "$FAIL" -le 2 ]; then echo "⚠️ MINOR ISSUES — fix before deploy"; else echo "❌ QUALITY GATE FAILED — do not deploy"; fi)

---
_Automated by QA/QC Bot ✅_
REOF

cat "$REPORT"
notify "QA/QC Bot" "Checked ${#RESULTS[@]} projects. Score: $SCORE%"
exit 0
