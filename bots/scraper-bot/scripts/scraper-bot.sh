#!/bin/bash
# 🕷️ Scraper Bot
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

REPORT="scraper-report.md"
log INFO "🕷️ Scraper Bot starting..."

# AI-powered trend analysis
AI_TRENDS=""
if [ -n "${GROQ_API_KEY:-}" ] || [ -n "${OPENROUTER_API_KEY:-}" ]; then
  log INFO "  🤖 AI mode — analyzing trends..."
  AI_TRENDS=$(ai_ask "What are the top 3 trending tech topics for developers right now? Brief answer." 2>/dev/null || echo "")
  [ -n "$AI_TRENDS" ] && log INFO "  ✅ AI trend analysis received"
fi

mkdir -p scraped-data

# Scrape GitHub trending
log INFO "Scraping GitHub trending..."
curl -sL "https://github.com/trending" 2>/dev/null | grep -oE 'href="/[^/]+/[^/"]+' | sed 's|href="/||' | head -20 | sort -u > scraped-trending-repos.txt 2>/dev/null || true
TRENDING=$(wc -l < scraped-trending-repos.txt 2>/dev/null || echo "0")
log INFO "Found $TRENDING trending repos"

# Scrape Hacker News top stories
log INFO "Scraping Hacker News..."
curl -sL "https://hacker-news.firebaseio.com/v0/topstories.json" 2>/dev/null | python3 -c "import json,sys; ids=json.load(sys.stdin)[:20]; [print(i) for i in ids]" > scraped-hn-ids.txt 2>/dev/null || true
HN=$(wc -l < scraped-hn-ids.txt 2>/dev/null || echo "0")
log INFO "Found $HN HN stories"

# Custom targets
if [ -f ".github/scraper-targets.json" ]; then
  python3 -c "
import json, subprocess
with open('.github/scraper-targets.json') as f:
    targets = json.load(f)
for t in targets.get('targets', []):
    url = t['url']
    name = t.get('name', url.replace('https://','').replace('/','_'))
    subprocess.run(['bash','-c',f'curl -sL \"{url}\" > \"scraped-data/{name}.txt\"'], timeout=30)
    print(f'Scraped: {name}')
" 2>/dev/null || true
fi

# Generate report
cat > "$REPORT" << REOF
# 🕷️ Scraper Bot Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repo:** $(get_repo)

## Scraped Data
- Trending repos: $TRENDING
- HN stories: $HN

## Usage
Add targets to \`.github/scraper-targets.json\`:
\`\`\`json
{"targets": [{"url": "https://example.com", "name": "example"}]}
\`\`\`

---
_Automated by Scraper Bot 🕷️_
REOF

cat "$REPORT"

notify "$(basename $BOT_NAME 2>/dev/null || basename $0)" "Bot completed successfully. Check report." 2>/dev/null || true
log INFO "🕷️ Scraper Bot complete!"
exit 0
