#!/bin/sh
# systemd launcher for Officer Maggot (MaxSec whitelist bot).
cd "/home/timb/Documents/LooneyBin Altis Life/loonybot" || exit 1
exec venv/bin/python -u officer_maggot.py
