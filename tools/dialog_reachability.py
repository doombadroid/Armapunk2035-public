#!/usr/bin/env python3
"""dialog_reachability.py -- every createDialog target must be declared at CONFIG ROOT.

THE FOOTGUN THIS EXISTS FOR. description.ext declares UI classes in two places that look
interchangeable and are not:

    #include "dialog\\MasterHandler.h"   at the top level  -> config ROOT. createDialog finds it.
    class RscTitles { #include ... }      -> RscTitles.      cutRsc/titleRsc find it; createDialog
                                                             does NOT.

A dialog whose include lands inside the RscTitles block is perfectly valid config -- it parses
clean, the deploy's config check passes, the PBO packs, the server boots -- and then
createDialog answers false at runtime with "Resource <name> not found". The two are one blank
line apart in description.ext, and a HUD layer and its editor are exactly the pair most likely
to be filed next to each other by topic rather than by mechanism. That happened on 2026-08-30
with AP_web_hudedit (hudeditor.md).

WHAT THIS CHECKS. Every `createDialog "X"` target found in the mission's SQF, HPP and EVH files
is resolved against description.ext's include tree, and the class must be reachable WITHOUT
passing through a `class RscTitles` block. Anything reachable only inside RscTitles is reported.

Deliberately NOT checked: that the class exists at all. A createDialog target built from a
variable, or declared in an addon rather than the mission, is out of scope and is reported as
UNRESOLVED for information rather than as a failure -- this gate is about the ROOT-vs-RscTitles
distinction, and widening it to "does the class exist" would make it fail on things that work.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MISSION = os.path.join(ROOT, "mission", "Armapunk2035.Malden")
DESC = os.path.join(MISSION, "description.ext")

CREATE = re.compile(r'createDialog\s*"([A-Za-z0-9_]+)"')
INCLUDE = re.compile(r'^\s*#include\s*"([^"]+)"', re.M)
CLASSDEF = re.compile(r'^\s*class\s+([A-Za-z0-9_]+)\s*(?::\s*[A-Za-z0-9_]+\s*)?\{', re.M)

SCAN_EXT = (".sqf", ".hpp", ".h", ".ext")


def read(path):
    try:
        return open(path, encoding="utf-8", errors="surrogateescape").read()
    except OSError:
        return ""


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def collect_targets():
    """Every createDialog "X" in the mission tree, with where it was found."""
    found = {}
    for base, dirs, files in os.walk(MISSION):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "ArmaQuest")]
        for fn in files:
            if not fn.endswith(SCAN_EXT):
                continue
            p = os.path.join(base, fn)
            for m in CREATE.finditer(strip_comments(read(p))):
                found.setdefault(m.group(1), os.path.relpath(p, ROOT))
    return found


def declared_in(path, seen=None):
    """{class name: True if it is inside a RscTitles block} for one file and its includes.

    Tracks brace depth so that a class declared inside `class RscTitles { ... }` is marked, and
    follows #include so the MasterHandler.h chain is walked the way the engine walks it.
    """
    if seen is None:
        seen = set()
    real = os.path.realpath(path)
    if real in seen or not os.path.exists(path):
        return {}
    seen.add(real)

    text = strip_comments(read(path))
    out = {}

    # Walk character by character so an include's position relative to the RscTitles block is
    # known. A regex over the whole file cannot tell inside from outside.
    depth = 0
    titles_depth = None          # brace depth at which class RscTitles opened, None = not in one
    i = 0
    line_start = 0
    while i < len(text):
        c = text[i]
        if c == "{":
            # was the token before this brace a `class Name`?
            head = text[line_start:i]
            m = re.search(r"class\s+([A-Za-z0-9_]+)\s*(?::\s*[A-Za-z0-9_]+\s*)?$", head)
            if m:
                name = m.group(1)
                out[name] = titles_depth is not None
                if name == "RscTitles" and titles_depth is None:
                    titles_depth = depth
            depth += 1
            i += 1
            continue
        if c == "}":
            depth -= 1
            if titles_depth is not None and depth <= titles_depth:
                titles_depth = None
            i += 1
            continue
        if c == "\n":
            line_start = i + 1
            i += 1
            continue
        if c == "#" and text.startswith("#include", i):
            m = re.match(r'#include\s*"([^"]+)"', text[i:])
            if m:
                inc = m.group(1).replace("\\", os.sep)
                cand = os.path.join(os.path.dirname(path), inc)
                if not os.path.exists(cand):
                    cand = os.path.join(MISSION, inc)
                inner = declared_in(cand, seen)
                # An include sitting inside the RscTitles block puts everything it declares
                # inside it too -- which is the entire bug this gate exists to catch.
                in_titles = titles_depth is not None
                for k, v in inner.items():
                    out[k] = v or in_titles
                i += m.end()
                continue
        i += 1

    return out


def main():
    if not os.path.exists(DESC):
        sys.exit("dialog reachability: cannot find %s" % DESC)

    decl = declared_in(DESC)
    targets = collect_targets()

    bad, unresolved = [], []
    for name, where in sorted(targets.items()):
        if name not in decl:
            unresolved.append((name, where))
        elif decl[name]:
            bad.append((name, where))

    if unresolved:
        print("dialog reachability: %d target(s) not declared in the mission config "
              "(addon-declared or built elsewhere -- informational):" % len(unresolved))
        for n, w in unresolved:
            print("    %-28s %s" % (n, w))

    if bad:
        print()
        print("dialog reachability: %d createDialog target(s) declared INSIDE class RscTitles."
              % len(bad))
        print("createDialog resolves from config ROOT and will answer false at runtime with")
        print('"Resource <name> not found". Move the #include out of description.ext\'s')
        print("RscTitles block and into dialog/MasterHandler.h, where every working dialog is.")
        for n, w in bad:
            print("    %-28s createDialog at %s" % (n, w))
        return 1

    print("dialog reachability: %d createDialog target(s), none trapped inside RscTitles"
          % len(targets))
    return 0


if __name__ == "__main__":
    sys.exit(main())
