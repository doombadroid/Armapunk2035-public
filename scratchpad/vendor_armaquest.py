#!/usr/bin/env python3
"""Vendor ~/ArmaQuest into the mission as a byte-identical copy.

The copy is byte-identical on purpose, so a local edit is not silently
discarded the way an edit to a generated file would be. The discipline is
directional instead: change the library upstream, then re-run this.
VENDORED.txt records which upstream commit the tree corresponds to, so a
divergence is answerable rather than guessed at.

EXCEPT IT WAS SILENTLY DISCARDED, on 2026-08-30, which is why the divergence
check below exists. "Byte-identical on purpose" described the intent and not
the tree: fn_storeSql.sqf and fn_srvInit.sqf had been edited in place by the
PostgreSQL sweep -- SELECT QUOTE(data) -> SELECT data, ON DUPLICATE KEY UPDATE
-> ON CONFLICT, and the spawn-and-carry fix for the unscheduled disconnect
flush -- because upstream's declared dialect is MariaDB and this host no longer
has one. A routine re-vendor reverted all three in one rmtree, and nothing said
so. The only reason it was caught is that `git status` was read afterwards.

So the banner is not enough, and neither is the recorded commit: a hash nobody
compares is a comment. This now DIFFS the destination against the commit
VENDORED.txt names before it overwrites anything, and refuses if the tree has
been edited locally. --force overwrites anyway, for when the local edit has
genuinely been carried upstream and is meant to go.

The real fix is to make the store dialect-aware upstream so this host stops
needing local edits at all. Until that happens, this check is what stands
between a re-vendor and a silently broken quest store.
"""
import argparse
import hashlib
import pathlib
import shutil
import subprocess
import sys

SRC = pathlib.Path.home() / "ArmaQuest"
DST = pathlib.Path(__file__).resolve().parent.parent / "mission/Armapunk2035.Malden/ArmaQuest"
COPY = ("config", "functions", "server", "types", "diagnostics", "ui")


def vendored_commit() -> str:
    """The commit VENDORED.txt claims the current tree came from, or ""."""
    f = DST / "VENDORED.txt"
    if not f.is_file():
        return ""
    for line in f.read_text(encoding="utf-8").splitlines():
        if line.startswith("commit:"):
            return line.split(":", 1)[1].strip()
    return ""


def local_edits(base: str) -> list:
    """Vendored files whose bytes differ from `base`'s version of them.

    Compared against the ORIGINAL commit rather than against upstream HEAD,
    because a difference from HEAD is expected -- that is what re-vendoring is
    for. A difference from the commit this tree was cut from is not: it is
    somebody having edited the copy.
    """
    if not base or not DST.is_dir():
        return []
    out = []
    for p in sorted(DST.rglob("*")):
        if not p.is_file() or p.name == "VENDORED.txt":
            continue
        rel = p.relative_to(DST).as_posix()
        r = subprocess.run(["git", "-C", str(SRC), "show", f"{base}:{rel}"],
                           capture_output=True)
        if r.returncode != 0:
            out.append((rel, "not present in " + base[:12]))
        elif r.stdout != p.read_bytes():
            out.append((rel, "edited in place"))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--force", action="store_true",
                    help="overwrite even if the vendored tree has local edits")
    ap.add_argument("--check", action="store_true",
                    help="report local edits and exit; copy nothing")
    args = ap.parse_args()

    if not SRC.is_dir():
        print(f"upstream missing: {SRC}", file=sys.stderr)
        return 1
    sha = subprocess.run(
        ["git", "-C", str(SRC), "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    dirty = subprocess.run(
        ["git", "-C", str(SRC), "status", "--porcelain"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    if dirty:
        print("REFUSING: upstream has uncommitted changes; commit them first so "
              "VENDORED.txt names something real:\n" + dirty, file=sys.stderr)
        return 1

    base = vendored_commit()
    if not base:
        print("WARNING: VENDORED.txt names no commit, so local edits to the "
              "vendored tree cannot be detected. Proceeding blind.", file=sys.stderr)
    edits = local_edits(base)
    if edits:
        print("The vendored tree has been EDITED IN PLACE since %s:" % base[:12],
              file=sys.stderr)
        for rel, why in edits:
            print("    %-46s %s" % (rel, why), file=sys.stderr)
        print("\nOverwriting would revert those edits and say nothing -- which is\n"
              "exactly how the PostgreSQL store fixes were lost once already.\n"
              "Carry them upstream first, or re-run with --force if they are\n"
              "already there and are meant to be replaced.", file=sys.stderr)
        if not args.force:
            return 1
        print("--force given; overwriting anyway.", file=sys.stderr)
    if args.check:
        if not edits:
            print("vendored tree matches %s -- no local edits." % base[:12])
        return 1 if edits else 0

    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir(parents=True)

    n = 0
    for sub in COPY:
        s = SRC / sub
        if not s.is_dir():
            print(f"upstream is missing {sub}/", file=sys.stderr)
            return 1
        shutil.copytree(s, DST / sub)
        n += sum(1 for _ in (DST / sub).rglob("*") if _.is_file())
    shutil.copy2(SRC / "LICENSE", DST / "LICENSE")

    digest = hashlib.sha256()
    for p in sorted(DST.rglob("*")):
        if p.is_file() and p.name != "VENDORED.txt":
            digest.update(p.relative_to(DST).as_posix().encode())
            digest.update(p.read_bytes())
    (DST / "VENDORED.txt").write_text(
        f"upstream: https://github.com/doombadroid/ArmaQuest\n"
        f"commit:   {sha}\n"
        f"files:    {n}\n"
        f"tree:     sha256:{digest.hexdigest()}\n"
        f"\nDo not edit this tree. Change the library upstream and re-run\n"
        f"scratchpad/vendor_armaquest.py.\n"
    )
    print(f"vendored {n} files from {sha[:12]} -> {DST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
