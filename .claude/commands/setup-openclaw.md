Set up OpenClaw with a Groq API key on this machine.

## What this does
Installs the OpenClaw CLI (if not already installed), configures it with your Groq API key, and verifies the connection works.

## Steps

### 1. Check if OpenClaw is installed
Run: `which openclaw`

If not found, install it:
```
npm install -g openclaw
```
Wait for the install to complete, then verify with `openclaw --version`.

### 2. Get the student's Groq API key
Ask the student to paste their Groq API key. It starts with `gsk_`.

If they don't have one yet, tell them:
- Go to https://console.groq.com
- Sign in (free account)
- Click "API Keys" → "Create API Key"
- Copy the key and paste it here

### 3. Add the key to their shell profile
Check if it's already there:
```
grep -n "GROQ_API_KEY" ~/.zshrc
```

If not found, append it:
```
echo '\nexport GROQ_API_KEY="<their key>"' >> ~/.zshrc
```

### 4. Configure OpenClaw with Groq

Write the batch config file:
```
cat > /tmp/groq-batch.json << 'EOF'
[
  {
    "path": "models.providers.groq",
    "value": {
      "baseUrl": "https://api.groq.com/openai/v1",
      "apiKey": {
        "source": "env",
        "provider": "default",
        "id": "GROQ_API_KEY"
      },
      "models": [
        { "id": "llama-3.3-70b-versatile", "name": "Llama 3.3 70B (Groq)", "input": ["text"] },
        { "id": "llama-3.1-8b-instant", "name": "Llama 3.1 8B Instant (Groq)", "input": ["text"] },
        { "id": "mixtral-8x7b-32768", "name": "Mixtral 8x7B (Groq)", "input": ["text"] },
        { "id": "gemma2-9b-it", "name": "Gemma2 9B (Groq)", "input": ["text"] }
      ]
    }
  }
]
EOF
```

Apply it:
```
openclaw config set --batch-file /tmp/groq-batch.json
```

Set Groq as the default model:
```
openclaw config set agents.defaults.model.primary "groq/llama-3.3-70b-versatile"
```

### 5. Verify the key works
Run a direct API check (bypasses openclaw's large system prompt so it won't hit free-tier token limits):
```
curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
  -H "Authorization: Bearer <their key>" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama-3.3-70b-versatile","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":50}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'] if 'choices' in d else d)"
```

If you see a response sentence, setup is complete.

### 6. Confirm the model is listed
```
export GROQ_API_KEY="<their key>" && openclaw models list
```
You should see `groq/llama-3.3-70b-versatile` with a `default` tag.

## Done
Tell the student:
- Their key is saved in `~/.zshrc` and will load automatically in every new terminal session
- Their default OpenClaw model is now Groq Llama 3.3 70B (fast and free tier)
- To start OpenClaw: `openclaw chat` or `openclaw gateway`
- Config lives at `~/.openclaw/openclaw.json`
