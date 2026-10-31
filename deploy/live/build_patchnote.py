#!/usr/bin/env python3
"""Compose the patch note for a live deploy. Runs on the dev box, prints the note on stdout.

    deploy/live/build_patchnote.py <prev_commit> <head_commit> <build>

Sources, in precedence order:
  1. deploy/patchnote_override.txt -- verbatim, `{version}` substituted, CONSUMED (deleted) on use.
     This is the curated path: write the note you want players to read, deploy, done.
  2. BUGS.md entries marked "(reboot pending" -- the historical generator's source; reuses
     gen_patchnotes.collect() so the player-facing EXCLUDE filter stays in ONE place.
  3. commit subjects in prev..head, minus the infrastructure prefixes players do not care about
     (docs/chore/test/ci/deploy/live/watchdog) and minus anything the EXCLUDE filter drops.

Prints NOTHING and exits 1 when there is nothing player-facing to say -- push-96.sh treats that as
"no post", which is what keeps a dev-mode day of deploys from spamming the channel.
"""
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "deploy"))
import gen_patchnotes as gp      # version reader, EXCLUDE filter, BUGS.md collector

OVERRIDE = os.path.join(ROOT, "deploy", "patchnote_override.txt")
# subjects starting with these are infrastructure, not player-facing
SKIP_PREFIX = ("docs", "chore", "test", "tests", "ci", "deploy", "live", "watchdog", "wip", "revert",
               "patchnotes", "tools", "pgmigrate")
NEW = "\U0001F195"      # feature
FIX = "\U0001F527"      # fix


def from_commits(prev, head):
    if not prev:
        return []
    out = subprocess.run(["git", "-C", ROOT, "log", "--no-merges", "--format=%s", "%s..%s" % (prev, head)],
                         capture_output=True, text=True)
    notes = []
    for subject in out.stdout.splitlines():
        subject = subject.strip()
        if not subject:
            continue
        head_word = subject.split(":", 1)[0].strip().lower()
        if head_word in SKIP_PREFIX:
            continue
        low = subject.lower()
        if any(k in low for k in gp.EXCLUDE):
            continue
        tag = NEW if re.match(r"^(feat|feature|add)\b", low) else FIX
        notes.append("%s %s" % (tag, subject))
    return notes


def main():
    prev = sys.argv[1] if len(sys.argv) > 1 else ""
    head = sys.argv[2] if len(sys.argv) > 2 else "HEAD"
    build = sys.argv[3] if len(sys.argv) > 3 else ""
    version = gp.read_version()
    header = "**Armapunk 2035 — %s** · server update%s" % (version, (" · %s" % build) if build else "")

    if os.path.exists(OVERRIDE):
        body = open(OVERRIDE, encoding="utf-8").read().replace("{version}", version).strip()
        # Archive before consuming: the file is one-shot (exactly as run-boot2 consumed it), and a
        # failed post must not take the text with it.
        arch = os.path.expanduser("~/.armapunk_patchnotes")
        os.makedirs(arch, exist_ok=True)
        with open(os.path.join(arch, time.strftime("%Y%m%d-%H%M%S.txt")), "w", encoding="utf-8") as fh:
            fh.write(body)
        os.remove(OVERRIDE)
        if body:
            print(body if body.lstrip().startswith("**") else header + "\n\n" + body)
            return 0

    try:
        bugs = open(os.path.join(ROOT, "BUGS.md"), encoding="utf-8").read()
    except OSError:
        bugs = ""
    pending = gp.collect(bugs, "(reboot pending") if bugs else []
    lines = ["%s %s" % (NEW if kind == "feature" else FIX, title) for _bid, kind, title in sorted(pending)]
    if not lines:
        lines = from_commits(prev, head)
    if not lines:
        return 1                                  # nothing player-facing -> no post
    print("\n".join([header] + lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
