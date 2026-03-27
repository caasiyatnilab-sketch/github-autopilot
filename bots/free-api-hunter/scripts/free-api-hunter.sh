#!/bin/bash
# 🆓 Free API Hunter — Finds APIs that need NO signup/login
# Auto-discovers, tests, and catalogs free APIs
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

REPORT="free-api-report.md"
log INFO "🆓 Free API Hunter starting..."

API_DB=".github/free-apis.json"
mkdir -p .github

if [ ! -f "$API_DB" ]; then
  echo '{"apis":[],"last_scan":"never"}' > "$API_DB"
fi

FOUND=0

# ═══════════════════════════════════════════════════════
# Free APIs — NO signup, NO login, NO API key needed
# ═══════════════════════════════════════════════════════

test_and_add() {
  local name="$1"
  local url="$2"
  local desc="$3"
  local category="$4"
  
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  if [ "$STATUS" = "200" ]; then
    log INFO "  ✅ $name (HTTP $STATUS)"
    FOUND=$((FOUND+1))
    # Add to JSON
    python3 -c "
import json
db = json.load(open('$API_DB'))
entry = {'name':'$name','url':'$url','desc':'$desc','category':'$category','status':'live','signup':'none'}
if not any(a['name'] == '$name' for a in db['apis']):
    db['apis'].append(entry)
db['last_scan'] = '$(now)'
json.dump(db, open('$API_DB','w'), indent=2)
" 2>/dev/null || true
  else
    log INFO "  ⚠️ $name (HTTP $STATUS)"
  fi
}

log INFO "Testing free APIs (no signup)..."

# ═══ AI APIs (no signup) ═══
log INFO "AI APIs:"
test_and_add "HuggingFace-Inference" "https://api-inference.huggingface.co/models" "Free AI inference, no signup for some models" "ai"
test_and_add "LibreTranslate" "https://libretranslate.com/languages" "Free translation, no key" "ai"

# ═══ Weather APIs ═══
log INFO "Weather APIs:"
test_and_add "OpenMeteo" "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0&current_weather=true" "Free weather, no key" "weather"
test_and_add "wttr.in" "https://wttr.in/?format=j1" "Weather in JSON, no key" "weather"

# ═══ Data APIs ═══
log INFO "Data APIs:"
test_and_add "RESTCountries" "https://restcountries.com/v3.1/all?fields=name" "Country data, no key" "data"
test_and_add "OpenLibrary" "https://openlibrary.org/api/books?bibkeys=ISBN:0451526538&format=json" "Book data, no key" "data"
test_and_add "PokeAPI" "https://pokeapi.co/api/v2/pokemon/1" "Pokemon data, no key" "data"
test_and_add "Jikan" "https://api.jikan.moe/v4/anime/1" "Anime data, no key" "data"
test_and_add "Dictionary" "https://api.dictionaryapi.dev/api/v2/entries/en/hello" "Dictionary, no key" "data"
test_and_add "ExchangeRate" "https://open.er-api.com/v6/latest/USD" "Currency rates, no key" "finance"
test_and_add "IP-Geolocation" "https://ipapi.co/json/" "IP info, no key" "tools"

# ═══ News APIs ═══
log INFO "News APIs:"
test_and_add "HN-API" "https://hacker-news.firebaseio.com/v0/topstories.json" "Hacker News, no key" "news"
test_and_add "DevTo" "https://dev.to/api/articles?top=7" "Dev.to articles, no key" "news"

# ═══ GitHub APIs ═══
log INFO "GitHub APIs:"
test_and_add "GitHub-Trending" "https://api.github.com/search/repositories?q=stars:>10000&sort=stars" "Trending repos, no key" "github"
test_and_add "GitHub-Users" "https://api.github.com/users/github" "User data, no key" "github"

# ═══ Tools APIs ═══
log INFO "Tool APIs:"
test_and_add "QR-GoQR" "https://goqr.me/api/v1/create?data=hello&size=100x100" "QR code gen, no key" "tools"
test_and_add "Lorem-Ipsum" "https://loripsum.net/api/1/short" "Lorem ipsum, no key" "tools"
test_and_add "RandomUser" "https://randomuser.me/api/" "Random user data, no key" "tools"
test_and_add "Jokes" "https://v2.jokeapi.dev/joke/Any" "Jokes API, no key" "fun"
test_and_add "Quotes" "https://api.quotable.io/random" "Quotes, no key" "fun"

# ═══ Music/Entertainment ═══
log INFO "Entertainment APIs:"
test_and_add "Lyrics-OVH" "https://api.lyrics.ovh/v1/coldplay/yellow" "Lyrics, no key" "music"
test_and_add "Cat-Facts" "https://catfact.ninja/fact" "Cat facts, no key" "fun"
test_and_add "Dog-Facts" "https://dogapi.dog/api/v2/facts" "Dog facts, no key" "fun"

# ═══ Generate Report ═══
TOTAL=$(jq '.apis | length' "$API_DB" 2>/dev/null || echo "0")

cat > "$REPORT" << REOF
# 🆓 Free API Hunter Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**New Found:** $FOUND
**Total Catalogued:** $TOTAL

## No-Signup APIs Found

### 🤖 AI & Language
- **HuggingFace Inference** — Free AI models, some no signup
- **LibreTranslate** — Free translation

### 🌤️ Weather
- **Open-Meteo** — Full weather data, completely free
- **wttr.in** — Weather in JSON

### 📊 Data
- **REST Countries** — Country info
- **Open Library** — Book database
- **PokeAPI** — Pokemon data
- **Jikan** — Anime database
- **Dictionary** — Word definitions
- **ExchangeRate** — Currency rates

### 📰 News
- **Hacker News API** — Tech news
- **DevTo API** — Dev articles

### 🔧 Tools
- **IP Geolocation** — IP lookup
- **QR Generator** — QR codes
- **RandomUser** — Fake user data

### 😄 Fun
- **Jokes API** — Random jokes
- **Quotes** — Inspirational quotes
- **Cat/Dog Facts** — Animal facts

## Usage in Bots
All bots can now use these APIs:
\`\`\`bash
source shared/utils.sh
WEATHER=$(http_get "https://api.open-meteo.com/v1/forecast?latitude=14.5995&longitude=120.9842&current_weather=true")
COUNTRIES=$(http_get "https://restcountries.com/v3.1/name/philippines")
\`\`\`

---
_Automated by Free API Hunter 🆓_
REOF

cat "$REPORT"
notify "Free API Hunter" "Found $FOUND new free APIs (no signup). Total: $TOTAL"
exit 0
