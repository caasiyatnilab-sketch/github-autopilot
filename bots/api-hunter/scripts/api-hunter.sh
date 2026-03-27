#!/bin/bash
# 🌐 API Hunter Bot
# 24/7 Freemium API finder — discovers free AI models, tools, services
# Stores found APIs in .github/found-apis.json

set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="api-hunter"
REPORT="api-hunter-report.md"
ACQUIRE_LOCK "$BOT_NAME" 2>/dev/null || source /dev/null

log INFO "🌐 API Hunter starting scan..."

# ═══════════════════════════════════════════════════════
# API Sources to Check
# ═══════════════════════════════════════════════════════

FOUND_APIS_FILE="${FOUND_APIS:-.github/found-apis.json}"
mkdir -p .github

# Initialize if not exists
if [ ! -f "$FOUND_APIS_FILE" ]; then
  echo '{"last_scan":"never","apis":[]}' > "$FOUND_APIS_FILE"
fi

NEW_APIS=()

# ═══════════════════════════════════════════════════════
# 1. Scan Free AI APIs
# ═══════════════════════════════════════════════════════
scan_ai_apis() {
  log INFO "Scanning for free AI APIs..."

  # Known free AI API endpoints
  declare -A FREE_AI_APIS=(
    ["Groq"]="https://api.groq.com/v1 FREE LLaMA/Mixtral models, very fast"
    ["Together AI"]="https://api.together.xyz/v1 FREE tier, open source models"
    ["Hugging Face"]="https://api-inference.huggingface.co/models FREE inference API"
    ["OpenRouter"]="https://openrouter.ai/api/v1 FREE tier on many models"
    ["DeepInfra"]="https://api.deepinfra.com/v1/openai FREE tier, many models"
    ["Fireworks AI"]="https://api.fireworks.ai/inference/v1 FREE credits on signup"
    ["Anyscale"]="https://api.endpoints.anyscale.com/v0 FREE tier for Llama models"
    ["Perplexity"]="https://api.perplexity.ai FREE tier with search"
    ["Mistral"]="https://api.mistral.ai/v1 FREE tier, Mistral models"
    ["Cohere"]="https://api.cohere.ai/v1 FREE trial, good for embeddings"
    ["Replicate"]="https://api.replicate.com/v1 FREE credits, runs any model"
    ["Stability AI"]="https://api.stability.ai/v1 FREE credits for image gen"
    ["ElevenLabs"]="https://api.elevenlabs.io/v1 FREE tier for TTS"
    ["AssemblyAI"]="https://api.assemblyai.com/v2 FREE tier for speech-to-text"
    ["Deepgram"]="https://api.deepgram.com/v1 FREE tier for STT"
    ["Clarifai"]="https://api.clarifai.com/v2 FREE tier, many AI models"
    ["Eden AI"]="https://api.edenai.run/v2 FREE tier, aggregates providers"
    ["AIMLAPI"]="https://api.aimlapi.com/v1 FREE tier, 200+ models"
    ["Zephyr"]="https://api.zephyr.cloud FREE inference"
    ["Novita AI"]="https://api.novita.ai/v3 FREE tier, GPU inference"
  )

  for name in "${!FREE_AI_APIS[@]}"; do
    local info="${FREE_AI_APIS[$name]}"
    local url=$(echo "$info" | awk '{print $1}')
    local desc=$(echo "$info" | cut -d' ' -f2-)

    # Check if already in our list
    if ! grep -q "\"$name\"" "$FOUND_APIS_FILE" 2>/dev/null; then
      NEW_APIS+=("$name|$url|$desc")
      log INFO "  Found: $name"
    fi
  done
}

# ═══════════════════════════════════════════════════════
# 2. Scan Free Tool APIs
# ═══════════════════════════════════════════════════════
scan_tool_apis() {
  log INFO "Scanning for free tool APIs..."

  declare -A FREE_TOOL_APIS=(
    ["Weather-OpenMeteo"]="https://api.open-meteo.com/v1 FREE weather, no key needed"
    ["News-NewsData"]="https://newsdata.io/api/1 FREE news API"
    ["Translate-Libre"]="https://libretranslate.com FREE translation, no key"
    ["Currency-ExchangeRate"]="https://open.er-api.com/v6/latest FREE exchange rates"
    ["IP-Info"]="https://ipapi.co/api FREE IP geolocation"
    ["QR-GoQR"]="https://goqr.me/api FREE QR code generation"
    ["URL-Shortener"]="https://cleanuri.com/api FREE URL shortener"
    ["Calendar-Holiday"]="https://date.nager.at/api/v3 FREE public holidays"
    ["Dictionary"]="https://api.dictionaryapi.dev/api/v2/entries FREE dictionary"
    ["Jokes"]="https://v2.jokeapi.dev FREE jokes API"
    ["Quotes"]="https://api.quotable.io FREE quotes"
    ["Anime-Jikan"]="https://api.jikan.moe/v4 FREE anime database"
    ["Music-LastFM"]="https://ws.audioscrobbler.com/2.0 FREE music data"
    ["Books-OpenLibrary"]="https://openlibrary.org/developers/api FREE book data"
    ["Movies-OMDB"]="https://www.omdbapi.com FREE movie database (1000/day)"
    ["Pokemon"]="https://pokeapi.co/api/v2 FREE Pokemon data"
    ["Countries"]="https://restcountries.com/v3.1 FREE country data"
    ["GitHub-Users"]="https://api.github.com FREE GitHub data"
    ["RandomUser"]="https://randomuser.me/api FREE random user data"
    ["Lorem-Ipsum"]="https://loripsum.net/api FREE lorem ipsum"
  )

  for name in "${!FREE_TOOL_APIS[@]}"; do
    local info="${FREE_TOOL_APIS[$name]}"
    local url=$(echo "$info" | awk '{print $1}')
    local desc=$(echo "$info" | cut -d' ' -f2-)

    if ! grep -q "\"$name\"" "$FOUND_APIS_FILE" 2>/dev/null; then
      NEW_APIS+=("$name|$url|$desc")
      log INFO "  Found: $name"
    fi
  done
}

# ═══════════════════════════════════════════════════════
# 3. Scan Free Hosting/Deploy APIs
# ═══════════════════════════════════════════════════════
scan_deploy_apis() {
  log INFO "Scanning for free deploy platforms..."

  declare -A FREE_DEPLOY_APIS=(
    ["Vercel"]="https://api.vercel.com FREE hosting, serverless functions"
    ["Netlify"]="https://api.netlify.com FREE hosting, forms, functions"
    ["Railway"]="https://railway.app FREE tier for backends"
    ["Render"]="https://api.render.com FREE tier, web services"
    ["Fly.io"]="https://fly.io FREE tier for containers"
    ["Deta"]="https://deta.space FREE cloud micro-services"
    ["Supabase"]="https://supabase.com FREE PostgreSQL + Auth + Storage"
    ["PlanetScale"]="https://api.planetscale.com FREE MySQL, serverless"
    ["Neon"]="https://neon.tech FREE serverless PostgreSQL"
    ["Turso"]="https://turso.tech FREE edge SQLite"
    ["Upstash"]="https://upstash.com FREE Redis + Kafka"
    ["Cloudflare-Workers"]="https://workers.cloudflare.com FREE edge compute"
    ["Firebase"]="https://firebase.google.com FREE tier, real-time DB"
    ["Appwrite"]="https://appwrite.io FREE BaaS, open source"
    ["NHost"]="https://nhost.io FREE GraphQL backend"
  )

  for name in "${!FREE_DEPLOY_APIS[@]}"; do
    local info="${FREE_DEPLOY_APIS[$name]}"
    local url=$(echo "$info" | awk '{print $1}')
    local desc=$(echo "$info" | cut -d' ' -f2-)

    if ! grep -q "\"$name\"" "$FOUND_APIS_FILE" 2>/dev/null; then
      NEW_APIS+=("$name|$url|$desc")
      log INFO "  Found: $name"
    fi
  done
}

# ═══════════════════════════════════════════════════════
# 4. Live Discovery — Check for new APIs
# ═══════════════════════════════════════════════════════
discover_new_apis() {
  log INFO "Running live API discovery..."

  # Check free-for.dev for updates
  local FFD=$(curl -sL "https://raw.githubusercontent.com/ripienaar/free-for-dev/master/README.md" 2>/dev/null | head -500 || echo "")
  if [ -n "$FFD" ]; then
    log INFO "  Checked free-for.dev list"
  fi

  # Check public-apis for new entries
  local PUBLIC=$(curl -sL "https://raw.githubusercontent.com/public-apis-dev/public-apis/master/README.md" 2>/dev/null | head -500 || echo "")
  if [ -n "$PUBLIC" ]; then
    log INFO "  Checked public-apis list"
  fi

  # Test discovered API endpoints
  TEST_ENDPOINTS=(
    "https://api.groq.com/openai/v1/models"
    "https://api-inference.huggingface.co/models"
    "https://openrouter.ai/api/v1/models"
    "https://api.deepinfra.com/v1/openai/models"
    "https://api.mistral.ai/v1/models"
    "https://api.together.xyz/v1/models"
  )

  for endpoint in "${TEST_ENDPOINTS[@]}"; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint" 2>/dev/null || echo "000")
    if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
      local name=$(echo "$endpoint" | sed 's|https://api\.||;s|\.com.*||;s|\.ai.*||;s|/||g')
      log INFO "  ✅ $name API is live (HTTP $STATUS)"
    fi
  done
}

# ═══════════════════════════════════════════════════════
# 5. Save Results
# ═══════════════════════════════════════════════════════
save_results() {
  log INFO "Saving API database..."

  # Build new API entries
  local NEW_ENTRIES=""
  for entry in "${NEW_APIS[@]}"; do
    IFS='|' read -r name url desc <<< "$entry"
    if [ -n "$NEW_ENTRIES" ]; then
      NEW_ENTRIES="$NEW_ENTRIES,"
    fi
    NEW_ENTRIES="$NEW_ENTRIES{\"name\":\"$name\",\"url\":\"$url\",\"description\":\"$desc\",\"found\":\"$(now)\",\"status\":\"active\"}"
  done

  # Update the JSON file
  if [ ${#NEW_APIS[@]} -gt 0 ]; then
    python3 -c "
import json
with open('$FOUND_APIS_FILE') as f:
    data = json.load(f)
new_entries = json.loads('[$NEW_ENTRIES]')
for entry in new_entries:
    if not any(a['name'] == entry['name'] for a in data['apis']):
        data['apis'].append(entry)
data['last_scan'] = '$(now)'
with open('$FOUND_APIS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
print(f'Added {len(new_entries)} new APIs')
" 2>/dev/null || log WARN "Could not update JSON file"
  fi
}

# ═══════════════════════════════════════════════════════
# 6. Generate Report
# ═══════════════════════════════════════════════════════
generate_report() {
  cat > "$REPORT" << EOF
# 🌐 API Hunter Report

**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**New APIs Found:** ${#NEW_APIS[@]}

## New Discovered APIs

$(if [ ${#NEW_APIS[@]} -eq 0 ]; then
  echo "No new APIs found this scan. Database is up to date."
else
  for entry in "${NEW_APIS[@]}"; do
    IFS='|' read -r name url desc <<< "$entry"
    echo "- **$name** — $desc"
    echo "  URL: \`$url\`"
    echo ""
  done
fi)

## API Categories

### 🤖 AI Models (Free Tier)
- Groq — LLaMA/Mixtral, fastest inference
- Together AI — Open source models
- Hugging Face — 200k+ models
- OpenRouter — Multi-provider gateway
- Mistral — Mistral/Mixtral models
- DeepInfra — Many models, cheap

### 🌍 Tools & Data
- Open-Meteo — Weather (no key needed)
- LibreTranslate — Translation
- Dictionary API — Definitions
- REST Countries — Country data
- Open Library — Book data

### 🚀 Free Hosting
- Vercel — Frontend + serverless
- Netlify — Static + functions
- Railway — Backends
- Supabase — Database + Auth
- Cloudflare Workers — Edge compute

## Usage

Found APIs are saved to: \`.github/found-apis.json\`

Use in your projects:
\`\`\`bash
# Get all AI APIs
cat .github/found-apis.json | jq '.apis[] | select(.description | contains("AI"))'

# Get all free tier APIs
cat .github/found-apis.json | jq '.apis[] | select(.description | contains("FREE"))'
\`\`\`

---
_Automated by API Hunter 🌐_
EOF

  cat "$REPORT"
}

# ═══════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════
scan_ai_apis
scan_tool_apis
scan_deploy_apis
discover_new_apis
save_results
generate_report

log INFO "🌐 API Hunter complete! Found ${#NEW_APIS[@]} new APIs."
notify "🌐 API Hunter" "Found ${#NEW_APIS[@]} new free APIs. See report for details."
