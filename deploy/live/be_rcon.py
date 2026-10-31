#!/usr/bin/env python3
"""Minimal BattlEye RCON client (stdlib): login, one command, print the reply.

    be_rcon.py '#restart'            # mission restart -> players to the lobby (the SOFT restart)
    be_rcon.py 'say -1 text'         # broadcast
    be_rcon.py players

Credentials from ~/.config/armapunk/rcon (RCON_PASSWORD, RCON_PORT) or env BE_RCON_PASSWORD/BE_RCON_PORT.
Protocol notes carried over from loonybot/lagwatch.py (verified live 2026-06-25): packet = 'BE' + CRC32LE(payload)
+ payload; login 0xFF 0x00 <pw>, reply byte[2]==0x01 = ok; command 0xFF 0x01 <seq> <cmd>; the server answers only
the IN-ORDER seq starting at 0 after login, so the first command MUST be seq 0. Replies to '#' admin commands are
usually empty; success is judged by the server journal, not by this reply."""
import os, socket, struct, sys, time, zlib

def _cred():
    pw = os.environ.get("BE_RCON_PASSWORD"); port = os.environ.get("BE_RCON_PORT")
    path = os.path.expanduser("~/.config/armapunk/rcon")
    if (not pw or not port) and os.path.exists(path):
        for ln in open(path):
            k, _, v = ln.strip().partition("=")
            if k == "RCON_PASSWORD" and not pw: pw = v
            if k == "RCON_PORT" and not port: port = v
    if not pw: sys.exit("be_rcon: no RCON password (~/.config/armapunk/rcon or BE_RCON_PASSWORD)")
    return pw, int(port or 2310)

def _wrap(payload):
    return b"BE" + struct.pack("<I", zlib.crc32(payload) & 0xFFFFFFFF) + payload

def main():
    if len(sys.argv) < 2: sys.exit(__doc__)
    cmd = " ".join(sys.argv[1:])
    pw, port = _cred()
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(5)
    addr = ("127.0.0.1", port)
    s.sendto(_wrap(b"\xff\x00" + pw.encode("ascii", "ignore")), addr)
    try:
        pkt, _ = s.recvfrom(4096)
    except socket.timeout:
        sys.exit("be_rcon: login timeout (RCON not bound on %d?)" % port)
    pl = pkt[6:]
    if len(pl) < 3 or pl[1] != 0x00 or pl[2] != 0x01:
        sys.exit("be_rcon: login REJECTED (wrong RConPassword?)")
    s.sendto(_wrap(b"\xff\x01\x00" + cmd.encode("ascii", "ignore")), addr)   # seq 0 = first command after login
    out, deadline = [], time.time() + 2.0
    s.settimeout(0.5)
    while time.time() < deadline:
        try:
            pkt, _ = s.recvfrom(65535)
        except socket.timeout:
            continue
        pl = pkt[6:]
        if len(pl) >= 2 and pl[1] == 0x02:                      # server message -> ACK it
            s.sendto(_wrap(b"\xff\x02" + pl[2:3]), addr); continue
        if len(pl) >= 3 and pl[1] == 0x01:
            body = pl[3:]
            if body[:1] == b"\x00" and len(body) >= 3:        # multi-part: 00 <total> <idx> data
                out.append(body[3:].decode("utf-8", "replace"))
            else:
                out.append(body.decode("utf-8", "replace"))
    print("".join(out).strip() or "(no reply)")

if __name__ == "__main__":
    main()
