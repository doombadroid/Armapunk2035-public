#!/usr/bin/env bash
# D5 daily reminder (owner 2026-09-07: "set verifySignatures to 0 for now but literally remind me daily that
# that needs to be changed (armapunk addon needs work and publishing)"). Posts one Discord message via REST
# using the credentials in ~/.config/armapunk/discord.env (DISCORD_TOKEN, DISCORD_CHANNEL_ID, DISCORD_PING_ID).
# No gateway connection, no bot process -- one HTTP POST a day.
# Retire it when verifySignatures=2 ships:  systemctl --user disable --now armapunk-d5-reminder.timer
set -u
. "$HOME/.config/armapunk/discord.env"
MSG="<@${DISCORD_PING_ID}> 🔓 DAILY REMINDER (D5): the live Armapunk server runs \`verifySignatures = 0\`. The @Armapunk2035 client addon still needs work + publishing. When it ships: set verifySignatures=2 in deploy/live/server.cfg, push-96, then \`systemctl --user disable --now armapunk-d5-reminder.timer\`. (MIGRATION_96.md D5)"
BODY=$(python3 -c 'import json,sys; print(json.dumps({"content": sys.argv[1]}))' "$MSG")
code=$(curl -s -o /tmp/d5_reminder.out -w '%{http_code}' -H "Authorization: Bot ${DISCORD_TOKEN}" -H 'Content-Type: application/json' \
  -X POST "https://discord.com/api/v10/channels/${DISCORD_CHANNEL_ID}/messages" --data "$BODY")
echo "d5_reminder: HTTP $code"; [ "$code" = 200 ] || { cat /tmp/d5_reminder.out; exit 1; }
