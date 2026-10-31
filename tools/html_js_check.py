#!/usr/bin/env python3
"""Parse-check the JavaScript in every ui/html page AND every ui/html .js asset.

Written for the deck-app wave: deck.html absorbs ~21 new views by scripted
insertion, and a bad splice would otherwise surface only as a dead phone in
game. Extracts each <script> block and runs `node --check` on the concatenation
per file. Skips silently if node is absent (the box gate is what matters).

.js assets are checked too since grid3d.js: these pages load their shared code
with A3API.RequestFile + eval (a <script src> has no base URL to resolve here),
so a syntax error in a module is not a parse error the page reports -- it is a
rejected eval and a dead screen. The file IS the script, so it is checked whole.

A run that checked NOTHING now FAILS. Printing "all ui/html scripts parse" over
an empty walk is indistinguishable from a real pass, and a wrong HTML path is
exactly how that happens -- a patched copy of this script run from a scratch
directory reported a clean pass on a file containing `function bad( {`.
"""
import os, re, subprocess, sys, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HTML = os.path.join(REPO, "mission", "Armapunk2035.Malden", "ui", "html")

def main():
    if subprocess.run(["which", "node"], capture_output=True).returncode != 0:
        print("node not present -- skipped")
        return 0
    bad, checked = [], []
    for root, _, files in os.walk(HTML):
        for fn in sorted(files):
            if not fn.endswith((".html", ".js")):
                continue
            p = os.path.join(root, fn)
            raw = open(p, encoding="utf-8", errors="replace").read()
            # A .js asset IS the script; an .html page carries its script in tags.
            js = raw if fn.endswith(".js") else "\n".join(
                re.findall(r"<script>(.*?)</script>", raw, re.S))
            if not js.strip():
                continue
            with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as t:
                t.write(js); tmp = t.name
            r = subprocess.run(["node", "--check", tmp], capture_output=True, text=True)
            os.unlink(tmp)
            checked.append(fn)
            if r.returncode != 0:
                first = (r.stderr.strip().splitlines() or ["?"])[0]
                bad.append(f"{os.path.relpath(p, REPO)}: {first}")
    if bad:
        for b in bad: print("FAIL " + b)
        return 1
    if not checked:
        print("FAIL: html_js_check found no files to check -- wrong path? " + HTML)
        return 1
    print("all ui/html scripts parse (%d: %s)" % (len(checked), ", ".join(checked)))
    return 0

if __name__ == "__main__":
    sys.exit(main())
