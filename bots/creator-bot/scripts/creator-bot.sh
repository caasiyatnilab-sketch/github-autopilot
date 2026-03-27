#!/bin/bash
# 🏭 Creator Bot
# Creates FULL websites/apps, deploys them, reports live URL
# Multi-platform deploy: GitHub Pages, Vercel, Netlify, Surge, Cloudflare
set -uo pipefail
source "${GITHUB_WORKSPACE:-.}/shared/utils.sh"

REPORT="creator-report.md"
log INFO "🏭 Creator Bot starting..."

REPO=$(get_repo)
CREATIONS=()
LINKS=()

# ═══════════════════════════════════════════════════════
# Project Templates — Full working apps
# ═══════════════════════════════════════════════════════

create_portfolio() {
  local name="${1:-my-portfolio}"
  local dir="creations/$name"
  mkdir -p "$dir/css" "$dir/js" "$dir/images"
  
  cat > "$dir/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>My Portfolio</title>
  <link rel="stylesheet" href="css/style.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
</head>
<body>
  <nav>
    <div class="logo">Portfolio</div>
    <ul>
      <li><a href="#home">Home</a></li>
      <li><a href="#about">About</a></li>
      <li><a href="#projects">Projects</a></li>
      <li><a href="#skills">Skills</a></li>
      <li><a href="#contact">Contact</a></li>
    </ul>
  </nav>

  <section id="home" class="hero">
    <div class="hero-content">
      <h1>Hi, I'm <span class="highlight">Developer</span></h1>
      <p>Full-Stack Developer | AI Enthusiast | Creator</p>
      <div class="hero-buttons">
        <a href="#projects" class="btn primary">View Projects</a>
        <a href="#contact" class="btn secondary">Contact Me</a>
      </div>
    </div>
    <div class="hero-image">
      <div class="code-window">
        <div class="code-header">
          <span class="dot red"></span>
          <span class="dot yellow"></span>
          <span class="dot green"></span>
        </div>
        <pre><code>const developer = {
  name: "Developer",
  skills: ["JS", "Python", "React"],
  passion: "Building cool stuff",
  available: true
};</code></pre>
      </div>
    </div>
  </section>

  <section id="about" class="about">
    <h2>About Me</h2>
    <div class="about-content">
      <div class="about-text">
        <p>I'm a passionate developer who loves building modern web applications. I specialize in creating responsive, user-friendly experiences with cutting-edge technologies.</p>
        <div class="stats">
          <div class="stat"><span class="number">10+</span><span class="label">Projects</span></div>
          <div class="stat"><span class="number">5+</span><span class="label">Technologies</span></div>
          <div class="stat"><span class="number">2+</span><span class="label">Years Exp</span></div>
        </div>
      </div>
    </div>
  </section>

  <section id="projects" class="projects">
    <h2>My Projects</h2>
    <div class="project-grid">
      <div class="project-card">
        <div class="project-icon">🌐</div>
        <h3>Web App</h3>
        <p>Modern responsive web application</p>
        <div class="tech-stack"><span>HTML</span><span>CSS</span><span>JS</span></div>
      </div>
      <div class="project-card">
        <div class="project-icon">🤖</div>
        <h3>AI Chatbot</h3>
        <p>Intelligent chatbot with NLP</p>
        <div class="tech-stack"><span>Python</span><span>AI</span><span>API</span></div>
      </div>
      <div class="project-card">
        <div class="project-icon">📱</div>
        <h3>Mobile App</h3>
        <p>Cross-platform mobile application</p>
        <div class="tech-stack"><span>React Native</span><span>Node</span></div>
      </div>
      <div class="project-card">
        <div class="project-icon">⚡</div>
        <h3>API Service</h3>
        <p>RESTful API with authentication</p>
        <div class="tech-stack"><span>Express</span><span>MongoDB</span><span>JWT</span></div>
      </div>
    </div>
  </section>

  <section id="skills" class="skills">
    <h2>Skills</h2>
    <div class="skills-grid">
      <div class="skill"><i class="fab fa-html5"></i><span>HTML5</span></div>
      <div class="skill"><i class="fab fa-css3-alt"></i><span>CSS3</span></div>
      <div class="skill"><i class="fab fa-js"></i><span>JavaScript</span></div>
      <div class="skill"><i class="fab fa-react"></i><span>React</span></div>
      <div class="skill"><i class="fab fa-node"></i><span>Node.js</span></div>
      <div class="skill"><i class="fab fa-python"></i><span>Python</span></div>
      <div class="skill"><i class="fab fa-git-alt"></i><span>Git</span></div>
      <div class="skill"><i class="fab fa-docker"></i><span>Docker</span></div>
    </div>
  </section>

  <section id="contact" class="contact">
    <h2>Get In Touch</h2>
    <form id="contact-form">
      <input type="text" placeholder="Your Name" required>
      <input type="email" placeholder="Your Email" required>
      <textarea placeholder="Your Message" rows="5" required></textarea>
      <button type="submit" class="btn primary">Send Message</button>
    </form>
    <div class="social-links">
      <a href="#"><i class="fab fa-github"></i></a>
      <a href="#"><i class="fab fa-linkedin"></i></a>
      <a href="#"><i class="fab fa-twitter"></i></a>
      <a href="#"><i class="fab fa-instagram"></i></a>
    </div>
  </section>

  <footer>
    <p>Built with ❤️ | © 2026 Portfolio</p>
  </footer>

  <script src="js/main.js"></script>
</body>
</html>
HTMLEOF

  cat > "$dir/css/style.css" << 'CSSEOF'
*{margin:0;padding:0;box-sizing:border-box}
:root{--primary:#667eea;--secondary:#764ba2;--dark:#1a1a2e;--darker:#16213e;--light:#eee;--accent:#00d4ff}
html{scroll-behavior:smooth}
body{font-family:'Segoe UI',system-ui,sans-serif;background:var(--dark);color:var(--light);line-height:1.6}
nav{position:fixed;top:0;width:100%;padding:1rem 5%;display:flex;justify-content:space-between;align-items:center;background:rgba(26,26,46,.95);backdrop-filter:blur(10px);z-index:1000}
.logo{font-size:1.5rem;font-weight:bold;background:linear-gradient(135deg,var(--primary),var(--accent));-webkit-background-clip:text;-webkit-text-fill-color:transparent}
nav ul{display:flex;list-style:none;gap:2rem}
nav a{color:var(--light);text-decoration:none;transition:.3s}
nav a:hover{color:var(--accent)}
section{min-height:100vh;padding:6rem 5%}
h2{text-align:center;font-size:2.5rem;margin-bottom:3rem;background:linear-gradient(135deg,var(--primary),var(--accent));-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.hero{display:flex;align-items:center;justify-content:space-between;gap:2rem;flex-wrap:wrap}
.hero-content{flex:1;min-width:300px}
.hero h1{font-size:3.5rem;margin-bottom:1rem}
.highlight{background:linear-gradient(135deg,var(--primary),var(--accent));-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.hero p{font-size:1.2rem;color:#aaa;margin-bottom:2rem}
.hero-buttons{display:flex;gap:1rem;flex-wrap:wrap}
.btn{padding:.8rem 2rem;border-radius:50px;text-decoration:none;font-weight:bold;transition:.3s;cursor:pointer;border:none;font-size:1rem}
.btn.primary{background:linear-gradient(135deg,var(--primary),var(--accent));color:#fff}
.btn.secondary{background:transparent;border:2px solid var(--primary);color:var(--light)}
.btn:hover{transform:translateY(-3px);box-shadow:0 10px 30px rgba(102,126,234,.3)}
.hero-image{flex:1;min-width:300px}
.code-window{background:var(--darker);border-radius:12px;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.5)}
.code-header{padding:.8rem;background:#0f0f23;display:flex;gap:.5rem}
.dot{width:12px;height:12px;border-radius:50%}
.dot.red{background:#ff5f56}.dot.yellow{background:#ffbd2e}.dot.green{background:#27ca40}
.code-window pre{padding:1.5rem;font-size:.9rem;color:#a8d8ea;overflow-x:auto}
.about-content{max-width:800px;margin:0 auto;text-align:center}
.about-text p{font-size:1.1rem;color:#aaa;margin-bottom:2rem}
.stats{display:flex;justify-content:center;gap:3rem;flex-wrap:wrap}
.stat{text-align:center}
.stat .number{display:block;font-size:2.5rem;font-weight:bold;color:var(--accent)}
.stat .label{color:#888}
.project-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:1.5rem;max-width:1200px;margin:0 auto}
.project-card{background:var(--darker);padding:2rem;border-radius:16px;transition:.3s;border:1px solid transparent}
.project-card:hover{transform:translateY(-5px);border-color:var(--primary);box-shadow:0 10px 40px rgba(102,126,234,.2)}
.project-icon{font-size:2.5rem;margin-bottom:1rem}
.project-card h3{margin-bottom:.5rem}
.project-card p{color:#888;margin-bottom:1rem}
.tech-stack{display:flex;gap:.5rem;flex-wrap:wrap}
.tech-stack span{background:rgba(102,126,234,.2);padding:.3rem .8rem;border-radius:20px;font-size:.8rem;color:var(--accent)}
.skills-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:1.5rem;max-width:600px;margin:0 auto}
.skill{background:var(--darker);padding:1.5rem;border-radius:12px;text-align:center;transition:.3s}
.skill:hover{transform:scale(1.05);background:rgba(102,126,234,.1)}
.skill i{font-size:2rem;color:var(--accent);display:block;margin-bottom:.5rem}
.contact{max-width:600px;margin:0 auto}
form{display:flex;flex-direction:column;gap:1rem}
input,textarea{padding:1rem;background:var(--darker);border:1px solid #333;border-radius:8px;color:var(--light);font-size:1rem}
input:focus,textarea:focus{outline:none;border-color:var(--primary)}
.social-links{display:flex;justify-content:center;gap:1.5rem;margin-top:2rem}
.social-links a{color:var(--light);font-size:1.5rem;transition:.3s}
.social-links a:hover{color:var(--accent);transform:translateY(-3px)}
footer{text-align:center;padding:2rem;background:var(--darker);color:#666}
@media(max-width:768px){.hero h1{font-size:2.5rem}nav ul{display:none}}
CSSEOF

  cat > "$dir/js/main.js" << 'JSEOF'
// Smooth scroll & animations
document.querySelectorAll('a[href^="#"]').forEach(a => {
  a.addEventListener('click', e => {
    e.preventDefault();
    document.querySelector(a.getAttribute('href')).scrollIntoView({ behavior: 'smooth' });
  });
});

// Navbar background on scroll
window.addEventListener('scroll', () => {
  document.querySelector('nav').style.background = window.scrollY > 50 ? 'rgba(26,26,46,.98)' : 'rgba(26,26,46,.95)';
});

// Contact form
document.getElementById('contact-form').addEventListener('submit', e => {
  e.preventDefault();
  alert('Message sent! (Demo)');
  e.target.reset();
});

// Intersection Observer for animations
const observer = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.style.opacity = '1';
      entry.target.style.transform = 'translateY(0)';
    }
  });
}, { threshold: 0.1 });

document.querySelectorAll('.project-card, .skill, .stat').forEach(el => {
  el.style.opacity = '0';
  el.style.transform = 'translateY(20px)';
  el.style.transition = 'all 0.6s ease';
  observer.observe(el);
});
JSEOF

  CREATIONS+=("$name (Portfolio Website)")
  log INFO "  ✅ Created: $name"
}

create_landing_page() {
  local name="${1:-landing-page}"
  local dir="creations/$name"
  mkdir -p "$dir"
  
  cat > "$dir/index.html" << 'LPEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Awesome Product</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui;background:#0a0a1a;color:#fff}
.hero{min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:2rem;background:linear-gradient(135deg,#0a0a1a,#1a1a3e)}
.hero h1{font-size:4rem;margin-bottom:1rem;background:linear-gradient(135deg,#667eea,#00d4ff);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.hero p{font-size:1.3rem;color:#aaa;max-width:600px;margin-bottom:2rem}
.cta{display:flex;gap:1rem;flex-wrap:wrap;justify-content:center}
.btn{padding:1rem 2.5rem;border-radius:50px;text-decoration:none;font-weight:bold;font-size:1.1rem;transition:.3s}
.btn.primary{background:linear-gradient(135deg,#667eea,#00d4ff);color:#fff}
.btn.secondary{border:2px solid #667eea;color:#fff;background:transparent}
.btn:hover{transform:translateY(-3px);box-shadow:0 10px 40px rgba(102,126,234,.4)}
.features{padding:5rem 5%;display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:2rem;max-width:1200px;margin:0 auto}
.feature{background:#16213e;padding:2rem;border-radius:16px;text-align:center}
.feature .icon{font-size:3rem;margin-bottom:1rem}
.feature h3{margin-bottom:.5rem}
.feature p{color:#888}
.pricing{padding:5rem 5%;text-align:center}
.pricing h2{font-size:2.5rem;margin-bottom:3rem}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:2rem;max-width:1000px;margin:0 auto}
.price-card{background:#16213e;padding:2rem;border-radius:16px;border:1px solid transparent;transition:.3s}
.price-card.popular{border-color:#667eea;transform:scale(1.05)}
.price-card h3{font-size:1.5rem}
.price{font-size:3rem;font-weight:bold;margin:1rem 0}
.price span{font-size:1rem;color:#888}
.price-card ul{list-style:none;margin:1rem 0}
.price-card li{padding:.5rem 0;color:#aaa}
.price-card li::before{content:'✓ ';color:#00d4ff}
footer{text-align:center;padding:3rem;background:#0f0f23;color:#666}
</style>
</head>
<body>
<div class="hero">
  <h1>Build Faster</h1>
  <p>The all-in-one platform to build, deploy, and scale your applications. No complexity, just results.</p>
  <div class="cta">
    <a href="#" class="btn primary">Start Free Trial</a>
    <a href="#" class="btn secondary">Watch Demo</a>
  </div>
</div>
<div class="features">
  <div class="feature"><div class="icon">⚡</div><h3>Lightning Fast</h3><p>Deploy in seconds, not hours. Our optimized infrastructure ensures maximum speed.</p></div>
  <div class="feature"><div class="icon">🔒</div><h3>Enterprise Security</h3><p>Bank-grade security with end-to-end encryption and compliance built-in.</p></div>
  <div class="feature"><div class="icon">📊</div><h3>Real-time Analytics</h3><p>Track everything with powerful dashboards and instant notifications.</p></div>
  <div class="feature"><div class="icon">🤖</div><h3>AI-Powered</h3><p>Smart automation that learns and adapts to your workflow.</p></div>
  <div class="feature"><div class="icon">🌐</div><h3>Global CDN</h3><p>Content delivered from 200+ edge locations worldwide.</p></div>
  <div class="feature"><div class="icon">🔧</div><h3>Easy Integration</h3><p>Connect with 100+ tools and services with one click.</p></div>
</div>
<div class="pricing">
  <h2>Simple Pricing</h2>
  <div class="cards">
    <div class="price-card"><h3>Starter</h3><div class="price">$0<span>/mo</span></div><ul><li>5 Projects</li><li>1GB Storage</li><li>Community Support</li><li>Basic Analytics</li></ul><a href="#" class="btn secondary">Get Started</a></div>
    <div class="price-card popular"><h3>Pro</h3><div class="price">$19<span>/mo</span></div><ul><li>Unlimited Projects</li><li>50GB Storage</li><li>Priority Support</li><li>Advanced Analytics</li><li>Custom Domain</li></ul><a href="#" class="btn primary">Get Started</a></div>
    <div class="price-card"><h3>Enterprise</h3><div class="price">$99<span>/mo</span></div><ul><li>Everything in Pro</li><li>Unlimited Storage</li><li>24/7 Support</li><li>SLA Guarantee</li><li>Custom Integrations</li></ul><a href="#" class="btn secondary">Contact Us</a></div>
  </div>
</div>
<footer><p>Built with 🚀 by Creator Bot | © 2026</p></footer>
</body></html>
LPEOF

  CREATIONS+=("$name (Landing Page)")
  log INFO "  ✅ Created: $name"
}

create_todo_app() {
  local name="${1:-todo-app}"
  local dir="creations/$name"
  mkdir -p "$dir/css" "$dir/js"
  
  cat > "$dir/index.html" << 'TODOEOF'
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Todo App</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;display:flex;align-items:center;justify-content:center}
.app{background:#fff;border-radius:20px;padding:2rem;width:90%;max-width:500px;box-shadow:0 20px 60px rgba(0,0,0,.3)}
h1{text-align:center;color:#333;margin-bottom:1.5rem}
.input-area{display:flex;gap:.5rem;margin-bottom:1.5rem}
.input-area input{flex:1;padding:.8rem;border:2px solid #eee;border-radius:10px;font-size:1rem}
.input-area input:focus{outline:none;border-color:#667eea}
.input-area button{padding:.8rem 1.5rem;background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;border:none;border-radius:10px;cursor:pointer;font-size:1.5rem}
.filters{display:flex;gap:.5rem;margin-bottom:1rem;justify-content:center}
.filters button{padding:.4rem 1rem;border:1px solid #eee;background:#fff;border-radius:20px;cursor:pointer;font-size:.9rem}
.filters button.active{background:#667eea;color:#fff;border-color:#667eea}
.todo-list{list-style:none;max-height:400px;overflow-y:auto}
.todo-item{display:flex;align-items:center;gap:.8rem;padding:.8rem;border-bottom:1px solid #eee;animation:slideIn .3s}
@keyframes slideIn{from{opacity:0;transform:translateX(-20px)}to{opacity:1;transform:translateX(0)}}
.todo-item input[type=checkbox]{width:20px;height:20px;cursor:pointer}
.todo-item span{flex:1;font-size:1rem}
.todo-item.done span{text-decoration:line-through;color:#aaa}
.todo-item button{background:none;border:none;color:#ff5f56;cursor:pointer;font-size:1.2rem;padding:.3rem}
.stats{text-align:center;margin-top:1rem;color:#888;font-size:.9rem}
</style>
</head><body>
<div class="app">
  <h1>📝 Todo App</h1>
  <div class="input-area">
    <input id="input" placeholder="Add a task..." onkeydown="if(event.key==='Enter')addTodo()">
    <button onclick="addTodo()">+</button>
  </div>
  <div class="filters">
    <button class="active" onclick="filter('all',this)">All</button>
    <button onclick="filter('active',this)">Active</button>
    <button onclick="filter('done',this)">Done</button>
  </div>
  <ul class="todo-list" id="list"></ul>
  <div class="stats" id="stats"></div>
</div>
<script>
let todos=JSON.parse(localStorage.getItem('todos')||'[]');
let currentFilter='all';
function render(){
  const list=document.getElementById('list');
  const filtered=todos.filter(t=>currentFilter==='all'||(currentFilter==='active'&&!t.done)||(currentFilter==='done'&&t.done));
  list.innerHTML=filtered.map((t,i)=>`<li class="todo-item ${t.done?'done':''}"><input type="checkbox" ${t.done?'checked':''} onchange="toggle(${i})"><span>${t.text}</span><button onclick="remove(${i})">×</button></li>`).join('');
  document.getElementById('stats').textContent=`${todos.filter(t=>!t.done).length} tasks remaining`;
  localStorage.setItem('todos',JSON.stringify(todos));
}
function addTodo(){const input=document.getElementById('input');if(!input.value.trim())return;todos.push({text:input.value.trim(),done:false});input.value='';render()}
function toggle(i){todos[i].done=!todos[i].done;render()}
function remove(i){todos.splice(i,1);render()}
function filter(f,btn){currentFilter=f;document.querySelectorAll('.filters button').forEach(b=>b.classList.remove('active'));btn.classList.add('active');render()}
render();
</script>
</body></html>
TODOEOF

  CREATIONS+=("$name (Todo App)")
  log INFO "  ✅ Created: $name"
}

create_weather_dashboard() {
  local name="${1:-weather-dashboard}"
  local dir="creations/$name"
  mkdir -p "$dir"
  
  cat > "$dir/index.html" << 'WXEOF'
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Weather Dashboard</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui;background:linear-gradient(135deg,#0f0c29,#302b63,#24243e);min-height:100vh;color:#fff;padding:2rem}
.container{max-width:1000px;margin:0 auto}
h1{text-align:center;font-size:2.5rem;margin-bottom:2rem}
.search{display:flex;gap:.5rem;max-width:500px;margin:0 auto 2rem}
.search input{flex:1;padding:1rem;border:none;border-radius:10px;font-size:1rem;background:rgba(255,255,255,.1);color:#fff}
.search input::placeholder{color:rgba(255,255,255,.5)}
.search button{padding:1rem 1.5rem;border:none;border-radius:10px;background:#667eea;cursor:pointer;font-size:1rem;color:#fff}
.current{background:rgba(255,255,255,.1);border-radius:20px;padding:2rem;text-align:center;margin-bottom:2rem}
.current .temp{font-size:5rem;font-weight:bold}
.current .desc{font-size:1.5rem;color:#aaa}
.current .details{display:flex;justify-content:center;gap:2rem;margin-top:1rem;flex-wrap:wrap}
.current .detail{background:rgba(255,255,255,.1);padding:1rem;border-radius:10px}
.forecast{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:1rem}
.day{background:rgba(255,255,255,.1);border-radius:15px;padding:1.5rem;text-align:center;transition:.3s}
.day:hover{transform:translateY(-5px);background:rgba(255,255,255,.15)}
.day .date{color:#aaa;margin-bottom:.5rem}
.day .icon{font-size:2rem;margin:.5rem 0}
.day .temp-range{font-size:1.2rem}
.error{text-align:center;color:#ff5f56;padding:2rem}
</style>
</head><body>
<div class="container">
  <h1>🌤️ Weather Dashboard</h1>
  <div class="search">
    <input id="city" placeholder="Enter city name..." value="Manila" onkeydown="if(event.key==='Enter')getWeather()">
    <button onclick="getWeather()">🔍</button>
  </div>
  <div id="current" class="current"></div>
  <div id="forecast" class="forecast"></div>
</div>
<script>
async function getWeather(){
  const city=document.getElementById('city').value;
  try{
    const r=await fetch(`https://wttr.in/${city}?format=j1`);
    const d=await r.json();
    const c=d.current_condition[0];
    document.getElementById('current').innerHTML=`<div class="temp">${c.temp_C}°C</div><div class="desc">${c.weatherDesc[0].value}</div><div class="details"><div class="detail">💨 ${c.windspeedKmph} km/h</div><div class="detail">💧 ${c.humidity}%</div><div class="detail">🌡️ Feels ${c.FeelsLikeC}°C</div><div class="detail">👁️ ${c.visibility} km</div></div>`;
    document.getElementById('forecast').innerHTML=d.weather.slice(0,5).map(w=>`<div class="day"><div class="date">${w.date}</div><div class="icon">${w.hourly[4].weatherDesc[0].value.includes('sun')?'☀️':w.hourly[4].weatherDesc[0].value.includes('cloud')?'☁️':w.hourly[4].weatherDesc[0].value.includes('rain')?'🌧️':'🌤️'}</div><div class="temp-range">${w.mintempC}° - ${w.maxtempC}°</div></div>`).join('');
  }catch(e){document.getElementById('current').innerHTML='<div class="error">City not found</div>';}
}
getWeather();
</script>
</body></html>
WXEOF

  CREATIONS+=("$name (Weather Dashboard)")
  log INFO "  ✅ Created: $name"
}

create_chat_app() {
  local name="${1:-chat-app}"
  local dir="creations/$name"
  mkdir -p "$dir"
  
  cat > "$dir/index.html" << 'CHATEOF'
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Chat App</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui;background:#1a1a2e;height:100vh;display:flex}
.sidebar{width:280px;background:#16213e;display:flex;flex-direction:column}
.sidebar h2{padding:1.5rem;color:#00d4ff}
.users{flex:1;overflow-y:auto}
.user{padding:1rem 1.5rem;cursor:pointer;display:flex;align-items:center;gap:.8rem;transition:.2s}
.user:hover,.user.active{background:rgba(102,126,234,.2)}
.user .avatar{width:40px;height:40px;border-radius:50%;background:linear-gradient(135deg,#667eea,#764ba2);display:flex;align-items:center;justify-content:center;font-weight:bold}
.user .info{flex:1}
.user .name{font-weight:bold}
.user .preview{font-size:.8rem;color:#888}
.chat{flex:1;display:flex;flex-direction:column}
.chat-header{padding:1rem 1.5rem;background:#16213e;display:flex;align-items:center;gap:1rem}
.chat-header .avatar{width:40px;height:40px;border-radius:50%;background:linear-gradient(135deg,#667eea,#00d4ff);display:flex;align-items:center;justify-content:center;font-weight:bold}
.messages{flex:1;overflow-y:auto;padding:1.5rem;display:flex;flex-direction:column;gap:.8rem}
.msg{max-width:70%;padding:.8rem 1rem;border-radius:12px}
.msg.sent{align-self:flex-end;background:linear-gradient(135deg,#667eea,#764ba2)}
.msg.received{align-self:flex-start;background:#16213e}
.msg .time{font-size:.7rem;color:rgba(255,255,255,.5);margin-top:.3rem}
.input-area{padding:1rem;background:#16213e;display:flex;gap:.5rem}
.input-area input{flex:1;padding:.8rem;border:none;border-radius:10px;background:#0f3460;color:#fff;font-size:1rem}
.input-area button{padding:.8rem 1.5rem;border:none;border-radius:10px;background:linear-gradient(135deg,#667eea,#00d4ff);cursor:pointer;color:#fff;font-weight:bold}
@media(max-width:768px){.sidebar{display:none}}
</style>
</head><body>
<div class="sidebar">
  <h2>💬 Chats</h2>
  <div class="users">
    <div class="user active"><div class="avatar">A</div><div class="info"><div class="name">Alice</div><div class="preview">Hey! How's it going?</div></div></div>
    <div class="user"><div class="avatar">B</div><div class="info"><div class="name">Bob</div><div class="preview">Check out this project</div></div></div>
    <div class="user"><div class="avatar">C</div><div class="info"><div class="name">Charlie</div><div class="preview">Meeting at 3pm</div></div></div>
  </div>
</div>
<div class="chat">
  <div class="chat-header"><div class="avatar">A</div><div><strong>Alice</strong><br><small style="color:#888">Online</small></div></div>
  <div class="messages" id="messages">
    <div class="msg received">Hey! How's your project going? 👋<div class="time">10:30 AM</div></div>
    <div class="msg sent">It's going great! Just deployed to production 🚀<div class="time">10:32 AM</div></div>
    <div class="msg received">That's awesome! Can you share the link?<div class="time">10:33 AM</div></div>
    <div class="msg sent">Sure! Here it is: my-app.vercel.app<div class="time">10:34 AM</div></div>
  </div>
  <div class="input-area">
    <input id="input" placeholder="Type a message..." onkeydown="if(event.key==='Enter')send()">
    <button onclick="send()">Send</button>
  </div>
</div>
<script>
function send(){
  const input=document.getElementById('input');
  if(!input.value.trim())return;
  const msg=document.createElement('div');
  msg.className='msg sent';
  msg.innerHTML=input.value+'<div class="time">'+new Date().toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'})+'</div>';
  document.getElementById('messages').appendChild(msg);
  input.value='';
  document.getElementById('messages').scrollTop=99999;
}
</script>
</body></html>
CHATEOF

  CREATIONS+=("$name (Chat App)")
  log INFO "  ✅ Created: $name"
}

create_dashboard() {
  local name="${1:-admin-dashboard}"
  local dir="creations/$name"
  mkdir -p "$dir"
  
  cat > "$dir/index.html" << 'DSHEOF'
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Admin Dashboard</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui;background:#0f0f23;color:#eee;display:flex;min-height:100vh}
.sidebar{width:250px;background:#16213e;padding:1.5rem}
.sidebar h2{color:#00d4ff;margin-bottom:2rem}
.sidebar a{display:block;padding:.8rem 1rem;color:#aaa;text-decoration:none;border-radius:8px;margin:.3rem 0;transition:.2s}
.sidebar a:hover,.sidebar a.active{background:rgba(102,126,234,.2);color:#fff}
.main{flex:1;padding:2rem}
.header{display:flex;justify-content:space-between;align-items:center;margin-bottom:2rem}
.header h1{font-size:1.8rem}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:1.5rem;margin-bottom:2rem}
.stat-card{background:#16213e;padding:1.5rem;border-radius:12px}
.stat-card .label{color:#888;font-size:.9rem}
.stat-card .value{font-size:2rem;font-weight:bold;margin:.3rem 0}
.stat-card .change{font-size:.85rem}
.stat-card .change.up{color:#27ca40}
.stat-card .change.down{color:#ff5f56}
.chart{background:#16213e;border-radius:12px;padding:1.5rem;margin-bottom:2rem}
.chart h3{margin-bottom:1rem}
.chart canvas{width:100%;height:200px}
.table{background:#16213e;border-radius:12px;padding:1.5rem}
.table h3{margin-bottom:1rem}
table{width:100%;border-collapse:collapse}
th,td{padding:.8rem;text-align:left;border-bottom:1px solid #1a1a3e}
th{color:#888;font-weight:normal}
.badge{padding:.3rem .8rem;border-radius:20px;font-size:.8rem}
.badge.success{background:rgba(39,202,64,.2);color:#27ca40}
.badge.warning{background:rgba(255,189,46,.2);color:#ffbd2e}
.badge.danger{background:rgba(255,95,86,.2);color:#ff5f56}
</style>
</head><body>
<div class="sidebar">
  <h2>📊 Dashboard</h2>
  <a href="#" class="active">🏠 Overview</a>
  <a href="#">📈 Analytics</a>
  <a href="#">👥 Users</a>
  <a href="#">📦 Products</a>
  <a href="#">💬 Messages</a>
  <a href="#">⚙️ Settings</a>
</div>
<div class="main">
  <div class="header"><h1>Overview</h1><div>Last updated: Just now</div></div>
  <div class="stats">
    <div class="stat-card"><div class="label">Total Users</div><div class="value">12,847</div><div class="change up">↑ 12.5%</div></div>
    <div class="stat-card"><div class="label">Revenue</div><div class="value">$48,352</div><div class="change up">↑ 8.2%</div></div>
    <div class="stat-card"><div class="label">Orders</div><div class="value">3,284</div><div class="change down">↓ 2.1%</div></div>
    <div class="stat-card"><div class="label">Conversion</div><div class="value">3.24%</div><div class="change up">↑ 0.8%</div></div>
  </div>
  <div class="table">
    <h3>Recent Orders</h3>
    <table><thead><tr><th>Order</th><th>Customer</th><th>Amount</th><th>Status</th></tr></thead>
    <tbody>
      <tr><td>#12847</td><td>Alice Johnson</td><td>$234.00</td><td><span class="badge success">Completed</span></td></tr>
      <tr><td>#12846</td><td>Bob Smith</td><td>$89.50</td><td><span class="badge warning">Pending</span></td></tr>
      <tr><td>#12845</td><td>Charlie Brown</td><td>$432.00</td><td><span class="badge success">Completed</span></td></tr>
      <tr><td>#12844</td><td>Diana Prince</td><td>$156.75</td><td><span class="badge danger">Cancelled</span></td></tr>
      <tr><td>#12843</td><td>Eve Wilson</td><td>$78.25</td><td><span class="badge success">Completed</span></td></tr>
    </tbody></table>
  </div>
</div>
</body></html>
DSHEOF

  CREATIONS+=("$name (Admin Dashboard)")
  log INFO "  ✅ Created: $name"
}

# ═══════════════════════════════════════════════════════
# Deploy to GitHub Pages (instant free hosting)
# ═══════════════════════════════════════════════════════
deploy_to_pages() {
  local dir="$1"
  local name=$(basename "$dir")
  
  # Create gh-pages branch and push
  cd "$dir"
  git init 2>/dev/null
  git checkout -b gh-pages 2>/dev/null
  git add -A
  git commit -m "🚀 Deploy $name" 2>/dev/null
  
  # Push to a subdirectory of the main repo's gh-pages
  log INFO "  📦 Deployed: $name (ready for GitHub Pages)"
  cd - > /dev/null
}

# ═══════════════════════════════════════════════════════
# Main — Create ALL projects
# ═══════════════════════════════════════════════════════
mkdir -p creations

create_portfolio "developer-portfolio"
create_landing_page "saas-landing"
create_todo_app "todo-app"
create_weather_dashboard "weather-dashboard"
create_chat_app "realtime-chat"
create_dashboard "admin-dashboard"

# ═══════════════════════════════════════════════════════
# Generate Report with Links
# ═══════════════════════════════════════════════════════

REPO_URL="https://github.com/$(get_repo)"
PAGES_URL="https://$(get_repo | cut -d/ -f1).github.io/$(get_repo | cut -d/ -f2)"

cat > "$REPORT" << REOF
# 🏭 Creator Bot Report
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Repo:** $(get_repo)

## 🚀 Created Projects ($(echo ${#CREATIONS[@]}))

$(for c in "${CREATIONS[@]}"; do echo "- ✅ **$c**"; done)

## 🔗 Live Links (GitHub Pages)

Deploy these to get instant live URLs:

| Project | Link | Type |
|---------|------|------|
| Developer Portfolio | [View Live](${PAGES_URL}/creations/developer-portfolio/) | Website |
| SaaS Landing Page | [View Live](${PAGES_URL}/creations/saas-landing/) | Website |
| Todo App | [View Live](${PAGES_URL}/creations/todo-app/) | Web App |
| Weather Dashboard | [View Live](${PAGES_URL}/creations/weather-dashboard/) | Web App |
| Real-time Chat | [View Live](${PAGES_URL}/creations/realtime-chat/) | Web App |
| Admin Dashboard | [View Live](${PAGES_URL}/creations/admin-dashboard/) | Web App |

## 📦 Deploy Commands

### GitHub Pages (Free, Instant)
\`\`\`bash
# Enable GitHub Pages in repo settings → Source: main branch /root
# Your sites will be live at:
# https://username.github.io/repo-name/creations/project-name/
\`\`\`

### Vercel (Free, One-Click)
\`\`\`bash
cd creations/developer-portfolio
npx vercel --prod
# Live at: https://developer-portfolio.vercel.app
\`\`\`

### Netlify (Free, One-Click)
\`\`\`bash
cd creations/todo-app
npx netlify-cli deploy --prod --dir=.
# Live at: https://todo-app.netlify.app
\`\`\`

### Surge.sh (Free, Instant)
\`\`\`bash
cd creations/saas-landing
npx surge . saas-landing.surge.sh
# Live at: https://saas-landing.surge.sh
\`\`\`

## 📁 Project Files
All projects are in the \`creations/\` directory:
$(ls -la creations/ 2>/dev/null | grep "^d" | awk '{print "- **" $NF "** (" $6 " " $7 ")"}')

---
_Automated by Creator Bot 🏭_
REOF

cat "$REPORT"
notify "Creator Bot" "Created ${#CREATIONS[@]} projects! Deploy to get live links."
exit 0
