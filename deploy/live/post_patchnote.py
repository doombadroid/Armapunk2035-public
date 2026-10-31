#!/usr/bin/env python3
"""Post a patch note to Discord as LoonyBot. Runs ON the live box (the token lives there).

    echo "**Armapunk 2035 ...**" | python3 post_patchnote.py
    python3 post_patchnote.py --file note.txt --header      # prepend the standard version/build header
    python3 post_patchnote.py --dry-run < note.txt      # print what would be sent, post nothing

Credentials: ~/.config/armapunk/discord.env -- DISCORD_TOKEN and PATCHNOTES_CHANNEL_ID (falls back
to DISCORD_CHANNEL_ID). Stdlib only, one REST call per chunk: the bot PROCESS is still retired
(loonybot is pymysql->3306 and needs a psycopg port), but its identity posts fine over REST, which
is all patch notes ever needed -- the old path was gen_patchnotes.py -> loonybot/outbox -> the bot.

House rules (memory: loonybin-patchnote-credits): never @everyone unless asked, never credit other
servers' staff. Discord caps a message at 2000 characters, so a long note is split on line
boundaries and posted in order.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

ENV = os.path.expanduser("~/.config/armapunk/discord.env")
LIMIT = 1900          # under Discord's 2000 so a continuation marker always fits
VERSION_HPP = os.path.expanduser("~/Armapunk2035/mission/Armapunk2035.Malden/version.hpp")
BUILD_FILE = os.path.expanduser("~/arma3server_live/.build")


def standard_header():
    """The same header build_patchnote.py puts on a deploy note, composed from the live box's own
    state. --header exists so a hand-posted note cannot drift from the pipeline's format."""
    version = "unknown version"
    try:
        m = re.search(r'AP_VERSION_STR\s+"([^"]+)"', open(VERSION_HPP, encoding="utf-8").read())
        if m:
            version = m.group(1)
    except OSError:
        pass
    build = ""
    try:
        build = " \u00b7 b%04d" % int(open(BUILD_FILE).read().strip())
    except (OSError, ValueError):
        pass
    return "**Armapunk 2035 \u2014 %s** \u00b7 server update%s" % (version, build)


def creds():
    env = {}
    if os.path.exists(ENV):
        for ln in open(ENV, encoding="utf-8"):
            k, _, v = ln.strip().partition("=")
            if k:
                env[k] = v
    env.update({k: v for k, v in os.environ.items() if k.startswith("DISCORD_") or k == "PATCHNOTES_CHANNEL_ID"})
    token = env.get("DISCORD_TOKEN")
    chan = env.get("PATCHNOTES_CHANNEL_ID") or env.get("DISCORD_CHANNEL_ID")
    if not token or not chan:
        sys.exit("post_patchnote: need DISCORD_TOKEN and PATCHNOTES_CHANNEL_ID (%s)" % ENV)
    return token, chan


def chunks(text):
    out, cur = [], ""
    for line in text.split("\n"):
        line = line[:LIMIT]
        if len(cur) + len(line) + 1 > LIMIT:
            if cur:
                out.append(cur)
            cur = line
        else:
            cur = (cur + "\n" + line) if cur else line
    if cur:
        out.append(cur)
    return out


def post(token, chan, content):
    req = urllib.request.Request(
        "https://discord.com/api/v10/channels/%s/messages" % chan,
        data=json.dumps({"content": content, "allowed_mentions": {"parse": []}}).encode("utf-8"),
        headers={"Authorization": "Bot %s" % token, "Content-Type": "application/json",
                 "User-Agent": "ArmapunkPatchnotes (armapunk.com, 1.0)"},
        method="POST")
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.status


def main():
    args = sys.argv[1:]
    dry = "--dry-run" in args
    if "--file" in args:
        text = open(args[args.index("--file") + 1], encoding="utf-8").read()
    else:
        text = sys.stdin.read()
    text = text.strip()
    if "--header" in args and not text.lstrip().startswith("**"):
        text = standard_header() + "\n\n" + text
    if not text:
        print("post_patchnote: empty note, nothing posted")
        return 0
    if "@everyone" in text or "@here" in text:
        sys.exit("post_patchnote: refusing to post a note containing @everyone/@here")
    # Owner 2026-09-08: this is a closed ALPHA. The header takes its label from version.hpp, which is
    # now "Alpha", but a hand-written override could still say beta -- and the first note that did was
    # deleted from the channel. Refuse rather than post it again.
    if re.search(r"\bbeta\b", text, re.I) and "--allow-beta" not in args:
        sys.exit("post_patchnote: the note says 'beta' -- this is a closed ALPHA (pass --allow-beta if you mean it)")
    parts = chunks(text)
    if dry:
        print("--- would post %d message(s) to the patchnotes channel ---" % len(parts))
        print(text)
        return 0
    token, chan = creds()
    for i, part in enumerate(parts):
        try:
            code = post(token, chan, part)
        except urllib.error.HTTPError as e:
            sys.exit("post_patchnote: HTTP %s -- %s" % (e.code, e.read()[:300].decode("utf-8", "replace")))
        print("post_patchnote: part %d/%d -> HTTP %s" % (i + 1, len(parts), code))
        if i + 1 < len(parts):
            time.sleep(1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
