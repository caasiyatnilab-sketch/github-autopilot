# 🚀 GitHub Autopilot — Unstoppable Bot Army

**15 autonomous bots** that run your GitHub repos. Install once, never touch again.

## 🤖 Bot Roster

### Core Bots (Project Health)
| Bot | Schedule | What it does |
|-----|----------|-------------|
| 🔍 **health-checker** | Daily 6AM | CI monitoring, branch protection, config audit, health scoring |
| 🔒 **security-scanner** | Daily 2AM + push | Vulnerability audit, secret detection, npm audit, CodeQL |
| 📦 **auto-updater** | Monday 8AM | Dependency updates, npm audit fix, auto-PRs |
| 🏷️ **issue-pr-manager** | On events + daily | Auto-label, stale cleanup, welcome msgs, PR size labels |
| 🛠️ **auto-fixer** | On push to main | ESLint, Prettier, whitespace, .gitignore, auto-PR with fixes |
| 📊 **weekly-reporter** | Friday 5PM | Activity summary, stats, CI, security, recommendations |

### Power Bots (Autonomous Operations)
| Bot | Schedule | What it does |
|-----|----------|-------------|
| 🌐 **api-hunter** | Every 6 hours | 50+ freemium APIs catalogued — AI, tools, deploy, data |
| 🏗️ **repo-builder** | Monday 9AM | 12 project templates, auto-create repos from ideas JSON |
| 🕷️ **scraper-bot** | Daily 4AM | Website scraping, data extraction, change monitoring |
| 🚀 **deploy-bot** | On push to main | Auto-deploy to Vercel, Netlify, GitHub Pages (free) |
| 🔑 **copilot-rotator** | Every 12 hours | API key health checks, free key discovery, rotation |
| 🧠 **ai-agent-factory** | Monday 10AM | Build chatbot, code reviewer, data analyst, content writer agents |

### Communication Bots (Freemium Notifications)
| Bot | Schedule | What it does |
|-----|----------|-------------|
| 📬 **notification-bot** | 3x daily + on failure | Multi-channel alerts: Email, Telegram, Discord, Slack, phone push |
| 📰 **daily-briefing** | Daily 8AM | Comprehensive daily email/notification with everything |

### Orchestrator
| Bot | Schedule | What it does |
|-----|----------|-------------|
| 🎯 **autopilot** | Every 4 hours | Master controller — monitors all bots, system health |

## 📬 Notification Channels (All Free/Freemium)

| Channel | Free Tier | Setup |
|---------|-----------|-------|
| **ntfy.sh** | Unlimited (no signup!) | Auto — just subscribe to your topic |
| **Telegram** | Unlimited | Create bot via @BotFather, add secrets |
| **Discord** | Unlimited webhooks | Create webhook in server settings |
| **Slack** | Unlimited webhooks | Create app at api.slack.com |
| **Email (Resend)** | 100/day | Sign up at resend.com |
| **Email (Brevo)** | 300/day | Sign up at brevo.com |
| **Email (Mailgun)** | 100/day (3 months) | Sign up at mailgun.com |
| **Pushover** | 7,500/month | Sign up at pushover.net |
| **GitHub Issues** | Always | Auto-created on failures |

## 🚀 One-Command Install

```bash
bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/github-autopilot/main/setup.sh)
```

Install specific bot only:
```bash
bash setup.sh --bot api-hunter
```

## ⚙️ Configuration

`.github/autopilot.yml`:
```yaml
autopilot:
  enabled: true

api_hunter:
  enabled: true
  categories: [ai_models, tools, deploy]

deploy_bot:
  enabled: true
  providers: [vercel, netlify, github_pages]

copilot_rotator:
  enabled: true
  providers: [groq, openrouter, mistral]

ai_agent_factory:
  enabled: true
  templates: [chatbot, code_reviewer, data_analyst]
```

## 🔑 GitHub Secrets (Optional — Add What You Need)

### AI API Keys (for copilot-rotator, ai-agent-factory)
- `GROQ_API_KEY` — Free at [console.groq.com](https://console.groq.com)
- `OPENROUTER_API_KEY` — Free at [openrouter.ai/keys](https://openrouter.ai/keys)
- `MISTRAL_API_KEY` — Free at [console.mistral.ai](https://console.mistral.ai)
- `TOGETHER_API_KEY` — Free at [api.together.xyz](https://api.together.xyz)

### Notifications
- `DISCORD_WEBHOOK` — Discord webhook URL
- `SLACK_WEBHOOK` — Slack webhook URL
- `TELEGRAM_BOT_TOKEN` — From @BotFather
- `TELEGRAM_CHAT_ID` — From @userinfobot
- `RESEND_API_KEY` — From resend.com
- `BREVO_API_KEY` — From brevo.com
- `NOTIFY_EMAIL` — Your email address
- `PUSHOVER_TOKEN` — From pushover.net
- `PUSHOVER_USER` — From pushover.net
- `NTFY_TOPIC` — Custom ntfy.sh topic (default: github-autopilot)

## 📁 Structure

```
github-autopilot/
├── .github/workflows/     # All 15 workflow files
├── bots/
│   ├── health-checker/
│   ├── security-scanner/
│   ├── auto-updater/
│   ├── issue-pr-manager/
│   ├── auto-fixer/
│   ├── weekly-reporter/
│   ├── api-hunter/        # 50+ free APIs
│   ├── repo-builder/      # 12 project templates
│   ├── scraper-bot/
│   ├── deploy-bot/
│   ├── copilot-rotator/
│   ├── ai-agent-factory/  # 4 AI agent templates
│   ├── notification-bot/  # 8 notification channels
│   ├── daily-briefing/    # Daily comprehensive update
│   └── autopilot/         # Master orchestrator
├── shared/
│   └── utils.sh           # Shared utilities
├── templates/
│   └── autopilot.yml      # Config template
└── setup.sh               # One-command installer
```

## 📝 License

MIT
