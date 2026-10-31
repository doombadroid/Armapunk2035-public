> **2026-09-07: superseded on the live box by `radio/docker-compose.live.yml`** (no Arch packages exist for icecast/liquidsoap; the dev-tested docker images run on .96 instead, loopback :8000 behind the tunnel). Kept for the systemd/AUR variant.

# Malden Radio — live install on .96 (owner-gated; do NOT run during a freeze window)

1. `paru -S icecast` (AUR — icecast is not in the official Arch repos); liquidsoap: `paru -S liquidsoap`
   (AUR) OR drop the official static binary from github.com/savonet/liquidsoap releases at
   /usr/bin/liquidsoap (pin the version dev tested: 2.2.5). `liquidsoap --version` must print it.
2. Users+dirs: `sudo useradd -r -s /usr/bin/nologin radio` (icecast pkg creates its own user);
   `sudo mkdir -p /srv/radio/{origin,khr,pulse,classico,anarchy} /etc/malden-radio && sudo chown -R radio:radio /srv/radio`
   `sudo mkdir -p /var/log/icecast && sudo chown icecast:icecast /var/log/icecast` (the unit's
   ReadWritePaths needs it to exist and be writable by the icecast user — don't rely on the package).
3. Configs: `sudo install -m 640 -o root -g icecast radio/prod/icecast.xml /etc/malden-radio/`
   `sudo install -m 644 radio/radio.liq /etc/malden-radio/`
   `sudo install -m 600 -o root -g root /dev/null /etc/malden-radio/liquidsoap.env`
   Generate real passwords (`openssl rand -hex 16` twice): edit them into icecast.xml AND write
   `ICECAST_SOURCE_PASSWORD=<the source one>` into liquidsoap.env (both files stay root-owned;
   systemd reads the env file as pid 1, the icecast group covers the daemon's config read).
4. Units: copy `radio/systemd/*.service` to /etc/systemd/system/;
   `sudo systemctl daemon-reload && sudo systemctl enable --now malden-radio-icecast malden-radio-liquidsoap`
5. Music: rsync station folders into /srv/radio/<mount>/ (adding a song later = drop a file, no restarts).
6. cloudflared: add ingress hostname radio.projectloonybin.com -> http://127.0.0.1:8000 in the
   existing tunnel config + a CNAME in the Cloudflare dashboard; restart the tunnel service.
7. Verify: `curl -s https://radio.projectloonybin.com/origin -m 1 -o /dev/null -w '%{http_code} %{content_type}\n'` -> 200 audio/mpeg;
   `curl -s https://radio.projectloonybin.com/status-json.xsl | grep -o origin` ;
   reboot test: `sudo reboot` (OUTSIDE freeze, players off) -> both units active after boot.
8. Mission/live PBO deploy: normal `update.md` process (the mission changes shipped in this branch).
