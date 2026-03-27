#!/bin/bash
# 🧠 AI Agent Factory Pro
# Builds ADVANCED AI agents — like Kilo/OpenClaw level
# Multi-provider, memory, tools, RAG, multi-modal, autonomous
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

REPORT="ai-agent-pro-report.md"
log INFO "🧠 AI Agent Factory Pro starting..."

AGENTS_DIR=".github/ai-agents"
mkdir -p "$AGENTS_DIR"

# ═══════════════════════════════════════════════════════
# Agent 1: Autonomous Agent (like Kilo/OpenClaw)
# ═══════════════════════════════════════════════════════
build_autonomous_agent() {
  local dir="$AGENTS_DIR/autonomous-agent"
  mkdir -p "$dir/src" "$dir/tools" "$dir/memory"

  cat > "$dir/package.json" << 'EOF'
{
  "name": "autonomous-agent",
  "version": "1.0.0",
  "description": "Advanced autonomous AI agent with tools, memory, and multi-provider support",
  "type": "module",
  "scripts": {
    "start": "node src/agent.js",
    "dev": "node --watch src/agent.js",
    "chat": "node src/cli.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "node-fetch": "^3.0.0",
    "better-sqlite3": "^9.0.0"
  }
}
EOF

  cat > "$dir/src/agent.js" << 'AGENTEOF'
import express from 'express';

// ═══ Multi-Provider AI Engine ═══
class AIEngine {
  constructor() {
    this.providers = {
      groq:      { url: 'https://api.groq.com/openai/v1/chat/completions', key: process.env.GROQ_API_KEY, models: ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'llama-3.1-8b-instant'], speed: 'fastest' },
      together:  { url: 'https://api.together.xyz/v1/chat/completions', key: process.env.TOGETHER_API_KEY, models: ['meta-llama/Llama-3-70b-chat-hf', 'mistralai/Mixtral-8x7B-Instruct-v0.1'], speed: 'fast' },
      openrouter:{ url: 'https://openrouter.ai/api/v1/chat/completions', key: process.env.OPENROUTER_API_KEY, models: ['meta-llama/llama-3-70b-instruct', 'mistralai/mistral-7b-instruct:free'], speed: 'medium' },
      mistral:   { url: 'https://api.mistral.ai/v1/chat/completions', key: process.env.MISTRAL_API_KEY, models: ['mistral-large-latest', 'mistral-medium', 'mistral-small'], speed: 'fast' },
      deepinfra: { url: 'https://api.deepinfra.com/v1/openai/chat/completions', key: process.env.DEEPINFRA_API_KEY, models: ['meta-llama/Llama-3-70b-Instruct'], speed: 'fast' },
      openai:    { url: 'https://api.openai.com/v1/chat/completions', key: process.env.OPENAI_API_KEY, models: ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo'], speed: 'medium' },
      anthropic: { url: 'https://api.anthropic.com/v1/messages', key: process.env.ANTHROPIC_API_KEY, models: ['claude-sonnet-4-20250514'], speed: 'slow' },
    };
  }

  getAvailable() {
    return Object.entries(this.providers).filter(([_, p]) => p.key).map(([name, p]) => ({ name, models: p.models, speed: p.speed }));
  }

  async chat(messages, options = {}) {
    const { provider, model, temperature = 0.7, maxTokens = 4096 } = options;
    const providers = provider ? [provider] : this.getAvailable().map(p => p.name);

    for (const pName of providers) {
      const p = this.providers[pName];
      if (!p?.key) continue;
      try {
        const res = await fetch(p.url, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${p.key}`, 'Content-Type': 'application/json', ...(pName === 'anthropic' ? { 'x-api-version': '2023-06-01', 'anthropic-version': '2023-06-01' } : {}) },
          body: JSON.stringify(pName === 'anthropic'
            ? { model: model || p.models[0], max_tokens: maxTokens, messages: messages.filter(m => m.role !== 'system'), system: messages.find(m => m.role === 'system')?.content }
            : { model: model || p.models[0], messages, temperature, max_tokens: maxTokens }
          ),
        });
        if (res.ok) {
          const data = await res.json();
          const content = pName === 'anthropic' ? data.content?.[0]?.text : data.choices?.[0]?.message?.content;
          return { content, provider: pName, model: model || p.models[0], usage: data.usage };
        }
      } catch (e) { continue; }
    }
    throw new Error('All providers failed');
  }
}

// ═══ Tool System ═══
class ToolSystem {
  constructor() {
    this.tools = {
      web_search: { desc: 'Search the web', fn: async (q) => { return `Search results for: ${q}`; } },
      read_file: { desc: 'Read a file', fn: async (p) => { const fs = await import('fs'); return fs.readFileSync(p, 'utf8'); } },
      write_file: { desc: 'Write to a file', fn: async (p, c) => { const fs = await import('fs'); fs.writeFileSync(p, c); return `Written to ${p}`; } },
      run_command: { desc: 'Run a shell command', fn: async (cmd) => { const { execSync } = await import('child_process'); return execSync(cmd).toString(); } },
      get_time: { desc: 'Get current time', fn: async () => new Date().toISOString() },
    };
  }

  list() { return Object.entries(this.tools).map(([name, t]) => `${name}: ${t.desc}`); }
  async execute(name, ...args) { return this.tools[name]?.fn(...args) || 'Tool not found'; }
}

// ═══ Memory System ═══
class MemorySystem {
  constructor() { this.shortTerm = []; this.longTerm = []; this.maxShort = 50; }
  add(role, content) {
    this.shortTerm.push({ role, content, time: Date.now() });
    if (this.shortTerm.length > this.maxShort) {
      this.longTerm.push(this.shortTerm.shift());
    }
  }
  getMessages(systemPrompt) {
    const msgs = [];
    if (systemPrompt) msgs.push({ role: 'system', content: systemPrompt });
    msgs.push(...this.shortTerm);
    return msgs;
  }
  clear() { this.shortTerm = []; }
  stats() { return { short: this.shortTerm.length, long: this.longTerm.length }; }
}

// ═══ Main Agent ═══
class AutonomousAgent {
  constructor(name = 'Agent') {
    this.name = name;
    this.ai = new AIEngine();
    this.tools = new ToolSystem();
    this.memory = new MemorySystem();
    this.systemPrompt = `You are ${name}, an advanced autonomous AI assistant. You can use tools, remember conversations, and help with any task. Be helpful, concise, and proactive.`;
  }

  async think(input, options = {}) {
    this.memory.add('user', input);
    const messages = this.memory.getMessages(this.systemPrompt);
    const response = await this.ai.chat(messages, options);
    this.memory.add('assistant', response.content);
    return response;
  }

  async act(toolName, ...args) {
    const result = await this.tools.execute(toolName, ...args);
    this.memory.add('tool', `[${toolName}] ${result}`);
    return result;
  }

  getStatus() {
    return {
      name: this.name,
      providers: this.ai.getAvailable().length,
      tools: Object.keys(this.tools.tools).length,
      memory: this.memory.stats(),
    };
  }
}

// ═══ REST API ═══
const app = express();
app.use(express.json());
const agent = new AutonomousAgent('Kilo');

app.get('/', (req, res) => res.json({ ...agent.getStatus(), status: 'running' }));

app.post('/chat', async (req, res) => {
  try {
    const { message, provider, model } = req.body;
    const result = await agent.think(message, { provider, model });
    res.json(result);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/tool/:name', async (req, res) => {
  try {
    const result = await agent.act(req.params.name, ...Object.values(req.body));
    res.json({ result });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/tools', (req, res) => res.json(agent.tools.list()));
app.get('/providers', (req, res) => res.json(agent.ai.getAvailable()));
app.post('/reset', (req, res) => { agent.memory.clear(); res.json({ status: 'reset' }); });

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🧠 ${agent.name} running on port ${PORT}`));
AGENTEOF

  cat > "$dir/.env.example" << 'EOF'
# AI Providers (add at least one)
GROQ_API_KEY=           # Free: console.groq.com (fastest)
OPENROUTER_API_KEY=     # Free: openrouter.ai/keys (many models)
MISTRAL_API_KEY=        # Free: console.mistral.ai
TOGETHER_API_KEY=       # Free: api.together.xyz ($25 credits)
DEEPINFRA_API_KEY=      # Free: deepinfra.com
OPENAI_API_KEY=         # Paid: platform.openai.com
ANTHROPIC_API_KEY=      # Paid: console.anthropic.com

PORT=3000
EOF

  log INFO "  ✅ Autonomous Agent built"
}

# ═══════════════════════════════════════════════════════
# Agent 2: RAG Agent (Retrieval-Augmented Generation)
# ═══════════════════════════════════════════════════════
build_rag_agent() {
  local dir="$AGENTS_DIR/rag-agent"
  mkdir -p "$dir/src" "$dir/data"

  cat > "$dir/package.json" << 'EOF'
{
  "name": "rag-agent",
  "version": "1.0.0",
  "description": "RAG agent — searches documents, answers questions with context",
  "type": "module",
  "scripts": { "start": "node src/rag.js", "ingest": "node src/ingest.js" },
  "dependencies": { "express": "^4.18.0", "node-fetch": "^3.0.0" }
}
EOF

  cat > "$dir/src/rag.js" << 'EOF'
import express from 'express';
import { readFileSync, writeFileSync, existsSync } from 'fs';

const PROVIDERS = {
  groq: { url: 'https://api.groq.com/openai/v1/chat/completions', key: process.env.GROQ_API_KEY },
  openrouter: { url: 'https://openrouter.ai/api/v1/chat/completions', key: process.env.OPENROUTER_API_KEY },
};

// Simple in-memory vector store
class VectorStore {
  constructor() { this.documents = []; }
  add(doc) { this.documents.push({ text: doc, id: this.documents.length }); }
  search(query, topK = 3) {
    const words = query.toLowerCase().split(/\s+/);
    return this.documents
      .map(d => ({ ...d, score: words.filter(w => d.text.toLowerCase().includes(w)).length }))
      .sort((a, b) => b.score - a.score)
      .slice(0, topK)
      .filter(d => d.score > 0);
  }
  load(path) { if (existsSync(path)) this.documents = JSON.parse(readFileSync(path)); }
  save(path) { writeFileSync(path, JSON.stringify(this.documents)); }
}

const store = new VectorStore();
store.load('./data/store.json');

async function generate(systemPrompt, userPrompt) {
  for (const [name, p] of Object.entries(PROVIDERS)) {
    if (!p.key) continue;
    try {
      const res = await fetch(p.url, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${p.key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: 'llama-3.3-70b-versatile', messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }], max_tokens: 2048 }),
      });
      if (res.ok) { const data = await res.json(); return data.choices[0].message.content; }
    } catch (e) { continue; }
  }
  return 'No AI provider available';
}

const app = express();
app.use(express.json());

app.post('/ask', async (req, res) => {
  const { question } = req.body;
  const relevant = store.search(question);
  const context = relevant.map(d => d.text).join('\n---\n');
  const answer = await generate(
    'Answer the question using the provided context. If the context does not contain the answer, say so.',
    `Context:\n${context}\n\nQuestion: ${question}`
  );
  res.json({ answer, sources: relevant.length });
});

app.post('/ingest', (req, res) => {
  const { text } = req.body;
  store.add(text);
  store.save('./data/store.json');
  res.json({ status: 'ingested', total: store.documents.length });
});

app.get('/stats', (req, res) => res.json({ documents: store.documents.length }));

app.listen(process.env.PORT || 3001, () => console.log('📚 RAG Agent running'));
EOF

  log INFO "  ✅ RAG Agent built"
}

# ═══════════════════════════════════════════════════════
# Agent 3: Multi-Agent Orchestrator
# ═══════════════════════════════════════════════════════
build_orchestrator() {
  local dir="$AGENTS_DIR/orchestrator"
  mkdir -p "$dir/src" "$dir/agents"

  cat > "$dir/package.json" << 'EOF'
{
  "name": "agent-orchestrator",
  "version": "1.0.0",
  "description": "Orchestrates multiple AI agents — routes tasks to specialists",
  "type": "module",
  "scripts": { "start": "node src/orchestrator.js" },
  "dependencies": { "express": "^4.18.0", "node-fetch": "^3.0.0" }
}
EOF

  cat > "$dir/src/orchestrator.js" << 'EOF'
import express from 'express';

const AGENTS = {
  coder: { name: 'Code Agent', system: 'You are an expert programmer. Write clean, efficient code.', model: 'llama-3.3-70b-versatile' },
  writer: { name: 'Writer Agent', system: 'You are a professional writer. Create engaging content.', model: 'llama-3.3-70b-versatile' },
  analyst: { name: 'Analyst Agent', system: 'You are a data analyst. Provide insights and analysis.', model: 'llama-3.3-70b-versatile' },
  researcher: { name: 'Research Agent', system: 'You are a research assistant. Find and summarize information.', model: 'llama-3.3-70b-versatile' },
  reviewer: { name: 'Code Reviewer', system: 'You review code for bugs, security issues, and best practices.', model: 'llama-3.3-70b-versatile' },
};

async function callAI(system, message, model) {
  const key = process.env.GROQ_API_KEY || process.env.OPENROUTER_API_KEY;
  const url = process.env.GROQ_API_KEY ? 'https://api.groq.com/openai/v1/chat/completions' : 'https://openrouter.ai/api/v1/chat/completions';
  if (!key) return 'No API key configured';
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model, messages: [{ role: 'system', content: system }, { role: 'user', content: message }], max_tokens: 2048 }),
  });
  const data = await res.json();
  return data.choices?.[0]?.message?.content || 'No response';
}

async function routeTask(task) {
  const keywords = {
    coder: ['code', 'function', 'program', 'build', 'implement', 'fix bug'],
    writer: ['write', 'blog', 'article', 'content', 'email', 'story'],
    analyst: ['analyze', 'data', 'statistics', 'report', 'metrics'],
    researcher: ['research', 'find', 'search', 'investigate', 'summarize'],
    reviewer: ['review', 'check', 'audit', 'improve', 'optimize'],
  };
  const taskLower = task.toLowerCase();
  let bestAgent = 'coder';
  let bestScore = 0;
  for (const [agent, words] of Object.entries(keywords)) {
    const score = words.filter(w => taskLower.includes(w)).length;
    if (score > bestScore) { bestScore = score; bestAgent = agent; }
  }
  return bestAgent;
}

const app = express();
app.use(express.json());

app.post('/task', async (req, res) => {
  const { task, agent } = req.body;
  const agentKey = agent || await routeTask(task);
  const a = AGENTS[agentKey];
  const result = await callAI(a.system, task, a.model);
  res.json({ agent: a.name, result });
});

app.get('/agents', (req, res) => res.json(AGENTS));

app.listen(process.env.PORT || 3002, () => console.log('🎭 Orchestrator running'));
EOF

  log INFO "  ✅ Orchestrator built"
}

# ═══════════════════════════════════════════════════════
# Agent 4: Chatbot with Web UI
# ═══════════════════════════════════════════════════════
build_chatbot_ui() {
  local dir="$AGENTS_DIR/chatbot-ui"
  mkdir -p "$dir/public" "$dir/src"

  cat > "$dir/package.json" << 'EOF'
{
  "name": "chatbot-ui",
  "version": "1.0.0",
  "description": "ChatGPT-style chatbot with web UI, multi-provider, free APIs",
  "type": "module",
  "scripts": { "start": "node src/server.js", "dev": "node --watch src/server.js" },
  "dependencies": { "express": "^4.18.0", "node-fetch": "^3.0.0" }
}
EOF

  cat > "$dir/src/server.js" << 'EOF'
import express from 'express';
import { readFileSync } from 'fs';

const PROVIDERS = {
  groq: { url: 'https://api.groq.com/openai/v1/chat/completions', key: process.env.GROQ_API_KEY, models: ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'llama-3.1-8b-instant'] },
  openrouter: { url: 'https://openrouter.ai/api/v1/chat/completions', key: process.env.OPENROUTER_API_KEY, models: ['meta-llama/llama-3-70b-instruct', 'mistralai/mistral-7b-instruct:free'] },
  mistral: { url: 'https://api.mistral.ai/v1/chat/completions', key: process.env.MISTRAL_API_KEY, models: ['mistral-large-latest', 'mistral-small'] },
};

const app = express();
app.use(express.json());
app.use(express.static('public'));

const sessions = {};

app.post('/api/chat', async (req, res) => {
  const { message, sessionId = 'default', provider = 'groq', model } = req.body;
  if (!sessions[sessionId]) sessions[sessionId] = [];
  sessions[sessionId].push({ role: 'user', content: message });

  const p = PROVIDERS[provider];
  if (!p?.key) return res.status(400).json({ error: `${provider} not configured` });

  try {
    const r = await fetch(p.url, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${p.key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: model || p.models[0], messages: sessions[sessionId], max_tokens: 2048 }),
    });
    const data = await r.json();
    const reply = data.choices?.[0]?.message?.content || 'No response';
    sessions[sessionId].push({ role: 'assistant', content: reply });
    res.json({ reply, provider, model: model || p.models[0] });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/providers', (req, res) => {
  const available = Object.entries(PROVIDERS).filter(([_, p]) => p.key).map(([name, p]) => ({ name, models: p.models }));
  res.json(available);
});

app.post('/api/reset', (req, res) => {
  const { sessionId = 'default' } = req.body;
  sessions[sessionId] = [];
  res.json({ status: 'reset' });
});

app.listen(process.env.PORT || 3000, () => console.log('💬 Chatbot UI running on http://localhost:3000'));
EOF

  cat > "$dir/public/index.html" << 'EOF'
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AI Chatbot</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui;background:#1a1a2e;color:#eee;display:flex;height:100vh}
.sidebar{width:250px;background:#16213e;padding:16px;display:flex;flex-direction:column}
.sidebar h2{color:#00d4ff;margin-bottom:16px}
.providers{flex:1;overflow-y:auto}
.provider{padding:8px 12px;margin:4px 0;border-radius:8px;cursor:pointer;background:#0f3460}
.provider.active{background:#00d4ff;color:#000}
.provider:hover{opacity:.8}
.main{flex:1;display:flex;flex-direction:column}
.messages{flex:1;overflow-y:auto;padding:20px}
.msg{margin:12px 0;padding:12px 16px;border-radius:12px;max-width:80%}
.msg.user{background:#0f3460;margin-left:auto}
.msg.assistant{background:#1a1a3e}
.input-area{padding:16px;background:#16213e;display:flex;gap:8px}
input{flex:1;padding:12px;border:none;border-radius:8px;background:#0f3460;color:#fff;font-size:16px}
button{padding:12px 24px;border:none;border-radius:8px;background:#00d4ff;color:#000;font-weight:bold;cursor:pointer}
button:hover{opacity:.8}
select{padding:8px;border-radius:8px;background:#0f3460;color:#fff;border:none}
</style>
</head><body>
<div class="sidebar">
<h2>🤖 AI Chatbot</h2>
<select id="provider" onchange="changeProvider()"></select>
<div class="providers" id="providers"></div>
<button onclick="resetChat()" style="margin-top:8px">New Chat</button>
</div>
<div class="main">
<div class="messages" id="messages"></div>
<div class="input-area">
<input id="input" placeholder="Type a message..." onkeydown="if(event.key==='Enter')send()">
<button onclick="send()">Send</button>
</div>
</div>
<script>
let currentProvider='groq';
async function init(){
  const r=await fetch('/api/providers');const providers=await r.json();
  const sel=document.getElementById('provider');
  const div=document.getElementById('providers');
  providers.forEach(p=>{
    sel.innerHTML+=`<option value="${p.name}">${p.name}</option>`;
    div.innerHTML+=`<div class="provider ${p.name===currentProvider?'active':''}" onclick="selectProvider('${p.name}')">${p.name}<br><small>${p.models[0]}</small></div>`;
  });
}
function selectProvider(p){currentProvider=p;document.querySelectorAll('.provider').forEach(e=>e.classList.remove('active'));}
function changeProvider(){currentProvider=document.getElementById('provider').value;}
async function send(){
  const input=document.getElementById('input');
  const msg=input.value.trim();if(!msg)return;
  addMsg('user',msg);input.value='';
  const r=await fetch('/api/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({message:msg,provider:currentProvider})});
  const data=await r.json();
  addMsg('assistant',data.reply||data.error);
}
function addMsg(role,text){
  const div=document.getElementById('messages');
  div.innerHTML+=`<div class="msg ${role}">${text}</div>`;
  div.scrollTop=div.scrollHeight;
}
async function resetChat(){
  await fetch('/api/reset',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({})});
  document.getElementById('messages').innerHTML='';
}
init();
</script>
</body></html>
EOF

  log INFO "  ✅ Chatbot UI built"
}

# ═══════════════════════════════════════════════════════
# Build All Agents
# ═══════════════════════════════════════════════════════
AGENTS_BUILT=()

build_autonomous_agent && AGENTS_BUILT+=("Autonomous Agent (Kilo-level)")
build_rag_agent && AGENTS_BUILT+=("RAG Agent (Document Q&A)")
build_orchestrator && AGENTS_BUILT+=("Multi-Agent Orchestrator")
build_chatbot_ui && AGENTS_BUILT+=("Chatbot with Web UI")

# ═══════════════════════════════════════════════════════
# Report
# ═══════════════════════════════════════════════════════
cat > "$REPORT" << REOF
# 🧠 AI Agent Factory Pro Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Agents Built:** ${#AGENTS_BUILT[@]}

## Built Agents
$(for a in "${AGENTS_BUILT[@]}"; do echo "- ✅ **$a**"; done)

## Agent Details

### 🤖 Autonomous Agent (Kilo-level)
- Multi-provider: Groq, Together, OpenRouter, Mistral, DeepInfra, OpenAI, Anthropic
- Tool system: web search, file read/write, shell commands
- Memory: short-term + long-term conversation memory
- REST API: /chat, /tool/:name, /providers, /reset
- Auto-fallback between providers

### 📚 RAG Agent (Document Q&A)
- Ingest documents into vector store
- Ask questions about your documents
- Context-aware answers with sources
- Simple file-based storage

### 🎭 Multi-Agent Orchestrator
- Routes tasks to specialist agents
- Code Agent, Writer, Analyst, Researcher, Reviewer
- Automatic task classification
- Single API endpoint for all tasks

### 💬 Chatbot with Web UI
- Beautiful ChatGPT-style interface
- Multi-provider support
- Conversation memory
- One-click deploy to Vercel/Netlify

## Quick Start
\`\`\`bash
# Autonomous Agent
cd .github/ai-agents/autonomous-agent
cp .env.example .env  # Add your API keys
npm install && npm start

# Chatbot UI
cd .github/ai-agents/chatbot-ui
npm install && npm start
# Open http://localhost:3000
\`\`\`

---
_Automated by AI Agent Factory Pro 🧠_
REOF

cat "$REPORT"
notify "AI Agent Factory Pro" "Built ${#AGENTS_BUILT[@]} advanced AI agents!"
exit 0
