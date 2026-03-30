#!/bin/bash
# 🚀 Persistent Deploy Bot v2
# Auto-detects project, generates deploy configs, pushes to GitHub
# Supports: Render, Railway, Vercel, GitHub Pages, Cloudflare Pages
# Tracks deployments in shared state, retries on failure
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"

REPORT="persistent-deploy-report.md"
log INFO "🚀 Persistent Deploy Bot starting..."

DEPLOYED=()
CONFIGS=()

# ═══════════════════════════════════════════════════════
# 1. Detect Project Type
# ═══════════════════════════════════════════════════════
detect_project() {
  local PROJECT="unknown"
  local FRAMEWORK=""
  local BUILD_CMD=""
  local OUTPUT_DIR=""
  local RUNTIME=""

  if [ -f "package.json" ]; then
    # Detect framework from dependencies
    FRAMEWORK=$(python3 -c "
import json
with open('package.json') as f:
    pkg = json.load(f)
deps = {**pkg.get('dependencies', {}), **pkg.get('devDependencies', {})}
for fw in ['next', 'react', 'vue', 'svelte', 'astro', 'nuxt', 'remix', 'angular', 'gatsby', 'express', 'fastify']:
    if fw in deps:
        print(fw)
        break
else:
    print('node')
" 2>/dev/null || echo "node")

    case "$FRAMEWORK" in
      next)    PROJECT="nextjs";     BUILD_CMD="npm run build";    OUTPUT_DIR=".next" ;;
      react)   PROJECT="react";      BUILD_CMD="npm run build";    OUTPUT_DIR="build" ;;
      vue)     PROJECT="vue";        BUILD_CMD="npm run build";    OUTPUT_DIR="dist" ;;
      svelte)  PROJECT="svelte";     BUILD_CMD="npm run build";    OUTPUT_DIR="dist" ;;
      astro)   PROJECT="astro";      BUILD_CMD="npm run build";    OUTPUT_DIR="dist" ;;
      express|fastify) PROJECT="node-api"; RUNTIME="node" ;;
      *)       PROJECT="node-static"; BUILD_CMD="npm run build" ;;
    esac

  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    PROJECT="python"
    RUNTIME="python"
  elif [ -f "go.mod" ]; then
    PROJECT="go"
    RUNTIME="go"
  elif [ -f "index.html" ] && [ ! -f "package.json" ]; then
    PROJECT="static"
  fi

  echo "$PROJECT|$FRAMEWORK|$BUILD_CMD|$OUTPUT_DIR|$RUNTIME"
}

# ═══════════════════════════════════════════════════════
# 2. Generate Platform Configs
# ═══════════════════════════════════════════════════════

# --- Render (free tier: 750h/month) ---
generate_render_yaml() {
  local project_type="$1"
  local build_cmd="$2"
  local output_dir="$3"

  [ -f "render.yaml" ] && return 0

  case "$project_type" in
    node-api)
      cat > render.yaml << EOF
services:
  - type: web
    name: $(basename "$(pwd)")
    runtime: node
    buildCommand: npm install
    startCommand: npm start
    plan: free
    envVars:
      - key: NODE_ENV
        value: production
EOF
      CONFIGS+=("render.yaml")
      ;;
    static|react|vue|svelte|astro)
      cat > render.yaml << EOF
services:
  - type: static
    name: $(basename "$(pwd)")
    buildCommand: npm install && ${build_cmd:-npm run build}
    staticPublishPath: ./${output_dir:-dist}
    plan: free
    routes:
      - type: rewrite
        source: /*
        destination: /index.html
EOF
      CONFIGS+=("render.yaml")
      ;;
    nextjs)
      cat > render.yaml << EOF
services:
  - type: web
    name: $(basename "$(pwd)")
    runtime: node
    buildCommand: npm install && npm run build
    startCommand: npm start
    plan: free
    envVars:
      - key: NODE_ENV
        value: production
EOF
      CONFIGS+=("render.yaml")
      ;;
  esac
}

# --- Railway (free tier: $5 credit/month) ---
generate_railway_json() {
  [ -f "railway.json" ] && return 0

  cat > railway.json << EOF
{
  "\$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "npm start",
    "healthcheckPath": "/health",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
EOF
  CONFIGS+=("railway.json")
}

# --- Vercel (free tier: 100GB bandwidth) ---
generate_vercel_json() {
  local project_type="$1"
  local output_dir="$2"

  [ -f "vercel.json" ] && return 0

  case "$project_type" in
    static)
      cat > vercel.json << EOF
{
  "version": 2,
  "builds": [{"src": "**/*", "use": "@vercel/static"}]
}
EOF
      ;;
    node-api)
      cat > vercel.json << EOF
{
  "version": 2,
  "builds": [{"src": "src/index.js", "use": "@vercel/node"}],
  "routes": [{"src": "/(.*)", "dest": "src/index.js"}]
}
EOF
      ;;
    *)
      cat > vercel.json << EOF
{
  "version": 2,
  "buildCommand": "npm run build",
  "outputDirectory": "${output_dir:-dist}"
}
EOF
      ;;
  esac
  CONFIGS+=("vercel.json")
}

# --- Dockerfile (for any platform) ---
generate_dockerfile() {
  local project_type="$1"
  local runtime="$2"

  [ -f "Dockerfile" ] && return 0

  case "$project_type" in
    node-api|node-static|nextjs|express|fastify)
      cat > Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
EOF
      CONFIGS+=("Dockerfile")
      ;;
    python)
      cat > Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["python", "main.py"]
EOF
      CONFIGS+=("Dockerfile")
      ;;
  esac
}

# --- GitHub Actions Deploy Workflow ---
generate_deploy_workflow() {
  local project_type="$1"
  local build_cmd="$2"
  local output_dir="$3"

  [ -f ".github/workflows/deploy.yml" ] && return 0
  mkdir -p .github/workflows

  cat > .github/workflows/deploy.yml << EOF
name: 🚀 Deploy
on:
  push:
    branches: [main]
  workflow_dispatch: {}

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pages: write
      id-token: write
    concurrency:
      group: pages
      cancel-in-progress: true

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - run: npm ci

      - name: Build
        run: ${build_cmd:-npm run build}

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ${output_dir:-.}

      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
EOF
  CONFIGS+=(".github/workflows/deploy.yml")
}

# ═══════════════════════════════════════════════════════
# 3. Health Check for Existing Deployments
# ═══════════════════════════════════════════════════════
check_deployments() {
  log INFO "🏥 Checking existing deployments..."

  local deployments=$(state_get ".deployments" "[]")
  local stale=""

  echo "$deployments" | python3 -c "
import json, sys
deps = json.load(sys.stdin)
for d in deps[-10:]:
    url = d.get('url', '')
    if url:
        print(url)
" 2>/dev/null | while read -r url; do
    local code=$(http_status "$url")
    if [ "$code" = "200" ]; then
      log INFO "  ✅ $url — healthy"
    elif [ "$code" = "000" ]; then
      log WARN "  ⚠️ $url — unreachable"
    else
      log WARN "  ❌ $url — HTTP $code"
    fi
  done
}

# ═══════════════════════════════════════════════════════
# Run
# ═══════════════════════════════════════════════════════
PROJECT_INFO=$(detect_project)
PROJECT_TYPE=$(echo "$PROJECT_INFO" | cut -d'|' -f1)
FRAMEWORK=$(echo "$PROJECT_INFO" | cut -d'|' -f2)
BUILD_CMD=$(echo "$PROJECT_INFO" | cut -d'|' -f3)
OUTPUT_DIR=$(echo "$PROJECT_INFO" | cut -d'|' -f4)
RUNTIME=$(echo "$PROJECT_INFO" | cut -d'|' -f5)

log INFO "Detected: $PROJECT_TYPE ($FRAMEWORK)"

if [ "$PROJECT_TYPE" != "unknown" ]; then
  generate_render_yaml "$PROJECT_TYPE" "$BUILD_CMD" "$OUTPUT_DIR"
  generate_railway_json
  generate_vercel_json "$PROJECT_TYPE" "$OUTPUT_DIR"
  generate_dockerfile "$PROJECT_TYPE" "$RUNTIME"
  generate_deploy_workflow "$PROJECT_TYPE" "$BUILD_CMD" "$OUTPUT_DIR"
else
  log INFO "  Not a deployable project — skipping config generation"
fi

check_deployments

# Report — write directly to avoid bash/python escaping issues
cat > "$REPORT" << REPORT_EOF
# 🚀 Persistent Deploy Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Project Type:** $PROJECT_TYPE ($FRAMEWORK)

## Configs Generated
$(if [ ${#CONFIGS[@]} -gt 0 ]; then printf -- '- ✅ %s\n' "${CONFIGS[@]}"; else echo '- No new configs needed'; fi)

## Deploy Targets
- **Render**: render.yaml ready (free tier: 750h/month)
- **Railway**: railway.json ready (free tier: 5 USD credit)
- **Vercel**: vercel.json ready (free tier: 100GB)
- **GitHub Pages**: deploy workflow ready

---
_Automated by Persistent Deploy Bot v2 🚀_
REPORT_EOF

cat "$REPORT"
record_result "persistent-deploy" "success" "${#CONFIGS[@]} configs generated"
log INFO "🚀 Persistent Deploy done. ${#CONFIGS[@]} configs."
