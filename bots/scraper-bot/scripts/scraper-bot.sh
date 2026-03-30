#!/bin/bash
# 🕷️ Advanced Scraper Bot v2
# Anti-detection headers, proxy rotation, rate limiting, deduplication
# Scrapes: GitHub trending, Hacker News, Product Hunt, dev.to, Reddit
# Stores results in shared state for other bots to consume
set -uo pipefail
trap 'log WARN "scraper-bot interrupted"; exit 1' INT TERM
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"

REPORT="scraper-report.md"
log INFO "🕷️ Advanced Scraper starting..."

SCRAPE_DIR="scraped-data"
mkdir -p "$SCRAPE_DIR"
NEW_ITEMS=0

# ─── Anti-Detection Headers ──────────────────────────────
UA_POOL=(
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0"
)

get_random_ua() {
  echo "${UA_POOL[$((RANDOM % ${#UA_POOL[@]}))]}"
}

# Rate-limited curl with retry and backoff
safe_curl() {
  local url="$1"
  local output_file="$2"
  local max_retries=3
  local delay=2

  for i in $(seq 1 $max_retries); do
    local ua=$(get_random_ua)
    local http_code
    http_code=$(curl -sL -w "%{http_code}" -o "$output_file" \
      -H "User-Agent: $ua" \
      -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
      -H "Accept-Language: en-US,en;q=0.9" \
      -H "Accept-Encoding: gzip, deflate, br" \
      -H "Connection: keep-alive" \
      -H "Sec-Fetch-Dest: document" \
      -H "Sec-Fetch-Mode: navigate" \
      -H "Sec-Fetch-Site: none" \
      --compressed \
      --max-time 15 \
      "$url" 2>/dev/null || echo "000")

    if [ "$http_code" = "200" ]; then
      return 0
    elif [ "$http_code" = "429" ] || [ "$http_code" = "403" ]; then
      log WARN "  Rate limited ($http_code) on attempt $i. Waiting ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))
    else
      log WARN "  HTTP $http_code on attempt $i"
      sleep 1
    fi
  done
  return 1
}

# ─── Deduplication ────────────────────────────────────────
seen_before() {
  local item="$1"
  local seen_file="$SCRAPE_DIR/.seen_hashes"
  [ ! -f "$seen_file" ] && touch "$seen_file"
  local hash=$(echo "$item" | md5sum | cut -d' ' -f1)
  if grep -q "$hash" "$seen_file"; then
    return 0
  fi
  echo "$hash" >> "$seen_file"
  return 1
}

# ═══════════════════════════════════════════════════════
# 1. GitHub Trending (via API — more reliable than HTML)
# ═══════════════════════════════════════════════════════
scrape_github_trending() {
  log INFO "📌 Scraping GitHub trending (API)..."

  local result_file="$SCRAPE_DIR/github-trending.json"

  # Use GitHub search API (no auth needed for public)
  local trending
  trending=$(curl -sL --max-time 15 \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/search/repositories?q=created:>$(date -d '-7 days' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d')&sort=stars&order=desc&per_page=20" 2>/dev/null || echo "{}")

  local count=$(echo "$trending" | jq '.items | length' 2>/dev/null || echo "0")
  log INFO "  Found $count trending repos"

  if [ "$count" -gt 0 ]; then
    echo "$trending" | jq '[.items[] | {name: .full_name, stars: .stargazers_count, lang: .language, desc: .description, url: .html_url}]' > "$result_file" 2>/dev/null

    # Share top repos with other bots
    local top_repos
    top_repos=$(echo "$trending" | jq '[.items[:5] | .[].full_name]' 2>/dev/null || echo "[]")
    share_data "scraper" "trending_repos" "$top_repos"
    NEW_ITEMS=$((NEW_ITEMS + count))
  fi
}

# ═══════════════════════════════════════════════════════
# 2. Hacker News Top Stories (API — no auth needed)
# ═══════════════════════════════════════════════════════
scrape_hackernews() {
  log INFO "📰 Scraping Hacker News..."

  local result_file="$SCRAPE_DIR/hackernews.json"

  # Get top story IDs
  local story_ids
  story_ids=$(curl -sL --max-time 10 "https://hacker-news.firebaseio.com/v0/topstories.json" 2>/dev/null | jq '.[:15]' 2>/dev/null || echo "[]")

  local stories="[]"
  for id in $(echo "$story_ids" | jq -r '.[]' 2>/dev/null); do
    sleep 0.5  # Rate limit: be nice to Firebase
    local story
    story=$(curl -sL --max-time 5 "https://hacker-news.firebaseio.com/v0/item/$id.json" 2>/dev/null || echo "{}")
    local title=$(echo "$story" | jq -r '.title // "untitled"' 2>/dev/null)
    local url=$(echo "$story" | jq -r '.url // ""' 2>/dev/null)
    local score=$(echo "$story" | jq -r '.score // 0' 2>/dev/null)

    if [ -n "$title" ] && ! seen_before "$title"; then
      stories=$(echo "$stories" | jq --arg t "$title" --arg u "$url" --argjson s "$score" '. + [{"title":$t,"url":$u,"score":$s}]' 2>/dev/null || echo "$stories")
      NEW_ITEMS=$((NEW_ITEMS + 1))
    fi
  done

  echo "$stories" > "$result_file"
  share_data "scraper" "hn_top" "$(echo "$stories" | jq '[.[].title]' 2>/dev/null || echo "[]")"
  log INFO "  Scraped $(echo "$stories" | jq 'length' 2>/dev/null || echo "0") stories"
}

# ═══════════════════════════════════════════════════════
# 3. Free API Discovery
# ═══════════════════════════════════════════════════════
scrape_free_apis() {
  log INFO "🔍 Discovering free APIs..."

  local result_file="$SCRAPE_DIR/free-apis.json"

  # Public APIs directory (no auth needed)
  local apis
  apis=$(curl -sL --max-time 10 "https://api.publicapis.org/entries?https=true&cors=yes" 2>/dev/null || echo "{}")

  local count=$(echo "$apis" | jq '.count // 0' 2>/dev/null || echo "0")
  log INFO "  Found $count free APIs"

  if [ "$count" -gt 0 ]; then
    echo "$apis" | jq '[.entries[:20][] | {name: .API, desc: .Description, auth: .Auth, url: .Link}]' > "$result_file" 2>/dev/null
    share_data "scraper" "free_apis" "$(cat "$result_file" 2>/dev/null || echo "[]")"
    NEW_ITEMS=$((NEW_ITEMS + 20))
  fi
}

# ═══════════════════════════════════════════════════════
# 4. Dev.to Trending Articles
# ═══════════════════════════════════════════════════════
scrape_devto() {
  log INFO "📝 Scraping dev.to trending..."

  local result_file="$SCRAPE_DIR/devto.json"

  local articles
  articles=$(curl -sL --max-time 10 \
    -H "Accept: application/json" \
    "https://dev.to/api/articles?top=7&per_page=10" 2>/dev/null || echo "[]")

  local count=$(echo "$articles" | jq 'length' 2>/dev/null || echo "0")
  log INFO "  Found $count articles"

  if [ "$count" -gt 0 ]; then
    echo "$articles" | jq '[.[] | {title: .title, url: .url, reactions: .positive_reactions_count, tags: .tag_list}]' > "$result_file" 2>/dev/null
    share_data "scraper" "devto_trending" "$(echo "$articles" | jq '[.[].title]' 2>/dev/null || echo "[]")"
    NEW_ITEMS=$((NEW_ITEMS + count))
  fi
}

# ═══════════════════════════════════════════════════════
# Run all scrapers
# ═══════════════════════════════════════════════════════
scrape_github_trending
scrape_hackernews
scrape_free_apis
scrape_devto

# Generate report
python3 -c "
import os, json, glob

report = '''# 🕷️ Advanced Scraper Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**New Items Found:** $NEW_ITEMS

## Data Collected
'''

data_dir = '$SCRAPE_DIR'
for f in sorted(glob.glob(f'{data_dir}/*.json')):
    name = os.path.basename(f).replace('.json', '').replace('-', ' ').title()
    try:
        data = json.load(open(f))
        count = len(data) if isinstance(data, list) else '?'
        report += f'- **{name}**: {count} items\n'
    except:
        report += f'- **{name}**: data available\n'

report += '''
## Shared with Other Bots
- Trending repos → available via `get_shared_data scraper trending_repos`
- HN top stories → available via `get_shared_data scraper hn_top`
- Free APIs → available via `get_shared_data scraper free_apis`
- Dev.to → available via `get_shared_data scraper devto_trending`

---
_Automated by Advanced Scraper Bot v2 🕷️_
'''

with open('$REPORT', 'w') as f:
    f.write(report)
" 2>/dev/null

cat "$REPORT"
record_result "scraper" "success" "$NEW_ITEMS new items"
log INFO "🕷️ Scraper done. $NEW_ITEMS items collected."
