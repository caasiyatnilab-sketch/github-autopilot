#!/bin/bash
# 🚀 Deploy Bot
# Free deploy websites/apps to Vercel, Netlify, GitHub Pages
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="deploy-bot"
REPORT="deploy-report.md"

log INFO "🚀 Deploy Bot starting..."

# ═══════════════════════════════════════════════════════
# Detect Project Type
# ═══════════════════════════════════════════════════════
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
    elif grep -q '"astro"' package.json; then
      PROJECT_TYPE="astro"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist"
    elif grep -q '"express"' package.json || grep -q '"fastify"' package.json; then
      PROJECT_TYPE="node-api"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist"
    else
      PROJECT_TYPE="node"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist"
    fi
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    PROJECT_TYPE="python"
  elif [ -f "index.html" ]; then
    PROJECT_TYPE="static"; OUTPUT_DIR="."
  elif [ -f "Gemfile" ]; then
    PROJECT_TYPE="ruby"
  elif [ -f "go.mod" ]; then
    PROJECT_TYPE="go"
  fi

  echo "$PROJECT_TYPE|$BUILD_CMD|$OUTPUT_DIR"
}

# ═══════════════════════════════════════════════════════
# GitHub Pages Deploy
# ═══════════════════════════════════════════════════════
setup_github_pages() {
  log INFO "Setting up GitHub Pages deployment..."

  mkdir -p .github/workflows

  cat > .github/workflows/deploy-pages.yml << 'EOF'
name: 🚀 Deploy to GitHub Pages

on:
  push:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4

      - name: 📦 Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: 📦 Install & Build
        run: |
          npm ci || npm install
          npm run build || true

      - name: 📄 Setup Pages
        uses: actions/configure-pages@v4

      - name: 📤 Upload
        uses: actions/upload-pages-artifact@v3
        with:
          path: dist || build || _site || .

      - name: 🚀 Deploy
        id: deployment
        uses: actions/deploy-pages@v4
EOF

  log INFO "✅ GitHub Pages workflow created"
}

# ═══════════════════════════════════════════════════════
# Auto-Detect & Configure
# ═══════════════════════════════════════════════════════

IFS='|' read -r PROJECT_TYPE BUILD_CMD OUTPUT_DIR <<< "$(detect_project)"
log INFO "Detected project: $PROJECT_TYPE"

DEPLOY_TARGETS=()

# Check for existing deploy configs
if [ ! -f ".github/workflows/deploy-pages.yml" ] && [ ! -f ".github/workflows/deploy.yml" ]; then
  setup_github_pages
  DEPLOY_TARGETS+=("GitHub Pages")
fi

# Check for Vercel
if [ ! -f "vercel.json" ] && [ "$PROJECT_TYPE" != "static" ]; then
  cat > vercel.json << EOF
{
  "version": 2,
  "builds": [
    { "src": "**/*", "use": "@vercel/static-build" }
  ],
  "routes": [
    { "src": "/(.*)", "dest": "/$1" }
  ]
}
EOF
  DEPLOY_TARGETS+=("Vercel (config created)")
fi

# Check for Netlify
if [ ! -f "netlify.toml" ] && [ -n "$OUTPUT_DIR" ]; then
  cat > netlify.toml << EOF
[build]
  command = "${BUILD_CMD:-npm run build}"
  publish = "${OUTPUT_DIR:-dist}"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
EOF
  DEPLOY_TARGETS+=("Netlify (config created)")
fi

# Check for Docker
if [ ! -f "Dockerfile" ] && [ "$PROJECT_TYPE" = "node-api" ]; then
  cat > Dockerfile << EOF
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
EOF
  cat > .dockerignore << 'EOF'
node_modules
.git
*.md
.env
EOF
  DEPLOY_TARGETS+=("Docker")
fi

# Generate report
cat > "$REPORT" << EOF
# 🚀 Deploy Bot Report

**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Project Type:** $PROJECT_TYPE

## Deploy Targets Configured
$(if [ ${#DEPLOY_TARGETS[@]} -eq 0 ]; then
  echo "All deploy targets already configured ✅"
else
  for t in "${DEPLOY_TARGETS[@]}"; do
    echo "- ✅ $t"
  done
fi)

## Quick Deploy

### GitHub Pages
Push to main — auto-deploys via Actions.

### Vercel
\`\`\`bash
npm i -g vercel
vercel --prod
\`\`\`

### Netlify
\`\`\`bash
npm i -g netlify-cli
netlify deploy --prod
\`\`\`

## Free Deploy Platforms
| Platform | Best For | Free Tier |
|----------|----------|-----------|
| GitHub Pages | Static sites | Unlimited |
| Vercel | Next.js, React | 100GB bandwidth |
| Netlify | Static, JAMstack | 100GB bandwidth |
| Railway | Backends, DBs | $5/mo free |
| Render | Full-stack | 750hrs/mo |
| Fly.io | Containers | 3 shared VMs |
| Cloudflare Pages | Edge sites | Unlimited |

---
_Automated by Deploy Bot 🚀_
EOF

cat "$REPORT"
log INFO "🚀 Deploy Bot complete!"
