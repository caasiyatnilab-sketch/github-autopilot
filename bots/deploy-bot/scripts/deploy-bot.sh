#!/bin/bash
# 🚀 Deploy Bot
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

REPORT="deploy-report.md"
log INFO "🚀 Deploy Bot starting..."

# Detect project
PROJECT_TYPE="unknown"
if [ -f "package.json" ]; then
  grep -q '"react"' package.json && PROJECT_TYPE="react"
  grep -q '"next"' package.json && PROJECT_TYPE="nextjs"
  grep -q '"vue"' package.json && PROJECT_TYPE="vue"
  [ "$PROJECT_TYPE" = "unknown" ] && PROJECT_TYPE="node"
elif [ -f "index.html" ]; then
  PROJECT_TYPE="static"
elif [ -f "requirements.txt" ]; then
  PROJECT_TYPE="python"
fi

log INFO "Detected: $PROJECT_TYPE"

# If not deployable, just report and exit
if [ "$PROJECT_TYPE" = "unknown" ]; then
  cat > "$REPORT" << 'REOF'
# 🚀 Deploy Bot Report
ℹ️ No deployable project detected (bot/utility repo). Deploy not needed.
---
_Automated by Deploy Bot 🚀_
REOF
  cat "$REPORT"
  log INFO "🚀 Deploy Bot complete (nothing to deploy)"
  exit 0
fi

# Create configs if missing
CREATED=""

if [ ! -f "vercel.json" ]; then
  cat > vercel.json << 'VEOF'
{"version":2,"builds":[{"src":"**/*","use":"@vercel/static-build"}],"routes":[{"src":"/(.*)","dest":"/index.html"}]}
VEOF
  CREATED="$CREATED vercel.json"
fi

if [ ! -f "netlify.toml" ]; then
  cat > netlify.toml << 'NEOF'
[build]
  command = "npm run build"
  publish = "dist"
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
NEOF
  CREATED="$CREATED netlify.toml"
fi

cat > "$REPORT" << REOF
# 🚀 Deploy Bot Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repo:** $(get_repo)
**Project Type:** $PROJECT_TYPE

## Configs Created
${CREATED:-All configs already present ✅}

## Deploy
Push to main to auto-deploy via GitHub Pages/Vercel/Netlify.

---
_Automated by Deploy Bot 🚀_
REOF

cat "$REPORT"
log INFO "🚀 Deploy Bot complete!"
exit 0
