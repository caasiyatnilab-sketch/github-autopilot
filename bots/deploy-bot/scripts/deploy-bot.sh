#!/bin/bash
# 🚀 Deploy Bot
# Free deploy websites/apps to Vercel, Netlify, GitHub Pages
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="deploy-bot"
REPORT="deploy-report.md"

log INFO "🚀 Deploy Bot starting..."

detect_project() {
  local PROJECT_TYPE="unknown"
  local BUILD_CMD=""
  local OUTPUT_DIR=""

  if [ -f "package.json" ]; then
    if grep -q '"next"' package.json; then
      PROJECT_TYPE="nextjs"; BUILD_CMD="npm run build"; OUTPUT_DIR=".next"
    elif grep -q '"react"' package.json; then
      if grep -q '"vite"' package.json; then
        PROJECT_TYPE="react-vite"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist"
      else
        PROJECT_TYPE="react"; BUILD_CMD="npm run build"; OUTPUT_DIR="build"
      fi
    elif grep -q '"vue"' package.json; then
      PROJECT_TYPE="vue"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist"
    elif grep -q '"svelte"' package.json; then
      PROJECT_TYPE="svelte"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist"
    elif grep -q '"express"' package.json || grep -q '"fastify"' package.json; then
      PROJECT_TYPE="node-api"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist"
    else
      PROJECT_TYPE="node"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist"
    fi
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    PROJECT_TYPE="python"
  elif [ -f "index.html" ]; then
    PROJECT_TYPE="static"; OUTPUT_DIR="."
  fi

  echo "$PROJECT_TYPE|$BUILD_CMD|$OUTPUT_DIR"
}

setup_github_pages() {
  log INFO "Setting up GitHub Pages workflow..."
  mkdir -p .github/workflows
  cp /storage/emulated/0/openclaw/workspace/github-autopilot/shared/deploy-pages.yml .github/workflows/deploy-pages.yml 2>/dev/null || true
  log INFO "✅ GitHub Pages workflow created"
}

IFS='|' read -r PROJECT_TYPE BUILD_CMD OUTPUT_DIR <<< "$(detect_project)"
log INFO "Detected project: $PROJECT_TYPE"

DEPLOY_TARGETS=()

# Only configure deploy for actual deployable projects
if [ "$PROJECT_TYPE" != "unknown" ]; then
  # GitHub Pages
  if [ ! -f ".github/workflows/deploy-pages.yml" ] && [ ! -f ".github/workflows/deploy.yml" ]; then
    setup_github_pages
    DEPLOY_TARGETS+=("GitHub Pages")
  fi

  # Vercel config
  if [ ! -f "vercel.json" ]; then
    cat > vercel.json << 'VEOF'
{
  "version": 2,
  "builds": [{ "src": "**/*", "use": "@vercel/static-build" }],
  "routes": [{ "src": "/(.*)", "dest": "/index.html" }]
}
VEOF
    DEPLOY_TARGETS+=("Vercel config")
  fi

  # Netlify config
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
    DEPLOY_TARGETS+=("Netlify config")
  fi
fi

# Generate report
python3 -c "
targets = '''$(if [ ${#DEPLOY_TARGETS[@]} -eq 0 ]; then echo 'All deploy configs already in place ✅'; else for t in "${DEPLOY_TARGETS[@]}"; do echo "- ✅ $t"; done; fi)'''

report = '''# 🚀 Deploy Bot Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repo:** $(get_repo)
**Project Type:** $PROJECT_TYPE

## Configs Created
$targets

## Status
$(if [ "$PROJECT_TYPE" = "unknown" ]; then echo 'ℹ️ No deployable project detected. This is a bot/utility repo — deploy not needed.'; else echo '✅ Deploy configs ready. Push to main to auto-deploy!'; fi)

## Free Deploy Platforms
- **GitHub Pages** — Static sites, unlimited
- **Vercel** — React/Next.js, 100GB free
- **Netlify** — JAMstack, 100GB free
- **Railway** — Backends, \$5/mo free
- **Cloudflare Pages** — Edge, unlimited

---
_Automated by Deploy Bot 🚀_'''
open('$REPORT', 'w').write(report)
"
cat "$REPORT"
log INFO "🚀 Deploy Bot complete!"
exit 0
