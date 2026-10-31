#!/usr/bin/env python3
"""Welcome a map designer by Discord DM, as LoonyBot. Runs ON the live box (the token lives there).

    python3 deploy/live/designer_welcome.py --name player097 --to 123456789012345678
    python3 deploy/live/designer_welcome.py --name player097 --to player097 --dry-run

Sends three DMs in order, so the link and the login never travel in one message:
  1. the welcome, what Eden Live is, and the download link
  2. the download login
  3. the kit's own README.txt as an attachment, plus the three-line version

--to is a Discord user id, or a username/nickname the bot resolves through the guild it is in
(member search; the bot must share a server with them, and Discord only delivers a bot's DM to
someone who shares a server with it). Reads the designer's line from ~/.config/armapunk/edenlive.kits
and README.txt straight out of the published zip under the site's public tree, so what they get is
exactly what is in their kit. Credentials: ~/.config/armapunk/discord.env (DISCORD_TOKEN), like
post_patchnote.py. Stdlib only.
"""
import argparse
import io
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zipfile

ENV = os.path.expanduser("~/.config/armapunk/discord.env")
KITS = os.path.expanduser("~/.config/armapunk/edenlive.kits")
SITE = os.path.expanduser("~/armapunk-site/public/kits")
API = "https://discord.com/api/v10"
KIT_BASE_URL = os.environ.get("KIT_BASE_URL", "https://armapunk.com/kits")
SERVER_ADDR = os.environ.get("SERVER_ADDR", "203.0.113.10:2330")


def token():
    env = {}
    try:
        for line in open(ENV):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"')
    except OSError:
        pass
    t = os.environ.get("DISCORD_TOKEN") or env.get("DISCORD_TOKEN")
    if not t:
        sys.exit("designer_welcome: DISCORD_TOKEN missing (%s)" % ENV)
    return t


def api(tok, method, path, body=None, content_type="application/json", data=None):
    if body is not None:
        data = json.dumps(body).encode()
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={"Authorization": "Bot " + tok, "Content-Type": content_type,
                                          "User-Agent": "LoonyBot designer_welcome (armapunk.com, 1.0)"})
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read()
        return json.loads(raw) if raw else {}


def kit_line(name):
    try:
        for line in open(KITS):
            f = line.rstrip("\n").split("\t")
            if f and f[0] == name:
                while len(f) < 9:
                    f.append("")
                return dict(name=f[0], token=f[1], file=f[2], built=f[3], size=int(f[4] or 0),
                            sha=f[5], rev=f[6], init=f[7], pw=f[8])
    except OSError:
        pass
    sys.exit("designer_welcome: no published kit for %r (run Tools/designer_kit.sh first)" % name)


def readme_from_kit(kit):
    path = os.path.join(SITE, kit["token"], kit["file"])
    with zipfile.ZipFile(path) as z:
        for n in z.namelist():
            if n.endswith("/README.txt"):
                return z.read(n)
    sys.exit("designer_welcome: no README.txt inside %s" % path)


def resolve_user(tok, to):
    if to.isdigit():
        return to, None
    guilds = api(tok, "GET", "/users/@me/guilds")
    q = to.lstrip("@")
    for g in guilds:
        try:
            hits = api(tok, "GET", "/guilds/%s/members/search?%s" % (g["id"], urllib.parse.urlencode({"query": q, "limit": 5})))
        except urllib.error.HTTPError:
            continue
        exact = [m for m in hits if q.lower() in {m["user"].get("username", "").lower(),
                                                 (m["user"].get("global_name") or "").lower(),
                                                 (m.get("nick") or "").lower()}]
        pick = exact or hits
        if len(pick) == 1:
            u = pick[0]["user"]
            return u["id"], "%s (%s) in %s" % (u.get("global_name") or u["username"], u["username"], g["name"])
        if len(pick) > 1:
            sys.exit("designer_welcome: %r matches several people in %s: %s -- pass the user id instead"
                     % (to, g["name"], ", ".join("%s (%s)" % (m["user"].get("global_name") or m["user"]["username"], m["user"]["id"]) for m in pick)))
    sys.exit("designer_welcome: nobody called %r in any server the bot is in -- pass the user id" % to)


def messages(kit):
    url = "%s/%s/%s" % (KIT_BASE_URL, kit["token"], kit["file"])
    host, _, port = SERVER_ADDR.partition(":")
    m1 = (
        "Welcome to the Armapunk 2035 design team, **%s**.\n\n"
        "You've got a seat in **Eden Live**: the Arma 3 editor, shared. Everyone editing sees everyone "
        "else's changes as they happen, and whatever you place, move or delete on Malden lands in the "
        "running game about ten seconds later. No saving, no files to send anyone, no restarts.\n\n"
        "Your kit is here (about %d MB):\n%s\n\n"
        "The download asks for a name and password. They're in my next message, on purpose."
    ) % (kit["name"], round(kit["size"] / 1048576), url)
    m2 = "Download login for the kit above.\nName: `%s`\nPassword: `%s`\n\nThat login, the link and the key inside the kit are yours alone. Please don't forward them; if you want it on a second machine, just ask." % (kit["name"], kit["pw"] or "(ask)")
    m3 = (
        "Attached is the README from inside your kit; it walks through setup one click at a time. The short version:\n"
        "1. Unzip. Put `@EdenLive` next to `arma3_x64.exe` (Steam → right-click Arma 3 → Manage → Browse local files).\n"
        "2. Put `MaldenEdit.Malden` in `Documents\\Arma 3 - Other Profiles\\<your name>\\mpmissions` (or `Documents\\Arma 3\\mpmissions` if you have no Other Profiles folder).\n"
        "3. Launcher → Mods → Local mod → pick `@EdenLive` → Play. Editor → Malden → open **MaldenEdit**.\n"
        "4. Tools → Eden Live: host `%s`, port `%s`, password box empty → Connect. Wait for *Eden Live: connected*.\n\n"
        "Delete is for real and for everyone, so look before you delete. Anything odd, send me the newest `.rpt` from `%%LOCALAPPDATA%%\\Arma 3` and say what you were doing."
    ) % (host, port or "2330")
    return m1, m2, m3


def send(tok, channel, content, attachment=None):
    if attachment is None:
        return api(tok, "POST", "/channels/%s/messages" % channel, body={"content": content})
    fname, data = attachment
    boundary = "----LoonyBot" + uuid.uuid4().hex
    payload = {"content": content, "attachments": [{"id": 0, "filename": fname}]}
    body = io.BytesIO()
    body.write(("--%s\r\nContent-Disposition: form-data; name=\"payload_json\"\r\nContent-Type: application/json\r\n\r\n%s\r\n"
                % (boundary, json.dumps(payload))).encode())
    body.write(("--%s\r\nContent-Disposition: form-data; name=\"files[0]\"; filename=\"%s\"\r\nContent-Type: text/plain\r\n\r\n"
                % (boundary, fname)).encode())
    body.write(data)
    body.write(("\r\n--%s--\r\n" % boundary).encode())
    return api(tok, "POST", "/channels/%s/messages" % channel, content_type="multipart/form-data; boundary=" + boundary, data=body.getvalue())


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--name", required=True, help="the designer, as in the kits index")
    ap.add_argument("--to", required=True, help="Discord user id, or a username the bot resolves")
    ap.add_argument("--dry-run", action="store_true", help="print the three messages, send nothing")
    a = ap.parse_args(argv)

    kit = kit_line(a.name)
    readme = readme_from_kit(kit)
    m1, m2, m3 = messages(kit)
    if a.dry_run:
        for i, m in enumerate((m1, m2, m3), 1):
            print("----- DM %d %s" % (i, "(+ README.txt attached)" if i == 3 else ""))
            print(m.replace(kit["pw"], "<password>") if kit["pw"] else m)
        print("----- README.txt: %d bytes from the published zip" % len(readme))
        return 0

    tok = token()
    uid, who = resolve_user(tok, a.to)
    print("recipient:", who or uid)
    dm = api(tok, "POST", "/users/@me/channels", body={"recipient_id": uid})
    chan = dm["id"]
    for i, (content, att) in enumerate(((m1, None), (m2, None), (m3, ("README.txt", readme))), 1):
        try:
            r = send(tok, chan, content, att)
            print("sent DM %d (message %s)" % (i, r.get("id")))
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:300]
            if e.code == 403:
                sys.exit("designer_welcome: Discord refused the DM (403). They must share a server with LoonyBot and allow DMs from server members. %s" % detail)
            sys.exit("designer_welcome: DM %d failed: HTTP %s %s" % (i, e.code, detail))
    return 0


if __name__ == "__main__":
    sys.exit(main())
