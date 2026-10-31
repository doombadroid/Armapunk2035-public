#!/usr/bin/env python3
"""gamectl — agent eyes & hands for the local Hyprland session.

Built 2026-08-04 (owner request) so the agent can see and drive the Arma
client itself instead of round-tripping screenshots through the owner.
Box-specific: relies on grim + hyprctl and the user ACL on /dev/uinput.

  gamectl.py shot [path] [--half]     grim screenshot (optionally downscaled)
  gamectl.py windows                  list Hyprland clients
  gamectl.py focus <class-substr>     focus first matching window
  gamectl.py key <combo> [...]        e.g. esc  f1  ctrl+shift+p  enter
  gamectl.py type <text>              type literal text (US layout)
  gamectl.py move <x> <y>             absolute cursor warp (hyprctl)
  gamectl.py click [left|right]       mouse button at current cursor
  gamectl.py sqf <code>               Arma debug-console exec (see CONSOLE_*)

Safety: synthetic input goes to whatever holds focus — always `focus` first.

Operating notes (owner, 2026-08-04):
  * Rejoining after a server redeploy: the moment a RED CHAIN icon appears
    bottom-right, the session is dead — Esc -> "QUIT LOONYBIN LIFE" drops
    straight to the main menu instead of waiting for Arma to time out.
    Then: DEPLOY (custom menu) or MULTIPLAYER -> server browser -> LoonyDev.
  * Addons (mod PBOs) only load at GAME LAUNCH. Mission PBO changes need a
    server redeploy + rejoin; @Armapunk2035 changes need a full Arma restart.
  * Screenshot coords: winshot/winmove/verify work in GAME-WINDOW space at a
    given viewscale. Never feed raw grim pixels to movecursor — grim
    composites every monitor at the max output scale, hyprctl takes logical
    global coords, and the two disagree by both a scale and an origin.
"""
import json
import subprocess
import sys
import time

import evdev
from evdev import UInput, ecodes as e

KEYMAP = {
    'esc': e.KEY_ESC, 'enter': e.KEY_ENTER, 'tab': e.KEY_TAB, 'space': e.KEY_SPACE,
    'backspace': e.KEY_BACKSPACE, 'delete': e.KEY_DELETE, 'up': e.KEY_UP, 'down': e.KEY_DOWN,
    'left': e.KEY_LEFT, 'right': e.KEY_RIGHT, 'home': e.KEY_HOME, 'end': e.KEY_END,
    'ctrl': e.KEY_LEFTCTRL, 'shift': e.KEY_LEFTSHIFT, 'alt': e.KEY_LEFTALT, 'super': e.KEY_LEFTMETA,
    **{f'f{i}': getattr(e, f'KEY_F{i}') for i in range(1, 13)},
    **{c: getattr(e, f'KEY_{c.upper()}') for c in 'abcdefghijklmnopqrstuvwxyz'},
    **{str(d): getattr(e, f'KEY_{d}') for d in range(10)},
    '-': e.KEY_MINUS, '=': e.KEY_EQUAL, '[': e.KEY_LEFTBRACE, ']': e.KEY_RIGHTBRACE,
    ';': e.KEY_SEMICOLON, "'": e.KEY_APOSTROPHE, '`': e.KEY_GRAVE, '\\': e.KEY_BACKSLASH,
    ',': e.KEY_COMMA, '.': e.KEY_DOT, '/': e.KEY_SLASH,
}
SHIFTED = {
    '!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7', '*': '8',
    '(': '9', ')': '0', '_': '-', '+': '=', '{': '[', '}': ']', ':': ';', '"': "'",
    '~': '`', '|': '\\', '<': ',', '>': '.', '?': '/',
}

# ---------------------------------------------------------------- geometry
# HARD LESSON 2026-08-04: grim composites ALL monitors into one image at the
# max output scale, while `hyprctl dispatch movecursor` takes LOGICAL global
# coords. Feeding screenshot pixels straight to movecursor put the pointer on
# the wrong monitor entirely. Always convert, and verify with a cursor capture
# before clicking.

# Debug-console hit points, in winshot space at viewscale 0.5 (calibrated
# 2026-08-04 against the Extended Debug Console on the 3440x1440 output).
CONSOLE_VIEW = 0.5
CONSOLE_EXEC_FIELD = (440, 100)
CONSOLE_LOCAL_EXEC = (551, 493)
CONSOLE_SERVER_EXEC = (333, 493)


def monitors():
    return json.loads(hypr('monitors', '-j'))


def game_window(cls='arma3_x64'):
    for c in json.loads(hypr('clients', '-j')):
        if cls in c['class']:
            return c
    raise SystemExit(f'no window matching {cls}')


def window_capture_factor(w):
    """grim composites a region at the MAX scale of every output it touches.

    hyprctl speaks logical pixels, so screenshot coords must be divided by
    this factor. It is a property of the captured REGION, not of the window's
    "monitor" field: a window overlapping a 1.0 and a 1.6 output is captured
    at 1.6 even though hyprctl reports it on the 1.0 one.
    """
    wx, wy = w['at']
    ww, wh = w['size']
    factor = 1.0
    for m in monitors():
        ms = float(m.get('scale', 1))
        mx, my = m['x'], m['y']
        mw, mh = m['width'] / ms, m['height'] / ms
        if wx < mx + mw and mx < wx + ww and wy < my + mh and my < wy + wh:
            factor = max(factor, ms)
    return factor


def shot_window(path, cls='arma3_x64', scale=1):
    """Capture ONLY the game window, 1:1 with its logical geometry.

    Returned coords in that image map to logical global as:
        logical = (win_x + px/scale, win_y + py/scale)
    """
    w = game_window(cls)
    x, y = w['at']
    ww, wh = w['size']
    subprocess.run(['grim', '-g', f'{x},{y} {ww}x{wh}', '-t', 'png', path], check=True)
    return (x, y, ww, wh)


def ui():
    caps = {
        e.EV_KEY: sorted(set(KEYMAP.values())) + [e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE],
        e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL],
    }
    return UInput(caps, name='gamectl-virtual')


def press(u, codes, hold=0.03):
    for c in codes:
        u.write(e.EV_KEY, c, 1)
    u.syn()
    time.sleep(hold)
    for c in reversed(codes):
        u.write(e.EV_KEY, c, 0)
    u.syn()
    time.sleep(0.02)


def combo_codes(combo):
    return [KEYMAP[p.strip().lower()] for p in combo.split('+')]


def type_text(u, text, delay=0.014):
    for ch in text:
        if ch == '\n':
            press(u, [e.KEY_ENTER]); continue
        if ch == ' ':
            press(u, [e.KEY_SPACE]); continue
        shift = ch.isupper() or ch in SHIFTED
        base = SHIFTED.get(ch, ch.lower())
        if base not in KEYMAP:
            raise SystemExit(f'unmapped char: {ch!r}')
        codes = ([e.KEY_LEFTSHIFT] if shift else []) + [KEYMAP[base]]
        press(u, codes, hold=0.02)
        time.sleep(delay)


def hypr(*args):
    return subprocess.run(['hyprctl', *args], capture_output=True, text=True).stdout


def main():
    cmd, *rest = sys.argv[1:] or ['help']
    if cmd == 'shot':
        path = rest[0] if rest else '/tmp/claude-1000/gamectl_shot.png'
        subprocess.run(['grim', '-t', 'png', path], check=True)
        if '--half' in rest:
            subprocess.run(['magick', path, '-resize', '50%', path], check=True)
        print(path)
    elif cmd == 'winshot':
        # winshot <path> [viewscale] — game window only; prints the mapping
        path = rest[0] if rest else '/tmp/claude-1000/gamectl_win.png'
        x, y, ww, wh = shot_window(path)
        view = float(rest[1]) if len(rest) > 1 else 1.0
        if view != 1.0:
            subprocess.run(['magick', path, '-resize', f'{view * 100:g}%', path], check=True)
        print(json.dumps({'path': path, 'win': [x, y, ww, wh], 'viewscale': view}))
    elif cmd == 'winmove':
        # winmove <px> <py> [viewscale] — cursor to a point in winshot space
        px, py = float(rest[0]), float(rest[1])
        view = float(rest[2]) if len(rest) > 2 else 1.0
        w = game_window()
        f = window_capture_factor(w)
        lx, ly = w['at'][0] + px / (view * f), w['at'][1] + py / (view * f)
        hypr('dispatch', 'movecursor', str(round(lx)), str(round(ly)))
        print(f'cursor -> logical {round(lx)},{round(ly)} (capture factor {f})')
    elif cmd == 'verify':
        # verify <px> <py> [viewscale] — cursor-visible crop around the target
        px, py = float(rest[0]), float(rest[1])
        view = float(rest[2]) if len(rest) > 2 else 1.0
        w = game_window()
        x, y = w['at']; ww, wh = w['size']
        full = '/tmp/claude-1000/gamectl_verify_full.png'
        subprocess.run(['grim', '-c', '-g', f'{x},{y} {ww}x{wh}', '-t', 'png', full], check=True)
        fx, fy = px / view, py / view
        x0, y0 = max(0, int(fx - 260)), max(0, int(fy - 160))
        subprocess.run(['magick', full, '-crop', f'520x320+{x0}+{y0}', '+repage',
                        '/tmp/claude-1000/gamectl_verify.png'], check=True)
        print('/tmp/claude-1000/gamectl_verify.png')
    elif cmd == 'windows':
        for c in json.loads(hypr('clients', '-j')):
            print(f"{c['class']:30} | {c['title'][:70]}")
    elif cmd == 'focus':
        print(hypr('dispatch', 'focuswindow', f'class:{rest[0]}').strip())
        time.sleep(0.25)
    elif cmd == 'key':
        with ui() as u:
            time.sleep(0.3)   # let the compositor register the device
            for combo in rest:
                press(u, combo_codes(combo))
    elif cmd == 'type':
        with ui() as u:
            time.sleep(0.3)
            type_text(u, ' '.join(rest))
    elif cmd == 'move':
        print(hypr('dispatch', 'movecursor', rest[0], rest[1]).strip())
    elif cmd == 'click':
        btn = {'left': e.BTN_LEFT, 'right': e.BTN_RIGHT}[rest[0] if rest else 'left']
        with ui() as u:
            time.sleep(0.3)
            u.write(e.EV_KEY, btn, 1); u.syn(); time.sleep(0.05)
            u.write(e.EV_KEY, btn, 0); u.syn()
    elif cmd == 'sqf':
        # sqf "<code>" [--server]  — console must already be open (Esc menu)
        target = CONSOLE_SERVER_EXEC if '--server' in rest else CONSOLE_LOCAL_EXEC
        code = ' '.join(a for a in rest if a != '--server')
        w = game_window()
        wx, wy = w['at']
        v = CONSOLE_VIEW

        f = window_capture_factor(w)

        def warp(pt):
            hypr('dispatch', 'movecursor', str(round(wx + pt[0] / (v * f))),
                 str(round(wy + pt[1] / (v * f))))
            time.sleep(0.25)

        with ui() as u:
            time.sleep(0.3)
            warp(CONSOLE_EXEC_FIELD)
            u.write(e.EV_KEY, e.BTN_LEFT, 1); u.syn(); time.sleep(0.05)
            u.write(e.EV_KEY, e.BTN_LEFT, 0); u.syn(); time.sleep(0.3)
            press(u, [e.KEY_LEFTCTRL, e.KEY_A]); time.sleep(0.15)
            type_text(u, code)
            time.sleep(0.2)
            warp(target)
            u.write(e.EV_KEY, e.BTN_LEFT, 1); u.syn(); time.sleep(0.05)
            u.write(e.EV_KEY, e.BTN_LEFT, 0); u.syn(); time.sleep(0.4)
        print('exec sent')
    else:
        print(__doc__)


if __name__ == '__main__':
    main()
