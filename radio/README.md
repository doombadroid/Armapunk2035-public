# Malden Radio — server backend + client addon

Streaming car-radio backend (Icecast + liquidsoap) and the optional `@MaldenRadio` client addon.
Design: `docs/malden-radio-design.md`. Music files live OUTSIDE the repo (`~/radio-music` on dev,
`/srv/radio` on live) and are never committed.

**Dev note:** gen_test_tracks.sh generates tagged FLAC (title/artist metadata) — liquidsoap needs
the tags to push now-playing titles; it still outputs MP3 for streaming via Icecast regardless of
source format.

Dev quickstart:
  bash radio/gen_test_tracks.sh          # tone tracks into ~/radio-music/
  docker compose -f radio/docker-compose.dev.yml up -d
  curl -s http://127.0.0.1:8000/origin -m 1 -o /dev/null -w '%{http_code} %{content_type}\n'   # expect: 200 audio/mpeg
Build addon:
  bash radio/build_addon.sh              # → radio/dist/@MaldenRadio/
Live install (owner-gated): radio/INSTALL-96.md
