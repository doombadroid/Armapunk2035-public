#!/usr/bin/env python3
"""
LooneyBin pre-deploy REGRESSION GUARD  (owner 2026-07-14, after the b0166 cascade).

WHY: the deploy packs a LOOSE source tree into a PBO. If that source tree is BEHIND the
currently-deployed PBO (files missing, or shrunk because git-synced source clobbered on-box
edits), the pack silently ships a REGRESSION -> client-side config cascade (shops/houses/
admin/dialogs all break, as happened at b0166). Nothing caught it.

WHAT: before packing, diff the source tree about to be packed against the CURRENTLY-DEPLOYED
PBO (the one run-boot2 is about to archive). ABORT if core files vanished or shrank past a
threshold. This makes "packed a stale/behind tree" a hard stop, not a silent outage.

USAGE:  predeploy_guard.py <source_mission_dir> <current_deployed_pbo>
        exit 0 = safe (or PBO unreadable/first deploy -> warn+pass); exit 3 = REGRESSION -> abort.
Override in run-boot2 with DEPLOY_GUARD_OVERRIDE=1 for an intentional shrink (rare).
"""
import os, sys, struct, re

# Files whose shrink/removal is a near-certain cascade. Path uses PBO-internal backslashes.
# (The b0166 disaster shrank exactly these kinds of files: dialog includes, remoteExec whitelist,
#  function registrations, config globals, shop defs.)
CRITICAL = {
    "cfgre.hpp", "functions.h", "description.ext",
    r"dialog\masterhandler.h", r"core\configuration.sqf",
    r"core\config\fn_virt_shops.sqf", r"core\admin\fn_adminmenu.sqf",
    r"dialog\admin_menu.hpp",
}
# The real b0166 regression was NOT one dramatic shrink -- it was SIX core files each shrinking
# 5-15% at once (git-synced source was behind on-box). So: flag ANY critical shrink >100B, and
# ABORT when MULTIPLE critical files shrink together (the regression fingerprint), a single file
# shrinks dramatically, or any critical file vanished outright.
SHRINK_MIN   = 100     # bytes; ignore <100B wobble (a comment tweak)
BIG_SHRINK   = 0.20    # a single critical file >=20% smaller -> abort on its own
MULTI_ABORT  = 2       # >=2 critical files shrank at once -> abort (b0166 had 6)

def pbo_manifest(fn):
    """path(lower, backslashes) -> original size, from the PBO header table."""
    d = open(fn, "rb").read(); off = 0
    e = d.find(b"\x00", off); off = e + 1
    pk, orig, res, ts, ds = struct.unpack("<5I", d[off:off+20]); off += 20
    if pk == 0x56657273:                      # 'Vers' product entry -> consume property strings
        while True:
            e = d.find(b"\x00", off); s = d[off:e]; off = e + 1
            if s == b"": break
    out = {}
    while True:
        e = d.find(b"\x00", off)
        nm = d[off:e].decode("latin-1", "replace"); off = e + 1
        pk, orig, res, ts, ds = struct.unpack("<5I", d[off:off+20]); off += 20
        if nm == "" and ds == 0: break
        out[nm.lower()] = ds
    return out

def src_manifest(root):
    out = {}
    for dp, _, fs in os.walk(root):
        for f in fs:
            full = os.path.join(dp, f)
            rel = os.path.relpath(full, root).replace("/", "\\").lower()
            try: out[rel] = os.path.getsize(full)
            except OSError: pass
    return out

def _mission_blob(src_dir):
    """Lowercased concat of all mission script/config text = the 'is this name referenced anywhere' corpus."""
    exts = (".sqf", ".hpp", ".h", ".ext", ".cpp", ".inc")
    parts = []
    for dp, _, fs in os.walk(src_dir):
        for f in fs:
            if f.lower().endswith(exts):
                try:
                    with open(os.path.join(dp, f), "r", encoding="latin-1", errors="replace") as fh:
                        parts.append(fh.read().lower())
                except OSError:
                    pass
    return "\n".join(parts)

def obf_orphan_check(src_dir):
    """
    Catch the market/capture (2026-07-18) class of SILENT breakage.

    The on-box tree is name-obfuscated: a digit is inserted into function names, and Functions.h
    `class market`->`class mark1et` moves TOGETHER with fn_market.sqf->fn_mark1et.sqf, so AP_fnc_mark1et
    still resolves and the function works. BUT the obfuscator is blind to function names inside STRING
    LITERALS -- phone-button actions ("[] spawn AP_fnc_market"), addAction / ctrlAddEventHandler strings,
    string-form remoteExec. Those keep the CLEAN name. Result: the definition becomes AP_fnc_mark1et while
    the (string) caller still says AP_fnc_market -> UNDEFINED -> `[] spawn nil` = silent no-op (menu never
    opens, NO -SCRIPTERR-). market + captures shipped broken this way and went unnoticed for weeks.

    Fingerprint (near-zero false positive): a Functions.h class name containing a digit whose AP_fnc_<name>
    is CALLED NOWHERE, while its digit-stripped twin AP_fnc_<clean> IS called somewhere. That twin caller is
    hitting an undefined function. (Legit obfuscated fns are called via their digit-name in obfuscated code, so
    they're not orphans; legit digit-names like CH7 / deleteP3DObjects have no called clean twin, so they pass.)
    """
    fh = os.path.join(src_dir, "Functions.h")
    if not os.path.exists(fh):
        return []
    with open(fh, "r", encoding="latin-1", errors="replace") as f:
        classes = re.findall(r"class\s+([A-Za-z0-9_]+)\s*\{", f.read())
    blob = _mission_blob(src_dir)
    def called(name):
        return re.search(r"AP_fnc_" + re.escape(name.lower()) + r"(?![a-z0-9_])", blob) is not None
    flags = []
    for name in sorted(set(classes)):
        if not any(ch.isdigit() for ch in name):
            continue
        if called(name):
            continue                                  # obfuscated def has a real caller -> fine
        clean = re.sub(r"\d", "", name)
        if not clean or clean == name:
            continue
        if called(clean):                             # clean twin IS called -> that caller is broken
            flags.append((name, clean))
    return flags

def main():
    if len(sys.argv) < 3:
        print("[guard] usage: predeploy_guard.py <src_dir> <deployed_pbo>"); return 0
    src_dir, pbo = sys.argv[1], sys.argv[2]
    # --- Obfuscation-orphan check (market/capture signature). Needs only the source tree, so run it FIRST,
    #     before the PBO-size regression logic; returns rc 3 (hard-block) just like a regression. ---
    if not src_dir.lower().endswith(".pbo"):
        orphans = obf_orphan_check(src_dir)
        if orphans:
            print("[guard] *** OBFUSCATION-ORPHAN DETECTED -- a function definition and its caller drifted apart ***")
            for obf, clean in orphans:
                print(f"[guard]   ORPHAN: Functions.h defines 'class {obf}' (AP_fnc_{obf}) but it is CALLED NOWHERE,")
                print(f"[guard]           while AP_fnc_{clean} IS called -> that caller hits an UNDEFINED fn (silent no-op).")
                print(f"[guard]           FIX: rename 'class {obf}'->'class {clean}' in Functions.h AND fn_{obf}.sqf->fn_{clean}.sqf.")
            print("[guard] Signature = name-obfuscation blind to string-literal calls (the market/capture 2026-07-18 bug).")
            print("[guard] Deploy ABORTED. If genuinely intentional, re-run with DEPLOY_GUARD_OVERRIDE=1.")
            return 3
    if not pbo or not os.path.exists(pbo):
        print(f"[guard] no prior deployed PBO ({pbo!r}) -> first deploy, skipping guard."); return 0
    try:
        dep = pbo_manifest(pbo)
    except Exception as ex:
        print(f"[guard] WARN: could not parse {pbo} ({ex}); skipping guard."); return 0
    # source may be a loose dir (normal) OR a .pbo (for validating/comparing two builds)
    src = pbo_manifest(src_dir) if src_dir.lower().endswith(".pbo") else src_manifest(src_dir)

    missing, shrunk, big = [], [], []
    for path, dsize in dep.items():
        if path not in CRITICAL:
            continue
        ssize = src.get(path)
        if ssize is None:
            missing.append((path, dsize)); continue
        if dsize - ssize > SHRINK_MIN:
            shrunk.append((path, dsize, ssize))
            if ssize < dsize * (1 - BIG_SHRINK):
                big.append((path, dsize, ssize))

    abort = bool(missing) or bool(big) or (len(shrunk) >= MULTI_ABORT)
    if abort:
        print("[guard] *** REGRESSION DETECTED -- source is BEHIND the deployed PBO ***")
        for path, d in missing:
            print(f"[guard]   CRITICAL-MISSING: {path}  (deployed={d}B, gone from source)")
        for path, d, s in shrunk:
            flag = "CRITICAL-SHRUNK-BIG" if (path, d, s) in big else "CRITICAL-SHRUNK"
            print(f"[guard]   {flag}: {path}  deployed={d}B  source={s}B  (-{d-s}B, -{100*(d-s)//d}%)")
        why = []
        if missing: why.append(f"{len(missing)} core file(s) vanished")
        if big:     why.append(f"{len(big)} core file(s) shrank >={int(BIG_SHRINK*100)}%")
        if len(shrunk) >= MULTI_ABORT: why.append(f"{len(shrunk)} core files shrank at once (b0166 fingerprint)")
        print(f"[guard] Reason: {'; '.join(why)}.")
        print("[guard] Deploy ABORTED -- this is the b0166 cascade signature (git-behind-onbox).")
        print("[guard] If this shrink is INTENTIONAL (real rollback/refactor), re-run with DEPLOY_GUARD_OVERRIDE=1.")
        return 3
    if shrunk:
        print(f"[guard] OK (with note): 1 core file shrank <{int(BIG_SHRINK*100)}% -- below multi-file abort threshold:")
        for path, d, s in shrunk:
            print(f"[guard]   note: {path} -{d-s}B")
    print("[guard] OK: no critical-file regression vs deployed PBO.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
