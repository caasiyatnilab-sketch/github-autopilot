#!/bin/bash
set -euo pipefail
trap 'record_result "free-api-hunter" "error" "script exited with error" 2>/dev/null || true' ERR
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"
BOT="free-api-hunter"; REPORT="free-api-report.md"
log INFO "🔍 Free API Hunter starting..."

# Directory for API data
API_DIR="${GITHUB_WORKSPACE:-.}/.github"
API_FILE="${API_DIR}/free-apis.json"
FREEMIUM_FILE="${API_DIR}/freemium-apis.json"
PAID_FILE="${API_DIR}/paid-apis.json"
CATEGORIZED_FILE="${API_DIR}/apis-categorized.json"

# Ensure API directory exists
mkdir -p "${API_DIR}"

# Initialize output files if they don't exist
for f in "${API_FILE}" "${FREEMIUM_FILE}" "${PAID_FILE}" "${CATEGORIZED_FILE}"; do
  if [ ! -f "$f" ]; then
    echo '[]' > "$f"
  fi
done

# List of known free API sources to check (expand as needed)
# In a real implementation, this would scrape websites, documentation, etc.
# For this example, we'll simulate by testing a few known APIs
declare -A TEST_APIS=(
  ["Open-Meteo"]="https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&current=temperature_2m,wind_speed_10m&hourly=temperature_2m,relativehumidity_2m,windspeed_10m"
  ["REST Countries"]="https://restcountries.com/v3.1/name/united%20states"
  ["Jikan"]="https://api.jikan.moe/v4/anime/1"
  ["Awesome API"]="https://api.awesomeapi.com.br/json/last/USD-BRL"
  ["ExchangeRate.API"]="https://api.exchangerate-api.com/v4/latest/USD"
  ["Frankfurter"]="https://api.frankfurter.dev/v1/latest?base=USD"
  ["Date.nager.at"]="https://date.nager.at/api/v3/PublicHolidays/2024/US"
  ["Open Library"]="https://openlibrary.org/search.json?title=the+lord+of+the+rings"
  ["IPinfo.io"]="https://ipinfo.io/json"
  # Add more test APIs as needed
)

# Function to test an API and categorize it
test_and_categorize_api() {
  local name="$1"
  local url="$2"
  
  log INFO "Testing API: $name"
  
  # Test with curl, timeout after 10 seconds
  local response
  response=$(curl -s --max-time 10 -w "%{http_code}" "$url" || echo "000")
  local http_code="${response: -3}"
  local body="${response:0:-3}"
  
  # Determine if we got a successful response (2xx or 3xx)
  if [[ "$http_code" =~ ^[23][0-9]{2}$ ]]; then
    # Further checks to determine if signup/login is required
    # Check if response indicates authentication required
    if echo "$body" | grep -i -E '"error".*(unauthorized|authentication|api.key|access.denied|forbidden)' >/dev/null 2>&1; then
      # Likely requires authentication/key
      log INFO "  $name: Appears to require authentication/key -> PAID/FREEMium"
      # For simplicity, we'll treat as freemium if it gave some response but with auth error
      # In reality, we'd need to test if there's a free tier
      echo "{\"name\": \"$name\", \"url\": \"$url\", \"type\": \"freemium\", \"signup_required\": true, \"key_required\": true, \"notes\": \"API returned auth error - may have free tier\"}" >> "${FREEMIUM_FILE}.tmp"
    else
      # Successful response without obvious auth error -> likely free
      log INFO "  $name: Successful response -> FREE"
      echo "{\"name\": \"$name\", \"url\": \"$url\", \"type\": \"free\", \"signup_required\": false, \"key_required\": false, \"notes\": \"API accessible without authentication\"}" >> "${FREE}.tmp"
    fi
  elif [[ "$http_code" =~ ^4[0-9]{2}$ ]]; then
    # 4xx errors - could be missing key, or not found
    if echo "$body" | grep -i -E '"error".*(unauthorized|authentication|api.key|access.denied|forbidden|missing)' >/dev/null 2>&1; then
      log INFO "  $name: Auth error (4xx) -> FREEMium/PAID"
      echo "{\"name\": \"$name\", \"url\": \"$url\", \"type\": \"freemium\", \"signup_required\": true, \"key_required\": true, \"notes\": \"API returned authentication error - may have free tier\"}" >> "${FREEMIUM_FILE}.tmp"
    else
      log INFO "  $name: Client error (4xx) -> Possibly not available or limited -> PAID"
      echo "{\"name\": \"$name\", \"url\": \"$url\", \"type\": \"paid\", \"signup_required\": true, \"key_required\": true, \"notes\": \"API returned client error - may require paid plan\"}" >> "${PAID}.tmp"
    fi
  else
    # 5xx errors or timeout/connection issues
    log WARN "  $name: Server error or timeout (${http_code}) -> Unable to determine, skipping"
    # Skip for now
  fi
}

# Temporary files for accumulating results
> "${FREE}.tmp"
> "${FREEMIUM}.tmp"
> "${PAID}.tmp"
> "${CATEGORIZED}.tmp"

# Test each API
for name in "${!TEST_APIS[@]}"; do
  url="${TEST_APIS[$name]}"
  test_and_categorize_api "$name" "$url"
done

# Combine results into proper JSON arrays
if [ -s "${FREE}.tmp" ]; then
  echo "[" > "${API_FILE}"
  cat "${FREE}.tmp" | sed '$s/,$//' | tr '\n' ',' | sed 's/,$//' >> "${API_FILE}"
  echo "]" >> "${API_FILE}"
else
  echo "[]" > "${API_FILE}"
fi

if [ -s "${FREEMIUM}.tmp" ]; then
  echo "[" > "${FREEMIUM_FILE}"
  cat "${FREEMIUM}.tmp" | sed '$s/,$//' | tr '\n' ',' | sed 's/,$//' >> "${FREEMIUM_FILE}"
  echo "]" >> "${FREEMIUM_FILE}"
else
  echo "[]" > "${FREEMIER_FILE}"
fi

if [ -s "${PAID}.tmp" ]; then
  echo "[" > "${PAID_FILE}"
  cat "${PAID}.tmp" | sed '$s/,$//' | tr '\n' ',' | sed 's/,$//' >> "${PAID_FILE}"
  echo "]" >> "${PAID_FILE}"
else
  echo "[]" > "${PAID_FILE}"
fi

# Create combined categorized file
{
  echo "{"
  echo "  \"free\": $(cat "${API_FILE}"),"
  echo "  \"freemium\": $(cat "${FREEMIUM_FILE}"),"
  echo "  \"paid\": $(cat "${PAID_FILE}")"
  echo "}"
} > "${CATEGORIZED_FILE}"

# Clean up temporary files
rm -f "${FREE}.tmp" "${FREEMIUM}.tmp" "${PAID}.tmp"

# Generate report
log INFO "Generating API categorization report..."
cat > "${REPORT}" << EOF
# 🔍 Free API Hunter Report - With Categorization
**Generated:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repository:** $GITHUB_REPOSITORY

## 📊 API Categorization Summary

### Free APIs (No signup, no key, no limits)
$(jq length "${API_FILE}" 2>/dev/null || echo "0") APIs

### Freemium APIs (Signup required, free tier available)
$(jq length "${FREEMIUM_FILE}" 2>/dev/null || echo "0") APIs

### Paid APIs (Payment required for any usage)
$(jq length "${PAID_FILE}" 2>/dev/null || echo "0") APIs

## 📋 Details

### Free APIs
$(jq -r '.[] | "- **\(.name)** (\(.url)): \(.notes // "No additional notes")"' "${API_FILE}" 2>/dev/null || echo "_No free APIs found_")

### Freemium APIs
$(jq -r '.[] | "- **\(.name)** (\(.url)): \(.notes // "No additional notes")"' "${FREEMIUM_FILE}" 2>/dev/null || echo "_No freemium APIs found_")

### Paid APIs
$(jq -r '.[] | "- **\(.name)** (\(.url)): \(.notes // "No additional notes")"' "${PAID_FILE}" 2>/dev/null || echo "_No paid APIs found_")

## 📈 Next Steps
1. Review any new APIs discovered
2. Consider testing freemium APIs for free tier usability
3. Update bot configurations to utilize new free APIs
4. Share findings with team
EOF

cat "${REPORT}"

# Notify completion
notify "$BOT" "Free API Hunter completed. Found $(jq length "${API_FILE}" 2>/dev/null || echo "0") free, $(jq length "${FREEMIUM_FILE}" 2>/dev/null || echo "0") freemium, $(jq length "${PAID_FILE}" 2>/dev/null || echo "0") paid APIs." 2>/dev/null || true
log INFO "🔍 Free API Hunter completed successfully"
exit 0