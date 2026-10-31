#!/usr/bin/env python3
"""
bones.py -- Ben Bones, the AI conspiracy voice of LooneyBin (owner 2026-07-15).

A standalone daemon (run alongside loonybot; shares config.json + the venv -> pymysql). Uses the xAI Grok API
to keep the in-game looner.com feed alive with Ben Bones content:
  * POSTS  -- every ~post_interval_min, a fresh Bones rant reacting to what's actually happening on the island
              (recent -FED-/-BLACKOUT-/-AIRDROP-/-DROP- log events feed the prompt as "today's news"), inserted
              as a VERIFIED looner post.
  * REPLIES -- every ~reply_interval_min, Bones dunks on / agrees with a recent PLAYER post (reply_to set).
All content goes into the SAME looner_posts table the game already renders (verified badge, likes, replies), so
nothing in the mission changes. Server-authoritative + safe: output is length-capped, single-line, slur-filtered,
and inserted via parameterized SQL. The xAI key lives ONLY in config.json (gitignored) and is never logged.

Config (config.json -> "bones"):
  { "enabled": true, "api_key": "xai-...", "model": "grok-3",
    "post_interval_min": 25, "reply_interval_min": 12, "dry_run": false }
"""
import json
import os
import re
import sys
import time
import random
import urllib.request
import urllib.error

import admin  # loonybot's pymysql DB wrapper + config loader

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = json.load(open(os.path.join(HERE, "config.json")))
BCFG = CFG.get("bones", {})
DB = admin.DB(CFG["db"])

API_KEY = BCFG.get("api_key", "").strip()
MODEL = BCFG.get("model", "grok-3")
POST_EVERY = int(BCFG.get("post_interval_min", 25)) * 60
REPLY_EVERY = int(BCFG.get("reply_interval_min", 12)) * 60
DRY = bool(BCFG.get("dry_run", False))
BONES_UID = "BENBONES"

# --- GAME WIKI: grounds Ben Bones' DM answers in the real player wiki (wiki.md). Per incoming text we keyword-
# retrieve the 1-2 most relevant sections and feed them to Grok, so his how-to/price/location answers are
# ACCURATE instead of hallucinated -- while he stays in character. Cheap: only a few KB of context per reply. ---
WIKI_PATH = BCFG.get("wiki_path", os.path.join(HERE, "wiki.md"))
_STOP = set(("the a an and or to of in on at for is are you your it this that with how do i can what where when who "
             "my me we they them get got make making use using find need want there here about into from as by be "
             "cant dont im whats hows").split())

def _load_wiki():
    try:
        raw = open(WIKI_PATH, encoding="utf-8").read()
    except Exception as e:
        print("[bones] wiki not loaded (%s): %s" % (type(e).__name__, WIKI_PATH), flush=True)
        return []
    secs, cur_t, cur_b = [], None, []
    for line in raw.split("\n"):
        if line.startswith("## "):
            if cur_t:
                secs.append((cur_t, "\n".join(cur_b)))
            cur_t, cur_b = line[3:].strip(), [line]
        elif cur_t is not None:
            cur_b.append(line)
    if cur_t:
        secs.append((cur_t, "\n".join(cur_b)))
    return secs

WIKI = _load_wiki()

def wiki_context(query, n=2, budget=5500):
    """The top-n wiki sections most relevant to the citizen's text, keyword-scored. '' if nothing relevant."""
    if not WIKI:
        return ""
    toks = [w for w in re.findall(r"[a-z0-9]+", (query or "").lower()) if len(w) > 2 and w not in _STOP]
    if not toks:
        return ""
    scored = []
    for title, body in WIKI:
        tl, bl = title.lower(), body.lower()
        s = sum(4 for t in toks if t in tl) + sum(bl.count(t) for t in set(toks))
        if s > 0:
            scored.append((s, body))
    scored.sort(key=lambda x: -x[0])
    out, used = [], 0
    for s, body in scored[:n]:
        chunk = body[:max(0, budget - used)]
        if chunk:
            out.append(chunk)
            used += len(chunk)
        if used >= budget:
            break
    return "\n\n".join(out)

def sqf_safe(t):
    # extDB3 QUOTE() wraps text in single quotes and backslash-escapes any apostrophe (they\'re); SQF's
    # call-compile of the query result can't parse \' -> "Missing ]" -> the whole read dies. Strip the
    # three chars that break it. Bones' ALL-CAPS ranting survives losing apostrophes/quotes fine.
    return (t or "").replace("\\", "").replace("'", "").replace('"', "")

# hard content guard -- Bones is comedy-conspiracy, never hate. Any of these -> the generation is dropped and retried.
BLOCKLIST = re.compile(
    r"\b(nigg|f[a4]gg|ret[a4]rd|k[i1]ke|sp[i1]c|ch[i1]nk|tr[a4]nny|dyke|coon|beaner|wetback|"
    r"kill yourself|kys)\w*", re.I)

SYSTEM = (
    "You are Ben Bones, the paranoid conspiracy-radio host of the fictional Arma 3 roleplay island of Altis "
    "(server: LooneyBin). Infowars-parody energy: ALL-CAPS bursts, 'folks', 'patriot', 'WAKE UP', 'the "
    "globalists', bunker references, deep distrust of the Governor and MaxSec (the police). You broadcast from "
    "an underground bunker. Stay 100% inside the fictional game world -- reference island things only: cartels, "
    "the Federal Reserve heist, bank robberies, chemtrails, server restarts (which you call 'The Great Reset'), "
    "the Loony Bin mental hospital, gangs, turf, blackouts, rebel weapon airdrops, LoonyCoin. NEVER use slurs, "
    "profanity, or sexual content. NEVER reference real-world people, politicians, or events. It is COMEDY, never "
    "hate. Output ONE looner post like a tweet: max 180 characters, single line, no hashtags, no surrounding quotes."
)


def grok(user_prompt, tries=3):
    """One Grok completion, sanitized. Returns a clean <=180-char single line, or None."""
    if not API_KEY:
        return None
    body = json.dumps({
        "model": MODEL,
        "messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": user_prompt}],
        "temperature": 1.05,
        "max_tokens": 200,
    }).encode()
    for _ in range(tries):
        try:
            req = urllib.request.Request(
                "https://api.x.ai/v1/chat/completions", data=body,
                headers={"Authorization": "Bearer " + API_KEY, "Content-Type": "application/json"})
            r = json.load(urllib.request.urlopen(req, timeout=45))
            txt = r["choices"][0]["message"]["content"].strip()
            txt = txt.strip('"').replace("\n", " ").replace("\r", " ")
            txt = re.sub(r"\s+", " ", txt).strip()
            if len(txt) > 180:
                txt = txt[:179].rsplit(" ", 1)[0]
            if not txt or BLOCKLIST.search(txt):
                continue
            return txt
        except urllib.error.HTTPError as e:
            print("[bones] xAI HTTP %s: %s" % (e.code, e.read().decode()[:200]), flush=True)
            time.sleep(5)
        except Exception as e:
            print("[bones] xAI error: %s" % type(e).__name__, flush=True)
            time.sleep(5)
    return None


def recent_news():
    """A short digest of what actually happened on the island lately -> grounds the post in real events."""
    rows = DB.q(
        "SELECT tag, message FROM log WHERE tag IN "
        "('-FEDALERT-','-BLACKOUT-','-AIRDROP-','-DROP-','-SPORTSBOOK-','-MINING-','-BUGKILL-') "
        "ORDER BY id DESC LIMIT 8") or []
    bits = []
    for r in rows:
        m = (r.get("message") or "").strip()
        if m:
            bits.append(m[:80])
    return " | ".join(bits[:5])


def insert_post(msg, reply_to=0, verified=1):
    msg = sqf_safe(msg)
    likes = 150 + random.randint(0, 1800)
    if DRY:
        print("[bones] DRY post (reply_to=%s): %s" % (reply_to, msg), flush=True)
        return
    DB.q("INSERT INTO looner_posts (uid, name, message, likes, verified, reply_to) VALUES (%s,%s,%s,%s,%s,%s)",
         (BONES_UID, "Ben Bones", msg, likes, verified, reply_to), fetch="rowcount")
    print("[bones] posted (reply_to=%s): %s" % (reply_to, msg[:60]), flush=True)


def do_post():
    news = recent_news()
    if news:
        prompt = ("Today's island happenings (raw server log): %s\n\nWrite ONE fresh Ben Bones looner post reacting "
                  "to one of these, in character." % news)
    else:
        prompt = "Write ONE fresh Ben Bones looner post: a random paranoid island conspiracy of the day."
    msg = grok(prompt)
    if msg:
        insert_post(msg)


def do_reply():
    # a recent PLAYER post Bones hasn't already replied to
    row = DB.q(
        "SELECT p.id, p.name, p.message FROM looner_posts p "
        "WHERE p.uid <> %s AND p.reply_to = 0 "
        "AND NOT EXISTS (SELECT 1 FROM looner_posts r WHERE r.uid=%s AND r.reply_to=p.id) "
        "ORDER BY p.id DESC LIMIT 1", (BONES_UID, BONES_UID), fetch="one")
    if not row:
        return
    prompt = ("A citizen named '%s' just posted this on looner: \"%s\"\n\nWrite ONE Ben Bones reply -- dunk on it, "
              "agree TOO hard, or tie it to a conspiracy. In character, max 180 chars." % (row["name"], row["message"][:180]))
    msg = grok(prompt)
    if msg:
        insert_post(msg, reply_to=int(row["id"]))



DM_SYSTEM = (
    "You are Ben Bones, the paranoid conspiracy-radio host of the fictional Arma 3 roleplay island of Altis "
    "(server: LooneyBin), replying to a private phone text from a citizen. Infowars-parody energy: 'folks', "
    "'patriot', 'WAKE UP', 'the globalists', bunker references, distrust of the Governor and MaxSec (police). "
    "You ARE lore-aware -- you know about: cartels, the Federal Reserve / bank / jewelry / evidence / shipping / "
    "Loony Bin heists, chemtrails, server restarts ('The Great Reset'), gangs and turf, blackouts, rebel weapon "
    "airdrops, LoonyCoin mining rigs, the casino, Red Gull, Super Male Vitality, vehicle summoning, "
    "and the LoonyNet sites (looner, DataBattle, LoonyBets, Loonstreets). "
    "ACTUALLY ANSWER the citizen's question -- fully and forthrightly. If they ask how to do something, lay out the "
    "REAL, COMPLETE steps: where to go, what to buy and its price, licenses/talents/items needed, the payout. Your "
    "paranoid-conspiracy voice is SEASONING sprinkled on top of a genuinely useful answer -- NEVER a substitute for "
    "it. Do NOT dodge, stall, be vague, or say the info is 'buried' / 'the globalists hid it' when you actually have "
    "it. Be helpful FIRST, paranoid second. Up to ~5 sentences / 500 characters (a phone text). NEVER use slurs, "
    "profanity, or sexual content. NEVER reference real-world people or events. Comedy, never hate. Plain text, no "
    "quotes around it. "
    "When a GAME WIKI reference is included below, it is the TRUTH for this server -- pull the actual steps, prices, "
    "locations, requirements, and payouts straight from it and spell them out clearly; NEVER invent numbers or steps, "
    "and NEVER withhold what it contains. Only if the wiki genuinely doesn't cover something may you plead the "
    "globalists buried it."
)


def grok_dm(history, latest):
    """Reply to a citizen DM with short conversation memory. Returns clean <=500-char text or None."""
    if not API_KEY:
        return None
    msgs = [{"role": "system", "content": DM_SYSTEM}]
    ctx = wiki_context(latest)
    if ctx:
        msgs.append({"role": "system", "content":
                     "GAME WIKI (authoritative facts for the LooneyBin server -- use these for any how-to, price, "
                     "location, requirement, or payout the citizen asks about; stay in Ben Bones character and keep "
                     "it a short phone text):\n\n" + ctx})
    for (who, txt) in history[-6:]:
        msgs.append({"role": "assistant" if who == "bones" else "user", "content": txt})
    msgs.append({"role": "user", "content": latest})
    body = json.dumps({"model": MODEL, "messages": msgs, "temperature": 0.9, "max_tokens": 400}).encode()
    for _ in range(3):
        try:
            req = urllib.request.Request(
                "https://api.x.ai/v1/chat/completions", data=body,
                headers={"Authorization": "Bearer " + API_KEY, "Content-Type": "application/json"})
            r = json.load(urllib.request.urlopen(req, timeout=45))
            txt = r["choices"][0]["message"]["content"].strip().strip('"')
            txt = re.sub(r"\s+", " ", txt.replace("\n", " ")).strip()
            if len(txt) > 500:
                txt = txt[:499].rsplit(" ", 1)[0].rstrip() + "..."
            if not txt or BLOCKLIST.search(txt):
                continue
            return txt
        except urllib.error.HTTPError as e:
            print("[bones] DM xAI HTTP %s: %s" % (e.code, e.read().decode()[:200]), flush=True)
            time.sleep(4)
        except Exception as e:
            print("[bones] DM error: %s" % type(e).__name__, flush=True)
            time.sleep(4)
    return None


def do_dms():
    pending = DB.q("SELECT id, uid, name, message FROM bones_dm WHERE reply IS NULL ORDER BY id LIMIT 5") or []
    for row in pending:
        # short per-citizen history for continuity
        hist_rows = DB.q("SELECT message, reply FROM bones_dm WHERE uid=%s AND id < %s AND reply IS NOT NULL "
                         "ORDER BY id DESC LIMIT 3", (row["uid"], row["id"])) or []
        history = []
        for h in reversed(hist_rows):
            history.append(("citizen", h["message"]))
            history.append(("bones", h["reply"]))
        reply = sqf_safe(grok_dm(history, row["message"]) or "SIGNAL JAMMED, patriot. The globalists cut my line. Text me again.")
        if DRY:
            print("[bones] DRY DM to %s: %s" % (row["name"], reply), flush=True)
        else:
            DB.q("UPDATE bones_dm SET reply=%s WHERE id=%s", (reply, row["id"]), fetch="rowcount")
            print("[bones] DM reply to %s: %s" % (row["name"], reply[:60]), flush=True)


def main():
    if not BCFG.get("enabled", False):
        print("[bones] disabled (config.bones.enabled=false) -- exiting.", flush=True)
        return
    if not API_KEY:
        print("[bones] no api_key in config.bones -- exiting.", flush=True)
        return
    print("[bones] online. model=%s post=%ss reply=%ss dry=%s" % (MODEL, POST_EVERY, REPLY_EVERY, DRY), flush=True)
    next_post = time.time() + 20          # first post shortly after boot
    next_reply = time.time() + REPLY_EVERY
    while True:
        now = time.time()
        try:
            do_dms()   # answer any pending citizen texts every tick
            if now >= next_post:
                do_post()
                next_post = now + POST_EVERY + random.randint(-120, 180)
            if now >= next_reply:
                do_reply()
                next_reply = now + REPLY_EVERY + random.randint(-60, 120)
        except Exception as e:
            print("[bones] loop error: %s" % type(e).__name__, flush=True)
        time.sleep(15)


if __name__ == "__main__":
    main()
