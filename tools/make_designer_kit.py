#!/usr/bin/env python3
"""Build the zip we hand to an external map designer. No tools on their end, ever.

The kit is three things:
  MaldenEdit.Malden/   a REAL copy of the edit mission (fresh-staged, so every map row, NPC
                       anchor and custom building is already an editable 3DEN entity -- the old
                       designer_package.py's in-editor bake step died with the D2 pipeline)
  compositions/        every MAD_* drag-in composition, generated straight into the kit
  README.txt           install + workflow, written for someone who will never open a terminal

Their loop: edit -> save -> send mission.sqm back. Ours: drop their file into our
MaldenEdit.Malden and run tools/edit-map.sh apply -- the same command every local save uses, and
the stale-session self-healing covers their file coming from an older staging.

    python3 tools/make_designer_kit.py            # writes dist/MAD_designer_kit_<date>.zip
"""
import os
import shutil
import subprocess
import sys
import time
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_codegen as MC

REPO = MC.REPO
DIST = os.path.join(REPO, "dist")

README = """MALDEN AFTER DARK -- MAP DESIGNER KIT
=====================================

WHAT THIS IS
  The complete, editable Armapunk 2035 map. Every building, prop, shop NPC and custom
  structure is a real object in the Eden editor -- drag things, place new ones, save, send the
  save back. You never run any tool.

INSTALL (once)
  1. Copy the  MaldenEdit.Malden  folder into:
         Documents\\Arma 3\\mpmissions\\
  2. Copy the CONTENTS of the  compositions  folder into:
         Documents\\Arma 3\\compositions\\
     (so you end up with Documents\\Arma 3\\compositions\\MAD_NPC_shops_gun\\ etc.)
  3. Start Arma 3 -> EDITOR -> Malden -> Open -> MaldenEdit.

EVERY TIME YOU OPEN THE MISSION
  Open the debug console (Tools -> Debug Console) and run, as LOCAL EXEC:

      call compile preprocessFileLineNumbers "edenDraw.sqf";

  This draws the shop NPCs and the custom buildings on their anchor points and keeps the models
  glued to the anchors while you drag them. Without it those anchors are invisible helipad
  markers -- you would be moving things you cannot see.

PLACING THINGS
  Asset Browser -> Compositions -> Custom. Everything of ours is prefixed MAD:
      MAD Building - ...     the custom structures (bank, palace, police HQ, bridges...)
      MAD NPC - ...          every shop/service/civic NPC, behaviour pre-wired
      MAD Garage - ...       vehicle shops & garages, spawn pads INCLUDED -- they wire
                             themselves to any pad marker within 150 m
      MAD Spawn Pad - ...    extra vehicle spawn pads (car / air / boat)
      MAD Light - ...        lamps that are actually on at night
  Vanilla objects from the normal asset browser are fine too -- place anything, anywhere.
  Rotating a spawn pad marker sets the direction vehicles face when they appear.

THE FEW RULES
  * SAVE NORMALLY, and save often. This mission is MEANT to be saved (unlike the old package).
  * Do not RENAME markers. Moving them is fine; names are wired into game systems.
  * A few NPC compositions contain the word SETME in their Init (turf dealer, chop shop,
    delivery point). That marks a value only you or the owner can decide -- either edit it per
    the note next to it, or leave it and tell the owner what you intended; unfinished SETMEs are
    caught on our side, nothing breaks.
  * Characters and buildings you drag from MAD compositions are anchors + drawn models. Select
    and move the ANCHOR (the entity the editor actually selects); the model follows.
  * Terrain-clearing modules (Systems -> Modules -> Environment -> Hide Terrain Objects) work
    and are kept -- use them freely.

SENDING WORK BACK
  Send the single file:
      Documents\\Arma 3\\mpmissions\\MaldenEdit.Malden\\mission.sqm
  That file carries everything you did. Nothing else is needed.

  When you receive an UPDATED kit (or just an updated mission.sqm) from the owner, replace your
  copy before continuing -- editing on top of an old one still works, but the owner's tooling
  has to reconstruct more and your next send gets slower to review.
"""


def main():
    stamp = time.strftime("%Y%m%d")
    os.makedirs(DIST, exist_ok=True)
    build = os.path.join(DIST, "_kit_build")
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)

    # fresh stage so the kit's sqm is exactly the current map
    # stage reads map_objects (mapdb): psycopg lives in the PySQF venv, not the system python
    _py = os.path.expanduser("~/pysqf-venv/bin/python")
    if not os.path.exists(_py):
        _py = sys.executable
    r = subprocess.run([_py, os.path.join(REPO, "tools", "map_codegen.py"), "stage"],
                       capture_output=True, text=True, env=dict(os.environ, AP_FORCE_STAGE="1"))
    if r.returncode != 0:
        sys.exit("stage failed:\n" + r.stdout + r.stderr)

    # the mission: real files, no symlinks, no .bak, plus the freshly staged sqm
    mdst = os.path.join(build, "MaldenEdit.Malden")
    print("copying mission (this is ~235 MB) ...")
    shutil.copytree(MC.MISSION, mdst,
                    ignore=shutil.ignore_patterns("*.bak", "*.bak-*", "mission.sqm"))
    shutil.copy(os.path.join(MC.EDIT_DIR, "mission.sqm"), os.path.join(mdst, "mission.sqm"))

    # compositions: generate straight into the kit
    comp = os.path.join(build, "compositions")
    os.makedirs(comp)
    r = subprocess.run([sys.executable, os.path.join(REPO, "tools", "make_compositions.py")],
                       capture_output=True, text=True, env=dict(os.environ, AP_COMPOSITIONS=comp))
    if r.returncode != 0:
        sys.exit("composition build failed:\n" + r.stdout + r.stderr)
    ncomp = len(os.listdir(comp))

    open(os.path.join(build, "README.txt"), "w", newline="\r\n").write(README)

    out = os.path.join(DIST, "MAD_designer_kit_%s.zip" % stamp)
    print("zipping ...")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for root, _dirs, files in os.walk(build):
            for f in files:
                p = os.path.join(root, f)
                z.write(p, os.path.relpath(p, build))
    shutil.rmtree(build)
    print("kit: %s  (%.0f MB, %d compositions)" % (out, os.path.getsize(out) / 1e6, ncomp))


if __name__ == "__main__":
    main()
