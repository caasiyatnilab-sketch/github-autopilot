#!/bin/bash
# 🚀 GitHub Autopilot — One-Command Setup
# Installs the full bot army into your repository
#
# Usage:
#   bash <(curl -s https://raw.githubusercontent.com/USER/github-autopilot/main/setup.sh)
#
# Or install specific bot:
#   bash setup.sh --bot api-hunter

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🚀 GitHub Autopilot — Bot Army Setup      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo -e "${RED}❌ Not in a git repo. Run from your repo root.${NC}"
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"
REPO_NAME=$(basename "$REPO_ROOT")
echo -e "${GREEN}📂 Repo: $REPO_NAME${NC}"

BOT_FILTER="${1:-all}"
BASE_URL="https://raw.githubusercontent.com/YOUR_USERNAME/github-autopilot/main"

# Download helper
download() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  curl -sL "$url" -o "$dest" 2>/dev/null && echo "  ✅ $(basename $dest)" || echo "  ⚠️ Failed: $(basename $dest)"
}

# Install shared utilities
echo ""
echo "📦 Installing shared utilities..."
mkdir -p shared
download "$BASE_URL/shared/utils.sh" "shared/utils.sh"
chmod +x shared/utils.sh

# Bot definitions
ALL_BOTS="health-checker security-scanner auto-updater issue-pr-manager auto-fixer weekly-reporter api-hunter repo-builder scraper-bot deploy-bot copilot-rotator ai-agent-factory autopilot"

install_bot() {
  local bot="$1"
  echo ""
  echo -e "${BLUE}🤖 Installing: $bot${NC}"
  mkdir -p "bots/$bot/scripts" "bots/$bot/.github/workflows"
  download "$BASE_URL/bots/$bot/scripts/$bot.sh" "bots/$bot/scripts/$bot.sh"
  download "$BASE_URL/bots/$bot/.github/workflows/$bot.yml" "bots/$bot/.github/workflows/$bot.yml"
  chmod +x "bots/$bot/scripts/$bot.sh" 2>/dev/null
}

if [ "$BOT_FILTER" = "all" ]; then
  for bot in $ALL_BOTS; do install_bot "$bot"; done
else
  install_bot "$BOT_FILTER"
fi

# Install config template
echo ""
echo "⚙️ Installing config..."
if [ ! -f ".github/autopilot.yml" ]; then
  cat > .github/autopilot.yml << 'EOF'
# GitHub Autopilot Configuration
autopilot:
  enabled: true

api_hunter:
  enabled: true
  categories: [ai_models, tools, deploy]

repo_builder:
  enabled: true
  auto_create: false

scraper_bot:
  enabled: true
  targets: []

deploy_bot:
  enabled: true
  providers: [vercel, netlify, github_pages]

copilot_rotator:
  enabled: true
  providers: [groq, openrouter, mistral]

ai_agent_factory:
  enabled: true
  templates: [chatbot, code_reviewer]
EOF
  echo "  ✅ .github/autopilot.yml"
else
  echo "  ℹ️ Config already exists"
fi

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✅ Autopilot Installed!               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "Installed bots:"
for bot in $ALL_BOTS; do
  [ -f "bots/$bot/scripts/$bot.sh" ] && echo "  ✅ $bot" || echo "  ⏭️ $bot (skipped)"
done
echo ""
echo "Next steps:"
echo "  1. git add -A && git commit -m '🚀 Install GitHub Autopilot'"
echo "  2. git push"
echo "  3. Go to repo Settings → Actions → enable workflows"
echo ""
echo "Run manually:"
echo "  gh workflow run autopilot.yml"
echo ""
echo "Add API keys (GitHub Secrets):"
echo "  - GROQ_API_KEY (free: console.groq.com)"
echo "  - OPENROUTER_API_KEY (free: openrouter.ai/keys)"
echo "  - MISTRAL_API_KEY (free: console.mistral.ai)"
echo ""
echo -e "${BLUE}Your repos will run themselves. 🤖${NC}"
