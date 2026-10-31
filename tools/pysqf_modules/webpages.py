"""Serve UI page markup to the game, off the server's disk.

    ["webpages.read", ["ui/html/deck.html"]] call APS_fnc_pysqfCall

WHY THIS EXISTS AT ALL. The obvious way for the server to read a page is
`loadFile`, and on this server that command is disabled -- the engine answers
`Trying to execute a disabled command 'loadfile'` and returns nothing. That was
measured on the dev server (b0638, 2026-08-18), not assumed, and it is what
sent this through PySQF instead.

Reading off DISK rather than out of an addon turns out to be the better answer
anyway. An addon copy still has to be repacked and the server restarted to ship
a UI change. A file on disk does not: edit it, and the next time a player opens
that screen they get the new markup. No mission repack, so no 230 MB client
re-download, and no server restart either.

SAFETY

    Every path is resolved and then checked to be inside ROOT. A path that
    escapes -- via .., a symlink, an absolute path, anything -- is refused
    rather than normalised, because normalising an attacker-supplied path is
    how directory traversal ships. The caller (APS_fnc_webPageSRV) checks too;
    this is the check that actually owns the filesystem.

    Only .html/.js/.css are readable. This directory is a publishing directory,
    and the whole point of it is that its bytes are sent to clients, so nothing
    else belongs in it and nothing else will be handed out of it.

    Read-only. There is no write verb here on purpose: a write verb reachable
    from the game would let anything that can reach the server's script layer
    author the UI everyone loads.

FAILURE IS NOT AN ERROR. A missing page returns "" and the caller treats that
as "no override", leaving the client on the copy in its mission PBO. That is
the designed fallback for the whole feature, so it must not raise.
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path

import pysqf

# Where the servable pages live.
#
# Derived from THIS FILE's location, not hardcoded: the module sits at
# <repo>/tools/pysqf_modules/webpages.py, so the repo root is two levels up and
# the page tree hangs off that. An absolute checkout path baked in here would be
# correct on exactly one machine and would break silently on a merge, a second
# worktree, or anyone else's clone -- and "breaks silently" here means every page
# override quietly stops happening, which is indistinguishable from the feature
# being off.
#
# AP_WEBPAGES_ROOT still wins, for a server whose pages live somewhere else
# entirely (a deploy tree, a separate content checkout).
_DEFAULT_ROOT = Path(__file__).resolve().parents[2] / "server" / "AP_server" / "web"
ROOT = Path(os.environ.get("AP_WEBPAGES_ROOT", _DEFAULT_ROOT)).resolve()

# The mission tree this repo packs into the PBO -- the copy every client already
# holds. serve() compares against it so that the common state, "nothing has been
# edited since the deploy", costs a client no bytes and no document rewrite.
# Same derivation rule as ROOT; AP_WEBPAGES_BASELINE overrides it.
_DEFAULT_BASELINE = Path(__file__).resolve().parents[2] / "mission" / "Armapunk2035.Malden"
BASELINE = Path(os.environ.get("AP_WEBPAGES_BASELINE", _DEFAULT_BASELINE)).resolve()

ALLOWED_SUFFIXES = {".html", ".js", ".css"}
MAX_BYTES = 900_000  # engine "Inflate" caps its OUTPUT at 1 MB; stay under it


def _resolve(rel: str) -> Path | None:
    """rel -> an absolute path inside ROOT, or None if it does not belong to us."""
    if not rel or len(rel) > 200:
        return None
    # The game speaks Windows-style paths; normalise before anything else looks
    # at the string, so a check cannot be fooled by the separator that was used.
    rel = rel.replace("\\", "/").lstrip("/")
    if Path(rel).suffix.lower() not in ALLOWED_SUFFIXES:
        return None
    target = (ROOT / rel).resolve()
    # resolve() has already followed symlinks, so this catches those too.
    if target != ROOT and ROOT not in target.parents:
        return None
    return target


@pysqf.export
def read(rel: str) -> str:
    """Page markup, or "" when there is nothing to serve."""
    target = _resolve(rel)
    if target is None:
        return ""
    try:
        if not target.is_file():
            return ""
        if target.stat().st_size > MAX_BYTES:
            return ""
        return target.read_text(encoding="utf-8")
    except OSError:
        return ""


@pysqf.export
def stamp(rel: str) -> str:
    """`<mtime>:<size>` for a page, or "" -- a cheap version tag.

    Lets a client say what it already has so an unchanged page costs a string
    comparison instead of shipping the bytes again.
    """
    target = _resolve(rel)
    if target is None:
        return ""
    try:
        st = target.stat()
        return f"{int(st.st_mtime)}:{st.st_size}"
    except OSError:
        return ""


@pysqf.export
def available() -> bool:
    """Is the page root actually there? Called once at boot to log the answer."""
    try:
        return ROOT.is_dir()
    except OSError:
        return False


def _read_exact(target: Path) -> bytes | None:
    """The file's bytes, or None when there is nothing to serve. No newline
    translation: what the client compares and rewrites must be the file."""
    try:
        if not target.is_file():
            return None
        if target.stat().st_size > MAX_BYTES:
            return None
        return target.read_bytes()
    except OSError:
        return None


def _baseline_bytes(rel: str) -> bytes | None:
    """The mission copy of a page (what the PBO carries), or None if absent."""
    rel = rel.replace("\\", "/").lstrip("/")
    target = (BASELINE / rel).resolve()
    if target != BASELINE and BASELINE not in target.parents:
        return None
    try:
        if not target.is_file():
            return None
        return target.read_bytes()
    except OSError:
        return None


@pysqf.export
def serve(rel: str, have: str = "") -> list:
    """[status, markup, version] -- the page a client should apply, if any.

        status "unchanged"  the client already has these bytes; markup is "".
        status "page"       apply markup; version identifies it for next time.
        status ""           nothing to serve (missing, refused, oversized).

    `have` is the version the client got with its last reply for this page
    ("" if it never had one). A matching version is answered "unchanged"
    without reading the page into the game at all. With no version, the file
    is compared byte-for-byte against the mission BASELINE: identical means the
    client's PBO copy already IS this page, so a rewrite would only re-boot the
    screen for nothing -- and that is the state every deploy leaves behind.

    A stale `have` always ships the page, even when the file matches the
    baseline: the client is holding a cached override that is older than the
    file, and the reply is what corrects that cache.
    """
    target = _resolve(rel)
    if target is None:
        return ["", "", ""]
    data = _read_exact(target)
    if data is None:
        return ["", "", ""]
    version = hashlib.sha1(data).hexdigest()
    if have:
        if have == version:
            return ["unchanged", "", version]
    elif _baseline_bytes(rel) == data:
        return ["unchanged", "", version]
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return ["", "", ""]
    return ["page", text, version]
