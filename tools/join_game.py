#!/usr/bin/env python3
"""join_game.py — take Arma from cold start to in-world on the dev server.

Unattended: launches the game (via launch_arma.sh, which parks the cursor on
the ultrawide and loads @Armapunk2035 + CBA), then drives role assignment,
the briefing screen, error dialogs and the spawn selector.

It does NOT follow a fixed script of sleeps. Each pass screenshots the game
window, classifies which screen is up from pixel signatures, and performs
that screen's action — so a slow load, an extra error dialog or a different
ordering just means another pass. That is what makes it safe to leave alone.

Usage:  python3 tools/join_game.py [--no-launch] [--timeout 600]
Exit 0 once the in-world HUD is detected; 1 on timeout.
"""
import argparse
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SHOT = '/tmp/claude-1000/join_state.png'
VIEW = 0.35   # winshot scale these coordinates were measured at


def sh(*args, **kw):
    return subprocess.run(args, capture_output=True, text=True, **kw)


def gamectl(*args):
    return sh(sys.executable, os.path.join(HERE, 'gamectl.py'), *args).stdout.strip()


def game_window():
    for c in json.loads(sh('hyprctl', 'clients', '-j').stdout or '[]'):
        if 'arma3_x64' in c['class']:
            return c
    return None


def shot():
    """Screenshot the game window at VIEW scale; None if no window yet."""
    if not game_window():
        return None
    gamectl('winshot', SHOT, str(VIEW))
    from PIL import Image
    return Image.open(SHOT).convert('RGB')


def mean(im, box):
    from PIL import ImageStat
    return [round(v) for v in ImageStat.Stat(im.crop(box)).mean]


def classify(im):
    """Identify the screen from measured pixel signatures.

    Thresholds were calibrated against real captures (2026-08-04); the first
    version averaged the whole title strip and diluted the orange header below
    its own threshold, so ROLE ASSIGNMENT read as 'unknown' and the driver sat
    there forever. Sample tight bands, not whole strips.
    """
    w, h = im.size
    header = mean(im, (0, int(h * 0.024), int(w * 0.25), int(h * 0.042)))
    play = mean(im, (int(w * 0.86), int(h * 0.94), w, h))
    spawn = mean(im, (int(w * 0.36), int(h * 0.74), int(w * 0.42), int(h * 0.78)))
    hud = mean(im, (int(w * 0.895), int(h * 0.86), int(w * 0.93), int(h * 0.95)))
    dialog = mean(im, (int(w * 0.41), int(h * 0.42), int(w * 0.59), int(h * 0.45)))

    # orange header: ROLE ASSIGNMENT / SERVER BROWSER
    if header[0] > 140 and header[0] > header[2] + 80:
        return 'role'
    if dialog[0] > 110 and dialog[1] > 70 and dialog[2] < 90:
        return 'dialog'
    if play[1] > 70 and play[1] > play[0] + 25:
        return 'briefing'
    if spawn[0] > 35 and spawn[0] > spawn[1] + 15:   # dark-red SPAWN button, measured [45,23,24]
        return 'spawn'
    if hud[1] > 55 and hud[1] > hud[0] + 15:
        return 'inworld'
    return 'unknown'


def click(px, py):
    gamectl('winmove', str(px), str(py), str(VIEW))
    time.sleep(0.4)
    gamectl('click')
    time.sleep(0.6)


ACTIONS = {
    # screen  -> sequence of clicks in VIEW-scale window coords
    'role': [(30, 145), (175, 103), (1130, 487)],   # civilian side, slot 1, OK
    'dialog': [(513, 235)],                          # CLOSE
    # The welcome screen ALWAYS carries an error dialog that must be cleared
    # before PLAY accepts a click (owner, 2026-08-04) — clearing it is part of
    # the briefing action, not a separate state, otherwise the driver loops
    # clicking a PLAY button that is behind a modal.
    'briefing': [(513, 235), (1113, 485)],           # CLOSE error, then PLAY
    'spawn': [(448, 130), (466, 371)],               # La Trinite, SPAWN
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--no-launch', action='store_true')
    ap.add_argument('--timeout', type=int, default=600)
    a = ap.parse_args()

    if not a.no_launch:
        # Note the OLD window first: launch_arma.sh kills any running instance,
        # and without this the driver classifies the doomed window (often
        # 'inworld') and declares success against a game that is about to die.
        before = game_window()
        old_pid = before['pid'] if before else None
        print('[join] launching...', flush=True)
        subprocess.Popen(['bash', os.path.join(HERE, 'launch_arma.sh'),
                          '-connect=127.0.0.1', '-port=2342'],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        for _ in range(90):          # wait for a genuinely new window
            time.sleep(5)
            w = game_window()
            if w and w['pid'] != old_pid:
                print(f"[join] new instance (pid {w['pid']})", flush=True)
                break

    deadline = time.time() + a.timeout
    last = None
    while time.time() < deadline:
        im = shot()
        if im is None:
            print('[join] waiting for game window', flush=True)
            time.sleep(10)
            continue
        state = classify(im)
        if state != last:
            print(f'[join] screen: {state}', flush=True)
            last = state
        if state == 'inworld':
            print('[join] IN WORLD', flush=True)
            return 0
        for pt in ACTIONS.get(state, []):
            click(*pt)
        time.sleep(6 if state == 'unknown' else 3)

    print('[join] TIMEOUT', flush=True)
    return 1


if __name__ == '__main__':
    sys.exit(main())
