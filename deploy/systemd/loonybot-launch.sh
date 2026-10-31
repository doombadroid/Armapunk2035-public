#!/bin/sh
# systemd launcher for LoonyBot — installed to a SPACE-FREE path (/usr/local/bin/loonybot)
# so neither systemd nor the venv choke on the space in the project path.
cd "/home/timb/Documents/LooneyBin Altis Life/loonybot" || exit 1
exec venv/bin/python -u loonybot.py
