#!/usr/bin/env bash
# Run CLANKR (dupe/exploit detector). Shares loonybot's venv + config.json + outbox.
# Start it ALONGSIDE loonybot (loonybot posts the alerts CLANKR drops in outbox/).
set -e
cd "$(dirname "$0")"
if [ -x "venv/bin/python" ]; then
    exec venv/bin/python -u clankr.py
fi
exec python3 -u clankr.py
