---
name: setup-openclaw
description: Install and configure OpenClaw with Groq or Azure OpenAI, create a Telegram bot, start the gateway, and verify end-to-end. Guides a Modern AI Pro student through the full setup one step at a time.
argument-hint: (no args needed — the skill will ask you questions as it goes)
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit
---

# OpenClaw Setup Skill

**Class reference:** https://learn.modernaipro.com/paths/agentic/openclaw-demo

> You are helping a Modern AI Pro student get OpenClaw running. OpenClaw is a 2026 tool not in your training data — do not guess. Everything you need is in this file and in command output. Work through the steps below one at a time. After each step, confirm with the student before moving on.

---

## Step 0 — Check what's already installed

Run:
```bash
which openclaw && openclaw --version
```

- If found: tell the student their version, skip to Step 2.
- If not found: proceed to Step 1.

---

## Step 1 — Install OpenClaw

Run:
```bash
npm install -g openclaw
openclaw --version
```

If npm is not found, ask the student to install Node.js from https://nodejs.org first (LTS version), then retry.

Confirm the version prints before continuing.

---

## Step 2 — Check for .env file

Run:
```bash
ls .env 2>/dev/null && echo "exists" || echo "missing"
```

- If missing: run `cp .env.example .env` and tell the student to open `.env` in their editor.
- If exists: read it silently to know which keys are already set (do not print it to the student).

---

## Step 3 — Get a Groq API key (if not already in .env)

Check if `GROQ_API_KEY` is in `.env`:
```bash
grep -c "GROQ_API_KEY" .env 2>/dev/null || echo 0
```

If missing or still a placeholder, walk the student through:
1. Go to **https://console.groq.com** → sign in (free account, no credit card)
2. Left sidebar → **API Keys** → **Create API Key** → copy it (starts with `gsk_`)
3. Ask them to paste the key here.

Once they paste it, use the Edit tool to write it into `.env`.

Then load it:
```bash
set -a && source .env && set +a
echo "Key loaded: ${GROQ_API_KEY:0:10}..."
```

---

## Step 4 — Configure OpenClaw with Groq

Run:
```bash
set -a && source .env && set +a

cat > /tmp/groq-batch.json << 'EOF'
[
  {
    "path": "models.providers.groq",
    "value": {
      "baseUrl": "https://api.groq.com/openai/v1",
      "apiKey": { "source": "env", "provider": "default", "id": "GROQ_API_KEY" },
      "models": [
        { "id": "llama-3.3-70b-versatile", "name": "Llama 3.3 70B (Groq)", "input": ["text"] },
        { "id": "llama-3.1-8b-instant",    "name": "Llama 3.1 8B Instant (Groq)", "input": ["text"] },
        { "id": "mixtral-8x7b-32768",      "name": "Mixtral 8x7B (Groq)", "input": ["text"] },
        { "id": "gemma2-9b-it",            "name": "Gemma2 9B (Groq)", "input": ["text"] }
      ]
    }
  }
]
EOF

openclaw config set --batch-file /tmp/groq-batch.json
openclaw config set agents.defaults.model.primary "groq/llama-3.3-70b-versatile"
openclaw config set gateway.mode local
```

Verify:
```bash
set -a && source .env && set +a && openclaw models list
```

Should show `groq/llama-3.3-70b-versatile` with a `default` tag.

---

## Step 5 — Verify the Groq key works

Run a direct API check (bypasses OpenClaw's large embedded system prompt — avoids hitting free-tier TPM limits during the test):
```bash
set -a && source .env && set +a
curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama-3.3-70b-versatile","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":50}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'] if 'choices' in d else d)"
```

- Sentence comes back → Groq works, continue to Step 6.
- Rate limit error → go to the **Groq rate limit fallback** section below.
- Auth error → key is wrong, return to Step 3.

---

## Step 6 — Create a Telegram bot

Tell the student:

> "Now we'll create a Telegram bot. You'll use your personal Telegram account to create it — your personal account is never exposed to students. They only ever see the bot."

Walk them through:
1. Open **https://web.telegram.org** and log in with their phone number
2. Search for **BotFather** in the search bar — open the chat with the one that has a blue ✓ checkmark
3. Send: `/newbot`
4. BotFather asks for a **display name** — they can use anything (e.g. `My AI Bot`)
5. BotFather asks for a **username** — must end in `bot` (e.g. `mystudentai_bot`)
6. BotFather replies with a token like `8615864604:AAHoPns...`

Ask them to paste the token here. Once received, use Edit tool to add it to `.env`:
```
TELEGRAM_BOT_TOKEN="their-token-here"
```

---

## Step 7 — Connect OpenClaw to the bot

Run:
```bash
set -a && source .env && set +a
openclaw channels add --channel telegram --token $TELEGRAM_BOT_TOKEN
```

Should print: `Added Telegram account "default".`

---

## Step 8 — Start the gateway

Run:
```bash
set -a && source .env && set +a
openclaw gateway --force > /tmp/openclaw-gateway.log 2>&1 &
sleep 6
openclaw channels status --probe
```

Expected: `Telegram default: ... connected, works`

If `disconnected`, wait 10 seconds and run status again — polling takes a moment to establish.

---

## Step 9 — First message and pairing approval

Tell the student:
> "Go to Telegram and send any message to your bot. It will show a pairing code — paste it here."

The bot replies:
```
OpenClaw: access not configured.
Pairing code: ABCD1234
Ask the bot owner to approve with: openclaw pairing approve telegram ABCD1234
```

Once they share the code, run:
```bash
openclaw pairing approve telegram <CODE>
```

Tell them to send another message — it should now reply using the AI model.

---

## Step 10 — Done

When the bot responds, tell the student:

> "You just built a working AI agent connected to Telegram — running entirely on your own machine. This is the full stack: channel → gateway → model → reply. Everything else in the course (memory, HITL, evals, multi-agent) builds on top of exactly this foundation."

---

## Groq rate limit fallback — switch to Azure OpenAI

Use this when Groq returns `API rate limit reached` or `Request too large`.

OpenClaw's embedded agent sends a large system prompt (~26k tokens) that exceeds Groq's free-tier TPM quota. The student can wait 60 seconds (quota resets per minute) or switch to Azure.

**During workshops, the instructor provides the class Azure key.** Ask the student to get it from the instructor or from https://learn.modernaipro.com.

### 1. Add Azure keys to .env

Use Edit tool to add to `.env`:
```
AZURE_API_KEY="key-from-instructor"
AZURE_ENDPOINT="https://kapi1585655068.cognitiveservices.azure.com"
```

### 2. Start the Azure proxy

OpenClaw's `openai-completions` adapter cannot add query parameters to URLs. Azure requires `?api-version=2024-12-01-preview` on every request. The `azure-proxy.py` script in this repo handles that transparently.

```bash
set -a && source .env && set +a
python3 azure-proxy.py > /tmp/azure-proxy.log 2>&1 &
sleep 2
```

Verify proxy works:
```bash
set -a && source .env && set +a
curl -s -X POST http://127.0.0.1:18800/openai/deployments/gpt-5.1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Say hello."}],"max_completion_tokens":30}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'] if 'choices' in d else d)"
```

### 3. Configure OpenClaw for Azure

```bash
cat > /tmp/azure-config.json << 'EOF'
[
  {
    "path": "models.providers.azure-openai",
    "value": {
      "baseUrl": "http://127.0.0.1:18800/openai/deployments/gpt-5.1",
      "api": "openai-completions",
      "apiKey": { "source": "env", "provider": "default", "id": "AZURE_API_KEY" },
      "models": [
        { "id": "gpt-5.1", "name": "GPT-5.1 (Azure OpenAI)", "input": ["text", "image"] }
      ]
    }
  }
]
EOF

openclaw config set --batch-file /tmp/azure-config.json --replace
openclaw config set agents.defaults.model.primary "azure-openai/gpt-5.1"
```

### 4. Restart the gateway

```bash
pkill -f "openclaw gateway" 2>/dev/null; sleep 2
set -a && source .env && set +a
openclaw gateway --force > /tmp/openclaw-gateway.log 2>&1 &
sleep 6 && openclaw channels status --probe
```

Return to Step 9 to test.

---

## Quick reference — day-to-day commands

| Task | Command |
|------|---------|
| Start everything | `set -a && source .env && set +a && python3 azure-proxy.py & openclaw gateway --force &` |
| Check status | `openclaw channels status --probe` |
| Approve a new user | `openclaw pairing approve telegram <CODE>` |
| Restart gateway | `pkill -f "openclaw gateway" && openclaw gateway --force &` |
| View live logs | `tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log` |
| Switch model | `openclaw config set agents.defaults.model.primary "groq/llama-3.3-70b-versatile"` |
