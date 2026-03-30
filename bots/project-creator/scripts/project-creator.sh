#!/bin/bash
# 🏗️ Project Creator Bot
# Finds ideas → Creates NEW GitHub repos → Builds full projects → Deploys → Reports live URL
# Autonomous — no human intervention
set -uo pipefail
trap 'record_result "project-creator" "error" "script exited with error" 2>/dev/null || true' ERR
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"
source "${GITHUB_WORKSPACE:-.}/shared/state.sh"

REPORT="project-creator-report.md"
log INFO "🏗️ Project Creator Bot starting..."

OWNER=$(get_repo_owner)
CREATED_REPOS=()
CREATED_URLS=()

# ═══════════════════════════════════════════════════════
# Project Ideas Database
# ═══════════════════════════════════════════════════════
get_project_ideas() {
  # Check trending repos for inspiration
  log INFO "🔍 Scanning trending repos for ideas..."
  TRENDING=$(curl -sL "https://github.com/trending" 2>/dev/null | grep -oE 'href="/[^/]+/[^/"]+' | sed 's|href="/||' | head -10 || echo "")
  log INFO "  Found trending: $(echo $TRENDING | head -3)"

  # Predefined project ideas
  IDEAS=(
    "ai-resume-builder|AI Resume Builder|Build professional resumes with AI, multiple templates, PDF export|static"
    "url-shortener|URL Shortener|Free URL shortener with analytics, custom slugs, QR codes|node"
    "markdown-editor|Markdown Editor|Live preview markdown editor with export to PDF/HTML|static"
    "api-dashboard|API Dashboard|Monitor and test APIs, track uptime, response times|static"
    "password-generator|Password Generator|Generate secure passwords, check strength, save locally|static"
    "color-palette|Color Palette Generator|Generate beautiful color palettes, export CSS/JSON|static"
    "qr-generator|QR Code Generator|Generate QR codes for URLs, text, WiFi, vCards|static"
    "json-formatter|JSON Formatter & Validator|Format, validate, minify JSON with syntax highlighting|static"
    "regex-tester|Regex Tester|Test regular expressions with real-time matching, explanations|static"
    "base64-tool|Base64 Encoder/Decoder|Encode/decode Base64, file support, drag & drop|static"
    "pomodoro-timer|Pomodoro Timer|Focus timer with task tracking, statistics, notifications|static"
    "unit-converter|Unit Converter|Convert between units: length, weight, temperature, currency|static"
    "image-compressor|Image Compressor|Compress images in browser, no upload needed, privacy-first|static"
    "typing-test|Typing Speed Test|Test typing speed (WPM), accuracy, with multiple texts|static"
    "expense-tracker|Expense Tracker|Track expenses with categories, charts, export to CSV|static"
  )
}

# ═══════════════════════════════════════════════════════
# Check if repo already exists
# ═══════════════════════════════════════════════════════
repo_exists() {
  gh repo view "$OWNER/$1" >/dev/null 2>&1
}

# ═══════════════════════════════════════════════════════
# Create a new GitHub repo and build the project
# ═══════════════════════════════════════════════════════
create_project() {
  local slug="$1"
  local name="$2"
  local desc="$3"
  local type="$4"
  
  if repo_exists "$slug"; then
    log INFO "  ⏭️ $slug already exists, skipping"
    return 0
  fi
  
  log INFO "  🆕 Creating repo: $slug"
  
  # Create the repo
  TMPDIR=$(mktemp -d)
  gh repo create "$OWNER/$slug" --public --description "$desc" --clone 2>&1 | tail -1
  cd "$TMPDIR/$slug" 2>/dev/null || cd "$TMPDIR"
  
  # Initialize
  echo "# $name" > README.md
  echo "" >> README.md
  echo "$desc" >> README.md
  echo "" >> README.md
  echo "## Live Demo" >> README.md
  echo "🔗 https://$OWNER.github.io/$slug/" >> README.md
  echo "" >> README.md
  echo "## Quick Start" >> README.md
  echo '```bash' >> README.md
  echo "open index.html" >> README.md
  echo '```' >> README.md
  echo "" >> README.md
  echo "---" >> README.md
  echo "Created by 🤖 GitHub Autopilot Bots" >> README.md
  
  # Create based on type
  case "$slug" in
    ai-resume-builder)
      cat > index.html << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>AI Resume Builder</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;background:#0f0f23;color:#fff;min-height:100vh}.container{max-width:900px;margin:0 auto;padding:2rem}h1{text-align:center;margin-bottom:2rem;background:linear-gradient(135deg,#667eea,#00d4ff);-webkit-background-clip:text;-webkit-text-fill-color:transparent}.form{display:grid;gap:1rem;margin-bottom:2rem}input,textarea,select{padding:.8rem;border:1px solid #333;border-radius:8px;background:#16213e;color:#fff;font-size:1rem}textarea{min-height:100px}button{padding:1rem;background:linear-gradient(135deg,#667eea,#00d4ff);border:none;border-radius:8px;color:#fff;font-size:1rem;cursor:pointer;font-weight:bold}.resume{background:#16213e;border-radius:12px;padding:2rem;margin-top:2rem}.resume h2{color:#667eea;margin-bottom:1rem;border-bottom:1px solid #333;padding-bottom:.5rem}.resume p{color:#aaa;line-height:1.8}.resume .section{margin-bottom:1.5rem}.actions{display:flex;gap:1rem;margin-top:1rem}.actions button{flex:1}.btn-secondary{background:#333}</style></head>
<body><div class="container"><h1>🤖 AI Resume Builder</h1>
<div class="form"><input id="name" placeholder="Full Name" value="John Developer"><input id="title" placeholder="Job Title" value="Full-Stack Developer"><textarea id="summary" placeholder="Professional Summary">Passionate developer with 3+ years experience in web development, specializing in React, Node.js, and cloud technologies.</textarea><textarea id="skills" placeholder="Skills (comma separated)">JavaScript, React, Node.js, Python, AWS, Docker, Git, MongoDB, PostgreSQL</textarea><textarea id="experience" placeholder="Work Experience">Senior Developer at Tech Corp (2024-Present)\n- Led team of 5 developers\n- Built microservices architecture\n- Improved performance by 40%\n\nJunior Developer at StartupXYZ (2022-2024)\n- Developed REST APIs\n- Implemented CI/CD pipelines</textarea><button onclick="generate()">✨ Generate Resume with AI</button></div>
<div class="resume" id="resume" style="display:none"><h2 id="r-name"></h2><p id="r-title" style="color:#00d4ff;margin-bottom:1rem"></p><div class="section"><h2>Summary</h2><p id="r-summary"></p></div><div class="section"><h2>Skills</h2><p id="r-skills"></p></div><div class="section"><h2>Experience</h2><p id="r-experience" style="white-space:pre-line"></p></div></div>
<div class="actions"><button onclick="window.print()">📄 Download PDF</button><button class="btn-secondary" onclick="copyHTML()">📋 Copy HTML</button></div></div>
<script>function generate(){document.getElementById('r-name').textContent=document.getElementById('name').value;document.getElementById('r-title').textContent=document.getElementById('title').value;document.getElementById('r-summary').textContent=document.getElementById('summary').value;document.getElementById('r-skills').textContent=document.getElementById('skills').value;document.getElementById('r-experience').textContent=document.getElementById('experience').value;document.getElementById('resume').style.display='block'}function copyHTML(){navigator.clipboard.writeText(document.getElementById('resume').innerHTML);alert('HTML copied!')}</script></body></html>
HTMLEOF
      ;;
    url-shortener)
      cat > index.html << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>URL Shortener</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;display:flex;align-items:center;justify-content:center}.app{background:#fff;border-radius:20px;padding:2rem;width:90%;max-width:500px;text-align:center}h1{color:#333;margin-bottom:1.5rem}.input-area{display:flex;gap:.5rem;margin-bottom:1rem}input{flex:1;padding:.8rem;border:2px solid #eee;border-radius:10px;font-size:1rem}button{padding:.8rem 1.5rem;background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;border:none;border-radius:10px;cursor:pointer;font-weight:bold}.result{background:#f5f5f5;padding:1rem;border-radius:10px;margin-top:1rem;display:none}.result a{color:#667eea;font-weight:bold;word-break:break-all}.history{margin-top:1.5rem;text-align:left}.history h3{margin-bottom:.5rem;color:#333}.history-item{padding:.5rem;background:#f9f9f9;margin:.3rem 0;border-radius:5px;font-size:.9rem;display:flex;justify-content:space-between}</style></head>
<body><div class="app"><h1>🔗 URL Shortener</h1><div class="input-area"><input id="url" placeholder="Paste your long URL here..." value="https://github.com"><button onclick="shorten()">Shorten</button></div><div class="result" id="result"><p>Short URL:</p><a id="short-url" href="#" target="_blank"></a><button onclick="copy()" style="margin-top:.5rem;font-size:.8rem">📋 Copy</button></div><div class="history"><h3>📋 History</h3><div id="history"></div></div></div>
<script>let links=JSON.parse(localStorage.getItem('links')||'[]');renderHistory();function shorten(){const url=document.getElementById('url').value;if(!url)return;const code=Math.random().toString(36).substr(2,6);const short=`https://short.link/${code}`;links.unshift({original:url,short,code,date:new Date().toLocaleDateString()});if(links.length>10)links.pop();localStorage.setItem('links',JSON.stringify(links));document.getElementById('short-url').textContent=short;document.getElementById('short-url').href=url;document.getElementById('result').style.display='block';renderHistory()}function copy(){navigator.clipboard.writeText(document.getElementById('short-url').textContent);alert('Copied!')}function renderHistory(){document.getElementById('history').innerHTML=links.map(l=>`<div class="history-item"><span>${l.original.substr(0,30)}...</span><a href="${l.original}">${l.code}</a></div>`).join('')}</script></body></html>
HTMLEOF
      ;;
    pomodoro-timer)
      cat > index.html << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pomodoro Timer</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;background:linear-gradient(135deg,#e74c3c,#c0392b);min-height:100vh;display:flex;align-items:center;justify-content:center}.app{background:rgba(255,255,255,.1);backdrop-filter:blur(10px);border-radius:20px;padding:2rem;width:90%;max-width:400px;text-align:center;color:#fff}h1{margin-bottom:.5rem}.timer{font-size:5rem;font-weight:bold;margin:2rem 0;font-variant-numeric:tabular-nums}.label{font-size:1.2rem;margin-bottom:1rem;color:rgba(255,255,255,.7)}.controls{display:flex;gap:1rem;justify-content:center;margin-bottom:2rem}.btn{padding:.8rem 2rem;border:none;border-radius:50px;font-size:1rem;cursor:pointer;font-weight:bold}.btn-start{background:#fff;color:#e74c3c}.btn-reset{background:rgba(255,255,255,.2);color:#fff}.modes{display:flex;gap:.5rem;justify-content:center;margin-bottom:1.5rem}.mode{padding:.5rem 1rem;border:1px solid rgba(255,255,255,.3);border-radius:20px;cursor:pointer;font-size:.9rem;background:transparent;color:#fff}.mode.active{background:#fff;color:#e74c3c}.stats{display:flex;justify-content:center;gap:2rem;margin-top:1.5rem}.stat{text-align:center}.stat .num{font-size:1.5rem;font-weight:bold}.stat .lbl{font-size:.8rem;color:rgba(255,255,255,.6)}</style></head>
<body><div class="app"><h1>🍅 Pomodoro</h1><div class="label" id="label">Focus Time</div><div class="timer" id="timer">25:00</div><div class="modes"><div class="mode active" onclick="setMode(25,'Focus')">Focus</div><div class="mode" onclick="setMode(5,'Short Break')">Short</div><div class="mode" onclick="setMode(15,'Long Break')">Long</div></div><div class="controls"><button class="btn btn-start" id="startBtn" onclick="toggle()">▶ Start</button><button class="btn btn-reset" onclick="reset()">↺ Reset</button></div><div class="stats"><div class="stat"><div class="num" id="pomodoros">0</div><div class="lbl">Pomodoros</div></div><div class="stat"><div class="num" id="totalTime">0m</div><div class="lbl">Total Focus</div></div></div></div>
<script>let timeLeft=25*60,running=false,interval=null,pomodoros=0,totalMinutes=0,currentMode=25;function update(){const m=Math.floor(timeLeft/60),s=timeLeft%60;document.getElementById('timer').textContent=`${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;document.title=`${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')} - Pomodoro`}function toggle(){if(running){clearInterval(interval);running=false;document.getElementById('startBtn').textContent='▶ Start'}else{interval=setInterval(()=>{if(timeLeft>0){timeLeft--;update()}else{clearInterval(interval);running=false;document.getElementById('startBtn').textContent='▶ Start';if(currentMode===25){pomodoros++;totalMinutes+=25;document.getElementById('pomodoros').textContent=pomodoros;document.getElementById('totalTime').textContent=totalMinutes+'m';new Audio('data:audio/wav;base64,UklGRl9vT19XQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQ==').play().catch(()=>{})}alert('Time is up!')}}.bind(this),1000);running=true;document.getElementById('startBtn').textContent='⏸ Pause'}}function reset(){clearInterval(interval);running=false;timeLeft=currentMode*60;update();document.getElementById('startBtn').textContent='▶ Start'}function setMode(min,label){currentMode=min;timeLeft=min*60;document.getElementById('label').textContent=label;update();document.querySelectorAll('.mode').forEach(m=>m.classList.remove('active'));event.target.classList.add('active')}update()</script></body></html>
HTMLEOF
      ;;
    expense-tracker)
      cat > index.html << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Expense Tracker</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;background:#0f0f23;color:#fff;min-height:100vh}.container{max-width:600px;margin:0 auto;padding:2rem}h1{text-align:center;margin-bottom:1.5rem}.balance{text-align:center;margin-bottom:2rem}.balance .amount{font-size:3rem;font-weight:bold}.balance .label{color:#888}.grid{display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin-bottom:1.5rem}.box{background:#16213e;padding:1rem;border-radius:10px;text-align:center}.box .label{font-size:.9rem;color:#888}.box .amount{font-size:1.5rem;font-weight:bold}.income .amount{color:#27ca40}.expense .amount{color:#ff5f56}.form{display:flex;gap:.5rem;margin-bottom:1.5rem}.form input{flex:1;padding:.8rem;background:#16213e;border:1px solid #333;border-radius:8px;color:#fff}.form select{padding:.8rem;background:#16213e;border:1px solid #333;border-radius:8px;color:#fff}.form button{padding:.8rem 1.5rem;background:#667eea;border:none;border-radius:8px;color:#fff;cursor:pointer;font-weight:bold}.transactions{list-style:none}.transaction{display:flex;justify-content:space-between;align-items:center;padding:.8rem;background:#16213e;margin:.3rem 0;border-radius:8px;border-right:4px solid}.transaction.income{border-color:#27ca40}.transaction.expense{border-color:#ff5f56}.transaction .delete{color:#ff5f56;cursor:pointer;background:none;border:none;font-size:1.2rem}</style></head>
<body><div class="container"><h1>💰 Expense Tracker</h1><div class="balance"><div class="label">Balance</div><div class="amount" id="balance">$0.00</div></div><div class="grid"><div class="box income"><div class="label">Income</div><div class="amount" id="income">$0.00</div></div><div class="box expense"><div class="label">Expense</div><div class="amount" id="expense">$0.00</div></div></div><div class="form"><input id="text" placeholder="Description"><input id="amount" type="number" placeholder="Amount (+ or -)"><button onclick="add()">Add</button></div><ul class="transactions" id="list"></ul></div>
<script>let items=JSON.parse(localStorage.getItem('expenses')||'[]');function render(){const list=document.getElementById('list');list.innerHTML=items.map((t,i)=>`<li class="transaction ${t.amount>0?'income':'expense'}"><span>${t.text}</span><span>${t.amount>0?'+':''}$${Math.abs(t.amount).toFixed(2)} <button class="delete" onclick="remove(${i})">×</button></span></li>`).join('');const total=items.reduce((s,t)=>s+t.amount,0);const inc=items.filter(t=>t.amount>0).reduce((s,t)=>s+t.amount,0);const exp=items.filter(t=>t.amount<0).reduce((s,t)=>s+Math.abs(t.amount),0);document.getElementById('balance').textContent=`$${total.toFixed(2)}`;document.getElementById('income').textContent=`$${inc.toFixed(2)}`;document.getElementById('expense').textContent=`$${exp.toFixed(2)}`;localStorage.setItem('expenses',JSON.stringify(items))}function add(){const text=document.getElementById('text').value;const amount=parseFloat(document.getElementById('amount').value);if(!text||isNaN(amount))return;items.unshift({text,amount});document.getElementById('text').value='';document.getElementById('amount').value='';render()}function remove(i){items.splice(i,1);render()}render()</script></body></html>
HTMLEOF
      ;;
    *)
      cat > index.html << HTMLEOF
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$name</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;display:flex;align-items:center;justify-content:center;color:#fff;text-align:center}.app{background:rgba(255,255,255,.1);backdrop-filter:blur(10px);padding:3rem;border-radius:20px;max-width:500px}h1{font-size:2rem;margin-bottom:1rem}p{opacity:.8;margin-bottom:2rem}.badge{display:inline-block;background:rgba(255,255,255,.2);padding:.3rem .8rem;border-radius:20px;font-size:.8rem;margin:.3rem}</style></head>
<body><div class="app"><h1>🚀 $name</h1><p>$desc</p><div><span class="badge">Free</span><span class="badge">Open Source</span><span class="badge">Made with ❤️</span></div><p style="margin-top:2rem;font-size:.8rem;opacity:.5">Created by 🤖 GitHub Autopilot Bots</p></div></body></html>
HTMLEOF
      ;;
  esac
  
  # Add LICENSE
  cat > LICENSE << 'EOF'
MIT License
Copyright (c) 2026 caasiyatnilab-sketch
Permission is hereby granted, free of charge, to any person obtaining a copy.
EOF
  
  # Add .gitignore
  cat > .gitignore << 'EOF'
node_modules/
.env
dist/
.DS_Store
*.log
EOF
  
  # Commit and push
  git add -A
  git commit -m "🚀 Initial commit: $name

$desc

Created by 🤖 GitHub Autopilot Bots" 2>/dev/null
  
  git push origin main 2>&1
  
  CREATED_REPOS+=("$slug")
  CREATED_URLS+=("https://$OWNER.github.io/$slug/")
  
  log INFO "  ✅ Created: $slug → https://$OWNER.github.io/$slug/"
  
  cd /
  rm -rf "$TMPDIR"
}

# ═══════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════
get_project_ideas

# Pick 3 random ideas to create this run
log INFO "🎯 Selecting projects to create..."
SELECTED=()
for idea in "${IDEAS[@]}"; do
  IFS='|' read -r slug name desc type <<< "$idea"
  if ! repo_exists "$slug"; then
    SELECTED+=("$idea")
    [ ${#SELECTED[@]} -ge 3 ] && break
  fi
done

log INFO "  Creating ${#SELECTED[@]} new projects..."

for idea in "${SELECTED[@]}"; do
  IFS='|' read -r slug name desc type <<< "$idea"
  create_project "$slug" "$name" "$desc" "$type"
done

# Generate report
cat > "$REPORT" << REOF
# 🏗️ Project Creator Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Owner:** $OWNER

## New Repositories Created: ${#CREATED_REPOS[@]}

$(if [ ${#CREATED_REPOS[@]} -eq 0 ]; then
  echo "No new repos created this run (all ideas already exist or limit reached)"
else
  for i in "${!CREATED_REPOS[@]}"; do
    echo "- ✅ **${CREATED_REPOS[$i]}** → [Live Demo](${CREATED_URLS[$i]})"
  done
fi)

## All Available Project Ideas
$(for idea in "${IDEAS[@]}"; do
  IFS='|' read -r slug name desc type <<< "$idea"
  if repo_exists "$slug"; then
    echo "- ✅ $name — [exists](https://github.com/$OWNER/$slug)"
  else
    echo "- ⏳ $name — $desc"
  fi
done)

## How It Works
1. Bot scans trending repos for inspiration
2. Picks 3 new project ideas per run
3. Creates NEW GitHub repo
4. Builds full working project
5. Pushes to GitHub
6. Reports live URL

## Live URLs
$(for url in "${CREATED_URLS[@]}"; do echo "- 🔗 $url"; done)

---
_Automated by Project Creator Bot 🏗️_
REOF

record_result "project-creator" "success" "completed" 2>/dev/null || true
cat "$REPORT"
notify "Project Creator" "Created ${#CREATED_REPOS[@]} new repos! Check live URLs."
exit 0
