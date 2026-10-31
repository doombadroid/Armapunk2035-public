#!/usr/bin/env python3
"""Block-aware CfgFunctions audit (two-pass).

`file = "..."` is a class ATTRIBUTE and applies to the whole block regardless of declaration
order, so resolution must happen AFTER the tree is built -- a single in-order pass wrongly
flags members declared above their own block's file= line.
"""
import os, re, sys

TOK = re.compile(r'class\s+(\w+)|(\{)|(\})|file\s*=\s*"([^"]+)"')

def build(src):
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    src = re.sub(r'//[^\n]*', '', src)
    root = {"name": None, "line": 0, "file": None, "kids": []}
    stack, pending = [root], None
    for m in TOK.finditer(src):
        line = src[:m.start()].count("\n") + 1
        cls, lb, rb, fv = m.groups()
        if cls:
            pending = (cls, line)
        elif lb:
            n = {"name": pending[0] if pending else None,
                 "line": pending[1] if pending else line, "file": None, "kids": []}
            pending = None
            stack[-1]["kids"].append(n); stack.append(n)
        elif fv:
            stack[-1]["file"] = fv.replace("\\", "/").lstrip("/")
        elif rb and len(stack) > 1:
            stack.pop()
    return root

def resolve(node, root_dir, inherited, out, strip):
    d = node["file"] or inherited
    if node["name"] and not node["kids"] and not node["file"]:
        if d is None:
            out.append((node["line"], node["name"], "<no file= in any ancestor>")); return
        rel = d[len(strip):].lstrip("/") if strip and d.startswith(strip) else d
        if not os.path.exists(os.path.join(root_dir, rel, "fn_%s.sqf" % node["name"])):
            out.append((node["line"], node["name"], "%s/fn_%s.sqf" % (rel, node["name"])))
        return
    for k in node["kids"]:
        resolve(k, root_dir, d, out, strip)

def audit(cfg, root_dir, label, strip=""):
    out = []
    resolve(build(open(cfg, errors="ignore").read()), root_dir, None, out, strip)
    out = [x for x in out if x[1] != "BIS_AddonInfo"]
    print("== %s: %d unresolved" % (label, len(out)))
    for i, n, p in out:
        print("   line %d: class %s -> %s" % (i, n, p))
    return out

def declared(cfg):
    """Every leaf class name in the config, i.e. every function it declares."""
    names, stack = set(), [build(open(cfg, errors="ignore").read())]
    while stack:
        n = stack.pop()
        if n["name"] and not n["kids"]:
            names.add(n["name"].lower())
        stack.extend(n["kids"])
    return names

# Unregistered files that were ALREADY unregistered when this check was written
# (2026-08-14). Each one is a function that does not exist at runtime; none has
# been examined yet, so they are recorded rather than fixed, and the check fails
# only on something NEW. Shrink this list, never grow it.
BASELINE = {
    "core/config/fn_vehicleModConfig.sqf",
    "core/functions/fn_inString.sqf",
    "core/gangfort/fn_captureGangFort.sqf",
    "core/gangfort/fn_gangBoatHud.sqf",
    "core/gangfort/fn_gangFortHud.sqf",
    "core/gangfort/fn_initGangBoatClient.sqf",
    "core/gangfort/fn_initGangFortClient.sqf",
    "core/gov/fn_payGovTax.sqf",
    "core/shops/fn_vehicleSkinShopMenu.sqf",
}

def orphans(cfg, root_dir, label, dirs):
    """The OTHER direction: an fn_*.sqf that no CfgFunctions entry declares.

    The forward audit catches a declaration with no file behind it -- a typo, a
    deleted script. This catches the opposite and far quieter failure: the file
    ships inside the PBO, the config never names it, so the function simply does
    not exist at runtime. Nothing errors at build or boot; the first CALLER gets
    "undefined variable", which in a dialog onLoad means the screen opens, the
    page boots its own half of the bridge, and every call it makes times out with
    no cause on screen. That cost a debugging session on 2026-08-14 (the STAFF
    DECK's staffOpen/staffAct, dropped when the branch was replayed onto main).
    """
    have = declared(cfg)
    out = []
    for d in dirs:
        for dirpath, _, files in os.walk(os.path.join(root_dir, d)):
            for f in files:
                if not (f.startswith("fn_") and f.endswith(".sqf")):
                    continue
                if f[3:-4].lower() not in have:
                    out.append(os.path.relpath(os.path.join(dirpath, f), root_dir))
    out.sort()
    fresh = [p for p in out if p.replace(os.sep, "/") not in BASELINE]
    print("== %s: %d unregistered fn_*.sqf (%d new, %d known)"
          % (label, len(out), len(fresh), len(out) - len(fresh)))
    for p in out:
        print("   %s%s" % (p, "" if p.replace(os.sep, "/") in BASELINE else "   <-- NEW"))
    return fresh

if __name__ == "__main__":
    base = sys.argv[1] if len(sys.argv) > 1 else "."
    M = os.path.join(base, "mission/Armapunk2035.Malden")
    bad = audit(os.path.join(M, "Functions.h"), M, "mission/Functions.h")
    S = os.path.join(base, "server/AP_server")
    # CfgMovesFatigue is a CfgMoves class that happens to live in config.cpp, not a
    # function -- it has no fn_ file by design.
    bad += [x for x in audit(os.path.join(S, "config.cpp"), S, "server/config.cpp", strip="AP_server")
            if x[1] != "CfgMovesFatigue"]
    bad += orphans(os.path.join(M, "Functions.h"), M, "mission/Functions.h", ["core", "evh", "npcs"])
    bad += orphans(os.path.join(S, "config.cpp"), S, "server/config.cpp", ["core"])
    sys.exit(1 if bad else 0)

