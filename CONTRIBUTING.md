# 🤝 Contributing to GitHub Autopilot

Want to add a new bot or improve an existing one? Here's how.

## Adding a New Bot

1. Create a folder in `bots/your-bot-name/`
2. Create `scripts/your-bot-name.sh` (the bot script)
3. Create `.github/workflows/your-bot-name.yml` (the GitHub Actions workflow)
4. Test it: `bash bots/your-bot-name/scripts/your-bot-name.sh`
5. Submit a PR

## Bot Script Template

```bash
#!/bin/bash
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

REPORT="your-bot-report.md"
log INFO "🤖 Your Bot starting..."

# Your bot logic here

cat > "$REPORT" << REOF
# 🤖 Your Bot Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')

## Results
Your results here.
REOF

cat "$REPORT"
notify "Your Bot" "Completed!"
exit 0
```

## Rules

- All scripts must pass `bash -n` syntax check
- Must use `source shared/utils.sh`
- Must generate a report file
- Must call `notify` at the end
- Must end with `exit 0`
- No hardcoded secrets — use GitHub Secrets

## Testing

```bash
# Syntax check
bash -n bots/your-bot/scripts/your-bot.sh

# Run locally
source shared/utils.sh
REPO="test/test" bash bots/your-bot/scripts/your-bot.sh
```
