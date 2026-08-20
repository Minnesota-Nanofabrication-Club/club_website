#!/bin/bash
# Post one sync outcome to a Discord channel via an incoming webhook.
#
#   notify-discord.sh <state> <headline> [detail]
#     state:    ok | proposed | changed | fail
#     headline: one short line -- the ultra-concise summary
#     detail:   optional second line (commit hash, file list, error text)
#
# A webhook rather than a bot: this only ever sends, never listens, so there is
# nothing to keep running and no gateway connection to drop. A bot would add a
# permanently-running process whose own failure mode is silence -- the exact
# thing this notification exists to prevent.
#
# Setup (once):
#   Discord > your server > Server Settings > Integrations > Webhooks > New Webhook
#   Pick the channel, Copy Webhook URL, then:
#     mkdir -p ~/.config/mnfc-sync
#     echo 'https://discord.com/api/webhooks/...' > ~/.config/mnfc-sync/discord-webhook
#     chmod 600 ~/.config/mnfc-sync/discord-webhook
#   Optional, to get an actual @ping instead of a silent post:
#     echo '<@YOUR_DISCORD_USER_ID>' > ~/.config/mnfc-sync/discord-mention
#
# The webhook URL is a secret -- anyone holding it can post to your channel as
# this integration. It lives in ~/.config, never in this repo.
#
#   notify-discord.sh --test    send a test message and exit

set -uo pipefail

CONFIG_DIR="$HOME/.config/mnfc-sync"
WEBHOOK_FILE="$CONFIG_DIR/discord-webhook"
MENTION_FILE="$CONFIG_DIR/discord-mention"
SITE_URL="https://minnesota-nanofabrication-club.github.io/club_website/"

if [ "${1:-}" = "--test" ]; then
  set -- ok "Test message" "If you can read this, the webhook is wired up correctly."
fi

STATE="${1:-ok}"
HEADLINE="${2:-}"
DETAIL="${3:-}"

# Missing config is not an error. The sync must never fail because Discord is
# unconfigured -- publishing the site matters, announcing it does not.
if [ ! -f "$WEBHOOK_FILE" ]; then
  echo "Discord: not configured (no $WEBHOOK_FILE); skipping notification."
  exit 0
fi

WEBHOOK=$(tr -d '[:space:]' < "$WEBHOOK_FILE")
if [ -z "$WEBHOOK" ]; then
  echo "Discord: webhook file is empty; skipping notification."
  exit 0
fi

MENTION=""
if [ -f "$MENTION_FILE" ]; then
  MENTION=$(tr -d '\n' < "$MENTION_FILE")
fi

# Build and send the payload in python3 so that commit subjects containing
# quotes, backslashes or newlines cannot break the JSON.
STATE="$STATE" HEADLINE="$HEADLINE" DETAIL="$DETAIL" MENTION="$MENTION" \
WEBHOOK="$WEBHOOK" SITE_URL="$SITE_URL" /usr/bin/env python3 <<'PYEOF'
import json, os, sys, urllib.request, urllib.error

state    = os.environ.get("STATE", "ok")
headline = os.environ.get("HEADLINE", "").strip()
detail   = os.environ.get("DETAIL", "").strip()
mention  = os.environ.get("MENTION", "").strip()
webhook  = os.environ["WEBHOOK"]
site_url = os.environ["SITE_URL"]

style = {
    # Every outcome pings, at Leo's request (2026-08-20). Quiet runs pinged
    # silently at first, on the theory that a notification firing whether or not
    # anything happened becomes one you stop reading. He wants confirmation the
    # job ran at all, which that theory does not serve -- an absent ping is the
    # signal, and it only reads as a signal if a present one is guaranteed.
    # Twice a week is a low enough rate for that to stay legible.
    "ok":       ("✓ Site checked",              0x95A5A6, True),
    "proposed": ("📋 Update proposed — review",  0xE0A100, True),
    "changed":  ("↻ Site updated",              0x7A0019, True),
    "fail":     ("✗ Sync failed",               0xE74C3C, True),
}
title, color, ping = style.get(state, style["ok"])

description = headline or "(no summary)"
if detail:
    description += "\n" + detail
if state == "changed":
    description += f"\n\n[View the site]({site_url})"

payload = {
    "username": "Website Sync",
    "embeds": [{
        "title": title,
        "description": description[:4000],
        "color": color,
    }],
}
if ping and mention:
    payload["content"] = mention

req = urllib.request.Request(
    webhook,
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json", "User-Agent": "mnfc-sync/1.0"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=15) as r:
        print(f"Discord: posted ({r.status}).")
except urllib.error.HTTPError as e:
    body = e.read().decode("utf-8", "replace")[:300]
    print(f"Discord: HTTP {e.code} -- {body}")
    sys.exit(1)
except Exception as e:
    print(f"Discord: send failed -- {e}")
    sys.exit(1)
PYEOF
