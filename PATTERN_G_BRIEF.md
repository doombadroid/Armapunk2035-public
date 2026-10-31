# Pattern G — ICEBREAKER OS / TAL OS. Design brief.

Paste this whole file. It is self-contained; you do not need the repo.

You designed this screen once already. **The correction I sent you afterwards was
partly wrong, and this brief supersedes both.** Details in §2 — read that before
anything else, because the thing I told you to delete is real.

---

## 1. What you are designing

The two terminal screens of the in-game phone: **ICEBREAKER OS** (civilian
intrusion tools) and **TAL OS** (the police counterpart). These are the signature
screens of the whole handset — everything else is a list or a table; this is
where the cyberpunk fiction actually lives.

Everything else in the phone is now built and in game: launcher, gang roster,
keychain, money, six point-spend trees, messages, market, wallpaper, settings,
inventory. Your chassis, tokens and row grammar carried all of them unchanged.
This is the last big one.

---

## 2. Corrections to the corrections

I sent you a list of things your first Pattern G pass got wrong. **One of those
"corrections" was itself wrong.** Sorting it out matters, because the mechanic I
told you to delete is the best thing on the screen.

**The 10-second trace window is REAL. You had it right. I was wrong.**

I claimed nothing counted down and that you had lifted the number from another
hack's description. Wrong. `fn_qhCfg`'s own header lists it as one of three
universal levers, and it is implemented: casting a targeted hack on a player
arms a 10-second window on the VICTIM, gives them a `TRACE INTRUSION` action,
and if they use it in time it pings the hacker's position back. The code calls
it "the risk half of every quickhack's risk/reward". Design for it.

What confused me is that **there are two different things called "trace"**, and
they point in opposite directions:

| | who acts | when | what they get |
|---|---|---|---|
| **TRACE WINDOW** | the **victim** | 10s after being hit | the hacker's position |
| **ICE TRACE** | nearby **MaxSec** | instantly, on cast | the location and what was hit — *never* the hacker's name |

Both are live. The victim's window is the duel; ICE TRACE is the ambient risk of
doing crime near police. A hack can trigger both.

**Two firewall chips: also correct, also mine to concede.** The cap really is
two, from the same header.

**What my correction got right, and still stands: Proxy Chain is not a chip.**
It is a **consumable inventory item** costing $60,000, armed *before* you cast by
using it from your bag. When you next hack, the server burns it and that hack
leaves no ICE TRACE. One charge, one hack. There is no reactive "burn now"
button — by the time a trace fires, the decision was already made. So a
`BURN PROXY CHAIN` button still cannot exist; the screen shows an **armed state**
instead.

The chips are separate and permanent: **Scrambler, Optic Filter, Audio Limiter,
Hardened Firmware, Deadbolt, Freq-Hop** — $250k–$400k each, owned forever, two
equipped at a time.

---

## 3. The real mechanics, verified against the code

**Three universal levers.** Every hack has these; they are the balance:

- **UPLOAD CHANNEL** 1–8s. The victim sees `INTRUSION DETECTED` and a bar. The
  *server* runs this clock and re-validates range, target and authorisation when
  it completes — a modified client cannot skip it.
- **TRACE WINDOW** 10s, as above.
- **FIREWALL SLOTS** two equipped, so nobody is immune to everything.

**A hack is:** `id, name, blurb, icon, side, uploadSecs, cooldown, range,
needsLOS, auth, targetKind, counterChip`.

Real values, not examples: `Ping.exe` is `2s up · 60s cd · 150m`.
`Negotiation Blackout` is `4s · 240s · 50m`. `Warrant Tap` is `5s · 300s · 40m`.
So the spread is wide and the numbers matter — a 5-second channel at 40 metres is
a commitment.

**Six ring slots**, filled from a library. The default civ set is
`Ping · Whiteout · Synapse · Leech · Static · Distract`. Only hacks you have
unlocked (via an installed chip) are loadable. Civilians additionally carry four
**breach tools** that need no chip: `unlock · house · atm · cuffs`.

**Almost every target is a player** — 15 of 16 catalogue rows. One targets a
vehicle. Design the target list for people first.

**TAL OS is not a reskin with different colours.** Cop hacks are gated by
**authorisation, not rarity** — the row carries `auth`, one of
`"" | wanted | restrained | wantedArmed`. `Silence Cell` only works on a
*restrained* suspect. `Dazzle Protocol` is pursuit-only. That gate is enforced
server-side and it is the design's whole answer to "why don't cops just get the
same toys". The screen should make the gate legible: a hack you cannot use on
this person should say *why*, in the same voice the trees do.

Cop hacks: `Pursuit Tag · PA Override · Dazzle Protocol · Silence Cell ·
Negotiation Blackout · Warrant Tap`.

**VR goggles are a SPEED upgrade only.** The screens work without them. Do not
design a "no goggles" empty state.

---

## 4. What is already built, and must be matched

Unchanged from your handoff and still correct: the SPOOL MK-II chassis, the
token set, the row grammar, the two-layer glyphs, the `.tal` cop recolour.

**New since you last saw it, and relevant here:**

- **A live wallpaper layer** now sits behind everything (your Matrix Rain, in as
  a CSS layer). There is a **scrim** between it and the panels, four levels. On a
  full-bleed terminal screen, assume the scrim is doing work and do not fight it.
- **The pause rule you specified is implemented** and it generalises: motion runs
  on the launcher and freezes when an app opens. If this screen wants motion —
  and it should — it is running *while an app is open*, which is the expensive
  case. Say what animates and roughly how much of the surface it touches.
- **Real `<input>` works.** Filter the nearby list by typing if that helps.
- The status strip at the foot of the panel is now on every screen and is where
  refusals go.

---

## 5. What the screen has to answer

In rough priority — these are the questions a player has with the phone open:

1. Who is near me, and can I reach them? (range, per hack, varies 15–150m)
2. What can I fire *right now* — not what do I own, what is off cooldown, in
   range, and authorised for this target?
3. What is it going to cost me — how long is the channel, and do they get a
   trace window on me?
4. Am I covered? Proxy armed or not; which two chips are in.
5. What just happened? Last cast, did it land, did it get traced.

The upload is the dramatic moment: a 5-second bar during which the victim knows
they are being hacked and you are standing still. That deserves the screen.

---

## 6. Deliverables

- Two self-contained `.html` files — ICEBREAKER OS and TAL OS — inline CSS and
  JS, no `<script src>`, openable in a browser for review.
- A small `AP` stub with mock data so they render standalone.
- The `AP.on()` channels with payload shapes, and the `AP.call()` verbs with
  argument and return shapes.
- Any new glyphs as two-layer `<symbol>`s matching the existing set.

**Four glyphs are missing and blocking**, which you spotted yourself last time
and was a genuine find: `ghouse`, `gcuffs`, `gshield`, `gcarlock` are in the icon
map but were never baked. House Breach and Cuff Cracker have no icon until they
exist. Include them.

---

## 7. Do not

- design a reactive `BURN PROXY CHAIN` button — the decision happens before the cast
- treat TAL OS as a colour swap; the authorisation gate is the design
- invent a RAM or heat economy; the levers are channel, cooldown, range and the
  two chip slots
- show a hacker's name to the MaxSec on an ICE TRACE — they get a place and a crime,
  never a person. That gap is deliberate and it is the whole reason the mechanic
  is interesting
- assume the page decides anything. The server owns the channel, re-validates on
  completion, and tells the page what happened. The screen animates a result.
