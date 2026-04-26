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
1234567890:AAHxxx...your_token_here
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

## GitHub integration (2-way)

Connect your GitHub repo to Telegram so you get notified of new issues and can reply directly from Telegram to post GitHub comments.

**The classroom use case:**
```
Student opens a GitHub issue
        ↓
Instructor gets a Telegram ping with the issue title, author, and preview
        ↓
Instructor replies to that message in Telegram
        ↓
Reply is posted as a GitHub comment on the issue
        ↓
Telegram confirms with a link to the comment
```

### Setup

**1. Create a GitHub personal access token**

1. Go to github.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Click **Generate new token**
3. Under "Repository access" → select the repo you want (e.g. `balajivis/openclaw`)
4. Under "Permissions" → Issues → **Read and Write**
5. Click **Generate token** → copy it

**2. Get your Telegram user ID**

Message your bot once — the pairing screen shows `Your Telegram user id: XXXXXXX`. That number is your `TELEGRAM_OWNER_CHAT_ID`.

**3. Add to your .env**

```bash
GH_TOKEN="github_pat_your_token_here"
TELEGRAM_OWNER_CHAT_ID="your_numeric_telegram_id"
REPO="yourusername/yourrepo"   # defaults to balajivis/openclaw
```

**4. Set up the cron jobs**

```bash
# Make scripts executable
chmod +x gh-notify.sh gh-reply.sh

# Add to crontab (runs every minute)
(crontab -l 2>/dev/null; echo "* * * * * /Users/you/openclaw/gh-notify.sh >> /tmp/gh-notify.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /Users/you/openclaw/gh-reply.sh  >> /tmp/gh-reply.log  2>&1") | crontab -

# Verify
crontab -l
```

Adjust the path to match where you cloned the repo.

**5. Test it**

Open a GitHub issue on your repo. Within 60 seconds you'll get a Telegram notification. Reply to it in Telegram — the reply appears as a GitHub comment.

### How it works

- `gh-notify.sh` — polls GitHub API every minute for new open issues, sends each one to Telegram, stores the `telegram_msg_id → issue_number` mapping in `.gh-msg-map`
- `gh-reply.sh` — polls Telegram `getUpdates` every minute; when you reply to a notification message, it looks up the issue number, posts your reply as a GitHub comment, and confirms in Telegram

Both files are stored in `.gitignore` so the mapping and offset files don't pollute the repo.

---

## Repo structure

```
openclaw/
├── .env.example          # Copy to .env, fill in your keys
├── .env                  # Your keys — never committed
├── .gitignore
├── azure-proxy.py        # Local proxy that adds ?api-version to Azure calls
├── gh-notify.sh          # GitHub → Telegram notifications (cron, every minute)
├── gh-reply.sh           # Telegram reply → GitHub comment (cron, every minute)
└── .claude/
    └── skills/
        └── setup-openclaw/
            └── SKILL.md  # /setup-openclaw Claude Code skill
```
