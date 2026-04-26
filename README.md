# OpenClaw Setup — Modern AI Pro

OpenClaw is a self-hosted AI agent gateway that connects chat apps (Telegram, WhatsApp, Discord, etc.) to AI models. This repo gets you set up with Groq (free, fast) and Telegram in under 15 minutes.

---

## What you'll have when done

```
You message @YourBot on Telegram
        ↓
OpenClaw receives it (running on your machine)
        ↓
Groq Llama 3.3 70B processes it
        ↓
Bot replies in Telegram
```

---

## Prerequisites

- [Node.js](https://nodejs.org) 18+
- A free [Groq account](https://console.groq.com)
- A Telegram account (personal account is fine — we'll create a separate bot)

---

## Step 1 — Install OpenClaw

```bash
npm install -g openclaw
openclaw --version   # should print OpenClaw 2026.x.x
```

---

## Step 2 — Set up your environment

```bash
git clone https://github.com/balajivis/openclaw.git
cd openclaw
cp .env.example .env
```

Open `.env` and fill in your Groq API key (see Step 3 below).

---

## Step 3 — Get your Groq API key

1. Go to [console.groq.com](https://console.groq.com) and sign in (free account)
2. Click **API Keys** in the left sidebar
3. Click **Create API Key**, give it a name, copy it
4. Paste it into your `.env`:

```
GROQ_API_KEY="gsk_your_key_here"
```

---

## Step 4 — Configure OpenClaw with Groq

Run these three commands:

```bash
# Load your key into the shell
set -a && source .env && set +a

# Register Groq as a model provider
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

# Set Groq as the default model
openclaw config set agents.defaults.model.primary "groq/llama-3.3-70b-versatile"

# Set gateway mode
openclaw config set gateway.mode local
```

Verify Groq is connected:
```bash
openclaw models list
# Should show: groq/llama-3.3-70b-versatile ... default
```

---

## Step 5 — Create a Telegram bot

You use your personal Telegram account to create a bot. Students message the **bot** — your personal account is never exposed.

### 5a. Log into Telegram

Go to [web.telegram.org](https://web.telegram.org) and log in with your phone number. (Or use the Telegram desktop/mobile app — it's the same.)

### 5b. Create a bot via BotFather

1. In the search bar, search for **BotFather** — open the chat with the one that has a blue checkmark ✓
2. Send: `/newbot`
3. BotFather asks for a **name** — this is the display name (e.g. `Balaji AI`)
4. Then it asks for a **username** — must end in `bot` (e.g. `balajimai_bot`)
5. BotFather replies with your bot token:

```
Use this token to access the HTTP API:
8615864604:AAHoPnsF6tN594wf0QF4uatELXpH0NBHVZA
```

Copy that token.

### 5c. Add the token to your .env

```
TELEGRAM_BOT_TOKEN="your_token_here"
```

### 5d. Connect OpenClaw to your bot

```bash
set -a && source .env && set +a
openclaw channels add --channel telegram --token $TELEGRAM_BOT_TOKEN
```

You should see: `Added Telegram account "default".`

---

## Step 6 — Start the gateway

```bash
set -a && source .env && set +a
openclaw gateway --force &
```

Check that Telegram is running:
```bash
openclaw channels status
# Should show: Telegram default: enabled, configured, running, mode:polling
```

---

## Step 7 — Approve yourself

The first time you (or any student) messages the bot, OpenClaw shows a pairing code:

```
OpenClaw: access not configured.
Your Telegram user id: 1234567890
Pairing code: ABCD1234

Ask the bot owner to approve with:
openclaw pairing approve telegram ABCD1234
```

Run the approve command shown:

```bash
openclaw pairing approve telegram ABCD1234
```

Then send the bot another message — it will respond.

> **For a class**: each student messages the bot once, gets a pairing code, and you run `openclaw pairing approve telegram <code>` for each of them. Or set up open access in `openclaw config` to skip per-user approval.

---

## Claude Code slash command

If you open this repo in [Claude Code](https://claude.ai/code), you get a `/setup-openclaw` slash command that walks you through Steps 3–7 interactively.

```
/setup-openclaw
```

---

## Troubleshooting

**Bot doesn't respond**
- Check the gateway is running: `openclaw channels status`
- Check your Groq key is loaded: `echo $GROQ_API_KEY`
- Restart the gateway: `openclaw gateway --force &`

**"access not configured" message**
- This is normal on first contact — run `openclaw pairing approve telegram <code>`

**Groq rate limit errors**
- The free tier has TPM limits. Switch to `llama-3.3-70b-versatile` (highest free limit) or upgrade at [console.groq.com](https://console.groq.com)

---

## Repo structure

```
openclaw/
├── .env.example                       # Copy to .env, fill in your keys
├── .env                               # Your keys — never committed
├── .gitignore
└── .claude/
    └── commands/
        └── setup-openclaw.md          # Claude Code slash command
```
