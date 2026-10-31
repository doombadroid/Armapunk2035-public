#!/usr/bin/env python3
"""hudlayout_parity.py -- the HUD UI EDITOR's stylesheet exists twice. Keep the copies identical.

The status HUD's saved layout (hudeditor.md) is applied by two different files, in two different
languages, to the same page:

    mission/Armapunk2035.Malden/core/web/fn_hudLayoutApply.sqf   the LIVE title layer
    mission/Armapunk2035.Malden/ui/html/hudedit.js               the EDITOR dialog

They have to emit the same CSS or a layout renders one way while it is being dragged and another
way once it is saved -- and that failure is invisible until somebody notices their plates are a
few rem off where they left them, with nothing in any log to say why.

There is no way to merge them: one is SQF running on the client and the other is JavaScript
running inside the page, and the editor needs its rules present before it has ever spoken to SQF.
So they stay duplicated and this asserts the duplication is exact.

Exit 0 if the RULES and PIN blocks match character for character, 1 otherwise.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQF = os.path.join(ROOT, "mission/Armapunk2035.Malden/core/web/fn_hudLayoutApply.sqf")
JS = os.path.join(ROOT, "mission/Armapunk2035.Malden/ui/html/hudedit.js")

# SQF has no backslash escape and doubles a quote to embed one; neither appears in this CSS, so a
# plain non-greedy literal scan is exact here rather than approximately right.
SQF_LIT = re.compile(r'\+\s*"((?:[^"]|"")*)"')
JS_LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')


def between(text, start, end, what, path):
    if start not in text:
        sys.exit("%s: cannot find %r in %s" % (what, start, path))
    tail = text.split(start, 1)[1]
    if end not in tail:
        sys.exit("%s: cannot find %r after it in %s" % (what, end, path))
    return tail.split(end, 1)[0]


def main():
    sqf = open(SQF, encoding="utf-8").read()
    js = open(JS, encoding="utf-8").read()

    sqf_rules = "".join(SQF_LIT.findall(
        between(sqf, '_css = ":root{" + _vars + "}"', "if (_breakout)", "SQF rules", SQF)))
    sqf_pin = "".join(SQF_LIT.findall(
        between(sqf, "if (_breakout) then {", "};", "SQF pin", SQF)))

    # The JS statement ends at a quote FOLLOWED by a semicolon. A bare ";" would stop at the first
    # one inside the CSS (transform-origin:...;transform:...) and scan an empty block -- which the
    # emptiness check below would then flag as a broken scan rather than let pass.
    js_rules = "".join(JS_LIT.findall(between(js, "var RULES =", '";', "JS rules", JS) + '"'))
    js_pin = "".join(JS_LIT.findall(between(js, "var PIN =", '";', "JS pin", JS) + '"'))

    bad = False
    for name, a, b in (("RULES", sqf_rules, js_rules), ("PIN", sqf_pin, js_pin)):
        if not a or not b:
            print("hudlayout parity: %s block came out EMPTY on the %s side -- the scan is "
                  "broken, not the code" % (name, "SQF" if not a else "JS"))
            bad = True
        elif a != b:
            print("hudlayout parity: %s differs between the two emitters" % name)
            print("  fn_hudLayoutApply.sqf: %s" % a)
            print("  hudedit.js           : %s" % b)
            bad = True

    if bad:
        return 1
    print("hudlayout parity: RULES and PIN identical in both emitters")
    return 0


if __name__ == "__main__":
    sys.exit(main())
