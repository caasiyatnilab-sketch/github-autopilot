# 🚀 GitHub Autopilot — Unstoppable Bot Army

A complete autonomous GitHub automation system. Install once, never touch again.

## 🤖 Bot Roster

### Core Bots (Project Health)
| Bot | What it does | Runs |
|-----|-------------|------|
| 🔍 **health-checker** | Repo health scoring, CI monitoring, config audit | Daily 6AM UTC |
| 🔒 **security-scanner** | Vulnerability audit, secret detection, CodeQL | Daily 2AM UTC + push |
| 📦 **auto-updater** | Dependency updates, npm audit fix, auto-PRs | Monday 8AM UTC |
| 🏷️ **issue-pr-manager** | Auto-label, stale cleanup, welcome msgs, PR size | On events + daily |
| 🛠️ **auto-fixer** | ESLint, Prettier, auto-fix bugs, .gitignore | On push to main |
| 📊 **weekly-reporter** | Activity summary, stats, recommendations | Friday 5PM UTC |

### Power Bots (Autonomous Operations)
| Bot | What it does | Runs |
|-----|-------------|------|
| 🌐 **api-hunter** | 24/7 freemium API finder — AI models, tools, services | Every 6 hours |
| 🏗️ **repo-builder** | Auto-creates repos from templates, scaffolds projects | On demand + weekly |
| 🕷️ **scraper-bot** | Website scraping, data extraction, monitoring | On demand + daily |
| 🚀 **deploy-bot** | Free deploy websites/apps (Vercel, Netlify, GH Pages) | On push to main |
| 🔑 **copilot-rotator** | API key rotation, Copilot management, key health | Every 12 hours |
| 🧠 **ai-agent-factory** | Builds and deploys AI agent templates | Weekly + on demand |

### Orchestrator
| Bot | What it does | Runs |
|-----|-------------|------|
| 🎯 **autopilot** | Master controller — coordinates all bots, monitors health | Every hour |

## 🚀 One-Command Install

```bash
bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/github-autopilot/main/setup.sh)
```

Or install individual bots:
```bash
bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/github-autopilot/main/setup.sh) --bot api-hunter
```

## ⚙️ Configuration

Each bot reads from `.github/autopilot.yml`:

```yaml
# .github/autopilot.yml
autopilot:
  enabled: true
  github_token: "${{ secrets.GITHUB_TOKEN }}"

api_hunter:
  enabled: true
  categories:
    - ai_models
    - text_generation
    - image_generation
    - translation
    - speech
    - code_assist
  save_to: ".github/found-apis.json"
  notify: true

repo_builder:
  enabled: true
  templates_dir: ".github/project-templates/"
  auto_create: true

scraper_bot:
  enabled: true
  targets:
    - url: "https://example.com"
      schedule: "daily"
      extract: "links,headlines"

deploy_bot:
  enabled: true
  providers:
    - vercel
    - netlify
    - github_pages
  auto_deploy_on_push: true

copilot_rotator:
  enabled: true
  providers:
    - github_copilot
    - openai
    - anthropic
    - google
  rotation_schedule: "every_12h"
  min_free_tier: true

ai_agent_factory:
  enabled: true
  templates:
    - chatbot
    - code_reviewer
    - data_analyst
    - content_writer
    - api_connector
  deploy_to: "replit"  # or "vercel", "railway"
```

## 📁 Structure

```
github-autopilot/
├── bots/
│   ├── health-checker/     # Core: repo health
│   ├── security-scanner/   # Core: security
│   ├── auto-updater/       # Core: dependencies
│   ├── issue-pr-manager/   # Core: issue/PR automation
│   ├── auto-fixer/         # Core: code fixes
│   ├── weekly-reporter/    # Core: reports
│   ├── api-hunter/         # Power: find free APIs
│   ├── repo-builder/       # Power: create repos/projects
│   ├── scraper-bot/        # Power: scrape websites
│   ├── deploy-bot/         # Power: deploy for free
│   ├── copilot-rotator/    # Power: key rotation
│   ├── ai-agent-factory/   # Power: build AI agents
│   └── autopilot/          # Orchestrator
├── shared/                 # Shared utilities
├── templates/              # Project templates
└── docs/                   # Documentation
```

## 🔒 Security

- All secrets use GitHub Secrets
- No credentials in code
- Isolated bot permissions
- Audit logging on all operations

## 📝 License

MIT
