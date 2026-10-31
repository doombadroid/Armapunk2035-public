"""Vendor the PySQF SQF client and its diagnostics into the mission, renamed to
the APS_ convention.

Mechanical rename only -- the logic is not touched, so upstream fixes can be
re-vendored by re-running this. Every substitution is listed so a reviewer can
see there is no hand-editing hiding in here. The one exception is PATCHES below:
exact-text local edits, each asserted to match exactly once.

    python3 scratchpad/vendor_pysqf.py           re-vendor (upstream HEAD must be the pin)
    python3 scratchpad/vendor_pysqf.py --check   render the PINNED TAG in memory and fail if the
                                                 committed copy differs (run_checks.sh runs this)

The smoke test and the conformance suite are vendored the same way and for a
specific reason: they assert against Python fixtures (python/pysqf/diag.py) that
live upstream. Assertions here and fixtures there drift; keeping the assertions
upstream and generating this copy is what stops that.
"""
import pathlib, re, sys

CHECK = "--check" in sys.argv

# ── PIN (2026-08-27): upstream has an outside collaborator with WRITE now.
# Vendor only from the reviewed tag; moving the pin is a deliberate act that
# happens in this file, in a commit, after reading the upstream diff.
PINNED_TAG = "v0.2.0"
import subprocess as _sp
_head = _sp.run(["git", "-C", UPSTREAM if 'UPSTREAM' in dir() else "/home/timb/PySQF",
                 "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
_pin = _sp.run(["git", "-C", "/home/timb/PySQF", "rev-parse", PINNED_TAG + "^{commit}"],
               capture_output=True, text=True).stdout.strip()
if _head != _pin and not CHECK:   # --check reads the tag itself, so HEAD may be anywhere
    raise SystemExit(
        f"REFUSED: upstream checkout is at {_head[:9]}, the pin is {PINNED_TAG} ({_pin[:9]}).\n"
        f"Read the upstream diff, then move PINNED_TAG here to accept it.")


import os

# Repo root is this script's parent's parent (scratchpad/ lives at the top).
REPO = pathlib.Path(__file__).resolve().parent.parent
# Override with PYSQF_SRC if the upstream checkout is somewhere else.
SRC = pathlib.Path(os.environ.get("PYSQF_SRC", pathlib.Path.home() / "PySQF")) / "sqf"
DST = REPO / "server" / "AP_server" / "core" / "pysqf"
DST.mkdir(parents=True, exist_ok=True)

SUBS = [
    ("pysqf_fnc_pysqf",   "APS_fnc_pysqfRaw"),
    ("pysqf_fnc_call",    "APS_fnc_pysqfCall"),
    ("pysqf_fnc_smoke",   "APS_fnc_pysqfSmoke"),
    ("pysqf_fnc_conform", "APS_fnc_pysqfConform"),
    # Not functions: the conformance suite parks a memo cache and one
    # cross-context sentinel in missionNamespace, and those keys need the
    # mission's prefix for the same reason the functions do. Upstream they are
    # pysqf_conform_*, because a library that writes APS_* into someone else's
    # missionNamespace has taken a name it does not own.
    #
    # Named exactly rather than as one broad `pysqf_conform_` prefix. That
    # shorter form also matches the deliberately-nonexistent SQL table
    # `pysqf_conform_no_such_table_9x7` in the db group, and rewriting an SQL
    # identifier while renaming SQF variables is precisely the silent edit this
    # script exists to make impossible.
    ("pysqf_conform_memo_",   "APS_pysqfConform_memo_"),
    ("pysqf_conform_unsched", "APS_pysqfConform_unsched"),
]

# AP-local edits, applied after the renames. Each must match EXACTLY ONCE, so an upstream change to
# the patched text fails the vendor loudly instead of silently shipping it unpatched.
PATCHES = {
    "fn_pysqfCall.sqf": [
        # No global timeout override (audit srvdb-0-0). pysqf_timeout was a plain missionNamespace global
        # read on every call, and any client can publicVariable one onto the server: a tiny value fails
        # every DB query, a string throws. A caller still passes its own _timeout per call.
        ('_timeout = if (isNil "pysqf_timeout") then { PYSQF_DEF_TIMEOUT } else { pysqf_timeout };',
         '_timeout = PYSQF_DEF_TIMEOUT;   // AP: no pysqf_timeout global override (client-publishable) -- see vendor_pysqf.py PATCHES'),
        ("Default 10, or pysqf_timeout if set.", "Default 10."),
    ],
}

FILES = {
    "fn_pysqf.sqf":        "fn_pysqfRaw.sqf",
    "fn_pysqfCall.sqf":    "fn_pysqfCall.sqf",
    "fn_pysqfSmoke.sqf":   "fn_pysqfSmoke.sqf",
    "fn_pysqfConform.sqf": "fn_pysqfConform.sqf",
}

BANNER = (
    "/*  VENDORED from the PySQF repo -- do not hand-edit.\n"
    "    Re-vendor with scratchpad vendor_pysqf.py after pulling upstream.\n"
    "    Renamed for this mission's convention: APS_ = owned by the server addon,\n"
    "    which matters because the server compiles both CfgFunctions trees into\n"
    "    missionNamespace and a shared name silently overwrites.\n"
    "    Upstream name: %s  */\n"
)

def pattern(old):
    """Match `old` as a whole identifier, or as a prefix if it ends in `_`.

    A trailing `\\b` after an underscore never matches what it is meant to:
    `_` is a word character, so `\\bpysqf_conform_\\b` requires a NON-word
    character next and so skips every `pysqf_conform_memo_*` it exists to
    catch. Leaving the boundary off entirely is not the fix either -- then
    `pysqf_fnc_call` would rewrite the inside of `pysqf_fnc_callback`. So the
    trailing boundary is dropped only for entries that are explicitly prefixes.
    """
    return r"\b%s" % re.escape(old) if old.endswith("_") else r"\b%s\b" % re.escape(old)


drift = []
for src_name, dst_name in FILES.items():
    if CHECK:
        text = _sp.run(["git", "-C", str(SRC.parent), "show", f"{PINNED_TAG}:sqf/{src_name}"],
                       capture_output=True, text=True, check=True).stdout
    else:
        text = (SRC / src_name).read_text(encoding="utf-8")
    counts = []
    for old, new in SUBS:
        text, n = re.subn(pattern(old), new, text)
        if n:
            counts.append(f"{old}*{n}")
    for old, new in PATCHES.get(src_name, []):
        if text.count(old) != 1:
            raise SystemExit(f"PATCH REFUSED: {src_name} has {text.count(old)} copies of {old!r}, expected 1")
        text = text.replace(old, new)
    out = BANNER % src_name + text
    if CHECK:
        dst = DST / dst_name
        if not dst.exists() or dst.read_text(encoding="utf-8") != out:
            drift.append(dst_name)
        continue
    (DST / dst_name).write_text(out, encoding="utf-8")
    print(f"{src_name:20s} -> {dst_name:20s} {' '.join(counts) or '(no renames)'}")
if CHECK:
    if drift:
        raise SystemExit(f"DRIFT: {', '.join(drift)} differ from PySQF {PINNED_TAG} -- re-run scratchpad/vendor_pysqf.py")
    print(f"vendored PySQF matches {PINNED_TAG}")

# Prove no upstream name survived. This is the check that turns a missed
# substitution into a line of vendoring output instead of an undefined function
# at runtime, so it has to use the same matcher the substitution did.
leftovers = []
for p in sorted(DST.glob("*.sqf")):
    t = p.read_text(encoding="utf-8")
    for old, _ in SUBS:
        # the banner legitimately names the upstream FILE, not the function
        for m in re.finditer(pattern(old), t):
            leftovers.append(f"{p.name}: {old} at {m.start()}")
print("leftover upstream names:", leftovers or "none")
