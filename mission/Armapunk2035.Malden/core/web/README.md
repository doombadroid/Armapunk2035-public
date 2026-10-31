# Web UI bridge

HTML/CSS/JS screens rendered in the game's embedded Chromium (`CT_WEBBROWSER`,
type 106, Arma 2.20+), wired to SQF in four directions.

Two things using it today: `ui/html/deck.html` (the phone, dialog 937500) and
`ui/html/bridgetest.html` (the harness, dialog 937400, which exercises every
direction so a change can be checked in game rather than reasoned about).

---

## The two engine primitives

Everything below is protocol built on these. There is nothing else.

```
SQF -> JS    ctrlWebBrowserAction ["ExecJS", "<javascript source>"]
JS  -> SQF   A3API.SendAlert(str)     raises the control's "JSDialog" event
             A3API.SendConfirm(str)   same event, but the EH's return value is
                                      the answer — no ExecJS leg at all
```

## The four directions

```sqf
// SQF -> page, fire and forget
[_ctrl, "money", createHashMapFromArray [["cash", AP_cash]]] call AP_fnc_webPush;

// page -> SQF, page gets a Promise
[_ctrl, "gangInfo", { [AP_gang_data select 1, count AP_gangMembersList] }] call AP_fnc_webOn;

// SQF -> page, SQF gets the return value (needs a scheduled context)
private _row = [_ctrl, "selectedRow"] call AP_fnc_webCall;

// page -> SQF boolean, one round trip
[_ctrl, "isCop", { playerSide isEqualTo west }] call AP_fnc_webOn;
```

```js
AP.on("money", v => render(v));          // replays the last value on subscribe
AP.get("money");                          // last value, or undefined
const info  = await AP.call("gangInfo");  // 15-21 ms
const isCop = await AP.ask("isCop");      // ~half that, bool only
AP.handle("selectedRow", () => state.selected);   // SQF can now call this
```

## The game filesystem, straight from the page

```js
const url = await AP.texture("icons\\deck_cyberdeck.paa", 256);  // data URL
img.src = url;  el.style.backgroundImage = `url(${url})`;        // both work

const raw  = await AP.file("ui\\html\\bridge.js");        // like loadFile
const cfg  = await AP.preprocessed("core\\config\\x.hpp"); // like preprocessFile
```

`RequestTexture` is how `.paa` art reaches a page — CSS panels for chrome,
real textures for imagery, in the same screen.

---

## Everything here that is load-bearing

Each of these was a bug first.

**The page must be served from a whitelisted path.** `url=` or `ctrlSetURL`,
with the path listed in `CfgCommands::allowedHTMLLoadURIs` (`description.ext`).
A page handed over some other way gets **no `A3API` binding at all** — it renders
perfectly and can never call back.

**A `JSDialog` handler must be attached.** Without one, `SendAlert` succeeds on
the page side and the message goes nowhere.

Those two fail silently and each looks like a different bug. Check them first.

**The JSDialog handler's return value IS the reply to the page.** A Boolean
releases it. Anything else — a Script handle from `spawn`, say — leaves the
browser blocked forever waiting for an explicit response. `fn_webBridgeInit`
assigns `_out` on every path and ends on it for exactly this reason.

**`SendAlert` is `alert()`, so the page is blocked while the handler runs.**
Calling `ExecJS` inline targets a browser that cannot execute anything. The
handler returns immediately and the answer is delivered from a spawned thread.

**ExecJS before `PageLoaded` is dropped.** Silently, per the BIKI. So everything
goes through `AP_fnc_webExec`, which queues until `PageLoaded` fires and drains
there. `PageLoaded` also fires on navigation and on `ResumeBrowser`, and each of
those is a fresh document with no `AP` in it — so bridge.js is re-injected on
every one.

**`toJSON` refuses a bare `nil`.** Not exotic: `AP_fnc_promptText` returns nil
on every cancel. The response path emits the literal `null` instead.

**Base64 in the SQF -> page direction is not decoration.** The payload is
interpolated into JavaScript *source text* by `format[]`. A quote, newline or
backslash in a player's name would break the statement or inject code. Base64
has none of those characters.

**`atob` alone mangles non-ASCII.** It yields one latin1 char per *byte*, but the
game hands `ToBase64` a UTF-8 string — so an accented player name arrives as
mojibake. `decode()` re-decodes as UTF-8 and falls back to the latin1 reading.

**bridge.js must be idempotent.** There are two boot paths and SQF re-injects on
every `PageLoaded`. Without the `_v` guard, a second run replaced `window.AP` and
silently discarded every handler registered with `AP.on()` — calls kept working,
pushes stopped, nothing errored.

**Typed text DOES reach the DOM.** This document previously claimed the opposite,
and that claim was wrong: it came from a probe tile that printed `keydown: 0`
as static text with no listeners attached, so it could only ever print zeros.

Measured properly on 2.22.153995 (2026-08-11): typing 25 characters into an
`<input>` produced `keydown` 25, `keypress` 25, `beforeinput` 25, `input` 25, and
`.value` held the typed string. `contenteditable` behaves the same. Backspace
registers. Real fields, live validation and multi-field forms are all fine.

`promptText` is therefore **optional**, not mandatory. It is still worth using
when you want the native Arma look, or on a frozen browser — but a page that
needs a text field should just use one:

```js
const name = await AP.call("promptText", ["Rename gang", current, 24], 60000);
if (name !== null) applyRename(name);      // null = cancelled
```

Mouse works fully. **Native controls do NOT draw on top of the browser surface**
(measured 2026-09-03 with the I-screen's body camera, five builds): a sibling
control declared or `ctrlCreate`d after the browser never shows. The browser
does alpha-composite over controls drawn *before* it, so the pattern that works
is: declare the native control BEFORE the browser control and have the page
leave a transparent hole where it should show (`core/inventory/fn_invFigure.sqf`,
`inventory.html` `body.figlive #frame` mask). Separate displays (engine error
boxes) do draw above the browser. The prompt overlay is declared after the
browser and has not been seen in game — treat it as unverified.

**Esc closes the dialog.** Do not build a page-level Esc handler.

**`OpenDevConsole` needs the `-debug` start parameter.** Without it, nothing
happens and there is no message.

---

## Animation works — but ONLY if Arma was launched through Steam

This is the single most expensive thing found in this project, and it looked
like an engine limitation for an entire afternoon.

The page's user agent is `... Valve Steam Client Safari/537.36`: under Proton
this control is serviced by **Steam's webhelper**, not by a CEF inside Arma.
Frame delivery is **dirty-driven** — nothing changes, nothing paints — and it
only runs when the Steam overlay hook (`gameoverlayrenderer.so`) is injected,
which happens when the game is **started from Steam**.

Same page, same build, same machine, thirteen minutes apart:

| launched via | idle | animated GIF | rAF |
|---|---|---|---|
| `tools/launch_arma.sh` (no Steam) | 0.6 fps | **1.0 fps** | **1.9 fps** |
| **Steam** | 0.6 fps | **20.0 fps** | **61.4 fps** |

Idle being ~0.6 fps in both is correct and desirable: a static page costs
nothing. What matters is that content changes *drive* frames in the Steam case
and cannot in the other.

So CSS transitions, `@keyframes`, `requestAnimationFrame` and hover feedback
all work normally — the phone's roll animation included. **When debugging
anything that looks like the page is frozen, check how Arma was started before
touching a line of CSS.** Launching outside Steam also clamps hover response,
which reads as "the buttons are laggy".

`AP_fnc_deckDrawRate` measures it in fifteen seconds and is the fastest way
to tell the two worlds apart.

### What was measured against the wrong client

Everything in the following list was recorded as an engine limit and is simply
false for a normally-launched game — kept here because the wrong conclusion is
more instructive than the right one:

- "CSS transitions and keyframes cannot render"
- "requestAnimationFrame is throttled to ~2 fps"
- "a JS style mutation at 60Hz cannot force a repaint"
- "no engine-side lever changes it" (ctrlSetFocus, EachFrame ctrlCommit,
  EachFrame displayUpdate, 30Hz ExecJS were all measured on the clamped client)

The Steam overlay itself will not draw on this machine under GE-Proton even
with the hook correctly injected, so the overlay cannot be used as a lever —
but its *hook* being present is what matters, not the overlay UI working.

## Cost
## Cost

Measured properly on 2026-08-11, client 2.22.153995, 3440x1440, via
`AP_fnc_webBench` — one identical sampling method, browser closed / open /
closed again:

```
A  baseline, no browser : mean 56.0 fps  (49.8-62.7, 29 samples)
B  browser open, idle   : mean 57.1 fps  (51.0-62.5, 29 samples)
A' closed again         : mean 58.1 fps  (54.4-63.5, 29 samples)
=> -1.1 fps (-2%)
```

**The browser has no measurable frame cost.** FPS was marginally higher with it
open, and the three passes trend upward across the run, which is the client
settling rather than anything the browser did. The min/max spread is ~13 fps, so
any real cost sits well below the noise floor.

This replaces an earlier "~12 FPS" figure quoted throughout the project. That
number was never an A/B: the with-browser half was sampled immediately after a
dialog opened, while the page was still loading, and the baseline half had no
recorded provenance at all. Re-measure with `[] spawn AP_fnc_webBench;` rather
than trusting either number.

Per-call latency (unchanged, and separately measured): **15-21 ms**, ~413 ms for
20 concurrent — they pipeline.

`AP_fnc_webFreeze` (StopBrowser / ResumeBrowser) still exists and still frees
the browser's memory, but **not for frame-rate reasons** — there are none to
reclaim. Resuming reloads the page, which fires PageLoaded and re-pushes every
channel.

## The page's viewport scales with the CONTROL, not the screen

Measured two control sizes on a 3440x1440 display at uiScale 0.55:

| control (UI_GRID) | CSS viewport | px per grid unit |
|---|---|---|
| 40 x 20 | 1200 x 600 | 30 |
| 19 x 9  |  570 x 270 | 30 |

**30 CSS pixels per UI_GRID unit, at devicePixelRatio 1, regardless of screen
resolution.** So resolution independence is real — the same control gives the
same CSS surface on 1080p and on ultrawide — but the viewport is *not* a
constant 1200x600. That earlier claim came from measuring one control and
assuming; a second control size disproved it immediately.

Consequence for the `1rem = frame width / 75` trick: it yields 16px on the
40x20 deck box, but only 7.6px on a 19x9 panel. A page reused at a smaller
control size needs the floor in `fit()`, or its text will be unreadably small.

Design rule: **fetch on open, push on change.** Never poll per frame.

## Page rules

One self-contained `.html` per screen — or one page with view swapping, which is
what `deck.html` does, because a page load drops `window.AP` and forces every
channel to be re-pushed.

- Inline all CSS and JS. **No `<script src>`** — the page has no resolvable base
  URL and a relative `src` silently resolves to nothing. Pull scripts with
  `A3API.RequestFile` and `eval` them, the way `deck.html` boots the bridge.
- No external stylesheets, web fonts, CDNs or icon packs. System font stack only.
- `fetch`, `XMLHttpRequest`, `localStorage` and `IndexedDB` are blocked by the
  sandbox. Persisted settings round-trip through SQF.
- Images are data URIs or `AP.texture()`.
- Fit the control's box or scroll one designated region; if the body overflows,
  the whole surface scrolls and content is cut off at the top.

## Files

| file | what it is |
|---|---|
| `fn_webBridgeInit.sqf` | attaches JSDialog + PageLoaded, registers the default handlers |
| `fn_webOn.sqf` | register a handler a page may call (per control) |
| `fn_webPush.sqf` | SQF -> page value push |
| `fn_webCall.sqf` | SQF -> page call with a return value |
| `fn_webExec.sqf` | ExecJS, queued until the page is up |
| `fn_webFreeze.sqf` | StopBrowser / ResumeBrowser |
| `fn_promptText.sqf` | native text entry (`dialog/web_prompt_overlay.hpp`) |
| `fn_deck*.sqf` | the phone: opener, payloads, handlers, map ping |
| `../../ui/html/bridge.js` | the browser-side half |

## Security

Handler names are per control, so one screen cannot reach another's verbs. That
is a **convenience boundary, not a trust boundary**: anyone who can run JS in the
page can call every registered name with arbitrary args, exactly as they could
from the debug console. Anything touching money, inventory or permissions must
be validated server-side, same as any other client path (`security.md`).
