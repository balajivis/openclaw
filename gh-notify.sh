#!/bin/bash
# Polls GitHub for open issues and sends new ones to Telegram.
# Run directly or via system cron.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
set -a && source "$SCRIPT_DIR/.env" && set +a

REPO="${REPO:-balajivis/openclaw}"
SEEN_FILE="$SCRIPT_DIR/.gh-seen-issues"
CHAT_ID="7670036459"

touch "$SEEN_FILE"

# Fetch open issues
ISSUES=$(curl -s \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/issues?state=open&per_page=10")

python3 << PYEOF
import json, subprocess, os

issues    = json.loads("""$ISSUES""")
seen_file = "$SEEN_FILE"
bot_token = "$TELEGRAM_BOT_TOKEN"
chat_id   = "$CHAT_ID"
repo      = "$REPO"

with open(seen_file) as f:
    seen = set(f.read().split())

new_seen = []
for issue in issues:
    num = str(issue["number"])
    if num in seen:
        continue

    title = issue["title"]
    user  = issue["user"]["login"]
    url   = issue["html_url"]
    body  = (issue.get("body") or "").strip()[:200]
    msg   = f"📌 New issue in {repo}\n\n#{num}: {title}\nBy: @{user}\n{url}"
    if body:
        msg += f"\n\n{body}{'…' if len(issue.get('body','')) > 200 else ''}"

    subprocess.run([
        "curl", "-s", "-X", "POST",
        f"https://api.telegram.org/bot{bot_token}/sendMessage",
        "-H", "Content-Type: application/json",
        "-d", json.dumps({"chat_id": chat_id, "text": msg})
    ], capture_output=True)
    new_seen.append(num)
    print(f"Notified #{num}: {title}")

if new_seen:
    with open(seen_file, "a") as f:
        f.write("\n".join(new_seen) + "\n")
elif not issues:
    print("No open issues.")
else:
    print(f"{len(issues)} issue(s) already seen.")
PYEOF
