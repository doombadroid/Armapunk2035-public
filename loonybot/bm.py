#!/usr/bin/env python3
"""
bm.py  --  minimal BattleMetrics REST client (stdlib only: urllib).

CLANKR uses this to mirror the LooneyBin `bans` table into a BattleMetrics organization:
a ban there is recorded in the dashboard AND enforced at the BattlEye-RCON level (BM kicks the
identity on its next connect, independent of the in-game `bans` table). Synchronous, no deps.

Bans are keyed on BOTH the player's Steam64 AND the BattlEye GUID computed locally from it
(md5("BE" + steam64_le_u64)) -> BM can enforce even a player it has never indexed.

CLI:  python bm.py <token>            # verify token -> print org + ban-list ids it can see
      python bm.py guid <steam64>     # print the BE GUID for a Steam64
"""
import json, hashlib, struct, urllib.request, urllib.error

API = "https://api.battlemetrics.com"


def be_guid(steam64):
    """BattlEye GUID for an Arma player from their Steam64:  md5('BE' + steamid as LE u64)."""
    return hashlib.md5(b"BE" + struct.pack("<Q", int(steam64))).hexdigest()


def _request(method, path, token, body=None, timeout=12):
    """Returns (status, parsed_json). status 0 = transport/network failure (transient -> caller retries)."""
    url = path if path.startswith("http") else (API + path)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token)
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read().decode("utf-8", "replace")
            return getattr(r, "status", r.getcode()), (json.loads(raw) if raw.strip() else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = {"_raw": raw}
        return e.code, parsed
    except Exception as e:
        return 0, {"_err": str(e)}


def _msg(js):
    """Best-effort human error string out of a JSON:API error body."""
    try:
        errs = js.get("errors")
        if errs:
            parts = []
            for e in errs:
                m = e.get("detail") or e.get("title") or e.get("message") or "?"
                p = e.get("instancePath") or (e.get("source") or {}).get("pointer")
                parts.append(f"{p}: {m}" if p else m)
            return "; ".join(parts)
    except Exception:
        pass
    return (json.dumps(js) if isinstance(js, dict) else str(js))[:300]


def discover_ids(token):
    """(org_id, banlist_id, err). Pulls the token's first ban list + its org. Empty ids on failure."""
    st, js = _request("GET", "/ban-lists", token)
    if st != 200:
        return "", "", f"HTTP {st}: {_msg(js)}"
    for item in (js.get("data") or []):
        bl = item.get("id")
        org = ((((item.get("relationships") or {}).get("organization") or {}).get("data")) or {}).get("id")
        if bl and org:
            return org, bl, ""
    return "", "", "token sees no ban lists (check ban-list:read scope, or set ids in config)"


def create_ban(token, org_id, banlist_id, steam64, reason, expires_iso=None,
               timestamp_iso=None, note="", uid=None, native=None):
    """
    POST /bans. Returns (ok, info).
      ok=True  -> created (info = BM ban id) or already existed (info = 'exists')
      ok=False -> info = 'HTTP <code>: <msg>'  (code 0 = network; 5xx/429 = transient)
    """
    ids = [{"type": "steamID", "identifier": str(steam64), "manual": True}]
    try:
        ids.append({"type": "BEGUID", "identifier": be_guid(steam64), "manual": True})
    except Exception:
        pass
    attrs = {
        "timestamp": timestamp_iso,
        "reason": (reason or "CLANKR ban")[:255],
        "note": (note or "")[:1000],
        "expires": expires_iso,                 # None -> permanent
        "identifiers": ids,
        "autoAddEnabled": True,                 # BM auto-applies to org servers as it sees the identity
        "orgWide": True,
    }
    if uid:
        attrs["uid"] = str(uid)[:255]
    if native is not None:
        attrs["nativeEnabled"] = bool(native)   # force a native BE ban push; None = ban-list default
    body = {"data": {
        "type": "ban",
        "attributes": attrs,
        "relationships": {
            "organization": {"data": {"type": "organization", "id": str(org_id)}},
            "banList":      {"data": {"type": "banList",      "id": str(banlist_id)}},
        },
    }}
    st, js = _request("POST", "/bans", token, body)
    if st in (200, 201):
        return True, ((js.get("data") or {}).get("id", "?"))
    if st == 409:                                # duplicate -> treat as success (already banned in BM)
        return True, "exists"
    return False, f"HTTP {st}: {_msg(js)}"


if __name__ == "__main__":
    import sys
    if len(sys.argv) >= 3 and sys.argv[1] == "guid":
        print(be_guid(sys.argv[2]))
    elif len(sys.argv) >= 2:
        org, bl, err = discover_ids(sys.argv[1])
        if err:
            print("FAIL:", err)
        else:
            print(f"OK  org_id={org}  banlist_id={bl}")
    else:
        print(__doc__)
