# 🤖 GitHub Autopilot

**20 autonomous bots that run your GitHub repos. Install once, never touch again.**

[![GitHub Stars](https://img.shields.io/github/stars/caasiyatnilab-sketch/github-autopilot)](https://github.com/caasiyatnilab-sketch/github-autopilot)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Bots](https://img.shields.io/badge/Bots-20-blue.svg)](#bots)

## 🚀 One-Line Install

```bash
bash <(curl -s https://raw.githubusercontent.com/caasiyatnilab-sketch/github-autopilot/main/setup.sh)
```

That's it. Your repo now has 20 bots running 24/7.

## 🤖 What It Does

| Category | Bots | What they do |
|----------|------|-------------|
| 🔍 **Checking** | Health Checker, Security Scanner | Monitor CI, vulnerabilities, secrets |
| 📦 **Updating** | Auto Updater, Copilot Rotator | Dependencies, API key health |
| 🛠️ **Fixing** | Auto Fixer, Issue Manager | ESLint, Prettier, auto-label, stale cleanup |
| 🏗️ **Creating** | Project Creator, Creator Bot, AI Agents | Build new repos, websites, AI agents |
| 🔒 **Security** | Secret Scan, Vulnerability Audit | Find leaked keys, fix vulnerabilities |
| 🚀 **Deploying** | Deploy Bot, Mega Deploy | GitHub Pages, Vercel, Netlify, 10 platforms |
| 📬 **Alerts** | Notification Bot, Daily Briefing | ntfy.sh, email, Telegram, Discord |
| 🧠 **Smart** | Autopilot, Bot Brain | Orchestrate, self-upgrade, bot-to-bot |

## 📋 All 20 Bots

### Core (Project Health)
| Bot | Schedule | Description |
|-----|----------|-------------|
| 🔍 Health Checker | Daily 6AM | CI monitoring, branch protection, health scoring |
| 🔒 Security Scanner | Daily 2AM | Vulnerability audit, secret detection |
| 📦 Auto Updater | Monday 8AM | Dependency updates, npm audit fix |
| 🏷️ Issue & PR Manager | On events | Auto-label, stale cleanup, welcome messages |
| 🛠️ Auto Fixer | On push | ESLint, Prettier, whitespace, .gitignore |
| 📊 Weekly Reporter | Friday 5PM | Activity summary with stats |

### Power (Autonomous Operations)
| Bot | Schedule | Description |
|-----|----------|-------------|
| 🌐 API Hunter | Every 6 hours | Finds 50+ free APIs (AI, tools, deploy) |
| 🏗️ Project Creator | Mon/Thu 8AM | Creates NEW GitHub repos with full projects |
| 🏗️ Repo Builder | Monday 9AM | 12 project templates |
| 🕷️ Scraper Bot | Daily 4AM | Web scraping, data extraction |
| 🚀 Deploy Bot | On push | GitHub Pages, Vercel, Netlify |
| 🚀 Mega Deploy | On push | 10 platforms: Vercel, Netlify, Cloudflare, Surge, Firebase... |
| 🔑 Copilot Rotator | Every 12h | API key health, free key discovery |
| 🧠 AI Agent Factory | Monday 10AM | Build chatbot, code reviewer, data analyst agents |
| 🧠 AI Agent Pro | Monday 10AM | Kilo-level autonomous agents with tools & memory |
| 🏭 Creator Bot | Monday 6AM | Creates full websites & apps |

### Communication
| Bot | Schedule | Description |
|-----|----------|-------------|
| 📬 Notification Bot | 3x daily | 8 channels: ntfy.sh, email, Telegram, Discord, Slack |
| 📰 Daily Briefing | Daily 8AM | Comprehensive daily email/notification |

### Orchestrators
| Bot | Schedule | Description |
|-----|----------|-------------|
| 🎯 Autopilot | Every 4 hours | Master controller, monitors all bots |
| 🔗 Bot Brain | Every 2 hours | Bot-to-bot communication, self-upgrade |

## 🛠️ Install Options

### Option 1: One-Line (Recommended)
```bash
bash <(curl -s https://raw.githubusercontent.com/caasiyatnilab-sketch/github-autopilot/main/setup.sh)
```

### Option 2: Install Specific Bot
```bash
bash <(curl -s https://raw.githubusercontent.com/caasiyatnilab-sketch/github-autopilot/main/setup.sh) --bot api-hunter
```

### Option 3: Manual
```bash
git clone https://github.com/caasiyatnilab-sketch/github-autopilot.git
cd github-autopilot
bash setup.sh
```

## 🔑 Optional: Free API Keys

Add these to GitHub Secrets for AI features:

| Provider | Free Tier | Sign Up |
|----------|-----------|---------|
| **Groq** | 30 req/min, fastest | [console.groq.com](https://console.groq.com) |
| **OpenRouter** | Free tier, many models | [openrouter.ai/keys](https://openrouter.ai/keys) |
| **Mistral** | Free tier | [console.mistral.ai](https://console.mistral.ai) |
| **Together AI** | $25 free credits | [api.together.xyz](https://api.together.xyz) |

## 📬 Notifications (Free)

| Channel | Free Tier | Setup |
|---------|-----------|-------|
| **ntfy.sh** | Unlimited, no signup! | Auto — just subscribe to your topic |
| **Telegram** | Unlimited | Add `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` |
| **Discord** | Unlimited | Add `DISCORD_WEBHOOK` |
| **Email (Resend)** | 100/day | Add `RESEND_API_KEY` + `NOTIFY_EMAIL` |
| **Email (Brevo)** | 300/day | Add `BREVO_API_KEY` + `NOTIFY_EMAIL` |

## 📁 Structure

```
github-autopilot/
├── bots/                    # All 20 bots
│   ├── health-checker/
│   ├── security-scanner/
│   ├── auto-updater/
│   ├── issue-pr-manager/
│   ├── auto-fixer/
│   ├── weekly-reporter/
│   ├── api-hunter/
│   ├── project-creator/     # Creates NEW repos
│   ├── repo-builder/
│   ├── scraper-bot/
│   ├── deploy-bot/
│   ├── mega-deploy/
│   ├── copilot-rotator/
│   ├── ai-agent-factory/
│   ├── ai-agent-pro/
│   ├── creator-bot/
│   ├── notification-bot/
│   ├── daily-briefing/
│   ├── autopilot/
│   └── bot-brain/
├── shared/
│   └── utils.sh             # Shared utilities
├── templates/               # Config templates
├── setup.sh                 # One-line installer
└── README.md
```

## 🔒 Security

- All secrets use GitHub Secrets (never in code)
- Isolated bot permissions
- No credentials exposed
- Audit logging on all operations

## 📊 Stats

- **20 bots** running autonomously
- **10+ deploy platforms** supported
- **8 notification channels**
- **50+ free APIs** catalogued
- **12 project templates**
- **Zero human intervention** needed

## 📝 License

MIT — use it however you want. Share it. Improve it.

## ⭐ Star This Repo

If this helped you, star it! It helps others find it.

[![Star on GitHub](https://img.shields.io/github/stars/caasiyatnilab-sketch/github-autopilot?style=social)](https://github.com/caasiyatnilab-sketch/github-autopilot)

---

Built with 🤖 by [caasiyatnilab-sketch](https://github.com/caasiyatnilab-sketch)
