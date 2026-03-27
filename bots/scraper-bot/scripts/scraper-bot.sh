#!/bin/bash
# 🕷️ Scraper Bot
# Website scraping, data extraction, monitoring changes
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="scraper-bot"
REPORT="scraper-report.md"

log INFO "🕷️ Scraper Bot starting..."

# ═══════════════════════════════════════════════════════
# Scrape Functions
# ═══════════════════════════════════════════════════════

scrape_url() {
  local url="$1"
  local output_file="$2"
  local extract="${3:-text}"

  log INFO "Scraping: $url"

  case "$extract" in
    text)
      curl -sL "$url" 2>/dev/null | sed 's/<[^>]*>//g' | sed '/^$/d' > "$output_file"
      ;;
    links)
      curl -sL "$url" 2>/dev/null | grep -oE 'href="[^"]*"' | sed 's/href="//;s/"$//' | sort -u > "$output_file"
      ;;
    headlines)
      curl -sL "$url" 2>/dev/null | grep -oE '<h[1-3][^>]*>[^<]*</h[1-3]>' | sed 's/<[^>]*>//g' > "$output_file"
      ;;
    images)
      curl -sL "$url" 2>/dev/null | grep -oE 'src="[^"]*\.(jpg|jpeg|png|gif|webp|svg)[^"]*"' | sed 's/src="//;s/"$//' | sort -u > "$output_file"
      ;;
    meta)
      curl -sL "$url" 2>/dev/null | grep -oE '<meta[^>]*>' > "$output_file"
      ;;
    json)
      curl -sL "$url" 2>/dev/null | python3 -m json.tool > "$output_file" 2>/dev/null || curl -sL "$url" > "$output_file"
      ;;
    all)
      curl -sL "$url" 2>/dev/null > "$output_file"
      ;;
  esac

  local lines=$(wc -l < "$output_file" 2>/dev/null || echo "0")
  log INFO "  Extracted $lines items"
}

# ═══════════════════════════════════════════════════════
# Monitor for Changes
# ═══════════════════════════════════════════════════════
check_changes() {
  local url="$1"
  local name="$2"
  local snapshot_dir=".github/scraper-snapshots"
  mkdir -p "$snapshot_dir"

  local current=$(curl -sL "$url" 2>/dev/null | md5sum | cut -d' ' -f1)
  local snapshot_file="$snapshot_dir/${name}.hash"

  if [ -f "$snapshot_file" ]; then
    local previous=$(cat "$snapshot_file")
    if [ "$current" != "$previous" ]; then
      log INFO "🔄 Change detected on $name ($url)"
      echo "changed"
    else
      log INFO "No changes on $name"
      echo "unchanged"
    fi
  else
    log INFO "First snapshot for $name"
    echo "first-run"
  fi

  echo "$current" > "$snapshot_file"
}

# ═══════════════════════════════════════════════════════
# Common Scraping Tasks
# ═══════════════════════════════════════════════════════

scrape_github_trending() {
  log INFO "Scraping GitHub trending repos..."
  local data=$(curl -sL "https://github.com/trending" 2>/dev/null)
  echo "$data" | grep -oE 'href="/[^/]+/[^/"]+' | sed 's|href="/||' | head -25 | sort -u > "scraped-trending-repos.txt"
  local count=$(wc -l < "scraped-trending-repos.txt")
  log INFO "Found $count trending repos"
}

scrape_hacker_news() {
  log INFO "Scraping Hacker News..."
  curl -sL "https://hacker-news.firebaseio.com/v0/topstories.json" 2>/dev/null | \
    python3 -c "
import json, sys
ids = json.load(sys.stdin)[:30]
for i in ids:
    print(i)
" > "scraped-hn-ids.txt" 2>/dev/null || true
}

scrape_product_hunt() {
  log INFO "Scraping Product Hunt data..."
  curl -sL "https://www.producthunt.com" 2>/dev/null | \
    grep -oE '<h3[^>]*>[^<]*</h3>' | sed 's/<[^>]*>//g' | head -20 > "scraped-products.txt" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════

mkdir -p scraped-data

# Run standard scrapes
scrape_github_trending
scrape_hacker_news

# Custom scrapes from config
if [ -f ".github/scraper-targets.json" ]; then
  python3 -c "
import json, subprocess

with open('.github/scraper-targets.json') as f:
    targets = json.load(f)

for target in targets.get('targets', []):
    url = target['url']
    name = target.get('name', url.replace('https://', '').replace('/', '_'))
    extract = target.get('extract', 'text')
    outfile = f'scraped-data/{name}.txt'
    subprocess.run(['bash', '-c', f'curl -sL \"{url}\" > \"{outfile}\"'])
    print(f'Scraped: {name}')
" 2>/dev/null || true
fi

# Generate report
cat > "$REPORT" << EOF
# 🕷️ Scraper Bot Report

**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')

## Scraped Data
$(for f in scraped-*.txt scraped-data/*.txt 2>/dev/null; do
  if [ -f "$f" ]; then
    count=$(wc -l < "$f")
    echo "- **$(basename $f)**: $count items"
  fi
done || echo "No data scraped")

## Usage

Add scrape targets to \`.github/scraper-targets.json\`:
\`\`\`json
{
  "targets": [
    { "url": "https://example.com", "name": "example", "extract": "links" }
  ]
}
\`\`\`

Supported extract types: text, links, headlines, images, meta, json, all

---
_Automated by Scraper Bot 🕷️_
EOF

cat "$REPORT"
log INFO "🕷️ Scraper Bot complete!"
