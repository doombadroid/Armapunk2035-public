#!/usr/bin/env bash
# Run LoonyBot. Uses ./venv if present, else system python3.
set -e
cd "$(dirname "$0")"
if [ -x "venv/bin/python" ]; then
    exec venv/bin/python loonybot.py
fi
exec python3 loonybot.py
