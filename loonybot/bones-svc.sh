#!/bin/bash
# bones launcher -- supervise-daemon chokes on spaces in the project path, so cd here + exec the venv python.
cd "/home/timb/Documents/LooneyBin Altis Life/loonybot" || exit 1
exec ./venv/bin/python -u bones.py
