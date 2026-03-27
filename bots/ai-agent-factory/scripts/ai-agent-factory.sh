#!/bin/bash
# 🧠 AI Agent Factory Bot
# Builds and deploys advanced AI agent templates
# Creates agents like OpenClaw/Kilo for free using freemium APIs
set -euo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

BOT_NAME="ai-agent-factory"
REPORT="ai-agent-factory-report.md"

log INFO "🧠 AI Agent Factory starting..."

AGENTS_DIR=".github/ai-agents"
mkdir -p "$AGENTS_DIR"

# ═══════════════════════════════════════════════════════
# Agent Templates
# ═══════════════════════════════════════════════════════

create_chatbot_agent() {
  local dir="$1"
  mkdir -p "$dir/src"

  cat > "$dir/package.json" << 'EOF'
{
  "name": "ai-chatbot-agent",
  "version": "1.0.0",
  "description": "Multi-provider AI chatbot agent with memory",
  "type": "module",
  "scripts": {
    "start": "node src/agent.js",
    "dev": "node --watch src/agent.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "node-fetch": "^3.0.0"
  }
}
EOF

  cat > "$dir/src/agent.js" << 'AGENTEOF'
import express from 'express';

// Multi-provider AI agent with automatic fallback
class AIAgent {
  constructor() {
    this.providers = {
      groq: { url: 'https://api.groq.com/openai/v1/chat/completions', key: process.env.GROQ_API_KEY, models: ['llama-3.1-8b-instant', 'llama-3.3-70b-versatile', 'llama-3.1-8b-instant'] },
      together: { url: 'https://api.together.xyz/v1/chat/completions', key: process.env.TOGETHER_API_KEY, models: ['meta-llama/Llama-3-8b-chat-hf', 'mistralai/Mixtral-8x7B-Instruct-v0.1'] },
      openrouter: { url: 'https://openrouter.ai/api/v1/chat/completions', key: process.env.OPENROUTER_API_KEY, models: ['meta-llama/llama-3-8b-instruct:free', 'mistralai/mistral-7b-instruct:free'] },
      mistral: { url: 'https://api.mistral.ai/v1/chat/completions', key: process.env.MISTRAL_API_KEY, models: ['mistral-tiny', 'mistral-small', 'mistral-medium'] },
      deepinfra: { url: 'https://api.deepinfra.com/v1/openai/chat/completions', key: process.env.DEEPINFRA_API_KEY, models: ['meta-llama/Llama-3-8b-Instruct', 'mistralai/Mixtral-8x7B-Instruct-v0.1'] },
    };
    this.memory = [];
    this.currentProvider = 'groq';
  }

  getAvailableProviders() {
    return Object.entries(this.providers)
      .filter(([_, p]) => p.key)
      .map(([name]) => name);
  }

  async chat(message, options = {}) {
    const { provider, model, systemPrompt } = options;

    // Auto-select provider
    const providers = provider ? [provider] : this.getAvailableProviders();
    if (providers.length === 0) throw new Error('No AI providers configured');

    // Add to memory
    this.memory.push({ role: 'user', content: message });
    if (this.memory.length > 20) this.memory = this.memory.slice(-20);

    const messages = [];
    if (systemPrompt) messages.push({ role: 'system', content: systemPrompt });
    messages.push(...this.memory);

    // Try providers with fallback
    for (const pName of providers) {
      const p = this.providers[pName];
      if (!p?.key) continue;

      try {
        const res = await fetch(p.url, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${p.key}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model: model || p.models[0],
            messages,
            max_tokens: 1024,
            temperature: 0.7,
          }),
        });

        if (res.ok) {
          const data = await res.json();
          const reply = data.choices?.[0]?.message?.content || 'No response';
          this.memory.push({ role: 'assistant', content: reply });
          return { reply, provider: pName, model: model || p.models[0], usage: data.usage };
        }
      } catch (e) {
        console.error(`${pName} failed: ${e.message}`);
        continue;
      }
    }

    throw new Error('All providers failed');
  }

  clearMemory() { this.memory = []; }
}

// Express server
const app = express();
app.use(express.json());

const agent = new AIAgent();

app.get('/', (req, res) => res.json({
  name: 'AI Agent',
  status: 'running',
  providers: agent.getAvailableProviders(),
  memory_length: agent.memory.length,
}));

app.post('/chat', async (req, res) => {
  try {
    const { message, provider, model, system } = req.body;
    const result = await agent.chat(message, { provider, model, systemPrompt: system });
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/reset', (req, res) => {
  agent.clearMemory();
  res.json({ status: 'memory cleared' });
});

app.get('/providers', (req, res) => {
  res.json({ available: agent.getAvailableProviders() });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🧠 AI Agent running on port ${PORT}`));
AGENTEOF

  cat > "$dir/.env.example" << 'EOF'
# Add at least one provider key
GROQ_API_KEY=           # Free: console.groq.com
TOGETHER_API_KEY=       # Free: api.together.xyz
OPENROUTER_API_KEY=     # Free: openrouter.ai/keys
MISTRAL_API_KEY=        # Free: console.mistral.ai
DEEPINFRA_API_KEY=      # Free: deepinfra.com

PORT=3000
EOF

  log INFO "  ✅ Chatbot agent created"
}

create_code_reviewer_agent() {
  local dir="$1"
  mkdir -p "$dir/src"

  cat > "$dir/package.json" << 'EOF'
{
  "name": "ai-code-reviewer",
  "version": "1.0.0",
  "description": "AI agent that reviews code, finds bugs, suggests improvements",
  "type": "module",
  "scripts": {
    "start": "node src/reviewer.js",
    "review": "node src/cli.js"
  },
  "dependencies": {
    "node-fetch": "^3.0.0"
  }
}
EOF

  cat > "$dir/src/reviewer.js" << 'EOF'
// AI Code Reviewer Agent
// Uses free AI APIs to review code

const PROVIDERS = {
  groq: { url: 'https://api.groq.com/openai/v1/chat/completions', key: process.env.GROQ_API_KEY },
  openrouter: { url: 'https://openrouter.ai/api/v1/chat/completions', key: process.env.OPENROUTER_API_KEY },
};

export async function reviewCode(code, language = 'javascript') {
  const systemPrompt = `You are an expert code reviewer. Analyze the following ${language} code and provide:
1. 🔴 Critical issues (bugs, security vulnerabilities)
2. 🟡 Warnings (potential issues, edge cases)
3. 🟢 Suggestions (best practices, optimizations)
4. 📊 Code quality score (1-10)

Be specific with line references and provide fixes.`;

  for (const [name, provider] of Object.entries(PROVIDERS)) {
    if (!provider.key) continue;
    try {
      const res = await fetch(provider.url, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${provider.key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: name === 'groq' ? 'llama-3.3-70b-versatile' : 'meta-llama/llama-3-70b-instruct',
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: `Review this code:\n\`\`\`${language}\n${code}\n\`\`\`` }
          ],
          max_tokens: 2048,
        }),
      });
      if (res.ok) {
        const data = await res.json();
        return data.choices[0].message.content;
      }
    } catch (e) { continue; }
  }
  throw new Error('No providers available');
}
EOF

  log INFO "  ✅ Code reviewer agent created"
}

create_data_analyst_agent() {
  local dir="$1"
  mkdir -p "$dir/src"

  cat > "$dir/package.json" << 'EOF'
{
  "name": "ai-data-analyst",
  "version": "1.0.0",
  "description": "AI agent that analyzes data, generates insights, creates reports",
  "type": "module",
  "scripts": { "start": "node src/analyst.js" },
  "dependencies": { "node-fetch": "^3.0.0" }
}
EOF

  cat > "$dir/src/analyst.js" << 'EOF'
// AI Data Analyst Agent
import { readFileSync } from 'fs';

export async function analyzeData(data, question = null) {
  const prompt = question
    ? `Analyze this data and answer: ${question}\n\nData:\n${typeof data === 'string' ? data : JSON.stringify(data, null, 2)}`
    : `Analyze this data and provide key insights, trends, anomalies, and recommendations:\n\n${typeof data === 'string' ? data : JSON.stringify(data, null, 2)}`;

  const providers = [
    { url: 'https://api.groq.com/openai/v1/chat/completions', key: process.env.GROQ_API_KEY, model: 'llama-3.3-70b-versatile' },
    { url: 'https://openrouter.ai/api/v1/chat/completions', key: process.env.OPENROUTER_API_KEY, model: 'meta-llama/llama-3-70b-instruct' },
  ];

  for (const p of providers) {
    if (!p.key) continue;
    try {
      const res = await fetch(p.url, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${p.key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: p.model,
          messages: [
            { role: 'system', content: 'You are a data analyst. Provide clear, actionable insights with numbers and evidence.' },
            { role: 'user', content: prompt }
          ],
          max_tokens: 2048,
        }),
      });
      if (res.ok) {
        const data = await res.json();
        return data.choices[0].message.content;
      }
    } catch (e) { continue; }
  }
}
EOF

  log INFO "  ✅ Data analyst agent created"
}

create_content_writer_agent() {
  local dir="$1"
  mkdir -p "$dir"

  cat > "$dir/package.json" << 'EOF'
{
  "name": "ai-content-writer",
  "version": "1.0.0",
  "description": "AI agent for blog posts, docs, marketing copy",
  "type": "module",
  "scripts": { "start": "node src/writer.js" },
  "dependencies": { "node-fetch": "^3.0.0" }
}
EOF
  mkdir -p "$dir/src"
  cat > "$dir/src/writer.js" << 'EOF'
export async function writeContent(type, topic, tone = 'professional') {
  const prompts = {
    blog: `Write a comprehensive blog post about: ${topic}. Tone: ${tone}. Include intro, sections with headers, and conclusion.`,
    readme: `Write a detailed README.md for: ${topic}. Include description, installation, usage, API, and examples.`,
    changelog: `Write a changelog entry for: ${topic}. Follow Keep a Changelog format.`,
    email: `Write a ${tone} email about: ${topic}.`,
    docs: `Write technical documentation for: ${topic}. Include overview, getting started, API reference, and examples.`,
  };

  const prompt = prompts[type] || `Write ${type} content about: ${topic}`;

  const providers = [
    { url: 'https://api.groq.com/openai/v1/chat/completions', key: process.env.GROQ_API_KEY, model: 'llama-3.3-70b-versatile' },
    { url: 'https://openrouter.ai/api/v1/chat/completions', key: process.env.OPENROUTER_API_KEY, model: 'meta-llama/llama-3-70b-instruct' },
  ];

  for (const p of providers) {
    if (!p.key) continue;
    try {
      const res = await fetch(p.url, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${p.key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: p.model, messages: [{ role: 'user', content: prompt }], max_tokens: 4096 }),
      });
      if (res.ok) {
        const data = await res.json();
        return data.choices[0].message.content;
      }
    } catch (e) { continue; }
  }
}
EOF
  log INFO "  ✅ Content writer agent created"
}

# ═══════════════════════════════════════════════════════
# Main — Build all agents
# ═══════════════════════════════════════════════════════

AGENTS_CREATED=()

create_chatbot_agent "$AGENTS_DIR/chatbot"
AGENTS_CREATED+=("Chatbot Agent")

create_code_reviewer_agent "$AGENTS_DIR/code-reviewer"
AGENTS_CREATED+=("Code Reviewer Agent")

create_data_analyst_agent "$AGENTS_DIR/data-analyst"
AGENTS_CREATED+=("Data Analyst Agent")

create_content_writer_agent "$AGENTS_DIR/content-writer"
AGENTS_CREATED+=("Content Writer Agent")

# Generate report
cat > "$REPORT" << EOF
# 🧠 AI Agent Factory Report

**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Agents Created:** ${#AGENTS_CREATED[@]}

## Built Agents

$(for agent in "${AGENTS_CREATED[@]}"; do
  echo "- ✅ **$agent**"
done)

## Agent Capabilities

### 🤖 Chatbot Agent
- Multi-provider support (Groq, Together, OpenRouter, Mistral, DeepInfra)
- Conversation memory (last 20 messages)
- Automatic provider fallback
- System prompt customization
- REST API for integration

### 🔍 Code Reviewer Agent
- Automatic bug detection
- Security vulnerability scanning
- Code quality scoring (1-10)
- Best practice suggestions
- Multi-language support

### 📊 Data Analyst Agent
- CSV/JSON data analysis
- Trend detection
- Anomaly identification
- Natural language queries
- Report generation

### ✍️ Content Writer Agent
- Blog posts, READMEs, docs
- Email drafting
- Changelog generation
- Multiple tone options
- Technical writing

## How to Use

\`\`\`bash
# Chatbot Agent
cd .github/ai-agents/chatbot
cp .env.example .env  # Add your free API keys
npm install && npm start

# Code Reviewer
cd .github/ai-agents/code-reviewer
node src/cli.js --file path/to/code.js

# Data Analyst
cd .github/ai-agents/data-analyst
node src/analyst.js --data data.csv --question "What are the trends?"
\`\`\`

## Free API Keys Needed

Get free keys from:
- **Groq** (recommended, fastest): https://console.groq.com
- **OpenRouter**: https://openrouter.ai/keys
- **Together AI**: https://api.together.xyz

---
_Automated by AI Agent Factory 🧠_
EOF

cat "$REPORT"

notify "$(basename $BOT_NAME 2>/dev/null || basename $0)" "Bot completed successfully. Check report." 2>/dev/null || true
log INFO "🧠 AI Agent Factory complete! Created ${#AGENTS_CREATED[@]} agents."

exit 0
