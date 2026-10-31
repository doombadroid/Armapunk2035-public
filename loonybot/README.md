# LoonyBot

Discord bug-report intake for LooneyBin Altis Life. Captures reports into
`../BUGS.md` (the project-root queue Claude reads). Lifecycle: **NEW → STAGED → FIXED**.

## Channels
- **Intake** (`bug_channel_id`) — any plain message here = a `NEW` bug.
- **Status** (`status_channel_id`) — the bot posts a confirmation when a bug is logged,
  and an update whenever its Status changes (🐛 logged → 🛠️ STAGED → ✅ FIXED). A background
  watcher diffs `BUGS.md`, so even when Claude edits the file the change is announced here.

## What it does
- Plain message in the intake channel, or `!bug <what broke>` anywhere → logged `NEW`.
- `!bugs` → list open (NEW/STAGED) bugs.
- `!resolve <id>` → mark a bug `FIXED` (owner-only if you set `owner_ids`).
- Reacts ✅ on a report once logged.

The bot **only writes NEW**. You (or Claude) move Status to STAGED/FIXED by editing
`BUGS.md` or with `!resolve`; the watcher announces it in the status channel.

## One-time setup

### 1. Create the bot + token
1. https://discord.com/developers/applications → **New Application** (name it LoonyBot).
2. Left menu → **Bot** → **Reset Token** → copy the token (keep it secret).
3. Same page → **Privileged Gateway Intents** → enable **MESSAGE CONTENT INTENT**. Save.

### 2. Invite it to your server
- Left menu → **OAuth2 → URL Generator**.
- Scopes: **bot**. Bot Permissions: **View Channels, Send Messages, Add Reactions, Read Message History**.
- Open the generated URL, pick your server, authorize.

### 3. Get IDs (enable Discord Developer Mode: Settings → Advanced → Developer Mode)
- **Channel ID:** right-click your #bug-reports channel → *Copy Channel ID*.
- **Your user ID:** right-click your name → *Copy User ID* (for `owner_ids`).

### 4. Configure
```bash
cd loonybot
cp config.example.json config.json
# edit config.json:
#   token             -> the bot token from step 1
#   bug_channel_id    -> the intake (#bug-reports) channel ID (number, no quotes)
#   status_channel_id -> the channel where the bot posts confirmations + fix-tracking
#   owner_ids         -> [your_user_id]   (optional; restricts !resolve)
#   report_file       -> absolute path to BUGS.md (default is fine)
```
`config.json` holds your token — it's gitignored; don't share it.

### 5. Install + run
```bash
cd loonybot
python3 -m venv venv
venv/bin/pip install -r requirements.txt
./run.sh            # or: venv/bin/python loonybot.py
```
(If `python3 -m venv` is unavailable: `pip install --user discord.py`, then `python3 loonybot.py`.)

Leave it running (e.g. `./run.sh &`, `tmux`, or a systemd unit) so it keeps listening.

## Flow with Claude
1. Players/you report in Discord → bot appends `NEW` entries to `BUGS.md`.
2. Tell Claude "check BUGS.md" → Claude reads the `NEW` ones.
3. You give the go-ahead → Claude stages fixes, marks entries `STAGED`, then `FIXED` after reboot.
