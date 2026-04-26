#!/usr/bin/env python3
"""
Thin proxy: openclaw → localhost:18800 → Azure OpenAI
- Adds ?api-version and the api-key header that Azure requires.
- Rewrites legacy /completions calls to /chat/completions (gpt-5.x are chat-only models).
Run: python3 azure-proxy.py
"""
import os, json, urllib.request, urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

AZURE_KEY     = os.environ["AZURE_API_KEY"]
AZURE_BASE    = os.environ.get("AZURE_ENDPOINT", "https://kapi1585655068.cognitiveservices.azure.com").rstrip("/")
API_VERSION   = "2024-12-01-preview"
PROXY_PORT    = 18800

def completions_to_chat(body_bytes):
    """Convert legacy /completions body to /chat/completions format."""
    try:
        payload = json.loads(body_bytes)
    except Exception:
        return body_bytes
    if "messages" in payload:
        return body_bytes  # already chat format
    prompt = payload.pop("prompt", "") or ""
    payload["messages"] = [{"role": "user", "content": prompt}]
    # gpt-5.x requires max_completion_tokens, not max_tokens
    if "max_tokens" in payload:
        payload["max_completion_tokens"] = payload.pop("max_tokens")
    return json.dumps(payload).encode()

class AzureProxy(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[proxy] {fmt % args}")

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body   = self.rfile.read(length)

        path = self.path
        # Rewrite /completions → /chat/completions for chat-only models
        if path.split("?")[0].endswith("/completions") and "/chat/completions" not in path:
            path = path.replace("/completions", "/chat/completions", 1)
            body = completions_to_chat(body)
            print(f"[proxy] rewrote /completions → /chat/completions")

        sep = "&" if "?" in path else "?"
        target = f"{AZURE_BASE}{path}{sep}api-version={API_VERSION}"

        req = urllib.request.Request(
            target, data=body, method="POST",
            headers={"api-key": AZURE_KEY, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req) as resp:
                data = resp.read()
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    if k.lower() not in ("transfer-encoding",):
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(data)

if __name__ == "__main__":
    print(f"[proxy] Azure proxy → {AZURE_BASE}  (port {PROXY_PORT})")
    HTTPServer(("127.0.0.1", PROXY_PORT), AzureProxy).serve_forever()
