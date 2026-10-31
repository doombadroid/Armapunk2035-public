#!/bin/sh
# LoonyBot service launcher. Installed to a SPACE-FREE path (/usr/local/bin/loonybot)
# because OpenRC's supervise-daemon can't handle the spaces in the project path.
cd "/home/timb/Documents/LooneyBin Altis Life/loonybot" || exit 1
exec venv/bin/python -u loonybot.py
