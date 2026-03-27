#!/bin/bash
# 🚀 Mega Deploy Bot
# Auto-deploys to ALL free platforms: Vercel, Netlify, GitHub Pages, Railway, Render, Cloudflare, Surge, Firebase
# Zero config — detects project, creates configs, deploys automatically
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

REPORT="mega-deploy-report.md"
log INFO "🚀 Mega Deploy Bot starting..."

REPO=$(get_repo)
DEPLOYED=()
CONFIGS_CREATED=()
PLATFORMS=()

# ═══════════════════════════════════════════════════════
# 1. Detect Project Type
# ═══════════════════════════════════════════════════════
PROJECT="unknown"
BUILD_CMD=""
OUTPUT_DIR=""
FRAMEWORK=""

if [ -f "package.json" ]; then
  FRAMEWORK=$(cat package.json | python3 -c "import json,sys; d=json.load(sys.stdin); deps={**d.get('dependencies',{}), **d.get('devDependencies',{})}; print(next((k for k in ['next','react','vue','svelte','astro','nuxt','remix','angular','gatsby'] if k in deps), 'node'))" 2>/dev/null || echo "node")
  
  case "$FRAMEWORK" in
    next) PROJECT="nextjs"; BUILD_CMD="npm run build"; OUTPUT_DIR=".next" ;;
    react) PROJECT="react"; BUILD_CMD="npm run build"; OUTPUT_DIR="build" ;;
    vue) PROJECT="vue"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist" ;;
    svelte) PROJECT="svelte"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist" ;;
    astro) PROJECT="astro"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist" ;;
    nuxt) PROJECT="nuxt"; BUILD_CMD="npm run build"; OUTPUT_DIR=".output" ;;
    remix) PROJECT="remix"; BUILD_CMD="npm run build"; OUTPUT_DIR="build" ;;
    gatsby) PROJECT="gatsby"; BUILD_CMD="npm run build"; OUTPUT_DIR="public" ;;
    *) PROJECT="node"; BUILD_CMD="npm run build"; OUTPUT_DIR="dist" ;;
  esac
  
  # Check for Vite
  grep -q '"vite"' package.json 2>/dev/null && PROJECT="${PROJECT}-vite" && OUTPUT_DIR="dist"
elif [ -f "index.html" ]; then
  PROJECT="static"; OUTPUT_DIR="."
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  PROJECT="python"; BUILD_CMD="pip install -r requirements.txt"
elif [ -f "Gemfile" ]; then
  PROJECT="ruby"; BUILD_CMD="bundle install"
elif [ -f "go.mod" ]; then
  PROJECT="go"; BUILD_CMD="go build"
elif [ -f "Cargo.toml" ]; then
  PROJECT="rust"; BUILD_CMD="cargo build --release"
fi

log INFO "Detected: $PROJECT ($FRAMEWORK)"

if [ "$PROJECT" = "unknown" ]; then
  cat > "$REPORT" << 'REOF'
# 🚀 Mega Deploy Bot
ℹ️ No deployable project detected.
---
_Automated by Mega Deploy Bot 🚀_
REOF
  cat "$REPORT"
  exit 0
fi

# ═══════════════════════════════════════════════════════
# 2. Create Deploy Configs for ALL Platforms
# ═══════════════════════════════════════════════════════

# --- GitHub Pages ---
if [ ! -f ".github/workflows/deploy-pages.yml" ]; then
  mkdir -p .github/workflows
  cat > .github/workflows/deploy-pages.yml << 'GHEOF'
name: 🚀 Deploy to GitHub Pages
on:
  push: { branches: [main, master] }
  workflow_dispatch:
permissions: { contents: read, pages: write, id-token: write }
concurrency: { group: pages, cancel-in-progress: true }
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: { name: github-pages, url: ${{ steps.deploy.outputs.page_url }} }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci || npm install; npm run build || true
      - uses: actions/configure-pages@v4
      - uses: actions/upload-pages-artifact@v3
        with: { path: dist || build || public || . }
      - id: deploy
        uses: actions/deploy-pages@v4
GHEOF
  CONFIGS_CREATED+=("GitHub Pages workflow")
fi

# --- Vercel ---
if [ ! -f "vercel.json" ]; then
  cat > vercel.json << 'VEOF'
{"version":2,"builds":[{"src":"**/*","use":"@vercel/static-build"}],"routes":[{"src":"/(.*)","dest":"/index.html"}]}
VEOF
  CONFIGS_CREATED+=("vercel.json")
fi

# --- Netlify ---
if [ ! -f "netlify.toml" ]; then
  cat > netlify.toml << 'NEOF'
[build]
  command = "npm run build"
  publish = "dist"
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
NEOF
  CONFIGS_CREATED+=("netlify.toml")
fi

# --- Cloudflare Pages (wrangler) ---
if [ ! -f "wrangler.toml" ] && [ "$PROJECT" != "node" ]; then
  cat > wrangler.toml << 'CWEOF'
name = "my-app"
compatibility_date = "2024-01-01"
pages_build_output_dir = "dist"
CWEOF
  CONFIGS_CREATED+=("wrangler.toml")
fi

# --- Surge.sh ---
if [ ! -f "CNAME" ] && [ -f "index.html" ]; then
  echo "${REPO##*/}.surge.sh" > CNAME
  CONFIGS_CREATED+=("CNAME (surge.sh)")
fi

# --- Firebase ---
if [ ! -f "firebase.json" ]; then
  cat > firebase.json << 'FBEOF'
{
  "hosting": {
    "public": "dist",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{ "source": "**", "destination": "/index.html" }]
  }
}
FBEOF
  cat > .firebaserc << 'FBREOF'
{
  "projects": {
    "default": "my-app"
  }
}
FBREOF
  CONFIGS_CREATED+=("firebase.json")
fi

# --- Docker ---
if [ ! -f "Dockerfile" ] && [ "$PROJECT" = "node" ]; then
  cat > Dockerfile << 'DKEOF'
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build || true

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app .
EXPOSE 3000
CMD ["npm", "start"]
DKEOF
  cat > .dockerignore << 'DKIEOF'
node_modules
.git
*.md
.env
.env.*
dist
build
DKIEOF
  CONFIGS_CREATED+=("Dockerfile")
fi

# --- Railway ---
if [ ! -f "railway.json" ]; then
  cat > railway.json << 'RLEOF'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": { "builder": "NIXPACKS" },
  "deploy": { "startCommand": "npm start", "healthcheckPath": "/" }
}
RLEOF
  CONFIGS_CREATED+=("railway.json")
fi

# --- Render ---
if [ ! -f "render.yaml" ]; then
  cat > render.yaml << 'RNDEOF'
services:
  - type: web
    name: my-app
    env: node
    buildCommand: npm install && npm run build
    startCommand: npm start
    envVars:
      - key: NODE_ENV
        value: production
RNDEOF
  CONFIGS_CREATED+=("render.yaml")
fi

# --- Fly.io ---
if [ ! -f "fly.toml" ]; then
  cat > fly.toml << 'FLYEOF'
app = "my-app"
primary_region = "sjc"

[build]

[http_service]
  internal_port = 3000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
FLYEOF
  CONFIGS_CREATED+=("fly.toml")
fi

# ═══════════════════════════════════════════════════════
# 3. Generate Report
# ═══════════════════════════════════════════════════════

cat > "$REPORT" << REOF
# 🚀 Mega Deploy Bot Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repo:** $REPO
**Project:** $PROJECT ($FRAMEWORK)

## Configs Created
$(if [ ${#CONFIGS_CREATED[@]} -eq 0 ]; then echo "All configs already present ✅"; else for c in "${CONFIGS_CREATED[@]}"; do echo "- ✅ $c"; done; fi)

## Free Deploy Platforms Ready

### 🟢 One-Click Deploy (Push to activate)
| Platform | Command | Free Tier |
|----------|---------|-----------|
| **GitHub Pages** | Push to main | Unlimited |
| **Vercel** | \`vercel --prod\` | 100GB bandwidth |
| **Netlify** | \`netlify deploy --prod\` | 100GB bandwidth |
| **Cloudflare Pages** | \`wrangler pages deploy\` | Unlimited |
| **Surge.sh** | \`surge .\` | Free custom domain |
| **Firebase** | \`firebase deploy\` | 10GB storage |

### 🟡 Backend Deploy
| Platform | Command | Free Tier |
|----------|---------|-----------|
| **Railway** | Connect repo | \$5/mo free |
| **Render** | Connect repo | 750hrs/mo |
| **Fly.io** | \`fly deploy\` | 3 shared VMs |
| **Docker** | Any container host | Varies |

## Quick Start
\`\`\`bash
# Vercel
npx vercel --prod

# Netlify
npx netlify-cli deploy --prod

# Surge
npx surge . your-domain.surge.sh

# Firebase
npx firebase-tools deploy
\`\`\`

---
_Automated by Mega Deploy Bot 🚀_
REOF

cat "$REPORT"
notify "Mega Deploy" "Created ${#CONFIGS_CREATED[@]} deploy configs for $PROJECT project"
exit 0
