#!/usr/bin/env python3
"""
LooneyBin patch-notes generator -- runs on EVERY pbo pack (hooked in deploy/run-boot2.sh).

Normal (pack) mode:
  1. version from mission/Armapunk2035.Malden/version.hpp (AP_VERSION_STR)
  2. collect BUGS.md entries whose note says "(reboot pending" -> ship in THIS pack
  3. rewrite those notes to "(deployed <version>" so the next pack won't repeat them
  4. drop a player-facing message in loonybot/outbox/ -> the bot posts it

Re-post mode:  gen_patchnotes.py --repost "Beta 0.0.16"
  collects the entries already marked "(deployed <version>", posts them again with purge_bot set so
  the bot wipes its previous post for that version first. Does NOT change BUGS.md.

PLAYER-FACING FILTER (owner 2026-06-11): patch notes must NEVER mention anything admin- or
Asylum-related. Any entry whose chosen title line contains an EXCLUDE keyword is dropped silently.
"""
import json
import os
import re
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUGS = os.path.join(ROOT, "BUGS.md")
VERSION_HPP = os.path.join(ROOT, "mission", "Armapunk2035.Malden", "version.hpp")
OUTBOX = os.path.join(ROOT, "loonybot", "outbox")
CONFIG = os.path.join(ROOT, "loonybot", "config.json")
DEFAULT_CHANNEL = 100000000000000974

# entry is dropped from player notes if its title contains any of these (case-insensitive)
EXCLUDE = [
    "asylum", "de-asylum", "admin", "owner-only", "owner only", "kick", "ban player",
    "economy", "arsenal", "bullet cam", "anti-cheat", "anticheat", "spyglass",
    "cfgre", "cfgdisabled", "remoteexec", "whitelist",
]


def read_version():
    try:
        with open(VERSION_HPP, encoding="utf-8") as fh:
            m = re.search(r'AP_VERSION_STR\s+"([^"]+)"', fh.read())
            return m.group(1) if m else "unknown version"
    except OSError:
        return "unknown version"


def read_channel():
    try:
        with open(CONFIG, encoding="utf-8") as fh:
            return int(json.load(fh).get("patchnotes_channel_id") or DEFAULT_CHANNEL)
    except Exception:
        return DEFAULT_CHANNEL


def title_of(body):
    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith(("- **", ">", "---")):
            continue
        return re.sub(r"\s+", " ", line)[:140]
    return ""


def collect(text, marker):
    """marker = '(reboot pending' (pack) or '(deployed <version>' (repost). Returns kept notes
    [(id, kind, title)] after applying the player-facing EXCLUDE filter."""
    notes = []
    for m in re.finditer(r"### #(\d+) · ([A-Z]+[^·\n]*) · [^\n]*\n(.*?)(?=\n### #|\Z)", text, re.S):
        bid, status, body = m.group(1), m.group(2).strip(), m.group(3)
        if marker not in body:
            continue
        title = title_of(body)
        if not title:
            continue
        low = title.lower()
        if any(k in low for k in EXCLUDE):
            continue   # admin/Asylum -> never shown to players
        kind = "feature" if "FEATURE" in status else "fix"
        notes.append((int(bid), kind, title))
    return notes


def message(version, notes):
    lines = ["**Loonybin Life — %s** • server update" % version]
    if notes:
        for bid, kind, title in sorted(notes):
            tag = "\U0001F195" if kind == "feature" else "\U0001F527"
            lines.append("%s %s" % (tag, title))
    else:
        lines.append("_maintenance update — no player-facing changes_")
    return "\n".join(lines)


def queue(content, purge=0, seq=None):
    os.makedirs(OUTBOX, exist_ok=True)
    job = {"channel_id": read_channel(), "content": content}
    if purge:
        job["purge_bot"] = purge
    # The bot drains the outbox with sorted(os.listdir(...)), so the filename decides post ORDER.
    # A multi-part note gets a zero-padded seq suffix; same timestamp then sorts by part.
    name = "patchnotes-%d.json" % int(time.time()) if seq is None \
        else "patchnotes-%d-%02d.json" % (int(time.time()), seq)
    path = os.path.join(OUTBOX, name)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(job, fh, ensure_ascii=False)
    return path


def main():
    version = read_version()
    text = ""
    try:
        text = open(BUGS, encoding="utf-8").read()
    except OSError:
        pass

    # repost mode: re-issue an already-deployed version's notes, wiping the prior post
    if len(sys.argv) >= 2 and sys.argv[1] == "--repost":
        ver = sys.argv[2] if len(sys.argv) >= 3 else version
        notes = collect(text, "(deployed %s" % ver)
        queue(message(ver, notes), purge=6)
        print("[gen_patchnotes] REPOST %s (%d note(s), filtered)" % (ver, len(notes)))
        return 0

    # OVERRIDE: deploy/patchnote_override.txt (one-shot) wins -- post its text verbatim for special
    # updates (e.g. a teaser). Still flips reboot-pending -> deployed so BUGS stays consistent.
    override = os.path.join(ROOT, "deploy", "patchnote_override.txt")
    if os.path.exists(override):
        msg = open(override, encoding="utf-8").read().strip()
        if "(reboot pending" in text:
            with open(BUGS, "w", encoding="utf-8") as fh:
                fh.write(text.replace("(reboot pending", "(deployed %s" % version))
        # A line containing only ---POST--- splits the override into separate Discord messages,
        # posted in order. Discord hard-caps a message at 2000 chars, so a long update needs this.
        parts = [p.strip() for p in re.split(r'(?m)^\s*---POST---\s*$', msg) if p.strip()]
        for i, part in enumerate(parts):
            body = part.replace("{version}", version)
            if len(body) > 2000:
                print("[gen_patchnotes] WARNING: part %d is %d chars -- Discord will reject it"
                      % (i + 1, len(body)))
            queue(body, seq=(None if len(parts) == 1 else i))
        os.remove(override)
        print("[gen_patchnotes] %s -> override posted (%d part%s)"
              % (version, len(parts), "" if len(parts) == 1 else "s"))
        return 0

    # normal pack mode
    notes = collect(text, "(reboot pending")
    if "(reboot pending" in text:
        text = text.replace("(reboot pending", "(deployed %s" % version)
        with open(BUGS, "w", encoding="utf-8") as fh:
            fh.write(text)
    queue(message(version, notes))
    print("[gen_patchnotes] %s -> %d player note(s) posted (admin/asylum filtered)" % (version, len(notes)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
