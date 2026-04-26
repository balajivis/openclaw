# CLAUDE.md — OpenClaw Student Setup

This file tells you (Claude) how to help a Modern AI Pro student get OpenClaw running. Read this before doing anything else in this repo.

**Class reference:** https://learn.modernaipro.com/paths/agentic/openclaw-demo

---

## Important: OpenClaw is not in your training data

OpenClaw was released in 2026 and is unlikely to appear in your training data. Do not guess how it works based on similar tools. Everything you need to know about its CLI, config format, and behavior is in this file and in the command output you see when you run it. When in doubt, run `openclaw --help` or `openclaw <command> --help` and reason from the actual output.

OpenClaw's CLI is installed globally via npm (`npm install -g openclaw`). Its config lives at `~/.openclaw/openclaw.json`. Its gateway is a local WebSocket server (default port 18789). The `openclaw` binary is the single entry point for all operations.

---

## What is OpenClaw

OpenClaw (version 2026.x) is a self-hosted AI agent gateway built for developers and teams who want to run AI agents connected to real communication channels — without sending data to a third-party cloud platform.

**What it does:**
- Runs a local gateway (WebSocket server) on the user's machine
- Connects chat channels (Telegram, WhatsApp, Discord, Slack, iMessage, Signal) to AI models
- Routes incoming messages from those channels through an AI agent and sends the reply back
- Supports multiple LLM providers simultaneously (OpenAI, Anthropic, Groq, Azure OpenAI, Ollama, etc.)
- Provides memory, HITL (human-in-the-loop), observability, and scheduling on top of the model

**What it is NOT:**
- Not a SaaS product — it runs entirely on the user's machine
- Not a wrapper around one specific model — it's provider-agnostic
- Not related to OpenAI's "Operator" or any browser-automation tool despite the similar naming

**The core flow:**
```
User → Telegram (or other channel)
     → OpenClaw gateway (local, port 18789)
     → LLM provider (Groq / Azure / etc.)
     → Reply back to Telegram
```

**Key CLI concepts:**
- `openclaw gateway` — starts the persistent agent server
- `openclaw channels add/login` — connects a chat channel (Telegram, WhatsApp, etc.)
- `openclaw config set` — modifies `~/.openclaw/openclaw.json`
- `openclaw models list` — shows available LLM providers and models
- `openclaw pairing approve` — authorizes a new user to talk to the bot
- `openclaw capability model run` — one-shot model test without starting a full session

---

## What the student is learning

By the end of this setup, students will understand:

1. **AI agents need infrastructure** — a model alone isn't a product. OpenClaw is the 8-layer stack (UI, graph, integrations, knowledge, memory, HITL, evals, observability) made tangible.
2. **API keys and providers** — the difference between Groq (free, rate-limited), Azure OpenAI (paid, enterprise-grade), and how to switch between them.
3. **Channel integration** — how a Telegram bot token wires a chat app to an agent.
4. **Local gateway pattern** — running a persistent service on their machine that handles incoming messages.

This is a hands-on demo of the **Build layer** in the Learn → Build → Deploy journey.

---

## Student profile

These are Modern AI Pro students — mid-career professionals, age 30–50, mixed technical backgrounds. Some are engineers; many are not. Be patient. Explain the "why" before the "how". Never assume they know what a terminal is without checking.

---

## Repo structure

```
openclaw/
├── CLAUDE.md               ← you are here
├── .env.example            ← key template students copy to .env
├── .env                    ← their actual keys (gitignored, never shared)
├── .gitignore
├── azure-proxy.py          ← local proxy that adds ?api-version to Azure calls
└── .claude/
    └── commands/
        └── setup-openclaw.md   ← /setup-openclaw slash command
```

---

## The setup flow (in order)

### Step 1 — Install OpenClaw
```bash
npm install -g openclaw
openclaw --version
```

### Step 2 — Create their .env
```bash
cp .env.example .env
```
Then fill in their key (see Key Acquisition below).

### Step 3 — Configure OpenClaw with their model provider
Run the `/setup-openclaw` slash command — it walks through this interactively.

Or manually:
```bash
set -a && source .env && set +a

cat > /tmp/groq-batch.json << 'EOF'
[{"path":"models.providers.groq","value":{"baseUrl":"https://api.groq.com/openai/v1","apiKey":{"source":"env","provider":"default","id":"GROQ_API_KEY"},"models":[{"id":"llama-3.3-70b-versatile","name":"Llama 3.3 70B (Groq)","input":["text"]}]}}]
EOF
openclaw config set --batch-file /tmp/groq-batch.json
openclaw config set agents.defaults.model.primary "groq/llama-3.3-70b-versatile"
openclaw config set gateway.mode local
```

### Step 4 — Create a Telegram bot
1. Go to [web.telegram.org](https://web.telegram.org) → log in
2. Search **BotFather** (blue checkmark) → open chat
3. Send `/newbot` → follow prompts → copy the token
4. Add to `.env`: `TELEGRAM_BOT_TOKEN="..."`

### Step 5 — Connect the bot
```bash
set -a && source .env && set +a
openclaw channels add --channel telegram --token $TELEGRAM_BOT_TOKEN
```

### Step 6 — Start the gateway
```bash
set -a && source .env && set +a
openclaw gateway --force &
```

Verify: `openclaw channels status --probe`
Should show: `Telegram default: ... connected, works`

### Step 7 — Approve yourself
First message to the bot shows a pairing code. Run:
```bash
openclaw pairing approve telegram <CODE>
```
Then message the bot again — it responds.

---

## Key acquisition — walk the student through this

### Groq (free, start here)
1. Go to [console.groq.com](https://console.groq.com) → sign in (free account)
2. Left sidebar → **API Keys** → **Create API Key**
3. Copy the key (starts with `gsk_`)
4. Add to `.env`: `GROQ_API_KEY="gsk_..."`

### If Groq hits rate limits (TPM exceeded)

Groq's free tier limits tokens per minute. The OpenClaw embedded agent sends a large system prompt (~26k tokens), which can exceed Groq's free tier on first use.

**What to tell the student when this happens:**

> "You've hit Groq's free-tier token limit. This is normal — the free plan has a small per-minute quota. You have two options:
> 1. Wait a minute and try again (quota resets per minute)
> 2. Switch to Azure OpenAI (no rate limits, what we use in class)"

**To switch to Azure OpenAI:**

The class Azure account is available for students during workshops. Ask the instructor for the key, or use your own Azure account.

Once you have the key:
1. Add to `.env`:
```
AZURE_API_KEY="your-azure-key"
AZURE_ENDPOINT="https://your-resource.cognitiveservices.azure.com"
```

2. Start the Azure proxy (handles the api-version Azure requires):
```bash
set -a && source .env && set +a
python3 azure-proxy.py &
```

3. Configure OpenClaw to use Azure via the proxy:
```bash
cat > /tmp/azure-config.json << 'EOF'
[{"path":"models.providers.azure-openai","value":{"baseUrl":"http://127.0.0.1:18800/openai/deployments/gpt-5.1","api":"openai-completions","apiKey":{"source":"env","provider":"default","id":"AZURE_API_KEY"},"models":[{"id":"gpt-5.1","name":"GPT-5.1 (Azure OpenAI)","input":["text","image"]}]}}]
EOF
openclaw config set --batch-file /tmp/azure-config.json --replace
openclaw config set agents.defaults.model.primary "azure-openai/gpt-5.1"
```

4. Restart the gateway:
```bash
pkill -f "openclaw gateway"
set -a && source .env && set +a
openclaw gateway --force &
```

---

## Key commands reference

| What | Command |
|------|---------|
| Check everything is working | `openclaw channels status --probe` |
| List available models | `openclaw models list` |
| Test a model directly | `openclaw capability model run --model groq/llama-3.3-70b-versatile --prompt "hello"` |
| Approve a student pairing | `openclaw pairing approve telegram <CODE>` |
| View gateway logs | `tail -f /tmp/openclaw/openclaw-*.log` |
| Restart gateway | `pkill -f "openclaw gateway" && openclaw gateway --force &` |
| Check config file | `~/.openclaw/openclaw.json` |

---

## Common problems and fixes

**"HTTP 404: Resource not found" on Azure**
The `azure-proxy.py` script is not running. Start it:
```bash
set -a && source .env && set +a && python3 azure-proxy.py &
```

**"API rate limit reached" on Groq**
Groq free tier hit. Wait 60 seconds and retry, or switch to Azure (see above).

**"access not configured" in Telegram**
Normal on first message. Run: `openclaw pairing approve telegram <CODE>`

**Bot doesn't respond at all**
Gateway isn't running. Run:
```bash
openclaw channels status --probe
openclaw gateway --force &
```

**Models list shows nothing**
The env vars aren't loaded. Run: `set -a && source .env && set +a` then retry.

---

## Your role as Claude in this repo

- Walk students through setup **one step at a time** — ask them to confirm each step before moving to the next
- When something fails, read the error carefully before suggesting a fix
- Don't overwhelm them with options — pick the right path based on what they have (Groq key vs Azure key)
- Celebrate small wins — getting the bot to respond for the first time is a big moment
- If they get stuck for more than 2 attempts on anything, suggest they message the instructor
