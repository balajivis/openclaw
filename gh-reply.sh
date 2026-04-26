#!/bin/bash
# Polls Telegram for replies to issue notifications and posts them as GitHub comments.
# Run every minute via cron alongside gh-notify.sh.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
set -a && source "$SCRIPT_DIR/.env" && set +a

REPO="${REPO:-balajivis/openclaw}"
MSG_MAP="$SCRIPT_DIR/.gh-msg-map"
OFFSET_FILE="$SCRIPT_DIR/.gh-tg-offset"
CHAT_ID="7670036459"

touch "$MSG_MAP" "$OFFSET_FILE"
OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo "0")

UPDATES=$(curl -s \
  "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates?offset=$OFFSET&timeout=5&allowed_updates=[\"message\"]")

python3 << PYEOF
import json, subprocess

updates   = json.loads("""$UPDATES""")
msg_map   = "$MSG_MAP"
offset_f  = "$OFFSET_FILE"
bot_token = "$TELEGRAM_BOT_TOKEN"
chat_id   = "$CHAT_ID"
repo      = "$REPO"
gh_token  = "$GH_TOKEN"

# Load message_id → issue_number map
mapping = {}
with open(msg_map) as f:
    for line in f:
        line = line.strip()
        if ":" in line:
            tg_id, issue_num = line.split(":", 1)
            mapping[int(tg_id)] = issue_num

if not updates.get("ok") or not updates.get("result"):
    print("No updates.")
    exit()

last_update_id = 0
for update in updates["result"]:
    last_update_id = update["update_id"]
    msg = update.get("message", {})

    # Only process replies from the owner (chat_id match)
    if str(msg.get("chat", {}).get("id", "")) != chat_id:
        continue

    reply_to = msg.get("reply_to_message", {})
    if not reply_to:
        continue

    replied_msg_id = reply_to.get("message_id")
    issue_num = mapping.get(replied_msg_id)
    if not issue_num:
        continue

    comment_text = msg.get("text", "").strip()
    if not comment_text:
        continue

    # Post to GitHub as a comment
    result = subprocess.run([
        "curl", "-s", "-X", "POST",
        f"https://api.github.com/repos/{repo}/issues/{issue_num}/comments",
        "-H", f"Authorization: Bearer {gh_token}",
        "-H", "Accept: application/vnd.github+json",
        "-H", "Content-Type: application/json",
        "-d", json.dumps({"body": comment_text})
    ], capture_output=True, text=True)

    resp = json.loads(result.stdout)
    if resp.get("id"):
        comment_url = resp["html_url"]
        # Confirm back in Telegram
        subprocess.run([
            "curl", "-s", "-X", "POST",
            f"https://api.telegram.org/bot{bot_token}/sendMessage",
            "-H", "Content-Type: application/json",
            "-d", json.dumps({
                "chat_id": chat_id,
                "text": f"✅ Posted to GitHub issue #{issue_num}\n{comment_url}",
                "reply_to_message_id": msg["message_id"]
            })
        ], capture_output=True)
        print(f"Commented on #{issue_num}: {comment_text[:60]}")
    else:
        print(f"GitHub error: {resp}")

# Advance offset so we don't reprocess
if last_update_id:
    with open(offset_f, "w") as f:
        f.write(str(last_update_id + 1))
PYEOF
