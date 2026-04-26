#!/bin/bash
# Polls GitHub for open issues and sends new ones to Telegram.
# Stores telegram_message_id → issue_number in .gh-msg-map for 2-way replies.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
set -a && source "$SCRIPT_DIR/.env" && set +a

REPO="${REPO:-balajivis/openclaw}"
SEEN_FILE="$SCRIPT_DIR/.gh-seen-issues"
MSG_MAP="$SCRIPT_DIR/.gh-msg-map"   # format: telegram_msg_id:issue_number
CHAT_ID="7670036459"

touch "$SEEN_FILE" "$MSG_MAP"

ISSUES=$(curl -s \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/issues?state=open&per_page=10")

python3 << PYEOF
import json, subprocess

issues    = json.loads("""$ISSUES""")
seen_file = "$SEEN_FILE"
msg_map   = "$MSG_MAP"
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
    msg   = f"📌 New issue #{num} in {repo}\n\n{title}\nBy: @{user}\n{url}"
    if body:
        msg += f"\n\n{body}{'…' if len(issue.get('body','')) > 200 else ''}"
    msg  += f"\n\n↩️ Reply to this message to comment on GitHub"

    result = subprocess.run([
        "curl", "-s", "-X", "POST",
        f"https://api.telegram.org/bot{bot_token}/sendMessage",
        "-H", "Content-Type: application/json",
        "-d", json.dumps({"chat_id": chat_id, "text": msg})
    ], capture_output=True, text=True)

    resp = json.loads(result.stdout)
    if resp.get("ok"):
        tg_msg_id = resp["result"]["message_id"]
        with open(msg_map, "a") as f:
            f.write(f"{tg_msg_id}:{num}\n")

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
